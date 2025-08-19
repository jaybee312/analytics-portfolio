# Adding a New Dataset

## 1) Config
Create `config/datasets/<dataset>.yml` with:
- start_date, end_date, seed
- population sizes/mixes
- domain knobs (rates, channels, etc.)

## 2) Module
Create `R/modules/<dataset>/` with:
- build_dataset.R  (writes tables to outputs/<dataset>/)
- one file per table generator

## 3) Orchestrator
Edit `R/main.R` -> add a new `switch()` arm for `<dataset>` to source your builder and call `build_<dataset>_dataset(cfg, out_dir)`.

## 4) (Optional) Validator
Add `validate_<dataset>_schema()` in `R/utils/validate.R`.

## 5) Run
Rscript R/main.R --dataset <dataset> --config config/datasets/<dataset>.yml --out outputs/<dataset> --seed 123

## 6) Test
Copy tests/test_template.R → tests/test_<dataset>.R and update names/paths.
