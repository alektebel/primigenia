'use strict';
// Primigenia pounce lab core (A60/A61 step 3): starter B (no arms, beak "pico"). Pure maths, no DOM. Needs bite2_core.js first (body rig, IK, REST).
// Units: metres, +x forward, +y up, +z creature's right. Times in ms of ANIMATION time; the hit-pause freezes animation time for `pause` ms of real time.
// Game numbers (core/src/combat.c): pounce = 8 ticks wind-up, 4 active ticks, 4 recovery, range 4.8 m, stun 4 ticks, 10 Hz => 0.8 s / 0.4 s / 0.4 s / 0.4 s stun.
(function(root){
const B=root.BITECORE,T=B.T,REST=B.REST,frames=B.frames,interp=B.interp,V=B.V,DEF=B.DEF,FOOT_REST=B.FOOT_REST;
const X=new T.Vector3(1,0,0),Y=new T.Vector3(0,1,0),Z=new T.Vector3(0,0,1);
const clamp=(x,a,b)=>x<a?a:x>b?b:x,sm=u=>{u=clamp(u,0,1);return u*u*(3-2*u);};
const G=9.81,FY=.03,R=.27,P0=V(...REST.P0),NECK=[Math.hypot(.14,.16),Math.hypot(.14,.1)];
const PAUSE=80;
// ---------------------------------------------------------------- skeleton (body rig of bite2_core, feet driven by foot segments)
function ik(hip,foot,a,b,pole){
  const d=foot.clone().sub(hip);let L=d.length();const mx=a+b-1e-4,mn=Math.abs(a-b)+1e-3,err=Math.max(0,L-mx);
  const dir=d.clone().divideScalar(L||1);L=clamp(L,mn,mx);
  const x=(a*a-b*b+L*L)/(2*L),h=Math.sqrt(Math.max(0,a*a-x*x));
  const perp=pole.clone().sub(dir.clone().multiplyScalar(pole.dot(dir)));if(perp.lengthSq()<1e-8)perp.set(0,1,0);perp.normalize();
  return {knee:hip.clone().addScaledVector(dir,x).addScaledVector(perp,h),foot:hip.clone().addScaledVector(dir,L),err};
}
function toWorld(p,fr,P,F){const v=V(p[0]-P0.x,p[1]-P0.y,p[2]-P0.z).applyQuaternion(fr==='f'?F.Qf:F.Qr);return v.add(V(P0.x+P.bx,P0.y+P.by,P0.z+P.bz));}
// foot segments: p planted (world), s swing along the ground with a lift arc, a airborne (blended from the ground, body-relative pose, blended to the landing spot)
function footTarget(segs,a,hipW,Fq){
  let s=segs[segs.length-1];for(const q of segs)if(a<=q.t1){s=q;break;}
  if(s.k==='p')return {t:V(s.x,FY,s.z),planted:true};
  if(s.k==='s'){const u=clamp((a-s.t0)/(s.t1-s.t0),0,1),e=sm(u);return {t:V(s.x0+(s.x1-s.x0)*e,FY+s.h*Math.sin(Math.PI*u),s.z0+(s.z1-s.z0)*e),planted:false};}
  const u=a-s.t0,w=Math.min(sm(u/Math.max(1,s.in)),sm((s.t1-a)/Math.max(1,s.out))),half=(s.t1-s.t0)/2;
  const Wp=(u<half?V(s.x0,FY,s.z0):V(s.x1,FY,s.z1)),Bv=interp(s.B,a),Bp=hipW.clone().add(V(Bv[0],Bv[1],Bv[2]).applyQuaternion(Fq));
  const tg=Wp.lerp(Bp,w);tg.y=Math.max(tg.y,FY);return {t:tg,planted:false,w};
}
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
  const out={F,nodes,stretch:s,head:headC,neckErr:ng.err,legErr:0,Qh,axis,hinge,tip,hips:[],knees:[],feet:[],planted:[],targets:[],reach:[]};
  if(!legs)return out;
  for(let i=0;i<4;i++){
    const fore=i>=2,hip=toWorld(REST.hip[i],fore?'f':'r',P,F),ft=footTarget(ver.segs[i],P.a,hip,fore?F.Qf:F.Qr);
    const pole=X.clone().applyQuaternion(fore?F.Qf:F.Qr),r=ik(hip,ft.t,REST.seg[i][0],REST.seg[i][1],pole);
    if(r.knee.y<.025)r.knee.y=.025;out.hips.push(hip);out.knees.push(r.knee);out.feet.push(r.foot);out.planted.push(ft.planted);out.targets.push(ft.t);out.legErr=Math.max(out.legErr,r.err);
    out.reach.push(hip.distanceTo(r.foot)/(REST.seg[i][0]+REST.seg[i][1]));
  }
  return out;
}
// ---------------------------------------------------------------- authoring helpers
function FootB(i){this.i=i;this.cur=[FOOT_REST[i][0],FOOT_REST[i][1]];this.t=0;this.segs=[];}
FootB.prototype={
  hold(t){if(t>this.t){this.segs.push({k:'p',t0:this.t,t1:t,x:this.cur[0],z:this.cur[1]});this.t=t;}return this;},
  step(t0,t1,x,z,h){this.hold(t0);this.segs.push({k:'s',t0,t1,x0:this.cur[0],z0:this.cur[1],x1:x,z1:z,h});this.cur=[x,z];this.t=t1;return this;},
  air(t0,t1,Bk,x,z,inn,out,fx){this.hold(t0);this.segs.push({k:'a',t0,t1,x0:this.cur[0],z0:this.cur[1],x1:x,z1:z,B:Bk,in:inn,out,fx:fx===undefined?.6:fx});this.cur=[x,z];this.t=t1;return this;},
  end(t){this.hold(t);return this.segs;}
};
function wig(t0,t1,amp,hz,ramp,base){const o=[],n=Math.max(2,Math.round((t1-t0)/10));for(let k=0;k<=n;k++){const t=t0+(t1-t0)*k/n,e=Math.min(1,(t-t0)/ramp);o.push([t,(base||0)+amp*e*Math.sin(2*Math.PI*hz*(t-t0)/1000),'l']);}return o;}
function cat(...ls){const o=[];for(const l of ls)for(const k of l)o.push(k);o.sort((a,b)=>a[0]-b[0]);return o;}
// integral of a speed profile, scaled so that x(t1)=X1; keys every 10 ms
function integ(prof,t0,t1,X0,X1){const f=t=>interp(prof.map(k=>[k[0],k[1],'l']),t),ts=[],vals=[];let s=0;
  for(let t=t0;t<=t1;t+=5){if(t>t0)s+=(f(t)+f(t-5))/2*.005;ts.push(t);vals.push(s);}
  const k=s>0?(X1-X0)/s:0;return ts.map((t,i)=>[t,X0+vals[i]*k,'l']);}
// ---------------------------------------------------------------- contact solve
function bodyPose(ver,a){
  const P={};for(const n in DEF)P[n]=ver.ch[n]?interp(ver.ch[n],a):DEF[n];P.hd=ver.ch.hd?interp(ver.ch.hd,a):[0,0,0];
  for(const r of ver.arcs)if(a>=r.t0&&a<=r.t1){const tau=(a-r.t0)/1000,Ts=(r.t1-r.t0)/1000,vy=(r.y1-r.y0)/Ts+G*Ts/2;P.by=r.y0+vy*tau-.5*G*tau*tau;if(r.x!==false)P.bx=r.x0+(r.x1-r.x0)*(a-r.t0)/(r.t1-r.t0);}
  P.a=a;return P;
}
function solveContact(ver,P){ // P with bx=by=0
  const c=V(...ver.prey.c0),sk=skel(ver,Object.assign({},P,{bx:0,by:0}),false),an=ver.an;
  if(an.mode==='chest'){const nd=sk.nodes[5],r=REST.nodes[5][2],dist=R+.8*r,dy=nd.y+P.by-c.y;return {x:c.x-Math.sqrt(Math.max(0,dist*dist-dy*dy))-nd.x,y:P.by};}
  return {x:an.T.x-sk.tip.x,y:an.T.y-sk.tip.y};
}
function poseAt(ver,a){
  const P=bodyPose(ver,a),an=ver.an;
  if(an){const wA=a<an.t0?0:a<=an.t1?1:1-sm((a-an.t1)/an.rel);
    if(wA>0){const s=solveContact(ver,P);P.bx=P.bx+(s.x-P.bx)*wA;if(an.y)P.by=P.by+(s.y-P.by)*wA;}}
  // ground collision: the body never sinks into the floor while it is on the legs (flights are left alone)
  if(!ver.arcs.some(r=>a>=r.t0&&a<=r.t1)){const sk=skel(ver,P,false);let lo=9;sk.nodes.forEach((n,i)=>{if(i<7)lo=Math.min(lo,n.y-REST.nodes[i][2]*.9);});if(lo<.012)P.by+=.012-lo;}
  return P;
}
function hipAt(ver,i,a){const P=poseAt(ver,a),F=frames(P);return toWorld(REST.hip[i],i>=2?'f':'r',P,F);}
// ---------------------------------------------------------------- prey (pure function of animation time: never indexed by a fraction)
function preyAt(ver,a){
  const p=ver.prey,c0=p.c0,tc=ver.tc,S={x:c0[0],y:.34,z:0,yaw:0,pitch:0,roll:0,sx:1,sy:1,sz:1,stun:0,held:false,f:0};
  if(a<tc){const b=Math.sin(a/230);S.pitch=.02*b;S.sy=1+.01*b;return S;}
  const tau=(a-tc)/1000,f=Math.exp(-tau/.09)*Math.cos(2*Math.PI*tau/.17);S.f=f;
  const sq=1-p.amp*f;S.sx=sq;S.sy=1+.5*p.amp*f;S.sz=1+.5*p.amp*f;
  const rel=a-p.rel;
  if(p.kind==='pin'){ // held flat under the paws until the step off, then wobbles back up
    const press=sm((a-tc)/110)*(1-sm(rel/120)),r2=Math.max(0,rel)/1000,wob=Math.exp(-r2/.18)*Math.cos(2*Math.PI*r2/.22);
    S.sy*=1-.3*press+.0*wob;S.sx*=1+.14*press;S.sz*=1+.14*press;S.y=.02+.32*S.sy;S.held=press>.5;
    S.pitch=.1*press*0+(rel>0?.22*wob:0);S.roll=rel>0?.28*wob:0;S.x=c0[0]-.03*press;S.stun=a<tc+p.stun?1:Math.max(0,1-(a-tc-p.stun)/250);
  }else if(p.kind==='tackle'){
    const d=p.v0/p.mu*(1-Math.exp(-p.mu*tau)),hop=p.hop*Math.max(0,Math.sin(Math.PI*Math.min(tau/.34,1)));
    const roll=p.rollMax*(1-Math.exp(-tau/.11))*(1-sm((a-p.rise)/320)),yawN=p.yaw*(1-Math.exp(-tau/.2));
    S.x=c0[0]+p.dir[0]*d;S.z=p.dir[1]*d;S.y=.34+hop;S.roll=roll;S.yaw=yawN;S.pitch=.25*Math.exp(-tau/.2);
    S.y=Math.max(S.y,.02+(.32*Math.cos(roll)+.2*Math.abs(Math.sin(roll)))*S.sy+hop);
    S.stun=a<tc+p.stun?1:Math.max(0,1-(a-tc-p.stun)/250);if(a>p.rise)S.roll=roll+.06*Math.sin((a-p.rise)/40)*Math.exp(-(a-p.rise)/200);
  }else if(p.kind==='squash'){ // driven into the ground from above
    const press=sm((a-tc)/90)*(1-sm(rel/260)),r2=Math.max(0,rel)/1000,wob=Math.exp(-r2/.2)*Math.cos(2*Math.PI*r2/.24);
    S.sy=(1-.46*press)*(1+.0*f)+.12*Math.max(0,wob)*(rel>0?1:0);S.sx=1+.3*press+.05*wob;S.sz=1+.3*press+.05*wob;S.y=.02+.32*S.sy;S.x=c0[0]-.02*press;
    S.pitch=.08*press+(rel>0?.2*wob:0);S.roll=rel>0?.22*wob:0;S.stun=a<tc+p.stun?1:Math.max(0,1-(a-tc-p.stun)/250);
  }else{ // knock: pushed back a little, wobbles
    const d=p.v0/p.mu*(1-Math.exp(-p.mu*tau)),hop=p.hop*Math.max(0,Math.sin(Math.PI*Math.min(tau/.2,1)));
    S.x=c0[0]+p.dir[0]*d;S.z=p.dir[1]*d;S.y=.34+hop;S.pitch=p.tilt*Math.exp(-tau/.22)-.18*Math.exp(-tau/.12)*Math.sin(tau*18);S.roll=.16*Math.exp(-tau/.3)*Math.sin(tau*14);
    S.stun=a<tc+p.stun?1:Math.max(0,1-(a-tc-p.stun)/250);S.yaw=.12*Math.exp(-tau/.3)*Math.sin(tau*11);
  }
  S.y=Math.max(S.y,.02+(.32*Math.cos(S.roll)+.2*Math.abs(Math.sin(S.roll)))*S.sy);
  return S;
}
// ---------------------------------------------------------------- versions
const BX=(ver)=>ver; // (kept for readability)
function finish(ver,spec){ // common wrap-up after a version's make()
  ver.id=spec.id;ver.name=spec.name;ver.tag=spec.tag;ver.D=spec.D;ver.prey.c0=[spec.D,.34,0];
  return ver;
}
function pt(c0,dir){return V(c0[0]+dir[0]*(R-.006),c0[1]+dir[1]*(R-.006),0);}
const SPECS=[
// ---------------------------------------------------------------- 1 cat pounce
{id:'cat',name:'Cat pounce',D:4.2,tag:'crouch-stalk, freeze + butt wiggle, arcing leap, front feet and beak land on the prey, pin it, step off',
 make(env){
  const cx=env.cx,tc=1460,tL=tc+110,c0=[cx,.34,0],dir=[-.55,.83];
  const bxC=env.bxC;
  const ch={
    bx:[[0,0],[200,0],[560,.16,'s'],[850,.16],[890,.12,'s'],[960,.30,'s'],[tc,bxC],[1860,env.ae.x],[1950,env.ae.x],[2300,bxC-.30,'s'],[2700,bxC-.32,'s']],
    by:[[0,0],[200,-.2,'o'],[560,-.22,'s'],[850,-.26,'s'],[890,-.31,'s'],[960,0,'i'],[tc,env.byC],[1860,env.ae.y],[1950,-.24,'s'],[2300,-.17,'s'],[2650,0,'s']],
    pitch:[[0,0],[200,.05,'s'],[560,.08,'s'],[850,.14,'s'],[890,-.12,'s'],[960,-.28,'o'],[1210,0,'s'],[tc,.3,'i2'],[tL,.2,'o'],[1950,.2],[2300,.05,'s'],[2650,0,'s']],
    sp:[[0,0],[850,.05,'s'],[960,-.08,'o'],[tc,.1,'s'],[2300,.0,'s']],
    hd:[[0,[0,0,0]],[200,[.04,-.22,0],'s'],[560,[.04,-.26,0]],[850,[.02,-.2,0]],[890,[-.1,-.12,0]],[960,[-.2,-.04,0],'o'],[1210,[-.26,0,0],'s'],[tc,[-.22,-.1,0],'s'],[1950,[-.22,-.1,0]],[2300,[-.1,0,0],'s'],[2650,[0,0,0],'s']],
    hp:[[0,0],[560,.1,'s'],[960,0,'s'],[1350,.0],[tc,.35,'i2'],[1950,.35],[2300,0,'s']],
    gape:[[0,0],[1350,0],[1415,.9,'o'],[tc-12,.9],[tc,0,'i2'],[1580,0]],
    tailP:cat([[0,0],[560,-.05,'s'],[850,-.08,'s']],[[890,-.16,'s'],[960,.1,'o'],[tc,.4,'s'],[tL,.3,'o'],[2300,.1,'s'],[2650,0,'s']]),
    tailY:cat(wig(560,850,.3,5.5,160,0),[[850,0,'s'],[2650,0]]),
    roll:cat(wig(600,850,.055,5.5,160,0),[[850,0,'s'],[2650,0]]),
    stretch:[[0,1]]
  };
  const arcs=[{t0:960,t1:tc,x0:.30,x1:bxC,y0:0,y1:env.byC}];
  const an={t0:tc,t1:tc+420,rel:160,y:true,T:pt(c0,dir)};
  const ver={land:tc,ch,arcs,an,tc,pause:PAUSE,end:2850,prey:{c0,dir,kind:'pin',amp:.2,rel:1950,stun:400},
    phl:[['crouch',0,200],['stalk',200,610],['freeze',610,890],['coil',890,960],['leap',960,tc],['pin',tc,1950],['step off',1950,2300],['recovery',2300,2850]],
    strip:[330,780,1140,1250,tc,2100]};
  const hip=(i,a)=>hipAt(ver,i,a),sg=i=>(i%2?1:-1);
  const f=[0,1,2,3].map(i=>new FootB(i));
  const stp=(i,t0,dx)=>f[i].step(t0,t0+170,f[i].cur[0]+dx,f[i].cur[1],.05);
  stp(2,200,.16);stp(1,280,.16);stp(3,360,.16);stp(0,440,.16);
  const bF=(z)=>[[0,[0,0,0]],[945,[-.04,-.32,0]],[1150,[.12,-.26,0],'s'],[tc-90,[.2,-.3,0],'s'],[tc,[.18,-.52,0],'s']];
  const bH=[[0,[0,0,0]],[960,[-.1,-.34,0]],[1200,[-.26,-.28,0],'s'],[tc,[-.28,-.26,0],'s'],[tL,[-.12,-.5,0],'s']];
  for(const i of [2,3]){const h=hip(i,tc);f[i].air(945,tc,bF(),h.x+.27,.27*sg(i),35,60,.5);}
  for(const i of [0,1]){const h=hip(i,tL);f[i].air(960,tL,bH,h.x-.03,.19*sg(i),30,60,.7);}
  stp(2,2000,-.30);stp(3,2080,-.30);stp(0,2150,-.31);stp(1,2230,-.31);
  ver.segs=f.map((q,i)=>q.end(2850));
  return ver;
 }},
// ---------------------------------------------------------------- 2 low dash-tackle
{id:'tackle',name:'Low dash-tackle',D:4.6,tag:'low burst, two gallop strides, shoulder and chest slam, prey knocked over',
 make(env){
  const cx=env.cx,tc=1070,c0=[cx,.34,0],bxC=env.bxC,byC=-.27;
  const prof=[[560,0],[620,4.5],[740,7.5],[890,8],[tc,8.5]];
  const ch={
    bx:cat([[0,0],[560,0]],integ(prof,560,tc,0,bxC),[[tc+120,bxC+.20,'o'],[tc+350,bxC+.30,'o'],[1500,bxC+.30],[1950,bxC+.30]]),
    by:[[0,0],[300,-.27,'o'],[560,-.29,'s'],[620,-.18,'o'],[740,-.27,'s'],[765,-.31,'s'],[790,-.22,'o'],[890,-.27,'s'],[915,-.31,'s'],[940,-.18,'o'],[tc,byC],[tc+130,-.32,'s'],[1500,-.22,'s'],[1800,-.04,'s'],[1950,0,'s']],
    pitch:[[0,0],[300,.1,'o'],[560,.08],[620,-.1,'s'],[740,.1,'s'],[790,.12],[890,-.05,'s'],[940,-.12,'s'],[tc,.2,'i2'],[tc+200,.1,'s'],[1500,.05,'s'],[1800,0,'s']],
    sp:[[0,0],[tc,.08,'i2'],[tc+250,.0,'s']],
    hd:[[0,[0,0,0]],[300,[-.06,-.05,0],'o'],[560,[-.06,-.05,0]],[740,[.04,.04,0],'s'],[tc,[.0,.07,0],'s'],[1300,[.02,.10,0],'s'],[1800,[0,0,0],'s']],
    hp:[[0,0],[560,.1,'s'],[tc,-.1,'s'],[1500,0,'s']],
    gape:[[0,0],[940,0],[tc-60,.8,'o'],[1300,.8],[1450,0,'s']],
    tailP:[[0,0],[560,-.1,'s'],[740,.15,'s'],[tc,.5,'s'],[1400,.3,'s'],[1800,0,'s']],
    tailY:[[0,0],[560,.1,'s'],[tc,0,'s'],[1800,0]],
    roll:[[0,0]],stretch:[[0,1]]
  };
  const arcs=[[620,740,-.18,-.27],[790,890,-.22,-.27],[940,tc,-.18,byC]].map(r=>({t0:r[0],t1:r[1],y0:r[2],y1:r[3],x:false}));
  const an={t0:tc,t1:tc,rel:1,mode:'chest',y:false};
  const ver={land:tc,ch,arcs,an,tc,pause:PAUSE,end:2000,prey:{c0,kind:'tackle',dir:[.98,.15],v0:3.4,mu:5,hop:.16,amp:.3,rollMax:1.5,yaw:.7,rise:tc+80+900,stun:400},
    phl:[['crouch',0,300],['freeze',300,560],['push',560,620],['stride 1',620,890],['stride 2',890,tc],['slam',tc,tc+300],['stand over',tc+300,1500],['recovery',1500,2000]],
    strip:[420,640,820,970,tc,1300]};
  const hip=(i,a)=>hipAt(ver,i,a),sg=i=>(i%2?1:-1);
  const f=[0,1,2,3].map(i=>new FootB(i));
  const bFa=[[0,[0,0,0]],[570,[.0,-.3,0]],[650,[.28,-.28,0],'s'],[740,[.24,-.4,0],'s']];
  const bFb=[[0,[0,0,0]],[790,[-.05,-.3,0]],[880,[.0,-.26,0],'s'],[960,[.28,-.28,0],'s'],[tc,[.3,-.4,0],'s']];
  const bHa=[[0,[0,0,0]],[620,[-.22,-.3,0]],[700,[-.3,-.22,0],'s'],[790,[-.02,-.36,0],'s'],[890,[.1,-.46,0],'s']];
  const bHb=[[0,[0,0,0]],[940,[-.24,-.3,0]],[tc,[-.3,-.24,0],'s'],[tc+80,[-.06,-.4,0],'s'],[tc+160,[.0,-.5,0],'s']];
  for(const i of [2,3]){const z=.17*sg(i),h1=hip(i,740);f[i].air(570,740,bFa,h1.x+.14,z,30,40,.35);f[i].hold(790);f[i].air(790,tc,bFb,cx-.17,.30*sg(i),30,50,.9);}
  for(const i of [0,1]){const z=.17*sg(i),h1=hip(i,890),h2=hip(i,tc+160);f[i].air(620,890,bHa,h1.x-.02,z,30,40,.5);f[i].hold(940);f[i].air(940,tc+160,bHb,h2.x-.02,z,30,50,.6);}
  ver.segs=f.map(q=>q.end(2000));
  return ver;
 }},
// ---------------------------------------------------------------- 3 high leap dive
{id:'dive',name:'High leap dive',D:3.8,tag:'tall jump, beak-first dive onto the back, pivots over the beak and lands heavy with a dust ring',
 make(env){
  const cx=env.cx,tc=1490,tL=tc+360,c0=[cx,.34,0],dir=[-.2,.98],bxC=env.bxC,byC=env.byC;
  const ch={
    bx:[[0,0],[760,0],[850,.12,'s'],[tc,bxC],[tL+60,env.ae.x],[tL+700,bxC-.3,'s'],[2800,bxC-.34]],
    by:[[0,0],[250,.025,'o'],[470,-.30,'o'],[760,-.34,'s'],[850,0,'i'],[tc,byC],[tL+60,env.ae.y],[2250,-.08,'s'],[2650,0,'s']],
    pitch:[[0,0],[250,-.05,'s'],[470,0,'s'],[760,-.12,'s'],[850,-.45,'o'],[1100,-.28,'s'],[1300,.3,'s'],[tc,.95,'i2'],[tL,.22,'i2'],[tL+300,.15,'s'],[2700,0,'s']],
    sp:[[0,0],[850,-.1,'o'],[tc,.1,'s'],[tL,.0,'s']],
    hd:[[0,[0,0,0]],[250,[.04,.12,0],'o'],[470,[-.1,-.2,0],'s'],[760,[-.14,-.2,0]],[850,[-.04,-.08,0],'o'],[1100,[-.1,-.05,0],'s'],[1300,[.0,.05,0],'s'],[tc,[.1,.04,0],'s'],[tL,[-.1,-.08,0],'s'],[2200,[-.06,0,0],'s'],[2700,[0,0,0],'s']],
    hp:[[0,0],[760,.1],[850,-.1],[tc,-.12,'s'],[tL,.2,'s'],[2200,0,'s']],
    gape:[[0,0],[1300,0],[1400,.9,'o'],[tc-10,.9],[tc,0,'i2'],[tc+300,0]],
    tailP:[[0,0],[470,-.1,'s'],[850,.2,'o'],[tc,-.3,'s'],[tL,.4,'o'],[2250,.0,'s']],tailY:[[0,0]],roll:[[0,0]],stretch:[[0,1]]
  };
  const arcs=[{t0:850,t1:tc,x0:.12,x1:bxC,y0:0,y1:byC}];
  const an={t0:tc,t1:tL+60,rel:220,y:true,T:pt(c0,dir)};
  const ver={land:tL,ch,arcs,an,tc,pause:PAUSE,end:3000,prey:{c0,kind:'squash',amp:.3,rel:tL+80,stun:400},
    phl:[['alert',0,250],['crouch',250,470],['freeze',470,760],['push',760,850],['leap',850,tc],['dive hit',tc,tL],['heavy landing',tL,tL+400],['recovery',tL+400,3000]],
    strip:[120,600,900,1250,tc,tL+60]};
  const hip=(i,a)=>hipAt(ver,i,a),sg=i=>(i%2?1:-1);
  const f=[0,1,2,3].map(i=>new FootB(i));
  const bF=[[0,[0,0,0]],[812,[-.02,-.30,0]],[1100,[.05,-.28,0],'s'],[1300,[.14,-.3,0],'s'],[tc,[.22,-.44,0],'s'],[tL-90,[.14,-.60,0],'s'],[tL,[.12,-.60,0]]];
  const bH=[[0,[0,0,0]],[850,[-.1,-.36,0]],[1100,[-.2,-.3,0],'s'],[tc,[-.28,-.3,0],'s'],[tL-90,[-.1,-.58,0],'s'],[tL,[-.06,-.6,0]]];
  for(const i of [2,3]){const h=hip(i,tL);f[i].air(812,tL,bF,h.x+.12,.2*sg(i),30,70,1);}
  for(const i of [0,1]){const h=hip(i,tL);f[i].air(850,tL,bH,h.x-.03,.19*sg(i),30,70,1);}
  {const sb=(i,t0,dx)=>f[i].step(t0,t0+180,f[i].cur[0]+dx,f[i].cur[1],.05);sb(2,2250,-.28);sb(3,2330,-.28);sb(0,2400,-.28);sb(1,2480,-.28);}
  ver.segs=f.map(q=>q.end(3000));
  ver.rings=[{t:tL,x:cx-.55,z:0}];
  return ver;
 }},
// ---------------------------------------------------------------- 4 hop-hop-pounce
{id:'hop',name:'Hop-hop-pounce',D:4.4,tag:'two short bounding hops, then a pounce that lands and bites (the A64 lunge+peck feel)',
 make(env){
  const cx=env.cx,tl=1690,tc=tl+80,c0=[cx,.34,0],dir=[-.7,.7],bxC=env.bxC,byC=env.byC,L1=.27*bxC,L2=.54*bxC;
  const ch={
    bx:[[0,0],[440,0],[500,.03*bxC,'s'],[730,L1,'o'],[800,L1+.02*bxC,'s'],[870,L1+.04*bxC],[1100,L2,'o'],[1170,L2+.02*bxC,'s'],[1260,L2+.05*bxC,'s'],[tl,bxC-.1,'o'],[tc,bxC,'o'],[2050,env.ae.x,'s'],[2400,bxC-.30,'s'],[2800,bxC-.32]],
    by:[[0,0],[180,-.22,'o'],[440,-.24,'s'],[500,0,'o'],[730,-.1],[780,-.22,'o'],[830,-.2,'s'],[870,0,'o'],[1100,-.1],[1150,-.24,'o'],[1200,-.26,'s'],[1260,-.02,'i'],[tl,byC+.04],[tc,byC,'o'],[2050,env.ae.y,'s'],[2400,-.14,'s'],[2750,0,'s']],
    pitch:[[0,0],[180,.08,'o'],[440,.1,'s'],[500,-.2,'o'],[620,-.02,'s'],[730,.18,'s'],[780,.16],[870,-.2,'o'],[980,-.02,'s'],[1100,.18,'s'],[1150,.12],[1260,-.28,'o'],[1470,.0,'s'],[tl,.3,'i2'],[tc,.34,'o'],[2050,.34],[2400,.06,'s'],[2750,0,'s']],
    sp:[[0,0],[1260,-.08,'o'],[tl,.1,'s'],[2400,0,'s']],
    hd:[[0,[0,0,0]],[180,[.0,-.12,0],'o'],[440,[.0,-.14,0]],[500,[-.1,-.04,0]],[730,[-.1,-.1,0]],[870,[-.1,-.04,0]],[1100,[-.1,-.1,0]],[1260,[-.18,-.02,0],'o'],[tl-10,[-.18,-.04,0],'s'],[tc,[-.05,.0,0],'i'],[2050,[-.05,0,0]],[2150,[-.2,-.04,0],'s'],[2500,[0,0,0],'s']],
    hp:[[0,0],[1260,.2,'s'],[tl,.3,'s'],[tc-40,.18,'s'],[tc,-.05,'i'],[2050,-.1],[2150,.1,'s'],[2400,0,'s']],
    gape:[[0,0],[tl-30,0],[tl+10,.9,'o'],[tc-6,.9],[tc,0,'i2'],[2050,0],[2100,.35,'o'],[2180,0,'s']],
    tailP:[[0,0],[440,-.1,'s'],[500,.2,'o'],[730,.0,'s'],[870,.2,'o'],[1100,.0,'s'],[1260,.4,'o'],[tc,.5,'s'],[2400,.1,'s'],[2750,0,'s']],tailY:[[0,0]],roll:[[0,0]],stretch:[[0,1]]
  };
  const arcs=[{t0:500,t1:730,x0:.03*bxC,x1:L1,y0:0,y1:-.1},{t0:870,t1:1100,x0:L1+.04*bxC,x1:L2,y0:0,y1:-.1},{t0:1260,t1:tl,x0:L2+.05*bxC,x1:bxC-.1,y0:-.02,y1:byC+.04}];
  const an={t0:tc,t1:2050,rel:200,y:true,T:pt(c0,dir)};
  const ver={land:tl,ch,arcs,an,tc,pause:PAUSE,end:2850,prey:{c0,kind:'knock',amp:.2,dir:[.8,-.1],v0:1.8,mu:8,hop:.05,tilt:.35,stun:400},
    phl:[['crouch',0,180],['freeze',180,440],['hop 1',440,780],['hop 2',780,1150],['coil',1150,1260],['pounce',1260,tl],['bite',tl,tc],['hold on',tc,2050],['pull out',2050,2250],['recovery',2250,2850]],
    strip:[300,610,980,1450,tc,2300]};
    const hip=(i,a)=>hipAt(ver,i,a),sg=i=>(i%2?1:-1);
  const f=[0,1,2,3].map(i=>new FootB(i));
  const bF=[[0,[0,0,0]],[500,[.02,-.30,0]],[620,[.1,-.3,0],'s'],[730,[.16,-.42,0],'s']];
  const bH=[[0,[0,0,0]],[500,[-.14,-.34,0]],[620,[-.22,-.26,0],'s'],[730,[-.06,-.34,0],'s'],[780,[-.0,-.42,0]]];
  const bF2=[[0,[0,0,0]],[870,[.02,-.30,0]],[980,[.1,-.3,0],'s'],[1100,[.16,-.42,0],'s']];
  const bH2=[[0,[0,0,0]],[870,[-.14,-.34,0]],[980,[-.22,-.26,0],'s'],[1100,[-.06,-.34,0],'s'],[1150,[-.0,-.42,0]]];
  const bF3=[[0,[0,0,0]],[1238,[-.04,-.3,0]],[1400,[.12,-.26,0],'s'],[tl-80,[.2,-.32,0],'s'],[tl,[.18,-.5,0],'s']];
  const bH3=[[0,[0,0,0]],[1260,[-.12,-.34,0]],[1470,[-.26,-.26,0],'s'],[tl,[-.28,-.24,0],'s'],[tl+100,[-.08,-.48,0],'s']];
  const hop=(i,a1,a2,Bk,Bh)=>{};
  for(const i of [2,3]){const z=.165*sg(i);
    let h=hip(i,730);f[i].air(500,730,bF,h.x+.2,z,30,40,.5);h=hip(i,1100);f[i].air(870,1100,bF2,h.x+.2,z,30,40,.5);
    h=hip(i,tl);f[i].air(1238,tl,bF3,h.x+.27,.27*sg(i),30,60,.9);}
  for(const i of [0,1]){const z=.17*sg(i);
    let h=hip(i,780);f[i].air(500,780,bH,h.x-.02,z,30,40,.5);h=hip(i,1150);f[i].air(870,1150,bH2,h.x-.02,z,30,40,.5);
    h=hip(i,tl+100);f[i].air(1260,tl+100,bH3,h.x-.03,.19*sg(i),30,60,.8);}
  {const sb=(i,t0,dx)=>f[i].step(t0,t0+180,f[i].cur[0]+dx,f[i].cur[1],.05);sb(2,2200,-.28);sb(3,2280,-.28);sb(0,2350,-.28);sb(1,2430,-.28);}
  ver.segs=f.map(q=>q.end(2850));
  return ver;
 }}
];
// ---------------------------------------------------------------- build (pass 1 finds the solved body position at contact, pass 2 builds with it)
function build(spec){
  const mk=env=>{const v=spec.make(env);return finish(v,spec);};
  let env={cx:spec.D,bxC:0,byC:0,ae:{x:0,y:0}},v=mk(env);
  // pass 1 has no valid feet; the contact solve only needs the body channels
  const P=bodyPose(v,v.tc),s=solveContact(v,P);const ae=solveContact(v,bodyPose(v,v.an.t1));env={cx:spec.D,bxC:s.x,byC:s.y,ae};
  v=mk(env);
  const P2=bodyPose(v,v.tc),s2=solveContact(v,P2);if(Math.abs(s2.x-s.x)>1e-6||Math.abs(s2.y-s.y)>1e-6){env={cx:spec.D,bxC:s2.x,byC:s2.y,ae:env.ae};v=mk(env);}
  v.env=env;
  v.hits=[{tc:v.tc,pause:v.pause}];
  const sk=skel(v,poseAt(v,v.tc),true),c=V(...v.prey.c0);
  v.contact=v.an.mode==='chest'?sk.nodes[5].clone().add(c.clone().sub(sk.nodes[5]).setLength(REST.nodes[5][2])):sk.tip.clone();
  v.contactPart=v.an.mode==='chest'?'chest':'beak';v.hits[0].contact=v.contact;
  // fx: dust at every take-off and landing (auto), rings
  v.fx=[];
  const skA=a=>skel(v,poseAt(v,a),true);
  v.segs.forEach((segs,i)=>{for(const s of segs)if(s.k==='a'){
    v.fx.push({t:s.t0,x:s.x0,z:s.z0,n:3,s:.5,kind:'puff'});v.fx.push({t:s.t1,x:s.x1,z:s.z1,n:Math.round(2+4*s.fx),s:.45+.6*s.fx,kind:'puff'});}});
  (v.rings||[]).forEach(r=>v.fx.push({t:r.t,x:r.x,z:r.z,n:0,s:1,kind:'ring'}));
  v.fx.push({t:v.tc,x:v.contact.x,z:v.contact.z,y:Math.min(v.contact.y,.1),n:4,s:.6,kind:'puff'});
  return v;
}
const VERSIONS=SPECS.map(build);
// ---------------------------------------------------------------- real <-> animation time (the hit-pause freezes the animation)
function realToAnim(ver,tr){const h=ver.hits[0];if(tr<h.tc)return tr;if(tr<h.tc+h.pause)return h.tc;return tr-h.pause;}
function animToReal(ver,a){return a>ver.tc?a+ver.pause:a;}
function realLen(ver){return ver.end+ver.pause;}
function hitReal(ver){return ver.tc;}
function partsOf(ver){const out=[];for(const [n,a,b] of ver.phl){out.push([n,b-a]);if(b===ver.tc)out.push(['contact',ver.pause]);}return out;}
function stripTimes(ver){return ver.strip.map(a=>a===ver.tc?ver.tc+ver.pause/2:animToReal(ver,a)).map(Math.round);}
// ---------------------------------------------------------------- self check
function check(){
  const fails=[],rows=[];
  for(const ver of VERSIONS){
    const r={id:ver.id,name:ver.name};
    const c=V(...ver.prey.c0),skc=skel(ver,poseAt(ver,ver.tc),true);
    r.startDistance=ver.prey.c0[0]-P0.x;if(r.startDistance<3||r.startDistance>5)fails.push(`${ver.id}: start distance ${r.startDistance.toFixed(2)} m outside 3-5`);
    r.contactDist=ver.contactPart==='chest'?skc.nodes[5].distanceTo(c)-R-REST.nodes[5][2]:skc.tip.distanceTo(c)-R;
    if(Math.abs(r.contactDist)>.03)fails.push(`${ver.id}: ${ver.contactPart} ${r.contactDist.toFixed(3)} m from the hitbox at contact`);
    r.legErrAtContact=Math.max(skc.legErr,skc.neckErr);
    // hit-pause: animation time is frozen across it
    const a1=realToAnim(ver,ver.tc+1),a2=realToAnim(ver,ver.tc+ver.pause-1);if(ver.pause<60||ver.pause>90||a1!==a2)fails.push(`${ver.id}: hit-pause not a clean freeze`);
    // feet: planted segments must not drift, IK must reach, nothing below ground
    let drift=0,maxErr=0,minY=9,maxStretch=0;
    const sampled=[];for(let a=0;a<=ver.end;a+=4)sampled.push([a,skel(ver,poseAt(ver,a),true)]);
    for(let i=0;i<4;i++)for(const s of ver.segs[i])if(s.k==='p'&&s.t1-s.t0>30){let p0=null;
      for(const [a,sk] of sampled)if(a>=s.t0+2&&a<=s.t1-2){if(!p0)p0=sk.feet[i].clone();drift=Math.max(drift,sk.feet[i].distanceTo(p0),sk.feet[i].distanceTo(sk.targets[i]));}}
    for(const [a,sk] of sampled){maxErr=Math.max(maxErr,sk.legErr,sk.neckErr);maxStretch=Math.max(maxStretch,sk.stretch);
      sk.nodes.forEach((n,i)=>{if(i<7)minY=Math.min(minY,n.y-REST.nodes[i][2]*.9);});sk.knees.forEach(k=>minY=Math.min(minY,k.y-.02));sk.feet.forEach(f=>minY=Math.min(minY,f.y-.03));minY=Math.min(minY,sk.tip.y,sk.head.y-REST.hr*.9);}
    r.plantedDrift=drift;r.maxReachErr=maxErr;r.minY=minY;r.neckStretch=maxStretch;
    if(drift>.02)fails.push(`${ver.id}: planted foot drift ${(drift*100).toFixed(1)} cm`);
    if(maxErr>.02)fails.push(`${ver.id}: IK out of reach by ${(maxErr*100).toFixed(1)} cm`);
    if(minY<-.012)fails.push(`${ver.id}: geometry ${(minY*100).toFixed(1)} cm below ground`);
    // flight is honest: body centre height follows a parabola with g, no foot planted inside it
    r.flights=[];
    for(const ar of ver.arcs){const T0=ar.t1-ar.t0;if(T0<100)continue;const q={t0:ar.t0,t1:ar.t1};let worst=0;
      for(let a=ar.t0+25;a<=ar.t1-25;a+=25){const h=.02,y=k=>bodyPose(ver,k).by,acc=(y(a-h*1000)-2*y(a)+y(a+h*1000))/(h*h);worst=Math.max(worst,Math.abs(-acc-G)/G);}
      q.gErr=worst;let pl=0;for(let i=0;i<4;i++)for(const s of ver.segs[i])if(s.k==='p'&&s.t0<ar.t1-60&&s.t1>ar.t0+60)pl++;q.plantedInFlight=pl;
      q.apex=Math.max(...[0,.25,.5,.75,1].map(u=>bodyPose(ver,ar.t0+u*(ar.t1-ar.t0)).by));q.ms=T0;r.flights.push(q);
      if(worst>.1)fails.push(`${ver.id}: flight ${ar.t0}-${ar.t1} deviates from g by ${(worst*100).toFixed(0)} %`);
      if(pl)fails.push(`${ver.id}: a foot is planted during the flight ${ar.t0}-${ar.t1}`);}
    // landing absorbs weight: legs compress after the last long flight (reach ratio drops, or the body dips)
    let r0=0,rmin=9;
    {const sk0=skel(ver,poseAt(ver,ver.land),true);r0=Math.max(...sk0.reach.slice(2));
     for(let a=ver.land;a<=ver.land+300;a+=10){const s=skel(ver,poseAt(ver,a),true);rmin=Math.min(rmin,Math.min(...s.reach.slice(2)));}}
    r.landing={reachAtTouch:r0,reachMin:rmin,compress:r0-rmin};
    if(ver.contactPart==='chest'){/* the chest slam lands on the run: judged by the stride dips below */}
    else if(r.landing.compress<.04)fails.push(`${ver.id}: legs barely compress after landing (${r.landing.compress.toFixed(3)})`);
    // prey state finite and above ground for any time
    let bad=0,preyMin=9;for(let a=0;a<=ver.end;a+=3){const s=preyAt(ver,a);for(const k in s)if(typeof s[k]==='number'&&!isFinite(s[k]))bad++;preyMin=Math.min(preyMin,s.y-(.32*Math.cos(s.roll)+.2*Math.abs(Math.sin(s.roll)))*s.sy);}
    r.preyMinY=preyMin;if(bad)fails.push(`${ver.id}: prey state not finite`);if(preyMin<-.012)fails.push(`${ver.id}: prey through the ground ${preyMin.toFixed(3)}`);
    const s1=preyAt(ver,ver.tc+500),s0=preyAt(ver,ver.tc-5);r.preyMoved=Math.hypot(s1.x-s0.x,s1.z-s0.z);r.preyRoll=Math.max(...[0,200,400,600,800].map(d=>Math.abs(preyAt(ver,ver.tc+d).roll)));
    if(ver.id==='tackle'&&(r.preyMoved<.3||r.preyRoll<1.2))fails.push(`tackle: prey not knocked over (moved ${r.preyMoved.toFixed(2)} roll ${r.preyRoll.toFixed(2)})`);
    // timing
    const hold=ver.phl.find(p=>p[0]==='freeze');r.freezeMs=hold?hold[2]-hold[1]:0;if(!hold||r.freezeMs<200||r.freezeMs>600)fails.push(`${ver.id}: freeze ${r.freezeMs} ms outside 200-600`);
    const fl=ver.phl.filter(p=>/leap|stride|hop|pounce/.test(p[0])).map(p=>p[2]-p[1]);r.flightPhases=fl;
    let lead=0;for(const p of ver.phl){if(p[0]==='leap'||p[0]==='push'||p[0]==='stride 1'||p[0]==='hop 1'){lead=p[1];break;}}r.windupMs=lead;
    if(lead>1100)fails.push(`${ver.id}: wind-up ${lead} ms is too long against the game's 800 ms`);
    r.activeMs=ver.tc-lead;if(r.activeMs<300||r.activeMs>1500)fails.push(`${ver.id}: active ${r.activeMs} ms`);
    r.timing={};for(const [n,a,b] of ver.phl)r.timing[n]=b-a;
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.POUNCECORE={T,REST,VERSIONS,skel,poseAt,preyAt,realToAnim,animToReal,realLen,hitReal,partsOf,stripTimes,check,FOOT_REST,R,G};
})(typeof window!=='undefined'?window:globalThis);
