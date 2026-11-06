// Usage: node scripts/web-audit/audit.js "$PWD/web/recetario.html"   (needs Playwright: npm i -D playwright && npx playwright install chromium)
// Walks every view and recipe in both themes, both unit systems and three serving sizes,
// and reports errors, overflow, broken output and layout problems.
const { chromium } = require('playwright');
(async () => {
  const [file, out] = process.argv.slice(2);
  const b = await chromium.launch();
  const issues = [];
  const add = (where, what) => issues.push(`${where}: ${what}`);
  for (const scheme of ['light', 'dark']) {
    const p = await b.newPage({ viewport: { width: 375, height: 760 }, colorScheme: scheme });
    p.on('pageerror', e => add(scheme, 'page error ' + e.message));
    p.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') add(scheme, 'console ' + m.text()); });
    await p.goto('file://' + file + '#recetas'); await p.waitForTimeout(900);
    const ids = await p.$$eval('.loteria', els => els.map(a => a.getAttribute('href').slice(1)));
    const total = JSON.parse(require('fs').readFileSync(require('path').join(__dirname, '../../Recetario/Resources/recipes.json'), 'utf8')).recipes.length;
    if (ids.length !== total) add(scheme, `home shows ${ids.length} of ${total} cards`);
    // card layout: names overflowing, cards of unequal height in a row, art missing
    const cardProblems = await p.$$eval('.loteria', els => els.map(a => {
      const nm = a.querySelector('.nm'), svg = a.querySelector('.art svg');
      const r = [];
      if (nm.scrollWidth > nm.clientWidth + 1) r.push('name overflows');
      if (nm.getBoundingClientRect().height > 48) r.push('name is 3+ lines: ' + nm.textContent);
      if (!svg || !svg.innerHTML.trim()) r.push('no art');
      return r.length ? a.getAttribute('href') + ' ' + r.join('; ') : null;
    }).filter(Boolean));
    cardProblems.forEach(x => add(scheme + ' card', x));
    for (const units of ['us', 'metric']) {
      for (const f of [0.5, 1, 2]) {
        for (const id of ids) {
          await p.goto('file://' + file + '#' + id); await p.waitForTimeout(40);
          if (units === 'metric') { const u = await p.$('[data-units="metric"]'); if (u && !(await u.getAttribute('aria-pressed') === 'true')) await u.click(); }
          else { const u = await p.$('[data-units="us"]'); if (u && !(await u.getAttribute('aria-pressed') === 'true')) await u.click(); }
          await p.click(`[data-factor="${f}"]`);
          for (const tab of ['trad', 'pc', 'vars']) {
            const t = await p.$(`[data-tab="${tab}"]`); if (!t) continue;
            await t.click();
            const res = await p.evaluate(() => {
              const text = document.getElementById('panel').innerText + ' ' + document.querySelector('.hero').innerText;
              const bad = [];
              if (/\[\[|\]\]/.test(text)) bad.push('markup visible: ' + (text.match(/.{0,30}(\[\[|\]\]).{0,20}/) || [''])[0]);
              if (/\bundefined\b|\bNaN\b|\bnull\b|\[object/.test(text)) bad.push('bad token: ' + (text.match(/.{0,40}(undefined|NaN|null|\[object).{0,20}/i) || [''])[0]);
              if (/\b0 (g|ml|cups?|lb|tsp|tbsp)\b/.test(text)) bad.push('zero amount: ' + text.match(/.{0,30}\b0 (g|ml|cups?|lb|tsp|tbsp)\b.{0,20}/)[0]);
              if (/\d\s?–\s?\d+[⅛¼⅓½⅔¾]?\s?–/.test(text)) bad.push('double range');
              if (document.documentElement.scrollWidth > window.innerWidth) bad.push('horizontal overflow ' + document.documentElement.scrollWidth);
              const ings = [...document.querySelectorAll('.ings span')].map(s => s.textContent);
              ings.forEach(s => { if (/\b(\d+[⅛¼⅓½⅔¾]?|[⅛¼⅓½⅔¾]) (cups?|lb|g|ml) \(\1 \2\)/.test(s)) bad.push('dup amount: ' + s); });
              ings.forEach(s => { if (/ml \(\d+ ml\)|g \(\d+ g\)/.test(s)) bad.push('dup metric: ' + s); });
              ings.forEach(s => { if (/°F/.test(s) && document.querySelector('[data-units="metric"][aria-pressed="true"]')) bad.push('°F in metric: ' + s); });
              return bad;
            });
            res.forEach(x => add(`${scheme} ${units} ×${f} ${id} ${tab}`, x));
          }
        }
      }
    }
    // other views
    for (const v of ['guardadas', 'despensa', 'que-tengo']) {
      await p.goto('file://' + file + '#' + v); await p.waitForTimeout(150);
      const ov = await p.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
      if (ov) add(scheme + ' ' + v, 'horizontal overflow');
    }
    // search: every recipe findable by its name without accents
    await p.goto('file://' + file + '#recetas'); await p.waitForTimeout(200);
    for (const q of ['albondigas', 'yucatan', 'guajillo', 'pan de muerto', 'cafe', 'xyzzy']) {
      await p.fill('#q', q); await p.waitForTimeout(60);
      const n = await p.$$eval('.loteria', e => e.length);
      if ((q === 'xyzzy') !== (n === 0)) add(scheme + ' search', `"${q}" → ${n} results`);
    }
    await p.fill('#q', '');
    // contrast of key text in this theme (WCAG ratio)
    const contrast = await p.evaluate(() => {
      const lum = c => { let m = c.match(/\d+(\.\d+)?/g).map(Number); if (/^color\(srgb/.test(c)) m = m.map(v => v * 255); const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(m[0]) + 0.7152 * f(m[1]) + 0.0722 * f(m[2]); };
      const bg = el => { let e = el; while (e) { const c = getComputedStyle(e).backgroundColor; if (c && !/rgba\(0, 0, 0, 0\)|transparent/.test(c)) return c; e = e.parentElement; } return 'rgb(255,255,255)'; };
      const out = [];
      for (const sel of ['.mast .tag', '.cat h2', '.loteria .nm', '.chip', '.nav a', '.hoy-w', '.mast h1 .de', '.hoy-t']) {
        const el = document.querySelector(sel); if (!el) continue;
        const a = lum(getComputedStyle(el).color), c = lum(bg(el));
        const ratio = (Math.max(a, c) + 0.05) / (Math.min(a, c) + 0.05);
        if (ratio < 4.5) out.push(`${sel} ${ratio.toFixed(2)}:1`);
      }
      return out;
    });
    contrast.forEach(x => add(scheme + ' contrast', x));
    await p.close();
  }
  const uniq = [...new Set(issues)];
  console.log(uniq.length + ' issues');
  console.log(uniq.slice(0, 120).join('\n'));
  await b.close();
})();
