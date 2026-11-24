'use strict';
// Move 1: ICE SPIKE (A85). A projectile that damages and slows. Four takes: spat icicle, shard volley, spike from the ground, breath-formed lance.
// Shared stage: the cryo creature "Rimeback" (left, faces +x) and a tan grazer that walks in from the right; the walker model slows it after the hit(s).
(function(root){
const IC=root.IC,T=IC.T,BB=IC.BB,{V,clamp,sm,lerp,ramp,win,pls,ease,easeOut,back,keys,hash,emit,burst,skel,TAU}=IC;
const A=(a,b)=>V(a.x,a.y,a.z).sub(b);
// ---- shared stage (also used by the breath move)
function stage(scene,o){o=o||{};IC.dress(scene,o.bg||'#1d2a33',o.dress);const S={scene,fx:IC.FX(scene),perf:IC.buildQuad(scene,'cryo'),tgt:IC.buildQuad(scene,'prey'),shell:IC.buildShell(scene)};return S;}
IC.stage=stage;
const perfBase=(t,o)=>Object.assign({x:0,yaw:0,s:1.15,frost:.3,cold:0,amp:0,t,bob:.006*Math.sin(t/620),blink:Math.sin(t/900+1)>.97?1:0,sac:.12+.04*Math.sin(t/700),glow:.06,legFrost:.15},o);
const tgtBase=(t,w,o)=>Object.assign({x:w.x,yaw:Math.PI,s:.92,D:w.D,amp:1,t,blink:Math.sin(t/1100+3)>.97?1:0},o);
IC.perfBase=perfBase;IC.tgtBase=tgtBase;
// target reaction record from walker state: flinch recoil, slow stiffness, frost, shiver
function reaction(w,t,hits,frostK){
  const R={};let fl=0,last=-1e9;for(const h of hits)if(t>=h&&h>last){last=h;}for(const h of hits)if(t>=h)fl+=Math.exp(-(t-h)/260);fl=Math.min(1.4,fl);
  const since=t-(hits.length?hits[0]:1e9),chill=since<0?0:sm(since/260)*(1-sm((since-3300)/2800));
  Object.assign(R,{fl,chill,x:w.x+.1*fl,crouch:Math.min(.5,.28*fl+.16*chill),pitch:.08*fl*0+.1*fl,neckA:.45*fl-.1*chill,headA:.2*fl,jaw:Math.min(1,fl*.7),squint:Math.min(1,fl*1.2),stiff:chill,cold:chill*.9,frost:chill*(frostK===undefined?.6:frostK),legFrost:chill,shiver:chill*.8+fl*.6,flash:Math.min(.7,Math.max(0,hits.reduce((a,h)=>a+(t>=h?.7*Math.exp(-(t-h)/120):0),0)))});
  return R;}
IC.reaction=reaction;
function makeSpike(def){
  const hits=def.hits,hit0=hits[0],X0=5.7,V0=.95;
  const walkerFor=()=>IC.makeWalker({x0:X0,v0:V0,dir:-1,t0:0,len:def.len,chill:t=>{const s=t-hit0;return s<0?0:.62*sm(s/260)*(1-sm((s-3300)/2800));},flinches:hits});
  const rig={move:'spike',id:def.id,label:def.label,name:def.name,org:def.org,tag:def.tag,len:def.len,ph:def.ph};
  rig.build=scene=>{const S=stage(scene);S.w=walkerFor();
    S.tposeAt=t=>{const w=S.w.at(t),R=reaction(w,t,hits,def.frostK),y=(def.lift?def.lift(t):0);return tgtBase(t,w,{x:R.x,y,crouch:R.crouch,pitch:R.pitch,neckA:R.neckA,headA:R.headA,jaw:R.jaw,squint:R.squint,stiff:R.stiff,cold:R.cold,frost:R.frost,legFrost:R.legFrost,shiver:R.shiver,flash:R.flash,spot:def.spot?def.spot(t):0,R,w});};
    S.pposeAt=t=>perfBase(t,def.perf(t));
    return S;};
  rig.frame=(S,u,ctx)=>{
    const fx=S.fx;fx.reset();const tp=S.tposeAt(u),pp=S.pposeAt(u),R=tp.R,psk=skel(pp),tsk=skel(tp);
    IC.drawQuad(S.perf,pp);IC.drawQuad(S.tgt,tp);S.shell.g.visible=false;
    // idle vapour from both noses (the cold one is whiter, denser)
    emit(fx,u,{t0:0,t1:def.len,rate:.55,seed:3,life:[900,1400],origin:tb=>skel(S.pposeAt(tb)).nose,vel:r=>V(.25+.1*r(),.12+.1*r(),(r()-.5)*.1),drag:1.2,size:[.06,.26],kind:'puff',col:'#d8f1ff',op:.28});
    emit(fx,u,{t0:0,t1:def.len,rate:.45,seed:4,life:[800,1200],origin:tb=>skel(S.tposeAt(tb)).nose,vel:r=>V(-.2-.1*r(),.1+.08*r(),(r()-.5)*.1),drag:1.3,size:[.05,.2],kind:'puff',col:'#f4fbff',op:.12});
    def.fx(fx,u,{S,tp,pp,psk,tsk,R,ctx});
    // slowed target: frost motes drifting off, cold breath shimmer
    if(R.chill>.05)emit(fx,u,{t0:hit0,t1:hit0+4800,rate:9,seed:8,life:[700,1300],origin:tb=>{const q=skel(S.tposeAt(tb));return q.back.clone().add(V((hash(Math.round(tb/10),1)-.5)*.5,-.1,(hash(Math.round(tb/10),2)-.5)*.3));},vel:r=>V(0,.15+.2*r(),(r()-.5)*.1),size:[.03,.06],kind:'spark',col:'#c6ecff',op:.7*Math.max(.25,R.chill),spin:3});
    fx.flush();
    const sp=Math.round(S.w.at(u).sp*100);
    const left=u<hit0?0:Math.max(0,Math.round((hit0+6100-u)/100)/10);
    return {hud:`<div><span class="k">Target speed</span> <b>${u<hit0?100:Math.round(100*(1-.88*R.chill))}%</b> ${R.chill>.1?'<span class="ice">slowed</span>':''}</div><div class="mt"><div style="width:${100*R.chill}%"></div></div><div><span class="k">Slow</span> <b class="ice">${R.chill>.02?(R.chill*100|0)+'%':'none'}</b></div><div><span class="k">Damage</span> ${u>=hit0?'<b class="bad">-'+def.dmg+' HP</b>':'-'}</div>`,
      banner:u>=hit0&&u<hit0+260?'HIT':'',bannerK:1-(u-hit0)/260,shake:R.fl>.4?R.fl:0};
  };
  rig.cam=(u,ctx)=>{const tx=u>0?(rig.inst?rig.inst.w.at(u).x:5):5;const fz=def.camZoom?def.camZoom(u):0;return {cx:(tx-.25)/2,cy:.5,span:Math.max(4.8,tx+2.4-fz),v:1.8};};
  IC.rigs.spike.push(rig);return rig;}
// -------------------------------------------------- shared bits for the four versions
// the target's chest in the world at time t
const chestAt=(S,t)=>skel(S.tposeAt(t)).chest.clone().add(V(0,.02,0));
// the projectile model: ice spike pointing along dir, length L, at pos, with growth g (0..1) and fade
function drawSpikeObj(S,key,pos,dir,L,r,g,op){
  if(!S.objs)S.objs={};let o=S.objs[key];if(!o){o=S.objs[key]=IC.spikeMesh(1,1,.75,6);S.scene.add(o);}
  o.visible=g>.01&&op>.01;if(!o.visible)return;o.position.copy(pos);o.quaternion.setFromUnitVectors(V(0,1,0),dir.clone().normalize());o.scale.set(r*g,L*g,r*g);IC.iceOpacity(o,op);}
IC.drawSpikeObj=drawSpikeObj;
// frost mist trail behind a flying thing: path(t) gives position; emits puffs and sparks over [t0,t1]
function trail(fx,u,t0,t1,path,seed,k){k=k||1;
  emit(fx,u,{t0,t1,rate:90*k,seed,life:[350,650],origin:tb=>path(tb),vel:r=>V((r()-.5)*.2,(r()-.5)*.2,(r()-.5)*.2),drag:2,size:[.05,.22],kind:'puff',col:'#d3f0ff',op:.34});
  emit(fx,u,{t0,t1,rate:130*k,seed:seed+1,life:[300,700],origin:tb=>path(tb),vel:r=>V((r()-.5)*.5,(r()-.5)*.5+.1,(r()-.5)*.5),grav:-.3,drag:1.5,size:[.04,.09],kind:'spark',col:'#e6f9ff',op:.9,spin:4});}
IC.trail=trail;
function sacVapor(fx,u,S,t0,t1,k){emit(fx,u,{t0,t1,rate:26*(k||1),seed:21,life:[500,900],origin:tb=>skel(S.pposeAt(tb)).sac,vel:r=>V(.1+.2*r(),-.12-.12*r(),(r()-.5)*.3),drag:1.8,size:[.04,.2],kind:'puff',col:'#cdeeff',op:.4});}
IC.sacVapor=sacVapor;
// the frost bloom on the target at an impact point: ground patch and chill sparkle
function impactFrost(fx,u,S,t,seedV,strength){const age=u-t;if(age<0)return;const g=ease(age/700),tp=S.tposeAt(t);fx.frost(tp.x+.05,tp.z+.05,.35*strength*g+.05,.8*Math.min(1,g*2)*(1-sm((age-3800)/2500)),1.1);}
IC.impactFrost=impactFrost;

// ================= V1: spat icicle ==============================================================
const TR=1750;
const spat=makeSpike({id:'icicle',label:'Spat icicle',name:'Rear back, snap, spit',org:'one fat icicle grown in the mouth, spat like a dart',len:6600,
  tag:'The sac swells and glows while the head rears back and the haunches coil. A crystal grows between the parted jaws, then a hard head snap spits it. It leaves a mist trail, strikes the chest with a flash and a shatter of shards, and frost blooms outward from the wound while the target limps slowly on.',
  hits:[2130],dmg:14,spot:t=>ramp(t,2130,2700)*(1-sm((t-5200)/1800)),frostK:.55,
  ph:[['approach',900,'#5d6d78'],['charge (sac fills)',850,'#6fb4d8'],['snap + spit',380,'#e0925c'],['impact',500,'#d9576b'],['slowed, recovers',3970,'#7f8c96']],
  perf:t=>{
    const ch=ramp(t,900,1650),snap=sm((t-TR)/90)*(1-sm((t-TR-90)/320)),after=ramp(t,TR,TR+250)*(1-sm((t-TR-600)/1200)),rec=1-sm((t-TR-250)/1400);
    return {sac:.12+.9*ch*(1-sm((t-TR)/160))+.05,glow:.1+.9*ch*(1-ramp(t,TR+100,TR+900)),pulse:.5*Math.sin(t/55)*ch*(t<TR?1:0),
      crouch:.38*ch*rec-.05*snap,pitch:.16*ch*(1-sm((t-TR+60)/120))-.14*snap-.05*after,neckA:.55*ch*(1-sm((t-TR+50)/110))-.18*snap-.1*after,neckE:-.5*ch*(1-sm((t-TR+50)/110))+.65*snap,headA:.3*ch*(1-sm((t-TR+50)/110))-.25*snap,
      jaw:.25*ramp(t,1350,1700)*(t<TR?1:0)+.9*sm((t-TR)/60)*(1-sm((t-TR-150)/280)),squint:ch*.4,x:.28*snap-.06*ch,legFrost:.15+.4*ch,tw:.4*snap,tz:.3*ch};},
  fx:(fx,u,E)=>{const {S,tsk,psk}=E;
    IC.sacVapor(fx,u,S,950,TR+200,1);
    // crystal growing between the jaws, then released
    const g=ramp(u,1380,TR-20),rel=TR+45,fly=.0;
    const mouthAt=t=>skel(S.pposeAt(t)).mouth;const dest=chestAt(S,2130),orig=mouthAt(rel),dirF=A(dest,orig).normalize();
    if(u<rel+0){const q=skel(S.pposeAt(u));drawSpikeObj(S,'a',q.mouth.clone().addScaledVector(q.axis,.04),q.axis,.32,.055,g*(u>1380?1:0),.9);}
    else if(u<2130){const e=(u-rel)/(2130-rel),pos=orig.clone().lerp(dest,e).add(V(0,.07*Math.sin(Math.PI*e),0));drawSpikeObj(S,'a',pos,dirF.clone().add(V(0,-.07*(e-.5)*1.3,0)),.5,.06,1,.9);
      trail(fx,u,rel,2130,t=>{const ee=clamp((t-rel)/(2130-rel),0,1);return orig.clone().lerp(dest,ee).add(V(0,.07*Math.sin(Math.PI*ee),0)).addScaledVector(dirF,-.2);},41);}
    else{const age=u-2130,k=1-sm((age-220)/380);drawSpikeObj(S,'a',dest.clone().addScaledVector(dirF,.1),dirF,.5,.06,1,.9*k);}
    // impact: shards, frost bloom
    burst(fx,u,2130,dest,{n:16,speed:2.4,size:.8,seed:5,up:1.1,life:1100});
    if(u>2130){const a=u-2130;fx.ring(dest,.1+.7*ease(a/380),.7*(1-ease(a/380)),'#d6f3ff',true);}
    emit(fx,u,{t0:2130,t1:2700,rate:70,seed:12,life:[500,900],origin:tb=>chestAt(S,tb),vel:r=>V((r()-.3)*.9,.2+.5*r(),(r()-.5)*.9),grav:-.2,drag:1.6,size:[.05,.2],kind:'puff',col:'#e2f6ff',op:.45});
    IC.impactFrost(fx,u,S,2130,1,.9);
  }});
// ================= V2: shard volley =============================================================
const VR=[1700,1770,1840,1915,1985,2055,2125],VT=[0,1,2,3,4,5,6].map(k=>2020+k*58+Math.round((hash(k,9)-.5)*20));
const volley=makeSpike({id:'volley',label:'Shard volley',name:'Pump, shake, spray of small shards',org:'seven finger-length shards flung in a fan, each a small hit',len:6600,
  tag:'The sac pumps five times like a bellows, each pump shivering the head. Then a quick side-to-side head shake sprays seven small shards in a fan. They arrive one after another, each with a flinch and a tiny frost spot: the damage is spread, the slow builds up from the first to the last.',
  hits:VT,dmg:7*3,spot:t=>.8*ramp(t,VT[2],VT[2]+500)*(1-sm((t-5200)/1800)),frostK:.5,
  ph:[['approach',900,'#5d6d78'],['pump x5',800,'#6fb4d8'],['shake + spray',480,'#e0925c'],['hits',620,'#d9576b'],['slowed, recovers',3800,'#7f8c96']],
  perf:t=>{
    const pump=Math.max(...[0,1,2,3,4].map(k=>pls(t,1000+k*170,70))),ch=ramp(t,950,1700),ph=ramp(t,1650,1700)*(1-sm((t-2200)/500)),shake=Math.sin((t-1700)/38)*sm((t-1690)/60)*(1-sm((t-1700-420)/160));
    return {sac:.15+.5*ch*(1-sm((t-1900)/300))+.35*pump,glow:.15+.75*ch*(1-ramp(t,2000,2800)),pulse:pump,crouch:.15*ch*(1-sm((t-2100)/500)),pitch:.07*ch-.05*ph,neckA:.1*pump+.05*ch-.1*ph,neckE:.1*pump+.4*ph,headA:-.15*ph,
      headY:.7*shake,neckY:.35*shake,jaw:.6*ph*(t<2200?1:0)+.5*pump*.4,squint:.5*ch,tw:.3*shake,x:-.03*pump+.12*ph};},
  fx:(fx,u,E)=>{const {S}=E;IC.sacVapor(fx,u,S,950,1800,1.3);
    for(let k=0;k<7;k++){const rel=VR[k]+20,tH=VT[k],mo=skel(S.pposeAt(rel)).mouth;const sp=V(0,(hash(k,4)-.5)*.5-.02,(k-3)/3*.45);
      const dest=chestAt(S,tH).add(V((hash(k,5)-.5)*.1,(hash(k,6)-.5)*.34,(k-3)/3*.28)),dir=A(dest,mo).normalize();
      if(u>=rel-60&&u<rel){const q=skel(S.pposeAt(u));drawSpikeObj(S,'v'+k,q.mouth.clone(),q.axis,.18,.03,ramp(u,rel-60,rel),.9);}
      else if(u>=rel&&u<tH){const e=(u-rel)/(tH-rel);drawSpikeObj(S,'v'+k,mo.clone().lerp(dest,e).add(V(0,.04*Math.sin(Math.PI*e),0)),dir,.22,.032,1,.9);
        trail(fx,u,rel,tH,t=>mo.clone().lerp(dest,clamp((t-rel)/(tH-rel),0,1)),60+k,.5);}
      else if(u>=tH){const age=u-tH;drawSpikeObj(S,'v'+k,dest.clone().addScaledVector(dir,.04),dir,.22,.032,1,.9*(1-sm((age-150)/300)));burst(fx,u,tH,dest,{n:5,speed:1.5,size:.5,seed:30+k,up:.7,life:800});}
      else drawSpikeObj(S,'v'+k,mo,dir,.2,.03,0,0);}
    IC.impactFrost(fx,u,S,VT[3],2,.7);
    emit(fx,u,{t0:VT[0],t1:VT[6]+300,rate:50,seed:15,life:[400,800],origin:tb=>chestAt(S,tb),vel:r=>V((r()-.3)*.7,.2+.4*r(),(r()-.5)*.8),drag:1.6,size:[.04,.16],kind:'puff',col:'#e2f6ff',op:.35});
  }});
// ================= V3: spike from the ground ====================================================
const GX=5.7-.95*2.5;   // target ground position at the strike (2500 ms)
const SPK=[[0,0,1.1,.17,0],[.34,.18,.7,.11,60],[-.3,.22,.62,.1,100],[.12,-.36,.55,.09,140],[-.12,.42,.45,.085,180]];
const eruption=makeSpike({id:'eruption',label:'Ground spike',name:'Stomp, frost line, eruption',org:'a crack of frost races along the ground; spikes burst up under the target',len:6800,
  tag:'The head drops, the sac glows through the throat, a foreleg lifts and stamps. A line of rime shoots across the ground ahead, fern-like, and ice spikes erupt under the target a beat later, one tall and four short, kicking it up and back. The spikes stand for a moment, then crack and fall apart into shards while the frost on the ground fades slowly.',
  hits:[2500],dmg:20,lift:t=>.2*pls(t,2610,150)*(t>2500?1:0),spot:t=>.9*ramp(t,2520,3000)*(1-sm((t-5200)/1800)),frostK:.6,
  ph:[['approach',900,'#5d6d78'],['head drops, glow',700,'#6fb4d8'],['stomp + frost line',700,'#e0925c'],['eruption',500,'#d9576b'],['spikes stand, crack',1500,'#8fb0c8'],['slowed, recovers',2500,'#7f8c96']],
  perf:t=>{
    const ch=ramp(t,900,1600),st=ramp(t,1500,1760)*(1-sm((t-1850)/100)),slam=pls(t,1860,70),rec=1-sm((t-1900)/900);
    return {sac:.12+.8*ch*rec+.04,glow:.1+.9*ch*(1-ramp(t,1950,3200)),crouch:.28*ch*rec+.1*slam,pitch:-.16*ch*rec*.5-.08*slam+.1*st,neckA:-.28*ch*rec,neckE:.2*ch*rec,headA:-.3*ch*rec,jaw:.1*ch*rec,stomp:st,legFrost:.15+.8*ramp(t,1860,2400),squint:.5*ch,x:.05*slam,tz:-.2*ch*rec};},
  fx:(fx,u,E)=>{const {S}=E;IC.sacVapor(fx,u,S,950,1850,1.1);
    // the stamp: ring + frost line racing along z=0 from the foot toward the strike point
    const foot0=.75,tS=1860,tE=2480;
    if(u>=tS){const a=u-tS;fx.ring(V(foot0,.02,.2),.1+1.2*ease(a/500),.8*(1-ease(a/500)),'#d6f3ff');}
    for(let k=0;k<10;k++){const px=foot0+.25+k*(GX-foot0-.1)/9,t0=tS+k*(tE-tS)/10;const g=ease((u-t0)/520);if(u>t0){const fade=1-sm((u-4600-k*40)/2000);fx.frost(px,(hash(k,2)-.5)*.35,.28+.15*g,.85*Math.min(1,g*2)*fade,hash(k,1)*6);}}
    emit(fx,u,{t0:tS,t1:tE,rate:120,seed:31,life:[350,700],origin:tb=>V(foot0+(GX-foot0)*clamp((tb-tS)/(tE-tS),0,1),.04,(hash(Math.round(tb),3)-.5)*.2),vel:r=>V((r()-.5)*.3,.3+.5*r(),(r()-.5)*.3),grav:1.2,drag:1.2,size:[.04,.1],kind:'spark',col:'#e6f9ff',op:.9,spin:5});
    // spikes under the target
    SPK.forEach((s,k)=>{const t0=2500+s[4],g=back((u-t0)/200),dec=u>4150+s[4]?1-sm((u-4150-s[4])/260):1,sc=u<t0?0:g,L=s[2],tilt=V(s[1]*.4,1,s[0]*.0+(k?hash(k,1)-.5:0)*.3);
      drawSpikeObj(S,'g'+k,V(GX+s[1]*.7-.02,-.04,s[3]*1.0*0+s[0]*0+(k===0?0:s[3]*(k%2?1:-1)*1.4)),tilt,L,s[3],Math.max(.001,sc*dec)*(u<t0?0:1),.8);});
    if(u>=2500){const a=u-2500;fx.ring(V(GX,.03,0),.2+1.3*ease(a/420),.9*(1-ease(a/420)),'#e6f9ff');
      burst(fx,u,2500,V(GX,.1,0),{n:12,speed:2.6,size:.9,seed:41,up:2.2,life:1200,spread:V(1,.6,1)});
      emit(fx,u,{t0:2500,t1:3100,rate:60,seed:42,life:[600,1000],origin:tb=>V(GX,.1,0),vel:r=>V((r()-.5)*1.4,.3+.4*r(),(r()-.5)*1.4),drag:1.6,size:[.1,.45],kind:'puff',col:'#e6f6ff',op:.4});}
    burst(fx,u,4150,V(GX,.5,0),{n:20,speed:2.2,size:1,seed:44,up:1.3,life:1500,spread:V(1,.5,1)});
    fx.frost(GX,0,1.05*ease((u-2500)/500),.9*(u<2500?0:1)*(1-sm((u-5200)/1500)),.4);
  }});
// ================= V4: frozen-breath lance ======================================================
const LH=2650,LR=2330;
const lance=makeSpike({id:'lance',label:'Breath lance',name:'Breath condenses, head flick',org:'exhaled vapour crystallises into a lance that is thrown with a flick',len:6800,
  tag:'A long exhale hangs in front of the muzzle and condenses into a growing spear of ice, turning slowly while sparkles gather. The head draws back for a beat of anticipation and flicks forward; the lance leaves with a ring of vapour, spears the target (it stays in the wound for a moment) and bursts into shards, leaving a heavy frost patch.',
  hits:[LH],dmg:24,spot:t=>ramp(t,LH,LH+700)*(1-sm((t-5400)/1800)),frostK:.65,
  ph:[['approach',800,'#5d6d78'],['exhale + condense',1100,'#6fb4d8'],['draw back',430,'#a6b1ff'],['flick + throw',320,'#e0925c'],['hit',700,'#d9576b'],['slowed, recovers',3450,'#7f8c96']],
  perf:t=>{
    const ex=ramp(t,900,1300)*(1-sm((t-2000)/200)),dr=ramp(t,1950,2300),fl=sm((t-LR+30)/70)*(1-sm((t-LR-70)/300)),aft=ramp(t,LR,LR+200)*(1-sm((t-LR-500)/1300));
    return {sac:.15+.85*ramp(t,900,1500)*(1-sm((t-2000)/300)),glow:.1+.9*ramp(t,900,1400)*(1-ramp(t,2250,3000)),pulse:.4*ex*Math.sin(t/70),neckA:.35*ex*(1-dr)+.55*dr*(1-fl)-.16*fl-.08*aft,neckE:.5*ex*(1-dr)-.4*dr*(1-fl)+.7*fl,headA:.2*ex-.1*fl,jaw:.7*ex+.1*dr*(1-fl)+.6*fl*(t<LR+120?1:0),
      crouch:.2*dr*(1-fl),pitch:.1*dr*(1-fl)-.1*fl-.04*aft,squint:.5*ex,x:.22*fl-.04*dr,tw:.3*fl,legFrost:.2+.3*ex};},
  fx:(fx,u,E)=>{const {S}=E;
    // the exhale: a stream of vapour out of the open mouth, condensing
    emit(fx,u,{t0:1000,t1:1800,rate:110,seed:51,life:[700,1100],origin:tb=>skel(S.pposeAt(tb)).mouth,vel:r=>{const q=skel(S.pposeAt(1300)).axis;return V(q.x*.9+(r()-.5)*.3,q.y*.9+(r()-.4)*.25,(r()-.5)*.4);},drag:1.1,size:[.08,.38],kind:'puff',col:'#dff4ff',op:.5});
    // the hovering lance (grows by crystallising) in front of the muzzle
    const q=skel(S.pposeAt(Math.min(u,LR))),g=ramp(u,1250,2050),spin=u/380;
    if(u<LR){const pos=q.mouth.clone().addScaledVector(q.axis,.1+.62*g+.04*Math.sin(u/90)).add(V(0,.0,0));drawSpikeObj(S,'l',pos.clone().addScaledVector(q.axis,.0),q.axis.clone().add(V(0,.0,0)),1.0,.075,g,.88);
      for(let k=0;k<3;k++){const gk=clamp((g-.2-k*.15)*2,0,1);drawSpikeObj(S,'lf'+k,pos.clone().addScaledVector(q.axis,.15+.2*k).add(V(0,.0,0)).add(q.up.clone().multiplyScalar(.04*Math.sin(spin+k*2.1)).add(V(0,0,.05*Math.cos(spin+k*2.1)))),q.axis.clone().add(V(0,.5*Math.sin(spin+k*2.1),.5*Math.cos(spin+k*2.1))),.18,.03,gk,.85);}
      emit(fx,u,{t0:1250,t1:LR,rate:60,seed:52,life:[400,700],origin:tb=>skel(S.pposeAt(tb)).mouth.clone().addScaledVector(skel(S.pposeAt(tb)).axis,.1+.6*ramp(tb,1250,2050)),vel:r=>V((r()-.5)*.5,(r()-.5)*.5,(r()-.5)*.5),drag:2,size:[.04,.09],kind:'spark',col:'#e6f9ff',op:.9,spin:5});}
    else{const mo=skel(S.pposeAt(LR)),orig=mo.mouth.clone().addScaledVector(mo.axis,.72),dest=chestAt(S,LH),dir=A(dest,orig).normalize();
      for(let k=0;k<3;k++)drawSpikeObj(S,'lf'+k,orig,dir,.1,.02,0,0);
      if(u<LH){const e=(u-LR)/(LH-LR),pos=orig.clone().lerp(dest,e).add(V(0,.05*Math.sin(Math.PI*e),0));drawSpikeObj(S,'l',pos,dir,1.0,.075,1,.9);trail(fx,u,LR,LH,t=>orig.clone().lerp(dest,clamp((t-LR)/(LH-LR),0,1)),53,1.4);fx.ring(orig,.15+.9*ease((u-LR)/260),.7*(1-ease((u-LR)/260)),'#d6f3ff',true);}
      else{const a=u-LH,k=1-sm((a-420)/260);drawSpikeObj(S,'l',dest.clone().addScaledVector(dir,.25),dir,1.0,.075,1,.9*k);}
      burst(fx,u,LH,dest,{n:22,speed:3,size:1,seed:55,up:1.2,life:1300});burst(fx,u,LH+680,dest,{n:12,speed:1.8,size:.8,seed:56,up:1,life:1000});
      if(u>LH){const a=u-LH;fx.ring(dest,.1+.9*ease(a/400),.8*(1-ease(a/400)),'#d6f3ff',true);}
      emit(fx,u,{t0:LH,t1:LH+800,rate:70,seed:57,life:[500,900],origin:tb=>chestAt(S,tb),vel:r=>V((r()-.3)*.9,.2+.5*r(),(r()-.5)*.9),grav:-.2,drag:1.6,size:[.06,.24],kind:'puff',col:'#e2f6ff',op:.45});}
    IC.impactFrost(fx,u,S,LH,3,1.1);
  }});
})(window);
