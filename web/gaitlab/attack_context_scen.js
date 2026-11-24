'use strict';
// Context-attack lab, scenarios: 4 attacks x 4 contexts x 1-2 options. Numbers are STARTING values for the C port (see docs/evidence/loco/attack_context.md).
(function(root){
const C=root.ACCORE0,S=root.ACSIM,{interp,rot,SPEED,PI,DT,R}=C,L=C.layers;
const ATTACKS=['bite','pounce','spit','roar'],CONTEXTS=['standing','walking','galloping','far'];
const ANAME={bite:'Bite',pounce:'Pounce / charge',spit:'Acid spit',roar:'Roar'},CNAME={standing:'Standing',walking:'Walking',galloping:'Galloping',far:'From far'};
const VW=SPEED.walk,VG=SPEED.gallop,VC=SPEED.charge,TW=SPEED.tWalk,TF=SPEED.flee;
const k0=v=>[[0,v]];
function bars(spec,phl,winEnd){ // timing bar: gait lead-in, attack phases (ms relative to the anchor), contact pause, back in the gait
  const a=spec.anchor*1000,out=[],push=(n,ms)=>{if(ms>1)out.push([n,Math.round(ms)]);};
  const first=phl[0][1];push('gait',a+first);let cur=first;
  for(const [n,s,e] of phl){push(n,e-s);cur=e;if(e===0&&spec.hit&&spec.hit.pause)out.push(['contact',spec.hit.pause]);}
  push('back to gait',spec.dur*1000-(a+cur));spec.bars=out;spec.phl=phl;}
function mk(a){return Object.assign({x0:0,z0:0,Byaw:[[0,0]],layer:null,contact:null,locks:[]},a);}
function farProfile(start){ // run-up of the charge: standing burst start or walking start, building to the charge speed
  return start==='walking'
   ?{Bv:[[0,VW],[.6,VW],[1.1,2.8],[1.6,3.5],[2.3,VC],[9,VC]],burst:[.55,1.3],lead:.6}
   :{Bv:[[0,0],[.6,0],[1.1,2.2],[1.7,3.4],[2.5,VC],[9,VC]],burst:[.6,1.4],lead:.6};}
function cut(Bv,tEnd,...tail){return Bv.filter(k=>k[0]<tEnd).concat(tail);}
// ---------------------------------------------------------------- bite
function biteBase(id,ctx,v,slug,name,tag){return mk({id,attack:'bite',ctx,variant:v,slug,name,tag,contact:'beak'});}
function biteHit(extra){return Object.assign({kind:'knock',pause:70,slide:.06,dirLocal:[-.62,.78,0],impulseLocal:[2.5,0],mu:7,hop:.05,tilt:.5,amp:.26,stun:.5,resumeK:.8},extra);}
function biteScenarios(far){
  const out=[];
  { // standing: lab version 3 lunge + peck, A71 fast timing
    const tc=1.3,s=biteBase('bite.standing.A','standing','A','lunge-peck','Lunge + peck (version 3)','the owner-approved bite, fast: lands 0.3 s after the press; feet planted, whole body lunges');
    s.dur=2.8;s.anchor=tc;s.Bv=k0(0);s.tgt={anchor:{t:tc,rel:[1.5,0]},v:k0(0),yaw:k0(0),look:2.7};s.layer=L.biteLayer({L:.4,d:1,k:1});s.layer.noForce=true;s.hit=biteHit({t:tc});
    bars(s,[['wind-up',-300,-100],['strike',-100,0],['hold on',0,60],['pull out',60,190],['recovery',190,700]]);out.push(s);}
  { // walking A: bite on the move
    const tc=2.4,s=biteBase('bite.walking.A','walking','A','on-the-move','Bite on the move','sprawl walk keeps its legs; head and neck lunge as a layer with a small lean; no stop');
    s.dur=4.2;s.anchor=tc;s.Bv=[[0,VW],[tc-.3,VW],[tc,1.6],[tc+.5,VW]];s.tgt={anchor:{t:tc,rel:[1.2,0]},v:k0(TW),yaw:k0(0)};s.layer=L.biteLayer({L:.12,d:.3,k:.8});
    s.hit=biteHit({t:tc,impulseLocal:[2.6,0],resumeSpeed:2.8});bars(s,[['wind-up',-300,-100],['strike',-100,0],['hold on',0,60],['pull out',60,190],['recovery',190,800]]);out.push(s);
    const t2=2.4,u=biteBase('bite.walking.B','walking','B','slow-step','Slow-step lunge','eases the pace to a crawl, deeper lunge, then picks the walk back up');
    u.dur=4.4;u.anchor=t2;u.Bv=[[0,VW],[t2-.8,VW],[t2-.15,.55],[t2+.4,.5],[t2+1.3,VW]];u.tgt={anchor:{t:t2,rel:[1.5,0]},v:[[0,TW],[t2-1.1,TW],[t2-.5,.25],[t2+.3,.25],[t2+1,TW]],yaw:k0(0)};
    u.layer=L.biteLayer({L:.2,d:.3,k:.9});u.hit=biteHit({t:t2,impulseLocal:[3.4,0],resumeSpeed:2.8,resumeAt:.2});bars(u,[['wind-up',-300,-100],['strike',-100,0],['hold on',0,60],['pull out',60,190],['recovery',190,900]]);out.push(u);}
  { // galloping A: snap in passing; B: bite and drag
    const tc=2.5,s=biteBase('bite.galloping.A','galloping','A','snap-in-passing','Snap at the neck in passing','keeps the gallop, head whips sideways at the neck, B overshoots and turns wide; knockback from the closing speed');
    s.dur=5;s.anchor=tc;s.Bv=[[0,VG],[tc,VG],[tc+.7,2.9],[tc+2.5,2.6]];s.Byaw=[[0,0],[tc+.1,0],[tc+1.5,.5]];
    s.tgt={anchor:{t:tc,rel:[1.25,.3]},v:k0(TF),yaw:k0(0)};s.layer=L.biteLayer({L:.06,d:.3,k:.5,hold:20,rel:90});
    s.hit=biteHit({t:tc,dirLocal:[-.4,.6,-.65],impulseLocal:[1.6,3.8],stun:.6,resumeSpeed:2.8});
    bars(s,[['wind-up',-300,-100],['strike',-100,0],['hold on',0,20],['pull out',20,110],['overshoot + turn',110,1500]]);out.push(s);
    const t2=2.5,u=biteBase('bite.galloping.B','galloping','B','bite-drag','Bite and drag to a stop','locks on, brakes hard (skid) dragging the target along, then lets go');
    u.dur=5;u.anchor=t2;u.Bv=[[0,VG],[t2,VG],[t2+.3,2.9],[t2+.9,1.5],[t2+1.3,.2],[t2+1.6,0]];u.tgt={anchor:{t:t2,rel:[1.3,0]},v:k0(TF),yaw:k0(0)};
    u.layer=L.biteLayer({L:.06,d:.3,k:.5,hold:1000,rel:160});u.skid=[t2+.15,t2+1.8];
    u.hit=biteHit({t:t2,dirLocal:[-.75,.45,0],kind:'drag',drag:{t1:t2+1.0,rel0:[1.3,0],rel:[1.12,0]},impulseLocal:[0,0],mu:5});
    bars(u,[['wind-up',-300,-100],['strike',-100,0],['drag + brake',0,1000],['let go',1000,1160],['recovery',1160,1900]]);out.push(u);}
  { // from far: A charge (dash-tackle), B run-up + snap in passing
    const p=farProfile(far),tc=far==='walking'?3.4:3.8;
    const s=biteBase('bite.far.A','far','A','charge','Charge (embestida)','run-up building speed (burst start), head lowered, dash-tackle impact; recoil on both, target knocked over');
    s.contact='chest';s.dur=tc+2.3;s.anchor=tc;s.Bv=cut(p.Bv,tc,[tc,VC],[tc+.13,1.5],[tc+.5,.4],[tc+1.2,1.6],[tc+2.0,VW]);s.burst=p.burst;
    s.tgt={anchor:{t:tc,rel:[.78,0]},v:k0(0),yaw:k0(0),look:2.7};s.layer=L.tackleLayer({});s.layer.noForce=true;
    s.hit={t:tc,kind:'tackle',pause:90,impulseLocal:[3.8,.6],mu:5,hop:.16,amp:.3,rollMax:1.5,yawN:.7,rise:1.15,stun:1.2,resumeAt:1.4,resumeK:0};
    s.calib=true;bars(s,[['crouch',-700,-380],['run in',-380,-60],['slam',-60,150],['recoil',150,600],['recovery',600,1100]]);out.push(s);
    const u=biteBase('bite.far.B','far','B','run-up-snap','Run-up, snap in passing','same run-up, but a bite on the run at the end instead of the tackle; B overshoots and turns wide');
    u.dur=tc+3;u.anchor=tc;u.Bv=cut(p.Bv,tc,[tc,VC],[tc+.8,3.4],[tc+2.6,3.0]);u.Byaw=[[0,0],[tc+.1,0],[tc+1.6,.55]];u.burst=p.burst;
    u.tgt={anchor:{t:tc,rel:[1.25,.3]},v:k0(0),yaw:k0(0),look:2.7};u.layer=L.biteLayer({L:.1,d:.3,k:.5,hold:20,rel:90});
    u.hit=biteHit({t:tc,dirLocal:[-.4,.6,-.65],impulseLocal:[2.4,3.6],stun:.7,resumeSpeed:1.5});
    bars(u,[['wind-up',-300,-100],['strike',-100,0],['hold on',0,20],['pull out',20,110],['overshoot + turn',110,1500]]);out.push(u);}
  return out;
}
// ---------------------------------------------------------------- pounce / charge
const AIR_F=[[0,[-.04,-.32,0]],[205,[.12,-.26,0]],[425,[.2,-.3,0]],[515,[.18,-.52,0]]],AIR_H=[[0,[-.1,-.34,0]],[240,[-.26,-.28,0]],[500,[-.28,-.26,0]],[610,[-.12,-.5,0]]];
function pounceScenario(id,ctx,v,slug,name,tag,o){ // o: tc, quick, stride, Bv, tgt v, anchor rel at take-off, dur
  const s=mk({id,attack:'pounce',ctx,variant:v,slug,name,tag,contact:'beak'}),tc=o.tc,tTO=tc-.5;
  s.dur=o.dur;s.anchor=tc;s.Bv=o.Bv.filter(k=>k[0]<tTO).concat([[tTO,o.Bv.filter(k=>k[0]<=tTO).slice(-1)[0][1]],[tc+.02,0],[tc+.03,0]]);s.burst=o.burst;s.tgt={anchor:{t:tTO,rel:[o.gap,0]},v:o.tv,yaw:k0(0),look:2.7};
  s.flight={t0:tTO,t1:tc,y0:o.y0||0,y1:-.14,rel:[.95,0]};
  s.layer=L.pounceLayer({quick:o.quick,stride:o.stride});s.layer.noForce=true;
  s.air=[{legs:[2,3],t0:tc-.515,t1:tc,B:AIR_F,in:35,out:60,land:[null,null,[.56,-.27],[.56,.27]],dust:3},{legs:[0,1],t0:tc-.5,t1:tc+.11,B:AIR_H,in:30,out:60,land:[[-.13,-.19],[-.13,.19]],dust:3}];
  s.hit={t:tc,kind:'pin',pause:80,dirLocal:[-.55,.83,0],rel:.49,mu:40,amp:.2,stun:.4};
  const phl=o.stride?[['coil',-520,-500],['leap',-500,0],['pin',0,480],['recovery',480,1100]]:o.quick?[['crouch',-640,-560],['coil',-560,-500],['leap',-500,0],['pin',0,480],['recovery',480,1100]]:[['crouch',-1000,-850],['freeze + wiggle',-850,-570],['coil',-570,-500],['leap',-500,0],['pin',0,480],['step off',480,800],['recovery',800,1300]];
  bars(s,phl);return s;}
function tackleScenario(id,ctx,v,slug,name,tag,o){
  const s=mk({id,attack:'pounce',ctx,variant:v,slug,name,tag,contact:'chest'}),tc=o.tc;
  s.dur=o.dur;s.anchor=tc;s.Bv=o.Bv;s.burst=o.burst;s.tgt={anchor:{t:tc,rel:[.78,0]},v:o.tv,yaw:k0(0),look:2.7};s.layer=L.tackleLayer({});s.layer.noForce=true;
  s.hit={t:tc,kind:'tackle',pause:90,impulseLocal:[o.v0,.6],mu:5,hop:.16,amp:.3,rollMax:1.5,yawN:.7,rise:1.15,stun:1.2,resumeAt:1.4,resumeK:0};s.calib=true;
  bars(s,[['crouch',-700,-380],['burst',-380,-60],['slam',-60,150],['recoil',150,600],['recovery',600,1100]]);return s;}
function pounceScenarios(far){
  const out=[],p=farProfile(far);
  out.push(pounceScenario('pounce.standing.A','standing','A','cat','Cat pounce','crouch, freeze + butt wiggle, coil, arcing leap, beak and front feet land on the prey, pin it',{tc:2.4,dur:4.5,Bv:k0(0),tv:k0(0),gap:3.5}));
  out.push(pounceScenario('pounce.standing.B','standing','B','quick-spring','Quick spring','no stalk: a short crouch and straight into the leap',{tc:1.7,dur:3.6,Bv:k0(0),tv:k0(0),gap:3.5,quick:true}));
  out.push(pounceScenario('pounce.walking.A','walking','A','gather-leap','Gather, then leap','brakes to a stop (a commitment), short crouch, leap onto the walking target',{tc:3.1,dur:5,Bv:[[0,VW],[1.1,VW],[1.9,0]],tv:k0(TW),gap:3.5,quick:true}));
  out.push(pounceScenario('pounce.walking.B','walking','B','leap-off-the-stride','Leap off the stride','no braking: the last stance foot becomes the take-off; flight starts at walking speed',{tc:2.7,dur:4.6,Bv:k0(VW),tv:k0(TW),gap:3.5,stride:true}));
  out.push(pounceScenario('pounce.galloping.A','galloping','A','leap-from-gallop','Leap from the gallop','long low leap at running speed onto the fleeing target; lands, pins and stops dead',{tc:2.9,dur:5,Bv:[[0,VG],[2.3,VG]],tv:k0(TF),gap:3.8,stride:true}));
  out.push(tackleScenario('pounce.galloping.B','galloping','B','dash-tackle','Dash-tackle (galloping peck look)','no leap: lowers the head, a short burst, shoulder and chest slam; target knocked over',{tc:3.0,dur:5.2,Bv:[[0,VG],[2.2,VG],[2.9,3.9],[3.0,4.0],[3.13,1.5],[3.5,.4],[4.2,1.6],[5,VW]],tv:k0(TF),v0:3.6}));
  { const tc=far==='walking'?3.1:3.7,tTO=tc-.5;
    out.push(pounceScenario('pounce.far.A','far','A','run-in-leap','Run in, leap at 4 m','burst start, gallop, then leaps from the gallop when the band says pounce',{tc,dur:tc+2,Bv:cut(p.Bv,tTO+.5,[tc,0]),burst:p.burst,tv:k0(0),gap:3.7,stride:true}));
    const tc2=5.0;
    out.push(pounceScenario('pounce.far.B','far','B','run-in-brake-pounce','Run in, brake, cat pounce','gallops in, plants with a skid, then the quick pounce from a standstill (commitment)',{tc:tc2,dur:tc2+2,Bv:[[0,far==='walking'?VW:0],[.6,far==='walking'?VW:0],[1.1,far==='walking'?2.8:2.2],[1.7,3.4],[2.3,3.8],[3.0,3.8],[3.9,0],[9,0]],burst:p.burst,tv:k0(0),gap:3.4,quick:true})); }
  return out;
}
// ---------------------------------------------------------------- spit
function spitScenario(id,ctx,v,slug,name,tag,o){
  const s=mk({id,attack:'spit',ctx,variant:v,slug,name,tag}),ts=o.ts,W=o.wind;
  s.dur=o.dur;s.anchor=ts;s.Bv=o.Bv;s.Byaw=o.Byaw||[[0,0]];s.burst=o.burst;s.tgt={anchor:{t:ts,rel:o.rel},v:o.tv,yaw:o.tyaw||k0(0),look:2.7};
  s.layer=L.spitLayer({type:o.type,wind:W,s:o.s});s.spit={ts,speed:26,tof:o.tof||null,dur:o.type==='jet'?.2:.001,sideHd:o.side?.16:0,big:!!s.layer.big,r:o.type==='jet'?.03:(o.type==='glob'?.17:.09)};
  s.hit={kind:'acid',pause:o.type==='jet'?0:o.type==='glob'?90:60,mu:6,amp:o.type==='glob'?.2:.12,slowS:2};
  const ph=o.type==='jet'?[['rise',-W,-300],['pulses',-300,-30],['fire',-30,200],['recovery',200,850]]:o.type==='lob'?[['tilt back',-W,-220],['swell',-220,-40],['lob',-40,40],['recovery',40,860]]:[['brace',-W,-300],['charge',-300,-20],['release',-20,60],['recovery',60,1000]];
  bars(s,ph);return s;}
function spitScenarios(far){
  const out=[],walkStart=far==='walking',bvF=walkStart?k0(VW):k0(0);
  out.push(spitScenario('spit.standing.A','standing','A','jet','Aimed jet (cobra)','neck rises, throat pulses twice, thin fast stream; leads nothing (target idle)',{ts:1.8,wind:600,dur:3.8,Bv:k0(0),rel:[5,0],tv:k0(0),type:'jet',s:1}));
  out.push(spitScenario('spit.standing.B','standing','B','glob','Charged glob','longer wind-up, big slow glob that hits hard',{ts:2.2,wind:1000,dur:4.2,Bv:k0(0),rel:[5,0],tv:k0(0),type:'glob',s:1,tof:.85}));
  out.push(spitScenario('spit.walking.A','walking','A','jet','Jet on the move','sprawl walk continues; neck and head layer, aim leads the walking target',{ts:2.2,wind:600,dur:4.4,Bv:k0(VW),rel:[4.6,.2],tv:k0(TW),type:'jet',s:.4}));
  out.push(spitScenario('spit.walking.B','walking','B','glob','Charged glob on the move','keeps walking through the long charge; the glob is thrown ahead of the walking target',{ts:2.4,wind:1000,dur:4.6,Bv:k0(VW),rel:[4.6,.2],tv:k0(TW),type:'glob',s:.4,tof:.85}));
  out.push(spitScenario('spit.galloping.A','galloping','A','sideways-parting-shot','Sideways shot at the crossing target','keeps galloping, head swings to the side and leads the fleeing target (parting shot)',{ts:2.2,wind:600,dur:4.4,Bv:k0(VG),rel:[5,1.8],tv:k0(TF),tyaw:k0(-.35),type:'jet',s:.3,side:true}));
  out.push(spitScenario('spit.galloping.B','galloping','B','forward-lob','Forward lob over the stride','head level, lobs a glob ahead of the fleeing target while running straight',{ts:2.3,wind:640,dur:4.6,Bv:k0(VG),rel:[5.5,.3],tv:k0(TF),type:'lob',s:.3,tof:.9}));
  out.push(spitScenario('spit.far.A','far','A','llama-lob','Llama lob','head tilts back, cheeks swell, one high lob (game range 6 m: here 9.5 m)',{ts:1.8,wind:640,dur:4.4,Bv:bvF,rel:[9.5,.3],tv:k0(0),type:'lob',s:walkStart?.3:1,tof:1.15}));
  out.push(spitScenario('spit.far.B','far','B','charged-lob','Charged long lob','long charge then a big glob thrown high',{ts:2.4,wind:1000,dur:5,Bv:bvF,rel:[9.5,.3],tv:k0(0),type:'glob',s:walkStart?.3:1,tof:1.3}));
  return out;
}
// ---------------------------------------------------------------- roar
function roarScenario(id,ctx,v,slug,name,tag,o){
  const s=mk({id,attack:'roar',ctx,variant:v,slug,name,tag}),te=o.te;
  s.dur=o.dur;s.anchor=te;s.Bv=o.Bv;s.burst=o.burst;s.tgt={anchor:{t:te,rel:o.rel},v:o.tv,yaw:o.tyaw||k0(0),look:o.look===undefined?1.2:o.look};
  s.layer=o.kind==='rear'?L.rearLayer():L.bellowLayer({s:o.s});s.layer.noForce=true;
  if(o.kind==='rear'){s.air=[{legs:[2,3],t0:te-.3,t1:te+.84,B:[[0,[0,0,0]],[300,[.1,-.3,0]],[760,[.12,-.32,0]],[1080,[.04,-.2,0]]],in:120,out:140,land:[null,null,[.2909+.1-.0,-.165],[.3909-.1,.165]],dust:5}];
    s.air[0].land=[null,null,[.2909,-.165],[.2909,.165]];}
  s.roar={te,radius:4,dur:o.kind==='rear'?.46:.82,rings:o.kind==='rear'?[{dt:0,amp:1,dur:.46},{dt:.08,amp:.45,dur:.52}]:[{dt:0,amp:1,dur:.82},{dt:.33,amp:.7,dur:.88},{dt:.66,amp:.5,dur:.92}]};
  s.hit={kind:'fear',pause:0,flee:o.flee||3.2,mu:6,amp:.2};
  bars(s,o.kind==='rear'?[['crouch',-620,-400],['rear up',-400,0],['roar',0,600],['drop',600,880],['recover',880,1300]]:[['brace',-520,-220],['breath in',-220,0],['rumble',0,1220],['ease',1220,1480],['recover',1480,1900]]);return s;}
function roarScenarios(far){
  const out=[],p=farProfile(far);
  out.push(roarScenario('roar.standing.A','standing','A','rear-up','Rear-up roar','rears onto the hind legs, chest out, head thrown up, holds 0.6 s, drops',{te:1.5,dur:3.6,Bv:k0(0),rel:[3,.5],tv:k0(0),kind:'rear'}));
  out.push(roarScenario('roar.standing.B','standing','B','bellow','Low bellow (intimidate)','crouched and braced, head low, a long rumble with the throat pulsing',{te:1.2,dur:3.8,Bv:k0(0),rel:[3,.5],tv:k0(0),kind:'bellow',s:1}));
  out.push(roarScenario('roar.walking.A','walking','A','bellow-on-the-move','Bellow while walking','legs keep the sprawl walk, chest and throat swell, head forward; the target flinches and runs',{te:2.1,dur:4.6,Bv:k0(VW),rel:[2.6,.4],tv:k0(TW),kind:'bellow',s:.3}));
  out.push(roarScenario('roar.walking.B','walking','B','halt-rear-up','Halt and rear up','slows to a stop (commitment) and rears; the roar blast hits the walking target',{te:2.9,dur:5,Bv:[[0,VW],[1.1,VW],[1.8,0]],rel:[3.2,.4],tv:k0(TW),kind:'rear'}));
  out.push(roarScenario('roar.galloping.A','galloping','A','bellow-on-the-run','Bellow on the run','keeps the gallop with a low bellow; the fleeing target gets a fear boost',{te:2.3,dur:4.6,Bv:k0(VG),rel:[2.4,.4],tv:k0(TF),kind:'bellow',s:.25,flee:3.8}));
  out.push(roarScenario('roar.galloping.B','galloping','B','brake-and-rear','Brake and rear up','skids to a stop from the gallop, rears up and roars at the fleeing target',{te:2.3,dur:4.6,Bv:[[0,VG],[.6,VG],[1.5,0]],rel:[2.6,.4],tv:[[0,1.0],[.9,1.0],[1.3,TF]],kind:'rear',flee:3.8}));
  { const te=far==='walking'?4.6:4.9;
    out.push(roarScenario('roar.far.A','far','A','run-in-plant-rear','Run in, plant, rear up','runs in at the charge speed, skids to a stop at the roar range, then rears',{te,dur:te+2.4,Bv:[[0,far==='walking'?VW:0],[.6,far==='walking'?VW:0],[1.1,far==='walking'?2.8:2.2],[1.7,3.4],[2.3,3.8],[3.0,3.8],[3.9,0],[9,0]],burst:p.burst,rel:[3.2,.4],tv:k0(0),kind:'rear'}));
    const te2=far==='walking'?3.1:3.5;
    out.push(roarScenario('roar.far.B','far','B','bellow-in-stride','Bellow in stride, then ease off','roars as it closes to 3.5 m without stopping, then slows to a halt',{te:te2,dur:te2+3,Bv:cut(farProfile(far).Bv,te2,[te2,3.8],[te2+.9,0],[9,0]),burst:p.burst,rel:[3.5,.4],tv:k0(0),kind:'bellow',s:.25})); }
  return out;
}
// ================================================================ build (chest contacts are calibrated so the shoulder touches the hit sphere)
function buildOne(spec){
  let r=S.simulate(spec);
  if(spec.contact==='chest'){for(let it=0;it<5;it++){const e=spec.hit.err;if(e===undefined||Math.abs(e)<.01)break;spec.tgt.anchor.rel[0]-=e;r=S.simulate(spec);}}
  else if(spec.contact==='beak'&&!spec.noCalib){ // bring the target to a comfortable neck stretch (about 1.05) at the contact
    for(let it=0;it<6;it++){const st=spec.metrics.stretchAtContact;if(st===undefined||Math.abs(st-1.05)<.012)break;const mv=(st-1.05)*.385;
      if(spec.flight)spec.flight.rel[0]+=mv;else spec.tgt.anchor.rel[0]-=mv;r=S.simulate(spec);}}
  return r;
}
function buildAll(far){
  const all=[].concat(biteScenarios(far),pounceScenarios(far),spitScenarios(far),roarScenarios(far));
  all.forEach(buildOne);return all;
}
// ================================================================ self-check
function check(all){
  const fails=[],rows=[];
  for(const s of all){
    const m=s.metrics,r={id:s.id,legErr:m.legErr,neckErr:m.neckErr,minY:m.minY,stanceErrCm:m.stanceErr*100,contactErr:m.contactErr,stretch:m.maxStretch,minRelToTarget:m.minRel};
    if(m.legErr>.02)fails.push(`${s.id}: IK out of reach by ${(m.legErr*100).toFixed(1)} cm`);
    if(m.neckErr>.02)fails.push(`${s.id}: neck out of reach by ${(m.neckErr*100).toFixed(1)} cm`);
    if(m.minClear<.3)fails.push(`${s.id}: target comes ${m.minClear.toFixed(2)} m from the creature's body line (t ${m.tClear.toFixed(1)} s), inside it`);
    if(m.minY<-.012)fails.push(`${s.id}: geometry ${(m.minY*100).toFixed(1)} cm below ground`);
    if(m.stanceErr>.02)fails.push(`${s.id}: stance foot off its plant by ${(m.stanceErr*100).toFixed(1)} cm`);
    if(s.contact){const lim=s.contact==='chest'?.04:.03;if(m.contactErr===null||Math.abs(m.contactErr)>lim)fails.push(`${s.id}: contact ${m.contactErr===null?'missing':m.contactErr.toFixed(3)} m from the hitbox`);
      if(s.contact==='beak'&&m.stretchAtContact>1.081)fails.push(`${s.id}: neck stretch ${m.stretchAtContact.toFixed(2)} at contact above the 1.08 cap`);}
    if(s.hit&&s.hit.pause&&(s.hit.pause<60||s.hit.pause>90))fails.push(`${s.id}: hit-pause ${s.hit.pause} ms outside 60-90`);
    if(s.attack!=='roar'&&s.hit&&(s.hit.t===undefined))fails.push(`${s.id}: no hit time`);
    if(s.hit&&s.hit.t!==undefined&&(s.hit.t>s.dur-.8))fails.push(`${s.id}: hit too close to the end`);
    // target geometry: never inside the creature, never through the ground
    let preyMin=9;for(const f of s.frames){if(f.S)preyMin=Math.min(preyMin,f.S.y-(.32*Math.cos(f.S.roll)+.2*Math.abs(Math.sin(f.S.roll)))*f.S.sy);}r.preyMinY=preyMin;
    if(preyMin<-.015)fails.push(`${s.id}: target through the ground ${preyMin.toFixed(3)}`);
    if(s.attack==='spit'){
      const pj=s.proj,g=[],dist=[];let hits=0,gErr=0,under=9;
      for(const p of pj){for(let k=1;k<=6;k++){const h=.02,t=p.te+.1*k;if(t+h>p.end)break;const q=u=>p.p0[1]+p.v[1]*(u-p.te)-.5*9.81*(u-p.te)**2,a=(q(t-h)-2*q(t)+q(t+h))/(h*h);gErr=Math.max(gErr,Math.abs(-a-9.81)/9.81);}
        for(let u=p.te;u<=p.end;u+=.01)under=Math.min(under,p.p0[1]+p.v[1]*(u-p.te)-.5*9.81*(u-p.te)**2);
        if(p.endk==='hit'){hits++;dist.push(p.hitDist);}}
      r.shots=pj.length;r.hits=hits;r.gravityErr=gErr;r.hitDistMax=dist.length?Math.max(...dist):null;r.shotMinY=under;
      r.tof=s.aimInfo?s.aimInfo.tof:null;
      if(hits<Math.ceil(pj.length*.9))fails.push(`${s.id}: only ${hits}/${pj.length} shots hit the moving target`);
      if(gErr>.02)fails.push(`${s.id}: projectile deviates from gravity by ${(gErr*100).toFixed(1)} %`);
      if(under<-.02)fails.push(`${s.id}: projectile through the ground`);
      if(dist.length&&Math.max(...dist)>.31)fails.push(`${s.id}: projectile hit distance ${Math.max(...dist).toFixed(3)} m`);
    }
    if(s.attack==='roar'){const rr=s.roar;r.ringHit=rr.hitIdx>=0;if(!r.ringHit)fails.push(`${s.id}: roar ring never reaches the target`);}
    const d0=Math.hypot(s.pathArr.tx[0]-s.pathArr.bx[0],s.pathArr.tz[0]-s.pathArr.bz[0]);r.startDistance=d0;
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.ACSCEN={ATTACKS,CONTEXTS,ANAME,CNAME,buildAll,check};
})(typeof window!=='undefined'?window:globalThis);
