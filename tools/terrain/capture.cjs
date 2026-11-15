/* Terrain lab captures. Serve the repo root first (see docs/TERRAIN.md).
 * Only software WebGL; one page load per terrain, three pictures from it;
 * the browser is always closed.
 *
 *   node tools/terrain/capture.cjs                 evidence set + lab smoke
 *   node tools/terrain/capture.cjs --out DIR --seeds 42 [--no-smoke] [--no-before] [--no-base]
 *
 * Each terrain gives NAME-oblique.png (fixed camera above), NAME-valley.png
 * (eye 2.2 m above the valley floor) and NAME-top.png (hillshade + drainage,
 * one pixel per cell). "before" is the phase-A generator, which needs its
 * module in build/wasm-v1 (docs/TERRAIN.md says how to build it). */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const url=process.env.TERRAIN_URL||'http://127.0.0.1:8031/web/terrain-lab/';
const args=process.argv.slice(2),flag=name=>args.includes(name),value=(name,fallback)=>args.includes(name)?args[args.indexOf(name)+1]:fallback;
const out=value('--out','docs/evidence/terrain'),seeds=value('--seeds','42,1,7').split(',').map(Number);
const jobs=[];
if(!flag('--no-before')&&fs.existsSync('build/wasm-v2/cpore_terrain.mjs'))jobs.push({name:'v2-42',seed:42,engine:'v2'});
if(!flag('--no-base'))jobs.push({name:`base-${seeds[0]}`,seed:seeds[0],base:1});
for(const seed of seeds)jobs.push({name:`after-${seed}`,seed});
(async()=>{
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  try {
    const page=await browser.newPage({viewport:{width:1440,height:1040},deviceScaleFactor:1});
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    fs.mkdirSync(out,{recursive:true});
    const results=[];
    for(const job of jobs) {
      await page.goto(`${url}?seed=${job.seed}&n=1024&map=1024&base=${job.base||0}${job.engine?`&engine=${job.engine}`:''}`);
      await page.waitForFunction(()=>window.terrainResult||document.body.dataset.error==='true',{timeout:120000});
      const result=await page.evaluate(()=>window.terrainResult);
      assert.ok(result,await page.locator('#status').textContent());
      assert.equal(result.seed,job.seed);assert.equal(result.base,Boolean(job.base));assert.equal(result.version,job.engine?2:3);
      await page.locator('#scene').screenshot({path:`${out}/${job.name}-oblique.png`});
      await page.selectOption('#view','valley');
      await page.locator('#scene').screenshot({path:`${out}/${job.name}-valley.png`});
      const png=await page.evaluate(()=>document.getElementById('map').toDataURL('image/png'));
      fs.writeFileSync(`${out}/${job.name}-top.png`,Buffer.from(png.split(',')[1],'base64'));
      if(!job.engine && !job.base && job.seed===42) {
        assert.ok(result.entrances.length>=3 && result.entrances.length<=6);
        assert.ok(result.materialCounts[3]>100);
        await page.selectOption('#view','orbit');await page.selectOption('#shading','classification');
        await page.screenshot({path:`${out}/lab-material-caves.png`,fullPage:true});
        const material=await page.evaluate(()=>document.getElementById('map').toDataURL('image/png'));
        fs.writeFileSync(`${out}/material-caves-42.png`,Buffer.from(material.split(',')[1],'base64'));
        await page.selectOption('#shading','materials');
      }
      results.push({name:job.name,...result});console.log(job.name,result);
    }
    const gl=await page.evaluate(()=>{const gl=document.getElementById('scene').getContext('webgl2');const dbg=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL);});
    assert.match(gl,/SwiftShader/i);
    if(!flag('--no-smoke')) {
      // Surface modes, both views, keyboard camera, drainage switch, validation and regeneration.
      for(const mode of ['height','slope','flow','sediment','classification','materials'])await page.selectOption('#shading',mode);
      await page.selectOption('#view','orbit');
      await page.locator('#scene').focus();await page.keyboard.press('ArrowLeft');await page.keyboard.press('+');
      await page.click('#reset');await page.uncheck('#drainage');await page.check('#drainage');
      await page.fill('#seed','-1');await page.click('#generate');
      assert.equal(await page.locator('#seed').evaluate(el=>el.validity.valid),false);
      await page.fill('#seed','7');await page.selectOption('#resolution','256');
      await page.click('#generate');await page.waitForFunction(()=>window.terrainResult?.seed===7&&window.terrainResult?.n===256);
      assert.equal(await page.locator('#generate').isEnabled(),true);
      await page.screenshot({path:`${out}/lab-desktop.png`,fullPage:true});
      await page.setViewportSize({width:390,height:844});
      await page.screenshot({path:`${out}/lab-mobile.png`,fullPage:true});
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
      fs.writeFileSync(`${out}/browser.json`,JSON.stringify({browser:browser.version(),renderer:gl,errors,terrains:results,
        captures:jobs.length*3+2+2,interactions:'all six surface modes, both views, keyboard camera, reset, drainage, invalid seed, regeneration, mobile overflow'},null,2)+'\n');
    }
    if(flag('--no-smoke'))fs.writeFileSync(`${out}/browser.json`,JSON.stringify({browser:browser.version(),renderer:gl,errors,terrains:results,captures:jobs.length*3+2},null,2)+'\n');
    assert.deepEqual(errors,[]);
    console.log('Terrain browser capture: PASS; '+gl);
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
