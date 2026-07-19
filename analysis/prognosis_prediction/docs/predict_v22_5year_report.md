# Five-year comparison with the online PREDICT Breast calculator

## Conclusion

For five-year overall survival, the Guangzhou Breast Cancer Cohort (GBCS) clinical Cox model and PREDICT v2.2 had similar discrimination in the temporal validation cohort. The GBCS model was much better calibrated to observed real-world survival. PREDICT v2.2's surgery-only calculation substantially overpredicted mortality because most cohort patients received systemic treatment and sufficiently detailed treatment data were unavailable for a reliable patient-level treatment adjustment.

The GBCS model should therefore remain the primary five-year prognosis model for this cohort. PREDICT is useful as an external discrimination benchmark, not as a replacement model on the present data mapping.

## Online-calculator verification

The supplied URL currently runs PREDICT Breast v2.2. The calculator was checked directly using this synthetic profile:

- Age 50, premenopausal
- ER positive, HER2 negative, Ki-67 positive
- 20 mm tumor, grade 2, zero positive nodes
- Detection method unknown
- No adjuvant treatment selected

The online calculator returned **95% five-year surgery-only overall survival**. The official open-source v2.2-equivalent equations returned 94.51%, which agrees after the website's whole-percentage rounding.

PREDICT v2.2 and v2.1 use the same five-year prognostic calculation; their difference in extended hormone therapy affects the longer horizon rather than this comparison.

## Primary comparison: temporal validation

The GBCS model was fitted only among patients diagnosed through 2014. Both models were then evaluated among eligible patients diagnosed from 2015 onward.

PREDICT is intended for early invasive, nonmetastatic breast cancer after surgery. The comparison was therefore restricted to M0 patients aged 25–85 with known ER status and recorded T and N categories. Exact tumor size and positive-node count were used when available. Otherwise, prespecified representative values were used:

- T1, T2, T3, T4: 15, 35, 60, and 50 mm
- N0, N1, N2, N3: 0, 1, 4, and 10 positive nodes

Unknown grade, HER2, Ki-67, and detection method used PREDICT's explicit unknown settings. The cohort Ki-67 threshold was ≥14%, whereas PREDICT defines positivity as >10%; cohort categories were mapped directly as an approximation.

The temporal comparison contained 1,371 patients and 77 deaths by five years.

| Measure | GBCS clinical Cox | PREDICT v2.2 surgery only |
|---|---:|---:|
| Five-year AUC | 0.752 | 0.758 |
| 95% bootstrap CI for AUC | 0.699–0.810 | 0.703–0.818 |
| Five-year Brier score | 0.0527 | 0.0752 |
| Calibration slope | 1.124 | 0.790 |
| Mean predicted five-year mortality | 6.46% | 17.16% |
| Kaplan–Meier observed mortality | 6.05% | 6.05% |
| Calibration-in-the-large | +0.41 percentage points | +11.11 percentage points |

The paired AUC difference for GBCS minus PREDICT was −0.006 (95% bootstrap CI −0.035 to 0.027), providing no evidence of a meaningful discrimination difference. The Brier-score difference was −0.0225 (95% CI −0.0293 to −0.0151), favoring GBCS, largely because PREDICT surgery-only risks were too high for this treated cohort.

## Exact-input sensitivity analysis

Only 148 patients had exact tumor size, exact positive-node count, grade 1–3, known ER, age 25–85, and M0 disease. There were only six deaths by five years, so these estimates are highly unstable and descriptive only.

| Measure | GBCS clinical Cox | PREDICT v2.2 surgery only |
|---|---:|---:|
| Five-year AUC | 0.767 | 0.730 |
| Five-year Brier score | 0.0392 | 0.0792 |
| Mean predicted mortality | 6.80% | 19.50% |
| Observed mortality | 4.26% | 4.26% |

The exact-input sensitivity analysis points in the same direction but cannot support a precise model comparison because of the very small number of events.

## Interpretation and limitations

- PREDICT v2.2 was developed for early invasive breast cancer after surgery and reports survival with different adjuvant-treatment combinations. The available cohort treatment variables did not reliably identify chemotherapy generation, hormone-therapy duration, trastuzumab exposure, and bisphosphonate treatment for all patients.
- Consequently, the PREDICT comparison used surgery-only survival. Its poor absolute calibration is expected in a treated cohort and must not be interpreted solely as geographic model failure.
- T/N-to-size/node conversion introduces measurement approximation. The small exact-input analysis was retained as a sensitivity check.
- Detection method was unavailable and set to unknown.
- The Ki-67 cutoffs do not align exactly.
- GBCS performance was assessed on a temporal validation subset but still within the same cohort system; independent external validation remains necessary.
- The supplied v2.2 page links to a newer PREDICT v3 model. A future comparison should use v3 if the required contemporary treatment and clinical inputs can be assembled reliably.

## Reproducible files

- Analysis: `compare_predict_v22_5year.R`
- Main and sensitivity metrics: `results/predict_v22_5year_comparison.csv`
- Bootstrap summary: `results/predict_v22_5year_bootstrap_summary.csv`
- Calibration data and plot: `results/predict_v22_5year_calibration.csv` and `results/predict_v22_5year_calibration.png`
- Input coverage: `results/predict_v22_input_coverage.csv`
