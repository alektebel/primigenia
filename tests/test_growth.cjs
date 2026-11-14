const assert=require('node:assert/strict');
const {performance}=require('node:perf_hooks');
const G=require('../web/studio/growth.js');

for(const family of ['horns','plates','tendrils']) {
  const recipe={family,seed:4294967295,count:18,branches:3,length:2.4,curve:-1};
  const a=G.generate(recipe),b=G.generate(recipe);
  assert.deepEqual(a,b,`${family}: repeatable geometry`);
  for(const p of a.pieces) {
    assert(p.positions.length===p.normals.length);
    assert(p.positions.every(Number.isFinite));
    assert(p.normals.every(Number.isFinite));
    assert(p.indices.every(i=>i<p.positions.length/3));
    for(let n=0;n<p.normals.length;n+=3)
      assert(Math.abs(Math.hypot(...p.normals.subarray(n,n+3))-1)<.001,`${family}: unit normals`);
  }
  const variant=G.generate({...recipe,seed:17});
  assert.notDeepEqual(a.pieces[0].positions,variant.pieces[0].positions,`${family}: seed changes form`);
}
const simple=G.generate({branches:0,count:1}),branched=G.generate({branches:3,count:1});
assert(branched.pieces[0].indices.length>simple.pieces[0].indices.length,'branching adds topology');
assert.deepEqual(G.generate({count:2}).pieces[0].positions,G.generate({count:8}).pieces[0].positions,'density preserves existing shape seeds');
for(const bad of [{count:0},{count:1.5},{count:10000},{length:NaN},{seed:-1},{family:'unknown'}])
  assert.throws(()=>G.generate(bad));
const samples=[];
for(let i=0;i<120;i++) {
  const start=performance.now();
  G.generate({family:'tendrils',count:18,branches:3,seed:i});
  if(i>=20)samples.push(performance.now()-start);
}
samples.sort((a,b)=>a-b);
console.log('Growth contracts passed. CPU-only stress generation (18 tendrils, 3 branches):',
  JSON.stringify({p50_ms:+samples[50].toFixed(2),p95_ms:+samples[95].toFixed(2)}));
