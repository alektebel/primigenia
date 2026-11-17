/* World ABI v2. JS owns input encoding and snapshots, never simulation. */
import {Combat, defaultProfile} from './cpcombat.js';
export const WORLD_VERB=Object.freeze({CONTINUE:0,WAIT:1,GO:2,HEADING:3,APPROACH:4,ATTACK:5,FLEE:6,GO_NEST:7,GUARD:8,DODGE:9});
export class World {
 static async create(options={}){const {default:factory}=await import('../../build/wasm/cpore_world.mjs');return new World(await factory(options));}
 constructor(module){if(module._cw_version()!==2)throw Error('world WASM ABI mismatch');this.module=module;this.combat=new Combat(module);}
 reset(setup){
  const s=structuredClone(setup),m=this.module,f=Math.fround;
  s.seed??=42;s.terrainSeed??=7;s.terrain??=0;s.nest??={x:0,z:0};s.flatHeight??=2;s.water??={x:0,z:0,r:0};s.obstacles??=[];
  s.profile={...defaultProfile(),...s.profile};s.wild??=[{x:0,z:18,home:{x:0,z:18},species:3,bot:-1,profile:{mouth:3,charge:0,spit:0,tail:1,guard:0,hp:80,stamina:100,speed:5.8,radiusCm:0}}];
  if(!Number.isInteger(s.seed)||s.seed<0||s.seed>0xffffffff||!Number.isInteger(s.terrainSeed)||s.terrainSeed<0||s.terrainSeed>0xffffffff||![0,1].includes(s.terrain)||s.wild.length>24||s.obstacles.length>1024)throw RangeError('world setup');
  const finite=v=>{if(!Number.isFinite(v)||!Number.isFinite(Math.fround(v)))throw RangeError('world number');return v};
  [s.nest.x,s.nest.z,s.flatHeight,s.water.x,s.water.z,s.water.r].forEach(finite);
  const profiles=[s.profile,...s.wild.map(c=>({...defaultProfile(),...c.profile}))];
  profiles.forEach(p=>{for(const key of ['mouth','charge','spit','tail','guard'])if(!Number.isInteger(p[key])||p[key]<0||p[key]>5)throw RangeError(key);['hp','stamina','speed'].forEach(k=>finite(p[k]));if(!Number.isInteger(p.radiusCm)||p.radiusCm<0||p.radiusCm>65535)throw RangeError('radius');});
  s.wild.forEach(c=>{[c.x,c.z,c.home?.x??c.x,c.home?.z??c.z].forEach(finite);if(!Number.isInteger(c.species??3)||!Number.isInteger(c.bot??-1))throw RangeError('species/bot');});s.obstacles.forEach(o=>[o.x,o.z,o.r].forEach(finite));
  m._cw_config(s.seed,s.terrainSeed,s.terrain,f(s.nest.x),f(s.nest.z),f(s.flatHeight),f(s.water.x),f(s.water.z),f(s.water.r),s.wild.length);
  profiles.forEach((p,i)=>{if(m._cw_profile(i,p.mouth,p.charge,p.spit,p.tail,p.guard,p.hp,p.stamina,p.speed,p.radiusCm))throw RangeError('profile');});
  s.wild.forEach((c,i)=>m._cw_spawn(i+1,c.x,c.z,c.home?.x??c.x,c.home?.z??c.z,c.species??3,c.bot??-1));
  s.obstacles.forEach((o,i)=>m._cw_obstacle(i,o.x,o.z,o.r,o.type??0));
  if(m._cw_reset())throw RangeError('invalid world setup');this.setup=s;return this;
 }
 height(x,z){return this.module._cw_height(x,z)}
 ground(x,z){return this.module._cw_ground(x,z)}
 hash(){const p=this.module._cw_hash()>>>2,a=this.module.HEAPU32;return a[p+1].toString(16).padStart(8,'0')+a[p].toString(16).padStart(8,'0')}
 step(a={}){const m=this.module;const row=[a.verb??0,a.target??0,a.move??0,a.dir??0,a.sprint?1:0,a.hx??0,a.hz??0,a.x??0,a.z??0];if(!row.every(Number.isFinite)||!row.slice(0,7).every(v=>Number.isInteger(v)&&v>=-2147483648&&v<=2147483647)||row[5]<-32768||row[5]>32767||row[6]<-32768||row[6]>32767||!row.slice(7).every(v=>Number.isFinite(Math.fround(v))))throw RangeError('world input');const error=m._cw_step(...row);return {error,hash:this.hash()}}
 snapshot(){const m=this.module,meta=Array.from(new Float32Array(m.HEAPU8.buffer,m._cw_meta(),17)),n=meta[16];
 const rows=new Float32Array(m.HEAPU8.buffer,m._cw_entities(),(n+1)*18);
 const entities=Array.from({length:n+1},(_,i)=>{const r=rows.subarray(i*18,(i+1)*18);return {id:i,x:r[0],z:r[1],fx:r[2],fz:r[3],yaw:Math.atan2(r[2],r[3]),hp:r[4],stamina:r[5],speed:r[6],acceleration:r[7],turnRate:r[8],dead:!!r[9],returning:!!r[10],species:r[11],home:{x:r[12],z:r[13]}}});
 return {tick:meta[0],clock:meta[1],active:meta[2],started:meta[3],outcome:[null,'victory','death','fled'][meta[4]],respawn:meta[5]/10,cooldown:meta[6]/10,point:{x:meta[7],z:meta[8]},order:{verb:meta[9],target:meta[10],move:meta[11],x:meta[12],z:meta[13]},accepted:meta.slice(14,16),entities};
 }
 orders(){const m=this.module,a=new Int32Array(m.HEAPU8.buffer,m._cw_orders(),16);return [0,1].map(i=>Object.fromEntries(['tick','id','verb','move','target','dir','hx','hy'].map((k,j)=>[k,a[i*8+j]])))}
 observe(){const pointer=this.module._cw_observe();if(!pointer)throw RangeError('world observation capacity');return JSON.parse(this.module.UTF8ToString(pointer))}
 exportSetup(){const s=this.setup,f=Math.fround,p=p=>[p.mouth,p.charge,p.spit,p.tail,p.guard,f(p.hp),f(p.stamina),f(p.speed),p.radiusCm??0].join(' ');
 const lines=['CPORE_WORLD_LOG 2',[s.seed,s.terrainSeed,s.terrain,f(s.nest.x),f(s.nest.z),f(s.flatHeight),f(s.water.x),f(s.water.z),f(s.water.r),s.wild.length,s.obstacles.length].join(' '),p(s.profile)];
 s.wild.forEach(c=>lines.push([f(c.x),f(c.z),f(c.home?.x??c.x),f(c.home?.z??c.z),c.species??3,c.bot??-1,p({...defaultProfile(),...c.profile})].join(' ')));
 s.obstacles.forEach(o=>lines.push([f(o.x),f(o.z),f(o.r),o.type??0].join(' ')));return lines.join('\n')+'\n';}
}
