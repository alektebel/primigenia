// Ground intersection samples the same height function as roaming and IK.
// It does not depend on terrain mesh tessellation or far-mountain geometry.
export function groundHit(T,camera,canvas,groundY,x,y){
 const rect=canvas.getBoundingClientRect(),raycaster=new T.Raycaster();
 raycaster.setFromCamera(new T.Vector2((x-rect.left)/rect.width*2-1,1-(y-rect.top)/rect.height*2),camera);
 const ray=raycaster.ray,p=new T.Vector3();let previous=0;
 for(let t=1;t<=900;t+=1){ray.at(t,p);if(p.y<=groundY(p.x,p.z)){
  let lo=previous,hi=t;for(let k=0;k<14;k++){const mid=(lo+hi)/2;ray.at(mid,p);if(p.y>groundY(p.x,p.z))lo=mid;else hi=mid}
  ray.at((lo+hi)/2,p);return {x:p.x,z:p.z};
 }previous=t}return null;
}
export function pointerControls({env,rigs,sim,onSelect,onOrbit,onZoom,onGesture}){
 const {T,camera,renderer,groundY}=env,canvas=renderer.domElement,pointers=new Map();let follow=null,gesture=null;
 const sample=(x,y,select=false)=>{
  if(sim.paused)return;
  if(select&&!sim.enemy.dead){const rect=canvas.getBoundingClientRect(),ray=new T.Raycaster();
   ray.setFromCamera(new T.Vector2((x-rect.left)/rect.width*2-1,1-(y-rect.top)/rect.height*2),camera);
   if(ray.intersectObjects([rigs[1].creature,rigs[1].limbs],true).length){onSelect(true);sim.destination=null;return false}
  }
  const hit=groundHit(T,camera,canvas,groundY,x,y);
  if(hit){onSelect(false);sim.destination=hit;sim.pendingAttack=null}return true;
 };
 const touchState=()=>{const a=[...pointers.values()].filter(p=>p.type==='touch');if(a.length<2)return null;
  return {x:(a[0].x+a[1].x)/2,y:(a[0].y+a[1].y)/2,gap:Math.hypot(a[0].x-a[1].x,a[0].y-a[1].y)}};
 canvas.addEventListener('contextmenu',e=>e.preventDefault());
 canvas.addEventListener('pointerdown',e=>{
  if(sim.paused)return;onGesture();canvas.focus({preventScroll:true});canvas.setPointerCapture(e.pointerId);
  pointers.set(e.pointerId,{x:e.clientX,y:e.clientY,type:e.pointerType,button:e.button});
  const two=touchState();if(two){follow=null;sim.destination=null;gesture=two;return}
  if(e.button===0){const move=sample(e.clientX,e.clientY,true);follow=move?e.pointerId:null}
 });
 canvas.addEventListener('pointermove',e=>{
  const old=pointers.get(e.pointerId);if(!old)return;
  pointers.set(e.pointerId,{...old,x:e.clientX,y:e.clientY});
  const two=touchState();
  if(two&&gesture){onOrbit(two.x-gesture.x,two.y-gesture.y);onZoom((gesture.gap-two.gap)*.04);gesture=two;return}
  if(old.button===1||old.button===2)onOrbit(e.clientX-old.x,e.clientY-old.y);
 });
 const release=e=>{pointers.delete(e.pointerId);if(follow===e.pointerId)follow=null;if(pointers.size<2)gesture=null};
 for(const name of ['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(name,release);
 addEventListener('blur',()=>{follow=null;pointers.clear();gesture=null});
 canvas.addEventListener('wheel',e=>{e.preventDefault();onZoom(e.deltaY*.01)},{passive:false});
 return {update(){const p=pointers.get(follow);if(p&&!gesture)sample(p.x,p.y)},cancel(){follow=null;pointers.clear();gesture=null}};
}
