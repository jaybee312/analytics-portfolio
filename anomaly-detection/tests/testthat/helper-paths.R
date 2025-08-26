# tests/testthat/helper-paths.R
# Loaded automatically by testthat. Provides project_root() for reliable paths.

project_root <- function() {
  # Walk up until we find the repo markers
  candidates <- c(
    ".", "..", "../..", "../../..", "../../../.."
  )
  for (p in candidates) {
    if (file.exists(file.path(p, "scripts", "run_odet.R")) &&
        file.exists(file.path(p, "R", "detectors_univariate.R"))) {
      return(normalizePath(p))
    }
  }
  stop("Could not locate project root containing scripts/run_odet.R and R/detectors_univariate.R")
}
