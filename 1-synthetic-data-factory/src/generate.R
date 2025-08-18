# generate.R

library(yaml)
library(dplyr)
library(stringr)
library(readr)

set.seed(312)  # Will be overridden by YAML if defined

# === 1. Load config ===
config_path <- "configs/segmentation.yml"
config <- yaml::read_yaml(config_path)

if (!is.null(config$seed)) {
  set.seed(config$seed)
}

rows <- config$rows

# === 2. Helper generators ===

generate_id_seq <- function(n, prefix = "ID", width = 5) {
  paste0(prefix, str_pad(1:n, width, pad = "0"))
}

generate_categorical <- function(n, levels, probs) {
  sample(levels, size = n, replace = TRUE, prob = probs)
}

generate_integer_negbin <- function(n, mu, size) {
  rnbinom(n, size = size, mu = mu)
}

generate_integer_pois <- function(n, lambda) {
  rpois(n, lambda)
}

generate_numeric_log_normal <- function(n, meanlog, sdlog) {
  rlnorm(n, meanlog, sdlog)
}

generate_numeric_normal <- function(n, mean = 0, sd = 1) {
  rnorm(n, mean, sd)
}

# === 3. Generate base columns ===

df <- tibble()

for (col in config$columns) {
  name <- col$name
  type <- col$type

  vals <- switch(type,
    id_seq = generate_id_seq(rows, col$prefix, col$width),
    categorical = generate_categorical(rows, col$levels, col$probs),
    integer_negbin = generate_integer_negbin(rows, col$mu, col$size),
    integer_pois = generate_integer_pois(rows, col$lambda),
    numeric_log_normal = generate_numeric_log_normal(rows, col$meanlog, col$sdlog),
    stop(paste("Unknown type:", type))
  )

  df[[name]] <- vals
}

# === 4. Apply correlation (optional step — simplified here) ===
# You can optionally use `mvrnorm` or `corpcor` to simulate correlated variables

# === 5. Apply rules ===

if (!is.null(config$rules)) {
  for (rule in config$rules) {
    condition <- rule$when
    idx <- which(eval(parse(text = condition), envir = df))

    for (field in names(rule$update)) {
      spec <- rule$update[[field]]
      type <- spec$type

      updated <- switch(type,
        integer_negbin = generate_integer_negbin(length(idx), spec$mu, spec$size),
        integer_pois = generate_integer_pois(length(idx), spec$lambda),
        numeric_normal = generate_numeric_normal(length(idx), spec$mean, spec$sd),
        stop(paste("Unknown rule type:", type))
      )

      df[[field]][idx] <- updated
    }
  }
}

# === 6. Derive columns ===

for (col in config$columns) {
  if (col$type == "derive") {
    formula <- col$formula
    if (!is.null(col$noise)) {
      noise_sd <- col$noise$sd
      df$noise <- generate_numeric_normal(nrow(df), sd = noise_sd)
    }
    df[[col$name]] <- eval(parse(text = formula), envir = df)
    df$noise <- NULL
  }
}

# === 7. Apply missingness ===

if (!is.null(config$missingness)) {
  for (miss in config$missingness) {
    cols <- miss$cols
    p <- miss$p
    for (colname in cols) {
      miss_idx <- sample(1:nrow(df), size = round(p * nrow(df)))
      df[[colname]][miss_idx] <- NA
    }
  }
}

# === 8. Write to CSV ===

output_path <- config$output
dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(df, output_path)

message("✅ Synthetic data written to ", output_path)

