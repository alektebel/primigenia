#!/usr/bin/env node
/* Moving-center check: grass blades must be anchored to the world, not to hU.center.
   Renders web/hero/index.html twice with a fixed camera, the second time with the grass ring centre
   shifted by --shift metres (default 3.7) via window.__heroCenterShift, and compares the two PNGs.
   Blades within --inner metres of both centres (default 24, inside the fade band start) must be identical,
   so we compare the bottom --rows fraction of the close-camera frame and report differing pixels.
   Usage: NODE_PATH=<playwright>/node_modules nice -n 10 node tools/hero/check_grass_anchor.cjs [--t golden] [--cam close] */
const {chromium} = require('playwright'), cp = require('child_process'), path = require('path'), fs = require('fs'), os = require('os');
const arg = (k, d) => { const i = process.argv.indexOf(k); return i < 0 ? d : process.argv[i + 1]; };
const T = arg('--t', 'golden'), CAM = arg('--cam', 'close'), SHIFT = +arg('--shift', 3.7), ROWS = +arg('--rows', .45);
const W = 1280, H = 800, ROOT = path.resolve(__dirname, '../..');
const CHROME = process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome';
const dec = f => cp.spawnSync('convert', [f, '-depth', '8', 'rgb:-'], {maxBuffer: 64 << 20}).stdout;
(async () => {
  const b = await chromium.launch({executablePath: CHROME, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader']});
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'anchor-')), files = [];
  try {
    const page = await b.newPage({viewport: {width: W, height: H}, deviceScaleFactor: 1});
    await page.goto('file://' + path.join(ROOT, `web/hero/index.html?t=${T}&cam=${CAM}`));
    await page.waitForFunction(() => window.Hero && window.Hero.ready, null, {timeout: 120000});
    for (const s of [0, SHIFT]) {
      await page.evaluate(v => { window.__heroCenterShift = v; }, s);
      const f0 = await page.evaluate(() => Hero.frame);
      await page.waitForFunction(f => Hero.frame >= f + 3, f0, {timeout: 120000});
      const f = path.join(dir, `s${s}.png`); await page.screenshot({path: f}); files.push(f);
    }
  } finally { await b.close(); }
  const A = dec(files[0]), B = dec(files[1]), y0 = Math.floor(H * (1 - ROWS));
  let n = 0, mx = 0, tot = 0;
  for (let y = y0; y < H; y++) for (let x = 0; x < W; x++) { const o = (y * W + x) * 3; tot++;
    const d = Math.max(Math.abs(A[o] - B[o]), Math.abs(A[o + 1] - B[o + 1]), Math.abs(A[o + 2] - B[o + 2])); if (d > 0) n++; if (d > mx) mx = d; }
  console.log(JSON.stringify({t: T, cam: CAM, shift_m: SHIFT, compared_rows: `${y0}-${H}`, pixels: tot, differing: n, max_channel_diff: mx, pass: n / tot < .002}));
  process.exitCode = n / tot < .002 ? 0 : 1;
})();
