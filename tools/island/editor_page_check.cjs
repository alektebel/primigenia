#!/usr/bin/env node
// F2 gate, the page itself: web/gaitlab/island_editor.html in headless Chromium on SwiftShader (never GPU flags), served from a throwaway
// static server. Desktop 1280x800 (mouse and keyboard) and phone 400x800 and 360x740 (touch through CDP: tap, drag, long press, pinch).
//   checks: the preview hash equals the native terrain_cli hash (committed island, then the island as edited in the page and exported),
//           shape / eroded / bake levels, undo and redo, numeric entry, mask painting, long press adds a point, JSON API and Copy,
//           the red/green validation panel, the phone layout (no horizontal scroll, 44 px handles), the motion rules, and a seeded free-play
//           session of random edits with ZERO console errors.
//   node tools/island/editor_page_check.cjs [--out DIR] [--no-bake]
//   env: PLAYWRIGHT_DIR (default the art-underwater worktree's node_modules/playwright), CHROME (default ~/.cache/ms-playwright/chromium-1254/...)
'use strict';
const http = require('http'), fs = require('fs'), path = require('path'), os = require('os'), assert = require('assert'), cp = require('child_process');
const ROOT = path.resolve(__dirname, '..', '..'), WEB = path.join(ROOT, 'web'), BUILD = path.join(ROOT, 'build');
const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const OUT = arg('--out', '/home/diego/Desarrollo/cpore-wt/_agent/island-f2'), noBake = process.argv.includes('--no-bake');
const PW = process.env.PLAYWRIGHT_DIR || '/home/diego/Desarrollo/cpore-wt/art-underwater/node_modules/playwright';
const CHROME = process.env.CHROME || path.join(os.homedir(), '.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
fs.mkdirSync(OUT, { recursive: true });
const log = (...a) => console.log(...a);
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css' };

let seedState = 12345; const rnd = () => { seedState = (seedState * 1664525 + 1013904223) >>> 0; return seedState / 4294967296; };
const rint = (a, b) => a + Math.floor(rnd() * (b - a + 1)), pick = (a) => a[Math.floor(rnd() * a.length)];

(async () => {
  const pack = await import(path.join(ROOT, 'tools/island/pack.mjs'));
  const expected = JSON.parse(fs.readFileSync(path.join(WEB, 'gaitlab/island/expected.json'), 'utf8'));
  const nativeHash = (json, seed, n, base) => {
    const f = path.join(BUILD, 'island', `page-${process.pid}.isl`); fs.writeFileSync(f, pack.packIsland(JSON.parse(json)));
    return cp.execFileSync('nice', ['-n', '10', path.join(BUILD, 'terrain_cli'), 'hash', '--desc', f, '--seed', String(seed), '--n', String(n)].concat(base ? ['--base'] : []), { encoding: 'utf8' }).trim().split(/\s+/)[0];
  };
  const server = http.createServer((q, r) => {
    const f = path.join(WEB, decodeURIComponent(q.url.split('?')[0]));
    if (!f.startsWith(WEB) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); r.end(); return; }
    r.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r);
  });
  await new Promise((res) => server.listen(0, '127.0.0.1', res));
  const URL = `http://127.0.0.1:${server.address().port}/gaitlab/island_editor.html`;
  const { chromium } = require(PW);
  const browser = await chromium.launch({ executablePath: CHROME, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox'] });
  const failures = [];
  const results = [];

  async function open(name, { w, h, touch }) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, hasTouch: touch, isMobile: touch, deviceScaleFactor: touch ? 2 : 1, acceptDownloads: true, permissions: ['clipboard-read', 'clipboard-write'] });
    const page = await ctx.newPage(), errors = [];
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`${m.type()}: ${m.text()}`); });
    page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
    page.on('requestfailed', (r) => errors.push(`requestfailed: ${r.url()}`));
    page.on('response', (r) => { if (r.status() >= 400) errors.push(`http ${r.status()}: ${r.url()}`); });
    await page.goto(URL);
    const cdp = touch ? await ctx.newCDPSession(page) : null;
    const S = { name, ctx, page, errors, cdp, touch, shot: (n) => page.screenshot({ path: path.join(OUT, `${name}-${n}.jpg`), type: 'jpeg', quality: 82 }).then(() => log(`  screenshot ${name}-${n}.jpg`)) };
    return S;
  }
  const status = (S) => S.page.evaluate(() => window.IslandEditor.status());
  async function idle(S, level = 'full', timeout = 120000) {   // wait until the shown result is the current edit at `level` (or deeper) and nothing runs
    await S.page.waitForFunction((lv) => { const s = window.IslandEditor.status(); const ok = lv === 'shape' ? ['shape', 'full', 'bake'] : lv === 'full' ? ['full', 'bake'] : ['bake']; return s.shown && s.shown.rev === s.rev && ok.includes(s.shown.level) && !Object.values(s.busy).some(Boolean); }, level, { timeout });
    return status(S);
  }
  // canvas-relative screen position -> page coordinates
  const canvasBox = (S) => S.page.locator('#map').boundingBox();
  async function mouseDrag(S, [x0, y0], [x1, y1], steps = 8) { const b = await canvasBox(S); await S.page.mouse.move(b.x + x0, b.y + y0); await S.page.mouse.down(); for (let i = 1; i <= steps; i++) await S.page.mouse.move(b.x + x0 + (x1 - x0) * i / steps, b.y + y0 + (y1 - y0) * i / steps); await S.page.mouse.up(); }
  async function touch(S, type, pts) { await S.cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map(([x, y], id) => ({ x, y, id })) }); }
  async function touchDrag(S, [x0, y0], [x1, y1], steps = 8) { const b = await canvasBox(S); await touch(S, 'touchStart', [[b.x + x0, b.y + y0]]); for (let i = 1; i <= steps; i++) { await touch(S, 'touchMove', [[b.x + x0 + (x1 - x0) * i / steps, b.y + y0 + (y1 - y0) * i / steps]]); await S.page.waitForTimeout(16); } await touch(S, 'touchEnd', []); }
  async function touchTap(S, x, y) { const b = await canvasBox(S); await touch(S, 'touchStart', [[b.x + x, b.y + y]]); await S.page.waitForTimeout(40); await touch(S, 'touchEnd', []); }
  // a spot on the visible map at least 60 px from every handle (a long press there is a long press on empty ground)
  async function emptySpot(S, maxY) {
    const hs = await handles(S), b = await canvasBox(S);
    for (let k = 0; k < 400; k++) { const x = rint(40, b.width - 80), y = rint(40, Math.min(maxY, b.height - 40)); if (hs.every((q) => Math.hypot(q.sx - x, q.sy - y) > 60)) return [x, y]; }
    return [60, 60];
  }
  const drag = (S, a, b) => (S.touch ? touchDrag(S, a, b) : mouseDrag(S, a, b));
  const handles = (S) => S.page.evaluate(() => window.IslandEditor.handles());
  const pointOf = (hs, sel) => hs.find((h) => h.sel.type === sel.type && h.sel.i === sel.i && h.sel.k === sel.k && h.role === 'pt');
  const exportJSON = (S) => S.page.evaluate(() => window.IslandEditor.exportJSON());
  const must = (cond, msg) => { if (!cond) { failures.push(msg); log(`  FAIL ${msg}`); } else log(`  ok   ${msg}`); };
  const noErrors = (S, what) => must(S.errors.length === 0, `${S.name}: zero console errors ${what} ${S.errors.length ? JSON.stringify(S.errors.slice(0, 4)) : ''}`);

  // ============================================================= desktop
  const only = process.env.ONLY || '';   // ONLY=desktop|phone|freeplay runs one part (development)
  let st, hs;
  if (!only || only === 'desktop') {
  log('desktop 1280x800');
  const D = await open('desktop', { w: 1280, h: 800, touch: false });
  st = await idle(D, 'full');
  must(st.native.cls === 'ok' && /matches native build/.test(st.native.text), `preview hash ${st.shown.terrainHash} (eroded 512, seed 1): ${st.native.text}`);
  must(st.shown.terrainHash === expected.entries.find((e) => e.mode === 'full' && e.n === 512).hash, 'preview hash equals the committed native hash');
  must(/native match/.test(await D.page.textContent('#chip')), 'the header chip says native match');
  await D.page.click('#tab-island'); st = await status(D);
  must((await D.page.textContent('#desc-hash')) === st.shown.descHash && (await D.page.textContent('#terrain-hash')) === st.shown.terrainHash, 'the page shows the desc hash and the terrain hash');
  must(/matches native build/.test(await D.page.textContent('#native-status')), 'the Island tab says "matches native build"');
  await D.shot('island-tab');
  await D.page.click('#tab-edit'); await D.shot('relief');
  await D.page.click('#tab-layers'); await D.page.getByRole('button', { name: 'Slopes' }).click(); await D.shot('slopes');
  await D.page.getByRole('button', { name: 'Reach' }).click(); await D.shot('reach');
  await D.page.getByRole('button', { name: 'Relief' }).click();
  await D.page.click('#tab-check');
  const rules = st.validation; must(rules.length === 6 && rules.every((r) => r.ok), `validation green on the committed island: ${rules.map((r) => `${r.id}=${r.value}`).join(', ')}`);
  await D.shot('check-green');

  // shape level while dragging, eroded on release; the hashes of the edited island equal native
  await D.page.click('#tab-edit');
  const before = await exportJSON(D), hashBefore = st.shown.terrainHash;
  hs = await handles(D);
  const h0 = pointOf(hs, { type: 'feature', i: 2, k: 1 });   // an end of the S spur
  const b0 = await canvasBox(D);
  await D.page.mouse.move(b0.x + h0.sx, b0.y + h0.sy); await D.page.mouse.down();
  for (let i = 1; i <= 6; i++) await D.page.mouse.move(b0.x + h0.sx + i * 10, b0.y + h0.sy - i * 7);
  await D.page.waitForFunction(() => window.IslandEditor.results().shape && window.IslandEditor.results().shape.rev > 1, null, { timeout: 20000 });
  const mid = await status(D);
  must(mid.shown && mid.shown.level === 'shape' && mid.shown.n === 256, 'while dragging the preview is the shape level at 256');
  await D.shot('dragging-shape');
  await D.page.mouse.up();
  st = await idle(D, 'full');
  must(st.shown.level === 'full' && st.shown.n === 512 && st.shown.terrainHash !== hashBefore, 'on release the eroded 512 preview replaces it and the terrain changed');
  const edited = await exportJSON(D);
  must(edited !== before, 'the drag changed the island JSON');
  const nh = nativeHash(edited, 1, 512, false);
  must(nh === st.shown.terrainHash, `edited island: page eroded hash ${st.shown.terrainHash} == native ${nh}`);
  const sh = (await D.page.evaluate(() => window.IslandEditor.results())).shape;
  must(sh.terrainHash === nativeHash(edited, 1, 256, true) || sh.rev < st.rev, 'shape hash equals native --base for the same island (when it is the final edit)');
  await D.shot('after-drag');

  // undo / redo
  await D.page.click('#undo'); st = await idle(D, 'full');
  must((await exportJSON(D)) === before && st.shown.terrainHash === hashBefore, 'undo restores the island and the hash');
  must(await D.page.isDisabled('#undo'), 'undo is disabled with nothing left to undo');
  await D.page.click('#redo'); st = await idle(D, 'full');
  must((await exportJSON(D)) === edited, 'redo brings the edit back');
  await D.page.keyboard.press('Control+z'); await idle(D, 'full');
  must((await exportJSON(D)) === before, 'Ctrl+Z undoes from the keyboard');
  await D.page.keyboard.press('Control+Shift+z'); await idle(D, 'full');
  must((await exportJSON(D)) === edited, 'Ctrl+Shift+Z redoes');

  // numeric entry: exact values, in the unit of the JSON
  await D.page.evaluate(() => window.IslandEditor.select({ type: 'feature', i: 8, k: null }));   // the Mesa plateau
  const topBox = D.page.getByLabel('Top height (cm)');
  await topBox.fill('31234'); await topBox.press('Tab');
  must(JSON.parse(await exportJSON(D)).features[8].top_cm === 31234, 'numeric entry stores the exact integer (31234 cm)');
  st = await idle(D, 'full');
  const mesa = st.validation.find((r) => r.id === 'mesa');
  const nh2 = nativeHash(await exportJSON(D), 1, 512, false);
  must(nh2 === st.shown.terrainHash, `numeric edit: page hash == native (${nh2})`);
  log(`  mesa top 312 m: rule ${mesa.ok ? 'green' : 'RED'} (${mesa.value})`);
  await topBox.fill('4000'); await topBox.press('Tab'); st = await idle(D, 'full');
  const mesa2 = st.validation.find((r) => r.id === 'mesa');
  must(!mesa2.ok, `a 40 m mesa is no longer climb-only: the Mesa rule turns red (${mesa2.value})`);
  await D.page.click('#tab-check'); must((await D.page.locator('.rule.bad').count()) >= 1, 'the Check tab shows a red rule'); must(await D.page.locator('#checkdot.bad').count() === 1, 'the Check tab dot is red');
  await D.shot('check-red');
  await D.page.click('#tab-edit'); await D.shot('inspector');

  // long press adds a point, delete point
  await D.page.evaluate(() => window.IslandEditor.select({ type: 'feature', i: 2, k: null }));
  const nPts = await D.page.evaluate(() => window.IslandEditor.state().features[2].pts.length);
  const bb = await canvasBox(D);
  await D.page.mouse.move(bb.x + 300, bb.y + 160); await D.page.mouse.down(); await D.page.waitForTimeout(650); await D.page.mouse.up();
  must((await D.page.evaluate(() => window.IslandEditor.state().features[2].pts.length)) === nPts + 1, 'a long press on the map adds a point to the selected range');
  await D.page.getByRole('button', { name: 'Delete point' }).click();
  must((await D.page.evaluate(() => window.IslandEditor.state().features[2].pts.length)) === nPts, 'Delete point removes it');

  // mask painting
  await D.page.click('#tab-edit'); await D.page.getByRole('button', { name: 'Paint mask' }).click();
  const maskBefore = JSON.parse(await exportJSON(D)).masks;
  await D.page.getByLabel('Mask', { exact: true }).selectOption('3');   // protect
  await mouseDrag(D, [380, 380], [520, 420], 14);
  const maskAfter = JSON.parse(await exportJSON(D)).masks;
  must(!maskBefore && maskAfter && maskAfter.protect && maskAfter.climate_bias && maskAfter.erosion, 'painting the protect mask adds it (and the slots before it) to the JSON');
  const bytes = Buffer.from(maskAfter.protect, 'base64'); must(bytes.length === 16384 && bytes.some((v) => v > 128) && bytes.filter((v) => v !== 128).length < 2000, `the soft brush changed ${bytes.filter((v) => v !== 128).length} of 16384 texels`);
  await D.shot('mask-paint');
  st = await idle(D, 'full'); const nh3 = nativeHash(await exportJSON(D), 1, 512, false);
  must(nh3 === st.shown.terrainHash, `painted island: page hash == native (${nh3})`);
  await D.page.click('#undo'); await idle(D, 'full');
  must(!JSON.parse(await exportJSON(D)).masks, 'undo takes the stroke back (no masks in the JSON again)');
  await D.page.getByRole('button', { name: 'Select' }).first().click();

  // JSON API, Copy island, download
  const json1 = await exportJSON(D);
  const rt = await D.page.evaluate((t) => { const E = window.IslandEditor; E.importJSON(t); return E.exportJSON(); }, json1);
  must(rt === json1, 'importJSON(exportJSON()) is the identity');
  const bad = await D.page.evaluate(() => { try { window.IslandEditor.importJSON('{"format":"nope"}'); return 'accepted'; } catch (e) { return e.message; } });
  must(/Not a primigenia.island\/1/.test(bad), `importJSON refuses a foreign file: ${bad}`);
  await D.page.click('#tab-island'); await D.page.click('#copy');
  must((await D.page.evaluate(() => navigator.clipboard.readText())) === json1, 'Copy island puts the exact JSON on the clipboard');
  const [dl] = await Promise.all([D.page.waitForEvent('download'), D.page.click('#dl')]);
  const dlPath = await dl.path(); must(dl.suggestedFilename() === 'island.json' && fs.readFileSync(dlPath, 'utf8') === json1, 'Download island.json saves the exact JSON');
  const changeSeen = await D.page.evaluate(() => new Promise((res) => { window.IslandEditor.events.addEventListener('change', (e) => res(e.detail.json), { once: true }); window.IslandEditor.undo(); window.IslandEditor.redo(); }));
  must(typeof changeSeen === 'string' && changeSeen.startsWith('{'), 'IslandEditor.events emits a change event with the JSON (the artifact store hook)');
  await D.page.reload(); await D.page.waitForFunction(() => document.body.dataset.boot === 'ready');
  must((await D.page.evaluate(() => window.IslandEditor.exportJSON())) === changeSeen, 'the draft autosaved in localStorage comes back after a reload');
  await D.page.click('#tab-island'); await D.page.click('#reset'); st = await idle(D, 'full');
  must(st.shown.terrainHash === hashBefore && st.native.cls === 'ok', 'Reset to Star massif gives the committed hash and native match again');

  // bake 1536
  if (!noBake) {
    await D.page.click('#tab-island'); await D.page.selectOption('#bake-n', '1536'); await D.page.click('#bake');
    await D.page.waitForSelector('#busy.on'); await D.shot('baking');
    st = await idle(D, 'bake', 240000);
    const bakeExp = expected.entries.find((e) => e.mode === 'bake' && e.n === 1536);
    must(st.shown.level === 'bake' && st.shown.n === 1536 && st.shown.terrainHash === bakeExp.hash, `bake 1536: ${st.shown.terrainHash} == native ${bakeExp.hash} (${(await D.page.evaluate(() => window.IslandEditor.results().bake.seconds)).toFixed(1)} s in the worker)`);
    must(st.native.cls === 'ok', 'the bake says matches native build');
    await D.page.click('#tab-layers'); await D.page.getByRole('button', { name: 'Slopes' }).click(); await D.shot('bake-slopes'); await D.page.getByRole('button', { name: 'Reach' }).click(); await D.shot('bake-reach');
    await D.page.getByRole('button', { name: 'Relief' }).click();
  }

  // motion rules, read from the page's own CSS
  const css = await D.page.evaluate(() => [...document.styleSheets].flatMap((s) => [...s.cssRules].map((r) => r.cssText)).join('\n'));
  const durs = [...css.matchAll(/transition(?:-duration)?:[^;}]*?(\d+(?:\.\d+)?)(m?s)/g)].map((m) => (m[2] === 's' ? +m[1] * 1000 : +m[1]));
  must(durs.length > 0 && Math.max(...durs) <= 250, `every transition is 250 ms or less (longest ${Math.max(...durs)} ms)`);
  must(!/scale\((0|\.0|0\.0)\)|scaleX\((0|\.0)\)/.test(css) && !/@keyframes/.test(css), 'nothing animates from scale 0 (no keyframes at all)');
  must(!/ease-in[^-]|linear/.test(css.replace(/cubic-bezier\(\.23,\s*1,\s*\.32,\s*1\)/g, '')), 'the only curve used is ease-out (cubic-bezier .23, 1, .32, 1)');
  await D.page.click('#tab-edit');
  const btn = D.page.locator('#zin'); const bx = await btn.boundingBox();
  await D.page.mouse.move(bx.x + 5, bx.y + 5); await D.page.mouse.down(); await D.page.waitForTimeout(260);
  const tr = await btn.evaluate((e) => getComputedStyle(e).transform); await D.page.mouse.up();
  must(/matrix\(0\.97,/.test(tr), `a pressed button scales to 0.97 (${tr})`);
  noErrors(D, 'after the desktop scenario');
  await D.ctx.close();
  }

  // ============================================================= phone
  if (!only || only === 'phone') for (const [w, h] of [[400, 800], [360, 740]]) {
    log(`phone ${w}x${h} (touch)`);
    const P = await open(`phone${w}`, { w, h, touch: true });
    st = await idle(P, 'full');
    must(st.native.cls === 'ok', `phone: preview hash ${st.shown.terrainHash} ${st.native.text}`);
    const geom = await P.page.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: innerWidth, sheet: document.getElementById('sheet').getBoundingClientRect().toJSON(), map: document.getElementById('map').getBoundingClientRect().toJSON(), small: [...document.querySelectorAll('button')].filter((b) => b.offsetParent && !b.closest('#tabs') && !b.classList.contains('small') && b.id !== 'grab' && b.getBoundingClientRect().height < 43.5).map((b) => `${b.textContent.trim() || b.id}:${Math.round(b.getBoundingClientRect().height)}`) }));
    must(geom.sw <= geom.iw, `phone ${w}: no horizontal scroll (${geom.sw} <= ${geom.iw})`);
    must(geom.sheet.bottom <= h + 1 && geom.map.width <= w, `phone ${w}: one column, the map on top and the inspector as a bottom sheet`);
    must(geom.small.length === 0, `phone ${w}: every main button is at least 44 px tall ${geom.small.join(', ')}`);
    await P.shot('relief');
    if (w === 400) {
      // touch hit radius: a tap 20 px off a handle still picks it
      hs = await handles(P); const t = pointOf(hs, { type: 'feature', i: 6, k: 1 }); const tb = await canvasBox(P);
      await touchTap(P, t.sx + 17, t.sy + 11);
      const sel = await P.page.evaluate(() => { const e = document.querySelector('#p-edit h2'); return e && e.textContent; });
      must(/Feature: E spur/.test(sel || ''), `a touch 20 px away from a handle selects it (44 px hit area): ${sel}`);
      await P.shot('inspector-open');
      // drag a handle with a finger
      hs = await handles(P); const t2 = pointOf(hs, { type: 'feature', i: 6, k: 1 }); const j0 = await exportJSON(P);
      await touchDrag(P, [t2.sx, t2.sy], [t2.sx + 30, t2.sy + 24]);
      st = await idle(P, 'full'); const j1 = await exportJSON(P);
      must(j1 !== j0, 'a finger drag moves the handle'); must(nativeHash(j1, 1, 512, false) === st.shown.terrainHash, `phone edit: page hash == native (${st.shown.terrainHash})`);
      // pinch zoom with two fingers, then two-finger pan
      const ppm0 = await P.page.evaluate(() => window.IslandEditor.view.ppm), c = await canvasBox(P);
      await touch(P, 'touchStart', [[c.x + 150, c.y + 300], [c.x + 250, c.y + 300]]);
      for (let i = 1; i <= 8; i++) { await touch(P, 'touchMove', [[c.x + 150 - i * 12, c.y + 300], [c.x + 250 + i * 12, c.y + 300]]); await P.page.waitForTimeout(16); }
      await touch(P, 'touchEnd', []);
      const ppm1 = await P.page.evaluate(() => window.IslandEditor.view.ppm); must(ppm1 > ppm0 * 1.5, `pinch zooms the map (${ppm0.toFixed(3)} -> ${ppm1.toFixed(3)} px/m)`);
      const cx0 = await P.page.evaluate(() => window.IslandEditor.view.cx);
      await touch(P, 'touchStart', [[c.x + 150, c.y + 300], [c.x + 250, c.y + 300]]);
      for (let i = 1; i <= 8; i++) { await touch(P, 'touchMove', [[c.x + 150 + i * 10, c.y + 300], [c.x + 250 + i * 10, c.y + 300]]); await P.page.waitForTimeout(16); }
      await touch(P, 'touchEnd', []);
      must(Math.abs((await P.page.evaluate(() => window.IslandEditor.view.cx)) - cx0) > 20, 'two fingers pan the map');
      await P.shot('zoomed');
      // long press with a finger adds a point to the selected shape
      const n0 = await P.page.evaluate(() => window.IslandEditor.state().features[6].pts.length);
      await P.page.evaluate(() => window.IslandEditor.select({ type: 'feature', i: 6, k: null })); const [lx, ly] = await emptySpot(P, 420); await touch(P, 'touchStart', [[c.x + lx, c.y + ly]]); await P.page.waitForTimeout(650); await touch(P, 'touchEnd', []);
      await P.page.waitForTimeout(150);
      must((await P.page.evaluate(() => window.IslandEditor.state().features[6].pts.length)) === n0 + 1, `a finger long press adds a point (${await P.page.evaluate(() => document.getElementById('toast').textContent)})`);
      // the bottom sheet: peek, open, tabs
      await P.page.tap('#grab'); await P.page.waitForTimeout(300); must(await P.page.evaluate(() => document.getElementById('sheet').classList.contains('peek')), 'the grab bar tucks the sheet away');
      await P.shot('sheet-peek'); await P.page.tap('#grab'); await P.page.waitForTimeout(300);
      await P.page.tap('#tab-check'); await P.shot('check'); await P.page.tap('#tab-island'); await P.shot('island'); await P.page.tap('#tab-layers'); await P.shot('layers'); await P.page.tap('#tab-edit');
      // keyboard actions do not animate
      await P.page.focus('#grab'); await P.page.keyboard.press('Enter');
      must(await P.page.evaluate(() => { const s = document.getElementById('sheet'); return s.classList.contains('instant') && getComputedStyle(s).transitionDuration === '0s'; }), 'a keyboard action (Enter on the grab bar) moves the sheet with no animation');
      await P.page.keyboard.press('Enter');
      // phone paint
      await P.page.tap('#tab-edit'); await P.page.getByRole('button', { name: 'Paint mask' }).tap(); await P.page.getByLabel('Mask', { exact: true }).selectOption('1');
      await touchDrag(P, [120, 200], [260, 260], 10); await P.shot('paint');
      must(!!JSON.parse(await exportJSON(P)).masks, 'a finger paints the mask');
      await P.page.getByRole('button', { name: 'Select' }).first().tap();
    } else await P.shot('inspector');
    noErrors(P, `after the ${w}x${h} phone scenario`);
    await P.ctx.close();
  }

  // ============================================================= free play: seeded random edits, mouse on desktop and touch on the phone
  if (!only || only === 'freeplay') for (const [name, w, h, touchy] of [['freeplay-desktop', 1280, 800, false], ['freeplay-phone', 400, 800, true]]) {
    log(`${name}: 70 random actions, seed 12345`);
    const F = await open(name, { w, h, touch: touchy });
    await idle(F, 'full');
    const counts = {};
    const act = async () => {
      const r = rnd(), b = await canvasBox(F), hs2 = await handles(F), vis = hs2.filter((q) => q.sx > 20 && q.sy > 20 && q.sx < b.width - 60 && q.sy < (touchy ? 520 : b.height - 30));
      let what;
      if (r < 0.26 && vis.length) { what = 'drag'; const q = pick(vis); await drag(F, [q.sx, q.sy], [q.sx + rint(-60, 60), q.sy + rint(-60, 60)]); }
      else if (r < 0.34) { what = 'tap'; const x = rint(30, b.width - 70), y = rint(30, Math.min(b.height - 30, 500)); if (touchy) await touchTap(F, x, y); else await F.page.mouse.click(b.x + x, b.y + y); }
      else if (r < 0.46) { what = 'number'; const inputs = F.page.locator('#p-edit input[type=number]:visible'), n = await inputs.count(); if (n) { const el = inputs.nth(rint(0, n - 1)), mn = +(await el.getAttribute('min')), mx = +(await el.getAttribute('max')); await el.fill(String(rint(mn, mx))); await el.press('Tab'); } }
      else if (r < 0.52) { what = 'tab'; await F.page.click('#tab-' + pick(['edit', 'layers', 'check', 'island']), { force: true }); }
      else if (r < 0.60) { what = 'undo/redo'; await F.page.click(pick(['#undo', '#redo']), { force: true }).catch(() => {}); }
      else if (r < 0.68) { what = 'paint'; await F.page.click('#tab-edit', { force: true }); await F.page.getByRole('button', { name: 'Paint mask' }).click({ force: true }); await F.page.getByLabel('Mask', { exact: true }).selectOption(String(rint(0, 3))); const x = rint(60, b.width - 100), y = rint(60, 400); await drag(F, [x, y], [x + rint(-90, 90), y + rint(-60, 60)]); await F.page.getByRole('button', { name: 'Select' }).first().click({ force: true }); }
      else if (r < 0.76) { what = 'long-press'; const [x, y] = await emptySpot(F, 420); if (touchy) { await touch(F, 'touchStart', [[b.x + x, b.y + y]]); await F.page.waitForTimeout(600); await touch(F, 'touchEnd', []); } else { await F.page.mouse.move(b.x + x, b.y + y); await F.page.mouse.down(); await F.page.waitForTimeout(600); await F.page.mouse.up(); } }
      else if (r < 0.82) { what = 'zoom'; await F.page.click(pick(['#zin', '#zout', '#zfit']), { force: true }); }
      else if (r < 0.90) { what = 'layer'; await F.page.click('#tab-layers', { force: true }); await F.page.getByRole('button', { name: pick(['Relief', 'Slopes', 'Reach']) }).click({ force: true }); }
      else if (r < 0.95) { what = 'select-list'; await F.page.click('#tab-edit', { force: true }); const items = F.page.locator('.list button'); const n = await items.count(); if (n) await items.nth(rint(0, n - 1)).click({ force: true }); }
      else { what = 'delete-point'; const bt = F.page.getByRole('button', { name: 'Delete point' }); if (await bt.count() && await bt.isEnabled()) await bt.click({ force: true }); }
      counts[what] = (counts[what] || 0) + 1;
      if (F.errors.length) throw new Error(`console error after ${what}: ${F.errors[0]}`);
    };
    // make selecting useful: a first selection so long presses and point deletion do something
    await F.page.evaluate(() => window.IslandEditor.select({ type: 'feature', i: 2, k: null }));
    let skipped = 0;
    for (let i = 0; i < 70; i++) { try { await act(); } catch (e) { if (/console error/.test(e.message)) throw e; skipped++; } if (i % 12 === 11) { const fi = pick([2, 3, 4, 6, 12, 15, 21]); await F.page.evaluate((k) => window.IslandEditor.select({ type: 'feature', i: k, k: null }), fi); } }
    log(`  actions: ${JSON.stringify(counts)}${skipped ? `, ${skipped} skipped because the target was off screen` : ''}`);
    st = await idle(F, 'full', 180000);
    const json = await exportJSON(F);
    must(await F.page.evaluate((t) => { try { window.IslandEditor.importJSON(t); return window.IslandEditor.exportJSON() === t; } catch (e) { return false; } }, json), `${name}: the island after the session is still valid JSON (round trip)`);
    st = await idle(F, 'full', 180000); const fn = nativeHash(await exportJSON(F), 1, 512, false);
    must(fn === st.shown.terrainHash, `${name}: after random edits the page hash ${st.shown.terrainHash} == native ${fn}`);
    await F.shot('end');
    noErrors(F, `across ${Object.values(counts).reduce((a, b) => a + b, 0)} random actions`);
    await F.ctx.close();
  }
  await browser.close(); server.close();
  log(failures.length ? `\nFAILED ${failures.length}:\n- ${failures.join('\n- ')}` : '\neditor_page_check: all checks passed');
  process.exit(failures.length ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
