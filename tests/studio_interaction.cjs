const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
// Optional development dependency: npm install --prefix /tmp/cpore-browser playwright
// Run with the repository served at CPORE_STUDIO_URL (default localhost:8765).
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const artifacts=process.env.CPORE_ARTIFACT_DIR||'/tmp/cpore-studio-evidence';
fs.mkdirSync(artifacts,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 let page=await browser.newPage({viewport:{width:1280,height:800}});const errors=[],checks=[];
 const watch=p=>{p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(m.text())})};watch(page);
 const check=(c,n)=>{assert(c,n);checks.push(n);console.log('PASS',n)};
 const settle=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 await page.goto(base+'/web/studio/index.html#preset=Coralino',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>!!window.CreatureStudio);
 await page.evaluate(()=>{const g=CreatureStudio.genome();g.legs.stride=0;CreatureStudio.load(g)});await settle();
 await page.locator('#placeGrowth').click();
 const before=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
 let point=null,changed;
 for(const [x,y]of [[420,380],[480,360],[380,410],[500,420],[350,380]]){
   await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+35,y-10,{steps:3});await page.mouse.up();
   changed=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
   if(before!==changed){point=[x,y];break}
 }
 check(!!point,'pointer drag changes surface attachment');
 await page.locator('#undo').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===before,'one undo restores entire drag');
 await page.locator('#redo').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===changed,'redo restores placed growth');
 await page.mouse.move(...point);await page.mouse.down();await page.mouse.move(point[0]+20,point[1]-10);
 await page.keyboard.press('Escape');await page.mouse.up();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===changed,'Escape cancels pointer transaction');
 const start=await page.evaluate(()=>CreatureStudio.diagnostics().geometryCount);
 for(let i=0;i<8;i++){await page.locator('[data-growth-action="vary"]').click();await settle()}
 check(await page.evaluate(()=>CreatureStudio.diagnostics().geometryCount)===start,'repeated variants retain stable geometry allocation count');
 // Independent region authoring: UI selection does not mutate the document.
 const initialRegion=await page.evaluate(()=>CreatureStudio.genome().regions[0]);
 await page.locator('[data-growth-action="add"]').click();await settle();
 const secondId=await page.evaluate(()=>CreatureStudio.diagnostics().selectedRegionId);
 check(await page.evaluate(()=>CreatureStudio.genome().regions.length)===2,'add creates a second independent region');
 await page.locator('#s-growth-2').click();
 await page.locator('#s-growthSurface-1').click();
 const slider=async(id,value)=>{await page.locator('#r-'+id).fill(String(value));await page.locator('#r-'+id).dispatchEvent('change');await settle()};
 await slider('growthLength',.65);await slider('growthCount',4);await slider('growthAngle',.9);
 check(await page.evaluate(first=>JSON.stringify(CreatureStudio.genome().regions[0])===JSON.stringify(first),initialRegion),'second region edits preserve the first recipe');
 const multi=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
 await page.locator(`[data-region="${initialRegion.id}"]`).click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===multi,'selection is editor state and does not change saved design');
 const builds=await page.evaluate(()=>CreatureStudio.diagnostics());
 await page.locator('[data-growth-action="vary"]').click();await settle();
 const afterVariant=await page.evaluate(()=>CreatureStudio.diagnostics());
 check(afterVariant.growthBuilds===builds.growthBuilds+1&&afterVariant.regions.find(r=>r.id===secondId).builds===builds.regions.find(r=>r.id===secondId).builds,'only the changed region regenerates geometry');
 const buildCount=afterVariant.growthBuilds;
 await slider('growthPos',.45);await slider('growthAngle',.65);
 check(await page.evaluate(()=>CreatureStudio.diagnostics().growthBuilds)===buildCount,'surface placement reuses all region geometry');
 const beforeDuplicate=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
 await page.locator('[data-growth-action="duplicate"]').click();await settle();
 const duplicate=await page.evaluate(()=>CreatureStudio.genome());
 const {id:originalId,...originalShape}=duplicate.regions[0],{id:copyId,...copyShape}=duplicate.regions[2];
 check(copyId!==originalId&&JSON.stringify(originalShape)===JSON.stringify(copyShape),'duplicate preserves shape with a new stable id');
 await page.locator('#undo').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===beforeDuplicate,'undo removes only the duplicate');
 await page.locator('#redo').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===JSON.stringify(duplicate),'redo restores the same duplicate id and recipe');
 await page.locator(`[data-region="${copyId}"]`).click();
 await page.locator('[data-growth-action="delete"]').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===beforeDuplicate,'delete removes only the selected region');
 await page.locator('#undo').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===JSON.stringify(duplicate),'delete undo restores all region recipes');
 await page.locator('#redo').click();await settle();
 await page.locator(`[data-region="${secondId}"]`).click();
 await page.locator('#s-growthMirror-0').click();await settle();
 check(await page.evaluate(id=>{const g=CreatureStudio.genome();return g.regions[0].mirror&&!g.regions.find(r=>r.id===id).mirror},secondId),'symmetry changes only the selected region');
 if(await page.locator('#placeGrowth').getAttribute('aria-pressed')!=='true')await page.locator('#placeGrowth').click();
 await page.locator('#gl').focus();const beforeKey=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
 await page.keyboard.press('ArrowRight');await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))!==beforeKey,'keyboard placement edits the selected region');
 await page.locator('#undo').click();await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===beforeKey,'keyboard placement is undoable');
 const savedMulti=await page.evaluate(()=>CreatureStudio.genome());
 await page.evaluate(g=>CreatureStudio.load(g),savedMulti);await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===JSON.stringify(savedMulti),'multiple regions reload exactly');
 await page.locator('[data-p="Coralino"]').click();await settle();
 await page.locator('#s-growth-2').click();await settle();
 check(await page.evaluate(()=>CreatureStudio.genome().regions[0].family)==='plates','plate family rendered');
 await page.locator('[data-p="Abisal"]').click();await settle();
 check(await page.evaluate(()=>CreatureStudio.genome().regions[0].family)==='tendrils','tendril family rendered');
 // Capture a fresh desktop context after the interaction stress sequence.
 await page.close();page=await browser.newPage({viewport:{width:1280,height:800}});watch(page);
 await page.goto(base+'/web/studio/index.html#g='+Buffer.from(JSON.stringify(savedMulti)).toString('base64'),{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>!!window.CreatureStudio);await settle();
 await page.screenshot({timeout:120000,path:path.join(artifacts,'regions-desktop.png')});console.log('Regions captured');
 // Independent contexts also verify mobile startup and avoid a software-WebGL
 // capture failure observed when resizing a long-running desktop context.
 const mobileGenome=savedMulti;
 await page.close();page=await browser.newPage({viewport:{width:390,height:844}});watch(page);
 await page.goto(base+'/web/studio/index.html#g='+Buffer.from(JSON.stringify(mobileGenome)).toString('base64'),{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>!!window.CreatureStudio);await settle();
 check(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()))===JSON.stringify(mobileGenome),'shared multi-region document survives mobile startup');
 await page.locator('#bench').evaluate(el=>el.scrollTop=0);
 check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile no horizontal overflow');
 await page.locator('#r-growthLength').evaluate(el=>el.scrollIntoView());
 check(await page.locator('#gl').evaluate(el=>{const r=el.getBoundingClientRect();return r.top>=0&&r.bottom<=innerHeight}),'mobile creature remains visible while editing lower controls');
 await page.locator('#bench').evaluate(el=>el.scrollTop=0);
 await page.screenshot({timeout:120000,path:path.join(artifacts,'regions-mobile.png')});console.log('Mobile captured');
 check(errors.length===0,'no shader or runtime errors');
 await page.goto(base+'/web/studio/test.html',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>document.querySelector('#out').textContent!=='running',null,{timeout:60000});
 const result=await page.locator('#out').innerText();check(result.startsWith('ALL OK'),'all existing and extended genome regression checks');
 check(errors.length===0,'regression page has no runtime errors');
 fs.writeFileSync(path.join(artifacts,'results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',checks,errors,regressions:result},null,2));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
