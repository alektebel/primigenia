#!/usr/bin/env node
// F2 gate for the island editor (docs/plans/island-realism.md 3.4), everything that needs no browser:
//   1. the shared packer in the page (island/pack.js) is byte for byte tools/island/pack.mjs; the WASM the page loads is the one built from the C
//   2. exportJSON / importJSON round trip, and bad input is refused with a message
//   3. the page's WASM engine (the same island/engine.js the Worker runs) gives the NATIVE terrain hash for the committed island and for an edited
//      one (moved points, splines, painted masks): shape 256, eroded 512, two seeds, and the 1536 bake
//   4. the validation numbers (island/analysis.js) equal tools/island/maps.py within 1% (and `terrain_cli stats` for the flat nest)
//   node tools/island/editor_check.cjs [--write-expected]     (--write-expected also rewrites island/expected.json and copies the island json)
//   EDITOR_FAST=1 skips the 1536 bake in WASM (about 20 s).
'use strict';
const fs = require('fs'), path = require('path'), assert = require('assert'), cp = require('child_process');
const ROOT = path.resolve(__dirname, '..', '..'), WEB = path.join(ROOT, 'web/gaitlab/island'), BUILD = path.join(ROOT, 'build');
const write = process.argv.includes('--write-expected'), fast = !!process.env.EDITOR_FAST;
const sh = (cmd, args) => cp.execFileSync(cmd, args, { cwd: ROOT, encoding: 'utf8', maxBuffer: 1 << 26 });
const native = (file, seed, n, base) => sh('nice', ['-n', '10', path.join(BUILD, 'terrain_cli'), 'hash', '--desc', file, '--seed', String(seed), '--n', String(n)].concat(base ? ['--base'] : [])).trim().split(/\s+/)[0];
const log = (...a) => console.log(...a);

(async () => {
  const M = await import(path.join(WEB, 'model.js')), { createEngine } = await import(path.join(WEB, 'engine.js')), AN = await import(path.join(WEB, 'analysis.js'));
  const pack = await import(path.join(ROOT, 'tools/island/pack.mjs'));
  const createModule = (await import(path.join(WEB, 'wasm/cpore_terrain.mjs'))).default;

  // 1. shared files
  assert(fs.readFileSync(path.join(WEB, 'pack.js')).equals(fs.readFileSync(path.join(ROOT, 'tools/island/pack.mjs'))), 'island/pack.js differs from tools/island/pack.mjs (make island-editor-assets)');
  for (const f of ['cpore_terrain.mjs', 'cpore_terrain.wasm']) assert(fs.readFileSync(path.join(WEB, 'wasm', f)).equals(fs.readFileSync(path.join(BUILD, 'wasm', f))), `island/wasm/${f} is stale (make island-editor-assets)`);
  log('shared files: pack.js == pack.mjs; wasm/ == build/wasm');

  // 2. JSON round trip
  // F4 (A101): the source of truth is data/islands/star_massif.island.json; the page's copy is byte for byte that file (make island-pack)
  const srcText = fs.readFileSync(path.join(ROOT, 'data/islands/star_massif.island.json'), 'utf8'), layout = JSON.parse(srcText);
  const base = M.importJSON(layout), text = M.exportJSON(base);
  assert.strictEqual(text, srcText, 'data/islands/star_massif.island.json is not in the editor export format (re-save it from the editor, or fix the key order)');
  if (write) fs.writeFileSync(path.join(WEB, 'star_massif.island.json'), srcText);
  assert.strictEqual(fs.readFileSync(path.join(WEB, 'star_massif.island.json'), 'utf8'), srcText, 'island/star_massif.island.json is stale (make island-pack)');
  const again = M.importJSON(text);
  assert.strictEqual(M.exportJSON(again), text, 'export(import(export(s))) differs');
  assert(Buffer.from(M.packState(base)).equals(Buffer.from(pack.packIsland(layout))), 'the editor blob differs from the packer CLI blob');
  assert.throws(() => M.importJSON('{nope'), /Not JSON/);
  assert.throws(() => M.importJSON({ format: 'x' }), /Not a primigenia.island\/1/);
  const bad = JSON.parse(text); bad.features[0].h_cm = 1.5;
  assert.throws(() => M.importJSON(bad), /h_cm.*not an integer/);
  const bad2 = JSON.parse(text); bad2.nest.floor_cm = 1e9;
  assert.throws(() => M.importJSON(bad2), /floor_cm/);
  log(`JSON: ${text.length} bytes, round trip stable, blob == packer CLI blob (${M.packState(base).length} bytes), bad input refused with the field name`);

  // an edited island: points moved and added, two splines, a protect disc and an erosion ramp painted with the editor's brush
  const edit = M.cloneState(base);
  const rng = edit.features.map((f, i) => [f, i]).filter(([f]) => f.kind === 'range');
  rng[0][0].spline = 1; M.addPoint(edit, { type: 'feature', i: rng[0][1] }, M.wm(edit, (rng[0][0].pts[0][0] + rng[0][0].pts[1][0]) / 2) + 240, M.wm(edit, (rng[0][0].pts[0][1] + rng[0][0].pts[1][1]) / 2) - 200);
  rng[1][0].pts[1][0] += 400; rng[1][0].pts[1][1] -= 300; rng[1][0].spline = 1;
  edit.features.find((f) => f.kind === 'plateau').top_cm = 52000;
  edit.nest.floor_cm = 4100;
  M.paintMask(edit.maskData[3] = edit.maskData[3].slice(), 8000, 0, 0, 260, 1, 255);   // protect the nest
  M.paintMask(edit.maskData[2] = edit.maskData[2].slice(), 8000, -1500, 1200, 900, 0.8, 40);   // calm erosion in the SW
  M.paintMask(edit.maskData[1] = edit.maskData[1].slice(), 8000, 700, -900, 600, 1, 0);   // bar the forest: canopy
  edit.trails.push({ name: 'Game trail', kind: 'game_trail', pts: [[0, 0], [2500, -3300], [5600, -6900]] });
  const editText = M.exportJSON(edit); assert.strictEqual(M.exportJSON(M.importJSON(editText)), editText, 'edited island round trip');
  fs.mkdirSync(path.join(BUILD, 'island'), { recursive: true });
  const files = { base: path.join(BUILD, 'island/editor-base.isl'), edit: path.join(BUILD, 'island/editor-edit.isl') };
  fs.writeFileSync(files.base, M.packState(base)); fs.writeFileSync(files.edit, M.packState(edit));
  fs.writeFileSync(path.join(BUILD, 'island/editor-edit.island.json'), editText);

  // 3. WASM (the page's engine) == native
  const engine = await createEngine(createModule);
  const rows = [], entries = [];
  const levels = [[256, 'shape'], [512, 'full']].concat(fast && !write ? [] : [[1024, 'bake'], [1536, 'bake']]);
  for (const [name, st, file, seeds] of [['committed', base, files.base, [1, 7]], ['edited', edit, files.edit, [1, 42]]]) {
    for (const seed of seeds) for (const [n, lv] of levels) {
      if (n >= 1024 && (name === 'edited' || seed !== 1)) continue;
      if (n === 1536 && fast) continue;
      const w = engine.run({ blob: M.packState(st), seed, n, mode: lv === 'shape' ? 'shape' : 'full', keep: [] });
      const nh = native(file, seed, n, lv === 'shape');
      assert.strictEqual(w.terrainHash, nh, `${name} seed ${seed} ${lv} ${n}: WASM ${w.terrainHash} != native ${nh}`);
      rows.push(`${name.padEnd(9)} seed ${String(seed).padEnd(2)} ${lv.padEnd(5)} ${String(n).padStart(4)}  ${w.terrainHash}  WASM ${w.seconds.toFixed(2)} s  desc ${w.descHash}`);
      if (name === 'committed' && seed === 1) entries.push({ seed, n, mode: lv, hash: w.terrainHash, desc_hash: w.descHash });
    }
  }
  rows.forEach((r) => log(r));
  log('WASM == native for every row above');
  const dhash = entries[0].desc_hash;
  const exp = { git: sh('git', ['rev-parse', '--short', 'HEAD']).trim(), desc_hash: dhash, entries: entries.map(({ seed, n, mode, hash }) => ({ seed, n, mode, hash })) };
  if (write) { fs.writeFileSync(path.join(WEB, 'expected.json'), JSON.stringify(exp, null, 1) + '\n'); log(`wrote island/expected.json (${exp.entries.length} entries, native build ${exp.git})`); }
  else {
    const stored = JSON.parse(fs.readFileSync(path.join(WEB, 'expected.json'), 'utf8'));
    assert.strictEqual(stored.desc_hash, exp.desc_hash, 'expected.json: desc hash differs');
    for (const e of exp.entries) { const s = stored.entries.find((x) => x.seed === e.seed && x.n === e.n && x.mode === e.mode); assert(s && s.hash === e.hash, `expected.json: no matching hash for ${e.mode} ${e.n}`); }
    log(`expected.json matches the native hashes (build ${stored.git})`);
  }

  // 4. validation numbers == maps.py within 1%
  let worst = 0, worstRel = 0;
  const near = (what, a, b, lim, rel, tiny) => { const d = rel ? 100 * Math.abs(a - b) / Math.max(Math.abs(b), 1e-9) : Math.abs(a - b); if (!tiny) { if (rel) worstRel = Math.max(worstRel, d); else worst = Math.max(worst, d); } assert(d <= lim, `${what}: editor ${a} vs maps.py ${b} (${d.toFixed(2)} ${rel ? '%' : 'points'}, limit ${lim})`); };
  for (const [name, st, file, seed] of [['committed', base, files.base, 1], ['edited', edit, files.edit, 42]]) {
    const n = 512, outDir = path.join(BUILD, 'island', 'm-' + name); fs.mkdirSync(outDir, { recursive: true });
    sh('python3', ['tools/island/maps.py', '--cli', path.join(BUILD, 'terrain_cli'), '--desc', file, '--out', outDir, '--n', String(n), '--px', String(n), '--seed', String(seed)]);
    const py = Object.values(JSON.parse(fs.readFileSync(path.join(outDir, 'stats-desc.json'), 'utf8')))[0];
    const r = engine.run({ blob: M.packState(st), seed, n, mode: 'full' });
    const a = AN.analyse({ height: r.height, river: r.river, material: r.material, n, size: r.size, meta: M.toMeta(st), canopy: (x, y) => M.sampleMask(st.maskData[1], r.size, x, y), wantImages: false }).stats;
    near(`${name} land_km2`, a.land_km2, py.land_km2, 1, true);
    near(`${name} plain_reach_pct`, a.plain_reach_pct, py.plain_reach_pct, 1); near(`${name} climb_reach_pct`, a.climb_reach_pct, py.climb_reach_pct, 1);
    a.regions.forEach((g, i) => {
      const p = py.regions[i]; assert.strictEqual(g.name, p.name);
      near(`${name} ${g.name} land_px`, g.land_px, p.land_px, p.land_px >= 1000 ? 2 : 100 * 26 / Math.max(1, p.land_px), true, p.land_px < 1000);
      for (const k of ['plain_pct', 'climb_only_pct', 'core_plain_pct', 'core_climb_only_pct']) near(`${name} ${g.name} ${k}`, g[k], p[k], 1.05);   // one point, the percentages are rounded to 0.1
    });
    assert.strictEqual(a.routes.every((x) => x.walkable), Object.values(py.routes_walkable).every(Boolean), `${name}: route walkability differs from maps.py`);
    const stats = sh(path.join(BUILD, 'terrain_cli'), ['stats', '--desc', file, '--seed', String(seed), '--n', String(n)]);
    const vf = /valley_flat (\d+)\/(\d+)/.exec(stats); assert.strictEqual(a.valley_flat_n, +vf[2], 'valley_flat disc cell count'); assert.strictEqual(Math.round(a.valley_flat * a.valley_flat_n), +vf[1], 'valley_flat cell count vs terrain_cli stats');
    const rules = AN.validate(a);
    log(`${name}: land ${a.land_km2} km2 (maps.py ${py.land_km2}), nest flat ${(a.valley_flat * 100).toFixed(1)}% (${vf[1]}/${vf[2]} = terrain_cli), ` + rules.map((x) => `${x.id} ${x.ok ? 'ok' : 'RED'} ${x.value}`).join('; '));
  }
  log(`validation == maps.py: worst percentage deviation ${worst.toFixed(2)} points (limit 1), worst area deviation ${worstRel.toFixed(2)}% (limit 2% per region, land area 1%); regions under 1000 px are held to 26 px`);
  log('editor_check: OK');
})().catch((e) => { console.error(e); process.exit(1); });
