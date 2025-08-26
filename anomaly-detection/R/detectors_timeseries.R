# R/detectors_timeseries.R
# Time-series outlier detectors (quiet)

suppressPackageStartupMessages({
  library(data.table)
})

.ts_coerce <- function(dt, time_col) {
  if (is.null(time_col) || !time_col %in% names(dt)) return(NULL)
  t <- suppressWarnings(tryCatch(as.POSIXct(dt[[time_col]]), error = function(e) NA))
  if (all(is.na(t))) t <- suppressWarnings(tryCatch(as.Date(dt[[time_col]]), error = function(e) NA))
  if (all(is.na(t))) return(NULL)
  as.POSIXct(t)
}

# --- tsoutliers ---------------------------------------------------------------
tsoutliers_flags <- function(dt, time_col, value_cols) {
  out <- list()
  t <- .ts_coerce(dt, time_col)
  if (is.null(t)) return(data.table())
  ok <- requireNamespace("tsoutliers", quietly = TRUE)
  if (!ok) return(data.table())
  
  for (col in value_cols) {
    x <- suppressWarnings(as.numeric(dt[[col]]))
    if (all(is.na(x))) next
    ord <- order(t)
    df <- data.table(time = as.Date(t[ord]), val = x[ord])
    agg <- df[, .(val = mean(val, na.rm = TRUE)), by = time][order(time)]
    if (nrow(agg) < 10) next
    
    res <- tryCatch({
      # Weekly default frequency; suppress internal warnings about iteration caps
      suppressWarnings({
        fit <- tsoutliers::tso(ts(agg$val, frequency = 7))
        idx <- unique(fit$outliers$ind)
        if (length(idx)) {
          data.table(
            row_index = match(agg$time[idx], df$time),
            detector  = "timeseries.tsoutliers",
            score     = NA_real_,
            severity  = "medium",
            columns   = col,
            notes     = sprintf("types=%s", paste(unique(fit$outliers$type), collapse = ","))
          )
        } else data.table()
      })
    }, error = function(e) data.table())
    out[[length(out) + 1]] <- res
  }
  rbindlist(out, use.names = TRUE, fill = TRUE)
}

# --- anomalize ----------------------------------------------------------------
anomalize_flags <- function(dt, time_col, value_cols, method = "stl", alpha = 0.05) {
  out <- list()
  t <- .ts_coerce(dt, time_col)
  if (is.null(t)) return(data.table())
  ok <- requireNamespace("anomalize", quietly = TRUE) &&
    requireNamespace("tibble", quietly = TRUE) &&
    requireNamespace("dplyr", quietly = TRUE) &&
    requireNamespace("tidyr", quietly = TRUE)
  if (!ok) return(data.table())
  
  for (col in value_cols) {
    x <- suppressWarnings(as.numeric(dt[[col]])); if (all(is.na(x))) next
    ord <- order(t)
    tt <- as.Date(t[ord]); xx <- x[ord]
    df <- data.frame(time = tt, value = xx)
    if (nrow(df) < 10) next
    
    res <- tryCatch({
      suppressPackageStartupMessages({
        library(dplyr); library(tidyr); library(tibble); library(anomalize)
      })
      tib <- tibble::as_tibble(df)
      out_df <- suppressMessages(
        tib %>%
          anomalize::time_decompose(value, method = method) %>%
          anomalize::anomalize(remainder, alpha = alpha) %>%
          anomalize::time_recompose()
      )
      anoms <- dplyr::filter(out_df, anomaly == "Yes")
      if (!nrow(anoms)) return(data.table())
      idx <- match(as.Date(anoms$time), as.Date(df$time))
      data.table(
        row_index = idx,
        detector  = paste0("timeseries.anomalize.", method),
        score     = NA_real_,
        severity  = "medium",
        columns   = col,
        notes     = sprintf("alpha=%.3f", alpha)
      )
    }, error = function(e) data.table())
    out[[length(out) + 1]] <- res
  }
  rbindlist(out, use.names = TRUE, fill = TRUE)
}

# --- fable (quiet) ------------------------------------------------------------
fable_resid_flags <- function(dt, time_col, value_cols) {
  out <- list()
  t <- .ts_coerce(dt, time_col)
  if (is.null(t)) return(data.table())
  ok <- requireNamespace("tsibble", quietly = TRUE) &&
    requireNamespace("fable", quietly = TRUE) &&
    requireNamespace("fabletools", quietly = TRUE) &&
    requireNamespace("dplyr", quietly = TRUE)
  if (!ok) return(data.table())
  
  for (col in value_cols) {
    x <- suppressWarnings(as.numeric(dt[[col]])); if (all(is.na(x))) next
    ord <- order(t)
    tt <- as.Date(t[ord]); xx <- x[ord]
    df <- data.frame(time = tt, value = xx)
    if (nrow(df) < 10) next
    
    res <- tryCatch({
      suppressPackageStartupMessages({ library(dplyr); library(tsibble); library(fable); library(fabletools) })
      tsib <- tsibble::as_tsibble(df, index = time)
      fit  <- suppressMessages(fabletools::model(tsib, ARIMA(value)))
      fc   <- suppressMessages(fabletools::augment(fit))
      r <- abs(as.numeric(fc$.resid / sd(fc$.resid, na.rm = TRUE)))
      idx <- which(r >= 3)
      if (!length(idx)) return(data.table())
      data.table(
        row_index = idx,
        detector  = "timeseries.fable.ARIMA_resid",
        score     = round(r[idx], 3),
        severity  = ifelse(r[idx] >= 4, "high", "medium"),
        columns   = col,
        notes     = "std resid >= 3"
      )
    }, error = function(e) data.table())
    out[[length(out) + 1]] <- res
  }
  rbindlist(out, use.names = TRUE, fill = TRUE)
}
