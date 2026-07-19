# GBCS breast cancer prognosis prediction

Code for the manuscript **Development and internal validation of a diagnosis-time model for five-year mortality after invasive breast cancer in South China: the Guangzhou Breast Cancer Study**.

The project develops and internally validates a five-year prognosis model using the Guangzhou Breast Cancer Study (GBCS), performs temporal and leave-one-hospital-out validation, benchmarks the model against PREDICT v2.2, prepares publication tables and figures, and builds the Word manuscript.

## Important status

This is research code. The model has not undergone independent external validation and is not ready for clinical decision-making. Bootstrap, temporal, and hospital hold-out analyses remain internal validation within the GBCS system. The PREDICT analysis is a benchmark comparison, not external validation.

No participant-level data are included in this repository. Access to the GBCS data is governed by cohort approvals and institutional requirements.

## Repository structure

```text
analysis/prognosis_prediction/
├── gbcs_prognosis_models.R        # Cohort construction, imputation, model fitting and validation
├── compare_predict_v22_5year.R   # Five-year comparison with PREDICT v2.2
├── prepare_paper_results.R        # Publication tables and figures
├── score_gbcs_clinical_model.R   # Scoring function for the saved model bundle
├── build_manuscript.py           # Word manuscript and study-flow figure builder
└── docs/
    ├── model_report.md
    ├── paper_protocol.md
    └── predict_v22_5year_report.md
```

Generated outputs are written to `analysis/prognosis_prediction/results/` and are intentionally excluded from version control.

## Analysis population and model

The locked analysis cohort contains 4,231 women with invasive breast cancer diagnosed from 1 October 2008 through 31 January 2018 and valid OS and PFS follow-up. The primary diagnosis-time Cox model uses:

- age at diagnosis, modeled with a natural cubic spline;
- AJCC stage I–IV;
- estrogen receptor status;
- progesterone receptor status;
- HER2 status; and
- Ki-67 status.

The primary outcome is five-year all-cause mortality. Five-year progression-free survival is secondary.

## Software requirements

R packages:

```r
install.packages(c(
  "haven", "mice", "survival", "glmnet", "ggplot2", "scales"
))
```

Python packages used to build the manuscript:

```bash
python3 -m pip install -r requirements.txt
```

The analysis was developed with R 4.x and Python 3.x. Exact R session information is written to the generated results directory after a run.

## Secure data configuration

Set `GBCS_INPUT_FILE` to the authorized local SPSS file. Do not copy the cohort dataset into this repository.

```bash
export GBCS_INPUT_FILE="/secure/path/to/gbcs_followup_2023.sav"
```

The scripts expect these source fields:

```text
CLASSIFICATION, 诊断时间, OS2023, PFS2023, 死亡2023, 进展2023,
Age, BMI_GROUP, Menopause, EDUCATION_GROUP, PARITY, BREASTFEEDING,
BCHISTORY, RE_stage, RE_HER2, RE_ki67, RE_ER, RE_PR, 医院
```

The PREDICT comparison additionally uses `K23A2`, `K23B2`, `K24`, `RE_T`, `RE_N`, and `RE_M`.

## Reproduce the analysis

Run all commands from the repository root.

### 1. Fit and validate the GBCS models

```bash
Rscript analysis/prognosis_prediction/gbcs_prognosis_models.R
```

The prespecified full run uses 10 imputations, 10 MICE iterations, and 50 bootstrap samples per imputation. These can be changed for code testing only:

```bash
GBCS_IMPUTATIONS=2 \
GBCS_MICE_ITERATIONS=2 \
GBCS_BOOT_PER_IMPUTATION=2 \
Rscript analysis/prognosis_prediction/gbcs_prognosis_models.R
```

Do not report reduced-run estimates as manuscript results.

### 2. Run the PREDICT v2.2 benchmark

```bash
Rscript analysis/prognosis_prediction/compare_predict_v22_5year.R
```

The comparison uses PREDICT v2.2 surgery-only survival because sufficiently detailed patient-level adjuvant-treatment inputs were unavailable. This limitation is essential when interpreting absolute-risk calibration.

### 3. Prepare paper tables and figures

```bash
Rscript analysis/prognosis_prediction/prepare_paper_results.R
```

This produces the main GBCS-versus-PREDICT figure, calibration and discrimination figures, and manuscript tables.

### 4. Build the manuscript

```bash
python3 analysis/prognosis_prediction/build_manuscript.py
```

The manuscript builder creates the participant-selection and validation flow diagram and writes the combined main manuscript and supplementary materials to `analysis/prognosis_prediction/results/paper_outputs/`. The generated submission draft places all main tables and figures after the references, followed by the supplementary methods, tables, and figures.

## Score the saved model

After the main analysis has produced `gbcs_clinical_model_bundle.rds`:

```r
source("analysis/prognosis_prediction/score_gbcs_clinical_model.R")

patients <- data.frame(
  age = c(45, 62),
  stage = c("II", "III"),
  er = c("Positive", "Negative"),
  pr = c("Positive", "Negative"),
  her2 = c("Negative", "Positive"),
  ki67 = c(">=14%", ">=14%")
)

score_gbcs_model(
  patients,
  endpoint = "OS",
  horizon_months = 60,
  bundle_path = "analysis/prognosis_prediction/results/gbcs_clinical_model_bundle.rds"
)
```

## Reproducibility and reporting notes

- Random seeds are fixed in the analysis scripts.
- Missing predictors are handled by multiple imputation by chained equations.
- Performance includes C-index, censoring-adjusted AUC, Brier score, calibration slope, and calibration-in-the-large.
- Internal validation uses bootstrap optimism correction, temporal validation, and leave-one-hospital-out analyses.
- The manuscript structure follows TRIPOD+AI principles and discusses PROBAST+AI considerations.
- Proportional-hazards diagnostics motivate a flexible time-varying-effect sensitivity analysis before journal submission.

## Data governance

Do not commit raw or participant-level GBCS data, model objects containing restricted information, credentials, or local data paths. The `.gitignore` blocks common clinical-data and generated-output formats as an additional safeguard.
