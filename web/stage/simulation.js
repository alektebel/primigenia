import {Encounter,heading} from '../engine/encounter.js';
import {WORLD_VERB as V} from '../engine/cpworld.js';
export const STEP=.1;
const copy=p=>({...p});
/* Display adapter: all state transitions happen in cw_step, once per 100 ms. */
export class StageSimulation {
 constructor({world,profile,enemyProfile,nest,home,obstacles=[],seed=42,terrain=0,water,flatHeight=2,onTick=()=>{}}){
  if(!world)throw Error('StageSimulation requires a C World');
  Object.assign(this,{world,combat:world.combat,profile,enemyProfile,nest:copy(nest),home:copy(home),seed:seed>>>0,onTick});
  world.reset({seed:this.seed,terrain,profile,nest,flatHeight,water,obstacles,wild:[{...home,home,species:3,bot:2,profile:enemyProfile}]});
  this.accumulator=0;this.paused=false;this.encounter=null;this.lastEncounter=null;this.completed=[];this.hits=[];this.events=[];this.log=[];this.hashes=[];
  this.destination=null;this.pendingAttack=null;this.sync();this.previous=[copy(this.player),copy(this.enemy)];
 }
 get alpha(){return this.accumulator/STEP}
 sync(){const s=this.world.snapshot();this.state=s;this.player=s.entities[0];this.enemy=s.entities[1];Object.assign(this,{ticks:s.tick,clock:s.clock,started:s.started,outcome:s.outcome,respawn:s.respawn,cooldown:s.cooldown,returning:this.enemy.returning});}
 action(intent){
  const vector=heading(intent.move??[0,0]);
  if(vector){this.destination=null;this.pendingAttack=null;}
  if(intent.attack!==undefined&&intent.attack!==null&&!this.enemy.dead){this.pendingAttack=intent.attack;this.destination=null;}
  if(intent.flee)return {verb:V.FLEE};
  if(intent.dodge!==undefined&&intent.dodge!==false)return {verb:V.DODGE,dir:intent.dodge===true?0:intent.dodge};
  if(intent.guard)return {verb:V.GUARD};
  if(this.pendingAttack!==null)return {verb:V.ATTACK,target:1,move:this.pendingAttack};
  if(vector)return {verb:V.HEADING,hx:vector.hx,hz:vector.hy,sprint:!!intent.sprint};
  if(this.destination)return {verb:V.GO,...this.destination,sprint:!!intent.sprint};
  return {verb:V.WAIT};
 }
 beginEncounter(){
  // Encounter is used solely as a snapshot/log container; C already reset it.
  const e=Object.create(Encounter.prototype);Object.assign(e,{combat:this.combat,point:this.state.point,player:0,enemy:1,accumulator:0,log:[],hashes:[],lastOrderError:0});
  const states=this.combat.states();e.setup={seed:this.seed,flat:true,creatures:states.map((c,i)=>({profile:{...(i?this.enemyProfile:this.profile),hp:c.hp,stamina:c.stamina},x:c.x,y:c.y,fx:c.fx,fy:c.fy,team:i}))};e.current=states;e.previous=structuredClone(states);this.encounter=e;this.hits=[];
 }
 tick(intent={}){
  this.previous=[copy(this.player),copy(this.enemy)];const old=this.state,action=this.action(intent),result=this.world.step(action);this.log.push({tick:this.ticks,...action});this.hashes.push(result.hash);this.sync();
  if(this.destination&&this.state.order.verb!==V.GO)this.destination=null;
  if(this.started>old.started)this.beginEncounter();
  const e=this.encounter;
  this.events=this.combat.events();
  if(e&&this.combat.tick>e.hashes.length){
   e.previous=e.current;e.current=this.combat.states();e.hashes.push(this.combat.hash());this.world.orders().forEach((a,i)=>{if(this.state.accepted[i])e.log.push(a)});
   e.current.forEach((c,i)=>{const target=i?this.enemy:this.player;Object.assign(target,{phase:c.phase,move:c.move,ptick:c.ptick,plen:c.plen});const damage=this.previous[i].hp-c.hp;if(damage>0)this.hits.push({id:i,amount:damage,time:this.ticks*STEP,x:target.x,z:target.z});});
  }
  if(e&&this.state.active<0){this.lastEncounter=e;this.completed.push({outcome:this.outcome,log:e.exportLog(),hash:e.hashes.at(-1)});this.encounter=null;this.destination=null;this.pendingAttack=null;}
  this.onTick(this);
 }
 advance(delta,sample=()=>({})){if(!Number.isFinite(delta)||delta<0)throw RangeError('stage delta');if(this.paused)return;this.accumulator+=delta;
  while(this.accumulator+1e-9>=STEP){this.tick(sample(this.ticks*STEP,this.ticks)||{});this.accumulator=Math.max(0,this.accumulator-STEP)}
 }
 exportLog(){const lines=[this.world.exportSetup().trimEnd(),String(this.ticks)];for(const a of this.log)lines.push([a.verb??0,a.target??0,a.move??0,a.dir??0,a.sprint?1:0,a.hx??0,a.hz??0,Math.fround(a.x??0),Math.fround(a.z??0)].join(' '));return lines.join('\n')+'\n';}
}
