#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/befriend_bodies_capture.cjs [outdir]
// file://, local three.js, SwiftShader only (never GPU flags). Free-play check first (no ?test=1: >= 4 s, zero page errors, two differing screenshots),
// then the self-check JSON, the 4x4 grid at the success frame in three cameras + both-framing + target-framing + the beat frame,
// and one 6-frame strip per cell (focus view, performer close). ONLY=armed,bird,octo,snake or ONLY=sing,dance,... or ONLY=armed:pose to limit the strips.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/befriend_bodies');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const URL_=pathToFileURL(path.join(root,'web/gaitlab/befriend_bodies.html')).href;
const only=process.env.ONLY?process.env.ONLY.split(','):null;
const want=(b,a)=>!only||only.includes(b)||only.includes(a)||only.includes(b+':'+a);
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1920,height:1180}}),errors=[];
 if(!process.env.SKIP_FREEPLAY){const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});fp.on('request',r=>{if(/^https?:/.test(r.url()))fe.push('network '+r.url());});
  await fp.goto(URL_,{timeout:120000});await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});
  await fp.waitForTimeout(900);const a=await fp.screenshot({type:'jpeg',quality:80}),T1=await fp.evaluate(()=>[BF.S.T,window.__frames]);
  await fp.waitForTimeout(4200);const b=await fp.screenshot({type:'jpeg',quality:80}),T2=await fp.evaluate(()=>[BF.S.T,window.__frames,window.__errs.slice()]);
  fs.writeFileSync(path.join(out,'freeplay_a.jpg'),a);fs.writeFileSync(path.join(out,'freeplay_b.jpg'),b);
  const moved=Buffer.compare(a,b)!==0,adv=T2[1]-T1[1]>=4&&Math.abs(T2[0]-T1[0])>500,errs=fe.concat(T2[2]);
  const res={errors:errs,frames:[T1[1],T2[1]],T:[T1[0],T2[0]],screenshotsDiffer:moved,pass:errs.length===0&&moved&&adv};
  fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',res.pass?'PASS':'FAIL',JSON.stringify(res));
  await fp.close();if(!res.pass)throw Error('free-play check failed '+JSON.stringify(res));}
 const page=await ctx.newPage();page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto(URL_+'?test=1',{timeout:120000});await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:120000});
 const chk=await page.evaluate(()=>window.__stylesCheck);fs.writeFileSync(path.join(out,'check.json'),JSON.stringify(chk,null,1));
 console.log(chk.pass?'SELF-CHECK PASS':'SELF-CHECK FAIL',chk.fails.join('\n'));
 const grid=async(name,fn,cam,tight)=>{await page.evaluate(([c,t])=>{BF.setCam(c);BF.setTight(t);},[cam,tight]);await page.evaluate(f=>{BF.setOver(eval(f));BF.render();},fn);await page.waitForTimeout(150);
  await page.screenshot({path:path.join(out,name),type:'jpeg',quality:88});};
 if(!process.env.ONLY){
  for(const cam of ['game','side','front'])await grid(`grid_${cam}.jpg`,'c=>c.ts+200',cam,0);
  await grid('grid_both.jpg','c=>c.ts+200','game',1);await grid('grid_target.jpg','c=>c.ts+200','game',2);await grid('grid_beat.jpg','c=>c.tb','game',0);
  await page.evaluate(()=>{BF.setCam('game');BF.setTight(0);});}
 if(process.env.GRIDS_ONLY){await browser.close();return;}
 const cellsInfo=await page.evaluate(()=>BF.cells.map(c=>({key:c.key,rig:c.rig.id,act:c.act,name:c.def.name,tb:c.tb,ts:c.ts,end:c.end})));
 for(const ci of cellsInfo){if(!want(ci.rig,ci.act))continue;
  const idx=cellsInfo.indexOf(ci);await page.evaluate(i=>BF.toggleFocus(BF.cells[i]),idx);
  const offs=[ci.tb-300,ci.tb,Math.round((ci.tb+ci.ts)/2),ci.ts-60,ci.ts+300,ci.ts+1100];
  const box=await page.locator('#stage').boundingBox(),imgs=[];
  for(const t of offs){await page.evaluate(t=>{BF.setOver(()=>t);BF.render();},t);const b=await page.screenshot({type:'jpeg',quality:84,clip:{x:box.x,y:box.y,width:box.width,height:box.height}});imgs.push('data:image/jpeg;base64,'+b.toString('base64'));}
  await page.evaluate(i=>BF.toggleFocus(BF.cells[i]),idx);
  const comp=await ctx.newPage();await comp.setViewportSize({width:1920,height:1660});
  await comp.setContent(`<body style="margin:0;background:#111;color:#eee;font:15px system-ui"><div style="padding:5px 12px">${ci.rig} ${ci.act}: ${ci.name} · real ms ${offs.join(', ')} (beat ${ci.tb}, success ${ci.ts})</div><div style="display:grid;grid-template-columns:repeat(2,1fr);gap:3px">${imgs.map((s,k)=>`<div style="position:relative"><img src="${s}" style="width:100%;display:block"><span style="position:absolute;left:8px;bottom:6px;background:#000a;padding:1px 6px;border-radius:3px">${k+1} · ${offs[k]} ms${offs[k]===ci.tb?' (beat)':''}${offs[k]>=ci.ts?' (after success)':''}</span></div>`).join('')}</div></body>`);
  fs.writeFileSync(path.join(out,`strip_${ci.rig}_${ci.act}.jpg`),await comp.screenshot({type:'jpeg',quality:86}));await comp.close();await page.bringToFront();
  console.log('strip',ci.key);}
 await page.evaluate(()=>{if(window.__errs.length)throw Error(window.__errs.join())});if(errors.length)throw Error(errors.join('\n'));
 await browser.close();process.exitCode=chk.pass?0:1;
}catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
