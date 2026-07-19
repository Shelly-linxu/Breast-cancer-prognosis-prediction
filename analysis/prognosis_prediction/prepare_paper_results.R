#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(haven)
  library(ggplot2)
  library(scales)
})

input_file <- Sys.getenv("GBCS_INPUT_FILE", unset = "")
if (!nzchar(input_file)) {
  stop("Set GBCS_INPUT_FILE to the authorized local GBCS .sav file.")
}
results_dir <- file.path("analysis", "prognosis_prediction", "results")
paper_dir <- file.path(results_dir, "paper_outputs")
dir.create(paper_dir, recursive = TRUE, showWarnings = FALSE)

vars <- c(
  "CLASSIFICATION", "诊断时间", "OS2023", "PFS2023", "死亡2023", "进展2023",
  "Age", "Menopause", "RE_stage", "RE_HER2", "RE_ki67", "RE_ER", "RE_PR", "医院"
)
raw <- read_sav(input_file, col_select = all_of(vars))
num <- function(x) as.numeric(zap_labels(x))
eligible <- num(raw$CLASSIFICATION) == 1 & !is.na(raw$诊断时间) &
  raw$诊断时间 >= as.Date("2008-10-01") & raw$诊断时间 <= as.Date("2018-01-31") &
  !is.na(raw$OS2023) & !is.na(raw$死亡2023) &
  !is.na(raw$PFS2023) & !is.na(raw$进展2023) &
  num(raw$OS2023) >= 0 & num(raw$PFS2023) >= 0
eligible[is.na(eligible)] <- FALSE
raw <- raw[eligible, ]
n_total <- nrow(raw)
stopifnot(n_total == 4231L)

diagnosis_year <- as.integer(format(raw$诊断时间, "%Y"))
age <- num(raw$Age)
os_event <- num(raw$死亡2023)
pfs_event <- num(raw$进展2023)

# Table 1: cohort characteristics and missingness.
table1 <- data.frame(
  characteristic = c(
    "Patients", "Age, mean (SD), years", "Age, median (IQR), years",
    "Diagnosis through 2014", "Diagnosis from 2015",
    "Five-year deaths", "Deaths during all follow-up",
    "Five-year PFS events", "PFS events during all follow-up"
  ),
  level = "",
  value = c(
    as.character(n_total),
    sprintf("%.1f (%.1f)", mean(age, na.rm = TRUE), sd(age, na.rm = TRUE)),
    sprintf("%.1f (%.1f–%.1f)", median(age, na.rm = TRUE), quantile(age, .25, na.rm = TRUE), quantile(age, .75, na.rm = TRUE)),
    sprintf("%d (%.1f%%)", sum(diagnosis_year <= 2014), 100 * mean(diagnosis_year <= 2014)),
    sprintf("%d (%.1f%%)", sum(diagnosis_year >= 2015), 100 * mean(diagnosis_year >= 2015)),
    sprintf("%d (%.1f%%)", sum(os_event == 1 & num(raw$OS2023) <= 60), 100 * mean(os_event == 1 & num(raw$OS2023) <= 60)),
    sprintf("%d (%.1f%%)", sum(os_event), 100 * mean(os_event)),
    sprintf("%d (%.1f%%)", sum(pfs_event == 1 & num(raw$PFS2023) <= 60), 100 * mean(pfs_event == 1 & num(raw$PFS2023) <= 60)),
    sprintf("%d (%.1f%%)", sum(pfs_event), 100 * mean(pfs_event))
  ),
  missing = c(0, sum(is.na(age)), sum(is.na(age)), rep(0, 6))
)

add_categorical <- function(label, x, valid, labels) {
  x <- num(x)
  clean <- ifelse(x %in% valid, x, NA_real_)
  counts <- table(factor(clean, levels = valid))
  data.frame(
    characteristic = label,
    level = labels,
    value = sprintf("%d (%.1f%%)", as.integer(counts), 100 * as.integer(counts) / n_total),
    missing = sum(is.na(clean))
  )
}

table1 <- rbind(
  table1,
  add_categorical("Hospital", raw$医院, 1:3, c("Hospital 1", "Hospital 2", "Cancer Center")),
  add_categorical("Stage", raw$RE_stage, 1:4, c("I", "II", "III", "IV")),
  add_categorical("ER status", raw$RE_ER, 0:1, c("Negative", "Positive")),
  add_categorical("PR status", raw$RE_PR, 0:1, c("Negative", "Positive")),
  add_categorical("HER2 status", raw$RE_HER2, 0:2, c("Negative", "Equivocal", "Positive")),
  add_categorical("Ki-67", raw$RE_ki67, 0:1, c("<14%", "≥14%")),
  add_categorical("Menopausal status", raw$Menopause, 1:2, c("Premenopausal", "Postmenopausal"))
)
write.csv(table1, file.path(paper_dir, "table1_cohort_characteristics.csv"), row.names = FALSE)

# Table 2: complete final-model coefficients.
coef_data <- read.csv(file.path(results_dir, "pooled_cox_coefficients.csv"), check.names = FALSE)
table2 <- coef_data[coef_data$model == "clinical_cox", c(
  "endpoint", "term", "coefficient", "standard_error", "hazard_ratio", "ci_low", "ci_high", "p_value"
)]
table2$term_label <- table2$term
table2$term_label <- sub("stage", "Stage ", table2$term_label, fixed = TRUE)
table2$term_label <- sub("erPositive", "ER positive", table2$term_label, fixed = TRUE)
table2$term_label <- sub("prPositive", "PR positive", table2$term_label, fixed = TRUE)
table2$term_label <- sub("her2Equivocal", "HER2 equivocal", table2$term_label, fixed = TRUE)
table2$term_label <- sub("her2Positive", "HER2 positive", table2$term_label, fixed = TRUE)
table2$term_label <- sub("ki67>=14%", "Ki-67 ≥14%", table2$term_label, fixed = TRUE)
table2$hr_95ci <- sprintf("%.2f (%.2f–%.2f)", table2$hazard_ratio, table2$ci_low, table2$ci_high)
table2$p_formatted <- ifelse(table2$p_value < .001, "<0.001", sprintf("%.3f", table2$p_value))
table2 <- table2[, c("endpoint", "term_label", "coefficient", "standard_error", "hr_95ci", "p_formatted", "term")]
write.csv(table2, file.path(paper_dir, "table2_final_model_coefficients.csv"), row.names = FALSE)

# Table 3: five-year model performance.
validated <- read.csv(file.path(results_dir, "validated_model_performance.csv"))
validated <- validated[validated$model == "clinical_cox" & validated$horizon_months == 60, ]
bootstrap_table <- data.frame(
  endpoint = validated$endpoint,
  validation = "Bootstrap optimism-corrected",
  c_index = validated$corrected_c_index,
  auc_5year = validated$corrected_auc,
  brier_5year = validated$corrected_brier,
  calibration_slope = validated$validation_calibration_slope,
  calibration_in_large = validated$calibration_in_large
)
temporal <- read.csv(file.path(results_dir, "temporal_validation_summary.csv"))
temporal <- temporal[temporal$model == "clinical_cox", ]
temporal_table <- data.frame(
  endpoint = temporal$endpoint,
  validation = "Temporal validation (diagnosis ≥2015)",
  c_index = temporal$c_index,
  auc_5year = temporal$auc,
  brier_5year = temporal$brier,
  calibration_slope = temporal$calibration_slope,
  calibration_in_large = temporal$calibration_in_large
)
table3 <- rbind(bootstrap_table, temporal_table)
table3 <- table3[order(table3$endpoint, table3$validation), ]
write.csv(table3, file.path(paper_dir, "table3_five_year_performance.csv"), row.names = FALSE)

# Table 4: external benchmark against PREDICT.
table4 <- read.csv(file.path(results_dir, "predict_v22_5year_comparison.csv"))
table4 <- table4[table4$analysis == "temporal_TN_approximation", ]
write.csv(table4, file.path(paper_dir, "table4_gbcs_predict_comparison.csv"), row.names = FALSE)

# Figure 1: observed risk bars with GBCS and PREDICT predictions in shared deciles.
decile_data <- read.csv(file.path(results_dir, "gbcs_predict_observed_by_shared_decile.csv"))
prediction_lines <- rbind(
  data.frame(decile = decile_data$decile, model = "GBCS", predicted_risk = decile_data$gbcs_predicted_risk),
  data.frame(decile = decile_data$decile, model = "PREDICT v2.2 surgery only", predicted_risk = decile_data$predict_predicted_risk)
)
prediction_lines$model <- factor(prediction_lines$model, levels = c("GBCS", "PREDICT v2.2 surgery only"))
figure1 <- ggplot() +
  geom_col(
    data = decile_data, aes(decile, observed_risk, fill = "Observed"),
    width = .72, color = "grey72"
  ) +
  geom_line(
    data = prediction_lines,
    aes(decile, predicted_risk, color = model, group = model), linewidth = .9
  ) +
  geom_point(
    data = prediction_lines,
    aes(decile, predicted_risk, color = model, shape = model), size = 2.7
  ) +
  scale_color_manual(values = c("GBCS" = "#3F77B5", "PREDICT v2.2 surgery only" = "#4DAF4A")) +
  scale_shape_manual(values = c("GBCS" = 16, "PREDICT v2.2 surgery only" = 15)) +
  scale_fill_manual(values = c("Observed" = "grey72")) +
  scale_x_continuous(breaks = 1:10) +
  scale_y_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, .06))) +
  labs(
    title = "Five-year all-cause mortality",
    x = "Decile of GBCS-predicted risk", y = "Five-year mortality risk",
    color = NULL, shape = NULL, fill = NULL
  ) +
  guides(
    color = guide_legend(order = 1), shape = guide_legend(order = 1),
    fill = guide_legend(order = 2)
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
    plot.title = element_text(hjust = .5, face = "bold"),
    legend.position = c(.17, .82), legend.background = element_blank()
  )
ggsave(file.path(paper_dir, "figure1_gbcs_predict_observed_by_decile.png"), figure1, width = 8, height = 5.5, dpi = 300)
ggsave(file.path(paper_dir, "figure1_prediction_risk_histograms.png"), figure1, width = 8, height = 5.5, dpi = 300)

# Figure 2: five-year calibration of the final GBCS models.
calibration <- read.csv(file.path(results_dir, "calibration_deciles.csv"))
calibration <- calibration[calibration$model == "clinical_cox" & calibration$horizon_months == 60, ]
calibration$endpoint <- factor(calibration$endpoint, levels = c("OS", "PFS"))
figure2 <- ggplot(calibration, aes(mean_predicted_risk, observed_risk, color = endpoint)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, color = "grey45") +
  geom_line(linewidth = .7) + geom_point(size = 2) +
  facet_wrap(~ endpoint, labeller = as_labeller(c(OS = "Overall survival", PFS = "Progression-free survival"))) +
  coord_equal() +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(x = "Mean predicted five-year risk", y = "Kaplan–Meier observed risk") +
  theme_minimal(base_size = 11) + theme(legend.position = "none", strip.text = element_text(face = "bold"))
ggsave(file.path(paper_dir, "figure2_five_year_calibration.png"), figure2, width = 8, height = 4.5, dpi = 300)

# Figure 3: temporal and bootstrap-corrected discrimination.
perf_long <- rbind(
  data.frame(endpoint = table3$endpoint, validation = table3$validation, metric = "C-index", value = table3$c_index),
  data.frame(endpoint = table3$endpoint, validation = table3$validation, metric = "Five-year AUC", value = table3$auc_5year)
)
perf_long$endpoint <- factor(perf_long$endpoint, levels = c("OS", "PFS"))
figure3 <- ggplot(perf_long, aes(value, validation, color = endpoint, shape = endpoint)) +
  geom_vline(xintercept = .5, linetype = 2, color = "grey55") +
  geom_point(size = 3) +
  facet_wrap(~ metric) +
  scale_x_continuous(limits = c(.5, .85), breaks = seq(.5, .85, .05)) +
  labs(x = "Discrimination", y = NULL, color = "Endpoint", shape = "Endpoint") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave(file.path(paper_dir, "figure3_validation_discrimination.png"), figure3, width = 8, height = 4.5, dpi = 300)

# A concise Markdown index for manuscript drafting.
writeLines(c(
  "# GBCS prognosis-model paper results package",
  "",
  "## Tables",
  "",
  "- Table 1: cohort characteristics, outcomes, and missingness.",
  "- Table 2: complete OS and PFS clinical Cox coefficients.",
  "- Table 3: bootstrap-corrected and temporal five-year performance.",
  "- Table 4: temporal comparison with PREDICT v2.2.",
  "",
  "## Figures",
  "",
  "- Figure 1: observed mortality bars with GBCS and PREDICT predictions by shared GBCS-risk decile.",
  "- Figure 2: five-year OS and PFS calibration.",
  "- Figure 3: bootstrap-corrected and temporal discrimination.",
  "",
  "Observed five-year mortality in the PREDICT-comparison subset was 6.05%. Mean predicted mortality was 6.46% for GBCS and 17.16% for PREDICT surgery-only."
), file.path(paper_dir, "README.md"))

cat("Paper tables and figures written to:", normalizePath(paper_dir), "\n")
