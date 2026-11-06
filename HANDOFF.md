# Recetario de la Abuela: where things stand

This file explains where the project is, what's left, and how to keep going in a new chat.
Everything is in this GitHub repo. Nothing lives only in an old chat.

## What the app is

An iPhone app of traditional Mexican home cooking. Each recipe is a lotería card. It has:

- **39 recipes in 11 sections**: Desayunos, Caldos y Pozoles, Guisos y Carnes, Mariscos,
  Moles, Masa y Tortilla, Frijoles y Arroz, Salsas, Bebidas, Panadería, Postres.
- **Pressure-cooker (olla exprés) versions** and **variations** under each dish. For
  example, pozole has verde and blanco under it.
- **Servings control** (half, double, any number). It scales every ingredient and the
  amounts inside the steps. Cooking times stay as written.
- **Cups and pounds, or grams and liters.**
- **¿Qué tengo?**: type what's in your kitchen (English or Spanish, typos OK) and see what
  you can cook.
- **Guardadas** (saved recipes), **Despensa** (chile and pantry guide), and a light/dark switch.
- A **"Hoy hay…"** card that follows the calendar: pozole for September 15, tamales for
  Candelaria, fish on Lenten Fridays, and so on.

## Status

| Step | Status |
|---|---|
| App builds, and its recipe math checks out on iPhone | ✅ Every push to `main` runs the build |
| Simulator screenshots | ✅ On the `ci-screenshots` branch, refreshed on every build |
| App Store screenshots (6.9-inch, 1320 × 2868) | ✅ On the `app-store-screenshots` branch |
| App Store text (name, subtitle, description, keywords, privacy answers) | ✅ In `docs/app-store.md` |
| Privacy policy and support pages (GitHub Pages) | ✅ Live, see the links below |
| Bundle ID `com.keatonmx.recetario` | ✅ Registered (Team ID `NHYD37TC9V`) |
| App record in App Store Connect | ✅ Created 2026-11-05, Apple ID `6831412202`, version 1.0 |
| App Store Connect API key in GitHub secrets | ⬜ **You**, step 2 below |
| Contact form on the support page | ⬜ **You**, step 3 below |
| First TestFlight upload | ⬜ After step 2, run the **TestFlight** workflow |

Pages:

- Home: https://keatonmx.github.io/Recetario-de-la-abuela/
- Privacy policy: https://keatonmx.github.io/Recetario-de-la-abuela/privacy.html
- Support: https://keatonmx.github.io/Recetario-de-la-abuela/support.html

## What you need to do

Steps 1 and 2 need your Apple login. Apple doesn't let anyone else create an app, and only
you can download an API key, so a chat can't do these for you.

### 1. Create the app in App Store Connect (done)

Done on 2026-11-05 (Apple ID `6831412202`). For the record, it was made by going to App Store Connect, then **Apps**, then **+**, then **New App**, and fill in:

- **Platform**: iOS
- **Name**: Recetario de la Abuela
- **Primary language**: English (U.S.)
- **Bundle ID**: com.keatonmx.recetario
- **SKU**: recetario-abuela-001
- **User access**: Full Access

### 2. Put the signing secrets in GitHub

The TestFlight workflow is the same lane Packmule's `release.yml` uses, so it takes the same
App Store Connect API key and Apple Distribution certificate (`.p12`) you already set up for
Packmule, plus one profile made for this app. Set each with `gh secret set NAME -R
Keatonmx/Recetario-de-la-abuela --body "..."` (don't pipe values in: Windows adds a hidden CR).

| Secret name | What it is |
|---|---|
| `ASC_KEY_ID` | Same as Packmule: the API key's Key ID |
| `ASC_ISSUER_ID` | Same as Packmule: the Issuer ID |
| `ASC_KEY_P8` | Same as Packmule: the `.p8`, base64 encoded (raw PEM also works) |
| `DIST_P12_B64` | Same as Packmule: the Apple Distribution `.p12`, base64 encoded |
| `DIST_P12_PASSWORD` | Same as Packmule: that `.p12`'s password |
| `PROFILE_APP_B64` | New for this app: run `python scripts/mint_profile.py` (instructions at its top) |

Don't paste these into a chat. GitHub secrets are the only place they should go.
You don't need a Team ID, because it's already in the workflow.

### 3. Turn on the contact form

The support page has a contact form. It stays hidden until it's connected, so your email
never appears on the page or in this public repo.

1. Sign up at **formspree.io** with the email you want support messages sent to.
2. Click **New form** and copy the form ID: the part after `formspree.io/f/`, for example `xyzabcde`.
3. Give the ID to the chat, or edit it yourself: in `docs/support.html`, change
   `const FORM_ID = '';` to `const FORM_ID = 'xyzabcde';`.

The form ID is fine to share, since it's public on the page anyway. Your email address is not.

### 4. Send a build to TestFlight

After step 2, go to the repo's **Actions** tab, open **TestFlight**, and click **Run workflow**
(or ask the chat to run it). It takes about 15 minutes. The build shows up in App Store
Connect under **TestFlight** about 10 to 30 minutes after that. Each run gets a new build
number automatically.

If it fails at **Check setup**, a secret is missing or misnamed. The error message says which one.

## Continuing in a new chat

A cloud chat can't be moved to your computer. You can continue in either of two ways:

- **A new cloud chat** (claude.ai/code) with this repo selected. It reads `CLAUDE.md`, which
  points it here.
- **On your Mac**: clone this repo and run Claude Code in that folder, either with the
  `claude` command in a terminal or in the Claude desktop app.

To pick up where this chat left off, start with something like:

> Read HANDOFF.md. I've finished steps 1 and 2. Run the TestFlight workflow and tell me when
> it's uploaded. My Formspree form ID is `xyzabcde`.

## How the project works (for whoever edits it next)

**One source of truth.** The recipes, card art and search vocabulary all live in
`web/recetario.html`, a single-page web version of the app. The iPhone app reads a JSON
file generated from it, and the card pictures are rendered from the same drawings.

After changing recipes or art:

```sh
node scripts/export-recipes.mjs                                                   # writes Recetario/Resources/recipes.json + test cases
node scripts/render-assets.cjs "$PWD/web/recetario.html" "$PWD/Recetario/Assets.xcassets"   # card art + icons (needs Playwright)
```

Then commit everything. The build fails if `recipes.json` is out of date.

**Writing recipe steps.** Wrap an amount in a step in double brackets when it should scale
with servings, for example `Add [[1½ cups]] of the broth`. Leave times, temperatures, pot
sizes and per-piece amounts unwrapped, because those shouldn't change.

**Checks.**

- `scripts/validate/`: runs the iPhone app's scaling, unit conversion and pantry search code
  against about 7,500 cases taken from the web version. It runs on every build.
- `scripts/web-audit/audit.js`: opens every recipe in light and dark, cups and grams, at half,
  original and double size. It reports broken text, overflow, unscaled markers and low-contrast
  text. Run it with `node scripts/web-audit/audit.js "$PWD/web/recetario.html"` after
  `npm i -D playwright && npx playwright install chromium`.

**Where the iPhone code is.**

| Folder | What's in it |
|---|---|
| `Recetario/App/` | App entry, the four tabs, and the light/dark setting |
| `Recetario/Models/` | Recipe data, servings scaling, units, pantry search, and saved state |
| `Recetario/Views/` | Lotería cards, recipe page, lists, ¿Qué tengo?, Despensa, and the theme |
| `project.yml` | Xcode project definition (XcodeGen). The `.xcodeproj` is generated, not committed |
| `.github/workflows/` | `ios-build.yml` (every push), `app-store-screenshots.yml`, `testflight.yml` |
| `docs/` | GitHub Pages site (privacy, support) and `app-store.md`, which has the listing text |

**Hand-written spots that need updating with new recipes or sections.**

- The ¿Qué tengo? quick picks: `Recetario/Views/QueTengoView.swift`, and `PICKS` in the web file.
- The "Hoy hay…" calendar rules: `Today` in `Recetario/Views/Loteria.swift`, and `today()` in
  the web file.

## Ground rules

- Don't put the owner's personal email anywhere in this repo. It's public.
- Apple keys go only in GitHub secrets, never in files or chat.
- Recipes stay traditional and home-style, not Americanized. Regional names and Spanish
  terms stay, with English explanations.
