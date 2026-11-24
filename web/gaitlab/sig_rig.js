'use strict';
// Primigenia signature-attack lab, shared toolkit (round 2): keyframes, soft sprite effects, ballistic emitters, beams, an articulated
// quadruped rig (IK legs, tube neck and tail, jointed head with jaw), a serpent rig, and Pip, the little herbivore that every attack is fired at.
// Units: metres, +x forward, +y up, z toward the camera. Everything is a pure function of the loop time s (scrub safe).
(function(){
window.SIGB=window.SIGB||{};
const BB=window.BB,T=BB.T,{V,clamp,sm,lam,place,limb,Tube,ik,Y}=BB;
// low-poly ellipsoid (the shared BB sphere is 18x12; hundreds of them per scene are too heavy for software GL)
const SPH=new T.SphereGeometry(1,12,8),ell=(par,mat,sx,sy,sz)=>{const m=new T.Mesh(SPH,mat);m.scale.set(sx,sy,sz);par.add(m);return m;};
const rp=(s,a,b)=>clamp((s-a)/(b-a),0,1),eo=u=>1-Math.pow(1-u,3),s2=(s,a,b)=>sm(rp(s,a,b)),tri=(s,a,b,c)=>s2(s,a,b)*(1-s2(s,b,c));
const eb=u=>{u=clamp(u,0,1);const c1=1.70158,c3=c1+1;return 1+c3*Math.pow(u-1,3)+c1*Math.pow(u-1,2);};
const rnd=k=>{const x=Math.sin(k*127.1+311.7)*43758.5453;return x-Math.floor(x);};
const lerpV=(a,b,u)=>a.clone().lerp(b,u);
const CC={},col=c=>CC[c]||(CC[c]=new T.Color(c));
// keyframes: [[t,v],...] -> smooth Hermite through the keys, flat at extrema (so holds hold and overshoot keys overshoot)
function kf(s,k){const n=k.length;if(s<=k[0][0])return k[0][1];if(s>=k[n-1][0])return k[n-1][1];let i=0;while(s>k[i+1][0])i++;
  const t0=k[i][0],t1=k[i+1][0],v0=k[i][1],v1=k[i+1][1],h=t1-t0,u=(s-t0)/h;
  const sl=j=>{if(j<=0||j>=n-1)return 0;const a=k[j][1]-k[j-1][1],b=k[j+1][1]-k[j][1];if(a*b<=0)return 0;return (k[j+1][1]-k[j-1][1])/(k[j+1][0]-k[j-1][0]);};
  const m0=sl(i)*h,m1=sl(i+1)*h,u2=u*u,u3=u2*u;return (2*u3-3*u2+1)*v0+(u3-2*u2+u)*m0+(-2*u3+3*u2)*v1+(u3-u2)*m1;}
// ---------------------------------------------------------------- textures for soft effects
function cv(n,fn){const c=document.createElement('canvas');c.width=c.height=n;const g=c.getContext('2d');fn(g,n);return new T.CanvasTexture(c);}
const rg=(g,n,stops)=>{const r=g.createRadialGradient(n/2,n/2,0,n/2,n/2,n/2);stops.forEach(([a,c])=>r.addColorStop(a,c));g.fillStyle=r;g.fillRect(0,0,n,n);};
const TX={soft:cv(64,(g,n)=>rg(g,n,[[0,'rgba(255,255,255,1)'],[.35,'rgba(255,255,255,.55)'],[1,'rgba(255,255,255,0)']])),
  drop:cv(32,(g,n)=>rg(g,n,[[0,'rgba(255,255,255,1)'],[.55,'rgba(255,255,255,.95)'],[.8,'rgba(255,255,255,.35)'],[1,'rgba(255,255,255,0)']])),
  puff:cv(128,(g,n)=>{for(let k=0;k<7;k++){const a=k*2.4,x=n/2+Math.cos(a)*n*.16,y=n/2+Math.sin(a)*n*.16,r=n*(.24+.05*(k%3)),q=g.createRadialGradient(x,y,0,x,y,r);q.addColorStop(0,'rgba(255,255,255,.55)');q.addColorStop(.6,'rgba(255,255,255,.28)');q.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=q;g.fillRect(0,0,n,n);}}),
  star:cv(64,(g,n)=>{g.translate(n/2,n/2);for(const [sx,sy] of [[1,.1],[.1,1],[.55,.55]]){g.save();if(sx===.55)g.rotate(Math.PI/4);g.scale(sx,sy);const r=g.createRadialGradient(0,0,0,0,0,n/2);r.addColorStop(0,'rgba(255,255,255,1)');r.addColorStop(.3,'rgba(255,255,255,.6)');r.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=r;g.fillRect(-n/2,-n/2,n,n);g.restore();}}),
  bubble:cv(64,(g,n)=>{g.strokeStyle='rgba(255,255,255,.85)';g.lineWidth=3;g.beginPath();g.arc(n/2,n/2,n*.42,0,6.3);g.stroke();g.fillStyle='rgba(255,255,255,.12)';g.fill();g.fillStyle='rgba(255,255,255,.9)';g.beginPath();g.arc(n*.36,n*.34,n*.07,0,6.3);g.fill();}),
  ring:BB.TEX.ring};
// ---------------------------------------------------------------- beams (cylinders) for lightning, tongues, jets
function Beams(sc){const cyl=new T.CylinderGeometry(1,1,1,5),segs=[],rings=[];let us=0,ur=0;
  for(let k=0;k<44;k++){const m=new T.Mesh(cyl,new T.MeshBasicMaterial({color:'#fff',transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending}));m.visible=false;sc.add(m);segs.push(m);}
  for(let k=0;k<6;k++){const m=new T.Mesh(new T.PlaneGeometry(2,2),new T.MeshBasicMaterial({map:BB.TEX.ring,transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending,side:T.DoubleSide}));m.rotation.y=Math.PI/2;m.visible=false;sc.add(m);rings.push(m);}
  return {begin(){us=ur=0;},
    seg(a,b,r,c,op,add){if(us>=segs.length)return;const m=segs[us++];m.visible=true;place(m,a,b);m.scale.x=m.scale.z=r;m.material.color.copy(col(c));m.material.opacity=op===undefined?1:op;},
    bolt(a,b,seed,n,r,c,jit,op){let p=a.clone();const d=b.clone().sub(a),nrm=V(0,1,0).cross(d).normalize(),n2=d.clone().cross(nrm).normalize();for(let i=1;i<=n;i++){const q=a.clone().addScaledVector(d,i/n);if(i<n){q.addScaledVector(nrm,(rnd(seed+i)-.5)*jit);q.addScaledVector(n2,(rnd(seed+i*7)-.5)*jit);}this.seg(p,q,r,c,op);p=q;}},
    vring(pos,r,op,c){if(ur>=rings.length)return;const m=rings[ur++];m.visible=true;m.position.copy(pos);m.scale.set(r,r,1);m.material.opacity=op;m.material.color.copy(col(c));},
    end(){for(let k=us;k<segs.length;k++)segs[k].visible=false;for(let k=ur;k<rings.length;k++)rings[k].visible=false;}};}
// ---------------------------------------------------------------- effects pool: sprites (additive and normal) + ballistic emitters on top of BB.FXPool (ground rings)
function mkFx(sc,NA,NN){const fx=BB.FXPool(sc),pa=[],pn=[];let ua=0,un=0;
  const mk=(add,n,arr)=>{for(let k=0;k<n;k++){const m=new T.SpriteMaterial({map:TX.soft,transparent:true,depthWrite:false,blending:add?T.AdditiveBlending:T.NormalBlending,fog:false});const sp=new T.Sprite(m);sp.visible=false;sp.renderOrder=add?3:2;sc.add(sp);arr.push(sp);}};
  mk(true,NA||76,pa);mk(false,NN||60,pn);const r0=fx.reset,f0=fx.flush;
  fx.reset=()=>{r0();ua=un=0;};fx.flush=()=>{f0();for(let k=ua;k<pa.length;k++)pa[k].visible=false;for(let k=un;k<pn.length;k++)pn[k].visible=false;};
  fx.p=(pos,size,op,c,tx,add,rot,sy)=>{if(op<=.004||size<=0)return;let sp;if(add){if(ua>=pa.length)return;sp=pa[ua++];}else{if(un>=pn.length)return;sp=pn[un++];}
    sp.visible=true;sp.position.copy(pos);sp.scale.set(size,sy?size*sy:size,1);const m=sp.material;m.opacity=op>1?1:op;m.color.copy(col(c));const t=tx||TX.soft;if(m.map!==t)m.map=t;m.rotation=rot||0;};
  // o:{t0,dt,n,life,pos(k),vel(k),g,drag,size(u,k),op(u,k),c(u,k),tx,add,rot(u,k)}; particle k is born at t0+k*dt
  fx.em=(s,o)=>{for(let k=0;k<o.n;k++){const a=s-(o.t0+k*o.dt);if(a<0||a>o.life)continue;const u=a/o.life,p=o.pos(k),v=o.vel?o.vel(k):null;
    if(v){const dr=o.drag?(1-Math.exp(-o.drag*a))/o.drag:a;p.addScaledVector(v,dr);}if(o.g)p.y=Math.max(.01,p.y-.5*o.g*a*a);
    fx.p(p,o.size(u,k),o.op(u,k),o.c(u,k),o.tx,o.add,o.rot?o.rot(u,k):0);}};
  // impact burst: flash core + spark stars + ring, a = seconds since contact
  fx.hit=(pos,a,o)=>{o=Object.assign({n:7,r:.5,sz:.1,c:'#fff3c0',c2:'#ffb347',dust:null},o);if(a<0||a>.6)return;const u=a/.6;
    if(a<.14)fx.p(pos,.55*o.sz*8*(1-a/.14)+.12,.95*(1-a/.14),'#ffffff',TX.star,true,.4);
    fx.p(pos,.3+.5*eo(u),.5*(1-u),o.c2,TX.soft,true);
    for(let i=0;i<o.n;i++){const az=i*2.4+.5,el=.25+(i%3)*.4,d=V(Math.cos(az)*Math.cos(el),Math.abs(Math.sin(el))+.15,Math.sin(az)*Math.cos(el)*.8),e=eo(u);fx.p(pos.clone().addScaledVector(d,o.r*e),o.sz*(1-u)*1.3,1-u,i%2?o.c:o.c2,TX.star,true,i);}
    if(o.dust)for(let i=0;i<4;i++){const az=i*1.6+.3;fx.p(V(pos.x+Math.cos(az)*.35*eo(u),pos.y*.5+.1+.1*u,pos.z+Math.sin(az)*.25*eo(u)),.18+.25*u,.45*(1-u),o.dust,TX.puff,false,i);}};
  return fx;}
// ---------------------------------------------------------------- helpers
function orient(obj,x,up){const xv=x.clone().normalize(),zv=new T.Vector3().crossVectors(xv,up||Y);if(zv.lengthSq()<1e-8)zv.set(0,0,1);zv.normalize();const yv=new T.Vector3().crossVectors(zv,xv);obj.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(xv,yv,zv));}
const rgb=h=>{const c=col(h);return [c.r,c.g,c.b];};
function blob(sc,w,d){const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.004;sh.scale.set(w,d,1);sc.add(sh);return sh;}
// ---------------------------------------------------------------- QUADRUPED
function Quad(sc,o){
  o=Object.assign({col:'#9a7a52',belly:'#d9c9a3',dark:'#33281c',x0:0,z0:0,yaw0:0,sl:.5,pr:[.2,.17,.16],cr:[.22,.2,.18],legU:.3,legL:.3,lr:.045,hip:.45,sprawl:0,
    nl:.34,ns:8,nr0:.085,nr1:.05,na0:.7,nc0:-.4,hlev:-.15,hfol:.3,hl:.12,hh:.09,hw:.085,sn:.1,snh:.04,snw:.045,tl:.5,ts:9,tr0:.06,tr1:.012,ta0:.1,
    eye:.028,eyeY:.55,ears:0,earL:.16,earW:.05,toeL:.05,nb:[.8,.3],fw:.75,skin:null,tprof:null},o);
  const c={o,mats:[],P:null};
  const mk=(hex)=>{const m=lam(hex);c.mats.push({m,base:col(hex).clone(),tube:false});return m;};
  const mat=mk(o.col),bm=mk(o.belly),dk=mk(o.dark);c.mat=mat;c.bm=bm;c.dk=dk;
  const root=c.root=new T.Group();root.rotation.order='YZX';sc.add(root);const pel=c.pel=new T.Group();root.add(pel);const ch=c.chest=new T.Group();ch.position.x=o.sl;pel.add(ch);
  ell(pel,mat,...o.pr);ell(ch,mat,...o.cr);const mh=(o.pr[1]+o.cr[1])/2,mw=(o.pr[2]+o.cr[2])/2;
  ell(pel,mat,o.sl*.62,mh*.98,mw*.98).position.x=o.sl/2;ell(pel,bm,o.sl*.6,mh*.6,mw*.85).position.set(o.sl/2,-mh*.4,0);
  c.hipL=[V(-.02,-o.cr[1]*o.hip,-o.cr[2]*o.fw),V(-.02,-o.cr[1]*o.hip,o.cr[2]*o.fw),V(.0,-o.pr[1]*o.hip,-o.pr[2]*o.fw),V(.0,-o.pr[1]*o.hip,o.pr[2]*o.fw)];
  c.gph=[0,Math.PI,Math.PI,0];c.up=[];c.lo=[];c.kn=[];c.ft=[];c.hipW=[0,1,2,3].map(()=>V(0,0,0));c.foot0=[0,1,2,3].map(()=>V(0,0,0));
  for(let i=0;i<4;i++){const g=i<2?ch:pel;ell(g,mat,o.lr*1.7,o.lr*1.7,o.lr*1.5).position.copy(c.hipL[i]);
    c.up.push(limb(sc,mat,o.lr*1.25,o.lr*.8));c.lo.push(limb(sc,mat,o.lr*.8,o.lr*.5));c.kn.push(ell(sc,mat,o.lr*.8,o.lr*.8,o.lr*.8));c.ft.push(ell(sc,dk,o.toeL,o.lr*.55,o.lr*.9));}
  const tm=()=>{const t=new Tube(o.ns+1,8);t.mesh.material=new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide});c.mats.push({m:t.mesh.material,base:new T.Color('#fff'),tube:true});sc.add(t.mesh);return t;};
  c.neck=tm();const tt=c.tail=new Tube(o.ts+1,8);tt.mesh.material=new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide});c.mats.push({m:tt.mesh.material,base:new T.Color('#fff'),tube:true});sc.add(tt.mesh);
  const top=rgb(o.col),bot=rgb(o.belly);
  c.colf=part=>(i,a,out)=>{const b=sm((-Math.cos(a)-.05)/.8);for(let k=0;k<3;k++)out[k]=top[k]+(bot[k]-top[k])*b;if(o.skin)o.skin(i,a,out,part,top,bot);};
  c.ncol=c.colf('neck');c.tcol=c.colf('tail');
  // head
  const hd=c.head=new T.Group();sc.add(hd);ell(hd,mat,o.hl,o.hh,o.hw).position.x=o.hl*.4;
  const tipX=c.tipX=o.hl*1.3+o.sn;if(o.sn>.005){const L=(tipX-o.hl*.5)/2;ell(hd,mat,L,o.snh,o.snw).position.set(o.hl*.5+L,-o.hh*.22,0);}
  ell(hd,dk,o.snh*.5,o.snh*.45,o.snw*.5).position.set(tipX-.005,-o.hh*.12,0);
  const jw=c.jaw=new T.Group();jw.position.set(o.hl*.1,-o.hh*.5,0);hd.add(jw);const Lj=tipX*.93-o.hl*.1;ell(jw,bm,Lj/2,o.snh*.42,o.snw*.85).position.set(Lj/2,0,0);
  c.mouthIn=ell(jw,lam('#7a2430'),Lj/2*.92,o.snh*.1,o.snw*.7);c.mouthIn.position.set(Lj/2,o.snh*.4,0);c.Lj=Lj;
  c.eyeW=[];c.eyeP=[];c.blind=[];for(const z of [-1,1]){const w=ell(hd,lam('#f4f1e8'),o.eye,o.eye*1.05,o.eye*.85);w.position.set(o.hl*.62,o.hh*o.eyeY,z*o.hw*.8);const p=ell(hd,lam('#111'),o.eye*.5,o.eye*.6,o.eye*.45);p.position.set(o.hl*.62+o.eye*.55,o.hh*o.eyeY,z*(o.hw*.8+o.eye*.4));
    const b=ell(hd,lam('#0a0808'),o.eye*1.2,o.eye*1.2,o.eye*1.05);b.position.set(o.hl*.64,o.hh*o.eyeY,z*o.hw*.82);b.visible=false;c.eyeW.push(w);c.eyeP.push(p);c.blind.push(b);}
  c.ears=[];if(o.ears)for(const z of [-1,1]){const pv=new T.Group();pv.position.set(-o.hl*.15,o.hh*.7,z*o.hw*.75);hd.add(pv);const e=ell(pv,mat,o.earW,o.earL,o.earW*.45);e.position.y=o.earL*.85;const i=ell(pv,lam('#e3a79a'),o.earW*.6,o.earL*.7,o.earW*.3);i.position.set(.004,o.earL*.85,z*o.earW*.25);pv.userData.z=z;c.ears.push(pv);}
  c.tailEnd=new T.Group();sc.add(c.tailEnd);c.shadow=blob(sc,(o.sl+o.pr[0]+o.cr[0])*1.3+.3,(o.pr[2]+o.cr[2])*2.2+.2);
  c.h=(o.legU+o.legL)*.9+o.pr[1]*o.hip+.02;
  const Q=new T.Quaternion(),E=new T.Euler();
  c.pose=function(P){P=P||{};c.P=P;
    root.position.set(P.x===undefined?o.x0:P.x,P.y===undefined?c.h:P.y,P.z===undefined?o.z0:P.z);root.rotation.set(P.roll||0,P.yaw===undefined?o.yaw0:P.yaw,P.pitch||0);
    const sq=P.sq||0;root.scale.set(1+sq*.45,1-sq,1+sq*.45);ch.rotation.set(P.ctw||0,P.cyaw||0,P.bend||0);ch.scale.setScalar(1+(P.br||0));
    root.updateMatrixWorld(true);
    const F=V(1,0,0).applyQuaternion(root.quaternion);F.y=0;if(F.lengthSq()<1e-6)F.set(1,0,0);F.normalize();const fyaw=Math.atan2(-F.z,F.x),W=V(0,0,1).applyQuaternion(root.quaternion);
    for(let i=0;i<4;i++){const g=i<2?ch:pel,hip=g.localToWorld(c.hipL[i].clone());c.hipW[i].copy(hip);
      const fl=P.follow||0,dyw=(P.yaw===undefined?o.yaw0:P.yaw)-o.yaw0,cy=Math.cos(dyw),sy=Math.sin(dyw),rx=c.foot0[i].x-c.root0.x,rz=c.foot0[i].z-c.root0.z,ft=V(c.root0.x+rx*cy+rz*sy+fl*(root.position.x-c.root0.x),c.foot0[i].y,c.root0.z-rx*sy+rz*cy+fl*(root.position.z-c.root0.z));
      const gt=P.gait;if(gt){const ph=gt.ph+c.gph[i];ft.addScaledVector(F,gt.amp*Math.sin(ph));ft.y+=gt.lift*Math.max(0,Math.cos(ph));}
      ft.y+=(P.fy||0);const fo=P.foot&&P.foot[i];if(fo){ft.x+=fo[0];ft.y+=fo[1];ft.z+=fo[2];}
      if(P.limp){const lp=hip.clone().add(V(.06,-(o.legU+o.legL)*.8,0).applyQuaternion(root.quaternion));lp.x+=.05*Math.sin((P.lt||0)*7+i*2);lp.y+=.04*Math.sin((P.lt||0)*9+i);ft.lerp(lp,P.limp);}
      const fwdSide=i<2?-1:1,spr=o.sprawl,zs=c.hipL[i].z>0?1:-1;
      const pole=F.clone().multiplyScalar(fwdSide*(1-spr)).addScaledVector(W,zs*spr*1.2).add(V(0,.5*spr,0));
      const r=ik(hip,ft,o.legU,o.legL,pole);if(r.knee.y<.03)r.knee.y=.03;place(c.up[i],hip,r.knee);place(c.lo[i],r.knee,r.foot);c.kn[i].position.copy(r.knee);
      c.ft[i].position.copy(r.foot).addScaledVector(F,o.toeL*.55);c.ft[i].position.y=Math.max(r.foot.y,0)+o.lr*.2;c.ft[i].rotation.set(0,fyaw,0);}
    // neck (chest local) -> world
    const cm=ch.matrixWorld,np=[],nb=V(o.cr[0]*o.nb[0],o.cr[1]*o.nb[1],0);np.push(nb.clone());let th=0,ph=0;const st=o.nl/o.ns;
    for(let j=0;j<o.ns;j++){const u=(j+.5)/o.ns;th=o.na0+(P.na||0)+(o.nc0+(P.nc||0))*u;ph=(P.ny||0)*u;if(P.nx){const e=P.nx(u);th+=e[0];ph+=e[1];}
      nb.x+=Math.cos(th)*Math.cos(ph)*st;nb.y+=Math.sin(th)*st;nb.z+=Math.cos(th)*Math.sin(ph)*st;np.push(nb.clone());}
    np.forEach(p=>p.applyMatrix4(cm));const nrad=np.map((p,i)=>(o.nr0+(o.nr1-o.nr0)*i/o.ns)*(P.nrf?P.nrf(i/o.ns):1));c.neck.update(np,nrad,c.ncol,Y);
    const thE=th,hp=thE*o.hfol+o.hlev+(P.hp||0);ch.getWorldQuaternion(Q);E.set(P.hr||0,ph+(P.hy||0),hp,'YZX');hd.position.copy(np[o.ns]);hd.quaternion.copy(Q).multiply(new T.Quaternion().setFromEuler(E));
    c.jaw.rotation.z=-(P.jaw||0);c.mouthIn.visible=(P.jaw||0)>.05;c.neckPts=np;
    c.ears.forEach(pv=>{const e=P.ear||0;pv.rotation.set(pv.userData.z*(.35+.35*(P.earOut||0)),0,e*1.3+(P.ear2?P.ear2*Math.sin((P.lt||0)*20):0));});
    // tail (pelvis local)
    const tp=[],tb=V(-o.pr[0]*.85,o.pr[1]*.1,0);tp.push(tb.clone());const ts=o.tl/o.ts;let tth=0,tph=0;
    for(let j=0;j<o.ts;j++){const u=(j+.5)/o.ts;tth=o.ta0+(P.ta||0)+(P.tc||0)*u;tph=(P.ty||0)*u;if(P.tx){const e=P.tx(u);tth+=e[0];tph+=e[1];}
      tb.x-=Math.cos(tth)*Math.cos(tph)*ts;tb.y+=Math.sin(tth)*ts;tb.z+=Math.cos(tth)*Math.sin(tph)*ts;tp.push(tb.clone());}
    const pm=pel.matrixWorld;tp.forEach(p=>p.applyMatrix4(pm));const trad=tp.map((p,i)=>(o.tr0+(o.tr1-o.tr0)*i/o.ts)*(o.tprof?o.tprof(i/o.ts):1));c.tail.update(tp,trad,c.tcol,Y);c.tailPts=tp;
    const te=tp[o.ts],td=te.clone().sub(tp[o.ts-1]);c.tailEnd.position.copy(te);orient(c.tailEnd,td,Y);
    c.shadow.position.set(root.position.x,.004,root.position.z);c.shadow.rotation.z=-(P.yaw===undefined?o.yaw0:P.yaw);
    c.shadow.material.opacity=1;hd.updateMatrixWorld(true);
  };
  c.mouth=(f)=>c.head.localToWorld(V(c.tipX*(f||1),-o.hh*.3,0));
  c.root0=V(0,0,0);c.pose({});c.root0=root.position.clone();for(let i=0;i<4;i++)c.foot0[i].set(c.hipW[i].x,.015,c.hipW[i].z);c.pose({});
  c.tint=(hex,amt)=>{for(const m of c.mats){if(m.tube)m.m.color.set('#ffffff').lerp(col(hex||'#fff'),amt||0);else m.m.color.copy(m.base).lerp(col(hex||'#fff'),amt||0);}};
  c.flash=(r,g,b)=>{for(const m of c.mats)m.m.emissive.setRGB(r,g,b);};
  return c;}
// ---------------------------------------------------------------- PIP: the little herbivore every attack is fired at (faces -x)
function Pip(sc,x,o){o=Object.assign({col:'#c9a86a',belly:'#efe0b4',y0:0,z0:0,shield:false,s:1},o);
  const d=Quad(sc,{col:o.col,belly:o.belly,dark:'#5e4b30',x0:x,z0:o.z0,yaw0:Math.PI,sl:.34,pr:[.17,.15,.13],cr:[.19,.19,.15],legU:.2,legL:.21,lr:.034,nl:.3,ns:7,nr0:.07,nr1:.05,na0:.95,nc0:-.55,hlev:-.1,hl:.1,hh:.08,hw:.075,sn:.06,snh:.04,snw:.04,tl:.26,ts:6,tr0:.04,tr1:.014,ta0:.35,ears:1,earL:.15,earW:.045,eye:.025,toeL:.04,
    skin:(i,a,out,part,top)=>{if(part==='tail'&&i>=5){out[0]=.95;out[1]=.92;out[2]=.82;}}});
  d.x0=x;d.y0=o.y0;d.stars=[0,1,2].map(()=>{const m=new T.Sprite(new T.SpriteMaterial({map:TX.star,color:'#ffe066',transparent:true,depthWrite:false,blending:T.AdditiveBlending}));m.visible=false;sc.add(m);return m;});
  d.quills=[[.1,.1,.06],[.0,.14,-.05],[.12,-.02,.09],[-.06,.1,.08],[.14,.06,-.08]].map(([qx,qy,qz],k)=>{const q=new T.Mesh(new T.ConeGeometry(.01,.34,5),lam('#efe6cc'));q.geometry.translate(0,.17,0);q.visible=false;d.chest.add(q);q.position.set(.1+qx*.4,qy*.5,qz*1.1);q.rotation.set(0,0,Math.PI/2+.5-k*.25);q.rotation.x=(k-2)*.2;q.userData.k=k;return q;});
  d.hoof=null;
  if(o.shield){d.shield=new T.Mesh(new T.CylinderGeometry(.22,.22,.04,18),lam('#7aa6b0'));d.shield.rotation.z=Math.PI/2;d.shield.position.set(.24,0,0);d.chest.add(d.shield);d.shards=[0,1,2,3,4,5].map(k=>{const m=new T.Mesh(new T.BoxGeometry(.1,.07,.025),lam('#8fb6c0'));m.visible=false;sc.add(m);return m;});}
  // dizzy/burn/etc helpers set from attack code
  d.set=function(s,A,R){A=A||{};const idl=idleP(s,true);const P={};for(const k in idl)P[k]=idl[k];
    for(const k in A){if(k==='dx')P.x=x+A.dx;else if(k==='dy')P.y=d.h+A.dy;else if(k==='dz')P.z=o.z0+A.dz;else if(k==='yaw')P.yaw=Math.PI+A.yaw;else if(ADD[k])P[k]=(P[k]||0)+A[k];else P[k]=A[k];}
    if(P.y===undefined)P.y=d.h;P.y+=o.y0;P.lt=s;d.pose(P);
    const f=A.flash||0;d.flash(f*(A.fr===undefined?.9:A.fr),f*(A.fg===undefined?.8:A.fg),f*(A.fb===undefined?.4:A.fb));d.tint(A.tint,A.tamt||0);
    d.blind.forEach(b=>b.visible=!!A.blind);d.eyeW.forEach(e=>e.visible=!A.blind);d.eyeP.forEach(e=>e.visible=!A.blind);
    const st=A.stars||0;d.stars.forEach((q,k)=>{q.visible=st>.05;if(q.visible){const a=s*7+k*2.1,hp=d.head.position;q.position.set(hp.x+.15*Math.cos(a),hp.y+.2+.02*Math.sin(a*2),hp.z+.15*Math.sin(a));q.scale.setScalar(.09*st);}});
    d.quills.forEach((q,k)=>{const v=A.quills||0;q.visible=v>k;});
    if(d.shield){d.shield.visible=!A.nosh;}
    return P;};
  return d;}
const ADD={na:1,nc:1,hp:1,hy:1,ny:1,br:1,bend:1,pitch:1,roll:1,ear:1,ta:1,tc:1,jaw:1,ctw:1,cyaw:1,sq:1};
// idle: watching the attacker, breathing, ears twitching, tail sway
function idleP(s,watch){return {br:.014*Math.sin(s*2.6),na:.05*Math.sin(s*1.3),hy:watch?.0:0,ear:.12+.08*Math.max(0,Math.sin(s*1.7)),ta:.06*Math.sin(s*1.9),tx:u=>[0,.35*u*Math.sin(s*2.3-u*3)]};}
// ---------------------------------------------------------------- SERPENT rig (tube body + head with jaw, tongue and optional hood)
function Serp(sc,o){o=Object.assign({n:22,nv:10,col:'#6b5a2e',belly:'#d8c58a',rf:u=>.03+.045*Math.sin(Math.PI*Math.min(1,u*1.1+.03)),hl:.085,hh:.045,hw:.055,eye:.014,hood:0,eel:0,band:0,bandCol:'#2a2010',eyeCol:'#f2d36a'},o);
  const c={o},tube=c.tube=new Tube(o.n+1,o.nv);tube.mesh.material=new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide});sc.add(tube.mesh);
  const top=rgb(o.col),bot=rgb(o.belly),bd=rgb(o.bandCol);
  const colf=(i,a,out)=>{const b=sm((-Math.cos(a)-.1)/.7),u=i/o.n;let m=0;if(o.band){const q=(u*o.band)%1;m=sm((.25-Math.abs(q-.5))/.12)*(1-b)*.8;}
    for(let k=0;k<3;k++){const v=top[k]+(bd[k]-top[k])*m;out[k]=v+(bot[k]-v)*b;}};
  const hd=c.head=new T.Group();sc.add(hd);const hm=lam(o.col),pale=lam(o.belly);
  ell(hd,hm,o.hl,o.hh,o.hw).position.x=o.hl*.4;ell(hd,pale,o.hl*.85,o.hh*.5,o.hw*.85).position.set(o.hl*.45,-o.hh*.4,0);
  const jw=c.jaw=new T.Group();jw.position.set(o.hl*.1,-o.hh*.55,0);hd.add(jw);ell(jw,pale,o.hl*.8,o.hh*.28,o.hw*.8).position.x=o.hl*.7;c.mouthIn=ell(jw,lam('#8a2230'),o.hl*.7,o.hh*.1,o.hw*.65);c.mouthIn.position.set(o.hl*.7,o.hh*.28,0);
  c.fangs=[-1,1].map(z=>{const f=new T.Mesh(new T.ConeGeometry(.007,.04,5),lam('#f4f1e2'));f.position.set(o.hl*1.15,-o.hh*.55,z*o.hw*.4);f.rotation.z=Math.PI;hd.add(f);return f;});
  for(const z of [-1,1]){const e=ell(hd,lam(o.eyeCol),o.eye,o.eye,o.eye*.85);e.position.set(o.hl*.9,o.hh*.45,z*o.hw*.8);const p=ell(hd,lam('#0b0b0b'),o.eye*.35,o.eye*.9,o.eye*.35);p.position.set(o.hl*.9+o.eye*.4,o.hh*.45,z*(o.hw*.8+o.eye*.4));}
  const tg=c.tongue=new T.Group();tg.position.set(o.hl*1.3,-o.hh*.3,0);hd.add(tg);const tm=lam('#d83a4a');const t0=new T.Mesh(new T.CylinderGeometry(.004,.004,1,5),tm);t0.rotation.z=Math.PI/2;t0.position.x=.5;tg.add(t0);
  for(const z of [-1,1]){const f=new T.Mesh(new T.CylinderGeometry(.003,.002,.3,5),tm);f.position.set(1.08,0,z*.02);f.rotation.z=Math.PI/2;f.rotation.x=z*.5;tg.add(f);}tg.visible=false;
  if(o.hood){const hg=new T.Group();sc.add(hg);c.hoodG=hg;const hm2=new T.MeshLambertMaterial({color:o.col,side:T.DoubleSide});const hb=ell(hg,hm2,.03,1,1);hb.position.x=-.01;
    const bel=new T.Mesh(new T.CircleGeometry(.62,24),new T.MeshLambertMaterial({color:'#e2cf8a',side:T.DoubleSide}));bel.rotation.y=Math.PI/2;bel.position.x=.04;bel.position.y=-.05;hg.add(bel);
    const sp=new T.Mesh(new T.RingGeometry(.2,.3,18),new T.MeshBasicMaterial({color:'#2a1f0d',side:T.DoubleSide}));sp.rotation.y=Math.PI/2;sp.position.set(.045,-.12,0);hg.add(sp);c.hoodB=hb;}
  c.set=function(pts,P){P=P||{};const n=o.n,rad=pts.map((p,i)=>o.rf(i/n)*(P.rs||1));tube.update(pts,rad,colf,Y);
    const dir=pts[n].clone().sub(pts[n-2]);hd.position.copy(pts[n]);orient(hd,P.hdir||dir,Y);
    if(P.hroll)hd.rotateX(P.hroll);c.jaw.rotation.z=-(P.jaw||0);c.mouthIn.visible=(P.jaw||0)>.06;c.fangs.forEach(f=>f.visible=(P.jaw||0)>.2);
    const tgv=P.tg||0;c.tongue.visible=tgv>.02;c.tongue.scale.set(tgv*.16,1,1);
    if(o.hood){const h=P.hood||0,g=c.hoodG;g.visible=h>.03;if(h>.03){const nd=pts[n-1].clone().sub(pts[n-5]).normalize();const p5=pts[n-3];g.position.copy(p5).addScaledVector(nd,.0);const yv=nd.clone(),zv=(P.hz||V(0,0,1)).clone(),xv=new T.Vector3().crossVectors(yv,zv).normalize();if(xv.x<0)xv.negate();zv.crossVectors(xv,yv);
      g.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(xv,yv,zv));g.scale.set(1,.2*h*(P.hh||1)+.02,.22*h)}}};
  c.setGlow=(r,g,b)=>{tube.mesh.material.emissive.setRGB(r,g,b);};
  return c;}
Object.assign(BB,{sig:{ell,rp,eo,s2,tri,eb,rnd,lerpV,col,kf,TX,Beams,mkFx,orient,rgb,blob,Quad,Pip,Serp,idleP}});
})();
