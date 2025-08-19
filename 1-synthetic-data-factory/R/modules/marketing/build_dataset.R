#===== FILE: R/modules/marketing/build_dataset.R =====
suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
})

source("R/modules/marketing/customers.R")
source("R/modules/marketing/marketing_campaigns.R")
source("R/modules/marketing/sales_funnel.R")
source("R/modules/marketing/product_usage.R")
source("R/modules/marketing/nps.R")
source("R/utils/io.R")
source("R/utils/logger.R")

build_marketing_dataset <- function(cfg, out_dir) {
  p <- cfg$marketing
  # 1) Customers
  customers <- gen_customers(
    n_customers = p$n_customers,
    start = as.Date(p$start_date),
    end   = as.Date(p$end_date),
    countries = p$countries,
    plan_mix = p$plan_mix,
    segments = p$segments
  )
  write_csv_safe(customers, file.path(out_dir, "customers.csv"))
  log_info(glue("customers: {nrow(customers)}"))
  
  # 2) Campaigns
  campaigns <- gen_marketing_campaigns(
    channels = p$channels,
    start = as.Date(p$start_date),
    end   = as.Date(p$end_date),
    monthly_spend = p$monthly_spend
  )
  write_csv_safe(campaigns, file.path(out_dir, "marketing_campaigns.csv"))
  log_info(glue("marketing_campaigns: {nrow(campaigns)}"))
  
  # 3) Sales Funnel
  funnel <- gen_sales_funnel(customers, campaigns, p)
  write_csv_safe(funnel, file.path(out_dir, "sales_funnel.csv"))
  log_info(glue("sales_funnel: {nrow(funnel)}"))
  
  # 4) Product Usage
  usage <- gen_product_usage(customers, p)
  write_csv_safe(usage, file.path(out_dir, "product_usage.csv"))
  log_info(glue("product_usage: {nrow(usage)}"))
  
  # 5) NPS
  nps <- gen_nps(customers, p)
  write_csv_safe(nps, file.path(out_dir, "nps_responses.csv"))
  log_info(glue("nps_responses: {nrow(nps)}"))
  
  invisible(list(
    customers = file.path(out_dir, "customers.csv"),
    marketing_campaigns = file.path(out_dir, "marketing_campaigns.csv"),
    sales_funnel = file.path(out_dir, "sales_funnel.csv"),
    product_usage = file.path(out_dir, "product_usage.csv"),
    nps_responses = file.path(out_dir, "nps_responses.csv")
  ))
}