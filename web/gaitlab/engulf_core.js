'use strict';
// Primigenia engulf lab (A84 "fauces", study process A60): a creature swallows a smaller limp or stunned creature whole.
// Shared core: maths, the skin tube with a prey-shaped bulge, the limp prey (a small starter-B cub), the spit-out timeline, scene dressing.
// Rigs: engulf_snake.js (jaw walk), engulf_bird.js (pelican gulp + heron toss), engulf_frog.js (frog gulp, eyes press down).
// Units: metres, +x forward (the predator faces +x), +y up, +z the predator's right. Times in ms, u = ms since the start of the clip.
// Every rig is a pure function of u: frame(inst,u,ov). ov carries the spit-out overlay (see EG.timeMap), so scrubbing and frame stepping always work.
// Numbers marked "start" are starting values, not measured; the owner picks the look, the game numbers come from A84.
(function(root){
const T=root.THREE,BB=root.BB;
const {V,clamp,sm,lerp,ik,lam,place,ell,limb,coneX,GEO,X,Y,Z,qEul}=BB;
const EG={T,BB,V,clamp,sm,lerp,ik,lam,place,ell,limb,coneX,GEO,X,Y,Z,qEul,rigs:{}};
const TAU=Math.PI*2;
const ramp=(u,a,b)=>sm((u-a)/Math.max(1e-6,b-a));            // 0 before a, 1 after b, smooth between
const win=(u,a,b,ri,ro)=>sm((u-a)/Math.max(1,ri))*sm((b-u)/Math.max(1,ro));   // 0 outside [a,b], 1 inside, ri/ro ease in/out (ms)
const pls=(u,t,w)=>{const d=(u-t)/w;return Math.exp(-d*d);}; // gaussian pulse centred on t
const ease=u=>{u=clamp(u,0,1);return 1-(1-u)*(1-u)*(1-u);};   // ease-out cubic
const easeIn=u=>{u=clamp(u,0,1);return u*u*u;};
const keys=(u,K,i=1)=>{                                        // smooth piecewise interpolation of rows [u,v0,v1,...]
  if(u<=K[0][0])return K[0].slice(1);const n=K.length;if(u>=K[n-1][0])return K[n-1].slice(1);
  let k=0;while(K[k+1][0]<u)k++;const a=K[k],b=K[k+1],f=sm((u-a[0])/(b[0]-a[0]));return a.slice(1).map((v,j)=>v+(b[j+1]-v)*f);};
Object.assign(EG,{TAU,ramp,win,pls,ease,easeIn,keys});

// ------------------------------------------------------------------ skin tube: rings along a path, two radii per ring, optional half arc (pouch)
function Tube2(nr,nv,a0,a1,mat){
  a0=a0||0;a1=a1===undefined?TAU:a1;const closed=(a1-a0)>=TAU-1e-6;const nc=closed?nv:nv+1;
  this.nr=nr;this.nc=nc;this.a0=a0;this.da=(a1-a0)/nv;
  const g=new T.BufferGeometry(),n=nr*nc;
  g.setAttribute('position',new T.BufferAttribute(new Float32Array(n*3),3));g.setAttribute('color',new T.BufferAttribute(new Float32Array(n*3),3));
  const idx=[],cm=closed?nc:nc-1;for(let i=0;i<nr-1;i++)for(let j=0;j<cm;j++){const j2=closed?(j+1)%nc:j+1,a=i*nc+j,b=i*nc+j2,c=(i+1)*nc+j,d=(i+1)*nc+j2;idx.push(a,c,b,b,c,d);}
  g.setIndex(idx);this.geo=g;this.mesh=new T.Mesh(g,mat||new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide}));this.mesh.frustumCulled=false;
}
// pts[nr] centres, rA/rB radii along n / b, ref = Vector3 'up' reference or 'planar' (path in the xy plane: n = Z x t), col(i,ang,out), off[i] shifts the centre along n
Tube2.prototype.update=function(pts,rA,rB,ref,col,off){
  const nr=this.nr,nc=this.nc,P=this.geo.attributes.position.array,C=this.geo.attributes.color.array,out=[.5,.5,.5];
  const t=new T.Vector3(),n=new T.Vector3(),b=new T.Vector3(),c=new T.Vector3();
  for(let i=0;i<nr;i++){
    const a=pts[Math.max(0,i-1)],e=pts[Math.min(nr-1,i+1)];t.copy(e).sub(a);if(t.lengthSq()<1e-12)t.set(1,0,0);t.normalize();
    if(ref==='planar'){n.set(-t.y,t.x,0);if(n.lengthSq()<1e-8)n.set(0,1,0);n.normalize();}
    else{const r=ref||Y;n.copy(r).addScaledVector(t,-r.dot(t));if(n.lengthSq()<1e-6)n.set(0,0,1).addScaledVector(t,-t.z);n.normalize();}
    b.crossVectors(t,n);c.copy(pts[i]);if(off&&off[i])c.addScaledVector(n,off[i]);
    for(let j=0;j<nc;j++){const ang=this.a0+j*this.da,cs=Math.cos(ang)*rA[i],sn=Math.sin(ang)*rB[i],k=(i*nc+j)*3;
      P[k]=c.x+cs*n.x+sn*b.x;P[k+1]=c.y+cs*n.y+sn*b.y;P[k+2]=c.z+cs*n.z+sn*b.z;
      col(i,ang,out);C[k]=out[0];C[k+1]=out[1];C[k+2]=out[2];}
  }
  this.geo.attributes.position.needsUpdate=true;this.geo.attributes.color.needsUpdate=true;this.geo.computeVertexNormals();
};
// points at arc distances k*ds (k=0..n) along a polyline, extended straight past its end
function arcSample(poly,ds,n){
  const o=[];let seg=0,acc=0;const cum=[0];for(let i=1;i<poly.length;i++)cum.push(cum[i-1]+poly[i].distanceTo(poly[i-1]));
  const L=cum[cum.length-1];
  for(let k=0;k<=n;k++){const d=k*ds;
    if(d>=L){const a=poly[poly.length-2],b=poly[poly.length-1],dir=b.clone().sub(a).normalize();o.push(b.clone().addScaledVector(dir,d-L));continue;}
    while(seg<poly.length-2&&cum[seg+1]<d)seg++;const u=(d-cum[seg])/Math.max(1e-9,cum[seg+1]-cum[seg]);o.push(poly[seg].clone().lerp(poly[seg+1],clamp(u,0,1)));}
  return o;
}
// ------------------------------------------------------------------ the prey: a small starter-B cub, limp or stunned. Nose at local +x.
const PREY={L:.68,nose:.32,R:.105,kcal:520};
const PROF=[[0,.25],[.06,.55],[.16,.72],[.26,.62],[.34,.72],[.5,1],[.66,.98],[.8,.7],[.9,.4],[1,.15]];
function profile(xi){let k=0;while(k<PROF.length-2&&PROF[k+1][0]<xi)k++;const a=PROF[k],b=PROF[k+1];return lerp(a[1],b[1],sm((xi-a[0])/(b[0]-a[0])));}
// radius of a prey inside a tube at arc distance a, when the prey nose is at aF and its length is Lp (0 where there is none)
function lumpR(a,aF,Lp,Rp){const xi=(aF-a)/Lp;if(xi<=0||xi>=1)return 0;return Rp*profile(xi)*Math.sqrt(clamp(xi/.07,0,1))*Math.sqrt(clamp((1-xi)/.1,0,1));}
function makePrey(scene){
  const cA=lam('#a9824e'),cB=lam('#5e4527'),cC=lam('#e8dcb8'),dk=lam('#17120d'),wh=lam('#f4f1e8'),pk=lam('#d68a8a');
  const mats=[cA,cB,cC,dk,wh,pk];
  const clip=new T.Plane(new T.Vector3(0,1,0),1000);mats.forEach(m=>{m.clippingPlanes=[clip];});
  const root=new T.Group(),fr=new T.Group(),rr=new T.Group(),hd=new T.Group(),tl=new T.Group();scene.add(root);root.add(fr);root.add(rr);fr.add(hd);rr.add(tl);
  rr.position.set(-.04,0,0);hd.position.set(.2,.035,0);tl.position.set(-.2,0,0);
  ell(fr,cA,.17,.1,.09).position.set(.04,0,0);ell(fr,cC,.15,.06,.078).position.set(.04,-.05,0);
  ell(rr,cA,.17,.098,.088).position.set(-.08,0,0);ell(rr,cC,.15,.06,.075).position.set(-.08,-.05,0);
  for(const [par,x] of [[rr,-.1],[rr,-.2],[fr,.1]]){const sp=ell(par,cB,.05,.02,.05);sp.position.set(x,.09,0);}
  ell(hd,cA,.1,.088,.082);const sn=ell(hd,cC,.06,.045,.05);sn.position.set(.085,-.02,0);const nose=ell(hd,dk,.017,.014,.02);nose.position.set(.14,-.005,0);
  const eyes=[];for(const s of [-1,1]){const e=ell(hd,wh,.03,.034,.022);e.position.set(.05,.04,s*.07);const p=ell(hd,dk,.015,.02,.012);p.position.set(.066,.04,s*.082);const lid=ell(hd,cA,.034,.02,.026);lid.position.set(.05,.052,s*.07);eyes.push({e,p,lid,s});
    const ear=ell(hd,cB,.035,.06,.02);ear.position.set(-.04,.1,s*.055);ear.rotation.z=.2;ell(hd,pk,.02,.035,.012).position.set(-.035,.1,s*.064);}
  const t1=ell(tl,cA,.07,.05,.05);t1.position.set(-.05,0,0);const t2=ell(tl,cB,.06,.038,.038);t2.position.set(-.13,-.005,0);
  const legs=[];
  for(let i=0;i<4;i++){const front=i>=2,side=i%2?1:-1,par=front?fr:rr,m=side<0?cB:cA;
    const up=new T.Mesh(BB.taper(.032,.025),m),lo=new T.Mesh(BB.taper(.025,.018),m),ft=ell(par,cB,.03,.016,.026);par.add(up,lo);
    legs.push({up,lo,ft,front,side,hip:V(front?.1:-.1,-.05,side*.075)});}
  const stars=new T.Group();const sm2=new T.MeshBasicMaterial({color:'#ffd24a'});for(let k=0;k<3;k++)stars.add(new T.Mesh(new T.OctahedronGeometry(.04,0),sm2));scene.add(stars);
  const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.003;scene.add(sh);
  return {root,fr,rr,hd,tl,legs,eyes,stars,shadow:sh,clip,mats};
}
const Q0=new T.Quaternion(),dq=new T.Vector3();
// st: {pos,q,fold(0..2.4),stun(0..1),swing(rad),tr(ms),s(scale),vis,clip:{p,n}|null,flash}
function drawPrey(p,st,ov,u){
  ov=ov||{};let pos=st.pos,q=st.q,s=st.s===undefined?1:st.s,fold=st.fold||0,swing=st.swing||0,stun=st.stun===undefined?0:st.stun,lie=st.lie||0;
  if(ov.ej!==undefined&&ov.ej>=0){const E=ejectState(st,ov.ej);pos=E.pos;q=E.q;fold=E.fold;swing=E.swing;stun=E.stun;lie=E.lie;}
  p.root.visible=st.vis!==false;if(!p.root.visible){p.stars.visible=false;p.shadow.visible=false;return;}
  p.root.position.copy(pos);p.root.quaternion.copy(q);p.root.scale.setScalar(s);
  p.rr.rotation.z=fold;
  // gravity in the prey frame: limbs, head and tail hang (limp), a pendulum swing is added by the rig
  const dl=V(0,-1,0).applyQuaternion(q.clone().invert());
  const ang=Math.atan2(dl.y,dl.x)+Math.PI/2,tr=(st.tr||0)/1000;
  const hh=clamp(ang,-1.1,1.1)*.5-.14+.05*Math.sin(tr*1.3)*stun;
  p.hd.rotation.z=hh+swing*.5-.1*fold*0;p.hd.rotation.x=.12*Math.sin(tr*.9+1)*stun;
  p.tl.rotation.z=clamp(ang,-1.1,1.1)*.45+.1+swing*.7+.06*Math.sin(tr*2.1);p.tl.rotation.y=.12*Math.sin(tr*1.6);
  const sw=swing,bt=1+.02*Math.sin(tr*3.4)*stun;p.fr.scale.set(1,bt,bt);p.rr.scale.set(1,bt,bt);
  const gr=clamp(1-(pos.y-.095)/.09,0,1)*clamp((-dl.y-.55)/.3,0,1);
  p.legs.forEach((l,i)=>{
    const fdir=V(dl.x,dl.y,dl.z);
    if(l.front===false&&fold>0){const R=new T.Quaternion().setFromAxisAngle(Z,-fold);fdir.applyQuaternion(R);}
    const side=l.side,ph=i*1.7,tw=.06*Math.sin(tr*5+ph)*stun*.5,sw=swing;
    const fx=l.front?1:-1;
    const hang1=fdir.clone().multiplyScalar(.9).add(V(.18*Math.cos(sw+ph*.2)+sw*.5*fx,0,side*.34+tw));
    const hang2=fdir.clone().multiplyScalar(.9).add(V(.1*Math.sin(sw*1.3+ph)+sw*.45,0,side*.12));
    const rest1=V(.5*fx*(i%2?.7:1)+.2,-.18,side*1),rest2=V(.55*fx-.15*side*(i>1?1:-1),-.1,side*.7);
    const d1=hang1.lerp(rest1,gr).normalize(),d2=hang2.lerp(rest2,gr).normalize();
    const knee=l.hip.clone().addScaledVector(d1,.1),foot=knee.clone().addScaledVector(d2,.1);
    place(l.up,l.hip,knee);place(l.lo,knee,foot);l.ft.position.copy(foot);
  });
  // eyes: stunned = half-closed with dizzy pupils, a flash of white when hit
  p.eyes.forEach(e=>{e.lid.scale.set(.034,.024+.014*stun,.026);e.lid.position.y=.052-.012*stun;e.p.position.x=.066+.006*Math.sin(tr*4+e.s)*stun;});
  p.mats.forEach(m=>{const f=st.flash||0;m.emissive.setRGB(f,f,f);});
  // clip plane: the part of the prey behind the mouth plane is hidden (it is "inside" the predator, drawn as the bulge)
  if(st.clip){p.clip.setFromNormalAndCoplanarPoint(st.clip.n,st.clip.p);}else{p.clip.normal.set(0,1,0);p.clip.constant=1000;}
  p.stars.visible=stun>.05;
  if(p.stars.visible){const hp=V(0,0,0);p.hd.getWorldPosition(hp);p.stars.position.set(hp.x,hp.y+.2*s+.04,hp.z);p.stars.children.forEach((m,k)=>{const an=tr*5+k*2.094;m.position.set(.14*Math.cos(an),.025*Math.sin(an*2),.14*Math.sin(an));m.rotation.y=an*2;m.scale.setScalar(stun*s);});}
  p.shadow.visible=true;const lift=Math.max(0,pos.y-.1);p.shadow.position.set(pos.x,.003,pos.z);p.shadow.scale.set(.9*s,.55*s,1);p.shadow.material.opacity=clamp(.9-lift*1.5,.1,.9);
}
// spit-out flight: from the pose at the mouth (st), a short ballistic arc, a bounce, then lying limp and stunned
const GRAV=9.8,REST_Y=.1;
function ejectState(st,t){
  t/=1000;const vx=2.2,vy=2.3,y0=st.pos.y,p0=st.pos;
  const disc=vy*vy+2*GRAV*(y0-REST_Y),tl=(vy+Math.sqrt(disc))/GRAV;
  const tt=Math.min(t,tl),x=p0.x+vx*tt,y=y0+vy*tt-.5*GRAV*tt*tt;
  let pos=V(x,Math.max(REST_Y,y),p0.z),sw=0;
  if(t>tl){const k=t-tl;const slide=.28*(1-Math.exp(-k*5));pos.x+=slide;const b=.07*Math.abs(Math.sin(k*13))*Math.exp(-k*5.5);pos.y=REST_Y+b;sw=.6*Math.exp(-k*3)*Math.sin(k*11);}
  const tum=-(.8*TAU)*ease(tt/tl);
  const qa=new T.Quaternion().setFromAxisAngle(Z,tum).multiply(st.q);
  const rest=new T.Quaternion().setFromEuler(new T.Euler(1.25,.35,0,'YZX')).multiply(new T.Quaternion().setFromAxisAngle(Y,0));
  const lf=ramp(t,tl-.02,tl+.3);const q=qa.clone().slerp(rest,lf);
  return {pos,q,fold:lerp(st.fold||0,.5,lf),swing:sw+.5*Math.sin(t*14)*Math.exp(-t*2.2)*(1-lf),stun:ramp(t,tl+.15,tl+.6),lie:lf,tl};
}
// ------------------------------------------------------------------ timeline: real time -> clip time u + spit overlay
// spit: null | {t0, u0, only} ; u0 = clip time of the creature when hit. Returns {u, ov, end}
const SPIT={flinch:380,rev:2.3,fly:700,hold:1500};
function timeMap(rig,tr,spit){
  if(!spit)return {u:Math.min(tr,rig.len),ov:{},end:rig.len};
  const dt=tr-spit.t0,u0=Math.min(spit.u0,rig.len);
  if(dt<0)return {u:Math.min(tr,rig.len),ov:{},end:rig.len};
  const hitK=Math.exp(-dt/230);
  if(spit.only||u0<rig.u1+120){return {u:Math.min(tr,rig.len),ov:{hit:hitK,fl:Math.min(1,dt/60)*Math.exp(-dt/320)},end:rig.len};}
  const ur=Math.min(u0,rig.swEnd),digK=rig.digK(u0),rootU=u0;
  const base={rootU,digK,spitting:true};
  if(dt<SPIT.flinch)return {u:ur,ov:Object.assign({hit:hitK,fl:Math.min(1,dt/60)*Math.exp(-dt/260),retch:0},base),end:0};
  const dr=dt-SPIT.flinch,revLen=(ur-rig.u1)/SPIT.rev;
  const total=SPIT.flinch+revLen+SPIT.fly+SPIT.hold;
  if(dr<revLen){const f=dr/revLen;return {u:ur-(ur-rig.u1)*f,ov:Object.assign({hit:hitK*.3,retch:Math.sin(dr/115*Math.PI),rev:f},base),end:total};}
  const de=dr-revLen;
  return {u:rig.u1,ov:Object.assign({hit:0,retch:0,ej:de,spitK:pls(de,120,150)},base),end:total};
}
Object.assign(EG,{Tube2,arcSample,PREY,profile,lumpR,makePrey,drawPrey,ejectState,SPIT,timeMap});

// ------------------------------------------------------------------ scene dressing
function rngf(seed){let s=seed>>>0;return()=>{s=(s*1664525+1013904223)>>>0;return s/4294967296;};}
function grass(x0,x1,n,seed){
  const R=rngf(seed),parts=[];const bg=new T.ConeGeometry(.014,.2,5);bg.translate(0,.1,0);
  for(let k=0;k<n;k++){const x=x0+R()*(x1-x0),z=-3+R()*6;if(Math.abs(z)<.25&&R()<.55)continue;const g=bg.clone();g.scale(1,.32+R()*.42,1);g.rotateZ((R()-.5)*.25);g.rotateY(R()*6);g.translate(x,0,z);parts.push(g);}
  const cnt=parts.reduce((s,g)=>s+g.attributes.position.count,0),pos=new Float32Array(cnt*3),nor=new Float32Array(cnt*3),idx=[];let o=0;
  for(const g of parts){const p=g.attributes.position,q=g.attributes.normal;for(let i=0;i<p.count;i++){pos.set([p.getX(i),p.getY(i),p.getZ(i)],(o+i)*3);nor.set([q.getX(i),q.getY(i),q.getZ(i)],(o+i)*3);}const ix=g.index.array;for(let i=0;i<ix.length;i++)idx.push(ix[i]+o);o+=p.count;}
  const G=new T.BufferGeometry();G.setAttribute('position',new T.BufferAttribute(pos,3));G.setAttribute('normal',new T.BufferAttribute(nor,3));G.setIndex(idx);return G;
}
function dress(scene,bgc){
  scene.background=new T.Color(bgc);scene.fog=new T.Fog(bgc,12,34);
  scene.add(new T.AmbientLight('#ffffff',.74));const dl=new T.DirectionalLight('#fff4e0',.95);dl.position.set(-2.5,5,4);scene.add(dl);const rim=new T.DirectionalLight('#9cc4d8',.3);rim.position.set(3,2,-4);scene.add(rim);
  const gnd=new T.Mesh(new T.PlaneGeometry(80,80),new T.MeshLambertMaterial({map:BB.TEX.ground}));gnd.rotation.x=-Math.PI/2;scene.add(gnd);
  scene.add(new T.Mesh(grass(-6,14,520,11),new T.MeshLambertMaterial({color:'#6f9650'})));
  return {gnd,dl};
}
function shadowBlob(scene){const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.003;scene.add(sh);return sh;}
// white hit flash on a list of materials
function flashMats(mats,f){mats.forEach(m=>{if(m.emissive)m.emissive.setRGB(f,f,f);});}
Object.assign(EG,{dress,shadowBlob,flashMats,grass});
root.EG=EG;
})(typeof window!=='undefined'?window:globalThis);
