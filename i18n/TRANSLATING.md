# Translating the recetario

Every recipe's text lives in two files with exactly the same shape:

- `i18n/es/<recipe-id>.json`: Spanish (Mexico), all Spanish.
- `i18n/en/<recipe-id>.json`: English, all English.

`i18n/es/_book.json` and `i18n/en/_book.json` hold the category names, the chile guide and
the glossary. `scripts/export-recipes.mjs` merges these into the app's `recipes.json` and
fails if the two languages don't line up.

## File shape (one recipe)

```json
{
  "id": "huevos-rancheros",
  "subtitle": "Huevos estrellados sobre tortilla, bañados en salsa ranchera",
  "verso": "Al que madruga, Dios lo ayuda… con sus huevos rancheros.",
  "region": "Centro · Norte",
  "servings": "2 personas",
  "story": "…",
  "ingredients": [ { "title": "Salsa ranchera", "items": ["4 jitomates guaje (como 1 lb)", "…"] } ],
  "steps": ["…"],
  "pressureCooker": { "time": "45 min a presión alta + 20 min de liberación natural", "total": "1 h 45", "steps": ["…"], "note": null },
  "pressureNote": null,
  "tips": ["…"],
  "variations": [
    { "name": "Huevos Divorciados", "subtitle": "…", "region": null, "note": "…",
      "ingredients": [ { "title": "", "items": ["…"] } ], "steps": ["…"], "pressureNote": null }
  ]
}
```

The Spanish and English files for a recipe must match **one to one**: the same number of
ingredient groups, the same number of items in each group, the same number of steps,
tips, pressure-cooker steps and variations, in the same order, with `null` in the same
places. Line N in Spanish is the translation of line N in English. Variation `name`s are
dish names and are identical in both languages.

Field by field:

- `subtitle`: one short line saying what the dish is. Spanish: a Spanish description.
  English: an English description. (The source calls this `en`.)
- `verso`: la cantada, the lotería caller's line. Spanish: keep the original exactly.
  English: a faithful English translation that keeps the joke or rhyme if it can.
  `null` if the source has none.
- `region`: place names stay as they are (Yucatán, Ciudad de México, Motul). Translate the
  generic words: Centro → Central Mexico, Norte → Northern Mexico, Costa → Coast, Bajío,
  Huasteca etc. stay. Spanish uses the original.
- `servings`: Spanish like `2 personas`, `12 conchas`, `10 bolillos`, `8 rebanadas`,
  `Unas 48`, `1½ tazas`, `2 qt`. English like `2 servings`, `12 conchas`, `10 rolls`,
  `8 slices`, `About 48`, `1½ cups`, `2 quarts`. Always start with the number (or
  `Unas`/`Unos`/`About` then the number).
- Everything else: translate the prose faithfully and completely. Do not shorten, merge,
  add or drop sentences, steps or ingredients. Keep every number, time, temperature and
  amount exactly.

## Spanish (Mexico) rules

- Mexican Spanish, warm and plain, the way an abuela from Mexico writes: *jitomate* (red
  tomato), *tomate verde* or *tomatillo*, *chile*, *frijoles*, *elote*, *papa*, *cacahuate*,
  *aguacate*, *limón* (the small green lime), *betabel*, *ejotes*, *chícharos*, *jamón*,
  *crema*, *manteca*, *comal*, *molcajete*, *olla exprés*.
- Instructions in the **tú** imperative: *Asa los jitomates…*, *Muele…*, *Sirve…*.
- No English left anywhere, except brand names (Instant Pot, Maseca, Abuelita).
- Group titles in Spanish: *Para servir*, *Los huevos*, *La salsa*.

### Amounts (the app scales and converts these, so follow this exactly)

An ingredient line starts with the amount, then the noun, then the rest:
`4 jitomates guaje (como 1 lb)`, `2 dientes de ajo, sin pelar`, `1 cucharada de manteca o aceite`,
`Sal, al gusto`.

- Units, written out in full: `taza`/`tazas`, `cucharada`/`cucharadas`,
  `cucharadita`/`cucharaditas`. Keep `lb`, `oz`, `g`, `kg`, `ml`, `°F` as abbreviations.
  Inches: `pulgada`/`pulgadas` (`un trozo de 2 pulgadas`, `molde de 9 pulgadas`).
  Quarts: `qt` (`2 qt de agua`, `una olla de 8 qt`).
- "about" before an amount is `unos` or `unas`, agreeing with the noun (`unas 2 tazas`,
  `unos 450 g`, `unos 2 lb`). Inside parentheses use `como`: `(como 1 lb)`.
- Fractions stay as the characters `½ ¼ ¾ ⅓ ⅔ ⅛`, ranges use the en dash `–` with no
  spaces (`3–4 cucharadas`), decimals use a point. Never write numbers as words when the
  English uses digits.
- Packets and cans: `1 lata (800 g) de…`, `1 sobre (7 g) de levadura`, `2 tabletas de
  chocolate`.
- A second amount in the same line follows `, `, ` y `, ` o `, ` más ` or ` con `
  directly: `¼ de cebolla blanca, más 2 rebanadas delgadas`, `2 serranos o 1 jalapeño`.
- Use the singular after 1 or less and the plural above 1, for the noun and the
  adjectives right after it: `1 cebolla blanca`, `2 cebollas blancas`, `½ taza`.
- `al gusto` for "to taste".

### Amounts inside steps

Steps mark amounts that scale with servings in double brackets: `Add [[1½ cups]] of the broth`.
Keep **exactly** the same brackets around the matching Spanish amount, written by the
rules above: `Agrega [[1½ tazas]] del caldo`. Never add or remove brackets. Times,
temperatures and pot sizes are never in brackets.

## English rules

The English already exists (in `Recetario/Resources/recipes.json`). Copy it, then make it
**all English**:

- Replace Spanish phrases that have plain English equivalents: `al gusto` → `to taste`,
  group titles like `Para servir` → `To serve`, `Los huevos` → `The eggs`, `abuela` →
  `grandma`, `la tienda` → `the store`, `almuerzo` → `late breakfast`, and so on.
- Keep Spanish only for dish names, proper names and ingredients or tools with no real
  English name: masa, queso fresco, epazote, piloncillo, hoja santa, comal, molcajete,
  olla exprés may stay, in English sentences, as the source does. Chile names stay.
- Don't change amounts, numbers, units, `[[ ]]` markers or the order of anything.
- Light fixes only. Don't rewrite sentences that are already fine.

## Checking your work

For each recipe, open both files and confirm the counts match, the `[[ ]]` count matches
step by step, and every Spanish line is fully Spanish.
