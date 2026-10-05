# Export the finalized GBCS five-year OS model to a browser-readable JSON file.
#
# The exported file contains model parameters only. It contains no participant-level data.

args <- commandArgs(trailingOnly = TRUE)
bundle_path <- if (length(args) >= 1L) args[[1L]] else {
  file.path("analysis", "prognosis_prediction", "results", "gbcs_clinical_model_bundle.rds")
}
output_path <- if (length(args) >= 2L) args[[2L]] else {
  file.path("calculator", "model.json")
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The jsonlite package is required to export the calculator model.")
}

bundle <- readRDS(bundle_path)

# Each natural-spline basis column is a cubic polynomial between adjacent knots.
# Export local polynomial coefficients so the browser can reproduce splines::ns
# without an R runtime or an external JavaScript dependency.
boundaries <- bundle$age_boundaries
knots <- bundle$age_knots
breaks <- c(boundaries[1L], knots, boundaries[2L])

spline_intervals <- lapply(seq_len(length(breaks) - 1L), function(i) {
  left <- breaks[[i]]
  right <- breaks[[i + 1L]]
  width <- right - left
  t_values <- c(0, width / 3, 2 * width / 3, width)
  ages <- left + t_values
  basis <- splines::ns(
    ages,
    knots = knots,
    Boundary.knots = boundaries,
    intercept = FALSE
  )
  design <- cbind(1, t_values, t_values^2, t_values^3)
  coefficients <- solve(design, basis)
  list(
    left = unname(left),
    right = unname(right),
    coefficients = unname(split(coefficients, row(coefficients)))
  )
})

export_component <- function(component) {
  eligible <- component$basehaz$time <= 60
  baseline_hazard <- if (any(eligible)) {
    max(component$basehaz$hazard[eligible])
  } else {
    0
  }
  list(
    coefficients = as.list(unname(component$coefficients)),
    coefficient_names = names(component$coefficients),
    baseline_hazard_60 = unname(baseline_hazard)
  )
}

payload <- list(
  model_name = bundle$model_name,
  version = bundle$version,
  endpoint = "Five-year all-cause mortality",
  horizon_months = 60,
  required_predictors = bundle$required_predictors,
  allowed_levels = bundle$allowed_levels,
  age_knots = unname(bundle$age_knots),
  age_boundaries = unname(bundle$age_boundaries),
  spline_intervals = spline_intervals,
  components = lapply(bundle$endpoints$OS, export_component)
)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
json <- jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE, digits = 16)
if (grepl("\\.js$", output_path, ignore.case = TRUE)) {
  writeLines(c("window.GBCS_MODEL = ", json, ";"), output_path, useBytes = TRUE)
} else {
  writeLines(json, output_path, useBytes = TRUE)
}
message("Wrote model parameters to ", normalizePath(output_path))
