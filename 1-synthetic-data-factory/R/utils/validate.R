#===== FILE: R/utils/validate.R =====
  suppressPackageStartupMessages({
    library(dplyr)
    library(rlang)
  })

# Minimal schema checks for marketing dataset
validate_marketing_schema <- function(out_dir) {
  ok <- TRUE
  required <- list(
    customers = c("customer_id","customer_name","signup_date","country","segment","plan_type","is_trial","is_active"),
    marketing_campaigns = c("campaign_id","channel","source_campaign_id","start_date","end_date","spend","impressions","clicks"),
    sales_funnel = c("lead_id","customer_id","campaign_id","stage","stage_date","amount","is_won"),
    product_usage = c("customer_id","date","active_minutes","sessions","feature_flag"),
    nps_responses = c("response_id","customer_id","survey_date","score","comment")
  )
  for (tbl in names(required)) {
    f <- file.path(out_dir, paste0(tbl, ".csv"))
    if (!file.exists(f)) { warning(sprintf("Missing table: %s", f)); ok <- FALSE; next }
    cols <- names(read.csv(f, nrows = 1, check.names = FALSE))
    missing <- setdiff(required[[tbl]], cols)
    if (length(missing)) { warning(sprintf("%s is missing columns: %s", tbl, paste(missing, collapse = ", "))); ok <- FALSE }
  }
  ok
}