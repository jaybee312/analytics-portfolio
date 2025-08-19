# Outlier Detection (POC → MVP, R version)

An R-based module to create outlier alerting reports for any dataset produced by the **Data Factory**.  
It helps surface data anomalies, quality issues, and statistical outliers — feeding these learnings back into the Data Factory’s **dirty data** rules.

---

## 0) Why R?

- Consistent with the rest of the suite (R-first).  
- Strong ecosystem: `data.table`, `robustbase`, `isotree`, `changepoint`, `tsoutliers`.  
- Optional extensions from Rob Hyndman’s group (`weird`, `anomalize`, `fable`) for robust and time-series-specific anomaly detection.  
- Easy to ship reports (Markdown, HTML) via RMarkdown.

---

## 1) POC Scope

**Goal:** single dataset → single YAML config → one Markdown + CSV report.

- **Inputs**
  - CSV from Data Factory
  - Config: columns, thresholds, detectors

- **Detectors**
  - MAD (robust z-scores via `robustbase`)
  - IQR (boxplot whiskers)
  - Isolation Forest (`isotree`)
  - Time-series outliers (`tsoutliers` if time column present)

- **Outputs**
  - `reports/<dataset>/outliers.csv`
  - `reports/<dataset>/summary.md`

---

## 2) MVP Scope

**Batch, configurable, explainable.**

- **Batch configs**: run across many datasets  
- **Detectors**
  - LOF (via `dbscan`)
  - Change-points (`changepoint`)
  - Advanced time-series outliers (`tsoutliers`, `anomalize`, `fable`)  
  - Multivariate outliers with **`weird`** (Hyndman et al.)  
- **Quality checks**
  - Null % drift
  - Uniqueness
  - Schema drift
- **Reports**
  - RMarkdown HTML with plots (distribution shifts, flagged counts)
- **Backfeed**
  - Write `artifacts/<dataset>/rule_candidates.json` with suggested rules
- **Integration**
  - CLI via `Rscript scripts/run_odet.R --config ...`

---

## 3) Repo Layout

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
    ├─ requirements.md         # dependencies + schema
    ├─ usage_guide.md          # how to run (to be added)
    ├─ DESCRIPTION             # R package metadata
    ├─ NAMESPACE
    ├─ README.md
    └─ LICENSE

---

## 4) Config Schema (YAML)

### POC example (`configs/sample_poc.yml`)

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

## 5) CLI Usage

    # Single dataset (POC)
    Rscript scripts/run_odet.R --config configs/sample_poc.yml

    # Batch run (MVP)
    Rscript scripts/run_odet.R --config configs/sample_mvp.yml

    # Validate configs
    Rscript scripts/validate_config.R configs/*.yml

---

## 6) Outputs

- **outliers.csv** — row-level flags with detector info  
- **summary.md / summary.html** — high-level findings, drift plots, suggested rules  
- **rule_candidates.json** — machine-readable suggestions for Data Factory

---

## 7) Removing the Old R/Py Module

This repo fully replaces the need for a mixed R/Python submodule.  
Remove any mention of `r/py` integration from the Data Factory suite to avoid duplication.

---

## 8) Quick Start

    # Install deps
    install.packages(c(
      "data.table","yaml","robustbase","isotree",
      "changepoint","tsoutliers","rmarkdown","jsonlite","testthat"
    ))

    # Optional: Hyndman packages (for MVP+)
    install.packages(c("weird","fable","tsibble","anomalize","dbscan"))

    # Run sample
    Rscript scripts/run_odet.R --config configs/sample_poc.yml

    # View report
    cat reports/customers_aug/summary.md

---

## 9) Definition of Done

- Reproducible POC run on sample data  
- Markdown + CSV outputs produced  
- `rule_candidates.json` created  
- MVP adds: batch configs, drift detection, HTML reports, Hyndman-based detectors  
