'use strict';
// Primigenia acid-spit lab core (A60/A62): starter B (no arms, beak "pico", small spit gland in the throat). Pure maths, no DOM.
// Needs bite2_core.js and pounce_core.js first (body rig, IK, skeleton). Units: metres, +x forward, +y up, +z creature's right. Times in ms of ANIMATION time.
// Game numbers (core/src/combat.c, 10 Hz): spit = 6 ticks wind-up (0.6 s), 1 active, 4 recovery, range 6.0 m, status SLOW for 20 ticks (2.0 s), role poke, flag RANGED.
// Every projectile is an analytic ballistic particle (p0 + v t + g t^2 / 2): the renderer and the self-check read the same function.
(function(root){
const PC=root.POUNCECORE,B=root.BITECORE,T=PC.T,REST=PC.REST,V=B.V,interp=B.interp,skel=PC.skel,poseAt=PC.poseAt,FOOT_REST=PC.FOOT_REST;
const G=9.81,RH=.52,CY=.34,FY=.03;                      // gravity, prey hitbox radius and centre height
const clamp=(x,a,b)=>x<a?a:x>b?b:x,sm=u=>{u=clamp(u,0,1);return u*u*(3-2*u);};
function rng(seed){let s=seed>>>0;return()=>{s=(s+0x6D2B79F5)>>>0;let t=s;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
// ---------------------------------------------------------------- feet (all planted; a stance change is one swing)
function feetOf(end,steps){
  return [0,1,2,3].map(i=>{let t=0,cur=[FOOT_REST[i][0],FOOT_REST[i][1]];const segs=[];
    const hold=t1=>{if(t1>t){segs.push({k:'p',t0:t,t1,x:cur[0],z:cur[1]});t=t1;}};
    for(const s of steps.filter(q=>q.i===i)){hold(s.t0);const nx=cur[0]+s.dx,nz=cur[1]+s.dz;segs.push({k:'s',t0:s.t0,t1:s.t1,x0:cur[0],z0:cur[1],x1:nx,z1:nz,h:.03});cur=[nx,nz];t=s.t1;}
    hold(end);return segs;});
}
const stance=(t0,t1,dz,dx)=>[0,1,2,3].map(i=>({i,t0:t0+i*14,t1:t1+i*14,dx:dx||0,dz:dz*(FOOT_REST[i][1]<0?-1:1)}));
// ---------------------------------------------------------------- mouth
function mouthAt(ver,a){const sk=skel(ver,poseAt(ver,a),false);return {m:sk.tip.clone().addScaledVector(sk.axis,-.035),axis:sk.axis.clone(),sk};}
// neck polyline shoulder(5) -> elbow(6) -> head(7): point at arc fraction s
function neckPoint(sk,s){const a=sk.nodes[5],b=sk.nodes[6],c=sk.nodes[7],l1=a.distanceTo(b),l2=b.distanceTo(c),d=s*(l1+l2);
  return d<=l1?a.clone().lerp(b,d/l1):b.clone().lerp(c,(d-l1)/l2);}
// throat / cheeks / glow state of the spit gland at animation time a
function glandAt(ver,a){
  const g={pulses:[],cheek:ver.ch.cheek?interp(ver.ch.cheek,a):0,throat:ver.ch.throat?interp(ver.ch.throat,a):0,glow:ver.ch.glow?interp(ver.ch.glow,a):0,mg:ver.ch.mg?interp(ver.ch.mg,a):0,shake:ver.ch.shake?interp(ver.ch.shake,a):0};
  for(const p of ver.pulses){if(a<p.t0||a>p.t1)continue;const u=(a-p.t0)/(p.t1-p.t0);g.pulses.push({s:p.s0+(p.s1-p.s0)*sm(u),amp:p.size*Math.pow(Math.sin(Math.PI*u),.7)});}
  return g;
}
// ---------------------------------------------------------------- ballistics
function posAt(p,a){const tau=(a-p.t0)/1000;return [p.p0[0]+p.v[0]*tau,p.p0[1]+p.v[1]*tau-.5*G*tau*tau,p.p0[2]+p.v[2]*tau];}
function simulate(p,c0,hit,life){ // fills p.end (ms), p.ex (end position), p.endk ('hit'|'ground'|'life')
  const C=[c0[0],CY,c0[2]||0];let prevIn=false;p.endk='life';
  for(let ms=0;ms<=life;ms++){const a=p.t0+ms,q=posAt(p,a),d=Math.hypot(q[0]-C[0],q[1]-C[1],q[2]-C[2]);
    if(hit&&d<RH&&!prevIn&&ms>0){let lo=a-1,hi=a;for(let i=0;i<10;i++){const mid=(lo+hi)/2,qm=posAt(p,mid);if(Math.hypot(qm[0]-C[0],qm[1]-C[1],qm[2]-C[2])<RH)hi=mid;else lo=mid;}p.end=hi;p.ex=posAt(p,hi);p.endk='hit';return p;}
    if(q[1]<=.012&&ms>8){p.end=a;p.ex=[q[0],.012,q[2]];p.endk='ground';return p;}
    prevIn=d<RH;}
  p.end=p.t0+life;p.ex=posAt(p,p.end);return p;
}
// velocity that leaves m at t0 and arrives at A after `tof` seconds
function toArrive(m,A,tof){return [(A[0]-m.x)/tof,(A[1]-m.y+.5*G*tof*tof)/tof,(A[2]-m.z)/tof];}
// velocity of speed `sp` from m through A (low solution)
function toSpeed(m,A,sp){const dx=Math.hypot(A[0]-m.x,A[2]-m.z),h=A[1]-m.y,v2=sp*sp,disc=v2*v2-G*(G*dx*dx+2*h*v2),th=Math.atan((v2-Math.sqrt(Math.max(0,disc)))/(G*dx)),ang=Math.atan2(A[2]-m.z,A[0]-m.x);
  return [sp*Math.cos(th)*Math.cos(ang),sp*Math.sin(th),sp*Math.cos(th)*Math.sin(ang)];}
// ---------------------------------------------------------------- the four versions
const SPECS=[
// ---------------------------------------------------------------- 1 cobra-style aimed jet
{id:'jet',name:'Aimed jet (cobra)',D:5.5,tr:700,pause:0,
 tag:'neck rises and pulls back, the throat pulses twice, mouth opens, a fast thin stream arcs to the target',
 aimAt:c0=>[c0[0]-.36,CY+.1,0],
 make(env){const tr=700,hpA=env.hpA;
  const ch={
   sp:[[0,0],[300,-.22,'o'],[tr,-.22],[tr+60,-.26,'o'],[1050,-.2,'s'],[1550,0,'s']],
   pitch:[[0,0],[300,-.03,'s'],[1050,-.03],[1550,0,'s']],
   bx:[[0,0],[300,-.03,'o'],[tr,-.03],[tr+90,-.05,'o'],[1100,-.03,'s'],[1550,0,'s']],
   by:[[0,0],[300,-.05,'s'],[tr,-.05],[tr+90,-.07,'o'],[1100,-.04,'s'],[1550,0,'s']],
   hd:[[0,[0,0,0]],[300,[-.15,.16,0],'o'],[tr-40,[-.17,.17,0],'s'],[tr+50,[-.05,.12,0],'o'],[1050,[-.07,.10,0],'s'],[1550,[0,0,0],'s']],
   hp:[[0,0],[300,.25,'o'],[tr-30,.25],[tr,hpA,'o'],[1000,hpA,'s'],[1550,0,'s']],
   gape:[[0,0],[560,0],[650,1,'o'],[tr+260,1],[tr+430,0,'s']],
   mg:[[0,0],[600,0],[tr,1,'o'],[tr+260,.7],[tr+430,0,'s']],
   tailP:[[0,0],[300,.15,'s'],[tr+80,.28,'o'],[1550,0,'s']],
   throat:[[0,0]],cheek:[[0,0]],glow:[[0,0],[300,.5,'s'],[tr,.8],[tr+430,0,'s']]
  };
  const pulses=[{t0:300,t1:490,s0:.08,s1:.97,size:1},{t0:470,t1:660,s0:.08,s1:.97,size:1.2}];
  return {ch,pulses,segs:feetOf(1550,[]),tr,end:1550,
   pre:[['rise',0,300],['pulse 1',300,480],['pulse 2',480,tr]],flight:'jet',tshot:tr,
   prey:{amp:.018,rec:.0016,hop:0,tilt:.5,stag:.5},
   shake:.012,splash:{every:5,n:2,sp:[1.2,2.4],r:[.008,.013]},specks:{every:9,r:[.02,.04]},
   puddle:null,flash:.18,bubbles:7,tint:.62};},
 shots(ver,mouth,rnd){const out=[],A=this.aimAt(ver.c0);for(let k=0;k<41;k++){const te=ver.tr+k*5,mp=mouthAt(ver,te).m;
   out.push({k:'jet',idx:k,n:41,t0:te,p0:[mp.x,mp.y,mp.z],v:toSpeed(mp,A,26),r:.03,life:900,hit:true});}return out;}},
// ---------------------------------------------------------------- 2 llama-style lob
{id:'lob',name:'Lob (llama)',D:5.5,tr:640,pause:60,
 tag:'head tilts back, cheeks and throat swell, one gob lobbed in a high arc, splat with a small splash',
 aimAt:c0=>[c0[0]-.36,CY+.12,0],tof:1.15,
 make(env){const tr=640,hpA=env.hpA;
  const ch={
   sp:[[0,0],[420,-.18,'s'],[tr-40,-.15,'s'],[tr+40,-.02,'o'],[1000,-.02,'s'],[1500,0,'s']],
   pitch:[[0,0],[420,-.07,'s'],[tr-40,-.07],[tr+40,.04,'o'],[1000,0,'s']],
   bx:[[0,0],[420,-.06,'o'],[tr-40,-.07],[tr+40,.04,'o'],[tr+260,-.01,'s'],[1500,0,'s']],
   by:[[0,0],[420,-.03,'s'],[tr+40,-.05,'o'],[tr+300,0,'s']],
   hd:[[0,[0,0,0]],[430,[-.17,.12,0],'o'],[tr-50,[-.19,.10,0],'s'],[tr+30,[.06,.06,0],'o'],[tr+300,[0,.03,0],'s'],[1500,[0,0,0],'s']],
   hp:[[0,0],[430,-1.15,'o'],[tr-40,-1.2,'s'],[tr,hpA,'o'],[tr+380,hpA*.45,'s'],[1500,0,'s']],
   gape:[[0,0],[tr-110,0],[tr-40,.8,'o'],[tr+170,.8],[tr+330,0,'s']],
   mg:[[0,0],[tr-140,0],[tr-20,1],[tr+40,.6,'o'],[tr+240,0,'s']],
   tailP:[[0,0],[420,-.15,'s'],[tr+40,.25,'o'],[1500,0,'s']],
   cheek:[[0,0],[200,.25,'s'],[tr-40,1,'s'],[tr+30,.9],[tr+280,0,'s']],
   throat:[[0,0],[250,.15,'s'],[tr-40,1,'s'],[tr+40,.45,'o'],[tr+260,0,'s']],
   glow:[[0,0],[300,.35,'s'],[tr,.8],[tr+400,0,'s']]
  };
  const pulses=[{t0:200,t1:380,s0:.15,s1:.9,size:.8}];
  return {ch,pulses,segs:feetOf(1500,[]),tr,end:1500,
   pre:[['tilt back',0,430],['swell',430,tr-40],['lob',tr-40,tr+40]],flight:'flight',tshot:tr,
   prey:{amp:.12,rec:.12,hop:.05,tilt:.4,stag:.9},
   shake:.03,splash:{every:1,n:16,sp:[1.2,3.6],r:[.012,.026]},specks:{every:1,r:[.05,.09],extra:3},
   puddle:null,flash:.4,bubbles:11,tint:.85};},
 shots(ver){const mp=mouthAt(ver,ver.tr).m,A=this.aimAt(ver.c0);return [{k:'gob',idx:0,n:1,t0:ver.tr,p0:[mp.x,mp.y,mp.z],v:toArrive(mp,A,this.tof),r:.09,life:2400,hit:true}];}},
// ---------------------------------------------------------------- 3 spray burst
{id:'spray',name:'Spray burst',D:3.7,tr:520,pause:0,
 tag:'cheeks puff, mouth half open, a short cone of droplets (3 to 4 m) while the head sweeps side to side: area poke',
 make(env){const tr=520;
  const sw=(t0,t1,amp,per)=>{const o=[];for(let t=t0;t<=t1;t+=15)o.push([t,amp*Math.sin(2*Math.PI*(t-t0)/per)*sm((t-t0)/80)*(1-sm((t-t1+120)/120)),'l']);return o;};
  const ch={
   sp:[[0,0],[480,-.12,'o'],[tr+620,-.12],[1000,-.02,'s'],[1500,0,'s']],
   pitch:[[0,0],[480,.03,'s'],[1500,0,'s']],
   bx:[[0,0],[480,-.05,'o'],[tr+620,-.05],[1000,-.03,'s'],[1500,0,'s']],
   by:[[0,0],[480,-.06,'o'],[1000,-.04,'s'],[1500,0,'s']],
   hd:[[0,[0,0,0]],[400,[-.1,.05,0],'o'],[tr+620,[-.09,.05,0],'s'],[1000,[-.03,.03,0],'s'],[1550,[0,0,0],'s']],
   hp:[[0,0],[400,.1,'o'],[tr+640,.1],[1100,0,'s']],
   hyaw:sw(tr,tr+640,.24,600),
   yaw:sw(tr,tr+640,.05,600),
   hroll:sw(tr,tr+640,-.12,540),
   gape:[[0,0],[300,0],[470,.7,'o'],[tr+640,.7],[tr+760,0,'s']],
   mg:[[0,0],[400,0],[tr,1],[tr+640,.9],[tr+780,0,'s']],
   tailP:[[0,0],[480,.1,'s'],[1500,0,'s']],
   cheek:[[0,0],[100,.2,'s'],[460,1,'s'],[tr+300,.8],[tr+640,.25,'s'],[tr+800,0,'s']],
   throat:[[0,0],[200,.2],[460,.9,'s'],[tr+640,.5],[tr+800,0,'s']],
   glow:[[0,0],[300,.4,'s'],[tr,.8],[tr+640,.6],[tr+800,0,'s']]
  };
  const pulses=[{t0:150,t1:300,s0:.15,s1:.95,size:.7},{t0:280,t1:430,s0:.15,s1:.95,size:.8},{t0:tr+80,t1:tr+200,s0:.2,s1:.95,size:.7},{t0:tr+240,t1:tr+360,s0:.2,s1:.95,size:.7},{t0:tr+400,t1:tr+520,s0:.2,s1:.95,size:.7}];
  return {ch,pulses,segs:feetOf(1550,stance(300,470,.02)),tr,end:1550,
   pre:[['draw back',0,tr],['spray',tr,tr+640]],flight:null,tshot:tr,
   prey:{amp:.02,rec:.003,hop:0,tilt:.3,stag:.45},
   shake:0,splash:{every:10,n:1,sp:[.6,1.4],r:[.006,.01]},specks:{every:6,r:[.015,.03]},
   puddle:null,flash:.0,bubbles:10,tint:.5,spotty:true};},
 shots(ver,mouth,rnd){const out=[];let n=0;
  for(let te=ver.tr;te<ver.tr+640;te+=8)for(let j=0;j<3;j++){const ma=mouthAt(ver,te),ax=ma.axis,m=ma.m;
    const ang=Math.acos(1-rnd()*(1-Math.cos(.17))),phi=rnd()*2*Math.PI,up=new T.Vector3(0,1,0),side=new T.Vector3().crossVectors(ax,up).normalize(),up2=new T.Vector3().crossVectors(side,ax);
    const d=ax.clone().multiplyScalar(Math.cos(ang)).addScaledVector(side,Math.sin(ang)*Math.cos(phi)).addScaledVector(up2,Math.sin(ang)*Math.sin(phi)),sp=7.6+rnd()*3.4;
    out.push({k:'drop',idx:n++,n:0,t0:te+Math.floor(rnd()*7),p0:[m.x,m.y,m.z],v:[d.x*sp,d.y*sp,d.z*sp],r:.012+rnd()*.012,life:1300,hit:true,spray:true});}
  return out;}},
// ---------------------------------------------------------------- 4 charged glob
{id:'glob',name:'Charged glob',D:5.5,tr:1150,pause:100,
 tag:'long wind-up (throat glows, body braced), a big slow glob that hits hard and leaves a small acid puddle',
 aimAt:c0=>[c0[0]-.36,CY+.1,0],tof:.85,
 make(env){const tr=1150,hpA=env.hpA,sh=[];for(let t=300;t<tr;t+=20)sh.push([t,.012*Math.sin(t/17)*(.4+.6*sm((t-300)/700)),'l']);
  const ch={
   sp:[[0,0],[280,-.10,'o'],[tr,-.22,'s'],[tr+60,.02,'i2'],[tr+230,-.04,'o'],[1700,0,'s']],
   pitch:[[0,0],[280,.06,'o'],[tr,-.08,'s'],[tr+60,.08,'o'],[tr+300,0,'s'],[1700,0,'s']],
   bx:[[0,0],[280,-.04,'o'],[tr,-.06,'s'],[tr+70,-.20,'o'],[tr+380,-.10,'s'],[1700,0,'s']],
   by:[[0,0],[280,-.17,'o'],[tr,-.19,'s'],[tr+60,-.1,'o'],[tr+350,-.06,'s'],[1700,0,'s']],
   hd:[[0,[0,0,0]],[300,[-.07,-.06,0],'o'],[tr-120,[-.16,.0,0],'s'],[tr+20,[-.2,.08,0],'s'],[tr+80,[.07,.05,0],'o'],[tr+400,[0,.02,0],'s'],[1700,[0,0,0],'s']],
   hp:[[0,0],[300,.35,'o'],[tr-120,.5,'s'],[tr+10,-.55,'o2'],[tr+60,hpA,'o'],[tr+420,hpA*.4,'s'],[1700,0,'s']],
   bz:sh.concat([[tr,0,'l']]),
   gape:[[0,0],[tr-220,0],[tr-120,.55,'s'],[tr-10,.7],[tr+30,1,'o'],[tr+320,1],[tr+520,0,'s']],
   mg:[[0,0],[500,0],[tr,1,'s'],[tr+300,.5],[tr+560,0,'s']],
   tailP:[[0,0],[tr-200,.25,'s'],[tr+60,.5,'o'],[1700,0,'s']],
   cheek:[[0,0],[500,.15,'s'],[tr-100,.9,'s'],[tr+50,.9],[tr+320,0,'s']],
   throat:[[0,0],[300,.25,'s'],[tr-60,1.2,'s'],[tr+80,.5,'o'],[tr+350,0,'s']],
   glow:[[0,0],[300,.2,'s'],[tr-60,1,'s'],[tr+200,.7],[tr+560,0,'s']]
  };
  const pulses=[{t0:380,t1:640,s0:.12,s1:.9,size:.7},{t0:700,t1:950,s0:.12,s1:.9,size:.9}];
  return {ch,pulses,segs:feetOf(1700,stance(120,300,.05,.03)),tr,end:1700,
   pre:[['brace',0,300],['charge',300,tr],['release',tr,tr+60]],flight:'flight',tshot:tr+60,
   prey:{amp:.2,rec:.3,hop:.1,tilt:.6,stag:1.2},
   shake:.055,splash:{every:1,n:26,sp:[1.5,4.6],r:[.014,.032]},specks:{every:1,r:[.08,.14],extra:4},
   puddle:{r:.42,hold:1500,life:2500,dx:-.66},flash:.55,bubbles:16,tint:1,bigGlow:true};},
 shots(ver){const mp=mouthAt(ver,ver.tshot).m,A=this.aimAt(ver.c0);return [{k:'gob',idx:0,n:1,t0:ver.tshot,p0:[mp.x,mp.y,mp.z],v:toArrive(mp,A,this.tof),r:.17,life:2400,hit:true,big:true}];}}
];
// ---------------------------------------------------------------- build
function finish(v,spec,env){v.id=spec.id;v.name=spec.name;v.tag=spec.tag;v.D=spec.D;v.c0=[REST.P0[0]+spec.D,CY,0];v.arcs=[];v.pause=spec.pause;return v;}
function elev(d){return Math.atan2(d.y,Math.hypot(d.x,d.z));}
function build(spec){
  const mk=hpA=>finish(spec.make({hpA}),spec);
  let v=mk(-.2);
  if(spec.aimAt){ // solve the head pitch at release so the mouth axis points along the launch velocity
    for(let pass=0;pass<3;pass++){
      const t0=v.tshot,launch=spec.shots(v)[0],vel=new T.Vector3(...launch.v),target=elev(vel);
      let lo=-1.6,hi=1.0;for(let i=0;i<22;i++){const mid=(lo+hi)/2,w=mk(mid),m=mouthAt(w,t0);if(elev(m.axis)>target)lo=mid;else hi=mid;}
      v=mk((lo+hi)/2);v.hpA=(lo+hi)/2;
    }
  }
  const rnd=rng(spec.id.charCodeAt(0)*977+13);
  let ps=spec.shots(v,null,rnd);
  ps.forEach(p=>simulate(p,v.c0,true,p.life));
  const hits=ps.filter(p=>p.endk==='hit').sort((a,b)=>a.end-b.end);
  if(!hits.length)throw Error(spec.id+': no projectile reaches the hitbox');
  v.tc=Math.round(hits[0].end);v.hitTimes=hits.map(p=>p.end);v.hitPts=hits.map(p=>p.ex);
  v.hits=[{tc:v.tc,pause:v.pause,contact:V(...hits[0].ex)}];v.contact=v.hits[0].contact;
  // impact effects, all particles of the same kind: splash droplets, drips, specks stuck on the prey
  const sp=v.splash,rn=rng(spec.id.charCodeAt(1)*131+7),extra=[];
  hits.forEach((h,i)=>{if(i%sp.every!==0)return;const nrm=new T.Vector3(h.ex[0]-v.c0[0],h.ex[1]-CY,h.ex[2]).normalize();
    for(let k=0;k<sp.n;k++){const ang=rn()*Math.PI*2,sp0=sp.sp[0]+rn()*(sp.sp[1]-sp.sp[0]),spread=new T.Vector3(Math.cos(ang)*.0,Math.sin(ang),Math.cos(ang)).normalize(),
        d=nrm.clone().multiplyScalar(.65).add(new T.Vector3(0,.55,0)).addScaledVector(new T.Vector3(0,Math.sin(ang),Math.cos(ang)),.9).normalize();
      extra.push({k:'drop',t0:h.end+Math.floor(rn()*24),p0:[h.ex[0]+nrm.x*.012,h.ex[1]+nrm.y*.012,h.ex[2]+nrm.z*.012],v:[d.x*sp0,d.y*sp0,d.z*sp0],r:sp.r[0]+rn()*(sp.r[1]-sp.r[0]),life:1100,hit:false,splash:true});}});
  const spk=v.specks;v.specks=[];
  hits.forEach((h,i)=>{if(i%spk.every!==0)return;const a=Math.atan2(h.ex[2],h.ex[0]-v.c0[0]);v.specks.push({t:h.end,w:h.ex.slice(),r:spk.r[0]+rn()*(spk.r[1]-spk.r[0])});
    for(let k=0;k<(spk.extra||0);k++){const q=[h.ex[0]+(rn()-.5)*.2,h.ex[1]+(rn()-.35)*.18,h.ex[2]+(rn()-.5)*.18],d=Math.hypot(q[0]-v.c0[0],q[1]-CY,q[2]),s=RH/d;
      v.specks.push({t:h.end+Math.floor(rn()*60),w:[v.c0[0]+(q[0]-v.c0[0])*s,CY+(q[1]-CY)*s,q[2]*s],r:spk.r[0]*.45+rn()*spk.r[0]*.5});}});
  // drips from the prey's chin after the hit
  const drips=[];{const nd=Math.round(2+v.bubbles/4);for(let k=0;k<nd;k++){const t=v.tc+350+k*(900/nd)+rn()*120,S=preyAt(v,t);
    drips.push({k:'drop',t0:t,p0:[S.x-.4,S.y-.02,(rn()-.5)*.12],v:[0,0,0],r:.011+rn()*.008,life:900,hit:false,drip:true});}}
  ps=ps.concat(extra,drips);ps.forEach(p=>{if(p.end===undefined)simulate(p,v.c0,false,p.life);});
  ps.sort((a,b)=>a.t0-b.t0);v.ps=ps;
  v.jet=ps.filter(p=>p.k==='jet');v.gobs=ps.filter(p=>p.k==='gob');v.drops=ps.filter(p=>p.k==='drop');
  // timing: creature phases up to the release, flight to the hit, recovery, then the prey's slow status
  const cEnd=v.end;v.end=Math.max(cEnd,v.tc+2300);
  const ph=v.pre.slice();if(v.flight)ph.push([v.flight,ph[ph.length-1][2],v.tc]);
  let last=ph[ph.length-1][2];if(cEnd>last){ph.push(['recovery',last,cEnd]);last=cEnd;}
  ph.push(['prey slowed',last,v.end]);v.phl=ph;
  v.strip=stripOf(v);
  v.slowMs=2000;{const g0=v.gobs[0];v.apexY=g0?g0.p0[1]+Math.max(0,g0.v[1])*Math.max(0,g0.v[1])/(2*G):0;}
  return v;
}
function fixPhlUnused(v){ // make the phase list contiguous and ending at v.end, with the contact block after the phase that ends at tc
  const out=[];let t=0;for(const [n,a,b] of v.phl){if(b<=t)continue;out.push([n,Math.max(a,t),b]);t=b;}
  // split the phase containing tc
  const r=[];for(const [n,a,b] of out){if(a<v.tc&&b>v.tc){r.push([n,a,v.tc]);r.push([n+' ',v.tc,b]);}else r.push([n,a,b]);}return r;}
function stripOf(v){const tr=v.tr;return [Math.round(tr*.3),Math.round(tr*.72),tr+40,Math.round((tr+v.tc)/2),v.tc,v.tc+900].map(t=>Math.round(animToReal(v,t)));}
// ---------------------------------------------------------------- prey (pure function of animation time)
function preyAt(ver,a){
  const p=ver.prey,c0x=ver.c0[0],S={x:c0x,y:.34,z:0,yaw:0,pitch:0,roll:0,sx:1,sy:1,sz:1,hd:0,F:0};
  if(a<ver.tc){const b=Math.sin(a/230);S.pitch=.02*b;S.sy=1+.01*b;return S;}
  let F=0,D=0,H=0;
  for(const th of ver.hitTimes){const tau=(a-th)/1000;if(tau<0)break;F+=p.amp*Math.exp(-tau/.09)*Math.cos(2*Math.PI*tau/.17);D+=p.rec*(1-Math.exp(-tau/.07));H+=p.amp*1.2*Math.exp(-tau/.14);}
  F=clamp(F,-.45,.45);H=clamp(H,0,.8);const t0=(a-ver.tc)/1000;
  S.F=F;S.hd=H;S.x=c0x+D;S.y=.34+p.hop*Math.max(0,Math.sin(Math.PI*Math.min(t0/.3,1)));
  S.sx=1-F*.8;S.sy=1+.5*F;S.sz=1+.5*F;S.pitch=p.tilt*H*.5+.03*Math.sin(t0*9)*Math.exp(-t0/1.2);
  S.roll=.1*p.stag*Math.exp(-t0/.8)*Math.sin(t0*26);S.yaw=.09*p.stag*Math.exp(-t0/.7)*Math.sin(t0*17);
  S.y=Math.max(S.y,.02+(.32*Math.cos(S.roll)+.2*Math.abs(Math.sin(S.roll)))*S.sy);
  return S;
}
// ---------------------------------------------------------------- time maps (the hit-pause freezes the animation; pause 0 = none)
function realToAnim(ver,tr){const tc=ver.tc,p=ver.pause;if(tr<tc)return tr;if(tr<tc+p)return tc;return tr-p;}
function animToReal(ver,a){return a>ver.tc?a+ver.pause:a;}
function realLen(ver){return ver.end+ver.pause;}
function partsOf(ver){const out=[];for(const [n,a,b] of ver.phl){out.push([n.trim(),b-a]);if(b===ver.tc&&ver.pause>0)out.push(['contact',ver.pause]);}return out;}
const VERSIONS=SPECS.map(build);
// ---------------------------------------------------------------- self check
function check(){
  const fails=[],rows=[];
  for(const ver of VERSIONS){
    const r={id:ver.id,name:ver.name},spec=SPECS.find(s=>s.id===ver.id);
    r.preyDistance=ver.c0[0]-REST.P0[0];
    if(ver.id==='spray'){if(r.preyDistance<3||r.preyDistance>4.2)fails.push(`${ver.id}: prey ${r.preyDistance.toFixed(2)} m outside 3-4`);}else if(r.preyDistance<5||r.preyDistance>6)fails.push(`${ver.id}: prey ${r.preyDistance.toFixed(2)} m outside 5-6`);
    // 1 the projectile reaches the hitbox
    const C=V(ver.c0[0],CY,0),hp=ver.ps.filter(p=>p.endk==='hit');r.hits=hp.length;
    let worst=0;for(const p of hp)worst=Math.max(worst,Math.abs(V(...p.ex).distanceTo(C)-RH));r.hitSurfaceErr=worst;if(worst>.012)fails.push(`${ver.id}: a projectile ends ${(worst*100).toFixed(1)} cm off the hitbox surface`);
    if(!hp.length)fails.push(`${ver.id}: nothing reaches the hitbox`);
    r.hitFraction=ver.id==='spray'?hp.length/ver.ps.filter(p=>p.spray).length:1;
    // 2 arcs follow gravity (second difference of the position function, and the drawn gob / first jet particle)
    let gErr=0;const watch=ver.gobs.concat(ver.jet.slice(0,3),ver.drops.filter(p=>p.spray).slice(0,6));
    for(const p of watch){for(let a=p.t0+60;a<p.end-60;a+=40){const h=20,y0=posAt(p,a-h)[1],y1=posAt(p,a)[1],y2=posAt(p,a+h)[1],acc=(y0-2*y1+y2)/(h*h/1e6);gErr=Math.max(gErr,Math.abs(-acc-G)/G);}}
    r.gravityErr=gErr;if(gErr>.03)fails.push(`${ver.id}: arc deviates from g by ${(gErr*100).toFixed(1)} %`);
    const lead=ver.gobs.length?ver.gobs[0]:ver.jet[0];if(lead){r.flightMs=lead.end-lead.t0;r.speed=Math.hypot(...lead.v);r.launchAngleDeg=Math.atan2(lead.v[1],Math.hypot(lead.v[0],lead.v[2]))*180/Math.PI;
      let apex=-9;for(let a=lead.t0;a<=lead.end;a+=5)apex=Math.max(apex,posAt(lead,a)[1]);r.apex=apex;r.apexAboveLaunch=apex-lead.p0[1];}
    if(ver.id==='lob'&&r.apexAboveLaunch<.9)fails.push(`lob: arc not high (apex ${r.apexAboveLaunch.toFixed(2)} m above the mouth)`);
    // 3 the projectile leaves the mouth, and the head points where it goes
    const first=ver.ps.find(p=>p.k!=='drop'||p.spray),ma=mouthAt(ver,first.t0);r.leaveMouth=V(...first.p0).distanceTo(ma.m);if(r.leaveMouth>.03)fails.push(`${ver.id}: projectile starts ${(r.leaveMouth*100).toFixed(1)} cm from the mouth`);
    if(spec.aimAt){const ang=Math.acos(clamp(ma.axis.dot(V(...first.v).normalize()),-1,1))*180/Math.PI;r.aimErrDeg=ang;if(ang>6)fails.push(`${ver.id}: mouth axis is ${ang.toFixed(1)} deg off the launch direction`);}
    // contact frame: the first projectile reaches the prey exactly when the prey starts to flinch (tc), and the flinch starts at that frame
    const s0=preyAt(ver,ver.tc-2),s1=preyAt(ver,ver.tc+60);r.flinch=Math.abs(s1.sx-1)+Math.abs(s1.x-s0.x);if(r.flinch<.01)fails.push(`${ver.id}: prey does not react at the hit`);
    // 4 nothing through the ground (particles, creature, prey), feet planted, IK reach
    let pmin=9;for(const p of ver.ps)for(let a=p.t0;a<=p.end;a+=10)pmin=Math.min(pmin,posAt(p,Math.min(a,p.end))[1]);r.particleMinY=pmin;if(pmin<-.001)fails.push(`${ver.id}: a particle goes ${(pmin*100).toFixed(1)} cm below the ground`);
    let drift=0,maxErr=0,minY=9,lowest=9;const sampled=[];for(let a=0;a<=ver.end;a+=6)sampled.push([a,skel(ver,poseAt(ver,a),true)]);
    for(let i=0;i<4;i++)for(const s of ver.segs[i])if(s.k==='p'&&s.t1-s.t0>30){let p0=null;
      for(const [a,sk] of sampled)if(a>=s.t0+2&&a<=s.t1-2){if(!p0)p0=sk.feet[i].clone();drift=Math.max(drift,sk.feet[i].distanceTo(p0),sk.feet[i].distanceTo(sk.targets[i]));}}
    for(const [a,sk] of sampled){maxErr=Math.max(maxErr,sk.legErr,sk.neckErr);
      sk.nodes.forEach((n,i)=>{if(i<7)minY=Math.min(minY,n.y-REST.nodes[i][2]*.9);});sk.knees.forEach(k=>minY=Math.min(minY,k.y-.02));sk.feet.forEach(f=>minY=Math.min(minY,f.y-.03));minY=Math.min(minY,sk.tip.y,sk.head.y-REST.hr*.9);}
    r.plantedDrift=drift;r.maxReachErr=maxErr;r.minY=minY;
    if(drift>.02)fails.push(`${ver.id}: planted foot drift ${(drift*100).toFixed(1)} cm`);if(maxErr>.02)fails.push(`${ver.id}: IK out of reach by ${(maxErr*100).toFixed(1)} cm`);if(minY<-.012)fails.push(`${ver.id}: geometry ${(minY*100).toFixed(1)} cm below ground`);
    let pm=9,bad=0;for(let a=0;a<=ver.end;a+=5){const S=preyAt(ver,a);for(const k in S)if(typeof S[k]==='number'&&!isFinite(S[k]))bad++;pm=Math.min(pm,S.y-(.32*Math.cos(S.roll)+.2*Math.abs(Math.sin(S.roll)))*S.sy);}
    r.preyMinY=pm;if(bad)fails.push(`${ver.id}: prey state not finite`);if(pm<-.012)fails.push(`${ver.id}: prey through the ground`);
    // 5 timing against the game (wind-up 0.6 s for the standard spit; the charged version is longer by design)
    r.releaseMs=ver.tr;r.contactMs=ver.tc;r.windupMs=ver.tr;r.timing={};for(const [n,a,b] of ver.phl)r.timing[n.trim()]=b-a;
    if(ver.id==='glob'){if(ver.tr<900)fails.push('glob: wind-up should be clearly longer than the standard spit');}else if(ver.tr<450||ver.tr>800)fails.push(`${ver.id}: wind-up ${ver.tr} ms is far from the game's 600 ms`);
    r.slowMs=ver.slowMs;
    rows.push(r);
  }
  return {pass:!fails.length,fails,rows};
}
root.SPITCORE={SPECS,T,REST,VERSIONS,skel,poseAt,preyAt,glandAt,neckPoint,mouthAt,posAt,realToAnim,animToReal,realLen,partsOf,check,RH,CY,G};
})(typeof window!=='undefined'?window:globalThis);
