'use strict';
// Primigenia oil + fire lab (A89 stomach oil gland, A90 flamethrower; study process A60): shared core.
// Reuses the signature-lab rigs (sig_rig.js: IK legs, lagged tube neck and tail, jointed head) and adds: flame / ignition / smoke / oil-drop effects,
// oil puddle and burn decals, a ballistic jet emitter that reads the performer's baked mouth path, and a wet-body look for the target.
// Units: metres, +x forward (performer faces +x, target faces -x), +y up, +z toward the camera. Times in seconds; every rig is a pure function of s (scrub safe).
// Numbers marked "start" are starting values for the owner to tune, not measured.
(function(root){
const BB=root.BB,T=BB.T,S=BB.sig,{V,clamp,sm,lam}=BB,{ell,rp,eo,s2,rnd,kf,TX,Quad,mkFx,idleP}=S;
const fr=x=>x-Math.floor(x),TAU=Math.PI*2;
const OIL={T,BB,V,clamp,sm,fr,rnd,kf,eo,s2,rp,TAU,rigs:{vomit:[],ignite:[],flame:[]}};
const win=(s,a,b,r)=>{r=r||.06;return s2(s,a,a+r)*(1-s2(s,b-r,b));};
OIL.win=win;
const FIRE=['#fff6c8','#ffd76a','#ffa030','#e9561a','#8c2a12'];
const ramp=(u,c)=>c[Math.min(c.length-1,Math.max(0,Math.floor(u*c.length)))];
OIL.FIRE=FIRE;OIL.ramp=ramp;OIL.BLUE=['#eef8ff','#a8d8ff','#58a8ff','#2f62d0','#1a2a70'];
// ---------------------------------------------------------------- textures
function cv(w,h,fn){const c=document.createElement('canvas');c.width=w;c.height=h;fn(c.getContext('2d'),w,h);return new T.CanvasTexture(c);}
function blobPath(g,cx,cy,R,seed){const r=BB.rng(seed),a=r()*6,b=r()*6,c=r()*6,d=r()*6;g.beginPath();for(let i=0;i<=48;i++){const t=i/48*TAU,k=R*(1+.13*Math.sin(3*t+a)+.09*Math.sin(5*t+b)+.06*Math.sin(8*t+c)+.04*Math.sin(13*t+d));const x=cx+Math.cos(t)*k,y=cy+Math.sin(t)*k;if(i===0)g.moveTo(x,y);else g.lineTo(x,y);}g.closePath();}
const TXO={flame:cv(128,128,(g)=>{const gr=g.createRadialGradient(64,86,2,64,80,52);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.35,'rgba(255,255,255,.7)');gr.addColorStop(.75,'rgba(255,255,255,.18)');gr.addColorStop(1,'rgba(255,255,255,0)');
  g.fillStyle=gr;g.beginPath();g.moveTo(64,4);g.bezierCurveTo(70,30,100,52,98,86);g.bezierCurveTo(96,112,78,124,64,124);g.bezierCurveTo(50,124,32,112,30,86);g.bezierCurveTo(28,52,58,30,64,4);g.fill();}),
  oil:[1,2,3].map(seed=>cv(256,256,(g,w)=>{blobPath(g,128,128,100,seed);const gr=g.createRadialGradient(118,118,10,128,128,112);gr.addColorStop(0,'rgba(34,22,8,.97)');gr.addColorStop(.7,'rgba(26,17,6,.93)');gr.addColorStop(1,'rgba(20,12,4,.55)');g.fillStyle=gr;g.fill();
    g.save();g.clip();g.lineCap='round';for(let k=0;k<3;k++){g.strokeStyle='rgba(255,236,190,'+(.34-k*.08)+')';g.lineWidth=5-k;g.beginPath();g.arc(128,128,66+k*17,3.5+k*.4,4.7+k*.3);g.stroke();}
    g.fillStyle='rgba(255,246,220,.5)';g.beginPath();g.ellipse(96,92,14,6,-.6,0,TAU);g.fill();
    for(let k=0;k<2;k++){const gr2=g.createRadialGradient(150-k*40,150+k*20,0,150-k*40,150+k*20,50);gr2.addColorStop(0,'rgba(80,170,200,.28)');gr2.addColorStop(.5,'rgba(190,90,170,.2)');gr2.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr2;g.fillRect(0,0,w,w);}g.restore();})),
  scorch:[1,2,3].map(seed=>cv(256,256,(g)=>{blobPath(g,128,128,104,seed+7);const gr=g.createRadialGradient(128,128,10,128,128,112);gr.addColorStop(0,'rgba(8,6,4,.88)');gr.addColorStop(.8,'rgba(10,8,6,.6)');gr.addColorStop(1,'rgba(10,8,6,0)');g.fillStyle=gr;g.fill();})),
  iri:cv(128,128,(g,w)=>{const cg=g.createConicGradient?g.createConicGradient(0,64,64):null;if(cg){['#ff7ab0','#ffd36a','#7affb0','#6ad0ff','#b08aff','#ff7ab0'].forEach((c,i)=>cg.addColorStop(i/5,c));g.fillStyle=cg;g.fillRect(0,0,w,w);g.globalCompositeOperation='destination-in';}
    const gr=g.createRadialGradient(64,64,10,64,64,62);gr.addColorStop(0,'rgba(0,0,0,0)');gr.addColorStop(.55,'rgba(0,0,0,.7)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(0,0,w,w);})};
OIL.TX=TXO;
// ---------------------------------------------------------------- stage
OIL.stage=function(scene,o){o=o||{};const bg=o.bg||'#10151a';scene.background=new T.Color(bg);scene.fog=new T.Fog(bg,13,34);
  scene.add(new T.AmbientLight('#8d9fb4',.62));const dl=new T.DirectionalLight('#ffe9cc',.62);dl.position.set(-2.5,5,4);scene.add(dl);const rim=new T.DirectionalLight('#6f9fc0',.34);rim.position.set(3,2,-4);scene.add(rim);
  const g=new T.Mesh(new T.PlaneGeometry(70,70),new T.MeshLambertMaterial({map:BB.TEX.ground,color:o.ground||'#cfd6c8'}));g.rotation.x=-Math.PI/2;g.position.set(2,0,0);scene.add(g);
  const light=new T.PointLight('#ff8a30',0,7,1.5);light.position.set(2,1,0);scene.add(light);
  const rm=lam('#545a58'),R=BB.rng(5);if(!o.bare){for(let k=0;k<9;k++){const m=new T.Mesh(new T.DodecahedronGeometry(.18+R()*.22,0),rm);const side=k%2?-1:1;m.position.set(-2+R()*9,.06,side*(2.4+R()*1.6));m.scale.set(1,.5+R()*.4,1);m.rotation.set(R()*3,R()*3,0);scene.add(m);}
    const gm=lam('#5f8447');for(let k=0;k<26;k++){const c=new T.Mesh(new T.ConeGeometry(.02,.22,4),gm);c.position.set(-3+R()*10,.1,(R()<.5?-1:1)*(1.9+R()*2.4));c.rotation.z=(R()-.5)*.4;scene.add(c);}}
  const fx=mkFx(scene,o.na||340,o.nn||170);return {scene,fx,light,ground:g,fl:0,flx:0,fly:0,flz:0};};
// the warm point light follows the biggest fire this frame: OIL.fireAt(S,pos,amount) while drawing, OIL.lightEnd(S,s) once at the end
OIL.fireAt=function(St,pos,a){if(a>St.fl){St.fl=a;St.flx=pos.x;St.fly=pos.y;St.flz=pos.z;}};
OIL.lightEnd=function(St,s){const a=St.fl;St.light.position.set(St.flx,St.fly+.9,St.flz+.3);St.light.intensity=a*(1.9+.35*Math.sin(s*37)+.25*Math.sin(s*23.3));St.fl=0;};
// ---------------------------------------------------------------- creatures
function gland(par,pos,sz,hex){const m=new T.MeshPhongMaterial({color:hex,emissive:hex,emissiveIntensity:.05,shininess:90,transparent:true,opacity:.92});const e=ell(par,m,sz[0],sz[1],sz[2]);e.position.copy(pos);return e;}
// the performer: a long-necked creature with a stomach gland under the belly (amber) and optionally a fire gland at the cheeks (red)
OIL.performer=function(sc,x0,o){o=Object.assign({col:'#8f9a72',belly:'#e8dca8',dark:'#3b3a2a',fire:false,big:false,yaw0:0,z0:0},o);const k=o.big?1.18:1;
  const c=Quad(sc,{col:o.col,belly:o.belly,dark:o.dark,x0,z0:o.z0,yaw0:o.yaw0,sl:.6*k,pr:[.25*k,.2*k,.17*k],cr:[.27*k,.25*k,.2*k],legU:.3*k,legL:.32*k,lr:.05*k,nl:.58*k,ns:11,nr0:.115*k,nr1:.07*k,na0:.52,nc0:-.32,hlev:-.12,hfol:.3,hl:.16*k,hh:.1*k,hw:.095*k,sn:.2*k,snh:.052*k,snw:.058*k,tl:1*k,ts:12,tr0:.11*k,tr1:.015*k,ta0:.12,eye:.03*k,
    skin:(i,a,out,part)=>{if(part==='neck'&&Math.cos(a)<-.15&&i>1){out[0]=.9;out[1]=.72;out[2]=.36;}}});
  c.gl=gland(c.pel,V(.3*k,-.2*k,0),[.2*k,.115*k,.135*k],'#d6902a');const g0=c.gl.scale.clone();c.glow=v=>{c.gl.material.emissiveIntensity=.05+.7*v;c.gl.scale.set(g0.x*(1+.22*v),g0.y*(1+.38*v),g0.z*(1+.22*v));};
  if(o.fire){const m=new T.MeshPhongMaterial({color:'#d8421e',emissive:'#d8421e',emissiveIntensity:.05,shininess:60});c.fg=[-1,1].map(z=>{const e=ell(c.head,m,.034*k,.027*k,.027*k);e.position.set(.01*k,-.02*k,z*.088*k);return e;});c.fg.forEach(e=>e.userData.s0=e.scale.clone());c.fglow=v=>{m.emissiveIntensity=.05+1.2*v;c.fg.forEach(e=>e.scale.copy(e.userData.s0).multiplyScalar(1+.35*v));};
    const dm=lam('#4a2e22');for(let j=0;j<7;j++){const sp=new T.Mesh(new T.ConeGeometry(.026*k,.11*k,5),dm);sp.geometry.translate(0,.055*k,0);sp.rotation.z=.25;if(j<4){sp.position.set(-.15*k+j*.1*k,.2*k,0);c.pel.add(sp);}else{sp.position.set((j-4)*.08*k-.08*k,.24*k,0);c.chest.add(sp);}}}
  c.k=k;c.neckAt=f=>{const p=c.neckPts,i=clamp(f,0,1)*(p.length-1),a=Math.floor(i),b=Math.min(p.length-1,a+1);return p[a].clone().lerp(p[b],i-a);};
  c.mouthDir=()=>c.head.localToWorld(V(1,0,0)).sub(c.head.localToWorld(V(0,0,0))).normalize();return c;};
// prey: Pip (k=1) or a big rogue (k>1); same rig as signature Pip, scaled
const ADD={na:1,nc:1,hp:1,hy:1,ny:1,br:1,bend:1,pitch:1,roll:1,ear:1,ta:1,tc:1,jaw:1,ctw:1,cyaw:1,sq:1};
OIL.prey=function(sc,x,o){o=Object.assign({k:1,col:'#c9a86a',belly:'#efe0b4',dark:'#5e4b30',z0:0,ears:1,horns:false},o);const k=o.k;
  const d=Quad(sc,{col:o.col,belly:o.belly,dark:o.dark,x0:x,z0:o.z0,yaw0:Math.PI,sl:.34*k,pr:[.17*k,.15*k,.13*k],cr:[.19*k,.19*k,.15*k],legU:.2*k,legL:.21*k,lr:.034*k,nl:.3*k,ns:7,nr0:.07*k,nr1:.05*k,na0:.95,nc0:-.55,hlev:-.1,hl:.1*k,hh:.08*k,hw:.075*k,sn:.06*k,snh:.04*k,snw:.04*k,tl:.26*k,ts:6,tr0:.04*k,tr1:.014*k,ta0:.35,ears:o.ears,earL:.15*k,earW:.045*k,eye:.025*k,toeL:.04*k,
    skin:(i,a,out,part)=>{if(part==='tail'&&i>=5&&k<1.5){out[0]=.95;out[1]=.92;out[2]=.82;}}});
  d.x0=x;d.k=k;
  if(o.horns){const hm=lam('#e5dcc0');for(const z of [-1,1]){const h=new T.Mesh(new T.ConeGeometry(.026*k,.2*k,6),hm);h.geometry.translate(0,.1*k,0);h.position.set(-.02*k,.06*k,z*.05*k);h.rotation.set(z*.35,0,.8);d.head.add(h);}
    const dm=lam('#3a2c22');for(let j=0;j<6;j++){const sp=new T.Mesh(new T.ConeGeometry(.03*k,.12*k,5),dm);sp.geometry.translate(0,.06*k,0);sp.position.set(-.12*k+j*.08*k,.19*k,0);sp.rotation.z=.2;d.pel.add(sp);}}
  d.set=function(s,A){A=A||{};const idl=idleP(s,true),P={};for(const q in idl)P[q]=idl[q];
    for(const q in A){if(q==='dx')P.x=x+A.dx;else if(q==='dy')P.y=d.h+A.dy;else if(q==='dz')P.z=o.z0+A.dz;else if(q==='yaw')P.yaw=Math.PI+A.yaw;else if(ADD[q])P[q]=(P[q]||0)+A[q];else P[q]=A[q];}
    if(P.y===undefined)P.y=d.h;P.lt=s;d.pose(P);
    const f=A.flash||0;d.flash(f*(A.fr===undefined?.9:A.fr),f*(A.fg===undefined?.5:A.fg),f*(A.fb===undefined?.1:A.fb));d.tint(A.tint,A.tamt||0);return P;};
  d.chestW=()=>d.chest.localToWorld(V(.02*k,.0,0));
  return d;};
// bake the performer's mouth path (position and facing) for any pose function, so jets can be fired from earlier times
OIL.bake=function(c,poseFn,len){const N=Math.ceil(len*60)+2,a=new Float32Array(N*6);for(let i=0;i<N;i++){c.pose(poseFn(i/60));const m=c.mouth(1),f=c.mouthDir();a.set([m.x,m.y,m.z,f.x,f.y,f.z],i*6);}
  return t=>{const q=clamp(t*60,0,N-1.001),i=Math.floor(q),u=q-i,b=i*6,v=k=>a[b+k]+(a[b+6+k]-a[b+k])*u;return {p:V(v(0),v(1),v(2)),d:V(v(3),v(4),v(5)).normalize()};};};
// ---------------------------------------------------------------- effects
// one flame column on the ground (or on a body): glow, flame tongues, hot core, a smoke puff
OIL.flame=function(fx,s,pos,h,amt,seed,o){if(amt<.03||h<=.001)return;o=o||{};const lean=o.lean||0,n=o.n||4,hv=o.heat||1,hq=Math.pow(hv,.6);seed=seed||0;const y0=pos.y;
  fx.p(V(pos.x,y0+h*.2+h*.55,pos.z),h*1.3,.24*amt*hv,o.glow||'#ff7418',TX.soft,true);
  for(let k=0;k<n;k++){const u=fr(s*1.7+k/n+seed*.173),w=1+.2*Math.sin(s*31+k*5+seed*7),sw=Math.sin(s*7.3+k*2.1+seed)*h*.1*u+lean*u*h,sz=h*.62*(1-.58*u)*w*(k%2?1:1.18);
    const p=V(pos.x+(rnd(seed*3+k)-.5)*h*.24+sw,y0+sz*.82+h*.8*u,pos.z+(rnd(seed*5+k)-.5)*h*.2);
    fx.p(p,sz,amt*hq*(.98-.9*u*u)*.92,ramp(Math.min(.99,u*.95+.05),o.ramp||FIRE),TXO.flame,true,Math.sin(s*13+k*3+seed)*.16+lean*.6,1.65);}
  fx.p(V(pos.x,y0+h*.3,pos.z),h*.5,.7*amt*hv*(.82+.18*Math.sin(s*47+seed)),o.core||'#fff0a8',TX.soft,true);
  if(o.smoke!==false){const u2=fr(s*.5+seed*.31);fx.p(V(pos.x+lean*h*u2*2+.08*h*Math.sin(s*2+seed),y0+h*(1.2+2.2*u2),pos.z),h*(.5+1.0*u2),.2*amt*Math.sin(Math.min(1,u2*1.4)*Math.PI*.9),'#2d2927',TX.puff,false,seed+u2);}};
OIL.smoke=function(fx,s,pos,n,amt,seed,sz){for(let k=0;k<n;k++){const u=fr(s*.6+k/n+(seed||0)*.37);fx.p(V(pos.x+.1*Math.sin(k*3+s*1.3),pos.y+.15+.9*u,pos.z+.08*Math.sin(k*5+s)),(sz||.28)*(.5+1.2*u),.26*amt*Math.sin(u*Math.PI),'#34302d',TX.puff,false,k+s*.2);}};
OIL.shimmer=function(fx,s,pos,w,amt,seed){for(let k=0;k<3;k++){const u=fr(s*.9+k/3+(seed||0)*.21);fx.p(V(pos.x+(rnd(k+seed)-.5)*w+.05*Math.sin(s*4+k),pos.y+.3+1.1*u,pos.z+(rnd(k*3+seed)-.5)*w*.5),w*(.5+.4*u),.06*amt*Math.sin(u*Math.PI),'#ffe8c8',TX.puff,false);}};
OIL.embers=function(fx,s,pos,n,amt,seed,spread){spread=spread||.4;for(let k=0;k<n;k++){const u=fr(s*.8+k*.173+(seed||0)*.13),a=k*2.4;fx.p(V(pos.x+Math.cos(a)*spread*u+.1*Math.sin(s*3+k),pos.y+.2+1.5*u,pos.z+Math.sin(a)*spread*.6*u),.035+.02*(k%3),amt*(1-u)*(.7+.3*Math.sin(s*40+k)),k%2?'#ffd27a':'#ff9a40',TX.star,true,k+s);}};
// ignition: a whoosh. a = seconds since the light-up, R = radius in m
OIL.burst=function(fx,pos,a,R,seedv){if(a<0||a>1.3)return;seedv=seedv||0;const u=a/1.3,e=eo(Math.min(1,a/.3));
  if(a<.16)fx.p(V(pos.x,pos.y+.25*R,pos.z),R*(.7+1.3*a/.16),.6*(1-a/.16),'#fff3c4',TX.soft,true);
  fx.p(V(pos.x,pos.y+.35*R,pos.z),R*(.8+2.2*e),.42*Math.pow(1-u,1.4),'#ff9a2e',TX.soft,true);
  if(a<.6)fx.ring(pos.x,.02,pos.z,R*(.4+2.2*eo(Math.min(1,a/.5))),.34*(1-a/.6),'#ffb858');
  for(let i=0;i<5;i++){const az=i*TAU/5+seedv,rr=R*(.2+1.1*e),p=V(pos.x+Math.cos(az)*rr,pos.y+R*(.3+.3*e),pos.z+Math.sin(az)*rr*.8);fx.p(p,R*1.1*(1-.5*u),.32*Math.pow(1-u,1.3),ramp(Math.min(.99,u*1.2+.1),FIRE),TX.soft,true);}
  for(let i=0;i<8;i++){const az=i*2.3+seedv,sp=R*(.4+2.4*eo(Math.min(1,a/.8)))*(.5+.5*rnd(i+4)),p=V(pos.x+Math.cos(az)*sp,pos.y+R*(.3+1.4*Math.min(1,a/.5))*(.5+.5*rnd(i)),pos.z+Math.sin(az)*sp*.7);fx.p(p,.045,(1-u)*.9,'#ffd27a',TX.star,true,i);}};
// an oil drop: dark amber body, a sharp highlight
OIL.drop=function(fx,p,size,op,sy){if(op<=.01)return;fx.p(p,size*1.25,.55*op,'#c98a22',TX.drop,false,0,sy);fx.p(p,size*.92,.95*op,'#5a3508',TX.drop,false,0,sy);fx.p(V(p.x-size*.16,p.y+size*.22,p.z+size*.12),size*.3,.7*op,'#ffeec4',TX.soft,true);};
// drips hanging from an anchor then falling. anchor(): world position, rate = drips per second
OIL.drip=function(fx,s,anchor,seed,amt,rate){if(amt<.04)return;rate=rate||.8;const a=anchor();for(let j=0;j<2;j++){const ph=fr(s*rate+seed*.37+j*.5);
  if(ph<.55){const u=ph/.55;OIL.drop(fx,V(a.x,a.y-.012*u*3,a.z),.028+.022*u,amt,1+.7*u);}
  else{const t=(ph-.55)*1.1,y=a.y-.5*9.8*t*t;if(y>.02)OIL.drop(fx,V(a.x,y,a.z),.032,amt,1.3);else if(t<.4){fx.p(V(a.x,.012,a.z),.09+.1*(t-.32)*3,.4*amt*Math.max(0,1-(t-.3)*6),'#2e1d08',TX.soft,false);}}}};
// the wet look: a cool sheen on the coat, travelling glints, shifting rainbow film, drips from belly, chin and tail
OIL.wet=function(fx,s,d,amt,seed){if(amt<.03)return;const k=d.k;seed=seed||0;
  const pts=[()=>d.head.localToWorld(V(.02*k,.07*k,0)),()=>d.chest.localToWorld(V(.0,.2*k,.0)),()=>d.pel.localToWorld(V(.12*k,.17*k,0)),()=>d.pel.localToWorld(V(-.05*k,.0,.12*k))];
  pts.forEach((f,i)=>{const p=f(),q=.5+.5*Math.sin(s*5.1+i*1.9+seed);fx.p(p,(.07+.05*q)*k,.7*amt*q,'#fffbe6',TX.star,true,s*.6+i);fx.p(p,.1*k,.2*amt*(1-q),'#9fe0ff',TX.soft,true);
    if(i<2)fx.p(p.clone().add(V(0,.02,.04)),.13*k,.12*amt,['#ff8cc0','#8cffc8','#8cc8ff'][(Math.floor(s*1.7)+i)%3],TX.soft,true);});
  // long specular streaks: a flat soft sprite along the back and shoulder, a short one on the head
  [[()=>d.pel.localToWorld(V(.16*k,.2*k,.0)),.34],[()=>d.chest.localToWorld(V(.0,.215*k,.02*k)),.26],[()=>d.head.localToWorld(V(.02*k,.095*k,0)),.14]].forEach((q,i)=>{const w=.62+.38*Math.sin(s*2.2+i*2+seed);fx.p(q[0](),q[1]*k*(.9+.2*w),.46*amt*w,'#fff6dc',TX.soft,true,0,.18);});
  OIL.drip(fx,s,()=>d.chest.localToWorld(V(.02*k,-.17*k,.02*k)),seed+1,amt,.9);OIL.drip(fx,s,()=>d.head.localToWorld(V(.14*k,-.06*k,0)),seed+2,amt,.7);OIL.drip(fx,s,()=>d.pel.localToWorld(V(-.1*k,-.15*k,-.05*k)),seed+3,amt,1.1);
  d.flash(.012*amt,.035*amt,.05*amt);};
// the wet tint to feed into Prey.set: pass soak 0..1
OIL.soakTint=soak=>({tint:'#2b2112',tamt:.62*soak});
// ---------------------------------------------------------------- puddles and painted lines (flat decals)
const PG=new T.PlaneGeometry(1,1);
OIL.Puddle=function(sc,seed){seed=seed||0;const g=new T.Group();sc.add(g);const mk=(map,opt,y)=>{const m=new T.Mesh(PG,new T.MeshBasicMaterial(Object.assign({map,transparent:true,depthWrite:false,opacity:0},opt)));m.rotation.x=-Math.PI/2;m.position.y=y;m.visible=false;g.add(m);return m;};
  const sc1=mk(TXO.scorch[seed%3],{},.003),oil=mk(TXO.oil[seed%3],{},.005),iri=mk(TXO.iri,{blending:T.AdditiveBlending,color:'#ffffff'},.0065),glow=mk(TX.soft,{blending:T.AdditiveBlending,color:'#ff7a1c'},.0075);
  return {g,set(x,z,rx,rz,o){o=o||{};g.position.set(x,0,z);g.rotation.y=(o.rot||0)+seed*1.7;const sh=rx>.001&&(o.a||0)>.01,sc2=o.scorch||0;
    [oil,iri].forEach(m=>{m.visible=sh;m.scale.set(rx*2.2,rz*2.2,1);});oil.material.opacity=(o.a||0)*(1-.35*sc2);iri.material.opacity=.2*(o.a||0)*(1-(o.burn||0))*(.7+.3*Math.sin((o.t||0)*1.6+seed));iri.rotation.z=(o.t||0)*.3+seed;
    sc1.visible=sc2>.01;sc1.scale.set(rx*2.3,rz*2.3,1);sc1.material.opacity=sc2;glow.visible=(o.burn||0)>.02;glow.scale.set(rx*2.6,rz*2.6,1);glow.material.opacity=(o.burn||0)*(.5+.1*Math.sin((o.t||0)*30+seed));}};};
// a painted line of blobs along path(u)->{x,z}: set(reveal 0..1, burnFn(i,u)->0..1, scorchFn(i,u)->0..1, t)
OIL.Line=function(sc,n,path,w,seed){const L={n,pd:[],w,path};for(let i=0;i<n;i++)L.pd.push(OIL.Puddle(sc,(seed||0)+i));
  L.set=function(reveal,burnFn,scorch,t){for(let i=0;i<n;i++){const u=(i+.5)/n,p=path(u),a=sm(reveal*n-i);L.pd[i].set(p.x,p.z,w*(.55+.3*rnd(i+3))*a*1.15,w*(.5+.25*rnd(i+8))*a,{a:Math.min(1,a*1.1),burn:burnFn?burnFn(i,u):0,scorch:scorch?scorch(i,u):0,t,rot:rnd(i)*3});}};return L;};
// ---------------------------------------------------------------- ballistic jet from the baked mouth path
// o:{mp,t0,t1,dt,speed,spread,g,aim(tb,k)->{p,T},size(a,k),kind:'oil'|'lit',lit:age at which oil ignites,flame:fire life,life,onLand(k,pos,since,tb)}
OIL.jet=function(fx,s,o){const n=Math.floor((o.t1-o.t0)/o.dt),g=o.g===undefined?9.8:o.g;
  for(let k=0;k<=n;k++){const tb=o.t0+k*o.dt,a0=s-tb;if(a0<0||a0>(o.life||2))continue;const m=o.mp(tb),r3=rnd(k*3+3);
    let v,A=null;if(o.aim){A=o.aim(tb,k);v=A.p.clone().sub(m.p).multiplyScalar(1/A.T);v.y+=.5*g*A.T;if(A.stick&&a0>A.T){if(o.onStick)o.onStick(k,A.p,a0-A.T,tb);continue;}}else{const sp=typeof o.speed==='function'?o.speed(tb,k):o.speed;v=m.d.clone().multiplyScalar(sp*(.9+.2*r3));const sd=(o.spread||.1)*sp;v.x+=(rnd(k*3+1)-.5)*sd*.4;v.y+=(rnd(k*3+2)-.5)*sd;v.z+=(rnd(k*3+4)-.5)*sd;}
    const disc=v.y*v.y+2*g*(m.p.y-.03),al=g>0?(v.y+Math.sqrt(Math.max(0,disc)))/g:99;let a=a0,landed=0;if(a0>al){a=al;landed=a0-al;}
    const p=V(m.p.x+v.x*a,Math.max(.03,m.p.y+v.y*a-.5*g*a*a),m.p.z+v.z*a);
    if(landed>0&&o.onLand)o.onLand(k,p,landed,tb);
    if(o.kind==='oil'){if(landed<=0)OIL.drop(fx,p,o.size?o.size(a0,k):.07,1);else if(landed<.3)fx.p(p,.1+.2*landed,.5*(1-landed/.3),'#2e1d08',TX.soft,false);}
    else{const lit=o.lit||.03,fa=a0-lit;if(landed>.5)continue;
      if(fa<0)OIL.drop(fx,p,o.size?o.size(a0,k):.08,1);
      else{const fl=o.flame||.7,u=clamp(fa/fl,0,1),b=o.size?o.size(a0,k):.12,sz=b*(1+(o.grow||1)*5.5*Math.pow(u,.8)),fade=1-u*u,
          q=V(p.x+(rnd(k*7+1)-.5)*sz*.5*u,p.y+(rnd(k*7+2)-.3)*sz*.45*u+.12*u*u,p.z+(rnd(k*7+3)-.5)*sz*.5*u);
        fx.p(q,sz*1.15,.34*fade,ramp(Math.min(.99,u*1.1+.2),FIRE),TX.soft,true);
        if(u>.22&&k%2===0)fx.p(V(q.x,q.y+sz*.28,q.z),sz*.7,.6*fade,ramp(Math.min(.99,u*1.1+.15),FIRE),TXO.flame,true,Math.sin(k*2.7+a0*9)*.18,1.5);
        if(u<.32)fx.p(p,sz*.4,(1-u*3)*.7,'#fff2b8',TX.soft,true);
        if(u>.4&&k%3===0)fx.p(V(p.x,p.y+.15*u,p.z),sz*1.5,.2*(1-u),'#2c2826',TX.puff,false,k);}}}};
// ---------------------------------------------------------------- readout helpers
OIL.hud=function(rows,meters){let h='';for(const r of rows)h+=`<div><span class="k">${r[0]}</span> ${r[1]}</div>`;for(const m of meters||[])h+=`<div class="k">${m[0]}</div><div class="mt ${m[2]||''}"><div style="width:${Math.round(100*clamp(m[1],0,1))}%"></div></div>`;return h;};
OIL.add=function(move,def){def.move=move;OIL.rigs[move].push(def);return def;};
root.OIL=OIL;
})(window);
