suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(purrr)
  library(stringi)
  library(readr)
  library(ggplot2)
  library(charlatan)
})

set.seed(312)

# ---- Parameters ----
start_date <- as.Date("2024-01-01")
end_date   <- as.Date("2024-12-31")
channels   <- c("search","social","display","email","affiliate","direct","referral","organic")
platforms  <- c("web","ios","android")

# ---- Users ----
n_users <- 15000
ch <- charlatan::ch_name()
users <- tibble(
  user_id = sprintf("U%06d", 1:n_users),
  name = replicate(n_users, ch()),
  email = paste0(stri_trans_totitle(stri_replace_all_regex(name, "[^A-Za-z]", "")),
                 sample(1000:9999, n_users, TRUE), "@example.com"),
  signup_date = sample(seq(start_date - 200, start_date + 60, by = "day"), n_users, TRUE),
  platform = sample(platforms, n_users, TRUE, prob = c(0.55,0.25,0.20)),
  geo = sample(c("US","CA","UK","DE","AU","IN"), n_users, TRUE, prob = c(0.55,0.07,0.1,0.08,0.1,0.1))
)

# ---- Daily base series with trend + seasonality ----
dates <- seq(from = start_date, to = end_date, by = "day")
n <- length(dates)
dow <- wday(dates, label = TRUE, week_start = 1)
weekly_season <- case_when(
  dow %in% c("Sat","Sun") ~ 1.15,
  dow %in% c("Mon","Tue","Wed","Thu","Fri") ~ 0.95
)
trend <- seq(0.95, 1.15, length.out = n)
promo_days <- as.Date(c("2024-03-15","2024-05-10","2024-08-23","2024-11-29","2024-12-26"))
promo_lift <- if_else(dates %in% promo_days, 1.5, 1.0)
noise <- rnorm(n, 1, 0.05)

base_factor <- pmax(0.1, weekly_season * trend * promo_lift * noise)

# ---- Daily channel spend ----
spend_mix <- c(search=.35, social=.25, display=.15, email=.08, affiliate=.07, direct=.05, referral=.03, organic=.02)
daily_spend <- tibble(date = rep(dates, each = length(channels)),
                      channel = rep(channels, times = n)) %>%
  group_by(date) %>%
  mutate(total = 5000 * base_factor[match(date, dates)],
         spend = total * spend_mix[channel] * rlnorm(n(), 0, 0.15)) %>%
  ungroup() %>%
  select(-total) %>%
  mutate(spend = round(spend, 2))

# ---- Sessions (stochastic, driven by spend + seasonality) ----
sessions <- daily_spend %>%
  mutate(base_ctr = case_when(
           channel %in% c("search","email") ~ 0.08,
           channel %in% c("social","display") ~ 0.04,
           TRUE ~ 0.03),
         lambda = pmax(1, (spend/2) * base_ctr),
         sessions = rpois(n(), lambda)) %>%
  select(date, channel, sessions, spend)

# ---- Conversions (binomial with variation by channel + promo) ----
conv_rate <- c(search=.045, social=.03, display=.015, email=.055, affiliate=.035, direct=.05, referral=.025, organic=.04)
conversions <- sessions %>%
  left_join(tibble(channel = names(conv_rate), cr = as.numeric(conv_rate)), by="channel") %>%
  mutate(promo = if_else(date %in% promo_days, 1.25, 1.0),
         cr_eff = pmin(0.9, cr * promo * rlnorm(n(), 0, 0.1)),
         conversions = rbinom(n(), size = pmax(0, sessions), prob = pmin(cr_eff, 0.8))) %>%
  mutate(aov = case_when(
           channel %in% c("email","direct") ~ rnorm(n(), 85, 18),
           channel %in% c("search","organic") ~ rnorm(n(), 95, 22),
           TRUE ~ rnorm(n(), 78, 20)),
         revenue = round(pmax(0, conversions * aov), 2)) %>%
  select(date, channel, sessions, conversions, spend, revenue)

# ---- Transaction table (synthetic, user-linked) ----
tx_per_day <- conversions %>%
  group_by(date) %>%
  summarise(conversions = sum(conversions), .groups="drop")

# allocate users per day
alloc_users <- users %>%
  filter(signup_date <= end_date) %>%
  slice_sample(n = sum(tx_per_day$conversions), replace = TRUE) %>%
  mutate(key = row_number())

tx <- conversions %>%
  filter(conversions > 0) %>%
  rowwise() %>%
  mutate(user_ids = list(sample(alloc_users$user_id, conversions, replace = TRUE)),
         amounts = round(rlnorm(conversions, log(85), 0.25), 2)) %>%
  ungroup() %>%
  select(date, channel, user_ids, amounts) %>%
  unnest(c(user_ids, amounts)) %>%
  mutate(transaction_id = paste0("T", as.integer(runif(n(), 1e6, 9e6)))) %>%
  relocate(transaction_id)

# ---- Save CSVs ----
dir.create("synthetic-data-factory/data", showWarnings = FALSE, recursive = TRUE)
write_csv(users, "synthetic-data-factory/data/users.csv")
write_csv(daily_spend, "synthetic-data-factory/data/channel_spend_daily.csv")
write_csv(conversions, "synthetic-data-factory/data/channel_kpis_daily.csv")
write_csv(tx, "synthetic-data-factory/data/transactions.csv")

# ---- Quick plot to validate shape ----
dir.create("synthetic-data-factory/outputs", showWarnings = FALSE, recursive = TRUE)
p <- conversions %>%
  group_by(date) %>%
  summarise(revenue = sum(revenue), .groups="drop") %>%
  ggplot(aes(date, revenue)) + geom_line() +
  labs(title="Daily Revenue (Synthetic)", x=NULL, y="Revenue")
ggsave("synthetic-data-factory/outputs/revenue_timeseries.png", p, width=8, height=4, dpi=150)

message("Synthetic datasets written to synthetic-data-factory/data/*.csv")
