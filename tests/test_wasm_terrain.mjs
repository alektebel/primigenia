import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createTerrain } from '../web/terrain-lab/terrain.mjs';
const progress = [];
const engine = await createTerrain({ onTerrainProgress: (stage, done, total) => {
  assert.ok(done >= 0 && done <= total); progress.push(stage);
} });
assert.equal(engine.module._ct_generate(), -8);
assert.equal(engine.module._ct_map(7), 0);
for (const options of [{seed:-1},{seed:2**32},{n:2048},{n:NaN},{droplets:-1},{thermal:.5},{droplets:2**32+70000},{thermal:2**32+5},{stream:-1},{stream:2**32+48},{stream:1.5},{warp:NaN},{ridge:2},{gentle:NaN},{variety:-1},{bands:2},{coast:NaN},{rock:-1},{volcano:2},{caves:NaN}]) {
  assert.throws(() => engine.generate(options));
}
for (const seed of [1,7,42]) {
  const t=engine.generate({seed,n:32,droplets:300,thermal:3});
  assert.equal(t.hash,readFileSync(`tests/golden/terrain-${seed}.hash`,'utf8').trim());
}
const rows = [];
for (const [seed,n] of [[1,256],[7,256],[42,256],[99,256],[1234,256],[31337,256],[1,1024],[42,1024]]) {
  const native=execFileSync('nice',['-n','10','build/terrain_cli','hash','--seed',String(seed),'--n',String(n)],{encoding:'utf8'}).trim().split(/\s+/);
  const t=engine.generate({seed,n});
  assert.equal(t.hash,native[0],`seed ${seed} N=${n}`);
  assert.equal(t.height.length,n*n);
  for (const map of [t.height,t.flow,t.sediment,t.level]) assert.ok(map.every(Number.isFinite));
  assert.ok(t.material instanceof Uint8Array);assert.equal(t.material.length,n*n);
  assert.ok(t.material.every(v=>v<=5));assert.ok(!t.material.includes(3));
  assert.ok(t.entrances.length>=3 && t.entrances.length<=6);
  const features=JSON.parse(execFileSync('nice',['-n','10','build/terrain_cli','features','--seed',String(seed),'--n',String(n)],{encoding:'utf8'}));
  assert.deepEqual(t.material.reduce((a,v)=>(a[v]++,a),[0,0,0,0,0,0]),features.materials);
  assert.equal(t.entrances.length,features.caves.length);
  for(const [i,v] of t.entrances.entries()) {
    for(const key of ['position','facing','size'])for(let j=0;j<v[key].length;j++)assert.ok(Math.abs(v[key][j]-features.caves[i][key][j])<1e-5);
    assert.equal(v.waterfall,Boolean(features.caves[i].waterfall));
  }
  assert.equal(t.size,3600);assert.equal(t.version,4);
  assert.ok(t.level.every((v,i)=>t.height[i]<=0||v>=t.height[i]),'water level under the ground');
  console.log(`seed ${seed} N=${n}: ${t.hash}; native ${native[1]}s, WASM ${t.seconds.toFixed(4)}s`);
  rows.push({seed,n,hash:t.hash,native_seconds:Number(native[1]),wasm_seconds:t.seconds});
}
for (const [gentle,variety,bands] of [[0,0,0],[1,0,0],[0,1,0],[0,0,1],[.5,.5,.5]]) {
  const native=execFileSync('nice',['-n','10','build/terrain_cli','hash','--seed','42','--n','128',
    '--gentle-bases',String(gentle),'--layout-variety',String(variety),'--cliff-bands',String(bands)],{encoding:'utf8'}).trim().split(/\s+/);
  assert.equal(engine.generate({seed:42,n:128,gentle,variety,bands}).hash,native[0]);
}
for (const [coast,rock,volcano,caves] of [[0,0,0,0],[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1],[.5,.5,.5,.5]]) {
  const native=execFileSync('nice',['-n','10','build/terrain_cli','hash','--seed','42','--n','128',
    '--sea-cliffs',String(coast),'--hard-rock',String(rock),'--volcano',String(volcano),'--caves',String(caves)],{encoding:'utf8'}).trim().split(/\s+/);
  assert.equal(engine.generate({seed:42,n:128,coast,rock,volcano,caves}).hash,native[0]);
}
// Map bytes from original v2 (0386bb8), independent of v3's hash schema.
const baseline = JSON.parse(readFileSync('tests/golden/terrain-v2-maps.json', 'utf8'));
const unchanged = engine.generate({seed:baseline.seed,n:baseline.n,gentle:0,variety:0,bands:0,coast:0,rock:0,volcano:0,caves:0,rivers:0});
mkdirSync('build/terrain',{recursive:true});
const baselinePath = 'build/terrain/v2-regression.bin';
execFileSync('nice', ['-n','10','build/terrain_cli','dump','--seed',String(baseline.seed),'--n',String(baseline.n),'--out',baselinePath,
  ...['gentle-bases','layout-variety','cliff-bands','sea-cliffs','hard-rock','volcano','caves','rivers'].flatMap(name=>['--'+name,'0'])]);
const baselineNative = readFileSync(baselinePath), mapBytes = baseline.n*baseline.n*4;
for (const [i,name] of ['height','flow','sediment'].entries()) {
  const bytes = Buffer.from(unchanged[name].buffer, unchanged[name].byteOffset, mapBytes);
  assert.equal(createHash('sha256').update(bytes).digest('hex'),baseline.sha256[name],`original v2 ${name}`);
  assert.ok(bytes.equals(baselineNative.subarray(28+i*mapBytes,28+(i+1)*mapBytes)),`native v2 ${name}`);
}
console.log('original v2: all 196,608 height/flow/sediment samples match byte-for-byte, native and WASM');
assert.ok(progress.includes(0) && progress.includes(1) && progress.includes(2) && progress.includes(3) && progress.includes(4));
assert.ok(rows.at(-1).wasm_seconds<=10,'W13: default 1024 generation exceeds 10 seconds');
assert.equal(engine.module._ct_map(7),0);
mkdirSync('build/terrain',{recursive:true});
writeFileSync('build/terrain/parity.json',JSON.stringify({node:process.version,platform:process.platform,arch:process.arch,rows},null,2)+'\n');
console.log('terrain WASM: small goldens + eight native/WASM hashes and independent deltas match; W13 PASS');
