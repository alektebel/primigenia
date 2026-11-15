/* P3 stage acceptance: real browser rAF -> JS roam -> C/WASM fight -> native replay.
 * Only evidence frames render; no GPU and no wall-clock simulation waits. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const base=process.env.CPORE_STAGE_URL||'http://127.0.0.1:8765';
const out=path.resolve(process.env.CPORE_STAGE_EVIDENCE||'docs/evidence/stage');fs.mkdirSync(out,{recursive:true});
const launch={headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']};
const results=[],evidence=[];
const enemyGenome=JSON.parse(fs.readFileSync('web/stage/species/garfio.json'));
const enemyTiers=JSON.parse(fs.readFileSync('web/stage/species/garfio-combat.json'));
(async()=>{
 const browser=await chromium.launch(launch);
 try{
  async function open(fixture,mobile=false,saved=null){
   const context=await browser.newContext({viewport:mobile?{width:390,height:844}:{width:1280,height:800},hasTouch:mobile,isMobile:mobile,deviceScaleFactor:1});
   const page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.addInitScript(saved=>{
    window.__stageTesting=true;
    // The production rAF callback is driven at an explicit rate. Draws are
    // suppressed by the stage's test flag; simulation/input code is unchanged.
    requestAnimationFrame=callback=>{window.__stageRAF=callback;return 1};
    window.__frameTime=0;
    if(saved)localStorage.setItem('cpore.creature.v4',JSON.stringify(saved));
   },saved);
   await page.goto(base+'/web/stage/'+(fixture?'?creature='+encodeURIComponent('/tests/fixtures/combat/'+fixture):''));
   await page.waitForFunction(()=>window.Stage?.ready,null,{timeout:90000,polling:100});
   assert.deepEqual(await page.evaluate(()=>Stage.rigs[1].G),enemyGenome,'wild creature is Garfio');
   for(const [key,value] of Object.entries(enemyTiers))assert.equal(await page.evaluate(key=>Stage.simulation.enemyProfile[key],key),value,'shared Garfio '+key);
   assert.equal(await page.locator('#enemy-name').innerText(),'Garfio');
   assert.deepEqual(errors,[]);
   return {page,context,errors};
  }
  async function setup(page,attack){
   await page.evaluate(attack=>{
    const S=Stage,s=S.simulation,dx=s.home.x-s.nest.x,dz=s.home.z-s.nest.z,len=Math.hypot(dx,dz);
    // Input transitions are defined in simulation seconds, not render frames.
    S.setTimeline(time=>time<2.5?{move:[dx/len,dz/len]}:attack===3&&time<5.7?{}:{attack});
   },attack);
  }
  async function run(page,fps,until){
   return page.evaluate(({fps,until})=>{
    const s=Stage.simulation;let frames=0;
    while(s.ticks<900&&!s.outcome){
     window.__frameTime+=1000/fps;__stageRAF(__frameTime);frames++;
     if(until==='windup'&&s.encounter?.current[1].phase===1)break;
     const radii=((s.profile.radiusCm||60)+(s.enemyProfile.radiusCm||60))/100;
     const gap=Math.hypot(s.player.x-s.enemy.x,s.player.z-s.enemy.z)-radii;
     if(s.encounter&&gap < -1e-4)throw Error('combat bodies interpenetrate: '+gap);
     // Capture a recent impact while the interpolated bodies touch, rather
     // than stopping at the first ranged or long-reach damage event.
     const a=s.alpha,p=s.previous[0],e=s.previous[1];
     const visualGap=Math.hypot(p.x+(s.player.x-p.x)*a-e.x-(s.enemy.x-e.x)*a,p.z+(s.player.z-p.z)*a-e.z-(s.enemy.z-e.z)*a)-radii;
     if(until==='hit'&&s.hits.some(h=>s.ticks*.1-h.time<.4)&&Math.abs(visualGap)<.05)break;
    }
    return {frames,...Stage.snapshot()};
   },{fps,until});
  }
  for(const fixture of (process.argv.includes('--evidence-only')?[]:fs.readdirSync('tests/fixtures/combat').filter(f=>f.endsWith('.json')).sort())){
   const expected=JSON.parse(fs.readFileSync('tests/fixtures/combat/'+fixture));const runs=[];
   for(const fps of [30,73]){
    const {page,context,errors}=await open(fixture);
    try{
     assert.deepEqual(await page.evaluate(()=>Stage.simulation.profile),expected.expected);
     assert.deepEqual(await page.evaluate(()=>Stage.rigs[0].G),expected.creature);
     const attack=expected.expected.spit?3:0;await setup(page,attack);
     const final=await run(page,fps);
     assert(final.started>0,fixture+' encounter started');assert(final.outcome,fixture+' outcome within 90 seconds');
     const enemyMax=await page.evaluate(()=>Stage.simulation.enemyProfile.hp);
     assert(final.player.hp<expected.expected.hp,fixture+' player damaged');assert(final.enemy.hp<enemyMax,fixture+' enemy damaged');
     const replay=final.completed.at(-1),file=path.join(out,fixture.replace('.json',`-${fps}.log`));fs.writeFileSync(file,replay.log);
     const hashes=execFileSync('build/combat_parity',['--replay',file],{encoding:'utf8'}).trim().split('\n');assert.equal(hashes.at(-1),replay.hash,fixture+' native final hash');
     assert.deepEqual(errors,[]);runs.push(replay);
     results.push({fixture,fps,outcome:final.outcome,ticks:final.ticks,hp:[final.player.hp,final.enemy.hp],finalHash:replay.hash,nativeReplay:true,errors});
     console.log(`PASS ${fixture} ${fps} FPS: ${final.outcome}, HP ${final.player.hp.toFixed(1)}/${final.enemy.hp.toFixed(1)}, native ${replay.hash}`);
    }finally{await context.close()}
   }
   assert.deepEqual(runs[0],runs[1],fixture+' identical encounter log/hash at 30 and 73 rAF FPS');
  }
  // Four representative desktop states, all from one real default-creature duel.
  const {page,context,errors}=await open(null);
  try{
   const start=await page.evaluate(()=>Stage.snapshot());
   await page.screenshot({path:path.join(out,'explore.png'),timeout:90000});
   // Real keyboard controls move the creature and pause with no simulation drift.
   await page.keyboard.down('KeyW');await page.evaluate(()=>{for(let i=0;i<15;i++){__frameTime+=1000/30;__stageRAF(__frameTime)}});await page.keyboard.up('KeyW');
   assert((await page.evaluate(()=>Stage.snapshot())).player.z>start.player.z);
   await page.keyboard.press('Escape');const paused=await page.evaluate(()=>Stage.simulation.ticks);
   await page.evaluate(()=>{__frameTime+=1000;__stageRAF(__frameTime)});assert.equal(await page.evaluate(()=>Stage.simulation.ticks),paused);
   await page.keyboard.press('Escape');
   // Use the exact competent policy from the 150 headless duels. Enemy stats
   // and HP are loaded normally; only player inputs drive the evidence.
   await page.evaluate(async()=>{const {stagePlayerPolicy}=await import('/tests/stage_policy.mjs');
    Stage.setTimeline(()=>stagePlayerPolicy(Stage.simulation));
   });
   await run(page,30,'windup');
   // Orbit through the real mouse control so both creatures and the cone read clearly.
   await page.mouse.move(900,380);await page.mouse.down();await page.mouse.move(1030,410);await page.mouse.up();
   await page.evaluate(()=>Stage.draw());
   assert.equal(await page.evaluate(()=>Stage.simulation.encounter.current[1].phase),1);
   await page.screenshot({path:path.join(out,'fight-windup.png'),timeout:90000});
   await run(page,30,'hit');await page.evaluate(()=>Stage.draw());
   assert(await page.evaluate(()=>Stage.simulation.hits.length>0));
   const contact=await page.evaluate(()=>{
    const s=Stage.simulation,[p,e]=Stage.rigs.map(r=>r.creature.position);
    return {gap:Math.hypot(p.x-e.x,p.z-e.z)-((s.profile.radiusCm||60)+(s.enemyProfile.radiusCm||60))/100,
     radiiCm:[s.profile.radiusCm,s.enemyProfile.radiusCm],hp:[s.player.hp,s.enemy.hp],tick:s.ticks};
   });
   assert(Math.abs(contact.gap)<.05,'evidence bodies touch without penetration: '+JSON.stringify(contact));evidence.push({capture:'fight-hit.png',...contact});
   await page.screenshot({path:path.join(out,'fight-hit.png'),timeout:90000});
   const final=await run(page,30);assert.equal(final.outcome,'victory','honest victory evidence');
   await page.evaluate(()=>{__frameTime+=600;__stageRAF(__frameTime);Stage.draw()});await page.screenshot({path:path.join(out,'victory.png'),timeout:90000});
   assert.match(await page.locator('#status').innerText(),/DNA \+12/);assert(await page.evaluate(()=>Stage.simulation.enemy.dead));
   const log=final.completed.at(-1);fs.writeFileSync(path.join(out,'victory.log'),log.log);
   assert.equal(execFileSync('build/combat_parity',['--replay',path.join(out,'victory.log')],{encoding:'utf8'}).trim().split('\n').at(-1),log.hash);
   evidence.push({capture:'victory.png',outcome:final.outcome,hp:[final.player.hp,final.enemy.hp],finalHash:log.hash,nativeReplay:true});
   const grounded=await page.evaluate(()=>{
    const rig=Stage.rigs[0],groundY=(x,z)=>.04*x+.025*z;
    for(let i=0;i<12;i++){rig.setWorld({x:i*.2,z:0,yaw:.35,speed:2,groundY,pitch:-.04});rig.update(.1)}
    rig.setWorld({x:2.2,z:0,yaw:.35,speed:0,groundY,pitch:-.04});rig.update(.1);
    return rig.legs.map(l=>({error:Math.abs(l.ft.position.y-groundY(l.ft.position.x,l.ft.position.z)),finite:[...l.ft.position.toArray(),...l.lo.position.toArray()].every(Number.isFinite)}));
   });
   assert(grounded.length>0);assert(grounded.every(l=>l.finite&&l.error<.12),JSON.stringify(grounded));
   assert.deepEqual(errors,[]);console.log('PASS golden exploration, windup, hit and natural victory evidence; keyboard and pause');
  }finally{await context.close()}
  // Saved /4 takes the same shared G48 builder; touch stick + pointer buttons.
  const saved=JSON.parse(fs.readFileSync('tests/fixtures/studio/v4-glb-parts.json'));
  const mobile=await open(null,true,saved);
  try{
   const {page}=mobile;assert.deepEqual(await page.evaluate(()=>Stage.rigs[0].G),saved);
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
   const before=await page.evaluate(()=>Stage.snapshot()),pad=await page.locator('#stick').boundingBox(),cdp=await page.context().newCDPSession(page);
   const x=pad.x+pad.width/2,y=pad.y+pad.height/2;
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-35,id:1}]});
   await page.evaluate(()=>{for(let i=0;i<120;i++){__frameTime+=1000/30;__stageRAF(__frameTime)}});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   const after=await page.evaluate(()=>Stage.snapshot());assert(Math.hypot(after.player.x-before.player.x,after.player.z-before.player.z)>.5,'touch movement');
   assert(after.started>0,'touch walk reaches the enemy');
   await page.locator('[data-key=Digit1]').tap();
   await page.evaluate(()=>{__frameTime+=150;__stageRAF(__frameTime)});
   assert(await page.evaluate(()=>Stage.simulation.encounter.log.some(a=>a.id===0&&a.verb===2)),'a quick touch attack survives release before the next tick');
   await page.locator('[data-key=dodge-right]').tap();
   await page.evaluate(()=>{__frameTime+=150;__stageRAF(__frameTime)});
   assert(await page.evaluate(()=>Stage.simulation.encounter.log.some(a=>a.id===0&&a.verb===4&&a.dir===6)),'touch dodge issues a C order');
   // Orbit with a real two-finger touch drag, then let the unmodified enemy close for
   // contact. A side view makes the two different bodies readable on mobile.
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:130,y:300,id:2},{x:230,y:300,id:3}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:250,y:310,id:2},{x:350,y:310,id:3}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await run(page,30,'hit');
   await page.evaluate(()=>Stage.draw());await page.screenshot({path:path.join(out,'mobile-touch.png'),timeout:90000});
   assert.deepEqual(mobile.errors,[]);console.log('PASS 390×844 touch movement, action buttons, saved /4 G48 genome and no overflow');
  }finally{await mobile.context.close()}
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',forcedRafRates:[30,73],enemy:{genome:enemyGenome.name,tiers:enemyTiers},runs:results,evidence},null,2)+'\n');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
