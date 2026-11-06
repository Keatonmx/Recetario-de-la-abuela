# Notes for Claude

Read `HANDOFF.md` first. It has the project status, what the owner still needs to do, and
how the code fits together.

- `web/recetario.html` is the source of truth for recipes and art. After changing it, run
  `node scripts/export-recipes.mjs` and `node scripts/render-assets.cjs "$PWD/web/recetario.html" "$PWD/Recetario/Assets.xcassets"`,
  then commit the generated files. CI fails if they're out of date.
- Step amounts that should scale with servings are wrapped in `[[...]]`.
- Never commit the owner's email (the repo is public) or any Apple key. Keys live in GitHub
  secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `DIST_P12_B64`, `DIST_P12_PASSWORD`,
  `PROFILE_APP_B64`. The owner sets all six by running `scripts/setup_signing.py` with the
  RecetarioAPI `.p8`.
- TestFlight: run the `testflight.yml` workflow (workflow_dispatch) once those secrets exist.
  It is Packmule's release lane: unsigned build, hand codesign, altool upload.
