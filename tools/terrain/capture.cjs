/* Serve the repo root first. Only software WebGL; render on demand, always close. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const url=process.env.TERRAIN_URL||'http://127.0.0.1:8031/web/terrain-lab/';
(async()=>{
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  try {
    const page=await browser.newPage({viewport:{width:1440,height:1040},deviceScaleFactor:1});
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    const evidence='docs/evidence/terrain';fs.mkdirSync(evidence,{recursive:true});
    for(const seed of [1,7,42]) {
      for(const base of [true,false]) {
        await page.goto(`${url}?seed=${seed}&n=1024&base=${+base}`);
        await page.waitForFunction(()=>window.terrainResult,{timeout:60000});
        const result=await page.evaluate(()=>window.terrainResult);
        assert.equal(result.seed,seed);assert.equal(result.base,base);
        await page.locator('#scene').screenshot({path:`${evidence}/${base?'base':'eroded'}-${seed}.png`});
        if(!base)await page.locator('#map').screenshot({path:`${evidence}/hillshade-drainage-${seed}.png`});
        console.log(result);
      }
    }
    // Surface modes, keyboard camera, drainage switch, validation and regeneration.
    for(const mode of ['height','slope','flow','sediment','materials'])await page.selectOption('#shading',mode);
    await page.locator('#scene').focus();await page.keyboard.press('ArrowLeft');await page.keyboard.press('+');
    await page.click('#reset');await page.uncheck('#drainage');await page.check('#drainage');
    await page.fill('#seed','-1');await page.click('#generate');
    assert.equal(await page.locator('#seed').evaluate(el=>el.validity.valid),false);
    await page.fill('#seed','7');await page.selectOption('#resolution','256');
    await page.click('#generate');await page.waitForFunction(()=>window.terrainResult?.seed===7&&window.terrainResult?.n===256);
    assert.equal(await page.locator('#generate').isEnabled(),true);
    await page.screenshot({path:`${evidence}/lab-desktop.png`,fullPage:true});
    await page.setViewportSize({width:390,height:844});
    await page.screenshot({path:`${evidence}/lab-mobile.png`,fullPage:true});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    const gl=await page.evaluate(()=>{const gl=document.getElementById('scene').getContext('webgl2');const dbg=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL);});
    assert.match(gl,/SwiftShader/i);assert.deepEqual(errors,[]);
    fs.writeFileSync(`${evidence}/browser.json`,JSON.stringify({browser:browser.version(),renderer:gl,errors,captures:9,interactions:'all five surface modes, keyboard camera, reset, drainage, invalid seed, regeneration, mobile overflow'},null,2)+'\n');
    console.log('Terrain browser smoke: PASS; '+gl);
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
