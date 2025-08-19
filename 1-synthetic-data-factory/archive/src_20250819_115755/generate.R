source("modules/marketing_generator.R")

library(yaml)
config <- yaml::read_yaml("config.yaml")
dir.create("output/marketing", recursive = TRUE, showWarnings = FALSE)
outfile <- sprintf("output/marketing/marketing_dataset_%s.csv", Sys.Date())

marketing_data <- generate_marketing_data(config)
write.csv(marketing_data, outfile, row.names = FALSE)
cat("✅ Marketing dataset saved to:", outfile, "\n")
