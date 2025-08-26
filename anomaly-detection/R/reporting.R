# R/reporting.R
# Diagnostics JSON (per-column stats + detector thresholds + topN + runtimes) and HTML rendering

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

# ---------- utils ----------
.numify <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.integer(x)) return(as.numeric(x))
  suppressWarnings(as.numeric(x))
}

# ---------- per-column numeric diagnostics ----------
compute_numeric_diagnostics <- function(dt, numeric_cols, iqr_k = 1.5, mad_z = 3.5) {
  if (length(numeric_cols) == 0) return(list())
  out <- vector("list", length(numeric_cols))
  names(out) <- numeric_cols
  for (col in numeric_cols) {
    if (!col %in% names(dt)) next
    x_raw <- dt[[col]]
    x <- .numify(x_raw)
    
    n <- length(x_raw); n_na <- sum(is.na(x_raw)); n_unique <- length(unique(x_raw))
    q1 <- q3 <- iqr <- lower <- upper <- NA_real_
    med <- madv <- mad_lower <- mad_upper <- NA_real_
    mean_x <- sd_x <- min_x <- max_x <- NA_real_
    
    if (any(!is.na(x))) {
      qs <- tryCatch(quantile(x, c(.25,.5,.75), na.rm = TRUE), error = function(e) rep(NA_real_,3))
      q1 <- as.numeric(qs[[1]]); med <- as.numeric(qs[[2]]); q3 <- as.numeric(qs[[3]])
      iqr <- q3 - q1
      if (is.finite(iqr) && iqr > 0) { lower <- q1 - iqr_k * iqr; upper <- q3 + iqr_k * iqr }
      madv <- tryCatch(mad(x, constant = 1.4826, na.rm = TRUE), error = function(e) NA_real_)
      if (is.finite(madv) && madv > 0) { mad_lower <- med - mad_z * madv; mad_upper <- med + mad_z * madv }
      mean_x <- mean(x, na.rm = TRUE); sd_x <- sd(x, na.rm = TRUE)
      min_x  <- suppressWarnings(min(x, na.rm = TRUE)); max_x <- suppressWarnings(max(x, na.rm = TRUE))
    }
    
    out[[col]] <- list(
      column = col,
      counts = list(n = n, n_na = n_na, pct_na = ifelse(n>0, round(100*n_na/n,3), NA_real_), n_unique = n_unique),
      summary = list(mean = mean_x, sd = sd_x, min = min_x, q1 = q1, median = med, q3 = q3, max = max_x),
      iqr = list(k = iqr_k, iqr = iqr, lower = lower, upper = upper),
      mad = list(z = mad_z, mad = madv, lower = mad_lower, upper = mad_upper)
    )
  }
  out
}

# ---------- light time-series meta ----------
compute_timeseries_meta <- function(dt, time_col, id_cols = NULL) {
  if (is.null(time_col) || !time_col %in% names(dt)) return(NULL)
  tvec <- tryCatch(as.POSIXct(dt[[time_col]]), error = function(e) NA)
  if (all(is.na(tvec))) tvec <- tryCatch(as.Date(dt[[time_col]]), error = function(e) NA)
  if (all(is.na(tvec))) return(list(time_col = time_col, parse_ok = FALSE))
  d <- sort(unique(as.Date(tvec))); if (length(d) < 2) return(list(time_col = time_col, parse_ok = TRUE, n_unique_dates = length(d)))
  gaps <- as.integer(diff(d)); med_gap <- stats::median(gaps, na.rm = TRUE)
  cadence <- if (med_gap <= 1) "daily" else if (med_gap <= 7) "weekly-ish" else "monthly-ish"
  list(time_col = time_col, parse_ok = TRUE, n_unique_dates = length(d),
       median_gap_days = med_gap, inferred_cadence = cadence, id_cols = id_cols)
}

# ---------- diagnostics writer ----------
# mv_thresholds: list(isolation_forest=..., lof=...)
# top_flags: named list(detector -> data.frame rows)
# runtimes:  named list(detector -> list(elapsed_sec=..., rows=..., error=NULL))
write_diagnostics_json <- function(report_dir, dataset_name, detectors_config, numeric_diag, ts_meta = NULL,
                                   mv_thresholds = list(), top_flags = list(), runtimes = list()) {
  dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
  tf_serialized <- if (!length(top_flags)) NULL else lapply(top_flags, function(dd) {
    if (is.null(dd) || !NROW(dd)) list() else as.data.frame(dd)
  })
  payload <- list(
    dataset = dataset_name,
    generated_at = as.character(Sys.time()),
    detectors = detectors_config,
    thresholds = list(isolation_forest = mv_thresholds$isolation_forest, lof = mv_thresholds$lof),
    runtimes = runtimes,
    top_flags = tf_serialized,
    columns = numeric_diag,
    timeseries = ts_meta
  )
  out_path <- file.path(report_dir, "diagnostics.json")
  writeLines(jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE, digits = 10), out_path)
  message("Wrote: ", out_path)
  out_path
}

# ---------- HTML render (absolute paths + fresh env) ----------
render_html_report <- function(report_dir, dataset_name, dt_path, outliers_path, diagnostics_path,
                               extra_params = list()) {
  ok <- requireNamespace("rmarkdown", quietly = TRUE)
  if (!ok) { message("rmarkdown not installed; skipping HTML rendering."); return(invisible(NULL)) }
  if (!dir.exists(report_dir)) dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
  template <- file.path("reports", "templates", "summary.Rmd")
  if (!file.exists(template)) { message("HTML template not found at ", template, "; skipping HTML rendering."); return(invisible(NULL)) }
  
  norm <- function(p) {
    if (is.null(p) || !nzchar(p)) return(p)
    res <- try(normalizePath(p, winslash = "/", mustWork = FALSE), silent = TRUE)
    if (inherits(res, "try-error")) return(p) else return(res)
  }
  render_params <- c(list(
    dataset_name     = dataset_name,
    dt_path          = norm(dt_path),
    outliers_path    = norm(outliers_path),
    diagnostics_path = norm(diagnostics_path)
  ), extra_params)
  
  knit_env <- new.env(parent = globalenv())
  rmarkdown::render(
    input       = template,
    output_file = "summary.html",
    output_dir  = report_dir,
    params      = render_params,
    envir       = knit_env,
    quiet       = TRUE
  )
  message("Wrote: ", file.path(report_dir, "summary.html"))
  invisible(file.path(report_dir, "summary.html"))
}
