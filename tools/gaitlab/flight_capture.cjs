#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/flight_capture.cjs
// file://, local three.js r128, SwiftShader only (never GPU flags). One JPG per page plus interaction checks.
// FLIGHT_PAGES=0,1,2 limits the pages; FLIGHT_CAM=side|chase|three-quarter sets the camera for the page stills.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/evidence/loco/flight');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const only=process.env.FLIGHT_PAGES?process.env.FLIGHT_PAGES.split(',').map(Number):null;
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:1680,height:1100}}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push('console: '+m.text());});page.on('request',req=>{if(/^https?:/.test(req.url()))errors.push('Unexpected network request: '+req.url());});
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/flight.html')).href+'?test=1',{timeout:300000});
 await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:300000});
 const result=await page.evaluate(()=>window.__stylesCheck);
 fs.writeFileSync(path.join(out,'table.json'),JSON.stringify({pass:result.pass,cases:result.cases,passed:result.passed,fails:result.fails,table:result.table},null,1)+'\n');
 console.log(`${result.pass?'PASS':'FAIL'}: ${result.passed}/${result.cases} body x row x variant cases`);for(const f of result.fails.slice(0,40))console.log(f);
 await page.evaluate(()=>STYLELAB.setPause(true));
 const cam=process.env.FLIGHT_CAM||'three-quarter';
 const pages=await page.evaluate(()=>STYLELAB.PAGES.map(p=>p.b.id+' p'+(p.half+1)));
 for(let i=0;i<pages.length;i++){if(only&&!only.includes(i))continue;
  await page.evaluate(([i,cam])=>{STYLELAB.selectPage(i);STYLELAB.setCam(cam);
   // advance each cell to a representative moment of its manoeuvre
   for(const C of STYLELAB.cells){const F=C.F,r=C.row,v=C.vid;const run=(pred,max)=>{let n=0;while(!pred()&&F.t<max&&!F.done&&n++<20000){STYLELAB.stepCell(C,1/120);}};
    const upto=T=>run(()=>F.t>=T,T+1);
    if(r==='takeoff'){if(v==='cliff'||v==='treeleap'){run(()=>F.state==='air',20);upto(F.t+(v==='treeleap'?1.4:.9));}else upto(v==='vertical'?1.4:2.3);}
    else if(r==='cruise')upto(5.2);
    else if(r==='turn')upto(v==='bank'?5.6:v==='wingover'?4.6:v==='pivot'?5.8:5.5);
    else if(r==='landing'){run(()=>F.state!=='air'&&F.state!=='capture'||F.state==='perched',30);upto(F.t+.25);}
    else if(r==='hover')upto(v==='stall'?5.2:v==='flutter'?4.5:7.5);
    else if(r==='glide')upto(v==='thermal'?9:7);
    else if(r==='dive')run(()=>F.ph.indexOf('pull')===0,20),upto(F.t+.35);
    else if(r==='rough')upto(v.startsWith('carry')?4.2:6);
   }
   STYLELAB.render();},[i,cam]);
  await page.screenshot({path:path.join(out,`page${String(i+1).padStart(2,'0')}_${pages[i].replace(/[^a-z0-9]+/gi,'_')}.jpg`),type:'jpeg',quality:86});console.log('Captured '+pages[i]);}
 // Interactions with real keys and clicks.
 await page.evaluate(()=>STYLELAB.selectPage(0));
 await page.locator('.cell').nth(2).click();await page.locator('.cell').nth(1).click();await page.locator('.cell').nth(5).click();await page.locator('.cell').nth(15).click();
 await page.keyboard.press('Space');if(await page.evaluate(()=>STYLELAB.pageIndex)!==2)throw Error('Space did not advance the body');await page.locator('.cell').nth(8).click();await page.keyboard.press('Shift+Space');if(await page.evaluate(()=>STYLELAB.pageIndex)!==0)throw Error('Shift+Space did not reverse');
 const text=await page.evaluate(()=>STYLELAB.choicesText());
 const want='starterB: takeoff=leap; cruise=flapglide; turn=-; landing=crash; hover=-; glide=-; dive=-; rough=-\nhatchling: takeoff=-; cruise=-; turn=bank; landing=-; hover=-; glide=-; dive=-; rough=-';
 if(text!==want)throw Error('Choice text mismatch: '+JSON.stringify(text)+' vs '+JSON.stringify(want));
 await page.locator('#copy').click();await page.waitForFunction(()=>document.getElementById('copy-status').textContent.length>0);if(!(await page.locator('#copy-status').textContent()).includes('Copied')&&!(await page.locator('#copy-fallback').isVisible()&&await page.locator('#copy-fallback').inputValue()===text))throw Error('Copy did not copy or offer a selected fallback');
 await page.keyboard.press('g');if(await page.evaluate(()=>STYLELAB.pageIndex)!==1)throw Error('G did not switch page');await page.keyboard.press('g');
 await page.locator('.cell').nth(7).hover();await page.keyboard.press('f');if(!await page.locator('#stage').evaluate(el=>el.classList.contains('expanded')))throw Error('F failed');await page.screenshot({path:path.join(out,'focus_cell.jpg'),type:'jpeg',quality:88});await page.keyboard.press('Escape');
 await page.keyboard.press('p');if(await page.evaluate(()=>STYLELAB.paused))throw Error('Pause key failed to resume');await page.keyboard.press('p');
 const seen=new Set();for(let k=0;k<3;k++){seen.add(await page.evaluate(()=>STYLELAB.camMode));await page.keyboard.press('t');}if(seen.size!==3)throw Error('T did not cycle three cameras');
 for(const r of ['.25','.5','1']){await page.locator(`[data-rate="${r}"]`).click();if(await page.evaluate(()=>STYLELAB.rate)!==Number(r))throw Error('Playback rate failed');}
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/flight.html')).href);await page.waitForFunction(()=>window.__ready);if(await page.evaluate(()=>STYLELAB.choicesText())!==text)throw Error('Choices were not persisted');
 await page.setViewportSize({width:1280,height:800});await page.screenshot({path:path.join(out,'laptop.jpg'),type:'jpeg',quality:88});
 if(errors.length)throw Error(errors.join('\n'));console.log('PASS: file://, local assets, one star per row, persistence, copy, Space, Shift+Space, G, F/Esc, P, T (3 cameras), playback');
 await browser.close();process.exitCode=result.pass?0:1;
 }catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
