# Changelog

## 0.1.0-mvp — Initial MVP (Outlier Detection)
**Date:** 2025-08-25

### Added
- Core detectors: IQR, MAD, Isolation Forest (isotree), LOF (dbscan).
- Optional time-series detectors: tsoutliers, anomalize (STL), fable (ARIMA residuals).
- Config-driven runner with multi-dataset support (YAML).
- Per-dataset artifacts:
  - reports/<dataset>/outliers.csv
  - reports/<dataset>/diagnostics.json (per-column stats, thresholds, top flags, runtimes)
  - reports/<dataset>/summary.md
  - reports/<dataset>/summary.html (beta)
  - artifacts/<dataset>/rule_candidates.json
- Test harness (testthat), fixtures, and CI-friendly reports (tests/reports).

### Notes
- HTML report is beta: visuals and interactive tables are stable; styling/theme toggle included; minor layout and content polish to come.
- Isolation Forest sample size is auto-capped to avoid warnings; thresholds recorded in diagnostics JSON.

