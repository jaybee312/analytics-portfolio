#!/usr/bin/env Rscript
# scripts/run_tests.R — JUnit XML + text logs + session info (uses absolute paths)

suppressPackageStartupMessages({
  if (!requireNamespace("testthat", quietly = TRUE)) {
    install.packages("testthat", repos = "https://cran.r-project.org")
  }
  if (!requireNamespace("xml2", quietly = TRUE)) {
    install.packages("xml2", repos = "https://cran.r-project.org")
  }
  if (!requireNamespace("cli", quietly = TRUE)) {
    install.packages("cli", repos = "https://cran.r-project.org")
  }
  library(testthat)
})

# Resolve project root as the directory containing this script (fallback: getwd)
script_path <- tryCatch(normalizePath(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))), error = function(e) NA)
proj_root   <- if (!is.na(script_path)) dirname(script_path) else normalizePath(getwd())
# If scripts/ is under proj_root, go one up
if (basename(proj_root) == "scripts") proj_root <- dirname(proj_root)

# Absolute paths for outputs
reports_dir <- file.path(proj_root, "tests", "reports")
dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(reports_dir, "test-summary.txt")
junit_path   <- file.path(reports_dir, "junit.xml")
sessinfo_path<- file.path(reports_dir, "session-info.txt")

# 1) Plain-text summary
sink(summary_path, split = TRUE)
cat("Running unit tests in tests/testthat ...\n")
res <- testthat::test_dir(file.path(proj_root, "tests", "testthat"), reporter = "summary")
sink()

# 2) JUnit XML (absolute path so cwd changes don't matter)
junit_rep <- JunitReporter$new(file = junit_path)
testthat::test_dir(file.path(proj_root, "tests", "testthat"), reporter = junit_rep)

# 3) Session info + versions
con <- file(sessinfo_path, open = "wt")
sink(con); sink(con, type = "message")
cat("===== R SESSION INFO =====\n"); print(sessionInfo())
cat("\n===== INSTALLED VERSIONS (key pkgs) =====\n")
pkgs <- c("data.table","yaml","jsonlite","isotree","dbscan","anomalize","tsoutliers","tsibble","fable","fabletools","rmarkdown","ggplot2","testthat")
for (p in pkgs) {
  ver <- tryCatch(as.character(packageVersion(p)), error = function(e) "NOT INSTALLED")
  cat(sprintf("%-15s %s\n", p, ver))
}
sink(type = "message"); sink(); close(con)

# 4) Exit code based on failures
n_fail <- sum(vapply(res, function(x) length(x$failed), integer(1)))
if (n_fail > 0) {
  cat("Tests FAILED. See artifacts:\n  -", summary_path, "\n  -", junit_path, "\n  -", sessinfo_path, "\n")
  quit(status = 1)
} else {
  cat("All tests passed. Artifacts:\n  -", summary_path, "\n  -", junit_path, "\n  -", sessinfo_path, "\n")
  quit(status = 0)
}
