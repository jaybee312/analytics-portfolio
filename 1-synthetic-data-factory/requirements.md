# REQUIREMENTS

This document outlines all requirements to install, run, and extend the Data Factory MVP locally. It includes R package dependencies, directory structure, YAML schema options, and setup instructions.

---

## 📦 R Package Dependencies

You will need the following R packages installed. You can install them manually or use the install script in `scripts/install_packages.R`.

```r
install.packages(c("yaml", "dplyr", "tidyr", "lubridate", "stringr", "purrr", "readr"))
```

---

## 📁 Directory Structure

This is the recommended structure for the repo:

```
data-factory/
├── data/
│   └── output/              # Where generated datasets are written
├── scripts/
│   ├── install_packages.R   # One-time install script
│   ├── generate_dataset.R   # Main script to generate a dataset from YAML
├── yaml/
│   └── marketing.yml        # Example config file for Marketing dataset
├── README.md
├── REQUIREMENTS.md          # This file
```

> All outputs are written to the `/data/output/` folder.

---

## ⚙️ YAML Config Schema

Each dataset is configured via a YAML file stored in `yaml/`.

Here’s the schema with available options:

```yaml
dataset_name: "marketing"
num_customers: 1000
start_date: "2023-01-01"
end_date: "2025-01-01"
data_quality: "clean"  # Options: clean, moderate, dirty

modules:
  - name: customers
    include: true

  - name: marketing_campaigns
    include: true
    channels: ["Email", "Paid Search", "Organic Social", "Affiliate"]
    campaign_types: ["Awareness", "Conversion", "Retention"]
    spend_range: [100, 10000]

  - name: leads
    include: true
    lead_quality_distribution: [0.3, 0.5, 0.2]  # low, medium, high

  - name: sales_funnel
    include: true
    funnel_stages: ["lead", "demo", "trial", "close"]
    conversion_rates: [0.6, 0.5, 0.4]  # Between stages

  - name: revenue
    include: true
    plan_types: ["Basic", "Pro", "Enterprise"]
    plan_distribution: [0.5, 0.3, 0.2]
    revenue_range: [20, 1000]
```

### Notes:
- **data_quality** introduces controlled errors: missing fields, duplicate IDs, invalid timestamps.
- **conversion_rates** define drop-off from one stage to the next.
- **include: false** can disable a module entirely.

---

## ✅ Setup Instructions (CLI or RStudio)

1. Clone the repo and open in RStudio.
2. Run the install script:
   ```r
   source("scripts/install_packages.R")
   ```
3. Create or modify your YAML in `yaml/`.
4. Run the generator:
   ```r
   source("scripts/generate_dataset.R")
   ```

Output files will appear in `data/output/`.

---

## ➕ Adding More Datasets

To add a new dataset:
1. Duplicate an existing `.yml` file in the `yaml/` folder.
2. Update the parameters (name, date range, etc.).
3. Run the script again.

The script automatically uses the YAML to generate module-specific `.csv` files in `data/output/{dataset_name}/`.

---

## 🛠 Example

Example call:
```r
# In RStudio Console
source("scripts/generate_dataset.R")  # Defaults to marketing.yml
```

To use a different YAML file:
```r
source("scripts/generate_dataset.R", local = list(config_file = "yaml/your_file.yml"))
```

---

## 🔜 Roadmap

Future enhancements may include:
- CLI runner
- Unit tests
- YAML validation
- GUI input form

---
