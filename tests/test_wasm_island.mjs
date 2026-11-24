// F1 gate: island descs generate the same terrain natively and in WASM. Three seeds, a plain desc (layout 1 from the tables) and a rich one
// (splines on, erosion and protect masks, a game trail), plus the layout-1 parity of the desc arrays is covered by tests/test_island.c.
//   node tests/test_wasm_island.mjs      (needs build/terrain_cli, build/wasm/cpore_terrain.* and build/island/star_f0.isl: make terrain-parity)
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createTerrain } from '../web/terrain-lab/terrain.mjs';
import { packIsland, MASK_RES } from '../tools/island/pack.mjs';

const plain = readFileSync('build/island/star_f0.isl');
const json = JSON.parse(execFileSync('node', ['tools/island/from_layout.mjs'], { encoding: 'utf8' }));
// the rich island: the star massif with two ranges bent by splines (a third control point each), a ramp mask, and a game trail
const ranges = json.features.map((f, i) => [f, i]).filter(([f]) => f.kind === 'range').slice(0, 2);
for (const [f] of ranges) {
  const [a, b] = f.pts;
  f.pts = [a, [Math.round((a[0] + b[0]) / 2) + 300, Math.round((a[1] + b[1]) / 2) - 300, a[2], Math.round((a[3] + b[3]) / 2)], b];
  f.spline = 1;
}
const mask = (fn) => { const u = new Uint8Array(MASK_RES * MASK_RES); for (let y = 0; y < MASK_RES; y++) for (let x = 0; x < MASK_RES; x++) u[y * MASK_RES + x] = fn(x, y); return Buffer.from(u).toString('base64'); };
json.masks = { res: MASK_RES, climate_bias: mask(() => 128), canopy: mask(() => 128), erosion: mask((x) => 60 + x), protect: mask((x, y) => ((x - 64) ** 2 + (y - 64) ** 2 < 100 ? 255 : 128)) };
json.trails = [{ kind: 'game_trail', pts: [[0, 0], [2500, -3300], [5600, -6900]] }];
const rich = Buffer.from(packIsland(json));
mkdirSync('build/island', { recursive: true });
writeFileSync('build/island/rich.isl', rich);

const engine = await createTerrain({});
// M2: --climate makes the climate maps too; the output is "<terrain hash> <seconds> climate <climate hash>"
const cli = (file, seed, n) => execFileSync('nice', ['-n', '10', 'build/terrain_cli', 'hash', '--desc', file, '--seed', String(seed), '--n', String(n), '--climate'], { encoding: 'utf8' }).trim().split(/\s+/);
let rows = [];
assert.equal(engine.module._ct_desc_set(10), -12, 'a truncated blob is refused');
assert.equal(engine.module._ct_generate_desc(), -8, 'no configured terrain, no generation');
for (const [name, file, blob] of [['plain', 'build/island/star_f0.isl', plain], ['rich', 'build/island/rich.isl', rich]]) {
  for (const seed of [1, 7, 42]) {
    const n = seed === 42 ? 512 : 256;
    const native = cli(file, seed, n);
    const t = engine.generate({ seed, n, desc: new Uint8Array(blob) });
    assert.equal(t.hash, native[0], `${name} seed ${seed} n=${n}`);
    assert.equal(t.size, 8000); assert.equal(t.version, 5); assert.ok(t.desc);
    // M2: the climate maps are byte-identical native vs WASM (the climate hash covers climate, biome and veg), and a climate-only re-run reproduces them
    assert.equal(t.climateHash, native[3], `${name} seed ${seed} n=${n} climate maps`);
    assert.equal(t.climateN, 256); assert.equal(t.climate.length, 256 * 256 * 4); assert.equal(t.biome.length, n * n); assert.equal(t.veg.length, n * n * 4);
    assert.equal(engine.climate(null, n).climateHash, t.climateHash, 'climate re-run');
    assert.ok(t.height.every(Number.isFinite) && t.height.length === n * n);
    // the desc hash is part of the terrain hash: the same seed on the layout, and a different desc, differ
    const layout = execFileSync('build/terrain_cli', ['hash', '--layout', '1', '--seed', String(seed), '--n', String(n)], { encoding: 'utf8' }).trim().split(/\s+/)[0];
    assert.notEqual(layout, t.hash);
    console.log(`${name} seed ${seed} n=${n}: ${t.hash} native ${native[1]}s WASM ${t.seconds.toFixed(3)}s`);
    rows.push({ name, seed, n, hash: t.hash });
  }
}
assert.notEqual(rows[0].hash, rows[3].hash, 'the rich desc changes the terrain');
{   // the calibration block (island.h CP_ISL_CAL_*) is read by the WASM build and changes the maps, not the terrain
    const j2 = JSON.parse(execFileSync('node', ['tools/island/from_layout.mjs'], { encoding: 'utf8' })); j2.climate = { ...(j2.climate || {}), calib: { rain_scale_pm: 400, p_inf_mm: 60 } };
    const a = engine.generate({ seed: 1, n: 256, desc: new Uint8Array(plain) });
    const b = engine.generate({ seed: 1, n: 256, desc: new Uint8Array(packIsland(j2)) });
    assert.notEqual(a.climateHash, b.climateHash);
    assert.equal(engine.climate(new Uint8Array(plain), 256).climateHash, a.climateHash, 'a climate re-run with the first blob returns its maps');
    const sumR = (m) => { let t = 0; for (let i = 0; i < 256 * 256; i++) t += m.climate[4 * i]; return t; };
    assert.notEqual(sumR(a), sumR(b));   // the terrain hash mixes the desc hash so it differs; the shape does not:
    assert.deepEqual(Array.from(a.height.slice(0, 4096)), Array.from(b.height.slice(0, 4096)));
}
// a plain seed run after a desc run is the seed's terrain again (nothing leaks between the two)
const seedHash = execFileSync('build/terrain_cli', ['hash', '--seed', '1', '--n', '256'], { encoding: 'utf8' }).trim().split(/\s+/)[0];
const again = engine.generate({ seed: 1, n: 256 });
assert.equal(again.hash, seedHash); assert.equal(again.size, 3600); assert.ok(!again.desc);
console.log('island WASM: native == WASM for 3 seeds x 2 descs (splines, masks, protect, a trail) and for their climate maps; no leakage into seed generation');
