const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const artifacts=process.env.CPORE_ARTIFACT_DIR||path.resolve('docs/evidence');
fs.mkdirSync(artifacts,{recursive:true});
const launch={headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']};
(async()=>{const browser=await chromium.launch(launch);const errors=[];try{
 const page=await browser.newPage({viewport:{width:1280,height:800}});page.on('pageerror',e=>errors.push(e.message));
 await page.goto(base+'/web/studio/#preset=Merodeador');await page.waitForFunction(()=>window.CreatureStudio?.ready,{timeout:90000});
 const diagnostics=await page.evaluate(()=>CreatureStudio.diagnostics());assert.equal(diagnostics.loadedGLBs,require('../web/studio/parts.json').parts.filter(p=>p.source==='glb').length);assert.deepEqual(diagnostics.assetFailures,[]);
 await page.addScriptTag({url:base+'/web/studio/contracts.js'});
 const fixtures=[1,2,3].map(v=>JSON.parse(fs.readFileSync(`tests/fixtures/studio/v${v}.json`)));
 const result=await page.evaluate(fixtures=>studioContracts(CreatureStudio,fixtures),fixtures);console.log('PASS',result.checks.length,'contracts;',result.placements,'part/preset placements; maximum root distance',result.maxRootDistance);
 await page.evaluate(()=>CreatureStudio.preset('Merodeador'));
 const snap=()=>page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
 console.log('PASS catalog loading; starting gestures');
 const before=await snap();await page.locator('#name').fill('Prueba Ñ 🦎 &lt;');await page.locator('#name').blur();const renamed=await snap();assert.notEqual(renamed,before);assert.equal(JSON.stringify(JSON.parse(await page.locator('#json').inputValue())),renamed);
 await page.locator('#undo').click();assert.equal(await snap(),before);await page.locator('#redo').click();assert.equal(await snap(),renamed);
 await page.locator('[data-growth-action=add]').click();const initial=await snap();
 await page.locator('[data-growth-action=duplicate]').click();const duplicate=await snap();assert.equal(JSON.parse(duplicate).regions.length,2);
 await page.locator('#undo').click();assert.equal(await snap(),initial);await page.locator('#redo').click();assert.equal(await snap(),duplicate);
 await page.locator('[data-region=region-2]').click();await page.locator('[data-growth-action=delete]').click();assert.equal(await snap(),initial);await page.locator('#undo').click();assert.equal(await snap(),duplicate);
 const first=JSON.parse(duplicate).regions[0];await page.locator('[data-region=region-2]').click();await page.locator('#growth-family').selectOption('tendrils');await page.locator('#growth-family').dispatchEvent('input');await page.locator('#growth-family').dispatchEvent('change');
 assert.deepEqual(JSON.parse(await snap()).regions[0],first);
 const builds=await page.evaluate(()=>CreatureStudio.diagnostics().growthBuilds);await page.locator('#growth-position').fill('0.4');await page.locator('#growth-position').dispatchEvent('change');assert.equal(await page.evaluate(()=>CreatureStudio.diagnostics().growthBuilds),builds);
 await page.locator('#gl').focus();const preKey=await snap();await page.keyboard.press('ArrowRight');assert.notEqual(await snap(),preKey);await page.keyboard.press('Control+z');assert.equal(await snap(),preKey);await page.keyboard.press('Control+Shift+z');assert.notEqual(await snap(),preKey);
 // A real mouse gesture uses projected body coordinates, then Escape restores the transaction.
 const point=await page.evaluate(()=>CreatureStudio.projectPoint(.6,1.4));const preDrag=await snap();await page.mouse.move(...point);await page.mouse.down();await page.mouse.move(point[0]+15,point[1]-5,{steps:3});await page.mouse.up();const dragged=await snap();assert.notEqual(dragged,preDrag);
 await page.locator('#undo').click();assert.equal(await snap(),preDrag);await page.locator('#redo').click();assert.equal(await snap(),dragged);
 await page.mouse.move(...point);await page.mouse.down();await page.mouse.move(point[0]+20,point[1]-10);await page.keyboard.press('Escape');await page.mouse.up();assert.equal(await snap(),dragged);
 console.log('PASS growth/history gestures');
 // Palette drag and click-to-place are separate supported paths.
 await page.locator('[data-tool=sculpt]').click();await page.locator('[data-cat=arms]').click();
 const start=await page.locator('[data-part=arm_grasper]').boundingBox();const target=await page.evaluate(()=>CreatureStudio.projectPoint(.65,1.4));
 await page.mouse.move(start.x+start.width/2,start.y+start.height/2);await page.mouse.down();await page.mouse.move(...target,{steps:4});await page.mouse.up();assert(JSON.parse(await snap()).parts.some(p=>p.type==='arm_grasper'));
 const placed=await snap();await page.locator('#undo').click();assert.notEqual(await snap(),placed);await page.locator('#redo').click();assert.equal(await snap(),placed);
 await page.locator('#lang').click();assert.equal(await page.locator('html').getAttribute('lang'),'en');assert.equal(await page.locator('[data-mode=paint]').innerText(),'Paint');await page.locator('[data-mode=paint]').click();assert.equal(await page.locator('#panel h2').first().innerText(),'SKIN');
 await page.locator('[data-mode=test]').click();await page.locator('[data-act=run]').click();await page.locator('[data-mode=build]').click();
 const shared=await page.evaluate(()=>CreatureStudio.shareLink()),sharedGenome=await snap();await page.goto(shared);await page.waitForFunction(()=>window.CreatureStudio?.ready,{timeout:90000});assert.equal(await snap(),sharedGenome);
 console.log('PASS palette, modes and sharing');
 // Evidence: one desktop composition shows the imported arm, wing and material regions.
 await page.evaluate(()=>{CreatureStudio.preset('Merodeador');CreatureStudio.addPart('wing_glider',{t:.57,ang:1.1,size:1});CreatureStudio.addPart('arm_grasper',{t:.78,ang:1.6,size:.85});CreatureStudio.addPart('lure_lantern',{t:.92,ang:0,size:.65});});
 await page.locator('[data-cat=wings]').click();await page.screenshot({path:path.join(artifacts,'studio-v4-desktop.png'),timeout:90000});
 assert.deepEqual(errors,[]);
 fs.writeFileSync(path.join(artifacts,'studio-v4-results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',viewport:'1280x800',...result,errors},null,2)+'\n');console.log('PASS pointer, keyboard, history, regions, palette, modes, language and Unicode sharing');
 }finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
