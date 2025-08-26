context("Univariate detectors")

suppressPackageStartupMessages({
  library(data.table)
})

test_that("iqr_flags and mad_flags exist and flag simple spikes", {
  root <- project_root()
  sys.source(file.path(root, "R", "detectors_univariate.R"), envir = .GlobalEnv)

  expect_true(exists("iqr_flags"))
  expect_true(exists("mad_flags"))

  dt <- data.table(x = c(100, 120, 115, 118, 119, 900))  # clear spike
  iqr_res <- iqr_flags(dt, "x", whisker_k = 1.5)
  mad_res <- mad_flags(dt, "x", z_thresh = 3.0)

  expect_s3_class(iqr_res, "data.table")
  expect_s3_class(mad_res, "data.table")

  expect_true(nrow(iqr_res) >= 1)
  expect_true(nrow(mad_res) >= 1)
  expect_true(all(c("row_index","detector","score","severity","columns") %in% names(iqr_res)))
})
