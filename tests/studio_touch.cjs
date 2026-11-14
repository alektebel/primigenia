const {chromium}=require('playwright');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const artifacts=process.env.CPORE_ARTIFACT_DIR||'/tmp/cpore-studio-evidence';
fs.mkdirSync(artifacts,{recursive:true});
(async()=>{const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
try{const page=await browser.newPage({viewport:{width:1280,height:800},hasTouch:true});const errors=[],checks=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto(base+'/web/studio/#preset=Coralino');await page.waitForFunction(()=>!!window.CreatureStudio);
await page.evaluate(()=>{const g=CreatureStudio.genome();g.legs.stride=0;Object.assign(g.regions[0],{angle:.65,position:.45,seed:500});g.regions.push({...g.regions[0],id:'neck-plates',family:'plates',surface:'neck',coverage:.25,position:.6,angle:.9,count:4,length:.65,mirror:false,seed:17,branches:1});CreatureStudio.load(g)});
const before=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));
for(const [x,y]of [[331,330],[311,340],[350,317],[310,320]]){await page.touchscreen.tap(x,y);if(await page.evaluate(()=>CreatureStudio.diagnostics().selectedRegionId)==='neck-plates')break}
assert.equal(await page.evaluate(()=>CreatureStudio.diagnostics().selectedRegionId),'neck-plates');checks.push('touching visible neck plates selects their independent region');
assert.equal(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome())),before);checks.push('viewport selection leaves the saved document unchanged');
await page.locator('#placeGrowth').click();const cdp=await page.context().newCDPSession(page);
await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:480,y:390,id:1}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:515,y:385,id:1}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
const after=await page.evaluate(()=>JSON.stringify(CreatureStudio.genome()));assert.notEqual(after,before);assert.deepEqual(JSON.parse(after).regions[0],JSON.parse(before).regions[0]);checks.push('touch drag moves only the selected region');
await page.locator('#undo').click();assert.equal(await page.evaluate(()=>JSON.stringify(CreatureStudio.genome())),before);checks.push('touch drag is a single undo transaction');
assert.deepEqual(errors,[]);fs.writeFileSync(path.join(artifacts,'selection-results.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',viewport:'1280x800 with touch events',checks,errors},null,2));console.log(checks.join('\n'));
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exit(1)});
