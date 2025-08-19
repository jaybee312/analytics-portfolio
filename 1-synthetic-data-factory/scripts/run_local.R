#===== FILE: scripts/run_local.R =====
  # Convenience runner for RStudio
  suppressPackageStartupMessages(library(here))

proj <- here::here()
cmd  <- sprintf("Rscript %s -d marketing -c %s -o %s -s %d",
                file.path(proj, "R/main.R"),
                file.path(proj, "config/datasets/marketing.yml"),
                file.path(proj, "outputs/marketing"),
                123)
message("Running: ", cmd)
status <- system(cmd)
if (status != 0) stop("Data Factory run failed")