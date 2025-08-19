#===== FILE: R/main.R =====
# Orchestrator for the Data Factory
# Usage (from project root):
#   Rscript R/main.R --dataset marketing --config config/datasets/marketing.yml --out outputs/marketing --seed 123

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(glue)
  library(lubridate)
  library(dplyr)
})

source("R/utils/logger.R")
source("R/utils/io.R")
source("R/utils/validate.R")

# ---- CLI ----
option_list <- list(
  make_option(c("-d", "--dataset"), type = "character", default = "marketing",
              help = "Dataset key (e.g., marketing)", metavar = "character"),
  make_option(c("-c", "--config"), type = "character", default = "config/datasets/marketing.yml",
              help = "Path to YAML config", metavar = "character"),
  make_option(c("-o", "--out"), type = "character", default = "outputs/marketing",
              help = "Output directory", metavar = "character"),
  make_option(c("-s", "--seed"), type = "integer", default = NA,
              help = "Random seed (overrides YAML)", metavar = "integer")
)

opt <- parse_args(OptionParser(option_list = option_list))

cfg <- read_yaml_safe(opt$config)
if (!is.na(opt$seed)) cfg$seed <- opt$seed
if (!dir.exists(opt$out)) dir.create(opt$out, recursive = TRUE)

set.seed(as.integer(cfg$seed))
log_info(glue("Running Data Factory for dataset '{opt$dataset}' | seed={cfg$seed}"))

# ---- Dispatch to dataset builder ----
switch(opt$dataset,
       marketing = {
         source("R/modules/marketing/build_dataset.R")
         artifacts <- build_marketing_dataset(cfg, opt$out)
         log_info(glue("Wrote {length(artifacts)} tables to {opt$out}"))
       },
       stop(glue("Unknown dataset key: {opt$dataset}"))
)

# Optional: schema check summary
ok <- validate_marketing_schema(file.path(opt$out))
if (!ok) {
  log_warn("Schema validation reported issues. See warnings above.")
} else {
  log_success("Schema validation passed.")
}