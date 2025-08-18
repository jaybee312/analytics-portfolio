# PLANNING.md — Analytics Portfolio

## Purpose
A clear, step-by-step plan to build a polished analytics portfolio using:  
- **RStudio** for coding and rendering  
- **GitHub Desktop** for commits and pushes  

No terminal required. Each milestone ends with a rendered HTML deliverable visible on GitHub Pages or as raw HTML in the repo.  

---

## Final Repo Shape (Phase 1)

    analytics-portfolio/
    ├── rs-py-integration/
    │   ├── notebooks/
    │   ├── src/
    │   ├── data/
    │   ├── outputs/
    │   └── docs/
    ├── forecasting-framework/
    │   ├── notebooks/
    │   ├── src/
    │   ├── data/
    │   ├── outputs/
    │   └── docs/
    ├── attribution-roi/
    │   ├── notebooks/
    │   ├── src/
    │   ├── data/
    │   ├── outputs/
    │   └── docs/
    ├── synthetic-data-factory/
    │   ├── notebooks/
    │   ├── src/
    │   ├── data/
    │   ├── outputs/
    │   └── docs/
    ├── experiment-framework/
    │   ├── notebooks/
    │   ├── src/
    │   ├── data/
    │   ├── outputs/
    │   └── docs/
    ├── README.md
    ├── DELIVERABLES.txt
    ├── SCHEDULE.txt
    └── PLANNING.md

---

## Milestones

### Phase 0: Setup
- [ ] Create repo root with GitHub Desktop  
- [ ] Add `README.md`, `DELIVERABLES.txt`, `SCHEDULE.txt`, `PLANNING.md`  
- [ ] Create 5 project folders with subfolders (`notebooks`, `src`, `data`, `outputs`, `docs`)  
- [ ] Verify repo structure visible in GitHub  

### Phase 1: Minimal Deliverables
- [ ] Add one demo `.qmd` notebook to **rs-py-integration** showing R + Python chunk  
- [ ] Render to HTML in RStudio  
- [ ] Commit + push outputs and confirm HTML displays in repo  
- [ ] Repeat for one notebook each in the other 4 project folders (simple placeholder analysis)  

### Phase 2: Project Build-Out
- [ ] Flesh out **forecasting-framework** with a baseline time series model (R `forecast` or Python `prophet`)  
- [ ] Build synthetic data generator in **synthetic-data-factory** (use R’s `fakir` or Python’s `faker`)  
- [ ] Create attribution demo in **attribution-roi** (logistic regression or uplift modeling)  
- [ ] Add experimentation design doc + A/B test demo in **experiment-framework**  

### Phase 3: Presentation Polish
- [ ] Add consistent README.md to each subfolder  
- [ ] Include rendered HTML outputs in `/outputs`  
- [ ] Update top-level README with portfolio index linking to subprojects  
- [ ] Push all and verify repo navigates cleanly  

---

## Deliverables
- One rendered HTML file per project in `/outputs`  
- Notebooks (`.qmd`) in `/notebooks`  
- Reproducible synthetic datasets in `/data`  
- Explanatory README in each subfolder  

---

## Time Budget (Target: 60–80 hrs)
- Phase 0 (Setup): 5 hrs  
- Phase 1 (Minimal Deliverables): 10–12 hrs  
- Phase 2 (Project Build-Out): 35–45 hrs  
- Phase 3 (Presentation Polish): 10–15 hrs  

Buffer: 5–10 hrs for debugging + cleanup.  

---

## Notes
- Use **RStudio** as the main IDE for both R and Python (via reticulate).  
- Always render to HTML before committing.  
- Use **GitHub Desktop** for all commits/pushes (no CLI).  
