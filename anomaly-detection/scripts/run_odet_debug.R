#!/usr/bin/env Rscript
# scripts/run_odet_debug.R
# Verbose runner: prints numeric columns, quantiles/MAD per column, detector counts,
# and how many rows are removed by caps/support filters.

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(data.table)
  library(jsonlite)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- CLI ----
option_list <- list(
  make_option(c("--config"), type = "character", help = "Path to YAML config"),
  make_option(c("--dataset"), type = "character", default = NULL,
              help = "Only run one dataset by name (for batch configs)"),
  make_option(c("--no_caps"), action = "store_true", default = FALSE,
              help = "Disable max_flagged_pct cap"),
  make_option(c("--no_support"), action = "store_true", default = FALSE,
              help = "Disable min_support_rows filter")
)
opt <- parse_args(OptionParser(option_list = option_list))
if (is.null(opt$config)) stop("Provide --config <yml>")

# ---- Load config ----
cfg <- yaml::read_yaml(opt$config)

# ---- Load detectors (same as prod runner) ----
safe_source <- function(path) {
  if (!file.exists(path)) { message("WARN: Missing file: ", path); return(FALSE) }
  tryCatch({
    # Put all functions directly into the global workspace for this Rscript
    sys.source(path, envir = .GlobalEnv)
    TRUE
  }, error = function(e) {
    message("ERROR sourcing ", path, ": ", conditionMessage(e))
    FALSE
  })
}


safe_source(file.path("R", "detectors_univariate.R"))
safe_source(file.path("R", "detectors_multivariate.R"))
# Fallbacks
ok_uni   <- safe_source(file.path("R", "detectors_univariate.R"))
ok_multi <- safe_source(file.path("R", "detectors_multivariate.R"))
if (!ok_uni || !ok_multi) stop("Failed to source one or more detector files.")

# Hard fail if functions are missing (check in the global env, inherit if needed)
stopifnot(
  exists("iqr_flags", envir = .GlobalEnv, inherits = TRUE),
  exists("mad_flags", envir = .GlobalEnv, inherits = TRUE),
  exists("apply_flag_caps", envir = .GlobalEnv, inherits = TRUE),
  exists("if_isolation_forest", envir = .GlobalEnv, inherits = TRUE),
  exists("lof_flags", envir = .GlobalEnv, inherits = TRUE)
)



num_cols_from_cfg <- function(dt, cfg_cols) {
  if (is.null(cfg_cols) || !length(cfg_cols)) {
    return(names(dt)[vapply(dt, function(v) is.numeric(v) || is.integer(v), TRUE)])
  }
  intersect(cfg_cols, names(dt))
}

# ---- Debug helpers ----
dbg_univariate_stats <- function(dt, cols, whisker_k, z_thresh) {
  cat("\n[DEBUG] Univariate stats per numeric column\n")
  for (col in cols) {
    x <- suppressWarnings(as.numeric(dt[[col]]))
    if (all(is.na(x))) {
      cat(sprintf("  - %s: all NA after coercion\n", col)); next
    }
    q <- quantile(x, c(.25,.75), na.rm=TRUE)
    iqr <- q[2]-q[1]
    lower <- q[1] - whisker_k * iqr
    upper <- q[2] + whisker_k * iqr
    iqr_n <- sum(!is.na(x) & (x < lower | x > upper))
    med <- median(x, na.rm=TRUE)
    madv <- mad(x, constant = 1.4826, na.rm=TRUE)
    rz <- if (is.finite(madv) && madv>0) abs(x - med)/madv else rep(NA_real_, length(x))
    mad_n <- sum(!is.na(rz) & rz >= z_thresh)
    cat(sprintf("  - %s: Q1=%.3f Q3=%.3f IQR=%.3f (k=%.2f) -> IQR flags=%d | median=%.3f MAD=%.3f (z>=%.2f) -> MAD flags=%d\n",
                col, q[1], q[2], iqr, whisker_k, iqr_n, med, madv, z_thresh, mad_n))
  }
}

dbg_counts <- function(stage, dt_flags) {
  cat(sprintf("[DEBUG] %-18s flags=%d\n", stage, ifelse(is.null(dt_flags), 0L, nrow(dt_flags))))
}

write_outputs <- function(dt_flags, report_dir, artifact_dir, dataset_name, detectors_enabled) {
  dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
  
  outliers_file <- file.path(report_dir, "outliers.csv")
  if (nrow(dt_flags)) {
    data.table::setorder(dt_flags, -score, detector, columns, row_index)
    data.table::fwrite(dt_flags, outliers_file)
  } else {
    data.table::fwrite(data.table(
      row_index = integer(), detector = character(), score = numeric(),
      severity = character(), columns = character(), notes = character()
    ), outliers_file)
  }
  
  summary_file <- file.path(report_dir, "summary.md")
  writeLines(c(
    paste0("# Outlier Report: ", dataset_name),
    "",
    "## Detectors Enabled",
    paste0("- ", names(detectors_enabled), ": ", ifelse(unlist(detectors_enabled), "yes", "no")),
    "",
    paste0("Flags found: ", ifelse(nrow(dt_flags)>0, nrow(dt_flags), 0L))
  ), summary_file)
  
  rules_file <- file.path(artifact_dir, "rule_candidates.json")
  writeLines(jsonlite::toJSON(list(dataset = dataset_name, generated_at = as.character(Sys.time()), rules=list()),
                              pretty = TRUE, auto_unbox = TRUE), rules_file)
  
  cat("Wrote:", outliers_file, "(", nrow(dt_flags), "rows )\n", sep=" ")
  cat("Wrote:", summary_file, "\n")
  cat("Wrote:", rules_file, "\n")
}

run_one <- function(global_cfg, ds_cfg, is_mvp=FALSE, no_caps=FALSE, no_support=FALSE) {
  dataset_name <- ds_cfg$name %||% global_cfg$dataset_name %||% "<unnamed>"
  input_path   <- ds_cfg$input$path %||% global_cfg$input$path
  if (is.null(input_path) || !nzchar(input_path)) stop("input.path is required for dataset: ", dataset_name)
  
  if (is_mvp) {
    out_root <- global_cfg$reporting$out_dir_root %||% "reports"
    art_root <- global_cfg$backfeed$out_dir_root %||% "artifacts"
    report_dir   <- file.path(out_root, dataset_name)
    artifact_dir <- file.path(art_root, dataset_name)
  } else {
    report_dir   <- global_cfg$reporting$out_dir %||% file.path("reports", dataset_name)
    artifact_dir <- global_cfg$backfeed$out_dir %||% file.path("artifacts", dataset_name)
  }
  
  cat("\n=== Running:", dataset_name, "===\n")
  cat("Input:", input_path, "\n")
  if (!file.exists(input_path)) stop("Input not found: ", input_path)
  dt <- data.table::fread(input_path)
  cat("Rows/Cols:", nrow(dt), "/", ncol(dt), "\n")
  
  schema <- ds_cfg$schema %||% global_cfg$schema %||% list()
  numeric_cols <- num_cols_from_cfg(dt, schema$numeric_cols)
  cat("Numeric cols:", ifelse(length(numeric_cols), paste(numeric_cols, collapse=", "), "<none>"), "\n")
  
  det <- (global_cfg$run$detectors %||% list())
  if (!is.null(ds_cfg$run$detectors)) det <- modifyList(det, ds_cfg$run$detectors)
  
  iqr_enabled  <- isTRUE(det$iqr$enabled)
  mad_enabled  <- isTRUE(det$mad$enabled)
  if_enabled   <- isTRUE(det$isolation_forest$enabled)
  lof_enabled  <- isTRUE(det$lof$enabled)
  
  whisker_k <- det$iqr$whisker_k %||% 1.5
  mad_thresh <- det$mad$z_thresh %||% 3.5
  if_contam <- det$isolation_forest$contamination %||% 0.02
  if_ntrees <- det$isolation_forest$ntrees %||% 200
  if_sample <- det$isolation_forest$sample_size %||% 256
  lof_minPts <- det$lof$minPts %||% 10
  
  detectors_enabled <- list(
    "IQR" = iqr_enabled, "MAD" = mad_enabled,
    "IsolationForest" = if_enabled, "LOF" = lof_enabled
  )
  cat("Detectors:", paste(names(detectors_enabled)[unlist(detectors_enabled)], collapse=", "), "\n")
  
  # Print per-column stats for IQR/MAD so we see expected flags
  if (length(numeric_cols)) dbg_univariate_stats(dt, numeric_cols, whisker_k, mad_thresh)
  
  flags_list <- list()
  if (iqr_enabled) { flags_list[["iqr"]] <- iqr_flags(dt, numeric_cols, whisker_k = whisker_k); dbg_counts("after IQR", flags_list[["iqr"]]) }
  if (mad_enabled) { flags_list[["mad"]] <- mad_flags(dt, numeric_cols, z_thresh = mad_thresh); dbg_counts("after MAD", flags_list[["mad"]]) }
  if (if_enabled)  { flags_list[["if"]]  <- if_isolation_forest(dt, numeric_cols, contamination = if_contam, ntrees = if_ntrees, sample_size = if_sample); dbg_counts("after IF", flags_list[["if"]]) }
  if (lof_enabled) { flags_list[["lof"]] <- lof_flags(dt, numeric_cols, minPts = lof_minPts); dbg_counts("after LOF", flags_list[["lof"]]) }
  
  flags <- data.table::rbindlist(flags_list, use.names = TRUE, fill = TRUE)
  dbg_counts("combined", flags)
  
  # Controls
  controls <- global_cfg$controls %||% list()
  max_flagged_pct <- controls$max_flagged_pct %||% NA_real_
  min_support_rows <- controls$min_support_rows %||% 0
  
  if (!opt$no_caps && is.finite(max_flagged_pct) && max_flagged_pct > 0) {
    before <- nrow(flags); flags <- apply_flag_caps(flags, n_rows = nrow(dt), max_flagged_pct = max_flagged_pct)
    cat(sprintf("[DEBUG] cap max_flagged_pct=%s: %d -> %d\n", as.character(max_flagged_pct), before, nrow(flags)))
  } else {
    cat("[DEBUG] caps DISABLED for this run\n")
  }
  
  if (!opt$no_support && is.finite(min_support_rows) && min_support_rows > 1 && nrow(flags)) {
    before <- nrow(flags)
    col_support <- flags[, .N, by = columns]
    keep_cols <- col_support[N >= min_support_rows, columns]
    flags <- if (length(keep_cols)) flags[columns %in% keep_cols] else flags[0]
    cat(sprintf("[DEBUG] min_support_rows=%d: %d -> %d\n", min_support_rows, before, nrow(flags)))
  } else {
    cat("[DEBUG] min_support_rows filter DISABLED or <=1\n")
  }
  
  write_outputs(flags, report_dir, artifact_dir, dataset_name, detectors_enabled)
}

# ---- Main ----
if (!is.null(cfg$datasets)) {
  ds <- cfg$datasets
  if (!is.null(opt$dataset)) ds <- Filter(function(x) identical(x$name, opt$dataset), ds)
  if (!length(ds)) stop("No dataset matched --dataset (or datasets list empty).")
  for (d in ds) run_one(cfg, d, is_mvp = TRUE, no_caps = opt$no_caps, no_support = opt$no_support)
} else {
  run_one(cfg, cfg, is_mvp = FALSE, no_caps = opt$no_caps, no_support = opt$no_support)
}

cat("\nDone (debug run).\n")
