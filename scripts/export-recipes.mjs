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

const { CATS, R, CHILES, GLOSS, ARTICLE, CATCOLOR } = new Function(
  html.slice(start, end) + "\nreturn { CATS, R, CHILES, GLOSS, ARTICLE, CATCOLOR };"
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

const out = join(root, "Recetario/Resources/recipes.json");
writeFileSync(out, JSON.stringify(book, null, 2) + "\n");
const variations = book.recipes.reduce((n, r) => n + r.variations.length, 0);
console.log(`Wrote ${book.recipes.length} recipes, ${variations} variations to ${out}`);
