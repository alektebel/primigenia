'use strict';
// Primigenia bite lab core (A58/A60): starter B (no arms, beak "pico"). Pure maths on top of THREE vectors, no DOM.
// Units: metres, +x forward, +y up, +z the creature's right side (towards the side camera). Times in ms of ANIMATION time;
// the hit-pause freezes animation time for `pause` ms of real time (see realToAnim).
(function(root){
const T=root.THREE||require('three');
const X=new T.Vector3(1,0,0),Y=new T.Vector3(0,1,0),Z=new T.Vector3(0,0,1);
const V=(x,y,z)=>new T.Vector3(x,y,z);
const clamp=(x,a,b)=>x<a?a:x>b?b:x;
const EASE={l:u=>u,s:u=>u*u*(3-2*u),o:u=>1-Math.pow(1-u,3),o2:u=>1-(1-u)*(1-u),i:u=>u*u*u,i2:u=>u*u,b:u=>{const c1=1.70158,c3=c1+1;return 1+c3*Math.pow(u-1,3)+c1*Math.pow(u-1,2);}};
const mix=(a,b,e)=>Array.isArray(a)?a.map((v,i)=>v+(b[i]-v)*e):a+(b-a)*e;
function interp(keys,t){
  const n=keys.length;if(t<=keys[0][0])return keys[0][1];if(t>=keys[n-1][0])return keys[n-1][1];
  let i=0;while(t>keys[i+1][0])i++;const k0=keys[i],k1=keys[i+1],u=(t-k0[0])/(k1[0]-k0[0]);
  return mix(k0[1],k1[1],EASE[k1[2]||'s'](u));
}
// ---------------------------------------------------------------- starter B (godot/game/data/starters/b_runner.json)
const REST={
  nodes:[[-.7,.58,.03],[-.52,.6,.046],[-.32,.63,.092],[-.1,.66,.12],[.12,.68,.115],[.3,.72,.087],[.44,.88,.06],[.58,.98,.087]],
  P0:[-.1,.66,0],hr:.087,beak:.22,hinge:.04,
  hip:[[-.1999,.5969,-.0948],[-.1999,.5969,.0948],[.1909,.6391,-.0925],[.1909,.6391,.0925]], // HL HR FL FR
  seg:[[.317,.3406],[.317,.3406],[.327,.3499],[.327,.3499]],footZ:.165,footY:.03,
  color:'#b98f5a',cB:'#5a4026',cC:'#eadfc4'
};
const FOOT_REST=[[-.1999,-.165],[-.1999,.165],[.1909,-.165],[.1909,.165]];
const NECK=[Math.hypot(.14,.16),Math.hypot(.14,.1)];
const P0=V(...REST.P0);
function frames(P){
  const qy=new T.Quaternion().setFromAxisAngle(Y,P.yaw),qp=new T.Quaternion().setFromAxisAngle(Z,-P.pitch),qr=new T.Quaternion().setFromAxisAngle(X,P.roll);
  const Qr=qy.clone().multiply(qp).multiply(qr),Qf=Qr.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,-P.sp));
  return {Qr,Qf};
}
function toWorld(p,fr,P,F){const v=V(p[0]-P0.x,p[1]-P0.y,p[2]-P0.z).applyQuaternion(fr==='f'?F.Qf:F.Qr);return v.add(V(P0.x+P.bx,P0.y+P.by,P0.z+P.bz));}
function toLocal(w,fr,P,F){const q=(fr==='f'?F.Qf:F.Qr).clone().invert(),v=w.clone().sub(V(P0.x+P.bx,P0.y+P.by,P0.z+P.bz)).applyQuaternion(q);return [v.x+P0.x,v.y+P0.y,v.z+P0.z];}
// two-bone IK. Returns knee and the foot actually reached (clamped), plus the stretch error.
function ik(hip,foot,a,b,pole){
  const d=foot.clone().sub(hip);let L=d.length();const mx=a+b-1e-4,mn=Math.abs(a-b)+1e-3,err=Math.max(0,L-mx);
  const dir=d.clone().divideScalar(L||1);L=clamp(L,mn,mx);
  const x=(a*a-b*b+L*L)/(2*L),h=Math.sqrt(Math.max(0,a*a-x*x));
  const perp=pole.clone().sub(dir.clone().multiplyScalar(pole.dot(dir)));if(perp.lengthSq()<1e-8)perp.set(0,1,0);perp.normalize();
  return {knee:hip.clone().addScaledVector(dir,x).addScaledVector(perp,h),foot:hip.clone().addScaledVector(dir,L),err};
}
const DEF={bx:0,by:0,bz:0,yaw:0,pitch:0,roll:0,sp:0,hp:0,hyaw:0,hroll:0,gape:0,stretch:1,tailP:0,tailY:0,fxF:0,fxH:0};
function skeleton(P){
  const F=frames(P),nodes=[];
  const n3=REST.nodes[3];
  const qt=new T.Quaternion().setFromEuler(new T.Euler(0,P.tailY,P.tailP,'YZX'));
  for(let i=0;i<8;i++){
    const n=REST.nodes[i];let fr='r',p=[n[0],n[1],0];
    if(i<3){const v=V(n[0]-n3[0],n[1]-n3[1],0).applyQuaternion(qt);p=[n3[0]+v.x,n3[1]+v.y,v.z];}
    else if(i>=4)fr='f';
    nodes.push(toWorld(p,fr,P,F));
  }
  const head=toWorld([REST.nodes[7][0]+P.hd[0],REST.nodes[7][1]+P.hd[1],P.hd[2]],'f',P,F);
  const sh=nodes[5],s=clamp(Math.max(P.stretch,sh.distanceTo(head)/(NECK[0]+NECK[1])*1.002),.85,1.25),ng=ik(sh,head,NECK[0]*s,NECK[1]*s,V(.25,1,0).normalize().applyQuaternion(F.Qf));
  nodes[6]=ng.knee;nodes[7]=ng.foot.clone();
  const Qh=F.Qf.clone().multiply(new T.Quaternion().setFromAxisAngle(Y,P.hyaw)).multiply(new T.Quaternion().setFromAxisAngle(Z,-P.hp)).multiply(new T.Quaternion().setFromAxisAngle(X,P.hroll));
  const axis=X.clone().applyQuaternion(Qh),headC=nodes[7].clone(); // head follows the clamped neck end
  const hinge=headC.clone().addScaledVector(axis,REST.hinge),tip=headC.clone().addScaledVector(axis,REST.beak);
  const hips=[],knees=[],feet=[],targets=[];let legErr=0;
  for(let i=0;i<4;i++){
    const fore=i>=2,fr=fore?'f':'r',hip=toWorld(REST.hip[i],fr,P,F),f=P.feet[i];
    const Wp=V(f.W[0],REST.footY,f.W[1]),Bp=hip.clone().add(V(...f.B).applyQuaternion(fore?F.Qf:F.Qr));
    const tg=Wp.clone().lerp(Bp,f.w);
    const pole=X.clone().applyQuaternion(fore?F.Qf:F.Qr);
    const r=ik(hip,tg,REST.seg[i][0],REST.seg[i][1],pole);
    hips.push(hip);knees.push(r.knee);feet.push(r.foot);targets.push(tg);legErr=Math.max(legErr,r.err);
  }
  return {F,nodes,stretch:s,head:headC,headTarget:head,neckErr:ng.err,legErr,Qh,axis,hinge,tip,hips,knees,feet,targets};
}
// ---------------------------------------------------------------- versions (round 2)
// Placeholders in head keys: {C:[dx,dy,dz]} / {D:[...]} = contact head offset of hit 1 / hit 2 + extra; hp: {C:extra}.
// fxF / fxH = front / hind foot slide along x (m) from the rest position; a foot with fx constant and w=0 is planted.
const R_ABS=0;
const VERSIONS=[
// 1. the round-1 lunge, unchanged: the reference
{ id:'lunge',ref:true,name:'Lunge-bite (round 1)',tag:'the reference: whole body drives from the hind legs, front legs brace',
  tc:420,pause:80,end:1120,ph:{ant:[0,270],str:[270,420],fol:[420,590],rec:[590,1120]},
  prey:{c0:[1.42,.34,0],aC:.5,v0:2.2,mu:7,hop:.035,tilt:.42,amp:.2,kind:'knock'},
  ch:{
    bx:[[0,0],[270,-.13,'s'],[420,.37,'i2'],[500,.4,'o'],[700,.2,'s'],[1120,0,'s']],
    by:[[0,0],[270,-.24,'s'],[420,-.2,'i2'],[520,-.19,'o'],[1120,0,'s']],
    pitch:[[0,0],[270,.02,'s'],[420,.2,'i2'],[520,.2],[1120,0,'s']],
    sp:[[0,0],[270,.14,'s'],[420,-.06,'i2'],[700,0,'s']],
    hd:[[0,[0,0,0]],[270,[-.16,-.36,0],'s'],[420,{C:[0,0,0]},'i2'],[500,{C:[-.04,.03,0]},'o'],[700,[-.1,-.02,0],'s'],[1120,[0,0,0],'s']],
    hp:[[0,0],[270,.05,'s'],[420,{C:0},'i2'],[500,{C:-.1},'o'],[1120,0,'s']],
    gape:[[0,0],[190,.25,'s'],[300,1,'o'],[405,1],[420,0,'i2'],[500,0],[540,.35,'o'],[620,0,'s']],
    stretch:[[0,1],[270,.92,'s'],[420,1.18,'i2'],[520,1.05,'o'],[760,1,'s']],
    tailP:[[0,0],[270,-.1,'s'],[420,.4,'i2'],[540,.3,'o'],[1120,0,'s']],
    tailY:[[0,0],[270,.1,'s'],[420,-.1,'i2'],[600,.05,'s'],[1120,0,'s']]
  },
  holds:{pre:[270,300],post:250}
},
// 2. more explosive: deeper coil, strike 110 ms, big tail counter-lift, hard knockback, dust from the hind feet, front feet skid forward
{ id:'boom',name:'Explosive lunge',tag:'deeper coil, 110 ms drive, big tail counter-lift, hard knockback, dust kicked from the hind feet',
  tc:430,pause:80,end:1180,ph:{ant:[0,320],str:[320,430],fol:[430,600],rec:[600,1180]},
  prey:{dir:[-.88,.48],c0:[1.42,.34,0],aC:.45,v0:3.0,mu:8,hop:.07,tilt:.62,amp:.32,kind:'knock'},
  ch:{
    bx:[[0,0],[320,-.2,'s'],[430,.46,'i2'],[520,.5,'o'],[740,.3,'s'],[1180,0,'s']],
    by:[[0,0],[320,-.34,'s'],[430,-.24,'i2'],[540,-.22,'o'],[1180,0,'s']],
    pitch:[[0,0],[320,-.04,'s'],[430,.26,'i2'],[540,.26],[1180,0,'s']],
    sp:[[0,0],[320,.18,'s'],[430,-.1,'i2'],[740,0,'s']],
    hd:[[0,[0,0,0]],[320,[-.2,-.34,0],'s'],[430,{C:[0,0,0]},'i2'],[520,{C:[-.04,.03,0]},'o'],[740,[-.1,-.04,0],'s'],[1180,[0,0,0],'s']],
    hp:[[0,0],[320,.1,'s'],[430,{C:0},'i2'],[520,{C:-.1},'o'],[1180,0,'s']],
    gape:[[0,0],[210,.25,'s'],[310,1,'o'],[415,1],[430,0,'i2'],[520,0],[560,.35,'o'],[640,0,'s']],
    stretch:[[0,1],[320,.92,'s'],[430,1.0,'i2'],[560,1,'o']],
    tailP:[[0,0],[320,-.24,'s'],[430,.72,'i2'],[580,.55,'o'],[1180,0,'s']],
    tailY:[[0,0],[320,.14,'s'],[430,-.16,'i2'],[620,.06,'s'],[1180,0,'s']],
    fxF:[[0,0],[320,0],[440,.2,'o'],[760,.2],[1000,0,'s']]
  },
  holds:{pre:[320,300],post:200},kick:{off:0,feet:[0,1],n:7}
},
// 3. hybrid: body lunge AND a neck snap in the last 50 ms; cocked-S neck, carried low, during the hold
{ id:'hybrid',name:'Lunge + peck hybrid',tag:'body drives, neck stays cocked in an S, the head whips the last 15 cm',
  tc:450,pause:80,end:1160,ph:{ant:[0,310],str:[310,450],fol:[450,610],rec:[610,1160]},
  prey:{dir:[-.8,.6],c0:[1.40,.34,0],aC:.55,v0:2.5,mu:7,hop:.05,tilt:.5,amp:.26,kind:'knock'},
  ch:{
    bx:[[0,0],[310,-.12,'s'],[450,.4,'i2'],[520,.43,'o'],[740,.22,'s'],[1160,0,'s']],
    by:[[0,0],[310,-.2,'s'],[450,-.18,'i2'],[530,-.17,'o'],[1160,0,'s']],
    pitch:[[0,0],[310,.06,'s'],[450,.18,'i2'],[540,.18],[1160,0,'s']],
    sp:[[0,0],[310,.1,'s'],[450,-.05,'i2'],[740,0,'s']],
    hd:[[0,[0,0,0]],[310,[-.14,-.1,0],'s'],[390,{C:[-.15,.03,0]},'s'],[450,{C:[0,0,0]},'i'],[520,{C:[-.04,.03,0]},'o'],[740,[-.1,-.04,0],'s'],[1160,[0,0,0],'s']],
    hp:[[0,0],[310,.28,'s'],[390,{C:.18},'s'],[450,{C:0},'i'],[520,{C:-.1},'o'],[1160,0,'s']],
    gape:[[0,0],[200,.25,'s'],[320,.6,'o'],[400,1,'o'],[436,1],[450,0,'i2'],[520,0],[560,.35,'o'],[640,0,'s']],
    stretch:[[0,1],[310,.95,'s'],[450,1.04,'i2'],[560,1,'o']],
    tailP:[[0,0],[310,-.14,'s'],[450,.5,'i2'],[560,.38,'o'],[1160,0,'s']],
    tailY:[[0,0],[310,.1,'s'],[450,-.12,'i2'],[620,.05,'s'],[1160,0,'s']],
    fxF:[[0,0],[310,0],[460,.16,'o'],[760,.16],[1000,0,'s']]
  },
  holds:{pre:[310,310],post:230}
},
// 4. the chain: lunge, then a light peck-snap follow-up (the peck part, cock to recovery, lasts under 0.8 s). Authored in absolute time.
{ id:'chain',manual:true,name:'Lunge, then peck-snap',tag:'lunge-bite, then a quick light peck on the prey it just knocked loose',
  tc:670,pause:80,end:1460,slide1:760,peckStart:760,
  phl:[['wind-up',0,240],['hold',240,540],['lunge strike',540,670],['hold on',670,760],['cock',760,890],['peck strike',890,975],['hold on',975,1035],['recovery',1035,1460]],
  hit2:{tc:975,pause:60,aC:.62,dir:[-.85,.52],v0:1.0,mu:9,hop:.015,tilt:.4,amp:.14,slideAt:1035},
  prey:{dir:[-.88,.48],c0:[1.28,.34,0],aC:.45,v0:1.0,mu:8,hop:.02,tilt:.3,amp:.2,kind:'knock'},
  ch:{
    bx:[[0,0],[240,-.1,'s'],[540,-.1],[670,.34,'i2'],[760,.36,'o'],[890,.34,'s'],[975,.5,'i2'],[1035,.5],[1460,0,'s']],
    by:[[0,0],[240,-.2,'s'],[540,-.2],[670,-.2,'i2'],[760,-.19],[890,-.18,'s'],[975,-.22,'i2'],[1035,-.22],[1460,0,'s']],
    pitch:[[0,0],[240,.02,'s'],[540,.02],[670,.2,'i2'],[760,.2],[890,.14,'s'],[975,.32,'i2'],[1035,.32],[1460,0,'s']],
    sp:[[0,0],[240,.14,'s'],[540,.14],[670,-.06,'i2'],[760,0,'s'],[890,.06,'s'],[975,-.1,'i2'],[1035,-.04],[1460,0,'s']],
    hd:[[0,[0,0,0]],[240,[-.14,-.2,0],'s'],[540,[-.14,-.2,0]],[670,{C:[0,0,0]},'i2'],[760,{C:[-.03,.02,0]},'o'],[890,[-.14,-.06,0],'s'],[975,{D:[0,0,0]},'i'],[1035,{D:[-.03,.02,0]},'o'],[1460,[0,0,0],'s']],
    hp:[[0,0],[240,.05,'s'],[540,.05],[670,{C:0},'i2'],[760,{C:-.08},'o'],[890,.4,'s'],[975,{D:0},'i'],[1035,{D:-.1},'o'],[1460,0,'s']],
    gape:[[0,0],[150,.25,'s'],[225,1,'o'],[655,1],[670,0,'i2'],[760,0],[800,.3,'o'],[845,0,'s'],[925,0],[945,1,'o'],[968,1],[975,0,'i2'],[1035,0],[1055,.3,'o'],[1100,0,'s']],
    stretch:[[0,1],[240,.94,'s'],[670,1,'i2']],
    tailP:[[0,0],[240,-.1,'s'],[540,-.1],[670,.42,'i2'],[760,.3,'o'],[890,.2,'s'],[975,.38,'i2'],[1120,.2,'s'],[1460,0,'s']],
    tailY:[[0,0],[240,.1,'s'],[540,.1],[670,-.1,'i2'],[890,.0,'s'],[1460,0,'s']],
    fxF:[[0,0],[540,0],[690,.12,'o'],[890,.12],[1000,.22,'o'],[1300,.22],[1440,0,'s']]
  },
  kick:{t:540,feet:[0,1],n:5}
}];
const DIR0=[-.62,.78];
function shiftKeys(keys,at,dur){
  keys=keys.slice();let ex=keys.find(k=>k[0]===at),v;
  if(ex)v=ex[1];else{v=interp(keys,at);keys.push([at,v,'s']);keys.sort((p,q)=>p[0]-q[0]);}
  const out=keys.map(k=>k[0]>at?[k[0]+dur,k[1],k[2]]:k);out.push([at+dur,v,'l']);out.sort((p,q)=>p[0]-q[0]);return out;
}
function prep(ver){
  const pr=ver.prey;
  if(!ver.manual){
    const ph=ver.ph,[at,dur]=ver.holds.pre,sh=t=>t>at?t+dur:t;
    for(const k in ver.ch)ver.ch[k]=shiftKeys(ver.ch[k],at,dur);
    ver.tc=sh(ver.tc);ver.end+=dur;ph.hold=[at,at+dur];ph.str=[at+dur,sh(ph.str[1])];ph.fol=ph.fol.map(sh);ph.rec=ph.rec.map(sh);
    const H=ver.holds.post;pr.slideAt=ver.tc;
    if(H){const tc=ver.tc,s2=t=>t>tc?t+H:t;
      for(const k in ver.ch)ver.ch[k]=shiftKeys(ver.ch[k],tc,H);
      ver.end+=H;ph.cling=[tc,tc+H];ph.fol=[tc+H,s2(ph.fol[1])];ph.rec=ph.rec.map(s2);pr.slideAt=tc+H;}
    ver.phl=[['wind-up',...ph.ant],['hold',...ph.hold],['strike',...ph.str],['hold on',...ph.cling],['pull out',...ph.fol],['recovery',...ph.rec]];
    if(ver.kick&&ver.kick.t===undefined)ver.kick.t=ph.str[0]+ver.kick.off;
    ver.peckStart=null;
  }else pr.slideAt=ver.slide1;
  ver.hits=[{tc:ver.tc,pause:ver.pause,aC:pr.aC,dir:pr.dir||DIR0,key:'C',v0:pr.v0,mu:pr.mu,hop:pr.hop,tilt:pr.tilt,amp:pr.amp,slideAt:pr.slideAt}];
  if(ver.hit2)ver.hits.push(Object.assign({key:'D'},ver.hit2));
  const rl=a=>animToReal(ver,a),ph=ver.phl,find=n=>ph.find(p=>p[0]===n);
  if(ver.manual)ver.strip=[(240+540)/2,(540+670)/2-10,ver.hits[0].tc+ver.hits[0].pause/2-0,(760+890)/2,975,(1035+ver.end)/2];
  else ver.strip=[ver.phl[0],ver.phl[1],ver.phl[2]].map(p=>(p[1]+p[2])/2).concat([ver.tc,ver.phl[4][1]+(ver.phl[4][2]-ver.phl[4][1])*.5,(ver.phl[5][1]+ver.phl[5][2])/2]);
  // strip frames in real time: frame 3 and 5 sit inside a hit-pause
  if(ver.manual)ver.strip=[390,600,ver.tc+ver.pause/2,825,ver.hits[1].tc+ver.hits[1].pause/2,1250].map((v,i)=>i===2?hitReal(ver,0)+ver.hits[0].pause/2:i===4?hitReal(ver,1)+ver.hits[1].pause/2:rl(v));
  else ver.strip=ver.strip.map((v,i)=>i===3?hitReal(ver,0)+ver.pause/2:rl(v));
  ver.strip=ver.strip.map(Math.round);
}
function hitReal(ver,k){let s=0;for(let j=0;j<k;j++)s+=ver.hits[j].pause;return ver.hits[k].tc+s;}
function animToReal(ver,a){let s=0;for(const h of ver.hits)if(h.tc<a)s+=h.pause;return a+s;}
function partsOf(ver){ // [name, ms] in real order, with the hit-pauses inserted
  const out=[];for(const [n,a,b] of ver.phl){out.push([n,b-a]);const h=ver.hits.find(h=>h.tc===b);if(h)out.push(['contact',h.pause]);}return out;
}
// ---------------------------------------------------------------- build: contact solve, feet, prey
const PREY={R:.27,dirLocal:DIR0};
function chanAt(ver,name,a){const k=ver.ch[name];if(!k)return name==='hd'?[0,0,0]:DEF[name];return interp(k,a);}
function feetAt(ver,a){
  const out=[],fF=chanAt(ver,'fxF',a),fH=chanAt(ver,'fxH',a);
  for(let i=0;i<4;i++){const f=ver.feetSpec[i],W=interp(f.W.map(k=>[k[0],k[1],'l']),a);out.push({W:[W[0]+(i>=2?fF:fH),W[1]],w:interp(f.w,a),B:f.B});}
  return out;
}
function poseAt(ver,a,noHead){
  const P={};for(const n in DEF)P[n]=chanAt(ver,n,a);
  P.hd=noHead?[0,0,0]:chanAt(ver,'hd',a);P.feet=feetAt(ver,a);return P;
}
function solveHit(ver,h,c0){
  const T0=c0.clone().add(V(h.dir[0],h.dir[1],0).multiplyScalar(PREY.R-.006));
  const P=poseAt(ver,h.tc,true),F=frames(P),hpC=h.aC-P.pitch-P.sp;
  const Qh=F.Qf.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,-hpC)),axis=X.clone().applyQuaternion(Qh);
  const Hw=T0.clone().addScaledVector(axis,-REST.beak),loc=toLocal(Hw,'f',P,F);
  h.contact=T0;h.c0=c0.clone();h.hdC=[loc[0]-REST.nodes[7][0],loc[1]-REST.nodes[7][1],loc[2]];h.hpC=hpC;
}
function mapKeys(ch,key,fn){const out={};for(const n in ch)out[n]=ch[n];
  for(const nm of ['hd','hp'])out[nm]=ch[nm].map(k=>{const v=k[1];return v&&v[key]!==undefined?[k[0],fn(nm,v[key]),k[2]]:k;});return out;}
function build(ver){
  ver.feetSpec=FOOT_REST.map((p,i)=>({W:[[0,[p[0],p[1]]]],w:[[0,0]],B:[i>=2?.1:-.12,-.4,0]}));
  const h0=ver.hits[0],c0=V(...ver.prey.c0);
  const raw=ver.ch,neutral=ch=>mapKeys(ch,'D',nm=>nm==='hd'?[0,0,0]:0);
  ver.ch=neutral(raw);solveHit(ver,h0,c0);
  const solved=(h)=>(nm,v)=>nm==='hd'?v.map((x,j)=>x+h.hdC[j]):v+h.hpC;
  let ch1=mapKeys(raw,'C',solved(h0));ver.ch=neutral(ch1);
  if(ver.hits[1]){
    const S1=simPrey(ver,1),s=S1[ver.hits[1].tc];
    solveHit(ver,ver.hits[1],V(s.x,s.y,s.z));
    ver.ch=mapKeys(ch1,'D',solved(ver.hits[1]));
  }else ver.ch=ch1;
  ver.contact=h0.contact;ver.hdC=h0.hdC;
  ver.preyS=simPrey(ver,ver.hits.length);
  return ver;
}
function tipAt(ver,a){return skeleton(poseAt(ver,a)).tip;}
// ---------------------------------------------------------------- prey simulation, 1 ms steps in animation time
function simPrey(ver,nh){
  const pr=ver.prey,c0=V(...pr.c0),N=ver.end+1,S=new Array(N),H=ver.hits.slice(0,nh);
  for(const h of H){const tv=tipAt(ver,h.tc).clone().sub(tipAt(ver,h.tc-12)).multiplyScalar(1/.012),hd=V(tv.x,0,tv.z);if(hd.length()<1e-4)hd.set(1,0,0);hd.normalize();h.hitDir=hd;h.tipSpeed=tv.length();}
  const st=(o)=>Object.assign({x:c0.x,y:c0.y,z:c0.z,yaw:0,pitch:0,roll:0,sx:1,sy:1,sz:1,held:false,f:0},o);
  const base=[c0.clone()];
  for(let a=0;a<N;a++){
    let k=-1;for(let j=0;j<H.length;j++)if(a>H[j].tc)k=j;
    if(k>=1&&!base[k]){const q=S[H[k].tc];base[k]=V(q.x,q.y,q.z);}
    let tilt=0,yaw=0,f=0,x=c0.x,y=c0.y,z=c0.z;
    for(let j=0;j<H.length;j++){const h=H[j];if(a<h.tc)break;
      const tau=(a-h.tc)/1000,t2=Math.max(0,a-h.slideAt)/1000;
      f+=Math.exp(-tau/.09)*Math.cos(2*Math.PI*tau/.17)*(h.amp/(H[0].amp||.2));
      tilt+=a<h.slideAt?h.tilt*(a-h.tc)/Math.max(1,h.slideAt-h.tc):h.tilt*Math.exp(-t2/.14);
      yaw+=.18*(a<h.slideAt?0:Math.exp(-t2/.2))*(h.hitDir.z>=0?-1:1);
      if(j===k||(k<0&&j===0)){const d=h.v0/h.mu*(1-Math.exp(-h.mu*t2)),b=base[j]||c0;
        x=b.x+h.hitDir.x*d;z=b.z+h.hitDir.z*d;y=c0.y+h.hop*Math.sin(Math.PI*Math.min(t2/.22,1));}
    }
    const amp=H[0].amp;
    S[a]=st({x,y,z,pitch:tilt,sx:1-amp*f,sy:1+.5*amp*f,sz:1+.5*amp*f,yaw,f});
    if(a===H[0].tc&&H[1]){/* base for hit 2 is taken at its own tc */}
  }
  return S;
}
VERSIONS.forEach(v=>{prep(v);build(v);});
// ---------------------------------------------------------------- real <-> animation time (each hit-pause freezes the animation)
function realToAnim(ver,tr){let sub=0;for(const h of ver.hits){const s=h.tc+sub;if(tr<s)return tr-sub;if(tr<s+h.pause)return h.tc;sub+=h.pause;}return tr-sub;}
function realLen(ver){return ver.end+ver.hits.reduce((s,h)=>s+h.pause,0);}
// ---------------------------------------------------------------- self check
function allPoints(sk){
  const pts=[];sk.nodes.forEach((n,i)=>{if(i<7)pts.push([n.y-REST.nodes[i][2]*.9,'body'+i]);});
  sk.knees.forEach((k,i)=>pts.push([k.y-.02,'knee'+i]));sk.feet.forEach((f,i)=>pts.push([f.y-.03,'foot'+i]));
  pts.push([sk.tip.y,'beak'],[sk.head.y-REST.hr*.9,'head']);return pts;
}
function check(){
  const fails=[],rows=[];
  for(const ver of VERSIONS){
    const r={id:ver.id,name:ver.name,hits:[]};
    // prey state must exist and be finite for every integer animation ms (free-play lesson from round 1)
    let bad=0;if(ver.preyS.length<ver.end+1)bad++;for(const s of ver.preyS)for(const k in s){if(typeof s[k]==='number'&&!isFinite(s[k]))bad++;}
    if(bad)fails.push(`${ver.id}: prey state missing or non-finite (${bad})`);
    ver.hits.forEach((h,k)=>{
      const sk=skeleton(poseAt(ver,h.tc)),S=ver.preyS[h.tc],c=V(S.x,S.y,S.z),q={};
      q.contactDist=sk.tip.distanceTo(c)-PREY.R;if(Math.abs(q.contactDist)>.03)fails.push(`${ver.id} hit ${k+1}: beak tip ${q.contactDist.toFixed(3)} m from hitbox`);
      q.reachErr=Math.max(sk.neckErr,sk.legErr);if(q.reachErr>.003)fails.push(`${ver.id} hit ${k+1}: neck/leg reach error ${q.reachErr.toFixed(3)} m at contact`);
      const a1=realToAnim(ver,hitReal(ver,k)+1),a2=realToAnim(ver,hitReal(ver,k)+h.pause-1),sk2=skeleton(poseAt(ver,a2));
      q.pause=h.pause;q.pauseDrift=sk.tip.distanceTo(sk2.tip);
      if(h.pause<60||h.pause>90||a1!==a2||q.pauseDrift>1e-6)fails.push(`${ver.id} hit ${k+1}: hit-pause ${h.pause} ms not a clean freeze`);
      const nxt=ver.hits[k+1]?ver.hits[k+1].tc:ver.end,e=Math.min(nxt,h.slideAt+250,ver.end),s0=ver.preyS[Math.min(h.slideAt,ver.end)],s1=ver.preyS[e];
      const dx=s1.x-s0.x,dz=s1.z-s0.z,dl=Math.hypot(dx,dz);q.knockCos=dl<1e-6?0:(dx*h.hitDir.x+dz*h.hitDir.z)/dl;q.knock=dl;q.tipSpeed=h.tipSpeed;
      if(q.knockCos<.9||dl<.01)fails.push(`${ver.id} hit ${k+1}: knockback cos ${q.knockCos.toFixed(2)} dist ${dl.toFixed(3)}`);
      // front leg lean at contact (degrees from vertical), neck stretch
      q.foreLean=Math.max(...[2,3].map(i=>Math.atan2(Math.hypot(sk.feet[i].x-sk.hips[i].x,sk.feet[i].z-sk.hips[i].z),sk.hips[i].y-sk.feet[i].y)*180/Math.PI));
      q.neckStretch=sk.stretch;
      r.hits.push(q);
    });
    let drift=0,minY=9,maxReach=0,maxStr=0,vmax=0,prevTip=null,hindMove=0,maxLean=0;
    for(let a=0;a<=ver.end;a+=2){
      const P=poseAt(ver,a),k=skeleton(P);maxReach=Math.max(maxReach,k.legErr,k.neckErr);maxStr=Math.max(maxStr,k.stretch);
      for(const [y] of allPoints(k)){if(y<minY)minY=y;}
      hindMove=Math.max(hindMove,Math.abs(P.fxH));
      for(let i=0;i<4;i++){const f=ver.feetSpec[i],w=P.feet[i].w;
        const fxk=i>=2?'fxF':'fxH',dfx=Math.abs(chanAt(ver,fxk,Math.max(0,a-1))-chanAt(ver,fxk,a+1));
        const planted=w<1e-4&&dfx<1e-6&&interp(f.w,Math.max(0,a-8))<1e-4&&interp(f.w,a+8)<1e-4;
        if(planted){const t=V(P.feet[i].W[0],REST.footY,P.feet[i].W[1]);drift=Math.max(drift,k.feet[i].distanceTo(t));}}
      if(prevTip)vmax=Math.max(vmax,k.tip.distanceTo(prevTip)/.002);prevTip=k.tip;
    }
    r.feetDrift=drift;r.minY=minY;r.maxReach=maxReach;r.maxStretch=maxStr;r.tipSpeed=vmax;r.hindSlide=hindMove;
    if(drift>.02)fails.push(`${ver.id}: planted foot drift ${(drift*100).toFixed(1)} cm`);
    if(minY<-.01)fails.push(`${ver.id}: geometry ${(minY*100).toFixed(1)} cm below ground`);
    if(maxReach>.02)fails.push(`${ver.id}: IK stretched ${(maxReach*100).toFixed(1)} cm out of reach`);
    if(hindMove>1e-6)fails.push(`${ver.id}: hind feet must stay planted`);
    if(!ver.ref&&maxStr>1.0801)fails.push(`${ver.id}: neck stretch ${maxStr.toFixed(2)} above the 1.08 cap`);
    let preyMin=9;for(const s of ver.preyS)preyMin=Math.min(preyMin,s.y-.24*s.sy);r.preyMinY=preyMin;if(preyMin<-.01)fails.push(`${ver.id}: prey through ground ${preyMin.toFixed(3)}`);
    const tm={};for(const [n,a,b] of ver.phl)tm[n]=b-a;r.timing=tm;
    const strikes=ver.phl.filter(p=>/strike/.test(p[0])).map(p=>p[2]-p[1]);r.strikeMs=strikes;
    if(strikes.some(s=>s<80||s>150))fails.push(`${ver.id}: strike ${strikes} ms outside 80-150`);
    const hold=ver.phl.find(p=>p[0]==='hold');if(hold[2]-hold[1]<300||hold[2]-hold[1]>600)fails.push(`${ver.id}: hold ${hold[2]-hold[1]} ms outside 300-600`);
    if(ver.id==='chain'){const L=ver.end-ver.peckStart+ver.hits[1].pause;r.peckTotal=L;if(L>800)fails.push(`chain: peck follow-up ${L} ms above 800`);}
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.BITECORE={T,REST,VERSIONS,PREY,skeleton,poseAt,realToAnim,realLen,animToReal,hitReal,partsOf,check,FOOT_REST,interp,V,frames,DEF};
})(typeof window!=='undefined'?window:globalThis);
