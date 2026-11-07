// Draws the app icons: la abuela's lotería card, fanned with el chile and el maíz, on a sarape.
// The main icon has the fringed sarape; the alternates are picked in the app (Ícono de la app).
//
//   npm i --no-save @resvg/resvg-js@2.6.2
//   node scripts/app-icons.cjs
//
// Writes each AppIcon*.appiconset (1024, opaque) and a small preview of each for the picker.
const fs = require("fs");
const path = require("path");
const { Resvg } = require("@resvg/resvg-js");

const ROOT = path.join(__dirname, "..");
const ASSETS = path.join(ROOT, "Recetario", "Assets.xcassets");
const FONTS = path.join(ROOT, "Recetario", "Resources", "Fonts");

const INK = "#1D1A17", STOCK = "#FFFBF2", SKIN = "#B97A50", HAIR = "#DAD5CD", STRAND = "#A49C90", GOLD = "#F2A900";
const ROUND = `stroke="${INK}" stroke-width="16" stroke-linejoin="round" stroke-linecap="round"`;

// A lotería card: double border, numbered art panel, name underneath.
function card({ cx, cy, w, h, rot, id, art, artBg = GOLD, label, fs, num }) {
  const x = cx - w / 2, y = cy - h / 2, px = x + 44, py = y + 46, pw = w - 88, ph = h - 46 - 150;
  return `<g transform="rotate(${rot} ${cx} ${cy})">
<rect x="${x + 16}" y="${y + 22}" width="${w}" height="${h}" rx="30" fill="#000" opacity="0.35"/>
<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="30" fill="${STOCK}" stroke="${INK}" stroke-width="16"/>
<rect x="${x + 22}" y="${y + 22}" width="${w - 44}" height="${h - 44}" rx="14" fill="none" stroke="${INK}" stroke-width="6"/>
<clipPath id="${id}p"><rect x="${px}" y="${py}" width="${pw}" height="${ph}"/></clipPath>
<g clip-path="url(#${id}p)"><rect x="${px}" y="${py}" width="${pw}" height="${ph}" fill="${artBg}"/><g transform="translate(${px} ${py})">${art(pw, ph, id)}</g></g>
<rect x="${px}" y="${py}" width="${pw}" height="${ph}" fill="none" stroke="${INK}" stroke-width="10"/>
${num ? `<rect x="${px + 16}" y="${py + 16}" width="84" height="76" rx="10" fill="${STOCK}" stroke="${INK}" stroke-width="7"/><text x="${px + 58}" y="${py + 74}" text-anchor="middle" font-family="Alfa Slab One" font-size="52" fill="${INK}">${num}</text>` : ""}
<text x="${cx}" y="${y + h - 96 + fs * 0.36}" text-anchor="middle" font-family="Alfa Slab One" font-size="${fs}" fill="${INK}">${label}</text></g>`;
}

const chile = (pw, ph) => `<g transform="translate(${pw / 2} ${ph / 2 + 10}) rotate(-28)" stroke="${INK}" stroke-linejoin="round" stroke-linecap="round">
<path d="M-30 -150 C70 -160 90 -40 60 80 C35 180 -30 230 -80 236 C-40 160 -70 40 -80 -50 C-88 -120 -78 -146 -30 -150 Z" fill="#C8261E" stroke-width="14"/>
<path d="M-30 -150 C-30 -195 0 -225 40 -235" fill="none" stroke="#276B42" stroke-width="24"/></g>`;

function maiz(pw, ph) {
  let kernels = "";
  for (let r = 0; r < 9; r++) for (let c = -2; c <= 2; c++) {
    const yy = -150 + r * 36, ww = 80 * Math.sqrt(1 - Math.pow(yy / 200, 2));
    kernels += `<ellipse cx="${c * ww / 2.6}" cy="${yy}" rx="15" ry="13" fill="#F7D24A" stroke="#C99A16" stroke-width="3"/>`;
  }
  return `<g transform="translate(${pw / 2} ${ph / 2 + 10}) rotate(18)"><ellipse cx="0" cy="-10" rx="92" ry="210" fill="#F2C230" stroke="${INK}" stroke-width="14"/>${kernels}
<path d="M-20 200 C-140 120 -150 -20 -120 -120 C-90 0 -40 100 0 150 Z" fill="#3F8F4F" stroke="${INK}" stroke-width="12" stroke-linejoin="round"/>
<path d="M20 200 C140 120 150 -20 120 -120 C90 0 40 100 0 150 Z" fill="#2F7A40" stroke="${INK}" stroke-width="12" stroke-linejoin="round"/></g>`;
}

const petals = (x, y, n, rx, ry, color) => Array.from({ length: n }, (_, i) =>
  `<ellipse cx="${x}" cy="${y - ry}" rx="${rx}" ry="${ry}" transform="rotate(${i * 360 / n} ${x} ${y})" fill="${color}"/>`).join("");

// La abuela: gray hair in a chongo with a cempasúchil, glasses, gold hoops, an embroidered
// blouse under a red apron, and her wooden spoon raised, still steaming. Feet at y 1040.
function abuela() {
  const R = "#C8261E", W = "#C98A4B", WD = "#A86E35";
  let s = "";
  // Chongo.
  s += `<circle cx="512" cy="352" r="78" fill="${HAIR}" ${ROUND}/><path d="M462 340 C490 300 540 300 560 336 M470 372 C500 350 540 352 556 374" fill="none" stroke="${STRAND}" stroke-width="8"/>`;
  // Blouse with an embroidered neckline, and her neck.
  s += `<path d="M196 1040 C206 868 300 800 420 780 L604 780 C724 800 818 868 828 1040 Z" fill="#FFF8EC" ${ROUND}/>`;
  s += `<path d="M408 784 C424 884 600 884 616 784" fill="none" stroke="${INK}" stroke-width="10"/>`;
  for (const [x, y, c] of [[418, 822, "#E4007C"], [446, 856, "#F28C28"], [480, 874, "#3FAE5A"], [512, 878, "#E2533E"], [544, 874, "#3FAE5A"], [578, 856, "#F28C28"], [606, 822, "#E4007C"]])
    s += petals(x, y, 5, 6, 9, c) + `<circle cx="${x}" cy="${y}" r="4" fill="${GOLD}"/>`;
  s += `<path d="M466 690 L466 790 Q512 812 558 790 L558 690 Z" fill="${SKIN}" ${ROUND}/>`;
  // Apron: ruffled bib, straps, stitching, flowers.
  for (let x = 422; x <= 602; x += 20) s += `<circle cx="${x}" cy="866" r="13" fill="#FFF8EC" stroke="${INK}" stroke-width="6"/>`;
  const straps = "M450 866 C452 830 456 806 462 790 M574 866 C572 830 568 806 562 790";
  s += `<path d="${straps}" fill="none" stroke="${INK}" stroke-width="30" stroke-linecap="round"/><path d="${straps}" fill="none" stroke="${R}" stroke-width="16" stroke-linecap="round"/>`;
  s += `<path d="M414 870 L610 870 L646 1040 L378 1040 Z" fill="${R}" ${ROUND}/><path d="M424 896 H600" stroke="#FFF3DC" stroke-width="5" stroke-dasharray="12 10" opacity="0.8"/>`;
  for (const [x, y, k] of [[452, 950, 1], [512, 985, 1.25], [572, 950, 1]])
    s += `<g transform="translate(${x} ${y}) scale(${k})"><ellipse cx="-20" cy="10" rx="14" ry="6" transform="rotate(-25 -20 10)" fill="#5DBB63"/><ellipse cx="20" cy="10" rx="14" ry="6" transform="rotate(25 20 10)" fill="#5DBB63"/>${petals(0, 0, 5, 8, 11, "#FFF3DC")}<circle r="5" fill="${GOLD}"/></g>`;
  // Ears and gold hoops.
  for (const x of [364, 660]) s += `<ellipse cx="${x}" cy="590" rx="24" ry="34" fill="${SKIN}" stroke="${INK}" stroke-width="12"/>`;
  for (const x of [360, 664]) s += `<circle cx="${x}" cy="652" r="24" fill="none" stroke="${INK}" stroke-width="15"/><circle cx="${x}" cy="652" r="24" fill="none" stroke="${GOLD}" stroke-width="7"/>`;
  // Face and hair, parted in the middle and pulled back.
  s += `<ellipse cx="512" cy="566" rx="150" ry="170" fill="${SKIN}" ${ROUND}/>`;
  s += `<path d="M362 572 C346 430 424 382 512 382 C600 382 678 430 662 572 C644 496 590 466 512 478 C434 466 380 496 362 572 Z" fill="${HAIR}" ${ROUND}/>`;
  s += `<path d="M512 384 V476 M480 400 C430 420 396 470 384 530 M544 400 C594 420 628 470 640 530" fill="none" stroke="${STRAND}" stroke-width="7"/>`;
  // Brows, glasses, smiling eyes and crow's feet.
  s += `<path d="M420 516 Q452 500 484 514 M540 514 Q572 500 604 516" fill="none" stroke="#8E877C" stroke-width="12" stroke-linecap="round"/>`;
  for (const x of [452, 572]) s += `<circle cx="${x}" cy="572" r="50" fill="#FFF3DC" fill-opacity="0.3" stroke="${INK}" stroke-width="12"/>`;
  s += `<path d="M502 570 Q512 560 522 570" fill="none" stroke="${INK}" stroke-width="10"/>`;
  s += `<path d="M430 580 Q452 560 474 580 M550 580 Q572 560 594 580" fill="none" stroke="${INK}" stroke-width="11" stroke-linecap="round"/>`;
  s += `<path d="M392 560 l-18 -8 M392 576 l-20 2 M632 560 l18 -8 M632 576 l20 2" stroke="${INK}" stroke-width="6" stroke-linecap="round"/>`;
  // Cheeks, nose, smile and smile lines.
  for (const x of [420, 604]) s += `<circle cx="${x}" cy="640" r="30" fill="#E4007C" opacity="0.32"/>`;
  s += `<path d="M500 610 Q512 636 528 618" fill="none" stroke="${INK}" stroke-width="9" stroke-linecap="round"/>`;
  s += `<path d="M456 664 Q512 716 568 664 Q512 690 456 664 Z" fill="#7A1F2A" stroke="${INK}" stroke-width="10" stroke-linejoin="round"/>`;
  s += `<path d="M444 640 Q436 664 450 684 M580 640 Q588 664 574 684" fill="none" stroke="${INK}" stroke-width="6" stroke-linecap="round" opacity="0.6"/>`;
  // Cempasúchil in her chongo.
  s += `<g stroke="${INK}" stroke-width="9">${[0, 1, 2, 3, 4, 5].map((i) => `<circle cx="${584 + Math.cos(i * Math.PI / 3) * 28}" cy="${330 + Math.sin(i * Math.PI / 3) * 28}" r="22" fill="#F29F05"/>`).join("")}<circle cx="584" cy="330" r="18" fill="#E2533E"/></g>`;
  // Arm raised, sleeve, the spoon and the hand around it.
  s += `<path d="M850 1060 L762 800" stroke="${INK}" stroke-width="86" stroke-linecap="round"/><path d="M850 1060 L762 800" stroke="${SKIN}" stroke-width="64" stroke-linecap="round"/>`;
  s += `<path d="M774 1000 C780 940 820 916 860 920 C900 924 920 960 916 1040 L784 1060 Z" fill="#FFF8EC" ${ROUND}/><path d="M790 990 C820 970 860 966 900 980" fill="none" stroke="#E4007C" stroke-width="7" stroke-dasharray="2 14" stroke-linecap="round"/>`;
  s += `<g transform="rotate(-4 750 760)"><path d="M750 820 L750 520" stroke="${INK}" stroke-width="38" stroke-linecap="round"/><path d="M750 820 L750 520" stroke="${W}" stroke-width="20" stroke-linecap="round"/>`;
  s += `<ellipse cx="750" cy="466" rx="46" ry="66" fill="${W}" ${ROUND}/><ellipse cx="750" cy="460" rx="26" ry="42" fill="${WD}"/><path d="M736 438 C732 456 734 474 740 486" fill="none" stroke="#E2B07A" stroke-width="6" stroke-linecap="round"/>`;
  s += `<g fill="none" stroke="#FFF8EC" stroke-width="10" stroke-linecap="round" opacity="0.9"><path d="M732 382 C716 360 748 344 732 318"/><path d="M768 386 C752 364 784 348 768 322"/></g></g>`;
  s += `<ellipse cx="752" cy="770" rx="44" ry="40" fill="${SKIN}" ${ROUND}/><path d="M716 760 H748 M716 782 H748" stroke="${INK}" stroke-width="7" stroke-linecap="round"/><path d="M714 744 C700 754 704 776 716 782" fill="none" stroke="${INK}" stroke-width="8" stroke-linecap="round"/>`;
  return s;
}

// Her card's art: a warm glow, and la abuela framed from the chongo down.
const ABUELA = abuela();
function abuelaArt(pw, ph, id) {
  const k = pw / 492 * 0.86;
  return `<defs><radialGradient id="${id}g" cx="0.5" cy="0.42" r="0.75"><stop offset="0" stop-color="#FFD866"/><stop offset="1" stop-color="#E89A00"/></radialGradient></defs><rect width="${pw}" height="${ph}" fill="url(#${id}g)"/>` +
    `<g transform="translate(${pw / 2 - 512 * k} ${ph - 1040 * k + 58}) scale(${k})">${ABUELA}</g>`;
}

const hand = () => card({ id: "a", cx: 340, cy: 560, w: 470, h: 680, rot: -24, art: chile, artBg: "#F6B8D2", label: "EL CHILE", fs: 58 }) +
  card({ id: "b", cx: 684, cy: 560, w: 470, h: 680, rot: 20, art: maiz, artBg: "#9FD3B0", label: "EL MAÍZ", fs: 58 }) +
  card({ id: "c", cx: 512, cy: 520, w: 500, h: 720, rot: -2, art: abuelaArt, label: "LA ABUELA", fs: 62, num: "1" });

// Sarape stripes from a repeating band sequence [color, height, diamonds?].
function stripes(seq, from = -500, to = 1524) {
  let s = "", y = from, i = 0;
  while (y < to) {
    const [c, h, d] = seq[i % seq.length];
    s += `<rect x="-500" y="${y}" width="2024" height="${h + 0.5}" fill="${c}"/>`;
    if (d) for (let x = -500; x < 1524; x += h)
      s += `<path d="M${x} ${y + h / 2} L${x + h / 2} ${y + 4} L${x + h} ${y + h / 2} L${x + h / 2} ${y + h - 4} Z" fill="${d}"/><path d="M${x + h * 0.3} ${y + h / 2} L${x + h / 2} ${y + h * 0.3} L${x + h * 0.7} ${y + h / 2} L${x + h / 2} ${y + h * 0.7} Z" fill="${c}"/>`;
    y += h; i++;
  }
  return s;
}
const CLASICO = [["#C8261E", 44], ["#FFF3DC", 6], ["#F28C28", 14], ["#F2A900", 16], ["#3FAE5A", 10], ["#1F6B3F", 16], ["#FFF3DC", 6], ["#E4007C", 12], ["#7A1F5C", 50, "#FFF3DC"], ["#E4007C", 12], ["#FFF3DC", 6], ["#2FA4D9", 10], ["#F2A900", 16], ["#F28C28", 14], ["#FFF3DC", 6]];
const NEGRO = [["#1D1A17", 60], ["#FFF3DC", 6], ["#C8261E", 16], ["#F2A900", 12], ["#3FAE5A", 12], ["#1D1A17", 60, "#F28C28"], ["#3FAE5A", 12], ["#F2A900", 12], ["#C8261E", 16], ["#FFF3DC", 6]];

function flecos() {
  let s = stripes(CLASICO, -60, 900) + `<rect x="0" y="880" width="1024" height="144" fill="#2A1E17"/>`;
  const cols = ["#C8261E", "#F2A900", "#FFF3DC", "#3FAE5A", "#F28C28", "#E4007C"];
  for (let x = 4; x < 1024; x += 14)
    s += `<path d="M${x} 880 C${x + 4} 930 ${x - 4} 960 ${x + 2} ${1000 + ((x * 7) % 22)}" fill="none" stroke="${cols[Math.floor(x / 14) % 6]}" stroke-width="7" stroke-linecap="round"/>`;
  return s;
}
// Saltillo's center diamond behind the cards.
function rombo() {
  let s = stripes(CLASICO);
  const cols = ["#1D1A17", "#F2A900", "#C8261E", "#FFF3DC", "#3FAE5A", "#E4007C", "#F28C28", "#7A1F5C"];
  for (let r = 560, i = 0; r > 40; r -= 36, i++) s += `<path d="M512 ${512 - r} L${512 + r} 512 L512 ${512 + r} L${512 - r} 512 Z" fill="${cols[i % cols.length]}"/>`;
  return s;
}
const tricolor = () => `<rect width="342" height="1024" fill="#0B6B3E"/><rect x="341" width="342" height="1024" fill="#FFF8EC"/><rect x="682" width="342" height="1024" fill="#C8261E"/>`;

// Asset name, preview name, background. Keep in step with AppIconChoice in Loteria.swift.
const ICONS = [
  ["AppIcon", "icon-principal", flecos],
  ["AppIconClasico", "icon-clasico", () => stripes(CLASICO)],
  ["AppIconRombo", "icon-rombo", rombo],
  ["AppIconNegro", "icon-negro", () => stripes(NEGRO)],
  ["AppIconTricolor", "icon-tricolor", tricolor],
];

// App Store icons can't carry an alpha channel, so the PNGs are written as plain RGB.
const CRC = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc32 = (buf) => { let c = 0xFFFFFFFF; for (const b of buf) c = CRC[(c ^ b) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; };
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function rgbPng({ width, height, pixels }) {
  const rows = Buffer.alloc(height * (width * 3 + 1));
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const i = (y * width + x) * 4, o = y * (width * 3 + 1) + 1 + x * 3;
    rows[o] = pixels[i]; rows[o + 1] = pixels[i + 1]; rows[o + 2] = pixels[i + 2];
  }
  const head = Buffer.alloc(13); head.writeUInt32BE(width, 0); head.writeUInt32BE(height, 4); head[8] = 8; head[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", head), chunk("IDAT", require("zlib").deflateSync(rows, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
}

const fontFiles = [path.join(FONTS, "AlfaSlabOne-Regular.ttf")];
const render = (inner, size) => rgbPng(new Resvg(
  `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#C8261E"/>${inner}</svg>`,
  { font: { fontFiles, loadSystemFonts: false, defaultFontFamily: "Alfa Slab One" } }).render());
const json = (o) => JSON.stringify(o, null, 2) + "\n";
const write = (dir, file, data) => { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, file), data); };

const previews = path.join(ASSETS, "AppIconPreviews");
write(previews, "Contents.json", json({ info: { author: "xcode", version: 1 } }));
for (const [name, preview, background] of ICONS) {
  const svg = background() + hand();
  const set = path.join(ASSETS, `${name}.appiconset`);
  write(set, `${name}.png`, render(svg, 1024));
  write(set, "Contents.json", json({ images: [{ filename: `${name}.png`, idiom: "universal", platform: "ios", size: "1024x1024" }], info: { author: "xcode", version: 1 } }));
  const ps = path.join(previews, `${preview}.imageset`);
  write(ps, `${preview}@2x.png`, render(svg, 180));
  write(ps, `${preview}@3x.png`, render(svg, 270));
  write(ps, "Contents.json", json({ images: [{ filename: `${preview}@2x.png`, idiom: "universal", scale: "2x" }, { filename: `${preview}@3x.png`, idiom: "universal", scale: "3x" }], info: { author: "xcode", version: 1 } }));
  console.log("drew", name);
}
