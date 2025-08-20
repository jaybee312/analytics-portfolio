#!/usr/bin/env Rscript
# scripts/run_odet.R
# Outlier Detection runner (supports POC single-dataset AND MVP batch configs)

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

# ---- Load config ----
cfg <- yaml::read_yaml(opt$config)

# ---- Helpers ----
ensure_dir <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

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



# Load detectors (univariate + multivariate if present)
safe_source(file.path("R", "detectors_univariate.R"))
safe_source(file.path("R", "detectors_multivariate.R"))

# Load detectors (must succeed; no silent fallbacks)
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
    # auto-detect numeric-like columns
    return(names(dt)[vapply(dt, function(v) is.numeric(v) || is.integer(v), TRUE)])
  }
  intersect(cfg_cols, names(dt))
}

write_outputs <- function(dt_flags, report_dir, artifact_dir, dataset_name, numeric_cols, detectors_enabled) {
  ensure_dir(report_dir); ensure_dir(artifact_dir)
  
  # outliers.csv
  outliers_file <- file.path(report_dir, "outliers.csv")
  if (nrow(dt_flags)) {
    setorder(dt_flags, -score, detector, columns, row_index)
    fwrite(dt_flags, outliers_file)
  } else {
    fwrite(data.table(
      row_index = integer(), detector = character(), score = numeric(),
      severity = character(), columns = character(), notes = character()
    ), outliers_file)
  }
  
  # summary.md
  summary_file <- file.path(report_dir, "summary.md")
  summary_lines <- c(
    paste0("# Outlier Report: ", dataset_name),
    "",
    "## Summary",
    paste0("- Flags found: ", nrow(dt_flags)),
    "",
    "## Detectors Enabled"
  )
  summary_lines <- c(summary_lines, paste0("- ", names(detectors_enabled), ": ",
                                           ifelse(unlist(detectors_enabled), "yes", "no")))
  writeLines(summary_lines, summary_file)
  
  # rule_candidates.json (placeholder at POC/MVP start)
  rules_file <- file.path(artifact_dir, "rule_candidates.json")
  writeLines(toJSON(list(
    dataset = dataset_name,
    generated_at = as.character(Sys.time()),
    rules = list()
  ), pretty = TRUE, auto_unbox = TRUE), rules_file)
  
  cat("Wrote:", outliers_file, "(", nrow(dt_flags), "rows )\n", sep = " ")
  cat("Wrote:", summary_file, "\n")
  cat("Wrote:", rules_file, "\n")
}

run_single_dataset <- function(global_cfg, ds_cfg, is_mvp = FALSE) {
  # Derive dataset-level pieces from either POC or MVP schema
  dataset_name <- ds_cfg$name %||% global_cfg$dataset_name %||% "<unnamed>"
  input_path   <- ds_cfg$input$path %||% global_cfg$input$path
  if (is.null(input_path) || !nzchar(input_path)) stop("input.path is required for dataset: ", dataset_name)
  
  # Reporting dirs
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
  
  # Load data
  if (!file.exists(input_path)) stop("Input file not found: ", input_path)
  dt <- fread(input_path)
  cat("Loaded data with", nrow(dt), "rows and", ncol(dt), "columns\n")
  
  # Schema
  schema <- ds_cfg$schema %||% global_cfg$schema %||% list()
  numeric_cols <- num_cols_from_cfg(dt, schema$numeric_cols)
  
  # Controls
  controls <- global_cfg$controls %||% list()
  max_flagged_pct <- controls$max_flagged_pct %||% NA_real_
  min_support_rows <- controls$min_support_rows %||% 0
  
  # Detector params
  det <- (global_cfg$run$detectors %||% list())
  # Some configs nest detectors under ds_cfg; prefer ds_cfg overrides if present
  if (!is.null(ds_cfg$run$detectors)) {
    det <- modifyList(det, ds_cfg$run$detectors)
  }
  
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
  
  # Run detectors
  flags_list <- list()
  if (iqr_enabled) flags_list[["iqr"]] <- iqr_flags(dt, numeric_cols, whisker_k = whisker_k)
  if (mad_enabled) flags_list[["mad"]] <- mad_flags(dt, numeric_cols, z_thresh = mad_thresh)
  if (if_enabled)  flags_list[["if"]]  <- if_isolation_forest(dt, numeric_cols,
                                                              contamination = if_contam,
                                                              ntrees = if_ntrees,
                                                              sample_size = if_sample)
  if (lof_enabled) flags_list[["lof"]] <- lof_flags(dt, numeric_cols, minPts = lof_minPts)
  
  flags <- rbindlist(flags_list, use.names = TRUE, fill = TRUE)
  if (nrow(flags)) {
    flags <- flags[is.finite(score) & !is.na(row_index)]
    # Apply cap on total flagged rows
    flags <- apply_flag_caps(flags, n_rows = nrow(dt), max_flagged_pct = max_flagged_pct)
    # Enforce min_support_rows per column (simple)
    if (is.finite(min_support_rows) && min_support_rows > 1) {
      col_support <- flags[, .N, by = columns]
      keep_cols <- col_support[N >= min_support_rows, columns]
      if (length(keep_cols)) flags <- flags[columns %in% keep_cols] else flags <- flags[0]
    }
  }
  
  write_outputs(flags, report_dir, artifact_dir, dataset_name, numeric_cols, detectors_enabled)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- Main ----
if (!is.null(cfg$datasets)) {
  # MVP batch mode
  for (i in seq_along(cfg$datasets)) {
    run_single_dataset(cfg, cfg$datasets[[i]], is_mvp = TRUE)
  }
} else {
  # POC single dataset
  run_single_dataset(cfg, cfg, is_mvp = FALSE)
}

cat("\nAll datasets complete.\n")
