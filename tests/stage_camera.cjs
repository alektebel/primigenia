/* Camera and fight presentation acceptance, software WebGL and controlled clock. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const base=process.env.CPORE_STAGE_URL||'http://127.0.0.1:8765';
const out=path.resolve(process.env.CPORE_CAMERA_EVIDENCE||'docs/evidence/stage/camera');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({viewport:{width:1280,height:800}}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.addInitScript(()=>{window.__stageTesting=true;requestAnimationFrame=f=>1});
  const open=async()=>{await page.goto(base+'/web/stage/');await page.waitForFunction(()=>window.Stage?.ready,null,{timeout:90000,polling:100})};
  // Frozen pre-change stage at exactly the same spawn, terrain, viewport and yaw.
  let before=null;
  if(process.env.CPORE_CAMERA_BEFORE_REF){
   const original=execFileSync('git',['show',process.env.CPORE_CAMERA_BEFORE_REF+':web/stage/stage.js'],{encoding:'utf8'});
   await page.route('**/web/stage/stage.js',route=>route.fulfill({contentType:'text/javascript',body:'while(!window.__stageEnvironment)await new Promise(r=>setTimeout(r,20));\n'+original}));
   await open();before=await page.evaluate(()=>({nest:Stage.snapshot().nest,camera:Stage.cameraState()}));
   await page.screenshot({path:path.join(out,'before.png'),timeout:90000});
   await page.unroute('**/web/stage/stage.js');
  }
  await open();
  if(before)assert.deepEqual(await page.evaluate(()=>Stage.snapshot().nest),before.nest);
  const initial=await page.evaluate(()=>{
   const {camera,T}=Stage.env,forward=new T.Vector3();camera.getWorldDirection(forward);
   const horizon=new T.Vector3(camera.position.x+forward.x*10000,camera.position.y,camera.position.z+forward.z*10000).project(camera);
   return {...Stage.cameraState(),opticalPitch:Math.asin(-forward.y),horizonFraction:(1-horizon.y)/2,position:camera.position.toArray()};
  });
  assert(initial.opticalPitch>=12*Math.PI/180&&initial.opticalPitch<=18*Math.PI/180,JSON.stringify(initial));
  assert(initial.horizonFraction>0&&initial.horizonFraction<1/3,JSON.stringify(initial));
  assert(initial.distance/initial.height>=5&&initial.distance/initial.height<=7);
  await page.screenshot({path:path.join(out,'default.png'),timeout:90000});
  // Flat-ground projection uses the real camera module and Three perspective math.
  const flat=await page.evaluate(async()=>{const {ChaseCamera}=await import('/web/stage/camera.js');const s=new ChaseCamera({height:3}).update({player:{x:0,z:0,yaw:0,speed:0},groundY:()=>0,aspect:1.6});const c=new Stage.env.T.PerspectiveCamera(48,1.6,.1,1000);c.position.set(...['x','y','z'].map(k=>s.position[k]));c.lookAt(s.target.x,s.target.y,s.target.z);c.updateMatrixWorld();const v=new Stage.env.T.Vector3(0,c.position.y,10000).project(c);return {pitch:s.pitch,horizon:(1-v.y)/2}});
  assert(flat.horizon>0&&flat.horizon<=1/3);
  await page.mouse.move(900,400);await page.mouse.wheel(0,10000);await page.evaluate(()=>Stage.draw());
  const wide=await page.evaluate(()=>Stage.cameraState());assert(wide.pitch>.6);assert.equal(wide.distance,wide.maxDistance);
  await page.screenshot({path:path.join(out,'zoomed-out.png'),timeout:90000});
  const terrain=await page.evaluate(async()=>{
   const {ChaseCamera}=await import('/web/stage/camera.js'),c=new ChaseCamera({height:3}),g=(x,z)=>z<-5?20:0;
   const shot=c.update({player:{x:0,z:0,yaw:0,speed:0},groundY:g,aspect:1.6});return {...shot,clearance:shot.position.y-g(shot.position.x,shot.position.z)};
  });assert(terrain.clearance>=.65);assert(terrain.actualDistance<terrain.distance);
  await page.evaluate(()=>{Stage.chase.zoom(-1e4);Stage.chase.zoom(Stage.chase.height*6-Stage.chase.distance);const s=Stage.simulation;Stage.setTimeline(()=>({attack:0}));for(let i=0;i<300&&!s.encounter;i++)Stage.frame(.1);Stage.draw();});
  assert(await page.evaluate(()=>!!Stage.simulation.encounter));
  const fight=await page.evaluate(()=>{const s=Stage.simulation,c=Stage.env.camera,T=Stage.env.T;return {distance:c.position.distanceTo(new T.Vector3(Stage.chase.target.x,Stage.chase.target.y,Stage.chase.target.z)),target:{...Stage.chase.target},midpoint:{x:(Stage.rigs[0].creature.position.x+Stage.rigs[1].creature.position.x)/2,z:(Stage.rigs[0].creature.position.z+Stage.rigs[1].creature.position.z)/2},actors:Stage.rigs.map(r=>r.creature.position).map(p=>new T.Vector3(p.x,Stage.env.groundY(p.x,p.z)+Stage.chase.height*.6,p.z).project(c).toArray())}});
  assert(Math.abs(fight.target.x-fight.midpoint.x)<.01&&Math.abs(fight.target.z-fight.midpoint.z)<.01);
  for(const p of fight.actors)assert(Math.abs(p[0])<.85&&Math.abs(p[1])<.9&&Math.abs(p[2])<1,JSON.stringify(fight));
  assert(fight.distance>initial.distance);
  assert(Math.abs(fight.actors[0][0]-fight.actors[1][0])>.1,'opponents separate across the screen');
  const enemyScreen=await page.evaluate(()=>{const r=Stage.rigs[1],p=r.pts[r.NS>>1].clone().applyMatrix4(r.creature.matrixWorld).project(Stage.env.camera);return {x:(p.x+1)*innerWidth/2,y:(1-p.y)*innerHeight/2}});
  await page.mouse.click(enemyScreen.x,enemyScreen.y);assert(await page.evaluate(()=>Stage.selected));await page.evaluate(()=>Stage.draw());
  assert(await page.locator('#selected-name').isVisible());assert((await page.locator('#selected-name').innerText()).includes('Garfio'));
  assert.equal(await page.locator('#selected-hp').evaluate(el=>el.value),await page.evaluate(()=>Stage.simulation.enemy.hp));
  await page.screenshot({path:path.join(out,'fight-framing.png'),timeout:90000});
  // Real C windup + cone and stage pose hooks; each move also gets its own tell.
  const tells=await page.evaluate(async()=>{const {moveTell}=await import('/web/stage/feedback.js'),s=Stage.simulation;for(let i=0;i<100&&s.encounter?.current[1].phase!==1;i++)Stage.frame(.1);Stage.feedback.update(1);Stage.draw();return {windup:Stage.rigs[1].creature.userData.windup,cone:Stage.cone.visible,move:Stage.cone.userData.move,colors:[0,1,3,4].map(m=>moveTell(m).color)}});
  const allTells=await page.evaluate(()=>{
   const e=Stage.simulation.encounter,original=e.current[1],render=Stage.env.renderer.render,result=[];
   Stage.env.renderer.render=()=>{};
   try{for(const move of [0,1,3,4]){e.current[1]={...original,move,phase:1,ptick:5,plen:10};Stage.draw();result.push({move,hook:Stage.rigs[1].creature.userData.windup,cone:Stage.cone.visible,color:Stage.cone.material.color.getHexString(),rotation:Stage.rigs[1].creature.rotation.x})}}
   finally{e.current[1]=original;Stage.env.renderer.render=render;Stage.pose()}
   return result;
  });
  for(const tell of allTells){assert.equal(tell.hook.move,tell.move);assert(tell.cone&&tell.hook.crouch>0)}
  assert.equal(new Set(allTells.map(t=>t.rotation)).size,4);
  assert(tells.windup&&tells.cone);assert.equal(tells.windup.move,tells.move);assert.equal(new Set(tells.colors).size,4);
  await page.screenshot({path:path.join(out,'windup.png'),timeout:90000});
  const impact=await page.evaluate(()=>{const s=Stage.simulation;for(let i=0;i<200&&!Stage.feedback.frozen&&s.encounter;i++)Stage.frame(.1);Stage.draw();return {stop:Stage.feedback.frozen,shake:Stage.feedback.shake,hits:s.hits.length,damage:document.getElementById('damage').textContent,flashes:Stage.rigs.map(r=>r.skinM.emissive.toArray())}});
  assert(impact.stop&&impact.shake>0&&impact.hits>0&&impact.damage.includes('−'),JSON.stringify(impact));
  assert(impact.flashes.some(c=>c[0]>.5),'hit creature flashes during hit-stop');
  // Freeze lasts 45 ms regardless of world tick rate, then rendering resumes.
  await page.evaluate(()=>Stage.frame(.05));assert.equal(await page.evaluate(()=>Stage.feedback.frozen),false);
  await page.waitForFunction(()=>Stage.audio.buffers.size===15,null,{timeout:30000});
  const defensive=await page.evaluate(()=>{
   const s=Stage.simulation,previous={...Stage.audio.played};
   s.onTick({...s,events:[{type:2,b:0},{type:4,b:1}]});Stage.draw();
   const flashes=Stage.rigs.map(r=>r.skinM.emissive.toArray());
   const blockCount=Stage.audio.played.block;s.onTick({...s,events:[{type:3,b:0}]});
   return {guard:document.querySelector('#damage .guard')?.textContent,dodge:document.querySelector('#damage .dodge')?.textContent,flashes,block:Stage.audio.played.block-(previous.block||0),dodgeSound:Stage.audio.played.dodge-(previous.dodge||0),brokenGuardNoSuccessCue:blockCount===Stage.audio.played.block};
  });
  assert.equal(defensive.guard,'GUARDED');assert.equal(defensive.dodge,'DODGED');
  assert(defensive.flashes[0][2]>.5&&defensive.flashes[1][1]>.5);
  assert.equal(defensive.block,1);assert.equal(defensive.dodgeSound,1);assert(defensive.brokenGuardNoSuccessCue);
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader',before,initial,flat,wide,terrain,fight,tells,allTells,impact,defensive,errors},null,2)+'\n');
  console.log('PASS default horizon and pitch, scaled zoom, terrain collision, fight framing, windup, hit-stop, shake and defensive labels');
  await context.close();
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
