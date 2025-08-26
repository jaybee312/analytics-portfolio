suppressPackageStartupMessages({ library(data.table) })
set.seed(42)

mk_customers <- function(in_path, out_path) {
  if (!file.exists(in_path)) stop("Missing: ", in_path)
  dt <- fread(in_path)

  # Ensure numeric
  numify <- function(x) { if (is.numeric(x)) x else suppressWarnings(as.numeric(x)) }
  if ("monthly_spend" %in% names(dt)) dt[, monthly_spend := numify(monthly_spend)]
  if ("visits_30d"    %in% names(dt)) dt[, visits_30d    := numify(visits_30d)]

  n <- nrow(dt)
  if (n >= 40) {
    # Inject high spend spikes
    idx_hi <- sample(seq_len(n), size = ceiling(0.05*n))
    dt[idx_hi, monthly_spend := monthly_spend * runif(length(idx_hi), 2.5, 4.0)]

    # Inject low spend dips
    idx_lo <- setdiff(sample(seq_len(n), size = ceiling(0.03*n)), idx_hi)
    dt[idx_lo, monthly_spend := pmax(0, monthly_spend * runif(length(idx_lo), 0.1, 0.4))]

    # Visits extremes
    idx_v_hi <- sample(setdiff(seq_len(n), c(idx_hi, idx_lo)), size = ceiling(0.04*n))
    dt[idx_v_hi, visits_30d := visits_30d + sample(10:25, length(idx_v_hi), replace=TRUE)]
    idx_v_lo <- sample(setdiff(seq_len(n), c(idx_hi, idx_lo, idx_v_hi)), size = ceiling(0.03*n))
    dt[idx_v_lo, visits_30d := pmax(0, visits_30d - sample(5:10, length(idx_v_lo), replace=TRUE))]
  } else {
    # Tiny dataset fallback: add a few explicit anomalies
    dt[1, monthly_spend := monthly_spend * 5]
    if (n >= 2) dt[2, visits_30d := visits_30d + 20]
    if (n >= 3) dt[3, monthly_spend := monthly_spend * 0.2]
  }

  fwrite(dt, out_path)
  cat("Wrote:", out_path, "\n")
}

mk_web <- function(in_path, out_path) {
  if (!file.exists(in_path)) stop("Missing: ", in_path)
  dt <- fread(in_path)
  numify <- function(x) { if (is.numeric(x)) x else suppressWarnings(as.numeric(x)) }
  if ("sessions"    %in% names(dt)) dt[, sessions    := numify(sessions)]
  if ("bounce_rate" %in% names(dt)) dt[, bounce_rate := pmin(1, pmax(0, numify(bounce_rate)))]

  n <- nrow(dt)
  if (n >= 40) {
    # Sessions spikes and crashes
    idx_hi <- sample(seq_len(n), size = ceiling(0.05*n))
    dt[idx_hi, sessions := sessions * runif(length(idx_hi), 2.5, 5.0)]
    idx_lo <- setdiff(sample(seq_len(n), size = ceiling(0.04*n)), idx_hi)
    dt[idx_lo, sessions := pmax(5, sessions * runif(length(idx_lo), 0.05, 0.3))]

    # Bounce rate extremes
    idx_br_hi <- sample(setdiff(seq_len(n), c(idx_hi, idx_lo)), size = ceiling(0.04*n))
    dt[idx_br_hi, bounce_rate := pmin(1, bounce_rate + runif(length(idx_br_hi), 0.35, 0.55))]
    idx_br_lo <- sample(setdiff(seq_len(n), c(idx_hi, idx_lo, idx_br_hi)), size = ceiling(0.04*n))
    dt[idx_br_lo, bounce_rate := pmax(0, bounce_rate - runif(length(idx_br_lo), 0.25, 0.45))]
  } else {
    # Tiny dataset fallback
    dt[1, sessions := sessions * 4]
    if (n >= 2) dt[2, sessions := sessions * 0.2]
    if (n >= 3) dt[3, bounce_rate := pmin(1, bounce_rate + 0.5)]
  }

  fwrite(dt, out_path)
  cat("Wrote:", out_path, "\n")
}

# Paths
in_cust <- "data/customers_aug.csv"
in_web  <- "data/web_traffic.csv"
out_cust <- "data/customers_spiky.csv"
out_web  <- "data/web_traffic_spiky.csv"

if (file.exists(in_cust)) mk_customers(in_cust, out_cust) else cat("Skip: ", in_cust, " not found\n")
if (file.exists(in_web))  mk_web(in_web, out_web)        else cat("Skip: ", in_web,  " not found\n")
