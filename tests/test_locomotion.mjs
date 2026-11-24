import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {analyzeMorphology, gaitFor, Locomotion, insideSupport, supportPolygon} from '../web/creature/locomotion.js';

const fixtures=JSON.parse(readFileSync(new URL('./fixtures/locomotion/plans.json',import.meta.url)));
const catalog=JSON.parse(readFileSync(new URL('../web/studio/parts.json',import.meta.url))).parts;
const models=fixtures.map(f=>analyzeMorphology(f.genome,{catalog}));

test('spine volumes, mirrored part masses, COM and inertia respond to anatomy',()=>{
 const g={nodes:[{y:1,z:-1,r:.5},{y:1,z:1,r:.5}],parts:[]};
 const m=analyzeMorphology(g);
 assert(Math.abs(m.volume-Math.PI*.5)<1e-8);
 assert(Math.abs(m.centerOfMass.z)<1e-8);
 assert(m.massKg>100&&m.moments.x>m.moments.z);
 const armored=analyzeMorphology({...g,parts:[{type:'shell_plate',t:1,ang:0,size:2}]},{catalog});
 assert(armored.massKg>m.massKg);assert(armored.centerOfMass.z>0);
 const symmetric=analyzeMorphology({...g,parts:[{type:'shell_plate',t:.8,ang:1,size:2}]},{catalog});
 assert(Math.abs(symmetric.centerOfMass.x)<1e-8);
});

test('fixtures cover upright/horizontal bipeds, light/heavy quadrupeds, hexapod, Zancuda and slither',()=>{
 assert.deepEqual(models.map(m=>m.bodyPlan),fixtures.map(f=>f.plan));
 assert.deepEqual(models.map(m=>m.legs.length),[2,2,4,4,6,2,0]);
 assert(models[3].massKg>models[2].massKg*2);
 assert(models[5].neckMoment>models[2].neckMoment);
 for(const m of models){assert(m.massKg>0);assert(Object.values(m.moments).every(v=>v>0));assert(m.proposal.maxSpeed>0);assert(m.proposal.acceleration>0)}
});

test('Froude transition boundaries and lateral sequence footfalls are dimensionless',()=>{
 for(const m of models.filter(m=>m.legs.length===2||m.legs.length===4)){
  const at=fr=>gaitFor(m,Math.sqrt(fr*9.81*m.legLength));
  assert.equal(at(.49).name,'walk');assert.equal(at(.51).name,m.legs.length===2?'run':'trot');
  if(m.legs.length===4){assert.equal(at(2.01).name,'canter');assert.equal(at(3.01).name,'gallop')}
 }
 const m=models[2],g=gaitFor(m,1);
 const order=m.legs.map((l,i)=>({label:l.label,phase:g.offsets[i]})).sort((a,b)=>a.phase-b.phase);
 assert.deepEqual(order.map(l=>l.label),['LH','LF','RH','RF']);
 assert(g.duty>.75);assert.equal(gaitFor(models[4],2).name,'tripod');
});

test('heavier bodies lower cadence at the same leg length and speed; uphill shortens stride',()=>{
 const light=models[2],heavy={...light,load:light.load*8,massKg:light.massKg*8};
 assert(gaitFor(heavy,2).cadence<gaitFor(light,2).cadence);
 assert(gaitFor(light,2,.3).stride<gaitFor(light,2).stride);
});

test('stance targets stay fixed through turns, slopes, speed transitions and stops',()=>{
 for(const m of models){
  const loco=new Locomotion(m);let last=[],contacts=0;
  for(let i=0;i<900;i++){
   const t=i/60,a=t*.12,v=1.2,pose={x:10*Math.sin(a),z:10*(1-Math.cos(a)),yaw:Math.PI/2-a,speed:v,turnRate:-.12,groundY:(x,z)=>.04*x+.02*z};
   const s=loco.update(1/60,pose);
   s.feet.forEach((f,j)=>{if(!f.swing&&last[j]&&!last[j].swing)assert(Math.hypot(f.position.x-last[j].x,f.position.y-last[j].y,f.position.z-last[j].z)<1e-10);last[j]={...f.position,swing:f.swing};if(f.contact)contacts++});
   if(s.staticallyStable)assert(insideSupport(s.centerOfMass,s.support));
  }
  if(m.legs.length)assert(contacts>5);
  const phase=loco.phase;for(let i=0;i<60;i++)loco.update(1/60,loco.previous);
  assert.equal(loco.phase,phase);
 }
});

test('swing clears sampled obstacles, touchdown happens once, and teleport resets feet',()=>{
 const m=models[2],loco=new Locomotion(m);let raised=false,contact=false;
 const groundY=(x,z)=>z>.4&&z<.9?.35:0;
 for(let i=0;i<400;i++){
  const s=loco.update(1/60,{x:0,z:i/60,yaw:0,speed:1,groundY});
  for(const f of s.feet){if(f.swing&&f.position.y>.35)raised=true;if(f.contact)contact=true}
 }
 assert(raised&&contact);
 const s=loco.update(1/60,{x:100,z:100,yaw:0,speed:0,groundY});
 assert(s.feet.every(f=>Math.abs(f.position.x-100)<5&&!f.swing));
 assert.throws(()=>loco.update(-1,loco.previous),RangeError);
});

test('support hull handles collinear and asymmetric limbs without claiming static stability',()=>{
 assert.equal(insideSupport({x:0,z:0},[]),false);
 assert.equal(insideSupport({x:0,z:0},[{x:0,z:0}]),false);
 const hull=supportPolygon([{x:-1,z:-1},{x:1,z:-1},{x:1,z:1},{x:-1,z:1},{x:0,z:0}]);
 assert.equal(hull.length,4);assert(insideSupport({x:0,z:0},hull));assert(!insideSupport({x:2,z:0},hull));
 const empty=analyzeMorphology({nodes:[],parts:[]});assert.equal(empty.bodyPlan,'slither');
});
