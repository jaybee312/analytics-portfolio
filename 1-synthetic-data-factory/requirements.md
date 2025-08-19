# 📦 Requirements

This document outlines what’s required to run the Data Factory tool locally in RStudio or via CLI. It includes:

- ✅ R package dependencies  
- 📁 File/folder structure  
- ⚙️ YAML schema and available options  

---

## ✅ R Package Dependencies

Install required packages (via CLI or RStudio):

```r
install.packages(c(
  "yaml", 
  "dplyr", 
  "stringr", 
  "lubridate", 
  "glue", 
  "readr"
))
