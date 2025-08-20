# Outlier Detection – Requirements (MVP, R-first)

This document specifies the **environment, dependencies, repo layout, config schema, and run commands** required to execute the Outlier Detection module at MVP. It is copy–paste ready for your repo.

---

## 1) Environment

- R ≥ 4.3
- macOS/Linux/Windows (tested on macOS)
- Git (version control)
- Optional: RStudio (for development), Make (for shortcuts)

---

## 2) R Packages

### Core (POC → MVP)
    install.packages(c(
      "data.table","yaml","robustbase","isotree",
      "changepoint","tsoutliers","rmarkdown","jsonlite","testthat","dbscan"
    ))

### Hyndman ecosystem (MVP+ time series & robust multivariate)
    install.packages(c("weird","fable","tsibble","anomalize"))

Notes:
- `isotree` provides Isolation Forest in R.
- `dbscan` provides LOF via `dbscan::lof`.
- `weird`, `fable`, `tsibble`, `anomalize` power advanced time-series & multivariate anomaly workflows.
- `rmarkdown` enables HTML report generation.

---

## 3) Repository Layout (MVP)

    outlier-detection/
    ├─ R/
    │  ├─ detectors_univariate.R        # IQR, MAD
    │  ├─ detectors_multivariate.R      # Isolation Forest, LOF
    │  ├─ detectors_timeseries.R        # tsoutliers / anomalize / fable interfaces
    │  ├─ quality_checks.R              # null %, uniqueness, schema/type drift
    │  ├─ reporting.R                   # Markdown/HTML report writers
    │  ├─ backfeed.R                    # rule_candidates.json generator
    │  └─ utils_config.R                # config parsing/validation helpers
    ├─ scripts/
    │  ├─ run_odet.R                    # CLI entrypoint (batch-aware)
    │  └─ validate_config.R             # schema checks for YAML
    ├─ configs/
    │  ├─ sample_poc.yml
    │  └─ sample_mvp.yml
    ├─ data/                            # (optional) small sample files
    ├─ reports/                         # outputs (gitignore except samples)
    ├─ artifacts/                       # rule candidates, caches, models
    ├─ tests/
    │  └─ testthat/
    ├─ requirements.md                  # THIS FILE
    ├─ usage_guide.md                   # “how to run” doc
    ├─ DESCRIPTION                      # R package metadata (optional)
    ├─ NAMESPACE                        # (optional)
    ├─ README.md                        # project overview
    └─ LICENSE

---

## 4) Config Schema (YAML)

### POC (single dataset) – `configs/sample_poc.yml`
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
        iqr: { enabled: true, whisker_k: 1.5 }
        mad: { enabled: true, z_thresh: 3.5 }
        isolation_forest: { enabled: true, contamination: 0.02 }
        tsoutliers: { enabled: false }
    controls:
      max_flagged_pct: 5
      min_support_rows: 1
      whitelist:
        columns: []
        value_ranges: []
    reporting:
      formats: [md, csv]
      out_dir: reports/customers_aug
    backfeed:
      emit_rule_candidates: true
      out_dir: artifacts/customers_aug

### MVP (batch, advanced detectors) – `configs/sample_mvp.yml`
    datasets:
      - name: customers_aug
        input: { path: data/customers_aug.csv }
        schema:
          id_cols: [customer_id]
          numeric_cols: [monthly_spend, visits_30d]
          categorical_cols: [plan_type, region]
          time_col: signup_date
      - name: web_traffic
        input: { path: data/web_traffic.csv }
        schema:
          id_cols: [page_id]
          numeric_cols: [sessions, bounce_rate]
          time_col: date
    run:
      detectors:
        iqr: { enabled: true, whisker_k: 1.5 }
        mad: { enabled: true, z_thresh: 3.5 }
        isolation_forest: { enabled: true, contamination: 0.02 }
        lof: { enabled: true, minPts: 10 }                   # dbscan::lof
        tsoutliers: { enabled: true }                        # ARIMA-style outliers
        anomalize: { enabled: true, method: "stl", alpha: 0.05 }
        weird: { enabled: true }                             # multivariate “strange” pts
    controls:
      max_flagged_pct: 5
      min_support_rows: 5
      suppressions:
        - dataset: web_traffic
          window: { start: 2024-12-24, end: 2024-12-26 }     # ignore holiday spikes
      whitelist:
        columns: []
        value_ranges: []
    reporting:
      formats: [md, csv, html]
      out_dir_root: reports
    backfeed:
      emit_rule_candidates: true
      out_dir_root: artifacts

---

## 5) CLI Commands

### Run POC (single dataset)
    Rscript scripts/run_odet.R --config configs/sample_poc.yml

### Run MVP batch (multiple datasets)
    Rscript scripts/run_odet.R --config configs/sample_mvp.yml

### Validate configs
    Rscript scripts/validate_config.R configs/*.yml

---

## 6) Outputs (MVP)

- `reports/<dataset>/outliers.csv`  
  - Columns: `row_index, detector, score, severity, columns, notes`
- `reports/<dataset>/summary.md` and (if enabled) `summary.html`  
  - Findings, detector params, drift snapshots, time‑series panels
- `artifacts/<dataset>/rule_candidates.json`  
  - Suggested caps/ranges, allowed values, uniqueness keys for Data Factory backfeed

---

## 7) Quality & Controls

- **Flag rate control**: `controls.max_flagged_pct` caps total flagged rows (by highest scores).
- **Minimum support**: `controls.min_support_rows` drops columns with too few flags.
- **Suppressions**: skip known spike windows (e.g., holidays, quarter‑end).
- **Whitelists**: ignore columns or value ranges entirely.
- **Versioning**: write detector versions/thresholds into report headers.

---

## 8) Validation & Testing

- Config schema checks: `scripts/validate_config.R`
- Unit tests (testthat) per module in `tests/testthat/`
- CI smoke: run POC on sample data, publish sample report artifact

---

## 9) Integration Contract (with Data Factory)

- **Input**: reads Data Factory outputs (CSV/Parquet path in YAML).
- **Backfeed**: emits `artifacts/<dataset>/rule_candidates.json` for rule ingestion (caps, allowed values, uniqueness).
- **Design**: config‑driven, reproducible; both repos keep YAML as the single source of truth.

---

## 10) Practical Defaults

- IQR: `whisker_k = 1.5` (exploratory) → `3.0` (conservative)
- MAD: `z_thresh = 3.5`
- Isolation Forest: `contamination = 0.01–0.03` (or `auto` when tuner added)
- LOF: start with `minPts = max(10, round(0.02 * n_rows))`
- Hyndman stack:
  - `tsoutliers` for ARIMA-oriented outliers
  - `anomalize` for decomposition‑based anomalies
  - `fable`+`tsibble` for tidy time‑series modeling
  - `weird` for robust multivariate “strange” points

---

**This file is the authoritative requirements spec for the Outlier Detection MVP (R-first, Hyndman-enabled).**
