import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {World,WORLD_VERB as V} from '../web/engine/cpworld.js';
import {StageSimulation} from '../web/stage/simulation.js';
const world=await World.create(),second=await World.create();
const temp=mkdtempSync(join(tmpdir(),'cpore-world-'));
const update=process.argv.includes('--update-goldens');
const hashesFor=(log,file)=>{writeFileSync(file,log);return execFileSync('build/world_cli',['--replay',file],{encoding:'utf8',maxBuffer:2e6}).trim().split('\n')};
function run(seed,random=false){
 let rng=seed>>>0;const draw=()=>{rng=(Math.imul(rng,1664525)+1013904223)>>>0;return rng};
 const profile={mouth:2,charge:1,spit:2,tail:1,guard:1,hp:100,stamina:100,speed:4};
 const setup={seed,terrainSeed:seed,terrain:random?seed%2:0,profile,nest:{x:0,z:0},obstacles:[{x:5,z:0,r:1,type:1},{x:34.16093581616879,z:113.36430842876435,r:1.0850263082887979,type:0}],water:{x:10,z:0,r:3},wild:[
  {x:0,z:18,home:{x:0,z:18},species:3,bot:-1,profile},
  {x:25,z:15,home:{x:25,z:15},species:0,bot:-1,profile},
  {x:-18,z:4,home:{x:-18,z:4},species:2,bot:-1,profile},
 ]};
 world.reset(setup);second.reset(setup);
 const inputs=[],hashes=[];
 for(let i=0;i<3000;i++){
  const roll=draw();let a;
  if(!random&&i<250)a={verb:V.ATTACK,target:1,move:0};
  else if(!random&&i<340)a={verb:V.FLEE};
  else if(i%100<40)a={verb:V.HEADING,hx:(draw()%65535)-32767,hz:(draw()%65535)-32767,sprint:!!(roll&1)};
  else if(i%100<55)a={verb:V.GO,x:(draw()%120)-60,z:(draw()%120)-60};
  else if(i%100<70)a={verb:V.ATTACK,target:1+roll%3,move:[0,1,3,4][roll%4]};
  else if(i%100<80)a={verb:V.GO_NEST};
  else if(i%100<90)a={verb:V.FLEE};
  else if(i%100<93)a={verb:V.APPROACH,target:1+roll%3};
  else if(i%100<96)a={verb:V.GUARD};
  else if(i%100<99)a={verb:V.DODGE,dir:roll%8};
  else a={verb:V.WAIT};
  inputs.push([a.verb,a.target??0,a.move??0,a.dir??0,a.sprint?1:0,a.hx??0,a.hz??0,a.x??0,a.z??0].join(' '));
  const result=world.step(a);hashes.push(result.hash);assert.equal(second.step(a).hash,result.hash,'independent instances');
 }
 const log=world.exportSetup()+'3000\n'+inputs.join('\n')+'\n';
 assert.deepEqual(hashesFor(log,join(temp,'run.log')),hashes,`native/WASM seed ${seed}`);
 const obs=world.observe();assert.equal(obs.schema,'world-1');assert.equal(obs.tick,3000);assert(obs.nearby.every(e=>Number.isFinite(e.bearing)&&Number.isFinite(e.distance)));
 return {log,hashes,started:world.snapshot().started};
}
try{
 // Compare the C port against the reviewed analytic source without changing it.
 const hero=readFileSync('web/hero/index.html','utf8');
 const rng=hero.slice(hero.indexOf('const rngFrom='),hero.indexOf('const col='));
 const terrain=hero.slice(hero.indexOf('let perm;'),hero.indexOf('const walkable='));
 const original=Function(`const HALF=320;const lerp=(a,b,t)=>a+(b-a)*t,clamp=(x,a,b)=>Math.min(b,Math.max(a,x)),sstep=(a,b,x)=>{x=clamp((x-a)/(b-a),0,1);return x*x*(3-2*x)};${rng}${terrain};seedNoise(7);return height`)();
 world.reset({seed:42});
 const beforeInvalid=world.hash();
 assert.throws(()=>world.step({verb:2**32+3,hx:1}),/input/);
 assert.throws(()=>world.reset({seed:42,profile:{hp:NaN}}),/number/);
 assert.equal(world.hash(),beforeInvalid,'invalid wrapper inputs preserve live state');
 let maxHeightError=0;
 for(let x=-195;x<=195;x+=13)for(let z=-195;z<=195;z+=13)maxHeightError=Math.max(maxHeightError,Math.abs(world.height(x,z)-original(x,z)));
 assert(maxHeightError<.01,`analytic port error ${maxHeightError}`);
 console.log(`analytic C port: max height error ${maxHeightError.toFixed(6)} m on 961 valley samples`);
 world.reset({seed:42,obstacles:Array.from({length:1024},(_,i)=>({x:i%10,z:10,r:.1,type:i%2}))});
 assert.equal(world.observe().nearby.length,1026,'maximum nearby obstacle population fits observation ABI');
 mkdirSync('tests/golden',{recursive:true});
 for(const seed of [1,42,987654321]){const {log,hashes,started}=run(seed),path=`tests/golden/world-${seed}`;
  if(update){writeFileSync(path+'.log',log);writeFileSync(path+'.hashes',hashes.join('\n')+'\n');}
  console.log(`world golden ${seed}: ${started} encounters, 3,000 hashes`);
  assert.equal(readFileSync(path+'.log','utf8'),log);assert.deepEqual(readFileSync(path+'.hashes','utf8').trim().split('\n'),hashes);
 }
 for(let i=0;i<100;i++)run((Math.imul(i,2654435761)+17)>>>0,true);
 // A display-rate replay includes the roaming ticks and complete setup.
 const sessions=[];
 for(const fps of [30,73]){const p={mouth:2,charge:1,spit:0,tail:1,guard:0,hp:100,stamina:100,speed:4};const sim=new StageSimulation({world,profile:p,enemyProfile:p,nest:{x:0,z:0},home:{x:0,z:18},terrain:1});
  for(let i=0;i<30*fps;i++)sim.advance(1/fps,t=>t<2?{move:[0,1]}:{attack:0});
  const replay=hashesFor(sim.exportLog(),join(temp,'session.log'));assert.deepEqual(replay,sim.hashes);sessions.push({log:sim.exportLog(),hash:world.hash()});}
 assert.deepEqual(sessions[0],sessions[1]);
 console.log('PASS world: 3 committed 3,000-tick goldens; 100 random 3,000-tick native/WASM runs; independent instances; observations; full 30/73 FPS native replay');
}finally{rmSync(temp,{recursive:true,force:true});}
