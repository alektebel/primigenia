'use strict';
// Primigenia befriend-bodies lab (A77 step 2): the 4 social actions x 4 body types. Shared core: maths helpers, ring-tube mesh, the
// friendly Zanco-like target, scene dressing, timing. Rigs live in bb_armed.js, bb_bird.js, bb_octo.js, bb_snake.js.
// Units: metres, +x forward (the performer faces the target), +y up, +z the performer's right. Times in ms.
// Game numbers (same as befriend.html): beat = 12 ticks = 1200 ms, rhythm window +-2 ticks = +-200 ms, read at the end of the wind-up.
//   sing  W 200 A 800 R 200   dance W 200 A 1000 R 200   charm W 100 A 600 R 200   pose W 400 A 800 R 200
// g = ms from the moment the order starts (negative = lead-in); the real clock is tr = g + PRE.
(function(root){
const T=root.THREE;
const BB={T,PRE:800,BEAT:1200,WIN:200,TAIL:3400,GAP:700,
  GAME:{sing:{W:200,A:800,R:200,range:8},dance:{W:200,A:1000,R:200,range:5},charm:{W:100,A:600,R:200,range:4},pose:{W:400,A:800,R:200,range:10}},
  ACTS:['sing','dance','charm','pose'],rigs:{},cells:[]};
const V=(x,y,z)=>new T.Vector3(x,y,z);
const clamp=(x,a,b)=>x<a?a:x>b?b:x,sm=u=>{u=clamp(u,0,1);return u*u*(3-2*u);},lerp=(a,b,u)=>a+(b-a)*u;
// smooth window: rises over ri ending at t0+ri... env(g,t0,t1,ri,ro): 0 before t0, full from t0+ri to t1-ro, 0 after t1
const env=(g,t0,t1,ri,ro)=>sm((g-t0)/Math.max(1,ri))*sm((t1-g)/Math.max(1,ro));
// narrow bump centred on t (ms), peak exactly at t
const bump=(g,t,w)=>{const d=(g-t)/w;return Math.exp(-d*d);};
const bumps=(g,t0,n,per,w)=>{let s=0;for(let k=0;k<n;k++)s=Math.max(s,bump(g,t0+k*per,w));return s;};
// attack-release pulse: reaches 1 at t (rise over a), falls over r
const pulse=(g,t,a,r)=>g<t?sm(1-(t-g)/a):sm(1-(g-t)/r);
const X=V(1,0,0),Y=V(0,1,0),Z=V(0,0,1);
const qEul=(yaw,pitch,roll)=>new T.Quaternion().setFromAxisAngle(Y,yaw).multiply(new T.Quaternion().setFromAxisAngle(Z,pitch)).multiply(new T.Quaternion().setFromAxisAngle(X,roll));
function ik(hip,foot,a,b,pole){
  const d=foot.clone().sub(hip);let L=d.length();const mx=a+b-1e-4,mn=Math.abs(a-b)+1e-3,err=Math.max(0,L-mx);
  const dir=d.clone().divideScalar(L||1);L=clamp(L,mn,mx);
  const x=(a*a-b*b+L*L)/(2*L),h=Math.sqrt(Math.max(0,a*a-x*x));
  const perp=pole.clone().sub(dir.clone().multiplyScalar(pole.dot(dir)));if(perp.lengthSq()<1e-8)perp.set(0,1,0);perp.normalize();
  return {knee:hip.clone().addScaledVector(dir,x).addScaledVector(perp,h),foot:hip.clone().addScaledVector(dir,L),err};
}
function bez(p0,p1,p2,p3,u){const v=1-u,a=v*v*v,b=3*v*v*u,c=3*v*u*u,d=u*u*u;return V(a*p0.x+b*p1.x+c*p2.x+d*p3.x,a*p0.y+b*p1.y+c*p2.y+d*p3.y,a*p0.z+b*p1.z+c*p2.z+d*p3.z);}
function bezPath(p0,p1,p2,p3,n){const o=[];for(let i=0;i<=n;i++)o.push(bez(p0,p1,p2,p3,i/n));return o;}
// resample a polyline to n+1 points evenly spaced by arc length
function resample(pts,n){const cum=[0];for(let i=1;i<pts.length;i++)cum.push(cum[i-1]+pts[i].distanceTo(pts[i-1]));const L=cum[cum.length-1],o=[];let j=0;
  for(let i=0;i<=n;i++){const d=L*i/n;while(j<pts.length-2&&cum[j+1]<d)j++;const u=(d-cum[j])/Math.max(1e-9,cum[j+1]-cum[j]);o.push(pts[j].clone().lerp(pts[j+1],clamp(u,0,1)));}return {pts:o,len:L};}
// ---------------------------------------------------------------- ring tube with vertex colours (octopus arms and mantle, snake body)
function Tube(nr,nv,){this.nr=nr;this.nv=nv;const g=new T.BufferGeometry(),n=nr*nv;
  g.setAttribute('position',new T.BufferAttribute(new Float32Array(n*3),3));g.setAttribute('color',new T.BufferAttribute(new Float32Array(n*3),3));
  const idx=[];for(let i=0;i<nr-1;i++)for(let j=0;j<nv;j++){const a=i*nv+j,b=i*nv+(j+1)%nv,c=(i+1)*nv+j,d=(i+1)*nv+(j+1)%nv;idx.push(a,c,b,b,c,d);}
  g.setIndex(idx);this.geo=g;this.mesh=new T.Mesh(g,new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide}));this.mesh.frustumCulled=false;
  this.ring=[];for(let i=0;i<nr;i++)this.ring.push([]);}
// pts: nr points, rad: nr radii, col(i,a,out): fills out[0..2] with linear rgb for ring i at angle a (a=0 is the 'up' side)
Tube.prototype.update=function(pts,rad,col,up){
  const nr=this.nr,nv=this.nv,P=this.geo.attributes.position.array,C=this.geo.attributes.color.array,out=[0,0,0];
  const t=new T.Vector3(),n=new T.Vector3(),b=new T.Vector3(),ref=up||Y;
  for(let i=0;i<nr;i++){
    const a=pts[Math.max(0,i-1)],c=pts[Math.min(nr-1,i+1)];t.copy(c).sub(a);if(t.lengthSq()<1e-12)t.set(1,0,0);t.normalize();
    n.copy(ref).addScaledVector(t,-ref.dot(t));if(n.lengthSq()<1e-6){n.set(0,0,1).addScaledVector(t,-t.z);}n.normalize();b.crossVectors(t,n);
    for(let j=0;j<nv;j++){const ang=j/nv*Math.PI*2,cs=Math.cos(ang),sn=Math.sin(ang),k=(i*nv+j)*3;
      P[k]=pts[i].x+rad[i]*(cs*n.x+sn*b.x);P[k+1]=pts[i].y+rad[i]*(cs*n.y+sn*b.y);P[k+2]=pts[i].z+rad[i]*(cs*n.z+sn*b.z);
      col(i,ang,out);C[k]=out[0];C[k+1]=out[1];C[k+2]=out[2];}
  }
  this.geo.attributes.position.needsUpdate=true;this.geo.attributes.color.needsUpdate=true;this.geo.computeVertexNormals();
};
// ---------------------------------------------------------------- mesh helpers (shared geometry)
const GEO={sph:new T.SphereGeometry(1,18,12),cyl:new T.CylinderGeometry(1,1,1,10)};
const lam=(c,o)=>new T.MeshLambertMaterial(Object.assign({color:c},o||{}));
const Yax=Y;
function place(m,a,b){const d=b.clone().sub(a),l=d.length()||1e-6;m.position.copy(a).addScaledVector(d,.5);m.quaternion.setFromUnitVectors(Yax,d.divideScalar(l));m.scale.set(1,l,1);}
function ell(parent,mat,sx,sy,sz){const m=new T.Mesh(GEO.sph,mat);m.scale.set(sx,sy,sz);parent.add(m);return m;}
function taper(r0,r1){return new T.CylinderGeometry(r1,r0,1,10);}
function coneX(r,len,seg){const g=new T.ConeGeometry(r,len,seg||12);g.translate(0,len/2,0);g.rotateZ(-Math.PI/2);return g;}
// thin tapered limb between two points
function limb(parent,mat,r0,r1){const m=new T.Mesh(taper(r0,r1),mat);parent.add(m);return m;}
// feather / flat blade: plane with its base at the origin, length along local +y, width along x
const FEATHER=(()=>{const g=new T.PlaneGeometry(1,1);g.translate(0,.5,0);return g;})();
function featherPose(m,base,dir,nrm,len,wid){
  const y=dir.clone().normalize(),z=nrm.clone().addScaledVector(y,-nrm.dot(y));if(z.lengthSq()<1e-8)z.set(0,0,1);z.normalize();const x=new T.Vector3().crossVectors(y,z);
  m.position.copy(base);m.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(x,y,z));m.scale.set(wid,len,1);}
function blobTexture(){const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d'),gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(0,0,0,.6)');gr.addColorStop(.6,'rgba(0,0,0,.28)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);return new T.CanvasTexture(c);}
function groundTexture(base,alt){const c=document.createElement('canvas');c.width=c.height=128;const g=c.getContext('2d');g.fillStyle=base;g.fillRect(0,0,128,128);g.fillStyle=alt;g.fillRect(0,0,64,64);g.fillRect(64,64,64,64);g.strokeStyle='rgba(255,255,255,.05)';g.strokeRect(0,0,128,128);const t=new T.CanvasTexture(c);t.wrapS=t.wrapT=T.RepeatWrapping;t.repeat.set(40,40);t.anisotropy=4;return t;}
function glowTexture(){const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d'),gr=g.createRadialGradient(128,128,0,128,128,128);gr.addColorStop(0,'rgba(255,226,160,0)');gr.addColorStop(.62,'rgba(255,226,160,.07)');gr.addColorStop(.86,'rgba(255,226,160,.55)');gr.addColorStop(.93,'rgba(255,240,200,.9)');gr.addColorStop(1,'rgba(255,226,160,0)');g.fillStyle=gr;g.fillRect(0,0,256,256);return new T.CanvasTexture(c);}
function ringTexture(){const c=document.createElement('canvas');c.width=c.height=512;const g=c.getContext('2d');g.lineCap='round';
  for(const [r,w,a] of [[.965,9,.95],[.9,4,.42],[.835,3,.22]]){g.strokeStyle=`rgba(230,240,255,${a})`;g.lineWidth=w;g.beginPath();g.arc(256,256,256*r,0,Math.PI*2);g.stroke();}return new T.CanvasTexture(c);}
BB.TEX={blob:blobTexture(),glow:glowTexture(),ring:ringTexture(),ground:groundTexture('#2f383f','#343e46'),rock:groundTexture('#2a3036','#30373d')};
function rng(seed){let s=seed>>>0;return()=>{s=(s*1664525+1013904223)>>>0;return s/4294967296;};}
const BLADES=(()=>{const R=rng(7),parts=[];const bg=new T.ConeGeometry(.013,.2,5);bg.translate(0,.1,0);
  for(let k=0;k<120;k++){const x=-1.8+R()*7,z=-2.4+R()*4.8;const g=bg.clone();g.scale(1,.8+R()*.7,1);g.rotateZ((R()-.5)*.2);g.rotateY(R()*6);g.translate(x,0,z);parts.push(g);}
  const n=parts.reduce((s,g)=>s+g.attributes.position.count,0),pos=new Float32Array(n*3),nor=new Float32Array(n*3),idx=[];let o=0;
  for(const g of parts){const p=g.attributes.position,q=g.attributes.normal,base=o;for(let i=0;i<p.count;i++){pos.set([p.getX(i),p.getY(i),p.getZ(i)],(o+i)*3);nor.set([q.getX(i),q.getY(i),q.getZ(i)],(o+i)*3);}
    const ix=g.index.array;for(let i=0;i<ix.length;i++)idx.push(ix[i]+base);o+=p.count;}
  const G=new T.BufferGeometry();G.setAttribute('position',new T.BufferAttribute(pos,3));G.setAttribute('normal',new T.BufferAttribute(nor,3));G.setIndex(idx);return G;})();
// ---------------------------------------------------------------- the target: a Zanco-like tall herbivore (stilt legs, long neck, trumpet snout, ear scoops, back fringe)
const TL=[[-.27,-.1],[-.27,.1],[.27,-.1],[.27,.1]],THIP=[[-.27,-.02,-.09],[-.27,-.02,.09],[.27,-.02,-.09],[.27,-.02,.09]],TSEG=[[.42,.45],[.42,.45],[.43,.46],[.43,.46]];
const TH0=.84,TNB=[.30,.12,0],TNR=[.34,.52],TNL=.4,FY=.03;
function tPose(act,g,TD,gS,bow){bow=bow||0;
  const P={by:0,pitch:0,roll:0,nup:0,nfwd:0,hp:.16,hyaw:0,hroll:0,jaw:0,earL:.32,earR:.32,eturn:0,tailY:0,fin:.12,thr:0,react:0};
  P.by=.004*Math.sin(g/520);P.tailY=.22*Math.sin(g/760+1);P.fin=.14+.05*Math.sin(g/610);P.earL+=.05*Math.max(0,Math.sin(g/1400));P.earR+=.04*Math.max(0,Math.sin(g/1100+2));
  // before the success the target just watches: head turned a little towards the performer, ears half up, still
  P.nup=bow+.03*sm(g/600);P.hp-=.04*sm(g/600);P.hp+=-bow*.35;
  const u=(g-gS)/1000;
  if(g>=gS){
    P.react=1;
    const eu=sm(u/.12),fall=sm((u-2.4)/.9);P.earL=P.earL+(1-P.earL)*eu-.28*fall;P.earR=P.earR+(1-P.earR)*eu-.28*fall;P.eturn=.25*sm(u/.3);
    P.hroll+=.36*sm(u/.22)*(1-.75*sm((u-1.7)/1.2));P.tailY+=.5*Math.sin(u*9)*Math.exp(-u/1.5);P.fin+=.4*sm(u/.3)*(1-sm((u-2.2)/1));
    const e1=sm(u/.3)*(1-sm((u-2.4)/1)),bob=Math.sin(u*Math.PI*2/.45);
    P.nup+=-bow*.4*e1;P.hp+=bow*.35*.6*e1;
    if(act==='sing'){P.nup+=.1*e1;P.hp-=.12*e1;const on=(u>.2&&u<1.3)?1:0;P.jaw+=.3*Math.max(0,Math.sin(u*Math.PI*2/.4))*on;P.thr=Math.max(0,Math.sin(u*Math.PI*2/.4))*on;}
    else if(act==='dance'){const on=u>.05&&u<1.5?Math.min(1,u*8,(1.5-u)*3):0;P.by-=.03*Math.abs(Math.sin(u*Math.PI/.45))*on;P.roll+=.06*Math.sin(u*Math.PI*2/.9)*on;P.nup+=.04*bob*on;P.tailY+=.35*Math.sin(u*14)*on;}
    else if(act==='charm'){P.nup-=.12*e1;P.hp+=.22*e1;P.nfwd+=.06*e1+.04*Math.sin(u*10)*e1;}
    else if(act==='pose'){P.by+=.035*e1;P.nup+=.1*e1;P.fin+=.5*e1;P.pitch-=.02*e1;}
  }
  return P;
}
function tSkel(act,g,TD,gS,bow){
  const P=tPose(act,g,TD,gS,bow),Qb=qEul(Math.PI,P.pitch,P.roll),c=V(TD,TH0+P.by,0),W=l=>V(l[0],l[1],l[2]).applyQuaternion(Qb).add(c);
  const nb=W(TNB),head=W([TNB[0]+TNR[0]+P.nfwd,TNB[1]+TNR[1]+P.nup,0]);
  const ng=ik(nb,head,TNL,TNL,V(.35,1,0).normalize().applyQuaternion(Qb));
  const Qh=Qb.clone().multiply(new T.Quaternion().setFromAxisAngle(Y,P.hyaw)).multiply(new T.Quaternion().setFromAxisAngle(Z,-(P.hp-.1*P.nup))).multiply(new T.Quaternion().setFromAxisAngle(X,P.hroll));
  const axis=X.clone().applyQuaternion(Qh),tip=ng.foot.clone().addScaledVector(axis,.26);
  const hips=[],knees=[],feet=[],planted=[];
  for(let i=0;i<4;i++){const hip=W(THIP[i]),ft=V(TD-TL[i][0],FY,-TL[i][1]),pl=V(i>=2?1:-1,0,0).applyQuaternion(Qb),r=ik(hip,ft,TSEG[i][0],TSEG[i][1],pl);
    if(r.knee.y<.03)r.knee.y=.03;hips.push(hip);knees.push(r.knee);feet.push(r.foot);planted.push(true);}
  const tb=W([-.42,.06,0]),qa=new T.Quaternion().setFromEuler(new T.Euler(0,P.tailY,.18,'YZX')),Qt=Qb.clone().multiply(qa);
  const t1=tb.clone().addScaledVector(V(-1,0,0).applyQuaternion(Qt),.26),Qt2=Qt.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,-.25-.2*P.tailY)),t2=t1.clone().addScaledVector(V(-1,0,0).applyQuaternion(Qt2),.24);
  return {P,Qb,c,nb,neckMid:ng.knee,head:ng.foot.clone(),Qh,axis,tip,hips,knees,feet,planted,tail:[tb,t1,t2]};
}
function buildTarget(scene){
  const skin=lam('#8197a6'),dark=lam('#4a5762'),pale=lam('#ddd5c1'),fin=lam('#e3a64d',{side:T.DoubleSide}),earIn=lam('#c9948b'),eyeW=lam('#f4f1e8'),eyeP=lam('#121416'),hoof=lam('#3a3430'),mouth=lam('#6d2a30');
  const o={};o.body=new T.Group();scene.add(o.body);
  ell(o.body,skin,.46,.2,.17);const bel=ell(o.body,pale,.38,.12,.15);bel.position.set(-.02,-.1,0);
  const ch=ell(o.body,skin,.2,.22,.17);ch.position.set(.3,.04,0);const rp=ell(o.body,skin,.2,.19,.16);rp.position.set(-.3,.02,0);
  o.fins=[];for(let k=0;k<7;k++){const f=new T.Mesh(new T.ConeGeometry(.035,.2,4),fin);f.position.set(.34-k*.115,.19,0);o.body.add(f);o.fins.push(f);}
  o.neck=[0,1].map(()=>limb(scene,skin,.075,.055));o.nodes=[.085,.062,.06].map(r=>{const m=ell(scene,skin,r,r,r);return m;});
  o.head=new T.Group();scene.add(o.head);ell(o.head,skin,.1,.075,.07);
  const sn=new T.Mesh(coneX(.045,.2,12),skin);sn.position.set(.07,-.015,0);o.head.add(sn);const ns=ell(o.head,dark,.018,.016,.02);ns.position.set(.27,-.02,0);
  o.jaw=new T.Group();o.jaw.position.set(.03,-.045,0);o.head.add(o.jaw);const jw=ell(o.jaw,pale,.09,.022,.045);jw.position.set(.07,0,0);o.mouthIn=ell(o.jaw,mouth,.07,.012,.035);o.mouthIn.position.set(.07,.018,0);
  for(const s of [-1,1]){const e=ell(o.head,eyeW,.028,.03,.02);e.position.set(.05,.04,s*.062);const p=ell(o.head,eyeP,.015,.018,.012);p.position.set(.063,.04,s*.073);}
  o.ears=[-1,1].map(s=>{const pv=new T.Group();pv.position.set(-.04,.06,s*.055);o.head.add(pv);const ear=ell(pv,dark,.05,.15,.03);ear.position.set(0,.15,0);const inn=ell(pv,earIn,.032,.1,.02);inn.position.set(.008,.15,s*.012);return {pv,s};});
  o.throat=ell(scene,pale,.05,.05,.05);o.tail=[0,1].map(()=>limb(scene,skin,.055,.035));o.tuft=ell(scene,dark,.07,.07,.07);o.tailN=[0,1,2].map(()=>ell(scene,skin,.05,.05,.05));
  o.legs=[];for(let i=0;i<4;i++){const m=i%2?dark:skin,up=limb(scene,m,.05,.03),lo=limb(scene,dark,.03,.02),kn=ell(scene,dark,.036,.036,.036),ft=ell(scene,hoof,.055,.025,.04);o.legs.push({up,lo,kn,ft});}
  const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.003;scene.add(sh);o.shadow=sh;return o;
}
function drawTarget(o,s,TD){
  const P=s.P;o.body.position.copy(s.c);o.body.quaternion.copy(s.Qb);
  o.fins.forEach((f,k)=>{const sc=.5+1.5*P.fin;f.scale.set(1,sc,1);f.position.y=.17+.01*sc;f.rotation.z=-.15-.35*P.fin*(k/6);});
  place(o.neck[0],s.nb,s.neckMid);place(o.neck[1],s.neckMid,s.head);o.nodes[0].position.copy(s.nb);o.nodes[1].position.copy(s.neckMid);o.nodes[2].position.copy(s.head);
  o.head.position.copy(s.head);o.head.quaternion.copy(s.Qh);o.jaw.rotation.z=-P.jaw*.55;o.mouthIn.visible=P.jaw>.1;
  o.ears.forEach((e,i)=>{const up=i===0?P.earL:P.earR,x=Math.max(0,Math.min(1.1,up));e.pv.rotation.set(e.s*(.28+.5*P.eturn*(1-x*.4)),0,1.3*(1-x));e.pv.scale.set(1,.7+.5*x,1);});
  o.throat.visible=P.thr>.05;if(o.throat.visible){o.throat.position.copy(s.neckMid).lerp(s.head,.6).add(V(0,-.05,0));o.throat.scale.setScalar(.03+.04*P.thr);}
  place(o.tail[0],s.tail[0],s.tail[1]);place(o.tail[1],s.tail[1],s.tail[2]);o.tuft.position.copy(s.tail[2]);s.tail.forEach((p,i)=>o.tailN[i].position.copy(p));
  o.legs.forEach((l,i)=>{place(l.up,s.hips[i],s.knees[i]);place(l.lo,s.knees[i],s.feet[i]);l.kn.position.copy(s.knees[i]);l.ft.position.copy(s.feet[i]).add(V(.02,-.0,0).applyQuaternion(s.Qb));l.ft.quaternion.copy(s.Qb);});
  o.shadow.position.set(s.c.x,.003,s.c.z);o.shadow.scale.set(1.5,.6,1);o.shadow.rotation.z=-Math.PI;
}
Object.assign(BB,{V,clamp,sm,lerp,env,bump,bumps,pulse,X,Y,Z,qEul,ik,bez,bezPath,resample,Tube,GEO,lam,place,ell,taper,coneX,limb,FEATHER,featherPose,rng,BLADES,tSkel,buildTarget,drawTarget,FY,TH0});

// ---------------------------------------------------------------- transient effects pool: sound arcs, ground rings, soft dots (all optional, cheap)
function FXPool(scene){
  const arcG=new T.RingGeometry(.965,1,32,1,-.62,1.24),arcs=[],rings=[],dots=[];
  for(let k=0;k<18;k++){const m=new T.Mesh(arcG,new T.MeshBasicMaterial({color:'#e8f4ff',transparent:true,opacity:0,side:T.DoubleSide,depthWrite:false,blending:T.AdditiveBlending}));m.visible=false;scene.add(m);arcs.push(m);}
  for(let k=0;k<8;k++){const m=new T.Mesh(new T.PlaneGeometry(2,2),new T.MeshBasicMaterial({map:BB.TEX.ring,transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending}));m.rotation.x=-Math.PI/2;m.visible=false;scene.add(m);rings.push(m);}
  for(let k=0;k<40;k++){const m=new T.Mesh(GEO.sph,new T.MeshBasicMaterial({color:'#ffffff',transparent:true,opacity:0,depthWrite:false}));m.visible=false;scene.add(m);dots.push(m);}
  const used={a:0,r:0,d:0};
  return {
    reset(){used.a=used.r=used.d=0;},
    arc(pos,q,r,op,col){if(used.a>=arcs.length)return;const m=arcs[used.a++];m.visible=true;m.position.copy(pos);m.quaternion.copy(q);m.scale.setScalar(r);m.material.opacity=op;m.material.color.set(col||'#e8f4ff');},
    ring(x,y,z,r,op,col){if(used.r>=rings.length)return;const m=rings[used.r++];m.visible=true;m.position.set(x,y,z);m.scale.set(r,r,1);m.material.opacity=op;m.material.color.set(col||'#ffffff');},
    dot(pos,s,op,col,sy){if(used.d>=dots.length)return;const m=dots[used.d++];m.visible=true;m.position.copy(pos);m.scale.set(s,sy||s,s);m.material.opacity=op;m.material.color.set(col||'#ffffff');},
    flush(){for(let k=used.a;k<arcs.length;k++)arcs[k].visible=false;for(let k=used.r;k<rings.length;k++)rings[k].visible=false;for(let k=used.d;k<dots.length;k++)dots[k].visible=false;}
  };
}
Object.assign(BB,{FXPool});
root.BB=BB;
})(typeof window!=='undefined'?window:globalThis);
