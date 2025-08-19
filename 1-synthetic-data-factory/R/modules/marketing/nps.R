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
  end_all <- as.Date(p$end_date)

  out <- lapply(seq_len(nrow(customers)), function(i){
    cs <- customers[i,]
    start_i <- cs$signup_date + 30
    end_i   <- end_all

    # If the window is invalid (start after end), skip NPS for this customer
    if (is.na(start_i) || is.na(end_i) || start_i > end_i) {
      return(tibble(
        response_id = character(0),
        customer_id = character(0),
        survey_date = as.Date(character(0)),
        score = integer(0),
        comment = character(0)
      ))
    }

    k <- sample(1:3, 1)
    # Build the candidate date sequence safely
    cand <- seq.Date(from = start_i, to = end_i, by = "day")
    # Just in case (shouldn’t happen after the guard)
    if (length(cand) == 0) {
      return(tibble(
        response_id = character(0),
        customer_id = character(0),
        survey_date = as.Date(character(0)),
        score = integer(0),
        comment = character(0)
      ))
    }

    dates <- sort(sample(cand, size = k, replace = TRUE))

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
