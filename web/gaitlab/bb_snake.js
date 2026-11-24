'use strict';
// Body 4: SNAKE-LIKE serpentine body (A49): ring tube with a diamond pattern, a static ground coil (the planted part), a free rearing neck, wedge head with jaw and forked tongue,
// a flaring cobra hood (display organ) and a rattle at the tail.
// sing = hiss lunges + tail rattle bursts | dance = cobra sway with S-loops in the neck | charm = coil-and-nuzzle (neck bows forward, head tilts and nudges) | pose = hood flare.
(function(){
const BB=window.BB,T=BB.T,{V,clamp,sm,lerp,env,bump,bumps,qEul,lam,place,ell,limb,coneX,GEO,X,Y,Z,Tube,bez,bezPath}=BB;
const NN=26,NC=30,NT=14,NR=NN+NC+NT+1;
const COIL=(()=>{const o=[];for(let k=0;k<=NC;k++){const u=k/NC,th=Math.PI+u*3*Math.PI,r=.22-.075*u;o.push(V(r*Math.cos(th),.058+.15*u,r*Math.sin(th)));}return o;})();   // outer (back) -> top front
const NB=COIL[NC].clone(),EC=COIL[0].clone();
const BODY=[.43,.55,.24],DARK=[.2,.27,.1],BELLY=[.93,.88,.62];
const hash=(a,b)=>{const s=Math.sin(a*127.1+b*311.7)*43758.5453;return s-Math.floor(s);};
function skin(i,a,out,fl){
  const f=i/(NR-1),s=f*3.2,bel=sm((-Math.cos(a)-.2)/.45),dm=Math.abs(((s*6)%1)-.5)*2,cr=Math.abs(Math.sin(a))*.0+(1-Math.abs(Math.sin(a*.5+.0))),diam=sm((.62-Math.abs(((s*5.5)%1)-.5)*2-Math.abs(Math.sin(a))*.9)/.12)*(1-bel);
  const m=.03*hash(i,Math.round(a*3));let c=[BODY[0]+m,BODY[1]+m,BODY[2]+m*.5];
  c=[c[0]+(DARK[0]-c[0])*diam,c[1]+(DARK[1]-c[1])*diam,c[2]+(DARK[2]-c[2])*diam];
  c=[c[0]+(BELLY[0]-c[0])*bel,c[1]+(BELLY[1]-c[1])*bel,c[2]+(BELLY[2]-c[2])*bel];
  if(fl>0){c=[c[0]+(.9-c[0])*fl*.25,c[1]+(.55-c[1])*fl*.25,c[2]+(.2-c[2])*fl*.25];}
  out[0]=c[0];out[1]=c[1];out[2]=c[2];
}
function build(scene){
  const o={fx:BB.FXPool(scene),body:new Tube(NR,10)};scene.add(o.body.mesh);
  const head=o.head=new T.Group();scene.add(head);const hm=lam('#5a6f2a'),pale=lam('#e8dfaa');
  ell(head,hm,.085,.036,.052).position.set(.03,0,0);ell(head,pale,.07,.02,.045).position.set(.035,-.02,0);
  o.jaw=new T.Group();o.jaw.position.set(-.02,-.02,0);head.add(o.jaw);ell(o.jaw,pale,.075,.013,.04).position.set(.06,-.003,0);o.mouth=ell(o.jaw,lam('#7a1f26'),.06,.006,.03);o.mouth.position.set(.06,.008,0);
  for(const s of [-1,1]){const e=ell(head,lam('#f2d36a'),.015,.015,.013);e.position.set(.05,.018,s*.042);const p=ell(head,lam('#0b0b0b'),.006,.014,.006);p.position.set(.055,.018,s*.053);}
  o.tongue=new T.Group();o.tongue.position.set(.11,-.005,0);head.add(o.tongue);const tm=lam('#d83a4a');
  const t0=new T.Mesh(new T.CylinderGeometry(.004,.004,1,5),tm);t0.rotation.z=Math.PI/2;t0.position.x=.5;o.tongue.add(t0);
  for(const s of [-1,1]){const f=new T.Mesh(new T.CylinderGeometry(.003,.002,.35,5),tm);f.position.set(1.07,0,s*.02);f.rotation.z=Math.PI/2;f.rotation.x=s*.5;o.tongue.add(f);}
  // hood: a round flap (a disc with a spectacle mark), flat, facing forward
  const hg=new T.CircleGeometry(1,32),pc=hg.attributes.position,cols=new Float32Array(pc.count*3);
  for(let i=0;i<pc.count;i++){const r=Math.hypot(pc.getX(i),pc.getY(i)),y=pc.getY(i);const c=r<.7?[.88,.78,.42]:[.5-.1*(r-.7),.42-.1*(r-.7),.2];const ring=Math.abs(r-.85)<.06?.55:1;cols[i*3]=c[0]*ring;cols[i*3+1]=c[1]*ring;cols[i*3+2]=c[2]*ring;}
  hg.setAttribute('color',new T.BufferAttribute(cols,3));o.hood=new T.Mesh(hg,new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide}));scene.add(o.hood);
  o.spec=new T.Mesh(new T.RingGeometry(.2,.3,20),new T.MeshBasicMaterial({color:'#2a1f0d',side:T.DoubleSide}));o.spec.position.set(0,-.12,.01);o.hood.add(o.spec);
  const sp2=new T.Mesh(new T.CircleGeometry(.12,16),new T.MeshBasicMaterial({color:'#2a1f0d',side:T.DoubleSide}));sp2.position.set(0,-.12,.012);o.hood.add(sp2);
  o.rat=[0,1,2,3,4].map(k=>{const m=ell(scene,lam(k%2?'#d4c7a0':'#b8aa80'),.03-.002*k,.02,.022);return m;});
  const sf=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshBasicMaterial({map:BB.TEX.blob,transparent:true,depthWrite:false}));sf.rotation.x=-Math.PI/2;sf.position.y=.003;scene.add(sf);o.shadow=sf;
  return o;
}
function pose(act,g){
  const G=BB.GAME[act],W=G.W,ts=W+G.A,tb=W;
  const Q={hx:.14,hy:.5,hz:0,hpitch:-.3,hyaw:0,hroll:0,gape:0,tongue:0,flare:0,raise:0,shake:0,puff:0,ctrl:{l1:0,l2:0,x1:0,x2:0,up:.26},jets:[],fl:0};
  Q.hy=.5+.012*Math.sin(g/600);Q.hz=.012*Math.sin(g/900);Q.tongue=Math.max(0,Math.sin(g/410))>.9?.7:0;
  let obs=0;
  if(act==='sing'){
    const e=env(g,-300,ts+400,450,500),n=bumps(g,W,3,300,60);let br=0;for(let k=0;k<3;k++)br=Math.max(br,env(g,W+300*k,W+300*k+240,25,60));
    Q.raise=e;Q.shake=br;Q.hx=.14+.0*e+.16*n;Q.hy=lerp(.5,.42,e)-.02*n;Q.hpitch=-.2-.25*e;Q.gape=.9*n;Q.tongue=.9*n;Q.puff=.35*e+.65*n;Q.ctrl.x1=-.12*e;Q.ctrl.x2=.04*e;Q.jets=[W,W+300,W+600];Q.fl=.4*n;
    obs=Q.hx;
  }else if(act==='dance'){
    const e=env(g,-500,W+300*4+400,420,500),th=2*Math.PI*(g-tb)/600,c=Math.cos(th),s=Math.sin(th);
    Q.hx=.1+.04*Math.cos(2*th);Q.hy=lerp(.5,.66,e)+.05*e*Math.cos(2*th);Q.hz=.24*c*e;Q.hyaw=-.55*s*e;Q.hpitch=-.15;Q.hroll=.25*c*e;Q.tongue=.4*e*Math.max(0,s);
    Q.ctrl.l1=.14*Math.cos(th-1.1)*e;Q.ctrl.l2=-.12*Math.cos(th+.6)*e;Q.ctrl.x1=-.1*e*s;Q.ctrl.x2=.1*e*s;Q.raise=.1*e;Q.shake=0;Q.fl=.2*e;
    obs=Q.hz;
  }else if(act==='charm'){
    const r=sm((g+440)/600),back=sm((g-ts-1300)/900),q=r*(1-back),nod=Math.sin(2*Math.PI*(g-W)/600)*sm((g-W)/200)*(1-back);
    Q.hx=lerp(.14,.62,q)+.025*nod*q;Q.hy=lerp(.5,.17,q)+.02*nod*q;Q.hz=.05*Math.sin(2*Math.PI*(g-W)/1200)*q;Q.hpitch=lerp(-.3,-.55,q)+.12*nod*q;Q.hroll=.4*q;Q.hyaw=-.1*q;Q.tongue=.6*q*Math.max(0,Math.sin(g/230));Q.ctrl.up=lerp(.26,.34,q);Q.ctrl.x1=.12*q;Q.fl=.3*q;Q.raise=.15*q;
    obs=r;
  }else{
    const f=sm((g+226)/700),back=sm((g-ts-1800)/800),s_=f*(1-back),sh=Math.max(bump(g,tb+300,90),bump(g,tb+600,90),bump(g,tb+900,90))*f;
    Q.hx=lerp(.14,.14,s_);Q.hy=lerp(.5,.68,s_)+.004*Math.sin(g/300);Q.hz=.03*Math.sin(g/700)*s_;Q.hpitch=lerp(-.3,-.12,s_);Q.flare=s_+.05*sh;Q.tongue=.9*sh+Q.tongue*(1-sh);Q.raise=.2*s_;Q.fl=.35*s_;Q.ctrl.up=.32;Q.puff=.2*s_;
    obs=f;
  }
  return fin(Q,act,g,obs);
}
function fin(Q,act,g,obs){
  const S={Q,act,g,obs,nodes:[],anchors:[],arcs:[],legErr:0,jets:Q.jets};
  const Hd=V(1,0,0).applyQuaternion(qEul(Q.hyaw,Q.hpitch,0)),H=V(Q.hx,Q.hy,Q.hz),Hn=H.clone().addScaledVector(Hd,-.05);S.Hd=Hd;
  const p1=NB.clone().add(V(Q.ctrl.x1+.03,Q.ctrl.up,Q.ctrl.l1)),p2=Hn.clone().addScaledVector(Hd,-.3).add(V(Q.ctrl.x2,0,Q.ctrl.l2));
  const neck=bezPath(NB,p1,p2,Hn,NN);               // base -> head
  // tail
  const TT=V(-.5-.02*Q.raise,.03+.3*Q.raise,.0),tp1=EC.clone().add(V(-.14,.0,-.02)),tp2=TT.clone().add(V(.02*Q.raise,-.14*Q.raise-.02,.0));
  const tail=bezPath(EC,tp1,tp2,TT,NT);
  // vibrate the raised tail tip: lateral shake on the last third (burst envelope)
  for(let i=0;i<=NT;i++){const u=i/NT;tail[i].z+=Q.shake*.035*u*u*Math.sin(g*.14+u*3);}
  const pts=neck.slice().reverse().concat(COIL.slice().reverse().slice(1),tail.slice(1));        // head -> tail
  const rad=pts.map((p,i)=>{const f=i/(pts.length-1);let r;if(i<=NN){const u=i/NN;r=.034+.018*sm(u*1.4)}else if(i<=NN+NC)r=.052;else{const u=(i-NN-NC)/NT;r=.052*Math.pow(1-u,.8)+.012;}
    if(i<NN*.45)r*=1+Q.puff*.5*Math.sin(Math.PI*Math.min(1,(i/(NN*.45))))*1;return r;});
  rad[0]=.03;
  pts.forEach((p,i)=>{if(p.y<rad[i]+.003)p.y=rad[i]+.003;S.nodes.push({p,r:rad[i]});});
  S.pts=pts;S.rad=rad;
  // ground contact anchors: points of the coil that touch the rock
  for(const k of [1,4,8,11])S.anchors.push({id:'coil'+k,p:COIL[k].clone(),on:true});
  S.head=H;S.hn=Hn;S.nodes.push({p:H,r:.04});
  // hood centre on the neck ~0.12 m behind the head
  const hi=Math.round(2+Q.flare*0),hp=pts[7].clone(),hn=pts[5].clone().sub(pts[9]).normalize();
  S.hoodC=pts[10].clone();S.hoodT=pts[5].clone().sub(pts[11]).normalize();
  S.rat=[0,1,2,3,4].map(k=>{const u=NT-.5-k*.0,tp=tail[NT],dirv=tail[NT].clone().sub(tail[NT-2]).normalize();return tp.clone().addScaledVector(dirv,.022*(k+.6));});
  S.ratV=Q.shake;
  return S;
}
function draw(o,S,act,g){
  const Q=S.Q;
  o.body.update(S.pts,S.rad,(i,a,out)=>skin(i,a,out,Q.fl),Y);
  o.head.position.copy(S.head);o.head.quaternion.copy(qEul(Q.hyaw,Q.hpitch,Q.hroll));
  o.jaw.rotation.z=-Q.gape*.7;o.mouth.visible=Q.gape>.1;o.mouth.scale.set(.06,.006+.02*Q.gape,.03);
  o.tongue.visible=Q.tongue>.05;if(o.tongue.visible){const l=.07+.1*Q.tongue;o.tongue.scale.set(l,1,1);o.tongue.rotation.z=.2*Math.sin(g*.05);}
  const f=Q.flare;o.hood.visible=f>.04;
  if(o.hood.visible){const t=S.hoodT.clone().normalize(),L=V(0,0,1).addScaledVector(t,-t.z).normalize(),n=new T.Vector3().crossVectors(L,t);
    o.hood.position.copy(S.hoodC);o.hood.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(L.clone().negate(),t,n.negate()));
    o.hood.scale.set(.035+.24*f,.05+.17*f,1);o.spec.visible=f>.3;}
  o.rat.forEach((m,k)=>{m.position.copy(S.rat[k]);m.rotation.set(0,0,0);m.rotation.z=Q.shake*.5*Math.sin(g*.14+k);m.position.z+=Q.shake*.01*Math.sin(g*.16+k*1.3);});
  o.shadow.position.set(0,.003,0);o.shadow.scale.set(1.1,.9,1);o.shadow.material.opacity=.7;
  const fx=o.fx;fx.reset();const mouth=S.head.clone().addScaledVector(S.Hd,.14);
  for(const t of S.jets){for(let j=0;j<4;j++){const ph=(g-t-j*40)/650;if(ph>0&&ph<1)fx.dot(mouth.clone().addScaledVector(S.Hd,.35*Math.pow(ph,.7)).add(V(0,.1*ph+.02*j*ph,(j-1.5)*.05*ph)),.025+.06*ph,.55*Math.sin(Math.PI*Math.min(1,ph*1.1))*(1-ph*.3),'#f2f2f0');}
    const ph2=(g-t)/700;if(ph2>0&&ph2<1)fx.arc(mouth.clone().addScaledVector(S.Hd,.03),qEul(Q.hyaw,Q.hpitch,0),.08+.4*Math.pow(ph2,.75),.5*Math.sin(Math.PI*Math.min(1,ph2*1.1))*(1-ph2*.4),'#ffffff');}
  if(act==='sing')BB.noteBurst(fx,S.jets,g,mouth.clone().addScaledVector(S.Hd,.03),'#8fb04a',BB.rigs.snake.height);
  fx.flush();
}
const ACTS={
 sing:{id:'hiss-rattle',name:'Hiss + tail rattle',tag:'the neck lunges and hisses on each of three beats (white breath, open jaw), the raised tail rattles in bursts, body puffs',organ:'throat + tail rattle',tier:2,mode:'max'},
 dance:{id:'sway-loops',name:'Cobra sway with S-loops',tag:'the reared neck swings side to side in S-loops, head turning with the sway, rising on every beat; the coil stays planted',organ:'long serpentine body',tier:3,mode:'max'},
 charm:{id:'coil-nuzzle',name:'Coil and nuzzle',tag:'the body stays coiled, the neck bows forward low and the head tilts and nudges gently with tongue flicks',organ:'coiling body',tier:2,mode:'arrive'},
 pose:{id:'hood-flare',name:'Hood flare',tag:'neck rears tall and a wide hood fans open with a pale spectacle mark, held with shimmer flicks on the beat',organ:'hood (display organ, frill)',tier:2,mode:'arrive'}};
BB.rigs.snake={id:'snake',label:'Snake-like',TD:2.2,cam:{h:1.4,cx:.75,ty:.42},height:.7,tbow:-0.55,build,pose,draw,acts:ACTS};
})();
