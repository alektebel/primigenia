const assert=require('node:assert/strict');
const fs=require('node:fs');
const D=require('../web/studio/genome.js');
const table=require('../web/studio/parts.json');
const types=Object.fromEntries(table.parts.map(p=>[p.id,p]));
const sample={schema:'cpore.creature/4',name:'Ñandu 🦎',nodes:[{y:1,z:-2,r:.1},{y:1,z:-1,r:.5},{y:1.5,z:0,r:.6},{y:2,z:1,r:.4}],parts:[{type:'ojo',t:.9,ang:.8,size:1}],skin:{pat:1,cA:'#aabbcc',cB:'#112233',cC:'#ffffff',wet:.3,scale:7},regions:[]};
assert.deepEqual(D.parse(sample,types).genome,sample);
for(const mutate of [g=>g.schema='bad',g=>g.nodes[0].r=-1,g=>g.parts[0].type='missing',g=>g.parts[0].t=Infinity,g=>g.skin.cA='red',g=>g.nodes[0].x=2,g=>g.regions=null,g=>g.parts=[null],g=>g.parts[0].size=999,g=>g.name='<script>',g=>g.parts[0].mystery=1]){
 const g=structuredClone(sample);mutate(g);assert.throws(()=>D.parse(g,types));
}
for(const version of [1,2,3]){
 const legacy=JSON.parse(fs.readFileSync(`tests/fixtures/studio/v${version}.json`));
 const {genome,warnings}=D.parse(legacy,types);
 assert.equal(genome.schema,'cpore.creature/4');assert(warnings.length>0);
 assert.deepEqual(genome.migration.source,legacy,'preserve original');
 assert.equal(genome.regions.length,version===1?0:1);
 assert.deepEqual(D.parse(genome,types).genome,genome,'migration round trip');
 const invalid=structuredClone(legacy);invalid.body.torso=99;assert.throws(()=>D.parse(invalid,types));
}
console.log('Studio document validation and /1 /2 /3 migration contracts passed');
