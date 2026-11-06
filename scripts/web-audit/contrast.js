// Usage: node scripts/web-audit/contrast.js "$PWD/web/recetario.html"
// Prints each category heading's color and its contrast against the page, in light and dark.
const { chromium } = require('playwright');
(async () => {
  const [file] = process.argv.slice(2);
  const b = await chromium.launch();
  for (const scheme of ['light', 'dark']) {
    const p = await b.newPage({ viewport: { width: 375, height: 760 }, colorScheme: scheme });
    await p.goto('file://' + file + '#recetas'); await p.waitForTimeout(700);
    const rows = await p.evaluate(() => {
      const lum = c => { let m = c.match(/[\d.]+/g).map(Number); if (/^color\(srgb/.test(c)) m = m.map(v => v * 255); const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(m[0]) + 0.7152 * f(m[1]) + 0.0722 * f(m[2]); };
      const bg = lum(getComputedStyle(document.body).backgroundColor);
      return [...document.querySelectorAll('.cat h2')].map(h => {
        const c = getComputedStyle(h).color; const a = lum(c);
        return `${h.textContent.trim().padEnd(20)} ${c}  ${((Math.max(a, bg) + 0.05) / (Math.min(a, bg) + 0.05)).toFixed(2)}:1`;
      });
    });
    console.log(scheme + ' (body ' + await p.evaluate(() => getComputedStyle(document.body).backgroundColor) + ')\n  ' + rows.join('\n  '));
    await p.close();
  }
  await b.close();
})();
