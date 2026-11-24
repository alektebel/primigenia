'use strict';
// Version 1: SNAKE JAW WALK. A serpentine body (A49) with a loose-jawed wedge head. The head sits over the prey's nose, then the two lower-jaw halves
// "walk" alternately over it: one jaw hooks in and pulls the head forward while the other lets go and reaches. Seven small ratchets, the throat bulges as the prey
// slides in, then the head lifts and a swallow wave pushes the lump into the body. Afterwards a flat belly bulge and a heavy slither.
(function(){
const EG=window.EG,T=EG.T,BB=EG.BB,{V,clamp,sm,lerp,lam,ell,coneX,X,Y,Z,qEul,ramp,pls,ease,easeIn,keys,Tube2,arcSample,PREY,lumpR,makePrey,drawPrey}=EG;
const LH=.416,HS=1.3,XP=1.5,NR=84,DS=.043,RG=.05,LP=PREY.L,RP=PREY.R,AF=1.55,KW=Math.PI*2/1.8,PHI=.4;
const LEAD=900,GR0=900,WK0=1600,WK1=4500,GU0=4500,GU1=5500,SW=6200,DIG=7500,NSTEP=7,TAUS=(WK1-WK0)/NSTEP,DELTA=(.9)/NSTEP;
const smInt=(t,T0)=>t<=0?0:t<T0?T0*(Math.pow(t/T0,3)-Math.pow(t/T0,4)/2):T0*.5+(t-T0);
const rootX=u=>.2*smInt(u-SW,1800)/1000;
const digK=u=>1-.76*clamp((u-SW)/DIG,0,1);
const BODY=[.2,.3,.1],DARK=[.08,.13,.045],BELLY=[.6,.56,.34];
const hash=(a,b)=>{const s=Math.sin(a*127.1+b*311.7)*43758.5453;return s-Math.floor(s);};
const rb=a=>{let r=.05+.062*sm(a/1.2);if(a>2.2)r=lerp(r,.018,sm((a-2.2)/1.3));return r;};
// ------------------------------------------------------------------ the schedule: everything that moves, as a function of u
function sched(u,ov){
  const S={};const sp=ov&&ov.spitK||0;
  const wk=u>=WK0-60&&u<WK1+60?1:0;
  // tip position relative to the prey's nose (m)
  let dt;
  if(u<GR0)dt=-1.18+1.03*ease(u/GR0);
  else dt=keys(u,[[GR0,-.15],[1150,-.27],[1260,.08],[WK0,.10]])[0];
  let q=0,k=0,s=0,w=0;
  if(u>=WK0){const th=clamp((u-WK0)/(WK1-WK0)*NSTEP,0,NSTEP-1e-6);k=Math.floor(th);q=th-k;s=sm(clamp((q-.1)/.62,0,1));dt=.10+.9*((k+s)/NSTEP);if(u>=WK1)dt=1.0;
    w=ramp(u,WK0-40,WK0+140)*(1-ramp(u,WK1-140,WK1+40));}
  S.dt=dt;S.q=q;S.k=k;S.w=w;
  // jaws: alternate; jaw 0 (left, z-) anchors on even steps
  const jaw=(par)=>{const anch=((k+par)%2)===0;const sa=s,sr=sm(clamp(q/.72,0,1));
    const o=anch?DELTA/2-DELTA*sa:-DELTA/2+DELTA*sr;const lift=anch?0:.024*Math.sin(Math.PI*clamp(q/.8,0,1));return {o:o*w,lift:lift*w,anch};};
  S.jL=jaw(0);S.jR=jaw(1);
  const sig=(S.jL.anch?-1:1);                                    // head swings round the anchored jaw
  S.yaw=.10*sig*Math.sin(Math.PI*q)*w;S.roll=.06*sig*Math.sin(Math.PI*q)*w;
  S.surge=Math.sin(Math.PI*clamp((q-.25)/.55,0,1))*w;               // throat squeeze each step
  S.alpha=keys(u,[[0,.1],[500,.1],[GR0,.2],[1150,.6],[1235,.96],[1420,.74],[WK1-100,.74],[4850,.05],[5500,.05],[5650,.1],[5780,.62],[6040,.06],[SW,.05]])[0]+.035*Math.sin(((u-WK0)/TAUS)*Math.PI*2)*w;
  S.pitch=keys(u,[[0,-.02],[GR0,-.02],[1150,.14],[1262,-.12],[1420,-.05],[WK1,-.05],[4900,.6],[5250,.62],[5500,.2],[5900,-.03],[SW,.02]])[0];
  S.lift=keys(u,[[0,0],[GR0,.0],[1150,.07],[1262,0],[WK1,0],[4900,.30],[5250,.36],[5500,.2],[5950,0],[SW,0]])[0]+.03*sp;
  S.tongue=Math.max(0,Math.sin(u/330))>.93?1:0;
  S.tongue=Math.max(S.tongue,pls(u,5830,90),pls(u,700,120),pls(u,6300,90),pls(u,7800,90),pls(u,9400,90),pls(u,11000,90));
  // prey depth in the tube
  const preyL=LP*(.7+.3*(ov&&ov.digK||digK(u)));
  S.Lp=preyL;
  let aF=Math.max(0,dt-LH);
  if(u>=GU0){const g1=ramp(u,4720,5150),g2=ramp(u,5100,5560);aF=LP+(AF-LP)*(.55*g1+.45*g2);}
  if(u>=SW)aF=AF+.07*ramp(u,SW,SW+4000);
  S.aF=aF;
  S.walk=ramp(u,SW-100,SW+700);
  return S;
}
function build(scene){
  const o={};o.mats=[];
  o.body=new Tube2(NR,12);scene.add(o.body.mesh);o.body.mesh.material.emissive=new T.Color(0,0,0);o.mats.push(o.body.mesh.material);
  o.shad=new Tube2(NR,6,0,Math.PI*2,new T.MeshBasicMaterial({color:'#000',transparent:true,opacity:.34,depthWrite:false,vertexColors:true}));scene.add(o.shad.mesh);
  const hm=lam('#5b7030'),hd=lam('#475c26'),pale=lam('#e8dfaa'),mouth=lam('#8c2a35'),tooth=lam('#f4efe0');o.mats.push(hm,hd,pale,mouth,tooth);
  const head=o.head=new T.Group();scene.add(head);
  ell(head,hm,.17,.044,.072).position.set(.16,.02,0);ell(head,hm,.085,.034,.058).position.set(.27,.012,0);ell(head,hd,.1,.012,.05).position.set(.14,.062,0);
  for(const s of [-1,1]){const br=ell(head,hd,.05,.016,.022);br.position.set(.2,.06,s*.056);br.rotation.x=-s*.3;
    const e=ell(head,lam('#f2d36a'),.018,.018,.016);e.position.set(.2,.048,s*.062);const p=ell(head,lam('#0b0b0b'),.006,.015,.005);p.position.set(.211,.048,s*.074);
    const n=ell(head,lam('#101010'),.007,.006,.007);n.position.set(.335,.026,s*.026);
    for(let t=0;t<8;t++){const c=new T.Mesh(new T.ConeGeometry(.0065,.03,5),tooth);c.rotation.z=Math.PI;c.position.set(.1+.026*t,-.034,s*(.054-.0035*t));head.add(c);}}
  o.jawG=new T.Group();head.add(o.jawG);
  ell(o.jawG,mouth,.15,.006,.052).position.set(.16,-.002,0);
  o.rami=[-1,1].map(s=>{const g=new T.Group();o.jawG.add(g);const r=ell(g,pale,.15,.017,.021);r.position.set(.17,-.012,0);g.position.z=s*.06;
    for(let t=0;t<8;t++){const c=new T.Mesh(new T.ConeGeometry(.0058,.026,5),tooth);c.position.set(.06+.026*t,.005,0);g.add(c);}return g;});
  o.tg=new T.Group();o.tg.position.set(.3,-.006,0);o.jawG.add(o.tg);const tm=lam('#d83a4a');
  const t0=new T.Mesh(new T.CylinderGeometry(.0042,.0042,1,5),tm);t0.rotation.z=Math.PI/2;t0.position.x=.5;o.tg.add(t0);
  o.forks=[-1,1].map(s=>{const f=new T.Mesh(new T.CylinderGeometry(.003,.0018,.4,5),tm);f.position.set(1.15,0,s*.02);f.rotation.z=Math.PI/2;f.rotation.x=s*.5;o.tg.add(f);return f;});
  o.cheeks=[-1,1].map(s=>{const m=ell(head,new T.MeshLambertMaterial({color:'#8ba05a',transparent:true,opacity:.42,depthWrite:false,side:T.DoubleSide}),.15,.05,.004);m.position.z=s*.066;return m;});
  o.prey=makePrey(scene);return o;
}
function frame(o,u,ov){
  ov=ov||{};const S=sched(u,ov),ru=ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru),dk=ov.digK!==undefined?ov.digK:digK(u);
  const walk=ramp(ru,SW-100,SW+700),tt=u/1000;
  // head frame
  const al=S.alpha+(ov.spitK?.5*ov.spitK:0)+(ov.retch?.15*ov.retch:0),pitch=S.pitch+.1*(ov.retch||0)*(ov.rev>0?1:0)-.25*(ov.hit||0)-.2*(ov.spitK||0)*0;
  const hyG=Math.max(.058,.035+LH*Math.max(0,Math.sin(al-pitch)))+S.lift;
  const dt=S.dt+(ov.spitK?.1*ov.spitK:0);
  const tipX=rx+XP+dt;
  let hz=0;const Ah=.13*walk;
  const yaw=S.yaw+(walk>0?.2*Math.cos(KW*tipX+PHI)*walk*.8:0)+.2*Math.sin(u/600)*ramp(u,0,500)*(1-ramp(u,900,1100))+(ov.hit?.25*ov.hit*Math.sin(u/25):0);
  const Qh=qEul(yaw,pitch+.012*Math.sin(u/500),S.roll),fw=X.clone().applyQuaternion(Qh);
  const hinge=V(tipX,0,0).addScaledVector(fw,-LH);hinge.y=hyG;
  hz=Ah*Math.sin(KW*hinge.x+PHI)+.05*Math.sin(u/900)*(1-walk)*ramp(u,0,600)*(1-ramp(u,900,1100));hinge.z+=hz;
  if(ov.spitK)hinge.x+=0;
  o.head.scale.setScalar(HS);o.head.position.copy(hinge);o.head.quaternion.copy(Qh);
  o.jawG.rotation.z=-al;
  o.rami.forEach((g,i)=>{const j=i?S.jR:S.jL;g.position.x=j.o/HS;g.position.y=j.lift/HS;});
  const gap=LH*.5*Math.sin(al)+.02,ytop=-.02;
  o.cheeks.forEach(c=>{c.scale.set(.15,.5*(gap+.02)+.002,.004);c.position.set(.165+(S.jL.o+S.jR.o)*.2,ytop-.5*gap,c.position.z);c.visible=al>.2;});
  o.tg.scale.set(.3+.7*S.tongue,1,1);o.tg.position.x=.3;o.tg.visible=S.tongue>.02||al>.3;o.tg.children[0].scale.y=.26*S.tongue+.01;o.tg.children[0].position.x=.13*S.tongue;
  o.forks.forEach((f,i)=>{f.position.x=.26*S.tongue+.04;f.visible=S.tongue>.1;});
  // body path
  const A1=.30,A=x=>(Ah+(A1-Ah)*sm((hinge.x-x)/1.6)),zT=x=>A(x)*Math.sin(KW*x+PHI);
  const xg=hinge.x-(.85+1.5*Math.max(0,hinge.y-.08)),G=V(xg,RG,zT(xg)),dz=(zT(xg-.02)-zT(xg+.02))/-.04;
  const p1=hinge.clone().addScaledVector(fw,-.5),p2=G.clone().add(V(.5,0,.5*dz));
  const poly=BB.bezPath(hinge,p1,p2,G,22);for(let x=xg-.05;x>xg-5.6;x-=.05)poly.push(V(x,RG,zT(x)));
  const pts=arcSample(poly,DS,NR-1);
  // radii: skin plus the prey-shaped lump, pulsing with the swallow
  const rA=new Array(NR),st=new Array(NR);
  const Lp=S.Lp,Rp=RP*1.32*dk,pulse=1+.1*S.surge;
  const wave=(a)=>{if(u<GU0||u>GU1+200)return 1;const f=(u-GU0)/1000;return 1+.08*Math.sin((a*5.5-f*14))*Math.sin(Math.PI*clamp(f,0,1));};
  for(let i=0;i<NR;i++){const a=i*DS,base=rb(a);let lr=lumpR(a,S.aF,Lp,Rp)*pulse*wave(a);
    if(ov.retch)lr*=1+.09*Math.sin(a*12-u/45)*ov.retch;
    const r=Math.max(base,lr);rA[i]=r;st[i]=r>base*1.12?clamp((r/base-1.1)/1.2,0,1):0;
    if(pts[i].y<r+.004)pts[i].y=r+.004;}
  const col=(i,ang,out)=>{const f=i/(NR-1),s3=f*3.2,bel=sm((-Math.cos(ang)-.2)/.45),diam=sm((.62-Math.abs(((s3*5.5)%1)-.5)*2-Math.abs(Math.sin(ang))*.9)/.12)*(1-bel);
    const m=.03*hash(i,Math.round(ang*3));let c=[BODY[0]+m,BODY[1]+m,BODY[2]+m*.5];
    c=[c[0]+(DARK[0]-c[0])*diam,c[1]+(DARK[1]-c[1])*diam,c[2]+(DARK[2]-c[2])*diam];c=[c[0]+(BELLY[0]-c[0])*bel,c[1]+(BELLY[1]-c[1])*bel,c[2]+(BELLY[2]-c[2])*bel];
    const sx=st[i];if(sx>0){const sp=.5*sx*(1-bel*.6);c=[c[0]+(.78-c[0])*sp*.55+.03*diam,c[1]+(.74-c[1])*sp*.55,c[2]+(.46-c[2])*sp*.55];}  // stretched skin goes paler, the scale pattern spreads
    const fl=ov.hit?ov.hit*.2:0;out[0]=c[0]+(1-c[0])*fl;out[1]=c[1]+(1-c[1])*fl;out[2]=c[2]+(1-c[2])*fl;};
  o.body.update(pts,rA,rA,Y,col);
  const sc=(i,ang,out)=>{out[0]=out[1]=out[2]=0;};
  o.shad.update(pts.map(p=>V(p.x,.004,p.z)),rA.map(()=>.002),rA.map(r=>r*1.35+.02),Y,sc);
  // prey on the ground, nose to the snake
  const lie=new T.Quaternion().setFromAxisAngle(Y,Math.PI+.1).multiply(new T.Quaternion().setFromAxisAngle(X,.25));
  const tug=-.016*Math.sin(Math.PI*S.q)*S.w+(S.k%2?.004:-.004)*S.w;
  const stun=1-.4*ramp(u,GR0+350,GR0+600);
  const pp=V(rx+XP+PREY.nose+tug,.098,.0);
  const inside=S.aF>=LP*.995&&u>=WK1-80;
  const hit=ov.hit||0;
  drawPrey(o.prey,{pos:pp,q:lie,s:dk,fold:0,stun:stun*(u<SW+200?1:0),swing:.1*Math.sin(u/330),tr:u,vis:!inside&&u<GU0+50,flash:0,
    clip:{p:hinge.clone(),n:fw.clone()}},ov,u);
  EG.flashMats(o.mats,hit*.22);
  return {aF:S.aF,bulge:dk*clamp((S.aF-.2)/1.2,0,1),mouth:hinge.clone().addScaledVector(fw,LH),rx};
}
function cam(u,ov){
  const ru=ov&&ov.rootU!==undefined?ov.rootU:u,rx=rootX(ru);let c;
  c=keys(u,[[0,.7,.34,3.2],[GR0,.95,.3,2.4],[1250,1.35,.26,1.75],[WK0,XP+.35,.25,1.75],[WK1,XP+.8,.27,1.9],[4900,XP+.95,.34,2.2],[5700,XP+.7,.3,2.8],[SW,XP+.1,.26,3.5],[SW+1500,XP+.1,.26,3.7]]);
  const f=ru>SW?0:0;return {cx:rx+c[0],cy:c[1],span:c[2],v:1.7};
}
EG.rigs.snake={id:'snake',label:'Snake',name:'Jaw walk',
  tag:'The head settles over the prey and the two jaw halves walk alternately: one hooks in and pulls while the other lets go and reaches, seven small ratchets. The throat bulges as the prey slides in, then the head lifts and a swallow wave pushes the lump into the body. Afterwards a flat belly bulge and a heavy slither.',
  org:'serpentine body (A49) with the fauces mouth part',
  lead:LEAD,ph:[['grab',GR0+700-GR0,'#d9576b'],['work it in',WK1-WK0,'#e0925c'],['final gulp',GU1-GU0,'#d9b24f'],['settle',SW-GU1,'#9a86d6']],
  swEnd:SW,u1:WK0,credit:GU1,digest:DIG,len:SW+DIG,digK,build,frame,cam,rootX,PS:1,
  notes:['ratchet x7','skin stretch','swallow wave']};
})();
