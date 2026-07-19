#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(haven)
  library(mice)
  library(survival)
  library(splines)
  library(ggplot2)
})

set.seed(20260718)

# PREDICT v2.2 has the same five-year prognostic calculation as v2.1.
# Equations are from the official implementation and mathematical description:
# https://github.com/WintonCentre/predict-v21-r
# https://breast.predict.nhs.uk/predict-mathematics.pdf

input_file <- Sys.getenv("GBCS_INPUT_FILE", unset = "")
if (!nzchar(input_file)) {
  stop("Set GBCS_INPUT_FILE to the authorized local GBCS .sav file.")
}
output_dir <- file.path("analysis", "prognosis_prediction", "results")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

source_variables <- c(
  "CLASSIFICATION", "诊断时间", "OS2023", "PFS2023", "死亡2023", "进展2023",
  "Age", "BMI_GROUP", "Menopause", "EDUCATION_GROUP", "PARITY",
  "BREASTFEEDING", "BCHISTORY", "RE_stage", "RE_HER2", "RE_ki67",
  "RE_ER", "RE_PR", "医院", "K23A2", "K23B2", "K24", "RE_T", "RE_N", "RE_M"
)

raw <- read_sav(input_file, col_select = all_of(source_variables))
num <- function(x) as.numeric(zap_labels(x))

eligible <- (
  num(raw$CLASSIFICATION) == 1 &
    !is.na(raw$诊断时间) &
    raw$诊断时间 >= as.Date("2008-10-01") &
    raw$诊断时间 <= as.Date("2018-01-31") &
    !is.na(raw$OS2023) & !is.na(raw$死亡2023) &
    !is.na(raw$PFS2023) & !is.na(raw$进展2023) &
    num(raw$OS2023) >= 0 & num(raw$PFS2023) >= 0
)
eligible[is.na(eligible)] <- FALSE
raw <- raw[eligible, ]

factor_clean <- function(x, valid, labels) {
  x <- num(x)
  x[!x %in% valid] <- NA_real_
  factor(x, levels = valid, labels = labels)
}

family_history_raw <- num(raw$BCHISTORY)
family_history <- ifelse(
  family_history_raw == 0, 0,
  ifelse(family_history_raw %in% c(1, 2), 1, NA_real_)
)

analysis_data <- data.frame(
  row_id = seq_len(nrow(raw)),
  diagnosis_year = as.integer(format(raw$诊断时间, "%Y")),
  hospital = factor_clean(raw$医院, c(1, 2, 3), c("Hospital 1", "Hospital 2", "Cancer Center")),
  os_time = num(raw$OS2023), os_event = num(raw$死亡2023),
  pfs_time = pmax(num(raw$PFS2023), 0.01), pfs_event = num(raw$进展2023),
  age = num(raw$Age),
  stage = factor_clean(raw$RE_stage, 1:4, c("I", "II", "III", "IV")),
  er = factor_clean(raw$RE_ER, 0:1, c("Negative", "Positive")),
  pr = factor_clean(raw$RE_PR, 0:1, c("Negative", "Positive")),
  her2 = factor_clean(raw$RE_HER2, 0:2, c("Negative", "Equivocal", "Positive")),
  ki67 = factor_clean(raw$RE_ki67, 0:1, c("<14%", ">=14%")),
  bmi = factor_clean(raw$BMI_GROUP, 1:3, c("<23", "23-24.9", ">=25")),
  menopause = factor_clean(raw$Menopause, 1:2, c("Premenopausal", "Postmenopausal")),
  education = factor_clean(
    raw$EDUCATION_GROUP, 1:3,
    c("Junior school or below", "Senior high school", "College or above")
  ),
  parity = factor_clean(raw$PARITY, 1:2, c("Nulliparous", "Parous")),
  breastfeeding = factor_clean(raw$BREASTFEEDING, 0:1, c("No", "Yes")),
  family_history = factor(family_history, levels = 0:1, labels = c("No", "Yes"))
)

stopifnot(nrow(analysis_data) == 4231L)

# Reproduce the multiple-imputation data used for the local prognosis models.
imputation_data <- analysis_data[, setdiff(names(analysis_data), "row_id")]
imputation_data$na_os <- mice::nelsonaalen(imputation_data, "os_time", "os_event")
imputation_data$na_pfs <- mice::nelsonaalen(imputation_data, "pfs_time", "pfs_event")
method <- make.method(imputation_data)
method[c(
  "diagnosis_year", "hospital", "os_time", "os_event", "pfs_time", "pfs_event",
  "na_os", "na_pfs"
)] <- ""
method["age"] <- "pmm"
predictor_matrix <- make.predictorMatrix(imputation_data)
predictor_matrix[, c("diagnosis_year", "hospital", "na_os", "na_pfs")] <- 0
predictor_matrix[c(
  "diagnosis_year", "hospital", "os_time", "os_event", "pfs_time", "pfs_event",
  "na_os", "na_pfs"
), ] <- 0
diag(predictor_matrix) <- 0
imp <- mice(
  imputation_data, m = 10, maxit = 10, method = method,
  predictorMatrix = predictor_matrix, seed = 20260718, printFlag = FALSE
)
completed <- lapply(seq_len(10), function(i) complete(imp, i))

age_knots <- c(43, 52)
age_boundaries <- c(19, 97)
clinical_formula <- Surv(os_time, os_event) ~
  ns(age, knots = age_knots, Boundary.knots = age_boundaries) +
  stage + er + pr + her2 + ki67

get_h0 <- function(fit, horizon = 60) {
  bh <- basehaz(fit, centered = FALSE)
  available <- bh$hazard[bh$time <= horizon]
  if (length(available)) max(available) else 0
}

# Honest temporal predictions: fit through 2014 and evaluate diagnoses from 2015.
temporal_risk_by_imputation <- matrix(NA_real_, nrow(analysis_data), 10)
for (i in seq_len(10)) {
  data_i <- completed[[i]]
  train <- data_i$diagnosis_year <= 2014
  test <- data_i$diagnosis_year >= 2015
  fit <- coxph(clinical_formula, data = data_i[train, ], x = TRUE, y = TRUE)
  lp <- predict(fit, newdata = data_i[test, ], type = "lp", reference = "zero")
  temporal_risk_by_imputation[test, i] <- 1 - exp(-get_h0(fit, 60) * exp(lp))
}
local_temporal_risk <- rowMeans(temporal_risk_by_imputation, na.rm = TRUE)
local_temporal_risk[!is.finite(local_temporal_risk)] <- NA_real_

# Full-cohort fitted risks are used only for the small exact-input sensitivity analysis.
bundle <- readRDS(file.path(output_dir, "gbcs_clinical_model_bundle.rds"))
full_risk_by_imputation <- matrix(NA_real_, nrow(analysis_data), 10)
for (i in seq_len(10)) {
  component <- bundle$endpoints$OS[[i]]
  terms_i <- component$terms
  environment(terms_i) <- environment()
  design <- model.matrix(
    terms_i, data = completed[[i]], xlev = component$xlevels,
    contrasts.arg = component$contrasts
  )
  design <- design[, names(component$coefficients), drop = FALSE]
  lp <- drop(design %*% component$coefficients)
  h0 <- max(component$basehaz$hazard[component$basehaz$time <= 60])
  full_risk_by_imputation[, i] <- 1 - exp(-h0 * exp(lp))
}
local_full_risk <- rowMeans(full_risk_by_imputation)

predict_v22_survival_5y <- function(age, size_mm, grade, nodes, er, her2, ki67) {
  # Detection method is unavailable in GBCS. PREDICT's explicit unknown value is 0.204.
  screen <- rep(0.204, length(age))
  grade_model <- ifelse(grade %in% 1:3, grade, 2.13)
  grade_value <- ifelse(er == 1, grade_model, ifelse(grade_model %in% c(2, 3), 1, 0))

  age_mfp_1 <- ifelse(er == 1, (age / 10)^-2 - 0.0287449295, age - 56.3254902)
  age_beta_1 <- ifelse(er == 1, 34.53642, 0.0089827)
  age_mfp_2 <- ifelse(
    er == 1,
    (age / 10)^-2 * log(age / 10) - 0.0510121013,
    0
  )
  age_beta_2 <- ifelse(er == 1, -34.20342, 0)
  size_mfp <- ifelse(er == 1, log(size_mm / 100) + 1.545233938, sqrt(size_mm / 100) - 0.5090456276)
  size_beta <- ifelse(er == 1, 0.7530729, 2.093446)
  nodes_mfp <- ifelse(
    er == 1,
    log((nodes + 1) / 10) + 1.387566896,
    log((nodes + 1) / 10) + 1.086916249
  )
  nodes_beta <- ifelse(er == 1, 0.7060723, 0.6260541)
  grade_beta <- ifelse(er == 1, 0.746655, 1.129091)
  screen_beta <- ifelse(er == 1, -0.22763366, 0)
  her2_beta <- ifelse(her2 == 1, 0.2413, ifelse(her2 == 0, -0.0762, 0))
  ki67_beta <- ifelse(
    ki67 == 1 & er == 1, 0.14904,
    ifelse(ki67 == 0 & er == 1, -0.11333, 0)
  )
  pi <- age_beta_1 * age_mfp_1 + age_beta_2 * age_mfp_2 +
    size_beta * size_mfp + nodes_beta * nodes_mfp + grade_beta * grade_value +
    screen_beta * screen + her2_beta + ki67_beta

  t <- 5
  other_index <- 0.0698252 * ((age / 10)^2 - 34.23391957)
  h_other <- exp(-6.052919 + 1.079863 * log(t) + 0.3255321 * sqrt(t))
  h_breast <- ifelse(
    er == 1,
    exp(0.7424402 - 7.527762 / sqrt(t) - 1.812513 * log(t) / sqrt(t)),
    exp(-1.156036 + 0.4707332 / t^2 - 3.51355 / t)
  )
  exp(-exp(other_index) * h_other) * exp(-exp(pi) * h_breast)
}

# Map GBCS fields to PREDICT inputs.
predict_age <- num(raw$Age)
predict_er <- num(raw$RE_ER)
her2_raw <- num(raw$RE_HER2)
ki67_raw <- num(raw$RE_ki67)
grade_raw <- num(raw$K24)
predict_her2 <- ifelse(is.na(her2_raw), 9, ifelse(her2_raw == 2, 1, ifelse(her2_raw == 0, 0, 9)))
predict_ki67 <- ifelse(is.na(ki67_raw), 9, ifelse(ki67_raw == 1, 1, ifelse(ki67_raw == 0, 0, 9)))
predict_grade <- ifelse(is.na(grade_raw), 9, ifelse(grade_raw %in% 1:3, grade_raw, 9))
predict_m <- num(raw$RE_M)
predict_t <- num(raw$RE_T)
predict_n <- num(raw$RE_N)
exact_size <- num(raw$K23A2) * 10 # Recorded values are in centimetres.
exact_nodes <- num(raw$K23B2)

# Representative values for TNM categories, used only in the larger approximation analysis.
t_size_map <- c(`1` = 15, `2` = 35, `3` = 60, `4` = 50)
n_node_map <- c(`0` = 0, `1` = 1, `2` = 4, `3` = 10)
approx_size <- unname(t_size_map[as.character(predict_t)])
approx_nodes <- unname(n_node_map[as.character(predict_n)])
hybrid_size <- ifelse(is.finite(exact_size) & exact_size > 0, exact_size, approx_size)
hybrid_nodes <- ifelse(is.finite(exact_nodes) & exact_nodes >= 0, exact_nodes, approx_nodes)

base_predict_eligible <- is.finite(predict_age) & predict_age >= 25 & predict_age <= 85 &
  predict_er %in% 0:1 & predict_m == 0
base_predict_eligible[is.na(base_predict_eligible)] <- FALSE

temporal_approx <- base_predict_eligible & analysis_data$diagnosis_year >= 2015 &
  predict_t %in% 1:4 & predict_n %in% 0:3 &
  is.finite(local_temporal_risk)
temporal_approx[is.na(temporal_approx)] <- FALSE

exact_subset <- base_predict_eligible &
  is.finite(exact_size) & exact_size > 0 &
  is.finite(exact_nodes) & exact_nodes >= 0 &
  predict_grade %in% 1:3 & is.finite(local_full_risk)
exact_subset[is.na(exact_subset)] <- FALSE

predict_risk_approx <- 1 - predict_v22_survival_5y(
  predict_age, hybrid_size, predict_grade, hybrid_nodes,
  predict_er, predict_her2, predict_ki67
)
predict_risk_exact <- 1 - predict_v22_survival_5y(
  predict_age, exact_size, predict_grade, exact_nodes,
  predict_er, predict_her2, predict_ki67
)
temporal_approx <- temporal_approx & is.finite(predict_risk_approx)
exact_subset <- exact_subset & is.finite(predict_risk_exact)

km_survival <- function(time, event, at) {
  fit <- survfit(Surv(time, event) ~ 1)
  as.numeric(summary(fit, times = at, extend = TRUE)$surv)
}

km_step_function <- function(time, event) {
  fit <- survfit(Surv(time, 1 - event) ~ 1)
  stepfun(fit$time, c(1, fit$surv), right = TRUE)
}

ipcw_auc <- function(time, event, risk, horizon = 60) {
  cases <- which(event == 1 & time <= horizon)
  controls <- which(time > horizon)
  if (!length(cases) || !length(controls)) return(NA_real_)
  gfun <- km_step_function(time, event)
  w_case <- 1 / pmax(gfun(pmax(time[cases] - 1e-8, 0)), 1e-6)
  w_control <- rep(1 / pmax(gfun(horizon), 1e-6), length(controls))
  control_order <- order(risk[controls])
  control_risk <- risk[controls][control_order]
  control_weight <- w_control[control_order]
  cumulative <- cumsum(control_weight)
  contribution <- vapply(seq_along(cases), function(j) {
    r <- risk[cases[j]]
    less <- findInterval(r, control_risk, left.open = TRUE)
    less_weight <- if (less == 0) 0 else cumulative[less]
    equal_weight <- sum(control_weight[control_risk == r])
    w_case[j] * (less_weight + 0.5 * equal_weight)
  }, numeric(1))
  sum(contribution) / (sum(w_case) * sum(w_control))
}

ipcw_brier <- function(time, event, survival_probability, horizon = 60) {
  gfun <- km_step_function(time, event)
  result <- numeric(length(time))
  event_before <- event == 1 & time <= horizon
  at_risk <- time > horizon
  if (any(event_before)) {
    result[event_before] <- survival_probability[event_before]^2 /
      pmax(gfun(pmax(time[event_before] - 1e-8, 0)), 1e-6)
  }
  result[at_risk] <- (1 - survival_probability[at_risk])^2 / pmax(gfun(horizon), 1e-6)
  mean(result)
}

evaluate_risk <- function(time, event, risk) {
  observed_risk <- 1 - km_survival(time, event, 60)
  lp <- log(-log(pmax(1 - risk, 1e-8)))
  slope_fit <- try(coxph(Surv(time, event) ~ lp), silent = TRUE)
  data.frame(
    n = length(time), events_total = sum(event), events_5year = sum(event == 1 & time <= 60),
    auc_5year = ipcw_auc(time, event, risk),
    brier_5year = ipcw_brier(time, event, 1 - risk),
    calibration_slope = if (inherits(slope_fit, "try-error")) NA_real_ else as.numeric(coef(slope_fit)),
    mean_predicted_risk = mean(risk), observed_risk = observed_risk,
    calibration_in_large = mean(risk) - observed_risk
  )
}

comparison_data <- data.frame(
  time = analysis_data$os_time[temporal_approx],
  event = analysis_data$os_event[temporal_approx],
  local = local_temporal_risk[temporal_approx],
  predict = predict_risk_approx[temporal_approx]
)

main_metrics <- rbind(
  transform(evaluate_risk(comparison_data$time, comparison_data$event, comparison_data$local),
            analysis = "temporal_TN_approximation", model = "GBCS_clinical_Cox"),
  transform(evaluate_risk(comparison_data$time, comparison_data$event, comparison_data$predict),
            analysis = "temporal_TN_approximation", model = "PREDICT_v2.2_surgery_only")
)

exact_data <- data.frame(
  time = analysis_data$os_time[exact_subset], event = analysis_data$os_event[exact_subset],
  local = local_full_risk[exact_subset], predict = predict_risk_exact[exact_subset]
)
exact_metrics <- rbind(
  transform(evaluate_risk(exact_data$time, exact_data$event, exact_data$local),
            analysis = "full_cohort_exact_inputs", model = "GBCS_clinical_Cox"),
  transform(evaluate_risk(exact_data$time, exact_data$event, exact_data$predict),
            analysis = "full_cohort_exact_inputs", model = "PREDICT_v2.2_surgery_only")
)

all_metrics <- rbind(main_metrics, exact_metrics)
all_metrics <- all_metrics[, c("analysis", "model", setdiff(names(all_metrics), c("analysis", "model")))]
write.csv(all_metrics, file.path(output_dir, "predict_v22_5year_comparison.csv"), row.names = FALSE)

# Paired bootstrap on the honest temporal comparison.
bootstrap_rows <- vector("list", 500)
set.seed(20260718)
for (b in seq_len(500)) {
  index <- sample.int(nrow(comparison_data), replace = TRUE)
  d <- comparison_data[index, ]
  local_metric <- evaluate_risk(d$time, d$event, d$local)
  predict_metric <- evaluate_risk(d$time, d$event, d$predict)
  bootstrap_rows[[b]] <- data.frame(
    replicate = b,
    local_auc = local_metric$auc_5year,
    predict_auc = predict_metric$auc_5year,
    auc_difference_local_minus_predict = local_metric$auc_5year - predict_metric$auc_5year,
    local_brier = local_metric$brier_5year,
    predict_brier = predict_metric$brier_5year,
    brier_difference_local_minus_predict = local_metric$brier_5year - predict_metric$brier_5year
  )
}
bootstrap_results <- do.call(rbind, bootstrap_rows)
write.csv(bootstrap_results, file.path(output_dir, "predict_v22_5year_bootstrap.csv"), row.names = FALSE)

bootstrap_summary <- data.frame(
  metric = c("AUC: GBCS", "AUC: PREDICT", "AUC difference (GBCS - PREDICT)",
             "Brier: GBCS", "Brier: PREDICT", "Brier difference (GBCS - PREDICT)"),
  estimate = c(main_metrics$auc_5year, main_metrics$brier_5year)[c(1, 2, 1, 3, 4, 3)]
)
# Replace the compact construction above with exact named estimates.
bootstrap_summary$estimate <- c(
  main_metrics$auc_5year[main_metrics$model == "GBCS_clinical_Cox"],
  main_metrics$auc_5year[main_metrics$model == "PREDICT_v2.2_surgery_only"],
  diff(main_metrics$auc_5year[c(1, 2)]) * -1,
  main_metrics$brier_5year[main_metrics$model == "GBCS_clinical_Cox"],
  main_metrics$brier_5year[main_metrics$model == "PREDICT_v2.2_surgery_only"],
  main_metrics$brier_5year[1] - main_metrics$brier_5year[2]
)
bootstrap_columns <- c(
  "local_auc", "predict_auc", "auc_difference_local_minus_predict",
  "local_brier", "predict_brier", "brier_difference_local_minus_predict"
)
bootstrap_summary$ci_low <- vapply(bootstrap_columns, function(x) {
  quantile(bootstrap_results[[x]], 0.025, na.rm = TRUE)
}, numeric(1))
bootstrap_summary$ci_high <- vapply(bootstrap_columns, function(x) {
  quantile(bootstrap_results[[x]], 0.975, na.rm = TRUE)
}, numeric(1))
write.csv(bootstrap_summary, file.path(output_dir, "predict_v22_5year_bootstrap_summary.csv"), row.names = FALSE)

# Calibration plot for the temporal comparison.
calibration_rows <- list()
for (model_name in c("GBCS clinical Cox", "PREDICT v2.2 surgery only")) {
  risk <- if (model_name == "GBCS clinical Cox") comparison_data$local else comparison_data$predict
  groups <- cut(rank(risk, ties.method = "first"), breaks = 10, labels = FALSE)
  for (g in sort(unique(groups))) {
    selected <- groups == g
    calibration_rows[[length(calibration_rows) + 1L]] <- data.frame(
      model = model_name, decile = g, n = sum(selected),
      mean_predicted_risk = mean(risk[selected]),
      observed_risk = 1 - km_survival(comparison_data$time[selected], comparison_data$event[selected], 60)
    )
  }
}
calibration <- do.call(rbind, calibration_rows)
write.csv(calibration, file.path(output_dir, "predict_v22_5year_calibration.csv"), row.names = FALSE)

# Shared GBCS-risk deciles for a direct observed-versus-two-model comparison.
shared_decile <- cut(
  rank(comparison_data$local, ties.method = "first"),
  breaks = quantile(rank(comparison_data$local, ties.method = "first"), seq(0, 1, .1)),
  include.lowest = TRUE, labels = FALSE
)
shared_decile_data <- do.call(rbind, lapply(sort(unique(shared_decile)), function(g) {
  selected <- shared_decile == g
  data.frame(
    decile = g, n = sum(selected),
    gbcs_predicted_risk = mean(comparison_data$local[selected]),
    predict_predicted_risk = mean(comparison_data$predict[selected]),
    observed_risk = 1 - km_survival(
      comparison_data$time[selected], comparison_data$event[selected], 60
    )
  )
}))
write.csv(
  shared_decile_data,
  file.path(output_dir, "gbcs_predict_observed_by_shared_decile.csv"),
  row.names = FALSE
)

plot <- ggplot(calibration, aes(mean_predicted_risk, observed_risk, color = model)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, color = "grey50") +
  geom_line() + geom_point(size = 2) +
  coord_equal() +
  labs(x = "Mean predicted 5-year mortality risk", y = "Kaplan–Meier observed risk", color = NULL) +
  theme_minimal(base_size = 11)
ggsave(file.path(output_dir, "predict_v22_5year_calibration.png"), plot, width = 7.5, height = 5.5, dpi = 180)

# Publication histogram: patient-level predicted five-year mortality distributions.
histogram_data <- rbind(
  data.frame(model = "GBCS clinical Cox", predicted_risk = comparison_data$local),
  data.frame(model = "PREDICT v2.2 surgery only", predicted_risk = comparison_data$predict)
)
histogram_data$model <- factor(
  histogram_data$model,
  levels = c("GBCS clinical Cox", "PREDICT v2.2 surgery only")
)
observed_5y <- main_metrics$observed_risk[1]
mean_lines <- aggregate(predicted_risk ~ model, histogram_data, mean)

histogram_plot <- ggplot(histogram_data, aes(predicted_risk, fill = model)) +
  geom_histogram(
    aes(y = after_stat(count / sum(count))),
    binwidth = 0.025, boundary = 0, color = "white", linewidth = 0.2,
    show.legend = FALSE
  ) +
  geom_vline(xintercept = observed_5y, linetype = 2, color = "black", linewidth = 0.7) +
  geom_vline(
    data = mean_lines, aes(xintercept = predicted_risk, color = model),
    linewidth = 0.8, show.legend = FALSE
  ) +
  facet_wrap(~ model, ncol = 1) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 0.70)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    x = "Predicted five-year mortality risk",
    y = "Patients per risk interval",
    caption = paste0(
      "Dashed line: Kaplan–Meier observed risk (", scales::percent(observed_5y, accuracy = 0.1),
      "). Solid line: model mean predicted risk."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none", strip.text = element_text(face = "bold"))
ggsave(
  file.path(output_dir, "figure_prediction_risk_histograms.png"),
  histogram_plot, width = 8, height = 7, dpi = 300
)

# Aggregated bins for reusable visualizations; no row-level predictions are exported.
bin_breaks <- seq(0, 1, by = 0.025)
histogram_bins <- do.call(rbind, lapply(levels(histogram_data$model), function(model_name) {
  x <- histogram_data$predicted_risk[histogram_data$model == model_name]
  bin <- cut(x, breaks = bin_breaks, include.lowest = TRUE, right = FALSE, labels = FALSE)
  counts <- tabulate(bin, nbins = length(bin_breaks) - 1)
  data.frame(
    model = model_name,
    bin_lower = head(bin_breaks, -1), bin_upper = tail(bin_breaks, -1),
    bin_midpoint = (head(bin_breaks, -1) + tail(bin_breaks, -1)) / 2,
    count = counts, proportion = counts / length(x),
    mean_predicted_risk = mean(x), observed_risk = observed_5y
  )
}))
write.csv(
  histogram_bins, file.path(output_dir, "prediction_risk_histogram_bins.csv"),
  row.names = FALSE
)

coverage <- data.frame(
  analysis = c("Temporal validation with T/N approximation", "Exact-input sensitivity"),
  n = c(sum(temporal_approx), sum(exact_subset)),
  five_year_deaths = c(
    sum(analysis_data$os_event[temporal_approx] == 1 & analysis_data$os_time[temporal_approx] <= 60),
    sum(analysis_data$os_event[exact_subset] == 1 & analysis_data$os_time[exact_subset] <= 60)
  ),
  description = c(
    "Diagnosed 2015+, M0, age 25-85, ER known; exact size/nodes when available, otherwise representative T/N values",
    "M0, age 25-85, ER known, exact size, exact node count, and grade 1-3"
  )
)
write.csv(coverage, file.path(output_dir, "predict_v22_input_coverage.csv"), row.names = FALSE)

cat("PREDICT v2.2 five-year comparison completed.\n")
cat("Temporal approximation N:", sum(temporal_approx), "\n")
cat("Exact-input sensitivity N:", sum(exact_subset), "\n")
print(all_metrics)
