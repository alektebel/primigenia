'use strict';
// Versions 2 and 3: PELICAN GULP and HERON TOSS. One shared bird machine (body, S-neck skin tube with the prey-shaped bulge, head with a hinged lower bill and a
// stretchy translucent gular pouch, two-bone legs with a gait) and two scripts.
// Pelican: the open bill scoops the prey into the pouch, the head tilts up, the pouch squeezes and shrinks while the lump slides into the throat, a final gulp sends it down the neck.
// Heron: grab by the scruff, wind-up, a whip toss, catch head-first in the open bill, three gulps, then the neck bulge travels down the S-neck.
(function(){
const EG=window.EG,T=EG.T,BB=EG.BB,{V,clamp,sm,lerp,ik,lam,place,ell,limb,coneX,X,Y,Z,qEul,ramp,pls,ease,easeIn,keys,Tube2,PREY,lumpR,makePrey,drawPrey}=EG;
const rotZ=a=>new T.Quaternion().setFromAxisAngle(Z,a);
const smI=(t,T0)=>t<=0?0:t<T0?T0*(Math.pow(t/T0,3)-Math.pow(t/T0,4)/2):T0*.5+(t-T0);

function makeBird(P){
  const NN=32;
  function build(scene){
    const o={mats:[]};const skin=lam(P.cBody),pale=lam(P.cBelly),wing=lam(P.cWing),bill=lam(P.cBill),bill2=lam(P.cBill2),dk=lam('#14110e'),eyeW=lam('#f4f1e8'),leg=lam(P.cLeg);o.mats.push(skin,pale,wing,bill,bill2,leg);
    o.bodyG=new T.Group();scene.add(o.bodyG);ell(o.bodyG,skin,...P.body);
    o.belly=ell(o.bodyG,pale,P.body[0]*.8,P.body[1]*.7,P.body[2]*.9);
    o.wings=[-1,1].map(s=>{const g=new T.Group();g.position.set(P.body[0]*.1,P.body[1]*.35,s*P.body[2]*.86);o.bodyG.add(g);ell(g,wing,P.body[0]*.92,P.body[1]*.5,.03).position.set(-P.body[0]*.35,-P.body[1]*.2,0);
      const tip=ell(g,lam(P.cWingTip),P.body[0]*.4,P.body[1]*.28,.026);tip.position.set(-P.body[0]*.95,-P.body[1]*.55,0);return g;});
    const tail=new T.Mesh(new T.ConeGeometry(P.body[1]*.55,P.body[0]*.9,5),skin);tail.rotation.z=Math.PI/2+.2;tail.scale.z=.35;tail.position.set(-P.body[0]*1.05,P.body[1]*.05,0);o.bodyG.add(tail);
    o.neck=new Tube2(NN,12);o.neck.mesh.material.emissive=new T.Color(0,0,0);scene.add(o.neck.mesh);o.mats.push(o.neck.mesh.material);
    const h=o.head=new T.Group();scene.add(h);ell(h,skin,P.hr*1.25,P.hr,P.hr*.95).position.set(P.hr*.1,0,0);
    for(const s of [-1,1]){const w=ell(h,eyeW,P.hr*.3,P.hr*.3,P.hr*.2);w.position.set(P.hr*.7,P.hr*.3,s*P.hr*.78);const p=ell(h,dk,P.hr*.16,P.hr*.2,P.hr*.12);p.position.set(P.hr*.86,P.hr*.3,s*P.hr*.92);
      if(P.crest){const c=new T.Mesh(new T.ConeGeometry(.01,.3,5),dk);c.position.set(-P.hr*.9,P.hr*.5,s*.02);c.rotation.z=1.7;h.add(c);}}
    const L=P.bl;o.up=new T.Group();o.up.position.set(P.hr*.9,.004,0);h.add(o.up);
    const u=new T.Mesh(coneX(P.bw,L),bill);u.scale.set(1,P.bh/P.bw,1);o.up.add(u);
    if(P.hook){const k=ell(o.up,bill2,.03,.02,P.bw*.45);k.position.set(L-.01,-.012,0);}
    o.lo=new T.Group();o.lo.position.set(P.hr*.9,-.004,0);h.add(o.lo);const lw=new T.Mesh(coneX(P.bw*.85,L*.97),bill2);lw.scale.set(1,.55,1);o.lo.add(lw);
    o.mouthIn=ell(o.lo,lam('#8a3340'),L*.45,.008,P.bw*.55);o.mouthIn.position.set(L*.5,.01,0);
    o.pouch=new Tube2(18,12,0,Math.PI*2,new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide,transparent:true,opacity:.6,depthWrite:false}));scene.add(o.pouch.mesh);o.pouch.mesh.renderOrder=3;
    o.legs=[0,1].map(i=>{const up=limb(scene,leg,P.lr0,P.lr1),lo=limb(scene,leg,P.lr1,P.lr1*.7),kn=ell(scene,leg,P.lr0*1.1,P.lr0*1.1,P.lr0*1.1),ft=new T.Group();scene.add(ft);ell(ft,leg,.07,.016,.04).position.x=.03;
      for(const a of [-.4,0,.4]){const t=new T.Mesh(coneX(.011,.09,5),leg);t.rotation.y=a;t.position.x=.05;ft.add(t);}return {up,lo,kn,ft};});
    o.shadow=EG.shadowBlob(scene);o.prey=makePrey(scene);return o;
  }
  // S: {rx,bx,by,bz,bpitch,broll,H(V hinge world),hp,hyaw,hroll,gape,wing,B(belly bulge 0..1),aF,Lp,Rp,fill,gait:{t,on,cyc,stride,lift},nbDir,sway,pf(pouch fill extra)}
  function draw(o,S,ov,u){
    ov=ov||{};const Qb=qEul(0,S.bpitch,S.broll||0),C=V(S.rx+S.bx,P.cy+S.by,S.bz||0);
    o.bodyG.position.copy(C);o.bodyG.quaternion.copy(Qb);
    const B=S.B||0;o.belly.scale.set(P.body[0]*(.8+.22*B),P.body[1]*(.7+.55*B),P.body[2]*(.9+.3*B));o.belly.position.set(.02*P.body[0],-P.body[1]*(.25+.3*B),0);
    o.wings.forEach((w,i)=>{w.rotation.z=-(S.wing||0)*.4;w.rotation.x=(i?1:-1)*(S.wing||0)*.35;});
    const Nb=V(...P.nb).applyQuaternion(Qb).add(C),Qh=qEul(S.hyaw||0,S.hp,S.hroll||0),fw=X.clone().applyQuaternion(Qh),H=S.H;
    const gape=S.gape+(ov.spitK?.5*ov.spitK:0);
    o.head.position.copy(H);o.head.quaternion.copy(Qh);o.lo.rotation.z=-gape*.9;o.up.rotation.z=gape*.1;o.mouthIn.visible=gape>.25;
    const Lo=X.clone().applyQuaternion(Qh.clone().multiply(rotZ(-gape*.9)));
    // neck
    const nbD=V(...(S.nbDir||P.nbDir)).normalize().applyQuaternion(Qb),dist=H.distanceTo(Nb);
    const c1=Math.min(P.neckL*.55,dist*.55+.05),c2=Math.min(P.neckL*.55,dist*.55+.05);
    const bp=BB.bezPath(H.clone().addScaledVector(fw,-.0),H.clone().addScaledVector(fw,-c1),Nb.clone().addScaledVector(nbD,c2),Nb,40),rs=BB.resample(bp,NN-1),pts=rs.pts,len=rs.len,ds=len/(NN-1);
    const rA=[],st=[];
    for(let i=0;i<NN;i++){const a=i*ds,base=lerp(P.rh,P.rn,sm(a/len)),lr=lumpR(a,S.aF,S.Lp,S.Rp)*(1+(S.sq?.08*Math.sin(a*9-u/70)*S.sq:0))*(1+.06*(ov.retch?Math.sin(a*11-u/45)*ov.retch:0));
      const r=Math.max(base,lr);rA.push(r);st.push(r>base*1.12?clamp((r/base-1.1)/1.0,0,1):0);}
    const col=(i,ang,out)=>{const c=P.neckCol(i/(NN-1),ang),sx=st[i];const f=ov.hit?ov.hit*.2:0;
      out[0]=c[0]+(.86-c[0])*sx*.4+(1-c[0])*f;out[1]=c[1]+(.78-c[1])*sx*.4+(1-c[1])*f;out[2]=c[2]+(.7-c[2])*sx*.4+(1-c[2])*f;};
    o.neck.update(pts,rA,rA,'planar',col);
    // pouch along the lower bill
    const m=o.pouch.nr,pp=[],pa=[],pb=[],off=[];
    const Lb=P.bl*.97,base0=P.pouch,Qlo=Qh.clone().multiply(rotZ(-gape*.9));
    for(let i=0;i<m;i++){const f=i/(m-1),d=P.hr*.9+f*Lb;const pt=H.clone().add(X.clone().multiplyScalar(d).applyQuaternion(Qlo));pp.push(pt);
      const cR=Math.max(lumpR(-(d-P.hr*.9),S.aF,S.Lp,S.Rp)*(S.fill===undefined?1:S.fill),0);
      const env=Math.pow(Math.sin(Math.PI*clamp(f*.92+.04,0,1)),.7),empty=base0*env*(.012+.085*(S.pq||0));
      const depth=Math.max(empty,cR*1.04+(cR>0?.01:0)),wid=Math.max(.012+.4*empty*0,.016*env+cR*.92);
      pa.push(depth*.55+.004);pb.push(wid+.006);off.push(depth*.5);}
    const pcol=(i,ang,out)=>{const c=P.cPouch,sh=.8+.2*Math.cos(ang);out[0]=c[0]*sh;out[1]=c[1]*sh;out[2]=c[2]*sh;};
    o.pouch.update(pp,pa,pb,V(0,-1,0),pcol,off);o.pouch.mesh.visible=base0>0;
    // legs
    const g=S.gait||{on:0},hips=[],hz=P.hip[2];
    o.legs.forEach((l,i)=>{const sd=i?1:-1,hip=V(P.hip[0],P.hip[1],sd*hz).applyQuaternion(Qb).add(C);
      let fx=P.foot0+(S.footX||0),lift=0;
      if(g.on>0){const ph=(((g.t/g.cyc)+(i?.5:0))%1+1)%1,d=.62,sx=g.stride*g.on;if(ph<d)fx+=sx*(.5-ph/d);else{const uu=(ph-d)/(1-d);fx+=-sx*.5+sx*sm(uu);lift=g.lift*g.on*Math.sin(Math.PI*uu);}}
      const foot=V(S.rx+fx,.035+lift,sd*hz+(S.footZ||0)*0),pole=V(1,.3,0),r=ik(hip,foot,P.la,P.lb,pole);
      place(l.up,hip,r.knee);place(l.lo,r.knee,r.foot);l.kn.position.copy(r.knee);l.ft.position.copy(r.foot);l.ft.rotation.z=-.15+lift*1.5*0;});
    o.shadow.position.set(C.x,.003,C.z);o.shadow.scale.set(P.body[0]*3,P.body[2]*3.2,1);
    EG.flashMats(o.mats,(ov.hit||0)*.22);
    return {H,fw,Lo,Qh,Qlo,tip:H.clone().add(Lo.clone().multiplyScalar(P.bl)),Nb,len,C};
  }
  return {build,draw};
}
// prey sitting in the bill / pouch: nose toward the hinge, along the lower mandible direction. aF = distance of the nose behind the hinge (negative = inside the bill)
function preyInBill(info,aF,s){
  const d=info.Lo,nose=info.H.clone().addScaledVector(d,-aF),cen=nose.clone().addScaledVector(d,PREY.nose*s);
  const xx=d.clone().negate(),yy=Y.clone().addScaledVector(xx,-Y.dot(xx));if(yy.lengthSq()<1e-4)yy.set(0,0,1);yy.normalize();const q=new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(xx,yy,new T.Vector3().crossVectors(xx,yy)));
  if(aF<.3)cen.y-=.05*s*clamp((.3-aF)/.3,0,1);return {pos:cen,q};
}
const mapN=(a)=>a;
EG.bird={makeBird,preyInBill,smI};

// =================================================================== PELICAN
(function(){
const PS=.95,LP0=PREY.L*PS,FOLD=.9,LPE=LP0*.8,RPE=PREY.R*PS*1.12;
const P={cy:.64,body:[.44,.23,.21],nb:[.36,.14,0],nbDir:[.55,.85,0],neckL:.82,rh:.05,rn:.082,hr:.075,bl:.66,bw:.062,bh:.04,hook:true,pouch:1,crest:false,
  hip:[.0,-.12,.12],foot0:.0,la:.26,lb:.28,lr0:.034,lr1:.026,
  cBody:'#e9e4d6',cBelly:'#f6f1e2',cWing:'#c9c6bd',cWingTip:'#46444a',cBill:'#e3be6e',cBill2:'#d7a85c',cLeg:'#d59a52',cPouch:[.93,.62,.5],
  neckCol:(f,ang)=>{const c=.9-.06*f;return [c,c*.98,c*.92];}};
const B=makeBird(P);
const LEAD=900,SC0=900,WK0=2200,GU0=4300,GU1=5400,SW=6200,DIG=7500,XP=1.2,LN=.82;
const digK=u=>1-.72*clamp((u-SW)/DIG,0,1);
const rootX=u=>.16*smI(u-SW,1800)/1000;
const AFN=LN+.55;
function sched(u,ov){
  const S={};ov=ov||{};const ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru),walk=ramp(ru,SW-100,SW+800),dk=ov.digK!==undefined?ov.digK:digK(u);
  // head hinge (relative to root), bill pitch hp, gape, body lunge
  const K=keys(u,[[0,.42,1.08,-.32,.03,0,0],[500,.45,1.04,-.4,.03,0,0],[900,.5,1.02,-.55,.05,0,0],[1150,.28,1.24,.12,.35,-.02,0],[1300,.45,1.12,-.1,.8,.03,.06],[1480,.98,.3,-.12,.95,.18,.17],[1650,1.18,.19,-.05,.82,.2,.2],[1840,1.12,.2,-.02,.1,.2,.2],[2000,.95,.55,.15,.08,.12,.1],[WK0,.7,.95,.3,.06,.02,0],
    [3100,.55,1.12,.8,.06,0,0],[GU0,.4,1.22,1.12,.06,0,0],[4700,.36,1.26,1.22,.14,0,0],[GU1,.4,1.18,.9,.05,0,0],[5800,.44,1.08,-.2,.08,0,0],[SW,.42,1.04,-.32,.04,0,0]]);
  const Kw=keys(ru,[[SW,0],[SW+900,1]]);
  let hx=K[0],hy=K[1],hp=K[2],gape=K[3],bx=K[4],bpitch=-K[5];
  if(u>=SW){const w=ramp(u,SW,SW+800);hx=lerp(K[0],.4,w);hy=lerp(K[1],.92,w);hp=lerp(K[2],-.7,w);}
  // pace of the walk: head bob and waddle roll
  const cyc=1700,gt=ru-SW,sway=Math.sin(gt/cyc*Math.PI*2);
  S.rx=rx;S.bx=bx;S.by=-.012*Math.abs(Math.sin(u/190))*0+(-.03*(K[5]>0?1:0))+walk*(-.02+.02*Math.sin(gt/cyc*Math.PI*4));S.bz=.03*sway*walk;S.broll=.1*sway*walk;S.bpitch=bpitch+.02*Math.sin(u/700);
  const hb=walk*.04*Math.sin(gt/cyc*Math.PI*4+1);
  S.H=V(rx+hx+bx*0,hy+hb,0);S.H.x=rx+hx;S.hp=hp+.04*Math.sin(u/420)*(1-walk);S.gape=gape+(u>5330&&u<5880?.12*Math.max(0,Math.sin((u-5330)/90)):0);S.hyaw=(u>5400&&u<5950?.35*Math.sin((u-5400)/55)*Math.exp(-(u-5400)/260):0);
  S.hroll=0;S.wing=.15*pls(u,GU0+400,300)+.1*pls(u,5600,200);
  const gtc=walk>0?1:0;S.gait={t:gt,on:walk,cyc,stride:.17*walk*0+.16,lift:.07};S.gait.on=walk;
  S.footX=0;
  // prey in the pouch: nose position aF along the mouth path (negative inside the bill, positive in the throat)
  const e=ramp(u,1560,1860);S.e=e;
  let aF=-.1;
  if(u>=WK0){const g=(u-WK0)/(GU0-WK0)*3,k=Math.floor(clamp(g,0,2.999)),q=g-k;aF=-.1+.6*((k+sm(clamp((q-.15)/.7,0,1)))/3);S.sq=Math.sin(Math.PI*clamp((q-.15)/.7,0,1))*(u<GU0?1:0);}
  if(u>=GU0){const f=ramp(u,GU0,GU1);aF=.5+(AFN+.05-.5)*(.45*ramp(u,GU0+100,GU0+650)+.55*ramp(u,GU0+500,GU1));S.sq=Math.sin(Math.PI*clamp((u-GU0)/1100*2,0,2))*.8;}
  if(u>=SW)aF=AFN+.05+.1*ramp(u,SW,SW+4000);
  S.aF=aF;S.Lp=LPE*(.7+.3*dk);S.Rp=RPE*dk;S.fill=e;S.pq=.22+.78*EG.win(u,1150,1960,150,250)+.3*(u>=WK0&&u<GU0+300?1:0)*(1-ramp(u,GU0,GU0+300))+.15*(u>=GU0?1:0)*(1-ramp(u,GU1,SW));
  S.B=dk*clamp((aF-LN)/.5,0,1);S.nbDir=[.55,.85,0];
  return S;
}
function frame(o,u,ov){
  ov=ov||{};const S=sched(u,ov),dk=ov.digK!==undefined?ov.digK:digK(u),ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru);
  if(ov.retch){S.hp+=.18*ov.retch;S.sq=ov.retch;}
  if(ov.hit){S.by-=.05*ov.hit;S.hp-=.25*ov.hit;S.wing=.5*ov.hit;}
  const info=B.draw(o,S,ov,u);
  // prey: lies on the ground until the scoop, then sits in the bill/pouch (nose to the hinge)
  const lie=new T.Quaternion().setFromAxisAngle(Y,Math.PI+.15).multiply(new T.Quaternion().setFromAxisAngle(X,.25));
  const gp=V(rx+XP+PREY.nose*PS,.098,.05);
  const mouth=preyInBill(info,S.aF,PS);
  const e=S.e,pos=gp.clone().lerp(mouth.pos,e),q=lie.clone().slerp(mouth.q,e),inside=S.aF>=LPE*.97+0;
  const hid=S.aF>=LPE;
  drawPrey(o.prey,{pos,q,s:PS*dk,fold:FOLD*e,stun:(1-e*.7)*(u<SW+200?1:0),swing:.12*Math.sin(u/300)+.2*pls(u,1650,160)*e,tr:u,vis:!hid,clip:{p:info.H.clone(),n:info.fw.clone()}},ov,u);
  return {bulge:dk*clamp(.15*e+.85*clamp((S.aF+.1)/(AFN),0,1),0,1),mouth:info.tip};
}
function cam(u,ov){const ru=ov&&ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru);
  const c=keys(u,[[0,.7,.9,3.0,2.3],[900,.8,.85,2.9,2.3],[1400,.95,.7,2.6,2.2],[1850,.95,.7,2.4,2.2],[WK0,.6,.9,2.4,2.4],[GU0,.4,1.0,2.4,2.6],[5400,.45,.95,2.5,2.5],[SW,.35,.8,3.0,2.4],[SW+1500,.3,.75,3.3,2.4]]);return {cx:rx+c[0],cy:c[1],span:c[2],v:c[3]};}
EG.rigs.pelican={id:'pelican',label:'Pelican',name:'Gulp',org:'two-legged long-billed bird with a gular pouch',
  tag:'The open bill sweeps along the ground and scoops the prey into the pouch (it stretches around the prey), the bill closes and the head tilts up. The pouch squeezes in three pulses and shrinks as the lump slides into the throat, then a final gulp sends it down the neck. A slung belly bulge and a heavy waddle follow.',
  lead:LEAD,ph:[['scoop',WK0-SC0,'#d9576b'],['tilt, squeeze',GU0-WK0,'#e0925c'],['final gulp',GU1-GU0,'#d9b24f'],['settle',SW-GU1,'#9a86d6']],
  swEnd:SW,u1:WK0,credit:GU1,digest:DIG,len:SW+DIG,digK,build:B.build,frame,cam,rootX};
})();

// =================================================================== HERON
(function(){
const PS=.8,LP0=PREY.L*PS,FOLD=0,LPE=LP0,RPE=PREY.R*PS*1.3;
const P={cy:1.0,body:[.34,.16,.13],nb:[.3,.12,0],nbDir:[.35,.94,0],neckL:1.05,rh:.034,rn:.05,hr:.055,bl:.4,bw:.04,bh:.03,hook:false,pouch:.7,crest:true,
  hip:[.02,-.1,.075],foot0:.02,la:.42,lb:.44,lr0:.022,lr1:.016,
  cBody:'#8d9fae',cBelly:'#d9dde0',cWing:'#6d7f90',cWingTip:'#2a323a',cBill:'#d9b24a',cBill2:'#c49b3c',cLeg:'#a8a06a',cPouch:[.82,.58,.55],
  neckCol:(f,ang)=>{const th=Math.cos(ang)>.55&&f>.12;return th?[.9,.9,.92]:[.52-.04*f,.6-.04*f,.67-.04*f];}};
const B=makeBird(P);
const LEAD=900,G0=900,TS0=1500,TR=1640,CATCH=2380,WK0=CATCH,WK1=4100,GU1=5000,SW=5700,DIG=7500,XP=1.0,LN=1.05;
const digK=u=>1-.72*clamp((u-SW)/DIG,0,1);
const rootX=u=>.14*smI(u-SW,1800)/1000;
const AFN=LN+.5;
const GRAV=9.8;
function sched(u,ov){
  const S={};ov=ov||{};const ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru),walk=ramp(ru,SW-100,SW+800),dk=ov.digK!==undefined?ov.digK:digK(u);
  // head hinge (x,y), bill pitch, gape, body lean
  const K=keys(u,[[0,.46,1.72,-.1,.02,0],[500,.5,1.74,-.18,.02,0],[G0,.55,1.68,-.4,.02,.02],[1100,.34,1.78,.25,.05,-.04],[1230,.62,1.3,-.5,.12,.1],[1340,1.02,.52,-.8,.45,.2],[1420,1.02,.4,-.8,.05,.2],[TS0,.92,.62,-.5,.02,.12],
    [1560,.62,.5,.0,.02,.0],[TR,.8,1.72,1.0,.02,-.06],[1700,.88,1.98,1.25,.3,-.1],[1900,.7,1.9,1.1,.8,-.04],[2150,.52,1.78,.95,.95,0],[CATCH,.46,1.74,.92,.45,0],
    [2700,.4,1.8,1.1,.1,0],[3300,.42,1.78,1.22,.1,0],[WK1,.4,1.8,1.25,.12,0],[4500,.36,1.86,1.3,.1,0],[GU1,.42,1.74,.8,.05,0],[5300,.5,1.62,.0,.08,0],[SW,.46,1.6,-.25,.04,0]]);
  let hx=K[0],hy=K[1],hp=K[2],gape=K[3],bpitch=-K[4]*1;
  const cyc=2600,gt=ru-SW,sway=Math.sin(gt/cyc*Math.PI*2);
  if(u>=SW){const w=ramp(u,SW,SW+900);hx=lerp(K[0],.62,w);hy=lerp(K[1],1.62,w)+.05*Math.sin(gt/cyc*Math.PI*4+1)*w;hp=lerp(K[2],-.55,w);}
  S.rx=rx;S.bx=0;S.by=-.04*(u>1200&&u<1650?Math.sin(Math.PI*(u-1200)/450):0)+walk*.02*Math.sin(gt/cyc*Math.PI*4);S.bz=.025*sway*walk;S.broll=.05*sway*walk;S.bpitch=bpitch;
  S.H=V(rx+hx,hy,0);S.hp=hp;S.gape=gape+(u>5300&&u<5600?.1*Math.max(0,Math.sin((u-5300)/80)):0);S.hyaw=u>5330&&u<5800?.3*Math.sin((u-5330)/60)*Math.exp(-(u-5330)/220):0;
  S.wing=.12*pls(u,TR,150)+.2*pls(u,CATCH,250)+.1*pls(u,4500,300);
  S.gait={t:gt,on:walk,cyc,stride:.2,lift:.12};S.footX=0;
  // gulps and the travelling lump
  let aF=-P.bl;
  if(u>=CATCH){const g=(u-WK0)/(WK1-WK0)*3,k=Math.floor(clamp(g,0,2.999)),q=g-k;aF=-P.bl+(P.bl+.45)*((k+sm(clamp((q-.2)/.6,0,1)))/3);S.sq=Math.sin(Math.PI*clamp((q-.2)/.6,0,1));
    S.H.y+=.04*S.sq*(u<WK1?1:0);S.hp+=.1*S.sq*(u<WK1?1:0);}
  if(u>=WK1){aF=.45+(AFN-.45+.05)*ramp(u,WK1+100,GU1);S.sq=.9*Math.sin(Math.PI*clamp((u-WK1)/(GU1-WK1)*3,0,3));}
  if(u>=SW)aF=AFN+.05+.1*ramp(u,SW,SW+4000);
  S.aF=aF;S.Lp=LPE*(.7+.3*dk);S.Rp=RPE*dk;S.fill=1;S.pq=.15;
  S.B=dk*clamp((aF-LN)/.5,0,1);S.nbDir=[.35,.94,0];
  return S;
}
function frame(o,u,ov){
  ov=ov||{};const S=sched(u,ov),dk=ov.digK!==undefined?ov.digK:digK(u),ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru);
  if(ov.retch){S.hp+=.2*ov.retch;S.sq=ov.retch;}
  if(ov.hit){S.by-=.05*ov.hit;S.hp-=.3*ov.hit;S.wing=.6*ov.hit;}
  const info=B.draw(o,S,ov,u);
  const lie=new T.Quaternion().setFromAxisAngle(Y,Math.PI+.1).multiply(new T.Quaternion().setFromAxisAngle(X,.25));
  const gp=V(rx+XP+PREY.nose*PS,.098,0);
  let pos,q,fold=0,swing=0,stun=1,vis=true;
  const grip=info.tip.clone().add(V(0,-.02,0));
  // hanging by the scruff: nose up at the grip, body below
  const hang=(sw)=>{const qq=new T.Quaternion().setFromEuler(new T.Euler(0,0,Math.PI/2+sw));return qq;};
  const catchOf=()=>{ // pose at the catch: nose at the bill tip, along the lower mandible
    const cu=sched(CATCH,{rootU:ru});const inf2={H:cu.H,Lo:X.clone().applyQuaternion(qEul(0,cu.hp,0).multiply(rotZ(-cu.gape*.9)))};return inf2;};
  if(u<TS0-120){pos=gp;q=lie;stun=1;}
  else if(u<TR){ // gripped by the scruff, lifted: blend from the ground to hanging at the tip, pendulum swing from the wind-up
    const e=ramp(u,1330,1480),hp0=grip.clone().add(V(0,-PREY.nose*PS*0.0-.31*PS,0));
    pos=gp.clone().lerp(hp0.clone().add(V(0,0,0)),e);q=lie.clone().slerp(hang(.0),e);swing=.5*Math.sin((u-1480)/120)*e*.7-.4*ramp(u,1500,TR);fold=.2*e;stun=1-.4*e;
    if(e>=1){ // pivot at the nose: hang the body below the grip
      const sw=-.35*ramp(u,1500,TR-20);const qq=hang(sw);const off=V(0,-PREY.nose*PS,0).applyQuaternion(new T.Quaternion().setFromAxisAngle(Z,sw));pos=grip.clone().add(V(-Math.sin(sw)*0,-.0,0)).add(V(Math.sin(sw)*.31*PS,-Math.cos(sw)*.31*PS,0));q=qq;}
  }else if(u<CATCH){ // flight: ballistic from the release point to the open bill
    const rel=sched(TR,{rootU:ru}),relInfo=null;
    const relPos=V(rx+rel.H.x-rx+.34*Math.cos(rel.hp)-.0,rel.H.y+.34*Math.sin(rel.hp),0).add(V(0,-.2,0));
    const cat=catchOf(),Pc=cat.H.clone().addScaledVector(cat.Lo,P.bl*.92).add(V(0,0,0));
    const Tf=(CATCH-TR)/1000,tt=(u-TR)/1000;
    const vx=(Pc.x-relPos.x)/Tf,vy=(Pc.y-relPos.y+.5*GRAV*Tf*Tf)/Tf;
    const nosePos=V(relPos.x+vx*tt,relPos.y+vy*tt-.5*GRAV*tt*tt,0);
    // orientation: nose up at release (+x -> +y), spin to the catch direction (nose toward hinge)
    const a0=Math.PI/2,dir=cat.Lo.clone().negate(),a1=Math.atan2(dir.y,dir.x)+Math.PI*2*0;
    const ang=lerp(a0,a1+ (a1<a0? Math.PI*2:0),ease(tt/Tf)*.0+tt/Tf);
    q=new T.Quaternion().setFromAxisAngle(Z,ang);
    pos=nosePos.clone().add(V(Math.cos(ang),Math.sin(ang),0).multiplyScalar(-PREY.nose*PS)).addScaledVector(V(Math.cos(ang),Math.sin(ang),0),PREY.nose*PS*0);
    // nose is at nosePos; centre is behind it
    pos=nosePos.clone().addScaledVector(V(Math.cos(ang),Math.sin(ang),0),-PREY.nose*PS);
    swing=.5*Math.sin(tt*18)*.5;stun=.8;fold=.15;
  }else{ // in the bill, going down
    const m=preyInBill(info,S.aF,PS);pos=m.pos;q=m.q;stun=.5;swing=.1*Math.sin(u/200);
    vis=S.aF<LPE;
  }
  if(u<TR&&u>=TS0-120&&false)vis=true;
  drawPrey(o.prey,{pos,q,s:PS*dk,fold,stun:u<SW+200?stun:0,swing,tr:u,vis,clip:u>=CATCH?{p:info.H.clone(),n:info.fw.clone()}:null},ov,u);
  return {bulge:dk*clamp((S.aF+.3)/(AFN+.3),0,1)*(u>=CATCH?1:0),mouth:info.tip};
}
function cam(u,ov){const ru=ov&&ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru);
  const c=keys(u,[[0,.55,1.05,2.6,2.7],[G0,.65,.98,2.6,2.6],[1300,.7,.8,2.6,2.4],[TR,.7,1.15,2.8,2.8],[1900,.65,1.3,2.8,2.9],[CATCH,.5,1.32,2.6,2.8],[WK1,.45,1.32,2.4,2.7],[GU1,.45,1.22,2.5,2.7],[SW,.4,1.0,3.2,2.7],[SW+1500,.35,.95,3.6,2.7]]);return {cx:rx+c[0],cy:c[1],span:c[2],v:c[3]};}
EG.rigs.heron={id:'heron',label:'Heron',name:'Toss',org:'long-legged wader with a dagger bill and a stretchy throat',
  tag:'Wind-up, a stab and grip by the scruff, the neck coils back and whips: the prey is tossed up, flips and falls head-first into the open bill. Three throat gulps, then the lump travels down the S-neck into the body. A stalking walk with the bulge follows.',
  lead:LEAD,ph:[['grab',TS0-G0,'#d9576b'],['toss, catch',CATCH-TS0,'#e0925c'],['gulps',WK1-CATCH,'#e0a25c'],['neck bulge down',GU1-WK1,'#d9b24f'],['settle',SW-GU1,'#9a86d6']],
  swEnd:SW,u1:CATCH+40,credit:GU1,digest:DIG,len:SW+DIG,digK,build:B.build,frame,cam,rootX};
})();
})();
