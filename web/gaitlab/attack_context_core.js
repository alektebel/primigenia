'use strict';
// Primigenia context-adaptive attacks lab core (A72): starter B (no arms, beak "pico"). Needs bite2_core.js first (body rig, REST, keys).
// Units: metres, +x forward, +y up, +z the creature's right. Times in seconds of ANIMATION time, key lists of attack layers in ms relative to
// the attack anchor (contact, fire or emit). A hit-pause freezes the animation (frames are duplicated) while fx keep running in real time.
// Pipeline per scenario: 1 paths (B, target) 2 gait (real A42 patterns: sprawl walk, rotary gallop, event-driven feet) 3 attack layer on top
// 4 reactions, projectiles, fx 5 frame table at 120 Hz. Everything the renderer and the self-check read is in the frame table.
(function(root){
const B=root.BITECORE,T=B.T,REST=B.REST,interp=B.interp,V=B.V,frames=B.frames,DEF=B.DEF;
const X=new T.Vector3(1,0,0),Y=new T.Vector3(0,1,0),Z=new T.Vector3(0,0,1);
const clamp=(x,a,b)=>x<a?a:x>b?b:x,sm=u=>{u=clamp(u,0,1);return u*u*(3-2*u);},fr=x=>x-Math.floor(x);
const G=9.81,DT=1/120,H=.618,FY=.03,R=.27,CY=.34,PI=Math.PI;
const P0=V(...REST.P0),NECK=[Math.hypot(.14,.16),Math.hypot(.14,.1)],HIPL=REST.hip.map(h=>[h[0]-P0.x,h[1],h[2]]);
const REST_XZ=[[-.1999-P0.x,-.165],[-.1999-P0.x,.165],[.1909-P0.x,-.165],[.1909-P0.x,.165]]; // pivot-local rest feet HL HR FL FR
const SPEED={walk:1.9,gallop:3.2,charge:4.2,flee:2.2,tWalk:1.2};
// ---------------------------------------------------------------- skeleton (bite2 rig; feet are world targets)
function ik(hip,foot,a,b,pole){
  const d=foot.clone().sub(hip);let L=d.length();const mx=a+b-1e-4,mn=Math.abs(a-b)+1e-3,err=Math.max(0,L-mx);
  const dir=d.clone().divideScalar(L||1);L=clamp(L,mn,mx);
  const x=(a*a-b*b+L*L)/(2*L),h=Math.sqrt(Math.max(0,a*a-x*x));
  const perp=pole.clone().sub(dir.clone().multiplyScalar(pole.dot(dir)));if(perp.lengthSq()<1e-8)perp.set(0,1,0);perp.normalize();
  return {knee:hip.clone().addScaledVector(dir,x).addScaledVector(perp,h),foot:hip.clone().addScaledVector(dir,L),err};
}
function toWorld(p,fr_,P,F){const v=V(p[0]-P0.x,p[1]-P0.y,p[2]-P0.z).applyQuaternion(fr_==='f'?F.Qf:F.Qr);return v.add(V(P0.x+P.bx,P0.y+P.by,P0.z+P.bz));}
function toLocal(w,fr_,P,F){const q=(fr_==='f'?F.Qf:F.Qr).clone().invert(),v=w.clone().sub(V(P0.x+P.bx,P0.y+P.by,P0.z+P.bz)).applyQuaternion(q);return [v.x+P0.x,v.y+P0.y,v.z+P0.z];}
function hipW(P,F,i){return toWorld(REST.hip[i],i>=2?'f':'r',P,F);}
function skel(P,legs){
  const F=frames(P),nodes=[],n3=REST.nodes[3];
  const qt=new T.Quaternion().setFromEuler(new T.Euler(0,P.tailY,P.tailP,'YZX'));
  for(let i=0;i<8;i++){const n=REST.nodes[i];let fr_='r',p=[n[0],n[1],0];
    if(i<3){const v=V(n[0]-n3[0],n[1]-n3[1],0).applyQuaternion(qt);p=[n3[0]+v.x,n3[1]+v.y,v.z];}else if(i>=4)fr_='f';
    nodes.push(toWorld(p,fr_,P,F));}
  const head=toWorld([REST.nodes[7][0]+P.hd[0],REST.nodes[7][1]+P.hd[1],P.hd[2]],'f',P,F);
  const sh=nodes[5],s=clamp(Math.max(P.stretch,sh.distanceTo(head)/(NECK[0]+NECK[1])*1.002),.85,1.25),ng=ik(sh,head,NECK[0]*s,NECK[1]*s,V(.25,1,0).normalize().applyQuaternion(F.Qf));
  nodes[6]=ng.knee;nodes[7]=ng.foot.clone();
  const Qh=F.Qf.clone().multiply(new T.Quaternion().setFromAxisAngle(Y,P.hyaw)).multiply(new T.Quaternion().setFromAxisAngle(Z,-P.hp)).multiply(new T.Quaternion().setFromAxisAngle(X,P.hroll));
  const axis=X.clone().applyQuaternion(Qh),headC=nodes[7].clone(),hinge=headC.clone().addScaledVector(axis,REST.hinge),tip=headC.clone().addScaledVector(axis,REST.beak);
  const out={F,nodes,stretch:s,head:headC,neckErr:ng.err,legErr:0,Qh,axis,hinge,tip,hips:[],knees:[],feet:[],targets:[]};
  if(!legs)return out;
  for(let i=0;i<4;i++){
    const fore=i>=2,hip=hipW(P,F,i),tg=V(P.feetT[i*3],P.feetT[i*3+1],P.feetT[i*3+2]);
    const pole=X.clone().add(V(0,0,(i%2?1:-1)*(P.polez||0))).applyQuaternion(fore?F.Qf:F.Qr);
    const r=ik(hip,tg,REST.seg[i][0],REST.seg[i][1],pole);if(r.knee.y<.025)r.knee.y=.025;
    out.hips.push(hip);out.knees.push(r.knee);out.feet.push(r.foot);out.targets.push(tg);out.legErr=Math.max(out.legErr,r.err);
  }
  return out;
}
// ---------------------------------------------------------------- gait styles (A42, docs/evidence/loco/styles2.md): offsets order HL HR FL FR
const STY={
  stand:{off:[0,0,0,0],beta:1,k:1,bob:0,bobPhase:0,roll:.0,pitch:0,rock:0,height:1,lift:.1,wide:0,flight:false,polez:0},
  walk:{off:[0,.5,.75,.25],beta:.70,k:.95,bob:.025,bobPhase:0,roll:.06,pitch:0,rock:.02,height:.64,lift:.12,wide:.18,flight:false,polez:.45},
  canter:{off:[0,.32,.32,.66],beta:.29,k:1.35,bob:.07,bobPhase:.5,roll:.035,pitch:-.02,rock:.095,height:.86,lift:.22,wide:0,flight:true,polez:0},
  gallop:{off:[0,.12,.62,.5],beta:.25,k:1.55,bob:.10,bobPhase:.5,roll:.035,pitch:-.04,rock:.07,height:.86,lift:.24,wide:0,flight:true,polez:0}
};
const LEG_L=REST.seg.map(s=>(s[0]+s[1])*.985);
function strideOf(pat,v){const s=STY[pat],Fr=v*v/(G*H);return Math.max(.05*H,Math.min(2.3*Math.pow(Math.min(Fr,.65),.3)*H*s.k,pat==='walk'?1.23:2.37));}
// pattern with hysteresis: stand < .15 < walk; gallop from 2.5 (or forced by a burst window) and down to 1.4
function patternAt(prev,v,burst){
  if(burst)return 'gallop';
  if(prev==='gallop'){if(v>=1.4)return 'gallop';return v>=.15?'walk':'stand';}
  if(v>=2.5)return 'gallop';
  if(prev==='stand')return v>=.2?'walk':'stand';
  return v>=.12?'walk':'stand';
}
// ---------------------------------------------------------------- small helpers
const rot=(a,x,z)=>[x*Math.cos(a)+z*Math.sin(a),-x*Math.sin(a)+z*Math.cos(a)]; // pivot-local (x fwd, z right) -> world offset for heading a
const fwd=a=>[Math.cos(a),-Math.sin(a)];
const K=(keys,ms)=>interp(keys,ms);
function wig(t0,t1,amp,hz,ramp,base){const o=[],n=Math.max(2,Math.round((t1-t0)/10));for(let k=0;k<=n;k++){const t=t0+(t1-t0)*k/n,e=Math.min(1,(t-t0)/ramp,(t1-t)/ramp);o.push([t,(base||0)+amp*Math.max(0,e)*Math.sin(2*PI*hz*(t-t0)/1000),'l']);}return o;}
function plus(base,w){const ts=new Set();base.forEach(k=>ts.add(k[0]));w.forEach(k=>ts.add(k[0]));const o=[];[...ts].sort((a,b)=>a-b).forEach(t=>o.push([t,interp(base,t)+interp(w,t),'l']));return o;}
// ================================================================ attack layer kernels (key times in ms relative to the anchor)
// bite: lab version 3 "lunge + peck hybrid" at the A71 fast timing (press = anchor - 300 ms). L lunge, d dip scale, k pitch scale
function biteLayer(o){const L=o.L,d=o.d,k=o.k,hold=o.hold||60,rel=o.rel||130,ex=o.exLunge||1;
  return {win:[-300,hold+rel+500],
  ch:{
    bx:[[-300,0],[-120,-.3*L*.4,'s'],[0,L,'i2'],[hold+70,L*1.07,'o'],[hold+300,L*.55,'s'],[hold+620,0,'s']],
    by:[[-300,0],[-120,-.2*d,'s'],[0,-.18*d,'i2'],[hold+80,-.17*d,'o'],[hold+620,0,'s']],
    pitch:[[-300,0],[-120,.06*k,'s'],[0,.18*k,'i2'],[hold+90,.18*k],[hold+620,0,'s']],
    sp:[[-300,0],[-120,.1,'s'],[0,-.05,'i2'],[hold+260,0,'s']],
    hd:[[-300,[0,0,0]],[-110,[-.14,-.1,0],'s'],[-40,[-.15,.03,0],'s'],[0,[0,0,0],'i'],[hold+rel,[-.04,.03,0],'o'],[hold+rel+260,[0,0,0],'s']],
    hp:[[-300,0],[-110,.28,'s'],[-40,.18,'s'],[0,0,'i'],[hold+rel,-.1,'o'],[hold+rel+260,0,'s']],
    gape:[[-300,0],[-190,.25,'s'],[-100,1,'o'],[-14,1],[0,0,'i2'],[hold+rel,0],[hold+rel+60,.35,'o'],[hold+rel+140,0,'s']],
    stretch:[[-300,1],[-120,.95,'s'],[0,1.04,'i2'],[hold+rel+120,1,'o']],
    tailP:[[-300,0],[-120,-.14,'s'],[0,.5*ex,'i2'],[hold+110,.38*ex,'o'],[hold+640,0,'s']],
    tailY:[[-300,0],[-120,.1,'s'],[0,-.12,'i2'],[hold+300,.05,'s'],[hold+640,0,'s']]},
  wc:[[-300,0],[-70,0,'s'],[0,1,'i'],[hold,1],[hold+rel,0,'s']],aC:o.aC||.55};}
// dash-tackle / charge impact: low burst, head lowered, shoulder and chest slam. Chest contact (no head solve).
function tackleLayer(o){const sp=o.pre||1;
  return {win:[-700,1100],
  ch:{
    by:[[-700,0],[-380,-.26*sp,'o'],[-60,-.29*sp,'s'],[0,-.27,'s'],[130,-.31,'s'],[500,-.2,'s'],[1000,0,'s']],
    pitch:[[-700,0],[-380,.12*sp,'o'],[-60,.2*sp,'s'],[0,.2,'i2'],[200,.1,'s'],[500,.05,'s'],[1000,0,'s']],
    sp:[[-700,0],[0,.08*sp,'i2'],[250,0,'s']],
    hd:[[-700,[0,0,0]],[-380,[-.06,-.05,0],'o'],[-60,[.0,.04,0],'s'],[0,[.0,.07,0],'s'],[500,[.02,.1,0],'s'],[1000,[0,0,0],'s']],
    hp:[[-700,0],[-380,.1,'s'],[0,-.1,'s'],[600,0,'s']],
    gape:[[-700,0],[-70,0],[0,.8,'o'],[500,.8],[700,0,'s']],
    tailP:[[-700,0],[-380,-.1,'s'],[-60,.15,'s'],[0,.5,'s'],[500,.3,'s'],[1000,0,'s']],
    bx:[[-700,0],[0,0],[120,.2,'o'],[350,.3,'o'],[600,.0,'s']]},
  wc:[[-700,0],[1000,0]]};}
// cat pounce: crouch, freeze + butt wiggle, coil, leap (flight arc handled by the path), land beak + front feet on the prey, pin, step off
function pounceLayer(o){const q=o.quick,t0=q?-640:-1000,tw0=q?-640:-850,tw1=q?-540:-570;
  const wg=q?[[t0,0],[1500,0]]:wig(tw0,tw1,.3,5.5,160,0);
  return {win:[t0,1500],flight:500,
  ch:{
    by:[[t0,0],[t0+200,-.2,'o'],[tw0,-.26,'s'],[-540,-.31,'s'],[-500,0,'i'],[0,-.14,'o'],[200,-.2,'s'],[480,-.2],[800,-.12,'s'],[1300,0,'s']],
    pitch:[[t0,0],[t0+200,.05,'s'],[tw0,.14,'s'],[-570,-.12,'s'],[-500,-.28,'o'],[-250,0,'s'],[-30,.3,'i2'],[60,.2,'o'],[480,.2],[800,.05,'s'],[1300,0,'s']],
    sp:[[t0,0],[-570,.05,'s'],[-500,-.08,'o'],[0,.1,'s'],[800,0,'s']],
    hd:[[t0,[0,0,0]],[t0+200,[.04,-.22,0],'o'],[-570,[.02,-.2,0]],[-500,[-.2,-.04,0],'o'],[-250,[-.26,0,0],'s'],[0,[-.22,-.1,0],'s'],[480,[-.22,-.1,0]],[800,[-.1,0,0],'s'],[1200,[0,0,0],'s']],
    hp:[[t0,0],[-500,0,'s'],[-110,0],[0,.35,'i2'],[480,.35],[800,0,'s']],
    gape:[[t0,0],[-150,0],[-85,.9,'o'],[-12,.9],[0,0,'i2'],[400,0]],
    tailP:[[t0,0],[tw0,-.08,'s'],[-570,-.16,'s'],[-500,.1,'o'],[0,.4,'s'],[60,.3,'o'],[800,.1,'s'],[1300,0,'s']],
    tailY:q?[[t0,0],[1500,0]]:wg,
    roll:q?[[t0,0],[1500,0]]:wig(tw0,tw1,.055,5.5,160,0)},
  wc:[[t0,0],[-40,0,'s'],[0,1,'i'],[480,1],[560,0,'s']],aC:.62,arcAt:-500};}
// spit kernels (lab spit_core): rise + throat pulses, fire at 0. s scales the body dip when the legs are moving
function spitLayer(o){const s=o.s,t=o.type,hpA='aim',W=o.wind;
  if(t==='jet')return {win:[-W,900],fire:0,dur:200,ch:{
    sp:[[-W,0],[-W+300,-.22,'o'],[0,-.22],[60,-.26,'o'],[350,-.2,'s'],[850,0,'s']],
    by:[[-W,0],[-W+300,-.05*s,'s'],[90,-.07*s,'o'],[400,-.04*s,'s'],[850,0,'s']],
    bx:[[-W,0],[-W+300,-.03*s,'o'],[90,-.05*s,'o'],[400,-.03*s,'s'],[850,0,'s']],
    hd:[[-W,[0,0,0]],[-W+300,[-.15,.16,0],'o'],[-40,[-.17,.17,0],'s'],[50,[-.05,.12,0],'o'],[400,[-.07,.10,0],'s'],[850,[0,0,0],'s']],
    hpR:[[-W,0],[-W+300,.25,'o'],[-30,.25]],
    gape:[[-W,0],[-140,0],[-50,1,'o'],[260,1],[430,0,'s']],mg:[[-W,0],[-100,0],[0,1,'o'],[260,.7],[430,0,'s']],
    tailP:[[-W,0],[-W+300,.15,'s'],[80,.28,'o'],[850,0,'s']],glow:[[-W,0],[-W+300,.5,'s'],[0,.8],[430,0,'s']],throat:[[-W,0],[-W+300,.15],[0,.2,'s'],[300,0,'s']]},
    pulses:[[-W+300,-W+490],[-W+470,-W+660]],wa:[[-W,0],[-160,0,'s'],[-20,1],[200,1],[420,0,'s']]};
  if(t==='lob')return {win:[-W,900],fire:0,dur:1,ch:{
    sp:[[-W,0],[-220,-.18,'s'],[-40,-.15,'s'],[40,-.02,'o'],[360,-.02,'s'],[860,0,'s']],
    by:[[-W,0],[-220,-.03*s,'s'],[40,-.05*s,'o'],[340,0,'s']],bx:[[-W,0],[-220,-.06*s,'o'],[40,.04*s,'o'],[260,-.01,'s'],[860,0,'s']],
    hd:[[-W,[0,0,0]],[-210,[-.17,.12,0],'o'],[-50,[-.19,.10,0],'s'],[30,[.06,.06,0],'o'],[340,[0,.03,0],'s'],[860,[0,0,0],'s']],
    hpR:[[-W,0],[-210,-1.15,'o'],[-40,-1.2,'s']],
    gape:[[-W,0],[-110,0],[-40,.8,'o'],[170,.8],[330,0,'s']],mg:[[-W,0],[-140,0],[-20,1],[40,.6,'o'],[240,0,'s']],
    tailP:[[-W,0],[-220,-.15,'s'],[40,.25,'o'],[860,0,'s']],cheek:[[-W,0],[-440,.25,'s'],[-40,1,'s'],[30,.9],[280,0,'s']],
    throat:[[-W,0],[-400,.15,'s'],[-40,1,'s'],[40,.45,'o'],[260,0,'s']],glow:[[-W,0],[-350,.35,'s'],[0,.8],[400,0,'s']]},
    pulses:[[-440,-270]],wa:[[-W,0],[-120,0,'s'],[-20,1],[420,1],[700,0,'s']]};
  // glob: long charged wind-up, big slow glob
  return {win:[-W,1000],fire:0,dur:1,ch:{
    sp:[[-W,0],[-W+280,-.10*s,'o'],[0,-.22,'s'],[60,.02,'i2'],[230,-.04,'o'],[800,0,'s']],
    pitch:[[-W,0],[-W+280,.06*s,'o'],[0,-.08,'s'],[60,.08,'o'],[300,0,'s']],
    bx:[[-W,0],[-W+280,-.04*s,'o'],[0,-.06*s,'s'],[70,-.20*s,'o'],[380,-.10*s,'s'],[800,0,'s']],
    by:[[-W,0],[-W+280,-.17*s,'o'],[0,-.19*s,'s'],[60,-.1*s,'o'],[350,-.06*s,'s'],[800,0,'s']],
    hd:[[-W,[0,0,0]],[-W+300,[-.07,-.06,0],'o'],[-120,[-.16,.0,0],'s'],[20,[-.2,.08,0],'s'],[80,[.07,.05,0],'o'],[400,[0,.02,0],'s'],[800,[0,0,0],'s']],
    hpR:[[-W,0],[-W+300,.35,'o'],[-120,.5,'s'],[10,-.55,'o2']],
    gape:[[-W,0],[-220,0],[-120,.55,'s'],[-10,.7],[30,1,'o'],[320,1],[520,0,'s']],mg:[[-W,0],[-500,0],[0,1,'s'],[300,.5],[560,0,'s']],
    tailP:[[-W,0],[-200,.25,'s'],[60,.5,'o'],[800,0,'s']],cheek:[[-W,0],[-650,.15,'s'],[-100,.9,'s'],[50,.9],[320,0,'s']],
    throat:[[-W,0],[-850,.25,'s'],[-60,1.2,'s'],[80,.5,'o'],[350,0,'s']],glow:[[-W,0],[-850,.2,'s'],[-60,1,'s'],[200,.7],[560,0,'s']]},
    pulses:[[-770,-510],[-450,-200]],wa:[[-W,0],[-300,0,'s'],[-60,1],[500,1],[760,0,'s']],big:true};}
// roar kernels (lab roar_core), anchor = emit
function rearLayer(){return {win:[-620,1330],ch:{
  by:[[-620,0],[-400,-.09,'s'],[-300,-.07,'s'],[0,0,'s'],[140,.02,'s'],[600,.015,'s'],[740,-.04,'i2'],[880,-.11,'o'],[1080,-.02,'s'],[1330,0,'s']],
  bx:[[-620,0],[-400,-.07,'s'],[0,-.12,'s'],[600,-.12],[840,-.04,'i2'],[1080,0,'s']],
  pitch:[[-620,0],[-400,.1,'s'],[-290,.08,'s'],[0,-.5,'o'],[80,-.56,'s'],[600,-.56],[880,.06,'i2'],[1080,0,'s']],
  sp:[[-620,0],[-400,.1,'s'],[-290,.06],[0,-.4,'o'],[80,-.5,'s'],[600,-.5],[860,.0,'i2'],[1080,0,'s']],
  hd:[[-620,[0,0,0]],[-400,[-.04,-.12,0],'s'],[-200,[-.1,-.05,0],'s'],[-20,[.0,.07,0],'o'],[80,[.02,.09,0],'s'],[600,[.02,.09,0]],[800,[0,-.04,0],'s'],[1330,[0,0,0],'s']],
  hp:[[-620,0],[-400,.15,'s'],[-200,.1,'s'],[-20,-.25,'s'],[80,-.5,'s'],[600,-.5],[800,0,'s'],[1330,0,'s']],
  gape:[[-620,0],[-60,0],[20,1.15,'o'],[550,1.15],[660,0,'i2'],[1330,0]],
  stretch:[[-620,1],[0,1.06,'s'],[140,1.16,'s'],[600,1.16],[830,1,'s']],
  tailP:[[-620,0],[-400,-.1,'s'],[0,-.35,'s'],[600,-.35],[880,.1,'s'],[1080,0,'s']],tailY:wig(40,580,.14,5,160,0),
  chest:[[-620,0],[-180,.2,'s'],[0,1,'o'],[600,1],[780,.2,'s'],[1080,0,'s']],
  thr:[[-620,0],[0,.2,'s'],[100,.65,'o'],[1080,.65],[1240,0,'s']],crest:[[-620,0],[-300,.4,'s'],[0,1,'s'],[700,1],[1000,0,'s']]},
  air:{legs:[2,3],t0:-300,t1:760}};}
function bellowLayer(o){const s=o.s;return {win:[-520,1500],ch:{
  by:plus([[-520,0],[-220,-.13*s,'s'],[-100,-.15*s,'s'],[0,-.16*s,'s'],[1220,-.16*s],[1480,-.02,'s'],[1900,0,'s']],wig(20,1200,.004,21,80,0)),
  bx:[[-520,0],[-220,.05,'s'],[0,.08,'s'],[1220,.08],[1480,0,'s']],
  pitch:[[-520,0],[-220,.14*s,'s'],[0,.2*s,'s'],[1220,.2*s],[1480,0,'s']],
  sp:[[-520,0],[-220,.04],[0,.08],[1220,.08],[1480,0,'s']],
  hd:[[-520,[0,0,0]],[-220,[.08,-.18,0],'s'],[0,[.15,-.22,0],'s'],[1220,[.15,-.22,0]],[1480,[0,0,0],'s']],
  hp:[[-520,0],[0,-.25,'s'],[1220,-.25],[1480,0,'s']],
  gape:plus([[-520,0],[-40,0],[80,.85,'o'],[1180,.85],[1280,0,'i2'],[1900,0]],wig(100,1160,.12,7,140,0)),
  stretch:[[-520,1],[-220,1.05,'s'],[0,1.13,'s'],[1220,1.13],[1480,1,'s']],
  tailP:[[-520,0],[-100,-.2,'s'],[1220,-.2],[1480,0,'s']],tailY:wig(0,1220,.08,8,160,0),
  chest:[[-520,0],[-100,.35,'s'],[0,.6,'s'],[1220,.6],[1480,0,'s']],
  thr:plus([[-520,0],[0,.2,'s'],[100,.65,'o'],[1180,.65],[1340,0,'s']],wig(100,1180,.32,10,100,0)),hroll:wig(100,1180,.04,17,150,0)}};}
root.ACCORE0={T,B,REST,V,interp,frames,DEF,skel,toWorld,toLocal,hipW,ik,STY,strideOf,patternAt,rot,fwd,K,wig,plus,clamp,sm,fr,G,DT,H,FY,R,CY,PI,P0,HIPL,REST_XZ,SPEED,LEG_L,
  layers:{biteLayer,tackleLayer,pounceLayer,spitLayer,rearLayer,bellowLayer}};
})(typeof window!=='undefined'?window:globalThis);
