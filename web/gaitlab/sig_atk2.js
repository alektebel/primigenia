'use strict';
// Signature attacks 9-16 (round 2).
(function(){
const BB=window.BB,T=BB.T,S=BB.sig,{V,clamp,sm,lam,limb,place}=BB,{ell,rp,eo,s2,tri,eb,rnd,lerpV,kf,TX,Beams,Quad,Pip,Serp,win,fr,spike,ramp,FIRE}=S;
const SIGB=window.SIGB,Y=BB.Y,PI=Math.PI;
// 9 ------------------------------------------------------------------------------------------- stink cloud
SIGB.stink_cloud=function(sc,def){
  const wh=[.95,.95,.92],c=Quad(sc,{col:'#1f2226',belly:'#2b2e35',dark:'#111',x0:.95,sl:.42,pr:[.21,.2,.16],cr:[.21,.2,.16],legU:.15,legL:.17,lr:.04,nl:.15,ns:5,nr0:.12,nr1:.085,na0:.5,nc0:-.3,hl:.11,hh:.085,hw:.07,sn:.09,snh:.04,snw:.04,tl:.6,ts:10,tr0:.07,tr1:.03,ta0:.2,tprof:u=>1+1.6*Math.sin(Math.PI*(u*.9+.05)),yaw0:PI,eye:.022,
    skin:(i,a,out,part)=>{if(part==='tail'&&Math.cos(a)>-.3){out[0]=out[1]=out[2]=.92;}}}),d=Pip(sc,2.45),T0=def.ti,wm=lam('#f2f2ec');
  ell(c.pel,wm,.34,.018,.05).position.set(.18,.19,0);for(const z of [-1,1]){const w2=ell(c.pel,wm,.3,.015,.04);w2.position.set(.2,.17,z*.07);w2.rotation.x=z*.3;}ell(c.head,wm,.1,.012,.02).position.set(.04,.085,0);
  return {pose(s,fx){
    const turn=kf(s,[[.2,0],[.65,1],[2.5,1],[3.0,0]]),yawA=PI*turn-PI*0,stomp=win(s,.72,1.02,.05)*Math.max(0,Math.sin((s-.72)*22)),lift=kf(s,[[.6,0],[.95,1],[1.05,1.1],[1.9,1],[2.5,0]]),spr=win(s,1.05,1.75,.08);
    // starts facing the dummy, spins round, plants the front feet, rear and tail up
    const P=S.idleP(s);P.yaw=PI-PI*turn*0+(-PI)*0;P.yaw=kf(s,[[.2,PI],[.65,PI*2],[2.5,PI*2],[3.0,PI*3]])-PI*2+PI;
    P.pitch=-.28*lift;P.y=c.h+.07*lift-.01*stomp;P.ta=1.2*lift+.12*Math.sin(s*30)*spr;P.tc=.9*lift;P.na=-.1*lift;P.ny=2.7*s2(s,.5,.9)*(1-s2(s,2.5,2.9));P.hp=.1*lift;P.jaw=.1*lift;
    P.tx=u=>[.05*Math.sin(s*25-u*5)*spr*u,.2*Math.sin(s*3-u*3)*u*(1-lift)];P.foot=[[0,.1*stomp,0],[0,.1*Math.max(0,Math.sin((s-.72)*22+3))*win(s,.72,1.02,.05),0],[0,0,0],[0,0,0]];P.br=P.br+.08*spr;
    c.pose(P);
    const tail=c.pel.localToWorld(V(-.18,.12,0)).add(V(0,0,0)),tg=V(2.2,.5,0);
    // the spray: a green jet, then the cloud rolls over the target
    fx.em(s,{t0:1.08,dt:.03,n:14,life:.4,pos:k=>tail.clone(),vel:k=>{const v=tg.clone().sub(tail).multiplyScalar(1/.3);v.y+=.5+rnd(k)*.6;v.z+=(rnd(k+3)-.5)*1.4;return v;},drag:1.2,size:(u,k)=>.1+.35*u,op:(u,k)=>.55*(1-u*.4)*(s<1.8?1:0),c:(u,k)=>k%2?'#8fbf5a':'#b6d878',tx:TX.puff,add:false,rot:(u,k)=>k});
    const grow=eo(rp(s,1.35,2.1)),life=1-s2(s,2.3,3.2);
    if(s>1.3)for(let k=0;k<16;k++){const az=k*2.4+s*.5*(k%2?1:-1),r=(.1+.75*grow)*(.4+.6*rnd(k)),p=V(2.2+Math.cos(az)*r*1.1+.15*Math.sin(s*1.3+k),.2+.55*rnd(k+2)*grow+.08*Math.sin(s*2+k*1.7),Math.sin(az)*r*.7);
      fx.p(p,.3+.65*grow*(.6+.4*rnd(k+5)),.34*life*s2(s,1.3,1.6),k%3?'#7aa83e':'#a8c860',TX.puff,false,k+s*.4);}
    // stink lines: wavy marks rise from the cloud
    if(s>1.5)for(let k=0;k<5;k++){const u=fr(s*.7+k*.21),p=V(1.8+.2*k+.04*Math.sin(u*14+k),.65+.8*u,(k-2)*.09);fx.p(p,.07,.5*life*(1-u)*s2(s,1.5,1.8),'#c8e890',TX.drop,true);}
    if(s>1.05&&s<1.9){fx.p(tail,.14+.1*Math.sin(s*40),.5*spr,'#b8e070',TX.soft,true);}
    // target: gags, eyes stream, stumbles back, turns and bolts, returns
    const a=s-T0,g=a>0?1:0,gag=win(s,T0,2.2,.1),ret=Math.sin(Math.max(0,a)*18)*Math.exp(-a*.9)*g;
    const run1=win(s,1.95,2.5,.12),run2=win(s,2.7,3.35,.15);
    d.set(s,{dx:kf(s,[[T0,0],[T0+.25,.18],[1.9,.3],[2.5,1.0],[2.7,1.0],[3.35,0]]),yaw:kf(s,[[1.8,0],[1.97,-PI],[2.65,-PI],[2.8,0]]),na:-.8*gag*s2(s,T0,T0+.2)-.35*Math.max(0,ret)*gag,hp:.5*gag,pitch:.2*gag,jaw:.55*Math.max(0,Math.sin(a*20))*gag,br:.1*Math.max(0,ret)*gag,ear:1.1*s2(s,T0,T0+.1)*(1-s2(s,2.9,3.2)),ta:1.1*gag*0+.8*s2(s,T0,T0+.2)*(1-s2(s,2.8,3.2)),sq:.1*Math.abs(Math.sin(a*20))*gag,dy:.05*Math.abs(Math.sin(s*22))*run1,
      follow:1,gait:{ph:s*24,amp:.15*Math.max(run1,run2*.7),lift:.08*Math.max(run1,run2*.7)},blind:false});
    d.tint('#86b640',.5*s2(s,T0-.1,T0+.3)*(1-s2(s,2.9,3.3)));
    if(s>T0&&s<2.9)for(let k=0;k<4;k++){const u=fr(s*1.3+k*.27);fx.p(d.chest.localToWorld(V(.0+.04*k,.1+.3*u,(k%2?1:-1)*.1)),.16+.2*u,.35*(1-u),'#9cc86a',TX.puff,false,k);}
    if(a>0&&a<.5)fx.p(d.head.position.clone().add(V(0,.05,0)),.25+.3*a,.7*(1-a/.5),'#c8f08a',TX.soft,true);
    return 0;}};
};
// 10 ------------------------------------------------------------------------------------------ blood squirt
SIGB.blood_squirt=function(sc,def){
  const c=Quad(sc,{col:'#b08a5a',belly:'#e0cba0',dark:'#6a4a2a',x0:.5,sl:.3,pr:[.24,.1,.2],cr:[.22,.1,.21],legU:.1,legL:.12,lr:.04,sprawl:1,hip:.2,nl:.08,ns:3,nr0:.12,nr1:.1,na0:.2,nc0:0,hlev:0,hfol:0,hl:.13,hh:.075,hw:.13,sn:.03,snh:.05,snw:.07,tl:.3,ts:6,tr0:.07,tr1:.01,ta0:0,eye:.04,eyeY:.75,toeL:.06,
    skin:(i,a,out)=>{const n=Math.sin(i*5+a*3);out[0]+=.04*n;out[1]+=.03*n;}}),d=Pip(sc,2.0),T0=def.ti,bm=Beams(sc),dm=lam('#6a4a2a'),sp=lam('#8a6a3a');
  for(const z of [-1,1]){for(let k=0;k<4;k++)spike(c.head,dm,.026-.003*k,.14-.015*k,-.07-.045*k,.05,z*(.08+.03*k),z*.6,.9+.12*k);for(let k=0;k<6;k++)spike(c.pel,sp,.02,.07,.0+k*.1-.1,.07,z*.22,z*1.1,0).rotation.x=z*1.2;}
  for(let k=0;k<6;k++)spike(k<3?c.pel:c.chest,sp,.02,.06,(k%3)*.12-.1,.1,0,0,.1);
  const eyeRed=c.eyeW.map(e=>{const m=ell(c.head,new T.MeshBasicMaterial({color:'#e02020',transparent:true,opacity:0}),.045,.045,.04);m.position.copy(e.position);return m;});
  const eW0=c.eyeW.map(e=>e.scale.clone()),eP0=c.eyeP.map(e=>e.scale.clone());
  return {pose(s,fx){
    bm.begin();const sw=kf(s,[[.3,0],[.85,1],[1.1,1.1],[1.12,0],[2.2,0]]),sq=win(s,1.08,1.5,.05),bu=s2(s,.3,1.1)*(1-s2(s,1.15,1.3)),shk=win(s,.7,1.1,.1)*Math.sin(s*46);
    const P=S.idleP(s);P.br=.3*bu+.015*Math.sin(s*2.6);P.y=c.h-.04*bu;P.sq=.06*bu;P.na=.1*bu-.06*sq;P.hp=-.35*bu+.5*sq;P.hy=.18*shk;P.jaw=.1*sq;P.pitch=-.05*bu;
    P.foot=[[.05*bu,0,0],[.05*bu,0,0],[-.03*bu,0,0],[-.03*bu,0,0]];c.pose(P);
    c.eyeW.forEach((e,i)=>{e.scale.copy(eW0[i]).multiplyScalar(1+.6*bu);c.eyeP[i].scale.copy(eP0[i]).multiplyScalar(1+.3*bu);eyeRed[i].material.opacity=.7*bu;eyeRed[i].scale.set(.045,.045,.04).multiplyScalar(.9+.55*bu);});
    const tg=d.head.position.clone().add(V(-.05,.02,0)),tau=.18,g=7;
    for(let i=0;i<2;i++){const o=c.eyeW[i].getWorldPosition(V(0,0,0)),b=d.eyeW[i].getWorldPosition(V(0,0,0)),vel=k=>{const v=b.clone().sub(o).multiplyScalar(1/tau);v.y+=g*tau/2;return v;};
      const pos=u=>{const t=u*tau;return o.clone().addScaledVector(vel(0),t).add(V(0,-.5*g*t*t,0));};
      if(s>1.1&&s<1.6){const front=eo(rp(s,1.1,1.1+tau+.02)),tail=rp(s,1.34,1.5),N=7;if(front>tail+.01)for(let q=0;q<N;q++){const u0=tail+(front-tail)*q/N,u1=tail+(front-tail)*(q+1)/N;bm.seg(pos(u0),pos(u1),.016*(1-.25*q/N),'#e01c1c',.95);}}
      fx.em(s,{t0:1.1,dt:.007,n:22,life:tau+.04,pos:k=>o.clone(),vel:k=>{const v=vel(k);v.z+=(rnd(k+i*9)-.5)*.35;v.y+=(rnd(k+4)-.5)*.35;return v;},g,size:(u,k)=>.04+.025*rnd(k),op:u=>1,c:(u,k)=>k%3?'#9a1414':'#d02828',tx:TX.drop,add:false});
      fx.em(s,{t0:1.12,dt:.016,n:14,life:tau+.02,pos:k=>o.clone(),vel:k=>{const v=vel(k);v.z+=(rnd(k+i*3)-.5)*.2;return v;},g,size:(u,k)=>.05,op:u=>.7,c:()=>'#e03030',tx:TX.soft,add:true});}
    bm.end();
    // splatter on the face, red spots
    const a=s-T0;if(a>0&&a<.7){for(let i=0;i<2;i++){const b=d.eyeW[i].getWorldPosition(V(0,0,0));for(let k=0;k<5;k++){const az=k*1.3+i*2,u=eo(a/.4>1?1:a/.4);fx.p(b.clone().add(V(-.07*Math.cos(az)*u,.06*Math.sin(az)*u,.08*Math.sin(az+1)*u)),.04,.95*(1-a/.7),'#b01818',TX.drop,false);}}}
    if(a>0)fx.hit(d.head.position.clone().add(V(-.02,0,0)),a,{n:4,r:.3,c:'#ff8080',c2:'#d02020'});
    const run1=win(s,1.75,2.35,.1),run2=win(s,2.6,3.3,.15),jump=a>0?Math.exp(-a*3)*Math.sin(Math.min(a,.5)*PI/.5):0,sc2=s2(s,T0,T0+.15);
    d.set(s,{dx:kf(s,[[T0,0],[T0+.2,.35],[T0+.5,.38],[1.7,.4],[2.3,1.4],[2.6,1.4],[3.3,0]]),yaw:kf(s,[[1.7,0],[1.85,-PI],[2.55,-PI],[2.7,0]]),dy:.28*Math.max(0,Math.sin(Math.min(a*5.5,PI)))*(a>0&&a<.6?1:0)+.04*Math.abs(Math.sin(s*20))*run1,pitch:.4*Math.exp(-Math.max(0,a)*3)*(a>0?1:0),na:a>0?-.5*Math.exp(-a*5):0,jaw:.5*(a>0&&a<1.2?1:0),ear:1.2*sc2*(1-s2(s,2.8,3.2)),ta:1.2*sc2*(1-s2(s,2.7,3.1)),sq:.15*Math.exp(-Math.max(0,a)*8)*(a>0?1:0),hy:.4*Math.sin(a*30)*Math.exp(-a*3)*(a>0?1:0),
      follow:1,gait:{ph:s*24,amp:.15*Math.max(run1,run2*.7),lift:.08*Math.max(run1,run2*.7)},foot:[[0,.0,0],[0,0,0],[0,0,0],[0,0,0]],flash:.3*Math.exp(-Math.max(0,a)*8)*(a>0?1:0),fr:.9,fg:.2,fb:.1});
    d.tint('#c8402a',.4*s2(s,T0,T0+.2)*(1-s2(s,2.6,3.2)));
    return 0;}};
};
// 11 ------------------------------------------------------------------------------------------ quill storm
SIGB.quill_storm=function(sc,def){
  const c=Quad(sc,{col:'#5a4330',belly:'#b38e62',dark:'#2c2018',x0:1.05,sl:.36,pr:[.25,.21,.18],cr:[.21,.2,.17],legU:.12,legL:.15,lr:.045,nl:.1,ns:4,nr0:.14,nr1:.1,na0:.4,nc0:-.2,hl:.12,hh:.09,hw:.09,sn:.09,snh:.05,snw:.05,tl:.2,ts:5,tr0:.08,tr1:.03,ta0:.1,yaw0:PI,eye:.025}),d=Pip(sc,2.3),T0=def.ti;
  const qm=lam('#efe6cc'),tipm=lam('#3a2c20'),qs=[];
  const qgeo=new T.ConeGeometry(.012,.34,5);qgeo.translate(0,.17,0);
  for(let i=0;i<64;i++){const grp=i<36?c.pel:c.chest,j=i<36?i:i-36,nx=i<36?36:28,x=i<36?-.25+.5*((j*7)%12)/11:-.12+.24*((j*5)%12)/11,z=(((j*5)%7)-3)*.04,y=(i<36?.21:.19)*Math.sqrt(Math.max(.2,1-(x*x)/(i<36?.07:.05))-z*z*10);
    const q=new T.Mesh(qgeo,qm);q.position.set(x,y*.95,z);grp.add(q);qs.push({q,fan:-.55+1.1*((j*3)%9)/8,side:z/.14,ph:rnd(i)*6,len:.8+.4*rnd(i+3)});}
  const fly=[0,1,2,3,4,5,6,7].map(k=>{const m=new T.Mesh(qgeo,qm);m.visible=false;sc.add(m);return m;});
  return {pose(s,fx){
    const up=s2(s,.3,.8)*(1-s2(s,2.2,2.8)),rat=win(s,.8,1.6,.1)*.1+(s>T0?.25*Math.exp(-(s-T0)*4):0),a=s-T0;
    qs.forEach(k=>{const w=up*rat*Math.sin(s*44+k.ph);k.q.rotation.z=1.4*(1-up)+(k.fan*(1-.2*Math.abs(k.side)))*up+w;k.q.rotation.x=k.side*.7*up+w*.5;k.q.scale.y=k.len*(.6+.4*up);});
    const P=S.idleP(s);P.br=.12*up;P.y=c.h-.03*up+.01*Math.sin(s*50)*win(s,.8,1.6,.1);P.na=-.2*up;P.hp=-.2*up;P.pitch=.06*up;P.x=1.05+.05*Math.exp(-Math.max(0,a)*5)*(a>0?1:0)*1;c.pose(P);
    // the dummy charges in (gallop, crouch first), hits the quills, rebounds
    const crouch=kf(s,[[.45,0],[.8,1],[.92,0]]),charge=s2(s,.88,T0),run=win(s,.88,T0+.02,.05);
    const dxc=-.42*eo(charge),rebound=a>0?eo(rp(a,0,.45))*.95:0,ret=s2(s,2.5,3.2);
    d.set(s,{dx:(dxc+rebound)*(1-ret)+(a>0?0:0),dy:.04*Math.abs(Math.sin(s*20))*run*0+(a>0?.22*Math.sin(PI*rp(a,0,.5)):0),pitch:-.35*crouch*0+.2*crouch-.15*run+(a>0?.5*Math.exp(-a*4):0),bend:-.3*crouch,na:.3*crouch+(a>0?.6*Math.exp(-a*5):0)-.35*run,hp:(a>0?.5*Math.exp(-a*4):0),jaw:.6*run+(a>0?.7*Math.exp(-a*1.5):0),ear:1.1*s2(s,T0,T0+.05)*(1-s2(s,2.6,3.1)),ta:.9*s2(s,T0,T0+.05)*(1-s2(s,2.6,3.1)),sq:.2*Math.exp(-Math.max(0,a)*12)*(a>0?1:0),hy:.4*Math.sin(a*26)*Math.exp(-a*2.5)*(a>0?1:0),
      quills:a>0?5:0,follow:1,gait:{ph:s*26,amp:.16*run,lift:.09*run},foot:[[0,0,0],[0,0,0],[0,0,0],[0,0,0]],flash:.6*Math.exp(-Math.max(0,a)*9)*(a>0?1:0),fr:.9,fg:.4,fb:.3});
    // a handful of quills fly back into the face and chest
    fly.forEach((m,k)=>{const t=a-k*.012,live=t>0&&t<.14;m.visible=live&&a<.2;if(!m.visible)return;const o=c.pel.localToWorld(V(.1-.1*k*.4,.18,(k-3.5)*.03)),b=d.head.position.clone().add(V(0,(k%3-1)*.05,(k-3.5)*.02)),u=t/.1;m.position.lerpVectors(o,b,clamp(u,0,1));const dd=b.clone().sub(o);m.quaternion.setFromUnitVectors(Y,dd.normalize());m.scale.setScalar(.55);});
    if(a>-.02&&a<.5)fx.hit(d.head.position.clone().add(V(.08,-.0,0)),a,{n:8,r:.45,sz:.08,c:'#fff0c0',c2:'#ffd070',dust:'#c9b48a'});
    if(s>T0&&s<T0+.4)for(let k=0;k<4;k++)fx.p(c.pel.localToWorld(V(-.1+.08*k,.2,0)),.1,.4*(1-(s-T0)/.4),'#fff4d8',TX.star,true,k);
    return a>0?.4*Math.exp(-a*8):0;}};
};
// 12 ------------------------------------------------------------------------------------------ ground-pound shockwave
SIGB.ground_pound=function(sc,def){
  const c=Quad(sc,{col:'#8c929a',belly:'#a9aeb6',dark:'#5c6068',x0:.4,sl:.78,pr:[.37,.32,.27],cr:[.38,.35,.28],legU:.4,legL:.42,lr:.1,hip:.5,nl:.26,ns:4,nr0:.24,nr1:.19,na0:.35,nc0:-.15,hlev:-.1,hfol:.2,hl:.23,hh:.19,hw:.16,sn:.02,snh:.08,snw:.09,tl:.55,ts:8,tr0:.07,tr1:.015,ta0:-.1,ears:1,earL:.33,earW:.2,toeL:.1,eye:.03,eyeY:.55}),d=Pip(sc,2.7),T0=def.ti,TC=1.2;
  c.ears.forEach(pv=>{pv.children.forEach(m=>{m.scale.z*=1.4;});});
  const iv=lam('#f0ead6');for(const z of [-1,1])spike(c.head,iv,.04,.4,c.o.hl*1.0,-.1,z*.12,z*.25,-1.25);
  const trunk=new BB.Tube(14,8);trunk.mesh.material=new T.MeshLambertMaterial({color:'#8c929a',vertexColors:true,side:T.DoubleSide});sc.add(trunk.mesh);
  const peb=[0,1,2,3,4,5,6,7].map(()=>{const m=new T.Mesh(new T.DodecahedronGeometry(.04,0),lam('#7a7468'));m.visible=false;sc.add(m);return m;});
  return {pose(s,fx){
    const rear=kf(s,[[.25,0],[.55,.5],[.95,1],[1.05,1],[1.12,.05],[1.18,-.05],[1.3,0],[2.2,0]]),slam=s2(s,TC-.02,TC+.02),hold=Math.exp(-Math.pow((s-TC-.03)/.1,2)),trump=kf(s,[[.5,0],[.95,1],[1.08,1],[1.15,0],[2.2,0]]);
    const P=S.idleP(s);P.pitch=.62*rear;P.y=c.h+.0*rear-.08*hold+.02*Math.sin(s*2)*0;P.x=.4-.12*rear;P.na=.1*rear;P.hp=.2*rear-.15*hold;P.jaw=.4*trump;P.br=.04*rear+.06*hold;P.sq=.1*hold;P.earOut=1.8*trump+.3;P.ear=-.1*trump;P.tx=u=>[.2*Math.sin(s*2-u*3)*u*(1-rear),0];
    const lifted=kf(s,[[.3,0],[.8,1],[1.1,1],[1.17,0],[1.5,0]]);P.foot=[[.2*lifted,.62*lifted,0],[.2*lifted,.62*lifted,0],[0,0,0],[0,0,0]];P.sq=P.sq;c.pose(P);
    // trunk raises to trumpet, then slams down with the body
    const tb=c.head.localToWorld(V(c.tipX,-.06,0)),tp=[];const k1=1.9*trump-.3*(1-trump);for(let i=0;i<14;i++){const u=i/13,th=-1.2+k1*Math.sin(u*1.6)+.6*trump*u*u,p=i?tp[i-1].clone():tb.clone();if(i)p.add(V(Math.cos(th)*.04+.015*trump,Math.sin(th)*.045*(1)+.02*trump*u,0));tp.push(p);}
    trunk.update(tp,tp.map((p,i)=>.13*(1-i/13)+.035),(i,a,out)=>{out[0]=.7;out[1]=.72;out[2]=.76;},Y);
    // the stomp: ring of dust and a pressure ring
    const a=s-TC,fp=V(1.15,.0,0);
    if(a>-.02&&a<1.3){const u=clamp(a/1.2,0,1),r=.4+3.1*eo(u);fx.ring(fp.x,.014,0,r,.9*(1-u),'#f5e6bc');fx.ring(fp.x,.015,0,r*.72,.55*(1-u),'#d8c490');
      for(let k=0;k<12;k++){const az=k*PI*2/12+.2,e=eo(u);fx.p(V(fp.x+Math.cos(az)*(.2+3.0*e)*(k%2?.95:1),.08+.2*Math.sin(PI*Math.min(1,u*1.2))*(1+(k%3)*.4),Math.sin(az)*(.2+3.0*e)*.55),.2+.25*e,.5*(1-u),'#c9b48a',TX.puff,false,k);}
      if(a<.12)fx.p(V(fp.x,.1,0),1.2*(1-a/.12)+.2,.9*(1-a/.12),'#fff2c8',TX.soft,true);
      for(let k=0;k<2;k++)fx.p(V(fp.x+.2*k-.1,.05,.15*(k?1:-1)),.5*eo(Math.min(1,a/.3)),.6*(1-u),'#fff6d8',TX.star,true,k);}
    peb.forEach((m,k)=>{const t=a-.02;m.visible=t>0&&t<.9;if(!m.visible)return;const az=k*.78,v=V(Math.cos(az)*(.8+rnd(k)*1.2),2.2+rnd(k+3)*1.8,Math.sin(az)*.9);m.position.set(fp.x+v.x*t,Math.max(.04,.05+v.y*t-4.9*t*t),v.z*t);m.rotation.set(t*8+k,t*6,0);});
    // the target: floor jumps under it, is flung up and back, lands flat, dazed, gets up, ambles back
    const b=s-T0,fly=b>0?eo(rp(b,0,.9)):0;
    const air=b>0&&b<.8?Math.sin(PI*b/.8):0;
    d.set(s,{dx:.55*fly*(1-s2(s,2.7,3.4)),dy:.6*air,roll:b>0?-1.55*s2(b,.0,.8)*(1-s2(s,2.4,2.9)):0,pitch:.5*Math.exp(-Math.max(0,b)*3)*(b>0?1:0),na:b>0?-.4:0,jaw:.4*(b>0&&b<.9?1:0),ear:1.1*s2(s,T0,T0+.05)*(1-s2(s,2.8,3.2)),stars:s2(s,T0+.7,T0+.9)*(1-s2(s,2.4,2.8)),flash:.6*Math.exp(-Math.max(0,b)*8)*(b>0?1:0),sq:.12*Math.exp(-Math.max(0,b)*10)*(b>0?1:0),limp:b>0?s2(b,0,.2)*(1-s2(s,2.4,2.9)):0,lt:s,follow:1,gait:{ph:s*14,amp:.1*win(s,2.8,3.35,.1),lift:.05*win(s,2.8,3.35,.1)}});
    const lie=s2(s,T0+.6,T0+.85)*(1-s2(s,2.4,2.9));if(lie>0)d.root.position.y=Math.max(.15,d.root.position.y);
    if(b>.78&&b<1.2){const u=(b-.78)/.42;for(let k=0;k<5;k++)fx.p(V(2.7+.55+Math.cos(k*1.3)*.4*eo(u),.08+.1*u,Math.sin(k*1.3)*.3*eo(u)),.2+.2*u,.4*(1-u),'#c9b48a',TX.puff,false,k);}
    return Math.exp(-Math.pow((s-TC-.05)/.12,2))*1.0+(s>TC&&s<TC+.6?.2*Math.sin(s*50)*Math.exp(-(s-TC)*5):0);}};
};
// 13 ------------------------------------------------------------------------------------------ death roll
SIGB.death_roll=function(sc,def){
  const wh=lam('#f4f1e2'),c=Quad(sc,{col:'#4c6b3a',belly:'#cfc88a',dark:'#2c4026',x0:-.2,sl:.95,pr:[.42,.12,.17],cr:[.36,.12,.16],legU:.13,legL:.15,lr:.055,sprawl:1.0,hip:.7,nl:.08,ns:3,nr0:.12,nr1:.1,na0:.0,nc0:0,hlev:0,hfol:0,hl:.19,hh:.08,hw:.11,sn:.5,snh:.05,snw:.075,tl:1.35,ts:14,tr0:.11,tr1:.012,ta0:.02,eye:.03,eyeY:1.0,toeL:.07,
    skin:(i,a,out,part,top,bot)=>{const m=Math.sin(i*2.6)*.5+.5;out[0]*=.85+.2*m;out[1]*=.85+.2*m;}}),d=Pip(sc,2.45),T0=def.ti,dm=lam('#2f4228');
  for(let k=0;k<7;k++){spike(c.pel,dm,.03,.07,-.28+k*.1,.1,.0,0,.15);if(k<5)spike(c.chest,dm,.03,.07,-.15+k*.1,.095,0,0,.1);for(const z of [-1,1])if(k<5)spike(c.pel,dm,.022,.05,-.2+k*.1,.1,z*.08,z*.4,.1);}
  const sx=c.head;for(let k=0;k<7;k++)for(const z of [-1,1]){spike(sx,wh,.009,.04,c.o.hl*.9+k*.07,-.02,z*(.05),0,PI).scale.set(1,1,1);}
  for(const z of [-1,1])for(let k=0;k<6;k++)spike(c.jaw,wh,.008,.035,.1+k*.07,.01,z*.05,0,0);
  return {pose(s,fx){
    const creep=kf(s,[[0,-.15],[.5,-.05],[1.0,.35],[1.1,.78],[1.14,.8],[2.45,.8],[3.3,-.15]]),roll=kf(s,[[1.24,0],[1.4,.5],[2.4,PI*2*3.2],[2.5,PI*2*3.35]]),rollAmt=s2(s,1.2,1.3)*(1-s2(s,2.47,2.52)),hold=s2(s,1.12,1.16)*(1-s2(s,2.46,2.5));
    const lunge=s2(s,.95,1.1),P=S.idleP(s);P.x=-.2+creep*1.25*(s<2.46?1:1)*0+(-.2+ (creep+.15)*1.0);P.x=-.2+(creep+.15);
    const jaw=kf(s,[[.5,0],[.9,.15],[1.05,.95],[1.1,.95],[1.145,0],[1.3,.0],[2.46,.0],[2.52,.7],[2.9,.1],[3.2,0]]);
    P.y=c.h+.06*lunge*(1-s2(s,1.15,1.3))+.01*Math.sin(s*3);P.pitch=.12*lunge*(1-s2(s,1.15,1.3))-.04*s2(s,.6,.95)*(1-lunge);P.na=.1*lunge;P.hp=.45*lunge*(1-s2(s,1.15,1.3));P.jaw=jaw;P.roll=roll*rollAmt;P.limp=.85*rollAmt;P.lt=s;P.follow=1;
    P.gait={ph:s*9,amp:.09*win(s,.3,1.1,.2),lift:.04*win(s,.3,1.1,.2)};P.ta=0;P.tx=u=>[.0,(.35*Math.sin(s*3.2-u*5)+.35*s2(s,1.2,1.6)*(1-s2(s,2.5,3.0))*Math.sin(s*9-u*4))*Math.min(1,u*2)*(1-.5*rollAmt)];
    c.pose(P);
    const m=c.mouth(.82),spin=roll*rollAmt;
    // the target: watches, is seized in the jaws, spun with the croc, released and flung, dazed, gets up
    const b=s-T0,rel=s-2.5;let A={};
    if(s<1.14){const bk=kf(s,[[1.0,0],[1.12,.12],[1.14,.2]]);A={dx:-bk*.5*0,pitch:0,na:.3*s2(s,.8,1.0),ear:.5*s2(s,.8,1.0),jaw:.2*s2(s,.8,1.0)};}
    else if(s<2.5){const grab=s2(s,1.14,1.24);A={dx:m.x-2.45,dy:m.y-d.h,dz:m.z,yaw:-PI,roll:spin+.05*Math.sin(s*30),pitch:0,limp:.85,lt:s,jaw:.5,stars:0};}
    else{const u=rp(rel,0,.6),R0=(PI*2*3.35)%(PI*2),lyi=1-s2(s,2.85,3.25),land=s2(rel,.35,.55);
      A={dx:(.15+.7*eo(u))*(1-s2(s,2.9,3.35)),dy:(.3-d.h)*(1-eo(u))+(.3*Math.sin(PI*u))-(d.h-.14)*land*lyi*0+(-(d.h-.14))*land*lyi,dz:0,yaw:-PI,roll:(R0*(1-s2(rel,0,.45))+(-PI*.5)*s2(rel,0,.45))*lyi,limp:.9*lyi,lt:s,stars:s2(s,2.75,2.9)*(1-s2(s,3.1,3.3)),sq:.15*Math.exp(-Math.max(0,rel-.45)*12)*(rel>.45?1:0),pitch:0};}
    d.set(s,A);
    if(s>=1.14&&s<2.5){d.root.position.copy(m);d.root.position.y=m.y;}
    // water: splash on the bite, foam spiral while spinning, droplets flung off tangentially
    const a=s-1.15;if(a>0&&a<.5)fx.hit(m.clone().add(V(0,.05,0)),a,{n:8,r:.6,c:'#dff4ff',c2:'#9fd8ff'});
    if(rollAmt>.3)for(let k=0;k<12;k++){const ang=spin+k*.52+s*8,u=fr(s*1.8+k*.19),r=.22+.45*u;fx.p(V(m.x-.2*u+.2*Math.cos(k),.14+r*Math.cos(ang)*.9,r*Math.sin(ang)),.05+.03*(1-u),.8*(1-u)*rollAmt,k%3?'#dff4ff':'#ffffff',TX.drop,false);}
    if(rollAmt>.3)for(let k=0;k<4;k++){const u=fr(s*1.1+k/4);fx.ring(m.x-.3,.012,0,.3+1.2*u,.5*(1-u)*rollAmt,'#dff4ff');}
    if(rollAmt>.3)for(let k=0;k<5;k++){const u=fr(s*.9+k*.21);fx.p(V(m.x-.4+.1*k,.1+.3*u,(k-2)*.15),.18+.2*u,.35*(1-u)*rollAmt,'#e8f6ff',TX.puff,false,k);}
    if(rel>0&&rel<.5)fx.hit(m.clone().add(V(.6*eo(rel/.5),.05,0)),rel,{n:5,r:.5,c:'#dff4ff',c2:'#9fd8ff'});
    return win(s,1.25,2.5,.1)*.16*(.5+.5*Math.sin(s*30))+(a>0&&a<.3?.5*Math.exp(-a*9):0);}};
};
// 14 ------------------------------------------------------------------------------------------ ink cloud
SIGB.ink_cloud=function(sc,def){
  const om=lam('#b0466f'),O=new T.Group();sc.add(O);const man=ell(O,om,.24,.34,.22);man.position.set(-.12,.1,0);const hm=ell(O,om,.2,.19,.2);hm.position.set(.1,-.04,0);const brow=ell(O,lam('#8a3358'),.12,.03,.1);brow.position.set(.16,.1,0);
  const eyes=[-1,1].map(z=>{const w=ell(O,lam('#f0e2a0'),.06,.06,.045);w.position.set(.2,.02,z*.14);const p=ell(O,lam('#0a0a0a'),.032,.045,.015);p.position.set(.235,.02,z*.14);return {w,p};});
  const sip=new T.Mesh(new T.CylinderGeometry(.025,.04,.14,8),lam('#8a3a58'));sip.rotation.z=-1.3;sip.position.set(.0,-.1,.0);O.add(sip);
  const arms=[];for(let k=0;k<8;k++){const t=new BB.Tube(12,7);t.mesh.material=new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide});sc.add(t.mesh);arms.push(t);}
  const d=Pip(sc,2.6),T0=def.ti,col1=S.rgb('#b0466f'),col2=S.rgb('#e8b0b8');
  return {pose(s,fx){
    const jet=s2(s,1.2,1.3)*(1-s2(s,1.8,2.5)),swell=kf(s,[[.7,0],[1.15,1],[1.2,-.3],[1.35,0],[2,0]]),flush=win(s,1.05,1.9,.15);
    const x=.9-1.35*eo(rp(s,1.2,1.85))+1.15*s2(s,2.5,3.3)*0+1.35*s2(s,2.5,3.3)*0;let xx=kf(s,[[0,.9],[1.2,.9],[1.4,.4],[1.85,-.45],[2.5,-.45],[3.3,.9]]);const y=.52+.04*Math.sin(s*2)+.12*jet*(1-s2(s,1.9,2.4))+.05*swell;
    O.position.set(xx,y,0);O.rotation.z=.5*jet*(1-s2(s,2.4,3.0))+.06*Math.sin(s*2.2);O.scale.set(1+.22*swell*0,1+.0,1);man.scale.set(.24*(1+.12*swell),.34*(1+.2*swell+.0),.22*(1+.12*swell));man.scale.y*=1-.25*Math.exp(-Math.pow((s-1.25)/.08,2));
    om.color.copy(S.col('#b0466f')).lerp(S.col('#f0c0b8'),.55*flush);eyes.forEach(e=>{e.w.scale.set(.06,.06,.045).multiplyScalar(1+.3*swell+.2*flush);});
    O.updateMatrixWorld(true);
    const base=O.localToWorld(V(.0,-.2,0)),rest=jet;
    arms.forEach((t,k)=>{const a=(k+.5)/8*PI*2,sa=Math.sin(a),ca=Math.cos(a),pts=[],rad=[];const b=V(base.x+.08*ca,base.y-.04,.12*sa);
      for(let j=0;j<12;j++){const u=j/11,w=Math.sin(s*3+k*.9-u*3)*.08*(1-jet)+.03*Math.sin(s*5+k);
        const out=V(.34*ca-.07,0,.36*sa),pr=b.clone().add(V(.0,-.05,0)).addScaledVector(out,u*1.0).add(V(0,0,0));pr.y=Math.max(.03,base.y-.04-.5*Math.sin(u*1.0)*(.9+.3*Math.sin(k))*(1-u*.2)*1.0+u*u*.06);pr.z+=w*u;pr.x+=.12*Math.sin(s*2+k)*u*(1-jet);pr.y=Math.max(.025,pr.y-.25*(u<.4?0:(u-.4)*.2)*0);
        const st=b.clone().add(V(-.9*u,-.05*u+.07*Math.sin(u*5-s*14+k),.06*sa*u*.6+.04*Math.sin(u*6-s*10+k*2)*u));
        const p=pr.clone().lerp(st,jet);pts.push(p);rad.push(.045*Math.pow(1-u,.75)+.006);}
      t.update(pts,rad,(i,an,o)=>{const bb=sm((-Math.cos(an)-.1)/.7);o[0]=col1[0]+(col2[0]-col1[0])*bb;o[1]=col1[1]+(col2[1]-col1[1])*bb;o[2]=col1[2]+(col2[2]-col1[2])*bb;},Y);});
    // bubbles + jet wake
    S.bubbles(fx,s,-1,2.5,0,5);if(jet>.1)for(let k=0;k<5;k++){const u=fr(s*3+k*.2);fx.p(O.localToWorld(V(.1,-.12,0)).add(V(.3*u,.0,0)),.1+.15*u,.45*(1-u)*jet,'#dbeaff',TX.bubble,false);}
    // the ink: a dark blob first, then a spreading cloud with tendrils
    const a=s-1.28;if(a>0){const u=rp(a,0,1.6),e=eo(u),fade=1-s2(s,2.5,3.2),C=V(1.15,.55,0);
      for(let k=0;k<18;k++){const rr=rnd(k),ph=rnd(k+4)*6.28,dist=(.1+.85*rr)*e,p=C.clone().add(V(dist*1.15*Math.cos(ph)*.8+.35*e,(rnd(k+8)-.45)*.75*e+.05*Math.sin(s*1.5+k),dist*.85*Math.sin(ph)));
        fx.p(p,.18+.55*e*(.7+.5*rnd(k+2)),.7*fade*(a<.1?a/.1:1),k%4?'#161230':'#0c0a1c',TX.puff,false,k);}
      for(let k=0;k<6;k++)fx.p(C.clone().add(V(.5*e*(k-2.5)*.4+.2*e,.2*Math.sin(k*2+s)*e,(rnd(k)-.5)*.5*e)),.5+.5*e,.18*fade,'#3a2e68',TX.puff,false,k);}
    // pursuer: charges in, enters the ink, is blinded, flounders, gives up
    const b=s-T0,charge=kf(s,[[.5,0],[1.35,-1.05]]),skid=b>0?1:0,run=win(s,.55,T0+.12,.06);
    const wander=s2(s,T0+.3,T0+.6)*(1-s2(s,2.6,3.0));
    d.set(s,{dx:(s<T0?charge:-1.05-.12*eo(rp(b,0,.3)))*(1-s2(s,2.5,3.3))+(.08*Math.sin(s*3)*wander),yaw:.7*Math.sin(s*3.2)*wander+.25*Math.sin(s*20)*Math.exp(-Math.max(0,b)*3)*(b>0?1:0),pitch:-.08*run+(b>0?.3*Math.exp(-b*4):0),na:-.25*run+(b>0?-.5*Math.exp(-b*4):0),jaw:.5*run*(s<T0?1:0)+(b>0?.4*Math.max(0,Math.sin(b*16))*(b<1.4?1:0):0),hy:.8*Math.sin(b*22)*Math.exp(-Math.max(0,b)*1.6)*(b>0?1:0),ear:.5*run+.8*s2(s,T0,T0+.1)*(1-s2(s,2.8,3.2)),blind:s>T0&&s<2.95,sq:.1*Math.exp(-Math.max(0,b)*9)*(b>0?1:0),ta:.4*run,follow:1,
      gait:{ph:s*(s<T0?27:8),amp:s<T0?.17*run:.06*wander,lift:s<T0?.09*run:.03*wander},dy:0});
    d.tint('#2a2448',.5*s2(s,T0,T0+.2)*(1-s2(s,2.8,3.3)));
    return 0;}};
};
// 15 ------------------------------------------------------------------------------------------ hind kick
SIGB.hind_kick=function(sc,def){
  const c=Quad(sc,{col:'#8a8378',belly:'#d0c9b8',dark:'#3f3a33',x0:1.3,sl:.58,pr:[.27,.24,.18],cr:[.28,.25,.18],legU:.3,legL:.32,lr:.05,nl:.46,ns:8,nr0:.12,nr1:.08,na0:.7,nc0:-.4,hlev:-.15,hl:.17,hh:.11,hw:.085,sn:.2,snh:.065,snw:.058,ears:1,earL:.26,earW:.05,tl:.6,ts:8,tr0:.04,tr1:.02,ta0:-.1,yaw0:PI,eye:.028,tprof:u=>u>.8?2.2:1,
    skin:(i,a,out,part)=>{if(part==='neck'&&Math.cos(a)>.5){out[0]*=.6;out[1]*=.6;out[2]*=.6;}}}),d=Pip(sc,2.25),T0=def.ti,TK=1.04;
  const cross=lam('#3f3a33');ell(c.pel,cross,.03,.2,.18).position.set(.35,.05,0);ell(c.head,lam('#d8d2c2'),.06,.04,.05).position.set(c.tipX*.9,-.03,0);
  return {pose(s,fx){
    const turn=s2(s,.25,.65)*(1-s2(s,2.6,3.2)),dn=kf(s,[[.55,0],[.9,1],[1.02,1],[1.12,.2],[1.45,.3],[2.2,0]]),k=kf(s,[[.7,0],[.95,-.5],[1.0,-.2],[TK,1],[1.2,1],[1.5,.4],[1.9,0]]),buck=kf(s,[[.7,0],[.98,.0],[TK,1],[1.14,1],[1.5,.2],[2.0,0]]);
    const P=S.idleP(s);P.yaw=PI*(1-0)+kf(s,[[.2,-PI],[.65,0],[2.6,0],[3.2,-PI]])*1*(1)+0;P.yaw=PI+kf(s,[[.2,-PI],[.65,0],[2.6,0],[3.2,-PI]]);
    P.pitch=-.2*dn*.5-.3*buck;P.y=c.h+.07*buck-.03*dn;P.na=-.3*dn;P.hp=-.35*dn;P.ny=2.5*turn*(1-.4*buck);P.ear=1.1*dn;P.ta=.9*buck+.1*dn;P.tx=u=>[.0,.3*Math.sin(s*9)*u*buck];P.jaw=.12*buck;P.br=.03*dn;
    // hind feet: gather under the belly, then both fire backwards (world +x, because the donkey faces away from the target)
    const hf=(sgn)=>{const gather=kf(s,[[.7,0],[.95,1],[1.0,.9],[TK,0],[2.0,0]]),ext=kf(s,[[.95,0],[1.0,0],[TK,1],[1.16,1],[1.45,.1],[1.7,0]]);return [.5*ext-.28*gather+0,.16*gather+.34*ext+.0,.0];};
    P.foot=[[0,0,0],[0,0,0],hf(0),hf(1)];P.foot[3][1]+=.01;c.pose(P);
    const hoof=c.ft[3].position.clone(),a=s-TK;
    if(a>-.02&&a<.5)fx.hit(hoof.clone().add(V(.18,.05,.0)),a,{n:8,r:.6,sz:.1,c:'#fff0c0',c2:'#ffd070',dust:'#c9b48a'});
    if(a>0&&a<.9){const u=a/.9;for(let n=0;n<5;n++)fx.p(V(1.75+.45*n*u*.6,.06+.1*u,(n-2)*.12),.16+.18*u,.45*(1-u),'#c9b48a',TX.puff,false,n);}
    if(s>1.2&&s<1.7){const u=(s-1.2)/.5;fx.p(c.mouth(1.0).add(V(0,0,0)),.1+.15*u,.35*(1-u),'#e8e8e8',TX.puff,false,0);}
    // the target: caught in the chest, thrown back with a flip, lands, rolls, wobbles up
    const b=s-T0,fly=b>0?eo(rp(b,0,.9)):0,air=b>0&&b<.75?Math.sin(PI*b/.75):0,ret=s2(s,2.7,3.35);
    d.set(s,{dx:.95*fly*(1-ret),dy:.5*air,pitch:b>0?2.2*s2(b,0,.7)*(1-s2(s,.0+T0+.9,T0+1.2))+(-0)*0:0,roll:b>0?-1.5*s2(b,.6,.95)*(1-s2(s,2.5,2.95)):0,na:b>0?-.6*Math.exp(-b*4):0,jaw:.4*(b>0&&b<1?1:0),ear:1.0*s2(s,T0,T0+.05)*(1-s2(s,2.8,3.2)),stars:s2(s,T0+.9,T0+1.1)*(1-s2(s,2.3,2.7)),flash:.7*Math.exp(-Math.max(0,b)*9)*(b>0?1:0),sq:.2*Math.exp(-Math.max(0,b)*10)*(b>0?1:0),limp:b>0?s2(b,0,.2)*(1-s2(s,2.5,3.0)):0,lt:s,follow:1,gait:{ph:s*12,amp:.09*win(s,2.8,3.35,.1),lift:.05*win(s,2.8,3.35,.1)}});
    if(b>.9&&s<2.9){const lyi=1-s2(s,2.5,2.9);d.root.position.y=Math.max(.15,d.root.position.y*(1-0)+0);}
    if(b>.72&&b<1.1){const u=(b-.72)/.4;for(let n=0;n<6;n++)fx.p(V(2.25+.95+Math.cos(n*1.1)*.5*eo(u),.08+.1*u,Math.sin(n*1.1)*.35*eo(u)),.2+.2*u,.45*(1-u),'#c9b48a',TX.puff,false,n);}
    return a>0?.55*Math.exp(-a*8):0;}};
};
// 16 ------------------------------------------------------------------------------------------ tail club
SIGB.tail_club=function(sc,def){
  const c=Quad(sc,{col:'#6b7a5a',belly:'#a9b48c',dark:'#3a4530',x0:.85,sl:.6,pr:[.3,.2,.27],cr:[.3,.2,.28],legU:.12,legL:.15,lr:.065,sprawl:.5,hip:.4,nl:.12,ns:3,nr0:.16,nr1:.13,na0:.2,nc0:-.1,hlev:0,hfol:0,hl:.2,hh:.1,hw:.15,sn:.05,snh:.06,snw:.08,tl:1.15,ts:14,tr0:.14,tr1:.07,ta0:.05,yaw0:PI,eye:.03,toeL:.08,
    skin:(i,a,out,part)=>{if(part==='tail'){const m=(i%2)*.1;out[0]*=1-m;out[1]*=1-m;}}}),d=Pip(sc,2.4),T0=def.ti,dm=lam('#3f4a35'),bone=lam('#bfb896');
  for(let k=0;k<6;k++)for(const z of [-.09,.09]){const p=ell(k<3?c.pel:c.chest,dm,.075,.03,.08);p.position.set(k<3?-.2+k*.17:-.1+(k-3)*.16,.2,z*1.0);spike(k<3?c.pel:c.chest,bone,.02,.07,k<3?-.2+k*.17:-.1+(k-3)*.16,.22,z*1.0,0,0);}
  for(const z of [-1,1]){for(let k=0;k<5;k++)spike(k<3?c.pel:c.chest,bone,.025,.09,(k<3?-.22+k*.17:-.1+(k-3)*.17),.12,z*.27,z*1.2,0);spike(c.head,bone,.025,.15,-.12,.05,z*.1,z*.9,.7);}
  const cl=ell(c.tailEnd,bone,.2,.15,.18);cl.position.x=.14;for(const z of [-1,1]){spike(c.tailEnd,bone,.04,.15,.1,z*.12,0,z*1.2,0);spike(c.tailEnd,bone,.04,.15,.22,z*.1,.05,z*1.2,0);}spike(c.tailEnd,bone,.04,.1,.3,0,0,0,-PI/2);
  const dust=new BB.Tube(2,3);
  return {pose(s,fx){
    const lag=.04,A=t=>kf(t,[[.3,0],[.55,.55],[.95,1.45],[1.0,1.5],[1.1,.2],[1.18,-.75],[1.3,-1.0],[1.8,-.6],[2.5,0],[3.0,0]]),a=s-T0,whip=win(s,1.04,1.22,.03);
    const body=kf(s,[[.3,0],[.95,.28],[1.05,.2],[1.2,-.28],[1.8,-.1],[2.6,0]]);
    const P=S.idleP(s);P.yaw=PI+body;P.y=c.h-.03*s2(s,.5,.95)*(1-s2(s,1.05,1.2));P.pitch=-.03;P.na=.0;P.ta=.0;P.tc=0;P.bend=-.1*body;P.hy=0;P.ny=-.3*body;
    P.tx=u=>[.02*Math.sin(s*3-u*4)*0+.05*Math.sin(s*2-u*4)*u*(1-s2(s,.3,.5)),A(s-lag*u*4)*(.3+.7*u)*.85];
    c.pose(P);
    const club=c.tailEnd.localToWorld(V(.22,0,0)),hit=V(2.3,.4,0);
    // motion arc + club smear during the whip
    if(whip>.02){for(let k=1;k<4;k++){const t=s-.012*k,ph=A(t-lag*4)*.85;}fx.p(club,.35,.35*whip,'#fff0c8',TX.soft,true);}
    if(s>.98&&s<1.25)for(let k=1;k<5;k++){const t=s-.015*k,ph=A(t),p=club.clone().addScaledVector(V(0,0,0),0);fx.p(club.clone().add(V(-.03*k,0,-.12*k*Math.sign(1.2-s+.0)*(-1))),.2*(1-k/5),.35*(1-k/5)*whip,'#ffe8b0',TX.soft,true);}
    if(a>-.02&&a<.6)fx.hit(V(2.2,.5,0),a,{n:9,r:.7,sz:.1,c:'#fff0c0',c2:'#ffd070',dust:'#c9b48a'});
    if(a>0&&a<.8){const u=a/.8;fx.ring(2.2,.012,0,.3+1.0*eo(u),.65*(1-u),'#e6d6ac');}
    // target: struck from the side, spins away, lands flat, stunned, gets up
    const fly=a>0?eo(rp(a,0,.8)):0,air=a>0&&a<.7?Math.sin(PI*a/.7):0,ret=s2(s,2.6,3.3);
    d.set(s,{dx:.55*fly*(1-ret),dz:.4*fly*(1-ret),dy:.3*air,yaw:a>0?1.2*s2(a,0,.7)*(1-ret):0,roll:a>0?-1.55*s2(a,.4,.85)*(1-s2(s,2.4,2.9)):0,pitch:a>0?.5*Math.exp(-a*4):0,na:a>0?-.5*Math.exp(-a*4):0,jaw:.4*(a>0&&a<.9?1:0),ear:1.0*s2(s,T0,T0+.05)*(1-s2(s,2.8,3.2)),stars:s2(s,T0+.7,T0+.9)*(1-s2(s,2.3,2.7)),flash:.7*Math.exp(-Math.max(0,a)*9)*(a>0?1:0),sq:.2*Math.exp(-Math.max(0,a)*10)*(a>0?1:0),limp:a>0?s2(a,0,.2)*(1-s2(s,2.4,2.9)):0,lt:s,follow:1,gait:{ph:s*12,amp:.09*win(s,2.8,3.35,.1),lift:.05*win(s,2.8,3.35,.1)}});
    if(a>.7&&a<1.1){const u=(a-.7)/.4;for(let n=0;n<5;n++)fx.p(V(2.4+.55+Math.cos(n*1.3)*.4*eo(u),.08+.1*u,.4+Math.sin(n*1.3)*.3*eo(u)),.2+.2*u,.4*(1-u),'#c9b48a',TX.puff,false,n);}
    return a>0?.55*Math.exp(-a*8):0;}};
};
})();
