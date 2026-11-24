'use strict';
// Primigenia signature-attack picker lab (A60 design-first step). 16 real-animal-inspired signature attacks, one looping cell each.
// Shared helpers come from bb_core.js (BB: vectors, ell/lam/place, FXPool, ground textures). Units: metres, +x forward, +y up, z toward the camera.
// Every attack = { id,name,animal,organ,role,effect,env,D,cam:{cx,ty,h},ti, build(scene) -> {pose(s,fx,bm)} }, s = seconds in the loop, ti = impact time.
(function(){
const BB=window.BB,T=BB.T,{V,clamp,sm,place,ell,lam}=BB;
const L=3.4;
const rp=(s,a,b)=>clamp((s-a)/(b-a),0,1),eo=u=>1-Math.pow(1-u,3),s2=(s,a,b)=>sm(rp(s,a,b)),tri=(s,a,b,c)=>s2(s,a,b)*(1-s2(s,b,c));
const rnd=k=>{const x=Math.sin(k*127.1+311.7)*43758.5453;return x-Math.floor(x);};
const lerpV=(a,b,u)=>a.clone().lerp(b,u);
function rod(par,mat,r0,r1,len,dir){const g=new T.CylinderGeometry(r1,r0,len,8);
  if(dir==='x'){g.translate(0,len/2,0);g.rotateZ(-Math.PI/2);}else if(dir==='-x'){g.translate(0,len/2,0);g.rotateZ(Math.PI/2);}else if(dir==='-y')g.translate(0,-len/2,0);else g.translate(0,len/2,0);
  const m=new T.Mesh(g,mat);par.add(m);return m;}
function cone(par,mat,r,len,x,y,z,rz){const m=new T.Mesh(new T.ConeGeometry(r,len,6),mat);m.position.set(x,y,z);m.rotation.z=rz||0;par.add(m);return m;}
// ---------------------------------------------------------------- generic quadruped body (all limbs hang off `body`, which can pitch/roll)
function creature(sc,o){
  o=Object.assign({col:'#9a7a52',belly:'#d9c9a3',sx:1,sy:1,sz:1,legH:.42,hs:1,tl:.5},o);const c={o},mat=lam(o.col),bm=lam(o.belly),dk=lam('#33281c'),hs=o.hs;
  c.mat=mat;c.root=new T.Group();sc.add(c.root);c.body=new T.Group();c.root.add(c.body);
  ell(c.body,mat,.36*o.sx,.2*o.sy,.19*o.sz);ell(c.body,bm,.3*o.sx,.1*o.sy,.15*o.sz).position.y=-.1*o.sy;
  const hd=c.hd=new T.Group();hd.position.set(.36*o.sx,.09*o.sy,0);c.body.add(hd);
  ell(hd,mat,.13*hs,.1*hs,.1*hs).position.x=.07*hs;ell(hd,mat,.12*hs,.055*hs,.065*hs).position.set(.19*hs,-.015*hs,0);
  const jw=c.jw=new T.Group();jw.position.set(.1*hs,-.04*hs,0);hd.add(jw);ell(jw,bm,.1*hs,.024*hs,.05*hs).position.x=.09*hs;
  c.mouthIn=ell(jw,lam('#6d1f26'),.07*hs,.012,.035*hs);c.mouthIn.position.set(.09*hs,.012,0);
  c.eyes=[];for(const s of [-1,1]){const w=ell(hd,lam('#f4f1e8'),.03*hs,.03*hs,.025*hs);w.position.set(.12*hs,.05*hs,s*.075*hs);const p=ell(hd,lam('#111'),.015*hs,.017*hs,.012*hs);p.position.set(.135*hs,.05*hs,s*.092*hs);c.eyes.push(w,p);}
  c.legs=[[.24,-1],[.24,1],[-.24,-1],[-.24,1]].map(([x,z])=>{const g=new T.Group();g.position.set(x*o.sx,-.1*o.sy,z*.13*o.sz);c.body.add(g);const len=o.legH-.1*o.sy;rod(g,mat,.05*Math.max(1,o.sx*.8),.032,len,'-y');ell(g,dk,.06,.025,.045).position.set(.02,-len,0);return g;});
  const t1=c.t1=new T.Group();t1.position.set(-.34*o.sx,.04*o.sy,0);c.body.add(t1);rod(t1,mat,.06,.032,o.tl*.5,'-x');
  const t2=c.t2=new T.Group();t2.position.x=-o.tl*.5;t1.add(t2);rod(t2,mat,.032,.012,o.tl*.5,'-x');
  const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.004;sh.scale.set(1.5*o.sx,.7*o.sz,1);c.root.add(sh);
  return c;
}
function idle(c,s){const o=c.o;c.root.position.set(0,0,0);c.root.rotation.set(0,0,0);c.body.position.set(0,o.legH+.006*Math.sin(s*3),0);c.body.rotation.set(0,0,0);c.hd.rotation.set(0,0,0);c.jw.rotation.z=0;c.legs.forEach(l=>l.rotation.set(0,0,0));c.t1.rotation.set(0,.25*Math.sin(s*1.6),0);c.t2.rotation.set(0,.25*Math.sin(s*1.6+1),0);}
function gait(c,ph,a){const q=Math.sin(ph)*a;c.legs[0].rotation.z=q;c.legs[1].rotation.z=-q;c.legs[2].rotation.z=-q;c.legs[3].rotation.z=q;}
// ---------------------------------------------------------------- target dummy: feet at its pivot, faces -x
function dummy(sc,x,o){o=Object.assign({s:1,col:'#c9a86a',y0:0},o);const d={o,x,y0:o.y0};d.pv=new T.Group();sc.add(d.pv);const g=d.g=new T.Group();d.pv.add(g);
  const m=d.mat=lam(o.col),dk=lam('#6b5a3c'),red=lam('#b2483a');d.col=new T.Color(o.col);
  for(const z of [-.09,.09]){const l=rod(g,dk,.06,.05,.4,'y');l.position.set(0,0,z);}
  ell(g,m,.2,.3,.17).position.y=.62;ell(g,red,.205,.04,.175).position.y=.52;ell(g,m,.15,.15,.14).position.y=1.1;
  for(const z of [-.07,.07]){ell(g,lam('#f4f1e8'),.035,.035,.03).position.set(-.12,1.13,z);ell(g,lam('#111'),.018,.02,.015).position.set(-.145,1.13,z*1.1);}
  d.blind=[-.07,.07].map(z=>{const b=ell(g,lam('#050505'),.05,.045,.04);b.position.set(-.14,1.13,z);b.visible=false;return b;});
  d.arms=[-1,1].map(z=>{const a=rod(g,dk,.04,.03,.34,'-y');a.position.set(0,.8,z*.22);return a;});
  d.stars=[0,1,2].map(()=>{const q=ell(g,new T.MeshBasicMaterial({color:'#ffe066'}),.05,.05,.05);q.visible=false;return q;});
  d.quills=[0,1,2,3].map(k=>{const q=cone(g,lam('#e9dfc4'),.012,.3,-.2,.5+.1*k,(k-1.5)*.07,Math.PI/2+.1*(k-1.5));q.visible=false;return q;});
  if(o.shield){d.shield=new T.Mesh(new T.CylinderGeometry(.34,.34,.05,16),lam('#7aa6b0'));d.shield.rotation.z=Math.PI/2;d.shield.position.set(-.3,.65,0);g.add(d.shield);}
  return d;
}
const FC=new T.Color();
function dpose(d,p,r,s){r=r===undefined?1:r;const z=k=>(p[k]||0)*r,sc=d.o.s;
  d.pv.position.set(d.x+z('dx'),d.y0+z('dy'),(p.z0||0)+z('dz'));d.pv.rotation.set(z('rx'),z('yaw'),z('tilt'));
  d.g.scale.set(sc,sc*(1-z('sq')),sc);d.g.position.y=(p.gy||0);
  d.mat.color.copy(d.col);if(p.tint)d.mat.color.lerp(FC.set(p.tint),clamp(z('ta'),0,1));
  const f=z('flash');d.mat.emissive.setRGB(f*(p.fr===undefined?.9:p.fr),f*(p.fg===undefined?.8:p.fg),f*(p.fb===undefined?.4:p.fb));
  d.blind.forEach(b=>b.visible=z('blind')>.5);
  const st=z('stars');d.stars.forEach((q,k)=>{q.visible=st>.05;if(q.visible){const a=(s||0)*7+k*2.1;q.position.set(.13*Math.cos(a),1.34+.02*Math.sin(a*2),.13*Math.sin(a));q.scale.setScalar(.05*st);}});
  d.quills.forEach(q=>q.visible=!!p.qv);if(d.shield)d.shield.visible=!p.nosh;
}
// standard knock reaction after impact time ti
function R(s,ti,m){const a=s-ti;if(a<0)return {};m=m||{};const u=rp(a,0,.3);
  return {dx:(m.kb||0)*eo(rp(a,0,m.kt||.3)),dy:(m.hop||0)*Math.sin(Math.PI*rp(a,0,.5)),tilt:-(m.tilt||0)*s2(a,0,.3),flash:(m.flash||0)*Math.exp(-a*7),stars:(m.stars||0)*rp(a,0,.2)*(1-rp(a,1.1,1.5)),sq:(m.sq||0)*Math.exp(-a*9),yaw:(m.shake||0)*Math.sin(a*38)*Math.exp(-a*3.2)*rp(a,0,.05)};}
function burst(fx,pos,a,n,spd,sz,col){if(a<0||a>.5)return;const u=a/.5;
  if(a<.16)fx.dot(pos,.2*(1-a/.16)+.04,.8*(1-a/.16),'#fff6c8');
  for(let i=0;i<n;i++){const az=i*2.4,el=.3+(i%3)*.45,dir=V(Math.cos(az)*Math.cos(el),Math.abs(Math.sin(el)),Math.sin(az)*Math.cos(el));fx.dot(pos.clone().addScaledVector(dir,spd*eo(u)),sz*(1-u),1-u,col);}}
function Beams(sc){const cyl=new T.CylinderGeometry(1,1,1,5),segs=[],rings=[];let us=0,ur=0;
  for(let k=0;k<30;k++){const m=new T.Mesh(cyl,new T.MeshBasicMaterial({color:'#fff',transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending}));m.visible=false;sc.add(m);segs.push(m);}
  for(let k=0;k<4;k++){const m=new T.Mesh(new T.PlaneGeometry(2,2),new T.MeshBasicMaterial({map:BB.TEX.ring,transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending,side:T.DoubleSide}));m.rotation.y=Math.PI/2;m.visible=false;sc.add(m);rings.push(m);}
  return {begin(){us=ur=0;},
    seg(a,b,r,col,op){if(us>=segs.length)return;const m=segs[us++];m.visible=true;place(m,a,b);m.scale.x=m.scale.z=r;m.material.color.set(col);m.material.opacity=op===undefined?1:op;},
    bolt(a,b,seed,n,r,col,jit){let p=a.clone();const d=b.clone().sub(a),nrm=V(0,1,0).cross(d).normalize();for(let i=1;i<=n;i++){const q=a.clone().addScaledVector(d,i/n);if(i<n){q.y+=(rnd(seed+i)-.5)*jit;q.addScaledVector(nrm,(rnd(seed+i*7)-.5)*jit);}this.seg(p,q,r,col,1);p=q;}},
    vring(pos,r,op,col){if(ur>=rings.length)return;const m=rings[ur++];m.visible=true;m.position.copy(pos);m.scale.set(r,r,1);m.material.opacity=op;m.material.color.set(col);},
    end(){for(let k=us;k<segs.length;k++)segs[k].visible=false;for(let k=ur;k<rings.length;k++)rings[k].visible=false;}};}
// ---------------------------------------------------------------- snake / eel body: a chain of spheres along a path
function snake(sc,n,col,belly){const m=lam(col),sp=[];for(let i=0;i<n;i++){const s=ell(sc,m,1,1,1);sp.push(s);}const head=new T.Group();sc.add(head);ell(head,m,.1,.06,.07).position.x=.04;ell(head,lam('#111'),.014,.014,.014).position.set(.08,.03,.05);ell(head,lam('#111'),.014,.014,.014).position.set(.08,.03,-.05);
  const jw=new T.Group();head.add(jw);ell(jw,lam(belly||col),.07,.02,.045).position.set(.04,-.04,0);
  return {mat:m,sp,head,jw,set(pts){const n=sp.length;pts.forEach((p,i)=>{const u=i/(n-1),r=.03+.045*Math.sin(Math.PI*Math.min(1,u*1.15+.03))*.9+.01;sp[i].position.copy(p);sp[i].scale.setScalar(Math.max(.025,r*(i===0?.5:1)));});const a=pts[n-2],b=pts[n-1];head.position.copy(b);head.rotation.z=Math.atan2(b.y-a.y,b.x-a.x);head.rotation.y=-Math.atan2(b.z-a.z,b.x-a.x);}};}
const hood=(sc,col)=>{const h=ell(sc,lam(col),.03,.15,.14);return h;};
const dust='#c9b48a',fire=['#fff2a0','#ffb03a','#e8501f'],green='#9cc86a';
const mix=(u,a)=>a[Math.min(a.length-1,Math.floor(u*a.length))];

const A=[];
// 1 ------------------------------------------------------------------------------------------- flamethrower
A.push({id:'flamethrower',name:'Flamethrower',animal:'island vent-cooked fire gland (none on Earth)',organ:'fire gland, needs 16%+ O2 (A38, D-28)',role:'poke / signature',effect:'Cone of fire in front; burns over time.',env:'land',D:2.4,cam:{cx:1.2,ty:.6,h:2.5},ti:1.15,
 build(sc){const c=creature(sc,{col:'#a85a3a',belly:'#e0b070',sx:1.1,hs:1.15,tl:.7}),d=dummy(sc,2.4);ell(c.hd,lam('#e8742c'),.06,.05,.05).position.set(.04,-.1,0);
  return {pose(s,fx){idle(c,s);c.root.position.x=.25;const r=tri(s,.2,.75,2.0),act=s2(s,.95,1.05)*(1-s2(s,1.85,2.0));
   c.body.rotation.z=.26*r;c.hd.rotation.z=.4*r;c.legs[0].rotation.z=-.5*r;c.legs[1].rotation.z=-.5*r;c.jw.rotation.z=-(.12*r+.5*act);c.t1.rotation.z=.2*r;
   sc.updateMatrixWorld(true);const m=c.hd.localToWorld(V(.38,-.02,0)),tg=V(2.15,.62,0),a=s-1.15;
   if(act>.01)for(let i=0;i<14;i++){const u=((s*1.9+i/14)%1),p=lerpV(m,tg,u*1.02);p.y+=(rnd(i)-.5)*.16*u+.06*u;p.z+=(rnd(i+9)-.5)*.34*u;fx.dot(p,.05+.2*u,act*.85*(1-.5*u),mix(u,fire));}
   const burn=s2(s,1.15,1.4)*(1-s2(s,2.5,3.1));
   if(a>0)for(let i=0;i<6;i++){const u=((s*.9+i/6)%1);fx.dot(V(2.4+.2*Math.sin(i*5+s*3),.4+u*1.0,.15*Math.cos(i*3)),.035*(1-u),.9*burn*(1-u),'#ff9a3c');}
   dpose(d,Object.assign(R(s,1.15,{kb:.1,hop:0,shake:.0}),{tint:'#3a1a0e',ta:.8*burn,flash:.35*burn*(.6+.4*Math.sin(s*30)),fg:.4,fb:0,dy:.1*burn*Math.abs(Math.sin(s*14)),yaw:.2*burn*Math.sin(s*20)}),1,s);}};}});
// 2 ------------------------------------------------------------------------------------------- boiling spray
A.push({id:'boiling_spray',name:'Boiling spray',animal:'bombardier beetle',organ:'rear gland + armour',role:'control / signature',effect:'Short-range hot spray from the rear: burn and fear.',env:'land',D:2.3,cam:{cx:1.3,ty:.5,h:2.4},ti:1.1,
 build(sc){const c=creature(sc,{col:'#2d3a48',belly:'#c8693a',sx:.8,sy:.9,hs:.7,legH:.25,tl:.35}),d=dummy(sc,2.3);ell(c.body,lam('#c8693a'),.18,.1,.2).position.set(-.28,.1,0);
  return {pose(s,fx){idle(c,s);c.root.position.x=1;c.root.rotation.y=Math.PI;const lift=tri(s,.5,.95,2.2);c.t1.rotation.z=-.8*lift;c.t2.rotation.z=-.4*lift;c.body.rotation.z=-.1*lift;
   sc.updateMatrixWorld(true);const tip=c.t2.localToWorld(V(-.2,0,0)),tg=V(2.1,.6,0);let ps=0;for(const t of [1.1,1.45,1.8])ps=Math.max(ps,Math.exp(-Math.pow((s-t-.1)/.13,2)));
   if(ps>.02)for(let i=0;i<10;i++){const u=((s*2.4+i/10)%1),p=lerpV(tip,tg,u);p.y+=.18*Math.sin(Math.PI*u);p.z+=(rnd(i)-.5)*.2*u;fx.dot(p,.045+.1*u,ps*(1-.4*u),i%3?'#ff9a3c':'#ffffff');if(i%2)fx.dot(p.clone().add(V(0,.1*u,0)),.1+.14*u,.3*ps*(1-u),'#d6dadd');}
   if(ps>.4)fx.ring(tip.x,.01,tip.z,.4+.3*ps,.5*ps,'#ffd27a');
   const a=s-1.1,fl=s2(s,1.5,2.3);const hot=Math.exp(-a*1.2)*rp(a,0,.1)*(1-s2(s,2.5,3.1));
   dpose(d,Object.assign(R(s,1.1,{kb:.2,hop:.15,flash:.7,sq:.12,shake:.1}),{tint:'#d4482a',ta:.7*hot,dx:(.2*eo(rp(a,0,.3))+.9*fl)*(s>1.1?1:0),yaw:Math.PI*s2(s,1.3,1.6)*(s>1.1?1:0)+.0,dy:.1*Math.abs(Math.sin(s*12))*rp(s,1.5,1.6)*(1-rp(s,2.2,2.4))}),1,s);}};}});
// 3 ------------------------------------------------------------------------------------------- sonic snap
A.push({id:'sonic_snap',name:'Sonic snap',animal:'pistol shrimp',organ:'oversized claw; strongest underwater',role:'control / signature',effect:'Cavitation shockwave: stun at range, in water.',env:'water',D:2.5,cam:{cx:1.25,ty:.55,h:2.5},ti:1.2,
 build(sc){const c=creature(sc,{col:'#d9603f',belly:'#f0c8a0',sx:.8,sy:.8,hs:.6,legH:.3,tl:.5}),d=dummy(sc,2.5),bm=Beams(sc);
  const ar=new T.Group();ar.position.set(.3,.0,.14);c.body.add(ar);const cm=lam('#e87050');rod(ar,cm,.05,.04,.3,'x');const cl=new T.Group();cl.position.x=.3;ar.add(cl);ell(cl,cm,.15,.06,.06).position.x=.12;const up=new T.Group();up.position.set(.0,.04,0);cl.add(up);ell(up,cm,.14,.04,.05).position.x=.12;
  return {pose(s,fx){idle(c,s);c.root.position.x=.55;const open=tri(s,.45,1.1,1.16)*.85;up.rotation.z=open;ar.rotation.z=.25*s2(s,.4,1.0)*(1-s2(s,1.4,1.8));c.body.rotation.z=-.05*s2(s,1,1.2)*(1-s2(s,1.2,1.6));
   sc.updateMatrixWorld(true);const tip=cl.localToWorld(V(.32,.02,0)),a=s-1.2;bm.begin();
   if(a>0){for(let k=0;k<3;k++){const u=rp(a-k*.09,0,.6);if(u>0&&u<1){bm.vring(lerpV(tip,V(2.25,.6,.14),eo(u)),.2+.5*eo(u),.8*(1-u),'#bff2ff');}}fx.dot(tip,.3*Math.max(0,1-a/.15),Math.max(0,1-a/.15),'#ffffff');}
   for(let i=0;i<7;i++){const u=((s*.9+i/7)%1);if(s>1.0)fx.dot(tip.clone().add(V(.1+.2*u,.05+.5*u,.04*Math.sin(i*5))),.025*(1-u*.5),.7*(1-u),'#dff6ff');}
   bm.end();const w=rp(a,0,.4);dpose(d,Object.assign(R(s,1.28,{kb:.1,stars:1,sq:.05}),{yaw:.35*Math.sin(s*9)*rp(s,1.3,1.5)*(1-rp(s,2.4,2.8)),tilt:.18*Math.sin(s*7)*rp(s,1.3,1.5)*(1-rp(s,2.4,2.8)),flash:.5*Math.exp(-(s-1.3)*6)*(s>1.3?1:0)}),1,s);}};}});
// 4 ------------------------------------------------------------------------------------------- blinding spit
A.push({id:'blinding_spit',name:'Blinding spit',animal:'spitting cobra',organ:'spit gland + fangs',role:'control / signature',effect:'Twin venom jets at the eyes: target is blind, accuracy drops.',env:'land',D:2.4,cam:{cx:1.1,ty:.6,h:2.5},ti:1.25,
 build(sc){const sn=snake(sc,15,'#6b5a2e','#d8c58a'),hd=hood(sc,'#5a4a24'),d=dummy(sc,2.4),bm=Beams(sc);
  return {pose(s,fx){const r=tri(s,.2,.7,2.2),hx=.1+.05*r,hy=.08+.78*r,fl=tri(s,.5,.9,2.1),lean=.06*Math.sin(s*3)*r;
   const p0=V(-1.3,.04,0),p1=V(hx-.9,.04,0),p2=V(hx-.5,hy,0),p3=V(hx,hy,0),pts=BB.resample(BB.bezPath(p0,p1,p2,p3,30),14).pts;
   pts.forEach((p,i)=>{p.z+=.07*Math.sin(i*.9+s*3)*(1-r)*(1-i/14);p.y=Math.max(.04,p.y);});sn.set(pts);const hp=pts[13];hd.position.copy(hp).add(V(-.1,-.05,0));hd.scale.set(.03,.05+.1*fl,.02+.12*fl);
   sn.jw.rotation.z=-.5*tri(s,1.0,1.1,1.5);sc.updateMatrixWorld(true);const m=V(hx+.1,hy-.02,0),act=s2(s,1.0,1.08)*(1-s2(s,1.5,1.6));bm.begin();
   if(act>0)for(const z of [-.02,.02]){const a=m.clone().add(V(0,0,z)),b=V(2.26,1.12,z*3.5),u0=rp(s,1.05,1.3),u1=rp(s,1.18,1.42);if(u0>u1&&u1<1)bm.seg(lerpV(a,b,u1),lerpV(a,b,u0),.012,'#e8f09a',1);
     for(let i=0;i<4;i++){const u=rp(s,1.05+i*.02,1.3);if(u>0&&u<1)fx.dot(lerpV(a,b,u),.025,1,'#f2f7b0');}}
   bm.end();const a=s-1.25,bl=s>1.28?1:0;
   dpose(d,Object.assign(R(s,1.28,{kb:.25,flash:.4}),{blind:bl,yaw:.5*Math.sin(s*11)*rp(s,1.3,1.4)*(1-rp(s,2.4,2.8)),dx:.25*eo(rp(a,0,.3))+.18*Math.sin(s*6)*rp(s,1.5,2.0)*(1-rp(s,2.4,2.8))}),1,s);}};}});
// 5 ------------------------------------------------------------------------------------------- smash punch
A.push({id:'smash_punch',name:'Smash punch',animal:'mantis shrimp',organ:'club arm (smasher, A58)',role:'control / signature',effect:'Blur-fast heavy hit: stuns, breaks shells and guard.',env:'water',D:2.15,cam:{cx:1.1,ty:.55,h:2.4},ti:1.05,
 build(sc){const c=creature(sc,{col:'#2f8f7a',belly:'#e8d27a',sx:.75,sy:.8,hs:.6,legH:.3,tl:.4}),d=dummy(sc,2.15,{shield:true});
  const ar=new T.Group();ar.position.set(.3,-.02,.15);c.body.add(ar);const am=lam('#e0553a');rod(ar,am,.045,.035,.26,'x');const el=new T.Group();el.position.x=.26;ar.add(el);rod(el,am,.035,.03,.26,'x');ell(el,lam('#ff8a3a'),.11,.075,.075).position.x=.33;
  return {pose(s,fx){idle(c,s);c.root.position.x=.55;const co=s2(s,.35,.9),pu=s2(s,.98,1.06),rec=s2(s,1.4,2.1),k=co*(1-pu),extend=(1-rec);
   ar.rotation.z=(1.6*k+.0*pu)*extend+.5*(1-co)*0-(.5*(1-co));el.rotation.z=(-2.0*k)*extend;c.body.rotation.z=.08*k-.08*pu*(1-rec);c.body.position.x=.1*pu*(1-rec);
   sc.updateMatrixWorld(true);const club=el.localToWorld(V(.33,0,0));
   if(s>.97&&s<1.1){fx.dot(club.clone().add(V(-.12,.08,0)),.12,.4,'#ffb070');fx.dot(club.clone().add(V(-.26,.16,0)),.09,.25,'#ffb070');}
   const a=s-1.05;burst(fx,V(1.82,.6,.1),a,9,.7,.07,'#fff0b8');
   if(a>0&&a<.5)for(let i=0;i<6;i++){const dir=V(Math.cos(i*1.05),.5+Math.abs(Math.sin(i*2.1)),Math.sin(i*1.05)*.8);fx.dot(V(1.85,.65,0).addScaledVector(dir,.8*eo(a/.5)),.08*(1-a/.5),1-a/.5,'#9fcad2');}
   dpose(d,Object.assign(R(s,1.07,{kb:.55,tilt:.2,hop:.1,flash:.8,sq:.12,stars:1}),{nosh:s>1.06}),1,s);}};}});
// 6 ------------------------------------------------------------------------------------------- electric discharge
A.push({id:'electric_discharge',name:'Electric discharge',animal:'electric eel',organ:'electric organ',role:'control / signature',effect:'Stun in contact, chains to a second target; stronger in water.',env:'water',D:2.0,cam:{cx:1.2,ty:.5,h:2.5},ti:1.05,
 build(sc){const sn=snake(sc,18,'#3d4a44','#b8c06a'),d=dummy(sc,2.0),b=dummy(sc,3.0,{s:.7,z0:0,col:'#a9b6c8'}),bm=Beams(sc);
  return {pose(s,fx){const g=s2(s,.4,.95)*(1-s2(s,1.8,2.3));sn.mat.emissive.setRGB(.9*g,.85*g,.25*g);
   const pts=[];for(let i=0;i<18;i++){const u=i/17,x=-1.3+1.8*u,w=.14*Math.sin(u*7-s*5)*(1-u*.4);pts.push(V(x,.3+.03*Math.sin(u*5+s*2),w*(.5+.5*u)));}sn.set(pts);
   const head=V(.5,.34,0),t1=V(1.88,.6,0),t2=V(2.9,.45,0),seed=Math.floor(s*30)*13;bm.begin();
   const on=s2(s,1.0,1.04)*(1-s2(s,1.75,1.85));if(on>.1){bm.bolt(head,t1,seed,7,.014,'#bfe8ff',.28);bm.bolt(head,t1,seed+50,6,.008,'#ffffff',.2);if(s>1.15)bm.bolt(t1,t2,seed+90,7,.012,'#cfe6ff',.3);
    fx.dot(t1,.16,.7*on,'#fff7b0');if(s>1.15)fx.dot(t2,.12,.6*on,'#fff7b0');for(let i=0;i<5;i++)bm.bolt(head.clone().add(V(-.1-.2*i,0,0)),head.clone().add(V(-.2*i,.12,.14*Math.sin(i+seed))),seed+i,2,.008,'#e8f4ff',.08);}
   bm.end();dpose(d,Object.assign(R(s,1.05,{kb:.0,stars:1,flash:.0}),{flash:.6*(s>1.05&&s<1.9?.5+.5*Math.sin(s*60):0),yaw:.12*Math.sin(s*60)*rp(s,1.05,1.1)*(1-rp(s,1.8,2.0)),tilt:-.12*s2(s,1.05,1.3)}),1,s);
   dpose(b,Object.assign(R(s,1.2,{stars:1}),{z0:.4,flash:.6*(s>1.2&&s<1.9?.5+.5*Math.sin(s*60+1):0),yaw:.15*Math.sin(s*55)*rp(s,1.2,1.25)*(1-rp(s,1.8,2.0)),tilt:-.12*s2(s,1.2,1.4)}),1,s);}};}});
A[A.length-1].cam={cx:1.5,ty:.5,h:2.6};
// 7 ------------------------------------------------------------------------------------------- tongue snatch
A.push({id:'tongue_snatch',name:'Tongue snatch',animal:'chameleon',organ:'long tongue',role:'poke / utility',effect:'Pulls small prey or items to you from range.',env:'land',D:1.55,cam:{cx:.85,ty:.45,h:2.0},ti:1.15,
 build(sc){const c=creature(sc,{col:'#6aa84f',belly:'#c9dc8a',sx:.7,sy:.9,sz:.8,legH:.28,hs:.8,tl:.7}),bm=Beams(sc);c.eyes.forEach(e=>e.scale.multiplyScalar(1.7));
  const st=new T.Mesh(new T.CylinderGeometry(.1,.14,.25,10),lam('#7a5a38'));st.position.set(1.5,.125,0);sc.add(st);const fr=ell(sc,lam('#d8402e'),.07,.07,.07);const lf=ell(sc,lam('#4a8a3a'),.05,.012,.03);
  return {pose(s,fx){idle(c,s);c.root.position.x=.15;const lk=tri(s,.3,.7,1.9);c.hd.rotation.z=-.1*lk;c.body.rotation.z=.05*lk;c.t1.rotation.z=.9*lk;c.t2.rotation.z=.8*lk;c.jw.rotation.z=-.6*tri(s,.95,1.05,1.2)-.05*lk;
   const ext=s2(s,1.0,1.12)*(1-s2(s,1.16,1.6));sc.updateMatrixWorld(true);const m=c.hd.localToWorld(V(.3,-.02,0)),tipX=m.x+(1.43-m.x)*ext,tip=V(tipX,m.y+(.34-m.y)*ext,0);
   const gone=s>1.62&&s<3.0,pulled=s2(s,1.16,1.6);const pf=lerpV(V(1.5,.34,0),m,pulled);fr.visible=lf.visible=!gone;fr.position.copy(pf);lf.position.copy(pf).add(V(0,.08,0));fr.scale.setScalar(.07*(1-.5*pulled));
   bm.begin();if(ext>.01){bm.seg(m,tip,.016,'#e8808f',1);fx.dot(tip,.05,1,'#f090a0');}bm.end();
   if(s>1.62&&s<2.1)fx.dot(V(m.x-.02,m.y-.12,0),.05+.04*Math.sin((s-1.62)*14),.9,'#e6b59a');}};}});
// 8 ------------------------------------------------------------------------------------------- water jet
A.push({id:'water_jet',name:'Water jet',animal:'archerfish',organ:'spit gland, near water',role:'poke / signature',effect:'Knocks a target off a branch from range.',env:'land',D:2.0,cam:{cx:1.2,ty:.65,h:2.9},ti:1.3,
 build(sc){const pool=new T.Mesh(new T.CircleGeometry(.85,28),new T.MeshBasicMaterial({color:'#3b86b8',transparent:true,opacity:.85}));pool.rotation.x=-Math.PI/2;pool.position.set(.0,.012,0);sc.add(pool);
  const f=new T.Group();sc.add(f);const fm=lam('#d0a050');ell(f,fm,.28,.1,.07);ell(f,lam('#f0e0b0'),.22,.05,.06).position.y=-.04;cone(f,fm,.09,.2,-.34,0,0,Math.PI/2);const eye=ell(f,lam('#111'),.02,.02,.02);eye.position.set(.2,.04,.05);const eye2=eye.clone();eye2.position.z=-.05;f.add(eye2);
  const tr=new T.Mesh(new T.CylinderGeometry(.05,.07,1.0,8),lam('#6a4a2a'));tr.position.set(2.0,.5,0);sc.add(tr);const br=new T.Mesh(new T.CylinderGeometry(.04,.05,1.3,8),lam('#6a4a2a'));br.rotation.z=Math.PI/2;br.position.set(1.7,1.0,0);sc.add(br);
  const d=dummy(sc,1.9,{s:.55,y0:1.0,col:'#7aa04a'});
  return {pose(s,fx){const r=tri(s,.3,.7,1.9);f.position.set(0,.01+.04*Math.sin(s*3)-.02*(1-r),0);f.rotation.z=.55*r;const act=s2(s,1.15,1.2)*(1-s2(s,1.35,1.4));
   const m=V(.24,.17,0).add(f.position);if(act>0)for(let i=0;i<12;i++){const u=rp(s,1.18,1.4)-i*.02;if(u<=0||u>=1)continue;const p=lerpV(m,V(1.82,1.35,0),u);p.y+=.45*Math.sin(Math.PI*u);fx.dot(p,.032,1,'#bfe4ff');}
   const a=s-1.35;let p={};if(a>0){const g=Math.min(1.0,4.5*a*a);p={dx:.45*eo(rp(a,0,.5)),dy:-g,tilt:-2.5*s2(a,0,.45),flash:.5*Math.exp(-a*8)};if(a>.47&&a<.9)fx.ring(2.35,.01,0,.2+.5*(a-.47),.6*(1-(a-.47)/.43),'#cfe8ff');}
   dpose(d,p,1,s);}};}});
// 9 ------------------------------------------------------------------------------------------- stink cloud
A.push({id:'stink_cloud',name:'Stink cloud',animal:'skunk',organ:'scent gland',role:'control / signature',effect:'Area fear: enemies flee; also hides your scent trail.',env:'land',D:2.45,cam:{cx:1.4,ty:.55,h:2.7},ti:1.4,
 build(sc){const c=creature(sc,{col:'#22262b',belly:'#2a2d33',sx:.95,legH:.3,tl:.7,hs:.8}),d=dummy(sc,2.45,{col:'#c9a86a'});const st=ell(c.body,lam('#f0f0ea'),.3,.02,.05);st.position.y=.2;ell(c.t1,lam('#f0f0ea'),.2,.045,.04).position.x=-.2;ell(c.t2,lam('#f0f0ea'),.2,.03,.03).position.x=-.2;
  return {pose(s,fx){idle(c,s);c.root.position.x=.8;c.root.rotation.y=Math.PI;const r=tri(s,.3,.8,2.3);c.t1.rotation.z=-1.3*r;c.t2.rotation.z=-.25*r;c.t1.rotation.y=.0;c.hd.rotation.y=.9*r;c.hd.rotation.z=-.1*r;c.body.rotation.z=-.12*r;c.legs[0].rotation.z=.2*r;c.legs[1].rotation.z=.2*r;
   sc.updateMatrixWorld(true);const tip=c.t2.localToWorld(V(-.2,0,0)),life=1-s2(s,2.4,3.1);
   if(s>1.0)for(let i=0;i<14;i++){const u=rp(s,1.0+i*.045,2.3),e=eo(u);if(u<=0)continue;const tg=V(2.2+rnd(i)*.6,.35+rnd(i+4)*.6,(rnd(i+8)-.5)*.6),p=lerpV(tip,tg,e);p.y+=.12*Math.sin(s*2+i);fx.dot(p,.1+.3*e,.4*life*(1-.4*u),i%2?'#8fbf5a':'#a9c978');}
   const fl=s2(s,1.5,1.7),away=s2(s,1.6,2.5);dpose(d,{ta:.45*Math.min(1,rp(s,1.4,1.7))*life,tint:'#8fb04a',dx:1.1*away*(s>1.5?1:0),yaw:Math.PI*fl*(s>1.4?1:0),dy:(s>1.7&&s<2.6)?.12*Math.abs(Math.sin(s*11)):0,sq:.08*Math.exp(-(s-1.45)*8)*(s>1.45?1:0),flash:0},1,s);}};}});
// 10 ------------------------------------------------------------------------------------------ blood squirt
A.push({id:'blood_squirt',name:'Blood squirt',animal:'horned lizard',organ:'head crest + armour',role:'defence / signature',effect:'Squirts blood from the eyes: scares predators off.',env:'land',D:2.0,cam:{cx:1.0,ty:.55,h:2.3},ti:1.15,
 build(sc){const c=creature(sc,{col:'#b08a5a',belly:'#d9c39a',sx:.9,sy:.7,sz:1.25,legH:.2,hs:.9,tl:.4}),d=dummy(sc,2.0,{col:'#9a8a70'}),sm_=lam('#6a4a2a');
  for(const z of [-1,1])for(let k=0;k<3;k++)cone(c.hd,sm_,.025,.1-.02*k,-.02-.05*k,.1+.01*k,z*(.05+.03*k),.5+.1*k).rotation.x=z*.5;
  for(let k=0;k<6;k++)cone(c.body,sm_,.02,.08,.28-k*.11,.15,(k%2?1:-1)*.08,0);
  return {pose(s,fx){idle(c,s);c.root.position.x=.55;const cr=tri(s,.3,.7,1.9);c.body.position.y-=.05*cr;c.hd.rotation.z=-.25*cr+.35*pulse(s,1.1);c.legs.forEach(l=>l.rotation.z*=1);c.legs[0].rotation.z=.2*cr;c.legs[1].rotation.z=.2*cr;
   sc.updateMatrixWorld(true);const m=c.hd.localToWorld(V(.13,.06,.07)),act=s2(s,1.08,1.14)*(1-s2(s,1.45,1.55));
   if(act>0)for(let i=0;i<12;i++){const u=rp(s,1.12,1.5)-i*.025;if(u<=0||u>=1)continue;const p=lerpV(m,V(1.86,.95,.1),u);p.y+=.35*Math.sin(Math.PI*u);fx.dot(p,.03,1,'#b01818');}
   const a=s-1.5;if(a>0&&a<.3)fx.dot(V(1.86,.95,.1),.1*(1-a/.3),.7,'#c01c1c');
   const fl=s2(s,1.5,1.65),away=s2(s,1.6,2.4);dpose(d,{dx:-.0+.8*away*(s>1.5?1:0),yaw:Math.PI*fl*(s>1.45?1:0),sq:.1*Math.exp(-(s-1.5)*9)*(s>1.5?1:0),tint:'#c8402a',ta:.35*rp(s,1.5,1.6)*(1-s2(s,2.5,3.1)),dy:(s>1.7&&s<2.5)?.14*Math.abs(Math.sin(s*12)):0},1,s);}};
 }});
function pulse(s,t){return Math.exp(-Math.pow((s-t)/.06,2));}
// 11 ------------------------------------------------------------------------------------------ quill storm
A.push({id:'quill_storm',name:'Quill storm',animal:'porcupine',organ:'back spines',role:'defence / signature',effect:'Thorns: attackers who strike in melee are hurt.',env:'land',D:2.3,cam:{cx:1.35,ty:.55,h:2.4},ti:1.3,
 build(sc){const c=creature(sc,{col:'#6b4f35',belly:'#b99a70',sx:1,sy:1.1,sz:1.1,legH:.28,hs:.8,tl:.25}),d=dummy(sc,2.3),qm=lam('#efe6cc'),qs=[];
  for(let i=0;i<36;i++){const g=new T.Group(),x=-.3+.6*((i*7)%12)/11,z=((i*5)%7-3)*.045;g.position.set(x,.17*Math.sqrt(Math.max(.1,1-x*x/.1)),z);const q=new T.Mesh(new T.ConeGeometry(.012,.3,5),qm);q.position.y=.15;g.add(q);c.body.add(g);qs.push({g,fan:-.7+1.4*(i%9)/8,sp:(rnd(i)-.5)*1.2,ph:rnd(i+5)*6});}
  return {pose(s,fx){idle(c,s);c.root.position.x=1.0;const up=s2(s,.25,.75)*(1-s2(s,2.1,2.7)),ra=Math.min(1,rp(s,.8,1.3))*Math.sin(Math.min(rp(s,.8,1.3)*30,Math.PI))*.0;
   qs.forEach(q=>{const rat=up*(s>.9&&s<2.0?.05*Math.sin(s*38+q.ph):0);q.g.rotation.z=1.4*(1-up)+q.fan*up+rat;q.g.rotation.x=q.sp*up;});
   c.hd.rotation.z=-.15*up;c.body.position.y-=.03*up;const ap=s2(s,.5,1.25)*(1-s2(s,1.6,2.1)),a=s-1.3;
   const dx=-.82*s2(s,.5,1.3)*(1-s2(s,1.45,1.9));if(a>0&&a<.5)burst(fx,V(1.55,.62,.0),a,7,.45,.05,'#fff0c0');
   dpose(d,Object.assign(R(s,1.3,{hop:.1,flash:.8,stars:1,sq:.1,shake:.0}),{dx:dx,qv:s>1.3&&s<3.0,flash:.7*Math.exp(-Math.max(0,a)*8)*(a>0?1:0),tint:'#c8402a',ta:0}),1,s);}};}});
// 12 ------------------------------------------------------------------------------------------ ground-pound shockwave
A.push({id:'ground_pound',name:'Ground-pound shockwave',animal:'elephant-scale stomp, exaggerated',organ:'heavy legs',role:'control / signature',effect:'Rear up and slam: knockdown ring around you.',env:'land',D:2.7,cam:{cx:1.5,ty:.7,h:3.4},ti:1.2,
 build(sc){const c=creature(sc,{col:'#8c929a',belly:'#a9aeb6',sx:1.5,sy:1.4,sz:1.3,legH:.75,hs:1.3,tl:.6}),d=dummy(sc,2.7),m=c.mat;
  const tk=new T.Group();tk.position.set(.25,-.03,0);c.hd.add(tk);rod(tk,m,.07,.04,.4,'-y');const tk2=new T.Group();tk2.position.y=-.4;tk.add(tk2);rod(tk2,m,.04,.025,.3,'x');
  for(const z of [-1,1]){cone(c.hd,lam('#f0ead6'),.03,.3,.15,-.1,z*.09,-1.2);ell(c.hd,lam('#7a8088'),.02,.2,.14).position.set(-.02,.0,z*.2);}
  return {pose(s,fx){idle(c,s);c.root.position.x=.0;const r=s2(s,.25,.95)*(1-s2(s,.95,1.2)),down=s2(s,1.2,1.5);
   c.body.rotation.z=.5*r;c.body.position.y+=.38*r;c.legs[0].rotation.z=.9*r;c.legs[1].rotation.z=.9*r;c.legs[2].rotation.z=-.5*r;c.legs[3].rotation.z=-.5*r;c.hd.rotation.z=.25*r;tk.rotation.z=-.5*r;
   const sl=Math.exp(-Math.pow((s-1.2)/.12,2));c.body.position.y-=.07*sl;c.hd.rotation.z-=.2*sl;const a=s-1.2;
   if(a>0&&a<1.1){const rr=.4+2.6*eo(a/1.1);fx.ring(.4,.012,0,rr,.9*(1-a/1.1),'#f2e2b8');fx.ring(.4,.013,0,rr*.7,.5*(1-a/1.1),'#d8c490');
    for(let i=0;i<10;i++){const az=i*.628,e=eo(a/1.1);fx.dot(V(.4+Math.cos(az)*(.2+2.2*e),.05+.22*Math.sin(Math.PI*Math.min(1,a/.8))*(1+(i%3)*.4),Math.sin(az)*(.2+2.2*e)*.5),.12+.12*e,.6*(1-a/1.1),dust);}}
   const hit=s-1.2-2.3/(2.6/1.1*1.0)*.75,h=Math.max(0,s-1.9);
   dpose(d,{dy:.5*Math.sin(Math.PI*rp(s,1.75,2.2)),tilt:-1.45*s2(s,1.9,2.25),dx:.4*s2(s,1.8,2.3),flash:.5*Math.exp(-h*8)*(h>0?1:0)},1,s);}};}});
// 13 ------------------------------------------------------------------------------------------ death roll
A.push({id:'death_roll',name:'Death roll',animal:'crocodile',organ:'jaws + heavy tail',role:'control / signature',effect:'Grab and spin: big damage over time while holding.',env:'water',D:2.45,cam:{cx:1.35,ty:.5,h:2.7},ti:1.15,
 build(sc){const c=creature(sc,{col:'#4c6b3a',belly:'#b9b46a',sx:1.6,sy:.55,sz:.9,legH:.2,hs:1.5,tl:1.2}),d=dummy(sc,2.45,{s:.8});c.legs.forEach(l=>{l.rotation.x=0;});
  return {pose(s,fx){idle(c,s);const lu=s2(s,.5,1.1),hold=s2(s,1.1,1.14)*(1-s2(s,2.55,2.6)),back=s2(s,2.9,3.3);c.root.position.x=-.2+1.25*lu-1.25*back*0;
   gait(c,s*14,.5*tri(s,.4,.8,1.1));const roll=2*Math.PI*2.3*s2(s,1.3,2.4);c.body.rotation.x=roll;c.body.position.y+=.12*Math.sin(Math.PI*s2(s,1.3,2.4));c.t1.rotation.y=.5*Math.sin(s*9)*tri(s,1.3,1.8,2.5);
   c.jw.rotation.z=-(.7*tri(s,.5,.95,1.15)+.0)-.0*hold;if(s>1.15&&s<2.55)c.jw.rotation.z=-.12;
   sc.updateMatrixWorld(true);const m=c.hd.localToWorld(V(.36,-.01,0));let p={};
   if(s<1.1)p={};else if(s<2.55)p={dx:m.x+.05-2.45,dy:m.y,gy:-.5*.8,rx:roll,flash:.0,yaw:0};else p={dx:m.x-2.45+.5*s2(s,2.55,2.9),dy:0,tilt:-1.5*s2(s,2.55,2.8),flash:0};
   if(s>1.15&&s<2.55){p.rx=-roll;}
   if(s>1.3&&s<2.4){for(let i=0;i<6;i++){const u=((s*2+i/6)%1);fx.dot(V(m.x-.1+.3*Math.cos(i*2+s*9),.15+.35*u,.3*Math.sin(i*2+s*9)),.07*(1-u),.8*(1-u),'#dff0f0');}}
   if(s>1.1&&s<1.5)burst(fx,V(m.x,m.y,.1),s-1.1,6,.5,.06,'#fff0c0');
   dpose(d,Object.assign(p,{z0:0}),1,s);if(p.gy!==undefined)d.pv.position.set(m.x+.05,m.y,0);}};}});
// 14 ------------------------------------------------------------------------------------------ ink cloud
A.push({id:'ink_cloud',name:'Ink cloud',animal:'octopus and squid',organ:'ink sac (water)',role:'defence / escape / signature',effect:'Blinds the pursuer and lets you jet away.',env:'water',D:2.6,cam:{cx:.9,ty:.55,h:3.0},ti:1.25,
 build(sc){const O=new T.Group();sc.add(O);const om=lam('#b0466f'),man=ell(O,om,.2,.28,.2);man.position.y=.0;const hdm=ell(O,om,.17,.16,.17);hdm.position.set(.14,-.12,0);for(const z of [-1,1]){ell(O,lam('#f4f1e8'),.045,.045,.04).position.set(.24,-.08,z*.1);ell(O,lam('#111'),.025,.025,.02).position.set(.27,-.08,z*.115);}
  const tent=[];for(let k=0;k<8;k++){const ch=[];for(let j=0;j<5;j++)ch.push(ell(sc,om,.04-.006*j,.04-.006*j,.04-.006*j));tent.push(ch);}
  const d=dummy(sc,2.6,{s:1.1,col:'#7a3a3a'});
  return {pose(s,fx){const jet=s2(s,1.15,1.35)*(1-s2(s,1.5,2.2));const x=.7-1.5*eo(rp(s,1.2,1.7))+1.5*s2(s,2.6,3.3),pump=Math.max(0,Math.sin(s*5))*.0+.12*Math.exp(-Math.pow((s-1.25)/.12,2));
   const y=.55+.04*Math.sin(s*2)+.1*jet;O.position.set(x,y,0);O.scale.set(1-pump,1+pump*1.3,1-pump);O.rotation.z=.3*s2(s,1.1,1.3)*(1-s2(s,1.8,2.4));
   tent.forEach((ch,k)=>{const a=k/8*Math.PI*2,base=V(.05+.09*Math.cos(a)*.6,y-.18,.1*Math.sin(a));let p=base.clone();for(let j=0;j<5;j++){const sw=.5*Math.sin(s*3+k+j*.6),down=V(.12*Math.sin(s*2+k)*(1-jet),-1,.25*Math.sin(a)+.12*sw*(1-jet)).normalize(),back=V(-1,-.1,.1*Math.sin(a)).normalize(),dir=lerpV(down,back,jet).normalize();p=p.clone().addScaledVector(dir,.1);ch[j].position.set(x+p.x-.0,p.y,p.z);}});
   const a=s-1.25;if(a>0){const u=rp(a,0,1.2),fade=1-s2(s,2.3,3.1);for(let i=0;i<12;i++){const dx=(rnd(i)-.4)*1.0*eo(u),dz=(rnd(i+3)-.5)*.7*eo(u),dy=(rnd(i+7)-.4)*.6*eo(u);fx.dot(V(.7+dx+.3*eo(u),.55+dy,dz),.12+.3*eo(u),.85*fade,i%3?'#1a1430':'#0e0a1e');}}
   const adv=-1.25*s2(s,.5,1.35)*(1-s2(s,2.3,2.9));const bl=(s>1.35&&s<2.7)?1:0;
   dpose(d,{dx:adv-.0,blind:bl,yaw:.5*Math.sin(s*10)*rp(s,1.4,1.5)*(1-rp(s,2.3,2.7)),tilt:.0,dy:.0,dz:.2*Math.sin(s*5)*rp(s,1.4,1.5)*(1-rp(s,2.3,2.7))},1,s);}};}});
// 15 ------------------------------------------------------------------------------------------ hind kick
A.push({id:'hind_kick',name:'Hind kick',animal:'donkey',organ:'strong legs',role:'control / defence',effect:'Knockback to whatever is behind you.',env:'land',D:2.25,cam:{cx:1.4,ty:.6,h:2.5},ti:1.05,
 build(sc){const c=creature(sc,{col:'#8a8378',belly:'#cfc8b8',sx:1.2,sy:1.1,legH:.55,hs:1.05,tl:.5}),d=dummy(sc,2.25);for(const z of [-1,1])cone(c.hd,lam('#6a645a'),.035,.22,.0,.17,z*.06,.2);
  return {pose(s,fx){idle(c,s);c.root.position.x=1.25;c.root.rotation.y=Math.PI;const dn=tri(s,.35,.9,2.0),kick=s2(s,.98,1.04)*(1-s2(s,1.4,1.9)),cock=s2(s,.5,.95)*(1-s2(s,.95,1.0));
   c.body.rotation.z=-.3*dn;c.hd.rotation.z=.2*dn;c.legs[0].rotation.z=.15*dn;c.legs[1].rotation.z=.15*dn;c.legs[2].rotation.z=.5*cock-1.5*kick;c.legs[3].rotation.z=.5*cock-1.5*kick*(s>1.0?1:0);c.body.position.y+=.05*dn;
   const a=s-1.05;burst(fx,V(1.95,.5,.05),a,8,.5,.06,'#fff0c0');if(a>0&&a<.8)for(let i=0;i<5;i++){const u=a/.8;fx.dot(V(1.7+.4*i*u,.06+.1*u,(i-2)*.12),.1+.1*u,.5*(1-u),dust);}
   dpose(d,Object.assign(R(s,1.07,{kb:1.0,kt:.5,tilt:1.1,hop:.35,flash:.8,sq:.1}),{tilt:-1.35*s2(s,1.07,1.5)}),1,s);}};}});
// 16 ------------------------------------------------------------------------------------------ tail club
A.push({id:'tail_club',name:'Tail club',animal:'ankylosaur-style armour (ankylosaur, glyptodont)',organ:'tail + bone club',role:'control / signature',effect:'Sweeping knockdown with a stun; breaks the target\'s guard.',env:'land',D:2.4,cam:{cx:1.5,ty:.5,h:2.5},ti:1.1,
 build(sc){const c=creature(sc,{col:'#6b7a5a',belly:'#a9b48c',sx:1.3,sy:.9,sz:1.3,legH:.3,hs:.7,tl:1.1}),d=dummy(sc,2.4),pm=lam('#4d5a40');
  for(let k=0;k<7;k++)ell(c.body,pm,.07,.045,.12).position.set(.3-k*.1,.2*(1-Math.abs(k-3)*.05),0);
  const cl=ell(c.t2,lam('#c8c2a4'),.1,.1,.1);cl.position.x=-.3;for(const z of [-1,1])cone(c.t2,lam('#e8e2c4'),.03,.12,-.3,0,z*.1,0).rotation.x=z*Math.PI/2;
  return {pose(s,fx){idle(c,s);c.root.position.x=.85;c.root.rotation.y=Math.PI;const wind=s2(s,.35,.95),whip=s2(s,.95,1.08),rec=s2(s,1.4,2.2);const sw=(1.15*wind*(1-whip)+(-.15)*whip*(1-rec)+.0)*(1);
   c.t1.rotation.y=sw*.85;c.t2.rotation.y=sw*.5;c.body.rotation.y=-.25*wind*(1-whip)*(1-rec)+.1*whip*(1-rec);c.body.position.y+=-.02*wind;
   sc.updateMatrixWorld(true);const club=c.t2.localToWorld(V(-.3,0,0)),a=s-1.08;if(s>.98&&s<1.2){fx.dot(club.clone().add(V(-.1,0,.25)),.12,.35,'#ffe0a0');}
   burst(fx,V(club.x,.45,club.z),a,7,.5,.06,'#fff0c0');if(a>0&&a<.7)fx.ring(club.x,.012,0,.3+.9*a,.6*(1-a/.7),'#e2d2a8');
   dpose(d,Object.assign(R(s,1.1,{kb:.75,kt:.45,hop:.2,flash:.7,stars:1,sq:.08}),{tilt:-1.5*s2(s,1.15,1.6)}),1,s);}};}});
// ---------------------------------------------------------------- scene dressing + per-loop wrapper
function build(def,idx){
  const water=def.env==='water',sc=new T.Scene(),bg=water?'#143c4a':'#1c2227';sc.background=new T.Color(bg);sc.fog=new T.Fog(bg,12,32);
  sc.add(new T.AmbientLight('#ffffff',.78));const dl=new T.DirectionalLight('#fff4e0',.9);dl.position.set(-2.5,5,4);sc.add(dl);const rim=new T.DirectionalLight('#9cc4d8',.3);rim.position.set(3,2,-4);sc.add(rim);
  const g=new T.Mesh(new T.PlaneGeometry(60,60),new T.MeshLambertMaterial({map:BB.TEX.ground,color:water?'#6fa8b8':'#ffffff'}));g.rotation.x=-Math.PI/2;g.position.set(2,0,0);sc.add(g);
  if(water){const w=new T.Mesh(new T.PlaneGeometry(60,60),new T.MeshBasicMaterial({color:'#4fb0d8',transparent:true,opacity:.1,depthWrite:false}));w.rotation.x=-Math.PI/2;w.position.set(2,.006,0);sc.add(w);}
  else sc.add(new T.Mesh(BB.BLADES,new T.MeshLambertMaterial({color:'#6f9650'})));
  const fx=BB.FXPool(sc),inst=def.build(sc);return {def,sc,fx,inst,cam:new T.PerspectiveCamera(30,1.8,.05,90)};
}
window.SIG={A,L,build,rp,s2};
})();
