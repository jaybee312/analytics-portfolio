#===== FILE: R/modules/marketing/marketing_campaigns.R =====
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