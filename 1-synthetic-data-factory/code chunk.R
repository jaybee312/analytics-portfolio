===== FILE: R/main.R =====
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

===== FILE: R/utils/logger.R =====
  log_time <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log_line <- function(level, msg) cat(sprintf("[%s] %-7s %s\n", log_time(), level, msg))
log_info    <- function(msg) log_line("INFO", msg)
log_warn    <- function(msg) log_line("WARN", msg)
log_error   <- function(msg) log_line("ERROR", msg)
log_success <- function(msg) log_line("SUCCESS", msg)

===== FILE: R/utils/io.R =====
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

===== FILE: R/utils/validate.R =====
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

===== FILE: R/modules/marketing/build_dataset.R =====
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

===== FILE: R/modules/marketing/customers.R =====
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(stringi)
  })

rand_names <- function(n) {
  first <- c("Alex","Sam","Jordan","Taylor","Casey","Jamie","Riley","Avery","Morgan","Quinn")
  last  <- c("Lee","Patel","Garcia","Kim","Nguyen","Smith","Brown","Davis","Lopez","Martinez")
  paste(sample(first, n, TRUE), sample(last, n, TRUE))
}

rand_country <- function(n, pool) sample(pool, n, TRUE)

rand_segment <- function(n, segments) sample(names(segments), n, TRUE, prob = unlist(segments))

rand_plan <- function(n, mix) sample(names(mix), n, TRUE, prob = unlist(mix))

# customers table => synthetic_data.v2.customers
gen_customers <- function(n_customers, start, end, countries, plan_mix, segments) {
  signup <- as.Date(sample(seq.Date(start, end, by = "day"), n_customers, TRUE))
  is_trial <- rbinom(n_customers, 1, 0.35) == 1
  is_active <- rbinom(n_customers, 1, 0.82) == 1
  tibble(
    customer_id = sprintf("C%06d", seq_len(n_customers)),
    customer_name = rand_names(n_customers),
    signup_date = signup,
    country = rand_country(n_customers, countries),
    segment = rand_segment(n_customers, segments),
    plan_type = rand_plan(n_customers, plan_mix),
    is_trial = is_trial,
    is_active = is_active
  )
}

===== FILE: R/modules/marketing/marketing_campaigns.R =====
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(glue)
  })

# marketing_campaigns => synthetic_data.v2.marketing_campaigns
# Some leads will have NA source_campaign_id per user requirement

seq_months <- function(start, end) seq(as.Date(floor_date(start, "month")), as.Date(floor_date(end, "month")), by = "1 month")

gen_marketing_campaigns <- function(channels, start, end, monthly_spend) {
  months <- seq_months(start, end)
  rows <- lapply(months, function(m) {
    lapply(names(channels), function(ch) {
      impressions <- as.integer(abs(rnorm(1, mean=channels[[ch]]$impressions, sd = channels[[ch]]$impressions*0.25)))
      ctr <- runif(1, channels[[ch]]$ctr_min, channels[[ch]]$ctr_max)
      clicks <- as.integer(impressions * ctr)
      tibble(
        campaign_id = glue("K{format(m, '%Y%m')}_{toupper(substr(ch,1,3))}"),
        channel = ch,
        source_campaign_id = ifelse(runif(1) < 0.15, NA_character_, glue("SRC{sample(1000:9999,1)}")),
        start_date = m,
        end_date = ceiling_date(m, "month") - days(1),
        spend = round(monthly_spend[[ch]] + rnorm(1, 0, monthly_spend[[ch]]*0.1), 2),
        impressions = impressions,
        clicks = clicks
      )
    }) |> bind_rows()
  }) |> bind_rows()
  rows
}

===== FILE: R/modules/marketing/sales_funnel.R =====
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
  })

# sales_funnel => synthetic_data.v2.sales_funnel
# Stages: lead -> mql -> sql -> opportunity -> won/lost

pick_stage_dates <- function(signup_date) {
  base <- signup_date - sample(0:30, 1) # leads can exist before signup
  lead <- base
  mql  <- lead + sample(0:10,1)
  sql  <- mql + sample(0:14,1)
  opp  <- sql + sample(0:21,1)
  won  <- opp + sample(0:14,1)
  c(lead, mql, sql, opp, won)
}

gen_sales_funnel <- function(customers, campaigns, p) {
  n <- nrow(customers)
  # Map each customer to a campaign (with some organic NAs)
  camp_ids <- sample(campaigns$campaign_id, n, TRUE)
  if (p$organic_share > 0) {
    organic_idx <- sample(seq_len(n), size = floor(n * p$organic_share))
    camp_ids[organic_idx] <- NA_character_
  }
  
  # Build rows
  out <- lapply(seq_len(n), function(i) {
    cs <- customers[i,]
    dates <- pick_stage_dates(cs$signup_date)
    stages <- c("lead","mql","sql","opportunity","won")
    is_won <- rbinom(1, 1, prob = p$win_rate[[as.character(cs$segment)]]) == 1
    if (!is_won) stages[length(stages)] <- "lost"
    tibble(
      lead_id = sprintf("L%07d", i),
      customer_id = cs$customer_id,
      campaign_id = camp_ids[i],
      stage = stages,
      stage_date = as.Date(dates),
      amount = ifelse(stage %in% c("opportunity","won"), round(runif(length(stages), 1000, 25000),2), 0),
      is_won = stage == "won"
    )
  }) |> bind_rows()
  out
}

===== FILE: R/modules/marketing/product_usage.R =====
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
  })

# product_usage => synthetic_data.v2.product_usage
# Vary usage by plan_type; include trial drop-off and free->paid upgrades

gen_product_usage <- function(customers, p) {
  rows <- lapply(seq_len(nrow(customers)), function(i){
    cs <- customers[i,]
    # active window
    start <- cs$signup_date
    end   <- min(as.Date(p$end_date), cs$signup_date + sample(60:360,1))
    dates <- seq.Date(start, end, by = "day")
    
    # baseline by plan
    base_minutes <- switch(as.character(cs$plan_type),
                           free = 5, basic = 15, pro = 35, enterprise = 50, 10)
    # trial decay
    decay <- if (cs$is_trial) exp(-seq_along(dates)/60) else 1
    
    tibble(
      customer_id = cs$customer_id,
      date = dates,
      active_minutes = round(pmax(0, rnorm(length(dates), base_minutes, base_minutes*0.5) * decay)),
      sessions = pmax(0L, as.integer(rpois(length(dates), lambda = base_minutes/10))),
      feature_flag = sample(c("core","advanced","beta"), length(dates), TRUE, prob = c(0.7,0.25,0.05))
    )
  }) |> bind_rows()
  
  # Simulate some upgrades from free->basic for organic users (simple proxy via feature_flag)
  free_ids <- customers$customer_id[customers$plan_type == "free"]
  upgrade <- sample(free_ids, size = floor(length(free_ids) * 0.12))
  # After ~45 days, more advanced features appear for upgraded cohort
  rows$feature_flag[rows$customer_id %in% upgrade & ave(rows$date, rows$customer_id, FUN = function(x) x - min(x)) > 45] <- "advanced"
  rows
}

===== FILE: R/modules/marketing/nps.R =====
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
  })

# nps_responses => synthetic_data.v2.nps
# 1–3 surveys per customer, score distribution varies by segment/plan

nps_by_segment <- function(seg) {
  switch(seg,
         solopreneur = rnorm(1, 7.2, 2.2),
         smb         = rnorm(1, 7.8, 1.9),
         enterprise  = rnorm(1, 8.1, 1.6),
         rnorm(1, 7.5, 2.0)
  )
}

gen_nps <- function(customers, p) {
  out <- lapply(seq_len(nrow(customers)), function(i){
    cs <- customers[i,]
    k <- sample(1:3, 1)
    dates <- sort(sample(seq(cs$signup_date + 30, as.Date(p$end_date), by = "day"), size = k, replace = TRUE))
    tibble(
      response_id = sprintf("R%08d_%d", i, seq_len(k)),
      customer_id = cs$customer_id,
      survey_date = dates,
      score = pmin(10L, pmax(0L, round(nps_by_segment(cs$segment)))),
      comment = NA_character_
    )
  }) |> bind_rows()
  out
}

===== FILE: config/datasets/marketing.yml =====
  # Master YAML driving the marketing dataset build
  seed: 123
marketing:
  start_date: "2023-01-01"
end_date:   "2024-12-31"

# population
n_customers: 3500
countries: ["US","CA","MX","GB","DE","BR","AU"]
segments: { solopreneur: 0.45, smb: 0.40, enterprise: 0.15 }
plan_mix: { free: 0.25, basic: 0.45, pro: 0.25, enterprise: 0.05 }

# channels config (impressions baseline + CTR bands)
channels:
  search:      { impressions: 900000,  ctr_min: 0.02, ctr_max: 0.06 }
paid_social: { impressions: 600000,  ctr_min: 0.01, ctr_max: 0.03 }
display:     { impressions: 450000,  ctr_min: 0.003, ctr_max: 0.01 }
email:       { impressions: 120000,  ctr_min: 0.06,  ctr_max: 0.12 }
affiliate:   { impressions: 220000,  ctr_min: 0.015, ctr_max: 0.04 }

monthly_spend:
  search: 120000
paid_social: 80000
display: 30000
email: 15000
affiliate: 25000

# funnel / conversions
organic_share: 0.20   # fraction of customers with no campaign attribution
win_rate: { solopreneur: 0.18, smb: 0.24, enterprise: 0.31 }

===== FILE: tests/test_marketing.R =====
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

===== FILE: scripts/run_local.R =====
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

===== FILE: Makefile =====
  # Quick make targets for local dev
  .PHONY: run clean test
run:
  \tRscript R/main.R --dataset marketing --config config/datasets/marketing.yml --out outputs/marketing --seed 123

clean:
  \trm -rf outputs/marketing

test:
  \tR -e "tinytest::test_all('tests')"
