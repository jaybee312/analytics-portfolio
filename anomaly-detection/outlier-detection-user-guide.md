# Outlier Detection – Usage Guide

This guide explains how to use the **Outlier Detection** module, from running the POC on a single dataset to expanding into the MVP workflow.

---

## 1. Prerequisites

- R ≥ 4.3
- Required packages installed:

      install.packages(c(
        "data.table","yaml","robustbase","isotree",
        "changepoint","tsoutliers","rmarkdown","jsonlite","testthat"
      ))

- Optional packages (for MVP):

      install.packages(c("weird","fable","tsibble","anomalize","dbscan"))

- Ensure you have cloned the repo and are working from the repo root.

---

## 2. Running the POC

1. **Prepare a dataset** (CSV or Parquet) from the Data Factory. Place it in `data/`.
2. **Create a config file** in `configs/` (e.g. `configs/sample_poc.yml`). Use the provided template.
3. **Run the detector**:

       Rscript scripts/run_odet.R --config configs/sample_poc.yml

4. **Inspect outputs**:
   - `reports/<dataset>/outliers.csv` → row-level flags
   - `reports/<dataset>/summary.md` → Markdown summary of findings
   - `artifacts/<dataset>/rule_candidates.json` → suggested rules for Data Factory backfeed

---

## 3. Batch Runs (MVP)

Once multiple configs exist:

    Rscript scripts/run_odet.R --config configs/sample_mvp.yml

- Runs across all datasets defined in the config.
- Outputs reports for each dataset in `reports/<dataset>/`.
- Generates HTML reports via RMarkdown with plots and drift analysis.
- Emits `rule_candidates.json` for each dataset.

---

## 4. Config Validation

Before running, validate configs to catch schema errors:

    Rscript scripts/validate_config.R configs/*.yml

---

## 5. Output Files

- **outliers.csv** – row index, detector name, score, severity, columns flagged, notes.
- **summary.md / summary.html** – top-level findings, drift snapshots, suggested rules.
- **rule_candidates.json** – machine-readable rules for Data Factory.

---

## 6. Workflow

- Start with a single dataset + sample config → run POC.
- Review outputs, confirm detectors behave as expected.
- Add more detectors + quality checks in YAML as you expand.
- Transition to batch configs + HTML reporting for MVP.

---

## 7. Integration with Data Factory

- Outlier Detection consumes datasets from the Data Factory (`data/` or `outputs/`).
- It produces `rule_candidates.json` that Data Factory ingests to expand its **dirty data** rules.
- Aligns on config-driven design for reproducibility.

---

**You are now ready to run the Outlier Detection module. Start with the POC and expand step by step into the MVP.**
