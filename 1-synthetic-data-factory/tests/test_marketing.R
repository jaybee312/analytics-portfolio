# Robust test runner: finds project root from this file location or CWD

root_from <- function(start="."){
  d <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(d, "R")) && file.exists(file.path(d, "config"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) stop("Project root not found (no R/ and config/ folders above).")
    d <- parent
  }
}

# If run via Rscript, get the --file argument to locate this script
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
start_dir <- if (length(file_arg)) dirname(file_arg) else getwd()

proj <- root_from(start_dir)

# Load schema validator
source(file.path(proj, "R/utils/validate.R"))

# 1) Files exist
out <- file.path(proj, "outputs/marketing")
files <- c("customers.csv","marketing_campaigns.csv","sales_funnel.csv","product_usage.csv","nps_responses.csv")
missing <- files[!file.exists(file.path(out, files))]
if (length(missing)) {
  stop(sprintf("Missing expected output files: %s", paste(missing, collapse=", ")))
}

# 2) Schema passes
if (!validate_marketing_schema(out)) stop("Schema validation failed.")

cat("All checks passed ✅\n")
