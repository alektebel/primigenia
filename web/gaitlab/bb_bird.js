'use strict';
// Body 2: WINGED creature (bird-like, A56 wings): two-bone legs with a backward heel, S-neck, beak, gular pouch, crest plumes, tail fan, two 3-bone wings with real feather blades.
// sing = puffed throat call + wing flicks | dance = wing-flap hop | charm = preen, then offer a feather | pose = full wing spread display (tier 3 sail / wing display).
(function(){
const BB=window.BB,T=BB.T,{V,clamp,sm,lerp,env,bump,bumps,ik,qEul,lam,place,ell,limb,coneX,GEO,X,Y,Z,FY,FEATHER,featherPose}=BB;
const H0=.50,HR=.062,PIT0=.12;
const BODY='#2f8f8a',BELLY='#eee3c6',WING1='#26456b',WING2='#3f7fb0',WING3='#6bb4d6',CREST='#e0702f',BEAK='#f0b84a';
const HIP=[[.0,-.12,-.075],[.0,-.12,.075]],FOOT=[[.02,-.08],[.02,.08]],SEGL=[.2,.26],NB=[.20,.12,0],NK=[.17,.17];
const SH=[V(.07,.14,-.115),V(.07,.14,.115)];
const EF=[V(-.08,.11,-.17),V(-.08,.11,.17)],WF=[V(.05,.17,-.175),V(.05,.17,.175)],EE=[V(.04,.17,-.31),V(.04,.17,.31)],WE=[V(.0,.20,-.62),V(.0,.20,.62)];
const NP=8,NS=6;
function build(scene){
  const body=lam(BODY),belly=lam(BELLY),beak=lam(BEAK),eyeW=lam('#f4f1e8'),eyeP=lam('#121416'),leg=lam('#c8924a');
  const o={fx:BB.FXPool(scene)};
  o.body=new T.Group();scene.add(o.body);ell(o.body,body,.27,.17,.15);ell(o.body,belly,.2,.15,.13).position.set(.1,-.04,0);ell(o.body,lam('#256f6c'),.2,.06,.13).position.set(-.04,.11,0);
  o.neck=[0,1].map(()=>limb(scene,body,.055,.045));o.nodes=[.06,.052,.05].map(r=>ell(scene,body,r,r,r));
  const head=o.head=new T.Group();scene.add(head);ell(head,body,HR*1.15,HR,HR*.95);
  for(const s of [-1,1]){const w=ell(head,eyeW,HR*.3,HR*.3,HR*.2);w.position.set(HR*.35,HR*.25,s*HR*.78);const p=ell(head,eyeP,HR*.16,HR*.18,HR*.12);p.position.set(HR*.52,HR*.25,s*HR*.92);}
  const len=.115;o.up=new T.Group();o.lo=new T.Group();head.add(o.up,o.lo);o.up.position.set(HR*.8,0,0);o.lo.position.set(HR*.8,-.008,0);
  const u=new T.Mesh(coneX(HR*.5,len),beak);u.scale.set(1,.8,.9);o.up.add(u);const l=new T.Mesh(coneX(HR*.36,len),lam('#d89c32'));l.scale.set(1,.7,.85);o.lo.add(l);
  o.mouth=ell(head,lam('#7a1f26'),len*.4,.01,HR*.3);o.mouth.position.set(HR*.8+len*.45,-.004,0);o.beakLen=len;
  const crestM=lam(CREST);o.crest=[];for(let k=0;k<5;k++){const c=new T.Mesh(new T.ConeGeometry(.011,.17,5),crestM);c.position.set(-HR*.3-.012*k,HR*.8,(k-2)*.012);head.add(c);o.crest.push(c);}
  o.pouch=ell(scene,lam('#e45a3a'),.03,.03,.03);
  o.tail=[];for(let i=0;i<7;i++){const f=new T.Mesh(FEATHER,lam(i%2?'#1f6a72':'#2a8a8e',{side:T.DoubleSide}));scene.add(f);o.tail.push(f);}
  o.legs=[0,1].map(i=>{const up=limb(scene,leg,.03,.022),lo=limb(scene,leg,.022,.016),kn=ell(scene,leg,.03,.03,.03),ft=new T.Group();scene.add(ft);ell(ft,leg,.05,.016,.03);for(let k=0;k<3;k++){const t=new T.Mesh(coneX(.01,.07,5),leg);t.rotation.y=(k-1)*.45;t.position.set(.04,0,0);ft.add(t);}return {up,lo,kn,ft};});
  o.wings=[0,1].map(i=>{const arm=limb(scene,lam(WING2),.03,.024),fore=limb(scene,lam(WING2),.024,.018),el=ell(scene,lam(WING2),.03,.03,.03);
    const prim=[],sec=[];for(let k=0;k<NP;k++){const f=new T.Mesh(FEATHER,lam(k%2?WING1:'#2f5b8c',{side:T.DoubleSide}));scene.add(f);prim.push(f);}
    for(let k=0;k<NS;k++){const f=new T.Mesh(FEATHER,lam(k%2?WING2:'#4d90bf',{side:T.DoubleSide}));scene.add(f);sec.push(f);}
    return {arm,fore,el,prim,sec};});
  o.feather=new T.Mesh(FEATHER,lam('#e8527a',{side:T.DoubleSide}));scene.add(o.feather);
  const sh=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sh.rotation.x=-Math.PI/2;sh.position.y=.003;scene.add(sh);o.shadow=sh;
  return o;
}
function pose(act,g){
  const G=BB.GAME[act],W=G.W,ts=W+G.A,tb=W;
  const P={by:0,pitch:PIT0,roll:0,yaw:0,hx:.2,hy:.22,hp:0,hyaw:0,hroll:0,gape:0,thr:0,chest:0,sig:[0,0],phi:[0,0],tailFan:.25,tailUp:.1,air:0,foot:[0,0],crest:.2,prop:0,featherAt:null,arcs:[]};
  P.by=.004*Math.sin(g/450);P.sig=[.0,.0];P.hyaw=.0;
  let obs=0;
  if(act==='sing'){
    const e=env(g,-300,ts+400,450,500),n=bumps(g,W,3,300,60),fl=bumps(g,W,3,300,45);
    P.hx=.2-.02*e;P.hy=.22+.1*e;P.hp=.45*e;P.pitch=PIT0+.1*e;P.gape=.9*n;P.thr=.15*e+.85*n;P.chest=.3*e+.7*n;P.crest=.4+.5*e;P.by+=.014*n;
    P.sig=[.55*fl,.55*fl];P.phi=[.45*fl,.45*fl];P.tailFan=.25+.3*n;P.tailUp=.1+.25*n;obs=P.thr;for(let k=0;k<3;k++)P.arcs.push(W+300*k);
  }else if(act==='dance'){
    const hh=.13,AIR=320;let by=0,air=0,flap=0,sigma=0,cr=0,landed=false;
    for(let k=0;k<4;k++){const tl=W+400*k,to=tl-AIR;
      if(g>=to&&g<=tl){const u=(g-to)/AIR;by=Math.max(by,hh*4*u*(1-u));air=Math.max(air,1);sigma=Math.max(sigma,.95*Math.sin(Math.PI*u));flap=lerp(.75,-.55,u);}
      const c1=bump(g,to-40,60)*(g<to?1:0),c2=g>tl?bump(g,tl,90):0;cr=Math.max(cr,c1,c2);}
    const e=env(g,-100,W+400*3+500,300,450);
    P.by+=by-.05*cr*e;P.sig=[sigma,sigma];P.phi=[flap,flap];if(sigma<.05){const f=sm((g-W)/200);P.phi=[.15*f,.15*f];}
    P.yaw=.35*Math.sin(Math.PI*(g-W)/400)*e*0+.0;P.hp=.2*air;P.hy=.22+.05*air;P.tailFan=.25+.5*sigma;P.tailUp=.1+.3*sigma;P.crest=.3+.6*air;P.roll=.05*Math.cos(Math.PI*(g-W)/400)*e;
    P.pitch=PIT0-.1*cr*e+.1*air;
    // feet: airborne weight a per hop (planted otherwise)
    let a=0;for(let k=0;k<4;k++){const tl=W+400*k,to=tl-AIR;if(g>=to&&g<=tl+0)a=Math.max(a,Math.min(sm((g-to)/50),sm((tl-g)/50)));}
    P.air=a;obs=0;P.footA=a;
    // observable for the beat check: height of the lowest foot
  }else if(act==='charm'){
    const r=sm((g+437)/600),q=r,pw=1-r,back=sm((g-ts-1300)/900),qq=q*(1-back),nib=Math.sin(g/62);
    const pre=sm((g+1000)/400);
    // preen: head over the right folded wing, nibbling; offer: head forward and down with the feather in the beak
    const pr=V(-.04,.05,.16);P.hx=lerp(.2,pr.x+nib*.035*pre*pw,pre*pw)*1;P.hy=lerp(.22,.02,pre*pw);P.hyaw=0;
    const ox=.30,oy=.08;P.hx=lerp(P.hx,ox,qq);P.hy=lerp(P.hy,oy,qq);P.hp=-.5*qq+.3*pre*pw;P.hroll=.25*qq;P.zoff=.12*pre*pw*(1-qq)*0;
    P.preenZ=.16*pre*pw;P.sig=[0,.45*pre*pw+.2*qq];P.phi=[.1*qq,.5*pre*pw+.15*qq];P.pitch=PIT0-.14*qq+.05*pre*pw;P.by-=.02*qq;P.tailFan=.25+.5*qq;P.tailUp=.1+.2*qq;P.crest=.4+.5*qq;P.hy+=.015*Math.cos(2*Math.PI*(g-W)/600)*qq;
    P.prop=1;P.featherAt=g<-250?'wing':'beak';obs=r;
  }else{
    const f=sm((g+226)/700),back=sm((g-ts-1800)/800),s_=f*(1-back),sh=Math.max(bump(g,tb+300,90),bump(g,tb+600,90),bump(g,tb+900,90))*f;
    P.sig=[s_,s_];P.phi=[.62*s_+.07*sh,.62*s_+.07*sh];P.pitch=PIT0+.16*s_;P.hy=.22+.1*s_;P.hx=.2-.01*s_;P.hp=.3*s_;P.tailFan=.25+1.0*s_;P.tailUp=.1+.5*s_;P.crest=.3+.7*s_;P.thr=.2*s_;P.chest=.5*s_;P.by+=.015*s_;
    obs=f;
  }
  return fin(P,act,g,obs);
}
function fin(P,act,g,obs){
  const Qb=qEul(P.yaw,P.pitch,P.roll),c=V(0,H0+P.by,0),W=l=>V(l[0],l[1],l[2]).applyQuaternion(Qb).add(c),Wv=v=>v.clone().applyQuaternion(Qb).add(c);
  const nodes=[],anchors=[],S={P,Qb,c,obs,nodes,anchors,act,g,arcs:P.arcs,legErr:0};
  const nb=W(NB),preen=P.preenZ||0;let hzl=0;
  const hdLocal=V(NB[0]+P.hx,NB[1]+P.hy,preen);const head=Wv(hdLocal),pole=V(-.4,1,0).normalize().applyQuaternion(Qb);
  const ng=ik(nb,head,NK[0],NK[1],pole);S.nb=nb;S.neckMid=ng.knee;S.head=ng.foot.clone();
  S.Qh=Qb.clone().multiply(new T.Quaternion().setFromAxisAngle(Z,P.hp)).multiply(new T.Quaternion().setFromAxisAngle(Y,preen?-preen*1.6*0:0)).multiply(new T.Quaternion().setFromAxisAngle(X,P.hroll));
  if(preen>.01){const wing=V(0,0,1);S.Qh.multiply(new T.Quaternion().setFromAxisAngle(Y,-1.0*preen/.16)).multiply(new T.Quaternion().setFromAxisAngle(Z,-.3*preen/.16));}
  S.axis=X.clone().applyQuaternion(S.Qh);S.tip=S.head.clone().addScaledVector(S.axis,HR*.8+.115);
  S.hips=[];S.knees=[];S.feet=[];
  for(let i=0;i<2;i++){const hip=W(HIP[i]),pl=V(FOOT[i][0],FY,FOOT[i][1]),a=P.footA||0;let ft=pl;
    if(a>0){const tuck=W([.06,-.30,FOOT[i][1]*.9]);ft=pl.clone().lerp(tuck,a);}
    const r=ik(hip,ft,SEGL[0],SEGL[1],V(-1,.1,0).applyQuaternion(Qb));if(r.knee.y<.04)r.knee.y=.04;
    S.hips.push(hip);S.knees.push(r.knee);S.feet.push(r.foot);S.legErr=Math.max(S.legErr,r.err);anchors.push({id:i?'R':'L',p:r.foot.clone(),on:a<.0005});nodes.push({p:r.knee,r:.03},{p:r.foot,r:.02});}
  if(act==='dance'){S.obs=Math.min(S.feet[0].y,S.feet[1].y)-FY;}
  nodes.push({p:S.head,r:.06},{p:W([0,0,0]),r:.17},{p:S.neckMid,r:.045});
  // wings
  S.wing=[];
  for(let i=0;i<2;i++){const s=i?1:-1,sg=P.sig[i],ph=P.phi[i],Sh=SH[i];
    const rot=(v,isDir)=>{const q=v.clone();if(!isDir)q.sub(Sh);q.applyAxisAngle(X,-s*ph);if(!isDir)q.add(Sh);return q;};
    const E=rot(EF[i].clone().lerp(EE[i],sg)),Wr=rot(WF[i].clone().lerp(WE[i],sg));
    const prim=[],sec=[];
    for(let k=0;k<NP;k++){const u=k/(NP-1),b=lerp(.05,.8,u),de=V(-Math.sin(b),.0+.05*(1-u)-.06*u*Math.max(0,-ph),Math.cos(b)*s),df=V(-1,-.1,.04*s),d=df.clone().lerp(de,sg).normalize();
      const base=Wr.clone().add(d.clone().multiplyScalar(-.0)),nrm=V(0,.2,s).lerp(Y,sg).normalize();
      const dr=rot(d,true);const nr2=rot(nrm,true);prim.push({base,dir:dr,nrm:nr2,len:.34-.1*u,wid:.052});}
    for(let k=0;k<NS;k++){const u=k/(NS-1),t=(k+.5)/NS,b=lerp(.55,.9,u),de=V(-Math.sin(b),.02,Math.cos(b)*s),df=V(-1,-.12,.02*s),d=df.clone().lerp(de,sg).normalize(),
      base=E.clone().lerp(Wr,t),nrm=V(0,.2,s).lerp(Y,sg).normalize();sec.push({base,dir:rot(d,true),nrm:rot(nrm,true),len:.24-.04*u,wid:.07});}
    S.wing.push({sh:W([Sh.x,Sh.y,Sh.z]).clone(),E,Wr,prim,sec});
    for(const f of prim.concat(sec)){const tip=f.base.clone().addScaledVector(f.dir,f.len);nodes.push({p:Wv(tip),r:.01});}
    nodes.push({p:Wv(E),r:.03},{p:Wv(Wr),r:.025});}
  // tail feather blades
  S.tailF=[];for(let k=0;k<7;k++){const a=(k-3)*P.tailFan/3,tp=P.tailUp,d=V(-Math.cos(a)*Math.cos(tp),Math.sin(tp),Math.sin(a)*Math.cos(tp)).normalize();S.tailF.push({base:V(-.23,.05,0),dir:d,nrm:Y.clone(),len:.32});nodes.push({p:W([-.23+d.x*.32,.05+d.y*.32,d.z*.32]),r:.01});}
  S.pouchP=S.neckMid.clone().lerp(S.head,.88).addScaledVector(V(0,-1,0).applyQuaternion(S.Qh),.04+.03*P.thr);
  return S;
}
function draw(o,S,act,g){
  const P=S.P,Qb=S.Qb,c=S.c,Wv=v=>v.clone().applyQuaternion(Qb).add(c);
  o.body.position.copy(c);o.body.quaternion.copy(Qb);o.body.scale.set(1+.04*P.chest,1+.1*P.chest,1+.1*P.chest);
  place(o.neck[0],S.nb,S.neckMid);place(o.neck[1],S.neckMid,S.head);o.nodes[0].position.copy(S.nb);o.nodes[1].position.copy(S.neckMid);o.nodes[2].position.copy(S.head);
  o.head.position.copy(S.head);o.head.quaternion.copy(S.Qh);o.up.rotation.z=P.gape*.34;o.lo.rotation.z=-.02-P.gape*.62;o.mouth.visible=P.gape>.12;o.mouth.scale.set(o.beakLen*.4,.005+.03*P.gape,HR*.3);
  o.crest.forEach((cm,k)=>{const sp=P.crest;cm.rotation.z=1.3-sp*1.0-.05*k;cm.rotation.x=(k-2)*.18*sp;cm.scale.set(1,.5+.9*sp,1);});
  const pu=P.thr;o.pouch.position.copy(S.pouchP);o.pouch.quaternion.copy(S.Qh);o.pouch.scale.set(.03+.045*pu,.025+.065*pu,.03+.05*pu);o.pouch.material.color.set('#c8503a').lerp(new T.Color('#ff7a52'),Math.min(1,pu));
  S.tailF.forEach((f,k)=>featherPose(o.tail[k],Wv(f.base),f.dir.clone().applyQuaternion(Qb),f.nrm.clone().applyQuaternion(Qb),f.len,.055));
  o.legs.forEach((l,i)=>{place(l.up,S.hips[i],S.knees[i]);place(l.lo,S.knees[i],S.feet[i]);l.kn.position.copy(S.knees[i]);l.ft.position.copy(S.feet[i]).add(V(.02,-.01,0).applyQuaternion(Qb));l.ft.quaternion.copy(Qb);});
  o.wings.forEach((w,i)=>{const W_=S.wing[i];place(w.arm,Wv(SH[i]),Wv(W_.E));place(w.fore,Wv(W_.E),Wv(W_.Wr));w.el.position.copy(Wv(W_.E));
    W_.prim.forEach((f,k)=>featherPose(w.prim[k],Wv(f.base),f.dir.clone().applyQuaternion(Qb),f.nrm.clone().applyQuaternion(Qb),f.len,f.wid));
    W_.sec.forEach((f,k)=>featherPose(w.sec[k],Wv(f.base),f.dir.clone().applyQuaternion(Qb),f.nrm.clone().applyQuaternion(Qb),f.len,f.wid));});
  o.feather.visible=P.prop>0;
  if(o.feather.visible){if(P.featherAt==='wing'){const w=S.wing[1];featherPose(o.feather,Wv(w.prim[3].base).clone().add(V(0,.05,0)),V(-.5,.6,.4).applyQuaternion(Qb),Y,.2,.05);}
    else{const q=S.Qh.clone();featherPose(o.feather,S.tip.clone().addScaledVector(S.axis,-.025),V(.45,.9,0).applyQuaternion(q),V(0,0,1).applyQuaternion(q),.22,.05);}}
  const lift=Math.max(0,Math.min(...S.feet.map(f=>f.y))-.03);o.shadow.position.set(0,.003,0);o.shadow.scale.set(1.0+lift*.5,.55,1);o.shadow.material.opacity=Math.max(.1,.9-lift*2);
  const fx=o.fx;fx.reset();
  for(const t of S.arcs)for(let j=0;j<3;j++){const ph=(g-t-j*85)/700;if(ph>0&&ph<1)fx.arc(S.tip.clone().addScaledVector(S.axis,.02),S.Qh,.08+.8*Math.pow(ph,.75),.62*Math.sin(Math.PI*Math.min(1,ph*1.1))*(1-ph*.4),'#e8f4ff');}
  if(act==='sing')BB.noteBurst(fx,S.arcs,g,S.tip.clone().addScaledVector(S.axis,.02),BODY,BB.rigs.bird.height);
  fx.flush();
}
const ACTS={
 sing:{id:'throat-call',name:'Puffed throat call',tag:'red gular pouch puffs on three call notes, beak open, wings flick out on each note, tail fans',organ:'throat sac (gular pouch)',tier:2,mode:'max'},
 dance:{id:'flap-hop',name:'Wing-flap hop',tag:'three hops that land on the beat, wings burst open and flap down each hop, tail fans, body rolls',organ:'wings + legs',tier:2,mode:'land'},
 charm:{id:'preen-feather',name:'Preen, then a feather gift',tag:'nibbles a wing feather, then lifts the head and holds the feather out to the target, leaning in',organ:'beak + wing feather (gift)',tier:3,mode:'arrive'},
 pose:{id:'wing-spread',name:'Full wing spread',tag:'both wings rise and fan wide in a V, tail fans up, chest out, head high; feathers shimmer on the beat',organ:'wing display (sail / wing)',tier:3,mode:'arrive'}};
BB.rigs.bird={id:'bird',label:'Winged',TD:2.4,cam:{h:1.62,cx:.95,ty:.58},height:.75,tbow:-0.5,build,pose,draw,acts:ACTS};
})();
