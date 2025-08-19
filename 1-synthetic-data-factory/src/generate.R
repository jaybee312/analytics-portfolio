# File: src/generate.R

library(tidyverse)
library(lubridate)
library(glue)
library(yaml)

# Load config
config_path <- "configs/config.yaml"
if (!file.exists(config_path)) {
  stop(glue("❌ Config file not found at {config_path}"))
}

config <- yaml::read_yaml(config_path)

# Validate required fields
if (is.null(config$num_rows) || is.null(config$output_path)) {
  stop("❌ 'num_rows' and 'output_path' must be defined in config.yaml")
}

# Set seed
set.seed(config$seed %||% 42)

# Parameters
n <- config$num_rows
output_path <- config$output_path
dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)

# Generate synthetic data
generate_customers <- function(n) {
  customer_id <- sprintf("U%06d", 1:n)
  segment <- sample(c("Solopreneur", "SMB", "Enterprise"),
                    size = n,
                    replace = TRUE,
                    prob = c(0.5, 0.4, 0.1))
  age <- round(rnorm(n, mean = 35, sd = 10))
  signup_date <- sample(seq(as.Date("2022-01-01"), as.Date("2024-12-31"), by = "day"), size = n, replace = TRUE)
  orders_90d <- pmax(rpois(n, lambda = 2), 0)
  
  aov <- case_when(
    segment == "Solopreneur" ~ rnorm(n, mean = 30, sd = 5),
    segment == "SMB" ~ rnorm(n, mean = 100, sd = 20),
    segment == "Enterprise" ~ rnorm(n, mean = 300, sd = 75)
  )
  
  revenue_90d <- round(aov * orders_90d + rnorm(n, 0, 10), 2)
  
  tibble(
    customer_id,
    segment,
    age,
    signup_date,
    orders_90d,
    revenue_90d
  )
}

# Generate and write data
customers <- generate_customers(n)
write_csv(customers, output_path)

message(glue("✅ Generated {n} synthetic customers to {output_path}"))
