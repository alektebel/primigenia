'use strict';
// Tab 2: IGNITION COMBO (A89 effect table: oil + fire = ignite x2). Four takes: fire-gland spark on a soaked target, thrown ember into a puddle,
// natural ignition (lava) that lights an oil line into a wall of flame that stops the prey, chain ignition along a painted line into an oiled gorge (a giant is lured).
(function(root){
const OIL=root.OIL,BB=OIL.BB,T=OIL.T,H=OIL.H,{V,clamp,sm,fr,rnd,kf,eo,s2,win,TAU}=OIL,TX=BB.sig.TX,TXO=OIL.TX;
const fl=(pos,text,t0,s,dur,cls)=>({pos,text,k:(s-t0)/dur,cls});
const ramp01=(s,a,b)=>sm((s-a)/(b-a));
// flames on a body: per-part amounts (0..1) in order chest, back, haunch, head, tail
function burnBody(St,s,d,amts,seed,hs){const fx=St.fx,k=d.k;hs=hs||1;
  const pts=[d.chest.localToWorld(V(.0,.17*k,0)),d.pel.localToWorld(V(.12*k,.15*k,0)),d.pel.localToWorld(V(-.1*k,.13*k,0)),d.head.localToWorld(V(.0,.07*k,0)),d.pel.localToWorld(V(-.28*k,.02*k,0))];
  const hh=[.36,.34,.32,.22,.22];let big=0;
  pts.forEach((p,i)=>{const a=amts[i]||0;if(a<.03)return;OIL.flame(fx,s,p,hh[i]*k*hs*(.6+.4*a),a,seed+i*3,{lean:-.15,n:5,heat:.85});if(a>big){big=a;OIL.fireAt(St,p,a);}});
  return big;}
const stagger=(s,t,k0)=>[0,.1,.2,.15,.28].map(o=>ramp01(s,t+o,t+o+.14));
// charring + soak tint: char 0..1 darkens, soak wets
const look=(soak,char)=>char>soak?{tint:'#17120d',tamt:.7*char}:{tint:'#2b2112',tamt:.62*soak};
// the spark/ember cheek glow readout for the performer
function cheek(St,v){St.c.fglow(v);}
// small ground flame field for oil that burns where it fell
function groundFire(St,s,x,z,r,amt,seed,n){if(amt<.04)return;for(let i=0;i<n;i++){const a=i*2.4+seed,rr=r*(.2+.8*rnd(seed+i)),h=(.26+.26*rnd(seed+i*3))*amt;OIL.flame(St.fx,s,V(x+Math.cos(a)*rr,0,z+Math.sin(a)*rr*.7),h,amt,seed+i*5,{n:3,heat:.65});}OIL.fireAt(St,V(x,.2,z),amt*.7);}
H.burnBody=burnBody;H.stagger=stagger;H.look=look;H.fl=fl;H.ramp01=ramp01;H.groundFire=groundFire;
// ================================================================ 2A  fire-gland spark
OIL.add('ignite',(()=>{
  const px=2.9,len=7.2,tS=1.8,tI=2.03,HP0=100,perf=s=>{const P=H.base(s);
    P.na=kf(s,[[0,0],[1.1,0],[1.45,-.22],[1.75,-.3],[1.95,.05],[2.5,0]]);P.hp=kf(s,[[1.2,0],[1.6,.15],[1.78,-.2],[2.0,.1],[2.5,0]]);P.sq=kf(s,[[1.3,0],[1.7,.05],[1.95,0]]);
    P.jaw=kf(s,[[0,0],[1.4,0],[1.45,.5],[1.52,0],[1.58,.55],[1.66,0],[1.74,.8],[1.95,.35],[2.5,0]]);P.x=kf(s,[[1.7,0],[1.9,-.04],[2.4,0]]);P.ta=kf(s,[[1.5,0],[2.0,.2],[2.6,0]]);return P;};
  const circ=s=>{const t=Math.max(0,s-2.35),w=5,th=w*t;return {x:-.4*Math.sin(th),z:-.4*(1-Math.cos(th)),th};};
  const def={id:'a',label:'2A',name:'Fire gland spark',org:'Fire gland (cheek flints) + oil on the target',len,px,perf,stage:{},
    tag:'Soaked target (glossy, dripping). The fire gland glows, the jaws clack twice like flints (sparks), and one spark flies out. Whoosh: the coat ignites front to back, x2 damage, then burning over time. The target rears, runs in circles, rolls to put it out, and ends scorched with the oil burnt off.',
    ph:[['soaked, gland glows',1.8,'#8a3a1c'],['spark',.25,'#ffd76a'],['whoosh x2',.6,'#ff8a2a'],['burning, panic',1.8,'#e0501a'],['roll, out',1.1,'#8a6a4a'],['scorched',1.65,'#4a3a30']],cam:{cx:1.9,cy:.65,span:5.3,v:2.1},az:0};
  def.build=sc=>{const St=H.make(Object.assign(def,{perfOpt:{fire:true,col:'#a56a46',belly:'#e8c898',dark:'#3d2418'}}))(sc);St.line=null;return St;};
  def.cam0={cx:1.9,cy:.65,span:5.3,v:2.1};def.cam=()=>def.cam0;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,m=St.mp(tS).p;c.pose(perf(s));c.glow(.25*(1-ramp01(s,tI,tI+1)));cheek(St,kf(s,[[.8,0],[1.5,1],[1.9,1],[2.3,.3],[2.8,0]]));H.neckGlow(St,0);
    // sparks at the teeth on each clack
    for(const tc of [1.45,1.58]){const a=s-tc;if(a>0&&a<.22){const q=c.mouth(1.0);for(let i=0;i<6;i++){const az=i*1.1+tc*3;fx.p(V(q.x+Math.cos(az)*.14*a*5,q.y+.02+Math.sin(az)*.1*a*5,q.z+.03*Math.sin(az*2)),.05,1-a/.22,'#fff0b0',TX.star,true,i);}fx.p(q,.2*(1-a/.22),.9*(1-a/.22),'#ffd27a',TX.soft,true);}}
    // the spark flying out: bright star with a short trail
    const u=(s-tS)/.23,chestW=V(px-.12,.36,0);
    if(u>=0&&u<1){const p=m.clone().lerp(chestW,u);p.y+=.07*Math.sin(u*Math.PI);fx.p(p,.28,.95,'#fff6c8',TX.star,true,u*8);fx.p(p,.5,.55,'#ffa030',TX.soft,true);for(let i=1;i<6;i++){const uu=Math.max(0,u-.06*i),q=m.clone().lerp(chestW,uu);q.y+=.07*Math.sin(uu*Math.PI);fx.p(q,.12*(1-i/7),.7*(1-i/6),'#ffb040',TX.star,true,i);}}
    const since=s-tI,burn=ramp01(s,tI,tI+.25)*(1-ramp01(s,4.2,5.1));
    // prey: soaked + dripping, then burning
    const cr=circ(s),run=win(s,2.3,3.85,.15),rollK=ramp01(s,3.9,4.85),rear=since>0&&since<.5?Math.sin(since/.5*Math.PI):0;
    const soak=1-.85*ramp01(s,tI+.2,4.6),char=.8*ramp01(s,tI+.4,4.8);const st=H.slip(s,s*5,0,1,soak*(1-run));
    const A=Object.assign({dx:cr.x,dz:cr.z,dy:.14*rear*.9+.1*Math.abs(Math.sin(s*14))*run-.1*rollK*(1-ramp01(s,4.85,5.1)),yaw:(s>2.35?Math.min(cr.th,TAU*1.3):0)+(s>3.85&&s<4.9?0:0),
      pitch:.5*rear,na:-.6*rear+.25*Math.sin(s*22)*run,hp:.5*rear+.2*Math.sin(s*18)*run,jaw:.8*rear+.5*run,ear:1.3*(s>tI?1:0),ta:s>tI?1:0,sq:.12*(s>tI&&s<tI+.25?1:0),
      gait:run>.05?{ph:s*26,amp:.15*run,lift:.09*run}:null,follow:1,fy:.07*rear,roll:s>3.9?rollK*TAU*2:0,limp:s>3.9&&s<4.9?.9*(1-ramp01(s,4.8,4.95)):(rear>.05?.6:0),
      foot:(s<tI&&soak>.3)?st.foot:undefined,flash:.25*burn*(.5+.5*Math.sin(s*30)),fg:.35,fb:0},look(soak,char));
    if(A.gait===null)delete A.gait;if(!A.foot)delete A.foot;d.set(s,A);
    const am=stagger(s,tI,0).map(v=>v*burn*(1-.55*rollK*sm((s-4.2)/.3)));const big=burnBody(St,s,d,am,3,1);
    OIL.wet(fx,s,d,Math.max(0,soak),5);
    if(big>.1){OIL.smoke(fx,s,d.head.position,3,big,2,.3);OIL.embers(fx,s,d.pel.position,6,big,1,.35);OIL.shimmer(fx,s,V(d.pel.position.x,.5,d.pel.position.z),.5,big,1);}
    if(s>4.8)OIL.smoke(fx,s,d.chest.position,3,.8*(1-ramp01(s,5.4,7)),4,.25);
    OIL.burst(fx,V(px-.1+cr.x*0,.3,0),s-tI,.45,2);
    // the puddle that dripped under the target lights too, then scorches
    if(!St.pd[0])St.pd[0]=OIL.Puddle(St.scene,2);const pb=ramp01(s,tI+.1,tI+.4)*(1-ramp01(s,4.4,5.2));St.pd[0].set(px-.05,0,.3,.22,{a:ramp01(s,0,.3)*(1-.6*ramp01(s,tI,5)),burn:pb,scorch:ramp01(s,tI+.2,5.2),t:s});groundFire(St,s,px-.05,0,.28,pb,7,4);
    OIL.embers(fx,s,V(c.mouth(1).x,.3,0),0,0,0);
    // damage readout
    const dots=[2.65,3.15,3.65,4.15,4.65,5.15],floats=[fl(d.head.position.clone().add(V(.1,.3,0)),'12',tI,s,1.1,'sm'),fl(d.head.position.clone().add(V(0,.5,0)),'x2 = 24',tI+.1,s,1.4,'x2')];
    dots.forEach((t,i)=>floats.push(fl(V(px-.1+cr.x*(s>2.35&&s<4?1:0),.7+.0*i,cr.z*(s>2.35&&s<4?1:0)),'-3',t,s,.8,'sm')));
    const nd=dots.filter(t=>s>t).length,hp=HP0-(s>tI?24:0)-3*nd,burnLeft=s<tI?0:Math.max(0,5.2-(s-tI));
    return {floats,shake:since>0&&since<.3?1-since/.3:0,hud:OIL.hud([['Base damage',s>tI?'<b>12</b>':'-'],['Combo','<b class="fire">'+(s>tI?'oil + fire: x2 = 24':'soaked, ready')+'</b>'],['Burning',s>tI&&s<tI+5.2?'<b class="fire">'+burnLeft.toFixed(1)+' s, -3 / 0.5 s</b>':'-'],['Soaked',s<tI?'<b class="oil">'+(8-Math.min(s,tI)*.5).toFixed(1)+' s</b>':'<b>burnt off</b>']],[['Target HP',hp/HP0,'hp'],['Fire gland charge',1-.12*ramp01(s,1.5,1.9),'fire']]),
      banner:since>.05&&since<1.6?'IGNITE x2':'',bannerK:since>1?1-(since-1)/.6:sm(since/.1)};};
  return def;})());
// ================================================================ 2B  thrown ember into a puddle
OIL.add('ignite',(()=>{
  const px=3.1,len=7.4,tT=1.9,flight=.62,tL=tT+flight,land=V(px-.95,0,0),perf=s=>{const P=H.base(s);
    P.na=kf(s,[[0,0],[.9,0],[1.5,.5],[1.85,.65],[1.95,-.1],[2.2,-.35],[2.7,0]]);P.nc=kf(s,[[1.4,0],[1.85,.4],[2.0,0]]);P.hp=kf(s,[[1.2,0],[1.7,.5],[1.9,.5],[2.05,-.1],[2.6,0]]);P.pitch=kf(s,[[1.5,0],[1.85,.14],[2.05,-.06],[2.5,0]]);P.sq=kf(s,[[1.5,0],[1.85,.06],[2.1,0]]);
    P.jaw=kf(s,[[0,0],[1.0,.12],[1.5,.4],[1.85,.65],[2.0,.9],[2.25,.2],[2.6,0]]);P.x=kf(s,[[1.8,0],[2.0,.07],[2.6,0]]);P.ta=kf(s,[[1.6,0],[2.0,.4],[2.6,0]]);return P;};
  const pools=[[0,0,.75,.55,0],[.5,.3,.6,.4,1],[-.4,-.25,.55,.4,2],[.1,-.3,.5,.35,3]];
  const def={id:'b',label:'2B',name:'Thrown ember',org:'Fire gland: a glowing coal lobbed onto spilled oil',len,px,perf,stage:{},
    tag:'A puddle with the target standing in it (stuck, slipping). The fire gland packs a glowing ember in the cheek, the head lobs it, and where it lands the oil lights: a flame front races across the puddle, the target ignites (x2) and bolts out through the fire. The lit puddle burns as a pool of flame, then scorches.',
    ph:[['pool, ember forms',1.9,'#8a3a1c'],['lob',.62,'#ffd76a'],['front races',.7,'#ff8a2a'],['pool fire',2.6,'#e0501a'],['burnt out',1.6,'#4a3a30']],cam:{cx:2.0,cy:.7,span:5.5,v:2.2},az:0};
  def.build=sc=>{const St=H.make(Object.assign(def,{perfOpt:{fire:true,col:'#a56a46',belly:'#e8c898',dark:'#3d2418'}}))(sc);const m=new T.MeshPhongMaterial({color:'#ff7a20',emissive:'#ff5a10',emissiveIntensity:1.2,shininess:30});St.ember=new T.Mesh(new T.IcosahedronGeometry(1,1),m);St.ember.visible=false;sc.add(St.ember);St.pools=pools.map((q,i)=>OIL.Puddle(sc,i+1));return St;};
  def.cam0={cx:2.0,cy:.7,span:5.5,v:2.2};def.cam=()=>def.cam0;
  
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx;c.pose(perf(s));c.glow(.2);cheek(St,kf(s,[[.7,0],[1.4,1],[1.95,1],[2.3,.2],[3,0]]));H.neckGlow(St,0);
    // pool: grows in at the start (target already stood in it)
    const t0=s-tL,burnLife=ramp01(s,tL+3.2,tL+4.6);
    // prey
    const front=pt=>tL+Math.hypot(pt[0]-(land.x-px),pt[1])*.75/1.0*1.0;
    const igP=tL+.55,ig=ramp01(s,igP,igP+.2),since=s-igP,flee=ramp01(s,igP+.3,igP+1.2),out=ramp01(s,igP+.5,igP+2.0);
    const dx=kf(s,[[0,1.6],[1.0,.0],[igP,0],[igP+.35,-.1],[igP+.7,.7],[igP+1.5,1.15],[igP+2.5,1.3]]),spd=Math.abs(kf(s+.02,[[0,1.6],[1.0,.0],[igP,0],[igP+.35,-.1],[igP+.7,.7],[igP+1.5,1.15],[igP+2.5,1.3]])-kf(s-.02,[[0,1.6],[1.0,.0],[igP,0],[igP+.35,-.1],[igP+.7,.7],[igP+1.5,1.15],[igP+2.5,1.3]]))/.04;
    const ph=kf(s,[[0,0],[1.0,20],[igP,20],[igP+2.5,20+1.3*13]]),inPool=1-ramp01(s,igP+.6,igP+1.4),soak=Math.max(.0,sm(s/.5)*(1-.8*ramp01(s,igP+.3,igP+2.5))),char=.8*ramp01(s,igP+.5,igP+3);
    const st=H.slip(s,ph,spd,1,inPool*sm(s/.5)),rear=since>0&&since<.45?Math.sin(since/.45*Math.PI):0;
    const A=Object.assign({dx,gait:{ph:ph*1.0,amp:.14*Math.min(1,spd/.8),lift:.08*Math.min(1,spd/.8)},follow:1,yaw:s<igP?st.yaw*.6:kf(s,[[igP,0],[igP+.4,Math.PI],[igP+3,Math.PI]]),na:s<tL?(s>1.9?.3:0):-.55*rear,hp:.5*rear,pitch:.45*rear,dy:.13*rear*.9+(spd>.3?.06*Math.abs(Math.sin(s*15)):0),jaw:.8*rear*(s>igP?1:0)+(s>igP?.4:0),ear:s>1.4?1.1:0,ta:s>igP?1:0,sq:.12*(since>0&&since<.2?1:0),
      foot:inPool>.2?st.foot:undefined,roll:inPool>.2?st.roll:0,flash:.2*ig*(1-out),fg:.35,fb:0},look(soak,char));if(!A.foot)delete A.foot;d.set(s,A);
    const burn=ig*(1-ramp01(s,igP+3.2,igP+4.4));burnBody(St,s,d,stagger(s,igP,0).map(v=>v*burn),9,1);OIL.wet(fx,s,d,soak,3);
    if(burn>.1){OIL.smoke(fx,s,d.head.position,3,burn,3,.3);OIL.embers(fx,s,d.pel.position,5,burn,2,.3);}
    // ember: forms in the cheek, lobbed in an arc, tumbling, trail of sparks
    const em=St.ember,m0=St.mp(tT).p,u=(s-tT)/flight;
    if(s<tT){const sz=.01+.04*sm((s-1.0)/.8);em.visible=sz>.015;em.position.copy(c.mouth(1.0));em.scale.setScalar(sz);fx.p(em.position,.2*sz*10,.5*sm((s-1.0)/.8),'#ff8a2a',TX.soft,true);}
    else if(u<1){em.visible=true;const p=m0.clone().lerp(land.clone().setY(.06),u);p.y+=1.15*4*u*(1-u)*.5*2*.5;p.y+=m0.y*0;em.position.copy(p);em.scale.setScalar(.05);em.rotation.set(s*9,s*7,0);fx.p(p,.3,.8,'#ff9a30',TX.soft,true);fx.p(p,.16,.9,'#fff0b0',TX.star,true,s*5);
      for(let i=1;i<9;i++){const uu=Math.max(0,u-.035*i),q=m0.clone().lerp(land.clone().setY(.06),uu);q.y+=1.15*2*uu*(1-uu);q.x+=.04*Math.sin(i*5+s*20);q.y+=.03*Math.cos(i*3);fx.p(q,.08*(1-i/10),.8*(1-i/9),i%2?'#ffb040':'#ff7a20',TX.star,true,i);}}
    else{em.visible=s<tL+.1;em.position.copy(land).setY(.05);em.scale.setScalar(.05);}
    // pool: flame front from the landing point outwards
    St.pools.forEach((pd,i)=>{const q=pools[i],ox=px+q[0],oz=q[1],dist=Math.hypot(ox-land.x,oz-land.z)-.2,bi=ramp01(s,tL+dist*.55,tL+dist*.55+.2)*(1-ramp01(s,tL+3.0+q[4]*.25,tL+4.4+q[4]*.25));
      pd.set(ox,oz,q[2],q[3],{a:.92*sm(s/.4)*(1-.35*ramp01(s,tL+2,tL+5)),burn:bi,scorch:ramp01(s,tL+dist*.55+.3,tL+4.8),t:s,rot:i*1.3});groundFire(St,s,ox,oz,q[2]*.85,bi,i*11+3,4);});
    OIL.burst(fx,V(land.x,.1,0),s-tL,.5,1);
    for(const pt of [[0,0],[.45,.28],[-.4,-.2]])OIL.burst(fx,V(px+pt[0],.15,pt[1]),s-(tL+Math.hypot(px+pt[0]-land.x,pt[1])*.55+.1),.38,pt[0]*5);
    OIL.shimmer(fx,s,V(px,.3,0),1.2,ramp01(s,tL+.4,tL+1)*(1-ramp01(s,tL+3.5,tL+4.5)),3);
    const floats=[fl(V(px,.8,0),'12',igP,s,1,'sm'),fl(V(px-.1,1.05,0),'x2 = 24',igP+.1,s,1.4,'x2')];[0,1,2,3,4].forEach(i=>{const t=igP+.9+i*.5;floats.push(fl(V(px+Math.min(1.4,Math.max(0,dx)*.55)+.3,.7,0),'-3',t,s,.8,'sm'));});
    const nd=[0,1,2,3,4].filter(i=>s>igP+.9+i*.5).length,hp=s<igP?100:100-24-3*nd;
    return {floats,shake:s>tL&&s<tL+.4?1-(s-tL)/.4:0,hud:OIL.hud([['Fuel','<b class="oil">'+(s<tL?'oil puddle (slows, slippery)':'burning pool')+'</b>'],['Combo','<b class="fire">'+(s>igP?'x2 = 24 + burning':'ember in flight')+'</b>'],['Pool fire',s>tL?'<b class="fire">'+Math.max(0,tL+4.2-s).toFixed(1)+' s</b>':'-']],[['Target HP',hp/100,'hp'],['Fire gland charge',1-.14*ramp01(s,1.4,1.9),'fire']]),
      banner:s>tL+.05&&s<tL+1.6?'PUDDLE LIT':'',bannerK:(s-tL)>1?1-((s-tL)-1)/.6:sm((s-tL)/.1)};};
  return def;})());
// ================================================================ 2C  lava ignites a painted line: a wall that blocks the path
OIL.add('ignite',(()=>{
  const wx=3.3,len=8.4,tI=1.5,path=u=>({x:wx+.15*Math.sin(u*5),z:1.3-u*3.2}),Nn=11;
  const perf=s=>{const P=H.base(s);P.na=kf(s,[[0,0],[2,.1],[3,0]]);P.hp=.1*Math.sin(s*1.3);P.jaw=.05;return P;};
  const def={id:'c',label:'2C',name:'Lava lights the line: a wall that blocks',org:'No fire gland needed: natural ignition (lava seep) + a painted oil line',len,px:6.6,perf,stage:{},
    tag:'The oil line was painted across the path earlier. A lava seep at its end lights it with no gland and no lightning: the fire races along the line and rises into a wall of flame. The prey arrives, rears back, paces and circles, and refuses to cross until the wall dies down. The wall holds about 12 s in the game.',
    ph:[['seep touches the line',1.5,'#8a3a1c'],['fire races',.9,'#ff8a2a'],['wall holds: prey refuses',4.3,'#e0501a'],['dies down',1.7,'#4a3a30']],cam:{cx:3.3,cy:.6,span:7,v:2.6},az:22};
  def.build=sc=>{const St=H.make(Object.assign(def,{x0:.1,perfOpt:{}}))(sc);
    St.line=OIL.Line(sc,Nn,path,.5,70);
    // lava seep: a glowing crack-pool with a dark rim, at the near end of the line
    const lm=new T.MeshBasicMaterial({map:TXO.oil[0],color:'#ff6a18',transparent:true,depthWrite:false,blending:T.AdditiveBlending,opacity:.9});St.lava=new T.Mesh(new T.PlaneGeometry(1,1),lm);St.lava.rotation.x=-Math.PI/2;St.lava.position.set(wx+.1,.006,1.75);St.lava.scale.set(1.25,1.0,1);sc.add(St.lava);
    const rim=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:TXO.scorch[1],transparent:true,depthWrite:false}));rim.rotation.x=-Math.PI/2;rim.position.set(wx+.1,.004,1.75);rim.scale.set(1.9,1.5,1);sc.add(rim);
    const rm=BB.lam('#2c2a28');for(let i=0;i<5;i++){const r=new T.Mesh(new T.DodecahedronGeometry(.14+.06*(i%2),0),rm);const a=i*1.3;r.position.set(wx+.1+Math.cos(a)*.85,.06,1.95+Math.sin(a)*.62+(-.2));sc.add(r);}
    return St;};
  def.cam0={cx:3.3,cy:.6,span:7,v:2.6};def.cam=()=>def.cam0;
  const hMax=1.25;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx;c.pose(perf(s));c.glow(0);H.neckGlow(St,0);
    const front=clamp((s-tI-.35)/.9,0,1),t=s-tI,die=ramp01(s,6.3,7.9),wall=win(s,tI+.3,8.0,.5);
    // lava: bubbling light, heat shimmer, embers
    St.lava.material.opacity=.7+.2*Math.sin(s*3)+.1*Math.sin(s*11);OIL.embers(fx,s,V(wx+.1,.1,1.75),4,.9,5,.5);OIL.shimmer(fx,s,V(wx+.1,.1,1.75),.8,.9,2);fx.p(V(wx+.1,.5,1.75),1.8,.18,'#ff6a18',TX.soft,true);OIL.fireAt(St,V(wx+.1,.4,1.75),.45);
    for(let i=0;i<4;i++){const u=fr(s*.7+i*.27);fx.p(V(wx+.1+(i-1.5)*.22,.06+.12*Math.sin(u*Math.PI),1.75+.1*Math.sin(i*5)),.09*(1-u*.4),.8,'#ffc060',TX.soft,true);}
    St.line.set(1,(i,u)=>sm((front*Nn-i)/1.2)*(1-ramp01(s,6.3+u*.5,7.6+u*.5)),(i,u)=>ramp01(s,tI+.6+u*.9,tI+1.8+u*.9)*(.7+.3*die),s);
    // the wall: flame columns along the line
    for(let i=0;i<Nn;i++){const u=(i+.5)/Nn,p=path(u),b=sm((front*Nn-i)/1.2)*(1-ramp01(s,6.3+u*.5,7.6+u*.5)),grow=ramp01(s,tI+.3+u*.9,tI+1.4+u*.9);if(b<.04)continue;
      const h=(.35+hMax*.6*grow)*(.85+.3*rnd(i+4))*b;OIL.flame(fx,s,V(p.x,0,p.z),h,b,i*7+1,{n:4,lean:.1,heat:.26});OIL.flame(fx,s,V(p.x+.12,0,p.z+.1),h*.7,b,i*7+2,{n:2,smoke:false,heat:.26});if(i%2===0)OIL.fireAt(St,V(p.x,.5,p.z),b*.9);}
    OIL.burst(fx,V(wx+.1,.1,1.6),t-.15,.45,2);for(let i=1;i<Nn;i+=3){const u=(i+.5)/Nn,p=path(u);OIL.burst(fx,V(p.x,.1,p.z),t-.35-u*.9,.3,i);}
    OIL.shimmer(fx,s,V(wx,.5,0),2.4,.8*wall*(1-die),4);OIL.embers(fx,s,V(wx,.3,.2),10,.9*wall*(1-die),3,1.4);OIL.embers(fx,s,V(wx,.3,-.5),8,.8*wall*(1-die),6,1.4);
    // prey comes along the path from the right, balks, paces, circles, refuses
    const ax=[[0,7.6],[1.8,6.6],[3.0,5.3],[3.7,4.7],[4.1,4.55],[4.6,4.9],[5.4,5.2],[6.0,5.1],[6.5,5.0],[7.0,4.6],[8.0,4.7]];
    const dx=kf(s,ax)-6.6,spd=Math.abs(kf(s+.02,ax)-kf(s-.02,ax))/.04;
    const bk=win(s,3.7,4.6,.2),ph=kf(s,[[0,0],[3.4,(7.6-4.8)*13],[8,(7.6-4.8)*13+9]]);
    const zz=kf(s,[[0,0],[4.6,0],[5.2,-.35],[5.9,-.5],[6.4,-.2],[7.0,.4],[7.6,.6]]);
    const yw=kf(s,[[0,0],[4.5,0],[5.2,.55],[5.9,.0],[6.5,-.5],[7.2,.4],[8,0]]);
    const A={dx,dz:zz,gait:{ph,amp:.12*Math.min(1,spd/.7),lift:.07*Math.min(1,spd/.7)},follow:1,yaw:yw,na:kf(s,[[3,0],[3.7,.25],[4.1,-.35],[4.5,.1]]),hp:bk*.4,pitch:.3*bk*Math.sin(Math.PI*clamp((s-3.7)/.5,0,1)),dy:.1*bk*(s<4.2?1:0),ear:s>3?1.2*sm((s-3)/.4):0,jaw:.4*bk,ta:s>3.6?.8:0,sq:.08*bk};
    d.set(s,A);if(s>3.4&&s<7.4){fx.p(d.head.position.clone().add(V(0,.25,0)),.5,.28*bk*0,'#ff8a2a',TX.soft,true);}
    // reflected glow on the prey's face
    d.flash(.1*wall*(1-die),.04*wall*(1-die),0);
    const left=s<tI+1.2?12:Math.max(0,12-(s-tI-1.2)*1.7);
    const status=s<3.5?'approaching':s<4.6?'balks':s<7.2?'refuses, circles':'waits';
    return {shake:0,hud:OIL.hud([['Wall',s<tI+.4?'<b>-</b>':'<b class="fire">'+Math.round(100*front)+'% lit, '+(hMax*Math.min(1,t/1.5)).toFixed(1)+' m high</b>'],['Prey','<b>'+status+'</b>'],['Wall time left','<b class="fire">'+(s<tI+1.2?'12.0':left.toFixed(1))+' s</b>']],[['Line lit',front,'fire'],['Wall height',(1-die)*Math.min(1,t/1.6),'fire']]),
      banner:s>3.9&&s<5.6?'PATH BLOCKED':'',bannerK:s>5?1-(s-5)/.6:sm((s-3.9)/.15)};};
  return def;})());
// ================================================================ 2D  chain ignition: a giant in an oiled gorge
OIL.add('ignite',(()=>{
  const len=8.6,x1=2.3,x2=7.4,gz=0,gx=g=>g,px=8.2,tSp=1.35,Nn=17,path=u=>({x:x1+u*(x2-x1),z:.12*Math.sin(u*9)});
  const perf=s=>{const P=H.base(s);P.na=kf(s,[[0,0],[.8,.1],[1.1,-.25],[1.3,-.3],[1.45,.05],[2,0]]);P.hp=kf(s,[[1.0,0],[1.3,-.2],[1.5,.1],[2,0]]);P.jaw=kf(s,[[0,0],[1.0,0],[1.06,.5],[1.14,0],[1.22,.5],[1.3,0],[1.35,.8],[1.6,.3],[2.2,0]]);P.x=kf(s,[[1.2,0],[1.4,-.05],[2,0]]);P.ta=kf(s,[[1.2,0],[1.5,.2],[2.2,0]]);return P;};
  const def={id:'d',label:'2D',name:'Chain ignition: a giant in the gorge',org:'Painted line = fuse: one spark, the whole oiled gorge lights',len,px,perf,stage:{bare:true},
    tag:'A line of oil runs the length of a narrow gorge and a giant is lured along it. One spark at the near end and the fire chains down the line like a fuse (about 6 m/s), reaches the giant, ignites its feet and belly for x2, and fills the gorge with a flame wall. The giant roars, rears, and backs out; it cannot pass.',
    ph:[['lure, giant enters',1.3,'#6a5a2e'],['spark',.3,'#ffd76a'],['chain races',1.0,'#ff8a2a'],['giant burns x2',2.4,'#e0501a'],['retreats, wall holds',3.6,'#8a3a1c']],cam:{cx:4.9,cy:1.0,span:10.2,v:3.9},az:0};
  def.build=sc=>{const St=H.make(Object.assign(def,{x0:.5,perfOpt:{fire:true,col:'#a56a46',belly:'#e8c898',dark:'#3d2418'},preyOpt:{k:2.4,col:'#7a6a86',belly:'#b9a9a0',dark:'#2c2430',horns:true}}))(sc);
    St.line=OIL.Line(sc,Nn,path,.5,90);
    // gorge: tall far wall of stacked rocks, low near rocks
    const rm=BB.lam('#4b4f50'),rm2=BB.lam('#5c5f5a'),R=BB.rng(21);for(let i=0;i<30;i++){const x=1.8+i*.24+(R()-.5)*.2,h=1.1+R()*.8,r=.3+R()*.22,m=new T.Mesh(new T.DodecahedronGeometry(r,0),i%2?rm:rm2);m.position.set(x,h*.35+.1,-1.35-R()*.35);m.scale.set(1,h/(r*1.3),1.1);m.rotation.set(R(),R()*3,R());sc.add(m);}
    for(let i=0;i<14;i++){const m=new T.Mesh(new T.DodecahedronGeometry(.22+R()*.2,0),i%2?rm:rm2);m.position.set(2.0+i*.4+R()*.2,.08,1.5+R()*.3);m.scale.set(1,.55,1);m.rotation.set(R(),R()*3,0);sc.add(m);}
    return St;};
  def.cam0={cx:4.9,cy:1.0,span:10.2,v:3.9};def.cam=()=>def.cam0;
  const speed=6,tFrontStart=tSp+.22;
  const gk=[[0,9.6],[1.3,8.35],[2.6,8.1],[3.4,7.7],[3.9,8.2],[4.6,8.7],[5.8,9.2],[7.4,9.4]],gSoak=s=>.5*ramp01(s,.6,1.3)+.0;
  def.frame=(St,s)=>{const c=St.c,d=St.d,fx=St.fx,k=d.k;c.pose(perf(s));c.glow(.2);cheek(St,kf(s,[[.6,0],[1.1,1],[1.4,1],[1.9,.3],[2.4,0]]));H.neckGlow(St,0);
    const frontX=x1+Math.max(0,(s-tFrontStart))*speed,fu=clamp((frontX-x1)/(x2-x1),0,1);
    // giant: lured in from the right, stops at the oil, burns, rears, backs out
    const gx0=kf(s,gk)-px,spd=Math.abs(kf(s+.02,gk)-kf(s-.02,gk))/.04,ph=kf(s,[[0,0],[1.3,20],[2.6,22],[3.4,30],[5.8,18],[7.4,0]]);
    const reach=gk[1][1]-.55,tG=tFrontStart+(Math.max(0,px-1.1-x1))/speed;                       // when the front reaches the giant's feet (approx.)
    const burnT=tFrontStart+(7.9-x1)/speed-.1,burn=ramp01(s,burnT,burnT+.3)*(1-ramp01(s,6.6,7.9)),since=s-burnT,rear=since>0&&since<1.0?Math.sin(clamp(since/1.0,0,1)*Math.PI):0,roar=since>.1&&since<2.2?1:0;
    const soak=.5*ramp01(s,.4,1.2)*(1-.7*ramp01(s,burnT+.3,burnT+2)),char=.5*ramp01(s,burnT+.5,6);
    const A=Object.assign({dx:gx0,gait:{ph,amp:.13*k*Math.min(1,spd/.9),lift:.07*k*Math.min(1,spd/.9)},follow:1,pitch:.4*rear,dy:.16*k*rear,na:-.5*rear+(roar?.25*Math.sin(s*16):0),hp:.5*rear,jaw:.9*roar,ear:s>burnT?1.3:0,ta:s>burnT?1:0,fy:.1*k*rear,flash:.18*burn,fg:.3,fb:0,yaw:s>burnT+.9?kf(s,[[burnT+.9,0],[burnT+1.4,Math.PI*.12]]):0},look(soak,char));d.set(s,A);
    const am=stagger(s,burnT,0).map(v=>v*burn);const big=burnBody(St,s,d,am,13,1.6);
    // feet flames
    if(burn>.05)for(let i=0;i<4;i++){const p=V(d.hipW[i].x,.05,d.hipW[i].z);OIL.flame(fx,s,p,.5*burn*(.8+.4*rnd(i)),burn,60+i*3,{n:3,heat:.7});}
    if(big>.1){OIL.smoke(fx,s,d.head.position,3,big,3,.7);OIL.embers(fx,s,d.pel.position,8,big,2,.7);OIL.shimmer(fx,s,V(d.pel.position.x,1,0),1.1,big,2);}
    OIL.wet(fx,s,d,soak,2);
    // spark and the chain
    const u=(s-tSp)/.2,m=St.mp(tSp).p,tgt=V(x1+.1,.05,path(0).z);
    if(u>=0&&u<1){const p=m.clone().lerp(tgt,u);p.y+=.1*Math.sin(u*Math.PI);fx.p(p,.3,.95,'#fff6c8',TX.star,true,u*8);fx.p(p,.5,.55,'#ffa030',TX.soft,true);for(let i=1;i<6;i++){const uu=Math.max(0,u-.06*i),q=m.clone().lerp(tgt,uu);q.y+=.1*Math.sin(uu*Math.PI);fx.p(q,.11*(1-i/7),.7*(1-i/6),'#ffb040',TX.star,true,i);}}
    for(const tc of [1.06,1.22]){const a=s-tc;if(a>0&&a<.22){const q=c.mouth(1.0);for(let i=0;i<6;i++){const az=i*1.1+tc*3;fx.p(V(q.x+Math.cos(az)*.14*a*5,q.y+.02+Math.sin(az)*.1*a*5,q.z),.05,1-a/.22,'#fff0b0',TX.star,true,i);}}}
    const lit=i=>{const x=x1+((i+.5)/Nn)*(x2-x1),a=s-(tFrontStart+(x-x1)/speed);return a;};
    St.line.set(ramp01(s,.1,1.0)*0+1,(i)=>ramp01(s,tFrontStart+(i/Nn)*(x2-x1)/speed,tFrontStart+(i/Nn)*(x2-x1)/speed+.18)*(1-ramp01(s,6.4+i*.05,7.6+i*.05)),(i)=>ramp01(s,tFrontStart+(i/Nn)*(x2-x1)/speed+.2,tFrontStart+(i/Nn)*(x2-x1)/speed+4),s);
    for(let i=0;i<Nn;i++){const p=path((i+.5)/Nn),a=lit(i),b=sm(a/.2)*(1-ramp01(s,6.4+i*.05,7.6+i*.05));if(b<.04)continue;const grow=ramp01(a,0,1.5);const h=(.3+.7*grow)*(.8+.4*rnd(i+4))*b;
      OIL.flame(fx,s,V(p.x,0,p.z),h,b,i*5+1,{n:4,lean:.12,heat:.6});if(i%2===0)OIL.flame(fx,s,V(p.x+.1,0,p.z+.15),h*.7,b,i*5+2,{n:3,smoke:false,heat:.6});if(i%3===0)OIL.burst(fx,V(p.x,.1,p.z),a-.05,.3,i);if(i%4===0)OIL.fireAt(St,V(p.x,.5,p.z),b*.85);}
    OIL.shimmer(fx,s,V((x1+x2)/2,.6,0),4,.6*fu*(1-ramp01(s,6.6,8)),2);OIL.embers(fx,s,V(4.6,.3,0),10,.8*fu*(1-ramp01(s,6.6,8)),3,2.2);OIL.embers(fx,s,V(6.4,.3,0),8,.7*fu*(1-ramp01(s,6.6,8)),4,2);
    const floats=[fl(d.head.position.clone().add(V(0,.4,0)),'40',burnT,s,1.1,'sm'),fl(d.head.position.clone().add(V(0,.8,0)),'x2 = 80',burnT+.1,s,1.5,'x2')];[0,1,2,3,4,5].forEach(i=>floats.push(fl(d.chest.position.clone().add(V(0,.5,0)),'-8',burnT+.8+i*.5,s,.8,'sm')));
    const nd=[0,1,2,3,4,5].filter(i=>s>burnT+.8+i*.5).length,hp=s<burnT?100:100-(s>burnT?80/3:0)-8*nd/3*(1);
    return {floats,shake:since>0&&since<.4?1-since/.4:0,hud:OIL.hud([['Fuse speed','<b class="fire">~'+speed+' m/s</b>'],['Giant','<b>'+(s<tG-.4?'lured in':s<burnT?'standing in oil':s<burnT+2.4?'burning, rears':'backs out')+'</b>'],['Combo',s>burnT?'<b class="fire">x2 = 80</b>':'-']],[['Giant HP',clamp(hp/100,0,1),'hp'],['Fire gland charge',1-.1*ramp01(s,1.0,1.4),'fire']]),
      banner:s>burnT+.1&&s<burnT+1.8?'GIANT IGNITED x2':'',bannerK:since>1.2?1-(since-1.2)/.6:sm(since/.15)};};
  return def;})());
})(window);
