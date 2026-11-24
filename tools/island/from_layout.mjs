// Layout table -> island JSON (F0 parity). Reads core/src/terrain_layouts.inc and converts one layout
// (default 1, the Star massif) into primigenia.island/1 JSON, straight segments only (no splines), keeping the
// design coordinates and the 1.56 scale factor in the data so the evaluator reproduces the table bit for bit.
//   node tools/island/from_layout.mjs [--layout 1] [--inc core/src/terrain_layouts.inc] > star_massif.island.json
// Each table CHANNEL or RANGE becomes its own two-point polyline feature, in table order: the evaluator's noise
// offsets use the feature index and the channels are applied in order, so merging them would change the bytes.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const layoutNo = Number(arg('--layout', '1'));
const incPath = arg('--inc', path.join(here, '..', '..', 'core', 'src', 'terrain_layouts.inc'));
const src = fs.readFileSync(incPath, 'utf8');

const SCALE_PM = 1560;
const die = (m) => { console.error(`from_layout: ${m}`); process.exit(1); };
const num = (s) => { const v = parseFloat(String(s).trim().replace(/f$/i, '')); if (!Number.isFinite(v)) die(`bad number ${s}`); return v; };
const exact = (v, scale, what) => {
  const r = Math.round(v * scale);
  if (Math.abs(v * scale - r) > 1e-6) die(`${what}: ${v} x ${scale} is not an integer, parity would be lost`);
  return r;
};
const dm = (v, w) => exact(v, 10, w), cm = (v, w) => exact(v, 100, w), pm = (v, w) => exact(v, 1000, w);

// The array body of `static const <type> <name>[] = { ... };`, one entry per source line, comments split off.
function block(name) {
  const m = src.match(new RegExp(`static const \\w+ ${name}\\[\\] = \\{([\\s\\S]*?)\\n\\};`));
  if (!m) die(`no table ${name} in ${incPath}`);
  return m[1];
}
function featureLines(name) {
  const out = [];
  for (const line of block(name).split('\n')) {
    const cm_ = line.match(/\/\*\s*(.*?)\s*\*\//);
    const code = line.replace(/\/\*.*?\*\//g, '');
    for (const m of code.matchAll(/([A-Z_]+)\(([^)]*)\)/g))
      out.push({ macro: m[1], a: m[2].split(',').map(num), comment: cm_ ? cm_[1] : '' });
  }
  return out;
}
// Tiny brace/string/number parser for the region, route and mark tables.
function nested(text) {
  const tok = text.match(/"[^"]*"|\{|\}|-?[\d.]+f?|,/g); let i = 0;
  const val = () => {
    const t = tok[i++];
    if (t === '{') { const a = []; while (tok[i] !== '}') { if (tok[i] === ',') { i++; continue; } a.push(val()); } i++; return a; }
    if (t[0] === '"') return t.slice(1, -1);
    return num(t);
  };
  const out = []; while (i < tok.length) { if (tok[i] === ',') { i++; continue; } out.push(val()); }
  return out;
}
const name32 = (s) => {   // at most 31 printable ASCII chars, cut at a word boundary
  s = s.replace(/[^\x20-\x7e]/g, '?');
  if (s.length <= 31) return s;
  const cut = s.slice(0, 32), sp = cut.lastIndexOf(' ');
  return (sp > 8 ? cut.slice(0, sp) : s.slice(0, 31)).replace(/[ ,:;]+$/, '');
};

const row = src.match(new RegExp(`LAYOUT_ROW\\("[^"]*",\\s*"[^"]*",\\s*([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),\\s*(\\d+),\\s*(\\d+),\\s*L${layoutNo}_F`));
if (!row) die(`no LAYOUT_ROW for L${layoutNo}`);
const [rx, ry, cx, cy, wx, wy] = row.slice(1, 7).map(num), stream = Number(row[7]), drops = Number(row[8]);
const idm = src.match(new RegExp(`LAYOUT_ROW\\("([^"]*)",\\s*"([^"]*)",\\s*[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,\\s*\\d+,\\s*\\d+,\\s*L${layoutNo}_F`));
const nestR = num(src.match(/\{ID, TITLE, ([\d.]+f?),/)[1]);

const features = [];
for (const { macro, a, comment } of featureLines(`L${layoutNo}_F`)) {
  const name = name32(comment), w = (what) => `${macro} ${what}`;
  switch (macro) {
    case 'MASSIF': { const [x, y, A, L, ang, H] = a; features.push({ kind: 'massif', x_dm: dm(x, w('x')), y_dm: dm(y, w('y')), across_dm: dm(A, w('across')), along_dm: dm(L, w('along')), axis_mdeg: pm(ang, w('angle')), h_cm: cm(H, w('h')), name }); break; }
    case 'RANGE': { const [x0, y0, x1, y1, hw, h0, h1, k] = a;
      features.push({ kind: 'range', pts: [[dm(x0, 'x0'), dm(y0, 'y0'), dm(hw, 'hw'), cm(h0, 'h0')], [dm(x1, 'x1'), dm(y1, 'y1'), dm(hw, 'hw'), cm(h1, 'h1')]], rugged_pm: pm(k, 'k'), name }); break; }
    case 'NEST_RIM': { const [R0, W2, H] = a; features.push({ kind: 'ring', r_dm: dm(R0, 'ring r'), half_dm: dm(W2, 'ring w'), h_cm: cm(H, 'ring h'), name: name || 'nest rim' }); break; }
    case 'PLATEAU': { const [x, y, R, cliff, top] = a; features.push({ kind: 'plateau', x_dm: dm(x, 'x'), y_dm: dm(y, 'y'), r_dm: dm(R, 'r'), cliff_dm: dm(cliff, 'cliff'), top_cm: cm(top, 'top'), name }); break; }
    case 'TERRACE': { const [x, y, R, feather, step, k] = a; features.push({ kind: 'terrace', x_dm: dm(x, 'x'), y_dm: dm(y, 'y'), r_dm: dm(R, 'r'), feather_dm: dm(feather, 'feather'), step_cm: cm(step, 'step'), k_pm: pm(k, 'k'), name }); break; }
    case 'BADLANDS': { const [x, y, R, amp, freq] = a; features.push({ kind: 'badlands', x_dm: dm(x, 'x'), y_dm: dm(y, 'y'), r_dm: dm(R, 'r'), amp_cm: cm(amp, 'amp'), freq_pm: pm(freq, 'freq'), name }); break; }
    case 'CHANNEL': { const [x0, y0, x1, y1, hw, wall, f0, f1, sea] = a;
      features.push({ kind: 'channel', pts: [[dm(x0, 'x0'), dm(y0, 'y0'), dm(hw, 'hw'), cm(f0, 'f0')], [dm(x1, 'x1'), dm(y1, 'y1'), dm(hw, 'hw'), cm(f1, 'f1')]], wall_dm: dm(wall, 'wall'), sea: sea > 0.5 ? 1 : 0, river: 0, name }); break; }
    case 'ISLET': { const [x, y, R, top, bay] = a; features.push({ kind: 'islet', x_dm: dm(x, 'x'), y_dm: dm(y, 'y'), r_dm: dm(R, 'r'), top_cm: cm(top, 'top'), bay_dm: dm(bay, 'bay'), name }); break; }
    case 'CONE': { const [x, y, reach, H] = a; features.push({ kind: 'cone', x_dm: dm(x, 'x'), y_dm: dm(y, 'y'), reach_dm: dm(reach, 'reach'), h_cm: cm(H, 'h'), name }); break; }
    default: die(`unknown feature macro ${macro}`);
  }
}

const regions = nested(block(`L${layoutNo}_R`)).map(([n, kind, biome, gate, , w, pts]) => ({
  name: name32(n), kind, biome, gate, w_dm: dm(w, `region ${n} w`), pts: pts.map(([x, y]) => [dm(x, `region ${n} x`), dm(y, `region ${n} y`)]) }));
const trails = nested(block(`L${layoutNo}_T`)).map(([n, kind, , pts]) => ({
  name: name32(n), kind, pts: pts.map(([x, y]) => [dm(x, `route ${n} x`), dm(y, `route ${n} y`)]) }));
const marks = nested(block(`L${layoutNo}_M`)).map(([n, kind, x, y]) => ({ name: name32(n), kind, x_dm: dm(x, `mark ${n} x`), y_dm: dm(y, `mark ${n} y`) }));

// Wind: the table's unit vector, as a compass-free angle in millidegrees (atan2 y,x), speed from the plan.
const windDeg = (Math.atan2(wy, wx) * 180 / Math.PI + 360) % 360;
const out = {
  format: 'primigenia.island/1',
  id: idm[1], size_dm: 80000, island_radius_dm: 24500, n: 1536, scale_pm: SCALE_PM,
  wind: { dir_mdeg: Math.round(windDeg * 1000), speed_cms: 800 },
  climate: { scale_h_pm: 8000, scale_z_pm: 2500, t_sea_cC: 1400, lapse_cK_per_km: 620 },
  coast: { reef_pm: [pm(rx, 'reef x'), pm(ry, 'reef y')], cliff_pm: [pm(cx, 'cliff x'), pm(cy, 'cliff y')] },
  erosion: { stream_iters: stream, droplets: drops },
  nest: { r_dm: dm(nestR, 'nest r'), floor_cm: 4200, lake: { x_dm: -1500, y_dm: 700, r_dm: 680, depth_cm: 3400 } },
  features, trails, regions, marks,
};
// Readable diff-friendly JSON: top-level keys indented, one line per feature, trail, region and mark.
const lines = [];
for (const [k, v] of Object.entries(out)) {
  if (Array.isArray(v) && v.length && typeof v[0] === 'object' && !Array.isArray(v[0]))
    lines.push(` ${JSON.stringify(k)}: [\n${v.map((o) => '  ' + JSON.stringify(o)).join(',\n')}\n ]`);
  else lines.push(` ${JSON.stringify(k)}: ${JSON.stringify(v)}`);
}
process.stdout.write(`{\n${lines.join(',\n')}\n}\n`);
