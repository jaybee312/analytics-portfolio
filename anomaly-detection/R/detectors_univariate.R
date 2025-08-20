# R/detectors_univariate.R
suppressPackageStartupMessages({
  library(data.table)
  library(robustbase)
})

numify <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.integer(x)) return(as.numeric(x))
  suppressWarnings(as.numeric(x))
}

iqr_flags <- function(dt, numeric_cols, whisker_k = 1.5) {
  if (length(numeric_cols) == 0) return(data.table())
  out_list <- vector("list", length(numeric_cols))
  for (i in seq_along(numeric_cols)) {
    col <- numeric_cols[i]
    if (!col %in% names(dt)) next
    x <- numify(dt[[col]])
    if (all(is.na(x))) { out_list[[i]] <- data.table(); next }
    q1 <- as.numeric(quantile(x, 0.25, na.rm = TRUE))
    q3 <- as.numeric(quantile(x, 0.75, na.rm = TRUE))
    iqr <- q3 - q1
    if (!is.finite(iqr) || iqr == 0) { out_list[[i]] <- data.table(); next }
    lower <- q1 - whisker_k * iqr
    upper <- q3 + whisker_k * iqr
    idx <- which(!is.na(x) & (x < lower | x > upper))
    if (!length(idx)) { out_list[[i]] <- data.table(); next }
    dist <- ifelse(x[idx] < lower, (lower - x[idx]) / iqr, (x[idx] - upper) / iqr)
    score <- abs(dist)
    severity <- ifelse(score >= 2, "high",
                       ifelse(score >= 1, "medium", "low"))
    out_list[[i]] <- data.table(
      row_index = idx,
      detector  = "univariate.IQR",
      score     = round(score, 3),
      severity  = severity,
      columns   = col,
      notes     = sprintf("Q1=%.3f Q3=%.3f IQR=%.3f k=%.2f", q1, q3, iqr, whisker_k)
    )
  }
  rbindlist(out_list, use.names = TRUE, fill = TRUE)
}

mad_flags <- function(dt, numeric_cols, z_thresh = 3.5) {
  if (length(numeric_cols) == 0) return(data.table())
  out_list <- vector("list", length(numeric_cols))
  c_mad <- 1.4826
  for (i in seq_along(numeric_cols)) {
    col <- numeric_cols[i]
    if (!col %in% names(dt)) next
    x <- numify(dt[[col]])
    if (all(is.na(x))) { out_list[[i]] <- data.table(); next }
    med <- median(x, na.rm = TRUE)
    madv <- mad(x, constant = c_mad, na.rm = TRUE)
    if (!is.finite(madv) || madv == 0) { out_list[[i]] <- data.table(); next }
    rz <- abs(x - med) / madv
    idx <- which(!is.na(rz) & rz >= z_thresh)
    if (!length(idx)) { out_list[[i]] <- data.table(); next }
    severity <- ifelse(rz[idx] >= (z_thresh + 1), "high", "medium")
    out_list[[i]] <- data.table(
      row_index = idx,
      detector  = "univariate.MAD",
      score     = round(rz[idx], 3),
      severity  = severity,
      columns   = col,
      notes     = sprintf("median=%.3f MAD=%.3f z_thresh=%.2f", med, madv, z_thresh)
    )
  }
  rbindlist(out_list, use.names = TRUE, fill = TRUE)
}

apply_flag_caps <- function(flags_dt, n_rows, max_flagged_pct = NULL) {
  if (is.null(flags_dt) || !nrow(flags_dt)) return(flags_dt)
  if (is.null(max_flagged_pct) || !is.finite(max_flagged_pct) || max_flagged_pct <= 0) return(flags_dt)
  unique_rows <- unique(flags_dt$row_index)
  cap_n <- ceiling(n_rows * (max_flagged_pct / 100))
  if (length(unique_rows) <= cap_n) return(flags_dt)
  row_max <- flags_dt[, .(max_score = max(score, na.rm = TRUE)), by = row_index]
  setorder(row_max, -max_score)
  keep_rows <- row_max$row_index[seq_len(min(cap_n, nrow(row_max)))]
  flags_dt[row_index %in% keep_rows]
}
