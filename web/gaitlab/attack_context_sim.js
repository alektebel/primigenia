'use strict';
// Context-attack lab, simulation: paths, event-driven gait, attack layer, contact/aim solves, reactions, projectiles, fx, frame table.
(function(root){
const C=root.ACCORE0,{T,REST,V,interp,frames,skel,toWorld,toLocal,hipW,STY,strideOf,patternAt,rot,fwd,clamp,sm,fr,G,DT,H,FY,R,CY,PI,P0,HIPL,REST_XZ,LEG_L}=C;
const Y=new T.Vector3(0,1,0);
const FPS=1/DT;
const lerp=(a,b,e)=>a+(b-a)*e;const fwd0=a=>[Math.cos(a),-Math.sin(a)];
function K(keys,ms){return interp(keys,ms);}
// ---------------------------------------------------------------- shot solve helpers
function toArrive(m,A,tof){return [(A[0]-m[0])/tof,(A[1]-m[1]+.5*G*tof*tof)/tof,(A[2]-m[2])/tof];}
const HR=.30;
// ================================================================ simulate one scenario spec into a frame table
function simulate(spec){
  const N=Math.round(spec.dur/DT)+1,NX=N+300,t_=i=>i*DT;
  const idx=t=>clamp(Math.round(t/DT),0,NX-1);
  const lay=spec.layer||{ch:{},wc:null},A0=spec.anchor;               // layer keys: ms relative to A0
  // ---------------- 1 path of B (v keys and heading keys; an optional leap flight is derived from the target)
  const bx=new Float64Array(NX),bz=new Float64Array(NX),byaw=new Float64Array(NX),bv=new Float64Array(NX);
  const tx=new Float64Array(NX),tz=new Float64Array(NX),tyaw=new Float64Array(NX),tv=new Float64Array(NX);
  const hasT=!!spec.tgt,tg=spec.tgt;
  const tvAt=t=>interp(tg.v,t),tyAt=t=>tg.yaw?interp(tg.yaw,t):0;
  const fl=spec.flight;let flStart=-1,flEnd=-1,flFrom=null,flTo=null,tBuilt=false;
  const buildTarget=ia=>{ // anchor the target path at index ia to B's pivot at that time, then integrate both ways
    const ta=t_(ia),yw=byaw[ia],o=rot(yw,tg.anchor.rel[0],tg.anchor.rel[1]);
    tx[ia]=bx[ia]+o[0];tz[ia]=bz[ia]+o[1];
    for(let i=ia+1;i<NX;i++){const t=t_(i-1),v=tvAt(t),a=tyAt(t);tx[i]=tx[i-1]+v*Math.cos(a)*DT;tz[i]=tz[i-1]-v*Math.sin(a)*DT;}
    for(let i=ia-1;i>=0;i--){const t=t_(i),v=tvAt(t),a=tyAt(t);tx[i]=tx[i+1]-v*Math.cos(a)*DT;tz[i]=tz[i+1]+v*Math.sin(a)*DT;}
    for(let i=0;i<NX;i++){tv[i]=tvAt(t_(i));tyaw[i]=tyAt(t_(i));}
    tBuilt=true;};
  const ia=hasT?idx(tg.anchor.t):-1;
  if(fl){flStart=idx(fl.t0);flEnd=idx(fl.t1);}
  bx[0]=spec.x0||0;bz[0]=spec.z0||0;byaw[0]=interp(spec.Byaw||[[0,0]],0);
  for(let i=0;i<NX;i++){
    const t=t_(i);
    if(i>0){
      if(fl&&i>flStart&&i<=flEnd){ // derived leap: straight line from take-off to the landing pivot
        if(!flFrom){flFrom=[bx[flStart],bz[flStart]];const tc=[tx[flEnd],tz[flEnd]];
          const dir=Math.atan2(-(tc[1]-flFrom[1]),tc[0]-flFrom[0]),lo=rot(dir,fl.rel[0],fl.rel[1]);flTo=[tc[0]-lo[0],tc[1]-lo[1]];fl.yawF=dir;fl.from=flFrom;fl.to=flTo;}
        const u=(i-flStart)/(flEnd-flStart);bx[i]=lerp(flFrom[0],flTo[0],u);bz[i]=lerp(flFrom[1],flTo[1],u);
        const y0=byaw[flStart],yf=fl.yawF;byaw[i]=y0+(yf-y0)*sm(u*3);
        bv[i]=Math.hypot(flTo[0]-flFrom[0],flTo[1]-flFrom[1])/(fl.t1-fl.t0);
      }else{
        const v=interp(spec.Bv,t_(i-1)),ya=(fl&&i>flEnd)?fl.yawF:interp(spec.Byaw||[[0,0]],t);
        bv[i-1]=v;byaw[i]=ya;bx[i]=bx[i-1]+v*Math.cos(byaw[i-1])*DT;bz[i]=bz[i-1]-v*Math.sin(byaw[i-1])*DT;
      }
    }
    if(hasT&&!tBuilt&&i===ia)buildTarget(ia);
  }
  if(hasT&&!tBuilt)buildTarget(Math.min(ia,NX-1));
  bv[NX-1]=bv[NX-2];
  if(fl&&flFrom){for(let i=flEnd+1;i<NX;i++){/* continue from landing already integrated with yawF */}}
  const pivAt=t=>{const f=clamp(t/DT,0,NX-1.001),i=Math.floor(f),u=f-i;return [lerp(bx[i],bx[i+1],u),lerp(bz[i],bz[i+1],u),lerp(byaw[i],byaw[i+1],u)];};
  // ---------------- gait pattern and phase (phase advances by v / stride; the burst window forces the gallop pattern from a standstill)
  const PAT=new Array(NX),PHI=new Float64Array(NX),inFlight=i=>fl&&i>=flStart&&i<flEnd;
  let pat='stand';PHI[0]=0;
  for(let i=0;i<NX;i++){
    const t=t_(i),burst=spec.burst&&t>=spec.burst[0]&&t<spec.burst[1];
    pat=inFlight(i)?'stand':patternAt(pat,bv[i],burst);PAT[i]=pat;
    if(i>0){const p=PAT[i-1];PHI[i]=PHI[i-1]+(p==='stand'?0:Math.max(bv[i-1],p==='gallop'&&burst?1.2:0)/strideOf(p,Math.max(bv[i-1],p==='gallop'&&burst?1.2:0))*DT);}
  }
  const timeOfPhi=(ph,i0)=>{let j=i0;while(j<NX-1&&PHI[j]<ph)j++;if(PHI[j]>=ph){const a=PHI[Math.max(0,j-1)],b=PHI[j];return (Math.max(0,j-1)+(b>a?(ph-a)/(b-a):0))*DT;}
    const F=Math.max(.5,(PHI[NX-1]-PHI[NX-30])/(29*DT));return t_(NX-1)+(ph-PHI[NX-1])/F;};
  // ---------------- 2 frames
  const frames_=[],lg=[0,1,2,3].map(i=>{const p0=pivAt(0),o=rot(p0[2],REST_XZ[i][0],REST_XZ[i][1]);return {mode:'st',p:[p0[0]+o[0],p0[1]+o[1]],p0:null,p1:null,t0:0,t1:0,below:true,lift:.1,air:null,td:-9,dust:0};});
  const g={height:1,bob:0,roll:0,rock:0,pitch:0,lift:.1,fl:0,wide:0,polez:0,bobPh:0};
  const avgRestHip=H;let hipYprev=H,prevPat='stand',standSince=0,prevF=null;
  const awins=(spec.air||[]);
  const hit=spec.hit||null;let ih=hit&&hit.t!==undefined?idx(hit.t):-1;
  // target dynamic state after the hit
  const D={x:0,z:0,ux:0,uz:0,yaw:0,on:false,phase:0,tau0:0};
  let preyPhase=0;
  const proj=[],fx=(spec.fx=[]);let shotsMade=false,aimInfo=null;
  const metrics={minClear:9,legErr:0,neckErr:0,minY:9,stanceErr:0,maxStretch:0,contactErr:null,minRel:9,slideCm:0};
  const rec=[];
  // roar ring
  if(spec.roar){const rr=spec.roar,ie=idx(rr.te),c=[bx[ie],bz[ie]];rr.C=c;rr.hitIdx=-1;
    for(let i=ie;i<NX;i++){const tau=t_(i)-rr.te,u=clamp(tau/rr.dur,0,1),Rr=rr.radius*(1-Math.pow(1-u,2.2));if(Rr>=Math.hypot(tx[i]-bx[i],tz[i]-bz[i])){rr.hitIdx=i;rr.hitCenter=[bx[i],bz[i]];break;}}
    if(rr.hitIdx>=0){ih=rr.hitIdx;hit.t=t_(ih);}}
  if(hit&&ih>=0){hit.yawC=byaw[ih];if(hit.impulseLocal){hit.impulse=rot(byaw[ih],hit.impulseLocal[0],hit.impulseLocal[1]);}hit.dirW=fwd0(byaw[ih]);}
  const preCenter=(t)=>{const i=idx(t);return [tx[i],CY,tz[i]];};
  const resume=hit&&hit.resume;
  for(let i=0;i<N;i++){
    const t=t_(i),P={bx:0,by:0,bz:0,yaw:0,pitch:0,roll:0,sp:0,hp:0,hyaw:0,hroll:0,gape:0,stretch:1,tailP:0,tailY:0,fxF:0,fxH:0,hd:[0,0,0],chest:0,thr:0,crest:0,cheek:0,glow:0,mg:0,polez:0,feetT:new Float32Array(12)};
    const pv=pivAt(t),piv=[pv[0],pv[1]],yw=pv[2],pt=PAT[i],sty=STY[pt],phi=PHI[i];
    if(pt!==prevPat){for(let k=0;k<4;k++)if(lg[k].mode==='st'){const q=fr(phi-sty.off[k]);lg[k].below=q<sty.beta;}if(pt==='stand')standSince=t;prevPat=pt;}
    const ams=(t-A0)*1000,inWin=lay.win&&ams>=lay.win[0]-1&&ams<=lay.win[1];
    const locked=(spec.locks||[]).some(l=>t>=l[0]&&t<=l[1])||(inWin&&!!lay.noForce);
    // --- legs
    const restOf=(k,wide)=>[REST_XZ[k][0],(k%2?1:-1)*(.165+wide*H)];
    const planFor=(k,tMid,wide)=>{const pm=pivAt(tMid),o=rot(pm[2],...restOf(k,wide));return [pm[0]+o[0],pm[1]+o[1]];};
    let wR=0,wL=0,wMax=0;const anySwing=lg.some(l=>l.mode!=='st');
    for(let k=0;k<4;k++){
      const l=lg[k];
      // air windows (leap, rear-up)
      for(const aw of awins){if(aw.legs.includes(k)&&t>=aw.t0&&t<aw.t1&&l.air!==aw){
        const cur=l.mode==='st'?l.p:[l.cur?l.cur[0]:l.p[0],l.cur?l.cur[1]:l.p[1]];
        const pm=pivAt(aw.t1),o=rot(pm[2],aw.land?aw.land[k][0]:REST_XZ[k][0],aw.land?aw.land[k][1]:REST_XZ[k][1]);
        l.mode='air';l.air=aw;l.p0=cur.slice();l.p1=[pm[0]+o[0],pm[1]+o[1]];}}
      if(l.mode==='air'){
        const aw=l.air;
        if(t>=aw.t1){l.mode='st';l.p=l.p1;l.air=null;l.below=false;l.td=t;if(aw.dust)fx.push({ta:t,x:l.p[0],y:0,z:l.p[1],kind:'puff',n:aw.dust,s:.7});}
      }
      if(l.mode==='sw'&&t>=l.t1){l.mode='st';l.p=l.p1;l.td=t;if(l.dust)fx.push({ta:t,x:l.p[0],y:0,z:l.p[1],kind:'puff',n:l.dust,s:.35});}
      if(l.mode==='st'){
        const q=fr(phi-sty.off[k]);let lift=false,forced=false,dur=0,p1=null,dtm=0;
        if(pt!=='stand'&&!inFlight(i)){
          if(q<sty.beta)l.below=true;
          else if(l.below){lift=true;const phiTd=phi+(1-q),tTd=timeOfPhi(phiTd,i),tM=timeOfPhi(phiTd+sty.beta/2,i);dur=Math.max(.06,tTd-t);let tm=tM;if(dur>.5||PAT[Math.min(NX-1,idx(tM))]==='stand'){dur=Math.min(dur,.22);tm=t+dur+.08;}p1=planFor(k,tm,sty.wide);l.lift=sty.lift;}
        }
        if(!lift&&!locked&&!inFlight(i)){
          const pp=pivAt(t),o=rot(pp[2],HIPL[k][0],HIPL[k][2]),dx=pp[0]+o[0]-l.p[0],dz=pp[1]+o[1]-l.p[1],dy=hipYprev-FY;
          if(dx*dx+dz*dz+dy*dy>Math.pow(LEG_L[k]*.975,2)){forced=true;dur=.17;p1=planFor(k,t+dur+.1,sty.wide);l.lift=.1;}
          else if(pt==='stand'&&t-standSince>.3&&!anySwing&&bv[i]<.1){const rw=planFor(k,t+.2,0);if(Math.hypot(rw[0]-l.p[0],rw[1]-l.p[1])>.07){forced=true;dur=.2;p1=rw;l.lift=.1;}}
        }
        if((lift||forced)&&fl&&t<fl.t0&&t+dur>fl.t0){dur=Math.max(.03,fl.t0-t);p1=planFor(k,fl.t0,sty.wide);}
        if((lift||forced)&&fl&&t>=fl.t0&&t<fl.t1)lift=forced=false;
        if(lift||forced){l.mode='sw';l.p0=l.p.slice();l.p1=p1;l.t0=t;l.t1=t+dur;l.dust=bv[i]>2.2?2:(bv[i]>1?1:0);l.below=false;}
      }
      // targets
      let tgx,tgy,tgz;
      if(l.mode==='st'){tgx=l.p[0];tgy=FY;tgz=l.p[1];
        const qq=fr(phi-sty.off[k]),w=pt==='stand'?0:Math.sin(PI*clamp(qq/sty.beta,0,1));if(k%2)wR=Math.max(wR,w);else wL=Math.max(wL,w);wMax=Math.max(wMax,w);}
      else if(l.mode==='sw'){const u=clamp((t-l.t0)/(l.t1-l.t0),0,1),e=sm(u);tgx=lerp(l.p0[0],l.p1[0],e);tgz=lerp(l.p0[1],l.p1[1],e);tgy=FY+l.lift*H*Math.sin(PI*u);l.cur=[tgx,tgz];}
      else{ // air
        const aw=l.air,ms=(t-aw.t0)*1000,Bv_=interp(aw.B,ms),w=Math.min(sm(ms/(aw.in||35)),sm((aw.t1-t)*1000/(aw.out||60)));
        const hip=prevF?prevF.hips[k]:V(0,H,0),Bw=V(Bv_[0],Bv_[1],Bv_[2]).applyQuaternion(prevF?(k>=2?prevF.F.Qf:prevF.F.Qr):new T.Quaternion());
        const half=(aw.t0+aw.t1)/2,Wp=t<half?l.p0:l.p1;
        tgx=lerp(Wp[0],hip.x+Bw.x,w);tgz=lerp(Wp[1],hip.z+Bw.z,w);tgy=Math.max(FY,lerp(FY,hip.y+Bw.y,w));l.cur=[tgx,tgz];
      }
      P.feetT[k*3]=tgx;P.feetT[k*3+1]=tgy;P.feetT[k*3+2]=tgz;
    }
    // --- body from the gait
    const kk=1-Math.exp(-DT/.12);
    for(const n of ['height','bob','roll','rock','pitch','lift','wide','polez'])g[n]+=((n==='lift'?sty.lift:sty[n])-g[n])*kk;
    g.fl+=((sty.flight?1:0)-g.fl)*kk;
    const theta=2*PI*phi,wave=Math.sin(theta+2*PI*sty.bobPhase);
    const moving=pt!=='stand';
    let yb=H*g.height+H*g.bob*(moving?(g.fl*(1-wMax)+(1-g.fl)*wave):0);
    P.pitch=-(g.pitch+(moving?g.rock*Math.sin(theta):0));P.roll=g.roll*(wR-wL);P.sp=-.55*P.pitch;P.tailP=.6*P.pitch;P.polez=g.polez;
    P.yaw=yw;P.by=yb-H;
    P.bx=piv[0]-P0.x;P.bz=piv[1];
    // reach: lower the body until no stance leg is over-extended (as the A42 lab does)
    const reach=()=>{const F=frames(P);let need=0;for(let k=0;k<4;k++){if(lg[k].mode==='air')continue;const hp=hipW(P,F,k),tx_=P.feetT[k*3],ty=P.feetT[k*3+1],tz_=P.feetT[k*3+2],L=LEG_L[k]*.96,hor=(hp.x-tx_)**2+(hp.z-tz_)**2;
      need=Math.max(need,hor<L*L?hp.y-ty-Math.sqrt(L*L-hor):.1*H);}return need;};
    for(let it=0;it<8;it++){const nd=reach();if(nd<=1e-5)break;P.by=Math.max(-.32,P.by-nd);}
    const gaitBy=P.by;
    // --- attack layer (additive, ms relative to the anchor)
    const ch=lay.ch||{};let lbx=0,lby=0;
    if(inWin||(lay.always)){
      lbx=ch.bx?K(ch.bx,ams):0;lby=ch.by?K(ch.by,ams):0;
      P.by+=lby;P.pitch+=ch.pitch?K(ch.pitch,ams):0;P.sp+=ch.sp?K(ch.sp,ams):0;P.tailP+=ch.tailP?K(ch.tailP,ams):0;P.tailY+=ch.tailY?K(ch.tailY,ams):0;
      P.roll+=ch.roll?K(ch.roll,ams):0;P.yaw+=ch.yaw?K(ch.yaw,ams):0;P.gape=ch.gape?K(ch.gape,ams):0;P.hroll=ch.hroll?K(ch.hroll,ams):0;
      for(const n of ['chest','thr','crest','cheek','glow','mg'])P[n]=ch[n]?K(ch[n],ams):0;
      if(ch.stretch)P.stretch=K(ch.stretch,ams);
      if(ch.hd){const h=K(ch.hd,ams);P.hd=[h[0],h[1],h[2]];}
      if(ch.hp)P.hp=K(ch.hp,ams);
      if(ch.hpR)P.hp=K(ch.hpR,ams);
    }
    const f0=rot(P.yaw,1,0);P.bx+=lbx*Math.cos(P.yaw);P.bz+=-lbx*Math.sin(P.yaw);
    // flight arc (leap): absolute by from a ballistic parabola
    if(inFlight(i)){const Ts=fl.t1-fl.t0,tau=t-fl.t0,y0=fl.y0,y1=fl.y1,vy=(y1-y0)/Ts+G*Ts/2;P.by=y0+vy*tau-.5*G*tau*tau;P.pitch+=ch.pitch?0:0;}
    // --- target state
    let S=null,tgtC=null;
    if(hasT){S=targetAt(i);tgtC=[S.x,S.y,S.z];}
    // --- head: bite contact solve
    if(spec.contact&&lay.wc){const w=K(lay.wc,ams);
      if(w>1e-3&&S){const dl=spec.hit.dirLocal,dW=rot(spec.hit.yawC,dl[0],dl[2]),dir=V(dW[0],dl[1],dW[1]).normalize();
        const Tw=V(S.x,S.y,S.z).addScaledVector(dir,R-.006),sol=solveHead(P,Tw,lay.aC);
        P.hd=P.hd.map((v,j)=>lerp(v,sol.hd[j],w));P.hp=lerp(P.hp,sol.hp,w);P.hyaw=lerp(P.hyaw,sol.hy,w);}}
    // --- spit aim and projectiles
    if(spec.spit){aimStep(i,t,ams,P,S);}
    // --- skeleton and metrics
    {for(let it=0;it<5;it++){const s0=skel(P,false),d=.03-s0.nodes[0].y;if(d<=0)break;P.tailP-=d/.5;}}
    const sk=skel(P,true);prevF=sk;hipYprev=(sk.hips[0].y+sk.hips[2].y)/2;
    if(i===0||true){
      let lo=9,wh='';const chk=(y,n)=>{if(y<lo){lo=y;wh=n;}};sk.nodes.forEach((n,j)=>{if(j<7)chk(n.y-REST.nodes[j][2]*.9,'node'+j);});sk.knees.forEach((kn,j)=>chk(kn.y-.02,'knee'+j));sk.feet.forEach((f,j)=>chk(f.y-.03,'foot'+j));chk(sk.tip.y,'beak');chk(sk.head.y-REST.hr*.9,'head');
      if(lo<metrics.minY){metrics.minY=lo;metrics.tMinY=t;metrics.whMinY=wh;}const pushOff=awins.some(aw=>t>=aw.t0&&t<aw.t0+.12)||(spec.skid&&t>=spec.skid[0]&&t<=spec.skid[1]);if(!pushOff&&sk.legErr>metrics.legErr){metrics.legErr=sk.legErr;metrics.tLeg=t;}if(pushOff)metrics.pushOffErr=Math.max(metrics.pushOffErr||0,sk.legErr);if(sk.neckErr>metrics.neckErr){metrics.neckErr=sk.neckErr;metrics.tNeck=t;}metrics.maxStretch=Math.max(metrics.maxStretch,sk.stretch);
      // stance feet: the real IK foot must stay on its planted point
      for(let k=0;k<4;k++)if(lg[k].mode==='st'&&!locked&&!(spec.skid&&t>=spec.skid[0]&&t<=spec.skid[1])){const d=Math.hypot(sk.feet[k].x-lg[k].p[0],sk.feet[k].z-lg[k].p[1]);if(d>metrics.stanceErr)metrics.stanceErr=d;}
    }
    if(S){metrics.minRel=Math.min(metrics.minRel,Math.hypot(S.x-piv[0],S.z-piv[1]));
      const ht=hit&&hit.t!==undefined?hit.t:1e9;if(hit&&hit.kind==='pin'){}else if(t<ht-(hit&&hit.kind==='tackle'?.55:.25)||t>ht+(hit&&hit.kind==='tackle'?3:1.8)){const lx=(S.x-piv[0])*Math.cos(yw)-(S.z-piv[1])*Math.sin(yw),lz=(S.x-piv[0])*Math.sin(yw)+(S.z-piv[1])*Math.cos(yw),cx=Math.max(-.7,Math.min(.95,lx)),cl=Math.hypot(lx-cx,lz);if(cl<metrics.minClear){metrics.minClear=cl;metrics.tClear=t;}}}
    // contact measurement
    if(hit&&i===ih&&hit.kind!=='fear'&&hit.kind!=='acid'){
      if(spec.contact==='chest'){const nd=sk.nodes[5],c=V(S.x,S.y,S.z);metrics.contactErr=nd.distanceTo(c)-(R+.8*REST.nodes[5][2]);hit.err=metrics.contactErr;}
      else{const c=V(S.x,S.y,S.z);metrics.contactErr=sk.tip.distanceTo(c)-R;hit.err=metrics.contactErr;}
      metrics.stretchAtContact=sk.stretch;metrics.neckErrAtContact=sk.neckErr;
    }
    rec.push({ta:t,P,S,planted:lg.map(l=>l.mode==='st'),mode:lg.map(l=>l.mode),pat:pt,v:bv[i],piv:[piv[0],piv[1]],yaw:yw,tip:[sk.tip.x,sk.tip.y,sk.tip.z],mouth:[sk.tip.x-sk.axis.x*.035,sk.tip.y-sk.axis.y*.035,sk.tip.z-sk.axis.z*.035],gaitBy});
  }
  // ---------------- target dynamics (pre-hit from the path, post-hit reactions)
  function targetAt(i){
    const t=t_(i),S={x:tx[i],y:CY,z:tz[i],yaw:tyaw[i],pitch:0,roll:0,sx:1,sy:1,sz:1,leg:0,spd:tv[i],eye:0,flash:0,tint:0,held:false,stun:0};
    if(!hit||i<ih||ih<0){preyPhase+=tv[i]*DT*2.4;S.leg=preyPhase;S.y=CY+.02*Math.abs(Math.sin(preyPhase))*Math.min(1,tv[i]/1.2)+(tv[i]<.1?.004*Math.sin(t*3.1):0);
      const hy=Math.atan2(0,1);if(tv[i]<.1&&spec.tgt.look)S.yaw=spec.tgt.look;S.eye=0;return S;}
    const k=hit.kind,tau=(t-hit.t);
    if(i===ih){D.on=true;D.x=tx[i];D.z=tz[i];const a=tyaw[i],vp=tv[i];D.ux=vp*Math.cos(a);D.uz=-vp*Math.sin(a);D.yaw=a;D.phase=preyPhase;D.pre=[D.ux,D.uz];D.kicked=!hit.impulse;}
    if(!D.kicked&&tau>=(hit.slide||0)-1e-9){D.ux+=hit.impulse[0];D.uz+=hit.impulse[1];D.kicked=true;}
    if(k==='drag'){const dr=spec.hit.drag,tt=hit.t;dr.rel=dr.rel0=spec.tgt.anchor.rel.slice();
      if(t<=dr.t1){const e=sm((t-hit.t)/.15),o=rot(byaw[i],lerp(dr.rel0[0],dr.rel[0],e),lerp(dr.rel0[1],dr.rel[1],e));D.x=bx[i]+o[0];D.z=bz[i]+o[1];D.ux=bv[i]*Math.cos(byaw[i]);D.uz=-bv[i]*Math.sin(byaw[i]);D.yaw=byaw[i];S.held=true;}
      else{const m=Math.hypot(D.ux,D.uz);D.ux*=Math.exp(-hit.mu*DT);D.uz*=Math.exp(-hit.mu*DT);D.x+=D.ux*DT;D.z+=D.uz*DT;}
      if(t<=dr.t1){/* carried */}}
    else{
      const stun=hit.stun||0,res=hit.resumeAt!==undefined?hit.resumeAt:stun;
      let gx=0,gz=0;
      if(k==='fear'){const hc=spec.roar.hitCenter,away=Math.atan2(-(D.z-hc[1]),D.x-hc[0]);const sp=Math.max(0,sm((tau-.14)/.25))*(hit.flee||3)*(tau<1.2?1:Math.max(0,1-(tau-1.2)/.5));gx=sp*Math.cos(away);gz=-sp*Math.sin(away);D.yaw+=clamp(Math.atan2(Math.sin(away-D.yaw),Math.cos(away-D.yaw)),-DT*10,DT*10);}
      else if(k==='acid'){const slow=tau<(hit.slowS||2)?.35:Math.min(1,.35+(tau-(hit.slowS||2))/.6);gx=D.pre[0]*slow;gz=D.pre[1]*slow;}
      else if(k==='pin'){gx=gz=0;}
      else if(!D.kicked){gx=D.pre[0];gz=D.pre[1];}
      else{const r=sm((tau-res)/.45),pm=Math.hypot(D.pre[0],D.pre[1]),k=hit.resumeSpeed!==undefined&&pm>.05?hit.resumeSpeed/pm:(hit.resumeK===undefined?.8:hit.resumeK);gx=D.pre[0]*k*r;gz=D.pre[1]*k*r;}
      const mu=hit.mu||6;D.ux+=(gx-D.ux)*(1-Math.exp(-mu*DT));D.uz+=(gz-D.uz)*(1-Math.exp(-mu*DT));D.x+=D.ux*DT;D.z+=D.uz*DT;
      const sp=Math.hypot(D.ux,D.uz);if(sp>.5&&k!=='fear'&&k!=='pin'&&k!=='tackle'&&!(k==='acid')){const a=Math.atan2(-D.uz,D.ux);D.yaw+=clamp(Math.atan2(Math.sin(a-D.yaw),Math.cos(a-D.yaw)),-DT*4,DT*4);}
    }
    const spd=Math.hypot(D.ux,D.uz);D.phase+=spd*DT*2.4;
    S.x=D.x;S.z=D.z;S.yaw=D.yaw;S.leg=D.phase;S.spd=spd;S.y=CY+.02*Math.abs(Math.sin(D.phase))*Math.min(1,spd/1.2);
    const f=Math.exp(-tau/.09)*Math.cos(2*PI*tau/.17)*(hit.amp||.2);
    if(k==='knock'||k==='drag'){S.sx=1-f;S.sy=1+.5*f;S.sz=1+.5*f;S.y=CY+(hit.hop||.05)*Math.sin(PI*Math.min(tau/.2,1));S.pitch=(hit.tilt||.4)*Math.exp(-tau/.22)-.18*Math.exp(-tau/.12)*Math.sin(18*tau);S.roll=.16*Math.exp(-tau/.3)*Math.sin(14*tau);S.yaw+=.12*Math.exp(-tau/.3)*Math.sin(11*tau);S.eye=Math.max(0,1-tau/.5);S.flash=tau<.11?.32*(1-tau/.11):0;
      if(k==='drag'&&t<=spec.hit.drag.t1){S.sy=.88;S.sx=1.08;S.pitch=.25;S.eye=1;S.held=true;S.y=CY-.03;}}
    else if(k==='tackle'){const rise=hit.rise||1.0,roll=hit.rollMax*(1-Math.exp(-tau/.11))*(1-sm((tau-rise)/.32));S.sx=1-f;S.sy=1+.5*f;S.sz=1+.5*f;S.roll=roll+(tau>rise?.06*Math.sin((tau-rise)*25)*Math.exp(-(tau-rise)/.2):0);S.pitch=.25*Math.exp(-tau/.2);S.yaw+=hit.yawN*(1-Math.exp(-tau/.2));S.y=CY+(hit.hop||.15)*Math.sin(PI*Math.min(tau/.34,1));S.y=Math.max(S.y,.02+(.32*Math.cos(S.roll)+.2*Math.abs(Math.sin(S.roll)))*S.sy);S.eye=Math.max(0,1-tau/1.4);S.flash=tau<.11?.32*(1-tau/.11):0;}
    else if(k==='pin'){const rel=hit.rel,press=sm(tau/.11)*(1-sm((tau-rel)/.12)),r2=Math.max(0,tau-rel),wob=Math.exp(-r2/.18)*Math.cos(2*PI*r2/.22);S.sy=1-.3*press;S.sx=1+.14*press;S.sz=1+.14*press;S.y=.02+.32*S.sy;S.held=press>.5;S.pitch=r2>0?.22*wob:0;S.roll=r2>0?.28*wob:0;S.eye=Math.max(0,1-tau/1.4);S.flash=tau<.11?.32*(1-tau/.11):0;
      if(tau<rel+.2){S.x=D.x;S.z=D.z;}}
    else if(k==='acid'){S.sx=1-f*.6;S.sy=1+.3*f;S.sz=S.sx;S.y=CY+.06*Math.sin(PI*Math.min(tau/.25,1));S.pitch=.3*Math.exp(-tau/.2)*Math.sin(Math.min(tau,.4)*8);S.roll=.1*Math.sin(tau*22)*Math.exp(-tau/.4);S.tint=tau<(hit.slowS||2)?1:Math.max(0,1-(tau-(hit.slowS||2))/.8);S.eye=Math.max(0,1-tau/1.0);S.flash=.18*Math.exp(-tau/.12);}
    else if(k==='fear'){const sq=.16*Math.exp(-tau/.16)*Math.cos(tau*17);S.sy=1-sq*.9;S.sx=1+sq*.45;S.sz=S.sx;S.pitch=-.18*Math.exp(-tau/.2);S.y=CY+.15*Math.sin(PI*clamp(tau/.28,0,1))+.04*Math.abs(Math.sin(D.phase))*Math.min(1,spd/2);S.roll=.07*Math.sin(tau*30)*Math.exp(-tau/.3);S.eye=tau<1.2?1:Math.max(0,1-(tau-1.2)/.5);}
    S.y=Math.max(S.y,.02+(.32*Math.cos(S.roll)+.2*Math.abs(Math.sin(S.roll)))*S.sy);
    return S;
  }
  // ---------------- head solve for bite contact
  function solveHead(P,Tw,aC){
    const F=frames(P),Tl=toLocal(Tw,'f',P,F);let hy=0,hdv=[0,0,0],hp=aC-P.pitch-P.sp;
    for(let it=0;it<4;it++){
      const ax=[Math.cos(hp)*Math.cos(hy),-Math.sin(hp),-Math.cos(hp)*Math.sin(hy)],Hl=[Tl[0]-ax[0]*REST.beak,Tl[1]-ax[1]*REST.beak,Tl[2]-ax[2]*REST.beak];
      hdv=[Hl[0]-REST.nodes[7][0],Hl[1]-REST.nodes[7][1],Hl[2]];hy=Math.atan2(-(Tl[2]-Hl[2]),Tl[0]-Hl[0]);}
    return {hd:hdv,hp,hy};
  }
  // ---------------- spit: aim at the intercept point, fire a stream or a gob; the shot is ballistic p0 + v t - g t^2/2
  function aimStep(i,t,ams,P,S){
    const sp=spec.spit,wa=lay.wa?K(lay.wa,ams):0;if(wa<=1e-3)return;
    const te=Math.max(t,sp.ts);let mouth=null;
    let hpBase=P.hp,hyA=0,hpA=hpBase;
    for(let it=0;it<3;it++){
      const Pt=Object.assign({},P,{hp:it?hpA:hpBase,hyaw:it?hyA:0}),s0=skel(Pt,false),m=[s0.tip.x-s0.axis.x*.035,s0.tip.y-s0.axis.y*.035,s0.tip.z-s0.axis.z*.035];
      let tof=sp.tof||Math.hypot(...[0,1,2].map(j=>preCenter(te+.3)[j]-m[j]))/sp.speed,A;
      for(let k=0;k<4;k++){A=preCenter(te+tof);if(!sp.tof)tof=Math.hypot(A[0]-m[0],A[1]-m[1],A[2]-m[2])/sp.speed;}
      const v=toArrive(m,A,tof),vl=Math.hypot(...v),F=frames(Object.assign({},P,{hd:P.hd})),dirW=V(v[0]/vl,v[1]/vl,v[2]/vl),dl=dirW.clone().applyQuaternion(F.Qf.clone().invert());
      hpA=-Math.asin(clamp(dl.y,-1,1));hyA=Math.atan2(-dl.z,dl.x);mouth={m,v,A,tof};aimInfo={m,v,A,tof,te};
    }
    P.hp=lerp(hpBase,hpA,wa);P.hyaw=lerp(0,hyA,wa);
    if(hyA!==0&&sp.sideHd){P.hd=[P.hd[0],P.hd[1],P.hd[2]-sp.sideHd*Math.sin(hyA)*wa];}
    if(ams>=-1e-6&&ams<sp.dur*1000+4){ // one particle per frame of the stream
      const tof=mouth.tof,pr={te:t,p0:mouth.m.slice(),v:mouth.v,r:sp.r||.03,big:!!sp.big,life:2.4,A:mouth.A};
      // impact: first time within HR of the predicted target path
      let hitT=null;for(let s=.004;s<pr.life;s+=.002){const q=[pr.p0[0]+pr.v[0]*s,pr.p0[1]+pr.v[1]*s-.5*G*s*s,pr.p0[2]+pr.v[2]*s],c=preCenter(t+s);
        if(Math.hypot(q[0]-c[0],q[1]-c[1],q[2]-c[2])<HR){hitT=s;break;}if(q[1]<=.012&&s>.05){break;}}
      if(hitT===null){pr.endk='ground';let s=.05;while(s<pr.life&&pr.p0[1]+pr.v[1]*s-.5*G*s*s>.012)s+=.002;pr.end=t+s;}else{pr.endk='hit';pr.end=t+hitT;
        const c=preCenter(pr.end);pr.hitDist=Math.hypot(pr.p0[0]+pr.v[0]*hitT-c[0],pr.p0[1]+pr.v[1]*hitT-.5*G*hitT*hitT-c[1],pr.p0[2]+pr.v[2]*hitT-c[2]);}
      proj.push(pr);
      if(!spec.hit.t||pr.endk==='hit'&&(spec.hit.t===undefined||pr.end<spec.hit.t)){if(pr.endk==='hit'&&(!spec.hit.t||pr.end<spec.hit.t)){spec.hit.t=pr.end;ih=idx(pr.end);}}
    }
  }
  spec.proj=proj;
  proj.forEach((pr,k)=>{if(pr.endk==='hit'&&(k%4===0||pr.big)){const u=pr.end-pr.te,q=[pr.p0[0]+pr.v[0]*u,pr.p0[1]+pr.v[1]*u-.5*G*u*u,pr.p0[2]+pr.v[2]*u];fx.push({ta:pr.end,x:q[0],y:q[1],z:q[2],kind:'splash',n:pr.big?16:4,s:pr.big?1.5:.6});}});
  // ---------------- real-time table: insert the hit-pause (animation frozen, fx and flash keep running)
  const pauseSteps=hit&&hit.pause?Math.round(hit.pause/1000/DT):0;
  const real=[];
  const ihr=ih>=0?ih:-1;
  for(let i=0;i<rec.length;i++){real.push(rec[i]);if(i===ihr&&pauseSteps)for(let k=0;k<pauseSteps;k++)real.push(Object.assign({},rec[i],{frozen:k+1}));}
  const ihReal=ihr>=0?ihr:-1;
  spec.pauseSteps=pauseSteps;spec.ihAnim=ihr;spec.hitReal=ihReal;
  spec.frames=real;spec.metrics=metrics;spec.N=real.length;spec.realDur=real.length*DT;
  spec.pathArr={bx,bz,byaw,bv,tx,tz,tyaw,tv};
  spec.aimInfo=aimInfo;
  // fx: contact burst and puffs
  if(ihr>=0&&hit.kind!=='roar'){const S=rec[ihr].S;if(S)fx.push({ta:hit.t,x:S.x,y:Math.min(S.y,.3),z:S.z,kind:'burst',n:hit.kind==='tackle'?5:3,s:hit.kind==='tackle'?1.1:.7,dir:hit.dirW||[1,0]});}
  if(spec.roar&&spec.roar.rings)for(const r of spec.roar.rings)fx.push({ta:spec.roar.te+r.dt,x:spec.roar.C[0],y:0,z:spec.roar.C[1],kind:'ring',s:r.amp,dur:r.dur,follow:true});
  // camera tracks
  buildCams(spec);
  return spec;
}
function anim2real(spec,ta){const i=Math.round(ta/DT);return i+(i>spec.ihAnim&&spec.ihAnim>=0?spec.pauseSteps:0);}
function buildCams(spec){
  const fr_=spec.frames,n=fr_.length,cam=new Float32Array(n*3);let cx=null,cz=null,sp=null;
  const tau=.3,kk=1-Math.exp(-DT/tau);
  // fixed (preset) camera: standing = the pair at the anchor; moving = the action window around the anchor
  const ia=Math.max(0,Math.min(n-1,Math.round(spec.anchor/DT)));
  if(spec.ctx==='standing'&&spec.attack!=='pounce'){const f=fr_[ia],b=f.piv,s=f.S?[f.S.x,f.S.z]:b,d=Math.hypot(s[0]-b[0],s[1]-b[1]);spec.fixedCam={c:[(b[0]+s[0])/2+.15,(b[1]+s[1])/2],span:Math.max(2.9,d*1.2+2.0)};}
  else{let x0=1e9,x1=-1e9,z0=1e9,z1=-1e9;const i0=Math.max(0,ia-Math.round(1.4/DT)),i1=Math.min(n-1,ia+Math.round(1.4/DT));
    for(let i=i0;i<=i1;i++){const f=fr_[i],ps=[f.piv].concat(f.S?[[f.S.x,f.S.z]]:[]);for(const p of ps){x0=Math.min(x0,p[0]);x1=Math.max(x1,p[0]);z0=Math.min(z0,p[1]);z1=Math.max(z1,p[1]);}}
    spec.fixedCam={c:[(x0+x1)/2+.2,(z0+z1)/2],span:Math.max(2.9,Math.hypot(x1-x0,z1-z0)*.9+2.0)};}
  for(let i=0;i<n;i++){
    const f=fr_[i],b=f.piv,s=f.S?[f.S.x,f.S.z]:b,d=Math.hypot(s[0]-b[0],s[1]-b[1]);
    const lead=clamp(f.v*.18,0,.8),gx=lerp(b[0],s[0],.5)+lead*Math.cos(f.yaw),gz=lerp(b[1],s[1],.5)-lead*Math.sin(f.yaw),gs=clamp(2.2+.72*d,2.9,8.5);
    if(cx===null){cx=gx;cz=gz;sp=gs;}else{cx+=(gx-cx)*kk;cz+=(gz-cz)*kk;sp+=(gs-sp)*kk;}
    cam[i*3]=cx;cam[i*3+1]=cz;cam[i*3+2]=sp;
  }
  spec.cam=cam;
}
root.ACSIM={simulate,anim2real};
})(typeof window!=='undefined'?window:globalThis);
