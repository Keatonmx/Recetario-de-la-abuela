// Usage: node scripts/render-assets.cjs "$PWD/web/recetario.html" "$PWD/Recetario/Assets.xcassets"
// Needs Playwright with Chromium installed.
// Renders the lotería art and folk icons from web/recetario.html into the iOS asset catalog.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const [html, xcassets] = process.argv.slice(2);
const INFO = { author: 'xcode', version: 1 };
const write = (dir, json) => { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, 'Contents.json'), JSON.stringify(json, null, 2) + '\n'); };
const icon = (inner, color = '#000') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="color:${color}">${inner}</svg>`;
const ICONS = {
  'tab-recetas': icon('<g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2.5" width="14" height="19" rx="2"/><rect x="7.5" y="5.2" width="9" height="9.3" rx="1"/><path d="M5 2.5h3.6v3.2H5z" fill="currentColor"/><circle cx="12" cy="10" r="1.9"/><path d="M12 6.6v.9M12 12.5v.9M8.6 10h.9M14.5 10h.9"/><path d="M8 18h8"/></g>'),
  'milagro': icon('<g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7.5-4.6-7.5-10A4 4 0 0 1 12 8.6 4 4 0 0 1 19.5 11c0 5.4-7.5 10-7.5 10z"/><path d="M12 7.6c-1.8-1.5-1.2-3.4 0-5 1.2 1.6 1.8 3.5 0 5z"/><path d="M3.5 6l1.8 1.2M20.5 6l-1.8 1.2"/></g>'),
  'tab-despensa': icon('<g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7.2 7c3.6-.9 6.6 1.5 8.4 5.1 1.6 3.4 2.6 6.9 1.3 8.4-1.7.8-4.6-1.3-6.7-4.5C8.1 12.8 5.7 9.4 7.2 7z"/><path d="M7.2 7c-.4-1.8.4-3.4 2.2-3.9"/><path d="M5.6 7.6c.6-1.4 2.4-1.9 3.6-1.1"/></g>'),
  'olla': icon('<g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 9.5c-3 2.4-3.4 7.4-.6 9.8 2.6 2.2 8.6 2.2 11.2 0 2.8-2.4 2.4-7.4-.6-9.8z"/><path d="M6.5 7h11v2.5h-11z"/><path d="M6.6 11.5C4.4 11 4 14.2 6 14.5M17.4 11.5c2.2-.5 2.6 2.7.6 3"/><path d="M10 4.6c-.8-.8.2-1.6-.4-2.4M14 4.6c-.8-.8.2-1.6-.4-2.4"/><path d="M8 15c1.3-1 2.7 1 4 0s2.7 1 4 0"/></g>'),
  'chile': icon('<path d="M7.2 7c3.6-.9 6.6 1.5 8.4 5.1 1.6 3.4 2.6 6.9 1.3 8.4-1.7.8-4.6-1.3-6.7-4.5C8.1 12.8 5.7 9.4 7.2 7z" fill="currentColor"/><path d="M7.2 7c-.4-1.8.4-3.4 2.2-3.9" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>'),
};
const COLOR_ICONS = {
  'milagro-fill': icon('<g stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"><path d="M12 21s-7.5-4.6-7.5-10A4 4 0 0 1 12 8.6 4 4 0 0 1 19.5 11c0 5.4-7.5 10-7.5 10z" fill="#D7262E" stroke="#1D1A17"/><path d="M12 7.6c-1.8-1.5-1.2-3.4 0-5 1.2 1.6 1.8 3.5 0 5z" fill="#F29F05" stroke="#1D1A17"/><path d="M8.6 12.6c.5-1.5 1.8-2.3 3-2.3" fill="none" stroke="#FFFDF7"/><path d="M3.5 6l1.8 1.2M20.5 6l-1.8 1.2" stroke="#F29F05"/></g>'),
};
(async () => {
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 390, height: 844 } });
  await page.goto('file://' + html + '#recetas'); await page.waitForTimeout(800);
  const arts = await page.$$eval('.loteria', els => els.map(a => ({ id: a.getAttribute('href').slice(1), svg: a.querySelector('.art svg').outerHTML })));
  const tile = await page.evaluate(() => decodeURIComponent(getComputedStyle(document.documentElement).getPropertyValue('--tile').trim().replace(/^url\("data:image\/svg\+xml,/, '').replace(/"\)$/, '')));
  const shot = async (svg, size, file) => {
    const p = await b.newPage({ viewport: { width: size, height: size } });
    await p.setContent(`<style>html,body{margin:0;background:transparent}svg{display:block;width:${size}px;height:${size}px}</style>${svg.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ')}`);
    await p.screenshot({ path: file, omitBackground: true }); await p.close();
  };
  write(path.join(xcassets, 'Art'), { info: INFO });
  for (const { id, svg } of arts) {
    const dir = path.join(xcassets, 'Art', `art-${id}.imageset`);
    write(dir, { images: [{ filename: `art-${id}.png`, idiom: 'universal' }], info: INFO });
    await shot(svg, 480, path.join(dir, `art-${id}.png`));
  }
  write(path.join(xcassets, 'Icons'), { info: INFO });
  const iconSet = async (name, svg, pt, template) => {
    const dir = path.join(xcassets, 'Icons', `${name}.imageset`);
    write(dir, { images: [2, 3].map(s => ({ filename: `${name}@${s}x.png`, idiom: 'universal', scale: `${s}x` })), info: INFO, ...(template ? { properties: { 'template-rendering-intent': 'template' } } : {}) });
    for (const s of [2, 3]) await shot(svg, pt * s, path.join(dir, `${name}@${s}x.png`));
  };
  for (const [n, svg] of Object.entries(ICONS)) await iconSet(n, svg, 26, true);
  for (const [n, svg] of Object.entries(COLOR_ICONS)) await iconSet(n, svg, 26, false);
  // Talavera tile, repeated as a strip under each category heading
  { const dir = path.join(xcassets, 'Icons', 'talavera-tile.imageset');
    write(dir, { images: [2, 3].map(s => ({ filename: `talavera-tile@${s}x.png`, idiom: 'universal', scale: `${s}x` })), info: INFO });
    for (const s of [2, 3]) await shot(tile, 18 * s, path.join(dir, `talavera-tile@${s}x.png`)); }
  console.log(`rendered ${arts.length} cards, ${Object.keys(ICONS).length + Object.keys(COLOR_ICONS).length} icons, 1 tile`);
  await b.close();
})();
