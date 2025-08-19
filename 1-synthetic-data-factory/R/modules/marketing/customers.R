#===== FILE: R/modules/marketing/customers.R =====
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

