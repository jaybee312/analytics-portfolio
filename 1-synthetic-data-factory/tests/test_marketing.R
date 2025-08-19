#===== FILE: tests/test_marketing.R =====
  # tinytest-based smoke tests (run: tinytest::test_all('tests'))
  if (interactive()) library(tinytest)

source("R/utils/validate.R")

# Basic check: required files exist after a build
run_smoke <- function() {
  out <- "outputs/marketing"
  files <- c("customers.csv","marketing_campaigns.csv","sales_funnel.csv","product_usage.csv","nps_responses.csv")
  all(file.exists(file.path(out, files)))
}

if (sys.nframe() == 0) {
  ok <- run_smoke()
  if (!ok) stop("Smoke test failed: expected outputs missing")
}