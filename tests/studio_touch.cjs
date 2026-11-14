const {chromium}=require('playwright');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';const artifacts=process.env.CPORE_ARTIFACT_DIR||path.resolve('docs/evidence');fs.mkdirSync(artifacts,{recursive:true});
(async()=>{const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});try{
 const page=await browser.newPage({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:1});const errors=[],checks=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(base+'/web/studio/#preset=Babosa');await page.waitForFunction(()=>window.CreatureStudio?.ready,{timeout:90000});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);checks.push('390px layout has no horizontal overflow');
 await page.locator('[data-growth-action=add]').click();
 await page.locator('#gl').scrollIntoViewIfNeeded();
 const snap=()=>page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));const before=await snap();
 const point=await page.evaluate(()=>CreatureStudio.projectPoint(.6,1.3));const cdp=await page.context().newCDPSession(page);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:point[0],y:point[1],id:1}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:point[0]+15,y:point[1]-8,id:1}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});const after=await snap();assert.notEqual(after,before);checks.push('touch drag places selected growth on the body');
 await page.locator('#undo').click();assert.equal(await snap(),before);await page.locator('#redo').click();assert.equal(await snap(),after);checks.push('touch placement is one undo/redo transaction');
 // Touch palette selection followed by body placement; scrolling leaves the stage available.
 await page.locator('[data-cat=wings]').tap();await page.locator('[data-part=wing_insect]').tap();await page.locator('#gl').scrollIntoViewIfNeeded();
 const wingTarget=await page.evaluate(()=>CreatureStudio.projectPoint(.65,1.3));await page.touchscreen.tap(...wingTarget);
 assert(JSON.parse(await snap()).parts.some(p=>p.type==='wing_insect'));checks.push('tap palette then tap body places a GLB');
 await page.locator('[data-tool=orbit]').tap();await page.locator('#gl').scrollIntoViewIfNeeded();const orbitBefore=await snap();
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:200,y:220,id:2}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:225,y:230,id:2}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});assert.equal(await snap(),orbitBefore);checks.push('explicit orbit tool preserves the document');
 await page.locator('#lang').tap();assert.equal(await page.locator('[data-mode=paint]').innerText(),'Paint');await page.locator('[data-mode=paint]').tap();assert.equal(await page.locator('#panel h2').first().innerText(),'SKIN');checks.push('mobile Paint and language toggle work');
 await page.locator('[data-mode=test]').tap();await page.locator('[data-act=run]').tap();await page.locator('[data-mode=build]').tap();checks.push('mobile Test actions return to Build');
 await page.evaluate(()=>{CreatureStudio.preset('Merodeador');CreatureStudio.addPart('wing_insect',{t:.6,ang:1.3,size:.7});});await page.locator('[data-cat=wings]').tap();await page.evaluate(()=>scrollTo(0,0));
 await page.screenshot({path:path.join(artifacts,'studio-v4-mobile.png'),fullPage:true,timeout:90000});
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(artifacts,'studio-v4-touch-results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',viewport:'390x844, DPR 1, touch',checks,errors},null,2)+'\n');console.log('PASS',checks.join('; '));
 }finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
