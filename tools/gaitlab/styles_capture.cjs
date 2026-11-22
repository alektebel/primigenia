#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules nice -n 10 node tools/gaitlab/styles_capture.cjs
// file://, local r128, SwiftShader only. Writes JPG evidence and measured JSON.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/evidence/loco/styles');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:1680,height:1100}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('request',req=>{if(/^https?:/.test(req.url()))errors.push('Unexpected network request: '+req.url());});
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/styles.html')).href+'?test=1',{timeout:300000});
 await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:300000});
 const result=await page.evaluate(()=>window.__stylesCheck);fs.writeFileSync(path.join(out,'table.json'),JSON.stringify(result,null,2)+'\n');
 console.log(`${result.pass?'PASS':'FAIL'}: ${result.table.length} body/style/speed cases`);for(const f of result.fails.slice(0,45))console.log(f);
 await page.evaluate(()=>STYLELAB.setPause(true));
 const bodies=await page.evaluate(()=>STYLELAB.BODIES.map(b=>b.name));
 for(let i=0;i<bodies.length;i++){await page.evaluate(i=>{STYLELAB.selectBody(i);STYLELAB.advance(.37);STYLELAB.render();},i);await page.screenshot({path:path.join(out,'grid_'+bodies[i].replaceAll(' ','_')+'.jpg'),type:'jpeg',quality:90});console.log('Captured '+bodies[i]);}
 // Interaction checks use actual keys/clicks and an isolated storage context.
 await page.evaluate(()=>STYLELAB.selectBody(0));await page.locator('.cell').nth(3).click();await page.keyboard.press('Space');if(await page.evaluate(()=>STYLELAB.bodyIndex)!==1)throw Error('Space did not advance');await page.locator('.cell').nth(4).click();await page.keyboard.press('Shift+Space');if(await page.evaluate(()=>STYLELAB.bodyIndex)!==0)throw Error('Shift+Space did not reverse');
 const text=await page.evaluate(()=>STYLELAB.choicesText());if(text!=='starter B: ★ knuckle-walk; hatchling: ★ trot')throw Error('Choice text mismatch: '+text);
 await page.locator('#copy').click();if(!(await page.locator('#copy-status').textContent()).includes('Copied')&&!(await page.locator('#copy-fallback').isVisible()&&await page.locator('#copy-fallback').inputValue()===text))throw Error('Copy did not copy or offer a selected fallback');
 await page.locator('.cell').nth(7).hover();await page.keyboard.press('f');if(!await page.locator('#stage').evaluate(el=>el.classList.contains('expanded')))throw Error('F failed');await page.keyboard.press('Escape');
 await page.keyboard.press('p');if(await page.evaluate(()=>STYLELAB.paused))throw Error('Pause key failed to resume');await page.keyboard.press('p');
 for(const r of ['.25','.5','1']){await page.locator(`[data-rate="${r}"]`).click();if(await page.evaluate(()=>STYLELAB.rate)!==Number(r))throw Error('Playback rate failed');}
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/styles.html')).href);await page.waitForFunction(()=>window.__ready);if(await page.evaluate(()=>STYLELAB.choicesText())!==text)throw Error('Choices were not persisted');
 await page.setViewportSize({width:1280,height:800});await page.screenshot({path:path.join(out,'laptop.jpg'),type:'jpeg',quality:90});
 await page.setViewportSize({width:720,height:900});await page.screenshot({path:path.join(out,'narrow.jpg'),type:'jpeg',quality:90});
 if(errors.length)throw Error(errors.join('\n'));console.log('PASS: file://, local assets, choices, persistence, copy, Space, Shift+Space, F/Esc, P, playback, laptop/narrow captures');
 await browser.close();process.exitCode=result.pass?0:1;
 }catch(e){console.error('Capture failed (browser may be sandbox-blocked):',e.message);if(browser)await browser.close();process.exitCode=1;}})();
