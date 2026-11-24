#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/octopus_capture.cjs
// file://, local three.js r128, SwiftShader only (never GPU flags). One JPG per page plus single-cell close-ups and interaction checks.
// OCTO_PAGES=0,1 limits pages; OCTO_FOCUS=id,id adds close-up captures (cell ids 0..47); OCTO_FAST=1 skips the self-check and the interaction block.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/evidence/loco/octopus');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const only=process.env.OCTO_PAGES?process.env.OCTO_PAGES.split(',').map(Number):null;
const focus=process.env.OCTO_FOCUS?process.env.OCTO_FOCUS.split(',').map(Number):[];
const fast=!!process.env.OCTO_FAST;
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:1680,height:1100}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push('console: '+m.text());});page.on('request',req=>{if(/^https?:/.test(req.url()))errors.push('Unexpected network request: '+req.url());});
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/octopus.html')).href+(fast?'':'?test=1'),{timeout:300000});
 await page.waitForFunction(()=>window.__ready&&(window.__stylesCheck||new URLSearchParams(location.search).get('test')!=='1'),null,{timeout:300000});
 let result={pass:true,cases:0,passed:0,fails:[],table:[]};
 if(!fast){result=await page.evaluate(()=>window.__stylesCheck);
  fs.writeFileSync(path.join(out,'table.json'),JSON.stringify({pass:result.pass,cases:result.cases,passed:result.passed,fails:result.fails,table:result.table},null,1)+'\n');
  console.log(`${result.pass?'PASS':'FAIL'}: ${result.passed}/${result.cases} cells`);for(const f of result.fails.slice(0,60))console.log(f);}
 await page.evaluate(()=>STYLELAB.setPause(true));
 const names=['core_modes','variations','special_cases'];
 // advance every cell to a moment that shows its movement
 const prep=(pi,cam)=>page.evaluate(([pi,cam])=>{STYLELAB.selectPage(pi);STYLELAB.setCam(cam||'view');
   for(const A of STYLELAB.walkers){const s=A.sp;let guard=0;const feat=s.scene==='gap'?2.0:s.scene==='rocks'?2.0:s.scene==='slope'?1.9:99;
    if(s.mode==='para')(()=>{while(A.t<4.1){A.step(1/120);STYLELAB.stepVis(A,1/120);}})();
    else if(s.mode==='land'&&s.row!=='terrain'){while(A.C.x<1.5&&A.t<30){A.step(1/120);STYLELAB.stepVis(A,1/120);}}
    else if((s.mode==='crawl'||s.mode==='land'||s.mode==='bipd')&&s.row==='terrain'){while(A.C.x<feat&&A.t<39&&guard++<9000){A.step(1/120);STYLELAB.stepVis(A,1/120);}}
    else if(s.row==='turn'){while(A.t<3.9){A.step(1/120);STYLELAB.stepVis(A,1/120);}}
    else if(s.row==='fast'&&(s.mode==='jet'||s.mode==='medu'||s.mode==='cirr')){while(A.t<.85){A.step(1/120);STYLELAB.stepVis(A,1/120);}}
    else {while(A.t<5.2){A.step(1/120);STYLELAB.stepVis(A,1/120);}}
    if(s.mode==='jet'||s.mode==='medu'){const lo=s.mode==='jet'?.6:.35,hi=lo+.1;let g2=0;while(!(A.phase>=lo&&A.phase<hi)&&g2++<400){A.step(1/120);STYLELAB.stepVis(A,1/120);}}
    for(let k=0;k<30;k++){A.step(1/120);STYLELAB.stepVis(A,1/120);}A.vis.camT={...A.C};}
   // let plankton and ghosts settle by stepping the visuals
   STYLELAB.render();},[pi,cam]);
 for(let i=0;i<3;i++){if(only&&!only.includes(i))continue;await prep(i);await page.screenshot({path:path.join(out,`page${i+1}_${names[i]}.jpg`),type:'jpeg',quality:88});console.log('Captured page '+(i+1));}
 for(const id of focus){const pi=Math.floor(id/16),idx=id%16;await prep(pi);await page.evaluate(idx=>{STYLELAB.focusCell(idx);},idx);
  // a few more frames so the camera settles
  await page.evaluate(()=>{for(let k=0;k<30;k++)STYLELAB.render();});
  const n=await page.evaluate(id=>STYLELAB.CELLS[id].name.replace(/[^a-z0-9]+/gi,'_'),id);
  await page.screenshot({path:path.join(out,`cell${String(id).padStart(2,'0')}_${n}.jpg`),type:'jpeg',quality:88});await page.keyboard.press('Escape');console.log('Focus '+id+' '+n);}
 if(fast){await browser.close();return;}
 // interactions with real keys and clicks
 await page.evaluate(()=>STYLELAB.selectPage(0));
 await page.locator('.cell').nth(2).click();await page.locator('.cell').nth(5).click();await page.locator('.cell').nth(10).click();await page.locator('.cell').nth(15).click();
 await page.keyboard.press('Space');if(await page.evaluate(()=>STYLELAB.pageIndex)!==1)throw Error('Space did not advance');await page.locator('.cell').nth(7).click();await page.keyboard.press('Shift+Space');if(await page.evaluate(()=>STYLELAB.pageIndex)!==0)throw Error('Shift+Space did not reverse');
 const text=await page.evaluate(()=>STYLELAB.choicesText());
 const expect='octopus (underwater): cruise=web pulse; fast=arm skitter; turn=asymmetric web; terrain=open-water climb';
 if(text!==expect)throw Error('Choice text mismatch: '+JSON.stringify(text)+' vs '+JSON.stringify(expect));
 await page.locator('#copy').click();await page.waitForFunction(()=>document.getElementById('copy-status').textContent.length>0);if(!(await page.locator('#copy-status').textContent()).includes('Copied')&&!(await page.locator('#copy-fallback').isVisible()&&await page.locator('#copy-fallback').inputValue()===text))throw Error('Copy did not copy or offer a selected fallback');
 await page.locator('.cell').nth(7).hover();await page.keyboard.press('f');if(!await page.locator('#stage').evaluate(el=>el.classList.contains('expanded')))throw Error('F failed');await page.screenshot({path:path.join(out,'focus_cell.jpg'),type:'jpeg',quality:88});await page.keyboard.press('Escape');
 await page.keyboard.press('p');if(await page.evaluate(()=>STYLELAB.paused))throw Error('Pause key failed to resume');await page.keyboard.press('p');
 const seen=new Set();for(let k=0;k<3;k++){seen.add(await page.evaluate(()=>STYLELAB.camMode));await page.keyboard.press('t');}if(seen.size!==3)throw Error('T did not cycle three cameras');
 for(const r of ['.25','.5','1']){await page.locator(`[data-rate="${r}"]`).click();if(await page.evaluate(()=>STYLELAB.rate)!==Number(r))throw Error('Playback rate failed');}
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/octopus.html')).href);await page.waitForFunction(()=>window.__ready);if(await page.evaluate(()=>STYLELAB.choicesText())!==text)throw Error('Choices were not persisted');
 await page.setViewportSize({width:1280,height:800});await page.screenshot({path:path.join(out,'laptop.jpg'),type:'jpeg',quality:88});
 if(errors.length)throw Error(errors.join('\n'));console.log('PASS: file://, local assets, one star per row, persistence, copy, Space, Shift+Space, F/Esc, P, T (3 cameras), playback');
 await browser.close();process.exitCode=result.pass?0:1;
 }catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
