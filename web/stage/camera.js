const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const angle=v=>Math.atan2(Math.sin(v),Math.cos(v));
const mix=(a,b,t)=>a+(b-a)*t;

// Presentation only: positions and heading come from the canonical world.
export class ChaseCamera {
 constructor({height,yaw=Math.PI}){
  this.height=Math.max(.5,height);this.yaw=yaw;this.pitch=.24;
  this.minDistance=this.height*2.8;this.maxDistance=this.height*12;
  this.distance=this.height*6;this.orbitPitch=0;this.manual=0;
  this.target=null;this.boom=null;this.fightBlend=0;this.viewYaw=yaw;
 }
 orbit(dx,dy){this.yaw-=dx*.006;this.viewYaw-=dx*.006;this.orbitPitch=clamp(this.orbitPitch+dy*.004,-.2,.5);this.manual=.15}
 zoom(delta){this.distance=clamp(this.distance+delta,this.minDistance,this.maxDistance)}
 update({player,enemy,fighting=false,groundY,dt=0,aspect=1.6}){
  this.manual=Math.max(0,this.manual-dt);
  if(player.speed>.4&&!this.manual)this.yaw+=angle(player.yaw+Math.PI-this.viewYaw)*(1-Math.exp(-dt/.4));
  const wide=clamp((this.distance/this.height-6)/6,0,1);
  this.pitch=clamp(.24+wide*.6+this.orbitPitch,.04,1.15);
  const h=this.height,target={x:player.x,y:groundY(player.x,player.z)+h*1.5,z:player.z};
  this.fightBlend=mix(this.fightBlend,fighting?1:0,dt?1-Math.exp(-dt/.25):1);
  // A sideward view separates opponents that would hide behind one another
  // along the chase axis. Keep orbit controls relative to the displayed view.
  this.viewYaw=this.yaw+this.fightBlend*.85;
  let desiredDistance=this.distance*(aspect<.7?1.25:1);
  if(fighting&&enemy){
   target.x=(player.x+enemy.x)/2;target.z=(player.z+enemy.z)/2;
   target.y=(groundY(player.x,player.z)+groundY(enemy.x,enemy.z))/2+h*1.5;
   const separation=Math.hypot(player.x-enemy.x,player.z-enemy.z);
   const halfFov=Math.atan(Math.tan(24*Math.PI/180)*Math.min(1,aspect));
   desiredDistance=Math.max(desiredDistance+separation*.6,(separation/2+h*1.5)/Math.sin(halfFov*.85));
  }
  const ease=dt?1-Math.exp(-dt/.25):1;
  if(!this.target)this.target={...target};
  for(const key of ['x','y','z'])this.target[key]=mix(this.target[key],target[key],ease);
  // Never smooth the safety correction: a newly intersecting ridge pulls in now.
  this.target.y=Math.max(this.target.y,groundY(this.target.x,this.target.z)+.8);
  this.boom=this.boom===null?desiredDistance:mix(this.boom,desiredDistance,dt?1-Math.exp(-dt/.3):1);
  const direction={x:Math.sin(this.viewYaw)*Math.cos(this.pitch),y:Math.sin(this.pitch),z:Math.cos(this.viewYaw)*Math.cos(this.pitch)};
  let length=this.boom;
  for(let d=.2;d<=this.boom+.2;d+=.2){
   const sample=Math.min(d,this.boom),x=this.target.x+direction.x*sample,z=this.target.z+direction.z*sample;
   if(this.target.y+direction.y*sample<groundY(x,z)+.65){length=Math.max(0,sample-.25);break}
  }
  const position={x:this.target.x+direction.x*length,y:this.target.y+direction.y*length,z:this.target.z+direction.z*length};
  position.y=Math.max(position.y,groundY(position.x,position.z)+.65);
  return {position,target:{...this.target},yaw:this.viewYaw,pitch:this.pitch,distance:this.boom,actualDistance:length};
 }
 state(){return {yaw:this.viewYaw,pitch:this.pitch,distance:this.distance,minDistance:this.minDistance,maxDistance:this.maxDistance,height:this.height}}
}
