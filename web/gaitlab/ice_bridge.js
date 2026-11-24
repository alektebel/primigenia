'use strict';
// Move 3: ICE BRIDGE (A85). Freezes the river surface ahead into a walkable path that lasts about 20 s, then cracks and melts (A85: rivers, lakes and shallow sea).
// Four takes: breath freezing the surface as you walk, spat slabs that float and fuse, a frost wave racing across, stepping-stone floes.
// The bridge clock runs 1:1 while the creature crosses, then time-lapsed x6 so the whole life of the bridge fits the clip (HUD shows both).
(function(root){
const IC=root.IC,T=IC.T,BB=IC.BB,{V,clamp,sm,lerp,ramp,pls,ease,easeOut,easeIO,back,hash,emit,skel,TAU}=IC;
const WX0=1.6,WX1=6.0,ICE_Y=.045,LAPSE=6,LEN=12500,LIFE=20;
// ---- scene: banks (earth blocks), river bed, translucent water with scrolling ripples
function riverScene(scene){
  const S={scene,fx:IC.FX(scene)};IC.dress(scene,'#1d2b35',{skipGround:true,grass:0,rocks:0,trees:14,seed:7});
  const gm=new T.MeshLambertMaterial({map:IC.TEX.ground}),earth=new T.MeshLambertMaterial({color:'#4a4237'});
  const bank=(x0,x1)=>{const g=new T.Group();const top=new T.Mesh(new T.PlaneGeometry(x1-x0,60),gm);top.rotation.x=-Math.PI/2;top.position.set((x0+x1)/2,0,0);g.add(top);scene.add(g);return g;};
  bank(-40,WX0);bank(WX1,40);
  for(const [x,sg] of [[WX0,1],[WX1,-1]]){const w=new T.Mesh(new T.PlaneGeometry(60,.9),earth);w.rotation.y=Math.PI/2*sg;w.position.set(x,-.45,0);scene.add(w);}
  const bed=new T.Mesh(new T.PlaneGeometry(WX1-WX0,60),new T.MeshLambertMaterial({color:'#1f3a42'}));bed.rotation.x=-Math.PI/2;bed.position.set((WX0+WX1)/2,-.85,0);scene.add(bed);
  S.water=new T.Mesh(new T.PlaneGeometry(WX1-WX0,60),new T.MeshPhongMaterial({color:'#2a6f8c',specular:'#bfe9ff',shininess:90,transparent:true,opacity:.82,depthWrite:false}));S.water.rotation.x=-Math.PI/2;S.water.position.set((WX0+WX1)/2,-.12,0);scene.add(S.water);
  S.rip=[0,1].map(k=>{const t=IC.TEX.water.clone();t.needsUpdate=true;t.repeat.set(3+k,10+k*4);const m=new T.Mesh(new T.PlaneGeometry(WX1-WX0,60),new T.MeshBasicMaterial({map:t,transparent:true,opacity:.7-.25*k,depthWrite:false}));m.rotation.x=-Math.PI/2;m.position.set((WX0+WX1)/2,-.105+k*.002,0);scene.add(m);return t;});
  // grass on the banks only
  const g1=IC.EG.grass(-6,WX0-.1,150,3),g2=IC.EG.grass(WX1+.1,10,120,5),gmat=new T.MeshLambertMaterial({color:'#86a39a'});scene.add(new T.Mesh(g1,gmat));scene.add(new T.Mesh(g2,gmat));
  for(let k=0;k<9;k++){const r=.2+hash(k,1)*.3,m=new T.Mesh(IC.GEO.rock,new T.MeshPhongMaterial({color:'#7d8c96',flatShading:true,shininess:8}));const left=k%2;m.scale.set(r*1.4,r*.7,r);m.position.set(left?WX0-.35-hash(k,2)*3:WX1+.35+hash(k,2)*3,r*.2,(hash(k,3)-.5)*8);m.rotation.y=k;scene.add(m);}
  return S;}
// the bridge clock: 1:1 until the creature is across, then time-lapsed
function clock(tF,tArr){const R0=LIFE-(tArr-tF)/1000,tCr=tArr+(R0-4)*1000/LAPSE,tGone=tArr+R0*1000/LAPSE;return {R:t=>t<tF?LIFE:Math.max(0,LIFE-(Math.min(t,tArr)-tF)/1000-Math.max(0,t-tArr)*LAPSE/1000),tCr,tGone,tF,tArr};}
// ---- the generic bridge piece list: def.objs(t,i) -> {x,y,z,yaw,sx,sy,sz,op,g} ; melt applied here
function makeBridge(def){
  const CK=clock(def.tF,def.tArr),rig={move:'bridge',id:def.id,label:def.label,name:def.name,org:def.org,tag:def.tag,len:LEN,
    ph:[['approach',def.t0,'#5d6d78'],['freezing the water',def.tF-def.t0,'#6fb4d8'],['crossing (solid)',CK.tCr-def.tF,'#a9dcff'],['cracks, melts',CK.tGone-CK.tCr+400,'#e0925c'],['water again',LEN-CK.tGone-400,'#7f8c96']]};
  const pos=(()=>{const w=def.walk;if(w)return IC.integ(t=>(t<w.tC||t>w.tEnd)?0:w.v*sm((t-w.tC)/500)*(1-sm((t-w.tEnd+500)/500)),LEN+100);return null;})();
  const path=t=>{if(def.path)return def.path(t);const w=def.walk,d=pos(t);return {x:w.x0+d,y:0,D:d,amp:ramp(t,w.tC,w.tC+400)*(1-sm((t-w.tEnd+300)/400))};};
  rig.clock=CK;
  rig.build=scene=>{const S=riverScene(scene);S.perf=IC.buildQuad(scene,'cryo');S.objs=[];
    for(let i=0;i<def.n;i++){const g=IC.iceSolid(def.geo(i),def.op||.62,{core:.2});g.visible=false;scene.add(g);const cr=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:IC.TEX.crack,transparent:true,opacity:0,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2}));cr.rotation.x=-Math.PI/2;cr.position.y=.5;g.add(cr);S.objs.push({g,cr});}
    S.pposeAt=t=>{const p=path(t),e=def.perf(t,p),P=IC.perfBase(t,Object.assign({y:p.y,D:p.D,amp:p.amp,frost:.3},e));P.x=p.x+(e.x||0);return P;};return S;};
  const floorY=x=>0;
  rig.cam=(u)=>{const S=rig.inst;const xc=S?path(u).x:1;return {cx:lerp(3.7,xc,.3),cy:.1,span:9.4,v:2.6};};
  rig.frame=(S,u)=>{
    const fx=S.fx;fx.reset();const p=path(u),pp=S.pposeAt(u),psk=skel(pp),R=CK.R(u);
    // creature stands on bank (y 0) or on the ice (ICE_Y) with smooth steps
    const onIce=sm((p.x-WX0+.2)/.35)*(1-sm((p.x-WX1-.05)/.35));pp.y=(pp.y||0)+(def.floorY?def.floorY(p,u):ICE_Y*onIce);
    IC.drawQuad(S.perf,pp);
    S.rip[0].offset.set(u*.00004,-u*.00012);S.rip[1].offset.set(-u*.00003,-u*.00019);
    let alive=0,gone=0;
    S.objs.forEach((o,i)=>{const d=def.objs(u,i,p);if(!d||d.g<=.002){o.g.visible=false;return;}
      const m=hash(i,77),span=CK.tGone-CK.tCr,pm=sm((u-(CK.tCr+span*(.08+.62*m)))/(span*.3)),crk=ramp(u,CK.tCr,CK.tCr+500);
      const k=1-pm;o.g.visible=k>.01;if(!o.g.visible){gone++;return;}alive++;
      o.g.position.set(d.x,d.y+(d.sy||.14)*.5*d.g*(1-.5*pm)-.12*pm,d.z);o.g.rotation.set((d.tilt||0)+(hash(i,5)-.5)*.5*pm,d.yaw||0,(hash(i,6)-.5)*.5*pm);
      o.g.scale.set(d.sx,(d.sy||.14)*Math.max(.001,d.g)*(1-.7*pm)*1,d.sz);IC.iceOpacity(o.g,Math.min(1,d.g*2)*(d.op===undefined?1:d.op)*(1-pm*pm));
      o.cr.position.set(0,.51,0);o.cr.scale.set(.9,.9,1);o.cr.rotation.z=hash(i,8)*6;o.cr.material.opacity=.95*crk*(1-pm);o.cr.visible=crk>.01;
      if(pm>.3&&pm<.9&&!def.noSplash)fx.ring(V(d.x,-.1,d.z),.2+.6*(pm-.3)*2,.5*(1-(pm-.3)/.6),'#dff3ff');});
    // water edge glints, fx of the version
    def.fx(fx,u,{S,p,pp,psk,CK,R});
    // cracking: sparkle along the bridge, then drifting steam and drips while it melts
    if(u>CK.tCr-100&&u<CK.tGone+500)emit(fx,u,{t0:CK.tCr-100,t1:CK.tGone+300,rate:40,seed:131,life:[500,900],origin:tb=>V(lerp(WX0+.2,WX1-.2,hash(Math.round(tb),1)),.06,(hash(Math.round(tb),2)-.5)*1.1),vel:r=>V((r()-.5)*.3,.2+.3*r(),(r()-.5)*.3),drag:1,size:[.04,.1],kind:'spark',col:'#ffffff',op:.9,spin:4});
    if(u>CK.tCr+300&&u<CK.tGone+900)emit(fx,u,{t0:CK.tCr+300,t1:CK.tGone+700,rate:26,seed:132,life:[900,1500],origin:tb=>V(lerp(WX0+.2,WX1-.2,hash(Math.round(tb),3)),.04,(hash(Math.round(tb),4)-.5)*1.2),vel:r=>V((r()-.5)*.2,.15+.12*r(),(r()-.5)*.2),drag:.6,size:[.1,.4],kind:'puff',col:'#e1f1f9',op:.2});
    fx.flush();
    const st=u<def.tF?'<b class="ice">freezing</b>':u<CK.tCr?'solid':u<CK.tGone?'<b class="bad">CRACKING, melting</b>':'<span class="k">water again</span>';
    return {hud:`<div><span class="k">Bridge life</span> <b>${R.toFixed(1)} s</b> / ${LIFE}</div><div class="mt"><div style="width:${100*R/LIFE}%"></div></div><div><span class="k">Clock</span> ${u<CK.tArr?'1x (walking)':'<b class="ice">time-lapse x'+LAPSE+'</b>'}</div><div><span class="k">State</span> ${st}</div>`,
      banner:u>=CK.tCr&&u<CK.tCr+600?'CRACK':'',bannerK:1-(u-CK.tCr)/600};
  };
  IC.rigs.bridge.push(rig);return rig;}
const SLABG=i=>IC.jitterGeo(new T.BoxGeometry(1,1,1,2,1,2),.07,4+i);
const FLOEG=i=>IC.jitterGeo(new T.CylinderGeometry(.5,.56,1,7,1),.07,8+i);
// creature breath helpers
const nose=(S,t)=>skel(S.pposeAt(t));
const WALK=(x0,tC,v,xe)=>({x0,tC,v,tEnd:tC+(xe-x0)/v*1000+700});
// water splash (ring + droplets) at x,z starting at t0
function splash(fx,u,t0,x,z,big){const a=u-t0;if(a<0||a>1100)return;fx.ring(V(x,-.1,z),.12+.55*big*ease(a/700),.75*(1-ease(a/700)),'#e8f7ff');fx.ring(V(x,-.1,z),.08+.3*big*ease(a/500),.5*(1-ease(a/500)),'#ffffff');
  emit(fx,u,{t0,t1:t0+120,rate:140,seed:Math.round(x*100)+5,life:[400,800],origin:tb=>V(x,-.08,z),vel:r=>V((r()-.5)*1.4*big,1.4*big*(.5+r()),(r()-.5)*1.4*big),grav:7,size:[.04,.07],kind:'glow',col:'#cfeeff',op:.9});}
// ================= BR1: breath freezing the surface as you walk ==============================================
const T1={t0:900,tF:4600,tC:1700,v:1.3,xe:7.4};const W1=WALK(.4,T1.tC,T1.v,T1.xe),K1=22;
const fr1=t=>Math.min(WX1+.2,WX0+1.5*Math.max(0,(t-1000)/1000)*1.0);
makeBridge({id:'breath',label:'Breath, walk on',name:'The ice grows ahead of every step',org:'a low steady exhale freezes the surface just ahead of the paws while it keeps walking',
  tag:'The head drops to the water and a low steady breath runs ahead. The surface whitens into crystals that grow into a slab a body-length in front of the paws, a clear jagged front edge advancing while the creature walks onto it. The path then stands, cracks from the weak points (timer low), and melts tile by tile.',
  t0:T1.t0,tF:T1.tF,tArr:W1.tEnd-700,walk:W1,n:K1,geo:i=>SLABG(i),
  perf:(t,p)=>{const bl=ramp(t,900,1100)*(1-sm((t-4000)/400));return {neckA:-.4*bl,neckE:.55*bl,headA:-.25*bl,jaw:.3*bl,crouch:.05*bl,sac:.12+.8*ramp(t,500,900)*(1-.75*ramp(t,900,4000)),glow:.1+.9*ramp(t,500,900)*(1-.5*ramp(t,900,4000))*(1-ramp(t,4000,5000)),pulse:.3*bl*Math.sin(t/60),legFrost:.2+.5*bl,squint:.4*bl};},
  objs:(t,i)=>{const L=(WX1-WX0)/K1,x=WX0+(i+.5)*L,ti=1000+(x-WX0)/1.5*1000,g=ease((t-ti)/650);return {x,y:-.02,z:0,sx:L*1.12,sz:1.55+.1*hash(i,3),sy:.15,g:t<ti?0:g,yaw:(hash(i,4)-.5)*.05};},
  fx:(fx,u,E)=>{const {S,p}=E;
    emit(fx,u,{t0:1000,t1:3950,rate:110,seed:141,life:[600,1000],origin:tb=>nose(S,tb).mouth,vel:r=>{const q=nose(S,2500).axis;return V(q.x*2.6+r()*.5,-1.4+(r()-.5)*.5,(r()-.5)*.8);},drag:1.1,size:[.08,.5],kind:'puff',col:'#d9eef8',op:.36});
    // the freezing front: white crystalline edge and sparkles, plus crystal tips popping along it
    const xf=fr1(u);if(u>1000&&u<4000+1000&&xf<WX1+.15){for(let k=0;k<9;k++){const z=(k-4)*.18+(hash(k,Math.round(u/80))-.5)*.08;fx.spr('spark',V(xf+.05,.0,z),.14+.07*hash(k,3),.9,'#ffffff',u/200+k);}
      emit(fx,u,{t0:1000,t1:4000,rate:90,seed:142,life:[350,650],origin:tb=>V(fr1(tb),.02,(hash(Math.round(tb),1)-.5)*1.5),vel:r=>V(.2*r(),.3+.5*r(),(r()-.5)*.3),grav:1,size:[.04,.09],kind:'spark',col:'#f0fcff',op:.9,spin:5});
      emit(fx,u,{t0:1000,t1:4000,rate:34,seed:143,life:[700,1200],origin:tb=>V(fr1(tb)-.1,.0,(hash(Math.round(tb),2)-.5)*1.3),vel:r=>V(.1,.12+.1*r(),(r()-.5)*.2),drag:.8,size:[.1,.4],kind:'puff',col:'#e4f4fb',op:.2});}
  }});
// ================= BR2: spat slabs that float and fuse =========================================================
const SX=[0,1,2,3,4].map(k=>WX0+.44+.88*k),SR=[900,1350,1800,2250,2700],FLY=520,FUSE=3500,FUSEMS=650;
const W2=WALK(.6,4300,1.65,7.4);
makeBridge({id:'slabs',label:'Spat slabs',name:'Spit, float, fuse',org:'five plates of ice spat onto the water, bobbing, then sliding together and welding',
  tag:'Five head-snaps spit five plates of ice (each unfolds as it flies) onto the water with a splash. They float at slightly different angles and bob; then they drift together, bump, and weld with a flash of white along the seams. It is a stepping bridge in the making: you see every plate. The path then lasts, cracks and melts.',
  t0:800,tF:FUSE+FUSEMS+250,tArr:W2.tEnd-700,walk:W2,n:5,geo:i=>SLABG(i),noSplash:false,
  perf:(t,p)=>{const sn=Math.max(...SR.map(s=>pls(t,s+30,70)*(t>s-420?1:0))),ant=Math.max(...SR.map(s=>t<s&&t>s-380?sm((t-(s-380))/330):0)),rec=Math.max(...SR.map(s=>t>s?pls(t,s+140,200):0));
    const ch=ramp(t,500,900)*(1-sm((t-3000)/500));return {sac:.2+.7*ch*(.65+.35*Math.sin(t/50)*0)+.2*ant,glow:.1+.8*ch+.0,neckA:.45*ant-.2*sn*0,neckE:-.35*ant+.6*sn,headA:.2*ant-.2*rec,jaw:.2*ant+.85*sn,crouch:.25*ant,pitch:.14*ant-.1*rec,x:.0+.1*sn,pulse:ant*.5,squint:ant*.4,legFrost:.2+.4*ch};},
  objs:(t,i)=>{const t0=SR[i],tL=t0+30+FLY;if(t<t0+30)return null;const L=.94,bx=SX[i],lx=bx+(hash(i,1)-.5)*.35,lz=(hash(i,2)-.5)*.7,ya=(hash(i,3)-.5)*.5;
    const mo=skel(IC.perfBase(t0+30,{x:.0,...{}})).mouth;const e=clamp((t-t0-30)/FLY,0,1);
    if(t<tL){const sx=lerp(.9,.94,0),x=lerp(1.0,lx,e),y=lerp(.7,-.02,e)+.9*Math.sin(Math.PI*e)*.9*0+1.0*Math.sin(Math.PI*e),sc=lerp(.2,1,easeOut(e));return {x,y,z:lz*e,sx:L*sc,sz:1.35*sc,sy:.15,g:1,yaw:ya*e+e*3,tilt:Math.sin(e*6)*.4*(1-e)};}
    const a=(t-tL)/1000,bob=-.09*Math.exp(-a*2.2)*Math.cos(a*9)+.012*Math.sin(t/430+i),fu=ease((t-FUSE-i*40)/FUSEMS),ov=back(clamp((t-FUSE-i*40)/FUSEMS,0,1));
    return {x:lerp(lx+.05*Math.sin(t/900+i),bx,ov),y:-.02+bob*(1-fu*.8),z:lerp(lz,0,ease(clamp((t-FUSE-i*40)/FUSEMS,0,1))),sx:L*(1+.04*fu),sz:lerp(1.35,1.55,fu),sy:.15,g:1,yaw:lerp(ya,0,fu),tilt:.05*Math.sin(t/600+i)*(1-fu)};},
  fx:(fx,u,E)=>{const {S}=E;
    SR.forEach((s,k)=>{splash(fx,u,s+30+FLY,lerp(1.0,SX[k]+(hash(k,1)-.5)*.35,1),(hash(k,2)-.5)*.7,1);
      emit(fx,u,{t0:s+20,t1:s+30+FLY,rate:70,seed:150+k,life:[300,600],origin:tb=>{const e=clamp((tb-s-30)/FLY,0,1);return V(lerp(1.0,SX[k]+(hash(k,1)-.5)*.35,e),lerp(.7,-.02,e)+Math.sin(Math.PI*e),(hash(k,2)-.5)*.7*e);},vel:r=>V((r()-.5)*.3,(r()-.5)*.3,(r()-.5)*.3),drag:1.2,size:[.05,.2],kind:'puff',col:'#dff3fb',op:.3});
      emit(fx,u,{t0:s+10,t1:s+120,rate:60,seed:160+k,life:[400,700],origin:tb=>nose(S,tb).mouth,vel:r=>V(1+r(),(r()-.4)*.6,(r()-.5)*.6),drag:1.5,size:[.05,.3],kind:'puff',col:'#d9eef8',op:.4});});
    // fuse flash along the seams
    for(let k=0;k<4;k++){const tt=FUSE+k*40+FUSEMS*.62,a=u-tt;if(a>0&&a<500){const x=WX0+.88*(k+1);for(let j=0;j<6;j++)fx.spr('spark',V(x,.05,(j-2.5)*.28),.3*(1-a/500)+.1,.95*(1-a/500),'#ffffff',j);fx.ring(V(x,.04,0),.15+.5*ease(a/500),.6*(1-a/500),'#f2fdff');}}
  }});
// ================= BR3: frost wave racing across ===============================================================
const WV0=1500,WVS=5.2,K3=26;const W3=WALK(.5,3300,1.7,7.4);
const wvx=t=>WX0+WVS*Math.max(0,(t-WV0)/1000);
makeBridge({id:'wave',label:'Frost wave',name:'Slam, and the river freezes in a rush',org:'a stamp sends a bright crest of frost racing across, freezing a strip behind it',
  tag:'The creature rears, the sac blazes, and it slams its forefeet down. A white crest of frost races across the river faster than a gallop, spraying crystals, and the water freezes behind it in a rush; the sheet settles with a ripple of cracks and a few snap-pops of ice. Fast and dramatic: one beat, a whole bridge. The ice is thinner at the edges.',
  t0:WV0,tF:WV0+Math.round((WX1-WX0)/WVS*1000)+700,tArr:W3.tEnd-700,walk:W3,n:K3,geo:i=>SLABG(i),
  perf:(t,p)=>{const ch=ramp(t,700,1400),sl=pls(t,WV0+30,90),rs=ramp(t,1000,1450)*(1-sm((t-1500)/90));return {sac:.12+.85*ch*(1-sm((t-WV0-200)/600))+.05,glow:.1+.9*ch*(1-ramp(t,WV0+200,2800)),pitch:.28*rs-.16*sl,crouch:.28*ch*(1-sl)+.12*sl,neckA:.4*rs-.3*sl,neckE:.35*sl,headA:.2*rs-.3*sl,jaw:.25*rs+.4*sl,stomp:rs*(1-sm((t-1470)/60)),squint:ch*.5,legFrost:.2+.7*ramp(t,WV0,WV0+500),x:.1*sl-.03*rs,tz:.3*rs};},
  objs:(t,i)=>{const L=(WX1-WX0)/K3,x=WX0+(i+.5)*L,ti=WV0+(x-WX0)/WVS*1000,a=(t-ti)/1000;if(t<ti)return null;const g=ease(a/.28),ov=1+.18*Math.exp(-a*7)*Math.sin(a*40);return {x,y:-.02+.05*Math.exp(-a*9)*Math.sin(a*30),z:0,sx:L*1.12,sz:1.55*(.75+.25*Math.min(1,a*5)),sy:.15*ov,g};},
  fx:(fx,u,E)=>{const {S}=E;
    if(u>=WV0&&u<WV0+500)fx.ring(V(1.0,.02,.2),.15+1.1*ease((u-WV0)/450),.8*(1-ease((u-WV0)/450)),'#e6f9ff');
    const xf=wvx(u);if(u>WV0&&xf<WX1+.2){for(let k=0;k<14;k++){const z=(k-6.5)*.12,h=.08+.14*hash(k,Math.round(u/60));fx.spr('spark',V(xf,h*.5,z),.2+.1*hash(k,3),.95,'#ffffff',u/150+k);fx.spr('puff',V(xf+.05,.12+.15*hash(k,4),z*1.2),.3+.3*hash(k,5),.28,'#e7f5fb',k);}
      emit(fx,u,{t0:WV0,t1:WV0+Math.round((WX1-WX0)/WVS*1000)+100,rate:260,seed:171,life:[400,800],origin:tb=>V(wvx(tb),.05,(hash(Math.round(tb),1)-.5)*1.4),vel:r=>V(1.2*r(),.9+1.4*r(),(r()-.5)*1.4),grav:5,drag:.6,size:[.04,.1],kind:'spark',col:'#f0fcff',op:.95,spin:6});}
    // crackle pops after it settles
    for(let k=0;k<6;k++){const tt=WV0+Math.round((WX1-WX0)/WVS*1000)+120+k*90,a=u-tt;if(a>0&&a<260){fx.spr('spark',V(lerp(WX0+.5,WX1-.5,hash(k,1)),.07,(hash(k,2)-.5)*1),.4*(1-a/260)+.05,.95*(1-a/260),'#ffffff',k);}}
    emit(fx,u,{t0:WV0+100,t1:WV0+1400,rate:70,seed:172,life:[500,800],origin:tb=>nose(S,tb).mouth,vel:r=>V(1+1.5*r(),-.8-.4*r(),(r()-.5)*.9),drag:1.3,size:[.08,.4],kind:'puff',col:'#d9eef8',op:.4});
  }});
// ================= BR4: stepping-stone floes ===================================================================
const FX4=[2.45,3.25,4.05,4.85,5.65],FR=[900,1350,1800,2250,2700],HP=[1.0,2.45,3.25,4.05,4.85,5.65,6.9],HT=[3150,3650,4150,4650,5150,5650];
const hopT=3150,hopD=470,hopP=[.35,1.0,...[]];
function path4(t){// bank -> floes -> bank: hops of 470 ms separated by a 30 ms settle (the floe dips under the paws)
  const xs=[.55,HP[0]+.25,HP[1]+0,HP[2],HP[3],HP[4],HP[5],7.0].slice(0,8);
  const X=[.55,1.12,FX4[0],FX4[1],FX4[2],FX4[3],FX4[4],6.9],TT=[2400,2900,3400,3900,4400,4900,5400];   // hop k departs TT[k]-... 
  let x=X[0],y=0,tuck=0,amp=0,crouch=0,D=0,pitch=0;
  for(let k=0;k<7;k++){const t0=TT[k],d=470;if(t<t0){break;}x=X[k+1];D=k*.9;const e=clamp((t-t0)/d,0,1);if(t<t0+d){x=lerp(X[k],X[k+1],easeIO(e));y=.52*Math.sin(Math.PI*e)*(k===0||k===6?1.15:1);tuck=Math.sin(Math.PI*e)*.9;pitch=-.16*Math.sin(Math.PI*e)+.14*(1-e)*(e<.25?1:0);crouch=.35*Math.exp(-e*12);D=k*.9+e*.9;}else{const a=t-t0-d;crouch=Math.max(crouch,.35*Math.exp(-a/180));}}
  const land=TT.map(t=>t+470);let dip=0;for(const l of land)if(t>=l)dip=Math.max(dip,Math.exp(-(t-l)/330)*Math.cos((t-l)/70));
  return {x,y,tuck,amp:0,crouch,D,pitch,dip};}
makeBridge({id:'floes',label:'Stepping floes',name:'Puff, pop up a floe, hop on',org:'five ice floes pop up one by one; the creature hops across them',
  tag:'Short puffs at the water ahead raise five floes one after another, each rising with a splash and then bobbing. The creature crouches and hops from floe to floe, each landing pressing the floe down and rippling the water. Slower and riskier than a solid path, but needs far less ice: the floes then crack and melt in turn, so the way is only open for a while.',
  t0:800,tF:2850,tArr:5900,path:path4,floorY:(p)=>p.y*0+ (p.x>FX4[0]-.45&&p.x<FX4[4]+.45?.07:(p.x>WX0-.05&&p.x<WX1+.05?.07:0)),n:5,geo:i=>FLOEG(i),op:.7,
  perf:(t,p)=>{const ant=Math.max(...FR.map(s=>t<s&&t>s-360?sm((t-(s-360))/300):0)),pf=Math.max(...FR.map(s=>pls(t,s+40,80)));const ch=ramp(t,450,900)*(1-sm((t-3000)/500));return {neckA:-.35*(ant+pf*.4),neckE:.45*pf-.2*ant,headA:-.2*pf,jaw:.5*pf,crouch:(p.crouch||0)+.1*ant,pitch:(p.pitch||0)+(t<2400?.08*ant:0),tuck:p.tuck,sac:.2+.7*ch*(1-.3*ramp(t,900,2700)),glow:.1+.9*ch*(1-ramp(t,2800,3400)),pulse:.4*pf,legFrost:.2+.5*ch,squint:.3*ant,tw:-.3*(p.tuck||0),bob:0};},
  objs:(t,i,p)=>{const t0=FR[i];if(t<t0)return null;const a=(t-t0)/1000,g=back(clamp(a/.55,0,1)),x=FX4[i],bob=.014*Math.sin(t/420+i*1.7);
    let dip=0;const lt=[3400,3900,4400,4900,5400][i-0]; // the floe the creature lands on: hops k=1..5 land on floe k-1 ( TT[k]+470 )
    const landT=[2900,3400,3900,4400,4900][i]+470;if(t>=landT&&t<landT+1200)dip=.07*Math.exp(-(t-landT)/260)*Math.cos((t-landT)/62);
    const tm=(t>=[3400,3900,4400,4900,5400][i]&&t<[3400,3900,4400,4900,5400][i]+470)?.05:0;
    return {x,y:-.02+bob-dip-tm*.5,z:.04*Math.sin(t/900+i),sx:.95*(.9+.1*hash(i,1)),sz:.95*(.9+.12*hash(i,2)),sy:.13,g,yaw:hash(i,3)*3,tilt:.05*Math.sin(t/500+i)+.06*dip*8};},
  fx:(fx,u,E)=>{const {S,p}=E;
    FR.forEach((s,k)=>{splash(fx,u,s+250,FX4[k],0,1.2);emit(fx,u,{t0:s,t1:s+150,rate:100,seed:180+k,life:[500,900],origin:tb=>nose(S,tb).mouth,vel:r=>V(2.2+r(),-.5-.4*r(),(r()-.5)*.7),drag:1.2,size:[.06,.35],kind:'puff',col:'#d9eef8',op:.45});
      const a=u-s-120;if(a>0&&a<500)fx.spr('spark',V(FX4[k],.1,0),.5*(1-a/500)+.1,.9*(1-a/500),'#ffffff',k);
      const lt=[2900,3400,3900,4400,4900][k]+470;splash(fx,u,lt,FX4[k],0,.5);});
    // ripples at each landing and take-off on the bank
    splash(fx,u,2900+470,1.35,0,.2);
  }});
})(window);
