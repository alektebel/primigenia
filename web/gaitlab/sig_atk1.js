'use strict';
// Signature attacks 1-8 (round 2). See sig_rig.js for the rigs and signature_core.js for the picker metadata.
(function(){
const BB=window.BB,T=BB.T,S=BB.sig,{V,clamp,sm,lam,limb,place}=BB,{ell,rp,eo,s2,tri,eb,rnd,lerpV,kf,TX,Beams,Quad,Pip,Serp}=S;
const SIGB=window.SIGB,Y=BB.Y;
const win=(s,a,b,r)=>{r=r||.06;return s2(s,a,a+r)*(1-s2(s,b-r,b));};
const fr=x=>x-Math.floor(x);
function spike(par,mat,r,len,x,y,z,rx,rz){const g=new T.ConeGeometry(r,len,6);g.translate(0,len/2,0);const m=new T.Mesh(g,mat);m.position.set(x,y,z);m.rotation.set(rx||0,0,rz||0);par.add(m);return m;}
function ramp(u,c){return c[Math.min(c.length-1,Math.floor(u*c.length))];}
const FIRE=['#fff0b0','#ffc24a','#ff8a2a','#e0501a','#8a2a12'];
Object.assign(S,{win,fr,spike,ramp,FIRE});
// running gait helper for Pip: amplitude follows how fast it is going
const gait=(s,amp,k)=>({ph:s*(k||22),amp:.13*amp,lift:.07*amp});
SIGB._stub=(sc)=>{const d=Pip(sc,2.2);return {pose(s){d.set(s,{});}};};
S.gait=gait;
// flames licking on a creature part
function lick(fx,s,pos,n,amt,seed){for(let k=0;k<n;k++){const u=fr(s*2.3+k*.37+(seed||0)),p=pos(k);p.y+=.28*u;p.x+=.03*Math.sin(s*20+k*2);const f=1+.25*Math.sin(s*33+k*4);fx.p(p,.2*(1-u*.55)*f*amt,.8*amt*(1-u*.6),ramp(u,FIRE),TX.soft,true);}}
// 1 ------------------------------------------------------------------------------------------- flamethrower
SIGB.flamethrower=function(sc,def){
  const c=Quad(sc,{col:'#a85a3a',belly:'#e8b878',dark:'#3d2418',x0:.05,sl:.6,pr:[.25,.2,.17],cr:[.27,.25,.2],legU:.3,legL:.32,lr:.05,nl:.55,ns:10,nr0:.12,nr1:.075,na0:.5,nc0:-.3,hl:.16,hh:.1,hw:.095,sn:.17,snh:.052,snw:.06,tl:1,ts:12,tr0:.12,tr1:.015,ta0:.12,eye:.03,
    skin:(i,a,out,part,top)=>{if(part==='neck'&&Math.cos(a)<-.1){out[0]=.95;out[1]=.7;out[2]=.45;}}});
  const dm=lam('#4a2a1c');for(let k=0;k<9;k++){const x=-.2+k*.1,y=.17+.07*Math.sin(Math.min(1,k/6)*3);spike(k<5?c.pel:c.chest,dm,.03,.09+.03*(k%2),k<5?x:(k-5)*.08-.08,k<5?.2:.24,0,0,.25);}
  for(const z of [-1,1]){spike(c.head,dm,.022,.13,-.02,.07,z*.05,z*.3,.55);const g=ell(c.chest,new T.MeshBasicMaterial({color:'#ff8a2a'}),.08,.07,.05);g.position.set(.12,-.04,z*.17);c['g'+z]=g;}
  const d=Pip(sc,2.75),T0=def.ti;
  return {pose(s,fx){
    const inh=s2(s,.3,.93),flm=win(s,1.0,1.98,.05),gl=kf(s,[[0,0],[.3,.1],[.95,1],[1.1,1],[2,.5],[2.6,0]]);
    const P=S.idleP(s);P.x=.05+kf(s,[[.88,0],[.96,.05],[1.04,-.1],[1.12,-.06],[2.0,-.06],[2.5,0]]);P.y=c.h+kf(s,[[.3,0],[.9,-.07],[1.04,-.02],[2.0,-.02],[2.5,0]]);
    P.pitch=kf(s,[[.3,0],[.9,.13],[1.03,-.06],[1.95,-.05],[2.5,0]]);P.br=kf(s,[[.3,0],[.93,.3],[1.04,-.12],[1.9,-.08],[2.1,.1],[2.5,0]])+P.br;
    P.na=kf(s,[[.3,0],[.9,.55],[.97,.6],[1.06,-.4],[1.9,-.4],[2.4,.05],[2.9,0]]);P.hp=kf(s,[[.3,0],[.9,.55],[1.06,-.2],[1.95,-.2],[2.4,0]])+.05*Math.sin(s*2.4);
    P.ny=.14*Math.sin((s-1.05)*3.4)*flm;P.jaw=kf(s,[[0,0],[.5,.08],[.92,.22],[1.0,.7],[1.95,.65],[2.1,.1],[2.4,0]]);P.ta=kf(s,[[.3,0],[.9,.4],[1.05,.1],[2.5,0]]);
    P.tx=u=>[.1*Math.sin(s*3.2-u*3.5)*u+.25*Math.sin(Math.max(0,s-1.0)*5)*u*flm,.25*Math.sin(s*2.4-u*4)*u];
    c.pose(P);c['g-1'].material.color.set(ramp(1-gl,['#ffe9a0','#ffb040','#ff8a2a','#b0501c','#6a2a14']));c['g1'].material.color.copy(c['g-1'].material.color);
    const M=c.mouth(.98),Tg=V(2.65,.4,0),D=Tg.clone().sub(M),Ld=D.length();
    // wind-up: glowing mouth, embers drawn in, hot breath
    const hot=win(s,.45,1.02,.3)*(1-flm);fx.p(M,.12+.2*inh,.7*hot,'#ffb040',TX.soft,true);
    for(let k=0;k<5;k++){const u=fr(s*1.8+k/5);if(inh>.1)fx.p(M.clone().add(V(.25*(1-u)*Math.cos(k*2),.2*(1-u)*Math.sin(k*3),.12*Math.sin(k*5))),.04+.03*u,.9*inh*(1-u)*(1-flm),'#ffd27a',TX.star,true,k);}
    // the stream: front runs out in 0.3 s, then a flickering cone
    const front=clamp((s-1.0)/.28,0,1)*flm,fl=1+.22*Math.sin(s*41);
    for(let k=0;k<34;k++){const u=fr(s*2.7+k/34);if(u>front)continue;const r=.03+.3*u*u+.03*u,a=k*2.4+s*17,p=M.clone().addScaledVector(D,u*1.1);p.addScaledVector(V(0,0,1),r*Math.sin(a)*.9);p.y+=r*Math.cos(a*1.3)*.8+.15*u*u;
      const sz=(.17+.5*u)*fl*(k%3?1:1.3);fx.p(p,sz,.42*(1-u*.4)*flm,ramp(Math.min(.99,u*1.15+.12),FIRE),TX.soft,true);}
    for(let k=0;k<8;k++){const u=fr(s*3.3+k/8);if(u>front)continue;fx.p(M.clone().addScaledVector(D,u*.7).add(V(0,.03*Math.sin(k+s*20),.03*Math.cos(k*2+s*22))),.06+.08*u,.5*flm*(1-u),'#fff4c0',TX.soft,true);}
    for(let k=0;k<7;k++){const u=fr(s*1.1+k/7);if(u>front)continue;const p=M.clone().addScaledVector(D,.9+u*.35);p.y+=.15+.55*u;p.z+=.1*Math.sin(k*3+s*4);fx.p(p,.25+.35*u,.3*(1-u)*flm,'#30292a',TX.puff,false,k);}
    for(let k=0;k<4;k++){const u=fr(s*.9+k/4),p=Tg.clone();p.y+=.45+.5*u;p.x+=.1*Math.sin(k+s*5)-.1;p.z+=.12*Math.sin(k*2+s*3);fx.p(p,.4,.07*flm*(1-u),'#ffe9c8',TX.puff,false,k);}  // heat shimmer
    for(let k=0;k<6;k++){const u=fr(s*2+k*.17),p=M.clone().addScaledVector(D,.4+.7*u);p.y+=.2*u;p.z+=(rnd(k)-.5)*.5*u;fx.p(p,.05,.9*flm*(1-u),'#ffd27a',TX.star,true,k);}
    // the target: flinch, catch fire, panic hop, bolt, come back
    const a=s-T0,bn=s2(s,T0,T0+.1)*(1-s2(s,2.3,2.6)),pan=win(s,T0+.25,1.95,.1),run1=win(s,1.95,2.45,.1),run2=win(s,2.62,3.3,.15);
    const dx=kf(s,[[T0,0],[T0+.1,.16],[T0+.4,.1],[1.9,.1],[2.4,1.15],[2.62,1.15],[3.3,0]]),yw=kf(s,[[1.9,0],[2.02,-Math.PI],[2.6,-Math.PI],[2.72,0]]);
    d.set(s,{dx,yaw:yw+.45*Math.sin(s*17)*pan,dy:.13*Math.abs(Math.sin(s*13))*pan+.04*Math.abs(Math.sin(s*20))*run1,sq:.2*Math.exp(-a*9)*(a>0?1:0),
      na:a>0?-.6*Math.exp(-a*5)*1+(pan?.3*Math.sin(s*25):0)*pan:0,hp:a>0?.5*Math.exp(-a*4):0,jaw:.5*pan,ear:1.1*s2(s,T0,T0+.08)*(1-s2(s,2.8,3.2)),ta:1.1*s2(s,T0,T0+.1)*(1-s2(s,2.5,2.9)),pitch:.25*Math.exp(-a*6)*(a>0?1:0),
      flash:.3*bn*(.5+.5*Math.sin(s*30)),fg:.35,fb:0,gait:null,follow:1,
      gait:{ph:s*24,amp:.15*Math.max(run1,run2*.7),lift:.08*Math.max(run1,run2*.7)}});
    d.tint('#2a1a10',.62*s2(s,T0,T0+.5)*(1-s2(s,2.8,3.3)));
    lick(fx,s,k=>d.chest.localToWorld(V(-.22+.12*k,.2,(rnd(k)-.5)*.1)),7,bn,0);if(s>T0&&s<2.6)fx.p(d.head.position.clone().add(V(.0,.12,0)),.2,.5*bn,'#ff8a2a',TX.soft,true);
    if(s>2.3&&s<3.0){const u=(s-2.3)/.7;for(let k=0;k<3;k++)fx.p(d.chest.localToWorld(V(-.1,.2+.5*u,0)).add(V(.05*k,0,.04*k)),.2+.3*u,.4*(1-u),'#4a4442',TX.puff,false,k);}
    const burn2=s2(s,T0,T0+.4)*(1-s2(s,2.5,3.1));if(burn2>.05&&s<2.0)fx.p(V(Tg.x-.1,.03,0),1.4,.3*bn,'#ff7a20',TX.soft,true);
    return .6*Math.exp(-Math.pow((s-1.0)/.06,2))+.25*flm*(.5+.5*Math.sin(s*60));}};
};

// ---------------------------------------------------------------- shared shrimp rig (pistol shrimp + mantis shrimp): tube body with ridged abdomen, stalked eyes, antennae, IK walking legs, 2-link raptorial/claw arm
function Shrimp(sc,o){o=Object.assign({col:'#e0623a',belly:'#f4d2a8',band:'#a8381c',L:1,eye:'#222',eyeR:.05,arm:[.3,.32],ar:.035},o);const L=o.L,c={o},NB=28;
  const body=c.body=new BB.Tube(NB+1,10);body.mesh.material=new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide});sc.add(body.mesh);
  const top=S.rgb(o.col),bot=S.rgb(o.belly),bd=S.rgb(o.band);const colf=(i,a,out)=>{const b=sm((-Math.cos(a)-.1)/.7),u=i/NB,m=u>.3?(Math.cos(u*2*Math.PI*6)*.5+.5)*.45:0;for(let k=0;k<3;k++){const v=top[k]+(bd[k]-top[k])*m;out[k]=v+(bot[k]-v)*b;}};
  const mat=lam(o.col),dk=lam(o.band),claw=lam(o.claw||o.col);c.mat=mat;
  c.eyes=[-1,1].map(z=>{const g=new T.Group();sc.add(g);const st=limb(sc,dk,.012*L,.012*L);const e=ell(g,lam(o.eyeCol||'#e8d060'),o.eyeR*L,o.eyeR*L*1.1,o.eyeR*L);const p=ell(g,lam('#101010'),o.eyeR*L*.5,o.eyeR*L*.5,o.eyeR*L*.3);p.position.set(o.eyeR*L*.75,0,z*.0);return {g,st,z};});
  c.ant=[-1,1].map(z=>{const t=new BB.Tube(10,4);t.mesh.material=new T.MeshLambertMaterial({color:o.band,side:T.DoubleSide});sc.add(t.mesh);return {t,z};});
  c.legs=[0,1,2,3,4,5].map(i=>({up:limb(sc,mat,.014*L,.01*L),lo:limb(sc,mat,.01*L,.006*L),i}));
  c.fan=[-.5,0,.5].map(a=>{const m=ell(sc,dk,.13*L,.012*L,.05*L);m.userData.a=a;return m;});
  c.a1=limb(sc,claw,o.ar*L*1.2,o.ar*L*.9);c.a2=limb(sc,claw,o.ar*L*.9,o.ar*L*.7);c.elb=ell(sc,claw,o.ar*L,o.ar*L,o.ar*L);c.hand=new T.Group();sc.add(c.hand);
  c.shadow=S.blob(sc,L*1.5,L*.8);
  const M=new T.Matrix4(),Q=new T.Quaternion(),E=new T.Euler(),one=V(1,1,1),W=p=>p.clone().applyMatrix4(M);c.W=W;
  c.pose=function(P){P=P||{};const pos=V(P.x||0,P.y===undefined?.09*L:P.y,P.z||0);E.set(P.roll||0,P.yaw||0,P.pitch||0,'YZX');Q.setFromEuler(E);M.compose(pos,Q,one);c.Q=Q;c.pos=pos;
    const pts=[];let x=.42*L,y=0,z=0;const cu=P.curl||0,st=.9*L/NB;for(let i=0;i<=NB;i++){const u=i/NB;pts.push(V(x,y,z));const th=.1*Math.sin(u*Math.PI*2)-cu*s2(u,.4,1)-(P.arch||0)*Math.sin(u*Math.PI)+(P.wag||0)*0;x-=Math.cos(th)*st;y+=Math.sin(th)*st;z+=(P.sway||0)*Math.sin(u*5-(P.sp||0))*st*.6;}
    const loc=pts;const wp=loc.map(W),rad=loc.map((p,i)=>{const u=i/NB;return L*(.075*Math.sin(Math.PI*Math.min(1,(u+.1)*.95))+.012)*(1+(u>.3?.07*Math.cos(u*Math.PI*12):0))*(i===0?.5:1);});
    body.update(wp,rad,colf,Y);c.pts=loc;
    c.eyes.forEach(e=>{const base=W(V(.37*L,.07*L,e.z*.05*L)),tip=W(V(.43*L,.11*L+(P.eyeUp||0)*.03*L,e.z*.07*L*(1+.3*(P.eyeOut||0))));e.g.position.copy(tip);place(e.st,base,tip);});
    c.ant.forEach(a=>{const ps=[];for(let i=0;i<10;i++){const u=i/9,w=(P.wig||0)*Math.sin((P.sp||0)*2-i*.7+a.z)*u;ps.push(W(V(.42*L+u*.55*L*(P.antF===undefined?1:P.antF),.05*L+.28*L*Math.sin(u*1.2)*(P.antU===undefined?1:P.antU)-.05*L*u,a.z*(.03*L+.1*L*u)+w*.08*L)));}a.t.update(ps,ps.map((p,i)=>.008*L*(1-i/10)+.001),(i,an,out)=>{out[0]=out[1]=out[2]=.5;},Y);});
    // legs: planted in the world under the body
    const yaw=P.yaw||0,cs=Math.cos(yaw),sn=Math.sin(yaw);c.legs.forEach((l,i)=>{const side=i%2?1:-1,k=(i>>1),hip=W(V((.22-.09*k)*L,-.04*L,side*.05*L)),lx=(.2-.12*k)*L+(P.legF||0)*L*(k===0?1:0),lz=side*.17*L,ft=V(pos.x*(P.follow===undefined?1:P.follow)+lx*cs+lz*sn,.01,pos.z*(P.follow===undefined?1:P.follow)-lx*sn+lz*cs);
      const r=ik(hip,ft,.1*L,.12*L,V(0,1,0));place(l.up,hip,r.knee);place(l.lo,r.knee,r.foot);});
    const te=wp[NB],td=wp[NB].clone().sub(wp[NB-1]).normalize();c.fan.forEach(f=>{f.position.copy(te).addScaledVector(td,.07*L);f.quaternion.copy(Q);f.rotateY(f.userData.a*(.6+(P.fanO||0)));f.position.addScaledVector(V(Math.cos(f.userData.a*0),0,0),0);});
    c.shadow.position.set(pos.x,.004,pos.z);c.shadow.rotation.z=-(P.yaw||0);
    // arm: shoulder -> elbow -> wrist, in the body plane, z offset to the camera side
    const zA=P.armZ===undefined?.09*L:P.armZ,sh=V((P.shX===undefined?.3:P.shX)*L,(P.shY===undefined?-.03:P.shY)*L,zA),a1=P.a1||0,a2=P.a2||0,l1=o.arm[0]*L,l2=o.arm[1]*L,el=sh.clone().add(V(Math.cos(a1)*l1,Math.sin(a1)*l1,0)),wr=el.clone().add(V(Math.cos(a1+a2)*l2,Math.sin(a1+a2)*l2,0));
    const shW=W(sh),elW=W(el),wrW=W(wr);place(c.a1,shW,elW);place(c.a2,elW,wrW);c.elb.position.copy(elW);c.hand.position.copy(wrW);c.hand.quaternion.copy(Q);c.hand.rotateZ(a1+a2+(P.a3||0));c.wrist=wrW;c.armAng=a1+a2+(P.a3||0);};
  c.pose({});return c;}
const ik=BB.ik;
// ripples / bubbles helpers
function bubbles(fx,s,x0,x1,y,n,tmul){for(let k=0;k<n;k++){const u=fr(s*.35+k*.173),p=V(x0+(x1-x0)*fr(k*.618),.1+u*1.6,(rnd(k)-.5)*1.2);p.x+=.04*Math.sin(s*3+k);fx.p(p,.035+.03*rnd(k+9),.4*(1-u*.4)*Math.min(1,u*8),'#cfeaff',TX.bubble,false);}}
S.bubbles=bubbles;S.Shrimp=Shrimp;
// 2 ------------------------------------------------------------------------------------------- boiling spray
SIGB.boiling_spray=function(sc,def){
  const blue=lam('#27384e'),shine=lam('#3f5f86'),org=lam('#d9672a'),dk=lam('#151a24'),c={},bx=.55;
  const root=new T.Group();root.rotation.order='YZX';sc.add(root);const thx=new T.Group();root.add(thx);ell(thx,blue,.2,.12,.14);ell(thx,shine,.12,.05,.08).position.set(.0,.09,0);
  const hd=new T.Group();hd.position.set(.22,-.01,0);thx.add(hd);ell(hd,dk,.11,.09,.1);for(const z of [-1,1]){ell(hd,lam('#e8e0d0'),.03,.03,.025).position.set(.07,.05,z*.07);ell(hd,lam('#080808'),.017,.017,.015).position.set(.09,.05,z*.08);spike(hd,dk,.012,.09,.1,-.04,z*.04,0,-Math.PI/2+z*.0).rotation.x=z*.5;}
  const ab=[];let par=thx,len=[.17,.17,.15];const abg=[];
  const a1=new T.Group();a1.position.set(-.14,.02,0);thx.add(a1);const e1=ell(a1,blue,.22,.12,.15);e1.position.x=-.13;ell(a1,shine,.14,.04,.1).position.set(-.13,.1,0);
  const a2=new T.Group();a2.position.set(-.3,0,0);a1.add(a2);ell(a2,org,.16,.1,.13).position.x=-.1;const a3=new T.Group();a3.position.set(-.2,0,0);a2.add(a3);ell(a3,lam('#f09a3a'),.08,.07,.08).position.x=-.04;const nozzle=new T.Group();nozzle.position.set(-.1,0,0);a3.add(nozzle);ell(nozzle,dk,.04,.035,.035);const hot=ell(nozzle,new T.MeshBasicMaterial({color:'#ffb040'}),.025,.025,.025);hot.position.x=-.03;
  const legs=[0,1,2,3,4,5].map(i=>({up:limb(sc,dk,.02,.014),lo:limb(sc,dk,.014,.008)}));const sh=S.blob(sc,.9,.5);
  const d=Pip(sc,2.3);const T0=def.ti,pulses=[1.0,1.11,1.22];
  return {pose(s,fx){
    const crouch=kf(s,[[.3,0],[.75,1],[1.0,.8],[2.0,.8],[2.5,0]]),curl=kf(s,[[.3,0],[.85,1.3],[1.0,1.45],[2.1,1.45],[2.6,0]]),shake=win(s,.5,1.0,.1)*.012;
    let rec=0;for(const t of pulses)rec=Math.max(rec,Math.exp(-Math.pow((s-t-.02)/.04,2)));
    const x=bx-.07*rec+shake*Math.sin(s*90);const y=.17-.045*crouch+.012*Math.sin(s*3);
    root.position.set(x,y+shake*Math.sin(s*77),0);root.rotation.set(0,0,-.1*crouch+.05*rec);a1.rotation.z=-curl*.72-.12*rec;a2.rotation.z=-curl*.7;a3.rotation.z=-curl*.65-.15*rec;hd.rotation.z=.15*crouch-.04*Math.sin(s*2);hot.material.color.set(S.ramp(1-s2(s,.4,1.0),['#fff2b0','#ffb040','#e8501f','#7a2a14']));
    root.updateMatrixWorld(true);
    // legs: planted, splayed in the bracing stance
    for(let i=0;i<6;i++){const k=i>>1,side=i%2?1:-1,hip=thx.localToWorld(V(.1-.1*k,-.07,side*.08)),ft=V(bx+.2-.17*k+.04*crouch*(k===0?1:0),.01,side*(.26+.05*crouch));const r=ik(hip,ft,.19,.2,V(0,1,.0).addScaledVector(V(0,0,side),.6));place(legs[i].up,hip,r.knee);place(legs[i].lo,r.knee,r.foot);}
    sh.position.set(bx,.004,0);
    const tip=nozzle.localToWorld(V(-.06,0,0)),tg=d.head.position.clone().add(V(-.0,-.08,0)),tau=.17,g=14;
    // three hot pulses
    for(let pi=0;pi<3;pi++){const t0=pulses[pi];if(s<t0||s>t0+.5)continue;
      for(let q=0;q<2;q++)fx.em(s,{t0:t0+q*.003,dt:.0065,n:12,life:tau+.04+.1*q,pos:k=>tip.clone(),vel:k=>{const v=tg.clone().sub(tip).multiplyScalar(1/(tau*(.8+.4*rnd(k+q*9))));v.y+=g*tau/2+(rnd(k+3+q)-.5)*1.3;v.z+=(rnd(k+pi*7+q*5)-.5)*1.5;return v;},g,size:(u,k)=>.03+.06*rnd(k+q*4)+.04*u,op:(u,k)=>1-u*.6,c:(u,k)=>k%3?'#ffb04a':'#fff2c0',tx:TX.drop,add:true});
      fx.em(s,{t0,dt:.012,n:6,life:.45,pos:k=>tip.clone(),vel:k=>tg.clone().sub(tip).multiplyScalar(1/tau*.7).add(V(0,.6+rnd(k)*.4,(rnd(k+4)-.5)*.8)),drag:3.5,size:(u,k)=>.12+.3*u,op:(u,k)=>.4*(1-u),c:()=>'#eee6dc',tx:TX.puff,add:false,rot:(u,k)=>k});
      if(s-t0<.1)fx.p(tip,.3*(1-(s-t0)/.1)+.1,1-(s-t0)/.1,'#ffd890',TX.star,true,s*20);}
    const wind=win(s,.55,1.0,.2);for(let k=0;k<4;k++){const u=fr(s*1.3+k/4);fx.p(tip.clone().add(V(-.04*k+.05*Math.sin(s*5+k),.1+.35*u,.05*Math.sin(k*3+s*4))),.12+.2*u,.35*wind*(1-u),'#e8e4de',TX.puff,false,k);}
    // the target: scalded, hops up on its hind legs yelping, flees, comes back
    const a=s-T0,ow=win(s,T0,1.9,.05),run1=win(s,1.85,2.4,.1),run2=win(s,2.6,3.3,.15),hop=Math.abs(Math.sin((s-T0)*11))*ow*rp(s,T0+.1,T0+.2);
    const hot2=s2(s,T0,T0+.1)*(1-s2(s,2.5,3.2));
    d.set(s,{dx:kf(s,[[T0,0],[T0+.1,.25],[T0+.35,.3],[1.8,.3],[2.35,1.3],[2.6,1.3],[3.3,0]]),yaw:kf(s,[[1.8,0],[1.95,-Math.PI],[2.55,-Math.PI],[2.7,0]])+.5*Math.sin(s*15)*ow*(s<1.8?1:0),dy:.16*hop+.04*Math.abs(Math.sin(s*20))*run1,
      pitch:kf(s,[[T0,0],[T0+.12,.55],[T0+.6,.4],[1.7,.4],[1.95,0]]),na:-.5*Math.exp(-a*6)*(a>0?1:0)+.5*Math.sin(s*20)*ow,jaw:.55*ow,ear:1.2*s2(s,T0,T0+.08)*(1-s2(s,2.8,3.2)),ta:1.3*s2(s,T0,T0+.1)*(1-s2(s,2.6,3))+0,sq:.15*Math.exp(-a*10)*(a>0?1:0),
      foot:[[0,.14*s2(s,T0,T0+.15)*(1-s2(s,1.8,2)),0],[0,.12*s2(s,T0,T0+.15)*(1-s2(s,1.8,2)),0],[0,0,0],[0,0,0]],follow:1,gait:{ph:s*24,amp:.15*Math.max(run1,run2*.7),lift:.08*Math.max(run1,run2*.7)},flash:.55*hot2*(.6+.4*Math.sin(s*26)),fg:.2,fb:0});
    d.tint('#e04a2a',.55*hot2);
    if(a>0&&a<.5)fx.hit(d.head.position.clone().add(V(0,-.05,0)),a,{n:6,r:.4,c:'#ffd890',c2:'#ff7a30'});
    for(let k=0;k<5;k++){const u=fr(s*1.6+k*.23);if(s>T0&&s<2.4)fx.p(d.chest.localToWorld(V(-.1+.1*k,.15,0)).add(V(0,.4*u,.04*Math.sin(k+s*8))),.14+.22*u,.35*hot2*(1-u),'#f2eee6',TX.puff,false,k);}
    return .35*Math.exp(-Math.pow((s-T0)/.05,2));}};
};


// 3 ------------------------------------------------------------------------------------------- sonic snap
SIGB.sonic_snap=function(sc,def){
  const L=1.25,c=Shrimp(sc,{L,col:'#d9603f',belly:'#f6d9b4',band:'#8c2a18',claw:'#e8764e',arm:[.22,.25],ar:.04,eyeR:.04,eyeCol:'#e8d060'}),d=Pip(sc,2.5),T0=def.ti,cm=lam('#ea7a52'),pale=lam('#f6e8d0');
  c.hand.scale.setScalar(1.55);ell(c.hand,cm,.16,.085,.075).position.set(.13,0,0);ell(c.hand,cm,.1,.03,.04).position.set(.3,-.035,0);const jd=new T.Group();jd.position.set(.14,.06,0);c.hand.add(jd);ell(jd,cm,.13,.032,.045).position.set(.12,0,0);ell(jd,pale,.025,.03,.03).position.set(.04,.03,0);
  const bm=Beams(sc);const bx=.55;
  return {pose(s,fx){
    const cock=kf(s,[[.3,0],[.85,1],[1.1,1],[1.14,0],[1.8,0]]),rec=Math.exp(-Math.pow((s-1.16)/.09,2));
    c.pose({x:bx-.14*rec-.04*s2(s,.5,1.0)*(1-s2(s,1.1,1.14)),y:.11*L+.02*cock,yaw:.0,pitch:.1*cock-.06*rec,curl:.5*cock-.2*rec,sp:s*3,wig:1,legF:0,a1:kf(s,[[.3,-.45],[.85,.12],[1.1,.14],[1.2,-.1],[1.9,-.45]]),a2:kf(s,[[.3,.7],[.85,.55],[1.1,.55],[1.2,.8],[1.9,.7]]),a3:kf(s,[[.3,0],[.85,.25],[1.1,.28],[1.2,0],[1.9,0]]),eyeUp:cock,antU:1-.5*rec,fanO:.4*rec});
    jd.rotation.z=kf(s,[[.3,0],[.8,1.15],[1.11,1.2],[1.145,0],[1.25,-.03],[1.9,.35],[2.6,.15]])+.02*Math.sin(s*60)*win(s,.9,1.12,.1);
    const tip=c.hand.localToWorld(V(.33,.0,0)),mid=c.hand.localToWorld(V(.3,.03,0)),tgh=d.chest.localToWorld(V(0,.1,0));
    bubbles(fx,s,0,3.2,0,9);
    // cavitation: the bubble blooms between the fingers, collapses with a flash, the pressure rings run out to the target
    const a=s-1.145,bs=kf(s,[[1.14,.0],[1.16,.1],[1.2,.3],[1.235,.34],[1.262,.04]]);
    if(s>1.14&&s<1.27)fx.p(mid.clone().add(V(.08,0,0)),bs,.9,'#d8f4ff',TX.bubble,true);
    if(a>0&&a<.14)fx.p(mid,.7*(1-a/.14)+.1,1-a/.14,'#ffffff',TX.star,true,.3);
    if(s>1.255&&s<1.42){const u=(s-1.255)/.165;fx.p(mid.clone().add(V(.1,0,0)),.3+.8*u,.9*(1-u),'#ffffff',TX.star,true,0);fx.p(mid.clone().add(V(.1,0,0)),.7*u+.3,.35*(1-u),'#9fe0ff',TX.soft,true);}
    bm.begin();for(let k=0;k<4;k++){const u=rp(s-1.15-k*.05,0,.2);if(u>0&&u<1)bm.vring(lerpV(mid.clone().add(V(.12,0,0)),tgh,eo(u)),.18+.3*eo(u)+.05*k,.85*(1-.5*u),k%2?'#d8f4ff':'#9fe0ff');}
    const ua=rp(s,T0,T0+.45);if(ua>0&&ua<1)bm.vring(tgh.clone().add(V(-.1,0,0)),.35+.7*eo(ua),.6*(1-ua),'#bff2ff');bm.end();
    // the target is hit by the pressure wave: rigid jolt, stars, goes limp and drifts
    const b=s-T0,jolt=b>0?Math.exp(-b*7):0,dz=b>0?.1*Math.sin(b*40)*Math.exp(-b*4):0,limp=s2(s,T0+.1,T0+.5)*(1-s2(s,2.3,2.9));
    d.set(s,{dx:kf(s,[[T0,0],[T0+.15,.14],[T0+.8,.2],[2.3,.2],[3.0,0]]),dy:kf(s,[[T0,0],[T0+.3,.1],[1.9,.12],[2.6,.04],[3.1,0]]),dz,roll:.25*Math.sin(b*17)*Math.exp(-b*2.5)*(b>0?1:0)+.5*limp*.2,pitch:.35*jolt+.12*limp,na:.7*jolt-.3*limp,hp:.4*jolt,jaw:.3*jolt,ear:.9*s2(s,T0,T0+.05)*(1-s2(s,2.7,3.1)),
      stars:s2(s,T0,T0+.1)*(1-s2(s,2.1,2.5)),flash:.55*Math.exp(-b*9)*(b>0?1:0),fr:.5,fg:.8,fb:1,limp:limp*.9,lt:s,sq:.12*jolt,ta:.8*limp});
    d.tint('#8fb4d8',.35*limp);
    if(b>0)fx.hit(d.chest.localToWorld(V(.15,.0,0)),b,{n:5,r:.35,c:'#d8f4ff',c2:'#7fd0ff'});
    return .3*Math.exp(-Math.pow((s-T0)/.05,2));}};
};
// 4 ------------------------------------------------------------------------------------------- blinding spit
SIGB.blinding_spit=function(sc,def){
  const sn=Serp(sc,{n:26,col:'#6b5a2e',belly:'#dcc98c',band:12,bandCol:'#4a3a1a',hood:1,hl:.11,hh:.052,hw:.062,eye:.016,rf:u=>.03+.075*Math.pow(Math.sin(Math.PI*Math.min(1,u*1.15+.04)),.5)}),d=Pip(sc,2.4),bm=Beams(sc),T0=def.ti,psi=-.75;
  const rot=(p,cx)=>{const x=p.x-cx,z=p.z;p.x=cx+x*Math.cos(psi)+z*Math.sin(psi);p.z=-x*Math.sin(psi)+z*Math.cos(psi);return p;};
  const tailP=V(-1.7,.04,.22);
  return {pose(s,fx){
    const rise=kf(s,[[.15,0],[.7,1],[2.2,1],[2.9,0]]),pull=kf(s,[[.7,0],[1.0,1],[1.045,-.2],[1.14,0],[1.9,0],[2.4,0]]),snap=s2(s,1.0,1.06)*(1-s2(s,1.7,2.3));
    const hx=.05-.1*pull*(pull>0?1:0)+.32*snap+.04*Math.sin(s*2.2)*rise,hy=.1+.72*rise-.04*snap+.02*Math.sin(s*3)*rise;
    const B=V(-.35,.04,0),H=V(hx,hy,0),H1=V(B.x-.2*rise,hy*.5,.0),H2=V(hx-.34+.08*(1-rise),hy*.98,0);
    const path=BB.bezPath(tailP,V(-1.2,.04,-.35),V(-.75,.04,.3),B,24).concat(BB.bezPath(B,H1,H2,H,24).slice(1)),pts=BB.resample(path,26).pts;
    pts.forEach((p,i)=>{const u=i/26;p.z+=.1*Math.sin(i*.8-s*2.5)*(1-rise)*(1-u)*.8+.03*Math.sin(i*.9+s*2)*u*rise;p.y=Math.max(.035,p.y);});pts.forEach(p=>rot(p,B.x));
    const head=pts[26],tgE=d.head.position.clone(),aim=tgE.clone().sub(head).normalize();const aimW=snap>.2?aim.clone().lerp(V(1,-.1,0),.0):V(1,-.15,.35).normalize();
    const hdir=V(1,-.12,0).normalize().lerp(aim,s2(s,.9,1.05)).normalize();
    sn.set(pts,{hood:s2(s,.25,.75)*(1-s2(s,2.5,3.1))+.12*Math.sin(s*3)*rise*0+.1*pull,hh:1,jaw:kf(s,[[.9,0],[1.03,0],[1.07,.7],[1.5,.7],[1.75,.05],[2.0,0]]),tg:Math.max(0,Math.sin(s*7))*(s<1.0?rise*.7:0),hdir,rs:1,hz:V(Math.sin(psi),0,Math.cos(psi))});
    // venom: two thin jets from the fangs to the two eyes
    bm.begin();const act=s>1.07&&s<1.46;
    if(act){const hp=sn.head.position;for(let i=0;i<2;i++){const z=i?1:-1;const a=sn.fangs[i].getWorldPosition(V(0,0,0)),b=d.eyeW[i].getWorldPosition(V(0,0,0)),front=eo(rp(s,1.075,1.2)),tail=rp(s,1.13,1.27);
      const pos=u=>{const p=lerpV(a,b,u);p.y+=.07*Math.sin(Math.PI*u);return p;};
      const N=7;for(let k=0;k<N;k++){const u0=tail+(front-tail)*k/N,u1=tail+(front-tail)*(k+1)/N;if(front>tail+.005)bm.seg(pos(u0),pos(u1),.024*(1-.3*k/N),'#d8f060',.95);}
      if(front>.1&&front<1)fx.p(pos(front),.09,.95,'#d8f060',TX.drop,false);
      fx.em(s,{t0:1.08+i*.01,dt:.012,n:8,life:.16,pos:k=>a.clone(),vel:k=>b.clone().sub(a).multiplyScalar(1/.15).add(V(0,.5,(rnd(k+i*5)-.5)*.5)),g:5,size:(u)=>.06,op:u=>.95,c:()=>'#c8e83a',tx:TX.drop,add:false});}}
    bm.end();
    // eyes hit: splatter, head snap, the dummy paws at its eyes and stumbles around blind
    const b=s-T0,blind=s>T0&&s<3.05,dec=Math.exp(-Math.max(0,b)*1.3),shake=blind?Math.sin(b*27)*dec:0,wander=s2(s,T0+.3,T0+.6)*(1-s2(s,2.6,3.0));
    d.set(s,{dx:kf(s,[[T0,0],[T0+.15,.2],[T0+.5,.3],[1.9,.5],[2.5,.4],[3.1,0]])+.1*Math.sin(s*5)*wander,yaw:.7*Math.sin(s*3.1)*wander+.3*shake*.5,pitch:.28*Math.exp(-Math.max(0,b)*5)*(b>0?1:0)-.15*wander,na:b>0?-.5*Math.exp(-b*5)-.1:0,hy:.85*shake,hr:.3*shake,hp:b>0?.2*Math.exp(-b*3):0,jaw:b>0?.3*Math.exp(-b*2):0,ear:1.0*s2(s,T0,T0+.1)*(1-s2(s,2.7,3.1)),sq:.14*Math.exp(-Math.max(0,b)*9)*(b>0?1:0),blind,
      flash:.35*Math.exp(-Math.max(0,b)*8)*(b>0?1:0),fr:.8,fg:.9,fb:.3,foot:[[-.14*s2(s,T0+.1,T0+.2)*(1-s2(s,1.6,1.9)),.24*s2(s,T0+.1,T0+.2)*(1-s2(s,1.6,1.9))*(.6+.4*Math.sin(s*14)),0],[0,0,0],[0,0,0],[0,0,0]],follow:1,gait:{ph:s*10,amp:.06*wander,lift:.03*wander}});
    d.tint('#c8d86a',.4*s2(s,T0,T0+.2)*(1-s2(s,2.5,3.1)));
    if(b>0&&b<.45){for(let i=0;i<2;i++){const e=d.eyeW[i].getWorldPosition(V(0,0,0));fx.p(e,.08+.2*b,.9*(1-b/.45),'#e8f598',TX.soft,true);for(let k=0;k<4;k++){const az=k*1.7+i;fx.p(e.clone().add(V(-.08*eo(b/.45)*Math.cos(az),.08*Math.sin(az)*eo(b/.45)+.04,.1*Math.sin(az+i)*eo(b/.45))),.03,.9*(1-b/.45),'#f2ffb0',TX.drop,true);}}}
    return .25*Math.exp(-Math.pow((s-T0)/.05,2));}};
};
// 5 ------------------------------------------------------------------------------------------- smash punch (mantis shrimp smasher, Odontodactylus; Patek et al. 2004, Nature 428)
// Not a punch: the two raptorial appendages are folded under the head like pocket knives. The merus flexes back and loads the saddle spring (small tremble, latch holds),
// then the latch lets go and the propodus + club swing about the elbow in a hammer arc from below-back, out and up, hitting with the club heel in ~3 ms (stretched to 50 ms here
// so it reads). A cavitation bubble forms behind the club and collapses a moment later with a flash: a second shock. Three rapid strikes, arms alternating, then fold back.
SIGB.smash_punch=function(sc,def){
  const L=1.3,c=Shrimp(sc,{L,col:'#2f9a82',belly:'#e8d27a',band:'#d85a2a',claw:'#d8552e',arm:[.13,.2],ar:.045,eyeR:.07,eyeCol:'#7ae0a0'}),d=Pip(sc,2.15,{shield:true}),H=[1.1,1.38,1.66],SA=[H[0],H[2]],SB=[H[1]];
  [c.a1,c.a2,c.elb,c.hand].forEach(m=>{m.visible=false;});
  const rm=lam('#e0502a'),rm2=lam('#ee6a38'),pale=lam('#ffe6b8'),club=lam('#ff5a2e'),spot=lam('#fff0d0');
  const mkArm=zs=>{const a={zs,mer:limb(sc,rm,.07*L,.055*L),prp:limb(sc,rm2,.048*L,.04*L),car:ell(sc,rm,.062*L,.062*L,.062*L),g:new T.Group()};sc.add(a.g);
    ell(a.g,club,.15,.1,.095).position.set(.05,0,0);ell(a.g,pale,.045,.085,.085).position.set(.17,0,0);for(const q of [[.02,.07,.05],[.07,.07,-.05],[.12,.06,.06],[.0,-.04,-.08]])ell(a.g,spot,.018,.018,.018).position.set(...q);
    spike(a.g,pale,.022,.2,.1,-.075,0,0,Math.PI/2);return a;};
  const arms=[mkArm(.075),mkArm(-.075)],bm=Beams(sc),pa=A=>A;
  const T0c=new T.Color('#f4f8f8'),REST1=.15,REST2=3.38,COCK1=-.12,COCK2=3.05,IMP1=.32,IMP2=6.5;
  // appendage state at time t for the strike list S (arm-local angles): a1 merus, a2 absolute propodus angle (rest 3.38 rad = folded back under the thorax, 6.5 = out front)
  const track=(t,S)=>{let i=-1;for(let k=0;k<S.length;k++)if(t>=S[k]-.3)i=k;if(i<0)return {a1:REST1,a2:REST2,cock:0};
    const t0=S[i],cock=s2(t,t0-.3,t0-.1),stk=Math.pow(clamp((t-(t0-.05))/.05,0,1),1.8),ret=eo(rp(t,t0+.05,t0+.31)),trem=cock*(1-stk)*.018*Math.sin(t*95);
    let a1=REST1+(COCK1-REST1)*cock,a2=REST2+(COCK2-REST2)*cock+trem;
    if(t>=t0-.05){a1=COCK1+(IMP1-COCK1)*stk;a2=COCK2+(IMP2-COCK2)*stk;}
    if(t>t0){const reb=Math.exp(-(t-t0)*40)*.1*Math.sin((t-t0)*70);a1=IMP1+(REST1-IMP1)*ret;a2=IMP2+(REST2-IMP2)*ret+reb;}
    return {a1,a2,cock};};
  const local=(t,S,zs)=>{const k=track(t,S),sh=V(.33*L,-.06*L,zs*L),el=sh.clone().add(V(Math.cos(k.a1)*.13*L,Math.sin(k.a1)*.13*L,0)),wr=el.clone().add(V(Math.cos(k.a2)*.2*L,Math.sin(k.a2)*.2*L,0)),tip=wr.clone().add(V(Math.cos(k.a2)*.2,Math.sin(k.a2)*.2,0));return {sh,el,wr,tip,a2:k.a2,cock:k.cock};};
  const shMat=d.shield.material,shC0=shMat.color.clone();
  const legPh=[0,Math.PI,Math.PI,0,0,Math.PI];
  return {pose(s,fx){
    const appr=s2(s,.12,.82),cockA=track(s,SA).cock,cockB=track(s,SB).cock,co=Math.max(cockA,cockB),moving=appr*(1-s2(s,.7,.85)),rise=s2(s,.85,1.0)*(1-s2(s,1.95,2.5));
    const bx=.13+.4*appr-.015*Math.exp(-Math.pow((s-H[0])/.05,2));
    c.pose({x:bx,y:(.17+.05*rise)*L+.012*Math.sin(s*3),pitch:.1*co+.03*rise,curl:.25*rise,sp:s*3,wig:1,a1:0,a2:0,eyeUp:co,eyeOut:co*.8,arch:.12*co,fanO:.25*rise,antU:1-.3*co,follow:1});
    // legs: custom stepping while it closes in, then braced and planted
    c.legs.forEach((l,i)=>{const side=i%2?1:-1,k=i>>1,hip=c.W(V((.22-.09*k)*L,-.04*L,side*.05*L)),ph=s*9+legPh[i],st=.045*moving,ft=V(bx+(.18-.14*k)*L+st*Math.sin(ph),.01+.04*moving*Math.max(0,Math.cos(ph)),side*(.17+.03*rise)*L);
      const r=ik(hip,ft,.14*L,.16*L,V(0,1,0).addScaledVector(V(0,0,side),.6));place(l.up,hip,r.knee);place(l.lo,r.knee,r.foot);});
    // raptorial appendages
    const P=[local(s,SA,.075),local(s,SB,-.075)];
    arms.forEach((a,i)=>{const p=P[i],shW=c.W(p.sh),elW=c.W(p.el),wrW=c.W(p.wr);place(a.mer,shW,elW);place(a.prp,elW,wrW);a.car.position.copy(elW);a.g.position.copy(wrW);a.g.quaternion.copy(c.Q);a.g.rotateZ(p.a2);});
    // target first (its shield is the contact point), then the effects that touch it
    const hp=d.chest.localToWorld(V(.3,.0,0)),n1=s>=H[0],n2=s>=H[1],a3=s-H[2];
    const jolt=H.reduce((m,h)=>s>=h?Math.max(m,Math.exp(-(s-h)*9)):m,0),sw=H.map((h,i)=>.045*s2(s,h,h+.05)*(i<2?1:0)),step=sw[0]+sw[1];
    const fly=a3>0?eo(rp(a3,0,.6)):0,fl3=s2(s,H[2],H[2]+.55)*(1-s2(s,2.5,2.9)),lim=Math.max(s2(s,H[2]+.1,H[2]+.5)*(1-s2(s,2.4,2.8)),.5*s2(s,H[1],H[1]+.3)*(1-s2(s,H[2],H[2]+.1)));
    d.set(s,{dx:(step+.55*fly)*(1-s2(s,2.6,3.3)),dy:a3>0?.35*Math.sin(Math.PI*rp(a3,0,.7))*(a3<.7?1:0):0,roll:a3>0?-(Math.PI*1.5)*fl3:0,pitch:.3*jolt+(a3>0?.6*Math.exp(-a3*5):0),na:-.45*jolt,jaw:.3*(jolt>.2?1:0),ear:.9*s2(s,H[0],H[0]+.05)*(1-s2(s,2.7,3.1)),nosh:s>H[1],stars:s2(s,H[2]+.5,H[2]+.7)*(1-s2(s,2.4,2.8)),flash:.7*Math.exp(-Math.min(...H.map(h=>Math.abs(s-h)+(s<h?9:0)))*9)*(s>H[0]?1:0),sq:.12*jolt,limp:lim,lt:s});
    // shield: cracks after the first hit, burst on the second
    shMat.color.copy(shC0).lerp(T0c,.3*(n1?1:0));d.shield.rotation.y=.12*Math.sin((s-H[0])*40)*Math.exp(-(s-H[0])*8)*(n1?1:0);
    const lie=s2(s,H[2]+.5,H[2]+.7)*(1-s2(s,2.3,2.9));if(lie>0)d.root.position.y=Math.max(.14,d.root.position.y*(1-lie)+.14*lie);
    // blur streak along the club arc during each swing, and the swing's tip flare
    bm.begin();const all=[[SA,P[0],0],[SB,P[1],1]];
    for(const [S,pp,ai] of all)for(const t0 of S){if(s<t0-.056||s>t0+.012)continue;let prev=null;for(let k=0;k<9;k++){const t=Math.min(s,t0)-.0055*k,q=c.W(local(t,S,pp.sh.z/L).tip);if(prev)bm.seg(prev,q,.1*(1-k/10),k%2?'#ffe0b0':'#ffc080',.9*(1-k/9));fx.p(q,.5*(1-k/10)+.1,.95*(1-k/9),'#ffd090',TX.soft,true);prev=q;}
      fx.p(c.W(pp.tip),.5,.5*(1-Math.abs(s-t0+.02)/.04>0?1:0),'#ffe0b0',TX.soft,true);}
    // impacts: flash, cavitation bubble blooms behind the club and collapses ~35 ms later with a second flash and shock ring
    H.forEach((h,i)=>{const a=s-h,big=i===2,cp=hp.clone().add(V(.04,i===1?.05:-.02,i===1?-.04:.03));
      if(a>0&&a<.5)fx.hit(cp,a,{n:big?9:6,r:big?.75:.5,sz:.09,c:'#fff0b8',c2:'#ff9a40'});
      if(a>-.004&&a<.036){const u=clamp((a+.004)/.04,0,1);fx.p(cp.clone().add(V(-.09*u,0,0)),.1+.34*Math.sin(Math.PI*u*.5),.9,'#d8f4ff',TX.bubble,true);}
      if(a>.036&&a<.2){const u=(a-.036)/.164;fx.p(cp.clone().add(V(-.1,0,0)),1.1*(1-u)+.15,1-u,'#ffffff',TX.star,true,.5+i);fx.p(cp.clone().add(V(-.1,0,0)),.35+.9*u,.4*(1-u),'#9fe0ff',TX.soft,true);bm.vring(cp.clone().add(V(-.1,0,0)),.2+.7*eo(u),.7*(1-u),'#bff2ff');}
    });bm.end();
    // shell fragments of the shield (burst at the second hit, a few more at the third)
    const sa=s-H[1];d.shards.forEach((m,k)=>{if(sa<0){m.visible=false;return;}m.visible=sa<1.1;const v=V(.6+.5*rnd(k),.9+rnd(k+3)*1.2,(rnd(k+7)-.5)*1.6);m.position.set(hp.x+.1+v.x*sa,Math.max(.03,hp.y+v.y*sa-4.5*sa*sa),hp.z+v.z*sa);m.rotation.set(sa*9+k,sa*7,sa*5);m.scale.setScalar(Math.max(.01,1-sa*.5));if(m.position.y<=.031)m.rotation.set(0,0,0);});
    if(a3>0&&a3<1.0)for(let k=0;k<4;k++){const v=V(.8+.5*rnd(k+20),.8+rnd(k+23),(rnd(k+27)-.5)*1.4);fx.p(V(hp.x+.1+v.x*a3,Math.max(.04,hp.y+v.y*a3-4.5*a3*a3),hp.z+v.z*a3),.05,.8*(1-a3),'#bfe0e4',TX.drop,false);}
    bubbles(fx,s,0,2.5,0,6);
    return .8*Math.max(...H.map(h=>Math.exp(-Math.pow((s-h)/.05,2))));}};
};
// 6 ------------------------------------------------------------------------------------------- electric discharge
SIGB.electric_discharge=function(sc,def){
  const sn=Serp(sc,{n:30,nv:10,col:'#3d4a44',belly:'#c4a84a',hl:.12,hh:.05,hw:.075,eye:.012,eyeCol:'#d8d060',rf:u=>.05+.045*Math.sin(Math.PI*Math.min(1,u*1.2+.0))*(1-.5*u*u)+.008}),d=Pip(sc,2.0),b=Pip(sc,3.1,{col:'#8fa3bd',belly:'#cfd9e6',z0:.35}),bm=Beams(sc),T0=def.ti;
  return {pose(s,fx){
    const g=kf(s,[[.3,0],[.95,1],[1.05,1.4],[1.9,1],[2.3,0]]),coil=kf(s,[[.3,0],[.95,1],[1.02,.3],[1.2,.1],[2.3,0],[2.8,0]]),flash=win(s,1.0,1.85,.04);
    const pts=[];for(let i=0;i<=30;i++){const u=i/30,amp=.1+.16*coil,w=amp*Math.sin(u*(6+2*coil)-s*(5+4*coil))*(.3+.9*(1-u));const x=-1.2+(1.7-.3*coil)*u+.12*coil*Math.sin(u*5);pts.push(V(x,.3+.025*Math.sin(u*5+s*2)+.05*coil*Math.sin(u*3.3),w*(.5+.5*(1-u)+.2)));}
    pts.forEach(p=>{p.z+=.0;});sn.set(pts,{jaw:.3*flash,hdir:pts[30].clone().sub(pts[28]).add(V(0,0,0))});
    const flick=.5+.5*Math.sin(s*70);sn.setGlow(.3*g*(.4+.6*flick*(g>.8?1:.3)),.26*g*(.4+.6*flick),.06*g);
    const head=pts[30].clone().add(V(.06,.04,0)),t1=d.chest.localToWorld(V(0,.05,0)),t2=b.chest.localToWorld(V(0,.05,0)),seed=Math.floor(s*30)*13;
    bm.begin();
    if(g>.1&&s<1.0)for(let k=0;k<5;k++){const i=3+Math.floor(rnd(Math.floor(s*14)+k)*24),p=pts[i];fx.p(p.clone().add(V(0,.08,0)),.12,.8*g*rnd(k+Math.floor(s*20)),'#cfe8ff',TX.star,true,k+s*10);if(k<3)bm.bolt(p,p.clone().add(V(.08*Math.sin(k+seed),.14,.16*Math.cos(k*2+seed))),seed+k,3,.006,'#dff2ff',.05,.8*g);}
    if(flash>.1){bm.bolt(head,t1,seed,8,.016,'#bfe8ff',.26,flash);bm.bolt(head,t1,seed+50,7,.009,'#ffffff',.18,flash);bm.bolt(head.clone().add(V(0,.0,-.05)),t1.clone().add(V(0,.1,.05)),seed+80,6,.007,'#e8f8ff',.3,flash*.8);
      if(s>1.2){bm.bolt(t1.clone().add(V(.1,.1,0)),t2,seed+90,8,.014,'#cfe6ff',.3,flash);bm.bolt(t1.clone().add(V(.1,.0,0)),t2,seed+120,7,.007,'#ffffff',.2,flash);}
      fx.p(head,.3,.7*flash,'#bfe8ff',TX.soft,true);fx.p(t1,.45+.15*flick,.7*flash,'#fff7b0',TX.soft,true);if(s>1.2)fx.p(t2,.4+.1*flick,.6*flash,'#fff7b0',TX.soft,true);
      for(let k=0;k<5;k++)fx.p(t1.clone().add(V(.2*Math.cos(seed+k*1.3)*rnd(seed+k),.2*rnd(seed+k+2)+.05,.2*Math.sin(seed+k*2.1))),.07,.9*flash,'#fff7b0',TX.star,true,k);}
    bm.end();
    // both targets seize: rigid, fur on end (spiky ears), tremor, then drop and twitch
    for(const [t,dd,t0,dz] of [[d,d,T0,0],[b,b,1.22,.35]]){const q=s-t0,on=win(s,t0,1.85,.03),tr=on*(.5+.5*Math.sin(s*64)),fall=s2(s,t0+.7,t0+.95)*(1-s2(s,2.4,2.9));
      t.set(s,{dx:.07*Math.sin(s*57)*on+(q>0?.05*s2(q,0,.3):0)*(1-s2(s,2.5,3)),dz:.05*Math.sin(s*43+1)*on+(dz?0:0),roll:-1.35*fall+.05*Math.sin(s*50)*on,pitch:.35*on*(1-fall),na:.5*on,hp:.5*on,jaw:.4*tr,ear:-.5*on,ta:.8*on,tc:.5*on,stars:on*(s>t0+.4?1:0),flash:.4*tr,fr:.5,fg:.75,fb:1,limp:fall,lt:s,dy:-.3*fall,sq:0});
      if(fall>.9)t.root.position.y=Math.max(.14,t.root.position.y);t.tint('#a8c8ff',.3*on);}
    return .35*flash*(.5+.5*Math.sin(s*60));}};
};
// 7 ------------------------------------------------------------------------------------------- tongue snatch (chameleon; de Groot & van Leeuwen 2004 Proc R Soc B 271; Anderson 2016 J Exp Biol 219)
// Sequence of the real strike: the eyes swivel independently, then both converge on the prey; the body freezes; the mouth opens slowly and the sticky, cupped tongue pad is pushed just
// past the lips; then the elastic-loaded tongue (collagen sheath around the entoglossal bone, latch-and-spring like the mantis) is released and shoots out ~1.2 body lengths in ~20 ms
// (stretched here to 50 ms); the pad grips the insect (viscous adhesion + suction) and the hyoglossus reels it back over ~0.4 s, the tongue bunching up, into a gulp.
SIGB.tongue_snatch=function(sc,def){
  const c=Quad(sc,{col:'#6aa84f',belly:'#cfe39a',dark:'#3f7a34',x0:.1,sl:.36,pr:[.16,.21,.1],cr:[.17,.22,.1],legU:.17,legL:.2,lr:.032,sprawl:.9,fw:1.1,nl:.12,ns:4,nr0:.1,nr1:.07,na0:.7,nc0:-.5,hl:.12,hh:.09,hw:.075,sn:.05,snh:.05,snw:.05,tl:.7,ts:14,tr0:.06,tr1:.016,ta0:-.2,eye:.06,eyeY:.7,toeL:.045,
    skin:(i,a,out,part,top)=>{if(part==='tail'&&i%3===0){out[0]*=.6;out[1]*=.8;}if(part==='neck'&&Math.cos(a)<-.1){out[0]=.9;out[1]=.9;out[2]=.55;}}}),T0=def.ti,bm=Beams(sc);
  const dm=lam('#3f7a34'),skin=lam('#6aa84f'),rimM=lam('#7fc85f');
  // casque (helmet crest), brow ridges and dorsal spines
  const cas=ell(c.head,dm,.1,.07,.03);cas.position.set(-.085,.075,0);cas.rotation.z=.5;for(let k=0;k<7;k++)spike(c.pel,dm,.012,.05,k*.08-.1,.19,0,0,.1);
  // turret eyes: a ball in a scaly cone (lid cap with a small opening), whole eye swivels independently
  c.eyeW.forEach(e=>{e.visible=false;});c.eyeP.forEach(e=>{e.visible=false;});c.blind.forEach(e=>{e.visible=false;});
  const ER=.062,eyes=[-1,1].map(z=>{const g=new T.Group();g.position.set(c.o.hl*.55,c.o.hh*.7,z*c.o.hw*.95);c.head.add(g);
    ell(g,lam('#d6e07a'),ER,ER,ER);const pu=ell(g,lam('#101010'),ER*.42,ER*.42,ER*.3);pu.position.x=ER*.8;pu.scale.multiplyScalar(1.25);
    const lg=new T.SphereGeometry(ER*1.18,12,8,0,Math.PI*2,0,2.0);lg.rotateZ(Math.PI/2);const lid=new T.Mesh(lg,rimM);g.add(lid);return {g,z};});
  // the branch the chameleon grips, a twig with leaves behind, and the prey (a fly)
  const br=new T.Mesh(new T.CylinderGeometry(.085,.1,2.4,10),lam('#7a5a38'));br.rotation.z=Math.PI/2;br.position.set(.5,.085,0);sc.add(br);
  const tw=new T.Mesh(new T.CylinderGeometry(.015,.02,.9,6),lam('#7a5a38'));tw.position.set(1.65,.45,-.3);tw.rotation.z=.25;sc.add(tw);const lf=lam('#4a8a3a');for(let k=0;k<5;k++){const l=ell(sc,lf,.1,.012,.05);l.position.set(1.62+.08*k-.1,.2+.18*k,-.3+.05*(k%2));l.rotation.set(0,k,.5-.2*k);}
  const fly=new T.Group();sc.add(fly);ell(fly,lam('#27384a'),.032,.022,.022);ell(fly,lam('#3a2a2a'),.014,.016,.016).position.x=.034;const wm=new T.MeshBasicMaterial({color:'#e8f4ff',transparent:true,opacity:.55,depthWrite:false,side:T.DoubleSide}),wings=[-1,1].map(z=>{const w=ell(fly,wm,.03,.003,.016);w.position.set(-.005,.018,z*.018);return {w,z};});
  const wing2=ell(sc,wm,.06,.005,.03);
  const tong=new BB.Tube(22,6),tm=new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide});tong.mesh.material=tm;sc.add(tong.mesh);
  const pad=ell(sc,lam('#f08a98'),.05,.042,.042),cup=ell(sc,lam('#a8344a'),.02,.032,.032);
  const eul=new T.Quaternion(),X=V(1,0,0),TF=1.07,TC=T0,TR0=1.2,TR1=1.62,FLY0=V(1.45,.74,0);
  const gv=(a,b)=>V(Math.cos(a)*Math.cos(b),Math.sin(b),Math.sin(a)*Math.cos(b));
  return {pose(s,fx){
    const lock=s2(s,.55,.95)*(1-s2(s,1.78,2.1)),sway=Math.sin(s*2.6)*(1-s2(s,.5,.9)),jawO=kf(s,[[.8,0],[.98,.55],[1.07,.95],[1.62,.9],[1.72,.4],[1.78,0],[1.9,.12],[2.0,0],[2.15,.12],[2.25,0]]),
      ext=kf(s,[[.88,0],[1.0,.05],[1.06,.1],[1.07,.1],[1.12,1],[1.2,1],[1.62,0]]),sp=Math.exp(-Math.pow((s-1.1)/.06,2)),gulp1=Math.exp(-Math.pow((s-1.82)/.07,2)),gulp2=Math.exp(-Math.pow((s-2.12)/.07,2)),creep=s2(s,.9,1.06)*(1-s2(s,1.15,1.4));
    const flyG=FLY0.clone();const stuck=s>=TC&&s<1.7;
    const base={x:.1+.04*sway*.5-.05*sp+.03*creep,y:c.h+.14-.02*lock,pitch:.04*sway-.04*lock+.06*sp-.07*creep,bend:-.08*lock,br:.02*Math.sin(s*2)+.1*(gulp1+gulp2),na:.18*lock-.1*sp+.04*sway,hp:-.1*lock+.12*sp,hy:0,jaw:jawO,ta:.25*lock,tc:kf(s,[[.3,2.2],[.9,3.6],[1.1,3.6],[1.7,3.1],[2.6,2.3]]),tx:u=>[0,.15*Math.sin(s*1.5-u*3)],hr:.02*sway,
      nrf:u=>1+.55*(gulp1*Math.exp(-Math.pow((u-.25)/.3,2))+gulp2*Math.exp(-Math.pow((u-.7)/.3,2)))+.35*s2(s,.9,1.07)*(1-s2(s,1.15,1.6))*Math.exp(-Math.pow((u-.8)/.3,2)),
      foot:[[0,.09,-.02],[0,.09,.02],[0,.09,-.02],[0,.09,.02]],follow:1};
    // fly: hovers in a little figure of eight, jerks when the tongue lands, is carried in on the pad, arrives anew at the end
    const hov=V(.04*Math.sin(s*5),.03*Math.sin(s*10)+.02*Math.sin(s*3),.04*Math.cos(s*5));
    // aim: the head points at the fly (iterate once)
    c.pose(base);let hd=V(1,0,0).applyQuaternion(c.head.quaternion),mp=c.mouth(.97);const want=Math.atan2(FLY0.y-mp.y,FLY0.x-mp.x),cur=Math.atan2(hd.y,hd.x);base.hp+=(want-cur)*lock*.95;c.pose(base);mp=c.mouth(.97);hd=V(1,0,0).applyQuaternion(c.head.quaternion);
    // eyes: independent sweeps, then converge on the prey
    const flyNow=FLY0.clone().add(hov);
    eyes.forEach((e,i)=>{const ew=c.head.localToWorld(e.g.position.clone()),to=c.head.worldToLocal(flyNow.clone()).sub(e.g.position).normalize(),scan=gv(.9*Math.sin(s*1.9+i*2.3)+(i?.3:-.3),.5*Math.sin(s*1.3+i*1.7)),conv=s2(s,.5+.12*i,.9+.08*i)*(1-s2(s,1.9,2.4));const g=scan.clone().lerp(to,conv).normalize();e.g.quaternion.setFromUnitVectors(X,g);});
    // the tongue: aimed along the mouth->fly line, flies ballistically, reels in bunched
    const dir=FLY0.clone().sub(mp),Lfull=dir.length()-.02;dir.normalize();const len=Lfull*ext,reel=s>TR0?clamp((s-TR0)/(TR1-TR0),0,1):0,pt=mp.clone().addScaledVector(dir,len),root=c.head.localToWorld(V(c.tipX*.55,-c.o.hh*.25,0));
    const vis=ext>.001,n=22,pts=[],rad=[],bunch=reel>0&&reel<1?Math.sin(reel*Math.PI)*.0:0;
    for(let i=0;i<n;i++){const u=i/(n-1),p=root.clone().lerp(pt,u);p.y+=-.035*Math.sin(Math.PI*u)*Math.min(1,len/Lfull)*(1-.5*reel)+.012*Math.sin(u*10-s*70)*(s>1.06&&s<1.14?1:0);
      // bunching: while reeling, the shaft is a wavy accordion
      const wob=reel>0&&reel<1?.045*Math.sin(u*14)*Math.sin(Math.PI*Math.min(1,reel*1.6))*(1-.3*u):0;p.y+=wob;p.z+=wob*.6;pts.push(p);
      const thick=1+(reel>0&&reel<1?.9*Math.sin(u*18+1)*.5*Math.sin(Math.PI*Math.min(1,reel*1.4)):0);rad.push((.014+.002*u+(u>.88?.03*(u-.88)/.12:0))*thick);}
    tong.mesh.visible=vis;pad.visible=cup.visible=vis;
    if(vis){tong.update(pts,rad,(i,a,o)=>{o[0]=.93;o[1]=.42;o[2]=.5;},Y);pad.position.copy(pt);const ori=dir.clone();pad.quaternion.setFromUnitVectors(X,ori);cup.position.copy(pt).addScaledVector(ori,.035);cup.quaternion.copy(pad.quaternion);
      const sq=s>=TC&&s<1.25?.8:1;pad.scale.set(.05*sq*.8,.042,.042);cup.scale.set(.02,.032,.032);}
    // fly position
    let fp=flyNow;if(stuck){const ft=Math.min(1,Math.max(0,(s-TC)/.06));fp=lerpV(flyNow,pt.clone().addScaledVector(dir,.05),ft);}else if(s>=1.7&&s<2.8)fp=null;
    const arrive=s2(s,2.75,3.25),away=1-arrive;if(s>=2.75)fp=FLY0.clone().add(hov).add(V(.7*away,.25*away*Math.sin(s*9),0));
    fly.visible=!!fp&&!(s<=TF&&false);if(fp){fly.position.copy(fp);fly.rotation.set(.3*Math.sin(s*4),stuck?2.8:Math.PI+.4*Math.sin(s*3),.15);const fl=Math.sin(s*(stuck?190:140));wings.forEach(w=>{w.w.rotation.x=w.z*(.5+.5*fl);});if(stuck){fly.scale.setScalar(2.2*(1-.45*s2(s,TR0+.2,TR1)));}else fly.scale.setScalar(2.2);}
    // contact flash, a stuck-and-tugged shiver, a wing left drifting down after the swallow
    const a=s-TC;if(a>-.01&&a<.3)fx.p(pt.clone().add(V(.02,0,0)),.14*(1-a/.3)+.05,.8*(1-a/.3),'#fff0e0',TX.star,true,s*10);
    if(a>0&&a<.22){const u=a/.22;for(let k=0;k<5;k++)fx.p(pt.clone().add(V(.04*Math.cos(k*1.3)*u,.04*Math.sin(k*2.1)*u,.04*Math.sin(k*1.1)*u)),.03,.8*(1-u),'#fff2f2',TX.drop,false);}
    // mucus strands between the pad and the mouth while the tongue is out (thin additive threads)
    bm.begin();if(ext>.3&&reel<.9)for(let k=0;k<2;k++){const q=pts[n-4-k*3];bm.seg(q,q.clone().add(V(0,-.03-.01*k,.02*(k?1:-1))),.0025,'#ffe8f0',.5);}bm.end();
    const wt=s-1.8;wing2.visible=wt>0&&wt<.9;if(wt>0&&wt<.9){wing2.position.set(mp.x+.05*Math.sin(wt*9),Math.max(.17,mp.y-.5*wt*wt*1.2-.25*wt),mp.z+.03*Math.cos(wt*7));wing2.rotation.set(wt*6,wt*5,wt*4);}
    if(gulp1>.3||gulp2>.3)for(let k=0;k<2;k++)fx.p(c.neckPts[1].clone().add(V(0,-.07,.1+.01*k)),.05,.6*Math.max(gulp1,gulp2),'#fff',TX.star,true,k);
    return .12*Math.exp(-Math.pow((s-TC)/.05,2));}};
};
// 8 ------------------------------------------------------------------------------------------- water jet
SIGB.water_jet=function(sc,def){
  const pool=new T.Mesh(new T.CylinderGeometry(.85,.85,.34,28,1,true),new T.MeshBasicMaterial({color:'#3b86b8',transparent:true,opacity:.35,side:T.DoubleSide,depthWrite:false}));pool.position.set(0,.17,0);sc.add(pool);
  const surf=new T.Mesh(new T.CircleGeometry(.85,28),new T.MeshBasicMaterial({color:'#6ab8e0',transparent:true,opacity:.5,depthWrite:false}));surf.rotation.x=-Math.PI/2;surf.position.set(0,.34,0);sc.add(surf);
  const rim=new T.Mesh(new T.TorusGeometry(.86,.035,6,28),lam('#7a7468'));rim.rotation.x=Math.PI/2;rim.position.y=.02;sc.add(rim);
  const f=new T.Group();f.scale.setScalar(1.35);sc.add(f);const fm=lam('#d0b058'),stripe=lam('#6a5a30'),pale=lam('#f4e8c0');ell(f,fm,.3,.11,.06);ell(f,pale,.24,.05,.055).position.set(.0,-.05,0);const hdf=new T.Group();hdf.position.set(.24,.02,0);f.add(hdf);ell(hdf,fm,.1,.07,.055).position.x=.03;const jw=new T.Group();jw.position.set(.0,-.03,0);hdf.add(jw);ell(jw,pale,.08,.02,.04).position.x=.05;const eye=ell(hdf,lam('#111'),.022,.022,.02);eye.position.set(.06,.035,.05);ell(hdf,lam('#e8c050'),.032,.032,.01).position.set(.06,.035,.045);
  for(let k=0;k<4;k++)ell(f,stripe,.015,.1,.062).position.set(-.14+k*.1,.0,0);
  const tail=new T.Group();tail.position.set(-.3,0,0);f.add(tail);const tf=new T.Mesh(new T.ConeGeometry(.1,.2,4),fm);tf.rotation.z=Math.PI/2;tf.scale.set(1,1,.2);tf.position.x=-.08;tail.add(tf);const fin=new T.Mesh(new T.ConeGeometry(.07,.18,3),fm);fin.scale.set(1,1,.15);fin.position.set(-.05,.12,0);f.add(fin);
  const tr=new T.Mesh(new T.CylinderGeometry(.06,.09,1.15,8),lam('#6a4a2a'));tr.position.set(2.45,.575,0);sc.add(tr);const br=new T.Mesh(new T.CylinderGeometry(.045,.055,1.7,8),lam('#6a4a2a'));br.rotation.z=Math.PI/2;br.position.set(1.65,1.0,0);sc.add(br);
  for(const [x,y,z,r] of [[2.3,1.45,.0,.4],[2.55,1.25,.1,.3]])ell(sc,lam('#4f7d3a'),r,r*.6,r*.7).position.set(x,y,z);
  const d=Pip(sc,1.85,{y0:1.03,col:'#c9a86a'}),T0=def.ti,bm=Beams(sc);
  const mouthFish=()=>hdf.localToWorld(V(.12,-.0,0));
  return {pose(s,fx){
    const aim=kf(s,[[.3,0],[.8,1],[2.0,1],[2.6,0]]),puff=kf(s,[[.5,0],[1.1,1],[1.2,0],[2.4,0]]),spit=s2(s,1.17,1.2)*(1-s2(s,1.36,1.44));
    f.position.set(-.12,.13+.04*aim+.012*Math.sin(s*3)-.02*puff*0,0);f.rotation.z=.42*aim+.12*s2(s,1.15,1.2)*(1-s2(s,1.3,1.6));hdf.rotation.z=.2*aim;jw.rotation.z=-.35*s2(s,1.15,1.2)*(1-s2(s,1.4,1.5));tail.rotation.y=.35*Math.sin(s*9)*(1-aim*.6);
    f.scale.set(1+.05*puff,1,1+.15*puff);hdf.scale.set(1,1+.2*puff,1+.35*puff);
    f.updateMatrixWorld(true);const m=mouthFish(),tg=V(1.78,1.34,0).add(V(0,0,0));
    // surface ripples where the snout breaks through
    for(let k=0;k<3;k++){const u=fr(s*.7+k/3);fx.ring(m.x*.9,.345,0,.1+.5*u,.5*(1-u)*(.4+.6*aim),'#dff2ff');}
    for(let k=0;k<6;k++){const u=fr(s*.6+k*.17);fx.p(V(-.5+.9*rnd(k),.05+.28*u,(rnd(k+4)-.5)*.5),.03,.4*(1-u),'#cfeaff',TX.bubble,false);}
    // the jet: one fast arc of water, built from beam pieces and drops
    bm.begin();const a=s-1.18;const pos=u=>{const p=lerpV(m,tg,u);p.y+=.5*Math.sin(Math.PI*u)*.9;return p;};
    if(spit>.01){const front=eo(rp(s,1.18,1.34)),tail=rp(s,1.3,1.44);const N=9;if(front>tail)for(let k=0;k<N;k++){const u0=tail+(front-tail)*k/N,u1=tail+(front-tail)*(k+1)/N;bm.seg(pos(u0),pos(u1),.018*(1-.2*k/N)*(1+.3*Math.sin(k+s*40)),'#d8f0ff',.85);}
      fx.em(s,{t0:1.18,dt:.01,n:14,life:.26,pos:k=>m.clone(),vel:k=>{const v=tg.clone().sub(m).multiplyScalar(1/.16);v.y+=2.2+rnd(k)*.6;v.z+=(rnd(k+5)-.5)*.5;v.x*=.9+rnd(k+2)*.2;return v;},g:9,size:(u,k)=>.03+.02*rnd(k),op:u=>.9*(1-u*.5),c:()=>'#e8f6ff',tx:TX.drop,add:false});}
    bm.end();
    // the Pip clinging to the branch is struck, loses its grip, flails and drops, lands, shakes and climbs back
    const b=s-T0,gz=b>0?Math.min(1.03,4.2*b*b):0,land=T0+Math.sqrt(1.03/4.2),L0=s>land,ret=s2(s,2.75,3.35);
    if(b>0&&b<.5)fx.hit(V(1.76,1.3,.02),b,{n:6,r:.35,c:'#e8f6ff',c2:'#9fd8ff'});
    let dy=-gz+(L0?.07*Math.abs(Math.sin((s-land)*10))*Math.exp(-(s-land)*4):0);dy=dy*(1-ret)+.3*Math.sin(Math.PI*ret);
    const dx=.5*eo(rp(b,0,.9))*(1-ret);
    d.set(s,{dx,dy,fy:1.03+(b>0?-gz:0)*1+(ret>0?0:0),roll:(b>0?-3.0*s2(b,0,.6)*(1-s2(s,land+.1,land+.35)):0),pitch:.35*Math.exp(-Math.max(0,b)*5)*(b>0?1:0),na:b>0?-.4*Math.exp(-b*4):0,jaw:b>0&&b<1?.4:0,ear:.9*s2(s,T0,T0+.05)*(1-s2(s,2.7,3.1)),sq:.12*Math.exp(-Math.max(0,b)*10)*(b>0?1:0)+.15*Math.exp(-Math.max(0,s-land)*12)*(L0?1:0),
      limp:b>0?s2(b,0,.15)*(1-s2(s,land+.1,land+.5)):0,lt:s,stars:s2(s,land+.1,land+.3)*(1-s2(s,2.6,2.9))});
    if(L0&&s-land<.6){const u=(s-land)/.6;for(let k=0;k<5;k++){const az=k*1.3;fx.p(V(2.15+Math.cos(az)*.5*eo(u),.1+.1*u,Math.sin(az)*.35*eo(u)),.2+.2*u,.4*(1-u),'#c9b48a',TX.puff,false,k);}}
    return .25*Math.exp(-Math.pow((s-T0)/.05,2));}};
};

})();
