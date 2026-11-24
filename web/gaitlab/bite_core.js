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
const DEF={bx:0,by:0,bz:0,yaw:0,pitch:0,roll:0,sp:0,hp:0,hyaw:0,hroll:0,gape:0,stretch:1,tailP:0,tailY:0};
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
// ---------------------------------------------------------------- versions
// Value placeholders in head keys: {C:[dx,dy,dz]} = contact head offset + extra; hp: {C:extra} = contact head pitch + extra.
const HOLD=(t,v)=>[t,v,'l'];
const R_FEET=FOOT_REST.map(p=>({W:[[0,p[0],p[1]]],w:[[0,0]],B:[0,-.4,0]}));
const VERSIONS=[
{ id:'peck',strip:[90,200,262,345,440,640],name:'Peck-snap',tag:'cocked neck, body stays tall, one fast head stab',
  tc:310,pause:70,end:780,ph:{ant:[0,200],str:[200,310],fol:[310,430],rec:[430,780]},
  prey:{c0:[1.03,.34,0],aC:.9,v0:1.0,mu:7,hop:.025,tilt:.30,amp:.14,kind:'knock'},
  ch:{
    bx:[[0,0],[200,-.035,'s'],[310,.06,'i2'],[380,.07,'o'],[560,.02,'s'],[780,0,'o']],
    by:[[0,0],[200,.025,'s'],[310,-.05,'i2'],[380,-.045,'o'],[560,0,'s'],[780,0,'o']],
    pitch:[[0,0],[200,-.07,'s'],[310,.12,'i2'],[380,.1,'o'],[600,.01,'s'],[780,0,'o']],
    sp:[[0,0],[200,-.05,'s'],[310,.08,'i2'],[430,.03,'s'],[780,0,'o']],
    hd:[[0,[0,0,0]],[200,[-.2,.1,0],'s'],[310,{C:[0,0,0]},'i2'],[370,{C:[-.06,.05,0]},'o'],[460,{C:[-.14,.04,0]},'s'],[540,{C:[-.1,.07,0]},'s'],[640,[-.03,.02,0],'s'],[780,[0,0,0],'o']],
    hp:[[0,0],[200,.4,'s'],[310,{C:0},'i2'],[370,{C:-.2},'o'],[780,0,'s']],
    gape:[[0,0],[215,0],[255,1,'o'],[292,1],[310,0,'i2'],[372,0],[395,.3,'o'],[440,0,'s'],[520,.0],[540,.25,'o'],[580,0,'s']],
    stretch:[[0,1]],
    tailP:[[0,0],[200,-.12,'s'],[310,.3,'i2'],[420,.22,'o'],[780,0,'s']]
  },
  feet:null,holds:{pre:[200,350],post:250}
},
{ id:'lunge',strip:[120,270,350,460,600,900],name:'Lunge-bite',tag:'whole body drives from the hind legs, front legs brace',
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
  feet:null,holds:{pre:[270,300],post:250}
},
{ id:'grab',strip:[110,240,370,545,1130,1400],name:'Grab-shake',tag:'bite and hold, shake the prey, throw it',
  tc:330,pause:80,end:1560,ph:{ant:[0,220],str:[220,330],fol:[330,1090],rec:[1090,1560]},
  prey:{c0:[1.14,.34,0],aC:.62,v0:0,mu:7,hop:0,tilt:0,amp:.08,kind:'grab',hold:[330,1010],release:1010},
  ch:{ // shake: right, left, right, left, right (5 half-swings of 120 ms)
    bx:[[0,0],[220,-.05,'s'],[330,.2,'i2'],[400,.17,'o'],[1000,.17],[1050,.0,'o'],[1560,0,'s']],
    by:[[0,0],[220,-.14,'s'],[330,-.12,'i2'],[1000,-.12],[1050,-.0,'o'],[1560,0,'s']],
    pitch:[[0,0],[220,-.02,'s'],[330,.22,'i2'],[1000,.2],[1050,.04,'o'],[1560,0,'s']],
    yaw:[[0,0],[330,0],[410,.1,'s'],[530,-.1,'s'],[650,.1,'s'],[770,-.1,'s'],[890,.1,'s'],[1000,0,'s']],
    roll:[[0,0],[330,0],[410,-.06,'s'],[530,.06,'s'],[650,-.06,'s'],[770,.06,'s'],[890,-.06,'s'],[1000,0,'s']],
    bz:[[0,0],[330,0],[410,.03,'s'],[530,-.03,'s'],[650,.03,'s'],[770,-.03,'s'],[890,.03,'s'],[1000,0,'s']],
    sp:[[0,0],[220,.06,'s'],[330,.02,'i2'],[1000,.02],[1090,0,'s']],
    hd:[[0,[0,0,0]],[220,[-.14,-.2,0],'s'],[330,{C:[0,0,0]},'i2'],[410,{C:[-.04,.0,.2]},'s'],[530,{C:[-.04,.0,-.2]},'s'],[650,{C:[-.04,.0,.2]},'s'],[770,{C:[-.04,.0,-.2]},'s'],[890,{C:[-.04,.0,.2]},'s'],[1010,{C:[0,.02,0]},'s'],
        [1060,[.02,.12,0],'o'],[1560,[0,0,0],'s']],
    hp:[[0,0],[220,.1,'s'],[330,{C:0},'i2'],[1010,{C:0}],[1060,-.35,'o'],[1560,0,'s']],
    hyaw:[[0,0],[330,0],[410,.6,'s'],[530,-.6,'s'],[650,.6,'s'],[770,-.6,'s'],[890,.6,'s'],[1010,0,'s']],
    hroll:[[0,0],[330,0],[410,-.3,'s'],[530,.3,'s'],[650,-.3,'s'],[770,.3,'s'],[890,-.3,'s'],[1010,0,'s']],
    gape:[[0,0],[170,.3,'s'],[255,1,'o'],[315,1],[330,0,'i2'],[1010,0],[1030,1,'o'],[1130,.3,'s'],[1200,0,'s']],
    stretch:[[0,1],[220,.9,'s'],[330,1.1,'i2'],[430,1.02,'o']],
    tailP:[[0,0],[220,-.05,'s'],[330,.25,'i2'],[1100,.2],[1560,0,'s']],
    tailY:[[0,0],[330,0],[410,-.5,'s'],[530,.5,'s'],[650,-.5,'s'],[770,.5,'s'],[890,-.5,'s'],[1010,0,'s']]
  },
  feet:null,holds:{pre:[220,350],post:0}
},
{ id:'pounce',strip:[150,250,370,540,680,930],name:'Hop-pounce bite',tag:'small hop, beak first, bite on the landing',
  tc:500,pause:80,end:1120,ph:{ant:[0,250],str:[250,500],fol:[500,680],rec:[680,1120]},
  prey:{c0:[1.46,.34,0],aC:.78,v0:.5,mu:8,hop:.02,tilt:.12,amp:.1,kind:'knock',press:.3},
  ch:{
    bx:[[0,0],[250,-.04,'s'],[290,-.04],[470,.46,'s'],[540,.5,'o'],[700,.5],[760,.5],[940,0,'s']],
    by:[[0,0],[250,-.2,'s'],[300,.06,'o'],[370,.2,'o2'],[440,.08,'i2'],[470,-.05,'i2'],[520,-.19,'o'],[600,-.12,'s'],[700,-.01,'s'],[780,.04,'o'],[860,0,'i2'],[940,-.02],[1000,0,'s']],
    pitch:[[0,0],[250,.1,'s'],[330,.2,'s'],[440,.5,'s'],[500,.3,'o'],[620,.06,'s'],[780,0,'o']],
    sp:[[0,0],[250,.12,'s'],[330,-.1,'o'],[440,.0],[500,.06,'o'],[700,0,'s']],
    hd:[[0,[0,0,0]],[250,[-.12,-.3,0],'s'],[330,[.0,-.02,0],'o'],[440,[-.02,-.02,0],'s'],[500,{C:[0,0,0]},'i2'],[580,{C:[-.04,.03,0]},'o'],[700,[-.06,.0,0],'s'],[1120,[0,0,0],'s']],
    hp:[[0,0],[250,.1,'s'],[440,.3,'s'],[500,{C:0},'i2'],[580,{C:-.1},'o'],[1120,0,'s']],
    gape:[[0,0],[250,.3,'s'],[400,1,'o'],[485,1],[500,0,'i2'],[580,0],[620,.3,'o'],[680,0,'s']],
    stretch:[[0,1],[250,.9,'s'],[440,1.05,'s'],[500,1.14,'i2'],[600,1,'o']],
    tailP:[[0,0],[250,.1,'s'],[370,.5,'o'],[500,.1,'s'],[700,0,'s']]
  },
  feet:'pounce',holds:{pre:[250,350],post:250},warp:[[0,0],[250,250],[500,420]]
}];

function shiftKeys(keys,at,dur){
  keys=keys.slice();let ex=keys.find(k=>k[0]===at),v;
  if(ex)v=ex[1];else{v=interp(keys,at);keys.push([at,v,'s']);keys.sort((p,q)=>p[0]-q[0]);}
  const out=keys.map(k=>k[0]>at?[k[0]+dur,k[1],k[2]]:k);out.push([at+dur,v,'l']);out.sort((p,q)=>p[0]-q[0]);return out;
}
function warpT(t,K){let i=0;while(i<K.length-1&&t>K[i+1][0])i++;if(i>=K.length-1){const l=K[K.length-1];return l[1]+(t-l[0]);}const a=K[i],b=K[i+1];return a[1]+(t-a[0])*(b[1]-a[1])/(b[0]-a[0]);}
function prep(ver){
  if(ver.warp){const w=t=>warpT(t,ver.warp);for(const k in ver.ch)ver.ch[k]=ver.ch[k].map(q=>[w(q[0]),q[1],q[2]]);ver.tc=w(ver.tc);ver.end=w(ver.end);for(const k in ver.ph)ver.ph[k]=ver.ph[k].map(w);}
  const ph=ver.ph,pr=ver.prey;
  const [at,dur]=ver.holds.pre;const sh=t=>t>at?t+dur:t;
  for(const k in ver.ch)ver.ch[k]=shiftKeys(ver.ch[k],at,dur);
  ver.tc=sh(ver.tc);ver.end+=dur;ph.hold=[at,at+dur];ph.str=[at+dur,sh(ph.str[1])];ph.fol=ph.fol.map(sh);ph.rec=ph.rec.map(sh);
  if(pr.hold)pr.hold=pr.hold.map(sh);if(pr.release)pr.release=sh(pr.release);
  const H=ver.holds.post;pr.slideAt=ver.tc;
  if(H){const tc=ver.tc,s2=t=>t>tc?t+H:t;
    for(const k in ver.ch)ver.ch[k]=shiftKeys(ver.ch[k],tc,H);
    ver.end+=H;ph.cling=[tc,tc+H];ph.fol=[tc+H,s2(ph.fol[1])];ph.rec=ph.rec.map(s2);pr.slideAt=tc+H;}
  const rl=a=>a<=ver.tc?a:a+ver.pause,mid=p=>(p[0]+p[1])/2;
  if(ver.id==='grab')ver.strip=[mid(ph.hold),mid(ph.str),ver.tc+ver.pause/2,rl(ver.tc+(pr.release-ver.tc)*.42),rl(pr.release+140),rl(mid(ph.rec))];
  else ver.strip=[mid(ph.ant),mid(ph.hold),mid(ph.str),ver.tc+ver.pause/2,rl(ph.cling?ph.cling[1]+(ph.fol[1]-ph.fol[0])*.5:mid(ph.fol)),rl(mid(ph.rec))].map(Math.round);
  ver.strip=ver.strip.map(Math.round);
}
// ---------------------------------------------------------------- build: resolve contact placeholders, feet, prey
const PREY={R:.27,dirLocal:[-.62,.78]};
function chanAt(ver,name,a){
  const k=ver.ch[name];if(!k)return name==='hd'?[0,0,0]:DEF[name];
  return interp(k,a);
}
function feetAt(ver,a){
  const out=[];
  for(let i=0;i<4;i++){const f=ver.feetSpec[i];out.push({W:interp(f.W.map(k=>[k[0],k[1],'l']),a),w:interp(f.w,a),B:f.B});}
  return out;
}
function poseAt(ver,a,noHead){
  const P={};for(const n in DEF)P[n]=chanAt(ver,n,a);
  P.hd=noHead?[0,0,0]:chanAt(ver,'hd',a);P.feet=feetAt(ver,a);return P;
}
function build(ver){
  // feet
  ver.feetSpec=FOOT_REST.map((p,i)=>({W:[[0,[p[0],p[1]]]],w:[[0,0]],B:[i>=2?.1:-.12,-.4,0]}));
  if(ver.feet==='pounce'){
    const L=.5,D=ver.tc-ver.ph.str[0],ls=ver.ph.str[0],r0=ver.ph.rec[0];
    ver.feetSpec.forEach((f,i)=>{const p=FOOT_REST[i],lead=i>=2?0:.08*D;
      f.w=[[0,0],[ls,0],[ls+.25*D,1,'s'],[ver.tc-.45*D,1,'l'],[ver.tc-.1*D+lead,0,'o'],[r0+90,0],[r0+130,1,'s'],[r0+220,1],[r0+250,0,'o']];
      f.B=i>=2?[.13,-.43,0]:[-.1,-.42,0];
      f.W=[[0,[p[0],p[1]]],[ls+.3*D,[p[0],p[1]]],[ls+.3*D+1,[p[0]+L,p[1]]],[r0+160,[p[0]+L,p[1]]],[r0+161,[p[0],p[1]]]];
    });
  }
  // contact solve (head at the contact frame)
  const pr=ver.prey,c0=V(...pr.c0),T0=c0.clone().add(V(PREY.dirLocal[0],PREY.dirLocal[1],0).multiplyScalar(PREY.R-.006));
  ver.contact=T0;const P=poseAt(ver,ver.tc,true),F=frames(P);
  // body orientation fixed at tc (hyaw=0 in all versions at tc), head pitch relative to the front frame
  const total=pr.aC,hpC=total-P.pitch-P.sp;
  const Qh=F.Qf.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,-hpC)),axis=X.clone().applyQuaternion(Qh);
  const Hw=T0.clone().addScaledVector(axis,-REST.beak),loc=toLocal(Hw,'f',P,F);
  ver.hdC=[loc[0]-REST.nodes[7][0],loc[1]-REST.nodes[7][1],loc[2]];ver.hpC=hpC;
  for(const key of ['hd','hp']){ver.ch[key]=ver.ch[key].map(k=>{
    const v=k[1];if(v&&v.C!==undefined){return [k[0],key==='hd'?v.C.map((x,j)=>x+ver.hdC[j]):v.C+ver.hpC,k[2]];}return k;});}
  simPrey(ver);
  return ver;
}
function tipAt(ver,a){return skeleton(poseAt(ver,a)).tip;}
// ---------------------------------------------------------------- prey simulation, 1 ms steps in animation time
function simPrey(ver){
  const pr=ver.prey,c0=V(...pr.c0),N=ver.end+1,S=new Array(N),tc=ver.tc;
  const tv=tipAt(ver,tc).clone().sub(tipAt(ver,tc-12)).multiplyScalar(1/.012);
  const hd=V(tv.x,0,tv.z);if(hd.length()<1e-4)hd.set(1,0,0);hd.normalize();ver.hitDir=hd;ver.tipSpeed=tv.length();
  const st=(o)=>Object.assign({x:c0.x,y:c0.y,z:c0.z,yaw:0,pitch:0,roll:0,sx:1,sy:1,sz:1,held:false,f:0},o);
  if(pr.kind==='knock'){
    const sa=pr.slideAt;
    for(let a=0;a<N;a++){
      const tau=Math.max(0,a-tc)/1000,t2=Math.max(0,a-sa)/1000,d=pr.v0/pr.mu*(1-Math.exp(-pr.mu*t2));
      const f=tau>0?Math.exp(-tau/.09)*Math.cos(2*Math.PI*tau/.17):0;
      const press=pr.press||0,g=a<tc?0:a<sa?Math.min(1,(a-tc)/50):Math.exp(-t2/.22)*(.6+.4*Math.cos(2*Math.PI*t2/.3));
      const tilt=a<tc?0:a<sa?pr.tilt*(a-tc)/Math.max(1,sa-tc):pr.tilt*Math.exp(-t2/.14);
      S[a]=st({x:c0.x+hd.x*d,z:c0.z+hd.z*d,y:c0.y+(press?-press*.24*g:pr.hop*Math.sin(Math.PI*Math.min(t2/.22,1))),
        pitch:tilt,sx:press?1+.12*pr.amp/.1*g:1-pr.amp*f,sy:press?1-press*g:1+.5*pr.amp*f,sz:press?1+.12*g:1+.5*pr.amp*f,
        yaw:.18*(a<sa?0:Math.exp(-t2/.2))*(hd.z>=0?-1:1),f});
    }
  }else{ // held in the beak, then thrown
    const [h0,h1]=pr.hold;const sk0=skeleton(poseAt(ver,tc)),qh0=sk0.Qh.clone().invert();
    const off=c0.clone().sub(sk0.tip).applyQuaternion(qh0);const yaw0=Math.atan2(-sk0.axis.z,sk0.axis.x);
    let vel=null,p=null,tl=0;
    for(let a=0;a<N;a++){
      if(a<h0)S[a]=st({});
      else if(a<=h1){
        const sk=skeleton(poseAt(ver,a)),pos=off.clone().applyQuaternion(sk.Qh).add(sk.tip);
        const yaw=Math.atan2(-sk.axis.z,sk.axis.x)-yaw0;
        const tau=(a-tc)/1000,f=Math.exp(-tau/.09)*Math.cos(2*Math.PI*tau/.17);
        S[a]=st({x:pos.x,z:pos.z,y:Math.max(pos.y,c0.y),yaw:yaw*.9,roll:clamp(pos.z/.2,-1,1)*.35,pitch:.1,sx:1-pr.amp*f,sy:1+.5*pr.amp*f,sz:1+.5*pr.amp*f,held:true,f});
        if(a===h1){const q=skeleton(poseAt(ver,a-8)),vv=pos.clone().sub(off.clone().applyQuaternion(q.Qh).add(q.tip)).multiplyScalar(1/.008);
          p=V(pos.x,Math.max(pos.y,c0.y),pos.z);vel=V(1.5,1.55,vv.z*.4);tl=0;}
      }else{
        // free flight with one bounce, then slide
        const dt=.001;tl+=dt;vel.y-=9.81*dt;p.addScaledVector(vel,dt);
        let land=0;
        if(p.y<c0.y){p.y=c0.y;if(vel.y<-.8){vel.y*=-.22;land=1;}else vel.y=0;vel.x*=.985;vel.z*=.985;}
        if(p.y<=c0.y+.001)vel.x*=Math.exp(-7*dt),vel.z*=Math.exp(-7*dt);
        const air=p.y>c0.y+.004;const sq=(S[a-1]&&S[a-1].land)?S[a-1].land*.9:0;
        S[a]=st({x:p.x,y:p.y,z:p.z,yaw:S[a-1].yaw,pitch:air?Math.min(.6,tl*2.4):S[a-1].pitch*.97,roll:S[a-1].roll*.98,held:false});
        S[a].land=land?1:Math.max(0,((S[a-1]&&S[a-1].land)||0)*.985-.005);
        const k=S[a].land;S[a].sy=1-.22*k;S[a].sx=S[a].sz=1+.12*k;
      }
    }
  }
  ver.preyS=S;
}
// ---------------------------------------------------------------- real <-> animation time (hit-pause freezes the animation)
function realToAnim(ver,tr){if(tr<ver.tc)return tr;if(tr<ver.tc+ver.pause)return ver.tc;return tr-ver.pause;}
function realLen(ver){return ver.end+ver.pause;}
VERSIONS.forEach(v=>{prep(v);build(v);});
// ---------------------------------------------------------------- self check
function allPoints(sk){
  const pts=[];sk.nodes.forEach((n,i)=>{if(i<7)pts.push([n.y-REST.nodes[i][2]*.9,'body'+i]);});
  sk.knees.forEach((k,i)=>pts.push([k.y-.02,'knee'+i]));sk.feet.forEach((f,i)=>pts.push([f.y-.03,'foot'+i]));
  pts.push([sk.tip.y,'beak'],[sk.head.y-REST.hr*.9,'head']);return pts;
}
function check(){
  const fails=[],rows=[];
  for(const ver of VERSIONS){
    const r={id:ver.id,name:ver.name};
    // 1. contact distance: closed beak tip to the prey hitbox surface at the contact frame
    const sk=skeleton(poseAt(ver,ver.tc)),S=ver.preyS[ver.tc],c=V(S.x,S.y,S.z);
    r.contactDist=sk.tip.distanceTo(c)-PREY.R;if(Math.abs(r.contactDist)>.03)fails.push(`${ver.id}: beak tip ${r.contactDist.toFixed(3)} m from hitbox`);
    r.reachErr=Math.max(sk.neckErr,sk.legErr);if(r.reachErr>.003)fails.push(`${ver.id}: neck/leg reach error ${r.reachErr.toFixed(3)} m at contact`);
    // 2. hit-pause
    const a1=realToAnim(ver,ver.tc+1),a2=realToAnim(ver,ver.tc+ver.pause-1),sk2=skeleton(poseAt(ver,a2));
    r.pause=ver.pause;r.pauseDrift=sk.tip.distanceTo(sk2.tip);
    if(ver.pause<60||ver.pause>90||a1!==a2||r.pauseDrift>1e-6)fails.push(`${ver.id}: hit-pause ${ver.pause} ms not a clean freeze`);
    // 3. feet planted, nothing through the ground, reach, beak speed, neck stretch
    let drift=0,minY=9,maxReach=0,maxStr=0,vmax=0,prevTip=null;
    for(let a=0;a<=ver.end;a+=2){
      const P=poseAt(ver,a),k=skeleton(P);maxReach=Math.max(maxReach,k.legErr,k.neckErr);maxStr=Math.max(maxStr,k.stretch);
      for(const [y,n] of allPoints(k)){if(y<minY)minY=y;}
      for(let i=0;i<4;i++){const f=ver.feetSpec[i],w=P.feet[i].w;
        const Wa=interp(f.W.map(q=>[q[0],q[1],'l']),Math.max(0,a-1)),Wb=interp(f.W.map(q=>[q[0],q[1],'l']),a+1);
        const planted=w<1e-4&&Math.hypot(Wa[0]-Wb[0],Wa[1]-Wb[1])<1e-6&&interp(f.w,Math.max(0,a-8))<1e-4&&interp(f.w,a+8)<1e-4;
        if(planted){const t=V(P.feet[i].W[0],REST.footY,P.feet[i].W[1]);drift=Math.max(drift,k.feet[i].distanceTo(t));}}
      if(prevTip)vmax=Math.max(vmax,k.tip.distanceTo(prevTip)/.002);prevTip=k.tip;
    }
    r.feetDrift=drift;r.minY=minY;r.maxReach=maxReach;r.maxStretch=maxStr;r.tipSpeed=vmax;
    if(drift>.02)fails.push(`${ver.id}: planted foot drift ${(drift*100).toFixed(1)} cm`);
    if(minY<-.01)fails.push(`${ver.id}: geometry ${(minY*100).toFixed(1)} cm below ground`);
    if(maxReach>.02)fails.push(`${ver.id}: IK stretched ${(maxReach*100).toFixed(1)} cm out of reach`);
    // 4. knockback direction = hit direction (horizontal), prey stays above ground
    const q=ver.preyS[Math.min(ver.end,ver.prey.slideAt+250)],dx=q.x-ver.prey.c0[0],dz=q.z-ver.prey.c0[2],dl=Math.hypot(dx,dz);
    r.knockCos=ver.prey.kind==='grab'?1:(dl<1e-6?0:(dx*ver.hitDir.x+dz*ver.hitDir.z)/dl);r.knock=dl;
    if(ver.prey.kind==='knock'&&(r.knockCos<.9||dl<.02))fails.push(`${ver.id}: knockback cos ${r.knockCos.toFixed(2)} dist ${dl.toFixed(3)}`);
    let preyMin=9;for(const s of ver.preyS)preyMin=Math.min(preyMin,s.y-.24*s.sy);r.preyMinY=preyMin;if(preyMin<-.01)fails.push(`${ver.id}: prey through ground ${preyMin.toFixed(3)}`);
    const L=ver.ph;const d=p=>p?p[1]-p[0]:0;r.timing={antic:d(L.ant),hold:d(L.hold),strike:d(L.str),pause:ver.pause,cling:d(L.cling),follow:d(L.fol),recovery:d(L.rec)};if(r.timing.strike<80||r.timing.strike>150&&ver.id!=='pounce')fails.push(`${ver.id}: strike ${r.timing.strike} ms outside 80-150`);if(r.timing.hold<300||r.timing.hold>600)fails.push(`${ver.id}: hold ${r.timing.hold} ms outside 300-600`);
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.BITECORE={T,REST,VERSIONS,PREY,skeleton,poseAt,realToAnim,realLen,check,FOOT_REST,interp,V,frames,DEF};
})(typeof window!=='undefined'?window:globalThis);
