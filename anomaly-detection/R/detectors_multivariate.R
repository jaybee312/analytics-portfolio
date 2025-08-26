# R/detectors_multivariate.R
# Multivariate detectors + threshold helpers (Isolation Forest, LOF)

suppressPackageStartupMessages({
  library(data.table)
})

# ---- Isolation Forest flags ---------------------------------------------------
# Returns: data.table(row_index, detector, score, severity, columns, notes)
if_isolation_forest <- function(dt, numeric_cols,
                                contamination = 0.02,
                                ntrees = 200,
                                sample_size = 256,
                                random_seed = 42L) {
  ok <- requireNamespace("isotree", quietly = TRUE)
  if (!ok || length(numeric_cols) == 0) return(data.table())
  
  X <- as.data.frame(dt[, ..numeric_cols])
  for (j in seq_along(X)) if (!is.numeric(X[[j]])) suppressWarnings(X[[j]] <- as.numeric(X[[j]]))
  X <- as.matrix(X)
  if (!ncol(X)) return(data.table())
  
  n <- nrow(X)
  sample_size <- min(sample_size, n)  # cap to avoid warnings
  
  set.seed(as.integer(random_seed))
  model <- suppressWarnings(
    isotree::isolation.forest(X, ntrees = ntrees, sample_size = sample_size, nthreads = 1)
  )
  scores <- suppressWarnings(
    isotree::predict.isolation_forest(model, X, type = "score")
  )
  if (!is.numeric(scores)) return(data.table())
  
  thr <- if (is.null(contamination) || !is.finite(contamination) || contamination <= 0) {
    stats::quantile(scores, 0.98, na.rm = TRUE)
  } else {
    stats::quantile(scores, 1 - contamination, na.rm = TRUE)
  }
  idx <- which(scores >= thr)
  if (!length(idx)) return(data.table())
  
  severity <- ifelse(scores[idx] >= (thr + 0.1 * abs(thr)), "high", "medium")
  data.table(
    row_index = idx,
    detector  = "multivariate.IF",
    score     = round(scores[idx], 5),
    severity  = severity,
    columns   = paste(numeric_cols, collapse = ","),
    notes     = sprintf("thr=%.5f contamination=%s ntrees=%d sample=%d", thr, as.character(contamination), ntrees, sample_size)
  )
}

# ---- LOF flags ----------------------------------------------------------------
# Returns: data.table(row_index, detector, score, severity, columns, notes)
lof_flags <- function(dt, numeric_cols, minPts = 10) {
  ok <- requireNamespace("dbscan", quietly = TRUE)
  if (!ok || length(numeric_cols) == 0) return(data.table())
  
  X <- as.data.frame(dt[, ..numeric_cols])
  for (j in seq_along(X)) if (!is.numeric(X[[j]])) suppressWarnings(X[[j]] <- as.numeric(X[[j]]))
  X <- as.matrix(X)
  if (!ncol(X)) return(data.table())
  
  cc <- stats::complete.cases(X)
  if (!any(cc)) return(data.table())
  
  lofv <- suppressWarnings(dbscan::lof(X[cc,, drop = FALSE], minPts = minPts))
  thr <- stats::quantile(lofv, 0.98, na.rm = TRUE)
  idx_cc <- which(lofv >= thr)
  if (!length(idx_cc)) return(data.table())
  idx <- which(cc)[idx_cc]
  
  severity <- ifelse(lofv[idx_cc] >= (thr + 0.25), "high", "medium")
  data.table(
    row_index = idx,
    detector  = "multivariate.LOF",
    score     = round(lofv[idx_cc], 5),
    severity  = severity,
    columns   = paste(numeric_cols, collapse = ","),
    notes     = sprintf("thr=%.5f minPts=%d", thr, minPts)
  )
}

# ---- Threshold helpers (used by reporting/run_odet) ---------------------------
# Compute IF score threshold so we can record it in diagnostics.json
compute_if_threshold <- function(dt, numeric_cols, contamination = 0.02, ntrees = 200, sample_size = 256, random_seed = 42L) {
  ok <- requireNamespace("isotree", quietly = TRUE)
  if (!ok || length(numeric_cols) == 0) return(NULL)
  X <- as.data.frame(dt[, ..numeric_cols])
  for (j in seq_along(X)) if (!is.numeric(X[[j]])) suppressWarnings(X[[j]] <- as.numeric(X[[j]]))
  X <- as.matrix(X)
  if (!ncol(X)) return(NULL)
  n <- nrow(X); sample_size <- min(sample_size, n)
  set.seed(as.integer(random_seed))
  model <- suppressWarnings(isotree::isolation.forest(X, ntrees = ntrees, sample_size = sample_size, nthreads = 1))
  scores <- suppressWarnings(isotree::predict.isolation_forest(model, X, type = "score"))
  if (!is.numeric(scores)) return(NULL)
  thr <- if (is.null(contamination) || !is.finite(contamination) || contamination <= 0) {
    stats::quantile(scores, 0.98, na.rm = TRUE)
  } else {
    stats::quantile(scores, 1 - contamination, na.rm = TRUE)
  }
  list(threshold = as.numeric(thr), quantile = ifelse(is.null(contamination) || contamination <= 0, 0.98, 1 - contamination))
}

# Compute LOF threshold likewise
compute_lof_threshold <- function(dt, numeric_cols, minPts = 10, q = 0.98) {
  ok <- requireNamespace("dbscan", quietly = TRUE)
  if (!ok || length(numeric_cols) == 0) return(NULL)
  X <- as.data.frame(dt[, ..numeric_cols])
  for (j in seq_along(X)) if (!is.numeric(X[[j]])) suppressWarnings(X[[j]] <- as.numeric(X[[j]]))
  X <- as.matrix(X)
  if (!ncol(X)) return(NULL)
  cc <- stats::complete.cases(X); if (!any(cc)) return(NULL)
  lofv <- suppressWarnings(dbscan::lof(X[cc,, drop = FALSE], minPts = minPts))
  list(threshold = as.numeric(stats::quantile(lofv, q, na.rm = TRUE)), quantile = q)
}
