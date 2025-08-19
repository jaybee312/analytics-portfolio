# Synthetic Data Factory

![R](https://img.shields.io/badge/R-4.5.0-blue) ![Status](https://img.shields.io/badge/status-stable-brightgreen)

A modular, configurable pipeline for generating **realistic synthetic datasets** in R.  
This factory powers the data for this entire Analytics Portfolio. 
More analytics and data science projects coming soon!

---

## Features
- Config-driven: YAML defines populations, channels, funnels, dates, etc.
- Modular R code: each dataset lives in `R/modules/<dataset>/`.
- Multiple outputs: tables saved to `outputs/<dataset>/` as CSV (Parquet/DuckDB coming soon).
- Tests: lightweight smoke tests validate schema + outputs.
- Extensible: add new datasets by dropping a YAML + module folder.

---

## Getting Started

### Prerequisites
- R ≥ 4.2
- Packages: yaml, dplyr, lubridate, readr, tinytest

### Install dependencies (run in R)
    install.packages(c("yaml","dplyr","lubridate","readr","tinytest"))

### Run the factory (from repo root)
    make run
This generates synthetic marketing data into `outputs/marketing/`.

### Run tests
    make test

---

## Project Structure
    ├─ config/datasets/marketing.yml   # config knobs
    ├─ R/                              # main + utils + modules
    │   ├─ main.R
    │   ├─ utils/…
    │   └─ modules/marketing/…
    ├─ outputs/marketing/              # generated CSVs
    ├─ scripts/run_local.R
    ├─ tests/                          # smoke tests
    └─ docs/ROADMAP.md                 # parked enhancements

---

## Example Dataset: Marketing
Generated tables:
- customers.csv (~3.5k customers)
- marketing_campaigns.csv (~120 campaigns)
- sales_funnel.csv (~17.5k leads/opp)
- product_usage.csv (~600k daily usage rows)
- nps_responses.csv (~7k survey responses)

---

## Portfolio Integration (Coming Soon!)

This factory is the data backbone for the rest of my analytics portfolio.  
Check out the projects it powers:

- Marketing Analytics Dashboard → https://github.com/jm/marketing-dashboard
- Experimentation Platform → https://github.com/jm/experimentation-platform
- Data Engineering Pipeline → https://github.com/jm/data-pipeline
- Customer Retention Modeling → https://github.com/jm/customer-retention

👉 Explore the other repos to see how synthetic data from this factory drives dashboards, models, and pipelines.

---

## Roadmap
See docs/ROADMAP.md for planned enhancements (Parquet, CI, channel ladders, etc.).

---

## License
MIT
