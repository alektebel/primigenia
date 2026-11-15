import assert from 'node:assert/strict';
import {World} from '../web/engine/cpworld.js';
import {StageSimulation} from '../web/stage/simulation.js';
const world=await World.create();
const profile={mouth:2,charge:1,spit:0,tail:0,guard:0,hp:100,stamina:100,speed:4};
function create(water,obstacles=[],home={x:0,z:18}){return new StageSimulation({world,profile,enemyProfile:profile,nest:{x:0,z:0},home,terrain:1,water,obstacles})}
let s=create();s.advance(1,()=>({move:[1,0],sprint:true}));assert(s.player.x>4);assert(s.player.stamina<100);
const x=s.player.x;s.paused=true;s.advance(1,()=>({move:[1,0]}));assert.equal(s.player.x,x);
s=create({x:10,z:0,r:9});s.advance(2,()=>({move:[1,0]}));assert(s.player.x<=1,'deep water blocks roaming');
s=create(undefined,[{x:2,z:0,r:1}]);s.advance(2,()=>({move:[1,0]}));assert(s.player.x<1,'rock blocks roaming');
const runs=[];
for(const fps of [30,73]){
 s=create();for(let f=0;f<90*fps&&!s.outcome;f++)s.advance(1/fps,t=>t<2?{move:[0,1]}:{attack:0});
 assert(s.started>0);assert(s.outcome);assert(s.lastEncounter.current.every((c,i)=>c.hp<100));
 runs.push({log:s.lastEncounter.exportLog(),hash:s.lastEncounter.hashes.at(-1)});
}
assert.deepEqual(runs[0],runs[1]);
console.log('PASS stage collision, water, sprint, pause, natural encounter/outcome and 30/73 FPS log equality');
// Death really fades/respawns at the nest and restores the same profile pool.
s=create();for(let t=0;t<900&&!s.outcome;t++)s.advance(.1,time=>time<2?{move:[0,1]}:{});
assert.equal(s.outcome,'death');const deathLog=s.lastEncounter.exportLog();s.advance(2.1);assert.equal(s.respawn,0);assert.equal(s.player.hp,profile.hp);assert.equal(s.player.x,s.nest.x);assert.equal(s.player.z,s.nest.z);assert.equal(s.lastEncounter.exportLog(),deathLog);
// Escape is a boundary crossing through real C movement, followed by homing.
s=create();for(let t=0;t<900&&!s.outcome;t++)s.advance(.1,()=>s.encounter?{move:[1,0],sprint:true}:{move:[0,1]});
assert.equal(s.outcome,'fled');const fleeHome={...s.home};for(let i=0;i<200&&s.returning;i++)s.advance(.1,()=>({move:[1,0]}));assert(!s.returning);assert(Math.hypot(s.enemy.x-fleeHome.x,s.enemy.z-fleeHome.z)<1);
console.log('PASS death/respawn and boundary flee/return home');
// Smooth acceleration/braking, continuous turns, target arrival and action approach.
s=create(undefined,[],{x:0,z:150});
s.tick({move:[.3,1]});const firstSpeed=s.player.speed;assert(firstSpeed>0&&firstSpeed<profile.speed);
for(let i=0;i<15;i++)s.tick({move:[.3,1]});
const fast=s.player.speed;s.tick({});assert(s.player.speed>0&&s.player.speed<fast,'braking has a curve');
const yaw=s.player.yaw;s.tick({move:[1,0]});assert(Math.abs(s.player.yaw-yaw)<.7,'limited turning speed');
s=create(undefined,[],{x:0,z:150});s.destination={x:5,z:6};
s.advance(6);assert(Math.hypot(s.player.x-5,s.player.z-6)<.25,'click destination reached');
s=create();s.advance(90,()=>({attack:0}));assert(s.started>0&&s.outcome,'selected action approaches and fights');
console.log('PASS smooth locomotion, destination arrival and approach-to-attack');
