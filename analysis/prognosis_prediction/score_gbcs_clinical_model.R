# Score the finalized GBCS diagnosis-time clinical prognosis model.
#
# Example:
#   source("score_gbcs_clinical_model.R")
#   patients <- data.frame(
#     age = c(45, 62), stage = c("II", "III"),
#     er = c("Positive", "Negative"), pr = c("Positive", "Negative"),
#     her2 = c("Negative", "Positive"), ki67 = c(">=14%", ">=14%")
#   )
#   score_gbcs_model(patients, endpoint = "OS", horizon_months = 60)

.gbcs_scorer_file <- tryCatch(normalizePath(sys.frame(1)$ofile), error = function(e) NA_character_)
.gbcs_scorer_dir <- if (is.na(.gbcs_scorer_file)) getwd() else dirname(.gbcs_scorer_file)

score_gbcs_model <- function(
    newdata,
    endpoint = c("PFS", "OS"),
    horizon_months = 60,
    bundle_path = file.path(.gbcs_scorer_dir, "results", "gbcs_clinical_model_bundle.rds")) {
  endpoint <- match.arg(endpoint)
  horizon_months <- as.numeric(horizon_months)
  if (length(horizon_months) != 1L || !is.finite(horizon_months) || horizon_months <= 0) {
    stop("horizon_months must be one positive number (for example, 60 or 120).")
  }

  bundle <- readRDS(bundle_path)
  missing_columns <- setdiff(bundle$required_predictors, names(newdata))
  if (length(missing_columns)) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }

  scored <- newdata[, bundle$required_predictors, drop = FALSE]
  scored$age <- as.numeric(scored$age)
  if (anyNA(scored$age) || any(!is.finite(scored$age))) {
    stop("age must be numeric and non-missing.")
  }
  if (any(scored$age < bundle$age_boundaries[1] | scored$age > bundle$age_boundaries[2])) {
    stop(
      "age is outside the development range [",
      paste(bundle$age_boundaries, collapse = ", "), "]."
    )
  }

  for (variable in names(bundle$allowed_levels)) {
    invalid <- setdiff(unique(as.character(scored[[variable]])), bundle$allowed_levels[[variable]])
    invalid <- invalid[!is.na(invalid)]
    if (length(invalid)) {
      stop(
        "Invalid ", variable, " level(s): ", paste(invalid, collapse = ", "),
        ". Allowed: ", paste(bundle$allowed_levels[[variable]], collapse = ", ")
      )
    }
    scored[[variable]] <- factor(
      scored[[variable]], levels = bundle$allowed_levels[[variable]]
    )
    if (anyNA(scored[[variable]])) stop(variable, " must be non-missing.")
  }

  component_risks <- vapply(bundle$endpoints[[endpoint]], function(component) {
    ns <- splines::ns
    environment(component$terms) <- environment()
    design <- model.matrix(
      component$terms,
      data = scored,
      contrasts.arg = component$contrasts,
      xlev = component$xlevels
    )
    design <- design[, setdiff(colnames(design), "(Intercept)"), drop = FALSE]
    design <- design[, names(component$coefficients), drop = FALSE]
    linear_predictor <- drop(design %*% component$coefficients)
    eligible_baseline <- component$basehaz$time <= horizon_months
    cumulative_baseline_hazard <- if (any(eligible_baseline)) {
      max(component$basehaz$hazard[eligible_baseline])
    } else {
      0
    }
    1 - exp(-cumulative_baseline_hazard * exp(linear_predictor))
  }, numeric(nrow(scored)))

  if (is.null(dim(component_risks))) {
    component_risks <- matrix(component_risks, nrow = nrow(scored))
  }
  output <- data.frame(
    endpoint = endpoint,
    horizon_months = horizon_months,
    predicted_risk = rowMeans(component_risks),
    imputation_min = apply(component_risks, 1, min),
    imputation_max = apply(component_risks, 1, max)
  )
  row.names(output) <- row.names(newdata)
  output
}
