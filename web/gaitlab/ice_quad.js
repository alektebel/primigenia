'use strict';
// Primigenia ice lab: the two quadrupeds and their ice. "Rimeback" is the performer (cryo gland in the throat: a pale sac that glows blue-white when charged,
// rime on the skin, ice crystals along the spine); the target is a plain tan grazer. Both come from one parametric builder, driven by a pose record P (pure data),
// so rigs can compute poses at any time (mouth position for particle origins) without touching meshes.
// Pose P (all optional): x,y,z,yaw,s | crouch,pitch,roll,bob | neckA,neckE,headA,jaw | sac,glow | D (walk distance),amp,stiff,stomp | tw,tz (tail yaw/pitch) |
//   frost (0..1 rime on the body),legFrost,spot (hit patch),flash | shiver | cold (blue tint)
(function(root){
const IC=root.IC,T=IC.T,BB=IC.BB,{V,clamp,sm,lerp,lam,ell,place,ik,easeIO,hash}=IC;
const TAU=Math.PI*2;
const _e=new T.Euler(),_q=new T.Quaternion();
const mk=(x,y,z,rz)=>new T.Matrix4().compose(V(x,y,z),_q.clone().setFromEuler(_e.set(0,0,rz||0)),V(1,1,1));
function dims(P){const c=P.crouch||0,e=P.neckE||0;return {hipH:.5-.14*c+(P.bob||0),neckLen:.3+.14*e,s:P.s||1};}
// skeleton positions in the world (head, mouth, throat sac, nose) for any pose
function skel(P){
  const d=dims(P),mR=new T.Matrix4().compose(V(P.x||0,P.y||0,P.z||0),_q.clone().setFromEuler(_e.set(0,P.yaw||0,0)),V(d.s,d.s,d.s));
  const mB=mR.clone().multiply(new T.Matrix4().compose(V(0,d.hipH,0),_q.clone().setFromEuler(_e.set(P.roll||0,0,P.pitch||0)),V(1,1,1)));
  const mN=mB.clone().multiply(mk(.5,.1,0,P.neckA||0)),mH=mN.clone().multiply(mk(d.neckLen,.08,0,P.headA||0)),pt=(m,x,y,z)=>V(x,y,z).applyMatrix4(m),j=P.jaw||0;
  return {mouth:pt(mH,.36,-.045-.075*j,0),sac:pt(mN,.18,-.1,0),nose:pt(mH,.4,.0,0),head:pt(mH,.1,0,0),chest:pt(mB,.42,.02,0),back:pt(mB,0,.3,0),
    axis:V(1,0,0).transformDirection(mH),up:V(0,1,0).transformDirection(mH),mH,mB,mR};}
const COL={
  cryo:{skin:'#6e8a9c',belly:'#d6e5ec',dark:'#38505f',eye:'#bfefff',paw:'#c9dae2'},
  prey:{skin:'#a9824e',belly:'#e6d9b5',dark:'#5e4527',eye:'#fff8e8',paw:'#d8c9a0'}};
const FROST='#e4f6ff',COLD='#8fc4e6';
function buildQuad(scene,style){
  const cryo=style==='cryo',C=COL[style],o={cryo,mats:[],style};
  const skin=lam(C.skin),belly=lam(C.belly),dark=lam(C.dark),paw=lam(C.paw);o.mats=[skin,belly,dark,paw];o.base=o.mats.map(m=>m.color.clone());
  const white=lam('#ffffff'),pup=lam('#10161a'),eye=lam(C.eye);
  const root_=new T.Group();scene.add(root_);o.root=root_;const B=new T.Group();root_.add(B);o.B=B;
  ell(B,skin,.52,.27,.3);ell(B,skin,.3,.3,.27).position.set(.34,.03,0);ell(B,skin,.28,.27,.27).position.set(-.3,0,0);ell(B,belly,.45,.15,.26).position.set(.02,-.1,0);
  // back marks / crest
  if(cryo){o.crest=[];for(let k=0;k<8;k++){const g=IC.spikeMesh(.1+.06*Math.sin(k*.9+1),.032,.75,5);g.position.set(.38-k*.11,.28-.02*Math.abs(k-2),0);g.rotation.z=-.15+k*.06;g.userData.k=k;B.add(g);o.crest.push(g);}}
  else{for(const [x,z] of [[-.2,.1],[0,-.14],[.2,.09],[-.34,-.08]]){ell(B,dark,.09,.04,.09).position.set(x,.255,z);}}
  // neck + head
  const N=new T.Group();N.position.set(.5,.1,0);B.add(N);o.N=N;o.neckM=ell(N,skin,.2,.12,.12);
  const H=new T.Group();B.add(H);H.position.set(.3,.08,0);N.add(H);o.H=H;
  ell(H,skin,.17,.12,.12).position.set(.08,0,0);const snL=cryo?.24:.18;o.snout=ell(H,skin,snL,.07,.075);o.snout.position.set(.26,-.015,0);
  ell(H,dark,.02,.016,.03).position.set(.26+snL*.95,.01,0);
  const J=new T.Group();J.position.set(.12,-.06,0);H.add(J);o.J=J;ell(J,belly,.15+(cryo?.04:0),.032,.052).position.set(.1,-.01,0);o.mouthIn=ell(H,lam('#3a1620'),.15,.02,.06);o.mouthIn.position.set(.2,-.05,0);
  o.tongue=ell(J,lam('#d9707e'),.09,.012,.035);o.tongue.position.set(.12,.012,0);
  o.eyes=[-1,1].map(s=>{const g=new T.Group();g.position.set(.14,.06,s*.095);H.add(g);const w=ell(g,white,.034,.034,.026);ell(g,eye,.026,.026,.02).position.x=.01;ell(g,pup,.014,.018,.012).position.x=.026;const lid=ell(g,skin,.036,.02,.03);lid.position.y=.03;return {g,lid,s};});
  if(cryo){ // frill crystals on the head and a pale crest; the rest of the cryo gland is the throat sac
    for(const s of [-1,1]){const c=IC.spikeMesh(.13,.03,.75,5);c.position.set(.02,.1,s*.07);c.rotation.set(s*.35,0,-.6);H.add(c);}
    o.sacMat=new T.MeshPhongMaterial({color:'#bfeaf7',emissive:'#1d6e96',specular:'#ffffff',shininess:80,transparent:true,opacity:.96});
    o.sac=new T.Mesh(BB.GEO.sph,o.sacMat);o.sac.position.set(.18,-.1,0);N.add(o.sac);
    o.sacGlow=new T.Sprite(new T.SpriteMaterial({map:IC.TEX.puff,transparent:true,depthWrite:false,blending:T.AdditiveBlending,color:'#8fe0ff'}));o.sacGlow.position.set(.18,-.1,0);N.add(o.sacGlow);
    // vein rings on the sac
    o.veins=[];for(let k=0;k<3;k++){const v=new T.Mesh(new T.TorusGeometry(1,.05,5,20),new T.MeshBasicMaterial({color:'#e7fbff',transparent:true,opacity:.4}));v.rotation.y=Math.PI/2;v.position.copy(o.sac.position);N.add(v);o.veins.push(v);}
  }else{for(const s of [-1,1]){const ear=ell(H,skin,.04,.075,.025);ear.position.set(-.02,.12,s*.075);ear.rotation.z=.2;ell(H,lam('#d68a8a'),.02,.045,.014).position.set(-.02,.12,s*.083);}}
  // tail: 3 chained segments
  o.tl=[];let par=B;const L=[[-.46,.04,.2,.085],[-.34,0,.17,.065],[-.3,0,.15,.04]];
  for(const [x,y,l,r] of L){const g=new T.Group();g.position.set(x,y,0);par.add(g);ell(g,skin,l,r,r).position.x=-l*.8;o.tl.push(g);par=g;}
  if(cryo){const c=IC.spikeMesh(.2,.04,.75,5);c.rotation.z=Math.PI/2;c.position.x=-.3;par.add(c);o.tailTip=c;}
  // legs
  o.legs=[0,1,2,3].map(i=>{const front=i<2,up=BB.limb(root_,skin,front?.065:.075,.04),lo=BB.limb(root_,dark,.04,.03),kn=ell(root_,skin,.05,.05,.05),ft=ell(root_,paw,.07,.032,.052);
    const boot=ell(root_,lam(FROST),.09,.05,.07);boot.visible=false;return {up,lo,kn,ft,boot,front,side:i%2?1:-1};});
  // rime patches on the skin (both flanks) and hit patches on the shoulder
  const rm=new T.MeshLambertMaterial({color:'#f0fbff',emissive:'#2c5068'});o.rime=[];
  const RP=[[-.3,.26,.1,.08],[0,.28,.13,.09],[.3,.28,.1,.08],[.12,.2,.25,.08],[-.2,.16,.27,.07],[.42,.16,.2,.06],[-.45,.12,.16,.07],[.52,.22,.12,.06],[0,.1,.28,.07],[.28,.06,.27,.065],[-.12,.28,-.1,.06],[.2,.28,-.12,.07]];
  RP.forEach((p,i)=>{for(const s of [1,-1]){if(i>=10&&s<0)continue;const m=ell(B,rm,p[3]*1.5,p[3]*.5,p[3]*1.1);m.position.set(p[0],p[1],p[2]*s*(i>=10?1:1));m.rotation.set(s*.5,0,0);o.rime.push({m,i,r:p[3]});}});
  o.spot=new T.Group();B.add(o.spot);for(const s of [-1,1]){const g=new T.Group();g.position.set(.34,.12,s*.2);g.rotation.x=s*1.0;o.spot.add(g);for(let k=0;k<5;k++){const c=IC.spikeMesh(.08+.07*hash(k,3),.03,.8,5);c.position.set(.05*Math.cos(k*1.3),0,.05*Math.sin(k*1.3));c.rotation.set(Math.sin(k)*.5,0,Math.cos(k*2)*.5);g.add(c);}ell(g,rm,.12,.02,.1);}
  o.shadow=IC.shadowBlob(scene);
  return o;}
function drawQuad(o,P){
  const d=dims(P),s=d.s,sk=P.shiver?(Math.sin((P.t||0)/23)*P.shiver*.006):0;
  o.root.position.set(P.x||0,(P.y||0),P.z||0);o.root.rotation.y=P.yaw||0;o.root.scale.setScalar(s);
  o.B.position.set(sk,d.hipH+(sk?Math.sin((P.t||0)/17)*sk:0),0);o.B.rotation.set(P.roll||0,0,P.pitch||0);
  const e=P.neckE||0;o.N.rotation.z=P.neckA||0;o.N.rotation.y=P.neckY||0;o.H.rotation.y=P.headY||0;o.neckM.scale.set(.2+.07*e,.12,.12);o.neckM.position.x=.14+.07*e;
  o.H.position.set(d.neckLen,.08,0);o.H.rotation.z=P.headA||0;const j=P.jaw||0;o.J.rotation.z=-j*.8;o.mouthIn.visible=j>.1;o.mouthIn.scale.set(.15,.02+.04*j,.06);o.mouthIn.position.set(.2,-.05-.03*j,0);o.tongue.visible=j>.3;
  const bl=P.blink||0;o.eyes.forEach(E=>{E.lid.scale.set(.036,.02+.018*Math.max(bl,P.squint||0),.03);E.lid.position.y=.034-.026*Math.max(bl,P.squint||0);});
  if(o.cryo){const sc=P.sac||0,gl=P.glow||0,pul=P.pulse||0;o.sac.scale.set(.1+.07*sc+.02*pul,.06+.1*sc+.03*pul,.1+.07*sc+.02*pul);o.sac.position.set(.18,-.085-.04*sc,0);
    o.sacMat.emissive.setRGB(.05+.45*gl,.28+.55*gl,.4+.6*gl);o.sacMat.color.set('#bfeaf7').lerp(new T.Color('#f3feff'),gl*.7);
    o.sacGlow.position.copy(o.sac.position);const gs=.12+.55*gl+.12*pul;o.sacGlow.scale.set(gs,gs,1);o.sacGlow.material.opacity=Math.min(1,.15+.85*gl);o.sacGlow.visible=gl>.02;
    o.veins.forEach((v,k)=>{v.position.copy(o.sac.position);v.scale.set(.02,o.sac.scale.y*(1.02+.0*k),o.sac.scale.z*(1.02));v.position.x+=(k-1)*o.sac.scale.x*.5;v.scale.y*=1-.4*Math.abs(k-1);v.scale.z*=1-.4*Math.abs(k-1);v.material.opacity=.15+.7*gl;});
    o.crest.forEach(c=>{const g=1+.35*(P.glow||0);c.scale.setScalar(g);});}
  // tail swing
  const tw=P.tw||0,tz=P.tz||0,tt=(P.t||0)/1000;o.tl.forEach((g,k)=>{g.rotation.y=tw*(k+1)*.55+.1*Math.sin(tt*1.6-k*.8);g.rotation.z=tz*(k+1)*.5+.04*Math.sin(tt*2.1-k);});
  // legs (root-local space)
  const qB=new T.Quaternion().setFromEuler(new T.Euler(P.roll||0,0,P.pitch||0)),amp=P.amp===undefined?0:P.amp,stiff=P.stiff||0,S=.62,f=.6,A=S*f/2,offs=[0,.5,.75,.25];
  o.legs.forEach((l,i)=>{const hx=l.front?.34:-.3,hz=l.side*.2,hip=V(hx,-.06,hz).applyQuaternion(qB).add(V(sk,d.hipH,0));
    const ph=(((P.D||0)/S+offs[i])%1+1)%1;let fx=0,lift=0;
    if(amp>0){if(ph<f){fx=A-2*A*(ph/f);}else{const w=(ph-f)/(1-f);fx=-A+2*A*easeIO(w);lift=.11*(1-.55*stiff)*Math.sin(Math.PI*w);}fx*=amp;lift*=amp;}
    let fy=.035+lift+.15*(P.tuck||0),fxx=hx+fx+(P.splay||0)*(l.front?1:-1)*.05+(l.front?.12:-.1)*(P.tuck||0);
    if(i===1&&(P.stomp||0)>0){const k=P.stomp;fy+=.34*k;fxx+=.14*k;}
    if(P.crouch)fxx+=0;const foot=V(fxx,fy,hz*1.14+l.side*(P.splay||0)*.04),pole=l.front?V(-.4,1,0):V(.5,1,0),r=ik(hip,foot,.27,.27,pole);
    place(l.up,hip,r.knee);place(l.lo,r.knee,r.foot);l.kn.position.copy(r.knee);l.ft.position.copy(r.foot);l.ft.position.y+=.0;
    const lf=P.legFrost||0;l.boot.visible=lf>.02;if(l.boot.visible){l.boot.position.copy(r.foot);l.boot.position.y+=.012;l.boot.scale.set(.09+.05*lf,.04+.08*lf,.07+.05*lf);}});
  // colour: rime tint (white-blue) and cold tint
  const fr=P.frost||0,cold=P.cold||0,fl=P.flash||0;o.mats.forEach((m,i)=>{m.color.copy(o.base[i]).lerp(new T.Color(COLD),cold*.55).lerp(new T.Color(FROST),fr*.4);m.emissive.setRGB(fl,fl,fl);});
  const nR=o.rime.length;o.rime.forEach(r=>{const k=clamp(fr*14-r.i*1.1,0,1),g=sm(k);r.m.visible=g>.02;r.m.scale.set(r.r*.95*g,r.r*.36*g,r.r*.75*g);});
  o.spot.visible=(P.spot||0)>.02;o.spot.scale.setScalar(Math.max(.01,(P.spot||0)));
  o.shadow.position.set(P.x||0,.003,P.z||0);o.shadow.scale.set(1.5*s,.9*s,1);o.shadow.rotation.z=-(P.yaw||0);
}
IC.COL=COL;
// ------------------------------------------------------------------ the ice shell that encases a creature (grow, crack, thaw, shatter is done with IC.burst)
function buildShell(scene){
  const g=new T.Group();scene.add(g);const sh={g};
  const geo=IC.jitterGeo(new T.IcosahedronGeometry(1,2),.09,17);
  sh.out=IC.iceSolid(geo,.58,{core:.14});sh.out.scale.set(.98,.6,.44);sh.out.position.set(.04,.36,0);g.add(sh.out);
  sh.cr=[];const R=BB.rng(4);for(let k=0;k<13;k++){const th=R()*TAU,ph=.3+R()*1.8,L=.14+R()*.22,c=IC.spikeMesh(L,.045+R()*.03,.7,6);const nx=Math.cos(th)*Math.sin(ph),ny=Math.cos(ph),nz=Math.sin(th)*Math.sin(ph);
    c.position.set(.04+nx*.9,.36+ny*.55,nz*.4);c.quaternion.setFromUnitVectors(Y_,V(nx,ny*.8,nz).normalize());c.userData={d:k/13};g.add(c);sh.cr.push(c);}
  sh.pud=new T.Mesh(new T.CircleGeometry(1,24),new T.MeshPhongMaterial({color:'#cfeeff',specular:'#fff',shininess:90,transparent:true,opacity:.0,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-3,polygonOffsetUnits:-3}));sh.pud.rotation.x=-Math.PI/2;sh.pud.position.y=.012;g.add(sh.pud);
  sh.cracks=[];for(const z of [-1,1]){const m=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:IC.TEX.crack,transparent:true,opacity:0,depthWrite:false}));m.position.set(.05,.38,z*.455);m.scale.set(1.6,.9,1);if(z<0)m.rotation.y=Math.PI;g.add(m);sh.cracks.push(m);}
  return sh;}
const Y_=V(0,1,0);
// grow 0..1 (encasing), thaw 0..1 (melting), crack 0..1, wob (jolt), P = root pose of the creature inside
function drawShell(sh,P,grow,thaw,crack,wob){
  const vis=grow>.002&&thaw<.999;sh.g.visible=vis;if(!vis)return;
  sh.g.position.set(P.x||0,P.y||0,P.z||0);sh.g.rotation.y=P.yaw||0;const s=P.s||1;sh.g.scale.setScalar(s);
  const gr=IC.back(grow),k=lerp(.55,1,gr)*(1-.1*thaw);sh.out.scale.set(.98*k,.6*k*(1-.3*thaw),.44*k);sh.out.position.y=.36*k*(1-.25*thaw)+.0;
  IC.iceOpacity(sh.out,IC.easeOut(grow)*(1-.85*thaw));
  sh.cr.forEach(c=>{const g=clamp((grow-.1-c.userData.d*.5)/.4,0,1),sc=IC.back(g)*(1-thaw);c.scale.setScalar(Math.max(.001,sc));c.visible=sc>.01;});
  sh.pud.scale.setScalar(.55+.35*grow+.5*thaw);sh.pud.material.opacity=.7*IC.easeOut(grow)*(1-.75*sm((thaw-.5)/.5));
  sh.cracks.forEach(m=>{m.material.opacity=.95*crack*(1-thaw*.6);});
  if(wob){sh.g.rotation.z=.03*wob*Math.sin((P.t||0)/21);}else sh.g.rotation.z=0;
}
// ------------------------------------------------------------------ a walker: position along a line with speed slowed by chill, stopped while frozen, recovering after a thaw or shatter
// cfg: x0,v0 (m/s),dir,t0,len,chill(t)->0..1,freezeAt,growMs,thawAt,thawMs,shatterAt,flinches[]
function makeWalker(c){
  const growMs=c.growMs||340,endIce=c.freezeAt==null?0:((c.shatterAt!=null&&c.shatterAt>c.freezeAt+growMs*.6)?c.shatterAt:c.thawAt+c.thawMs),rec=c.recoverMs||1500,sh=c.shatterAt!=null&&c.freezeAt!=null&&c.shatterAt>c.freezeAt+growMs*.6;
  const spd=t=>{if(t<c.t0)return 0;let v=1-.88*(c.chill?c.chill(t):0);if(c.freezeAt!=null&&t>=c.freezeAt+growMs*.4){if(t<endIce)return 0;const r=sm((t-endIce)/rec);v*=r*(sh?lerp(.6,1,sm((t-endIce-1800)/1500)):1);}return v;};
  const Dt=IC.integ(t=>spd(t)*c.v0,c.len+400);
  return {spd,at(t){const D=Dt(t),fl=(c.flinches||[]).reduce((a,f)=>a+(t>=f?Math.exp(-(t-f)/300):0),0),sp=spd(t);
    const grow=c.freezeAt==null?0:clamp((t-c.freezeAt)/growMs,0,1);let thaw=c.freezeAt==null||sh?0:clamp((t-c.thawAt)/c.thawMs,0,1),gone=false,sAge=-1;
    if(sh&&t>=c.shatterAt){gone=true;sAge=t-c.shatterAt;}
    return {x:c.x0+(c.dir||-1)*D,D,sp,spn:sp/1,grow:gone?0:grow,thaw,gone,sAge,frozen:c.freezeAt!=null&&t>=c.freezeAt+growMs*.4&&t<endIce,fl,endIce,shatter:sh};}};}
Object.assign(IC,{dims,skel,buildQuad,drawQuad,buildShell,drawShell,makeWalker});
})(typeof window!=='undefined'?window:globalThis);
