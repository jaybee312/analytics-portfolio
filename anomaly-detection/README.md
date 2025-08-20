# Outlier Detection (POC → MVP, R version)

An R-based module to create outlier alerting reports for any dataset produced by the **Data Factory**.  
It surfaces data anomalies, quality issues, and statistical outliers — then feeds these learnings back into the Data Factory’s **dirty data** rules.

---

## 0) Why R?

- Consistent with the wider suite (R-first).  
- Strong ecosystem: `data.table`, `robustbase`, `isotree`, `changepoint`, `tsoutliers`.  
- **Hyndman ecosystem support** for time series & robust anomalies: `weird`, `anomalize`, `fable`, `tsibble`.  
- Easy to ship reports (Markdown/HTML) via `rmarkdown`.

---

## 1) POC Scope (lean, fast)

**Goal:** Single dataset → single YAML config → Markdown + CSV outputs.

- **Inputs**
  - CSV (or Parquet) from Data Factory.
  - Minimal YAML: id columns, numeric/categorical columns, optional time column.

- **Detectors (POC)**
  - Univariate: IQR (boxplot whiskers), MAD (robust z).
  - Multivariate: Isolation Forest (`isotree`).
  - Time series (optional): `tsoutliers` when `time_col` is present.

- **Outputs**
  - reports/<dataset>/outliers.csv — row-level flags + detector metadata.
  - reports/<dataset>/summary.md — succinct human report.

- **Success Criteria**
  - Runnable in minutes on sample data.
  - False-positive control: global cap and min-support.

---

## 2) MVP Scope (config-driven, explainable)

- **Batch configs**: run across many datasets from paths or a manifest.
- **Detectors**
  - Univariate: IQR, MAD, Z-score (opt-in), percentile caps.
  - Multivariate: Isolation Forest, LOF (`dbscan`).
  - Time Series (Hyndman-forward):
    - `tsoutliers` for ARIMA-style outliers.
    - `anomalize` (tidy decomposition + anomaly detection).
    - `fable` + `tsibble` for tidy time-series modeling and diagnostics.
  - **Multivariate robust**: `weird` (Hyndman) for “strange” observations.
- **Quality checks**
  - Nullness drift, uniqueness violations, categorical cardinality spikes, schema/type drift.
- **Explainability & Controls**
  - Per-detector thresholds, target-flag rate auto-tuning.
  - Whitelists/ignores, suppression windows (e.g., quarter-end).
- **Reporting**
  - CSV + Markdown + HTML (RMarkdown) with plots (drift, distributions, ts panels).
- **Backfeed**
  - Write `artifacts/<dataset>/rule_candidates.json` with suggested rules (caps, allowed values, uniqueness keys).
- **Integration**
  - CLI via `Rscript scripts/run_odet.R --config ...`

---

## 3) Repository Layout

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
    │  ├─ run_odet.R            # CLI entrypoint (POC → MVP)
    │  └─ validate_config.R     # schema checks for YAML
    ├─ configs/
    │  ├─ sample_poc.yml
    │  └─ sample_mvp.yml
    ├─ reports/                 # outputs (gitignored except samples)
    ├─ artifacts/               # rule candidates, caches, models
    ├─ tests/
    │  └─ testthat/
    ├─ requirements.md          # dependencies + schema
    ├─ usage_guide.md           # how to run (POC → MVP)
    ├─ DESCRIPTION              # R package metadata
    ├─ NAMESPACE
    ├─ README.md
    └─ LICENSE

---

## 4) Config Schema (YAML)

**POC example — `configs/sample_poc.yml`**

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

**MVP highlights — `configs/sample_mvp.yml`**

    # Multiple datasets via glob/manifest; add HTML reporting and Hyndman detectors
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
        lof: { enabled: true, minPts: 10 }             # dbscan::lof
        tsoutliers: { enabled: true }
        anomalize: { enabled: true, method: "stl", alpha: 0.05 }
        weird: { enabled: true }                        # multivariate robust
    controls:
      max_flagged_pct: 5
      min_support_rows: 5
      suppressions:
        - dataset: web_traffic
          window: { start: 2024-12-24, end: 2024-12-26 }  # holiday spike ignore
    reporting:
      formats: [md, csv, html]
      out_dir_root: reports
    backfeed:
      emit_rule_candidates: true
      out_dir_root: artifacts

---

## 5) CLI Usage

**POC (single dataset)**

    Rscript scripts/run_odet.R --config configs/sample_poc.yml

**Batch (MVP)**

    Rscript scripts/run_odet.R --config configs/sample_mvp.yml

**Validate configs**

    Rscript scripts/validate_config.R configs/*.yml

---

## 6) Outputs

- **reports/<dataset>/outliers.csv** — row-level flags  
  - row_index, detector, score, severity, columns, notes
- **reports/<dataset>/summary.md / summary.html** — findings + drift snapshots + ts panels (MVP)  
- **artifacts/<dataset>/rule_candidates.json** — proposed upstream rules

---

## 7) Integrating with the Data Factory

- **Inputs:** reads Data Factory outputs (CSV/Parquet).  
- **Backfeed:** writes `rule_candidates.json` per dataset; Data Factory ingests to expand **dirty data** rules.  
- **Contract:** both repos are config-driven; version detectors and thresholds in report headers.

---

## 8) Install & Quick Start

**Core (POC)**

    install.packages(c(
      "data.table","yaml","robustbase","isotree",
      "changepoint","tsoutliers","rmarkdown","jsonlite","testthat","dbscan"
    ))

**Hyndman ecosystem (MVP+)**

    install.packages(c("weird","fable","tsibble","anomalize"))

**Run**

    Rscript scripts/run_odet.R --config configs/sample_poc.yml
    # Then open: reports/<dataset>/summary.md

---

## 9) Removing the Old R/Py Module

This repo replaces any R/Python hybrid module for outlier work.  
Clean up the suite by removing references to the deprecated r/py module and updating diagrams/CI to point here.

---

## 10) Definition of Done

- **POC**
  - Runnable on sample data.
  - IQR + MAD + Isolation Forest enabled via YAML.
  - Markdown + CSV outputs present.

- **MVP**
  - Batch configs, HTML reports with plots.
  - Hyndman detectors (`weird`, `anomalize`, `fable` + `tsibble`) integrated.
  - Quality checks + backfeed JSON produced.
  - Controls documented; thresholds versioned in reports.

---

## 11) Notes on Detector Behavior (practical defaults)

- **IQR**: start with `k = 1.5` for discovery; increase to `3.0` to reduce flags.  
- **MAD**: `z_thresh = 3.5` is robust; tighten/loosen per dataset.  
- **Isolation Forest**: `contamination = 0.01–0.03` typical; set `auto` when we add auto-tuner.  
- **`weird`**: best for multivariate “strangeness” without heavy modeling; use after basic cleaning.  
- **`anomalize`**/**`fable`**: ideal for seasonal/weekly time series; ensure `tsibble` index and keys are set.

---

**This README is the single source of truth for the Outlier Detection module (R-first) — including Hyndman-based detectors — and is safe to paste into your repo as-is.**
