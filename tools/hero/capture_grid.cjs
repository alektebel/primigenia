#!/usr/bin/env node
/* P0 acceptance grid (docs/DESIGN.md §9): time of day x camera, creature vs environment metrics.

   For every t in golden,noon,overcast,night and cam in close,mid,far it loads
   web/hero/index.html?t=..&cam=.. in headless Chromium with SOFTWARE WebGL (SwiftShader) and takes:
     A  the frame as rendered;
     B  the same frame after Hero.setCreatureVisible(false, true): creature pixels hidden, its shadow and
        grass occlusion kept, so |A-B| is the creature body only (the scene is frozen: no clock, no clouds);
     C  the same frame with the sky dome flat magenta and clouds hidden, to detect sky pixels.
   Metrics are computed in Node from the decoded PNGs (ImageMagick `convert` is used as the decoder).

   Usage (CPU heavy, run niced):
     NODE_PATH=<dir with playwright>/node_modules nice -n 10 node tools/hero/capture_grid.cjs [options]
       --out DIR        output dir (default docs/evidence/hero/grid)
       --only t:cam,..  subset, e.g. golden:mid,night:far
       --selftest       also take a second render of A to measure render noise (reported, not used)
       --thr N          creature mask threshold on max channel |A-B| in 0..255 (default 1: any change >=2 levels)
*/
const {chromium} = require('playwright');
const fs = require('fs'), path = require('path'), cp = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const arg = (k, d) => { const i = process.argv.indexOf(k); return i < 0 ? d : (process.argv[i + 1] ?? true); };
const OUT = path.resolve(arg('--out', path.join(ROOT, 'docs/evidence/hero/grid')));
const THR = +arg('--thr', 1);
const SELFTEST = process.argv.includes('--selftest');
const TIMES = ['golden', 'noon', 'overcast', 'night'], CAMS = ['close', 'mid', 'far'];
const ONLY = arg('--only', null);
const W = 1280, H = 800;
const CHROME = process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome';
const ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'];

const lin = new Float64Array(256);
for (let i = 0; i < 256; i++) { const c = i / 255; lin[i] = c <= .04045 ? c / 12.92 : Math.pow((c + .055) / 1.055, 2.4); }

function decode(file) {
  const r = cp.spawnSync('convert', [file, '-depth', '8', 'rgb:-'], {maxBuffer: 64 << 20});
  if (r.status !== 0) throw new Error('convert failed: ' + r.stderr);
  if (r.stdout.length !== W * H * 3) throw new Error(`unexpected raw size ${r.stdout.length} for ${file}`);
  return r.stdout;
}
function encodeGray(buf, file) {
  const r = cp.spawnSync('convert', ['-size', `${W}x${H}`, '-depth', '8', 'gray:-', file], {input: buf});
  if (r.status !== 0) throw new Error('convert failed: ' + r.stderr);
}

/* luminance: Rec.709 weights on sRGB-decoded (linear) values; saturation: HSV S of the 8-bit sRGB value */
function stats(A, idx) {
  const n = idx.length;
  if (!n) return {pixels: 0};
  const Y = new Float32Array(n);
  let sy = 0, ss = 0;
  for (let k = 0; k < n; k++) {
    const o = idx[k] * 3, r = A[o], g = A[o + 1], b = A[o + 2];
    const y = .2126 * lin[r] + .7152 * lin[g] + .0722 * lin[b];
    Y[k] = y; sy += y;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    ss += mx ? (mx - mn) / mx : 0;
  }
  Y.sort();
  const p = q => Y[Math.min(n - 1, Math.floor(q * (n - 1) + .5))];
  return {pixels: n, lum_mean: sy / n, lum_p10: p(.1), lum_p50: p(.5), lum_p90: p(.9), sat_mean: ss / n};
}

async function waitFrames(page, n) {
  const f0 = await page.evaluate(() => Hero.frame);
  await page.waitForFunction(([f, k]) => Hero.frame >= f + k, [f0, n], {timeout: 120000});
}

async function shoot(page, file) { await page.screenshot({path: file}); }

(async () => {
  fs.mkdirSync(OUT, {recursive: true});
  const wanted = ONLY ? new Set(ONLY.split(',')) : null;
  const jobs = [];
  for (const cam of CAMS) for (const t of TIMES) if (!wanted || wanted.has(`${t}:${cam}`)) jobs.push({t, cam});
  const browser = await chromium.launch({executablePath: CHROME, args: ARGS});
  const frames = [];
  let meta = null;
  try {
    meta = {browser: 'Chromium ' + browser.version(), executable: CHROME, args: ARGS, viewport: `${W}x${H}`, deviceScaleFactor: 1};
    for (const {t, cam} of jobs) {
      const name = `${t}-${cam}`, t0 = Date.now();
      const page = await browser.newPage({viewport: {width: W, height: H}, deviceScaleFactor: 1});
      const errs = [];
      page.on('pageerror', e => errs.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
      try {
        await page.goto('file://' + path.join(ROOT, `web/hero/index.html?t=${t}&cam=${cam}`));
        await page.waitForFunction(() => window.Hero && window.Hero.ready, null, {timeout: 120000});
        if (!meta.renderer) meta.renderer = await page.evaluate(() => {
          const gl = document.getElementById('gl').getContext('webgl2') || document.getElementById('gl').getContext('webgl');
          const e = gl.getExtension('WEBGL_debug_renderer_info');
          return e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
        });
        await waitFrames(page, 3);
        const fA = path.join(OUT, name + '.png'), fB = path.join(OUT, '.tmp-B.png'), fC = path.join(OUT, '.tmp-C.png'), fA2 = path.join(OUT, '.tmp-A2.png');
        await shoot(page, fA);
        let noise = null;
        if (SELFTEST) {
          await waitFrames(page, 2); await shoot(page, fA2);
          const a = decode(fA), a2 = decode(fA2); let d = 0, mx = 0;
          for (let i = 0; i < a.length; i += 3) { const m = Math.max(Math.abs(a[i] - a2[i]), Math.abs(a[i + 1] - a2[i + 1]), Math.abs(a[i + 2] - a2[i + 2])); if (m) d++; if (m > mx) mx = m; }
          noise = {pixels_differing_between_two_renders_of_A: d, max_channel_diff: mx};
        }
        await page.evaluate(() => Hero.setCreatureVisible(false, true));
        await waitFrames(page, 2); await shoot(page, fB);
        await page.evaluate(() => { Hero.setCreatureVisible(true); Hero.setSkyFlat(true); });
        await waitFrames(page, 2); await shoot(page, fC);
        const A = decode(fA), B = decode(fB), C = decode(fC);
        const cre = [], env = [], sky = [], viz = Buffer.alloc(W * H);
        for (let i = 0; i < W * H; i++) {
          const o = i * 3;
          const d = Math.max(Math.abs(A[o] - B[o]), Math.abs(A[o + 1] - B[o + 1]), Math.abs(A[o + 2] - B[o + 2]));
          if (d >= THR) { cre.push(i); viz[i] = 255; }
          else if (C[o] >= 250 && C[o + 1] <= 8 && C[o + 2] >= 250) { sky.push(i); viz[i] = 90; }
          else { env.push(i); viz[i] = 0; }
        }
        encodeGray(viz, path.join(OUT, name + '.mask.png'));
        const creature = stats(A, cre), environment = stats(A, env);
        const rec = {name, t, cam, creature, environment, sky_pixels: sky.length, mask_threshold: THR, noise, console_errors: errs.slice(0, 5), seconds: (Date.now() - t0) / 1000};
        if (!creature.pixels) { rec.pass = {lum: false, sat: false, all: false, reason: 'no creature pixels found'}; }
        else {
          const lum = creature.lum_mean >= environment.lum_p10 && creature.lum_mean <= environment.lum_p90;
          const dsat = creature.sat_mean - environment.sat_mean;
          const sat = Math.abs(dsat) <= .15;
          rec.pass = {lum, sat, sat_delta: dsat, all: lum && sat};
        }
        frames.push(rec);
        console.log(`${name}: creature ${creature.pixels}px lum ${creature.lum_mean?.toFixed(4)} vs env p10-p90 ${environment.lum_p10?.toFixed(4)}-${environment.lum_p90?.toFixed(4)}; sat ${creature.sat_mean?.toFixed(3)} vs ${environment.sat_mean?.toFixed(3)} -> ${rec.pass.all ? 'PASS' : 'FAIL'} (${rec.seconds}s)${noise ? ' noise ' + JSON.stringify(noise) : ''}`);
      } finally { await page.close(); }
    }
  } finally { await browser.close(); }
  for (const f of ['.tmp-A2.png', '.tmp-B.png', '.tmp-C.png']) fs.rmSync(path.join(OUT, f), {force: true});

  const metrics = {generated: new Date().toISOString(), settings: {...meta, page: 'web/hero/index.html?t=<t>&cam=<cam> (creature Merodeador, fixed seed, scene frozen)',
    luminance: 'Rec.709 weights on sRGB-decoded (linear) 8-bit values', saturation: 'HSV S of the 8-bit sRGB value',
    creature_mask: `|A-B| >= ${THR} on any channel, A = frame, B = same frame with creature pixels hidden (shadow kept)`,
    sky_mask: 'pixels that are pure magenta when the sky dome is painted magenta and clouds hidden',
    environment: 'all pixels that are neither creature nor sky',
    pass_rule: 'creature lum_mean within environment [lum_p10, lum_p90] AND |creature sat_mean - environment sat_mean| <= 0.15'},
    frames};
  fs.writeFileSync(path.join(OUT, 'metrics.json'), JSON.stringify(metrics, null, 1));

  const full = frames.length === TIMES.length * CAMS.length;
  if (full) {
    const order = []; for (const cam of CAMS) for (const t of TIMES) order.push(frames.find(f => f.t === t && f.cam === cam));
    const margs = [];
    for (const f of order) margs.push('-label', `${f.t} / ${f.cam}  ${f.pass.all ? 'PASS' : 'FAIL'}`, path.join(OUT, f.name + '.png'));
    const r = cp.spawnSync('montage', [...margs, '-tile', '4x3', '-geometry', '640x400+4+4', '-background', '#151515', '-fill', 'white', '-pointsize', '18', path.join(OUT, 'grid.png')], {stdio: 'inherit'});
    if (r.status !== 0) console.error('montage failed');
  }

  const f3 = x => x === undefined ? 'n/a' : x.toFixed(3), f4 = x => x === undefined ? 'n/a' : x.toFixed(4);
  let md = `# P0 acceptance grid\n\nGenerated by \`tools/hero/capture_grid.cjs\` (${metrics.generated}). Metrics in \`metrics.json\`; contact sheet \`grid.png\` (columns: golden, noon, overcast, night; rows: close, mid, far); per-frame masks \`*.mask.png\` (white = creature, grey = sky, black = environment).\n\n`;
  md += `## Settings\n\n- Browser: ${meta.browser} (headless, \`${meta.executable.replace(process.env.HOME, '~')}\`)\n- Launch args: \`${ARGS.join(' ')}\` (software WebGL only, no GPU flags)\n- Renderer reported by WebGL: \`${meta.renderer}\`\n- Viewport: ${W}x${H}, deviceScaleFactor 1, canvas antialias on, \`preserveDrawingBuffer\`\n- Page: \`web/hero/index.html?t=<t>&cam=<cam>\`, creature Merodeador, fixed seed, scene frozen (no sim clock, grass/water time fixed at 3, clouds not drifting)\n- Creature mask: |A-B| >= ${THR} on any 8-bit channel; A = frame, B = same frame after \`Hero.setCreatureVisible(false, true)\` (creature pixels hidden, shadow and grass occlusion kept)\n- Sky mask: pixels that are pure magenta in a third render with the sky dome painted magenta and clouds hidden\n- Environment: every pixel that is neither creature nor sky\n- Luminance: Rec.709 weights on sRGB-decoded values (linear Y, 0..1); saturation: HSV S of the 8-bit sRGB value\n- Pass rule (not tuned): creature mean luminance within the environment p10..p90, **and** creature mean saturation within +-0.15 of the environment mean saturation\n\n`;
  md += `## Results\n\n| t | cam | creature px | creature Y mean | env Y p10 / p50 / p90 | Y in range | creature S | env S | dS | S ok | result |\n|---|---|---|---|---|---|---|---|---|---|---|\n`;
  for (const f of frames) {
    const c = f.creature, e = f.environment;
    md += `| ${f.t} | ${f.cam} | ${c.pixels} | ${f4(c.lum_mean)} | ${f4(e.lum_p10)} / ${f4(e.lum_p50)} / ${f4(e.lum_p90)} | ${f.pass.lum ? 'yes' : 'no'} | ${f3(c.sat_mean)} | ${f3(e.sat_mean)} | ${f.pass.sat_delta === undefined ? 'n/a' : (f.pass.sat_delta >= 0 ? '+' : '') + f3(f.pass.sat_delta)} | ${f.pass.sat ? 'yes' : 'no'} | **${f.pass.all ? 'PASS' : 'FAIL'}** |\n`;
  }
  const np = frames.filter(f => f.pass.all).length;
  md += `\n${np} of ${frames.length} frames pass.\n`;
  fs.writeFileSync(path.join(OUT, 'README.md'), md);
  console.log(`${np}/${frames.length} pass; wrote ${path.relative(ROOT, OUT)}/metrics.json README.md${full ? ' grid.png' : ''}`);
})().catch(e => { console.error(e); process.exit(1); });
