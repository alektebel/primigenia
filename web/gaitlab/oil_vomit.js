'use strict';
// Tab 1: OIL VOMIT (A89 stomach oil gland, fulmar style). Four takes. Shared helpers for all three tabs live in OIL.H.
// Performer "Oiler" (left, faces +x) with an amber stomach gland under the belly; prey "Pip" (right, faces -x).
(function(root){
const OIL=root.OIL,BB=OIL.BB,T=OIL.T,{V,clamp,sm,fr,rnd,kf,eo,s2,win,TAU}=OIL,TX=BB.sig.TX;
const H=OIL.H={};
// performer base pose: breathing, tail sway, ears (idle of the signature rigs)
H.base=s=>{const P=Object.assign({},BB.sig.idleP(s));P.tx=u=>[0,.3*u*Math.sin(s*2.1-u*3)];return P;};
// throat bulges travelling base -> head at the gulp times; returns the neck-radius multiplier fn and the strongest bulge amount
H.gulp=(s,times,dur,amp)=>{dur=dur||.32;amp=amp||.6;let best=0,pos=0;for(const g of times){const u=(s-g)/dur;if(u>0&&u<1){const a=Math.sin(Math.PI*Math.min(1,u*1.1))*amp;if(a>best){best=a;pos=u;}}}
  return {amt:best,pos,nrf:best>0?(f=>1+best*Math.exp(-Math.pow((f-.12-.8*pos)/.13,2))):null};};
H.neckGlow=(St,v)=>{St.neckMat.emissive.setRGB(.55*v,.3*v,.04*v);};
// droplet burst on a body or the ground: a = seconds since impact
H.splat=(fx,pos,a,n,seed,o)=>{o=o||{};if(a<0||a>.7)return;const sp=o.speed||1.6,up=o.up||1;for(let i=0;i<n;i++){const az=rnd(seed+i)*TAU,el=.2+rnd(seed+i*3)*1.1,v=sp*(.4+.6*rnd(seed+i*7));
    const p=V(pos.x+Math.cos(az)*Math.cos(el)*v*a*(o.dir?o.dir.x*.3+.7:1),pos.y+(Math.sin(el)*v*up*a-4.9*a*a),pos.z+Math.sin(az)*Math.cos(el)*v*a*.8);if(p.y>.02)OIL.drop(fx,p,.03+.025*rnd(seed+i*5),1-a/.7);}
  if(a<.2)fx.p(pos,.3+.5*a,.75*(1-a/.2),'#2e1d08',BB.sig.TX.soft,false);};
// prey slip walk: feet skate out, hips sway, rare stumble. spd 0..1 of full speed, ph gait phase, k size
H.slip=(s,ph,spd,k,amt)=>{const f=[0,1,2,3].map(i=>[amt*.09*k*Math.sin(ph*.5+i*1.7)*(spd>.05?1:.2),0,(i%2?1:-1)*amt*.05*k*(.6+.4*Math.sin(ph*.35+i))]);return {foot:f,roll:amt*.06*Math.sin(ph*.5),yaw:amt*.12*Math.sin(ph*.45)};};
// the performer's oil reserve meter (fat), shared by all vomit takes
H.oilMeter=(v)=>['Stomach oil (fat)',v,'oil'];
// ---------------------------------------------------------------- scene builder
H.make=function(def){return scene=>{const St=OIL.stage(scene,def.stage);St.c=OIL.performer(scene,def.x0===undefined?0:def.x0,def.perfOpt||{});St.d=OIL.prey(scene,def.px,def.preyOpt||{});
  def.h=St.c.h;St.neckMat=St.c.mats.find(m=>m.tube).m;St.mp=OIL.bake(St.c,s=>def.perf(s),def.len);St.pd=[];if(def.init)def.init(St,scene);return St;};};
function poseBoth(St,def,s,A){const P=def.perf(s);St.c.pose(P);St.d.set(s,A);return P;}
H.poseBoth=poseBoth;
const SOAK_T=8;
// ================================================================ 1A  projectile spew
OIL.add('vomit',(()=>{
  const px=3.0,hitT=2.32,len=5.8,aimC=V(px-.1,.34,0);
  const walkX=s=>kf(s,[[0,1.55],[1.15,0],[3.4,0],[4.9,.8]]);
  const perf=s=>{const P=H.base(s),g=H.gulp(s,[1.05,1.5],.3,.55);
    P.na=kf(s,[[0,0],[.9,0],[1.4,.4],[1.78,.7],[1.9,.45],[2.0,-.5],[2.12,-.55],[2.6,-.3],[3.3,0]]);P.nc=kf(s,[[1.3,0],[1.78,.45],[2.0,-.2],[2.6,0]]);
    P.hp=kf(s,[[1.4,0],[1.8,.55],[2.0,-.1],[2.15,-.25],[2.7,0]])+.04*Math.sin(s*2.4);P.pitch=kf(s,[[1.2,0],[1.8,.1],[2.0,-.08],[2.6,0]]);P.br=P.br+kf(s,[[1.0,0],[1.3,.07],[1.8,.11],[2.0,-.14],[2.4,-.05],[3,0]]);
    P.sq=kf(s,[[1.5,0],[1.9,.06],[2.05,-.02],[2.6,0]]);P.x=kf(s,[[1.9,0],[2.08,.09],[2.7,.06],[3.5,0]]);P.y=def.h+kf(s,[[1.5,0],[1.9,-.05],[2.1,.0],[3,0]]);
    P.jaw=kf(s,[[0,0],[1.0,.1],[1.4,.2],[1.95,.5],[2.05,.85],[2.3,.8],[2.5,.15],[2.9,0]]);P.ta=kf(s,[[1.5,0],[2.0,.35],[2.4,.1],[3,0]]);P.nrf=g.nrf;return P;};
  const def={id:'a',label:'1A',name:'Projectile spew',org:'Fulmar chick: one hard jet at close range',len,px,perf,stage:{},
    tag:'Two throat gulps (a bulge runs up the neck, the belly gland glows), the head draws back, then the neck snaps forward and one hard jet hits the chest. The target flinches, shakes, goes dark and glossy, and walks off slowed and slipping.',
    ph:[['gulp',1.5,'#8a6a2a'],['heave',.55,'#c08a2a'],['jet',.4,'#d8b04a'],['soaked: slowed, slipping',3.35,'#6a5a2e']],cam:{cx:1.75,cy:.6,span:5.1,v:2},az:0};
  def.build=H.make(def);
  def.cam=s=>def.cam0;def.cam0={cx:1.75,cy:.6,span:5.1,v:2};
  def.cam=()=>def.cam0;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,[1.05,1.5],.3,.55);
    const dx=walkX(s),spd=Math.abs(walkX(s+.02)-walkX(s-.02))/.04,soak=sm((s-hitT)/.5),since=s-hitT,slowK=since<0?1:1-.55*sm(since/.4)*(1-sm((since-5.0)/1));
    const ph=kf(s,[[0,0],[1.15,1.55*13],[3.4,1.55*13],[4.9,1.55*13+.8*13*.45]]);
    const perfP=perf(s);c.pose(perfP);c.glow(kf(s,[[.6,0],[1.1,.65],[1.9,1],[2.25,.6],[2.9,0]]));H.neckGlow(St,g.amt*.9+.25*kf(s,[[1.6,0],[1.95,1],[2.2,0]]));
    const hz=since>0?Math.exp(-since*5):0,wob=since>0?Math.exp(-since*3.2)*Math.sin(since*21):0,st=H.slip(s,ph,spd,1,soak);
    const A={dx,gait:{ph,amp:.13*Math.min(1,spd/.9)*.9,lift:.07*Math.min(1,spd/.9)},follow:1,yaw:(s>3.3?kf(s,[[3.3,0],[3.9,Math.PI*.85],[4.1,Math.PI*.85]]):0)+.35*wob+(s>3.4?st.yaw:0),
      sq:.2*hz,na:s<hitT?kf(s,[[1.15,0],[1.5,.25],[hitT,.25]])-.0:-.7*hz+.3*wob,hp:.5*hz,jaw:.6*hz,ear:s<1.5?0:kf(s,[[1.5,0],[1.9,.9]])*(since<0?1:.0)+(since>=0?1.4:0),pitch:.25*hz,ta:since>0?.9*sm(since/.1)*(1-sm((since-2)/1)):0,
      foot:soak>.3?st.foot:undefined,roll:soak>.3?st.roll:0,dy:s>4.2&&s<4.6?-.05*Math.sin((s-4.2)/.4*Math.PI):0};
    Object.assign(A,OIL.soakTint(soak));if(!A.foot)delete A.foot;d.set(s,A);
    OIL.wet(fx,s,d,soak*(1-.4*sm((since-5)/1)),1);
    // the jet: 0.28 s of oil, fired from the baked mouth to the chest
    OIL.jet(fx,s,{mp:St.mp,t0:2.0,t1:2.3,dt:.005,kind:'oil',life:.7,size:a=>.1,aim:(tb,k)=>({p:aimC.clone().add(V((rnd(k)-.5)*.1,(rnd(k+9)-.5)*.14,(rnd(k+4)-.5)*.2)),T:.27+.03*rnd(k+2),stick:true}),onStick:(k,p,a,tb)=>{if(k%3===0)H.splat(fx,p,a,2,k,{speed:1.2});}});
    H.splat(fx,aimC,s-hitT,9,3,{speed:2});if(since>0&&since<.5)fx.p(aimC,.4+.5*since,.55*(1-since/.5),'#2e1d08',BB.sig.TX.soft,false);
    // drool strand, then the puddle under the target as it drips
    OIL.drip(fx,s,()=>c.mouth(.98),4,s>2.4?.8*(1-sm((s-3.6)/.8)):0,.9);
    if(!St.pd[0])St.pd[0]=OIL.Puddle(St.scene,1);St.pd[0].set(px-.1+dx*.3,0,.34*sm((since-.5)/2.5)+.01,.26*sm((since-.5)/2.5)+.01,{a:soak*.9,t:s});
    const left=since<0?SOAK_T:Math.max(0,SOAK_T-since),spdP=Math.round(100*(since<0?1:slowK));
    return {hud:OIL.hud([['Target speed','<b>'+spdP+'%</b>'+(spdP<100?' <span class="oil">slowed</span>':'')],['Soaked',since<0?'<b>-</b>':'<b class="oil">'+left.toFixed(1)+' s</b>'],['Damage',since<0?'-':'<b class="bad">-6 HP</b>']],[['Soak',soak,'soak'],H.oilMeter(1-.18*sm((s-2.0)/.3))]),
      banner:since>.1&&since<1.6?'SOAKED':'',bannerK:since>1?1-(since-1)/.6:sm(since/.15)};};
  return def;})());
// ================================================================ 1B  gurgling multi-gulp spray
OIL.add('vomit',(()=>{
  const px=3.05,len=6.6,pulses=[[1.95,2.2,.35],[3.0,3.3,.65],[4.0,4.55,1]],gulps=[.85,1.15,2.5,3.5];
  const perf=s=>{const P=H.base(s),g=H.gulp(s,gulps,.28,.5);
    const pul=pulses.reduce((a,p)=>Math.max(a,win(s,p[0],p[1],.06)),0);
    P.na=kf(s,[[0,0],[.8,0],[1.3,.55],[1.85,.7],[2.0,-.35],[2.3,.2],[2.55,.55],[2.95,.6],[3.05,-.4],[3.4,.35],[3.7,.6],[3.95,.65],[4.1,-.5],[4.5,-.35],[5.0,.05],[5.6,0]]);
    P.nc=kf(s,[[1.2,0],[1.85,.4],[2.0,-.1],[3.0,.4],[3.1,-.1],[3.9,.45],[4.1,-.2],[5,0]]);P.hp=kf(s,[[1.4,0],[1.85,.5],[2.0,-.2],[2.9,.5],[3.1,-.2],[3.9,.55],[4.1,-.25],[5,0]])+.05*Math.sin(s*2.4);
    P.ny=.28*Math.sin((s-3.9)*3.6)*win(s,3.95,4.6,.1)+.12*Math.sin(s*14)*pul;P.br=P.br+.1*Math.sin(s*9)*kf(s,[[.7,0],[1,1],[1.9,1],[2.0,0],[2.6,0],[2.8,1],[3.9,1],[4.1,0]]);
    P.pitch=kf(s,[[1.8,0],[2.0,-.06],[2.3,0],[2.9,.08],[3.1,-.08],[3.4,0],[3.9,.1],[4.1,-.1],[4.8,0]]);P.sq=pul*.05+kf(s,[[3.9,0],[4.0,.07],[4.5,0]]);
    P.jaw=kf(s,[[0,0],[.85,.15],[1.9,.4],[2.05,.8],[2.2,.7],[2.4,.2],[2.9,.45],[3.05,.9],[3.3,.8],[3.5,.25],[3.9,.5],[4.0,1],[4.55,.9],[4.9,.1],[5.4,0]]);
    P.x=kf(s,[[1.9,0],[2.0,.06],[2.4,0],[3.0,.1],[3.5,0],[4.0,.14],[4.6,.08],[5.4,0]]);P.nrf=g.nrf;P.ta=.3*pul;return P;};
  const aimAt=(tb,k)=>{const big=tb>3.9?1:tb>2.9?.65:.35,r=rnd(k*5+Math.round(tb*10));
    if(r>.78)return {p:V(px+.6+r*.5,.02,(rnd(k)-.5)*.5),T:.55,stick:false};
    return {p:V(px-.1+(rnd(k+1)-.5)*.25*big,.3+(rnd(k+2)-.5)*.34*big,(rnd(k+3)-.5)*.5*big),T:.3+.06*rnd(k+7),stick:true};};
  const def={id:'b',label:'1B',name:'Gurgling multi-gulp spray',org:'Fulmar chick: rapid retching pulses, each wider than the last',len,px,perf,stage:{},
    tag:'Three retch pulses, each preceded by a quick gulp that runs up the neck; the spray widens and the target is soaked in three steps (33, 66, 100 %). Some droplets overshoot and speckle the ground behind it.',
    ph:[['gulp, gulp',1.8,'#8a6a2a'],['spray 1',.55,'#d8b04a'],['spray 2',1.1,'#d8b04a'],['spray 3',.9,'#e8c060'],['soaked',2.25,'#6a5a2e']],cam:{cx:1.8,cy:.6,span:5.2,v:2},az:0};
  def.build=H.make(def);def.cam=()=>def.cam0;def.cam0=def.cam;
  def.cam0={cx:1.8,cy:.6,span:5.2,v:2};
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,gulps,.28,.5);
    const hits=[2.25,3.35,4.5],soak=clamp(hits.reduce((a,h)=>a+.34*sm((s-h)/.35),0),0,1)*.98+.0,since=s-hits[0],last=s-hits[2];
    const dx=kf(s,[[0,1.6],[1.0,0],[4.7,0],[6.2,.7]]),spd=Math.abs((kf(s+.02,[[0,1.6],[1.0,0],[4.7,0],[6.2,.7]])-kf(s-.02,[[0,1.6],[1.0,0],[4.7,0],[6.2,.7]]))/.04);
    const ph=kf(s,[[0,0],[1,1.6*13],[4.7,1.6*13],[6.2,1.6*13+.7*13*.5]]),st=H.slip(s,ph,spd,1,soak);
    const fl=hits.reduce((a,h)=>a+(s>h?Math.exp(-(s-h)*6)*Math.sin((s-h)*24):0),0),fh=hits.reduce((a,h)=>a+(s>h?Math.exp(-(s-h)*6):0),0);
    c.pose(perf(s));c.glow(kf(s,[[.5,0],[1.0,.7],[1.9,1],[2.4,.7],[3.0,1],[3.6,.7],[4,1],[4.7,.4],[5.4,0]]));H.neckGlow(St,g.amt*.9+.25*win(s,1.9,4.6,.4));
    const A={dx,gait:{ph,amp:.12*Math.min(1,spd/.7),lift:.06*Math.min(1,spd/.7)},follow:1,yaw:.4*fl+(s>5.2?kf(s,[[5.2,0],[5.7,Math.PI*.9]]):0)+(s>5.2?st.yaw:0),sq:.16*Math.min(1,fh),na:-.45*Math.min(1,fh)+.2*fl,hp:.4*Math.min(1,fh),jaw:.5*Math.min(1,fh),ear:s>1.9?1.1:0,pitch:.18*Math.min(1,fh),ta:s>2.2?.8:0,
      foot:soak>.3?st.foot:undefined,roll:soak>.3?st.roll:0};Object.assign(A,OIL.soakTint(soak));if(!A.foot)delete A.foot;d.set(s,A);
    OIL.wet(fx,s,d,soak*(1-.4*sm((s-5.8)/.8)),2);
    pulses.forEach((p,pi)=>{OIL.jet(fx,s,{mp:St.mp,t0:p[0],t1:p[1],dt:.006,kind:'oil',life:.9,size:()=>.09+.015*pi,aim:aimAt,onStick:(k,pt,a)=>{if(k%4===0)H.splat(fx,pt,a,2,k+pi*50,{speed:1.1});}});H.splat(fx,V(px-.1,.34,0),s-(p[0]+.3),5+pi*3,pi*7+1,{speed:1.6});});
    OIL.drip(fx,s,()=>c.mouth(.98),6,s>2.0&&s<5.2?.9:.0,1.1);OIL.drip(fx,s,()=>c.mouth(.9),8,s>3.2&&s<5.2?.8:0,.8);
    const hp=Array.from({length:3},(_,i)=>(i));if(!St.pd[0]){St.pd[0]=OIL.Puddle(scene0(St),2);St.pd[1]=OIL.Puddle(scene0(St),3);}
    St.pd[0].set(px+.95,.1,.22*sm((s-2.6)/.4)+.2*sm((s-3.9)/.5)+.01,.14*sm((s-2.6)/.4)+.1*sm((s-3.9)/.5)+.01,{a:.85*sm((s-2.5)/.3),t:s});
    St.pd[1].set(px+.02,0,.4*sm((s-4.6)/1.6)+.01,.3*sm((s-4.6)/1.6)+.01,{a:.9*sm((s-4.5)/.3),t:s});
    const left=s<hits[0]?SOAK_T:Math.max(0,SOAK_T-(s-hits[0])-0),spdP=Math.round(100*(1-.55*sm(soak/.8)*(1-sm((s-6)/.8))));
    return {hud:OIL.hud([['Target speed','<b>'+spdP+'%</b>'+(spdP<100?' <span class="oil">slowed</span>':'')],['Soaked',s<hits[0]?'<b>-</b>':'<b class="oil">'+left.toFixed(1)+' s</b>'],['Oil spent','<b>'+Math.round(22*clamp((s-1.9)/2.7,0,1))+'%</b> of fat']],[['Soak',soak,'soak'],H.oilMeter(1-.22*clamp((s-1.9)/2.7,0,1))]),
      banner:last>.05&&last<1.6?'SOAKED':'',bannerK:last>1?1-(last-1)/.6:sm(last/.15)};};
  return def;})());
function scene0(St){return St.scene;}
// ================================================================ 1C  lobbed glob (miss -> puddle)
OIL.add('vomit',(()=>{
  const px=3.1,len=6.6,tL=2.18,flight=.78,land=V(px-.15,0,0);
  const perf=s=>{const P=H.base(s),g=H.gulp(s,[.95,1.3],.3,.55);
    P.na=kf(s,[[0,0],[.8,0],[1.3,.5],[1.75,.85],[1.95,.95],[2.1,.85],[2.2,.5],[2.6,.2],[3.2,0]]);P.nc=kf(s,[[1.2,0],[1.8,.55],[2.1,.2],[2.6,0]]);
    P.hp=kf(s,[[1.3,0],[1.8,.7],[2.1,.8],[2.2,.0],[2.7,0]])+.04*Math.sin(s*2.4);P.pitch=kf(s,[[1.2,0],[1.9,.16],[2.1,.16],[2.25,-.05],[2.7,0]]);P.sq=kf(s,[[1.5,0],[1.95,.07],[2.2,-.02],[2.6,0]]);
    P.br=P.br+kf(s,[[.9,0],[1.3,.08],[1.8,.1],[2.1,-.1],[2.7,0]]);P.jaw=kf(s,[[0,0],[.9,.1],[1.5,.35],[1.9,.65],[2.15,.9],[2.3,.5],[2.7,0]]);P.x=kf(s,[[1.9,0],[2.15,.05],[2.8,0]]);P.ta=kf(s,[[1.7,0],[2.2,.5],[2.8,0]]);P.nrf=g.nrf;return P;};
  const def={id:'c',label:'1C',name:'Lobbed glob that splatters',org:'Long range: one fat glob on a high arc, a dodged miss',len,px,perf,stage:{},
    tag:'The head tosses up, a glossy glob swells in the mouth and is lobbed in a high arc. The target sees it and hops aside. The glob splatters on the ground and leaves an oil puddle (slippery); later the target steps in its edge, skids, and is only partly soaked.',
    ph:[['gulp, swell',1.9,'#8a6a2a'],['toss',.3,'#d8b04a'],['glob flight',.75,'#c89a3a'],['dodge, splat, puddle',1.5,'#6a5a2e'],['skid in puddle',2.1,'#7a6a3e']],cam:{cx:1.75,cy:.8,span:5.4,v:2.5},az:0};
  def.build=scene=>{const St=H.make(def)(scene);const m=new T.MeshPhongMaterial({color:'#4a2f0a',specular:'#fff4d0',shininess:140,emissive:'#241402',transparent:true,opacity:.96});St.glob=new T.Mesh(new T.SphereGeometry(1,16,12),m);St.glob.visible=false;scene.add(St.glob);return St;};
  def.cam=()=>def.cam0;def.cam0={cx:1.75,cy:.8,span:5.4,v:2.5};
  const dodge=s=>kf(s,[[0,1.6],[1.0,0],[2.0,0],[2.12,0],[2.4,.55],[2.6,.55],[3.3,.55],[4.4,.1],[5.0,-.05],[5.3,-.25],[5.9,-.5],[6.6,-.65]]);
  const dodgeZ=s=>kf(s,[[2.0,0],[2.15,0],[2.45,-.5],[3.0,-.55],[3.9,-.4],[4.6,0],[5.6,0]]);
  const hop=s=>Math.abs(Math.sin(clamp((s-2.1)/.5,0,1)*Math.PI))*.22;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,[.95,1.3],.3,.55);c.pose(perf(s));
    c.glow(kf(s,[[.5,0],[1.0,.7],[1.9,1],[2.3,.4],[2.9,0]]));H.neckGlow(St,g.amt*.9+.3*win(s,1.4,2.15,.2));
    const dd=dodge(s),spd=Math.abs(dodge(s+.02)-dodge(s-.02))/.04,ph=kf(s,[[0,0],[1,1.6*13],[2.0,1.6*13],[3.3,1.6*13+.55*13*1.2],[6.6,1.6*13+3]]);
    // prey: walks in, sees the glob (ears up, head tracks), hops aside, watches the puddle, then steps into its edge and skids
    const inPud=win(s,4.5,5.8,.3),sk=inPud,st=H.slip(s,ph,spd,1,.9*sk);
    const tl=s-tL-flight,part=sm((s-4.9)/.4)*.45;
    const A={dx:dd,dz:dodgeZ(s),dy:hop(s),gait:{ph:ph*(s<2.3?1:1),amp:.13*Math.min(1,spd/.9)*.9,lift:.07*Math.min(1,spd/.9)},follow:1,yaw:kf(s,[[2.1,0],[2.4,.7],[3.3,.6],[4.4,.1],[5.1,0],[5.8,-.4],[6.1,Math.PI*.85]])+.12*Math.sin(s*5)*(s>1.2&&s<2.1?1:0)*0+st.yaw,
      na:kf(s,[[1.2,0],[1.7,.3],[2.2,.5],[2.4,.1],[3.0,.1]]),hp:s>1.6&&s<2.4?kf(s,[[1.6,0],[2.0,.5],[2.4,.3]]):.0,ear:s>1.6?1.1:0,ta:s>2.1?.7:0,sq:.15*Math.exp(-Math.max(0,s-2.55)*8)*(s>2.55?1:0)+.15*s2(s,2.1,2.15)*(1-s2(s,2.22,2.3)),pitch:s>5.0&&s<5.5?.2*Math.sin((s-5.0)/.5*Math.PI):0,
      foot:sk>.2?st.foot:undefined,roll:sk>.2?st.roll+(s>5.0&&s<5.6?.5*Math.sin((s-5)/.6*Math.PI):0):0};
    Object.assign(A,OIL.soakTint(part));if(!A.foot)delete A.foot;d.set(s,A);OIL.wet(fx,s,d,part*(1-.3*sm((s-6.2)/.4)),3);
    // the glob: swells in the mouth, tossed, wobbles in flight, lands at the target's old spot
    const gl=St.glob,sw=sm((s-1.1)/.9),mouth=c.mouth(1.05),u=(s-tL)/flight;
    if(s<tL){const sz=.015+.075*sw;gl.visible=sw>.03;gl.position.copy(mouth);gl.position.y-=.02;gl.scale.set(sz*(1+.1*Math.sin(s*30)),sz*(1-.08*Math.sin(s*30)),sz);}
    else if(u<1){const m0=St.mp(tL).p,p=m0.clone().lerp(land.clone().setY(.05),u);p.y=m0.y+(.05-m0.y)*u+4*u*(1-u)*1.0;gl.visible=true;gl.position.copy(p);const vy=(4*(1-2*u)+(.05-m0.y)),vx=(land.x-m0.x),vl=Math.hypot(vx,vy),st2=1+.35*Math.min(1,vl/2.5);
      gl.rotation.set(0,0,Math.atan2(vy,vx));gl.scale.set(.09*st2*(1+.08*Math.sin(s*40)),.09/Math.sqrt(st2)*(1-.08*Math.sin(s*40)),.09/Math.sqrt(st2));
      for(let i=1;i<5;i++){const uu=Math.max(0,u-.03*i),q=m0.clone().lerp(land.clone().setY(.05),uu);q.y=m0.y+(.05-m0.y)*uu+4*uu*(1-uu)*1.0;OIL.drop(fx,q.add(V(0,-.02*i,.02*Math.sin(i*3+s*10))),.05-.006*i,1-.2*i);}}
    else gl.visible=false;
    // splat: ring of droplets, a splash crown, strings, and the puddle
    const sp=s-(tL+flight);H.splat(fx,V(land.x,.04,0),sp,26,11,{speed:3.0,up:1.5});
    if(sp>0&&sp<.5){const cr=eo(sp/.5);for(let i=0;i<9;i++){const az=i*TAU/9;OIL.drop(fx,V(land.x+Math.cos(az)*.32*cr,.05+.26*Math.sin(Math.PI*Math.min(1,sp/.45))*(1-.3*cr),land.z+Math.sin(az)*.25*cr),.07*(1-.5*cr),1-sp/.55,1.2);}}
    if(!St.pd[0])St.pd[0]=OIL.Puddle(St.scene,1);const pg=sm(sp/.55)*.55+.5*sm((sp-.6)/2.5);St.pd[0].set(land.x,0,.55*pg,.42*pg,{a:sm(sp/.12)*.95,t:s});
    OIL.drip(fx,s,()=>c.mouth(.98),4,s>2.1&&s<3.6?.9:0,1.1);
    const inP=since(s),slow=s<2.5?0:s>6.2?0:kf(s,[[4.5,0],[5.0,1],[5.8,1],[6.2,0]]);
    const spdP=100-Math.round(60*slow);
    return {hud:OIL.hud([['Result','<b>'+(s<tL+flight?'in flight':s<4.9?'MISS: puddle':'steps in the puddle')+'</b>'],['Target speed','<b>'+spdP+'%</b>'+(spdP<100?' <span class="oil">slipping</span>':'')],['Soaked',part>.05?'<b class="oil">partial</b>':'<b>no</b>']],[['Puddle size',pg,'soak'],H.oilMeter(1-.24*sm((s-2.15)/.2))]),
      banner:sp>.05&&sp<1.5?'MISS: PUDDLE':'',bannerK:sp>1?1-(sp-1)/.5:sm(sp/.15)};};
  function since(s){return s;}
  return def;})());
// ================================================================ 1D  sweeping head-swing paints a line
OIL.add('vomit',(()=>{
  const px=3.7,len=6.8,t0=1.8,t1=3.2;
  const path=u=>({x:1.25+u*2.05,z:.3*Math.sin(u*7.5+.4)*(1-.25*u)});
  const swp=s=>clamp((s-t0)/(t1-t0),0,1);
  const perf=s=>{const P=H.base(s),g=H.gulp(s,[.9,1.2],.28,.5),u=swp(s),p=path(u),act=win(s,t0-.08,t1+.12,.1);
    P.na=kf(s,[[0,0],[.8,0],[1.3,.4],[1.6,.5],[1.8,-.75],[2.8,-.8],[3.3,-.45],[3.9,-.1],[4.6,0]]);P.nc=kf(s,[[1.3,0],[1.6,.3],[1.85,-.2],[3.3,-.1],[4,0]]);P.hp=kf(s,[[1.2,0],[1.65,.5],[1.85,-.55],[3.2,-.4],[3.8,0]])+.04*Math.sin(s*2.4);
    P.ny=act*(p.z*1.7)+kf(s,[[1.5,0],[1.75,-.12]])*(s<t0?1:0);P.cyaw=act*p.z*.25;P.yaw=act*p.z*.15;P.sq=kf(s,[[1.5,0],[1.8,.08],[3.2,.05],[3.8,0]]);
    P.x=kf(s,[[1.7,0],[2.0,.12],[3.2,.2],[3.9,.08],[4.6,0]]);P.br=P.br+kf(s,[[.9,0],[1.3,.08],[1.7,.1],[1.9,-.12],[3.2,-.1],[3.9,0]]);P.jaw=kf(s,[[0,0],[.9,.1],[1.5,.35],[1.8,.7],[3.3,.65],[3.5,.1],[3.9,0]]);P.ta=kf(s,[[1.6,0],[2.0,.3],[3.3,.2],[4,0]]);P.nrf=g.nrf;return P;};
  const aimAt=(tb,k)=>{const u=swp(tb+.05*0),p=path(clamp(u+(rnd(k)-.5)*.05,0,1));return {p:V(p.x+(rnd(k+2)-.5)*.1,.03,p.z+(rnd(k+4)-.5)*.08),T:.2+.05*u*2+.1*u,stick:false};};
  const def={id:'d',label:'1D',name:'Sweeping head-swing paints a line',org:'Spray while the head sweeps: a line of oil toward the target',len,px,perf,stage:{},
    tag:'The head drops low and swings from near to far while spraying, so a wavy line of oil is painted on the ground out toward the target. It looks like a hose; the line is the fuse for the ignition tab, and the target that steps on it skids.',
    ph:[['gulp',1.7,'#8a6a2a'],['sweep',1.5,'#d8b04a'],['painted line',1.4,'#7a6a3e'],['target steps on it',2.2,'#6a5a2e']],cam:{cx:2.4,cy:.5,span:5.6,v:2},az:0};
  def.build=H.make(def);def.cam0={cx:2.4,cy:.5,span:5.6,v:2};def.cam=()=>def.cam0;
  def.init=(St)=>{St.line=OIL.Line(St.scene,11,path,.34,40);};
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,[.9,1.2],.28,.5);c.pose(perf(s));c.glow(kf(s,[[.5,0],[1.0,.7],[1.8,1],[3.0,.8],[3.6,0]]));H.neckGlow(St,g.amt*.9+.25*win(s,1.8,3.3,.2));
    const lu=swp(s-.22);St.line.set(lu,null,null,s);
    OIL.jet(fx,s,{mp:St.mp,t0:t0,t1:t1,dt:.007,kind:'oil',life:.8,size:()=>.09,aim:aimAt,onLand:()=>{}});
    // prey wanders in, stops, steps on the end of the line, skids, slows
    const dxk=[[0,1.6],[1.4,.05],[4.4,.05],[4.9,-.28],[5.5,-.34],[6.8,-.7]],dx=kf(s,dxk),spd=Math.abs(kf(s+.02,dxk)-kf(s-.02,dxk))/.04,ph=kf(s,[[0,0],[1.4,1.55*13],[4.4,1.55*13],[6.8,1.55*13+.7*13*.5]]);
    const on=sm((s-4.7)/.3),st=H.slip(s,ph,spd,1,on),part=.55*sm((s-4.9)/.5);
    const A={dx,gait:{ph,amp:.12*Math.min(1,spd/.6),lift:.06*Math.min(1,spd/.6)},follow:1,yaw:st.yaw+(s>6?kf(s,[[6,0],[6.5,Math.PI*.15]]):0),foot:on>.2?st.foot:undefined,roll:on>.2?st.roll+(s>4.9&&s<5.5?.4*Math.sin((s-4.9)/.6*Math.PI):0):0,na:s>1.8&&s<4.6?.25:0,ear:s>1.7?1:0,dy:s>5&&s<5.4?-.03:0,pitch:s>4.9&&s<5.5?.15*Math.sin((s-4.9)/.6*Math.PI):0};
    Object.assign(A,OIL.soakTint(part));if(!A.foot)delete A.foot;d.set(s,A);OIL.wet(fx,s,d,part,4);
    OIL.drip(fx,s,()=>c.mouth(.98),4,s>t0&&s<4.3?.8:0,1.4);
    const spdP=100-Math.round(55*on*(1-sm((s-6.3)/.4))),painted=Math.round(100*lu);
    return {hud:OIL.hud([['Line painted','<b>'+painted+'%</b>'],['Length','<b>'+(2.05*lu).toFixed(1)+' m</b>'],['Target speed','<b>'+spdP+'%</b>'+(spdP<100?' <span class="oil">slipping</span>':'')]],[['Line',lu,'soak'],H.oilMeter(1-.2*lu)]),
      banner:lu>.97&&s<4.4?'LINE PAINTED':'',bannerK:s>3.6?1-(s-3.6)/.8:sm((lu-.97)/.03)};};
  return def;})());
})(window);
