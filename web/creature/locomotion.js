/* G73. Renderer-independent anatomy and world-space contact controller.
 * Metres, seconds, kilograms. These are visual estimates, never C authority.
 * Assumptions, sources and the proposed C profile live in docs/LOCOMOTION.md. */
const G=9.81,TAU=2*Math.PI;
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),mix=(a,b,t)=>a+(b-a)*t;
const point=(x=0,y=0,z=0)=>({x,y,z});
const length=p=>Math.hypot(p.x,p.y,p.z);
const sub=(a,b)=>point(a.x-b.x,a.y-b.y,a.z-b.z);
const midpoint=(a,b)=>point((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2);
const turn=a=>Math.atan2(Math.sin(a),Math.cos(a));
const fract=a=>a-Math.floor(a);
const cross=(o,a,b)=>(a.x-o.x)*(b.z-o.z)-(a.z-o.z)*(b.x-o.x);

export function supportPolygon(points){
 const sorted=points.slice().sort((a,b)=>a.x-b.x||a.z-b.z);
 if(sorted.length<3)return sorted;
 const half=arr=>{const h=[];for(const p of arr){while(h.length>1&&cross(h.at(-2),h.at(-1),p)<=0)h.pop();h.push(p)}return h};
 return [...half(sorted).slice(0,-1),...half(sorted.reverse()).slice(0,-1)];
}
export function insideSupport(p,hull){
 return hull.length>=3&&hull.every((a,i)=>cross(a,hull[(i+1)%hull.length],p)>=-1e-8);
}
function supportedPoint(p,hull){
 if(insideSupport(p,hull)||hull.length<3)return p;
 let best=p,distance=Infinity;
 for(let i=0;i<hull.length;i++){
  const a=hull[i],b=hull[(i+1)%hull.length],dx=b.x-a.x,dz=b.z-a.z;
  const t=clamp(((p.x-a.x)*dx+(p.z-a.z)*dz)/(dx*dx+dz*dz||1),0,1),q={x:a.x+t*dx,z:a.z+t*dz};
  const d=Math.hypot(q.x-p.x,q.z-p.z);if(d<distance){best=q;distance=d}
 }
 const c=hull.reduce((s,p)=>({x:s.x+p.x/hull.length,z:s.z+p.z/hull.length}),{x:0,z:0});
 return {x:mix(best.x,c.x,.015),z:mix(best.z,c.z,.015)};
}

/* YXZ is also the rig's Euler order. Shared by balance and its mesh audit. */
export function rotateBody(p,yaw,pitch=0,roll=0){
 const x=p.x*Math.cos(roll)-p.y*Math.sin(roll),y=p.x*Math.sin(roll)+p.y*Math.cos(roll);
 const yy=y*Math.cos(pitch)-p.z*Math.sin(pitch),z=y*Math.sin(pitch)+p.z*Math.cos(pitch);
 return point(x*Math.cos(yaw)+z*Math.sin(yaw),yy,-x*Math.sin(yaw)+z*Math.cos(yaw));
}

// Volume at size=1, tissue density. Explicit categories avoid combat-stat mass.
export const PART_MASS=Object.freeze({
 mouths:[.055,850],senses:[.008,650],weapons:[.022,1400],details:[.025,1200],
 wings:[.018,400],fins:[.012,650],arms:[.035,950],tails:[.035,950],
 digging_claws:[.025,1100],default:[.012,850],
});
const LEG_FOOT={pata:'claw',zanca:'toes',pezuna:'hoof',leg_sprinter:'runner',leg_sucker:'sucker',foot_spring:'spring',foot_hoof:'cloven',foot_gecko:'gecko'};

// Only the standalone analysis uses linear interpolation. The live rig supplies
// its sampled Catmull-Rom spine, actual surface roots and fitted IK lengths.
function attachment(nodes,t,angle){
 if(!nodes.length)return point();
 const f=clamp(t??.5,0,1)*(nodes.length-1),i=Math.min(Math.floor(f),Math.max(0,nodes.length-2)),a=nodes[i],b=nodes[Math.min(i+1,nodes.length-1)],q=f-i;
 const r=mix(a.r,b.r,q);return point(Math.sin(angle)*r,mix(a.y,b.y,q)+Math.cos(angle)*r,mix(a.z,b.z,q));
}
export function analyzeMorphology(genome,{spine=genome.nodes,catalog=[],legs:resolvedLegs,attachments,groundOffset=0}={}){
 const nodes=genome.nodes||[],sp=spine?.length?spine:[{y:.2,z:0,r:.1},{y:.2,z:.1,r:.1}];
 const entries=new Map(catalog.map(p=>[p.id,p])),elements=[];let volume=0;
 function mass(m,p,r=.01,axis=point(0,0,1),len=0){
  const parallel=m*r*r/2,perpendicular=m*(3*r*r+len*len)/12;
  elements.push({m,p,inertia:point(...['x','y','z'].map(k=>perpendicular+(parallel-perpendicular)*axis[k]**2))});
 }
 for(let i=1;i<sp.length;i++){
  const a={x:0,...sp[i-1]},b={x:0,...sp[i]},d=sub(b,a),len=length(d),axis=point(d.x/(len||1),d.y/(len||1),d.z/(len||1));
  // Subdivided frusta place mass at the tapered end, not just the midpoint.
  for(let j=0;j<8;j++){
   const u=(j+.5)/8,r=mix(a.r,b.r,u),r0=mix(a.r,b.r,j/8),r1=mix(a.r,b.r,(j+1)/8);
   const v=Math.PI*len/24*(r0*r0+r0*r1+r1*r1);volume+=v;
   mass(v*950,point(mix(a.x,b.x,u),mix(a.y,b.y,u),mix(a.z,b.z,u)),r,axis,len/8);
  }
 }
 const rawLegs=[],partRoots=attachments||[];
 for(const [index,p] of (genome.parts||[]).entries()){
  const entry=entries.get(p.type),isLeg=!!LEG_FOOT[p.type]||entry?.category==='legs';
  const sides=isLeg||Math.abs(Math.sin(p.ang||0))>=.14?[1,-1]:[1];
  for(const side of sides){
   const root=partRoots.find(a=>a.index===index&&a.side===side)?.position||attachment(nodes,p.t,side*(p.ang||0));
   if(isLeg){
    const w=p.w??.16*(p.size??1),k=p.k||[.32,-root.y*.48,.34],f=p.f||[.35,-root.y+w*.6,.12];
    const knee=point(side*k[0],Math.max(k[1],-root.y+.12),k[2]),foot=point(side*f[0],-root.y+w*.6,f[2]);
    rawLegs.push({hip:root,home:point(root.x+foot.x,0,root.z+foot.z),a:length(knee),b:length(sub(foot,knee)),w,side,footType:LEG_FOOT[p.type]||'claw'});
   }else{
    const category=p.type.startsWith('tail_')?'tails':p.type.startsWith('arm_')?'arms':entry?.category||'default';
    const [v,density]=PART_MASS[category]||PART_MASS.default,s=p.size??1,len=p.len??1;
    mass(v*density*s**3*len,root,Math.cbrt(v)*s,point(0,0,1),len*.3);
   }
  }
 }
 const legs=(resolvedLegs||rawLegs).map(l=>({...l,hip:{...l.hip},home:{...l.home}}));
 const levels=[...new Set(legs.map(l=>l.hip.z.toFixed(3)))].sort((a,b)=>Number(a)-Number(b));
 for(const l of legs){
  l.row=levels.indexOf(l.hip.z.toFixed(3));l.front=l.row>=(levels.length/2);
  l.label=(l.side>0?'L':'R')+(levels.length>2?l.row:l.front?'F':'H');
  const a=point(l.hip.x,l.hip.y-(l.a+l.b)*.45,l.hip.z),m=950*Math.PI*l.w*l.w*(l.a+l.b)*.8;
  mass(m,a,l.w,point(0,1,0),l.a+l.b);
 }
 const massKg=elements.reduce((s,e)=>s+e.m,0),centerOfMass=point();
 for(const e of elements)for(const k of ['x','y','z'])centerOfMass[k]+=e.p[k]*e.m/massKg;
 const moments=point();
 for(const e of elements){const d=sub(e.p,centerOfMass);moments.x+=e.inertia.x+e.m*(d.y*d.y+d.z*d.z);moments.y+=e.inertia.y+e.m*(d.x*d.x+d.z*d.z);moments.z+=e.inertia.z+e.m*(d.x*d.x+d.y*d.y)}
 const spanY=Math.max(...sp.map(n=>n.y))-Math.min(...sp.map(n=>n.y)),spanZ=Math.max(...sp.map(n=>n.z))-Math.min(...sp.map(n=>n.z));
 const bodyPlan=legs.length===0?'slither':legs.length<=2?(spanY>spanZ*.65?'biped-upright':'biped-horizontal'):legs.length<6?'quadruped':'hexapod+';
 const legLength=legs.length?legs.reduce((s,l)=>s+Math.max(.12,l.hip.y+groundOffset-l.home.y),0)/legs.length:Math.max(.2,spanZ*.15);
 const load=massKg/(950*legLength**3),neckMoment=elements.filter(e=>e.p.y>centerOfMass.y+.3).reduce((s,e)=>s+e.m*length(sub(e.p,centerOfMass)),0);
 const tailMoment=elements.filter(e=>e.p.z<centerOfMass.z-.3).reduce((s,e)=>s+e.m*length(sub(e.p,centerOfMass)),0);
 const model={bodyPlan,legs,legLength,volume,massKg,centerOfMass,moments,load,groundOffset,neckMoment,tailMoment};
 model.support=supportPolygon(legs.map(l=>l.home));
 const maxFr=bodyPlan==='slither'?.12:clamp(4/(1+load*.35),.7,4);
 model.proposal={maxSpeed:Math.sqrt(G*legLength*maxFr),acceleration:clamp(G*.4/(1+load),.5,4),maxFr};
 return model;
}

export function gaitFor(model,speed,slope=0){
 const L=model.legLength,fr=Math.max(0,speed)**2/(G*L),n=model.legs.length;
 const name=!n?'slither':n>=6?'tripod':fr<.5?'walk':n<=2?'run':fr<2?'trot':fr<3?'canter':'gallop';
 const walking=name==='walk',duty=walking?(n>2?mix(.86,.76,clamp(fr/.5,0,1)):mix(.68,.56,clamp(fr/.5,0,1))):name==='tripod'?mix(.72,.54,clamp(fr,0,1)):name==='trot'?.48:name==='canter'?.43:.38;
 const offsets=model.legs.map(l=>{
  if(n<=2)return l.side>0?0:.5;
  if(n>=6)return (l.row+(l.side>0?0:1))%2*.5;
  if(walking)return (l.side>0?0:.5)+(l.front?.25:0);
  if(name==='trot')return (l.front===(l.side>0))?.5:0;
  if(name==='canter')return l.front?(l.side>0?.68:.38):(l.side>0?0:.38);
  return l.front?(l.side>0?.64:.52):(l.side>0?0:.12);
 });
 // At fixed speed more load means a longer, slower stride, bounded by reach.
 const weight=1+clamp(model.load*.12,0,.35),uphill=1/(1+Math.max(0,slope)*1.6);
 const stride=L*clamp((.65+1.35*Math.sqrt(fr))*weight,.4,3.5)*uphill;
 return {name,fr,duty,offsets,stride,cadence:speed>0?speed/stride:0,staticallyStable:walking&&n>=4||name==='tripod'&&duty>=.5};
}

function worldPoint(local,pose){const p=rotateBody(local,pose.yaw);return point(pose.x+p.x,0,pose.z+p.z)}
function contactHull(feet,legs){
 const points=[];
 feet.forEach((f,i)=>{if(f.swing)return;const w=legs[i].w;
  for(const x of [-w,w])for(const z of [-w,w*2]){
   const q=rotateBody(point(x,0,z),f.yaw);points.push({x:f.position.x+q.x,z:f.position.z+q.z});
  }
 });
 return supportPolygon(points);
}

export class Locomotion {
 constructor(model){this.model=model;this.phase=0;this.previous=null;this.feet=[];this.body={x:0,z:0,bob:0,pitch:0,roll:0,neck:0,tail:0};this.state=null}
 reset(pose){
  this.phase=0;
  this.feet=this.model.legs.map(l=>{const position=worldPoint(l.home,pose);position.y=pose.groundY(position.x,position.z)+(l.home.y||0);return {position,swing:false,progress:0,yaw:pose.yaw,liftCycle:-Infinity,contact:false}});
  this.previous={...pose};Object.assign(this.body,{x:0,z:0,bob:0,pitch:pose.pitch||0,roll:pose.roll||0,neck:0,tail:0});
 }
 update(dt,pose){
  if(!Number.isFinite(dt)||dt<0)throw RangeError('locomotion delta');
  const reset=!this.previous||Math.hypot(pose.x-this.previous.x,pose.z-this.previous.z)>3;
  if(reset)this.reset(pose);
  const m=this.model,b=this.body,L=m.legLength,dx=pose.x-this.previous.x,dz=pose.z-this.previous.z,travel=Math.hypot(dx,dz),yawDelta=turn(pose.yaw-this.previous.yaw);
  const speed=Math.max(0,pose.speed||0),fx=Math.sin(pose.yaw),fz=Math.cos(pose.yaw),ground=pose.groundY;
  const slope=(ground(pose.x+fx*L*.5,pose.z+fz*L*.5)-ground(pose.x-fx*L*.5,pose.z-fz*L*.5))/L;
  const gait=gaitFor(m,speed,slope),advance=(travel+Math.abs(yawDelta)*L*.22)/gait.stride;
  this.phase+=advance;
  const vx=dt>0?dx/dt:0,vz=dt>0?dz/dt:0,rate=pose.turnRate??(dt>0?yawDelta/dt:0);
  const acceleration=pose.acceleration??(dt>0?(speed-(this.previous.speed||0))/dt:0);
  for(const [i,f] of this.feet.entries()){
   f.contact=false;const l=m.legs[i],ph=fract(this.phase-gait.offsets[i]),cycle=Math.floor(this.phase-gait.offsets[i]);
   if(advance>0&&!f.swing&&ph>=gait.duty&&cycle!==f.liftCycle){
    f.swing=true;f.progress=0;f.liftCycle=cycle;f.from={...f.position};f.duration=1-gait.duty;
    const horizon=gait.cadence>0?(1-gait.duty/2)/gait.cadence:0,angle=clamp(rate*horizon,-.65,.65);
    const predicted={...pose,x:pose.x+vx*horizon,z:pose.z+vz*horizon,yaw:pose.yaw+angle};
    f.target=worldPoint(l.home,predicted);f.target.y=ground(f.target.x,f.target.z)+(l.home.y||0);
    let obstacle=0;
    for(const q of [.2,.4,.6,.8])obstacle=Math.max(obstacle,ground(mix(f.from.x,f.target.x,q),mix(f.from.z,f.target.z,q))-mix(f.from.y,f.target.y,q));
    f.clearance=L*(.06+.08*clamp(Math.sqrt(gait.fr),0,2))+Math.max(0,obstacle)*1.4;
   }else if(f.swing){
    f.progress=Math.min(1,f.progress+advance/f.duration);const q=f.progress,s=q*q*(3-2*q);
    f.position=point(mix(f.from.x,f.target.x,s),mix(f.from.y,f.target.y,q)+Math.sin(Math.PI*q)*f.clearance,mix(f.from.z,f.target.z,s));
    if(q>=1){f.position={...f.target};f.swing=false;f.contact=true;f.yaw=pose.yaw}
   }
  }
  const moving=travel>1e-8||Math.abs(yawDelta)>1e-8;
  const weight=1/Math.sqrt(1+m.load),response=1-Math.exp(-dt*8*weight),osc=Math.cos(this.phase*TAU*2);
  // Pendulum vault in walks; opposite vertical curvature for elastic running.
  const bob=moving?L*Math.min(.065,.018+gait.fr*.035)*(gait.name==='walk'?osc:-osc):0;
  const pitch=clamp((pose.pitch??-Math.atan(slope))+clamp(acceleration/G,-.3,.3)*.22,-.5,.5);
  const roll=clamp((pose.roll??-Math.atan(speed*rate/G)),-.32,.32);
  b.bob=mix(b.bob,bob,response);b.pitch=mix(b.pitch,pitch,response);b.roll=mix(b.roll,roll,response);
  const lag=1-Math.exp(-dt*3*weight);
  b.neck=mix(b.neck,-b.pitch*m.neckMoment/(m.moments.x+1),lag);
  b.tail=mix(b.tail,-rate*.16-b.pitch*m.tailMoment/(m.moments.x+1),lag);
  const support=contactHull(this.feet,m.legs),com=rotateBody(m.centerOfMass,pose.yaw,b.pitch,b.roll);
  com.x+=pose.x;com.z+=pose.z;com.y+=ground(pose.x,pose.z)+m.groundOffset+b.bob;
  const staticallyStable=gait.staticallyStable&&support.length>=3;
  const balanced=staticallyStable?supportedPoint(com,support):com;
  // Hard contact constraint after the damped body response. Never move feet to
  // hide imbalance; translate the rendered torso relative to the C root.
  b.x=balanced.x-com.x;b.z=balanced.z-com.z;com.x+=b.x;com.z+=b.z;
  this.previous={...pose};
  return this.state={gait,feet:this.feet,body:b,centerOfMass:com,support,staticallyStable,slope,distance:travel};
 }
}
