import {createCreatureRig} from '../creature/rig.js';
import {Combat,MOVE} from '../engine/cpcombat.js';
import {profileFromStudio} from '../engine/profile.js';
import {StageSimulation} from './simulation.js';
import {pointerControls} from './pointer.js';
import {StageAudio} from './audio.js';

const $=id=>document.getElementById(id),clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const mix=(a,b,t)=>a+(b-a)*t;
const MOVES=[['mouth',MOVE.BITE,'Bite'],['charge',MOVE.CHARGE,'Charge'],['spit',MOVE.SPIT,'Spit'],['tail',MOVE.TAIL,'Tail']];
const phases=['Ready','Windup','Strike','Recovery'];
const down=new Set(),pressed=new Set();let stick=[0,0],pendingDodge=null,yaw=Math.PI,pitch=.24,distance=17,timeline=null;
let pointer,audio,selected=false,orbitGrace=0,marker,selection;
let lastTap={},sim,rigs,env,shownOutcome=null,toastUntil=0;
function message(text){$('status').textContent=text}
async function json(path){const response=await fetch(path);if(!response.ok)throw Error(`Could not load ${path} (${response.status})`);return response.json()}
function worldVector(x,z){return [x*Math.cos(yaw)+z*Math.sin(yaw),-x*Math.sin(yaw)+z*Math.cos(yaw)]}
function input(){
 const gamepad=navigator.getGamepads?.()[0];
 if(gamepad){yaw-=Math.abs(gamepad.axes[2]||0)>.15?gamepad.axes[2]*.08:0;pitch=clamp(pitch+(Math.abs(gamepad.axes[3]||0)>.15?gamepad.axes[3]*.04:0),.05,.9)}
 const x=+(down.has('KeyD')||down.has('ArrowRight'))-+(down.has('KeyA')||down.has('ArrowLeft'))+stick[0]+(Math.abs(gamepad?.axes[0]||0)>.15?gamepad.axes[0]:0);
 const z=+(down.has('KeyS')||down.has('ArrowDown'))-+(down.has('KeyW')||down.has('ArrowUp'))+stick[1]+(Math.abs(gamepad?.axes[1]||0)>.15?gamepad.axes[1]:0);
 const attack=available.find((m,i)=>down.has(`Digit${i+1}`)||pressed.has(`Digit${i+1}`));
 const result={move:worldVector(x,z),sprint:down.has('ShiftLeft')||down.has('ShiftRight')||down.has('sprint'),guard:sim.profile.guard>0&&(down.has('Space')||pressed.has('Space'))};
 if(attack)result.attack=attack[1];
 if(pendingDodge!==null){result.dodge=pendingDodge;pendingDodge=null}
 pressed.clear();return result;
}
let available=[];
function pause(value=!sim.paused){sim.paused=value;$('pause-panel').hidden=!value;$('pause').textContent=value?'Resume':'Pause';$('pause').setAttribute('aria-label',value?'Resume game':'Pause game');down.clear();pressed.clear();stick=[0,0];pendingDodge=null;pointer?.cancel();sim.destination=null;sim.pendingAttack=null;sim.accumulator=0;audio?.setPaused(value);if(value)$('resume').focus();else env.renderer.domElement.focus()}
function controls(){
 const canvas=env.renderer.domElement;canvas.style.touchAction='none';canvas.tabIndex=0;canvas.setAttribute('aria-label','Creature valley. Click or hold to walk; WASD or arrows also move. Right drag to orbit.');
 pointer=pointerControls({env,rigs,sim,onSelect:value=>selected=value,onOrbit:(dx,dy)=>{yaw-=dx*.006;pitch=clamp(pitch+dy*.004,.04,.95);orbitGrace=2.5},onZoom:delta=>distance=clamp(distance+delta,8,30),onGesture:()=>audio.start()});
 addEventListener('pointerdown',()=>audio.start(),{once:true});
 addEventListener('keydown',()=>audio.start(),{once:true});
 addEventListener('keydown',e=>{
  if(sim.paused&&e.code==='Tab'){
   const focusable=[...$('pause-panel').querySelectorAll('button,a,input')].filter(el=>!el.disabled),first=focusable[0],last=focusable.at(-1);
   if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}
   else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}
   return;
  }
  if(e.code==='Escape'||e.code==='KeyP'){e.preventDefault();if(!e.repeat)pause();return}
  if(sim.paused||(e.target.matches('input')||e.code==='Space'&&e.target.matches('button,a')))return;
  if(['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code))e.preventDefault();
  if(!e.repeat){if(e.code==='Space'||/^Digit[1-4]$/.test(e.code))pressed.add(e.code);if(e.code==='KeyQ')pendingDodge=2;if(e.code==='KeyE')pendingDodge=6;
   if(['KeyW','KeyA','KeyS','KeyD','ArrowUp','ArrowLeft','ArrowDown','ArrowRight'].includes(e.code)){
    const now=performance.now();if(now-(lastTap[e.code]||-1000)<260){const vector=worldVector(['KeyD','ArrowRight'].includes(e.code)?1:['KeyA','ArrowLeft'].includes(e.code)?-1:0,['KeyS','ArrowDown'].includes(e.code)?1:['KeyW','ArrowUp'].includes(e.code)?-1:0);
     const relative=Math.atan2(vector[0],vector[1])-sim.player.yaw;pendingDodge=((Math.round(-relative/(Math.PI/4))%8)+8)%8}lastTap[e.code]=now;
   }
  }down.add(e.code);
 });
 addEventListener('keyup',e=>down.delete(e.code));
 addEventListener('blur',()=>{down.clear();pressed.clear();stick=[0,0];pendingDodge=null;if(!sim.paused)pause(true)});
 document.addEventListener('visibilitychange',()=>{if(document.hidden&&!sim.paused)pause(true)});
 $('pause').onclick=()=>pause();$('resume').onclick=()=>pause(false);
 available=MOVES.filter(([field])=>sim.profile[field]>0);
 const actions=[...available.map((m,i)=>[m[2],`Digit${i+1}`,String(i+1)]),['Guard','Space','Space'],['Dodge L','dodge-left','Q'],['Dodge R','dodge-right','E']];
 for(const [name,key,label]of actions){const button=document.createElement('button');button.innerHTML=`<kbd>${label}</kbd>${name}`;button.setAttribute('aria-label',name);button.dataset.key=key;if(key==='Space'&&!sim.profile.guard){button.disabled=true;button.title='Add an armour plate in Studio to guard'}
  button.addEventListener('pointerdown',e=>{e.preventDefault();button.setPointerCapture(e.pointerId);if(key.startsWith('dodge'))pendingDodge=key==='dodge-left'?2:6;else {down.add(key);pressed.add(key)}button.dataset.held=true});
  for(const event of ['pointerup','pointercancel','lostpointercapture'])button.addEventListener(event,()=>{down.delete(key);button.dataset.held=false});
  button.addEventListener('click',e=>{if(e.detail===0){if(key.startsWith('dodge'))pendingDodge=key==='dodge-left'?2:6;else{down.add(key);pressed.add(key);setTimeout(()=>down.delete(key),150)}}});$('actions').append(button);
 }
 const pad=$('stick');let touch=null;
 pad.addEventListener('pointerdown',e=>{e.preventDefault();touch=e.pointerId;pad.setPointerCapture(touch);moveStick(e)});
 function moveStick(e){if(e.pointerId!==touch)return;const rect=pad.getBoundingClientRect(),dx=e.clientX-rect.left-rect.width/2,dz=e.clientY-rect.top-rect.height/2,length=Math.max(40,Math.hypot(dx,dz));stick=[dx/length,dz/length];pad.firstElementChild.style.transform=`translate(${stick[0]*34}px,${stick[1]*34}px)`}
 pad.addEventListener('pointermove',moveStick);
 for(const event of ['pointerup','pointercancel','lostpointercapture'])pad.addEventListener(event,()=>{touch=null;stick=[0,0];pad.firstElementChild.style.transform=''});
 $('sprint').onpointerdown=e=>{e.preventDefault();e.currentTarget.setPointerCapture(e.pointerId);down.add('sprint')};
 for(const event of ['pointerup','pointercancel','lostpointercapture'])$('sprint').addEventListener(event,()=>down.delete('sprint'));
}
function lightEnvironment(){
 const {T,scene,renderer}=env,L=window.__heroLight;
 const sky=new T.Scene(),geometry=new T.SphereGeometry(50,24,16),p=geometry.attributes.position,colors=[];
 const hz=new T.Color(...L.envHz),mid=new T.Color(...L.envMid),top=new T.Color(...L.envTop),gd=new T.Color(...L.envGd);
 const smooth=(a,b,x)=>{const v=clamp((x-a)/(b-a),0,1);return v*v*(3-2*v)};
 for(let i=0;i<p.count;i++){const h=p.getY(i)/50,c=hz.clone();if(h<0)c.lerp(gd,smooth(0,.15,-h));else c.lerp(mid,smooth(0,.3,h)).lerp(top,smooth(.25,.95,h));colors.push(c.r,c.g,c.b)}
 geometry.setAttribute('color',new T.Float32BufferAttribute(colors,3));sky.add(new T.Mesh(geometry,new T.MeshBasicMaterial({vertexColors:true,side:T.BackSide})));
 const disc=new T.Mesh(new T.SphereGeometry(5,16,12),new T.MeshBasicMaterial({color:new T.Color(...L.envSun)}));disc.position.copy(env.SUN).multiplyScalar(44);sky.add(disc);
 const pm=new T.PMREMGenerator(renderer);scene.environment=pm.fromScene(sky,.03).texture;pm.dispose();sky.traverse(o=>{o.geometry?.dispose();o.material?.dispose()});
}
let arena,cone;
function makeGroundMesh(color,opacity){const {T,scene}=env,mesh=new T.Mesh(new T.BufferGeometry(),new T.MeshBasicMaterial({color,transparent:true,opacity,side:T.DoubleSide,depthWrite:false,depthTest:false}));mesh.frustumCulled=false;mesh.renderOrder=2;mesh.visible=false;scene.add(mesh);return mesh}
function setTriangles(mesh,points){const {T,groundY}=env;mesh.geometry.dispose();mesh.geometry=new T.BufferGeometry();mesh.geometry.setAttribute('position',new T.Float32BufferAttribute(points.flatMap(p=>[p.x,groundY(p.x,p.z)+.08,p.z]),3));mesh.geometry.computeVertexNormals()}
let arenaPoint=null;
function combatGround(){
 const e=sim.encounter;arena.visible=!!e;cone.visible=false;if(!e)return;
 if(arenaPoint!==e.point){arenaPoint=e.point;const points=[],p=e.point;
  for(const [a,b]of [[[-20,-20],[20,-20]],[[20,-20],[20,20]],[[20,20],[-20,20]],[[-20,20],[-20,-20]]])for(let i=0;i<40;i++){
   const u=i/40,v=(i+1)/40,A={x:p.x+mix(a[0],b[0],u),z:p.z+mix(a[1],b[1],u)},B={x:p.x+mix(a[0],b[0],v),z:p.z+mix(a[1],b[1],v)},dx=(b[1]-a[1])/40*.1,dz=-(b[0]-a[0])/40*.1;
   points.push(A,B,{x:A.x+dx,z:A.z+dz},B,{x:B.x+dx,z:B.z+dz},{x:A.x+dx,z:A.z+dz});
  }setTriangles(arena,points);
 }
 const state=e.current[1];if(state.phase===1&&[0,1,3,4].includes(state.move)){
  const preview=sim.combat.preview(1,state.move,0),p=e.toValley(preview),facing=Math.atan2(preview.fx,preview.fy),points=[];
  for(let i=0;i<24;i++){const a=facing-preview.arc/2+preview.arc*i/24,b=facing-preview.arc/2+preview.arc*(i+1)/24,r=preview.reach+.6;points.push(p,{x:p.x+Math.sin(a)*r,z:p.z+Math.cos(a)*r},{x:p.x+Math.sin(b)*r,z:p.z+Math.cos(b)*r})}
  setTriangles(cone,points);cone.visible=true;
 }
}
function targetGround(){
 const ring=(mesh,p,r,width)=>{mesh.visible=!!p;if(!p)return;const points=[];
  for(let i=0;i<48;i++){const a=i/48*Math.PI*2,b=(i+1)/48*Math.PI*2,A={x:p.x+Math.sin(a)*r,z:p.z+Math.cos(a)*r},B={x:p.x+Math.sin(b)*r,z:p.z+Math.cos(b)*r},C={x:p.x+Math.sin(a)*(r+width),z:p.z+Math.cos(a)*(r+width)},D={x:p.x+Math.sin(b)*(r+width),z:p.z+Math.cos(b)*(r+width)};points.push(A,B,C,B,D,C)}setTriangles(mesh,points)};
 ring(marker,sim.destination,.35,.07);ring(selection,selected&&!sim.enemy.dead?sim.enemy:null,(sim.enemyProfile.radiusCm||60)/100+.2,.09);
 const label=$('selected-name');label.hidden=!selection.visible;
 if(selection.visible){const p=new env.T.Vector3(sim.enemy.x,env.groundY(sim.enemy.x,sim.enemy.z)+4,sim.enemy.z).project(env.camera);label.style.left=`${(p.x+1)*innerWidth/2}px`;label.style.top=`${(1-p.y)*innerHeight/2}px`;label.hidden=p.z>1}
}
function poseRig(rig,entity,previous,dt,index){
 const a=sim.alpha,x=mix(previous.x,entity.x,a),z=mix(previous.z,entity.z,a),turn=Math.atan2(Math.sin(entity.yaw-previous.yaw),Math.cos(entity.yaw-previous.yaw)),facing=previous.yaw+turn*a;
 const fx=Math.sin(facing),fz=Math.cos(facing),slope=clamp((env.groundY(x+fx,z+fz)-env.groundY(x-fx,z-fz))/2,-.5,.5);
 const target=index===0?(selected?sim.enemy:sim.destination):sim.player;
 rig.setWorld({x,z,yaw:facing,groundY:env.groundY,speed:entity.speed||0,pitch:-Math.atan(slope)-clamp((entity.acceleration||0)*.008,-.07,.07),roll:clamp(-(entity.turnRate||0)*(entity.speed||0)*.012,-.16,.16),lookTarget:target,turnRate:entity.turnRate||0,onFootContact:p=>audio.footstep(p,entity.speed,(index?sim.enemyProfile:sim.profile).radiusCm||60)});
 const state=sim.encounter?.current[index];
 rig.biteT=state?.phase===1?.18:state?.phase===2?.3:state?.phase===3?.08:0;rig.update(dt);
 if(sim.encounter&&state?.phase){const progress=clamp((state.ptick+sim.alpha)/Math.max(1,state.plen),0,1),pulse=state.phase===1?-progress*.13:state.phase===2?.22:(1-progress)*.15;
  rig.creature.rotation.x+=pulse;
  for(const o of rig.objs){const u=o.g.userData;if(u.arm)u.arm.rotation.x+=pulse*4;if(u.tail&&state.move===MOVE.TAIL)u.tail.rotation.y+=Math.sin(progress*Math.PI)*1.1;if(u.sacs&&state.move===MOVE.SPIT)for(const sac of u.sacs)sac.scale.setScalar(1+Math.abs(pulse)*1.5)}
 }
 if(index===1&&entity.dead){rig.creature.rotation.z=1.4;rig.creature.updateMatrixWorld(true);rig.body.geometry.computeBoundingBox();const bounds=new env.T.Box3().setFromObject(rig.body).union(new env.T.Box3().setFromObject(rig.partsG)),bottom=bounds.min.y;rig.creature.position.y+=env.groundY(x,z)+.04-bottom;rig.limbs.visible=false}
 const recent=sim.hits.filter(h=>h.id===index).at(-1),flash=recent?Math.max(0,1-(sim.ticks*.1+sim.alpha*.1-recent.time)/.5):0;
 for(const mat of [rig.skinM,rig.skinM2,rig.boneM])mat.emissive.setRGB(flash*.6,flash*.13,flash*.03);
}
function hud(){
 for(const [prefix,p,profile]of [['player',sim.player,sim.profile],['enemy',sim.enemy,sim.enemyProfile]]){
  for(const [field,max]of [['hp',profile.hp],['stamina',profile.stamina]]){const el=$(`${prefix}-${field}`);el.max=max;el.value=Math.max(0,p[field])}
 }
 $('player-health').textContent=Math.ceil(Math.max(0,sim.player.hp));$('enemy-hud').hidden=!sim.encounter;
 const state=sim.encounter?.current[1];$('enemy-phase').textContent=state?phases[state.phase]:'';
 if(sim.encounter&&shownOutcome!==null){shownOutcome=null;message('Watch the windup · run beyond the boundary to flee')}
 if(sim.encounter&&!$('status').textContent.includes('windup'))message('Watch the windup · run beyond the boundary to flee');
 if(sim.outcome&&sim.outcome!==shownOutcome){shownOutcome=sim.outcome;toastUntil=sim.ticks+50;message({victory:'DNA +12\nA new trace of life. Keep exploring.',death:'Back to the nest…',fled:'Safe for now. The wild creature returns home.'}[sim.outcome])}
 if(sim.ticks>toastUntil&&!sim.encounter&&sim.outcome)message('Explore the first valley');
 $('fade').style.opacity=sim.respawn>0?clamp((2-sim.respawn)*2,0,1):0;
}
function pose(dt=0){rigs.forEach((rig,i)=>poseRig(rig,i?sim.enemy:sim.player,sim.previous[i],sim.paused?0:dt,i))}
function draw(dt=0){
 pose(dt);
 const {T,camera,groundY,renderer,scene,sun,SUN,hU,sky}=env,p=rigs[0].creature.position,c=rigs[0].pts[rigs[0].NS>>1].clone().applyMatrix4(rigs[0].creature.matrixWorld);
 orbitGrace=Math.max(0,orbitGrace-dt);
 if(!sim.paused&&!orbitGrace&&sim.player.speed>.4){const delta=Math.atan2(Math.sin(sim.player.yaw+Math.PI-yaw),Math.cos(sim.player.yaw+Math.PI-yaw));yaw+=delta*(1-Math.exp(-dt*.7))}
 const d=distance*(camera.aspect<.7?1.25:1),cp=Math.cos(pitch);camera.fov=48;
 camera.position.set(c.x+Math.sin(yaw)*cp*d,c.y+Math.sin(pitch)*d,c.z+Math.cos(yaw)*cp*d);
 // Pull the boom in before it crosses a ridge; keep the lens above terrain.
 const desired=camera.position.clone();for(let i=1;i<=32;i++){const t=i/32,p=c.clone().lerp(desired,t);if(p.y<groundY(p.x,p.z)+.65){camera.position.copy(c).lerp(desired,Math.max(.08,(i-1)/32));break}}
 camera.position.y=Math.max(camera.position.y,groundY(camera.position.x,camera.position.z)+.65);camera.lookAt(c);camera.updateProjectionMatrix();sky.position.copy(camera.position);
 sun.position.set(p.x+SUN.x*150,p.y+SUN.y*150,p.z+SUN.z*150);sun.target.position.copy(p);
 const occ=hU.occ.value;for(let k=0;k<8;k++){const i=rigs[0].NC+Math.round(k*(rigs[0].NSP-1)/7),w=rigs[0].pts[i].clone().applyMatrix4(rigs[0].creature.matrixWorld);occ[k].set(w.x,w.y,w.z,rigs[0].RAD[i]*1.05)}
 for(let k=0;k<4;k++){const l=rigs[0].legs[k];if(l)occ[k+8].set(l.ft.position.x,l.ft.position.y,l.ft.position.z,l.w*2.2);else occ[k+8].set(0,-999,0,0)}
 hU.uTime.value=3+(sim.ticks+sim.alpha)*.1;hU.center.value.set(p.x,0,p.z);env.W.p.x=p.x;env.W.p.z=p.z;
 combatGround();targetGround();audio.update(sim,rigs,env,dt);hud();$('damage').replaceChildren();
 for(const hit of sim.hits){const age=sim.ticks*.1+sim.alpha*.1-hit.time;if(age>.9)continue;
  const v=new T.Vector3(hit.x,groundY(hit.x,hit.z)+3+age*1.8,hit.z).project(camera);if(v.z>1)continue;
  const el=document.createElement('span');el.textContent='−'+Math.round(hit.amount);el.className=hit.id===0?'player':'';el.style.cssText=`left:${(v.x+1)*innerWidth/2}px;top:${(1-v.y)*innerHeight/2}px;opacity:${1-age/.9}`;$('damage').append(el);
 }
 renderer.render(scene,camera);
}
async function boot(){
 env=window.__stageEnvironment;
 if(!env){await new Promise(resolve=>addEventListener('load',resolve,{once:true}));env=window.__stageEnvironment}
 if(!env)throw Error('Valley environment unavailable');
 const {T,scene,SUN,W,groundY,obstacles}=env;
 W.p.vis.root.visible=false;for(const npc of W.npcs){npc.vis.root.visible=false;npc.mark.g.visible=false}
 const [partTable,partManifest,combat,enemyTiers]=await Promise.all([json('../studio/parts.json'),json('../studio/parts/manifest.json'),Combat.create(),json('species/garfio-combat.json')]);
 rigs=[];for(let i=0;i<2;i++)rigs.push(await createCreatureRig({T,scene,SUN,partTable,partManifest}));
 if(rigs.some(r=>r.assetFailures.length))throw Error('Creature parts could not be loaded');
 const types=Object.fromEntries(partTable.parts.map(p=>[p.id,p]));let creature=rigs[0].SEEDS.Merodeador;
 const fixture=new URLSearchParams(location.search).get('creature');
 try{if(fixture){const loaded=await json(new URL(fixture,location.href));creature=StudioDocument.parse(loaded.creature||loaded,types).genome}
  else {const saved=localStorage.getItem('cpore.creature.v4');if(saved)creature=StudioDocument.parse(saved,types).genome}
 }catch(error){if(fixture)throw error;message('Saved creature could not be read. Exploring as Merodeador.')}
 const enemy = StudioDocument.parse(await json('species/garfio.json'), types).genome;
 rigs[0].load(creature);rigs[1].load(enemy);$('enemy-name').textContent=enemy.name;
 const nest={x:W.spawn[0],z:W.spawn[1]};
 // Put one wild species on a dry route near the real nest, clear of trunks/rocks.
 let home=null;
 for(let k=0;k<64&&!home;k++){const a=k*Math.PI*2/64,point={x:nest.x+Math.sin(a)*20,z:nest.z+Math.cos(a)*20};
  if(Array.from({length:21},(_,i)=>({x:mix(nest.x,point.x,i/20),z:mix(nest.z,point.z,i/20)})).every(p=>groundY(p.x,p.z)>.5&&!obstacles.some(o=>Math.hypot(o.x-p.x,o.z-p.z)<o.r+1.3)))home=point;
 }
 if(!home)throw Error('No dry creature route near the nest');
 // This wild species fights with its horn and tail. Its author-defined tiers
 // and HP are separate from the studio document; body radius still follows it.
 sim=new StageSimulation({combat,profile:profileFromStudio(creature,partTable),enemyProfile:{...profileFromStudio(rigs[1].G,partTable),...enemyTiers},nest,home,groundY,obstacles});
 yaw=Math.atan2(nest.x-home.x,nest.z-home.z);sim.player.yaw=yaw+Math.PI;
 audio=new StageAudio();sim.onTick=s=>audio.tick(s);controls();audio.bindMenu($);lightEnvironment();marker=makeGroundMesh('#e9cf87',.9);selection=makeGroundMesh('#f5c86d',.9);arena=makeGroundMesh('#efd49c',.42);cone=makeGroundMesh('#ee9b51',.36);
 $('creature-name').textContent=creature.name;message('Your nest is behind you. Something is moving in the meadow.');
 window.Stage={ready:true,simulation:sim,rigs,env,
  frame(dt){pointer.update();sim.advance(dt,timeline||(()=>input()));if(!window.__stageTesting)draw(dt)},
  draw, pose, pause, audio, cameraState:()=>({yaw,pitch,distance}), get selected(){return selected}, setTimeline(fn){timeline=fn},
  snapshot(){return {ticks:sim.ticks,player:{...sim.player},enemy:{...sim.enemy},started:sim.started,outcome:sim.outcome,respawn:sim.respawn,paused:sim.paused,home:sim.home,nest:sim.nest,profile:sim.profile,completed:sim.completed,encounter:sim.encounter?{tick:sim.encounter.tick,current:sim.encounter.current,previous:sim.encounter.previous,alpha:sim.encounter.alpha,log:sim.encounter.exportLog(),hash:sim.encounter.hashes.at(-1)}:null}}
 };
 draw(0);
}
boot().catch(error=>{message('The valley could not open. Reload, or return to Studio.');console.error(error)});
