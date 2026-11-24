'use strict';
// Primigenia ice lab (A85 cryo gland, study process A60): shared core. Textures, deterministic particle emitters, ice materials and
// crystalline meshes, ground frost, the alpine scene. Creature and target live in ice_quad.js; the 3 moves in ice_spike.js, ice_breath.js, ice_bridge.js.
// Units: metres, +x forward (the cryo creature faces +x), +y up, +z its right. Times in ms. Every rig is a pure function of u (ms), so scrubbing and frame stepping work.
// Numbers marked "start" are starting values, not measured; the owner picks the look, the game numbers come from A85/A89.
(function(root){
const T=root.THREE,BB=root.BB,EG=root.EG;
const {V,clamp,sm,lerp,lam,ell,X,Y,Z}=BB;
const {ramp,win,pls,ease,keys}=EG;
const IC={T,BB,EG,V,clamp,sm,lerp,lam,ell,X,Y,Z,ik:BB.ik,place:BB.place,ramp,win,pls,ease,keys,rigs:{spike:[],breath:[],bridge:[]}};
const TAU=Math.PI*2;
const easeOut=u=>{u=clamp(u,0,1);return 1-(1-u)*(1-u);};
const easeIO=u=>{u=clamp(u,0,1);return u<.5?2*u*u:1-2*(1-u)*(1-u);};
const back=u=>{u=clamp(u,0,1);const c=1.7;return 1+(c+1)*Math.pow(u-1,3)+c*Math.pow(u-1,2);};   // overshoot ease-out
const hash=(a,b)=>{let s=(Math.imul(a|0,374761393)+Math.imul(b|0,668265263))>>>0;s=Math.imul(s^(s>>>13),1274126177)>>>0;return((s^(s>>>16))>>>0)/4294967296;};
Object.assign(IC,{TAU,easeOut,easeIO,back,hash});
// cumulative table of a speed function (m per ms*1000): table lookup so walk distance is a pure function of t
function integ(fn,len,dt){dt=dt||8;const n=Math.ceil(len/dt)+2,a=new Float32Array(n);let s=0;for(let i=1;i<n;i++){s+=fn((i-.5)*dt)*dt/1000;a[i]=s;}return t=>{const f=clamp(t/dt,0,n-1.001),i=Math.floor(f);return a[i]+(a[i+1]-a[i])*(f-i);};}
IC.integ=integ;

// ------------------------------------------------------------------ textures
function cv(n,fn,rep){const c=document.createElement('canvas');c.width=c.height=n;fn(c.getContext('2d'),n);const t=new T.CanvasTexture(c);if(rep){t.wrapS=t.wrapT=T.RepeatWrapping;t.repeat.set(rep,rep);}return t;}
const TEX={};
TEX.puff=cv(64,(g,n)=>{const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(255,255,255,.95)');gr.addColorStop(.35,'rgba(255,255,255,.5)');gr.addColorStop(.7,'rgba(255,255,255,.12)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,n,n);});
TEX.spark=cv(64,(g,n)=>{const gr=g.createRadialGradient(32,32,0,32,32,20);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.25,'rgba(210,240,255,.55)');gr.addColorStop(1,'rgba(180,225,255,0)');g.fillStyle=gr;g.fillRect(0,0,n,n);
  g.strokeStyle='rgba(255,255,255,.95)';g.lineWidth=2;g.lineCap='round';g.beginPath();g.moveTo(32,3);g.lineTo(32,61);g.moveTo(3,32);g.lineTo(61,32);g.stroke();g.lineWidth=1;g.globalAlpha=.6;g.beginPath();g.moveTo(14,14);g.lineTo(50,50);g.moveTo(50,14);g.lineTo(14,50);g.stroke();});
TEX.flake=cv(64,(g,n)=>{g.translate(32,32);g.strokeStyle='rgba(255,255,255,.95)';g.lineWidth=2.2;g.lineCap='round';for(let k=0;k<6;k++){g.save();g.rotate(k*Math.PI/3);g.beginPath();g.moveTo(0,0);g.lineTo(0,27);g.moveTo(0,13);g.lineTo(7,20);g.moveTo(0,13);g.lineTo(-7,20);g.stroke();g.restore();}
  const gr=g.createRadialGradient(0,0,0,0,0,10);gr.addColorStop(0,'rgba(255,255,255,.8)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(-32,-32,64,64);});
// ground frost: a fern of crystal arms with soft rime in between (alpha texture, white)
TEX.frost=cv(256,(g,n)=>{const R=BB.rng(5);g.translate(128,128);const gr=g.createRadialGradient(0,0,0,0,0,124);gr.addColorStop(0,'rgba(235,248,255,.62)');gr.addColorStop(.55,'rgba(225,244,255,.30)');gr.addColorStop(1,'rgba(220,240,255,0)');g.fillStyle=gr;g.beginPath();g.arc(0,0,124,0,TAU);g.fill();
  g.strokeStyle='rgba(255,255,255,.9)';g.lineCap='round';
  const arm=(len,w,d)=>{g.lineWidth=w;g.beginPath();g.moveTo(0,0);g.lineTo(len,0);g.stroke();if(d<=0)return;for(let k=1;k<=4;k++){const p=len*k/5,bl=len*(.42-.05*k);for(const sg of [-1,1]){g.save();g.translate(p,0);g.rotate(sg*(.9+R()*.2));arm(bl,w*.62,d-1);g.restore();}}};
  for(let k=0;k<7;k++){g.save();g.rotate(k*TAU/7+R()*.3);arm(112-R()*22,2.6,2);g.restore();}
  g.fillStyle='rgba(255,255,255,.55)';for(let k=0;k<70;k++){const a=R()*TAU,r=R()*120;g.fillRect(Math.cos(a)*r,Math.sin(a)*r,1.6,1.6);}});
TEX.crack=cv(256,(g,n)=>{const R=BB.rng(9);g.strokeStyle='rgba(20,52,78,.9)';g.lineCap='round';g.lineJoin='round';
  const cr=(x,y,a,len,w,d)=>{g.lineWidth=w;g.beginPath();g.moveTo(x,y);let px=x,py=y;const st=Math.max(3,len/14|0);for(let i=0;i<st;i++){a+=(R()-.5)*.7;px+=Math.cos(a)*len/st;py+=Math.sin(a)*len/st;g.lineTo(px,py);}g.stroke();if(d>0){cr(px,py,a+.7,len*.5,w*.7,d-1);cr(x+(px-x)*.5,y+(py-y)*.5,a-.8,len*.45,w*.7,d-1);}};
  for(let k=0;k<6;k++)cr(128,128,k*TAU/6+R()*.5,70+R()*40,3,2);g.strokeStyle='rgba(235,250,255,.7)';g.lineWidth=1;for(let k=0;k<6;k++)cr(128,128,k*TAU/6+.3,50+R()*30,1.2,1);});
TEX.water=cv(256,(g,n)=>{g.fillStyle='rgba(0,0,0,0)';g.clearRect(0,0,n,n);const R=BB.rng(21);g.lineCap='round';
  for(let k=0;k<70;k++){const x=R()*n,y=R()*n,l=14+R()*30;g.strokeStyle='rgba(210,240,255,'+(.08+R()*.14)+')';g.lineWidth=1+R()*1.4;g.beginPath();for(let i=0;i<=8;i++){const px=x+i/8*l,py=y+Math.sin(i*.9+k)*2;if(i===0)g.moveTo(px,py);else g.lineTo(px,py);}g.stroke();}},3);
TEX.ground=cv(256,(g,n)=>{const R=BB.rng(33);g.fillStyle='#55676b';g.fillRect(0,0,n,n);for(let k=0;k<420;k++){const v=70+R()*50|0;g.fillStyle=`rgba(${v+20},${v+36},${v+40},${.18+R()*.25})`;g.beginPath();g.ellipse(R()*n,R()*n,2+R()*9,1.5+R()*5,R()*3,0,TAU);g.fill();}
  for(let k=0;k<26;k++){g.fillStyle='rgba(225,240,248,'+(.06+R()*.12)+')';g.beginPath();g.ellipse(R()*n,R()*n,10+R()*26,6+R()*14,R()*3,0,TAU);g.fill();}},14);
IC.TEX=TEX;

// ------------------------------------------------------------------ ice materials and crystalline meshes
const ICE_OPT={color:'#a9e3ff',specular:'#ffffff',shininess:150,transparent:true,flatShading:true,emissive:'#14486a'};
function iceMat(op,col){const m=new T.MeshPhongMaterial(Object.assign({},ICE_OPT,{opacity:op===undefined?.66:op}));if(col)m.color.set(col);return m;}
const EDGE_COL='#e9fbff';
// a crystal: elongated hexagonal prism with a pointed tip, base at the origin, pointing +y. (len,r) in metres
function crystalGeo(len,r,tipK){const g=new T.CylinderGeometry(r*.06,r,len*(1-(tipK||.28)),6,1);g.translate(0,len*(1-(tipK||.28))/2,0);
  const tip=new T.ConeGeometry(r*.06+.0001,len*(tipK||.28),6);tip.translate(0,len*(1-(tipK||.28))+len*(tipK||.28)/2,0);
  // merge by hand (cylinder top radius is tiny, so the cone just caps it): build a single prism-with-point
  const g2=new T.CylinderGeometry(.0001,r,len,6,1);g2.translate(0,len/2,0);return g2;}
// ice solid: translucent faceted mesh + bright core + crystal edge lines. geo is any BufferGeometry.
function iceSolid(geo,op,opts){opts=opts||{};const grp=new T.Group();
  const m=new T.Mesh(geo,iceMat(op));grp.add(m);
  const core=new T.Mesh(geo,new T.MeshBasicMaterial({color:'#e6f8ff',transparent:true,opacity:(opts.core===undefined?.18:opts.core),blending:T.AdditiveBlending,depthWrite:false}));core.scale.setScalar(.7);grp.add(core);
  const eg=new T.LineSegments(new T.EdgesGeometry(geo,24),new T.LineBasicMaterial({color:EDGE_COL,transparent:true,opacity:.7}));grp.add(eg);
  grp.userData={m,core,eg,op:op===undefined?.66:op,coreOp:opts.core===undefined?.18:opts.core};return grp;}
function iceOpacity(grp,k){const d=grp.userData;d.m.material.opacity=d.op*k;d.core.material.opacity=d.coreOp*k;d.eg.material.opacity=.7*Math.min(1,k*1.2);grp.visible=k>.01;}
function jitterGeo(g,amt,seed){const R=BB.rng(seed||3),p=g.attributes.position;const seen={};for(let i=0;i<p.count;i++){const key=p.getX(i).toFixed(3)+','+p.getY(i).toFixed(3)+','+p.getZ(i).toFixed(3);if(!seen[key])seen[key]=[(R()-.5)*amt,(R()-.5)*amt,(R()-.5)*amt];const j=seen[key];p.setXYZ(i,p.getX(i)+j[0],p.getY(i)+j[1],p.getZ(i)+j[2]);}g.computeVertexNormals();return g;}
IC.GEO={
  shard:(()=>{const g=new T.OctahedronGeometry(1,0);g.scale(.5,1.5,.38);return g;})(),
  slab:()=>jitterGeo(new T.BoxGeometry(1,.14,1,2,1,2),.07,4),
  floe:()=>jitterGeo(new T.CylinderGeometry(.5,.56,.12,7,1),.06,8),
  rock:(()=>{const g=new T.DodecahedronGeometry(1,0);return jitterGeo(g,.25,2);})()
};
Object.assign(IC,{iceMat,iceSolid,iceOpacity,jitterGeo,crystalGeo});
// a spike (icicle): faceted cone, base at origin, tip along +y, plus edge lines. length L, base radius r
function spikeMesh(L,r,op,sides){const g=new T.ConeGeometry(r,L,sides||6,1);g.translate(0,L/2,0);return iceSolid(g,op===undefined?.72:op,{core:.28});}
IC.spikeMesh=spikeMesh;

// ------------------------------------------------------------------ FX pool: sprites (mist puffs, sparks, flakes, glows), ice shards, ground frost, rings
function FX(scene){
  const mk=(map,n,blend,col)=>{const a=[];for(let k=0;k<n;k++){const s=new T.Sprite(new T.SpriteMaterial({map,transparent:true,depthWrite:false,blending:blend,color:col||'#ffffff'}));s.visible=false;scene.add(s);a.push(s);}return {a,i:0};};
  const P={puff:mk(TEX.puff,360,T.NormalBlending),spark:mk(TEX.spark,240,T.AdditiveBlending),flake:mk(TEX.flake,140,T.NormalBlending),glow:mk(TEX.puff,40,T.AdditiveBlending)};
  const shards={a:[],i:0};for(let k=0;k<110;k++){const m=new T.Mesh(IC.GEO.shard,iceMat(.8));m.visible=false;scene.add(m);shards.a.push(m);}
  const gf={a:[],i:0};for(let k=0;k<44;k++){const m=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:TEX.frost,transparent:true,depthWrite:false,opacity:0,polygonOffset:true,polygonOffsetFactor:-2-k*.02,polygonOffsetUnits:-2}));m.rotation.x=-Math.PI/2;m.visible=false;m.position.y=.006;scene.add(m);gf.a.push(m);}
  const rg={a:[],i:0};for(let k=0;k<10;k++){const m=new T.Mesh(new T.RingGeometry(.9,1,48),new T.MeshBasicMaterial({color:'#bfeaff',transparent:true,opacity:0,side:T.DoubleSide,depthWrite:false,blending:T.AdditiveBlending}));m.visible=false;scene.add(m);rg.a.push(m);}
  const o={
    reset(){for(const k in P)P[k].i=0;shards.i=0;gf.i=0;rg.i=0;},
    spr(kind,pos,size,op,col,rot,sy){const p=P[kind];if(!p||p.i>=p.a.length||op<.004||size<=0)return;const s=p.a[p.i++];s.visible=true;s.position.copy(pos);s.scale.set(size,sy||size,1);s.material.opacity=Math.min(1,op);s.material.rotation=rot||0;if(col)s.material.color.set(col);},
    shard(pos,q,sx,sy,op,col){if(shards.i>=shards.a.length||op<.01)return;const m=shards.a[shards.i++];m.visible=true;m.position.copy(pos);m.quaternion.copy(q);m.scale.set(sx,sy,sx);m.material.opacity=Math.min(1,op);if(col)m.material.color.set(col);else m.material.color.set('#a9e3ff');},
    frost(x,z,r,op,rot){if(gf.i>=gf.a.length||op<.01||r<.02)return;const m=gf.a[gf.i++];m.visible=true;m.position.x=x;m.position.z=z;m.scale.set(r*2,r*2,1);m.rotation.z=rot||0;m.material.opacity=Math.min(1,op);},
    ring(pos,r,op,col,vert){if(rg.i>=rg.a.length||op<.01)return;const m=rg.a[rg.i++];m.visible=true;m.position.copy(pos);m.scale.setScalar(r);m.rotation.set(vert?0:-Math.PI/2,vert?Math.PI/2:0,0);m.material.opacity=Math.min(1,op);if(col)m.material.color.set(col);},
    flush(){for(const k in P){const p=P[k];for(let i=p.i;i<p.a.length;i++)p.a[i].visible=false;}for(let i=shards.i;i<shards.a.length;i++)shards.a[i].visible=false;for(let i=gf.i;i<gf.a.length;i++)gf.a[i].visible=false;for(let i=rg.i;i<rg.a.length;i++)rg.a[i].visible=false;}
  };return o;}
IC.FX=FX;
// deterministic emitter. o: t0,t1 (ms), rate (/s), seed, life [a,b] ms, origin(tb)->Vector3, vel(r)->Vector3 (m/s), grav (m/s2), drag (1/s), size [s0,s1] (m), kind, col, op (peak), spin (rad/s), floor (y)
const _p=new T.Vector3();
function emit(fx,u,o){
  const dt=1000/o.rate,lmax=o.life[1];if(u<o.t0||u-lmax>o.t1)return;
  const kA=Math.max(0,Math.ceil((u-lmax-o.t0)/dt)),kB=Math.floor((Math.min(u,o.t1)-o.t0)/dt),g=o.grav||0,dr=o.drag||0;
  for(let k=kA;k<=kB;k++){
    const tb=o.t0+k*dt,r=BB.rng(((o.seed||1)*7919+k*104729)>>>0);r();const life=lerp(o.life[0],o.life[1],r()),age=u-tb;if(age<0||age>life)continue;
    const f=age/life,a=age/1000,v=o.vel(r),p0=o.origin(tb),k1=dr>0?(1-Math.exp(-dr*a))/dr:a,vr=r();
    _p.set(p0.x+v.x*k1,p0.y+v.y*k1-.5*g*a*a,p0.z+v.z*k1);if(o.floor!==undefined&&_p.y<o.floor)_p.y=o.floor;
    const s=lerp(o.size[0],o.size[1],easeOut(f))*(.8+.4*vr),inn=sm(f/(o.fadeIn||.12)),out=1-sm((f-(o.hold||.35))/(1-(o.hold||.35)));
    fx.spr(o.kind,_p,s,(o.op===undefined?.5:o.op)*inn*out,o.col,(o.spin||0)*a+vr*6,o.sy?s*o.sy:undefined);
  }
}
IC.emit=emit;
// ice shards bursting out of a point (shatter, impact). centre c, n shards, t0 start (ms), speed m/s, size scale
function burst(fx,u,t0,c,o){o=o||{};const age=u-t0;if(age<0||age>(o.life||1500))return;const n=o.n||26,R=BB.rng((o.seed||11)*977),a=age/1000,sp=o.speed||3.2,sz=o.size||1,up=o.up===undefined?1.6:o.up,sx=o.spread||V(1,1,1),q=new T.Quaternion(),e=new T.Euler();
  for(let k=0;k<n;k++){const th=R()*TAU,ph=Math.acos(2*R()-1),spd=sp*(.35+.9*R()),vx=Math.sin(ph)*Math.cos(th)*spd*sx.x,vy=Math.abs(Math.cos(ph))*spd*sx.y+up,vz=Math.sin(ph)*Math.sin(th)*spd*sx.z,rs=(R()-.5)*14,rr=R(),ss=(.03+.06*R())*sz;
    let x=c.x+vx*a*(1-.25*a),y=c.y+vy*a-4.9*a*a*1.2,z=c.z+vz*a*(1-.25*a);let bounce=0;if(y<.03*sz){y=.03*sz;bounce=1;}
    e.set(rs*a+rr*5,rr*6,rs*a*.6);q.setFromEuler(e);const fade=1-sm((age-(o.life||1500)*.55)/((o.life||1500)*.45));
    fx.shard(V(x,y,z),q,ss,ss*(1.4+rr),(o.op||.9)*fade);}
  // sparkle and powder
  const R2=BB.rng((o.seed||11)*31+5);for(let k=0;k<(o.n||26)*1.4;k++){const th=R2()*TAU,ph=Math.acos(2*R2()-1),spd=(sp*.9)*R2(),f=age/(o.life||1500),dx=Math.sin(ph)*Math.cos(th)*spd*sx.x,dy=Math.abs(Math.cos(ph))*spd*sx.y+.5,dz=Math.sin(ph)*Math.sin(th)*spd*sx.z,d=1-Math.exp(-3*a),life=.25+R2()*.5;if(f>life)continue;
    fx.spr(k%3?'spark':'flake',V(c.x+dx*d/3,c.y+dy*d/3-.4*a*a,c.z+dz*d/3),(.06+.08*R2())*sz,.9*(1-f/life),null,a*3+k);}
  if(age<700)for(let k=0;k<5;k++){const th=R2()*TAU;fx.spr('puff',V(c.x+Math.cos(th)*.25*sz*(1+a*2),c.y+.1+.35*sz*a*2,c.z+Math.sin(th)*.25*sz*(1+a*2)),(.5+.5*R2())*sz*(.5+a*2),.35*(1-age/700),'#dff4ff',k);}
}
IC.burst=burst;

// ------------------------------------------------------------------ alpine scene: cold ground, rocks, snow patches, spruces, light
function rngf(seed){return BB.rng(seed);}
function dress(scene,bgc,o){o=o||{};
  scene.background=new T.Color(bgc);scene.fog=new T.Fog(bgc,10,30);
  scene.add(new T.HemisphereLight('#dcecff','#3c4a52',.62));const dl=new T.DirectionalLight('#fff6ea',.95);dl.position.set(-2.5,5,4);scene.add(dl);const rim=new T.DirectionalLight('#8fc8f0',.5);rim.position.set(3,2.4,-4);scene.add(rim);
  const gm=new T.MeshLambertMaterial({map:TEX.ground});const gnd=new T.Mesh(new T.PlaneGeometry(90,90),gm);gnd.rotation.x=-Math.PI/2;if(o.skipGround)gnd.visible=false;scene.add(gnd);
  const R=rngf(o.seed||5),rm=new T.MeshPhongMaterial({color:'#7d8c96',flatShading:true,shininess:8});
  for(let k=0;k<(o.rocks===undefined?14:o.rocks);k++){const x=-5+R()*17,z=(R()<.5?-1:1)*(1.6+R()*5.5);if(o.avoid&&o.avoid(x,z))continue;const r=.12+R()*.34,m=new T.Mesh(IC.GEO.rock,rm);m.scale.set(r*(1+R()*.6),r*(.55+R()*.4),r*(1+R()*.5));m.position.set(x,r*.25,z);m.rotation.y=R()*6;scene.add(m);
    const sn=new T.Mesh(new T.CircleGeometry(r*.8,7),new T.MeshLambertMaterial({color:'#eef6fb'}));sn.rotation.x=-Math.PI/2;sn.position.set(x,r*.5,z);sn.scale.set(1,1,.7);sn.visible=false;}
  const gg=EG.grass(-5,16,o.grass===undefined?380:o.grass,o.seed||11);scene.add(new T.Mesh(gg,new T.MeshLambertMaterial({color:'#86a39a'})));
  // spruce silhouettes far back
  const tm=new T.MeshPhongMaterial({color:'#2f4a46',flatShading:true,shininess:6}),sm2=new T.MeshPhongMaterial({color:'#e8f2f6',flatShading:true,shininess:20});
  for(let k=0;k<(o.trees===undefined?16:o.trees);k++){const x=-4+R()*18,z=-6.5-R()*5,h=1.4+R()*1.6;const g=new T.Group();for(let j=0;j<3;j++){const c=new T.Mesh(new T.ConeGeometry(.5*(1-j*.25)*h/1.8,h*.5,7),tm);c.position.y=h*.28+j*h*.26;g.add(c);const cap=new T.Mesh(new T.ConeGeometry(.3*(1-j*.25)*h/1.8,h*.2,7),sm2);cap.position.y=h*.28+j*h*.26+h*.12;g.add(cap);}g.position.set(x,0,z);scene.add(g);}
  return {gnd,dl};}
IC.dress=dress;
IC.shadowBlob=function(scene){const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.003;scene.add(sh);return sh;};
root.IC=IC;
})(typeof window!=='undefined'?window:globalThis);
