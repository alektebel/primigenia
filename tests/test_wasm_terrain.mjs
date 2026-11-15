import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createTerrain } from '../web/terrain-lab/terrain.mjs';
const progress = [];
const engine = await createTerrain({ onTerrainProgress: (stage, done, total) => {
  assert.ok(done >= 0 && done <= total); progress.push(stage);
} });
assert.equal(engine.module._ct_generate(), -8);
assert.equal(engine.module._ct_map(7), 0);
for (const options of [{seed:-1},{seed:2**32},{n:2048},{n:NaN},{droplets:-1},{thermal:.5},{droplets:2**32+70000},{thermal:2**32+5},{warp:NaN},{ridge:2}]) {
  assert.throws(() => engine.generate(options));
}
for (const seed of [1,7,42]) {
  const t=engine.generate({seed,n:32,droplets:300,thermal:3});
  assert.equal(t.hash,readFileSync(`tests/golden/terrain-${seed}.hash`,'utf8').trim());
}
const rows = [];
for (const [seed,n] of [[1,256],[7,256],[42,256],[1,1024]]) {
  const native=execFileSync('build/terrain_cli',['hash','--seed',String(seed),'--n',String(n)],{encoding:'utf8'}).trim().split(/\s+/);
  const t=engine.generate({seed,n});
  assert.equal(t.hash,native[0],`seed ${seed} N=${n}`);
  assert.equal(t.height.length,n*n);
  for (const map of [t.height,t.flow,t.sediment]) assert.ok(map.every(Number.isFinite));
  console.log(`seed ${seed} N=${n}: ${t.hash}; native ${native[1]}s, WASM ${t.seconds.toFixed(4)}s`);
  rows.push({seed,n,hash:t.hash,native_seconds:Number(native[1]),wasm_seconds:t.seconds});
}
assert.ok(progress.includes(0) && progress.includes(1) && progress.includes(2) && progress.includes(3) && progress.includes(4));
assert.ok(rows.at(-1).wasm_seconds<=10,'W13: default 1024 generation exceeds 10 seconds');
assert.equal(engine.module._ct_map(7),0);
mkdirSync('build/terrain',{recursive:true});
writeFileSync('build/terrain/parity.json',JSON.stringify({node:process.version,platform:process.platform,arch:process.arch,rows},null,2)+'\n');
console.log('terrain WASM: small goldens + four native/WASM hashes match; W13 PASS');
