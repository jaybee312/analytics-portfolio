#!/usr/bin/env Rscript

# Outlier Detection POC Runner (with IQR + MAD)
# Usage: Rscript scripts/run_odet.R --config configs/sample_poc.yml

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(data.table)
  library(jsonlite)
})

# --- CLI args ---
option_list <- list(
  make_option(c("--config"), type = "character", help = "Path to YAML config")
)
opt <- parse_args(OptionParser(option_list = option_list))
if (is.null(opt$config)) stop("You must provide --config pointing to a YAML file")

# --- Load config ---
cfg <- yaml::read_yaml(opt$config)

dataset_name <- cfg$dataset_name
input_path   <- cfg$input$path
report_dir   <- cfg$reporting$out_dir
artifact_dir <- cfg$backfeed$out_dir

dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)

cat("Running Outlier Detection POC\n")
cat("Dataset:", dataset_name, "\n")
cat("Input file:", input_path, "\n")

# --- Load data ---
if (!file.exists(input_path)) stop("Input file not found: ", input_path)
dt <- fread(input_path)
cat("Loaded data with", nrow(dt), "rows and", ncol(dt), "columns\n")

# --- Choose numeric columns from config (fall back to auto-detect) ---
numeric_cols <- cfg$schema$numeric_cols
if (is.null(numeric_cols) || length(numeric_cols) == 0) {
  numeric_cols <- names(dt)[vapply(dt, is.numeric, TRUE)]
  cat("Auto-detected numeric columns:", paste(numeric_cols, collapse = ", "), "\n")
} else {
  # ensure existence
  missing <- setdiff(numeric_cols, names(dt))
  if (length(missing)) {
    warning("Configured numeric_cols not found in data: ", paste(missing, collapse = ", "))
    numeric_cols <- intersect(numeric_cols, names(dt))
  }
}

# --- Load detectors (IQR + MAD) ---
source(file.path("R", "detectors_univariate.R"))

# Pull params with defaults
whisker_k <- tryCatch(cfg$run$detectors$iqr$whisker_k, error = function(e) 1.5)
iqr_enabled <- isTRUE(cfg$run$detectors$iqr$enabled)

mad_thresh <- tryCatch(cfg$run$detectors$mad$z_thresh, error = function(e) 3.5)
mad_enabled <- isTRUE(cfg$run$detectors$mad$enabled)

max_flagged_pct <- tryCatch(cfg$controls$max_flagged_pct, error = function(e) NA_real_)
min_support_rows <- tryCatch(cfg$controls$min_support_rows, error = function(e) 0)

# --- Run detectors ---
flags_list <- list()

if (iqr_enabled) {
  flags_list[["iqr"]] <- iqr_flags(dt, numeric_cols, whisker_k = whisker_k)
}

if (mad_enabled) {
  flags_list[["mad"]] <- mad_flags(dt, numeric_cols, z_thresh = mad_thresh)
}

flags <- rbindlist(flags_list, use.names = TRUE, fill = TRUE)
# Drop NA scores or rows without indices
if (nrow(flags)) {
  flags <- flags[is.finite(score) & !is.na(row_index)]
}

# Apply cap on total flagged rows (optional)
flags <- apply_flag_caps(flags, n_rows = nrow(dt), max_flagged_pct = max_flagged_pct)

# Optional: enforce min_support_rows at column level (simple heuristic)
if (nrow(flags) && is.finite(min_support_rows) && min_support_rows > 1) {
  col_support <- flags[, .N, by = columns]
  keep_cols <- col_support[N >= min_support_rows, columns]
  if (length(keep_cols)) {
    flags <- flags[columns %in% keep_cols]
  } else {
    flags <- flags[0]  # none meet support threshold
  }
}

# --- Write outputs ---
outliers_file <- file.path(report_dir, "outliers.csv")
if (nrow(flags)) {
  # ensure deterministic order
  setorder(flags, -score, detector, columns, row_index)
  fwrite(flags, outliers_file)
} else {
  fwrite(data.table(
    row_index = integer(),
    detector = character(),
    score = numeric(),
    severity = character(),
    columns = character(),
    notes = character()
  ), outliers_file)
}
cat("Wrote:", outliers_file, " (", nrow(flags), " rows )\n", sep = "")

# summary.md
summary_file <- file.path(report_dir, "summary.md")
summary_lines <- c(
  paste0("# Outlier Report: ", dataset_name),
  "",
  "## Summary",
  paste0("- Rows: ", nrow(dt)),
  paste0("- Columns: ", ncol(dt)),
  paste0("- Numeric cols evaluated: ", paste(numeric_cols, collapse = ", ")),
  paste0("- Flags found: ", ifelse(nrow(flags) > 0, nrow(flags), 0L)),
  "",
  "## Detectors Enabled",
  paste0("- IQR: ", ifelse(iqr_enabled, paste0("yes (k=", whisker_k, ")"), "no")),
  paste0("- MAD: ", ifelse(mad_enabled, paste0("yes (z_thresh=", mad_thresh, ")"), "no")),
  "",
  "## Notes",
  if (nrow(flags)) {
    "See outliers.csv for row-level details."
  } else {
    "No outliers flagged with current thresholds."
  }
)
writeLines(summary_lines, summary_file)
cat("Wrote:", summary_file, "\n")

# rule_candidates.json (very simple for POC; MVP will learn caps/allowed values)
rules_file <- file.path(artifact_dir, "rule_candidates.json")
writeLines(toJSON(list(
  dataset = dataset_name,
  generated_at = as.character(Sys.time()),
  rules = list()  # filled by MVP drift/quality modules
), pretty = TRUE, auto_unbox = TRUE), rules_file)
cat("Wrote:", rules_file, "\n")

cat("POC run complete.\n")
