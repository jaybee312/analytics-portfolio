# R/Python Integration – REQUIREMENTS (Phase 1.0)

## Purpose
Demonstrate how R and Python can be used together in a single workflow.  
This project will highlight:
- **R strengths**: EDA, visualization, data cleaning  
- **Python strengths**: machine learning, clustering, numerical computing  
- **Integration**: A single Quarto report (`.qmd`) that runs both R and Python chunks seamlessly  

## Business Framing
Clustering is a common analytics technique to segment users or customers.  
This project simulates a **small customer segmentation task**:  
- R handles the initial data cleaning, summaries, and exploratory plots  
- Python runs a clustering algorithm (KMeans or similar)  
- R wraps up the results into a final narrative report  

The framing shows practical collaboration: analysts (R) + data scientists (Python).

## Inputs
- Synthetic dataset generated from the **Synthetic Data Factory** project  
  - Example: `users.csv` with demographics, transactions, engagement metrics  

## Deliverables
- `rs-py-integration/notebooks/demo_r_python.qmd`  
  - Sections:
    1. **Introduction**: What problem we’re solving  
    2. **EDA in R**: Cleaning, summaries, and ggplot visuals  
    3. **Model in Python**: Run clustering, show centroids, assign groups  
    4. **Wrap-up in R**: Aggregate cluster summaries, interpret results  
  - Rendered to HTML (`outputs/demo_r_python.html`)  

## Success Criteria
- HTML report renders fully in RStudio without errors  
- Both R and Python chunks execute successfully  
- Outputs include at least:
  - One R visualization  
  - One Python model result (cluster assignments)  
  - One R table/summary of Python outputs  
- Clear, business-style narrative (not just code dumps)

## Next Steps (Phase 2+)
- Add interactivity with Shiny or Plotly  
- Compare R-native clustering vs Python clustering  
- Package as a reproducible tutorial for onboarding new analysts  
