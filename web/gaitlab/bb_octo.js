'use strict';
// Body 3: OCTOPUS (A55) on a wet rock: bulb mantle, bulging eyes, siphon, 8 soft arms (Bezier paths, planted tips) with an arm web and per-vertex colour-change skin.
// sing = silent: siphon hum pulses (water jets, ripples) + web billow | dance = arm wave in rhythm | charm = offer a shell, a second arm reaches out | pose = colour-change skin waves (signature).
(function(){
const BB=window.BB,T=BB.T,{V,clamp,sm,lerp,env,bump,bumps,qEul,lam,place,ell,limb,GEO,X,Y,Z,Tube,bez}=BB;
const PSI=[-.62,-.2,.2,.62,-1.25,1.25,-2.0,2.0],ALEN=[.64,.66,.66,.64,.6,.6,.55,.55],RD=.95;
const ORDER=[6,4,0,1,2,3,5,7];            // arms sorted by heading, for the web
const NR=14,NA=8,NW=7;
const BASE=(i,rise)=>{const p=PSI[i];return V(.08+.075*Math.cos(p),.075+rise,.085*Math.sin(p));};
const REST_TIP=PSI.map((p,i)=>{const b=BASE(i,0),d=ALEN[i]*.8,sg=(i%2?1:-1)*(i<4?.07:.12);return V(b.x+Math.cos(p)*d-Math.sin(p)*sg*.0,.013,b.z+Math.sin(p)*d+Math.cos(p)*sg*.0);});
const MC=[[.17,.10,.03],[.10,.15,.10],[-.02,.21,.135],[-.15,.28,.15],[-.28,.36,.125],[-.38,.42,.04]];
const hash=(a,b)=>{const s=Math.sin(a*127.1+b*311.7)*43758.5453;return s-Math.floor(s);};
const mixc=(a,b,u)=>[a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u];
// skin colour: base mottled brick-brown, belly pale; display = travelling dark/bright bands + chromatophore spots (amp 0..1)
function skinColor(q,a,out,K){
  const m=hash(Math.round(q*34),Math.round(a*2.4)),bel=sm((-Math.cos(a)-.05)/.6);let c=mixc([.56+.07*m,.33+.05*m,.25+.04*m],[.86,.7,.64],bel);
  if(K.flush>0)c=mixc(c,K.fc,K.flush*(1-bel*.5));
  if(K.amp>0){const w=.5+.5*Math.sin(2*Math.PI*(q*2.2-K.ph)),w2=.5+.5*Math.sin(2*Math.PI*(q*4.4-K.ph*2+a*.0)),spot=hash(Math.round(q*60),Math.round(a*4.2))>.78?1:0;
    const dark=[.17,.04,.26],bright=[1,.72,.16],hot=[.95,.2,.45];let d=mixc(dark,bright,w);d=mixc(d,hot,w2*.35*(1-w));if(spot)d=mixc(d,[1,.96,.86],.85);
    c=mixc(c,d,K.amp*(1-bel*.35));}
  out[0]=c[0];out[1]=c[1];out[2]=c[2];
}
function build(scene){
  const o={fx:BB.FXPool(scene),K:{amp:0,ph:0,flush:0,fc:[1,1,1]}};
  o.mantle=new Tube(16,14);scene.add(o.mantle.mesh);
  o.arms=PSI.map(()=>{const t=new Tube(NR,8);scene.add(t.mesh);return t;});
  const wg=new T.BufferGeometry(),nv=NA*NW*2;wg.setAttribute('position',new T.BufferAttribute(new Float32Array(nv*3),3));wg.setAttribute('color',new T.BufferAttribute(new Float32Array(nv*3),3));
  const idx=[];for(let m=0;m<NA;m++)for(let k=0;k<NW-1;k++){const a=(m*NW+k)*2,b=a+1,c=a+2,d=a+3;idx.push(a,c,b,b,c,d);}wg.setIndex(idx);
  o.web=new T.Mesh(wg,new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide,transparent:true,opacity:.92}));o.web.frustumCulled=false;scene.add(o.web);
  const eyeW=lam('#d9c37a'),pup=lam('#0a0a0a'),ring=lam('#6a4a22');o.eyes=[-1,1].map(s=>{const g=new T.Group();scene.add(g);ell(g,ring,.052,.052,.052);const e=ell(g,eyeW,.045,.045,.045);e.position.set(0,0,s*.012);const p=ell(g,pup,.026,.007,.004);p.position.set(0,0,s*.048);return {g,s};});
  o.siphon=new T.Mesh(new T.CylinderGeometry(.018,.03,.12,8),lam('#8a5a46'));scene.add(o.siphon);
  const sh=new T.Group();ell(sh,lam('#f1e2d2'),.06,.04,.05);const sp=ell(sh,lam('#e8b6a4'),.045,.035,.04);sp.position.set(.01,.02,0);const sp2=ell(sh,lam('#d89a8c'),.03,.025,.03);sp2.position.set(.02,.04,0);
  sh.add(new T.Mesh(new T.TorusGeometry(.04,.008,6,14),lam('#fff6ec')));scene.add(sh);o.shell=sh;
  const sf=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sf.rotation.x=-Math.PI/2;sf.position.y=.003;scene.add(sf);o.shadow=sf;
  return o;
}
// ---------------------------------------------------------------- arm path
function armPath(B,Tp,o){
  const d=Tp.clone().sub(B),side=V(-d.z,0,d.x).normalize();
  const p1=B.clone().addScaledVector(d,.33).addScaledVector(Y,o.y1).addScaledVector(side,o.l1),p2=B.clone().addScaledVector(d,.66).addScaledVector(Y,o.y2).addScaledVector(side,o.l2);
  return BB.bezPath(B,p1,p2,Tp,NR-1);
}
function pose(act,g){
  const G=BB.GAME[act],W=G.W,ts=W+G.A,tb=W;
  const S={act,g,nodes:[],anchors:[],arcs:[],legErr:0};
  const Q={rise:0,mUp:0,roll:0,puff:0,bill:0,free:PSI.map(()=>null),shell:null,sig:0,K:{amp:0,ph:0,flush:0,fc:[1,1,1]},jet:[]};
  Q.rise=.004*Math.sin(g/500);Q.puff=.03*(.5+.5*Math.sin(g/700));
  let obs=0;
  const rest=i=>({w:0});
  if(act==='sing'){
    const e=env(g,-300,ts+400,450,500),n=bumps(g,W,3,300,60);
    Q.rise+=.025*e+.02*n;Q.mUp=.15*e;Q.puff=.06*e+.2*n;Q.bill=.35*e+.65*n;Q.K.flush=.4*n;Q.K.fc=[.82,.9,1];Q.sig=1;obs=Q.puff;Q.jet=[W,W+300,W+600];
  }else if(act==='dance'){
    const e=env(g,-700,W+300*4+500,550,500),bd=bumps(g,W,5,300,70);
    Q.rise+=.03*e+.03*bd;Q.mUp=.1*e;Q.roll=.06*Math.sin(2*Math.PI*(g-tb)/600)*e;Q.puff=.05*bd;Q.K.flush=.28*bd;Q.K.fc=[.95,.62,.3];
    for(let i=0;i<4;i++){const th=2*Math.PI*(g-tb-70*i)/600,c=Math.cos(th),s=Math.sin(th);Q.free[i]={w:e,up:.42+.14*c,out:.26,lat:.12*s,y1:.12+.1*c,y2:.08*c,l1:.1*Math.sin(th-.8),l2:-.1*Math.sin(th-.8+1.2)};}
    obs=Q.free[0].up*e;Q.dbg=0;
  }else if(act==='charm'){
    const q=sm((g+440)/600),back=sm((g-ts-1300)/900),qq=q*(1-back),bob=Math.cos(2*Math.PI*(g-W)/600)*sm((g-W)/200)*(1-back);
    Q.rise+=.03*qq;Q.mUp=-.1*qq;Q.puff=.05*qq;Q.K.flush=.45*qq*(.6+.4*bob);Q.K.fc=[.95,.55,.6];
    Q.free[2]={w:qq,up:.34+.025*bob,out:.46,lat:.02,y1:.2,y2:.22+.03*bob,l1:.02,l2:-.03,shellTip:true};
    Q.free[1]={w:qq,up:.08+.02*Math.sin(g/260)*qq,out:.64,lat:-.02+.04*Math.sin(g/320),y1:.03,y2:.07,l1:.05*Math.sin(g/300),l2:-.05*Math.sin(g/300+1),tipCurl:1};
    Q.shell=1;obs=q;
  }else{
    const f=sm((g+226)/700),back=sm((g-ts-1800)/800),s_=f*(1-back);
    Q.rise+=.075*s_;Q.mUp=.4*s_;Q.puff=.1*s_;Q.K.amp=s_;Q.K.ph=(g-tb)/600+.0;Q.K.flush=.0;
    const ac=bump(g,tb+300,80);Q.K.flush=.0;
    for(let i=0;i<4;i++){const hd=PSI[i]*1.6,sw=Math.sin(2*Math.PI*g/900+i*1.4);Q.free[i]={w:s_,hd,up:.5+.04*sw,out:.16,lat:0,y1:.15,y2:.05,l1:.09*sw,l2:-.09*Math.sin(2*Math.PI*g/900+i*1.4+1)};}
    obs=s_;
  }
  return fin(S,Q,obs);
}
function fin(S,Q,obs){
  const rise=Q.rise;S.Q=Q;S.obs=obs;S.paths=[];S.baseP=[];
  // mantle control points: tilt about the head, lateral roll
  const pivot=V(.10,.12,0),mp=MC.map((m,k)=>{let x=m[0],y=m[1];const a=Q.mUp*(k/5),dx=x-pivot.x,dy=y-pivot.y-0;x=pivot.x+dx*Math.cos(a)-dy*Math.sin(a);y=pivot.y+dx*Math.sin(a)+dy*Math.cos(a)+rise;return V(x,y,Q.roll*(k/5)*(k/5));});
  const cp=new T.CatmullRomCurve3(mp),rc=new T.CatmullRomCurve3(MC.map(m=>V(m[2],0,0))),np=16,pts=[],rad=[];
  for(let i=0;i<np;i++){const u=i/(np-1);pts.push(cp.getPoint(u));rad.push(Math.max(.006,rc.getPoint(u).x*(1+Q.puff)));}
  S.mantle={pts,rad};for(let i=0;i<np;i+=1)S.nodes.push({p:pts[i],r:rad[i]});
  S.eyeP=[];const eu=.2,ep=cp.getPoint(eu),er=rc.getPoint(eu).x*(1+Q.puff);for(const s of [-1,1])S.eyeP.push(ep.clone().add(V(.035,.05,s*er*.93)));
  S.sipP=cp.getPoint(.28).add(V(.02,.06,.075)); S.sipDir=V(.65,.45,.62).normalize();
  // arms
  for(let i=0;i<8;i++){const B=BASE(i,rise);B.z+=Q.roll*0;S.baseP.push(B);const fr=Q.free[i],A=REST_TIP[i];let Tp,prm,w=0;
    const dirH=V(Math.cos(PSI[i]),0,Math.sin(PSI[i])),sd=V(-dirH.z,0,dirH.x);
    if(fr&&fr.w>1e-4){w=fr.w;const hd=fr.hd!==undefined?fr.hd:PSI[i],dd=V(Math.cos(hd),0,Math.sin(hd));let ft=B.clone().addScaledVector(dd,fr.out).addScaledVector(sd,fr.lat).add(V(0,fr.up,0));
      Tp=A.clone().lerp(ft,w);prm={y1:lerp(Math.max(.02,B.y*.55),fr.y1,w),y2:lerp(.02,fr.y2,w),l1:fr.l1*w,l2:fr.l2*w};}
    else{Tp=A.clone();const cur=(i%2?1:-1)*(i<4?.09:.12);prm={y1:Math.max(.03,B.y*.55),y2:.03,l1:cur*1.6,l2:-cur*1.3};}
    const path=armPath(B,Tp,prm);const rd=[];
    for(let k=0;k<NR;k++){const s=k/(NR-1),r=.036*Math.pow(1-s,1.05)+.006+.012*Math.exp(-s*8);rd.push(r);if(path[k].y<r+.004)path[k].y=r+.004;S.nodes.push({p:path[k],r});}
    path[NR-1].copy(Tp.y<.02?V(Tp.x,Math.max(Tp.y,rd[NR-1]+.004),Tp.z):Tp);
    if(fr&&fr.w>1e-4&&fr.w<.9999||(fr&&fr.w>=.9999)){}
    S.paths.push({path,rd,w});S.anchors.push({id:'arm'+i,p:path[NR-1].clone(),on:w<1e-4});}
  if(Q.shell){const f=Q.free[2];const tp=S.paths[2].path[NR-1];S.shellP=tp.clone().add(V(.02,.05,.0));}
  S.fx={jet:Q.jet};return S;
}
function draw(o,S,act,g){
  const Q=S.Q,K=o.K;K.amp=Q.K.amp;K.ph=Q.K.ph;K.flush=Q.K.flush;K.fc=Q.K.fc;
  const m=S.mantle;
  o.mantle.update(m.pts,m.rad,(i,a,out)=>skinColor((1-i/15)*.5,a,out,K),Y);
  o.arms.forEach((t,i)=>{const P=S.paths[i];t.update(P.path,P.rd,(k,a,out)=>skinColor(.5+k/(NR-1)*.5,a,out,K),Y);});
  // web: strips between neighbouring arms (sorted by heading), billow lifts the skirt
  const wp=o.web.geometry.attributes.position.array,wc=o.web.geometry.attributes.color.array,out=[0,0,0];let n=0;
  for(let m_=0;m_<NA;m_++){const A=S.paths[ORDER[m_]].path,B=S.paths[ORDER[(m_+1)%NA]].path,lim=Math.max(S.paths[ORDER[m_]].w,S.paths[ORDER[(m_+1)%NA]].w),kE=Math.max(1,NW-1-Math.round(5*Math.min(1,lim*1.5)));
    for(let k0=0;k0<NW;k0++){const k=Math.min(k0,kE);const lift=Q.bill*.11*Math.sin(Math.PI*k/(NW-1))*1+.012,pa=A[k],pb=B[k];
      for(const p of [pa,pb]){wp[n*3]=p.x;wp[n*3+1]=p.y+(k>0?lift*(p===pb?1:1)*1:0);wp[n*3+2]=p.z;skinColor(.5+k/(NR-1)*.5,Math.PI*.42,out,K);wc[n*3]=out[0]*1.06;wc[n*3+1]=out[1]*1.06;wc[n*3+2]=out[2]*1.06;n++;}}}
  // web should arch over the gap: lift the mid of the gap by moving the second vertex only a bit; fine for a skirt look
  o.web.geometry.attributes.position.needsUpdate=true;o.web.geometry.attributes.color.needsUpdate=true;o.web.geometry.computeVertexNormals();
  o.eyes.forEach((e,i)=>{e.g.position.copy(S.eyeP[i]);e.g.rotation.y=i?0:Math.PI;});
  o.siphon.position.copy(S.sipP).addScaledVector(S.sipDir,.05);o.siphon.quaternion.setFromUnitVectors(Y,S.sipDir);
  o.shell.visible=!!Q.shell;if(o.shell.visible){o.shell.position.copy(S.shellP);o.shell.rotation.set(0,.5,.4);}
  o.shadow.position.set(.05,.003,0);o.shadow.scale.set(1.3,.9,1);o.shadow.material.opacity=.6;
  const fx=o.fx;fx.reset();const tipP=S.sipP.clone().addScaledVector(S.sipDir,.11);
  for(const t of S.fx.jet){for(let j=0;j<5;j++){const ph=(g-t-j*55)/800;if(ph>0&&ph<1){const sp=.28+.06*j;fx.dot(tipP.clone().addScaledVector(S.sipDir,sp*Math.sqrt(ph)*.55).add(V(.04*Math.sin(j*2.3)*ph,.34*ph*(1-.2*j/5),.06*Math.cos(j*1.7)*ph)),.012+.011*(j%3)+.01*ph,.65*Math.sin(Math.PI*Math.min(1,ph*1.1)),'#dff0ff');}}
    const ph=(g-t)/1100;if(ph>0&&ph<1)fx.ring(.0,.007,.0,.3+1.3*Math.pow(ph,.8),.5*Math.sin(Math.PI*Math.min(1,ph*1.05))*(1-ph*.5),'#cfe6ff');}
  if(act==='sing')BB.noteBurst(fx,S.fx.jet,g,tipP.clone(),'#c9743f',BB.rigs.octo.height);
  fx.flush();
}
const ACTS={
 sing:{id:'siphon-hum',name:'Siphon hum + web billow',tag:'no voice: the mantle swells and the siphon jets three pulses (bubbles, ripples on the wet rock) while the arm web billows on the beat',organ:'siphon + arm web (resonating mantle)',tier:2,mode:'max'},
 dance:{id:'arm-wave',name:'Arm wave',tag:'four front arms rise and sway in a travelling wave on the beat, mantle bobbing, the rear arms stay planted',organ:'8 soft arms',tier:2,mode:'max'},
 charm:{id:'shell-offer',name:'Shell offer + gentle reach',tag:'one arm holds a shell out, a second arm reaches forward low and gentle, the skin flushes soft rose',organ:'soft arm tips (tentacle)',tier:2,mode:'arrive'},
 pose:{id:'colour-waves',name:'Colour-change skin waves',tag:'mantle lifts and the front arms crown while bands of violet, amber and white spots roll from mantle to arm tips in time',organ:'colour-change skin (chromatophores)',tier:'S',mode:'arrive'}};
BB.rigs.octo={id:'octo',label:'Octopus',TD:2.0,cam:{h:1.2,cx:.7,ty:.27},height:.5,env:'rock',tbow:-0.95,build,pose,draw,acts:ACTS};
})();
