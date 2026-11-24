'use strict';
// Version 4: FROG GULP. A squat toad-like creature with a very wide mouth. It coils, snaps the wide mouth over the prey's nose, then swallows in three pushes where the
// eyes sink down into the head (the eyelids close) and press the prey down the throat, a big final gulp sends the lump to the belly, which swells. A low, heavy crawl follows.
(function(){
const EG=window.EG,T=EG.T,BB=EG.BB,{V,clamp,sm,lerp,lam,ell,place,ik,X,Y,Z,qEul,ramp,win,pls,ease,easeIn,keys,PREY,makePrey,drawPrey}=EG;
const rotZ=a=>new T.Quaternion().setFromAxisAngle(Z,a);
const PS=.95,LPE=PREY.L*PS*.85,RPE=PREY.R*PS*1.15,XP=1.05;
const LEAD=900,GR0=900,WK0=1500,WK1=4400,GU1=5500,SW=6200,DIG=7500;
const smI=(t,T0)=>t<=0?0:t<T0?T0*(Math.pow(t/T0,3)-Math.pow(t/T0,4)/2):T0*.5+(t-T0);
const rootX=u=>.1*smI(u-SW,1800)/1000;
const digK=u=>1-.72*clamp((u-SW)/DIG,0,1);
const PATHLEN=.78;
function build(scene){
  const o={mats:[]};const skin=lam('#6f8a3f'),dark=lam('#3d5320'),pale=lam('#d9d29a'),gum=lam('#8a3340'),tong=lam('#d9707e'),gold=lam('#e8b93c'),blk=lam('#0e0e0b'),lump=lam('#9fb766');o.mats.push(skin,dark,pale,lump);
  o.bodyG=new T.Group();scene.add(o.bodyG);
  ell(o.bodyG,skin,.42,.27,.34).position.set(-.06,0,0);ell(o.bodyG,dark,.24,.05,.2).position.set(-.1,.235,0);
  for(const [x,z,r] of [[-.2,.1,.05],[-.05,-.14,.06],[-.3,-.12,.045],[.08,.12,.05],[-.18,-.02,.04]]){const w=ell(o.bodyG,dark,r,r*.45,r);w.position.set(x,.24,z);}
  o.belly=ell(o.bodyG,pale,.3,.14,.26);
  o.head=new T.Group();o.head.position.set(.26,.06,0);o.bodyG.add(o.head);
  ell(o.head,skin,.22,.12,.3).position.set(.14,.03,0);ell(o.head,skin,.12,.09,.2).position.set(.34,.0,0);ell(o.head,dark,.2,.02,.26).position.set(.14,.12,0);
  for(const s of [-1,1]){const n=ell(o.head,blk,.012,.012,.014);n.position.set(.45,.05,s*.05);}
  o.jaw=new T.Group();o.head.add(o.jaw);
  ell(o.jaw,pale,.24,.05,.27).position.set(.2,-.04,0);o.mouth=ell(o.jaw,gum,.21,.014,.22);o.mouth.position.set(.2,0,0);
  o.tongue=ell(o.jaw,tong,.13,.02,.1);o.tongue.position.set(.2,.012,0);
  o.sac=ell(o.head,pale,.14,.06,.17);
  o.eyes=[-1,1].map(s=>{const g=new T.Group();g.position.set(.12,.12,s*.17);o.head.add(g);ell(g,skin,.09,.04,.09).position.y=-.0;
    const b=ell(g,gold,.065,.065,.065);b.position.y=.045;const p=ell(g,blk,.012,.05,.026);p.position.set(.03,.055,s*.0);p.scale.set(.012,.05,.02);const lid=ell(g,skin,.072,.04,.072);lid.position.y=.07;return {g,b,p,lid,s};});
  o.lump=ell(scene,lump,.1,.1,.1);o.lump.visible=false;
  o.legs=[0,1,2,3].map(i=>{const hind=i>=2,m=skin,up=BB.limb(scene,m,hind?.07:.045,hind?.05:.035),lo=BB.limb(scene,m,hind?.05:.035,hind?.03:.025),kn=ell(scene,m,hind?.065:.045,hind?.065:.045,hind?.065:.045),ft=new T.Group();scene.add(ft);ell(ft,pale,hind?.12:.07,.02,hind?.07:.05).position.x=.03;
    for(const a of [-.35,0,.35]){const t=ell(ft,pale,.03,.014,.014);t.position.set(hind?.12:.08,0,a*(hind?.2:.14));}return {up,lo,kn,ft};});
  o.shadow=EG.shadowBlob(scene);o.prey=makePrey(scene);return o;
}
function sched(u,ov){
  ov=ov||{};const ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru),walk=ramp(ru,SW-100,SW+800);const S={rx,walk};
  // lunge: the whole body slides forward on the hind legs
  S.bx=keys(u,[[0,0],[GR0,0],[1150,-.07],[1262,.46],[1500,.46],[4400,.46],[SW,.46]])[0];
  const crouch=keys(u,[[0,0],[GR0,0],[1150,1],[1262,-.1],[1500,.1],[4400,.1],[SW,0]])[0];
  S.crouch=crouch;
  // snap: gape; clamp
  S.gape=keys(u,[[0,.04],[800,.04],[GR0,.06],[1150,.15],[1235,1.05],[1330,1.0],[1420,.3],[WK0,.22],[4300,.22],[4400,.3],[4560,.95],[4800,.95],[5050,.3],[5500,.1],[5600,.5],[5760,.1],[SW,.05]])[0];
  // eye presses: 3 cycles then the final hold
  let eye=0,aF=.2,th=0,hunch=0;
  if(u>=WK0){const g=clamp((u-WK0)/(WK1-WK0)*3,0,2.999),k=Math.floor(g),q=g-k;
    eye=sm(clamp((q-.08)/.3,0,1))*(1-sm(clamp((q-.62)/.3,0,1)));aF=.2+.17*(k+sm(clamp((q-.1)/.45,0,1)));th=Math.sin(Math.PI*clamp((q-.05)/.6,0,1));hunch=eye*.6;
    if(u>=WK1){aF=.71;}}
  if(u>=WK1){const f=(u-WK1);eye=sm(clamp(f/260,0,1))*(1-sm(clamp((f-700)/280,0,1)));aF=.71+.95*sm(clamp((f-120)/(GU1-WK1-250),0,1))+(PATHLEN*0);th=.6+.4*Math.sin(f/90)*(f<900?1:0);hunch=eye;}
  if(u>=SW)aF=1.66;
  S.eye=eye;S.aF=aF;S.th=th;S.hunch=hunch;S.sac=Math.max(.15*Math.sin(u/450)+.2,th,crouch>0?crouch*.9:0);
  S.blink=(u<GR0&&Math.sin(u/700)>.96)?1:0;
  S.pulses=pls(u,5620,90);
  return S;
}
function pathPt(pts,d){let acc=0;for(let i=0;i<pts.length-1;i++){const l=pts[i].distanceTo(pts[i+1]);if(d<=acc+l||i===pts.length-2){const t=clamp((d-acc)/l,0,1);return {p:pts[i].clone().lerp(pts[i+1],t),t:pts[i+1].clone().sub(pts[i]).normalize()};}acc+=l;}}
function frame(o,u,ov){
  ov=ov||{};const S=sched(u,ov),dk=ov.digK!==undefined?ov.digK:digK(u),ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru),walk=S.walk;
  const gt=ru-SW,cyc=2300,sw=Math.sin(gt/cyc*Math.PI*2);
  const B=clamp((S.aF-.55)/.85,0,1)*dk;
  const hC=.3-.07*S.crouch*(S.crouch>0?1:0)-.05*B-.03*S.hunch+.012*Math.sin(u/420)*(1-walk)+walk*(.004*Math.sin(gt/cyc*Math.PI*4)),pitch=-.12*S.crouch*(S.crouch>0?1:0)+.1*S.hunch+(ov.hit?-.2*ov.hit:0)-(ov.retch||0)*.12;
  const C=V(rx+S.bx,hC,walk*.025*sw);const Qb=qEul(walk*.07*sw,pitch,0);
  o.bodyG.position.copy(C);o.bodyG.quaternion.copy(Qb);
  o.belly.scale.set(.3+.1*B,.14+.2*B,.26+.12*B);o.belly.position.set(0,-.12-.06*B,0);
  // head
  const gape=S.gape+(ov.spitK?.6*ov.spitK:0)+(ov.retch?.12*ov.retch:0),hp=-.05+.45*(u>WK1&&u<WK1+1100?Math.sin(Math.PI*clamp((u-WK1)/1100,0,1)):0)+.12*S.crouch*(S.crouch>0?1:0)-.2*(ov.hit||0)+.3*(u>=SW-100&&u<SW+400?0:0)-.03*walk;
  o.head.rotation.z=hp;o.jaw.rotation.z=-gape;o.mouth.visible=gape>.12;o.tongue.visible=gape>.35;
  const sc=(.1+.9*S.th);o.sac.scale.set(.1+.07*S.sac,.04+.08*S.sac,.14+.06*S.sac);o.sac.position.set(.2,-.1-.03*S.sac,0);
  o.eyes.forEach(e=>{const r=S.eye;e.g.position.y=.12-.085*r;e.b.scale.set(.065,.065*(1-.35*r),.065);e.lid.position.y=.045+.025*(1-r*.0)+0;e.lid.scale.set(.072,.04+.045*Math.max(r,S.blink),.072);e.lid.position.y=.052-.02*Math.max(r,S.blink)*0+.0;e.p.visible=r<.7&&!S.blink;});
  // mouth tip (world) and axis
  const qh=Qb.clone().multiply(rotZ(hp)),qjaw=qh.clone().multiply(rotZ(-gape*.5));
  const hingeW=V(.26,.06,0).applyQuaternion(Qb).add(C),axis=X.clone().applyQuaternion(qjaw),tip=hingeW.clone().add(V(.46,0,0).applyQuaternion(qjaw));
  // legs: diagonal crawl
  const sh=[V(.2,-.02,-.27),V(.2,-.02,.27)],hp2=[V(-.28,-.02,-.3),V(-.28,-.02,.3)];
  o.legs.forEach((l,i)=>{const hind=i>=2,sd=i%2?1:-1,hip=(hind?hp2[i-2]:sh[i]).clone().applyQuaternion(Qb).add(C);
    let fx=hind?-.34:.4,lift=0;const ph=((gt/cyc+((i===0||i===3)?0:.5))%1+1)%1,d=.65;
    if(walk>0){const st=.14*walk;if(ph<d)fx+=st*(.5-ph/d);else{const uu=(ph-d)/(1-d);fx+=-st*.5+st*sm(uu);lift=.06*walk*Math.sin(Math.PI*uu);}}
    if(u<GR0+400&&u>1000)fx+=0;
    const foot=V(rx+fx+(hind?S.bx*0:S.bx*.9),.03+lift,sd*(hind?.46:.33)),pole=V(hind?-.3:.2,1,sd*(hind?.55:.3)).normalize(),r=ik(hip,foot,hind?.36:.23,hind?.36:.23,pole);
    place(l.up,hip,r.knee);place(l.lo,r.knee,r.foot);l.kn.position.copy(r.knee);l.ft.position.copy(r.foot);});
  o.shadow.position.set(C.x,.003,C.z);o.shadow.scale.set(1.3,.95,1);
  // prey: lies on the ground until the snap, then hangs from the mouth and is pulled in; clipped at the lips
  const lie=new T.Quaternion().setFromAxisAngle(Y,Math.PI+.1).multiply(new T.Quaternion().setFromAxisAngle(X,.25));
  const gp=V(rx+XP+PREY.nose*PS,.098,0);
  const held=ramp(u,1235,1300);
  const d=axis.clone().negate(),sag=-.25*(1-ramp(u,WK1-300,WK1));
  const dir=axis.clone().applyAxisAngle(Z,sag*.0);
  const nose=tip.clone().addScaledVector(axis,S.aF*-1*-1*0).addScaledVector(axis,-S.aF);
  const cen=nose.clone().addScaledVector(axis,PREY.nose*PS);
  const mq=(()=>{const xx=axis.clone().negate(),yy=Y.clone().addScaledVector(xx,-Y.dot(xx)).normalize(),zz=new T.Vector3().crossVectors(xx,yy);return new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(xx,yy,zz));})();
  const droop=(1-ramp(u,WK1-400,WK1))*.0;
  const pos=gp.clone().lerp(cen.clone().add(V(0,-.02*held*0,0)),held),q=lie.clone().slerp(mq,held);
  const hid=S.aF>=LPE*.98&&u>=GR0+400;
  drawPrey(o.prey,{pos,q,s:PS*dk,fold:0,stun:(1-held*.5)*(u<SW+200?1:0),swing:.15*Math.sin(u/260)*held+.25*pls(u,1262,120),tr:u,vis:!hid,clip:{p:tip.clone(),n:axis.clone()}},ov,u);
  // the lump travelling inside: head -> chin -> chest -> belly
  const pts=[tip.clone(),V(.3,-.07,0).applyQuaternion(Qb).add(C),V(.1,-.18,0).applyQuaternion(Qb).add(C),V(-.06,-.12,0).applyQuaternion(Qb).add(C)];
  const aF=S.aF,inL=Math.min(aF,LPE*dk),pl=pts[0].distanceTo(pts[1])+pts[1].distanceTo(pts[2])+pts[2].distanceTo(pts[3]);
  const dcen=aF-inL/2,fade=1-ramp(aF,PATHLEN+LPE*.5,PATHLEN+LPE);
  o.lump.visible=aF>.02&&dcen<pl&&fade>.01;
  if(o.lump.visible){const pp=pathPt(pts,clamp(dcen,0,pl)),r=RPE*dk*Math.min(1,aF/.2)*(.8+.35*S.th*0)*(1+.12*S.th),pz=pp.p;
    o.lump.position.copy(pz).add(V(0,-.01,0));o.lump.quaternion.setFromUnitVectors(X,pp.t);o.lump.scale.set(Math.max(.03,inL/2*1.05),r*fade,r*fade);
    o.lump.visible=aF>=.02;}
  EG.flashMats(o.mats,(ov.hit||0)*.22);
  return {bulge:dk*clamp((S.aF-.1)/1.5,0,1),mouth:tip};
}
function cam(u,ov){const ru=ov&&ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru);
  const c=keys(u,[[0,.55,.32,2.8,1.5],[GR0,.6,.3,2.5,1.5],[1250,.85,.28,2.2,1.4],[WK0,.95,.3,2.0,1.4],[WK1,.9,.3,1.9,1.4],[GU1,.85,.28,2.0,1.4],[SW,.5,.26,2.6,1.4],[SW+1500,.35,.26,3.0,1.4]]);return {cx:rx+c[0],cy:c[1],span:c[2],v:c[3]};}
EG.rigs.frog={id:'frog',label:'Frog',name:'Gulp, eyes press down',org:'squat wide-mouthed creature with retractable eyes',
  tag:'A coil, then a snap: the body lunges and the very wide mouth closes over the prey\'s nose. Three swallows, each one sinks the eyes into the head (the lids close) and presses the prey down the throat; a long final press sends the lump to the belly, which swells. A low, heavy crawl follows.',
  lead:LEAD,ph:[['snap',WK0-GR0,'#d9576b'],['eyes press x3',WK1-WK0,'#e0925c'],['final gulp',GU1-WK1,'#d9b24f'],['settle',SW-GU1,'#9a86d6']],
  swEnd:SW,u1:WK0,credit:GU1,digest:DIG,len:SW+DIG,digK,build,frame,cam,rootX};
})();
