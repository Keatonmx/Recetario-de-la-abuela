# Notes for Claude

Read `HANDOFF.md` first. It has the project status, what the owner still needs to do, and
how the code fits together.

- The app is bilingual: Spanish (Mexico, the default) and English, switched with the ES/EN
  button in every screen's toolbar. Recipe text lives in `i18n/es/<id>.json` and
  `i18n/en/<id>.json`, which must match line for line; read `i18n/TRANSLATING.md` before
  editing them. Interface strings are `store.t("español", "English")` in the Swift views.
- `web/recetario.html` is the source of truth for the recipe list, numbers, categories, art,
  the ¿Qué tengo? lexicon and the scaling/units engines (`SCALE`, `UNITS`, with Spanish rules).
  After changing it or anything in `i18n/`, run
  `node scripts/export-recipes.mjs` and `node scripts/render-assets.cjs "$PWD/web/recetario.html" "$PWD/Recetario/Assets.xcassets"`,
  then commit the generated files. CI fails if they're out of date.
- Step amounts that should scale with servings are wrapped in `[[...]]`, in both languages.
- Stage files by name; never `git add -A` (a key file once leaked that way).
- Never commit the owner's email (the repo is public) or any Apple key. Keys live in GitHub
  secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `DIST_P12_B64`, `DIST_P12_PASSWORD`,
  `PROFILE_APP_B64`. The owner sets all six by running `scripts/setup_signing.py` with the
  RecetarioAPI `.p8`.
- TestFlight: run the `testflight.yml` workflow (workflow_dispatch) once those secrets exist.
  It is Packmule's release lane: unsigned build, hand codesign, altool upload.
