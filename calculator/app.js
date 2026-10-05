(function () {
  "use strict";

  const form = document.querySelector("#calculator-form");
  const ageInput = document.querySelector("#age");
  const ageField = ageInput.closest(".field");
  const ageError = document.querySelector("#age-error");
  const emptyState = document.querySelector("#result-empty");
  const resultContent = document.querySelector("#result-content");
  const gaugeFill = document.querySelector("#gauge-fill");
  const mortalityValue = document.querySelector("#mortality-value");
  const survivalValue = document.querySelector("#survival-value");
  const componentRange = document.querySelector("#component-range");
  const profileSummary = document.querySelector("#profile-summary");
  const resetButton = document.querySelector("#reset-button");

  function patientFromForm() {
    const data = new FormData(form);
    return Object.fromEntries(data.entries());
  }

  function percent(value) {
    return `${(value * 100).toFixed(1)}%`;
  }

  function clearError() {
    ageField.classList.remove("invalid");
    ageInput.removeAttribute("aria-invalid");
    ageError.textContent = "";
  }

  function showError(message) {
    ageField.classList.add("invalid");
    ageInput.setAttribute("aria-invalid", "true");
    ageError.textContent = message;
    resultContent.hidden = true;
    emptyState.hidden = false;
    ageInput.focus();
  }

  function render(patient, result) {
    mortalityValue.textContent = percent(result.mortality);
    survivalValue.textContent = percent(result.survival);
    componentRange.textContent = `${percent(result.componentMin)}–${percent(result.componentMax)}`;
    gaugeFill.style.strokeDasharray = `${Math.max(0, Math.min(100, result.mortality * 100))} 100`;
    const ki67Text = patient.ki67 === ">=14%" ? "≥14%" : "<14%";
    profileSummary.textContent = `Estimate for a ${patient.age}-year-old woman with stage ${patient.stage} disease, ER ${patient.er.toLowerCase()}, PR ${patient.pr.toLowerCase()}, HER2 ${patient.her2.toLowerCase()}, and Ki-67 ${ki67Text}.`;
    emptyState.hidden = true;
    resultContent.hidden = false;
  }

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    clearError();
    try {
      const patient = patientFromForm();
      const result = window.GBCSScoring.score(patient, window.GBCS_MODEL);
      render(patient, result);
    } catch (error) {
      showError(error.message);
    }
  });

  ageInput.addEventListener("input", clearError);
  resetButton.addEventListener("click", () => {
    form.reset();
    clearError();
    resultContent.hidden = true;
    emptyState.hidden = false;
    gaugeFill.style.strokeDasharray = "0 100";
    ageInput.focus();
  });
})();
