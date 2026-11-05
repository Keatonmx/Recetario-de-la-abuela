// Exports the recipe data from web/recetario.html into the iOS app's recipes.json,
// so the web page stays the single place where recipes are written.
// Usage: node scripts/export-recipes.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const html = readFileSync(join(root, "web/recetario.html"), "utf8");

const start = html.indexOf("const CATS = [");
const end = html.indexOf("const CAT_NAME");
if (start < 0 || end < 0) throw new Error("Could not find the recipe data block in web/recetario.html");

const { CATS, R, CHILES, GLOSS, ARTICLE, CATCOLOR, VERSO } = new Function(
  html.slice(start, end) + "\nreturn { CATS, R, CHILES, GLOSS, ARTICLE, CATCOLOR, VERSO };"
)();

// Lotería card numbers follow the order recipes appear in the recetario (category order).
const ordered = CATS.flatMap(([c]) => R.filter((r) => r.cat === c));
const NUM = Object.fromEntries(ordered.map((r, i) => [r.id, i + 1]));

const groups = (ing) =>
  (ing.length && Array.isArray(ing[0]) ? ing : [["", ing]]).map(([title, items]) => ({ title, items }));

const book = {
  categories: CATS.map(([id, name]) => ({ id, name, color: CATCOLOR[id] })),
  recipes: ordered.map((r) => ({
    id: r.id,
    number: NUM[r.id],
    article: ARTICLE[r.id] ?? null,
    verso: VERSO[r.id] ?? null,
    name: r.name,
    en: r.en,
    category: r.cat,
    region: r.region,
    time: r.time,
    servings: r.yield,
    story: r.story,
    ingredients: groups(r.ing),
    steps: r.steps,
    pressureCooker: r.pc
      ? { time: r.pc.time, total: r.pc.total, steps: r.pc.steps, note: r.pc.note ?? null }
      : null,
    pressureNote: r.pcNote ?? null,
    tips: r.tips ?? [],
    variations: (r.vars ?? []).map((v) => ({
      name: v.name,
      en: v.en,
      region: v.region ?? null,
      note: v.note ?? null,
      ingredients: groups(v.ing),
      steps: v.steps,
      pressureNote: v.pc ?? null,
    })),
  })),
  chiles: CHILES.map((c) => ({ name: c.n, form: c.f, heat: c.h, taste: c.t, uses: c.u })),
  glossary: GLOSS.map(([term, definition]) => ({ term, definition })),
};

// Test cases for the Swift scaler: every ingredient line and yield, scaled by the web scaler.
const sStart = html.indexOf("const SCALE = (() => {");
const sEnd = html.indexOf("/* ---------- storage");
if (sStart < 0 || sEnd < 0) throw new Error("Could not find the SCALE block in web/recetario.html");
const { SCALE, UNITS } = new Function(html.slice(sStart, sEnd) + "\nreturn { SCALE, UNITS };")();
const lines = new Set();
for (const r of book.recipes) {
  for (const g of r.ingredients) g.items.forEach((i) => lines.add(i));
  for (const v of r.variations) for (const g of v.ingredients) g.items.forEach((i) => lines.add(i));
}
const factors = [0.5, 0.6, 1.5, 2, 3];
const cases = [];
for (const line of lines) for (const f of factors) cases.push({ kind: "text", input: line, factor: f, output: SCALE.text(line, f) });
for (const y of new Set(book.recipes.map((r) => r.servings)))
  for (const f of factors) cases.push({ kind: "yield", input: y, factor: f, output: SCALE.yieldText(y, f) });
// Metric conversion of every ingredient line, step, tip and note, and of scaled lines.
const texts = new Set(lines);
for (const r of book.recipes) {
  [...r.steps, ...r.tips, r.servings, r.pressureNote, r.pressureCooker?.note, ...(r.pressureCooker?.steps ?? [])]
    .filter(Boolean).forEach((t) => texts.add(t));
  for (const v of r.variations) [...v.steps, v.note, v.pressureNote].filter(Boolean).forEach((t) => texts.add(t));
}
for (const t of texts) cases.push({ kind: "metric", input: t, factor: 1, output: UNITS.metric(t) });
for (const line of lines) cases.push({ kind: "scaled-metric", input: line, factor: 0.5, output: UNITS.metric(SCALE.text(line, 0.5)) });
writeFileSync(join(root, "scripts/validate/scaling-fixtures.json"), JSON.stringify(cases, null, 1) + "\n");

const out = join(root, "Recetario/Resources/recipes.json");
writeFileSync(out, JSON.stringify(book, null, 2) + "\n");
const variations = book.recipes.reduce((n, r) => n + r.variations.length, 0);
console.log(`Wrote ${book.recipes.length} recipes, ${variations} variations to ${out}`);
console.log(`Wrote ${cases.length} scaling test cases`);
