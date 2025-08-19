# Copy to tests/test_<dataset>.R and edit paths/table names

root_from <- function(start="."){
  d <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(d, "R")) && file.exists(file.path(d, "config"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) stop("Project root not found.")
    d <- parent
  }
}
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
start_dir <- if (length(file_arg)) dirname(file_arg) else getwd()
proj <- root_from(start_dir)

dataset <- "<dataset>"  # <-- change me
out <- file.path(proj, paste0("outputs/", dataset))
files <- c("<table1>.csv","<table2>.csv")  # <-- change me

missing <- files[!file.exists(file.path(out, files))]
if (length(missing)) stop(sprintf("[%s] missing: %s", dataset, paste(missing, collapse=", ")))

cat(sprintf("[%s] smoke OK\n", dataset))
