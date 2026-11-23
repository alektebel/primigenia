'use strict';
// Primigenia befriend lab core (A76 step 1): starter B (no arms, beak "pico", crest "cresta") sings, dances, charms and poses for a Zanco-like
// tall herbivore. Pure maths, no DOM. Needs bite2_core.js first (body rig, REST, interp). Units: metres, +x forward, +y up, +z creature's right.
// Game numbers (core/include/cpore/world.h, core/src/stage_social.c, 10 ticks per second):
//   beat = CP_SOC_BEAT 12 ticks = 1200 ms, rhythm window CP_SOC_WINDOW +-2 ticks = +-200 ms. The rhythm is read at the END of the wind-up
//   (act_t == windup): hit = |tick - beat| <= 2 ticks. The skill applies (trust, "success") at windup + active ticks.
//   sing  wind-up 2, active 8,  recovery 2, range 8 m     dance wind-up 2, active 10, recovery 2, range 5 m
//   charm wind-up 1, active 6,  recovery 2, range 4 m     pose  wind-up 4, active 8,  recovery 2, range 10 m
// Times: everything is authored in g (ms from the moment the order starts, negative = lead-in) and shifted by ver.pre to the real clock tr.
(function(root){
const B=root.BITECORE,T=B.T,REST=B.REST,interp=B.interp,V=B.V,DEF=B.DEF,FOOT_REST=B.FOOT_REST,frames=B.frames;
const X=new T.Vector3(1,0,0),Y=new T.Vector3(0,1,0),Z=new T.Vector3(0,0,1);
const clamp=(x,a,b)=>x<a?a:x>b?b:x,sm=u=>{u=clamp(u,0,1);return u*u*(3-2*u);};
const FY=.03,P0=V(...REST.P0),P0x=P0.x,NECK=[Math.hypot(.14,.16),Math.hypot(.14,.1)],G=9.81;
const BEAT=1200,WIN=200,TX=2.7,TAIL_MS=3600;
const GAME={sing:{W:200,A:800,R:200,range:8},dance:{W:200,A:1000,R:200,range:5},charm:{W:100,A:600,R:200,range:4},pose:{W:400,A:800,R:200,range:10}};
const EXTRA={chest:0,thr:0,crest:0};
// ---------------------------------------------------------------- key helpers
function norm(k){k.sort((a,b)=>a[0]-b[0]);for(let i=1;i<k.length;i++)if(k[i][0]<=k[i-1][0])k[i][0]=k[i-1][0]+.05;return k;}
function cat(...ls){const o=[];for(const l of ls)for(const k of l)o.push(k.slice());return norm(o);}
function wig(t0,t1,amp,hz,ramp,base,ph){const o=[],n=Math.max(2,Math.round((t1-t0)/8));for(let k=0;k<=n;k++){const t=t0+(t1-t0)*k/n,e=Math.min(1,(t-t0)/ramp,(t1-t)/ramp);o.push([t,(base||0)+amp*e*Math.sin(2*Math.PI*hz*(t-t0)/1000+(ph||0)),'l']);}return o;}
function plus(a,b){const ts=new Set();a.forEach(k=>ts.add(k[0]));b.forEach(k=>ts.add(k[0]));return norm([...ts].sort((x,y)=>x-y).map(t=>[t,interp(a,t)+interp(b,t),'l']));}
// bumps: at each t a rise to amp (ease o) then a fall back to base
function bumps(ts,amp,base,rise,fall,hold){const o=[[-9000,base]];for(const t of ts){o.push([t-rise,base,'s'],[t,amp,'o']);if(hold)o.push([t+hold,amp]);o.push([t+(hold||0)+fall,base,'s']);}o.push([99999,base]);return norm(o);}
const shiftKeys=(k,p)=>k.map(e=>{const r=e.slice();r[0]=e[0]+p;return r;});
const rotXZ=(x,z,phi)=>[P0x+(x-P0x)*Math.cos(phi)+z*Math.sin(phi),-(x-P0x)*Math.sin(phi)+z*Math.cos(phi)];
const restWorld=(i,bx,bz,yaw)=>{const lx=FOOT_REST[i][0]-P0x,lz=FOOT_REST[i][1],c=Math.cos(yaw),s=Math.sin(yaw);return [P0x+bx+lx*c+lz*s,bz-lx*s+lz*c];};
// ---------------------------------------------------------------- foot segments: p planted, s swing (pw: lift skew, >1 = slow rise, fast slam), h hold lifted, a airborne
function FB(i,start){this.i=i;this.cur=start?start.slice():[FOOT_REST[i][0],FOOT_REST[i][1]];this.t=-3000;this.segs=[];}
FB.prototype={
  hold(t){if(t>this.t){this.segs.push({k:'p',t0:this.t,t1:t,x:this.cur[0],z:this.cur[1]});this.t=t;}return this;},
  step(t0,t1,x,z,h,pw){this.hold(t0);this.segs.push({k:'s',t0,t1,x0:this.cur[0],z0:this.cur[1],x1:x,z1:z,h,pw:pw||1});this.cur=[x,z];this.t=t1;return this;},
  stomp(t0,t1,h){return this.step(t0,t1,this.cur[0],this.cur[1],h,2.4);},
  lift(t0,t1,h,rise){this.hold(t0);this.segs.push({k:'h',t0,t1,x:this.cur[0],z:this.cur[1],h,rise:rise||140});this.t=t1;return this;},
  air(t0,t1,Bk,x,z,inn,out){this.hold(t0);this.segs.push({k:'a',t0,t1,x0:this.cur[0],z0:this.cur[1],x1:x,z1:z,B:Bk,in:inn,out});this.cur=[x,z];this.t=t1;return this;},
  end(t){this.hold(t);return this.segs;}
};
function footTarget(segs,a,hipW,Fq,FYv){
  let s=segs[segs.length-1];for(const q of segs)if(a<=q.t1){s=q;break;}
  if(s.k==='p')return {t:V(s.x,FYv,s.z),planted:true};
  if(s.k==='s'){const u=clamp((a-s.t0)/(s.t1-s.t0),0,1),e=sm(u);return {t:V(s.x0+(s.x1-s.x0)*e,FYv+s.h*Math.sin(Math.PI*Math.pow(u,s.pw)),s.z0+(s.z1-s.z0)*e),planted:false};}
  if(s.k==='h'){const w=Math.min(sm((a-s.t0)/s.rise),sm((s.t1-a)/s.rise));return {t:V(s.x,FYv+s.h*w,s.z),planted:w<.02};}
  const u=a-s.t0,w=Math.min(sm(u/Math.max(1,s.in)),sm((s.t1-a)/Math.max(1,s.out))),half=(s.t1-s.t0)/2;
  const Wp=(u<half?V(s.x0,FYv,s.z0):V(s.x1,FYv,s.z1)),Bv=interp(s.B,a),Bp=hipW.clone().add(V(Bv[0],Bv[1],Bv[2]).applyQuaternion(Fq));
  const tg=Wp.lerp(Bp,w);tg.y=Math.max(tg.y,FYv);return {t:tg,planted:false};
}
function ik(hip,foot,a,b,pole){
  const d=foot.clone().sub(hip);let L=d.length();const mx=a+b-1e-4,mn=Math.abs(a-b)+1e-3,err=Math.max(0,L-mx);
  const dir=d.clone().divideScalar(L||1);L=clamp(L,mn,mx);
  const x=(a*a-b*b+L*L)/(2*L),h=Math.sqrt(Math.max(0,a*a-x*x));
  const perp=pole.clone().sub(dir.clone().multiplyScalar(pole.dot(dir)));if(perp.lengthSq()<1e-8)perp.set(0,1,0);perp.normalize();
  return {knee:hip.clone().addScaledVector(dir,x).addScaledVector(perp,h),foot:hip.clone().addScaledVector(dir,L),err};
}
function toWorld(p,fr,P,F){const v=V(p[0]-P0.x,p[1]-P0.y,p[2]-P0.z).applyQuaternion(fr==='f'?F.Qf:F.Qr);return v.add(V(P0.x+P.bx,P0.y+P.by,P0.z+P.bz));}
// ---------------------------------------------------------------- starter B skeleton (body rig of bite2_core, feet from the foot segments)
function skel(ver,P,legs){
  const F=frames(P),nodes=[],n3=REST.nodes[3],qt=new T.Quaternion().setFromEuler(new T.Euler(0,P.tailY,P.tailP,'YZX'));
  for(let i=0;i<8;i++){const n=REST.nodes[i];let fr='r',p=[n[0],n[1],0];
    if(i<3){const v=V(n[0]-n3[0],n[1]-n3[1],0).applyQuaternion(qt);p=[n3[0]+v.x,n3[1]+v.y,v.z];}else if(i>=4)fr='f';
    nodes.push(toWorld(p,fr,P,F));}
  const head=toWorld([REST.nodes[7][0]+P.hd[0],REST.nodes[7][1]+P.hd[1],P.hd[2]],'f',P,F);
  const sh=nodes[5],s=clamp(Math.max(P.stretch,sh.distanceTo(head)/(NECK[0]+NECK[1])*1.002),.85,1.25),ng=ik(sh,head,NECK[0]*s,NECK[1]*s,V(.25,1,0).normalize().applyQuaternion(F.Qf));
  nodes[6]=ng.knee;nodes[7]=ng.foot.clone();
  const Qh=F.Qf.clone().multiply(new T.Quaternion().setFromAxisAngle(Y,P.hyaw)).multiply(new T.Quaternion().setFromAxisAngle(Z,-P.hp)).multiply(new T.Quaternion().setFromAxisAngle(X,P.hroll));
  const axis=X.clone().applyQuaternion(Qh),headC=nodes[7].clone(),hinge=headC.clone().addScaledVector(axis,REST.hinge),tip=headC.clone().addScaledVector(axis,REST.beak);
  const out={F,nodes,stretch:s,head:headC,neckErr:ng.err,legErr:0,Qh,axis,hinge,tip,hips:[],knees:[],feet:[],planted:[],targets:[]};
  if(!legs)return out;
  for(let i=0;i<4;i++){
    const fore=i>=2,hip=toWorld(REST.hip[i],fore?'f':'r',P,F),ft=footTarget(ver.segs[i],P.a,hip,fore?F.Qf:F.Qr,FY);
    const pole=X.clone().applyQuaternion(fore?F.Qf:F.Qr),r=ik(hip,ft.t,REST.seg[i][0],REST.seg[i][1],pole);
    if(r.knee.y<.025)r.knee.y=.025;out.hips.push(hip);out.knees.push(r.knee);out.feet.push(r.foot);out.planted.push(ft.planted);out.targets.push(ft.t);out.legErr=Math.max(out.legErr,r.err);
  }
  return out;
}
function bodyPose(ver,a){
  const P={};for(const n in DEF)P[n]=ver.ch[n]?interp(ver.ch[n],a):DEF[n];for(const n in EXTRA)P[n]=ver.ch[n]?interp(ver.ch[n],a):0;
  P.hd=ver.ch.hd?interp(ver.ch.hd,a):[0,0,0];
  for(const r of ver.arcs)if(a>=r.t0&&a<=r.t1){const tau=(a-r.t0)/1000,Ts=(r.t1-r.t0)/1000,vy=(r.y1-r.y0)/Ts+G*Ts/2,u=(a-r.t0)/(r.t1-r.t0);P.by=r.y0+vy*tau-.5*G*tau*tau;P.bx=r.x0+(r.x1-r.x0)*u;P.bz=r.z0+(r.z1-r.z0)*u;}
  P.a=a;return P;
}
function poseAt(ver,a){
  const P=bodyPose(ver,a);
  if(!ver.arcs.some(r=>a>=r.t0&&a<=r.t1)){const sk=skel(ver,P,false);let lo=9;sk.nodes.forEach((n,i)=>{if(i<7)lo=Math.min(lo,n.y-REST.nodes[i][2]*.9);});if(lo<.012)P.by+=.012-lo;}
  return P;
}
// ---------------------------------------------------------------- gait generator: feet stepping diagonally under a body path (keys bx, bz, yaw in g)
// pair A (hind left + fore right) lifts at t0, pair B half a cycle later; a swing lasts sw*Tc and lands where the rest position will be mid-stance.
function walk(f,ch,t0,t1,Tc,o){o=o||{};const sw=Tc*(o.sw||.34),ph=[0,.5,.5,0],rest=o.rest||restWorld,hh=o.h||.05;
  const at=t=>[interp(ch.bx,t),ch.bz?interp(ch.bz,t):0,ch.yaw?interp(ch.yaw,t):0];
  for(let i=0;i<4;i++)for(let k=0;;k++){const tau=t0+(k+ph[i])*Tc;if(tau>t1+Tc*.6)break;
    const tl=tau+sw,p=at(tl+(Tc-sw)*(o.look===undefined?.5:o.look)),w=rest(i,p[0],p[1],p[2]),f_=f[i];
    if(Math.hypot(w[0]-f_.cur[0],w[1]-f_.cur[1])<.02&&tau>t1)continue;
    f_.step(tau,tl,w[0],w[1],hh);}
}
const stage=(f,t0,phi,dur)=>{dur=dur||90;for(const i of [2,1]){const [x,z]=rotXZ(FOOT_REST[i][0],FOOT_REST[i][1],phi);f[i].step(t0,t0+dur,x,z,.045);}for(const i of [3,0]){const [x,z]=rotXZ(FOOT_REST[i][0],FOOT_REST[i][1],phi);f[i].step(t0+60,t0+60+dur,x,z,.045);}};
// ---------------------------------------------------------------- the tall target (Zanco-like: stilt legs, long neck, trumpet snout, ear scoops, back fringe)
const TL=[[-.27,-.1],[-.27,.1],[.27,-.1],[.27,.1]],THIP=[[-.27,-.02,-.09],[-.27,-.02,.09],[.27,-.02,-.09],[.27,-.02,.09]],TSEG=[[.42,.45],[.42,.45],[.43,.46],[.43,.46]];
const TH0=.84,TNB=[.30,.12,0],TNR=[.34,.52],TNL=.4;
const trest=(i,bx,bz)=>[TX-bx-TL[i][0],bz-TL[i][1]];
const qT=(yaw,pitch,roll)=>new T.Quaternion().setFromAxisAngle(Y,yaw).multiply(new T.Quaternion().setFromAxisAngle(Z,-pitch)).multiply(new T.Quaternion().setFromAxisAngle(X,roll));
function tparams(ver,tr){
  const ts=ver.ts,u=(tr-ts)/1000,P={by:0,bx:0,bz:0,pitch:0,roll:0,nup:0,nfwd:0,hp:.16,hyaw:0,hroll:0,jaw:0,earL:.32,earR:.32,eturn:0,tailY:0,tailP:-.18,fin:.12,thr:0,react:0};
  // idle life: breathing, an ear flick, a slow tail sway
  P.by=.004*Math.sin(tr/520);P.tailY=.22*Math.sin(tr/760+1);P.fin=.14+.05*Math.sin(tr/610);P.earL+=.05*Math.max(0,Math.sin(tr/1400));P.earR+=.04*Math.max(0,Math.sin(tr/1100+2));
  // gaze: the head follows B with a 150 ms lag, clamped
  const tg=tr-150,bxh=P0x+interp(ver.ch.bx,tg)+.55*Math.cos(interp(ver.ch.yaw,tg)),bzh=interp(ver.ch.bz,tg)-.55*Math.sin(interp(ver.ch.yaw,tg));
  const dx=bxh-(TX-interp(ver.tbx,tr)-.62),dz=bzh;P.hyaw=clamp(-Math.atan2(-dz,-dx),-1.0,1.0)*.9;P.gaze=P.hyaw;
  P.tgt={bx:bxh,bz:bzh};
  for(const n in ver.tch){const v=interp(ver.tch[n],tr);P[n]=(P[n]||0)+v;}
  P.bx=interp(ver.tbx,tr);P.bz=ver.tbz?interp(ver.tbz,tr):0;
  if(u>=0){
    P.react=1;
    // common reaction on the success frame: ears up, head tilt, tail swish, soft glow (renderer)
    const eu=sm(u/.12),fall=sm((u-2.4)/.9);P.earL=P.earL+(1-P.earL)*eu-.28*fall;P.earR=P.earR+(1-P.earR)*eu-.28*fall;P.eturn=.25*sm(u/.3);
    P.hroll+=.36*sm(u/.22)*(1-.75*sm((u-1.7)/1.2));P.tailY+=.5*Math.sin(u*9)*Math.exp(-u/1.5);P.fin+=.4*sm(u/.3)*(1-sm((u-2.2)/1));
    const k=ver.act,e1=sm(u/.3)*(1-sm((u-2.4)/1)),bob=Math.sin(u*Math.PI*2/.45);
    if(k==='sing'){P.nup+=.1*e1;P.hp-=.12*e1;P.jaw+=.3*Math.max(0,Math.sin(u*Math.PI*2/.4))*(u>.2&&u<1.3?1:0);P.thr=Math.max(0,Math.sin(u*Math.PI*2/.4))*(u>.2&&u<1.3?1:0);}
    else if(k==='dance'){const on=u>.05&&u<1.5?Math.min(1,u*8,(1.5-u)*3):0;P.by-=.03*Math.abs(Math.sin(u*Math.PI/.45))*on;P.roll+=.06*Math.sin(u*Math.PI*2/.9)*on;P.nup+=.04*bob*on;P.tailY+=.35*Math.sin(u*14)*on;}
    else if(k==='charm'){P.nup-=.12*e1;P.hp+=.22*e1;P.nfwd+=.06*e1+.04*Math.sin(u*10)*e1;}
    else if(k==='pose'){P.by+=.035*e1;P.nup+=.1*e1;P.fin+=.5*e1;P.pitch-=.02*e1;}
    if(ver.treact)ver.treact(u,P,ver);
  }
  return P;
}
function tskel(ver,tr){
  const Pp=tparams(ver,tr),a=tr;
  const Qb=qT(Math.PI,Pp.pitch,Pp.roll),c=V(TX-Pp.bx,TH0+Pp.by,Pp.bz);
  const W=l=>V(l[0],l[1],l[2]).applyQuaternion(Qb).add(c);
  const nb=W(TNB),hl=[TNB[0]+TNR[0]+Pp.nfwd,TNB[1]+TNR[1]+Pp.nup,0],head=W(hl);
  const pole=V(.35,1,0).normalize().applyQuaternion(Qb),ng=ik(nb,head,TNL,TNL,pole);
  const Qh=Qb.clone().multiply(new T.Quaternion().setFromAxisAngle(Y,Pp.hyaw)).multiply(new T.Quaternion().setFromAxisAngle(Z,-(Pp.hp+.1*Pp.nup*-1))).multiply(new T.Quaternion().setFromAxisAngle(X,Pp.hroll));
  const axis=X.clone().applyQuaternion(Qh),tip=ng.foot.clone().addScaledVector(axis,.26);
  const hips=[],knees=[],feet=[],planted=[],targets=[];let legErr=0;
  for(let i=0;i<4;i++){
    const hip=W(THIP[i]),ft=footTarget(ver.tsegs[i],a,hip,Qb,FY);
    const pl=V(i>=2?1:-1,0,0).applyQuaternion(Qb),r=ik(hip,ft.t,TSEG[i][0],TSEG[i][1],pl);
    if(r.knee.y<.03)r.knee.y=.03;hips.push(hip);knees.push(r.knee);feet.push(r.foot);planted.push(ft.planted);targets.push(ft.t);legErr=Math.max(legErr,r.err);
  }
  // tail: two segments from the rump
  const tb=W([-.42,.06,0]),qa=new T.Quaternion().setFromEuler(new T.Euler(0,Pp.tailY,-Pp.tailP-.0,'YZX')),Qt=Qb.clone().multiply(qa);
  const t1=tb.clone().addScaledVector(V(-1,0,0).applyQuaternion(Qt),.26),Qt2=Qt.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,-.25-.2*Pp.tailY)),t2=t1.clone().addScaledVector(V(-1,0,0).applyQuaternion(Qt2),.24);
  return {P:Pp,Qb,c,nb,neckMid:ng.knee,head:ng.foot.clone(),Qh,axis,tip,hips,knees,feet,planted,targets,legErr,neckErr:ng.err,tail:[tb,t1,t2],W};
}
// ---------------------------------------------------------------- versions
const VERSIONS=[];
const SPEC=(act,id,name,tag,o)=>Object.assign({act,id,name,tag,pre:800},GAME[act],o);
function finish(s){
  const pre=s.pre,W=s.W,A=s.A,R=s.R,end=W+A+R;
  s.tb=pre+W;s.ts=pre+W+A;s.tEndG=end;s.endReal=s.ts+TAIL_MS;
  const ch={};for(const n in s.ch)ch[n]=shiftKeys(s.ch[n],pre);s.ch=ch;
  for(const n of ['bx','bz','yaw'])if(!s.ch[n])s.ch[n]=[[0,0]];
  s.arcs=(s.arcs||[]).map(r=>Object.assign({},r,{t0:r.t0+pre,t1:r.t1+pre}));
  s.pulses=(s.pulses||[]).map(p=>Object.assign({n:3,big:0},p,{t:p.t+pre}));
  s.fx=(s.fx||[]).map(e=>Object.assign({},e,{t:e.t+pre}));
  s.tch={};for(const n in (s.tchg||{}))s.tch[n]=shiftKeys(s.tchg[n],pre);
  // B feet
  const f=[0,1,2,3].map(i=>new FB(i,s.start?s.start[i]:null));
  s.make(f,s);
  s.segs=f.map(q=>q.end(s.endReal+500).map(g=>{const r=Object.assign({},g);r.t0=g.t0+(g.t0>-2999?pre:0);r.t1=g.t1+pre;if(r.B)r.B=shiftKeys(r.B,pre);return r;}));
  for(const sg of s.segs)for(const q of sg)if(q.t0<-2000)q.t0=-1e5;
  // target feet and path
  const tf=[0,1,2,3].map(i=>new FB(i,trest(i,0,0)));
  const ts=s.ts,TS=s.tstep===undefined?{dt:450,d:.5}:s.tstep;
  s.tbx=[[0,0]];s.tbz=null;
  if(TS){const t0=ts+TS.dt,t1=t0+800,r0=ts+2000,r1=ts+2900;
    s.tbx=[[0,0],[t0,0,'s'],[t1,TS.d,'s'],[r0,TS.d],[r1,0,'s'],[r1+500,0]];}
  if(s.tmake)s.tmake(tf,s);
  if(TS){const t0=ts+TS.dt,t1=t0+800,r0=ts+2000,r1=ts+2900,chp={bx:s.tbx};
    walk(tf,chp,t0,t1,800,{rest:(i,bx,bz)=>trest(i,bx,bz),h:.07,sw:.4});walk(tf,chp,r0,r1,700,{rest:(i,bx,bz)=>trest(i,bx,bz),h:.06,sw:.4});}
  s.tsegs=tf.map(q=>q.end(s.endReal+500).map(g=>Object.assign({},g,{t0:g.t0<-2000?-1e5:g.t0})));
  // success pulses from the target
  if(s.act==='sing')s.pulses.push({t:ts+250,src:'T',n:3},{t:ts+650,src:'T',n:3});
  if(s.prop){const p=s.prop;s.propR={g0:p.ground,carry:[p.carry[0]+pre,p.carry[1]+pre],put:p.put,takeT:p.take?ts+p.take:null};}
  // framing points
  s.pts=[[P0x,0],[TX,0]];for(let t=0;t<=s.endReal;t+=100)s.pts.push([P0x+interp(s.ch.bx,t),interp(s.ch.bz,t)]);
  // beat ticks on the real clock
  s.beats=[];for(let t=s.tb-BEAT*2;t<=s.endReal+BEAT;t+=BEAT)if(t>=0&&t<=s.endReal)s.beats.push(t);
  return s;
}
const FL=2,FR=3,HL=0,HR=1;
const tuckF=[[0,[.1,-.26,0]],[99999,[.1,-.26,0]]],tuckH=[[0,[-.04,-.3,0]],[99999,[-.04,-.3,0]]];
const note=(ts,len,peak,base)=>{const o=[];for(const t of ts)o.push([t-50,base||0,'s'],[t,peak,'o'],[t+len,base||0,'i2']);return o;};
const trans=(...k)=>norm(k);
// ================================================================= SING (W 200, A 800, R 200; beat at g 200, success at g 1000)
VERSIONS.push(finish(SPEC('sing','trill','Bird trill','head up, throat pulses, beak opens and closes in three trill bursts on the beat, sound ripples leave the beak',{
  sig:'chest',pre:800,
  ch:(()=>{const nt=[200,500,800],bu=nt.map(t=>wig(t,t+240,.3,13,30,.62));
    return {
    pitch:[[0,0],[200,-.1,'s'],[1000,-.1],[1500,0,'s']],sp:[[0,0],[200,-.08,'s'],[1000,-.08],[1500,0,'s']],stretch:[[0,1],[200,1.08,'s'],[1000,1.08],[1500,1,'s']],
    hd:[[0,[0,0,0]],[200,[-.02,.1,0],'s'],[1000,[-.02,.1,0]],[1500,[0,0,0],'s']],hp:[[0,0],[200,-.38,'s'],[1000,-.38],[1450,0,'s']],
    gape:cat([[0,0]],...bu.map(b=>[[b[0][0]-50,0,'s'],...b,[b[b.length-1][0]+60,0,'s']]),[[1500,0]]),
    chest:bumps(nt,.9,.12,90,200),thr:cat([[0,0],[160,.2,'s']],...nt.map(t=>wig(t,t+240,.35,15,25,.55)),[[1100,.1,'s'],[1400,0,'s']]),
    crest:[[0,0],[200,.5,'s'],[1100,.5],[1500,0,'s']],by:plus([[0,0],[1500,0]],bumps(nt,.014,0,60,200)),tailY:wig(200,1300,.18,3,200,0),tailP:[[0,0],[300,.15,'s'],[1100,.15],[1500,0,'s']]};})(),
  pulses:[{t:200,src:'B',n:4},{t:500,src:'B',n:4},{t:800,src:'B',n:4}],
  tchg:{earL:[[0,0],[300,.12,'s'],[1000,.2]],earR:[[0,0],[300,.12,'s'],[1000,.2]],nup:[[0,0],[500,.03,'s'],[1000,.05]]},
  make(f){}
})));
VERSIONS.push(finish(SPEC('sing','hum','Low hum with sway','head low and forward, throat pulses slowly, the whole body sways side to side on planted feet',{
  sig:'thr',pre:800,
  ch:(()=>{const nt=[200,500,800];return {
    pitch:[[0,0],[200,.05,'s'],[1000,.05],[1500,0,'s']],hd:[[0,[0,0,0]],[200,[.06,-.04,0],'s'],[1000,[.06,-.04,0]],[1500,[0,0,0],'s']],hp:[[0,0],[200,.14,'s'],[1000,.14],[1450,0,'s']],
    gape:plus([[0,0],[200,.1,'s'],[1000,.1],[1400,0,'s']],wig(260,1000,.04,5,100,0)),
    thr:plus([[0,0],[200,.4,'s'],[1000,.4],[1500,0,'s']],bumps(nt,.5,0,100,200).filter(k=>k[0]>-100&&k[0]<2000)),
    chest:[[0,0],[200,.4,'s'],[1000,.4],[1500,0,'s']],
    bz:wig(0,1500,.08,.83,250,0,Math.PI/2),roll:wig(0,1500,.1,.83,250,0,Math.PI/2),by:plus([[0,0],[1500,0]],wig(0,1500,-.012,1.66,250,0,Math.PI/2)),
    tailY:wig(100,1500,.35,.83,300,0,Math.PI/2+.8),hyaw:wig(0,1500,.1,.83,300,0,-Math.PI/2)};})(),
  pulses:[{t:200,src:'B',kind:'hum'},{t:700,src:'B',kind:'hum'}],
  tchg:{earL:[[0,0],[400,.15,'s'],[1000,.2]],earR:[[0,0],[400,.15,'s'],[1000,.2]],nup:[[0,0],[1000,-.04,'s']]},
  make(f){}
})));
VERSIONS.push(finish(SPEC('sing','callans','Call and answer','B calls twice, listens with its head cocked while the target answers, then answers back',{
  sig:'gape',pre:800,
  ch:{
    pitch:[[0,0],[200,-.06,'s'],[1000,-.04],[1500,0,'s']],hd:[[0,[0,0,0]],[200,[-.02,.08,0],'s'],[600,[0,.04,0],'s'],[780,[-.02,.09,0],'s'],[1000,[-.02,.08,0]],[1500,[0,0,0],'s']],
    hp:[[0,0],[200,-.3,'s'],[560,-.12,'s'],[800,-.34,'s'],[1000,-.3],[1450,0,'s']],hroll:[[0,0],[500,0],[640,.28,'s'],[740,.28],[820,0,'s']],
    gape:cat([[0,0]],note([200,500],170,.95,0),[[790,0],[800,.95,'o'],[1060,.95],[1130,0,'i2'],[1500,0]]),chest:bumps([200,500,800],.8,.12,90,220),
    thr:cat([[0,0]],...[200,500].map(t=>wig(t,t+170,.3,16,20,.55)),wig(800,1060,.32,15,25,.55),[[1500,0]]),crest:[[0,0],[200,.4,'s'],[1100,.4],[1500,0,'s']],
    stretch:[[0,1],[200,1.06,'s'],[1000,1.06],[1500,1,'s']],tailP:[[0,0],[300,.12,'s'],[1100,.12],[1500,0,'s']]},
  pulses:[{t:200,src:'B',n:3},{t:500,src:'B',n:3},{t:660,src:'T',n:3},{t:800,src:'B',n:4}],
  tchg:{earL:[[0,0],[550,0],[700,.2,'s'],[1000,.3]],earR:[[0,0],[550,0],[700,.2,'s'],[1000,.3]],nup:[[0,0],[560,0],[660,.14,'s'],[960,.14],[1100,.06,'s']],jaw:cat([[0,0],[600,0]],[[660,.8,'o'],[820,.8],[900,0,'i2']],[[1500,0]]),thr:cat([[0,0],[600,0]],wig(640,840,.5,14,30,.5),[[1500,0]]),hp:[[0,0],[640,0],[700,-.2,'s'],[950,-.2],[1100,0,'s']]},
  make(f){}
})));
VERSIONS.push(finish(SPEC('sing','duet','Duet chirp, head bobs','short chirps on the beat, the head bobs down with each one, the tail flicks; the target bobs along',{
  sig:'hp',pre:800,
  ch:(()=>{const nt=[200,500,800];return {
    pitch:[[0,0],[200,-.04,'s'],[1000,-.04],[1500,0,'s']],hd:[[0,[0,0,0]],[200,[0,.05,0],'s'],[1000,[0,.05,0]],[1500,[0,0,0],'s']],
    hp:plus([[0,0],[160,-.15,'s'],[1000,-.15],[1400,0,'s']],bumps(nt,.5,0,70,170).map(k=>[k[0],k[1],k[2]]).filter(k=>k[0]>-100&&k[0]<2000)),
    gape:cat([[0,0]],...nt.map(t=>[[t-40,0,'s'],[t,.85,'o'],[t+80,.1,'s'],[t+130,0,'i2']]),[[1500,0]]),chest:bumps(nt,.5,.12,80,200),thr:bumps(nt,.8,.1,70,160),
    by:plus([[0,0],[1500,0]],bumps(nt,-.03,0,60,170)),tailP:plus([[0,0],[1500,0]],bumps(nt,.35,0,60,160)),tailY:wig(200,1100,.3,3.3,100,0),crest:[[0,0],[200,.5,'s'],[1100,.5],[1500,0,'s']]};})(),
  pulses:[{t:200,src:'B',n:2},{t:500,src:'B',n:2},{t:800,src:'B',n:2}],
  tchg:{earL:[[0,0],[300,.1,'s'],[1000,.25]],earR:[[0,0],[300,.1,'s'],[1000,.25]],nup:cat([[0,0],[400,0]],[[500,-.08,'o'],[620,0,'s'],[800,-.08,'o'],[920,0,'s']],[[1500,0]]),jaw:cat([[0,0],[560,0]],[[600,.3,'o'],[700,0,'s'],[860,.3,'o'],[960,0,'s'],[1500,0]])},
  make(f){}
})));
// ================================================================= DANCE (W 200, A 1000, R 200; beat at g 200, success at g 1200)
(function(){
  // 1 stomp dance: fore feet slam in turn on 200, 500, 800, 1100, body shifts onto the planted side before each lift
  const st=[200,500,800,1100];
  VERSIONS.push(finish(SPEC('dance','stomp','Stomp dance','fore feet lift and slam on the beat in turn (left, right, left, right), the body drops and dust puffs at each stomp',{
    sig:'-by',pre:800,
    ch:{by:plus([[0,0],[1700,0]],bumps(st,-.03,0,100,150).filter(k=>k[0]>-100&&k[0]<1800)),bz:cat([[0,0]],wig(0,1300,.03,1.667,60,0,Math.PI/2),[[1500,0,'s']]),pitch:plus([[0,0],[1700,0]],bumps(st,.06,0,80,160).filter(k=>k[0]>-100&&k[0]<1800)),
      hp:plus([[0,0],[1700,0]],bumps(st,.2,0,90,160).filter(k=>k[0]>-100&&k[0]<1800)),chest:bumps(st,.7,.1,90,160),tailY:wig(100,1300,.45,3.33,100,0),tailP:[[0,0],[300,.2,'s'],[1300,.2],[1600,0,'s']],crest:[[0,0],[200,.3,'s'],[1300,.3],[1600,0,'s']]},
    fx:[{t:200,x:.24,z:-.165,n:7,s:.9},{t:500,x:.24,z:.165,n:7,s:.9},{t:800,x:.24,z:-.165,n:7,s:.9},{t:1100,x:.24,z:.165,n:7,s:1}],
    tchg:{earL:[[0,0],[500,.12,'s'],[1200,.2]],earR:[[0,0],[500,.12,'s'],[1200,.2]],nup:[[0,0],[1200,.02]]},
    make(f){f[FL].stomp(0,200,.14);f[FR].stomp(300,500,.14);f[FL].stomp(600,800,.14);f[FR].stomp(900,1100,.14);}
  })));
  // 2 hop dance: three small hops side to side, takeoffs 200 / 600 / 1000, last landing on the success frame
  VERSIONS.push(finish(SPEC('dance','hop','Hop dance','crouch, then three small hops side to side (left, right, centre), tail flicks up at each landing',{
    sig:'-by',pre:800,
    arcs:[{t0:200,t1:430,x0:0,x1:0,z0:0,z1:-.14,y0:-.075,y1:-.05},{t0:600,t1:830,x0:0,x1:0,z0:-.14,z1:.14,y0:-.075,y1:-.05},{t0:1000,t1:1200,x0:0,x1:0,z0:.14,z1:0,y0:-.075,y1:-.04}],
    ch:{by:[[0,0],[200,-.075,'i2'],[430,-.05],[600,-.075,'i2'],[830,-.05],[1000,-.075,'i2'],[1200,-.04],[1400,0,'s']],bz:[[0,0],[200,0],[430,-.14],[600,-.14],[830,.14],[1000,.14],[1200,0]],roll:[[0,0],[200,0],[320,-.12,'s'],[430,0,'s'],[600,0],[720,.12,'s'],[830,0,'s'],[1000,0],[1100,-.1,'s'],[1200,0,'s']],
      pitch:[[0,0],[200,.05,'s'],[320,-.04,'s'],[430,.04,'s'],[600,.05,'s'],[1200,.03],[1500,0,'s']],tailP:cat([[0,0]],[[430,.1],[480,.6,'o'],[620,0,'s'],[830,.1],[880,.6,'o'],[1000,0,'s'],[1200,.1],[1260,.6,'o'],[1500,0,'s']]),
      hp:[[0,0],[200,.12,'s'],[320,-.2,'s'],[430,.1,'s'],[600,.12,'s'],[720,-.2,'s'],[830,.1,'s'],[1000,.12,'s'],[1100,-.18,'s'],[1200,0,'s']],chest:bumps([200,600,1000],.6,.1,90,220),crest:[[0,0],[200,.5,'s'],[1300,.5],[1600,0,'s']],tailY:wig(200,1300,.25,3,100,0)},
    fx:[{t:430,x:-.05,z:-.28,n:6,s:.8},{t:830,x:-.05,z:.28,n:6,s:.8},{t:1200,x:-.1,z:0,n:7,s:.9}],
    tchg:{earL:[[0,0],[500,.12,'s'],[1200,.2]],earR:[[0,0],[500,.12,'s'],[1200,.2]]},
    make(f){const fx=(i,dz)=>[FOOT_REST[i][0],FOOT_REST[i][1]+dz];
      const hops=[[200,430,-.14],[600,830,.14],[1000,1200,0]];let z=0;
      for(const [a,b,tz] of hops){for(let i=0;i<4;i++){const p=FOOT_REST[i];f[i].air(a,b,i>=2?tuckF:tuckH,p[0],p[1]+tz,45,80);}z=tz;}
    }
  })));
  // 3 circle dance: a trot on an arc round the target (r 2.8 -> 2.45 m, 34 degrees, camera side), then it turns in place to face it; walks back while the target reacts
  (function(){
    const TH1=.5,r0=2.8,r1=2.5,cx=TX,uu=g=>clamp((g-120)/980,0,1),mixu=u=>.45*u+.55*sm(u),sa=g=>TH1*mixu(uu(g)),ra=g=>r0+(r1-r0)*sm(clamp(g/700,0,1));
    const pos=(th,r)=>[cx-r*Math.cos(th)-P0x,r*Math.sin(th)];
    const bx=[],bz=[],yw=[];let prev=-1.4;
    for(let g=0;g<=1300;g+=20){const th=sa(g),r=ra(g),p=pos(th,r);bx.push([g,p[0],'l']);bz.push([g,p[1],'l']);
      const pn=pos(sa(g+20),ra(g+20)),dx=pn[0]-p[0],dz=pn[1]-p[1],sp=Math.hypot(dx,dz)/.02;
      const tang=sp>.2?Math.atan2(-dz,dx):prev;prev=tang;
      const wT=sm(g/560)*(1-sm((g-880)/360));yw.push([g,th+(tang-th)*wT,'l']);}
    const R0=1450,R1=3600;let prev2=yw[yw.length-1][1];
    for(let g=R0;g<=R1+500;g+=40){const u=clamp((g-R0-550)/(R1-R0-550),0,1),th=TH1*(1-mixu(u)),r=r1+(r0-r1)*sm(u),p=pos(th,r);bx.push([g,p[0],'l']);bz.push([g,p[1],'l']);
      const un=clamp((g+40-R0-550)/(R1-R0-550),0,1),pn=pos(TH1*(1-mixu(un)),r1+(r0-r1)*sm(un)),dx=pn[0]-p[0],dz=pn[1]-p[1],sp=Math.hypot(dx,dz)/.04;
      const tang=sp>.1?Math.atan2(-dz,dx):prev2;prev2=tang;const wT=sm((g-R0)/950)*(1-sm((g-(R1-500))/700));
      yw.push([g,th+(tang-th)*wT,'l']);}
    const bobK=[];for(let t=200;t<=1100;t+=200)bobK.push(t);
    VERSIONS.push(finish(SPEC('dance','circle','Circle dance','trots an arc round the target, a footfall on every beat subdivision, then turns in place to face it; it walks back while the target reacts',{
      sig:'-by',pre:800,
      ch:{bx:norm(bx),bz:norm(bz),yaw:norm(yw),by:plus([[0,0],[4000,0]],bumps(bobK,-.022,0,70,110).filter(k=>k[0]>-100&&k[0]<1300)),pitch:[[0,0],[100,.04,'s'],[1000,.04],[1300,0,'s']],
        hd:[[0,[0,0,0]],[200,[.03,.02,0],'s'],[1000,[.03,.02,0]],[1300,[0,0,0],'s']],tailY:wig(100,1100,.4,3.3,100,0),tailP:[[0,0],[200,.3,'s'],[1200,.3],[1600,0,'s']],chest:bumps(bobK,.5,.1,70,110),crest:[[0,0],[300,.4,'s'],[1300,.4],[1700,0,'s']]},
      fx:[{t:200,x:-.25,z:.1,n:5,s:.7},{t:600,x:.1,z:.6,n:5,s:.7},{t:1000,x:.2,z:1.1,n:5,s:.7}],
      tchg:{earL:[[0,0],[500,.12,'s'],[1200,.2]],earR:[[0,0],[500,.12,'s'],[1200,.2]]},
      make(f,s){const chg={bx:shiftKeys(s.ch.bx,-s.pre),bz:shiftKeys(s.ch.bz,-s.pre),yaw:shiftKeys(s.ch.yaw,-s.pre)};
        walk(f,chg,60,1100,400,{sw:.35,h:.07,look:.3});walk(f,chg,R0,R1,380,{sw:.34,h:.05,look:.3});}
    })));
  })();
  // 4 bob-and-weave: crouched, body dips on every 300 ms and weaves left-right, tail and head counter-swing
  const bw=[];for(let t=200;t<=1100;t+=300)bw.push(t);
  VERSIONS.push(finish(SPEC('dance','weave','Bob and weave','sinks and sways like a boxer, a dip on every 300 ms, tail and head swing against the body, feet planted',{
    sig:'-by',pre:800,
    ch:{by:norm((()=>{const o=[];for(let t=0;t<=1500;t+=25){const e=Math.min(1,t/200,(1500-t)/300);o.push([t,-.012*e-.045*e*(.5+.5*Math.cos(2*Math.PI*(t-200)/300)),'l']);}return o;})()),
      bz:wig(0,1500,.055,1.667,200,0),yaw:wig(0,1500,.13,1.667,200,0,Math.PI/2),roll:wig(0,1500,.07,1.667,200,0,Math.PI),tailY:wig(0,1500,.65,1.667,150,0,.9),tailP:[[0,0],[300,.25,'s'],[1300,.25],[1600,0,'s']],
      pitch:(()=>{const o=[];for(let t=0;t<=1500;t+=25){const e=Math.min(1,t/200,(1500-t)/300);o.push([t,.035*e*(.5+.5*Math.cos(2*Math.PI*(t-200)/300)),'l']);}return o;})(),
      hyaw:wig(0,1500,-.28,1.667,200,0,Math.PI/2),hd:[[0,[0,0,0]],[250,[.02,-.03,0],'s'],[1300,[.02,-.03,0]],[1600,[0,0,0],'s']],chest:bumps(bw,.5,.1,80,160),crest:[[0,0],[300,.4,'s'],[1300,.4],[1600,0,'s']]},
    tchg:{earL:[[0,0],[500,.12,'s'],[1200,.2]],earR:[[0,0],[500,.12,'s'],[1200,.2]]},
    make(f){}
  })));
})();
// ================================================================= CHARM (W 100, A 600, R 200; beat at g 100, success at g 700)
(function(){
  // 1 offer food: it picks a fruit in the lead-in (bow), walks forward, sets the fruit down in front of the target, backs off
  const walkIn=[[-1700,0],[-704,0],[600,1.05,'s'],[1500,1.05],[3000,0,'s'],[3600,0]];
  VERSIONS.push(finish(SPEC('charm','offer','Offer food','bows to pick a fruit with the beak, walks up and sets it down in front of the target, then backs off politely',{
    sig:'chest',pre:1700,W:100,
    ch:{bx:walkIn,
      by:norm([[-1700,0],[-1500,0],[-1350,-.14,'s'],[-1100,-.14],[-800,0,'s'],[0,0],[400,-.0],[520,-.12,'s'],[650,-.14],[900,-.14],[1150,0,'s'],[4000,0]]),
      pitch:norm([[-1700,0],[-1500,0],[-1330,.32,'s'],[-1100,.32],[-800,0,'s'],[420,0],[520,.3,'s'],[900,.3],[1150,0,'s'],[4000,0]]),sp:norm([[-1700,0],[-1500,0],[-1330,.18,'s'],[-1100,.18],[-800,0,'s'],[420,0],[520,.14,'s'],[900,.14],[1150,0,'s']]),
      hd:norm([[-1700,[0,0,0]],[-1500,[0,0,0]],[-1330,[.1,-.22,0],'s'],[-1100,[.1,-.22,0]],[-800,[0,.03,0],'s'],[0,[0,.03,0]],[100,[0,.06,0],'s'],[440,[0,.06,0],'s'],[600,[.05,-.2,0],'s'],[900,[.05,-.2,0]],[1200,[0,0,0],'s']]),
      hp:norm([[-1700,0],[-1500,0],[-1330,.5,'s'],[-1100,.5],[-800,-.1,'s'],[100,-.1],[560,.25,'s'],[900,.3],[1200,0,'s']]),
      gape:norm([[-1700,0],[-1260,0],[-1200,.5,'o'],[-1120,.05,'i2'],[-1090,0],[560,0],[620,.4,'o'],[860,.5],[960,0,'i2'],[4000,0]]),
      tailY:wig(-600,1200,.15,2,100,0),tailP:[[0,0],[100,.1,'s'],[1000,.1],[1200,0,'s']],chest:bumps([100],.6,.1,50,300)},
    prop:{ground:[.58,.05],carry:[-1120,640],put:[1.82,.0],take:1100},
    fx:[{t:-1200,x:.5,z:.05,n:4,s:.6},{t:640,x:1.8,z:.0,n:4,s:.6}],
    tstep:{dt:500,d:.55},
    tchg:{earL:[[0,0],[300,.12,'s'],[700,.18]],earR:[[0,0],[300,.12,'s'],[700,.18]]},
    treact:(u,P,ver)=>{ // after the step it lowers the long neck to the fruit, takes it and lifts its head
      const e=sm((u-.9)/.5)*(1-sm((u-1.8)/.6));P.nup-=.78*e;P.nfwd+=.12*e;P.by-=.1*e;P.hp+=.5*e;P.pitch+=.1*e;P.jaw+=.4*sm((u-1.4)/.2)*(1-sm((u-1.7)/.2));},
    make(f,s){const c={bx:norm(walkIn.map(k=>k.slice()))};walk(f,c,-704,600,600,{sw:.34,h:.06});walk(f,c,1500,3000,700,{sw:.32,h:.05});}
  })));
  // 2 nuzzle: slow approach along the target's near side, head rub up and down its neck
  const pa=[[-1700,0],[-1600,0],[200,1.62,'s'],[1500,1.62],[3300,0,'s'],[3800,0]],pz=[[-1700,0],[-1600,0],[0,.36,'s'],[1500,.36],[2800,0,'s'],[3800,0]],py=[[-1700,0],[-1600,0],[400,.12,'s'],[1500,.12],[2800,0,'s'],[3200,0]];
  VERSIONS.push(finish(SPEC('charm','nuzzle','Nuzzle','a slow approach along the target\'s side, then the head rubs up and down its neck with a little roll, eyes soft',{
    sig:'hd1',pre:1700,W:100,
    ch:{bx:pa,bz:pz,yaw:py,
      by:[[0,0],[200,0],[500,.012,'s'],[1500,.012],[2000,0,'s']],pitch:[[0,0],[100,-.1,'s'],[1500,-.1],[2000,0,'s']],
      hd:norm([[-1700,[0,0,0]],[-300,[0,0,0]],[100,[.04,.05,-.05],'s'],[400,[.04,-.03,-.05],'s'],[700,[.04,.05,-.05],'s'],[1000,[.04,-.03,-.05],'s'],[1300,[.04,.04,-.05],'s'],[1700,[0,0,0],'s']]),
      hyaw:[[-1700,0],[-300,0],[100,-.42,'s'],[1400,-.42],[1800,0,'s']],hroll:norm([[-1700,0],[100,0],[250,.3,'s'],[550,-.25,'s'],[850,.3,'s'],[1100,-.1,'s'],[1500,-.1],[1900,0,'s']]),hp:[[0,0],[100,-.18,'s'],[1500,-.18],[1900,0,'s']],
      gape:[[0,0],[300,.12,'s'],[1500,.12],[1900,0,'s']],chest:[[0,0],[400,.3,'s'],[1500,.3],[2000,0,'s']],tailY:wig(200,1700,.28,1.7,200,0),tailP:[[0,0],[300,.1,'s'],[1600,.1],[2000,0,'s']],stretch:[[0,1],[100,1.12,'s'],[1600,1.12],[2000,1,'s']]},
    tstep:null,fx:[],
    tchg:{earL:[[0,0],[300,.12,'s'],[700,.18]],earR:[[0,0],[300,.12,'s'],[700,.18]]},
    treact:(u,P)=>{P.nup-=.06*sm(u/.3)*(1-sm((u-2)/1));P.roll+=.04*sm(u/.4)*(1-sm((u-2)/1));P.hyaw+=.18*sm(u/.3)*(1-sm((u-2)/1));},
    make(f,s){const c={bx:norm(pa.map(k=>k.slice())),bz:norm(pz.map(k=>k.slice())),yaw:norm(py.map(k=>k.slice()))};walk(f,c,-1600,200,650,{sw:.34,h:.05});walk(f,c,1500,3300,650,{sw:.32,h:.05});}
  })));
  // 3 preen and show-off: fluffs up, quivers, crest and tail up, a slow turn to show the flank, holds, turns back
  const PSI=-1.1;
  VERSIONS.push(finish(SPEC('charm','preen','Preen and show off','puffs the body up, a quick shiver, crest and tail up, then a slow turn to show off its flank before settling again',{
    sig:'chest',pre:800,W:100,
    ch:{chest:norm([[-100,0],[0,.1],[100,.9,'o'],[240,.45,'s'],[400,1,'o'],[1700,1],[2200,0,'s']]),crest:[[0,0],[300,1,'o'],[1700,1],[2200,0,'s']],roll:cat([[0,0]],wig(100,330,.06,13,40,0),[[2200,0]]),
      tailP:[[0,0],[300,.9,'o'],[1700,.9],[2200,0,'s']],tailY:cat([[0,0],[300,0]],wig(350,1700,.25,2.2,200,0),[[2200,0]]),hd:[[0,[0,0,0]],[300,[-.03,.07,0],'s'],[1700,[-.03,.07,0]],[2200,[0,0,0],'s']],hp:[[0,0],[300,-.22,'s'],[1700,-.22],[2200,0,'s']],
      pitch:[[0,0],[300,-.05,'s'],[1700,-.05],[2200,0,'s']],stretch:[[0,1],[300,1.08,'s'],[1700,1.08],[2200,1,'s']],by:plus([[0,0],[2400,0]],bumps([100,400],.02,0,60,160).filter(k=>k[0]>-100&&k[0]<1000)),
      yaw:[[0,0],[350,0],[700,PSI,'s'],[1650,PSI],[2150,0,'s']],hyaw:[[0,0],[700,.25,'s'],[1650,.25],[2150,0,'s']]},
    fx:[{t:380,x:-.1,z:.2,n:4,s:.6},{t:500,x:.2,z:-.2,n:4,s:.6}],
    tchg:{earL:[[0,0],[300,.15,'s'],[700,.2]],earR:[[0,0],[300,.15,'s'],[700,.2]]},
    make(f){const sg=(t,phi)=>stage(f,t,phi,110);sg(380,PSI*.5);sg(540,PSI);sg(1700,PSI*.5);sg(1860,0);}
  })));
  // 4 play bow: front down, rear up, tail wag, two small bounces, mouth open and eyes on the target
  const bo=[400,700];
  VERSIONS.push(finish(SPEC('charm','bow','Play bow','forelegs drop, rear stays up, tail wags fast, two small bounces and a soft open mouth: an invitation to play',{
    sig:'pitch',pre:800,W:100,
    ch:{pitch:plus([[0,0],[100,.33,'o'],[240,.27,'s'],[900,.27],[1300,0,'s']],bumps(bo,.04,0,70,150).filter(k=>k[0]>-100&&k[0]<1400)),by:plus([[0,0],[100,-.06,'o'],[900,-.06],[1300,0,'s']],bumps(bo,-.025,0,70,150).filter(k=>k[0]>-100&&k[0]<1400)),
      sp:[[0,0],[100,.1,'o'],[900,.1],[1300,0,'s']],bx:plus([[0,0],[1400,0]],bumps(bo,.03,0,60,160).filter(k=>k[0]>-100&&k[0]<1400)),hd:[[0,[0,0,0]],[100,[.02,.09,0],'s'],[900,[.02,.09,0]],[1300,[0,0,0],'s']],hp:[[0,0],[100,-.38,'s'],[900,-.38],[1300,0,'s']],
      gape:plus([[0,0],[120,.4,'s'],[900,.4],[1200,0,'s']],wig(300,900,.08,4,100,0)),tailY:wig(60,1300,.75,8.5,60,0),tailP:[[0,0],[100,.55,'o'],[900,.55],[1300,0,'s']],chest:bumps(bo,.4,.1,60,140),crest:[[0,0],[200,.6,'s'],[1000,.6],[1400,0,'s']],stretch:[[0,1],[100,1.07,'s'],[900,1.07],[1300,1,'s']]},
    fx:[{t:400,x:.3,z:-.16,n:4,s:.6},{t:400,x:.3,z:.16,n:4,s:.6},{t:700,x:.3,z:-.16,n:4,s:.6},{t:700,x:.3,z:.16,n:4,s:.6}],
    tchg:{earL:[[0,0],[300,.2,'s'],[700,.25]],earR:[[0,0],[300,.2,'s'],[700,.25]]},
    make(f){}
  })));
})();
// ================================================================= POSE (W 400, A 800, R 200; beat at g 400, success at g 1200)
(function(){
  VERSIONS.push(finish(SPEC('pose','crest','Crest display','the crest snaps up on the beat and flushes, chest out, head pulled back, a crest quiver on 700 and 1000, then it holds',{
    sig:'crest',pre:800,
    ch:{crest:norm([[-100,0],[0,0],[250,.4,'s'],[400,1,'i2'],[560,1],[700,.76,'o'],[740,1,'o'],[1000,.76,'o'],[1040,1,'o'],[1700,1],[2200,0,'s']]),chest:[[0,0],[250,.3,'s'],[400,1,'o'],[1700,1],[2200,0,'s']],
      hd:[[0,[0,0,0]],[400,[-.05,.07,0],'s'],[1700,[-.05,.07,0]],[2200,[0,0,0],'s']],hp:[[0,0],[400,-.16,'s'],[1700,-.16],[2200,0,'s']],pitch:[[0,0],[400,-.07,'s'],[1700,-.07],[2200,0,'s']],sp:[[0,0],[400,-.05,'s'],[1700,-.05],[2200,0,'s']],
      stretch:[[0,1],[400,1.07,'s'],[1700,1.07],[2200,1,'s']],by:[[0,0],[400,.02,'s'],[1700,.02],[2200,0,'s']],thr:[[0,0],[400,.3,'s'],[1700,.2],[2200,0,'s']],tailP:[[0,0],[400,.25,'s'],[1700,.25],[2200,0,'s']]},
    pulses:[],fx:[],tchg:{earL:[[0,0],[500,.15,'s'],[1200,.25]],earR:[[0,0],[500,.15,'s'],[1200,.25]]},make(f){}
  })));
  VERSIONS.push(finish(SPEC('pose','tall','Stand tall','rises slowly onto straight legs, neck and head stretched high, then holds absolutely still (only the breath moves)',{
    sig:'by',pre:800,
    ch:{by:[[0,0],[150,0],[470,.045,'s'],[1700,.045],[2300,0,'s']],stretch:[[0,1],[150,1],[470,1.2,'s'],[1700,1.2],[2300,1,'s']],hd:[[0,[0,0,0]],[400,[-.02,.09,0],'o'],[1700,[-.02,.09,0]],[2300,[0,0,0],'s']],hp:[[0,0],[400,-.08,'s'],[1700,-.08],[2300,0,'s']],
      pitch:[[0,0],[400,-.05,'s'],[1700,-.05],[2300,0,'s']],sp:[[0,0],[400,-.04,'s'],[1700,-.04],[2300,0,'s']],tailP:[[0,0],[400,.12,'s'],[1700,.12],[2300,0,'s']],chest:wig(500,1700,.06,.5,200,.3),crest:[[0,0],[400,.25,'s'],[1700,.25],[2300,0,'s']]},
    tchg:{earL:[[0,0],[500,.15,'s'],[1200,.25]],earR:[[0,0],[500,.15,'s'],[1200,.25]]},make(f){}
  })));
  const PS=-1.25;
  VERSIONS.push(finish(SPEC('pose','side','Side-on display','two quick double-steps turn it flank-on to the target, tail lifted, crest half up, freeze',{
    sig:'-yaw',pre:800,
    ch:{yaw:[[0,0],[100,0],[460,PS,'s'],[1700,PS],[2150,0,'s']],tailP:[[0,0],[300,.2,'s'],[400,.85,'o'],[1700,.85],[2150,0,'s']],crest:[[0,0],[400,.8,'s'],[1700,.8],[2150,0,'s']],chest:[[0,0],[400,.7,'s'],[1700,.7],[2150,0,'s']],
      hd:[[0,[0,0,0]],[400,[-.03,.07,0],'s'],[1700,[-.03,.07,0]],[2150,[0,0,0],'s']],hp:[[0,0],[400,-.2,'s'],[1700,-.2],[2150,0,'s']],hyaw:[[0,0],[400,.9,'s'],[1700,.9],[2150,0,'s']],pitch:[[0,0],[400,-.04,'s'],[1700,-.04],[2150,0,'s']],by:[[0,0],[400,.02,'s'],[1700,.02],[2150,0,'s']],stretch:[[0,1],[400,1.06,'s'],[1700,1.06],[2150,1,'s']]},
    fx:[{t:150,x:.1,z:.2,n:4,s:.6},{t:300,x:-.1,z:-.2,n:4,s:.6}],
    tchg:{earL:[[0,0],[500,.15,'s'],[1200,.25]],earR:[[0,0],[500,.15,'s'],[1200,.25]]},
    make(f){const sg=(t,phi)=>stage(f,t,phi,110);sg(30,PS*.5);sg(190,PS);sg(1700,PS*.5);sg(1850,0);}
  })));
  // 4 mirror pose: the target strikes a sentinel posture (head tilt, one fore foot raised); B copies it as a mirror image, arriving on the beat
  VERSIONS.push(finish(SPEC('pose','mirror','Mirror pose','copies the target: when it tilts its head and raises a foreleg, B does the mirror image about 250 ms later, arriving on the beat',{
    sig:'-hroll',pre:800,
    ch:{hroll:[[0,0],[150,0],[430,-.36,'s'],[1700,-.36],[2200,0,'s']],hd:[[0,[0,0,0]],[130,[0,0,0]],[400,[-.02,.08,0],'s'],[1700,[-.02,.08,0]],[2200,[0,0,0],'s']],hp:[[0,0],[400,-.1,'s'],[1700,-.1],[2200,0,'s']],by:[[0,0],[400,.02,'s'],[1700,.02],[2200,0,'s']],stretch:[[0,1],[400,1.1,'s'],[1700,1.1],[2200,1,'s']],
      roll:[[0,0],[130,0],[400,.04,'s'],[1700,.04],[2200,0,'s']],crest:[[0,0],[400,.4,'s'],[1700,.4],[2200,0,'s']],chest:[[0,0],[400,.4,'s'],[1700,.4],[2200,0,'s']]},
    tchg:{hroll:[[-300,0],[-100,.36,'o'],[1150,.36],[1350,0,'s']],nup:[[-300,0],[-100,.1,'s'],[1150,.1],[1350,0,'s']],earL:[[0,0],[100,.12,'s'],[1100,.18]],earR:[[0,0],[100,.12,'s'],[1100,.18]]},
    tmake(tf,s){tf[FL].lift(s.pre-100,s.pre+1150,.2,160);},
    make(f){f[FR].lift(130,1400,.14,200);}
  })));
})();
// ---------------------------------------------------------------- check
function pickSig(name,P,sk){if(name[0]==='-')return -pickSig(name.slice(1),P,sk);if(name==='hd1')return P.hd[1];return P[name];}
function check(){
  const fails=[],rows=[];
  for(const ver of VERSIONS){
    const r={id:ver.id,act:ver.act,name:ver.name},F=m=>fails.push(`${ver.id}: ${m}`);
    r.W=ver.W;r.A=ver.A;r.R=ver.R;r.beatTickMs=ver.tb;r.successMs=ver.ts;r.endMs=ver.endReal;
    // B: feet planted, reach, ground
    let drift=0,maxErr=0,minY=9,maxStretch=0;const samp=[];for(let a=0;a<=ver.endReal;a+=4)samp.push([a,skel(ver,poseAt(ver,a),true)]);
    for(let i=0;i<4;i++)for(const s of ver.segs[i])if(s.k==='p'&&s.t1-s.t0>30){let p0=null;
      for(const [a,sk] of samp)if(a>=s.t0+2&&a<=s.t1-2){if(!p0)p0=sk.feet[i].clone();drift=Math.max(drift,sk.feet[i].distanceTo(p0),sk.feet[i].distanceTo(sk.targets[i]));}}
    for(const [a,sk] of samp){maxErr=Math.max(maxErr,sk.legErr,sk.neckErr);maxStretch=Math.max(maxStretch,sk.stretch);
      sk.nodes.forEach((n,i)=>{if(i<7)minY=Math.min(minY,n.y-REST.nodes[i][2]*.9);});sk.knees.forEach(k=>minY=Math.min(minY,k.y-.02));sk.feet.forEach(f=>minY=Math.min(minY,f.y-.03));minY=Math.min(minY,sk.tip.y,sk.head.y-REST.hr*.9);}
    r.plantedDriftCm=+(drift*100).toFixed(2);r.reachErrCm=+(maxErr*100).toFixed(2);r.minYCm=+(minY*100).toFixed(2);r.neckStretch=+maxStretch.toFixed(3);
    if(drift>.02)F(`planted foot drift ${(drift*100).toFixed(1)} cm`);if(maxErr>.02)F(`IK out of reach by ${(maxErr*100).toFixed(1)} cm`);if(minY<-.012)F(`geometry ${(minY*100).toFixed(1)} cm below ground`);if(maxStretch>1.24)F(`neck stretch ${maxStretch.toFixed(2)}`);
    // slide of planted feet between consecutive samples while planted (no slide < 2 cm)
    // target: feet, ground, reach
    let tdrift=0,tErr=0,tMinY=9;const ts_=[];for(let a=0;a<=ver.endReal;a+=8)ts_.push([a,tskel(ver,a)]);
    for(let i=0;i<4;i++)for(const s of ver.tsegs[i])if(s.k==='p'&&s.t1-s.t0>30){let p0=null;for(const [a,sk] of ts_)if(a>=s.t0+2&&a<=s.t1-2){if(!p0)p0=sk.feet[i].clone();tdrift=Math.max(tdrift,sk.feet[i].distanceTo(p0),sk.feet[i].distanceTo(sk.targets[i]));}}
    for(const [a,sk] of ts_){tErr=Math.max(tErr,sk.legErr,sk.neckErr);sk.feet.forEach(f=>tMinY=Math.min(tMinY,f.y));tMinY=Math.min(tMinY,sk.tip.y);}
    r.targetDriftCm=+(tdrift*100).toFixed(2);r.targetReachErrCm=+(tErr*100).toFixed(2);r.targetMinYCm=+(tMinY*100).toFixed(2);
    if(tdrift>.02)F(`target planted foot drift ${(tdrift*100).toFixed(1)} cm`);if(tErr>.03)F(`target IK out of reach by ${(tErr*100).toFixed(1)} cm`);if(tMinY<-.01)F('target geometry below ground');
    // reaction fires on the success frame: ears below .6 before, above .9 within 150 ms after; the pre-success part never fires it
    let preMax=0,tHit=null;for(let a=ver.ts-400;a<ver.ts;a+=4)preMax=Math.max(preMax,tparams(ver,a).earL);for(let a=ver.ts;a<=ver.ts+600;a+=4){if(tparams(ver,a).earL>=.9){tHit=a-ver.ts;break;}}
    r.earBeforeSuccess=+preMax.toFixed(2);r.earReachedAfterMs=tHit;
    if(preMax>.7)F(`target ears already at ${preMax.toFixed(2)} before success`);if(tHit===null||tHit>150)F(`target ears not up within 150 ms of success (${tHit})`);
    if(tparams(ver,ver.ts-1).react)F('react flag set before success');
    const dS=ver.tstep===null?0:(ver.tstep&&ver.tstep.d)||.5;let moved=0;for(const [a,sk] of ts_)moved=Math.max(moved,sk.P.bx);r.targetStepM=+moved.toFixed(2);if(ver.tstep!==null&&moved<.4)F(`target stepped only ${moved.toFixed(2)} m`);
    // hit-time timing: reaction onset must not precede success by more than the lead-in
    // beat alignment: peaks of the version's signal
    const ev=[];{const a0=ver.pre-100,a1=ver.ts;const xs=[];for(let a=a0;a<=a1;a+=4){const P=poseAt(ver,a);xs.push([a,pickSig(ver.sig,P)]);}
      const vs=xs.map(q=>q[1]),mn=Math.min(...vs),mx=Math.max(...vs),rg=mx-mn;
      if(rg<1e-6)F('beat signal is flat');else{
        for(let i=2;i<xs.length-2;i++){if(xs[i][1]>=xs[i-1][1]&&xs[i][1]>xs[i+1][1]&&xs[i][1]-mn>.55*rg&&(ev.length===0||xs[i][0]-ev[ev.length-1]>120))ev.push(xs[i][0]);}
        const hi=xs.find(q=>q[1]>=mn+.9*rg);if(hi&&(ev.length===0||hi[0]<ev[0]-100))ev.unshift(hi[0]);}}
    const rel=ev.map(t=>t-ver.tb);r.accentsRelBeatMs=rel.map(Math.round);
    if(!rel.length)F('no accent found');else{if(Math.abs(rel[0])>60)F(`first accent ${rel[0]} ms from the beat (limit 60)`);
      for(const q of rel){const best=Math.min(...[200,300,400,600].map(s=>Math.abs(q-Math.round(q/s)*s)));if(best>60)F(`accent ${q} ms off the beat subdivisions (limit 60)`);}}
    r.windowMs=WIN;r.beatMs=BEAT;
    // loop: B and target end where they began
    const p0=poseAt(ver,0),p1=poseAt(ver,ver.endReal);const dB=Math.hypot(p1.bx-p0.bx,p1.bz-p0.bz);const dy=Math.abs(Math.atan2(Math.sin(p1.yaw-p0.yaw),Math.cos(p1.yaw-p0.yaw)));r.loopBodyCm=+(dB*100).toFixed(1);r.loopYawRad=+dy.toFixed(3);
    if(dB>.03||dy>.05)F(`loop not clean: body off ${(dB*100).toFixed(1)} cm / yaw ${dy.toFixed(2)}`);
    const k0=skel(ver,p0,true),k1=skel(ver,p1,true);let fl=0;for(let i=0;i<4;i++)fl=Math.max(fl,k0.feet[i].distanceTo(k1.feet[i]));r.loopFootCm=+(fl*100).toFixed(1);if(fl>.04)F(`loop: a foot ends ${(fl*100).toFixed(1)} cm from where it began`);
    const t0s=tskel(ver,0),t1s=tskel(ver,ver.endReal);let tf=0;for(let i=0;i<4;i++)tf=Math.max(tf,t0s.feet[i].distanceTo(t1s.feet[i]));r.loopTargetFootCm=+(tf*100).toFixed(1);if(tf>.04)F(`loop: target foot ends ${(tf*100).toFixed(1)} cm away`);
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.BEFRIENDCORE={T,REST,VERSIONS,GAME,BEAT,WIN,TX,skel,poseAt,tskel,tparams,check,FOOT_REST,TL};
})(typeof window!=='undefined'?window:globalThis);
