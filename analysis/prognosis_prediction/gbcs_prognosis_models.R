#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(haven)
  library(mice)
  library(survival)
  library(glmnet)
  library(splines)
  library(ggplot2)
})

set.seed(20260718)

input_file <- Sys.getenv("GBCS_INPUT_FILE", unset = "")
if (!nzchar(input_file)) {
  stop("Set GBCS_INPUT_FILE to the authorized local GBCS .sav file.")
}
output_dir <- file.path("analysis", "prognosis_prediction", "results")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

imputations <- as.integer(Sys.getenv("GBCS_IMPUTATIONS", "10"))
bootstrap_per_imputation <- as.integer(Sys.getenv("GBCS_BOOT_PER_IMPUTATION", "50"))
imputation_iterations <- as.integer(Sys.getenv("GBCS_MICE_ITERATIONS", "10"))
horizons <- c(60, 120)

source_variables <- c(
  "CLASSIFICATION", "诊断时间", "OS2023", "PFS2023", "死亡2023", "进展2023",
  "Age", "BMI_GROUP", "Menopause", "EDUCATION_GROUP", "PARITY",
  "BREASTFEEDING", "BCHISTORY", "RE_stage", "RE_HER2", "RE_ki67",
  "RE_ER", "RE_PR", "医院"
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
  diagnosis_year = as.integer(format(raw$诊断时间, "%Y")),
  hospital = factor_clean(raw$医院, c(1, 2, 3), c("Hospital 1", "Hospital 2", "Cancer Center")),
  os_time = num(raw$OS2023),
  os_event = num(raw$死亡2023),
  pfs_time = pmax(num(raw$PFS2023), 0.01),
  pfs_event = num(raw$进展2023),
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
stopifnot(sum(analysis_data$os_event) == 492L)
stopifnot(sum(analysis_data$pfs_event) == 810L)
stopifnot(all(analysis_data$pfs_time <= analysis_data$os_time + 1e-8))

# Reverse Kaplan-Meier follow-up distribution.
reverse_km <- function(time, event) {
  fit <- survfit(Surv(time, 1 - event) ~ 1)
  q <- quantile(fit, probs = c(0.25, 0.5, 0.75), conf.int = FALSE)
  data.frame(
    endpoint = deparse(substitute(time)),
    q1_months = unname(q[1]), median_months = unname(q[2]), q3_months = unname(q[3])
  )
}
followup_summary <- rbind(
  transform(reverse_km(analysis_data$os_time, analysis_data$os_event), endpoint = "OS"),
  transform(reverse_km(analysis_data$pfs_time, analysis_data$pfs_event), endpoint = "PFS")
)
write.csv(followup_summary, file.path(output_dir, "reverse_km_followup.csv"), row.names = FALSE)

# Missingness report before imputation.
missingness <- data.frame(
  variable = names(analysis_data),
  non_missing = vapply(analysis_data, function(x) sum(!is.na(x)), integer(1)),
  missing = vapply(analysis_data, function(x) sum(is.na(x)), integer(1)),
  missing_percent = 100 * vapply(analysis_data, function(x) mean(is.na(x)), numeric(1))
)
write.csv(missingness, file.path(output_dir, "predictor_missingness.csv"), row.names = FALSE)

# Include event indicators and Nelson-Aalen estimates in the imputation model.
imputation_data <- analysis_data
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
  imputation_data, m = imputations, maxit = imputation_iterations,
  method = method, predictorMatrix = predictor_matrix,
  seed = 20260718, printFlag = FALSE
)
completed <- lapply(seq_len(imputations), function(i) complete(imp, i))
remaining_missing <- lapply(completed, function(x) {
  vapply(x, function(z) sum(is.na(z)), integer(1))
})
remaining_missing <- do.call(rbind, remaining_missing)
write.csv(remaining_missing, file.path(output_dir, "post_imputation_missingness.csv"), row.names = FALSE)

age_knots <- as.numeric(quantile(analysis_data$age, c(1 / 3, 2 / 3), na.rm = TRUE))
age_boundaries <- range(analysis_data$age, na.rm = TRUE)
age_spline_term <- sprintf(
  "ns(age, knots = c(%.8f, %.8f), Boundary.knots = c(%.8f, %.8f))",
  age_knots[1], age_knots[2], age_boundaries[1], age_boundaries[2]
)
clinical_rhs <- paste(age_spline_term, "+ stage + er + pr + her2 + ki67")
extended_rhs <- paste(
  clinical_rhs,
  "+ bmi + menopause + education + parity + breastfeeding + family_history"
)
penalized_rhs <- extended_rhs

model_definitions <- list(
  clinical_cox = list(type = "cox", rhs = clinical_rhs),
  extended_cox = list(type = "cox", rhs = extended_rhs),
  elastic_net = list(type = "elastic", rhs = penalized_rhs)
)

endpoint_definitions <- list(
  PFS = c(time = "pfs_time", event = "pfs_event"),
  OS = c(time = "os_time", event = "os_event")
)

get_h0 <- function(base_fit, horizon) {
  bh <- basehaz(base_fit, centered = FALSE)
  available <- bh$hazard[bh$time <= horizon]
  if (length(available) == 0) 0 else max(available)
}

fit_prediction_model <- function(data, endpoint, definition, indices = seq_len(nrow(data))) {
  time_name <- unname(endpoint["time"])
  event_name <- unname(endpoint["event"])
  train <- data[indices, , drop = FALSE]

  if (definition$type == "cox") {
    formula <- as.formula(paste0(
      "Surv(", time_name, ",", event_name, ") ~ ", definition$rhs
    ))
    fit <- coxph(formula, data = train, x = TRUE, y = TRUE, model = TRUE)
    fit$coefficients[is.na(fit$coefficients)] <- 0
    return(list(type = "cox", fit = fit))
  }

  x_formula <- as.formula(paste0("~ ", definition$rhs, " - 1"))
  x_all <- model.matrix(x_formula, data = data)
  y_train <- Surv(train[[time_name]], train[[event_name]])
  cv <- cv.glmnet(
    x_all[indices, , drop = FALSE], y_train, family = "cox", alpha = 0.5,
    nfolds = 10, type.measure = "deviance"
  )
  beta <- as.numeric(coef(cv, s = "lambda.1se"))
  names(beta) <- rownames(coef(cv, s = "lambda.1se"))
  lp_train <- drop(x_all[indices, , drop = FALSE] %*% beta)
  baseline_data <- data.frame(
    time = train[[time_name]], event = train[[event_name]], lp = lp_train
  )
  baseline_fit <- coxph(Surv(time, event) ~ offset(lp), data = baseline_data)
  list(
    type = "elastic", beta = beta, x_formula = x_formula,
    baseline_fit = baseline_fit, lambda = cv$lambda.1se
  )
}

predict_model <- function(model, newdata, horizons) {
  if (model$type == "cox") {
    lp <- as.numeric(predict(model$fit, newdata = newdata, type = "lp", reference = "zero"))
    survival_predictions <- sapply(horizons, function(h) {
      exp(-get_h0(model$fit, h) * exp(lp))
    })
  } else {
    x <- model.matrix(model$x_formula, data = newdata)
    x <- x[, names(model$beta), drop = FALSE]
    lp <- drop(x %*% model$beta)
    survival_predictions <- sapply(horizons, function(h) {
      exp(-get_h0(model$baseline_fit, h) * exp(lp))
    })
  }
  if (length(horizons) == 1) survival_predictions <- matrix(survival_predictions, ncol = 1)
  colnames(survival_predictions) <- paste0("S", horizons)
  list(lp = lp, survival = survival_predictions)
}

km_survival <- function(time, event, at, censoring = FALSE) {
  fit <- survfit(Surv(time, if (censoring) 1 - event else event) ~ 1)
  as.numeric(summary(fit, times = at, extend = TRUE)$surv)
}

km_step_function <- function(time, event, censoring = FALSE) {
  fit <- survfit(Surv(time, if (censoring) 1 - event else event) ~ 1)
  stepfun(fit$time, c(1, fit$surv), right = TRUE)
}

ipcw_auc <- function(time, event, risk, horizon) {
  valid <- is.finite(time) & !is.na(event) & is.finite(risk)
  time <- time[valid]
  event <- event[valid]
  risk <- risk[valid]
  cases <- which(event == 1 & time <= horizon)
  controls <- which(time > horizon)
  if (length(cases) == 0 || length(controls) == 0) return(NA_real_)
  gfun <- km_step_function(time, event, TRUE)
  g_case <- gfun(pmax(time[cases] - 1e-8, 0))
  g_h <- gfun(horizon)
  w_case <- 1 / pmax(g_case, 1e-6)
  w_control <- rep(1 / pmax(g_h, 1e-6), length(controls))
  order_control <- order(risk[controls])
  control_risk <- risk[controls][order_control]
  control_weight <- w_control[order_control]
  cumulative <- cumsum(control_weight)
  total_control <- sum(control_weight)
  contribution <- numeric(length(cases))
  for (j in seq_along(cases)) {
    r <- risk[cases[j]]
    less <- findInterval(r, control_risk, left.open = TRUE)
    less_weight <- if (less == 0) 0 else cumulative[less]
    equal_weight <- sum(control_weight[control_risk == r])
    contribution[j] <- w_case[j] * (less_weight + 0.5 * equal_weight)
  }
  sum(contribution) / (sum(w_case) * total_control)
}

ipcw_brier <- function(time, event, predicted_survival, horizon) {
  valid <- is.finite(time) & !is.na(event) & is.finite(predicted_survival)
  time <- time[valid]
  event <- event[valid]
  predicted_survival <- predicted_survival[valid]
  gfun <- km_step_function(time, event, TRUE)
  g_h <- gfun(horizon)
  result <- numeric(length(time))
  event_before <- event == 1 & time <= horizon
  at_risk <- time > horizon
  if (any(event_before)) {
    g_event <- gfun(pmax(time[event_before] - 1e-8, 0))
    result[event_before] <- (predicted_survival[event_before]^2) / pmax(g_event, 1e-6)
  }
  result[at_risk] <- ((1 - predicted_survival[at_risk])^2) / pmax(g_h, 1e-6)
  mean(result)
}

calibration_slope <- function(time, event, lp) {
  valid <- is.finite(time) & !is.na(event) & is.finite(lp)
  time <- time[valid]
  event <- event[valid]
  lp <- lp[valid]
  fit <- try(coxph(Surv(time, event) ~ lp), silent = TRUE)
  if (inherits(fit, "try-error")) return(NA_real_)
  as.numeric(coef(fit)[1])
}

evaluate_model <- function(data, endpoint, prediction, horizons) {
  time <- data[[unname(endpoint["time"])]]
  event <- data[[unname(endpoint["event"])]]
  c_index <- concordance(Surv(time, event) ~ prediction$lp, reverse = TRUE)$concordance
  rows <- lapply(seq_along(horizons), function(j) {
    h <- horizons[j]
    predicted_survival <- prediction$survival[, j]
    observed_risk <- 1 - km_survival(time, event, h, FALSE)
    data.frame(
      horizon_months = h,
      c_index = c_index,
      auc = ipcw_auc(time, event, 1 - predicted_survival, h),
      brier = ipcw_brier(time, event, predicted_survival, h),
      calibration_slope = calibration_slope(time, event, prediction$lp),
      mean_predicted_risk = mean(1 - predicted_survival),
      observed_risk = observed_risk,
      calibration_in_large = mean(1 - predicted_survival) - observed_risk
    )
  })
  do.call(rbind, rows)
}

apparent_rows <- list()
calibration_rows <- list()
elastic_coefficients <- list()
fitted_models <- list()
row_id <- 1L

for (endpoint_name in names(endpoint_definitions)) {
  endpoint <- endpoint_definitions[[endpoint_name]]
  for (model_name in names(model_definitions)) {
    definition <- model_definitions[[model_name]]
    for (i in seq_len(imputations)) {
      data_i <- completed[[i]]
      model <- fit_prediction_model(data_i, endpoint, definition)
      prediction <- predict_model(model, data_i, horizons)
      metrics <- evaluate_model(data_i, endpoint, prediction, horizons)
      metrics$endpoint <- endpoint_name
      metrics$model <- model_name
      metrics$imputation <- i
      apparent_rows[[row_id]] <- metrics

      for (j in seq_along(horizons)) {
        h <- horizons[j]
        risk <- 1 - prediction$survival[, j]
        groups <- cut(
          rank(risk, ties.method = "first"),
          breaks = quantile(rank(risk, ties.method = "first"), seq(0, 1, 0.1)),
          include.lowest = TRUE, labels = FALSE
        )
        for (g in sort(unique(groups))) {
          selected <- groups == g
          calibration_rows[[length(calibration_rows) + 1L]] <- data.frame(
            endpoint = endpoint_name, model = model_name, imputation = i,
            horizon_months = h, decile = g, n = sum(selected),
            mean_predicted_risk = mean(risk[selected]),
            observed_risk = 1 - km_survival(
              data_i[[unname(endpoint["time"])]][selected],
              data_i[[unname(endpoint["event"])]][selected], h, FALSE
            )
          )
        }
      }

      if (model$type == "elastic") {
        elastic_coefficients[[length(elastic_coefficients) + 1L]] <- data.frame(
          endpoint = endpoint_name, imputation = i,
          term = names(model$beta), coefficient = model$beta,
          selected = as.integer(abs(model$beta) > 0), lambda = model$lambda
        )
      }
      fitted_models[[paste(endpoint_name, model_name, i, sep = "_")]] <- model
      row_id <- row_id + 1L
    }
  }
}

apparent <- do.call(rbind, apparent_rows)
calibration <- do.call(rbind, calibration_rows)
elastic_coef <- do.call(rbind, elastic_coefficients)
write.csv(apparent, file.path(output_dir, "apparent_performance_by_imputation.csv"), row.names = FALSE)
write.csv(calibration, file.path(output_dir, "calibration_deciles_by_imputation.csv"), row.names = FALSE)
write.csv(elastic_coef, file.path(output_dir, "elastic_net_coefficients_by_imputation.csv"), row.names = FALSE)

# Proportional-hazards diagnostics for the preferred clinical model.
ph_rows <- list()
for (endpoint_name in names(endpoint_definitions)) {
  for (i in seq_len(imputations)) {
    model <- fitted_models[[paste(endpoint_name, "clinical_cox", i, sep = "_")]]
    diagnostic <- cox.zph(model$fit, transform = "km")$table
    ph_rows[[length(ph_rows) + 1L]] <- data.frame(
      endpoint = endpoint_name, imputation = i, term = rownames(diagnostic),
      chisq = diagnostic[, "chisq"], degrees_freedom = diagnostic[, "df"],
      p_value = diagnostic[, "p"], row.names = NULL
    )
  }
}
ph_diagnostics <- do.call(rbind, ph_rows)
write.csv(ph_diagnostics, file.path(output_dir, "proportional_hazards_diagnostics.csv"), row.names = FALSE)

# Save a deployable, de-identified bundle of the 10 imputation-specific clinical models.
make_bundle_component <- function(model) {
  fit <- model$fit
  list(
    coefficients = coef(fit),
    terms = delete.response(fit$terms),
    xlevels = fit$xlevels,
    contrasts = fit$contrasts,
    basehaz = basehaz(fit, centered = FALSE)
  )
}
clinical_bundle <- list(
  model_name = "GBCS diagnosis-time clinical Cox model",
  version = "2026-07-18",
  units = "months",
  required_predictors = c("age", "stage", "er", "pr", "her2", "ki67"),
  allowed_levels = list(
    stage = c("I", "II", "III", "IV"), er = c("Negative", "Positive"),
    pr = c("Negative", "Positive"),
    her2 = c("Negative", "Equivocal", "Positive"), ki67 = c("<14%", ">=14%")
  ),
  age_knots = age_knots, age_boundaries = age_boundaries,
  endpoints = lapply(names(endpoint_definitions), function(endpoint_name) {
    lapply(seq_len(imputations), function(i) {
      make_bundle_component(fitted_models[[paste(endpoint_name, "clinical_cox", i, sep = "_")]])
    })
  })
)
names(clinical_bundle$endpoints) <- names(endpoint_definitions)
saveRDS(clinical_bundle, file.path(output_dir, "gbcs_clinical_model_bundle.rds"), compress = "xz")

# Pool unpenalized Cox coefficients with Rubin's rules.
pool_cox <- function(endpoint, rhs, model_name) {
  fits <- lapply(completed, function(data_i) {
    coxph(as.formula(paste0(
      "Surv(", endpoint["time"], ",", endpoint["event"], ") ~ ", rhs
    )), data = data_i)
  })
  terms <- names(coef(fits[[1]]))
  q <- sapply(fits, function(f) coef(f)[terms])
  u <- sapply(fits, function(f) diag(vcov(f))[terms])
  qbar <- rowMeans(q)
  ubar <- rowMeans(u)
  between <- apply(q, 1, var)
  total <- ubar + (1 + 1 / imputations) * between
  se <- sqrt(total)
  data.frame(
    model = model_name, term = terms, coefficient = qbar, standard_error = se,
    hazard_ratio = exp(qbar), ci_low = exp(qbar - 1.96 * se),
    ci_high = exp(qbar + 1.96 * se), p_value = 2 * pnorm(-abs(qbar / se))
  )
}

pooled_coefficients <- do.call(rbind, lapply(names(endpoint_definitions), function(endpoint_name) {
  endpoint <- endpoint_definitions[[endpoint_name]]
  rbind(
    transform(pool_cox(endpoint, clinical_rhs, "clinical_cox"), endpoint = endpoint_name),
    transform(pool_cox(endpoint, extended_rhs, "extended_cox"), endpoint = endpoint_name)
  )
}))
write.csv(pooled_coefficients, file.path(output_dir, "pooled_cox_coefficients.csv"), row.names = FALSE)

# Bootstrap optimism validation. Fifty replicates in each of ten imputations = 500 total.
bootstrap_rows <- list()
bootstrap_id <- 1L
for (endpoint_name in names(endpoint_definitions)) {
  endpoint <- endpoint_definitions[[endpoint_name]]
  for (model_name in names(model_definitions)) {
    definition <- model_definitions[[model_name]]
    for (i in seq_len(imputations)) {
      data_i <- completed[[i]]
      n <- nrow(data_i)
      for (b in seq_len(bootstrap_per_imputation)) {
        indices <- sample.int(n, n, replace = TRUE)
        model <- try(fit_prediction_model(data_i, endpoint, definition, indices), silent = TRUE)
        if (inherits(model, "try-error")) next
        train_data <- data_i[indices, , drop = FALSE]
        train_prediction <- try(predict_model(model, train_data, horizons), silent = TRUE)
        test_prediction <- try(predict_model(model, data_i, horizons), silent = TRUE)
        if (inherits(train_prediction, "try-error") || inherits(test_prediction, "try-error")) next
        train_metrics <- evaluate_model(train_data, endpoint, train_prediction, horizons)
        test_metrics <- evaluate_model(data_i, endpoint, test_prediction, horizons)
        for (j in seq_along(horizons)) {
          bootstrap_rows[[bootstrap_id]] <- data.frame(
            endpoint = endpoint_name, model = model_name, imputation = i,
            bootstrap = b, horizon_months = horizons[j],
            train_c_index = train_metrics$c_index[j], test_c_index = test_metrics$c_index[j],
            train_auc = train_metrics$auc[j], test_auc = test_metrics$auc[j],
            train_brier = train_metrics$brier[j], test_brier = test_metrics$brier[j],
            test_calibration_slope = test_metrics$calibration_slope[j]
          )
          bootstrap_id <- bootstrap_id + 1L
        }
      }
    }
  }
}
bootstrap_results <- do.call(rbind, bootstrap_rows)
write.csv(bootstrap_results, file.path(output_dir, "bootstrap_validation_replicates.csv"), row.names = FALSE)

aggregate_mean <- function(x) mean(x, na.rm = TRUE)
apparent_summary <- aggregate(
  cbind(c_index, auc, brier, calibration_slope, mean_predicted_risk, observed_risk, calibration_in_large) ~
    endpoint + model + horizon_months,
  data = apparent, FUN = aggregate_mean
)
optimism <- aggregate(
  cbind(
    c_optimism = train_c_index - test_c_index,
    auc_optimism = train_auc - test_auc,
    brier_degradation = test_brier - train_brier,
    validation_calibration_slope = test_calibration_slope
  ) ~ endpoint + model + horizon_months,
  data = bootstrap_results, FUN = aggregate_mean
)
validation_summary <- merge(apparent_summary, optimism, by = c("endpoint", "model", "horizon_months"))
validation_summary$corrected_c_index <- validation_summary$c_index - validation_summary$c_optimism
validation_summary$corrected_auc <- validation_summary$auc - validation_summary$auc_optimism
validation_summary$corrected_brier <- validation_summary$brier + validation_summary$brier_degradation
validation_summary$total_bootstrap_replicates <- imputations * bootstrap_per_imputation
write.csv(validation_summary, file.path(output_dir, "validated_model_performance.csv"), row.names = FALSE)

# Temporal validation (development through 2014; validation from 2015 onward).
temporal_rows <- list()
for (endpoint_name in names(endpoint_definitions)) {
  endpoint <- endpoint_definitions[[endpoint_name]]
  for (model_name in names(model_definitions)) {
    definition <- model_definitions[[model_name]]
    for (i in seq_len(imputations)) {
      data_i <- completed[[i]]
      train_indices <- which(data_i$diagnosis_year <= 2014)
      test_indices <- which(data_i$diagnosis_year >= 2015)
      model <- fit_prediction_model(data_i, endpoint, definition, train_indices)
      prediction <- predict_model(model, data_i[test_indices, , drop = FALSE], 60)
      metric <- evaluate_model(data_i[test_indices, , drop = FALSE], endpoint, prediction, 60)
      metric$endpoint <- endpoint_name
      metric$model <- model_name
      metric$imputation <- i
      metric$development_n <- length(train_indices)
      metric$validation_n <- length(test_indices)
      temporal_rows[[length(temporal_rows) + 1L]] <- metric
    }
  }
}
temporal <- do.call(rbind, temporal_rows)
write.csv(temporal, file.path(output_dir, "temporal_validation_by_imputation.csv"), row.names = FALSE)

# Internal-external validation by hospital for the extended Cox model.
hospital_rows <- list()
for (endpoint_name in names(endpoint_definitions)) {
  endpoint <- endpoint_definitions[[endpoint_name]]
  for (held_out in levels(analysis_data$hospital)) {
    for (i in seq_len(imputations)) {
      data_i <- completed[[i]]
      train_indices <- which(data_i$hospital != held_out)
      test_indices <- which(data_i$hospital == held_out)
      model <- fit_prediction_model(data_i, endpoint, model_definitions$extended_cox, train_indices)
      prediction <- predict_model(model, data_i[test_indices, , drop = FALSE], 60)
      metric <- evaluate_model(data_i[test_indices, , drop = FALSE], endpoint, prediction, 60)
      metric$endpoint <- endpoint_name
      metric$model <- "extended_cox"
      metric$held_out_hospital <- held_out
      metric$imputation <- i
      metric$development_n <- length(train_indices)
      metric$validation_n <- length(test_indices)
      hospital_rows[[length(hospital_rows) + 1L]] <- metric
    }
  }
}
hospital_validation <- do.call(rbind, hospital_rows)
write.csv(hospital_validation, file.path(output_dir, "internal_external_hospital_validation.csv"), row.names = FALSE)

# Apparent five-year decision curves; intended as exploratory only.
decision_curve_rows <- list()
thresholds <- seq(0.05, 0.50, by = 0.01)
for (endpoint_name in names(endpoint_definitions)) {
  endpoint <- endpoint_definitions[[endpoint_name]]
  for (model_name in names(model_definitions)) {
    for (i in seq_len(imputations)) {
      data_i <- completed[[i]]
      model <- fitted_models[[paste(endpoint_name, model_name, i, sep = "_")]]
      prediction <- predict_model(model, data_i, 60)
      risk <- 1 - prediction$survival[, 1]
      time <- data_i[[unname(endpoint["time"])] ]
      event <- data_i[[unname(endpoint["event"])] ]
      gfun <- km_step_function(time, event, TRUE)
      g_h <- gfun(60)
      cases <- event == 1 & time <= 60
      controls <- time > 60
      case_weights <- numeric(nrow(data_i))
      if (any(cases)) {
        case_weights[cases] <- 1 / pmax(gfun(pmax(time[cases] - 1e-8, 0)), 1e-6)
      }
      control_weights <- numeric(nrow(data_i))
      control_weights[controls] <- 1 / pmax(g_h, 1e-6)
      for (threshold in thresholds) {
        positive <- risk >= threshold
        tp <- sum(case_weights * positive) / nrow(data_i)
        fp <- sum(control_weights * positive) / nrow(data_i)
        net_benefit <- tp - fp * threshold / (1 - threshold)
        treat_all <- sum(case_weights) / nrow(data_i) -
          sum(control_weights) / nrow(data_i) * threshold / (1 - threshold)
        decision_curve_rows[[length(decision_curve_rows) + 1L]] <- data.frame(
          endpoint = endpoint_name, model = model_name, imputation = i,
          threshold = threshold, net_benefit = net_benefit,
          treat_all = treat_all, treat_none = 0
        )
      }
    }
  }
}
decision_curves <- do.call(rbind, decision_curve_rows)
write.csv(decision_curves, file.path(output_dir, "decision_curve_5year.csv"), row.names = FALSE)

# Aggregate calibration and create plots.
calibration_summary <- aggregate(
  cbind(mean_predicted_risk, observed_risk) ~ endpoint + model + horizon_months + decile,
  data = calibration, FUN = mean
)
write.csv(calibration_summary, file.path(output_dir, "calibration_deciles.csv"), row.names = FALSE)

calibration_plot <- ggplot(
  calibration_summary,
  aes(x = mean_predicted_risk, y = observed_risk, color = model, group = model)
) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, color = "grey50") +
  geom_line() + geom_point(size = 1.8) +
  facet_grid(endpoint ~ horizon_months, labeller = label_both) +
  coord_equal() +
  labs(x = "Mean predicted risk", y = "Kaplan-Meier observed risk", color = "Model") +
  theme_minimal(base_size = 11)
ggsave(file.path(output_dir, "calibration_plot.png"), calibration_plot, width = 9, height = 7, dpi = 180)

decision_summary <- aggregate(
  cbind(net_benefit, treat_all, treat_none) ~ endpoint + model + threshold,
  data = decision_curves, FUN = mean
)
decision_plot <- ggplot(decision_summary, aes(threshold, net_benefit, color = model)) +
  geom_line() +
  geom_line(aes(y = treat_all), color = "grey45", linetype = 2) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.3) +
  facet_wrap(~ endpoint, scales = "free_y") +
  labs(x = "Five-year risk threshold", y = "Net benefit", color = "Model") +
  theme_minimal(base_size = 11)
ggsave(file.path(output_dir, "decision_curve_5year.png"), decision_plot, width = 9, height = 4.8, dpi = 180)

# Compact model ranking and machine-readable summary.
temporal_summary <- aggregate(
  cbind(c_index, auc, brier, calibration_slope, calibration_in_large) ~ endpoint + model,
  data = temporal, FUN = mean
)
write.csv(temporal_summary, file.path(output_dir, "temporal_validation_summary.csv"), row.names = FALSE)

hospital_summary <- aggregate(
  cbind(c_index, auc, brier, calibration_slope, calibration_in_large) ~
    endpoint + held_out_hospital,
  data = hospital_validation, FUN = mean
)
write.csv(hospital_summary, file.path(output_dir, "hospital_validation_summary.csv"), row.names = FALSE)

elastic_summary <- aggregate(
  cbind(coefficient, selected) ~ endpoint + term,
  data = elastic_coef, FUN = mean
)
names(elastic_summary)[names(elastic_summary) == "selected"] <- "selection_proportion"
write.csv(elastic_summary, file.path(output_dir, "elastic_net_predictor_summary.csv"), row.names = FALSE)

writeLines(capture.output(sessionInfo()), file.path(output_dir, "session_info.txt"))

cat("Prognosis-model analysis completed.\n")
cat("Eligible invasive cohort:", nrow(analysis_data), "\n")
cat("PFS events:", sum(analysis_data$pfs_event), "OS events:", sum(analysis_data$os_event), "\n")
cat("Bootstrap replicates per model/endpoint:", imputations * bootstrap_per_imputation, "\n")
cat("Results directory:", normalizePath(output_dir), "\n")
