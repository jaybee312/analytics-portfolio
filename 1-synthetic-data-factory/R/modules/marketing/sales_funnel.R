
#===== FILE: R/modules/marketing/sales_funnel.R =====
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