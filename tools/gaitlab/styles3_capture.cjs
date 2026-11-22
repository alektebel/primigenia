#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/styles3_capture.cjs [outdir]
// file://, local three.js r128, SwiftShader only (never GPU flags). One JPG per body plus interaction checks.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/evidence/loco/styles3');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const ADVANCE=Number(process.env.STYLES3_ADVANCE||3.6);
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:1680,height:1100}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('request',req=>{if(/^https?:/.test(req.url()))errors.push('Unexpected network request: '+req.url());});
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/styles3.html')).href+'?test=1',{timeout:300000});
 await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:300000});
 const result=await page.evaluate(()=>window.__stylesCheck);
 fs.writeFileSync(path.join(out,'table.json'),JSON.stringify({pass:result.pass,cases:result.cases,passed:result.passed,fails:result.fails,table:result.table.map(r=>({body:r.body,row:r.row,variant:r.variant,gait:r.gait,hz:+r.hz.toFixed(3),stride:+r.stride.toFixed(3),flightAnalytic:+r.flightAnalytic.toFixed(3),flightMeasured:+r.flightMeasured.toFixed(3),contactDriftCm:+r.slipCm.toFixed(4),kneeBad:r.kneeBad,float:r.float,below:r.below,clamp:r.clamp,cross:r.cross,segmentErr:+r.seg.toFixed(3),lateralSlip:+r.side.toFixed(3),v:+r.v.toFixed(3),Fr:r.Fr,radii:r.radii,sharpDeg:r.sharpDeg}))},null,1)+'\n');
 console.log(`${result.pass?'PASS':'FAIL'}: ${result.passed}/${result.cases} body x row x variant cases`);for(const f of result.fails.slice(0,40))console.log(f);
 await page.evaluate(()=>STYLELAB.setPause(true));
 const bodies=await page.evaluate(()=>STYLELAB.BODIES.map(b=>b.name));
 const ADV={'earthworm':5.5,'inchworm':7,'slug':9,'snake':4.5};
 for(let i=0;i<bodies.length;i++){await page.evaluate(([i,s])=>{STYLELAB.selectBody(i);STYLELAB.advance(s);STYLELAB.render();},[i,ADV[bodies[i]]||3.6]);await page.screenshot({path:path.join(out,'grid_'+bodies[i].replace(/[^a-z0-9]+/gi,'_')+'.jpg'),type:'jpeg',quality:88});console.log('Captured '+bodies[i]);}
 // camera toggles: a legged body top-down and a limbless body side view
 await page.evaluate(()=>{STYLELAB.selectBody(0);STYLELAB.advance(3.6);STYLELAB.setCam('top');STYLELAB.render();});await page.screenshot({path:path.join(out,'top_radial5.jpg'),type:'jpeg',quality:88});
 await page.evaluate(()=>{STYLELAB.selectBody(5);STYLELAB.advance(4.5);STYLELAB.setCam('view');STYLELAB.render();});await page.screenshot({path:path.join(out,'side_snake.jpg'),type:'jpeg',quality:88});
 // Interactions with real keys and clicks, isolated storage context.
 await page.evaluate(()=>STYLELAB.selectBody(0));
 await page.locator('.cell').nth(2).click();await page.locator('.cell').nth(1).click();await page.locator('.cell').nth(5).click();await page.locator('.cell').nth(15).click();
 await page.keyboard.press('Space');if(await page.evaluate(()=>STYLELAB.bodyIndex)!==1)throw Error('Space did not advance');await page.locator('.cell').nth(8).click();await page.keyboard.press('Shift+Space');if(await page.evaluate(()=>STYLELAB.bodyIndex)!==0)throw Error('Shift+Space did not reverse');
 const text=await page.evaluate(()=>STYLELAB.choicesText());
 const want='radial 5 (starfish): walk=rotating lead; turn=rotating lead; fast=-; rough=cartwheel\nradial 8 (octopus): walk=-; turn=-; fast=two-arm bipedal walk; rough=-';
 if(text!==want)throw Error('Choice text mismatch: '+JSON.stringify(text));
 await page.locator('#copy').click();await page.waitForFunction(()=>document.getElementById('copy-status').textContent.length>0);if(!(await page.locator('#copy-status').textContent()).includes('Copied')&&!(await page.locator('#copy-fallback').isVisible()&&await page.locator('#copy-fallback').inputValue()===text))throw Error('Copy did not copy or offer a selected fallback');
 await page.locator('.cell').nth(7).hover();await page.keyboard.press('f');if(!await page.locator('#stage').evaluate(el=>el.classList.contains('expanded')))throw Error('F failed');await page.screenshot({path:path.join(out,'focus_cell.jpg'),type:'jpeg',quality:88});await page.keyboard.press('Escape');
 await page.keyboard.press('p');if(await page.evaluate(()=>STYLELAB.paused))throw Error('Pause key failed to resume');await page.keyboard.press('p');
 await page.keyboard.press('t');const cm0=await page.evaluate(()=>STYLELAB.camMode);await page.keyboard.press('t');if(await page.evaluate(()=>STYLELAB.camMode)===cm0)throw Error('T failed');await page.keyboard.press('t');
 for(const r of ['.25','.5','1']){await page.locator(`[data-rate="${r}"]`).click();if(await page.evaluate(()=>STYLELAB.rate)!==Number(r))throw Error('Playback rate failed');}
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/styles3.html')).href);await page.waitForFunction(()=>window.__ready);if(await page.evaluate(()=>STYLELAB.choicesText())!==text)throw Error('Choices were not persisted');
 await page.setViewportSize({width:1280,height:800});await page.screenshot({path:path.join(out,'laptop.jpg'),type:'jpeg',quality:88});
 if(errors.length)throw Error(errors.join('\n'));console.log('PASS: file://, local assets, one star per row, persistence, copy, Space, Shift+Space, F/Esc, P, T, playback');
 await browser.close();process.exitCode=result.pass?0:1;
 }catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
