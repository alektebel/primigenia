const assert=require('node:assert/strict');
const fs=require('node:fs');
const D=require('../web/studio/genome.js');
const table=require('../web/studio/parts.json');
const types=Object.fromEntries(table.parts.map(p=>[p.id,p]));
const sample={schema:'cpore.creature/4',name:'Ñandu 🦎',nodes:[{y:1,z:-2,r:.1},{y:1,z:-1,r:.5},{y:1.5,z:0,r:.6},{y:2,z:1,r:.4}],parts:[{type:'ojo',t:.9,ang:.8,size:1}],skin:{pat:1,cA:'#aabbcc',cB:'#112233',cC:'#ffffff',wet:.3,scale:7},regions:[]};
assert.deepEqual(D.parse(sample,types).genome,sample);
// A /4 document saved while all 24 reference parts were GLBs must stay exact.
const savedGLBs=JSON.parse(fs.readFileSync('tests/fixtures/studio/v4-glb-parts.json'));
assert.equal(savedGLBs.parts.length,24);
assert.deepEqual(D.parse(savedGLBs,types),{genome:savedGLBs,warnings:[]});
for(const id of ['eye_triad','leg_sprinter','leg_sucker','arm_grasper','tail_paddle','tail_spike','wing_glider','frill_fan','beak_crusher','sac_spitter','arm_smasher','foot_spring','foot_hoof','foot_gecko','wing_insect','tail_hammer']){
 assert.equal(types[id].source,'procedural',id+' uses the creator geometry');
 assert.equal(types[id].shape_ref,'parts/'+id+'.glb');
 assert(fs.existsSync('web/studio/'+types[id].shape_ref));
}
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


const region={schema:'cpore.growth/1',family:'horns',seed:17,count:7,length:1,curve:.45,branches:1,surface:'torso',position:.6,coverage:.4,angle:.55,mirror:true,id:'region-1'};
for(const mutate of [r=>delete r.count,r=>r.id=undefined,r=>r.family='none',r=>r.surface='head',r=>r.mirror=1,r=>r.seed=-1,r=>r.count=1.5]){const g=structuredClone(sample);g.regions=[structuredClone(region)];mutate(g.regions[0]);assert.throws(()=>D.parse(g,types))}
const duplicate=structuredClone(sample);duplicate.regions=[region,region];assert.throws(()=>D.parse(duplicate,types));
const v2=JSON.parse(fs.readFileSync('tests/fixtures/studio/v2.json'));v2.growth.family='none';assert.equal(D.parse(v2,types).genome.regions.length,0);delete v2.growth.schema;assert.throws(()=>D.parse(v2,types));
assert.throws(()=>D.parse('{broken',types));assert.throws(()=>D.parse(null,types));
console.log('Studio document validation and /1 /2 /3 migration contracts passed');
