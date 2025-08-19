# Outlier Detection – Requirements

This document defines the technical requirements for the **Outlier Detection** repo. It covers R dependencies, directory structure, and the YAML schema for configs.

---

## 1. R Dependencies

### Core Packages (POC)
- **data.table** — fast IO and data manipulation
- **yaml** — config parsing
- **robustbase** — robust statistics (MAD, IQR)
- **isotree** — Isolation Forest
- **changepoint** — change-point detection
- **tsoutliers** — time-series outlier detection
- **rmarkdown**, **knitr** — report generation (Markdown/HTML)
- **jsonlite** — write `rule_candidates.json`
- **testthat** — testing framework

### Optional Packages (MVP+)
- **weird** — multivariate outlier detection (Hyndman)
- **anomalize** — tidy decomposition + anomaly detection
- **fable**, **tsibble** — time-series analysis + anomaly detection in tidyverse ecosystem
- **dbscan** — Local Outlier Factor (LOF)

---

## 2. Directory Structure

    outlier-detection/
    ├─ R/
    │  ├─ detectors_univariate.R
    │  ├─ detectors_multivariate.R
    │  ├─ detectors_timeseries.R
    │  ├─ quality_checks.R
    │  ├─ reporting.R
    │  ├─ backfeed.R
    │  └─ utils_config.R
    ├─ scripts/
    │  ├─ run_odet.R           # CLI entrypoint
    │  └─ validate_config.R
    ├─ configs/
    │  ├─ sample_poc.yml
    │  └─ sample_mvp.yml
    ├─ reports/
    ├─ artifacts/
    ├─ tests/
    │  └─ testthat/
    ├─ DESCRIPTION             # R package metadata
    ├─ NAMESPACE
    ├─ README.md
    └─ LICENSE

---

## 3. YAML Config Schema

### Top-Level Keys
- **dataset_name**: string identifier for dataset
- **input**: path to file (csv/parquet)
- **schema**:
  - id_cols: list of identifier columns
  - numeric_cols: list of numeric columns
  - categorical_cols: list of categorical columns
  - time_col: (optional) time index for time-series
- **run**: which detectors to enable + parameters
- **controls**: global settings (max % flagged, min rows, whitelist)
- **reporting**: output formats + directory
- **backfeed**: rule candidate settings

### Example (POC)

    dataset_name: customers_aug
    input:
      path: data/customers_aug.csv
    schema:
      id_cols: [customer_id]
      numeric_cols: [monthly_spend, visits_30d]
      categorical_cols: [plan_type, region]
      time_col: signup_date
    run:
      detectors:
        iqr:
          enabled: true
          whisker_k: 1.5
        mad:
          enabled: true
          z_thresh: 3.5
        isolation_forest:
          enabled: true
          contamination: 0.02
        tsoutliers:
          enabled: false
    controls:
      max_flagged_pct: 5
      min_support_rows: 3
      whitelist:
        columns: []
        value_ranges: []
    reporting:
      formats: [md, csv]
      out_dir: reports/customers_aug
    backfeed:
      emit_rule_candidates: true
      out_dir: artifacts/customers_aug

---

## 4. CLI

- **POC Run**:

      Rscript scripts/run_odet.R --config configs/sample_poc.yml

- **MVP Batch Run**:

      Rscript scripts/run_odet.R --config configs/sample_mvp.yml

- **Config Validation**:

      Rscript scripts/validate_config.R configs/*.yml

---

## 5. Deliverables

- Reproducible environment with required R packages installed
- POC run: sample config → outputs (`outliers.csv`, `summary.md`)
- MVP run: multiple configs, HTML reporting, rule_candidates.json
