# Synthetic Data Factory

![R](https://img.shields.io/badge/R-4.5.0-blue) ![Status](https://img.shields.io/badge/status-stable-brightgreen)

A modular, configurable pipeline for generating **realistic synthetic datasets** in R.  
This factory powers the rest of my [Analytics Portfolio](https://github.com/jm/analytics-portfolio) projects — all downstream repos pull their data from here.

---

## Features
- 🔧 **Config-driven**: YAML defines populations, channels, funnels, dates, etc.
- 🧩 **Modular R code**: each dataset lives in `R/modules/<dataset>/`.
- 📂 **Multiple outputs**: tables saved to `outputs/<dataset>/` as CSV (Parquet/DuckDB coming soon).
- ✅ **Tests**: lightweight smoke tests validate schema + outputs.
- 🔮 **Extensible**: add new datasets by dropping a YAML + module folder.

---

## Getting Started

### Prerequisites
- R ≥ 4.2  
- Packages: `yaml`, `dplyr`, `lubridate`, `readr`, `tinytest`

### Install dependencies
```r
install.packages(c("yaml","dplyr","lubridate","readr","tinytest"))
