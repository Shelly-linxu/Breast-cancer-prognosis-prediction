# Brief protocol: GBCS five-year breast-cancer prognosis model paper

## Proposed title

**Development and internal validation of a diagnosis-time model for five-year prognosis after invasive breast cancer in South China: the Guangzhou Breast Cancer Study**

Describe the study as model development with internal, temporal, and internal–external validation. Do not call the hospital hold-outs or the PREDICT comparison independent external validation.

## Step-by-step protocol

### 1. State the clinical question

Develop a parsimonious model, using routinely available diagnosis-time variables, to predict five-year overall mortality among women with invasive breast cancer in the GBCS. Make five-year OS the primary outcome. Present five-year PFS as a secondary model.

Target population: women with newly diagnosed invasive breast cancer in South China. Prediction time: date of diagnosis. Intended use: prognosis discussion and selection of patients for enhanced follow-up, initially for research rather than direct treatment decisions.

### 2. Freeze the analysis specification

Use the existing locked cohort and version the code and output before manuscript drafting. Prespecify eligibility, predictor coding, outcomes, missing-data methods, validation procedures, and performance measures. Follow TRIPOD+AI for reporting and complete a PROBAST+AI self-assessment.

### 3. Describe participants and construct the flow diagram

Start with the GBCS cohort described in the published cohort profile. Include invasive cancers diagnosed from 1 October 2008 to 31 January 2018 with valid survival follow-up. Report all exclusions and arrive at the analysis cohort of 4,231 patients.

Report recruitment hospitals, diagnosis period, follow-up schedule, loss to follow-up, censoring date, 810 PFS events, 492 deaths, and reverse Kaplan–Meier follow-up: median 94.1 months (7.84 years), IQR 73.2–129.4 months.

### 4. Define outcomes precisely

Primary outcome: all-cause mortality within five years of diagnosis. Secondary outcome: progression or death within five years, using the database PFS definition. State how recurrence, metastasis, death, censoring, and event dates were ascertained. Explain whether outcome adjudicators were blinded to predictors.

### 5. Define predictors without outcome-driven selection

Primary clinical model: age, AJCC stage, ER, PR, HER2, and Ki-67, all available at diagnosis. Model age continuously with the prespecified natural spline knots at 43 and 52 years. Retain all predictors regardless of individual P values. Do not use univariable screening.

Explain why post-diagnosis treatment variables were excluded: they occur after the prediction time and would introduce treatment-policy dependence or information leakage.

### 6. Address sample size and missing data

Justify sample size using the number of participants, events, and predictor parameters rather than only the “10 events per variable” rule. Report missingness for every predictor. Use 10-fold multiple imputation by chained equations, including the event indicator and Nelson–Aalen estimate in the imputation model. Add complete-case analysis as a sensitivity analysis.

### 7. Develop and compare models

Fit separate Cox models for OS and PFS. Compare:

1. Primary clinical Cox model.
2. Extended Cox model adding BMI, menopause, education, parity, breastfeeding, and family history.
3. Elastic-net Cox model as a secondary benchmark.

Select the final model using validated discrimination, calibration, prediction error, parsimony, and usability—not statistical significance. The current evidence supports selecting the clinical Cox model because the extended model adds negligible performance and elastic net underfits.

### 8. Validate model performance

Use 500 bootstrap replicates per model and endpoint for optimism correction. Report:

- Harrell C-index.
- IPCW five-year AUC.
- IPCW Brier score.
- Calibration-in-the-large and calibration slope.
- Smoothed or grouped five-year calibration plots.
- Decision-curve analysis across clinically defensible thresholds.

Present the temporal validation using diagnoses through 2014 for development and diagnoses from 2015 onward for validation. Present leave-one-hospital-out validation and explicitly discuss the weaker PFS transportability in Hospital 2.

### 9. Perform required sensitivity analyses

Before submission, address the significant proportional-hazards diagnostics. Fit a flexible parametric survival model or Cox model with prespecified time-varying effects for age and receptor variables, then compare five-year calibration and discrimination with the primary Cox model. Retain Cox only if absolute five-year predictions remain stable.

Also assess complete cases, exclusion of stage IV disease, hospital-specific calibration, diagnosis-period effects, and clinically important subgroups defined by age, stage, and molecular phenotype. Label subgroup analyses exploratory and avoid multiple significance testing.

### 10. Benchmark against PREDICT appropriately

Report PREDICT v2.2 as a benchmark, not an external validation of GBCS. In the 1,371-patient temporal comparison, five-year AUCs were 0.752 for GBCS and 0.758 for PREDICT; the paired difference was −0.006 (95% bootstrap CI −0.035 to 0.027).

Explain that PREDICT surgery-only risk overestimated mortality because complete treatment inputs were unavailable. Report the T/N approximations, detection set to unknown, and Ki-67 threshold mismatch. Do not use this calibration comparison to claim superiority over a fully treatment-adjusted PREDICT model.

### 11. Report the complete model

Publish all regression coefficients, spline specification, factor reference levels, baseline survival or cumulative baseline hazard at 60 months, and the exact five-year risk equation. Provide the R scoring code and a de-identified model object. Include an example patient calculation. State that the model is not ready for clinical use without independent external validation and impact evaluation.

### 12. Structure the manuscript and supplements

Main paper:

- Introduction: need for locally calibrated, diagnosis-time prognosis models in Chinese patients; study objective.
- Methods: cohort, outcomes, predictors, missing data, modeling, validation, PREDICT comparison, ethics.
- Results: participant flow, baseline data, model specification, performance, calibration, sensitivity analyses.
- Discussion: main findings, comparison with PREDICT and Chinese nomograms, strengths, limitations, transportability, future external validation.

Essential displays:

- Figure 1: participant flow.
- Figure 2: five-year OS and PFS calibration.
- Figure 3: temporal and hospital validation forest plot.
- Figure 4: decision curves or PREDICT comparison.
- Table 1: cohort characteristics and missingness.
- Table 2: final model coefficients and full equation.
- Table 3: apparent and optimism-corrected performance.
- Table 4: temporal, hospital, and PREDICT comparisons.
- Supplement: TRIPOD+AI checklist, PROBAST+AI self-assessment, imputation details, diagnostics, sensitivity analyses, code, and model object.

## Publication readiness decision

The analysis is suitable for a model-development manuscript after three additions: a time-varying-effects/flexible-survival sensitivity analysis, a formal sample-size justification, and a complete TRIPOD+AI/PROBAST+AI package. Independent external validation should be a separate subsequent study unless a suitable non-GBCS cohort becomes available before submission.
