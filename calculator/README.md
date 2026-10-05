# GBCS 5-year OS Calculator

This directory contains the browser-only implementation of the locked Guangzhou Breast Cancer Study diagnosis-time clinical Cox model for five-year all-cause mortality.

## Use locally

Open `index.html` directly, or serve this directory with any static web server. No application server, database, package installation, or build step is required.

## Model inputs

- age at diagnosis (19–97 years)
- AJCC overall stage at initial diagnosis (I–IV)
- ER status
- PR status
- HER2 status
- Ki-67 (`<14%` or `≥14%`)

The calculator reports estimated five-year all-cause mortality, estimated five-year overall survival, and the range across the 10 imputed model fits. It refuses to calculate when a required value is unavailable or age is outside the model-supported range.

## Privacy

All calculations occur locally in the browser. The page has no analytics, sends no patient information, stores no patient information, and places no inputs in the URL.

## Rebuild model parameters

`model.js` and `model.json` contain model parameters only; neither contains participant-level data. Regenerate the browser model from the locked R object with:

```bash
Rscript analysis/prognosis_prediction/export_static_calculator_model.R \
  /path/to/gbcs_clinical_model_bundle.rds \
  calculator/model.js
```

## Verify scoring parity

The reference test covers the model age boundaries, both internal spline knots, stages I–IV, every biomarker category, and invalid-age handling. Its expected values were generated with `score_gbcs_clinical_model.R` from the locked R model.

```bash
node calculator/test_scoring.js
```

## Intended use

Research use only. Independent external validation and clinical-impact evaluation remain necessary. The result must not be used alone to select treatment, alter follow-up, or replace clinical judgement.
