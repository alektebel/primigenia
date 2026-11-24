'use strict';
// Body 1: ARMED creature = starter-B-like quadruped (beak "pico", crest "cresta") + two arm_grasper hands (A58) + a throat sac and an extensible frill (tier 2).
// sing = trill + throat sac + chest-beat with the hands | dance = diagonal stomps + claps + hand waves | charm = offer food with both hands | pose = frill flare, arms flung wide.
(function(){
const BB=window.BB,T=BB.T,{V,clamp,sm,lerp,env,bump,bumps,ik,qEul,lam,place,ell,limb,taper,coneX,GEO,X,Y,Z,FY}=BB;
const H0=.68,HR=.09; // body height at rest, head radius
const SK='#b98f5a',DK='#5a4026',PL='#eadfc4',CR0='#5a4026',CR1='#d8613c';
const HIP=[[-.30,-.10,-.14],[-.30,-.10,.14],[.30,-.08,-.15],[.30,-.08,.15]];           // HL HR FL FR (z+ = right)
const FOOT=[[-.30,-.17],[-.30,.17],[.34,-.17],[.34,.17]];
const SEG=[[.32,.32],[.32,.32],[.32,.32],[.32,.32]],SHO=[[.36,.06,-.19],[.36,.06,.19]],ARM=[.26,.26],NB=[.46,.2,0],NK=[.2,.2];
const REST_H=[V(.52,-.10,-.24),V(.52,-.10,.24)],CHEST=[V(.50,.03,-.10),V(.50,.03,.10)];
function build(scene){
  const skin=lam(SK),dark=lam(DK),pale=lam(PL),beakU=lam('#d8c58a'),beakL=lam('#bfa86e'),eyeW=lam('#f4f1e8'),eyeP=lam('#121416'),hoof=lam('#3c2e20'),crestM=lam(CR0),throatM=lam('#e8b59a'),frillM=lam('#d9703f',{side:T.DoubleSide}),spokeM=lam('#5a2a1c');
  const o={crestM,frillM,throatM,fx:BB.FXPool(scene)};
  o.body=new T.Group();scene.add(o.body);
  ell(o.body,skin,.27,.21,.19).position.set(-.30,0,0);ell(o.body,skin,.30,.22,.2).position.set(0,.01,0);const ch=ell(o.body,skin,.25,.23,.2);ch.position.set(.31,.05,0);o.chest=ch;
  ell(o.body,pale,.42,.1,.16).position.set(0,-.14,0);
  for(let k=0;k<5;k++){const s=ell(o.body,dark,.09,.05,.07);s.position.set(.34-k*.16,.22-.01*k+(k>3?-.03:0),0);}
  o.tail=[0,1].map(()=>limb(scene,skin,.07,.04));o.tailN=[0,1,2].map((_,i)=>ell(scene,skin,[.07,.05,.035][i],[.07,.05,.035][i],[.07,.05,.035][i]));
  o.neck=[0,1].map(()=>limb(scene,skin,.09,.07));o.nodes=[.095,.075,.07].map(r=>ell(scene,skin,r,r,r));
  const head=o.head=new T.Group();scene.add(head);ell(head,skin,HR*1.2,HR,HR*.95);
  for(const s of [-1,1]){const w=ell(head,eyeW,HR*.26,HR*.26,HR*.2);w.position.set(HR*.3,HR*.35,s*HR*.8);const p=ell(head,eyeP,HR*.12,HR*.14,HR*.1);p.position.set(HR*.45,HR*.35,s*HR*.96);}
  o.crest=[];for(let k=0;k<3;k++){const c=new T.Mesh(new T.ConeGeometry(HR*.2,HR*(.9-k*.2),8),crestM);c.position.set(-HR*(.1+k*.45),HR*(1.0-k*.08),0);c.rotation.z=.9+k*.15;head.add(c);o.crest.push({m:c,base:.9+k*.15,len:.9-k*.2,y:1.0-k*.08});}
  const len=.17;o.up=new T.Group();o.lo=new T.Group();head.add(o.up,o.lo);o.up.position.set(HR*.7,0,0);o.lo.position.set(HR*.7,-.012,0);
  const u=new T.Mesh(coneX(HR*.5,len),beakU);u.scale.set(1,.85,1.05);o.up.add(u);const l=new T.Mesh(coneX(HR*.36,len),beakL);l.scale.set(1,.8,.95);o.lo.add(l);
  o.mouth=ell(head,lam('#7a1f26'),len*.42,.01,HR*.36);o.mouth.position.set(HR*.7+len*.45,-.005,0);
  o.beakLen=len;o.tipLocal=V(HR*.7+len,0,0);
  o.throat=ell(scene,throatM,.05,.05,.05);
  // extensible frill: a fan membrane behind the head with dark ribs (flat, facing forward)
  o.frill=new T.Group();head.add(o.frill);o.frill.position.set(-HR*.7,HR*.1,0);o.frill.rotation.y=Math.PI/2;
  const fan=new T.Mesh(new T.CircleGeometry(1,28,-.35,Math.PI+.7),frillM);o.frill.add(fan);o.fan=fan;
  o.ribs=[];for(let k=0;k<9;k++){const a=-.35+(Math.PI+.7)*k/8,r=new T.Mesh(new T.CylinderGeometry(.018,.018,1,5),spokeM);r.userData.a=a;o.frill.add(r);o.ribs.push(r);}
  o.rim=new T.Mesh(new T.RingGeometry(.9,1,28,1,-.35,Math.PI+.7),lam('#f0c36a',{side:T.DoubleSide}));o.frill.add(o.rim);
  o.legs=[];for(let i=0;i<4;i++){const m=i%2===0?lam('#8f6f44'):skin,up=limb(scene,m,.055,.04),lo=limb(scene,m,.04,.028),kn=ell(scene,lam('#6e5230'),.045,.045,.045),ft=ell(scene,hoof,.07,.03,.05);o.legs.push({up,lo,kn,ft});}
  // arms with grasper hands
  o.arms=[0,1].map(s=>{const m=lam(s?'#7a5535':'#6a4a2c'),up=limb(scene,m,.065,.052),lo=limb(scene,m,.052,.04),el=ell(scene,m,.055,.055,.055),sh=ell(scene,m,.07,.07,.07);
    const hand=new T.Group();scene.add(hand);ell(hand,pale,.07,.048,.062);const fing=[];
    for(let i=0;i<3;i++){const f=new T.Group();f.position.set(.055,0,(i-1)*.034);hand.add(f);const c=new T.Mesh(coneX(.02,.11,6),dark);f.add(c);fing.push(f);}
    const th=new T.Group();th.position.set(.0,-.01,s?.045:-.045);hand.add(th);th.add(new T.Mesh(coneX(.02,.08,6),dark));fing.push(th);
    return {up,lo,el,sh,hand,fing,s};});
  const fr=new T.Group();ell(fr,lam('#e0452e'),.075,.07,.075);const lf=new T.Mesh(new T.ConeGeometry(.02,.07,5),lam('#5f9a46'));lf.position.set(0,.06,0);lf.rotation.z=.5;fr.add(lf);scene.add(fr);o.fruit=fr;
  const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.003;scene.add(sh);o.shadow=sh;
  return o;
}
const footH=(g,tk,h)=>{const u=(g-(tk-240))/240;return (u<=0||u>=1)?0:h*Math.sin(Math.PI*Math.pow(u,1.6));};
function pose(act,g){
  const G=BB.GAME[act],W=G.W,ts=W+G.A,tb=W;
  const P={by:0,pitch:0,roll:0,yaw:0,hx:.34,hy:.12,hp:0,hyaw:0,hroll:0,gape:0,thr:0,chest:0,crest:0,frill:0,shim:0,tailY:.2*Math.sin(g/760),fl:[0,0,0,0],open:[.3,.3],prop:0,hand:[REST_H[0].clone(),REST_H[1].clone()],arcs:[]};
  P.by=.004*Math.sin(g/520);
  let obs=0;
  if(act==='sing'){
    const e=env(g,-300,ts+400,500,500),n=bumps(g,W,3,300,60),wL=Math.max(bump(g,W,70),bump(g,W+600,70)),wR=bump(g,W+300,70);
    P.pitch=.12*e;P.hy=.12+.2*e;P.hx=.34-.07*e;P.hp=.5*e-.0;P.gape=.9*n;P.thr=.2*e+.8*n;P.chest=.25*e+.75*n;P.crest=.55*e;P.by+=.012*n;P.tailY+=.2*Math.sin(g/200)*e;
    const outL=V(.56,.20,-.32),outR=V(.56,.20,.32);
    P.hand[0].lerp(outL,e).lerp(CHEST[0],wL);P.hand[1].lerp(outR,e).lerp(CHEST[1],wR);P.open=[.5*e*(1-wL),.5*e*(1-wR)];
    obs=P.thr;
    for(let k=0;k<3;k++)P.arcs.push(W+300*k);
  }else if(act==='dance'){
    const ks=[0,1,2,3,4];let bd=0,clap=0,wave=0;
    for(const k of ks){const tk=W+300*k,A=k%2===0;const fa=A?[3,0]:[2,1];for(const i of fa)P.fl[i]+=footH(g,tk,.14);bd=Math.max(bd,bump(g,tk,70));if(A)clap=Math.max(clap,bump(g,tk,60));else wave=Math.max(wave,bump(g,tk,80));}
    const e=env(g,W-420,W+300*4+400,380,400);
    P.by-=.045*bd*e;P.roll=.08*Math.cos(Math.PI*(g-W)/300)*e*0+.075*Math.cos(Math.PI*(g-W)/300)*e;P.yaw=.1*Math.sin(Math.PI*(g-W)/300+Math.PI/2)*e*.0+.08*Math.sin(Math.PI*(g-W)/300)*e;
    P.hy=.12+.04*bd*0-.05*bd*e;P.hroll=.2*Math.cos(Math.PI*(g-W)/300)*e;P.tailY+=.5*Math.sin(Math.PI*(g-W)/150)*e;P.chest=.3*bd;
    const spread=[V(.5,.32,-.30),V(.5,.32,.30)],clapP=[V(.62,.22,-.035),V(.62,.22,.035)],upP=[V(.42,.64,-.34),V(.42,.64,.34)];
    for(let s=0;s<2;s++){P.hand[s].lerp(spread[s],e).lerp(clapP[s],clap).lerp(upP[s],wave);P.open[s]=.9*e*(1-clap);}
    P.hand[0].y+=.04*Math.sin(Math.PI*(g-W)/300)*e;P.hand[1].y-=.04*Math.sin(Math.PI*(g-W)/300)*e;
    obs=P.fl[3];
  }else if(act==='charm'){
    const r=sm((g+440)/600),back=sm((g-ts-1200)/900),q=r*(1-back),sw=Math.cos(2*Math.PI*(g-W)/600)*sm((g-W)/200)*(1-back);
    const offer=[V(.78,.04,-.075),V(.78,.04,.075)];
    for(let s=0;s<2;s++){P.hand[s].lerp(CHEST[s],clamp((g+900)/400,0,1)).lerp(offer[s],q);P.hand[s].y+=.03*sw;P.open[s]=.1+.5*q;}
    P.pitch=-.08*q;P.by-=.03*q;P.hy=.12+.05*q;P.hp=.12*q;P.hroll=.25*q;P.hx=.34-.06*q;P.tailY+=.4*Math.sin(g/180)*q;P.crest=.3*q;
    P.prop=1;obs=r;
  }else{
    const f=sm((g+226)/700),back=sm((g-ts-1800)/800),s_=f*(1-back);
    P.frill=s_;P.shim=Math.max(bump(g,tb+300,90),bump(g,tb+600,90),bump(g,tb+900,90))*f;P.pitch=.1*s_;P.hy=.12+.2*s_;P.hx=.34-.05*s_;P.hp=.2*s_;P.chest=.6*s_;P.crest=1*s_;P.thr=.15*s_;P.by+=.02*s_;
    const out=[V(.38,.52,-.36),V(.38,.52,.36)];for(let s=0;s<2;s++){P.hand[s].lerp(out[s],s_);P.open[s]=1*s_;}
    obs=f;
  }
  return fin(P,act,g,obs);
}
function fin(P,act,g,obs){
  const Qb=qEul(P.yaw,P.pitch,P.roll),c=V(0,H0+P.by,0),W=l=>V(l[0],l[1],l[2]).applyQuaternion(Qb).add(c),Wv=v=>v.clone().applyQuaternion(Qb).add(c);
  const nodes=[],anchors=[];
  const nb=W(NB),head=W([NB[0]+P.hx,NB[1]+P.hy,0]),ng=ik(nb,head,NK[0],NK[1],V(.3,1,0).normalize().applyQuaternion(Qb));
  const Qh=Qb.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,P.hp)).multiply(new T.Quaternion().setFromAxisAngle(Y,P.hyaw)).multiply(new T.Quaternion().setFromAxisAngle(X,P.hroll));
  const S={P,Qb,c,nb,neckMid:ng.knee,head:ng.foot.clone(),Qh,obs,nodes,anchors,act,g,legErr:0,arcs:P.arcs};
  S.axis=X.clone().applyQuaternion(Qh);S.tip=S.head.clone().add(V(.7*HR+S.P.gape*0,0,0).applyQuaternion(Qh)).addScaledVector(S.axis,.17);
  S.hips=[];S.knees=[];S.feet=[];
  const ids=['HL','HR','FL','FR'];
  for(let i=0;i<4;i++){const hip=W(HIP[i]),ft=V(FOOT[i][0],FY+P.fl[i],FOOT[i][1]),fore=i>=2,pole=V(fore?-1:1,0,0).applyQuaternion(Qb),r=ik(hip,ft,SEG[i][0],SEG[i][1],pole);
    if(r.knee.y<.04)r.knee.y=.04;S.hips.push(hip);S.knees.push(r.knee);S.feet.push(r.foot);S.legErr=Math.max(S.legErr,r.err);
    anchors.push({id:ids[i],p:r.foot.clone(),on:P.fl[i]<.002});nodes.push({p:r.knee,r:.04},{p:r.foot,r:.03});}
  S.arm=[];
  for(let s=0;s<2;s++){const sh=W(SHO[s]),hp=Wv(P.hand[s]),pole=V(-.3,-.6,s?1:-1).normalize().applyQuaternion(Qb),r=ik(sh,hp,ARM[0],ARM[1],pole);S.arm.push({sh,el:r.knee,hand:r.foot,open:P.open[s]});nodes.push({p:r.knee,r:.03},{p:r.foot,r:.035});}
  nodes.push({p:head,r:HR*.9});
  S.tailPts=[W([-.5,.05,0])];{const qa=new T.Quaternion().setFromEuler(new T.Euler(0,P.tailY,.1,'YZX')),Qt=Qb.clone().multiply(qa);S.tailPts.push(S.tailPts[0].clone().addScaledVector(V(-1,0,0).applyQuaternion(Qt),.26));const Q2=Qt.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,-.25-.3*P.tailY));S.tailPts.push(S.tailPts[1].clone().addScaledVector(V(-1,0,0).applyQuaternion(Q2),.24));}
  for(const p of S.tailPts)nodes.push({p,r:.03});
  for(const q of [[-.30,0,0],[0,.01,0],[.31,.05,0]])nodes.push({p:W(q),r:.2});
  S.fruitP=S.arm[0].hand.clone().lerp(S.arm[1].hand,.5).add(V(0,.07,0));
  return S;
}
function draw(o,S,act,g){
  const P=S.P;o.body.position.copy(S.c);o.body.quaternion.copy(S.Qb);
  o.chest.scale.set(.25*(1+.08*P.chest),.23*(1+.2*P.chest),.2*(1+.2*P.chest));
  place(o.tail[0],S.tailPts[0],S.tailPts[1]);place(o.tail[1],S.tailPts[1],S.tailPts[2]);S.tailPts.forEach((p,i)=>o.tailN[i].position.copy(p));
  place(o.neck[0],S.nb,S.neckMid);place(o.neck[1],S.neckMid,S.head);o.nodes[0].position.copy(S.nb);o.nodes[1].position.copy(S.neckMid);o.nodes[2].position.copy(S.head);
  o.head.position.copy(S.head);o.head.quaternion.copy(S.Qh);
  o.up.rotation.z=P.gape*.34;o.lo.rotation.z=-.03-P.gape*.62;o.mouth.visible=P.gape>.12;o.mouth.scale.set(o.beakLen*.42,.006+.04*P.gape,HR*.36);
  o.crest.forEach((c,k)=>{c.m.rotation.z=c.base+(.12+.12*k-c.base)*P.crest;c.m.scale.set(1+.4*P.crest,1+1.1*P.crest,1+.4*P.crest);c.m.position.y=HR*(c.y+.35*P.crest*c.len);});
  o.crestM.color.set(CR0).lerp(new T.Color(CR1),Math.min(1,P.crest));
  const sac=P.thr;o.throat.position.copy(S.neckMid).lerp(S.head,.82).addScaledVector(V(0,-1,0).applyQuaternion(S.Qh),.07+.05*sac);o.throat.quaternion.copy(S.Qh);o.throat.scale.set(.05+.06*sac,.045+.1*sac,.05+.07*sac);o.throat.material.color.set('#e8b59a').lerp(new T.Color('#f08c70'),Math.min(1,sac));
  // frill: collapsed to a thin ruff, fans out to ~0.3 m
  const fs=P.frill,rs=.03+.27*fs+.012*P.shim;o.frill.visible=fs>.02;o.frill.scale.set(rs,rs*(.8+.2*fs),1);o.frill.rotation.y=Math.PI/2-.12*fs;o.frill.position.set(-HR*.7-.02*fs,HR*.1,0);
  o.frillM.color.set('#c9803f').lerp(new T.Color('#e8503a'),Math.min(1,fs*.6+P.shim*.5));
  o.ribs.forEach(r=>{const a=r.userData.a;r.position.set(.5*Math.sin(a+Math.PI/2)*0+.5*Math.cos(a),.5*Math.sin(a),.002);r.rotation.z=a-Math.PI/2;r.scale.set(1/rs*.6,1,1);});
  o.rim.position.z=.003;
  o.legs.forEach((l,i)=>{place(l.up,S.hips[i],S.knees[i]);place(l.lo,S.knees[i],S.feet[i]);l.kn.position.copy(S.knees[i]);l.ft.position.copy(S.feet[i]).add(V(.04,-.005,0).applyQuaternion(S.Qb));l.ft.quaternion.copy(S.Qb);});
  o.arms.forEach((a,i)=>{const A=S.arm[i];place(a.up,A.sh,A.el);place(a.lo,A.el,A.hand);a.el.position.copy(A.el);a.sh.position.copy(A.sh);a.hand.position.copy(A.hand);
    const d=A.hand.clone().sub(A.el).normalize();a.hand.quaternion.setFromUnitVectors(X,d);
    a.fing.forEach((f,k)=>{if(k<3){f.rotation.set(0,(k-1)*A.open*.6,-(1-A.open)*.9+.1);}else{f.rotation.set(0,0,0);f.rotation.y=(A.open*.8)*(i?1:-1);f.rotation.z=-(1-A.open)*.5;}});});
  o.fruit.visible=P.prop>0;if(o.fruit.visible)o.fruit.position.copy(S.fruitP);
  const lift=Math.max(0,Math.min(...S.feet.map(f=>f.y))-.03);o.shadow.position.set(0,.003,0);o.shadow.scale.set(1.4,.6,1);o.shadow.material.opacity=Math.max(.12,.9-lift*1.3);
  const fx=o.fx;fx.reset();
  for(const t of S.arcs)for(let j=0;j<3;j++){const ph=(g-t-j*85)/700;if(ph>0&&ph<1)fx.arc(S.tip.clone().addScaledVector(S.axis,.02),S.Qh,.1+.95*Math.pow(ph,.75),.62*Math.sin(Math.PI*Math.min(1,ph*1.1))*(1-ph*.4),'#e8f4ff');}
  if(act==='sing')BB.noteBurst(fx,S.arcs,g,S.tip.clone().addScaledVector(S.axis,.02),SK,BB.rigs.armed.height);
  fx.flush();
}
const ACTS={
 sing:{id:'trill-chest',name:'Trill + chest beat',tag:'throat sac swells on each of three trill notes, beak open, the hands drum the chest on the beat',organ:'throat sac + arm_grasper hands',tier:2,mode:'max'},
 dance:{id:'stomp-clap',name:'Stomp + clap',tag:'diagonal stomps land on the beat, hands clap, then fling up in a wave, body weaves side to side',organ:'4 legs + arm_grasper hands',tier:2,mode:'land'},
 charm:{id:'offer-food',name:'Offer food with both hands',tag:'a fruit held at the chest is lifted and held out to the target, body bowing, head tilted',organ:'arm_grasper hands',tier:2,mode:'arrive'},
 pose:{id:'frill',name:'Frill flare',tag:'an extensible frill fans open behind the head, chest swells, arms flung wide with open hands, a shimmer on the beat',organ:'extensible crest / frill',tier:2,mode:'arrive'}};
BB.rigs.armed={id:'armed',label:'Armed',TD:2.6,cam:{h:2.1,cx:1.0,ty:.68},height:1.2,tbow:-0.2,build,pose,draw,acts:ACTS};
})();
