#!/usr/bin/env Rscript
# scripts/run_odet.R
# Outlier Detection runner (POC & MVP) + diagnostics JSON (incl. topN & runtimes) + TS detectors + HTML

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(data.table)
  library(jsonlite)
})

# ---- CLI args ----
option_list <- list(make_option(c("--config"), type = "character", help = "Path to YAML config"))
opt <- parse_args(OptionParser(option_list = option_list))
if (is.null(opt$config)) stop("You must provide --config pointing to a YAML file")

ensure_dir <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

# Source into global env (so functions are visible)
safe_source <- function(path) {
  if (!file.exists(path)) { message("WARN: Missing file: ", path); return(FALSE) }
  tryCatch({ sys.source(path, envir = .GlobalEnv); TRUE },
           error = function(e){ message("ERROR sourcing ", path, ": ", conditionMessage(e)); FALSE })
}

# Load modules
ok_uni   <- safe_source(file.path("R", "detectors_univariate.R"))
ok_multi <- safe_source(file.path("R", "detectors_multivariate.R"))
ok_ts    <- safe_source(file.path("R", "detectors_timeseries.R"))
ok_rep   <- safe_source(file.path("R", "reporting.R"))
if (!ok_uni || !ok_multi || !ok_rep) stop("Failed to source one or more core files (univariate/multivariate/reporting).")

stopifnot(
  exists("iqr_flags", envir = .GlobalEnv, inherits = TRUE),
  exists("mad_flags", envir = .GlobalEnv, inherits = TRUE),
  exists("apply_flag_caps", envir = .GlobalEnv, inherits = TRUE)
)
if (!exists("tsoutliers_flags", envir = .GlobalEnv, inherits = TRUE)) tsoutliers_flags <- function(...) data.table()
if (!exists("anomalize_flags", envir = .GlobalEnv, inherits = TRUE)) anomalize_flags <- function(...) data.table()
if (!exists("fable_resid_flags", envir = .GlobalEnv, inherits = TRUE)) fable_resid_flags <- function(...) data.table()

num_cols_from_cfg <- function(dt, cfg_cols) {
  if (is.null(cfg_cols) || !length(cfg_cols)) {
    return(names(dt)[vapply(dt, function(v) is.numeric(v) || is.integer(v), TRUE)])
  }
  intersect(cfg_cols, names(dt))
}

write_outputs <- function(dt_flags, report_dir, artifact_dir, dataset_name, detectors_enabled) {
  ensure_dir(report_dir); ensure_dir(artifact_dir)
  outliers_file <- file.path(report_dir, "outliers.csv")
  if (nrow(dt_flags)) { setorder(dt_flags, -score, detector, columns, row_index); fwrite(dt_flags, outliers_file) }
  else { fwrite(data.table(row_index=integer(),detector=character(),score=numeric(),severity=character(),columns=character(),notes=character()), outliers_file) }
  summary_file <- file.path(report_dir, "summary.md")
  writeLines(c(
    paste0("# Outlier Report: ", dataset_name),"","## Detectors Enabled",
    paste0("- ", names(detectors_enabled), ": ", ifelse(unlist(detectors_enabled), "yes", "no")),
    "", paste0("Flags found: ", ifelse(nrow(dt_flags) > 0, nrow(dt_flags), 0L))
  ), summary_file)
  rules_file <- file.path(artifact_dir, "rule_candidates.json")
  writeLines(toJSON(list(dataset=dataset_name,generated_at=as.character(Sys.time()),rules=list()),
                    pretty=TRUE, auto_unbox=TRUE), rules_file)
  cat("Wrote:", outliers_file, "(", nrow(dt_flags), "rows )\n")
  cat("Wrote:", summary_file, "\n")
  cat("Wrote:", rules_file, "\n")
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- timing helper -----------------------------------------------------------
time_it <- function(label, fn) {
  err <- NULL; res <- NULL; elapsed <- NA_real_
  t <- tryCatch({
    st <- proc.time()[["elapsed"]]
    res <- fn()
    et <- proc.time()[["elapsed"]]
    elapsed <<- as.numeric(et - st)
    TRUE
  }, error = function(e) { err <<- conditionMessage(e); FALSE })
  list(ok = t, result = res, runtime = list(elapsed_sec = elapsed, error = err))
}

run_single_dataset <- function(global_cfg, ds_cfg, is_mvp = FALSE) {
  dataset_name <- ds_cfg$name %||% global_cfg$dataset_name %||% "<unnamed>"
  input_path   <- ds_cfg$input$path %||% global_cfg$input$path
  if (is.null(input_path) || !nzchar(input_path)) stop("input.path is required for dataset: ", dataset_name)
  
  # Output dirs
  if (is_mvp) {
    out_root <- global_cfg$reporting$out_dir_root %||% "reports"
    art_root <- global_cfg$backfeed$out_dir_root %||% "artifacts"
    report_dir   <- file.path(out_root, dataset_name)
    artifact_dir <- file.path(art_root, dataset_name)
  } else {
    report_dir   <- global_cfg$reporting$out_dir %||% file.path("reports", dataset_name)
    artifact_dir <- global_cfg$backfeed$out_dir %||% file.path("artifacts", dataset_name)
  }
  ensure_dir(report_dir); ensure_dir(artifact_dir)
  
  cat("\nRunning Outlier Detection\n")
  cat("Dataset:", dataset_name, "\n")
  cat("Input file:", input_path, "\n")
  if (!file.exists(input_path)) stop("Input file not found: ", input_path)
  dt <- fread(input_path)
  cat("Loaded data with", nrow(dt), "rows and", ncol(dt), "columns\n")
  
  schema <- ds_cfg$schema %||% global_cfg$schema %||% list()
  numeric_cols <- num_cols_from_cfg(dt, schema$numeric_cols)
  time_col <- schema$time_col %||% NULL
  id_cols <- schema$id_cols %||% NULL
  
  controls <- global_cfg$controls %||% list()
  max_flagged_pct <- controls$max_flagged_pct %||% NA_real_
  min_support_rows <- controls$min_support_rows %||% 0
  
  det <- (global_cfg$run$detectors %||% list())
  if (!is.null(ds_cfg$run$detectors)) det <- modifyList(det, ds_cfg$run$detectors)
  
  iqr_enabled  <- isTRUE(det$iqr$enabled);       whisker_k <- det$iqr$whisker_k %||% 1.5
  mad_enabled  <- isTRUE(det$mad$enabled);       mad_thresh <- det$mad$z_thresh %||% 3.5
  if_enabled   <- isTRUE(det$isolation_forest$enabled)
  if_contam    <- det$isolation_forest$contamination %||% 0.02
  if_ntrees    <- det$isolation_forest$ntrees %||% 200
  if_sample    <- det$isolation_forest$sample_size %||% 256
  lof_enabled  <- isTRUE(det$lof$enabled);       lof_minPts <- det$lof$minPts %||% 10
  tso_enabled  <- isTRUE(det$tsoutliers$enabled)
  ano_enabled  <- isTRUE(det$anomalize$enabled); ano_method <- det$anomalize$method %||% "stl"; ano_alpha <- det$anomalize$alpha %||% 0.05
  fab_enabled  <- isTRUE(det$fable$enabled) || FALSE
  
  detectors_enabled <- list(
    "IQR" = iqr_enabled, "MAD" = mad_enabled,
    "IsolationForest" = if_enabled, "LOF" = lof_enabled,
    "TS.tsoutliers" = tso_enabled, "TS.anomalize" = ano_enabled, "TS.fable" = fab_enabled
  )
  
  # ----- Run detectors with timing
  runtimes <- list()
  flags_list <- list()
  
  if (iqr_enabled) {
    ans <- time_it("IQR", function() iqr_flags(dt, numeric_cols, whisker_k = whisker_k))
    runtimes$iqr <- c(ans$runtime, list(rows = nrow(dt)))
    flags_list[["iqr"]] <- if (is.null(ans$result)) data.table() else ans$result
  }
  if (mad_enabled) {
    ans <- time_it("MAD", function() mad_flags(dt, numeric_cols, z_thresh = mad_thresh))
    runtimes$mad <- c(ans$runtime, list(rows = nrow(dt)))
    flags_list[["mad"]] <- if (is.null(ans$result)) data.table() else ans$result
  }
  if (if_enabled) {
    ans <- time_it("IsolationForest", function() if_isolation_forest(dt, numeric_cols, contamination = if_contam, ntrees = if_ntrees, sample_size = if_sample))
    runtimes$isolation_forest <- c(ans$runtime, list(rows = nrow(dt)))
    flags_list[["if"]] <- if (is.null(ans$result)) data.table() else ans$result
  }
  if (lof_enabled) {
    ans <- time_it("LOF", function() lof_flags(dt, numeric_cols, minPts = lof_minPts))
    runtimes$lof <- c(ans$runtime, list(rows = nrow(dt)))
    flags_list[["lof"]] <- if (is.null(ans$result)) data.table() else ans$result
  }
  
  if (!is.null(time_col) && time_col %in% names(dt)) {
    ts_cols <- numeric_cols
    if (tso_enabled) {
      ans <- time_it("TS.tsoutliers", function() tsoutliers_flags(dt, time_col, ts_cols))
      runtimes$tsoutliers <- c(ans$runtime, list(rows = nrow(dt)))
      flags_list[["tso"]] <- if (is.null(ans$result)) data.table() else ans$result
    }
    if (ano_enabled) {
      ans <- time_it("TS.anomalize", function() anomalize_flags(dt, time_col, ts_cols, method = ano_method, alpha = ano_alpha))
      runtimes$anomalize <- c(ans$runtime, list(rows = nrow(dt)))
      flags_list[["ano"]] <- if (is.null(ans$result)) data.table() else ans$result
    }
    if (fab_enabled) {
      ans <- time_it("TS.fable", function() fable_resid_flags(dt, time_col, ts_cols))
      runtimes$fable <- c(ans$runtime, list(rows = nrow(dt)))
      flags_list[["fab"]] <- if (is.null(ans$result)) data.table() else ans$result
    }
  }
  
  flags <- rbindlist(flags_list, use.names = TRUE, fill = TRUE)
  if (nrow(flags)) {
    flags <- flags[is.finite(score) | is.na(score)]
    flags <- flags[!is.na(row_index)]
    if (is.finite(max_flagged_pct) && max_flagged_pct > 0) {
      flags <- apply_flag_caps(flags, n_rows = nrow(dt), max_flagged_pct = max_flagged_pct)
    }
    if (is.finite(min_support_rows) && min_support_rows > 1 && nrow(flags)) {
      col_support <- flags[, .N, by = columns]
      keep_cols <- col_support[N >= min_support_rows, columns]
      flags <- if (length(keep_cols)) flags[columns %in% keep_cols] else flags[0]
    }
  }
  
  # ----- Compute exact thresholds for multivariate
  mv_thresholds <- list()
  if (if_enabled)  mv_thresholds$isolation_forest <- compute_if_threshold(dt, numeric_cols, contamination = if_contam, ntrees = if_ntrees, sample_size = if_sample)
  if (lof_enabled) mv_thresholds$lof <- compute_lof_threshold(dt, numeric_cols, minPts = lof_minPts, q = 0.98)
  
  # ----- Build top-N flags per detector (for JSON)
  topN <- 20
  top_flags <- list()
  if (nrow(flags)) {
    # split by detector and take top by score (NA scores last)
    det_levels <- unique(flags$detector)
    for (d in det_levels) {
      sub <- flags[detector == d]
      if (!nrow(sub)) next
      sub <- sub[order(-ifelse(is.finite(score), score, -Inf))][1:min(topN, nrow(sub))]
      # include row_index, columns, score, severity, notes
      top_flags[[d]] <- sub[, .(row_index, columns, score, severity, notes)]
    }
  }
  
  # ----- Diagnostics JSON
  detectors_config <- list(
    iqr = list(enabled = iqr_enabled, whisker_k = whisker_k),
    mad = list(enabled = mad_enabled, z_thresh = mad_thresh),
    isolation_forest = list(enabled = if_enabled, contamination = if_contam, ntrees = if_ntrees, sample_size = if_sample),
    lof = list(enabled = lof_enabled, minPts = lof_minPts),
    tsoutliers = list(enabled = tso_enabled),
    anomalize = list(enabled = ano_enabled, method = ano_method, alpha = ano_alpha),
    fable = list(enabled = fab_enabled)
  )
  numeric_diag <- compute_numeric_diagnostics(dt, numeric_cols, iqr_k = whisker_k, mad_z = mad_thresh)
  ts_meta <- compute_timeseries_meta(dt, time_col, id_cols = id_cols)
  diag_path <- write_diagnostics_json(
    report_dir, dataset_name, detectors_config, numeric_diag,
    ts_meta = ts_meta, mv_thresholds = mv_thresholds, top_flags = top_flags, runtimes = runtimes
  )
  
  # ----- Write CSV/MD & render HTML (if requested)
  write_outputs(flags, report_dir, artifact_dir, dataset_name, detectors_enabled)
  
  formats <- global_cfg$reporting$formats %||% list("md","csv")
  if ("html" %in% formats) {
    render_html_report(
      report_dir = report_dir,
      dataset_name = dataset_name,
      dt_path = input_path,
      outliers_path = file.path(report_dir, "outliers.csv"),
      diagnostics_path = diag_path
    )
  }
}

# ---- Main ----
cfg <- yaml::read_yaml(opt$config)
if (!is.null(cfg$datasets)) {
  for (i in seq_along(cfg$datasets)) run_single_dataset(cfg, cfg$datasets[[i]], is_mvp = TRUE)
} else {
  run_single_dataset(cfg, cfg, is_mvp = FALSE)
}
cat("\nAll datasets complete.\n")
