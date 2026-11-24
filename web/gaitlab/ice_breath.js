'use strict';
// Move 2: FROST BREATH -> FREEZE (A85, with the A89 combo "frozen + heavy hit = shatter"). A cone slows the target, then after about 1.5 s inside it the target is
// encased in ice mid-stride. Then either it thaws (drips, cracks, the block shrinks) or a heavy hit shatters it. Four breath looks: misty cone, fine crystal spray,
// hanging cloud, pulse rings. The timeline is shared; each version only changes the performer's breath and the effects.
(function(root){
const IC=root.IC,T=IC.T,BB=IC.BB,{V,clamp,sm,lerp,ramp,win,pls,ease,easeOut,back,hash,emit,burst,skel,TAU}=IC;
const X0=5.0,V0=.9,CONE_END=3.4,TE=Math.round((X0-CONE_END)/V0*1000),FREEZE=TE+1500,GROW=340,THAW=5200,THAWMS=1500,SHDEF=4350,LEN=9000;
function makeBreath(def){
  const rig={move:'breath',id:def.id,label:def.label,name:def.name,org:def.org,tag:def.tag,len:LEN,frozenWin:[FREEZE+GROW*.4,THAW],ph:[['approach, inhale',1000,'#5d6d78'],['breath (cone)',FREEZE-1000,'#6fb4d8'],['frozen',THAW-FREEZE,'#a9dcff'],['thaw / shatter',2200,'#e0925c'],['recover',LEN-THAW-2200,'#7f8c96']]};
  const walk=sa=>{const sh=sa!=null&&sa>FREEZE+GROW*.6,endIce=sh?sa:THAW+THAWMS;
    return IC.makeWalker({x0:X0,v0:V0,dir:-1,t0:0,len:LEN,growMs:GROW,freezeAt:FREEZE,thawAt:THAW,thawMs:THAWMS,shatterAt:sa,flinches:sh?[sa]:[],chill:t=>t<TE?0:(t<endIce?.85*sm((t-TE)/1500):.85*(1-sm((t-endIce)/3500)))});};
  rig.build=scene=>{const S=IC.stage(scene,{bg:'#1d2b35'});S.walkers={};S.wk=sa=>{const k=sa==null?'n':sa|0;return S.walkers[k]||(S.walkers[k]=walk(sa));};
    S.rock=new T.Mesh(IC.GEO.rock,new T.MeshPhongMaterial({color:'#8d8478',flatShading:true,shininess:10,transparent:true}));S.rock.scale.set(.3,.26,.28);S.rock.visible=false;scene.add(S.rock);
    S.pposeAt=t=>IC.perfBase(t,def.perf(t));S.tcache={};return S;};
  rig.cam=(u,ctx)=>{const S=rig.inst;const tx=S?S.wk(shAt(ctx)).at(u).x:5;return {cx:(tx-.25)/2,cy:.5,span:Math.max(4.8,tx+2.4),v:1.8};};
  const shAt=ctx=>ctx.shatter?(ctx.hitT!==null&&ctx.hitT!==undefined?ctx.hitT:SHDEF):null;
  rig.frame=(S,u,ctx)=>{
    const fx=S.fx;fx.reset();const sa=shAt(ctx),W=S.wk(sa),w=W.at(u),sh=w.shatter,tposeAt=(t)=>{const ww=W.at(t);return tpose(ww,t);};
    const chillOf=(ww,t)=>t<TE?0:(ww.frozen||(ww.grow>0&&ww.thaw<1&&!ww.gone)?.85:(ww.thaw>0||t>(sh?sa:THAW+THAWMS)?.85*(1-sm((t-(sh?sa:THAW+THAWMS))/3500)):.85*sm((t-TE)/1500)));
    function tpose(ww,t){const c=chillOf(ww,t),fz=ww.frozen||ww.grow>0&&!ww.gone&&ww.thaw<1?1:0,flv=ww.fl;
      return IC.tgtBase(t,ww,{x:ww.x+.09*flv,crouch:.12*c+.3*Math.min(1,flv),pitch:.1*Math.min(1,flv),neckA:-.15*c+.4*Math.min(1,flv),headA:.2*Math.min(1,flv),jaw:Math.min(1,flv*.8),squint:Math.min(1,c*.8+flv),stiff:c,cold:c,frost:Math.min(1,c*.8+(fz?.15:0))*(sh&&ww.gone?Math.max(0,1-ww.sAge/1500):1),legFrost:c,shiver:fz?0:c*.9+.4*Math.min(1,flv),flash:ww.gone&&ww.sAge<140?.8*(1-ww.sAge/140):0,c,ww});}
    const tp=tposeAt(u,w),pp=S.pposeAt(u),psk=skel(pp),tsk=skel(tp);S.tposeAt=tposeAt;
    IC.drawQuad(S.perf,pp);IC.drawQuad(S.tgt,tp);
    const grow=w.grow,thaw=w.thaw,crack=sh&&u>=sa?0:Math.max(ramp(u,THAW-300,THAW+800)*(sh?0:1),sh&&u>=sa-120?1:0);
    // heavy hit: boulder drops onto the block (shatter ending)
    let impact=0;if(sh){const a=u-(sa-260);S.rock.visible=a>=0&&a<1500;if(S.rock.visible){if(a<260){const e=a/260;S.rock.position.set(w.x+.05,lerp(3.4,.7,e*e),.0);S.rock.rotation.set(a/200,a/260,0);S.rock.material.opacity=1;}else{const b=(a-260)/1000;S.rock.position.set(w.x+.05+.6*b,.3+.5*Math.abs(Math.sin(b*3.6))*Math.exp(-b*2)+(.35-.3)*0,.1+.2*b);S.rock.rotation.set(a/90,a/110,0);S.rock.material.opacity=1-sm((a-760)/500);}}impact=u>=sa&&u<sa+300?1-(u-sa)/300:0;}else S.rock.visible=false;
    const shake=impact?impact:0;
    IC.drawShell(S.shell,{x:tp.x,y:0,z:0,yaw:Math.PI,s:.92,t:u},sh&&u>=sa?0:grow,sh?0:thaw,crack,(u<FREEZE+GROW+300&&u>=FREEZE?1:0)+(sh&&u>=sa-300&&u<sa?.6:0));
    // idle vapour
    emit(fx,u,{t0:0,t1:LEN,rate:.55,seed:3,life:[900,1400],origin:tb=>skel(S.pposeAt(tb)).nose,vel:r=>V(.25+.1*r(),.12+.1*r(),(r()-.5)*.1),drag:1.2,size:[.06,.26],kind:'puff',col:'#d8f1ff',op:.26});
    if(!w.frozen)emit(fx,u,{t0:0,t1:LEN,rate:.45,seed:4,life:[800,1200],origin:tb=>skel(S.tposeAt(tb)).nose,vel:r=>V(-.2-.1*r(),.1+.08*r(),(r()-.5)*.1),drag:1.3,size:[.05,.2],kind:'puff',col:'#f4fbff',op:.1});
    IC.sacVapor(fx,u,S,450,1000,1.2);
    def.fx(fx,u,{S,pp,psk,tp,tsk,w,sh,sa,TE,FREEZE});
    // the target in the cone: chill shiver puffs; the freezing moment; shimmer while frozen; drips and steam while thawing; the shatter
    const ctr=t=>V(S.tposeAt(t).x,.42,0);
    const fz0=FREEZE+GROW*.35;
    if(u>=FREEZE&&u<FREEZE+900){const a=u-FREEZE,c0=V(S.tposeAt(FREEZE).x,.4,0);fx.ring(V(c0.x,.03,0),.2+1.3*ease(a/450),.9*(1-ease(a/450)),'#e6f9ff');
      emit(fx,u,{t0:FREEZE,t1:FREEZE+360,rate:200,seed:61,life:[400,800],origin:tb=>V(c0.x+(hash(Math.round(tb),1)-.5)*.9,.12+hash(Math.round(tb),2)*.6,(hash(Math.round(tb),3)-.5)*.45),vel:r=>V((r()-.5)*.4,(r()-.2)*.5,(r()-.5)*.4),drag:2,size:[.05,.13],kind:'spark',col:'#f0fcff',op:.95,spin:5});}
    if(grow>.9&&!(sh&&u>=sa)&&thaw<.4)emit(fx,u,{t0:FREEZE+300,t1:Math.min(sh?sa:THAW+THAWMS,LEN),rate:11,seed:62,life:[500,900],origin:tb=>{const c=ctr(tb);return V(c.x+(hash(Math.round(tb),4)-.5)*1.1,.1+hash(Math.round(tb),5)*.7,(hash(Math.round(tb),6)-.5)*.5);},vel:r=>V(0,.05,0),size:[.05,.12],kind:'spark',col:'#ffffff',op:.95,spin:2});
    if(!sh&&u>=THAW){const tt=Math.min(sh?1e9:THAW+THAWMS,LEN);emit(fx,u,{t0:THAW,t1:THAW+THAWMS+500,rate:24,seed:63,life:[500,800],origin:tb=>{const c=ctr(tb);return V(c.x+(hash(Math.round(tb),7)-.5)*.9,.25+hash(Math.round(tb),8)*.35,(hash(Math.round(tb),9)>.5?.2:-.2));},vel:r=>V(0,0,0),grav:9,size:[.03,.025],kind:'glow',col:'#7fcdf0',op:.9});
      emit(fx,u,{t0:THAW,t1:THAW+THAWMS+800,rate:14,seed:64,life:[900,1500],origin:tb=>{const c=ctr(tb);return V(c.x+(hash(Math.round(tb),10)-.5)*.8,.3+hash(Math.round(tb),11)*.2,0);},vel:r=>V((r()-.5)*.15,.18+.12*r(),(r()-.5)*.15),drag:.6,size:[.08,.3],kind:'puff',col:'#e3f2fa',op:.18});}
    if(sh&&u>=sa){burst(fx,u,sa,V(w.x,.4,0),{n:38,speed:3.6,size:1.5,seed:77,up:2,life:1700,spread:V(1.2,.9,.8)});fx.ring(V(w.x,.35,0),.2+1.5*ease((u-sa)/360),.9*(1-ease((u-sa)/360)),'#ffffff',true);}
    // ground ice under the target: frozen puddle, grows with the freeze
    const gk=Math.max(grow*(1-thaw*.5),0);if(gk>0&&!(sh&&u>=sa)){fx.frost(tp.x,0,.55+.55*easeOut(grow),.9*(1-sm((thaw-.3)/.7)),.7);}
    if(sh&&u>=sa)fx.frost(w.x,0,1.0,.8*(1-sm((u-sa-900)/3000)),.7);
    fx.flush();
    // HUD
    const expo=clamp((u-TE)/1500,0,1),st=sh&&u>=sa?'<b class="bad">SHATTERED</b> frozen + heavy hit: <b class="bad">x1.6 damage</b>':w.frozen||(grow>0&&thaw<1&&!w.gone)?(thaw>.05?'<b class="ice">thawing</b>':'<b class="ice">FROZEN</b>'):u<TE?'walking toward you':expo<1&&u<FREEZE?'<b class="ice">chilled, slowing</b>':u<THAW?'free':'recovering';
    return {hud:`<div><span class="k">Cone exposure</span> <b>${(expo*1.5).toFixed(1)} s</b> / 1.5</div><div class="mt"><div style="width:${(u>=FREEZE&&!(w.frozen||grow>0)?0:expo)*100}%"></div></div><div><span class="k">Speed</span> <b>${Math.round(100*(1-.88*tp.c))}%</b></div><div><span class="k">State</span> ${st}</div>`,
      banner:sh&&u>=sa&&u<sa+450?'SHATTER':(u>=FREEZE&&u<FREEZE+700?'FROZEN':''),bannerK:sh&&u>=sa?1-(u-sa)/450:1-(u-FREEZE)/700,shake:shake};
  };
  IC.rigs.breath.push(rig);return rig;}
// ---- performer breath envelope shared by the versions: inhale, blow, exhale slump
function perfBreath(t,o){o=o||{};const ch=ramp(t,450,1000),bl=o.blow?o.blow(t):ramp(t,1000,1150)*(1-sm((t-(o.end||3900))/260)),ex=ramp(t,o.end||3900,(o.end||3900)+400)*(1-sm((t-(o.end||3900)-500)/1000));
  return {sac:(.12+.85*ch*(1-.8*ramp(t,1000,o.end||3900)))*(o.sacK||1),glow:.1+.9*ch*(1-.55*ramp(t,1000,o.end||3900))*(1-ramp(t,o.end||3900,(o.end||3900)+900)),pulse:o.pulse?o.pulse(t):bl*.45*Math.sin(t/55),
    neckA:.28*ch*(1-bl)-.1*bl+.18*ex,neckE:-.22*ch*(1-bl)+.55*bl,headA:-.12*bl,jaw:(o.jaw||.5)*bl+.15*ex,crouch:.2*ch*(1-bl)+.12*bl+.05*ex,pitch:.1*ch*(1-bl)-.05*bl+.05*ex,squint:.5*bl+.3*ch,legFrost:.15+.3*bl,x:-.06*ch*(1-bl)+.05*bl,tz:.2*bl};}
IC.perfBreath=perfBreath;
const mouthAt=(S,t)=>skel(S.pposeAt(t));
const dirAt=(S,t,drop)=>{const q=mouthAt(S,t),a=q.axis.clone();a.y=a.y*.3-(drop||.1);return a.normalize();};
// ground frost laid along the cone footprint; stations appear progressively
function coneGround(fx,u,t0,t1,x0,x1,half,n,seed,fade){for(let k=0;k<n;k++){const f=k/(n-1),t=lerp(t0,t1,f),px=lerp(x0,x1,f),g=ease((u-t)/700);if(u>t){const w=half*(.35+.65*f);fx.frost(px+(hash(k,seed)-.5)*.2,(hash(k,seed+1)-.5)*w,.3+.22*f,.9*Math.min(1,g*2)*(1-sm((u-(fade||THAW+500)-k*60)/2200)),hash(k,seed+2)*6);}}}
// ================= B1 misty cone + frost spreading on the ground ====================================
makeBreath({id:'mist',label:'Misty cone',name:'Billowing mist, frost on the ground',org:'a wide soft cone of cold fog; rime spreads over the grass in its footprint',
  tag:'A deep inhale lifts the chest and fills the sac; then a long steady exhale rolls out a billowing cone of fog that thins at the far end. Where it lands, ferny rime spreads across the ground ahead of the target. The target slows, its legs whiten first, then the ice grows over it mid-stride; it holds, then thaws with drips and steam, or shatters when hit hard.',
  perf:t=>perfBreath(t,{jaw:.5}),
  fx:(fx,u,E)=>{const {S}=E,R=(tb)=>mouthAt(S,tb);
    emit(fx,u,{t0:1050,t1:3950,rate:210,seed:71,life:[1300,2000],origin:tb=>R(tb).mouth,vel:r=>{const d=dirAt(S,1500,.08);return V(d.x*4.2*(.7+.5*r())+0,d.y*3+(r()-.5)*.7,(r()-.5)*1.5);},drag:1.0,grav:-.12,size:[.15,1.15],kind:'puff',col:'#e0f0f9',op:.5,hold:.55});
    emit(fx,u,{t0:1050,t1:3950,rate:55,seed:72,life:[800,1400],origin:tb=>R(tb).mouth,vel:r=>V(5*(.5+.6*r()),(r()-.5)*.9,(r()-.5)*1.8),drag:.9,size:[.03,.08],kind:'spark',col:'#eefaff',op:.8,spin:4});
    coneGround(fx,u,1250,3300,1.1,3.7,1.3,14,9);}});
// ================= B2 fine crystalline spray =========================================================
makeBreath({id:'spray',label:'Crystal spray',name:'Narrow, glittering, fast',org:'a tight hissing jet of ice dust that glitters in the light',
  tag:'A short sharp inhale, then a narrow, fast jet of fine ice crystals: thousands of sparkles instead of fog, hissing out of a barely open mouth. Less area, more precision. Fine white rime builds up on the target\'s fur from the front, it slows, stiffens and is encased the same way; the block catches the light in many small glints.',
  perf:t=>perfBreath(t,{jaw:.28}),
  fx:(fx,u,E)=>{const {S,tp}=E,R=tb=>mouthAt(S,tb);
    emit(fx,u,{t0:1050,t1:3950,rate:190,seed:81,life:[500,900],origin:tb=>R(tb).mouth,vel:r=>{const d=dirAt(S,1500,.06);const a=(r()-.5)*.28,b=(r()-.5)*.28;return V(d.x*(5.5+3*r()),d.y*4+a*1.2,b*5);},drag:.65,grav:.6,size:[.05,.12],kind:'spark',col:'#ffffff',op:.95,spin:6,hold:.5});
    emit(fx,u,{t0:1050,t1:3950,rate:70,seed:82,life:[700,1100],origin:tb=>R(tb).mouth,vel:r=>{const d=dirAt(S,1500,.06);return V(d.x*(5+2*r()),d.y*4,(r()-.5)*.9);},drag:.7,size:[.07,.2],kind:'flake',col:'#e8f8ff',op:.8,spin:3});
    emit(fx,u,{t0:1050,t1:3950,rate:60,seed:83,life:[900,1500],origin:tb=>R(tb).mouth,vel:r=>{const d=dirAt(S,1500,.06);return V(d.x*4.5,d.y*3.2,(r()-.5)*.9);},drag:.9,size:[.08,.45],kind:'puff',col:'#d6eaf5',op:.16});
    // glitter collecting on the target while it is in the jet
    emit(fx,u,{t0:TE,t1:FREEZE+100,rate:40,seed:84,life:[500,900],origin:tb=>{const c=skel(S.tposeAt(tb)).chest;return V(c.x+(hash(Math.round(tb),3)-.5)*.5,.15+hash(Math.round(tb),4)*.5,(hash(Math.round(tb),5)-.5)*.4);},vel:r=>V(0,.05,0),size:[.05,.1],kind:'spark',col:'#ffffff',op:.95,spin:5});
    coneGround(fx,u,1250,3300,1.4,3.6,.6,10,19);}});
// ================= B3 puff that hangs as a freezing cloud ===========================================
const CLX=2.7;
makeBreath({id:'cloud',label:'Hanging cloud',name:'A puff that stays and freezes',org:'one big breath that hangs in the air as a cold, slowly swirling cloud',
  tag:'One hard gust, shorter than the others, throws a dense puff ahead. It does not blow past: it blooms into a hanging cloud that swirls slowly, glittering, with a frost disc spreading on the ground under it. The target walks into the cloud and freezes inside it; the cloud lingers a while after, then drifts apart. The creature itself can step aside: the cloud does the work.',
  perf:t=>perfBreath(t,{end:1800,jaw:.65,sacK:1}),
  fx:(fx,u,E)=>{const {S}=E;
    emit(fx,u,{t0:1050,t1:1600,rate:160,seed:91,life:[500,800],origin:tb=>mouthAt(S,tb).mouth,vel:r=>{const d=dirAt(S,1400,.1);return V(d.x*(4.2+r()*1.6),d.y*3,(r()-.5)*.8);},drag:.9,size:[.15,.7],kind:'puff',col:'#cfe7f4',op:.4});
    // the hanging cloud: many large soft puffs orbiting slowly around its centre, building 1400..2200, held, thinning 4700..6300
    const buil=ramp(u,1350,2300),thin=1-sm((u-4700)/1600),k=buil*thin;
    for(let i=0;i<30;i++){const a0=hash(i,1)*TAU,rr=.25+.9*hash(i,2)*Math.sqrt(buil),sp=.35+.3*hash(i,3),aa=a0+u/1000*sp,yy=.12+.85*hash(i,4)*(.7+.3*buil)+.05*Math.sin(u/700+i),dx=Math.cos(aa)*rr*1.05,dz=Math.sin(aa)*rr*.55;
      fx.spr('puff',V(CLX+dx,yy,dz),(.55+.55*hash(i,5))*(.4+.6*buil),.3*k*(i<24?1:.6),i%3?'#c6e1f0':'#e6f4fb',aa);}
    for(let i=0;i<14;i++){const a0=hash(i,11)*TAU,aa=a0+u/700,rr=.2+.9*hash(i,12);fx.spr('spark',V(CLX+Math.cos(aa)*rr,.1+.9*hash(i,13)+.08*Math.sin(u/300+i),Math.sin(aa)*rr*.5),.08+.05*Math.sin(u/200+i*2),.9*k*(.5+.5*Math.sin(u/190+i*3)),'#ffffff',u/300);}
    for(let k2=0;k2<6;k2++){const t0=1500+k2*280,g=ease((u-t0)/800),a=hash(k2,31)*TAU,rr=k2?.55*hash(k2,32)*1.2:0;if(u>t0)fx.frost(CLX+Math.cos(a)*rr,Math.sin(a)*rr*.6,.55+.35*g,.9*Math.min(1,g*2)*(1-sm((u-5800-k2*120)/2400)),hash(k2,33)*6);}
  }});
// ================= B4 pulse rings ====================================================================
const PUL=[1000,1450,1900,2350,2800,3250];
makeBreath({id:'pulse',label:'Pulse rings',name:'Rhythmic cold pulses, a ring each',org:'six short exhales; each sends a ring of cold that sweeps the cone',
  tag:'Instead of one long breath: six short chuffs, the head punching forward and the sac pumping on each. Every chuff throws an expanding frost ring through the cone, leaving a puff of vapour and a rime ring on the ground. The target shudders as each ring passes; the chill builds ring after ring until it is locked in ice. Good for a rhythm or tap-to-hold feel.',
  perf:t=>{const bl=Math.max(...PUL.map(p=>pls(t,p+60,70)));const b=perfBreath(t,{blow:t=>Math.max(...PUL.map(p=>pls(t,p+60,70))),end:3600,jaw:.7,pulse:t=>Math.max(...PUL.map(p=>pls(t,p+50,50)))});b.sac=(.12+.85*ramp(t,450,1000)*(1-.7*ramp(t,1000,3500)))+.2*bl;return b;},
  fx:(fx,u,E)=>{const {S}=E;
    PUL.forEach((p,k)=>{const a=u-(p+90);if(a<0||a>1200)return;const q=mouthAt(S,p+90),o=q.mouth.clone(),d=dirAt(S,p+90,.08),e=a/760,r=.06+.9*Math.min(1,e*.9),x=Math.min(3.9,.1+4.4*easeOut(Math.min(1,e)));
      const f=1-sm((a-480)/700);fx.ring(o.clone().addScaledVector(d,x).setY(lerp(o.y,.5,Math.min(1,e))),.06+.95*Math.min(1,e*1.1),.85*f,'#cfeeff',true);if(a>90)fx.ring(o.clone().addScaledVector(d,Math.max(.1,x-.42)).setY(lerp(o.y,.5,Math.min(1,e))),.05+.8*Math.min(1,e*1.1),.5*f,'#ffffff',true);
      fx.ring(V(1.0+x*.8,.025,0),.1+.9*Math.min(1,e*1.1)*Math.min(1.2,.4+x*.35),.6*f,'#bfeaff');
      emit(fx,u,{t0:p+60,t1:p+240,rate:90,seed:100+k,life:[500,900],origin:tb=>mouthAt(S,tb).mouth,vel:r=>{const dd=dirAt(S,p+90,.08);return V(dd.x*(3.4+2*r()),dd.y*2.4,(r()-.5)*1.4);},drag:1.2,size:[.1,.6],kind:'puff',col:'#d3ecf8',op:.4});});
    emit(fx,u,{t0:1000,t1:3500,rate:46,seed:111,life:[500,900],origin:tb=>mouthAt(S,tb).mouth,vel:r=>V(3.5+3*r(),(r()-.5)*.7,(r()-.5)*1.2),drag:1,size:[.04,.09],kind:'spark',col:'#eefaff',op:.8,spin:4});
    coneGround(fx,u,1250,3400,1.1,3.6,1.1,12,29);}});
})(window);
