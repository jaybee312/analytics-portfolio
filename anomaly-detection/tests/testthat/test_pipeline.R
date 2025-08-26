context("Pipeline – fixtures e2e")

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

test_that("run_odet produces expected artifacts and non-empty outliers", {
  root <- project_root()
  cfg_path <- file.path(root, "configs", "sample_tests.yml")
  expect_true(file.exists(cfg_path))

  # Run the real runner via Rscript at the project root
  cmd <- sprintf('cd "%s" && Rscript scripts/run_odet.R --config %s', root, cfg_path)
  status <- system(cmd, intern = FALSE, ignore.stdout = TRUE, ignore.stderr = TRUE)
  expect_equal(status, 0L)

  # Validate artifacts for customers_small
  out_cust_csv <- file.path(root, "reports", "customers_small", "outliers.csv")
  diag_cust_js <- file.path(root, "reports", "customers_small", "diagnostics.json")
  expect_true(file.exists(out_cust_csv))
  expect_true(file.exists(diag_cust_js))
  out_cust <- data.table::fread(out_cust_csv)
  diag_cust <- jsonlite::fromJSON(diag_cust_js)
  expect_s3_class(out_cust, "data.table")
  expect_true(nrow(out_cust) >= 1)
  expect_true(!is.null(diag_cust$detectors))
  expect_true(!is.null(diag_cust$columns))

  # Validate artifacts for web_traffic_small
  out_web_csv <- file.path(root, "reports", "web_traffic_small", "outliers.csv")
  diag_web_js <- file.path(root, "reports", "web_traffic_small", "diagnostics.json")
  expect_true(file.exists(out_web_csv))
  expect_true(file.exists(diag_web_js))
  out_web <- data.table::fread(out_web_csv)
  diag_web <- jsonlite::fromJSON(diag_web_js)
  expect_s3_class(out_web, "data.table")
  expect_true(nrow(out_web) >= 1)
  expect_true(!is.null(diag_web$detectors))
  expect_true(!is.null(diag_web$columns))
})
