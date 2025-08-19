suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

# product_usage => synthetic_data.v2.product_usage
# Vary usage by plan_type; include trial drop-off and free->paid upgrades

gen_product_usage <- function(customers, p) {
  # 1) Per-customer daily usage rows
  rows <- lapply(seq_len(nrow(customers)), function(i){
    cs <- customers[i,]
    start <- cs$signup_date
    end   <- min(as.Date(p$end_date), cs$signup_date + sample(60:360,1))
    dates <- seq.Date(start, end, by = "day")

    base_minutes <- switch(as.character(cs$plan_type),
      free = 5, basic = 15, pro = 35, enterprise = 50, 10)

    decay <- if (isTRUE(cs$is_trial)) exp(-seq_along(dates)/60) else 1

    tibble(
      customer_id    = cs$customer_id,
      date           = as.Date(dates),
      active_minutes = round(pmax(0, rnorm(length(dates), base_minutes, base_minutes*0.5) * decay)),
      sessions       = pmax(0L, as.integer(rpois(length(dates), lambda = base_minutes/10))),
      feature_flag   = sample(c("core","advanced","beta"), length(dates), TRUE, prob = c(0.7,0.25,0.05))
    )
  }) |> bind_rows()

  # 2) Days since each customer's first usage date
  rows <- rows |>
    group_by(customer_id) |>
    arrange(date, .by_group = TRUE) |>
    mutate(days_since_signup = as.integer(difftime(date, first(date), units = "days"))) |>
    ungroup()

  # 3) Simulate upgrades among FREE users -> more "advanced" after ~45 days
  free_ids <- customers$customer_id[customers$plan_type == "free"]
  upgrade  <- if (length(free_ids)) sample(free_ids, size = floor(length(free_ids) * 0.12)) else character(0)

  rows <- rows |>
    mutate(
      feature_flag = if_else(
        customer_id %in% upgrade & days_since_signup > 45,
        "advanced",
        feature_flag
      )
    ) |>
    select(-days_since_signup)

  rows
}
