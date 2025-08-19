generate_marketing_data <- function(config) {
  set.seed(123)
  n <- config$rows
  personas <- config$personas
  cleanliness <- config$cleanliness

  base_data <- data.frame(
    customer_id = sprintf("CUST%05d", 1:n),
    signup_date = sample(seq.Date(as.Date("2023-01-01"), as.Date("2024-01-01"), by = "day"), n, replace = TRUE),
    persona = sample(personas, n, replace = TRUE),
    channel = sample(c("organic", "paid", "referral", "partner"), n, replace = TRUE),
    source_campaign_id = sample(c(NA, paste0("CAMP", 100:199)), n, replace = TRUE, prob = c(0.2, rep(0.8 / 100, 100))),
    plan_type = sample(c("Free", "Basic", "Pro", "Enterprise"), n, replace = TRUE, prob = c(0.2, 0.4, 0.3, 0.1)),
    is_trial = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.3, 0.7)),
    converted_to_paid = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.6, 0.4))
  )

  if (cleanliness == "messy") {
    base_data[sample(1:n, size = n * 0.1), "channel"] <- NA
    base_data[sample(1:n, size = n * 0.05), "plan_type"] <- "   PRO "
  } else if (cleanliness == "typical") {
    base_data[sample(1:n, size = n * 0.05), "channel"] <- NA
  }

  return(base_data)
}
