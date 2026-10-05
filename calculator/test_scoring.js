"use strict";

global.window = global;
require("./model.js");
const { score } = require("./scoring.js");

const tolerance = 1e-10;
const cases = [
  [{ age: 19, stage: "I", er: "Negative", pr: "Negative", her2: "Negative", ki67: "<14%" }, 0.03535081743626690],
  [{ age: 43, stage: "II", er: "Positive", pr: "Positive", her2: "Equivocal", ki67: ">=14%" }, 0.03810577905442242],
  [{ age: 52, stage: "III", er: "Negative", pr: "Positive", her2: "Positive", ki67: "<14%" }, 0.08435619015284986],
  [{ age: 97, stage: "IV", er: "Positive", pr: "Negative", her2: "Negative", ki67: ">=14%" }, 0.99954717739383769],
  [{ age: 50, stage: "II", er: "Positive", pr: "Positive", her2: "Negative", ki67: ">=14%" }, 0.04339733752890027],
  [{ age: 63, stage: "I", er: "Negative", pr: "Negative", her2: "Positive", ki67: "<14%" }, 0.03416719527395744]
];

for (const [patient, expected] of cases) {
  const actual = score(patient, global.GBCS_MODEL).mortality;
  const difference = Math.abs(actual - expected);
  if (difference > tolerance) {
    throw new Error(`Scoring mismatch for ${JSON.stringify(patient)}: ${actual} versus ${expected}`);
  }
}

for (const invalidAge of [18, 98, ""] ) {
  let failed = false;
  try {
    score({ ...cases[0][0], age: invalidAge }, global.GBCS_MODEL);
  } catch (_error) {
    failed = true;
  }
  if (!failed) throw new Error(`Invalid age was accepted: ${JSON.stringify(invalidAge)}`);
}

console.log(`Validated ${cases.length} R-reference profiles and invalid-age handling.`);
