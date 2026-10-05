(function (root) {
  "use strict";

  function splineBasis(age, model) {
    const interval = model.spline_intervals.find((item, index, items) =>
      age >= item.left && (age <= item.right || index === items.length - 1)
    );
    if (!interval) throw new RangeError("Age is outside the model-supported range.");
    const t = age - interval.left;
    return [0, 1, 2].map((basisIndex) =>
      interval.coefficients.reduce(
        (total, coefficientRow, power) => total + coefficientRow[basisIndex] * (t ** power),
        0
      )
    );
  }

  function featureValue(name, patient, ageBasis) {
    if (name.startsWith("ns(age") && /[123]$/.test(name)) return ageBasis[Number(name.slice(-1)) - 1];
    if (name === "stageII") return patient.stage === "II" ? 1 : 0;
    if (name === "stageIII") return patient.stage === "III" ? 1 : 0;
    if (name === "stageIV") return patient.stage === "IV" ? 1 : 0;
    if (name === "erPositive") return patient.er === "Positive" ? 1 : 0;
    if (name === "prPositive") return patient.pr === "Positive" ? 1 : 0;
    if (name === "her2Equivocal") return patient.her2 === "Equivocal" ? 1 : 0;
    if (name === "her2Positive") return patient.her2 === "Positive" ? 1 : 0;
    if (name === "ki67>=14%") return patient.ki67 === ">=14%" ? 1 : 0;
    throw new Error(`Unsupported model coefficient: ${name}`);
  }

  function validatePatient(patient, model) {
    const age = Number(patient.age);
    if (!Number.isFinite(age)) throw new TypeError("Age is required.");
    if (age < model.age_boundaries[0] || age > model.age_boundaries[1]) {
      throw new RangeError(`Age must be between ${model.age_boundaries[0]} and ${model.age_boundaries[1]} years.`);
    }
    for (const field of ["stage", "er", "pr", "her2", "ki67"]) {
      if (!model.allowed_levels[field].includes(patient[field])) {
        throw new TypeError(`A valid ${field.toUpperCase()} value is required.`);
      }
    }
    return { ...patient, age };
  }

  function score(patient, model) {
    const valid = validatePatient(patient, model);
    const ageBasis = splineBasis(valid.age, model);
    const componentRisks = model.components.map((component) => {
      const linearPredictor = component.coefficients.reduce((total, coefficient, index) => {
        const feature = featureValue(component.coefficient_names[index], valid, ageBasis);
        return total + coefficient * feature;
      }, 0);
      return 1 - Math.exp(-component.baseline_hazard_60 * Math.exp(linearPredictor));
    });
    const mortality = componentRisks.reduce((a, b) => a + b, 0) / componentRisks.length;
    return {
      mortality,
      survival: 1 - mortality,
      componentMin: Math.min(...componentRisks),
      componentMax: Math.max(...componentRisks),
      componentRisks
    };
  }

  const api = { score, splineBasis, validatePatient };
  root.GBCSScoring = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);
