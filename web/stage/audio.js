const clamp=v=>Math.max(0,Math.min(1,Number.isFinite(v)?v:0));
const names=['step-0','step-1','step-2','grass-rustle','wind','meadow','idle','aggro','hurt','death','hit','block','dodge','spit','click'];
const defaults={master:.7,music:.4,sfx:.75,mute:false};
export class StageAudio{
 constructor(){
  this.context=null;this.buffers=new Map();this.active=new Set();this.errors=[];this.steps=0;this.played={};this.paused=false;this.started=0;
  try{this.settings={...defaults,...JSON.parse(localStorage.getItem('cpore.audio')||'{}')}}catch{this.settings={...defaults}}
 }
 async start(){
  if(this.context){if(!this.paused)await this.context.resume();return this.loading}
  const Context=window.AudioContext||window.webkitAudioContext;if(!Context)return;
  this.context=new Context();const c=this.context;
  this.master=c.createGain();this.music=c.createGain();this.sfx=c.createGain();
  this.music.connect(this.master);this.sfx.connect(this.master);this.master.connect(c.destination);this.apply();
  // Context creation/resume happens synchronously inside the first user gesture.
  await c.resume();
  this.loading=Promise.all(names.map(async name=>{
   try{const response=await fetch(new URL(`../../assets/audio/${name}.ogg`,import.meta.url));if(!response.ok)throw Error(`${name}: ${response.status}`);
    this.buffers.set(name,await c.decodeAudioData(await response.arrayBuffer()));
   }catch(error){this.errors.push(String(error))}
  })).then(()=>{
   this.wind=this.play('wind',{loop:true,bus:'music',volume:.12,position:{x:0,y:0,z:0}});
   this.meadow=this.play('meadow',{loop:true,bus:'music',volume:.5,position:{x:0,y:0,z:0}});
   this.rustle=this.play('grass-rustle',{loop:true,volume:0,position:{x:0,y:0,z:0}});
  });return this.loading;
 }
 apply(){if(!this.context)return;for(const bus of ['master','music','sfx'])this[bus].gain.setTargetAtTime(bus==='master'&&(this.settings.mute||this.paused)?0:clamp(Number(this.settings[bus])),this.context.currentTime,.04)}
 setVolume(bus,value){if(!['master','music','sfx','mute'].includes(bus))return;this.settings[bus]=bus==='mute'?!!value:clamp(Number(value));this.apply();try{localStorage.setItem('cpore.audio',JSON.stringify(this.settings))}catch{}}
 setPaused(value){this.paused=value;this.apply();if(this.context){if(value)this.context.suspend();else this.context.resume()}}
 bindMenu($){
  for(const bus of ['master','music','sfx']){const slider=$(`volume-${bus}`);slider.value=clamp(Number(this.settings[bus]));slider.oninput=()=>this.setVolume(bus,Number(slider.value))}
  $('audio-mute').checked=!!this.settings.mute;$('audio-mute').onchange=e=>this.setVolume('mute',e.target.checked);
  document.addEventListener('click',e=>{if(e.target.closest('button,a,input'))this.play('click',{volume:.2})});
 }
 play(name,{position=null,volume=.5,rate=1,loop=false,bus='sfx'}={}){
  if(!this.context||!this.buffers.has(name))return null;
  const c=this.context,source=c.createBufferSource(),gain=c.createGain();source.buffer=this.buffers.get(name);source.playbackRate.value=rate;source.loop=loop;gain.gain.value=volume;source.connect(gain);
  let panner=null;if(position){panner=c.createPanner();panner.panningModel='HRTF';panner.distanceModel='inverse';panner.refDistance=5;panner.maxDistance=100;panner.rolloffFactor=.8;gain.connect(panner);panner.connect(this[bus]);this.position(panner,position)}else gain.connect(this[bus]);
  const voice={source,gain,panner};this.active.add(voice);source.onended=()=>{source.disconnect();gain.disconnect();panner?.disconnect();this.active.delete(voice)};source.start();this.played[name]=(this.played[name]||0)+1;return voice;
 }
 position(node,p){if(node)node.setPosition(p.x,p.y||0,p.z)}
 footstep(p,speed,radiusCm){if(this.paused||speed<.15)return;const size=Math.max(.5,radiusCm/100);this.play(`step-${this.steps++%3}`,{position:p,volume:Math.min(.65,.12+speed*.055)*Math.min(1.5,Math.sqrt(size)),rate:Math.max(.65,Math.min(1.4,1.15/Math.sqrt(size)))});}
 tick(sim){
  if(this.paused)return;
  const entities=[sim.player,sim.enemy],profiles=[sim.profile,sim.enemyProfile];
  const cry=(name,id,volume=.5)=>{const p=entities[id];if(!p)return;this.play(name,{position:p,volume,rate:Math.max(.6,Math.min(1.6,1.25/Math.sqrt((profiles[id].radiusCm||60)/100)))})};
  if(sim.started>this.started){cry('aggro',1,.7);this.started=sim.started}
  for(const event of sim.events){if(event.type===1){cry('hurt',event.b,.35);this.play('hit',{position:entities[event.b],volume:.5})}
   if(event.type===2||event.type===3)this.play('block',{position:entities[event.b],volume:.5});
   if(event.type===4)this.play('dodge',{position:entities[event.b],volume:.35});
   if(event.type===7)cry('death',event.b,.7);
  }
  for(let i=0;i<2;i++){
   const p=entities[i];if(p.hp<=0)continue;
   if(!sim.encounter&&p.speed<.1&&(sim.ticks+i*67)%173===0)cry('idle',i,.22);
   const state=sim.encounter?.current[i],old=sim.encounter?.previous[i];
   if(state?.phase===2&&old?.phase!==2&&state.move===3)this.play('spit',{position:p,volume:.4});
   if(state?.phase===2&&old?.phase!==2&&state.move===5)this.play('dodge',{position:p,volume:.3});
  }
 }
 update(sim,rigs,env){
  if(!this.context)return;const c=this.context,p=rigs[0].creature.position,cam=env.camera,forward=new env.T.Vector3();cam.getWorldDirection(forward);
  c.listener.setPosition(cam.position.x,cam.position.y,cam.position.z);c.listener.setOrientation(forward.x,forward.y,forward.z,0,1,0);
  for(const loop of [this.wind,this.meadow,this.rustle])this.position(loop?.panner,p);
  this.wind?.gain.gain.setTargetAtTime(.08+Math.min(.4,Math.max(0,env.groundY(p.x,p.z))*.009),c.currentTime,.3);
  const height=env.groundY(p.x,p.z),slope=Math.abs(env.groundY(p.x+1,p.z)-height)+Math.abs(env.groundY(p.x,p.z+1)-height);
  const grass=height>0&&height<35&&slope<1?1:0;
  this.rustle?.gain.gain.setTargetAtTime(sim.paused?0:grass*Math.min(.26,sim.player.speed*.04),c.currentTime,.15);
 }
 async close(){for(const voice of this.active)voice.source.stop();if(this.context)await this.context.close()}
}
