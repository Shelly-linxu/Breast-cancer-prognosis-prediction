"use strict";

const { chromium } = require("playwright");
const path = require("path");

(async () => {
  const output = path.join(__dirname, "calculator-preview.png");
  const launchOptions = { headless: true };
  if (process.env.CHROME_EXECUTABLE) launchOptions.executablePath = process.env.CHROME_EXECUTABLE;
  const browser = await chromium.launch(launchOptions);
  const page = await browser.newPage({ viewport: { width: 1440, height: 1120 }, deviceScaleFactor: 1 });
  await page.goto("http://127.0.0.1:8765", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "Calculate prognosis" }).click();
  await page.locator("#result-content").waitFor({ state: "visible" });
  await page.screenshot({ path: output, fullPage: false });
  await browser.close();
  console.log(output);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
