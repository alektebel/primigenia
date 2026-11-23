'use strict';
// Primigenia roar lab core (A60/A61 step 3, control move): starter B (no arms, beak "pico", crest "cresta"). Pure maths, no DOM.
// Needs bite2_core.js and pounce_core.js first (body rig, IK, foot segments). Units: metres, +x forward, +y up, +z creature's right (towards the game camera).
// Game numbers (core/src/combat.c, 10 ticks per second): roar = 6 ticks wind-up (0.6 s), 1 active tick (0.1 s), 6 recovery (0.6 s), range 4 m, full circle
// (CB_F_SWEEP, arc 2 pi), fear status 12 ticks (1.2 s), role control, part throat. A roar INTERRUPTs a charge in its wind-up (CB_CHARGE row).
// Times: B channels run on the animation clock `a` (ms); everything else (rings, dummies, camera) on real time tr = a + ver.pre.
(function(root){
const PC=root.POUNCECORE,B=root.BITECORE,T=B.T,REST=B.REST,interp=B.interp,V=B.V,DEF=B.DEF,FOOT_REST=B.FOOT_REST;
const skel=PC.skel;
const clamp=(x,a,b)=>x<a?a:x>b?b:x,sm=u=>{u=clamp(u,0,1);return u*u*(3-2*u);};
const RANGE=4.0,FEAR_MS=1200,P0=V(...REST.P0),CX=P0.x; // ring centre x = body centre
const EXTRA={chest:0,thr:0,crest:0};
// ---------------------------------------------------------------- foot segments (same shape as the pounce lab)
function FB(i){this.i=i;this.cur=[FOOT_REST[i][0],FOOT_REST[i][1]];this.t=0;this.segs=[];}
FB.prototype={
  hold(t){if(t>this.t){this.segs.push({k:'p',t0:this.t,t1:t,x:this.cur[0],z:this.cur[1]});this.t=t;}return this;},
  step(t0,t1,x,z,h){this.hold(t0);this.segs.push({k:'s',t0,t1,x0:this.cur[0],z0:this.cur[1],x1:x,z1:z,h});this.cur=[x,z];this.t=t1;return this;},
  air(t0,t1,Bk,x,z,inn,out){this.hold(t0);this.segs.push({k:'a',t0,t1,x0:this.cur[0],z0:this.cur[1],x1:x,z1:z,B:Bk,in:inn,out,fx:.6});this.cur=[x,z];this.t=t1;return this;},
  end(t){this.hold(t);return this.segs;}
};
function wig(t0,t1,amp,hz,ramp,base,ph){const o=[],n=Math.max(2,Math.round((t1-t0)/8));for(let k=0;k<=n;k++){const t=t0+(t1-t0)*k/n,e=Math.min(1,(t-t0)/ramp,(t1-t)/ramp);o.push([t,(base||0)+amp*e*Math.sin(2*Math.PI*hz*(t-t0)/1000+(ph||0)),'l']);}return o;}
function cat(...ls){const o=[];for(const l of ls)for(const k of l)o.push(k);o.sort((a,b)=>a[0]-b[0]);return o;}
// add a keyed base curve and a wiggle (both evaluated at every key time of either) so a held value can carry a tremor
function plus(base,w){const ts=new Set();base.forEach(k=>ts.add(k[0]));w.forEach(k=>ts.add(k[0]));const o=[];[...ts].sort((a,b)=>a-b).forEach(t=>o.push([t,interp(base,t)+(interp(w,t)-0),'l']));return o;}
const rotXZ=(x,z,phi)=>[CX+(x-CX)*Math.cos(phi)+z*Math.sin(phi),-(x-CX)*Math.sin(phi)+z*Math.cos(phi)];
// ---------------------------------------------------------------- pose
function bodyPose(ver,a){
  const P={};for(const n in DEF)P[n]=ver.ch[n]?interp(ver.ch[n],a):DEF[n];for(const n in EXTRA)P[n]=ver.ch[n]?interp(ver.ch[n],a):0;
  P.hd=ver.ch.hd?interp(ver.ch.hd,a):[0,0,0];
  for(const r of ver.arcs)if(a>=r.t0&&a<=r.t1){const tau=(a-r.t0)/1000,Ts=(r.t1-r.t0)/1000,vy=(r.y1-r.y0)/Ts+9.81*Ts/2;P.by=r.y0+vy*tau-.5*9.81*tau*tau;P.bx=r.x0+(r.x1-r.x0)*(a-r.t0)/(r.t1-r.t0);}
  P.a=a;return P;
}
function poseAt(ver,a){
  const P=bodyPose(ver,a);
  if(!ver.arcs.some(r=>a>=r.t0&&a<=r.t1)){const sk=skel(ver,P,false);let lo=9;sk.nodes.forEach((n,i)=>{if(i<7)lo=Math.min(lo,n.y-REST.nodes[i][2]*.9);});if(lo<.012)P.by+=.012-lo;}
  return P;
}
function skelAtReal(ver,tr){const a=tr-ver.pre,P=poseAt(ver,a);return {P,sk:skel(ver,P,true)};}
// ---------------------------------------------------------------- sound ring (a visual of the game's instant full-circle area, range 4 m)
function ringR(rg,tr){const u=(tr-rg.t)/rg.dur;if(u<=0)return 0;if(u>=1)return RANGE;return RANGE*(1-Math.pow(1-u,2.2));}
function ringInv(rg,d){const x=clamp(d/RANGE,0,1);return rg.t+rg.dur*(1-Math.pow(1-x,1/2.2));}
// ---------------------------------------------------------------- dummies (pure function of real time through a 5 ms precomputed path)
const DT=5,CHG={Vc:5.0,ramp:350,lead:700};
function Iv(s){s=Math.max(0,s);const r=CHG.ramp;if(s<=r){const x=s/r;return CHG.Vc*r*(x*x*x-x*x*x*x/2)/1000;}return CHG.Vc*(r*.5+(s-r))/1000;}
function vOf(s){return s<=0?0:CHG.Vc*sm(s/CHG.ramp);}
function layoutOf(ver){
  const L=[
    {id:'charger',kind:'charge',r:3.0,ang:.3,big:1.3},
    {id:'near',kind:'timid',r:2.9,ang:1.45,big:1},
    {id:'back',kind:'timid',r:3.3,ang:-2.15,big:1},
    {id:'far',kind:'idle',r:5.0,ang:-.9,big:1}];
  return L.map(d=>Object.assign({},d,{ang:d.ang+(ver.lay||0)}));
}
function simDummies(ver){
  const lay=layoutOf(ver),end=ver.endReal,n=Math.ceil(end/DT)+1,rg0=ver.rings[0],Cx=ver.C[0],Cz=ver.C[1];
  const out=[];
  for(const d of lay){
    const o={id:d.id,kind:d.kind,r:d.r,ang:d.ang,big:d.big,S:new Array(n),tHit:null,dist0:d.r};
    const bx=d.r*Math.cos(d.ang),bz=d.r*Math.sin(d.ang);
    if(d.kind==='charge'){
      const Ta=ver.chargeAnchor;o.Ta=Ta;const ux=Math.cos(d.ang),uz=Math.sin(d.ang);
      const tS=Math.max(0,Ta-CHG.lead),dist=t=>d.r+(Iv(Ta-tS)-Iv(t-tS)),vOfT=t=>vOf(t-tS);o.tStart=tS;// distance from the ring centre, before it is hit
      // first t where the ring front reaches the charger
      for(let t=0;t<end;t+=1){let hit=false;for(const rg of ver.rings.slice(0,1))if(ringR(rg,t)>=dist(t)&&t>=rg.t)hit=true;if(hit){o.tHit=t;break;}}
      const tH=o.tHit,v0=vOfT(tH),mu=6.5;let dd=dist(tH),phase=0,tStop=null;const yawF=Math.atan2(-(-uz),-ux);
      for(let k=0;k<n;k++){const t=k*DT,S={x:0,y:0,z:0,yaw:yawF,pitch:0,roll:0,sx:1,sy:1,sz:1,eye:0,ear:0,leg:0,graze:0,speed:0,react:false};
        let v;
        if(t<tH){dd=dist(t);v=vOfT(t);}
        else{const tau=(t-tH)/1000,dpath=v0/mu*(1-Math.exp(-mu*tau));dd=dist(tH)-dpath;v=v0*Math.exp(-mu*tau);if(tStop===null&&v<.25)tStop=t;
          if(tStop!==null){const bt=(t-tStop)/1000;dd+=.38*sm(bt/.7);v=Math.max(v,.0);}}
        phase+=v*DT/1000*2.3;
        S.x=Cx+dd*ux;S.z=Cz+dd*uz;S.speed=v;
        S.y=.05*Math.abs(Math.sin(phase))*Math.min(1,v/3);S.leg=phase;
        if(t>=tH){const tau=(t-tH)/1000;S.react=true;S.eye=tau<(FEAR_MS/1000)?1:Math.max(0,1-(tau-1.2)/.5);S.ear=S.eye;
          S.pitch=.26*Math.sin(Math.PI*clamp(tau/.55,0,1))*(tau<.55?1:0)-.1*Math.exp(-Math.max(0,tau-.5)/.2)*Math.sin(Math.max(0,tau-.5)*14)*(tau>.5?1:0);
          const f=Math.exp(-tau/.22);S.sy=1-.1*Math.min(1,tau/.06)*Math.exp(-tau/.7);S.sx=1+.06*(1-S.sy)/.1;S.sz=S.sx;S.y+=.0;
          S.roll=.05*Math.sin(tau*40)*Math.exp(-tau/.3);}
        o.S[k]=S;}
      o.vHit=v0;o.dHit=dist(tH);o.stopT=tStop;
    }else{
      const away=Math.atan2(-bz,bx),tH=d.kind==='timid'?Math.ceil(ringInv(rg0,Math.hypot(bx,bz))):null; // yaw convention: atan2(-dz,dx)
      o.tHit=(d.kind==='timid'&&Math.hypot(bx,bz)<=RANGE)?tH:null;
      const tR=o.tHit===null?1e9:o.tHit+60;
      const yaw0=Math.atan2(-(-bz),-bx)+1.15*(d.ang>0?1:-1);// grazing, side-on to B, unaware
      let x=Cx+bx,z=Cz+bz,yaw=yaw0,spd=0,phase=0;const vr=ver.fleeV;
      const fleeYaw=away,wob=t=>.22*Math.sin(t/95);
      for(let k=0;k<n;k++){const t=k*DT,tau=(t-tR)/1000,S={x:0,y:0,z:0,yaw,pitch:0,roll:0,sx:1,sy:1,sz:1,eye:0,ear:0,leg:0,graze:0,speed:0,react:false};
        const graze=.5+.5*Math.sin(t/620+d.ang*3);
        if(tau<0){S.graze=Math.max(0,graze-.15);S.sy=1+.012*Math.sin(t/260);}
        else{
          S.react=true;
          // shock: the shock front pushes it back, it squashes and hops, then turns and runs (fear lasts 1.2 s)
          const push=.2*(1-Math.exp(-tau/.06)),dirx=Math.cos(away),dirz=-Math.sin(away);
          let diff=fleeYaw+wob(t)*(tau>.12?1:0)-yaw;diff=Math.atan2(Math.sin(diff),Math.cos(diff));yaw+=clamp(diff,-DT/1000*10,DT/1000*10);S.yaw=yaw;
          const runOn=tau>.14&&tau<FEAR_MS/1000,ramp=sm((tau-.14)/.25),dec=tau>FEAR_MS/1000?1-sm((tau-FEAR_MS/1000)/.4):1;
          spd=(runOn||tau>=FEAR_MS/1000)?vr*ramp*dec:0;
          x+=Math.cos(away+(tau>.14?wob(t)*.4:0))*spd*DT/1000;z+=-Math.sin(away+(tau>.14?wob(t)*.4:0))*spd*DT/1000;
          const hopY=.15*Math.sin(Math.PI*clamp(tau/.28,0,1));phase+=spd*DT/1000*2.4;
          S.speed=spd;S.leg=phase;S.y=hopY+.055*Math.abs(Math.sin(phase))*Math.min(1,spd/2);
          S.eye=tau<1.2?1:Math.max(0,1-(tau-1.2)/.5);S.ear=S.eye;
          const sq=.16*Math.exp(-tau/.16)*Math.cos(tau*17);S.sy=1-sq*.9;S.sx=1+sq*.45;S.sz=S.sx;S.pitch=-.18*Math.exp(-tau/.2);S.roll=.07*Math.sin(tau*30)*Math.exp(-tau/.3)+(spd>.5?.05*Math.sin(phase*.5):0);
          S.x=x+dirx*push;S.z=z+dirz*push;}
        if(tau<0){S.x=x;S.z=z;}
        S.y=Math.max(S.y,0);
        o.S[k]=S;}
    }
    out.push(o);
  }
  return out;
}
function dummyAt(ver,k,tr){const o=ver.dummies[k],f=clamp(tr/DT,0,o.S.length-1),i=Math.floor(f),S=o.S[i];return S;}
// ---------------------------------------------------------------- the four versions
const FR=[[.1909,-.165],[.1909,.165]];
const VERSIONS=[];
function finish(ver){
  const pre=ver.pre;ver.endReal=pre+ver.end;ver.emitReal=pre+ver.emit;
  // real-time lists
  ver.rings=ver.rings.map(r=>({t:pre+r.t,dur:r.dur,amp:r.amp}));
  ver.airR=ver.air.map(r=>({t0:pre+r.t0,t1:pre+r.t1,period:r.period,amp:r.amp||1}));
  ver.shkR=ver.shk.map(s=>Object.assign({},s,{t0:pre+s.t0,t1:pre+s.t1}));
  ver.fxR=ver.fx.map(e=>Object.assign({},e,{t:pre+e.t}));
  ver.phlR=[['watch',0,pre]].concat(ver.phl.map(p=>[p[0],pre+p[1],pre+p[2]])).filter(p=>p[2]>p[1]);
  const {sk}=skelAtReal(ver,ver.emitReal);ver.C=[sk.nodes[3].x,sk.nodes[3].z];
  ver.chargeAnchor=ver.rings[0].t+ver.rings[0].dur*(1-Math.pow(1-.75,1/2.2)); // ring reaches 3 m (75 % of 4)
  ver.dummies=simDummies(ver);
  ver.pose=(ver.poseOff||[-300,-100,60,300,600,900]).map(o=>Math.max(0,Math.round(ver.emitReal+o)));
  const tHc=ver.dummies[0].tHit;ver.strip=(ver.stripOff||[-180,10,110]).map(o=>ver.emitReal+o).concat([tHc+120,tHc+520,tHc+1150]).map(Math.round);
  return ver;
}
const mk=(spec)=>{const f=[0,1,2,3].map(i=>new FB(i));spec.make(f);return finish(spec);};
// ---- 1 rear-up roar
VERSIONS.push(mk({id:'rear',name:'Rear-up roar',pre:140,tag:'rears onto the hind legs, chest out, head thrown forward and up, mouth wide, holds the roar 0.6 s, drops down',
  end:1950,emit:620,fleeV:3.6,lay:0,poseOff:[-520,-300,-60,260,640,900],
  phl:[['crouch',0,220],['rear up',220,620],['roar',620,1220],['drop',1220,1520],['recover',1520,1950]],
  rings:[{t:620,dur:460,amp:1},{t:700,dur:520,amp:.45}],air:[{t0:600,t1:1210,period:230}],
  shk:[{t0:610,t1:1000,amp:.03,hz:9,decay:110},{t0:1220,t1:1700,amp:.016,hz:11,decay:90,at:1500}],
  fx:[{t:300,x:-.2,z:-.165,n:7,s:.8},{t:320,x:-.2,z:.165,n:7,s:.8},{t:640,x:-.9,z:0,n:12,s:1.7,ring:false},{t:1490,x:.28,z:-.165,n:8,s:1.3},{t:1490,x:.28,z:.165,n:8,s:1.3}],
  strip:[240,520,760,1000,1260,1700],
  ch:{
    by:[[0,0],[220,-.09,'s'],[320,-.07,'s'],[620,.0,'s'],[760,.02,'s'],[1220,.015,'s'],[1360,-.04,'i2'],[1500,-.11,'o'],[1700,-.02,'s'],[1950,0,'s']],
    bx:[[0,0],[220,-.07,'s'],[620,-.12,'s'],[1220,-.12],[1460,-.04,'i2'],[1700,0,'s']],
    pitch:[[0,0],[220,.1,'s'],[330,.08,'s'],[620,-.5,'o'],[700,-.56,'s'],[1220,-.56],[1500,.06,'i2'],[1700,0,'s']],
    sp:[[0,0],[220,.1,'s'],[330,.06],[620,-.4,'o'],[700,-.5,'s'],[1220,-.5],[1480,.0,'i2'],[1700,0,'s']],
    hd:[[0,[0,0,0]],[220,[-.04,-.12,0],'s'],[420,[-.1,-.05,0],'s'],[600,[.0,.07,0],'o'],[700,[.02,.09,0],'s'],[1220,[.02,.09,0]],[1420,[0,-.04,0],'s'],[1950,[0,0,0],'s']],
    hp:[[0,0],[220,.15,'s'],[420,.1,'s'],[600,-.25,'s'],[700,-.5,'s'],[1220,-.5],[1420,.0,'s'],[1950,0,'s']],
    gape:cat([[0,0],[560,0],[640,1.15,'o'],[1170,1.15],[1280,0,'i2'],[1950,0]]),
    stretch:[[0,1],[620,1.06,'s'],[760,1.16,'s'],[1220,1.16],[1450,1,'s']],
    tailP:[[0,0],[220,-.1,'s'],[620,-.35,'s'],[1220,-.35],[1500,.1,'s'],[1700,0,'s']],
    tailY:wig(660,1200,.14,5,160,0),
    chest:[[0,0],[440,.2,'s'],[620,1,'o'],[1220,1],[1400,.2,'s'],[1700,0,'s']],
    thr:cat([[0,0],[560,.3,'s'],[640,.8,'o'],[1200,.8],[1330,0,'s']],wig(660,1190,.18,11,60,0)),
    hroll:wig(660,1200,.05,13,120,0)
  },
  arcs:[],
  make(f){
    const tuck=[[0,[.16,-.2,0]],[2000,[.16,-.2,0]]];
    f[0].hold(1950);f[1].hold(1950);
    f[2].air(330,1500,tuck,.25,FR[0][1],130,150);f[3].air(340,1500,tuck,.25,FR[1][1],130,150);
    f[2].hold(1950);f[3].hold(1950);
    this.segs=f.map(q=>q.end(1950));
  }}));
// ---- 2 low threat bellow
VERSIONS.push(mk({id:'bellow',name:'Low threat bellow',pre:0,tag:'crouched and braced, head low and forward, neck extended, long rumbling roar with the throat pulsing',
  end:2400,emit:520,fleeV:3.1,lay:0,poseOff:[-420,-90,100,500,1000,1350],
  phl:[['brace',0,420],['breath in',420,520],['rumble',520,1740],['ease',1740,1960],['recover',1960,2400]],
  rings:[{t:520,dur:820,amp:1},{t:850,dur:880,amp:.7},{t:1180,dur:920,amp:.5}],air:[{t0:540,t1:1720,period:300,amp:.7}],
  shk:[{t0:520,t1:1740,amp:.012,hz:23,decay:1e9},{t0:520,t1:700,amp:.016,hz:14,decay:120}],
  fx:[{t:140,x:.3,z:-.2,n:6,s:.8},{t:190,x:.3,z:.2,n:6,s:.8},{t:560,x:.22,z:-.2,n:5,s:.8},{t:900,x:.22,z:.2,n:5,s:.9},{t:1250,x:.22,z:-.2,n:5,s:.9},{t:1560,x:.22,z:.2,n:5,s:.8}],
  strip:[200,480,720,1100,1500,2000],
  ch:{
    by:plus([[0,0],[300,-.13,'s'],[420,-.15,'s'],[520,-.16,'s'],[1740,-.16],[2000,-.02,'s'],[2400,0,'s']],wig(540,1720,.004,21,80,0)),
    bx:[[0,0],[300,.05,'s'],[520,.08,'s'],[1740,.08],[2000,0,'s']],
    pitch:[[0,0],[300,.14,'s'],[520,.2,'s'],[1740,.2],[2000,0,'s']],
    sp:[[0,0],[300,.04],[520,.08],[1740,.08],[2000,0,'s']],
    hd:[[0,[0,0,0]],[300,[.08,-.18,0],'s'],[420,[.12,-.22,0],'s'],[520,[.15,-.22,0],'s'],[1740,[.15,-.22,0]],[2000,[0,0,0],'s']],
    hp:[[0,0],[300,-.05],[520,-.25,'s'],[1740,-.25],[2000,0,'s']],
    gape:plus([[0,0],[480,0],[600,.85,'o'],[1700,.85],[1800,0,'i2'],[2400,0]],cat([[0,0],[600,0]],wig(620,1680,.12,7,140,0))),
    stretch:[[0,1],[300,1.05,'s'],[520,1.13,'s'],[1740,1.13],[2000,1,'s']],
    tailP:[[0,0],[420,-.2,'s'],[1740,-.2],[2000,0,'s']],
    tailY:wig(520,1740,.08,8,160,0),
    chest:[[0,0],[420,.35,'s'],[520,.6,'s'],[1740,.6],[2000,0,'s']],
    thr:plus([[0,0],[520,.2,'s'],[620,.65,'o'],[1700,.65],[1860,0,'s']],wig(620,1700,.32,10,100,0)),
    hroll:wig(620,1700,.04,17,150,0)
  },
  arcs:[],
  make(f){
    f[2].step(100,260,.31,-.2,.04);f[3].step(160,320,.31,.2,.04);
    this.segs=f.map(q=>q.end(2400));
  }}));
// ---- 3 screech burst
VERSIONS.push(mk({id:'screech',name:'Screech burst',pre:520,tag:'sharp inhale, head snaps forward, a shriek under 0.3 s with a fast shock ring, small hop back',
  end:1150,emit:195,fleeV:4.6,lay:0,poseOff:[-190,-45,10,150,290,420],
  phl:[['inhale',0,150],['snap',150,195],['shriek',195,470],['hop back',470,720],['recover',720,1150]],
  rings:[{t:195,dur:250,amp:1}],air:[{t0:190,t1:470,period:80}],
  shk:[{t0:190,t1:520,amp:.045,hz:18,decay:80}],
  fx:[{t:210,x:-.9,z:0,n:12,s:1.9,ring:false},{t:470,x:-.2,z:-.165,n:7,s:.9},{t:470,x:.2,z:.165,n:7,s:.9},{t:715,x:-.5,z:-.165,n:8,s:1.1},{t:715,x:-.1,z:.165,n:8,s:1.1}],
  strip:[0,170,260,420,640,950],
  ch:{
    by:[[0,0],[150,-.04,'s'],[195,-.02,'o'],[420,-.07,'s'],[470,-.07],[720,-.05,'s'],[800,-.09,'o'],[1000,0,'s'],[1150,0]],
    bx:[[0,0],[150,-.05,'s'],[195,.02,'o'],[420,0,'s'],[470,0],[800,-.3,'s'],[1000,-.3],[1150,-.3]],
    pitch:[[0,0],[150,-.1,'s'],[195,.06,'o'],[420,.08,'s'],[470,.1],[720,.12,'s'],[800,.14,'o'],[1000,0,'s']],
    sp:[[0,0],[150,-.12,'s'],[195,.02,'o'],[420,0,'s'],[800,.04],[1000,0,'s']],
    hd:[[0,[0,0,0]],[150,[-.12,.1,0],'s'],[195,[.0,.09,0],'o'],[430,[.0,.08,0],'s'],[560,[0,-.04,0],'s'],[1000,[0,0,0],'s']],
    hp:[[0,0],[150,-.35,'s'],[195,-.28,'o'],[430,-.18,'s'],[560,.1,'s'],[1000,0,'s']],
    gape:plus([[0,0],[160,0],[200,1.3,'o'],[440,1.2],[480,0,'i2'],[1150,0]],cat([[0,0],[200,0]],wig(210,430,.1,30,40,0))),
    stretch:[[0,1],[150,.92,'s'],[195,1.12,'o'],[430,1.1],[540,1,'s']],
    tailP:[[0,0],[150,-.1,'s'],[195,-.3,'o'],[470,-.3],[720,.1,'s'],[1000,0,'s']],
    chest:[[0,0],[150,1,'s'],[195,.7,'o'],[440,.3,'s'],[560,0,'s']],
    thr:plus([[0,0],[150,.9,'s'],[200,1,'o'],[440,.6],[520,0,'s']],wig(210,430,.22,26,30,0)),
    hroll:wig(205,435,.06,28,25,0)
  },
  arcs:[{t0:480,t1:720,x0:0,x1:-.3,y0:-.07,y1:-.05}],
  make(f){
    const bF=[[0,[.1,-.26,0]],[2000,[.1,-.26,0]]],bH=[[0,[-.04,-.3,0]],[2000,[-.04,-.3,0]]];
    f[0].air(480,720,bH,FOOT_REST[0][0]-.3,FOOT_REST[0][1],40,60);f[1].air(480,720,bH,FOOT_REST[1][0]-.3,FOOT_REST[1][1],40,60);
    f[2].air(480,720,bF,FOOT_REST[2][0]-.3,FOOT_REST[2][1],40,60);f[3].air(480,720,bF,FOOT_REST[3][0]-.3,FOOT_REST[3][1],40,60);
    this.segs=f.map(q=>q.end(1150));
  }}));
// ---- 4 display roar: starts facing the charger, turns side-on (flank towards it, and towards the game camera), crest up, tail up, head arcs
(function(){
  const PSI=2.03,PHI0=-PSI,PHI1=Math.PI/2-PSI,PHIM=(PHI0+PHI1)/2; // 2.03 rad = the game camera side (flank shown to it) // nose faces the charger at first, ends with the right flank to it
  const tgt=(i,phi)=>rotXZ(FOOT_REST[i][0],FOOT_REST[i][1],phi);
  const stage=(f,t0,phi)=>{for(const i of [2,1]){const [x,z]=tgt(i,phi);f[i].step(t0,t0+90,x,z,.045);}for(const i of [3,0]){const [x,z]=tgt(i,phi);f[i].step(t0+60,t0+150,x,z,.045);}};
  VERSIONS.push(mk({id:'display',name:'Display roar',pre:60,tag:'turns side-on to look bigger, crest up, tail raised, head swings in an arc while it roars to sweep the area',
    end:2450,emit:640,fleeV:3.4,lay:PSI-.3,poseOff:[-600,-300,60,330,620,880],
    phl:[['turn side-on',0,330],['stand tall',330,640],['sweep roar',640,1440],['hold display',1440,1760],['relax, turn back',1760,2450]],
    rings:[{t:640,dur:640,amp:1},{t:880,dur:700,amp:.6},{t:1120,dur:760,amp:.4}],air:[{t0:660,t1:1430,period:260,amp:.8}],
    shk:[{t0:640,t1:980,amp:.02,hz:10,decay:140},{t0:640,t1:1440,amp:.007,hz:14,decay:1e9}],
    fx:[{t:80,x:.1,z:.2,n:4,s:.6},{t:200,x:-.1,z:-.2,n:4,s:.6},{t:290,x:.2,z:.1,n:4,s:.6},{t:650,x:-.9,z:0,n:12,s:1.7},{t:1900,x:.1,z:-.2,n:4,s:.6},{t:2100,x:-.1,z:.2,n:4,s:.6}],
    strip:[],
    ch:{
      yaw:[[0,PHI0],[330,PHI1,'s'],[1830,PHI1],[2160,PHI0,'s'],[2450,PHI0]],
      by:[[0,0],[330,.0,'s'],[640,.01,'s'],[1760,.01],[2300,0,'s']],
      bx:[[0,0],[2450,0]],
      pitch:[[0,0],[330,.0,'s'],[640,-.05,'s'],[1440,-.05],[1760,-.04],[2300,0,'s']],
      sp:[[0,0],[330,0],[640,-.12,'s'],[1440,-.12],[1760,-.1],[2300,0,'s']],
      hd:[[0,[0,0,0]],[330,[0,0,0]],[600,[.0,.05,.08],'s'],[680,[.0,.06,.12],'s'],[980,[.0,.07,0],'l'],[1280,[.0,.06,-.12],'l'],[1440,[.0,.05,-.12],'s'],[1760,[.0,.03,-.05],'s'],[2300,[0,0,0],'s']],
      hyaw:[[0,0],[600,-.5,'s'],[680,-.8,'s'],[980,0,'l'],[1280,.85,'l'],[1440,.8,'s'],[1760,.3,'s'],[2300,0,'s']],
      hp:[[0,0],[600,-.15,'s'],[680,-.28,'s'],[1440,-.28],[1760,-.2],[2300,0,'s']],
      gape:plus([[0,0],[580,0],[680,1.1,'o'],[1400,1.1],[1480,0,'i2'],[2450,0]],cat([[0,0],[680,0]],wig(700,1380,.1,6,100,0))),
      stretch:[[0,1],[640,1.1,'s'],[1440,1.12],[1760,1.05,'s'],[2300,1,'s']],
      tailP:[[0,0],[330,.0],[640,.9,'s'],[1760,.8],[2300,0,'s']],
      tailY:cat([[0,0],[640,0]],wig(680,1430,.2,3,200,0),[[1480,0],[2300,0]]),
      crest:[[0,0],[380,0],[640,1,'o'],[1760,1,'s'],[2200,0,'s']],
      chest:[[0,0],[380,0],[640,.8,'s'],[1440,.8],[1760,.6,'s'],[2200,0,'s']],
      thr:plus([[0,0],[600,.3,'s'],[680,.7,'o'],[1400,.7],[1480,0,'s']],wig(680,1380,.18,9,100,0))
    },
    arcs:[],
    make(f){
      for(let i=0;i<4;i++)f[i].cur=tgt(i,PHI0);
      stage(f,30,PHIM);stage(f,170,PHI1);
      stage(f,1850,PHIM);stage(f,2000,PHI0);
      this.segs=f.map(q=>q.end(2450));
    }}));
})();
// ---------------------------------------------------------------- check
function check(){
  const fails=[],rows=[];
  for(const ver of VERSIONS){
    const r={id:ver.id,name:ver.name};
    // ring: reaches the game range at peak, never beyond
    const rg=ver.rings[0],rEnd=ringR(rg,rg.t+rg.dur),rMax=Math.max(...ver.rings.map(g=>Math.max(ringR(g,g.t+g.dur),ringR(g,g.t+g.dur+500))));
    r.ringPeak=rEnd;r.ringMax=rMax;if(Math.abs(rEnd-RANGE)>1e-6)fails.push(`${ver.id}: ring ends at ${rEnd} m not ${RANGE}`);if(rMax>RANGE+1e-6)fails.push(`${ver.id}: ring beyond range`);
    r.ringMs=rg.dur;
    // dummies: inside react, outside do not
    r.dummies=[];
    for(const d of ver.dummies){
      const q={id:d.id,kind:d.kind,r0:d.r};
      let moved=0,react=false,maxEar=0;const S0=d.S[0];
      for(const S of d.S){if(S.react)react=true;maxEar=Math.max(maxEar,S.ear,S.eye);moved=Math.max(moved,Math.hypot(S.x-d.S[0].x,S.z-d.S[0].z));}
      q.tHit=d.tHit;q.reacts=react;q.moved=moved;
      const inside=d.kind!=='idle'&&d.r<=RANGE+.01||d.kind==='charge';
      if(d.kind==='idle'){if(react||maxEar>0||moved>.01)fails.push(`${ver.id}: dummy ${d.id} at ${d.r} m outside range reacted`);}
      else{if(!react||d.tHit===null)fails.push(`${ver.id}: dummy ${d.id} inside range did not react`);}
      if(d.kind!=='idle'&&d.tHit!==null){
        // reacts only after the ring front has reached it
        const dist=Math.hypot(d.S[Math.round(d.tHit/DT)].x-ver.C[0],d.S[Math.round(d.tHit/DT)].z-ver.C[1]);
        q.distAtHit=dist;q.ringAtHit=ringR(rg,d.tHit);
        if(Math.abs(q.ringAtHit-dist)>.12)fails.push(`${ver.id}: ${d.id} reacts when ring is ${q.ringAtHit.toFixed(2)} m but it is ${dist.toFixed(2)} m away`);
        if(dist>RANGE+.05)fails.push(`${ver.id}: ${d.id} reacts beyond range (${dist.toFixed(2)} m)`);
        q.preMove=0;const i0=Math.max(0,Math.round(d.tHit/DT)-8);
        // nothing before the ring (timid): displacement before tHit is zero
        if(d.kind==='timid'){let m=0;for(let k=0;k<=Math.round(d.tHit/DT);k++)m=Math.max(m,Math.hypot(d.S[k].x-d.S[0].x,d.S[k].z-d.S[0].z));q.preMove=m;if(m>.005)fails.push(`${ver.id}: ${d.id} moves before the ring reaches it`);}
        if(d.kind==='timid'){const e=d.S[d.S.length-1];q.fled=Math.hypot(e.x-d.S[0].x,e.z-d.S[0].z);if(q.fled<1.8||q.fled>6)fails.push(`${ver.id}: ${d.id} fled ${q.fled.toFixed(2)} m (want 2-6)`);}
        if(d.kind==='charge'){
          const si=Math.min(d.S.length-1,Math.round((d.tHit+1100)/DT)),e=d.S[si];q.speedAfter=e.speed;q.vHit=d.vHit;q.dHit=d.dHit;
          let mn=9;for(const S of d.S)mn=Math.min(mn,Math.hypot(S.x-ver.C[0],S.z-ver.C[1]));q.minDistToB=mn;
          if(d.vHit<3.5)fails.push(`${ver.id}: charger only ${d.vHit.toFixed(1)} m/s when hit (not mid-charge)`);
          if(e.speed>.08)fails.push(`${ver.id}: charger still moving ${e.speed.toFixed(2)} m/s 1.1 s after the roar`);
          if(mn<1.2)fails.push(`${ver.id}: charger reaches ${mn.toFixed(2)} m of B`);
        }
      }
      // ground
      let gmin=9;for(const S of d.S)gmin=Math.min(gmin,S.y-.0);q.minY=gmin;if(gmin<-.001)fails.push(`${ver.id}: dummy ${d.id} below ground`);
      let bad=0;for(const S of d.S)for(const k in S)if(typeof S[k]==='number'&&!isFinite(S[k]))bad++;if(bad)fails.push(`${ver.id}: dummy ${d.id} non-finite`);
      r.dummies.push(q);
    }
    // feet planted: planted segments must not drift; geometry above ground; IK
    let drift=0,maxErr=0,minY=9,maxStretch=0;const sampled=[];for(let a=0;a<=ver.end;a+=4)sampled.push([a,skel(ver,poseAt(ver,a),true)]);
    for(let i=0;i<4;i++)for(const s of ver.segs[i])if(s.k==='p'&&s.t1-s.t0>30){let p0=null;
      for(const [a,sk] of sampled)if(a>=s.t0+2&&a<=s.t1-2){if(!p0)p0=sk.feet[i].clone();drift=Math.max(drift,sk.feet[i].distanceTo(p0),sk.feet[i].distanceTo(sk.targets[i]));}}
    for(const [a,sk] of sampled){maxErr=Math.max(maxErr,sk.legErr,sk.neckErr);maxStretch=Math.max(maxStretch,sk.stretch);
      sk.nodes.forEach((n,i)=>{if(i<7)minY=Math.min(minY,n.y-REST.nodes[i][2]*.9);});sk.knees.forEach(k=>minY=Math.min(minY,k.y-.02));sk.feet.forEach(f=>minY=Math.min(minY,f.y-.03));minY=Math.min(minY,sk.tip.y,sk.head.y-REST.hr*.9);}
    r.plantedDrift=drift;r.maxReachErr=maxErr;r.minY=minY;r.neckStretch=maxStretch;
    if(drift>.02)fails.push(`${ver.id}: planted foot drift ${(drift*100).toFixed(1)} cm`);
    if(maxErr>.02)fails.push(`${ver.id}: IK out of reach by ${(maxErr*100).toFixed(1)} cm`);
    if(minY<-.012)fails.push(`${ver.id}: geometry ${(minY*100).toFixed(1)} cm below ground`);
    if(maxStretch>1.22)fails.push(`${ver.id}: neck stretch ${maxStretch.toFixed(2)} above 1.22`);
    // mouth: open window, size-scaled timing
    let o0=null,o1=null;for(let a=0;a<=ver.end;a+=2){const g=poseAt(ver,a).gape;if(g>.6){if(o0===null)o0=a;o1=a;}}
    r.mouthOpenMs=o1-o0;const wind=ver.emit;r.windupMs=wind;
    if(ver.id==='screech'){if(r.mouthOpenMs>300)fails.push(`screech: mouth open ${r.mouthOpenMs} ms (> 300)`);}
    else if(r.mouthOpenMs<500)fails.push(`${ver.id}: roar only ${r.mouthOpenMs} ms`);
    if(ver.id==='rear'&&(r.mouthOpenMs<500||r.mouthOpenMs>750))fails.push(`rear: roar hold ${r.mouthOpenMs} ms not about 0.6 s`);
    if(ver.id==='bellow'&&r.mouthOpenMs<1000)fails.push(`bellow: rumble ${r.mouthOpenMs} ms too short`);
    if(ver.id!=='screech'&&(wind<400||wind>800))fails.push(`${ver.id}: wind-up ${wind} ms outside 400-800 (game 600)`);
    if(ver.id==='screech'&&wind>300)fails.push(`screech: wind-up ${wind} ms`);
    // head height and rear-up
    let hmax=0;for(const [a,sk] of sampled)hmax=Math.max(hmax,sk.tip.y);r.headMax=hmax;
    if(ver.id==='rear'&&hmax<1.25)fails.push(`rear: head only ${hmax.toFixed(2)} m high`);
    if(ver.id==='display'){const cr=poseAt(ver,1200).crest,ty=poseAt(ver,1200).tailP;if(cr<.9||ty<.6)fails.push('display: crest/tail not raised at the roar');r.yawAtRoar=poseAt(ver,1200).yaw;}
    if(ver.id==='screech'){let ft=0;for(let a=ver.arcs[0].t0;a<=ver.arcs[0].t1;a+=10)if(skel(ver,poseAt(ver,a),true).feet.some(f=>f.y<.04))ft++;r.hopApex=Math.max(...[0,.25,.5,.75,1].map(u=>poseAt(ver,ver.arcs[0].t0+u*(ver.arcs[0].t1-ver.arcs[0].t0)).by))-(-.06);}
    r.timing={};for(const [n,a,b] of ver.phl)r.timing[n]=b-a;r.preMs=ver.pre;r.endReal=ver.endReal;
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.ROARCORE={T,REST,VERSIONS,RANGE,skelAtReal,poseAt,ringR,ringInv,dummyAt,check,DT,FEAR_MS};
})(typeof window!=='undefined'?window:globalThis);
