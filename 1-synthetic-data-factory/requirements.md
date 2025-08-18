# Synthetic Data Factory — Lightweight, General-Purpose (v1)

## Purpose
One small R tool to generate synthetic datasets for ANY project (segmentation, forecasting, dashboards, experiments), so you never hand-craft CSVs again.

## Philosophy
- **Config in, CSV out.** No code edits per dataset.
- **Small but flexible.** A few column types + simple relationships = 80/20 win.
- **Deterministic.** `set.seed()` for repeatable results.
- **RStudio-first.** Single script + YAML config.

---

## v1 Features (scope you can ship fast)
1) **Column generators**
   - `id_seq` (U000001…)
   - `categorical(levels, probs)`
   - `numeric_normal(mean, sd)`, `numeric_uniform(min, max)`, `numeric_log_normal(meanlog, sdlog)`
   - `integer_pois(lambda)`, `integer_negbin(mu, size)`
   - `date_range(start, end)`, `timestamp_range(start, end)`
2) **Light relationships**
   - **derive**: columns as simple functions of others (e.g., `revenue = round(aov * orders + noise, 2)`)
   - **conditional rules**: different params by segment/channel (`if channel == "email" then conv_rate ~ N(0.05, 0.005)`)
   - **correlate**: one numeric column correlated to another via `corr ~ rho` (simple linear combo)
3) **Noise + missingness**
   - `noise_normal(sd)`, `dropout(p)` to insert NA randomly
4) **Outputs**
   - Write **CSV** (+ optional **Parquet** later)
   - Small sample preview in the console and optional HTML preview (Quarto)
5) **CLI-like usage (from RStudio)**
   - Run: `Rscript src/generate.R --config configs/segmentation.yml --out data/segmentation.csv`

---

## Minimal File Structure
synthetic-data-factory/  
├─ src/  
│  ├─ generate.R                # reads YAML, creates dataset(s)  
│  ├─ generators.R              # small library of column generators  
│  ├─ transforms.R              # derive, conditional, correlate, noise  
│  └─ utils.R                   # helpers (seed, validate, write)  
├─ configs/  
│  ├─ segmentation.yml          # example config (for clustering demo)  
│  ├─ forecasting.yml           # example config (daily KPIs)  
│  └─ template.yml              # blank starter  
├─ data/                        # outputs land here (git-tracked)  
├─ notebooks/  
│  └─ preview.qmd               # optional HTML preview (head(), plots)  
└─ README.md

---

## YAML Config (v1 schema)

```yaml
# configs/segmentation.yml
seed: 312
rows: 10000
output: "data/segmentation.csv"

columns:
  - name: user_id
    type: id_seq
    prefix: "U"
    width: 6

  - name: channel_primary
    type: categorical
    levels: ["search","social","display","email","organic","direct"]
    probs:  [0.30,    0.20,    0.15,     0.10,   0.15,     0.10]

  - name: tenure_days
    type: integer_negbin
    mu: 300
    size: 20

  - name: sessions_30d
    type: integer_pois
    lambda: 8

  - name: aov
    type: numeric_log_normal
    meanlog: 4.5
    sdlog: 0.25

  - name: orders_90d
    type: integer_negbin
    mu: 2.4
    size: 1.3

  - name: total_spend
    type: derive
    formula: "round(aov * orders_90d + noise, 2)"
    noise: { type: numeric_normal, sd: 8 }

rules:
  - when: 'channel_primary == "email"'
    update:
      sessions_30d: { type: integer_pois, lambda: 10.5 }
      orders_90d:   { type: integer_negbin, mu: 3.1, size: 1.5 }

  - when: 'channel_primary == "display"'
    update:
      sessions_30d: { type: integer_pois, lambda: 6.5 }
      orders_90d:   { type: integer_negbin, mu: 1.6, size: 1.0 }

correlate:
  - target: aov
    with: sessions_30d
    rho: 0.15  # small positive association

missingness:
  - cols: ["aov"]
    p: 0.02
