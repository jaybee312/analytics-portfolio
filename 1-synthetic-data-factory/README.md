# Data Factory for Synthetic Portfolio Datasets

This R-based tool generates flexible, realistic synthetic datasets for analytics projects across a portfolio of use cases, including marketing, sales, customer success, and more.

---

## ✅ Features

* Modular YAML config: define what dataset to build (e.g. `marketing`, `sales_funnel`, etc.)
* Adjustable row count and cleanliness (simulate real-world messiness)
* Auto-generated tables written to CSV (per dataset)
* Clean, extensible codebase for adding more modules

---

## 🏗️ Directory Structure

```
├── data-factory/
│   ├── src/
│   │   ├── generate.R          # main driver script
│   │   ├── modules/
│   │   │   ├── marketing.R     # generates marketing dataset
│   │   │   └── ...             # other dataset generators
│   ├── config/
│   │   └── marketing.yaml      # yaml with generation options
│   ├── output/
│   │   └── marketing.csv       # output CSV
│   └── README.md
```

---

## ⚙️ Configuration (YAML)

Each dataset uses its own YAML config located in `config/`. Example for marketing:

```yaml
project: marketing
num_rows: 1000
cleanliness: medium  # options: clean, medium, messy
locale: us            # future expansion
```

* `project`: corresponds to module script in `modules/`
* `num_rows`: number of rows to simulate
* `cleanliness`: how realistic/messy the data is (nulls, fuzziness)
* `locale`: reserved for future country-specific modeling

---

## 🚀 How to Use

1. **Edit config**: modify `config/marketing.yaml` or create a new one
2. **Run script**:

```r
source("src/generate.R")
```

This will generate and save `output/{project}.csv`

---

## 🛠 Requirements

* R >= 4.1
* Packages:

  * `yaml`
  * `dplyr`
  * `stringi`
  * `lubridate`
  * `tibble`
  * `readr`
  * `rlang`
  * `purrr`

Install with:

```r
install.packages(c("yaml", "dplyr", "stringi", "lubridate", "tibble", "readr", "rlang", "purrr"))
```

---

## 🔜 Roadmap

* Add support for:

  * `sales_funnel`, `support_tickets`, `product_usage`, `nps_responses`, etc.
  * synthetic joins across datasets
  * language + regional overrides via `locale`
  * CLI wrapper for easy batch runs

---

## 👥 Contributors

* JM — concept, direction
* ChatGPT — scaffolding, generation logic
