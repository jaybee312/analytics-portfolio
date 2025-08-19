# Data Factory – Roadmap (Parked Until Portfolio Pass)

## High Priority (revisit later)
1. make deps target (auto-install required R packages)
2. Parquet & DuckDB outputs alongside CSV
3. Usage realism: weekday/seasonality + cohort adoption
4. Channel conversion ladder: impr → click → lead → MQL → SQL → opp → won
5. Plan-aware revenue: ACV + win-rate by plan_type/segment
6. Config flags: toggle NPS/usage/organic in YAML
7. CI: GitHub Action running `make run && make test` on push

## Medium
- Schema contracts (JSON Schema) + strict validator
- Seed strategy for reproducible variants
- Writers (optionally S3/local partitioning)
- Profiling to size N vs. speed

## Nice-to-haves
- Synthetic free-text (NPS comments, tickets)
- Anomaly switches (outliers/season shocks)
- Auto data dictionary from schemas
