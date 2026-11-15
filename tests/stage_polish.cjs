/* Input acceptance and planted-foot measurement. Render only evidence frames. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const out=path.resolve(process.env.CPORE_STAGE_POLISH_EVIDENCE||'docs/evidence/stage/polish');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({viewport:{width:1280,height:800},deviceScaleFactor:1});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.addInitScript(()=>{window.__stageTesting=true;requestAnimationFrame=callback=>{window.__stageRAF=callback;return 1}});
  await page.goto('http://127.0.0.1:8765/web/stage/');
  await page.waitForFunction(()=>window.Stage?.ready,null,{timeout:90000,polling:100});
  assert.equal(await page.evaluate(()=>Stage.audio.context),null,'no audio context before a gesture');
  const project=point=>page.evaluate(point=>{const p=new Stage.env.T.Vector3(point.x,Stage.env.groundY(point.x,point.z),point.z).project(Stage.env.camera);return {x:(p.x+1)*innerWidth/2,y:(1-p.y)*innerHeight/2}},point);
  const advance=seconds=>page.evaluate(seconds=>{for(let i=0;i<Math.round(seconds*30);i++)Stage.frame(1/30)},seconds);
  const start=await page.evaluate(()=>Stage.snapshot());
  // Keep the pointer journey independent of the new 28 m predator sight.
  // Reset through the C setup API; natural hostility is tested in stage_play.
  await page.evaluate(()=>{const s=Stage.simulation;window.__polishSetup=structuredClone(s.world.setup);s.world.reset({...s.world.setup,wild:[{...s.world.setup.wild[0],x:150,z:150,home:{x:150,z:150}}]});s.sync();s.previous=[{...s.player},{...s.enemy}];});
  // Walk a short clear part of the real nest-to-home route (away from aggro).
  const target={x:start.nest.x+(start.home.x-start.nest.x)*.22,z:start.nest.z+(start.home.z-start.nest.z)*.22};
  const screen=await project(target);await page.mouse.click(screen.x,screen.y);
  const chosen=await page.evaluate(()=>({...Stage.simulation.destination}));assert(Math.hypot(chosen.x-target.x,chosen.z-target.z)<.02);
  await page.evaluate(()=>Stage.draw());await page.screenshot({path:path.join(out,'click-marker.png'),timeout:90000});
  await advance(3);
  const arrived=await page.evaluate(()=>({...Stage.simulation.player}));const arrivalError=Math.hypot(arrived.x-target.x,arrived.z-target.z);assert(arrivalError<.25,`click arrival ${arrivalError}`);
  // Holding repicks the ground every frame, including after the pointer moves.
  const next={x:start.nest.x+(start.home.x-start.nest.x)*.4,z:start.nest.z+(start.home.z-start.nest.z)*.4};
  const s2=await project(next);await page.mouse.move(s2.x,s2.y);await page.mouse.down();await advance(.6);
  const heldA=await page.evaluate(()=>({...Stage.simulation.destination}));
  await page.mouse.move(s2.x+65,s2.y+15);await advance(.6);
  const heldB=await page.evaluate(()=>({...Stage.simulation.destination}));await page.mouse.up();
  assert(Math.hypot(heldA.x-heldB.x,heldA.z-heldB.z)>.5,'hold follows a moving pointer');
  const following=await page.evaluate(()=>({...Stage.simulation.player}));assert(Math.hypot(following.x-arrived.x,following.z-arrived.z)>.5);
  // Select using an actual ray into Garfio's visible anatomy.
  await page.evaluate(()=>{const s=Stage.simulation;s.world.reset(window.__polishSetup);s.encounter=null;s.sync();s.destination=null;s.pendingAttack=null;s.previous=[{...s.player},{...s.enemy}];Stage.draw()});
  const enemyScreen=await page.evaluate(()=>{const r=Stage.rigs[1],p=r.pts[Math.floor(r.NS*.6)].clone().applyMatrix4(r.creature.matrixWorld).project(Stage.env.camera);return {x:(p.x+1)*innerWidth/2,y:(1-p.y)*innerHeight/2}});
  await page.mouse.click(enemyScreen.x,enemyScreen.y);assert(await page.evaluate(()=>Stage.selected),'enemy selected');
  await page.evaluate(()=>Stage.draw());await page.screenshot({path:path.join(out,'selection-ring.png'),timeout:90000});
  await page.keyboard.press('Digit1');await advance(12);
  assert(await page.evaluate(()=>Stage.simulation.started>0),'selected action approaches');
  assert(await page.evaluate(()=>[Stage.simulation.encounter,Stage.simulation.lastEncounter].some(e=>e?.log.some(a=>a.id===0&&a.verb===2))),'selected action attacks in C');
  await page.waitForFunction(()=>Stage.audio.buffers.size===15,null,{timeout:30000,polling:100});
  assert.deepEqual(await page.evaluate(()=>Stage.audio.errors),[]);
  const audio=await page.evaluate(()=>({state:Stage.audio.context.state,buffers:Stage.audio.buffers.size,worldPanners:[Stage.audio.wind,Stage.audio.meadow,Stage.audio.rustle].every(v=>v?.panner),buses:['master','music','sfx'].every(k=>!!Stage.audio[k])}));assert(audio.worldPanners&&audio.buses);assert.equal(audio.state,'running');
  await page.keyboard.press('Escape');await page.locator('#volume-master').fill('0.4');await page.locator('#audio-mute').check();
  assert.equal(await page.evaluate(()=>Stage.audio.settings.master),.4);assert.equal(await page.evaluate(()=>Stage.audio.settings.mute),true);
  await page.locator('#audio-mute').uncheck();await page.locator('#resume').click();
  // Desktop camera controls: left input never orbits; right/middle do, zoom clamps.
  const cameraBefore=await page.evaluate(()=>Stage.cameraState());
  await page.mouse.move(900,450);await page.mouse.down({button:'right'});await page.mouse.move(960,470);await page.mouse.up({button:'right'});
  const cameraAfter=await page.evaluate(()=>Stage.cameraState());assert(Math.abs(cameraAfter.yaw-cameraBefore.yaw)>.2);
  await page.mouse.down({button:'middle'});await page.mouse.move(930,460);await page.mouse.up({button:'middle'});
  assert.notEqual((await page.evaluate(()=>Stage.cameraState())).yaw,cameraAfter.yaw);
  await page.mouse.wheel(0,10000);assert.equal((await page.evaluate(()=>Stage.cameraState())).distance,30);
  await page.mouse.wheel(0,-10000);assert.equal((await page.evaluate(()=>Stage.cameraState())).distance,8);
  await page.mouse.wheel(0,900);
  // Test real shared rig IK/foot meshes on a curving slope, without rendering.
  const feet=await page.evaluate(()=>{
   const r=Stage.rigs[0],groundY=(x,z)=>.025*x+.015*z;let last=[],max=0,samples=0,contacts=0;
   for(let i=0;i<240;i++){
    const t=i/60,a=t*.6,x=4*Math.sin(a),z=4*(1-Math.cos(a));
    r.setWorld({x,z,yaw:Math.PI/2-a,speed:2.4,groundY,pitch:-.025,onFootContact:()=>contacts++});r.update(1/60);
    r.legs.forEach((l,j)=>{if(!l.sw&&last[j]&&!last[j].swing){max=Math.max(max,l.ft.position.distanceTo(last[j].p));samples++}if(!l.sw&&last[j]&&!last[j].swing&&Math.abs(l.ft.rotation.y-last[j].yaw)>.001)throw Error('stance foot twists');last[j]={p:l.ft.position.clone(),swing:l.sw,yaw:l.ft.rotation.y}});
   }
   const movingPhase=r.phase;
   for(let i=0;i<60;i++){r.update(1/60)}
   return {maxStanceDisplacement:max,samples,contacts,phaseAtStop:movingPhase,phaseAfterStationary:r.phase,legs:r.legs.length};
  });
  assert(feet.samples>100&&feet.contacts>0);assert(feet.maxStanceDisplacement<.03,JSON.stringify(feet));assert.equal(feet.phaseAtStop,feet.phaseAfterStationary,'phase follows displacement, not time');
  // Six rendered frames of actual free-roam curved movement on the real valley.
  await page.evaluate(()=>{const s=Stage.simulation;s.destination=null;s.pendingAttack=null;s.world.reset({...s.world.setup,wild:[{...s.world.setup.wild[0],x:150,z:150,home:{x:150,z:150}}]});s.encounter=null;s.sync();s.previous=[{...s.player},{...s.enemy}];Stage.setTimeline(t=>({move:[Math.sin(t*.6),Math.cos(t*.6)]}))});
  const curve=[];
  for(let i=0;i<6;i++){await page.evaluate(()=>{for(let f=0;f<12;f++){Stage.frame(1/30);Stage.pose(1/30)}Stage.draw(0)});curve.push(await page.evaluate(()=>({...Stage.simulation.player})));await page.screenshot({path:path.join(out,`curve-${i+1}.png`),timeout:90000})}
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader',arrivalError,heldDestinations:[heldA,heldB],audio,feet,curve,errors},null,2)+'\n');
  await context.close();
  const mobileContext=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const mobile=await mobileContext.newPage();mobile.on('pageerror',e=>errors.push(e.message));
  await mobile.addInitScript(()=>{window.__stageTesting=true;requestAnimationFrame=callback=>{window.__stageRAF=callback;return 1}});
  await mobile.goto('http://127.0.0.1:8765/web/stage/');await mobile.waitForFunction(()=>window.Stage?.ready,null,{timeout:90000,polling:100});
  const tapTarget=await mobile.evaluate(()=>{const s=Stage.simulation,p=new Stage.env.T.Vector3(s.nest.x+(s.home.x-s.nest.x)*.18,0,s.nest.z+(s.home.z-s.nest.z)*.18);p.y=Stage.env.groundY(p.x,p.z);p.project(Stage.env.camera);return {x:(p.x+1)*innerWidth/2,y:(1-p.y)*innerHeight/2}});
  await mobile.touchscreen.tap(tapTarget.x,tapTarget.y);assert(await mobile.evaluate(()=>!!Stage.simulation.destination));
  const cdp=await mobileContext.newCDPSession(mobile);
  const touch=(type,points)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});
  await touch('touchStart',[{x:tapTarget.x,y:tapTarget.y,id:1}]);
  await mobile.evaluate(()=>{for(let i=0;i<20;i++)Stage.frame(1/30)});
  const a=await mobile.evaluate(()=>({...Stage.simulation.destination}));
  await touch('touchMove',[{x:tapTarget.x+35,y:tapTarget.y+10,id:1}]);
  await mobile.evaluate(()=>{for(let i=0;i<20;i++)Stage.frame(1/30)});
  const b=await mobile.evaluate(()=>({...Stage.simulation.destination}));assert(Math.hypot(a.x-b.x,a.z-b.z)>.3);
  await touch('touchEnd',[]);
  const mobileCamera=await mobile.evaluate(()=>Stage.cameraState());
  await touch('touchStart',[{x:100,y:330,id:2},{x:210,y:330,id:3}]);
  await touch('touchMove',[{x:130,y:350,id:2},{x:270,y:350,id:3}]);
  await touch('touchEnd',[]);
  const mobileAfter=await mobile.evaluate(()=>Stage.cameraState());assert.notEqual(mobileCamera.yaw,mobileAfter.yaw);assert(mobileAfter.distance<mobileCamera.distance,'pinch zoom');
  await mobile.locator('#pause').tap();
  assert(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile pause menu fits');
  const bounds=await mobile.locator('#audio-settings').boundingBox();assert(bounds.x>=0&&bounds.x+bounds.width<=390,'audio settings fit');
  await mobile.screenshot({path:path.join(out,'mobile-pause.png'),timeout:90000});
  await mobile.locator('#resume').tap();
  fs.writeFileSync(path.join(out,'touch-results.json'),JSON.stringify({tap:true,holdDestinations:[a,b],cameraBefore:mobileCamera,cameraAfter:mobileAfter,pauseFits:true,errors},null,2)+'\n');
  assert.deepEqual(errors,[]);await mobileContext.close();
  console.log('PASS pointer click/hold, selection/approach/attack, planted feet, gesture audio graph and pause volumes');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
