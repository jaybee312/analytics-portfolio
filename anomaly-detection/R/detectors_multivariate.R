# R/detectors_multivariate.R
# Multivariate outlier detectors: Isolation Forest (isotree) and LOF (dbscan)

suppressPackageStartupMessages({
  library(data.table)
  library(isotree)
  library(dbscan)
})

# --- helpers -----------------------------------------------------------------
# Select numeric matrix from data.table by column names
.as_numeric_matrix <- function(dt, cols) {
  if (is.null(cols) || !length(cols)) return(NULL)
  cols <- cols[cols %in% names(dt)]
  if (!length(cols)) return(NULL)
  m <- as.data.frame(dt[, ..cols])
  # Coerce non-numeric to numeric where possible
  for (j in seq_along(m)) {
    if (!is.numeric(m[[j]])) {
      suppressWarnings(m[[j]] <- as.numeric(m[[j]]))
    }
  }
  m <- as.matrix(m)
  # Drop cols that are all-NA after coercion
  keep <- which(colSums(!is.na(m)) > 0)
  if (!length(keep)) return(NULL)
  m[, keep, drop = FALSE]
}

# --- Isolation Forest ---------------------------------------------------------
# Params:
# - contamination: target fraction (0-0.5). If NULL, use quantile on scores.
# - ntrees, sample_size: isotree training params
if_isolation_forest <- function(dt, numeric_cols,
                                contamination = 0.02,
                                ntrees = 200,
                                sample_size = 256,
                                random_seed = 42L) {
  X <- .as_numeric_matrix(dt, numeric_cols)
  if (is.null(X)) return(data.table())
  
  set.seed(as.integer(random_seed))
  model <- isotree::isolation.forest(
    X,
    ntrees = ntrees,
    sample_size = sample_size,
    nthreads = 1
  )
  # higher score = more anomalous
  scores <- isotree::predict.isolation_forest(model, X, type = "score")
  if (!is.numeric(scores)) return(data.table())
  
  # Decide threshold
  if (is.null(contamination) || !is.finite(contamination) || contamination <= 0) {
    thr <- stats::quantile(scores, 0.98, na.rm = TRUE) # conservative default
  } else {
    thr <- stats::quantile(scores, 1 - contamination, na.rm = TRUE)
  }
  idx <- which(scores >= thr)
  if (!length(idx)) return(data.table())
  
  # Severity buckets (rough heuristics)
  q_hi <- stats::quantile(scores, probs = c(0.99, 0.95), na.rm = TRUE)
  sev <- ifelse(scores[idx] >= q_hi[[1]], "high",
                ifelse(scores[idx] >= q_hi[[2]], "medium", "low"))
  
  data.table(
    row_index = idx,
    detector  = "multivariate.IF",
    score     = round(scores[idx], 6),
    severity  = sev,
    columns   = paste(numeric_cols, collapse = ","),
    notes     = sprintf("ntrees=%d sample_size=%d thr=%.6f", ntrees, sample_size, thr)
  )
}

# --- LOF (Local Outlier Factor) ----------------------------------------------
# Uses dbscan::lof; higher score = more outlying (≈ >1.5 often interesting)
lof_flags <- function(dt, numeric_cols, minPts = 10) {
  X <- .as_numeric_matrix(dt, numeric_cols)
  if (is.null(X)) return(data.table())
  
  # dbscan::lof expects matrix without NA
  # Simple NA handling: complete cases only (MVP)
  cc <- stats::complete.cases(X)
  if (!any(cc)) return(data.table())
  Xc <- X[cc, , drop = FALSE]
  lofv <- dbscan::lof(Xc, minPts = minPts)
  
  # Map back to original row indices
  idx_all <- which(cc)
  # Threshold via quantiles; keep top 2% by default (guarded by max_flagged_pct later)
  thr <- stats::quantile(lofv, 0.98, na.rm = TRUE)
  keep <- which(lofv >= thr)
  if (!length(keep)) return(data.table())
  
  scores <- lofv[keep]
  r_idx  <- idx_all[keep]
  sev <- ifelse(scores >= stats::quantile(lofv, 0.995, na.rm = TRUE), "high",
                ifelse(scores >= stats::quantile(lofv, 0.99,  na.rm = TRUE), "medium", "low"))
  
  data.table(
    row_index = r_idx,
    detector  = "multivariate.LOF",
    score     = round(scores, 6),
    severity  = sev,
    columns   = paste(numeric_cols, collapse = ","),
    notes     = sprintf("minPts=%d thr=%.6f", minPts, thr)
  )
}
