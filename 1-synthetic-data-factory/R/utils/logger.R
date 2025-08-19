#===== FILE: R/utils/logger.R =====
log_time <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log_line <- function(level, msg) cat(sprintf("[%s] %-7s %s\n", log_time(), level, msg))
log_info    <- function(msg) log_line("INFO", msg)
log_warn    <- function(msg) log_line("WARN", msg)
log_error   <- function(msg) log_line("ERROR", msg)
log_success <- function(msg) log_line("SUCCESS", msg)