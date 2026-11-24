'use strict';
// Primigenia signature-attack picker lab (A60), round 2: animation pass. 16 real-animal-inspired signature attacks, one looping cell each.
// Rigs and effects live in sig_rig.js (Quad, Serp, Pip the target creature, soft-sprite fx, keyframes); the per-attack scenes in sig_atk1.js / sig_atk2.js
// register builders in SIGB. This file holds the picker metadata (name, animal, role, effect, impact time ti, camera) and the per-loop scene wrapper.
// Every attack = { id,name,animal,organ,role,effect,env,D,cam:{cx,ty,h},ti,tw,hs, build(scene) -> {pose(s,fx), kick(s)} }, s = seconds in the loop, ti = impact time,
// tw = a wind-up frame for the evidence captures, hs = hit-stop in seconds (the whole picture freezes at ti for that long, the way a real game frame would).
(function(){
const BB=window.BB,T=BB.T,L=3.4,SIGB=window.SIGB=window.SIGB||{};
const M=(id,name,animal,organ,role,effect,env,D,cam,ti,tw,hs,Lc)=>({id,name,animal,organ,role,effect,env,D,cam,ti,tw,hs:hs===undefined?.075:hs,L:Lc||L});
const A=[
 M('flamethrower','Flamethrower','island vent-cooked fire gland (none on Earth)','fire gland, needs 16%+ O2 (A38, D-28)','poke / signature','Cone of fire in front; burns over time.','land',2.75,{cx:1.4,ty:.62,h:2.7},1.45,.85,0),
 M('boiling_spray','Boiling spray','bombardier beetle','rear gland + armour','control / signature','Short-range hot spray from the rear: burn and fear.','land',2.3,{cx:1.2,ty:.5,h:2.2},1.18,.8,.05),
 M('sonic_snap','Sonic snap','pistol shrimp','oversized claw; strongest underwater','control / signature','Cavitation shockwave: stun at range, in water.','water',2.5,{cx:1.3,ty:.5,h:2.4},1.22,.9,.06),
 M('blinding_spit','Blinding spit','spitting cobra','spit gland + fangs','control / signature','Twin venom jets at the eyes: target is blind, accuracy drops.','land',2.4,{cx:1.1,ty:.6,h:2.3},1.27,.85,.04),
 M('smash_punch','Smash punch','mantis shrimp','club arm (smasher, A58)','control / signature','Blur-fast hammer strike: the first hit shatters any armour, shell or guard; massive damage, stuns.','water',2.15,{cx:1.15,ty:.5,h:2.3},1.1,.75,.09),
 M('electric_discharge','Electric discharge','electric eel','electric organ','control / signature','Stun in contact, chains to a second target; stronger in water.','water',2.0,{cx:.95,ty:.5,h:3.0},1.1,.85,0),
 M('tongue_snatch','Tongue snatch','chameleon','long tongue','poke / utility','Pulls small prey or items to you from range.','land',1.55,{cx:.85,ty:.42,h:1.9},1.12,.75,.0),
 M('water_jet','Water jet','archerfish','spit gland, near water','poke / signature','Knocks a target off a branch from range.','land',2.0,{cx:1.2,ty:1.0,h:3.3},1.34,.9,.05),
 M('stink_cloud','Stink cloud','skunk','scent gland','control / signature','Area fear: enemies flee; also hides your scent trail.','land',2.45,{cx:1.45,ty:.55,h:2.7},1.5,.9,0),
 M('blood_squirt','Blood squirt','horned lizard','head crest + armour','defence / signature','Squirts blood from the eyes: scares predators off.','land',2.0,{cx:1.0,ty:.5,h:2.2},1.3,.9,0),
 M('quill_storm','Quill storm','porcupine','back spines','defence / signature','Thorns: attackers who strike in melee are hurt.','land',2.3,{cx:1.3,ty:.5,h:2.3},1.3,.9,.08),
 M('ground_pound','Ground-pound shockwave','elephant-scale stomp, exaggerated','heavy legs','control / signature','Rear up and slam: knockdown ring around you.','land',2.7,{cx:1.5,ty:.95,h:3.8},1.42,.95,.09),
 M('death_roll','Death roll','crocodile','jaws + heavy tail','control / signature','Grab and spin: big damage over time while holding.','water',2.45,{cx:1.15,ty:.45,h:2.9},1.2,.85,.07,7.2),
 M('ink_cloud','Ink cloud','octopus and squid','ink sac (water)','defence / escape / signature','Blinds the pursuer and lets you jet away.','water',2.6,{cx:1.1,ty:.55,h:3.0},1.35,.95,0),
 M('hind_kick','Hind kick','donkey','strong legs','control / defence','Knockback to whatever is behind you.','land',2.25,{cx:1.5,ty:.58,h:2.6},1.12,.85,.085),
 M('tail_club','Tail club','ankylosaur-style armour (ankylosaur, glyptodont)','tail + bone club','control / signature','Sweeping knockdown with a stun; breaks the target\'s guard.','land',2.4,{cx:1.5,ty:.5,h:2.6},1.18,.85,.085)];
A.forEach(d=>{d.build=sc=>(SIGB[d.id]||SIGB._stub)(sc,d);});
// hit-stop: the clock holds at ti for hs seconds, then everything after shifts by hs (the loop end is inside the shifted tail, so the cycle still closes)
const warp=(s,d)=>{if(!d.hs||s<d.ti)return s;return s<d.ti+d.hs?d.ti:s-d.hs;};
function build(def,idx){
  const water=def.env==='water',sc=new T.Scene(),bg=water?'#143c4a':'#1c2227';sc.background=new T.Color(bg);sc.fog=new T.Fog(bg,12,32);
  sc.add(new T.AmbientLight('#ffffff',.78));const dl=new T.DirectionalLight('#fff4e0',.9);dl.position.set(-2.5,5,4);sc.add(dl);const rim=new T.DirectionalLight('#9cc4d8',.3);rim.position.set(3,2,-4);sc.add(rim);
  const g=new T.Mesh(new T.PlaneGeometry(60,60),new T.MeshLambertMaterial({map:BB.TEX.ground,color:water?'#6fa8b8':'#ffffff'}));g.rotation.x=-Math.PI/2;g.position.set(2,0,0);sc.add(g);
  if(water){const w=new T.Mesh(new T.PlaneGeometry(60,60),new T.MeshBasicMaterial({color:'#4fb0d8',transparent:true,opacity:.1,depthWrite:false}));w.rotation.x=-Math.PI/2;w.position.set(2,.006,0);sc.add(w);}
  else sc.add(new T.Mesh(BB.BLADES,new T.MeshLambertMaterial({color:'#6f9650'})));
  const fx=BB.sig.mkFx(sc),inst=def.build(sc),raw=inst.pose;inst.kick=0;
  inst.pose=(s,f)=>{const w=warp(s,def),k=raw(w,f);inst.kick=+k||0;};
  return {def,sc,fx,inst,cam:new T.PerspectiveCamera(30,1.8,.05,90)};
}
window.SIG={A,L,build,rp:BB.sig.rp,s2:BB.sig.s2,warp};
})();
