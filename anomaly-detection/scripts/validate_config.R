#!/usr/bin/env Rscript
# scripts/validate_config.R
# Validate odet YAML files (POC single-dataset or MVP batch)

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
})

schema_check_poc <- function(cfg) {
  errs <- c()
  need <- c("dataset_name","input","schema","run","reporting","backfeed")
  miss <- setdiff(need, names(cfg))
  if (length(miss)) errs <- c(errs, paste("Missing top-level keys:", paste(miss, collapse=", ")))
  
  if (is.null(cfg$input$path)) errs <- c(errs, "input.path is required")
  
  sch <- cfg$schema %||% list()
  if (is.null(sch$numeric_cols)) errs <- c(errs, "schema.numeric_cols is required (can be empty list, but must exist)")
  
  det <- cfg$run$detectors %||% list()
  if (is.null(det$iqr) && is.null(det$mad) && is.null(det$isolation_forest) &&
      is.null(det$lof) && is.null(det$tsoutliers) && is.null(det$anomalize)) {
    errs <- c(errs, "run.detectors has no entries")
  }
  
  rep <- cfg$reporting %||% list()
  if (is.null(rep$out_dir) && is.null(rep$out_dir_root)) errs <- c(errs, "reporting.out_dir or reporting.out_dir_root must be set")
  
  errs
}

schema_check_mvp <- function(cfg) {
  errs <- c()
  if (is.null(cfg$datasets) || !length(cfg$datasets)) {
    errs <- c(errs, "datasets list is required for MVP config")
    return(errs)
  }
  for (i in seq_along(cfg$datasets)) {
    ds <- cfg$datasets[[i]]
    if (is.null(ds$name)) errs <- c(errs, sprintf("datasets[%d].name is required", i))
    if (is.null(ds$input$path)) errs <- c(errs, sprintf("datasets[%d].input.path is required", i))
    if (is.null(ds$schema$numeric_cols)) errs <- c(errs, sprintf("datasets[%d].schema.numeric_cols is required", i))
  }
  det <- cfg$run$detectors %||% list()
  if (is.null(det$iqr) && is.null(det$mad) && is.null(det$isolation_forest) &&
      is.null(det$lof) && is.null(det$tsoutliers) && is.null(det$anomalize)) {
    errs <- c(errs, "run.detectors has no entries")
  }
  if (is.null(cfg$reporting$out_dir_root)) errs <- c(errs, "reporting.out_dir_root is required for MVP config")
  if (is.null(cfg$backfeed$out_dir_root)) errs <- c(errs, "backfeed.out_dir_root is required for MVP config")
  errs
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- CLI ----
option_list <- list(
  make_option(c("--config"), type="character", default=NULL, help="Path to YAML or glob pattern (e.g., configs/*.yml)")
)
opt <- parse_args(OptionParser(option_list = option_list))

if (is.null(opt$config)) {
  stop("Provide --config pointing to a YAML file or glob (e.g., configs/*.yml)")
}

# Expand globs via Sys.glob
paths <- Sys.glob(opt$config)
if (!length(paths)) stop("No files matched: ", opt$config)

status <- 0L
for (p in paths) {
  cat("Validating:", p, "\n")
  cfg <- tryCatch(yaml::read_yaml(p), error=function(e) {
    cat("  ERROR: YAML parse failed:", conditionMessage(e), "\n")
    return(NULL)
  })
  if (is.null(cfg)) { status <- 1L; next }
  
  # Choose schema check
  errs <- if (!is.null(cfg$datasets)) schema_check_mvp(cfg) else schema_check_poc(cfg)
  
  if (length(errs)) {
    cat("  INVALID:\n")
    for (e in errs) cat("   -", e, "\n")
    status <- 1L
  } else {
    cat("  OK\n")
  }
}
quit(status = status, save = "no")
