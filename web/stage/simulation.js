import {Encounter} from '../engine/encounter.js';

export const STEP = .1;
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const copy=p=>({...p});

// P3 roaming is JS. Every fight order and state transition remains in C/WASM.
// Both roaming and encounters sample a single time-indexed input at 10 Hz;
// display frames only consume the accumulator and interpolate snapshots.
export class StageSimulation {
  constructor({combat,profile,enemyProfile,nest,home,groundY,obstacles=[],seed=42,onTick=()=>{}}) {
    Object.assign(this,{combat,profile,enemyProfile,nest:copy(nest),home:copy(home),groundY,obstacles,seed:seed>>>0,onTick});
    this.player={...nest,yaw:0,hp:profile.hp,stamina:profile.stamina,speed:0};
    this.enemy={...home,yaw:Math.PI,hp:enemyProfile.hp,stamina:enemyProfile.stamina,speed:0,dead:false};
    this.previous=[copy(this.player),copy(this.enemy)];
    this.accumulator=0;this.ticks=0;this.started=0;this.paused=false;
    this.encounter=null;this.lastEncounter=null;this.outcome=null;this.respawn=0;this.cooldown=0;this.returning=false;
    this.hits=[];this.completed=[];
  }
  get alpha(){return this.accumulator/STEP}
  canWalk(from,to,radius=.7){
    if(Math.max(Math.abs(to.x),Math.abs(to.z))>195)return false;
    // Water is at y=0 in the valley. Ground deeper than 0.7 m is inaccessible.
    if(this.groundY(to.x,to.z)<-.7)return false;
    const rise=Math.abs(this.groundY(to.x,to.z)-this.groundY(from.x,from.z));
    if(rise>distance(from,to)*1.2+.04)return false;
    return !this.obstacles.some(o=>distance(o,to)<o.r+radius);
  }
  walk(entity,vector,speed){
    const length=Math.hypot(...vector);entity.speed=0;if(!length)return;
    const dx=vector[0]/length,dz=vector[1]/length;
    const slope=Math.abs(this.groundY(entity.x+dx,entity.z+dz)-this.groundY(entity.x,entity.z));
    const step=speed*STEP/(1+slope*.65),from=copy(entity),to={x:entity.x+dx*step,z:entity.z+dz*step};
    // Slide along a simple radius collision instead of sticking to a corner.
    if(this.canWalk(from,to))Object.assign(entity,to);
    else for(const axis of ['x','z']){const slide={x:entity.x,z:entity.z,[axis]:to[axis]};if(this.canWalk(entity,slide))Object.assign(entity,slide)}
    entity.speed=distance(from,entity)/STEP;
    if(entity.speed)entity.yaw=Math.atan2(dx,dz);
  }
  startEncounter(){
    const point={x:(this.player.x+this.enemy.x)/2,z:(this.player.z+this.enemy.z)/2};
    const spawn=(entity,profile,team,foe)=>({profile:{...profile,hp:entity.hp,stamina:entity.stamina},
      x:entity.x-point.x+20,y:entity.z-point.z+20,fx:foe.x-entity.x,fy:foe.z-entity.z,team});
    this.encounter=new Encounter(this.combat,{point,enemyBot:2,setup:{seed:this.seed,flat:true,creatures:[
      spawn(this.player,this.profile,0,this.enemy),spawn(this.enemy,this.enemyProfile,1,this.player)]}});
    this.started++;this.outcome=null;this.hits=[];
  }
  finish(outcome){
    this.outcome=outcome;this.lastEncounter=this.encounter;
    this.completed.push({outcome,log:this.encounter.exportLog(),hash:this.encounter.hashes.at(-1)});
    this.encounter=null;this.cooldown=8;this.player.speed=0;this.enemy.speed=0;
    if(outcome==='victory'){this.enemy.dead=true;this.enemy.speed=0}
    else {this.returning=true;if(outcome==='death')this.respawn=2}
  }
  fight(intent){
    const encounter=this.encounter;
    // Sprint uses C's stamina-paying flee verb while near the opponent.
    // Once separated, directional walking carries the player over the boundary.
    const sprint=intent.sprint&&Math.hypot(...(intent.move||[0,0]))>0&&distance(this.player,this.enemy)<15.2;
    encounter.advance(STEP,sprint?{flee:true}:intent);
    encounter.current.forEach((c,i)=>{
      const target=i?this.enemy:this.player,old=copy(target),p=encounter.toValley(c);
      Object.assign(target,p,{hp:c.hp,stamina:c.stamina,yaw:Math.atan2(c.fx,c.fy),phase:c.phase,move:c.move,ptick:c.ptick,plen:c.plen});
      target.speed=distance(target,old)/STEP;
      const damage=old.hp-c.hp;if(damage>0)this.hits.push({id:i,amount:damage,time:this.ticks*STEP,x:p.x,z:p.z});
    });
    if(!encounter.current[0].alive)this.finish('death');
    else if(!encounter.current[1].alive)this.finish('victory');
    else {
      const p=encounter.current[0];
      const radius=this.profile.radiusCm?this.profile.radiusCm/100:0.6;
      if(Math.min(p.x,p.y,40-p.x,40-p.y)<radius+0.25&&distance(this.player,this.enemy)>8)this.finish('fled');
    }
  }
  tick(intent){
    this.previous=[copy(this.player),copy(this.enemy)];
    if(this.encounter)this.fight(intent);
    else if(this.respawn>0){
      this.respawn=Math.max(0,this.respawn-STEP);
      if(this.respawn<1e-8){Object.assign(this.player,this.nest,{hp:this.profile.hp,stamina:this.profile.stamina,speed:0});this.respawn=0}
    }else{
      const moving=Math.hypot(...(intent.move||[0,0]))>0,sprint=intent.sprint&&moving&&this.player.stamina>2;
      this.walk(this.player,intent.move||[0,0],this.profile.speed*(sprint?1.7:1));
      this.player.stamina=Math.max(0,Math.min(this.profile.stamina,this.player.stamina+(sprint?-14:10)*STEP));
      this.cooldown=Math.max(0,this.cooldown-STEP);
      if(!this.enemy.dead){
        const target=this.returning?this.home:distance(this.enemy,this.player)<15&&this.cooldown<=0?this.player:
          {x:this.home.x+Math.sin(this.ticks*.025)*3,z:this.home.z+Math.cos(this.ticks*.025)*2};
        this.walk(this.enemy,[target.x-this.enemy.x,target.z-this.enemy.z],distance(target,this.enemy)>.4?2.8:0);
        if(this.returning&&distance(this.enemy,this.home)<.6)this.returning=false;
        if(!this.returning&&this.cooldown<=0&&distance(this.player,this.enemy)<5.5)this.startEncounter();
      }
    }
    this.ticks++;this.onTick(this);
  }
  advance(delta,sample=()=>({})){
    if(!Number.isFinite(delta)||delta<0)throw new RangeError('stage delta');
    if(this.paused)return;
    this.accumulator+=delta;
    while(this.accumulator+1e-9>=STEP){this.tick(sample(this.ticks*STEP,this.ticks)||{});this.accumulator=Math.max(0,this.accumulator-STEP)}
  }
}
