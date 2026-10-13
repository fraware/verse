import assert from "node:assert/strict";
import { chromium, firefox, webkit } from "playwright";

const engine = process.env.VERSE_BROWSER || "chromium";
const kind = { chromium, firefox, webkit }[engine];
if (!kind) throw new Error("Unknown browser: " + engine);

const root = "http://127.0.0.1:4173/verse/";
const browser = await kind.launch({ headless: true });

const exercises = [
  ["Emily Dickinson", "very sad", "grief has a circumference"],
  ["Arthur Rimbaud", "colors blend", "blue rings like a bell"],
  ["Ocean Vuong", "I remember my mother", "I remember the warmth of her coat"],
  ["Elizabeth Bishop", "the harbor is empty", "one green rope floats beside the pier"],
  ["Pablo Neruda", "I miss you", "your absence fills the unlit kitchen"],
  ["William Shakespeare", "time passes", "the hour steals the color from the rose"],
  ["Maya Angelou", "I will continue", "I will begin again. I will begin again."],
  ["Robert Frost", "the road splits", "the path divides at the fence"],
  ["Sylvia Plath", "feeling angry", "anger struck like a match"],
  ["Rumi", "I feel lost", "perhaps the wandering is the map"],
  ["Langston Hughes", "I kept walking", "step by step, I walked on"],
  ["Mary Oliver", "trees are tall", "the trees lean into the afternoon"],
];

try {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(root + "write");

  await page.getByLabel("Poem", { exact: true }).fill("very sadness");
  await page.getByRole("button", { name: "Show examples" }).click();
  await page.getByText("No examples match an exact phrase").waitFor();
  assert.equal(await page.getByRole("button", { name: "Apply to draft", exact: true }).count(), 3);
  assert.equal(await page.getByRole("button", { name: "Apply to draft", exact: true }).evaluateAll(buttons => buttons.every(button => button.disabled)), true);

  await page.getByLabel("Poem", { exact: true }).fill("very sad");
  await page.getByRole("button", { name: "Show examples" }).click();
  await page.getByRole("button", { name: "Apply to draft", exact: true }).first().click();
  assert.equal(await page.getByLabel("Poem", { exact: true }).inputValue(), "melancholy");
  assert.ok(page.url().endsWith("/verse/write"), "Suggestion application must not navigate away");

  for (const [name, source, replacement] of exercises) {
    await page.getByRole("combobox", { name: "Literary influence" }).click();
    await page.getByRole("option", { name: new RegExp(name) }).click();
    await page.getByLabel("Poem", { exact: true }).fill(source);
    await page.getByRole("button", { name: "Show examples" }).click();
    await page.getByText(replacement, { exact: true }).waitFor();
    // The product contract is an enabled, applicable action, not the exact
    // wording or count of a transient status message during React updates.
    const apply = page.getByRole("button", { name: "Apply to draft", exact: true }).first();
    try {
      await apply.click({ timeout: 15000 });
      assert.equal(await page.getByLabel("Poem", { exact: true }).inputValue(), replacement, name);
    } catch (error) {
      const statuses = await page.getByRole("status").allTextContents();
      throw new Error(`Literary application failed for ${name}; statuses: ${statuses.join(" | ")}`, { cause: error });
    }
  }

  // Selecting general exercises again is explicit and does not retain another poet's catalogue.
  await page.getByRole("combobox", { name: "Literary influence" }).click();
  await page.getByRole("option", { name: "General craft exercises" }).click();
  await page.getByLabel("Poem", { exact: true }).fill("very sad");
  await page.getByRole("button", { name: "Show examples" }).click();
  await page.getByRole("button", { name: "Apply to draft", exact: true }).first().click();
  assert.equal(await page.getByLabel("Poem", { exact: true }).inputValue(), "melancholy");

  console.log(`PASS (${engine}): twelve distinct literary catalogues, general fallback and exact phrase protection`);
  await context.close();
} finally {
  await browser.close();
}
