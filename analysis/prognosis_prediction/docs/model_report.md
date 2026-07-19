# Guangzhou Breast Cancer Cohort prognosis prediction models

## Executive conclusion

The finalized model is the **diagnosis-time clinical Cox model**, fitted separately for progression-free survival (PFS) and overall survival (OS). It uses age, stage, ER, PR, HER2, and Ki-67. It was selected because adding BMI, menopausal status, education, parity, breastfeeding, and family history produced no meaningful validated gain, while the elastic-net model was substantially underfit.

This is a research model with internal validation. It is not ready for clinical decision-making without independent external validation, local recalibration, and prospective impact assessment.

## Cohort and outcomes

- Source: 2023 follow-up database for the Guangzhou Breast Cancer Cohort.
- Eligibility: invasive breast cancer; diagnosis from 1 October 2008 through 31 January 2018; valid PFS and OS follow-up and event indicators.
- Analysis cohort: 4,231 patients.
- PFS events: 810 (19.1%).
- Deaths: 492 (11.6%).
- Reverse Kaplan–Meier follow-up for OS: median 94.06 months (7.84 years), IQR 73.17–129.38 months.
- Reverse Kaplan–Meier follow-up for PFS: median 94.13 months, IQR 73.26–129.58 months.

Five-year predictions are therefore better supported than 10-year predictions.

## Predictors and modeling

The final clinical model includes age as a restricted natural cubic spline with internal knots at ages 43 and 52 and boundaries at 19 and 97 years, plus stage (I–IV), ER, PR, HER2, and Ki-67. All predictors are available at diagnosis. Post-diagnosis treatment variables were excluded to prevent information leakage and to keep the prediction time origin clinically coherent.

Missing predictor data were handled using 10-fold multiple imputation by chained equations with 10 iterations, incorporating the survival outcome and Nelson–Aalen estimates in the imputation model. Before imputation, missingness was 0.2% for age, 11.6% for stage, 8.8% for ER, 9.0% for PR, 11.9% for HER2, and 15.3% for Ki-67. All model predictors were complete after imputation.

Three prespecified models were compared for each endpoint:

1. Clinical Cox model: age, stage, ER, PR, HER2, Ki-67.
2. Extended Cox model: clinical variables plus BMI, menopausal status, education, parity, breastfeeding, and family history.
3. Elastic-net Cox model using the extended predictor set and the one-standard-error penalty.

Performance used censoring-adjusted time-dependent AUC and Brier score. Internal validation used 50 bootstrap samples within each of 10 imputations, giving 500 bootstrap replicates per model and endpoint. Calibration, a temporal split (development through 2014; validation from 2015), and leave-one-hospital-out validation were also evaluated.

## Optimism-corrected performance

| Endpoint | Model | C-index | 5-year AUC | 5-year Brier | 10-year AUC | 10-year Brier | Validation slope |
|---|---|---:|---:|---:|---:|---:|---:|
| PFS | Clinical Cox | 0.690 | 0.713 | 0.109 | 0.689 | 0.154 | 0.976 |
| PFS | Extended Cox | 0.690 | 0.714 | 0.109 | 0.691 | 0.154 | 0.966 |
| PFS | Elastic net | 0.641 | 0.663 | 0.117 | 0.647 | 0.167 | 4.305 |
| OS | Clinical Cox | 0.749 | 0.775 | 0.061 | 0.755 | 0.105 | 0.970 |
| OS | Extended Cox | 0.752 | 0.778 | 0.061 | 0.760 | 0.105 | 0.957 |
| OS | Elastic net | 0.694 | 0.719 | 0.065 | 0.698 | 0.115 | 2.644 |

The extended model's gains were negligible: compared with the clinical model, its corrected C-index changed by less than 0.003 and its five-year AUC by less than 0.003. Its additional variables increase missing-data and implementation burden. The one-standard-error elastic net retained mainly stage, produced slopes far above 1, and underfit the data.

## Temporal and hospital validation

In the temporal validation set (patients diagnosed from 2015 onward; n=1,654), the clinical model achieved:

| Endpoint | C-index | 5-year AUC | 5-year Brier | Calibration slope | Calibration-in-the-large |
|---|---:|---:|---:|---:|---:|
| PFS | 0.699 | 0.725 | 0.108 | 0.957 | 0.003 |
| OS | 0.762 | 0.779 | 0.061 | 0.964 | 0.004 |

For the prespecified leave-one-hospital-out analysis of the extended model, five-year PFS C-indices were 0.693, 0.714, and 0.621 across the three hospitals. OS C-indices were 0.734, 0.745, and 0.737. The weaker PFS performance in Hospital 2 indicates transportability heterogeneity and reinforces the need for site-specific external validation.

## Predictor associations in the final clinical model

Stage was the dominant predictor. Relative to stage I, pooled hazard ratios were 1.41, 3.88, and 9.57 for PFS and 1.57, 5.09, and 15.83 for OS at stages II, III, and IV, respectively. PR positivity was associated with lower predicted hazard (PFS HR 0.78; OS HR 0.72), and Ki-67 ≥14% with higher hazard (PFS HR 1.33; OS HR 1.66). Age was modeled nonlinearly and should not be interpreted from individual spline coefficients.

These are prediction-model coefficients, not causal effects. In particular, apparent biomarker associations may reflect treatment patterns, measurement practices, and residual confounding.

## Diagnostics and limitations

- Calibration-in-the-large was close to zero and the clinical-model calibration curves were generally close to the 45-degree line.
- Schoenfeld-residual tests found global non-proportional hazards for both PFS and OS, particularly involving age and hormone-receptor variables. The Cox model is retained as prespecified because horizon-specific calibration was acceptable, but hazard ratios should not be interpreted as constant over follow-up. A flexible time-varying-effects model is an appropriate future sensitivity analysis.
- The decision-curve analysis is apparent rather than externally validated and is exploratory only.
- Ten-year estimates are less secure because median follow-up is under eight years.
- Outcome definitions and coding depend on the source database and should be adjudicated before clinical deployment.
- No independent external cohort was available. Bootstrap, temporal, and hospital hold-out analyses remain forms of internal validation.

## Using the saved model

The deployable model bundle contains no row-level patient data. It stores the coefficients and baseline hazards for all 10 imputation-specific clinical fits. The scoring function accepts one row per patient with the following columns and values:

- `age`: numeric, within the development range 19–97.
- `stage`: `I`, `II`, `III`, or `IV`.
- `er`, `pr`: `Negative` or `Positive`.
- `her2`: `Negative`, `Equivocal`, or `Positive`.
- `ki67`: `<14%` or `>=14%`.

Example:

```r
source("analysis/prognosis_prediction/score_gbcs_clinical_model.R")

new_patients <- data.frame(
  age = c(45, 62),
  stage = c("II", "III"),
  er = c("Positive", "Negative"),
  pr = c("Positive", "Negative"),
  her2 = c("Negative", "Positive"),
  ki67 = c(">=14%", ">=14%")
)

score_gbcs_model(new_patients, endpoint = "PFS", horizon_months = 60)
score_gbcs_model(new_patients, endpoint = "OS", horizon_months = 120)
```

The returned `predicted_risk` is averaged across the 10 imputation-specific models. `imputation_min` and `imputation_max` show the range across those models; they are not confidence intervals.
