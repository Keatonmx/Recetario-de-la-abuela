// Builds the iOS app's recipes.json from two sources:
//   web/recetario.html   the recipe list, numbers, categories, art and the ¿Qué tengo? lexicon
//   i18n/{es,en}/*.json  every recipe's text, in Spanish (Mexico) and in English
// It fails if a recipe is missing a language or the two languages don't line up line for line.
// Usage: node scripts/export-recipes.mjs
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const html = readFileSync(join(root, "web/recetario.html"), "utf8");
const LANGS = ["es", "en"];

const start = html.indexOf("const CATS = [");
const end = html.indexOf("const CAT_NAME");
if (start < 0 || end < 0) throw new Error("Could not find the recipe data block in web/recetario.html");

const dataBlock = html.slice(start, end);
const { CATS, R, CHILES, GLOSS, ARTICLE, CATCOLOR, LEXICON } = new Function(
  dataBlock + "\nreturn { CATS, R, CHILES, GLOSS, ARTICLE, CATCOLOR, LEXICON };"
)();
// The ¿Qué tengo? engine, run here so the app gets each recipe's needs precomputed.
const pStart = html.indexOf("const PANTRY = (() => {");
const pEnd = html.indexOf("/* ---------- storage");
const PANTRY = new Function(dataBlock + html.slice(pStart, pEnd) + "\nreturn PANTRY;")();

// Lotería card numbers follow the order recipes appear in the recetario (category order).
const ordered = CATS.flatMap(([c]) => R.filter((r) => r.cat === c));
const NUM = Object.fromEntries(ordered.map((r, i) => [r.id, i + 1]));

// ---------- the text, per language ----------

const problems = [];
const readJSON = (lang, name) => {
  const path = join(root, "i18n", lang, `${name}.json`);
  if (!existsSync(path)) {
    problems.push(`missing i18n/${lang}/${name}.json`);
    return null;
  }
  return JSON.parse(readFileSync(path, "utf8"));
};
const TEXT = Object.fromEntries(LANGS.map((lang) => [lang, Object.fromEntries(ordered.map((r) => [r.id, readJSON(lang, r.id)]))]));
const BOOK = Object.fromEntries(LANGS.map((lang) => [lang, readJSON(lang, "_book")]));

const groups = (g) => (g ?? []).map(({ title, items }) => ({ title: title ?? "", items }));
const recipeText = (t) => ({
  subtitle: t.subtitle,
  verso: t.verso ?? null,
  region: t.region,
  servings: t.servings,
  story: t.story,
  ingredients: groups(t.ingredients),
  steps: t.steps,
  pressureCooker: t.pressureCooker
    ? { time: t.pressureCooker.time, total: t.pressureCooker.total, steps: t.pressureCooker.steps, note: t.pressureCooker.note ?? null }
    : null,
  pressureNote: t.pressureNote ?? null,
  tips: t.tips ?? [],
  variations: (t.variations ?? []).map((v) => ({
    name: v.name,
    subtitle: v.subtitle,
    region: v.region ?? null,
    note: v.note ?? null,
    ingredients: groups(v.ingredients),
    steps: v.steps,
    pressureNote: v.pressureNote ?? null,
  })),
});

// The shape both languages must share: counts, nulls, [[ ]] markers and variation names.
const marks = (steps) => (steps ?? []).map((s) => (s.match(/\[\[/g) ?? []).length);
const shape = (t) =>
  JSON.stringify({
    verso: t.verso != null,
    ingredients: t.ingredients.map((g) => [g.title !== "", g.items.length]),
    steps: marks(t.steps),
    tips: t.tips.length,
    pressureCooker: t.pressureCooker && { steps: marks(t.pressureCooker.steps), note: t.pressureCooker.note != null },
    pressureNote: t.pressureNote != null,
    variations: t.variations.map((v) => ({
      name: v.name,
      region: v.region != null,
      note: v.note != null,
      ingredients: v.ingredients.map((g) => [g.title !== "", g.items.length]),
      steps: marks(v.steps),
      pressureNote: v.pressureNote != null,
    })),
  });
const empty = (t) => {
  const all = [t.subtitle, t.region, t.servings, t.story, ...t.ingredients.flatMap((g) => g.items), ...t.steps, ...t.tips,
    ...t.variations.flatMap((v) => [v.name, v.subtitle, ...v.ingredients.flatMap((g) => g.items), ...v.steps])];
  return all.some((s) => typeof s !== "string" || !s.trim());
};

const texts = {};
for (const r of ordered) {
  if (!TEXT.es[r.id] || !TEXT.en[r.id]) continue;
  texts[r.id] = Object.fromEntries(LANGS.map((lang) => [lang, recipeText(TEXT[lang][r.id])]));
  const [es, en] = [texts[r.id].es, texts[r.id].en];
  if (shape(es) !== shape(en)) problems.push(`${r.id}: Spanish and English don't line up (groups, items, steps, [[ ]] markers or variations)`);
  for (const lang of LANGS) if (empty(texts[r.id][lang])) problems.push(`${r.id} (${lang}): an empty line`);
  if (!!r.pc !== !!en.pressureCooker) problems.push(`${r.id}: the pressure-cooker version doesn't match web/recetario.html`);
}
for (const lang of LANGS) {
  const b = BOOK[lang];
  if (!b) continue;
  for (const [id] of CATS) if (!b.categories?.[id]) problems.push(`_book (${lang}): no name for category ${id}`);
  if (b.chiles?.length !== CHILES.length || b.chiles.some((c, i) => c.name !== CHILES[i].n)) problems.push(`_book (${lang}): chiles don't match`);
  if (b.glossary?.length !== GLOSS.length || b.glossary.some((g, i) => g.term !== GLOSS[i][0])) problems.push(`_book (${lang}): glossary doesn't match`);
}
if (problems.length) {
  problems.forEach((p) => console.error("ERROR: " + p));
  process.exit(1);
}

// Total times are written in English in the web file; these are the only words in them.
const TIME_WORDS = { es: [["overnight", "toda la noche"], ["chilling", "enfriar"], ["About", "Unas"], ["after assembly", "después de armar"]], en: [] };
const timeIn = (lang, t) => TIME_WORDS[lang].reduce((s, [a, b]) => s.replace(a, b), t);

const book = {
  categories: CATS.map(([id]) => ({ id, color: CATCOLOR[id], es: BOOK.es.categories[id], en: BOOK.en.categories[id] })),
  recipes: ordered.map((r) => ({
    id: r.id,
    number: NUM[r.id],
    article: ARTICLE[r.id] ?? null,
    name: r.name,
    category: r.cat,
    time: Object.fromEntries(LANGS.map((lang) => [lang, timeIn(lang, r.time)])),
    needs: PANTRY.needsOf(r),
    es: texts[r.id].es,
    en: texts[r.id].en,
  })),
  chiles: CHILES.map((c, i) => ({
    name: c.n,
    heat: c.h,
    ...Object.fromEntries(LANGS.map((lang) => {
      const { form, taste, uses } = BOOK[lang].chiles[i];
      return [lang, { form, taste, uses }];
    })),
  })),
  glossary: GLOSS.map(([term], i) => ({ term, es: BOOK.es.glossary[i].definition, en: BOOK.en.glossary[i].definition })),
  lexicon: LEXICON.map(([id, es, en, kind, parent, aliases]) => ({ id, es, en, kind, parent, aliases })),
};

// ---------- test cases for the Swift ports, computed by the web engines ----------

const sStart = html.indexOf("const SCALE = (() => {");
if (sStart < 0) throw new Error("Could not find the SCALE block in web/recetario.html");
const { SCALE, UNITS } = new Function(html.slice(sStart, pStart) + "\nreturn { SCALE, UNITS };")();
const cases = [];
const factors = [0.5, 0.6, 1.5, 2, 3];
for (const lang of LANGS) {
  const all = book.recipes.map((r) => r[lang]);
  // Every ingredient line and yield, scaled.
  const lines = new Set();
  for (const t of all) {
    for (const g of t.ingredients) g.items.forEach((i) => lines.add(i));
    for (const v of t.variations) for (const g of v.ingredients) g.items.forEach((i) => lines.add(i));
  }
  for (const line of lines) for (const f of factors) cases.push({ kind: "text", lang, input: line, factor: f, output: SCALE.text(line, f, lang) });
  for (const y of new Set(all.map((t) => t.servings)))
    for (const f of factors) cases.push({ kind: "yield", lang, input: y, factor: f, output: SCALE.yieldText(y, f, lang) });
  // Metric conversion of every ingredient line, step, tip and note, and of scaled lines.
  const prose = new Set(lines);
  for (const t of all) {
    [...t.steps, ...t.tips, t.servings, t.pressureNote, t.pressureCooker?.note, ...(t.pressureCooker?.steps ?? [])]
      .filter(Boolean).forEach((x) => prose.add(x));
    for (const v of t.variations) [...v.steps, v.note, v.pressureNote].filter(Boolean).forEach((x) => prose.add(x));
  }
  for (const x of prose) cases.push({ kind: "metric", lang, input: x, factor: 1, output: UNITS.metric(x, lang) });
  for (const line of lines)
    cases.push({ kind: "scaled-metric", lang, input: line, factor: 0.5, output: UNITS.metric(SCALE.text(line, 0.5, lang), lang) });
  // Steps: marked amounts scale.
  const allSteps = new Set();
  for (const t of all) {
    [...t.steps, ...(t.pressureCooker?.steps ?? [])].forEach((x) => allSteps.add(x));
    for (const v of t.variations) v.steps.forEach((x) => allSteps.add(x));
  }
  for (const st of allSteps) {
    for (const f of [0.5, 2, 1.5]) cases.push({ kind: "step", lang, input: st, factor: f, output: SCALE.stepText(st, f, lang) });
    cases.push({ kind: "step-metric", lang, input: st, factor: 0.5, output: UNITS.metric(SCALE.stepText(st, 0.5, lang), lang) });
  }
}
// ¿Qué tengo?: alias matching on every ingredient line of the web data, typed input, and rankings.
const webLines = new Set();
for (const r of R) {
  const g = r.ing.length && Array.isArray(r.ing[0]) ? r.ing : [["", r.ing]];
  g.forEach(([, items]) => items.forEach((i) => webLines.add(i)));
  for (const v of r.vars ?? []) {
    const vg = v.ing.length && Array.isArray(v.ing[0]) ? v.ing : [["", v.ing]];
    vg.forEach(([, items]) => items.forEach((i) => webLines.add(i)));
  }
}
for (const line of webLines) cases.push({ kind: "ids", lang: "en", input: line, factor: 1, output: PANTRY.idsIn(line).join(",") });
const queries = ["pork, onion, tomatoes, tortillas", "tengo pollo y chipotle", "chiken, tomatos, onoin", "eggs, tortillas, tomatillo, queso",
  "dried chiles, pork, hominy", "masa, lard, pork, chiles secos", "some leftover rice and milk", "harina, levadura, huevos, leche",
  "beef, potatoes, carrots, corn, zucchini", "frijoles, queso, bolillo", "quesadilla stuff xyz", "guajilo, ancho, puerco, oregano, comino",
  "camarones y arroz", "chocolate abuelita, masa, piloncillo, canela", "Jitomate, cebolla, ajo, serrano, huevo"];
for (const q of queries) {
  const p = PANTRY.parse(q);
  cases.push({ kind: "parse", lang: "en", input: q, factor: 1, output: p.ids.join(",") + "|" + p.unknown.join(",") });
  for (const basics of [true, false])
    cases.push({ kind: basics ? "rank" : "rank-nobasics", lang: "en", input: p.ids.join(","), factor: 1,
      output: PANTRY.rank(R, p.ids, { haveBasics: basics }).slice(0, 5).map((x) => `${x.recipe.id}:${x.score.toFixed(3)}`).join(",") });
}
writeFileSync(join(root, "scripts/validate/scaling-fixtures.json"), JSON.stringify(cases, null, 1) + "\n");

const out = join(root, "Recetario/Resources/recipes.json");
writeFileSync(out, JSON.stringify(book, null, 2) + "\n");
const variations = book.recipes.reduce((n, r) => n + r.en.variations.length, 0);
console.log(`Wrote ${book.recipes.length} recipes, ${variations} variations, in ${LANGS.join(" and ")}, to ${out}`);
console.log(`Wrote ${cases.length} scaling test cases`);
