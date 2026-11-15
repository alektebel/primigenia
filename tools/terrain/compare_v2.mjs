/* Original v2 must be built into build/wasm-v2 (docs/TERRAIN.md).
 * Compare raw maps, because v3's hash also covers the new output schema. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createTerrain } from '../../web/terrain-lab/terrain.mjs';

const original = await createTerrain({}, '../../build/wasm-v2/cpore_terrain.mjs');
const current = await createTerrain();
// Optional positional arguments: output.json seed n.
const seed = Number(process.argv[3] ?? 42), n = Number(process.argv[4] ?? 256);
const switches = ['gentle-bases', 'layout-variety', 'cliff-bands', 'sea-cliffs', 'hard-rock', 'volcano', 'caves'];
mkdirSync('build/terrain', { recursive: true });
const path = 'build/terrain/v2-disabled.bin';
execFileSync('nice', ['-n', '10', 'build/terrain_cli', 'dump', '--seed', String(seed), '--n', String(n),
  '--out', path, ...switches.flatMap(name => ['--' + name, '0'])]);
const native = readFileSync(path);
const before = original.generate({ seed, n });
const after = current.generate({ seed, n, gentle: 0, variety: 0, bands: 0, coast: 0, rock: 0, volcano: 0, caves: 0 });
assert.equal(before.version, 2);
const maps = ['height', 'flow', 'sediment'];
const sha256 = {};
for (const [i, name] of maps.entries()) {
  const bytes = Buffer.from(before[name].buffer, before[name].byteOffset, n*n*4);
  assert.ok(bytes.equals(Buffer.from(after[name].buffer, after[name].byteOffset, n*n*4)), `${name}: v2 != v3 WASM`);
  assert.ok(bytes.equals(native.subarray(28+i*n*n*4, 28+(i+1)*n*n*4)), `${name}: v2 != native`);
  sha256[name] = createHash('sha256').update(bytes).digest('hex');
}
const result = { source_commit: '0386bb8', seed, n, maps, sha256, samplesCompared: 3*n*n,
  differences: 0, comparison: 'Original v2 WASM == all-switches-off v3 WASM == native, byte-for-byte' };
const output = process.argv[2] || 'build/terrain/v2-disabled.json';
writeFileSync(output, JSON.stringify(result, null, 2)+'\n');
console.log(result);
