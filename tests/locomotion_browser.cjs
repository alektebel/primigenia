/* Manual clock, software WebGL, actual shared rig meshes. No continuous render. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const base=process.env.CPORE_STAGE_URL||'http://127.0.0.1:8765';
const out=path.resolve(process.env.CPORE_LOCOMOTION_EVIDENCE||'build/locomotion');
const capture=process.env.CPORE_LOCOMOTION_CAPTURE==='1';
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:720,height:480}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base+'/tests/locomotion.html');await page.waitForFunction(()=>window.Loco?.ready,null,{timeout:90000});
  assert.match(await page.evaluate(()=>Loco.renderer),/SwiftShader/i);
  const results=[];
  for(let index=0;index<7;index++){
   const result=await page.evaluate(index=>{
    const {rig:r,fixtures,insideSupport}=Loco,f=fixtures[index];r.load(f.genome);
    const m=r.locomotion.model,L=m.legLength;
    let x=0,z=0,yaw=0,last=[],contacts=0,maxSlide=0,maxStepSlide=0,stable=0,walkFrames=0,maxExtension=1,transitions=[],lastGait;
    const groundY=(x,z)=>.025*x+.015*z+.12*Math.exp(-((z-2)/.3)**2);
    const tick=(speed,dt,turnRate=0)=>{
     yaw+=turnRate*dt;x+=Math.sin(yaw)*speed*dt;z+=Math.cos(yaw)*speed*dt;
     r.setWorld({x,z,yaw,speed,turnRate,groundY});r.update(dt);
     const s=r.locomotionState,g=s.gait;
     if(lastGait&&g.name!==lastGait)transitions.push({from:lastGait,to:g.name,fr:g.fr});lastGait=g.name;
     const com=r.creature.localToWorld(new THREE.Vector3(m.centerOfMass.x,m.centerOfMass.y,m.centerOfMass.z));
     if(g.staticallyStable){walkFrames++;if(insideSupport(com,s.support))stable++}
     r.legs.forEach((l,j)=>{
      const p=l.ft.getWorldPosition(new THREE.Vector3()),old=last[j];
      if(!l.sw&&old&&!old.swing){maxSlide=Math.max(maxSlide,p.distanceTo(old.p));maxStepSlide=Math.max(maxStepSlide,p.distanceTo(old.plant));if(Math.abs(l.ft.rotation.y-old.yaw)>1e-8)throw Error('stance twist')}
      const plant=!l.sw&&old&&!old.swing?old.plant:p.clone();
      last[j]={p,plant,swing:l.sw,yaw:l.ft.rotation.y};
      if(s.feet[j].contact)contacts++;
      maxExtension=Math.max(maxExtension,l.up.scale.y);
      if(![...p.toArray(),...l.lo.position.toArray(),...r.creature.position.toArray()].every(Number.isFinite))throw Error('nonfinite pose');
     });
    };
    // Walk on a curving slope, cross all transitions in both directions, stop.
    for(let i=0;i<600;i++)tick(Math.sqrt(.18*9.81*L),1/60,.08);
    for(let i=0;i<600;i++)tick(Math.sqrt((.05+3.5*i/599)*9.81*L),1/60,.03);
    for(let i=599;i>=0;i--)tick(Math.sqrt((.05+3.5*i/599)*9.81*L),1/60,-.03);
    tick(0,1/60);const phase=r.phase;for(let i=0;i<60;i++)tick(0,1/60);
    if(r.phase!==phase)throw Error('idle phase advances');
    // Studio Test path uses the same module (a fresh rig has no world pose).
    return {id:f.id,plan:m.bodyPlan,legs:m.legs.length,massKg:m.massKg,legLength:L,centerOfMass:m.centerOfMass,moments:m.moments,neckMoment:m.neckMoment,tailMoment:m.tailMoment,proposal:m.proposal,maxSlide,maxStepSlide,contacts,stable,walkFrames,stableRatio:walkFrames?stable/walkFrames:null,maxExtension,transitions};
   },index);
   assert.equal(result.plan,(await page.evaluate(i=>Loco.fixtures[i].plan,index)));
   assert(result.maxStepSlide<.02,JSON.stringify(result));
   if(result.walkFrames)assert(result.stableRatio>.95,JSON.stringify(result));
   if(result.legs){assert(result.contacts>10);if(result.legs<6){for(const transition of result.transitions){const target=transition.to==='walk'||transition.from==='walk'?.5:transition.to==='trot'||transition.from==='trot'?2:3;assert(Math.abs(transition.fr-target)<.15,JSON.stringify(transition))}}}
   console.log(result.id,JSON.stringify({slide:result.maxStepSlide,stable:result.stableRatio,extension:result.maxExtension,transitions:result.transitions}));results.push(result);
   if(capture){
    const dir=path.join(out,result.id);fs.mkdirSync(dir,{recursive:true});
    const duration=await page.evaluate(index=>{
     const {rig:r,fixtures}=Loco;r.load(fixtures[index].genome);const speed=Math.sqrt(.18*9.81*r.locomotion.model.legLength);
     window.capturePose={x:0,z:0,yaw:0,speed,groundY:()=>0};
     r.setWorld(capturePose);r.update(0);
     // Let contacts and body settle before recording one and a half strides.
     const cycle=r.locomotionState.gait.stride/speed;
     for(let i=0;i<Math.ceil(cycle*120);i++){capturePose.z+=speed/60;r.setWorld(capturePose);r.update(1/60)}
     return cycle*1.5;
    },index);
    const footfalls=[];
    for(let frame=0;frame<24;frame++){
     footfalls.push(await page.evaluate(({dt,id})=>{
      const {rig:r}=Loco;for(let j=0;j<8;j++){capturePose.z+=capturePose.speed*dt/8;r.setWorld(capturePose);r.update(dt/8)}
      const g=r.locomotionState.gait;Loco.render(`${r.G.name}\n${g.name} · Fr ${g.fr.toFixed(2)} · ${capturePose.speed.toFixed(2)} m/s`);
      return {phase:r.phase,stance:r.legs.map(l=>!l.sw)};
     },{dt:duration/24,id:result.id}));
     await page.screenshot({path:path.join(dir,`frame-${String(frame).padStart(2,'0')}.png`),timeout:90000});
    }
    result.capture={frames:24,duration,footfalls};
   }
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({browser:browser.version(),renderer:await page.evaluate(()=>Loco.renderer),results,errors},null,2)+'\n');
  await page.evaluate(()=>Loco.dispose());await page.close();
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
