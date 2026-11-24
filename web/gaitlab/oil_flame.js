'use strict';
// Tab 3: FLAMETHROWER (A90): fire gland + stomach oil gland. The oil is lit as it leaves the mouth. Four takes with different rhythm and shape.
// Performer "Drakeling" (cheek fire glands, amber belly gland). Two meters drain: fat (oil) and fire charge.
(function(root){
const OIL=root.OIL,BB=OIL.BB,T=OIL.T,H=OIL.H,{V,clamp,sm,fr,rnd,kf,eo,s2,win,TAU}=OIL,TX=BB.sig.TX;
const {burnBody,stagger,look,fl,ramp01,groundFire}=H;
const PERF={fire:true,big:true,col:'#b0582e',belly:'#f0c890',dark:'#40241a'};
// lip flare + hot core while the jet runs
function lipFlame(St,s,amt,size){const c=St.c,fx=St.fx,p=c.mouth(1.05);if(amt<.03)return;fx.p(p,.55*size,.7*amt,'#ffb040',TX.soft,true);fx.p(p,.28*size,.95*amt,'#fff4c0',TX.soft,true);fx.p(p,.3*size*(.8+.3*Math.sin(s*50)),.8*amt,'#fffbe0',TX.star,true,s*3);OIL.fireAt(St,p.clone().add(V(.3,0,0)),amt);}
// the jet's fires on the ground where it lands
const landFlame=(St,s,tag)=>(k,p,since)=>{if(since>1.4||k%2)return;const a=1-since/1.4;OIL.flame(St.fx,s,V(p.x,0,p.z),.2*a+.05,a*.9,k+tag,{n:2,smoke:since>.4&&k%4===0});};
const mouthSmoke=(St,s,amt,seed)=>{if(amt>.03)OIL.smoke(St.fx,s,St.c.mouth(1.0),3,amt,seed||1,.2);};
const dots=(St,d,s,ts,txt,dur)=>ts.map(t=>fl(d.chest.position.clone().add(V(0,.35,0)),txt,t,s,dur||.8,'sm'));
// ================================================================ 3A  continuous sweeping jet
OIL.add('flame',(()=>{
  const px=4.2,len=6.4,t0=1.0,t1=3.4,tI=1.5;
  const perf=s=>{const P=H.base(s),on=win(s,t0-.05,t1,.15);
    P.na=kf(s,[[0,0],[.5,0],[.95,.5],[1.02,-.14],[1.3,-.12],[3.4,-.12],[3.9,.1],[4.6,0]]);P.hp=kf(s,[[.5,0],[.95,.45],[1.02,.0],[3.4,.0],[3.9,.05],[4.5,0]]);P.nc=kf(s,[[.7,0],[.95,.3],[1.05,-.1],[3.4,0]]);
    P.ny=.4*Math.sin((s-t0)*2.0-.2)*on;P.cyaw=.1*Math.sin((s-t0)*2.0-.2)*on;P.jaw=kf(s,[[0,0],[.5,.15],[.95,.4],[1.02,.9],[3.4,.9],[3.6,.2],[4.3,0]]);P.br=P.br+kf(s,[[.4,0],[.95,.22],[1.05,-.12],[3.4,-.2],[3.9,0]]);
    P.sq=kf(s,[[.7,0],[1.0,.06],[3.4,.04],[3.9,0]]);P.x=kf(s,[[.95,0],[1.05,-.1],[3.4,-.08],[3.9,0]]);P.ta=kf(s,[[.7,0],[1.1,.4],[3.4,.3],[4,0]]);P.nrf=null;return P;};
  const def={id:'a',label:'3A',name:'Continuous sweeping jet',org:'Fire + oil: a held jet, the head sweeps like a hose',len,px,perf,stage:{na:900,nn:300},
    tag:'Inhale (the belly gland glows amber, the cheeks red, the chest swells), then a held 2.4 s jet lit at the lip: dark oil for a hand-width, then flame. The head sweeps across the target like a hose; both meters drain steadily. The target ignites, bolts, rolls; burning oil lands on the ground behind it.',
    ph:[['inhale',1.0,'#8a6a2a'],['held jet, sweeping',2.4,'#ff8a2a'],['cut, recoil',.8,'#c06a2a'],['target rolls, scorched',2.2,'#4a3a30']],cam:{cx:3.0,cy:.8,span:7.6,v:2.8},az:0};
  def.build=sc=>H.make(Object.assign(def,{perfOpt:PERF}))(sc);def.cam0=def.cam;def.cam=()=>def.cam0;def.cam0={cx:3.0,cy:.8,span:7.6,v:2.8};
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,on=win(s,t0-.02,t1,.1),k=1;c.pose(perf(s));
    c.glow(kf(s,[[.3,0],[.95,1],[3.4,.8],[3.9,0]]));c.fglow(kf(s,[[.3,0],[.95,1],[3.4,1],[4.0,.1]]));H.neckGlow(St,.5*win(s,.6,1.0,.1)+.3*on);
    // jet: dark oil first (lit .06 s after leaving), then fire. aimed by the head, so sweeping bends the stream
    OIL.jet(fx,s,{mp:St.mp,t0,t1,dt:.005,kind:'lit',lit:.025,flame:.8,speed:9,spread:.14,g:1.6,size:()=>.15,life:1.1,grow:1.0,onLand:landFlame(St,s,1)});lipFlame(St,s,on,1);
    // prey: ignites when the jet reaches it, bolts away burning, rolls, smoulders
    const run=win(s,tI+.3,tI+2.2,.2),roll=ramp01(s,tI+2.2,tI+3.2),burn=ramp01(s,tI,tI+.2)*(1-.9*ramp01(s,tI+2.6,tI+3.6));
    const dxk=[[0,1.3],[.9,0],[tI,0],[tI+.3,.12],[tI+.6,.5],[tI+2.2,1.0],[tI+3,1.1]],dx=kf(s,dxk),spd=Math.abs(kf(s+.02,dxk)-kf(s-.02,dxk))/.04,ph=kf(s,[[0,0],[.9,17],[tI,17],[tI+2.2,17+1.0*13]]);
    const rear=s>tI&&s<tI+.4?Math.sin((s-tI)/.4*Math.PI):0;
    const A=Object.assign({dx,gait:{ph,amp:.15*Math.min(1,spd/.9),lift:.09*Math.min(1,spd/.9)},follow:1,yaw:s>tI+.3?kf(s,[[tI+.3,0],[tI+.55,Math.PI]]):0,pitch:.4*rear,dy:.1*rear+(spd>.5?.05*Math.abs(Math.sin(s*15)):0)-.1*roll*(1-ramp01(s,tI+3.15,tI+3.4)),na:-.5*rear+.3*Math.sin(s*20)*run,hp:.4*rear,jaw:.5*(run+rear),ear:s>tI?1.3:0,ta:s>tI?1:0,
      roll:roll*TAU*2,limp:roll>0&&roll<1?.9:0,flash:.25*burn,fg:.35,fb:0},look(0,.8*ramp01(s,tI+.4,tI+3.6)));if(!A.limp)delete A.limp;d.set(s,A);
    if(!A.limp===false){}
    const am=stagger(s,tI,0).map(v=>v*burn);const big=burnBody(St,s,d,am,3,1);if(big>.1){OIL.smoke(fx,s,d.head.position,3,big,2,.3);OIL.embers(fx,s,d.pel.position,6,big,1,.35);}
    if(s>tI+3)OIL.smoke(fx,s,d.chest.position,3,.7*(1-ramp01(s,tI+3.4,tI+5)),4,.25);
    mouthSmoke(St,s,s>t1?.9*(1-ramp01(s,t1+.3,t1+1.8)):0,3);OIL.shimmer(fx,s,V(2.4,.5,0),2,.5*on,1);
    if(!St.pd[0]){St.pd[0]=OIL.Puddle(St.scene,1);St.pd[1]=OIL.Puddle(St.scene,2);}
    St.pd[0].set(px-.2,0,.0,.0,{});St.pd[0].set(px+.3,.0,.7,.5,{a:0,scorch:.8*ramp01(s,tI+.3,tI+1.2),t:s});St.pd[1].set(px+1.6,.1,.55,.4,{a:0,scorch:.8*ramp01(s,tI+1.0,tI+2.0),t:s});
    const f=clamp((s-t0)/(t1-t0),0,1),dmgT=[0,1,2,3,4,5,6].map(i=>tI+.5+i*.45),nd=dmgT.filter(t=>s>t).length;
    const floats=dots(St,d,s,dmgT,'-4',.8);
    return {floats,shake:.7*on,hud:OIL.hud([['Jet',on>.5?'<b class="fire">lit at the lip</b>':'<b>-</b>'],['Range','<b>'+(on>.5?'4.5 m':'-')+'</b>'],['Burning',s>tI?'<b class="fire">'+(nd*4)+' dmg</b>':'-'],['Cost','<b>'+Math.round(f*40)+'% fat, '+Math.round(f*58)+'% fire</b>']],[['Target HP',1-.04*nd,'hp'],H.oilMeter(1-.38*f),['Fire charge',1-.58*f,'fire']]),
      banner:s>tI+.05&&s<tI+1.4?'IGNITED':'',bannerK:s>tI+.8?1-(s-tI-.8)/.6:sm((s-tI)/.1)};};
  return def;})());
// ================================================================ 3B  short burst pulses
OIL.add('flame',(()=>{
  const px=4.1,len=6.8,PU=[[1.5,1.85,6.2,.095],[2.55,2.9,6.6,.105],[3.65,4.2,7.6,.135]],gulps=[1.1,2.15,3.25];
  const perf=s=>{const P=H.base(s),g=H.gulp(s,gulps,.3,.6),on=PU.reduce((a,p)=>Math.max(a,win(s,p[0],p[1],.04)),0);
    P.na=kf(s,[[0,0],[.8,0],[1.2,.45],[1.46,.5],[1.52,-.2],[1.85,-.15],[2.1,.1],[2.25,.5],[2.5,.5],[2.57,-.2],[2.9,-.15],[3.15,.1],[3.3,.55],[3.6,.6],[3.68,-.25],[4.2,-.2],[4.6,.1],[5.2,0]]);
    P.hp=kf(s,[[1.2,.3],[1.46,.4],[1.52,-.15],[1.85,-.1],[2.25,.4],[2.5,.4],[2.57,-.15],[2.9,-.1],[3.3,.45],[3.6,.45],[3.68,-.2],[4.2,-.1],[4.7,0]]);
    P.jaw=kf(s,[[0,0],[1.0,.1],[1.45,.3],[1.52,.9],[1.85,.8],[1.95,.1],[2.5,.3],[2.57,.9],[2.9,.8],[3.0,.1],[3.6,.3],[3.68,1],[4.2,.9],[4.4,.1],[5,0]]);
    P.br=P.br+.1*on*0+kf(s,[[1.0,0],[1.4,.15],[1.52,-.12],[1.85,-.05],[2.1,0],[2.4,.15],[2.57,-.12],[2.9,0],[3.5,.2],[3.68,-.16],[4.2,-.1],[4.7,0]]);
    P.x=kf(s,[[1.5,0],[1.58,-.07],[1.95,-.03],[2.55,-.03],[2.62,-.09],[3.0,-.05],[3.65,-.05],[3.72,-.17],[4.4,-.1],[5,0]]);P.sq=.06*on;P.ta=.4*on;P.nrf=g.nrf;return P;};
  const def={id:'b',label:'3B',name:'Short burst pulses',org:'Three coughed fireballs: gulp, cough, recoil, repeat',len,px,perf,stage:{na:900,nn:300},
    tag:'Each pulse is a gulp that runs up the neck, a hard cough and a thick fireball of lit oil, then a recoil step back and a puff of smoke. Three pulses (the last is the biggest) so the meters drop in steps: cheaper per hit, and the creature can stop between them. The target is hit three times, ignites on the second.',
    ph:[['gulp',1.1,'#8a6a2a'],['pulse 1',.4,'#ff8a2a'],['gulp',.65,'#8a6a2a'],['pulse 2',.4,'#ff8a2a'],['gulp',.7,'#8a6a2a'],['pulse 3 (big)',.6,'#ffb347'],['target scorched',2.4,'#4a3a30']],cam:{cx:3.0,cy:.8,span:7.6,v:2.8},az:0};
  def.build=sc=>H.make(Object.assign(def,{perfOpt:PERF}))(sc);def.cam0={cx:3.0,cy:.8,span:7.6,v:2.8};def.cam=()=>def.cam0;
  const hits=[1.95,3.0,4.3],tI=3.0;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,gulps,.3,.6);c.pose(perf(s));
    c.glow(kf(s,[[.3,0],[1.1,.7],[1.5,.4],[2.1,.7],[2.55,.4],[3.2,.8],[3.7,.3],[4.6,0]]));c.fglow(kf(s,[[.3,0],[1.1,.9],[1.5,1],[1.9,.4],[2.1,.9],[2.55,1],[2.95,.4],[3.25,1],[3.7,1],[4.4,.1]]));H.neckGlow(St,g.amt*.9);
    PU.forEach((p,i)=>{OIL.jet(fx,s,{mp:St.mp,t0:p[0],t1:p[1],dt:.005,kind:'lit',lit:.025,flame:.6+.08*i,speed:p[2]*1.35,spread:.2,g:1.8,size:()=>p[3]*1.45,life:.85,grow:1.1,onLand:landFlame(St,s,i*7)});lipFlame(St,s,win(s,p[0],p[1],.05),1+.3*i);
      mouthSmoke(St,s,win(s,p[1]+.1,p[1]+1.1,.3)*.9,i+2);});
    const fh=hits.reduce((a,h)=>a+(s>h?Math.exp(-(s-h)*7):0),0),fw=hits.reduce((a,h)=>a+(s>h?Math.exp(-(s-h)*6)*Math.sin((s-h)*24):0),0);
    const lvl=kf(s,[[1.9,0],[2.05,.4],[2.9,.5],[3.05,1],[4.5,1],[5.6,.35],[6.4,0]]),burn=lvl;
    const dxk=[[0,1.3],[.9,0],[1.95,0],[2.1,.2],[3.0,.2],[3.15,.5],[4.3,.5],[4.5,1.2],[5.2,2.4],[5.8,2.6]],dx=kf(s,dxk),spd=Math.abs(kf(s+.02,dxk)-kf(s-.02,dxk))/.04,ph=kf(s,[[0,0],[.9,17],[4.3,17],[5.8,17+2.6*13]]);
    const roll=ramp01(s,5.2,6.1),A=Object.assign({dx,gait:{ph,amp:.14*Math.min(1,spd/.8),lift:.08*Math.min(1,spd/.8)},follow:1,yaw:kf(s,[[4.3,0],[4.55,Math.PI]]),sq:.18*Math.min(1,fh),na:-.55*Math.min(1,fh)+.25*Math.sin(s*20)*(s>2.9?1:0)*lvl,hp:.45*Math.min(1,fh),jaw:.6*Math.min(1,fh)+.4*lvl,ear:s>1.8?1.3:0,ta:s>2?1:0,pitch:.2*Math.min(1,fh),dy:(spd>.5?.05*Math.abs(Math.sin(s*15)):0)+.05*Math.min(1,fh)-.1*roll*(1-ramp01(s,6.15,6.4)),
      roll:roll*TAU*2,limp:roll>0&&roll<1?.9:0,flash:.22*burn,fg:.35,fb:0},look(0,.8*ramp01(s,3.2,6.2)));if(!A.limp)delete A.limp;d.set(s,A);
    const am=stagger(s,tI,0).map(v=>v*burn*(1-.9*ramp01(s,5.6,6.4)));const big=burnBody(St,s,d,am,3,1);if(big>.1){OIL.smoke(fx,s,d.head.position,3,big,2,.3);OIL.embers(fx,s,d.pel.position,5,big,1,.35);}
    if(s>6)OIL.smoke(fx,s,d.chest.position,3,.7*(1-ramp01(s,6.2,7)),4,.25);
    OIL.shimmer(fx,s,V(2.4,.5,0),2,.4*PU.reduce((a,p)=>Math.max(a,win(s,p[0],p[1]+.3,.1)),0),1);
    if(!St.pd[0])St.pd[0]=OIL.Puddle(St.scene,1);St.pd[0].set(px+.3,0,.7,.5,{a:0,scorch:.8*ramp01(s,3.0,4.5),t:s});
    const nHit=hits.filter(h=>s>h).length,fat=[1,.88,.76,.58][PU.filter(p=>s>p[0]+.2).length],fire=[1,.86,.72,.5][PU.filter(p=>s>p[0]+.2).length];
    const dmgT=[3.5,4.0,4.5,5.0,5.5],nd=dmgT.filter(t=>s>t).length;
    const floats=hits.map((h,i)=>fl(d.head.position.clone().add(V(0,.3+.0*i,0)),i===2?'-18':'-10',h,s,.9,i===2?'x2':'sm')).concat(dots(St,d,s,dmgT,'-4',.8));
    return {floats,shake:hits.reduce((a,h)=>a+(s>h-.4&&s<h-.4+.25?1:0),0)*.9,hud:OIL.hud([['Pulses','<b class="fire">'+PU.filter(p=>s>p[0]).length+' / 3</b>'],['Hit',nHit?'<b>'+nHit+' x</b>':'-'],['Burning',s>tI?'<b class="fire">'+(s<6?'yes':'out')+'</b>':'-']],[['Target HP',1-.1*nHit-.1*(nHit>2)-.03*nd,'hp'],H.oilMeter(fat),['Fire charge',fire,'fire']]),
      banner:PU.some(p=>s>p[0]+.1&&s<p[0]+.9)?'PULSE '+PU.filter(p=>s>p[0]).length:'',bannerK:1};};
  return def;})());
// ================================================================ 3C  sputtering rising jet that arcs
OIL.add('flame',(()=>{
  const px=5.7,len=7.2,t0=2.15,t1=3.95,flightK=t=>.98-.2*clamp((t-t0)/(t1-t0),0,1);
  const sput=[[1.3,1.4],[1.55,1.62],[1.75,1.95],[2.0,2.1]];
  const perf=s=>{const P=H.base(s),g=H.gulp(s,[.7,1.05],.3,.55),on=win(s,t0,t1,.1);
    P.na=kf(s,[[0,0],[.5,0],[1.0,.6],[1.3,.8],[2.0,.85],[2.15,.8],[3.9,.45],[4.6,.05],[5.2,0]]);P.nc=kf(s,[[1.0,0],[1.4,.45],[2.1,.3],[3.9,.05],[4.6,0]]);P.hp=kf(s,[[.9,0],[1.3,.55],[2.1,.6],[3.9,.2],[4.6,0]]);
    P.pitch=kf(s,[[1.0,0],[1.4,.2],[2.1,.2],[3.9,.1],[4.6,0]]);P.sq=kf(s,[[1.2,0],[1.9,.07],[2.15,.1],[3.9,.04],[4.6,0]]);
    const sp=sput.reduce((a,p)=>Math.max(a,win(s,p[0],p[1],.03)),0);P.jaw=kf(s,[[0,0],[.7,.15],[1.2,.4],[2.1,.7],[2.2,.9],[3.9,.85],[4.2,.2],[4.8,0]])+.25*sp;P.br=P.br+kf(s,[[.6,0],[1.0,.12],[1.5,.16],[2.1,.2],[2.2,-.1],[3.9,-.2],[4.5,0]])+.04*Math.sin(s*30)*(s>1.2&&s<2.1?1:0);
    P.x=kf(s,[[2.15,0],[2.25,-.1],[3.9,-.08],[4.5,0]]);P.ta=.35*on+.2*sp;P.nrf=g.nrf;return P;};
  const def={id:'c',label:'3C',name:'Sputtering rising jet that arcs',org:'Pressure builds: spits and pops, then a lobbed arc of fire onto far prey',len,px,perf,stage:{na:900,nn:300},
    tag:'Head thrown up. The gland sputters at first: spits of oil, orange pops at the lip, a cough. Then the pressure catches and the jet climbs, bends over at the top and rains fire onto a target 4 m away, out of reach of a flat jet. Burning drops fall behind the cover line.',
    ph:[['gulps, head up',1.3,'#8a6a2a'],['sputter',.85,'#c08a2a'],['rising jet, arcs',1.8,'#ff8a2a'],['rain of fire',1.4,'#e0501a'],['bolts, scorched',1.85,'#4a3a30']],cam:{cx:3.5,cy:1.0,span:8.4,v:3.2},az:0};
  def.build=sc=>H.make(Object.assign(def,{perfOpt:PERF}))(sc);def.cam0={cx:3.5,cy:1.0,span:8.4,v:3.2};def.cam=()=>def.cam0;
  const tI=t0+1.1;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,[.7,1.05],.3,.55),on=win(s,t0,t1,.1);c.pose(perf(s));
    c.glow(kf(s,[[.3,0],[1.0,.9],[2.1,1],[3.9,.7],[4.4,0]]));c.fglow(kf(s,[[.4,0],[1.2,.8],[2.0,1],[3.9,1],[4.5,.1]]));H.neckGlow(St,g.amt*.9+.3*win(s,1.2,2.2,.2));
    // sputter: weak spits and pops
    sput.forEach((p,i)=>{OIL.jet(fx,s,{mp:St.mp,t0:p[0],t1:p[1],dt:.02,kind:i%2?'oil':'lit',lit:.06,flame:.3,speed:3.6+.5*i,spread:.4,g:6,size:()=>.1,life:.6,grow:.7});const a=win(s,p[0],p[1]+.06,.02);if(a>.03){const q=c.mouth(1.05);fx.p(q,.5+.15*i,.85*a,'#ff9a30',TX.soft,true);fx.p(q,.22,.9*a,'#fff0b0',TX.star,true,i);OIL.flame(fx,s,q.clone().add(V(.06,0,0)),.2+.05*i,a,i+20,{n:3,smoke:false});}});
    // the main arc: lit oil aimed to drop on the target (rises, bends over)
    OIL.jet(fx,s,{mp:St.mp,t0,t1,dt:.007,kind:'lit',lit:.03,flame:.9,speed:8,spread:.1,g:9.8,aim:(tb,k)=>({p:V(px-.15+(rnd(k)-.5)*.5,.36+rnd(k+3)*.25,(rnd(k+7)-.5)*.5),T:flightK(tb),stick:true}),size:()=>.13,life:1.4,grow:.9,onStick:(k,p,a)=>{if(a<.7&&k%3===0)OIL.flame(fx,s,V(p.x,p.y*.4,p.z),.3*(1-a/.7),1-a/.7,k+9,{n:2,smoke:false});}});lipFlame(St,s,on,1.1);
    // prey: waits far away, hit by the rain of fire, panics in zigzags, rolls
    const burn=ramp01(s,tI,tI+.2)*(1-.9*ramp01(s,tI+3,tI+3.9)),rear=s>tI&&s<tI+.45?Math.sin((s-tI)/.45*Math.PI):0;
    const dxk=[[0,1.2],[1.0,0],[tI,0],[tI+.3,.2],[tI+.7,.9],[tI+1.2,.5],[tI+1.7,1.3],[tI+2.2,.9],[tI+2.6,.9]],zk=[[tI,0],[tI+.4,-.3],[tI+.8,.3],[tI+1.3,-.35],[tI+1.8,.3],[tI+2.4,0]];
    const dx=kf(s,dxk),spd=Math.abs(kf(s+.02,dxk)-kf(s-.02,dxk))/.04,ph=kf(s,[[0,0],[1.0,15],[tI,15],[tI+2.6,15+8]]),roll=ramp01(s,tI+2.4,tI+3.3),run=win(s,tI+.3,tI+2.4,.15);
    const A=Object.assign({dx,dz:s>tI?kf(s,zk):0,gait:{ph,amp:.15*Math.min(1,spd/.9),lift:.09*Math.min(1,spd/.9)},follow:1,yaw:s>tI?kf(s,[[tI,0],[tI+.3,Math.PI*.7],[tI+.8,Math.PI*.3],[tI+1.3,Math.PI*.8],[tI+1.8,Math.PI*.2],[tI+2.4,Math.PI*.5]]):0,pitch:.4*rear,dy:.1*rear+.05*run*Math.abs(Math.sin(s*15))-.1*roll*(1-ramp01(s,tI+3.35,tI+3.6)),na:-.5*rear+.3*Math.sin(s*20)*run,hp:.4*rear,jaw:.5*(run+rear),ear:s>tI-.4?1.3:0,ta:s>tI?1:0,roll:roll*TAU*2,limp:roll>0&&roll<1?.9:0,flash:.25*burn,fg:.35,fb:0},look(0,.8*ramp01(s,tI+.4,tI+3.6)));if(!A.limp)delete A.limp;d.set(s,A);
    const am=stagger(s,tI,0).map(v=>v*burn);const big=burnBody(St,s,d,am,3,1);if(big>.1){OIL.smoke(fx,s,d.head.position,3,big,2,.3);OIL.embers(fx,s,d.pel.position,6,big,1,.35);}
    if(s>tI+3.3)OIL.smoke(fx,s,d.chest.position,3,.7*(1-ramp01(s,tI+3.6,tI+5)),4,.25);
    OIL.burst(fx,V(px-.15,.3,0),s-tI,.45,3);
    if(!St.pd[0])St.pd[0]=OIL.Puddle(St.scene,1);St.pd[0].set(px,0,.9,.6,{a:0,scorch:.8*ramp01(s,tI+.3,tI+1.6),t:s});groundFire(St,s,px,0,.7,.8*ramp01(s,tI,tI+.4)*(1-ramp01(s,tI+2,tI+3.2)),6,3);
    mouthSmoke(St,s,s>t1?.9*(1-ramp01(s,t1+.3,t1+1.8)):0,3);
    const f=clamp((s-t0)/(t1-t0),0,1),sp=clamp((s-1.3)/.8,0,1),dmgT=[0,1,2,3,4,5].map(i=>tI+.5+i*.45),nd=dmgT.filter(t=>s>t).length;
    const floats=dots(St,d,s,dmgT,'-4',.8);
    return {floats,shake:.5*on,hud:OIL.hud([['Phase',s<1.3?'<b>building pressure</b>':s<t0?'<b class="oil">sputtering</b>':s<t1?'<b class="fire">arc, 4 m</b>':'<b>done</b>'],['Burning',s>tI?'<b class="fire">'+(nd*4)+' dmg</b>':'-'],['Cost','<b>'+Math.round(8*sp+34*f)+'% fat</b>']],[['Target HP',1-.04*nd,'hp'],H.oilMeter(1-.08*sp-.34*f),['Fire charge',1-.1*sp-.46*f,'fire']]),
      banner:s>t0+.9&&s<t0+2.2?'ARC':'',bannerK:1};};
  return def;})());
// ================================================================ 3D  pilot light at the lip, then a gush
OIL.add('flame',(()=>{
  const px=4.1,len=7.0,t0=3.05,t1=4.6,gulps=[.9,1.55,2.2];
  const perf=s=>{const P=H.base(s),g=H.gulp(s,gulps,.35,.5),on=win(s,t0,t1,.06);
    P.na=kf(s,[[0,0],[.5,.05],[.9,.3],[1.2,.15],[1.55,.35],[1.85,.2],[2.2,.4],[2.5,.3],[2.95,.55],[3.05,-.18],[3.4,-.15],[4.6,-.14],[5.2,.1],[5.8,0]]);P.hp=kf(s,[[.5,0],[1.2,.1],[2.2,.2],[2.9,.4],[3.05,-.2],[4.6,-.15],[5.2,0]]);
    P.jaw=kf(s,[[0,0],[.4,.15],[.9,.2],[2.5,.25],[3.0,.4],[3.1,.9],[4.6,.85],[4.8,.3],[5.6,.1],[6.2,0]]);P.br=P.br+kf(s,[[.8,0],[1.5,.06],[2.2,.1],[2.9,.2],[3.08,-.12],[4.6,-.18],[5.1,0]]);
    P.x=kf(s,[[3.0,0],[3.1,-.09],[4.6,-.07],[5.2,0]]);P.sq=kf(s,[[2.6,0],[3.0,.06],[4.6,.03],[5.2,0]]);P.ta=kf(s,[[2.8,0],[3.2,.4],[4.6,.2],[5.2,0]]);P.ny=.12*Math.sin((s-t0)*2.4)*on;P.nrf=g.nrf;return P;};
  const def={id:'d',label:'3D',name:'Pilot light, then a gush',org:'A small flame held at the lip, fed oil until it gushes',len,px,perf,stage:{na:900,nn:300},
    tag:'The cheek flints strike and a small steady pilot flame (blue core) sits on the lip while the belly gland pumps oil up in three gulps; the pilot swells with each. Then the throat opens: a whoosh as the oil meets the flame at the lip and a big gush jet. After the cut the pilot shrinks back, flickers and goes out. The target watches the flame grow, then bolts.',
    ph:[['strike',.8,'#8a6a2a'],['pilot light, pumping',2.2,'#4a7ad0'],['gush',1.6,'#ff8a2a'],['pilot dies',2.4,'#c06a2a']],cam:{cx:3.0,cy:.8,span:7.6,v:2.8},az:0};
  def.build=sc=>H.make(Object.assign(def,{perfOpt:PERF}))(sc);def.cam0={cx:3.0,cy:.8,span:7.6,v:2.8};def.cam=()=>def.cam0;
  const tI=t0+.5;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,g=H.gulp(s,gulps,.35,.5),on=win(s,t0,t1,.06);c.pose(perf(s));
    c.glow(kf(s,[[.6,0],[1.0,.5],[2.2,.8],[3.0,1],[4.6,.7],[5.4,0]]));c.fglow(kf(s,[[.3,0],[.55,1],[.7,.3],[.8,1],[2.9,.7],[3.05,1],[4.6,.8],[5.4,.1]]));H.neckGlow(St,g.amt*.9);
    // flint sparks at the start
    for(const tc of [.45,.62,.8]){const a=s-tc;if(a>0&&a<.22){const q=c.mouth(1.0);for(let i=0;i<5;i++){const az=i*1.3+tc*5;fx.p(V(q.x+Math.cos(az)*.12*a*5,q.y+.02+Math.sin(az)*.09*a*5,q.z),.05,1-a/.22,'#fff0b0',TX.star,true,i);}}}
    // the pilot: small blue-cored flame at the lip, swelling with each gulp, strong flicker; goes out after the gush
    const grow=kf(s,[[.8,0],[.95,1],[1.5,1.2],[2.2,1.6],[2.9,2.3],[3.05,2.6]]),pilotOn=(s>.8?1:0)*(s<t0?1:s<t1?1:1-ramp01(s,t1+.7,t1+1.5)*1)*(s>5.6?1-ramp01(s,5.6,6.1):1);
    const pil=c.mouth(1.04).add(V(.04,.03,0)),ph=pilotOn*(s<t0||s>t1?1:0)*(.5+.5*Math.min(1,grow/1.2));
    if(s>=.8&&(s<t0||s>t1)&&pilotOn>.02){const hh=(s<t0?.2+.08*grow:.2*(1-ramp01(s,t1+.2,t1+1.5)*.6))*(1+.18*Math.sin(s*35)),a=pilotOn;
      OIL.flame(fx,s,pil,hh,a,2,{n:3,ramp:OIL.BLUE,core:'#dff2ff',glow:'#6aa0ff',smoke:false,lean:.2});OIL.flame(fx,s,pil.clone().add(V(.01,.01,0)),hh*1.35,a*.7,5,{n:3,smoke:false,lean:.3});OIL.fireAt(St,pil,a*.35);}
    // gush: oil meets the pilot and whooshes
    OIL.jet(fx,s,{mp:St.mp,t0,t1,dt:.005,kind:'lit',lit:.025,flame:.85,speed:9.5,spread:.15,g:1.6,size:()=>.17,life:1.1,grow:1.0,onLand:landFlame(St,s,5)});lipFlame(St,s,on,1.3);
    OIL.burst(fx,c.mouth(1.1).setY(.9),s-t0-.02,.4,2);
    // prey watches the pilot grow (ears up, backs off a step), bolts when the gush comes
    const burn=ramp01(s,tI,tI+.2)*(1-.9*ramp01(s,tI+2.4,tI+3.4)),rear=s>tI&&s<tI+.4?Math.sin((s-tI)/.4*Math.PI):0;
    const dxk=[[0,1.3],[.8,0],[2.0,0],[2.5,.15],[2.9,.2],[tI,.2],[tI+.3,.3],[tI+.7,.8],[tI+2.0,1.5],[tI+3,1.6]],dx=kf(s,dxk),spd=Math.abs(kf(s+.02,dxk)-kf(s-.02,dxk))/.04,ph2=kf(s,[[0,0],[.8,17],[2,17],[tI+2,17+1.5*13]]);
    const roll=ramp01(s,tI+2.1,tI+3.0);
    const A=Object.assign({dx,gait:{ph:ph2,amp:.15*Math.min(1,spd/.9),lift:.09*Math.min(1,spd/.9)},follow:1,yaw:s>tI+.3?kf(s,[[tI+.3,0],[tI+.55,Math.PI]]):0,pitch:.4*rear,dy:.1*rear+(spd>.5?.05*Math.abs(Math.sin(s*15)):0)-.1*roll*(1-ramp01(s,tI+3.05,tI+3.3)),na:-.5*rear+(s>1.2&&s<tI?.25:0),hp:.4*rear,jaw:.5*rear,ear:s>.9?1.3:0,ta:s>tI?1:0,roll:roll*TAU*2,limp:roll>0&&roll<1?.9:0,flash:.25*burn,fg:.35,fb:0},look(0,.8*ramp01(s,tI+.4,tI+3.4)));if(!A.limp)delete A.limp;d.set(s,A);
    const am=stagger(s,tI,0).map(v=>v*burn);const big=burnBody(St,s,d,am,3,1);if(big>.1){OIL.smoke(fx,s,d.head.position,3,big,2,.3);OIL.embers(fx,s,d.pel.position,6,big,1,.35);}
    if(s>tI+3)OIL.smoke(fx,s,d.chest.position,3,.7*(1-ramp01(s,tI+3.2,tI+4.6)),4,.25);
    mouthSmoke(St,s,s>t1?.9*(1-ramp01(s,t1+.3,t1+1.8)):0,3);if(s>5.6&&s<6.6)OIL.smoke(fx,s,c.mouth(1.04),2,.8*(1-ramp01(s,5.7,6.6)),9,.16);
    if(!St.pd[0])St.pd[0]=OIL.Puddle(St.scene,1);St.pd[0].set(px+.3,0,.7,.5,{a:0,scorch:.8*ramp01(s,tI+.3,tI+1.4),t:s});
    const f=clamp((s-t0)/(t1-t0),0,1),pump=kf(s,[[.8,0],[2.9,1]]),dmgT=[0,1,2,3,4,5].map(i=>tI+.5+i*.45),nd=dmgT.filter(t=>s>t).length,floats=dots(St,d,s,dmgT,'-4',.8);
    return {floats,shake:.7*on,hud:OIL.hud([['Flame at lip',s<.8?'<b>-</b>':s<t0?'<b class="oil">pilot (small)</b>':s<t1?'<b class="fire">gush</b>':s<5.6?'<b class="oil">pilot</b>':'<b>out</b>'],['Burning',s>tI?'<b class="fire">'+(nd*4)+' dmg</b>':'-'],['Cost','<b>'+Math.round(36*f)+'% fat, '+Math.round(4*pump+46*f)+'% fire</b>']],[['Target HP',1-.04*nd,'hp'],H.oilMeter(1-.04*pump-.36*f),['Fire charge',1-.04*pump-.46*f,'fire']]),
      banner:s>t0+.05&&s<t0+1.3?'GUSH':(s>.9&&s<2.4?'PILOT LIGHT':''),bannerK:1};};
  return def;})());
})(window);
