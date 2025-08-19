
#===== FILE: R/utils/io.R =====
  suppressPackageStartupMessages({
    library(yaml)
    library(readr)
  })

read_yaml_safe <- function(path) {
  if (!file.exists(path)) stop(sprintf("YAML not found: %s", path))
  yaml::read_yaml(path)
}

write_csv_safe <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(df, path)
}