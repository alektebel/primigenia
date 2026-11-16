// Regenerates expected.json from the web sources of truth
// (web/studio/genome.js, web/studio/growth.js). Run from the repo root:
//   node godot/creature/tests/parity/gen_parity.cjs
// The Godot tests compare CreatureGenome / CreatureGrowth against this file.
const fs=require('node:fs');
const D=require('../../../../web/studio/genome.js');
const G=require('../../../../web/studio/growth.js');
const table=require('../../../../web/studio/parts.json');
const types=Object.fromEntries(table.parts.map(p=>[p.id,p]));
const fx=n=>JSON.parse(fs.readFileSync('tests/fixtures/studio/'+n));
const out={migrations:{},errors:[],growth:[]};
for(const v of [1,2,3])out.migrations['v'+v]=D.parse(fx(`v${v}.json`),types);
out.migrations.v4_glb=D.parse(fx('v4-glb-parts.json'),types);
const sample={schema:'cpore.creature/4',name:'Ñandu 🦎',nodes:[{y:1,z:-2,r:.1},{y:1,z:-1,r:.5},{y:1.5,z:0,r:.6},{y:2,z:1,r:.4}],parts:[{type:'ojo',t:.9,ang:.8,size:1}],skin:{pat:1,cA:'#aabbcc',cB:'#112233',cC:'#ffffff',wet:.3,scale:7},regions:[]};
const region={schema:'cpore.growth/1',family:'horns',seed:17,count:7,length:1,curve:.45,branches:1,surface:'torso',position:.6,coverage:.4,angle:.55,mirror:true,id:'region-1'};
const cases=[];
const add=(label,doc)=>{let error=null;try{D.parse(doc,types)}catch(e){error=e.message}cases.push({label,doc,error})};
add('sample',sample);
const muts={schema:g=>g.schema='bad',radius:g=>g.nodes[0].r=-1,type:g=>g.parts[0].type='missing',color:g=>g.skin.cA='red',extraNode:g=>g.nodes[0].x=2,regionsNull:g=>g.regions=null,
 partNull:g=>g.parts=[null],size:g=>g.parts[0].size=999,name:g=>g.name='<script>',mystery:g=>g.parts[0].mystery=1,close:g=>g.nodes[1]={y:1,z:-1.98,r:.3},
 pat:g=>g.skin.pat=1.5,legNoK:g=>g.parts.push({type:'pata',t:.5,ang:2,w:.2,f:[0,-1,0]}),hornNoCurve:g=>g.parts.push({type:'cuerno',t:.5,ang:2,size:1,len:1}),
 region:g=>g.regions=[structuredClone(region)],dupRegion:g=>g.regions=[structuredClone(region),structuredClone(region)],
 regionCount:g=>{g.regions=[structuredClone(region)];g.regions[0].count=1.5},regionSurface:g=>{g.regions=[structuredClone(region)];g.regions[0].surface='head'},
 regionFamily:g=>{g.regions=[structuredClone(region)];g.regions[0].family='none'},regionMirror:g=>{g.regions=[structuredClone(region)];g.regions[0].mirror=1},
 regionMissing:g=>{g.regions=[structuredClone(region)];delete g.regions[0].count},migrationBad:g=>g.migration={from:5,warnings:[],source:{}}};
for(const [k,f]of Object.entries(muts)){const g=structuredClone(sample);f(g);add(k,g)}
for(const v of [1,2,3]){const g=fx(`v${v}.json`);g.body.torso=99;add('v'+v+'-torso',g);const h=fx(`v${v}.json`);h.parts=h.parts.filter(p=>p.slot!=='mouth');add('v'+v+'-nomouth',h);
 const e=fx(`v${v}.json`);e.extra=1;e.skin.extra=2;add('v'+v+'-extra',e)}
const v2=fx('v2.json');v2.growth.family='none';add('v2-none',v2);const v2b=fx('v2.json');delete v2b.growth.schema;add('v2-noschema',v2b);
out.errors=cases;
for(const r of [{family:'horns',seed:491,count:9,length:1.25,curve:.65,branches:3},{family:'plates',seed:17,count:3,length:1,curve:.45,branches:0},
  {family:'tendrils',seed:4294967295,count:2,length:2.4,curve:-1,branches:3},{family:'horns',seed:0,count:1,length:.2,curve:1,branches:0}]){
 const g=G.generate(r);out.growth.push({recipe:r,pieces:g.pieces.map(p=>({positions:Array.from(p.positions,x=>+x.toFixed(6)),indices:Array.from(p.indices),rootRadius:p.rootRadius,offset:p.offset}))});
}
fs.writeFileSync('godot/creature/tests/parity/expected.json',JSON.stringify(out));
console.log('wrote',cases.length,'error cases;',out.growth.length,'growth recipes');
