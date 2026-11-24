#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 900 nice -n 10 node tools/gaitlab/signature_capture.cjs <outdir> [id,id,...]
// file://, local three.js, SwiftShader only (never GPU flags). Free-play check (no ?test=1: must animate, zero page errors), a grid shot at a few times,
// then per attack: wind-up frame, impact frame (ti + hit-stop), and a 6-frame contact sheet (wind-up .. recovery).
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/signature2'),only=process.argv[3]?process.argv[3].split(','):null;
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const URL_=pathToFileURL(path.join(root,'web/gaitlab/signature.html')).href;
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1700,height:1000}}),errors=[];
 {const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});fp.on('request',r=>{if(/^https?:/.test(r.url()))fe.push('network '+r.url());});
  await fp.goto(URL_,{timeout:120000});await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});
  await fp.waitForTimeout(1500);const a=await fp.screenshot({type:'jpeg',quality:80}),T1=await fp.evaluate(()=>[SG.S.T,window.__frames]);
  await fp.waitForTimeout(4500);const b=await fp.screenshot({type:'jpeg',quality:80}),T2=await fp.evaluate(()=>[SG.S.T,window.__frames,window.__errs.slice()]);
  // enlarge one cell in free play too
  await fp.evaluate(()=>SG.toggleFocus(SG.cells[12]));await fp.waitForTimeout(2500);const T3=await fp.evaluate(()=>[SG.S.T,window.__frames]);
  fs.writeFileSync(path.join(out,'freeplay_a.jpg'),a);fs.writeFileSync(path.join(out,'freeplay_b.jpg'),b);
  const res={errors:fe.concat(T2[2]),frames:[T1[1],T2[1],T3[1]],T:[T1[0],T2[0],T3[0]],gridFps:(T2[1]-T1[1])/((T2[0]-T1[0])/1000),focusFps:(T3[1]-T2[1])/((T3[0]-T2[0])/1000),screenshotsDiffer:Buffer.compare(a,b)!==0};
  res.pass=res.errors.length===0&&res.screenshotsDiffer&&T2[1]-T1[1]>=3&&T3[1]-T2[1]>=2;
  fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',res.pass?'PASS':'FAIL',JSON.stringify(res));await fp.close();if(!res.pass)throw Error('free-play check failed');}
 const page=await ctx.newPage();page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto(URL_+'?test=1',{timeout:120000});await page.waitForFunction(()=>window.__ready,null,{timeout:120000});
 const defs=await page.evaluate(()=>SG.cells.map(c=>({id:c.def.id,ti:c.def.ti,tw:c.def.tw,hs:c.def.hs})));
 for(const kind of ['windup','impact','mid']){await page.evaluate(k=>{SG.setT(0);SG.S.per=SG.cells.map(c=>k==='windup'?c.def.tw:k==='impact'?c.def.ti+c.def.hs+.04:c.def.ti+c.def.hs+.45);SG.render();},kind);
  await page.waitForTimeout(300);await page.screenshot({path:path.join(out,`grid_${kind}.jpg`),type:'jpeg',quality:88});}
 await page.evaluate(()=>{SG.S.per=null;});
 for(const d of defs){if(only&&!only.includes(d.id))continue;
  await page.evaluate(id=>SG.toggleFocus(SG.cellAt(id)),d.id);
  const shot=async(t,name)=>{await page.evaluate(t=>{SG.setT(t);SG.render();},t);await page.waitForTimeout(60);return page.locator('#stage').screenshot({type:'jpeg',quality:88,path:name?path.join(out,name):undefined});};
  await shot(d.tw,`${d.id}_windup.jpg`);await shot(d.ti+d.hs+.03,`${d.id}_impact.jpg`);
  const times=[d.tw,d.ti-.1,d.ti+d.hs+.03,d.ti+d.hs+.25,d.ti+d.hs+.7,2.7],imgs=[];for(const t of times)imgs.push((await shot(t)).toString('base64'));
  await page.evaluate(id=>SG.toggleFocus(SG.cellAt(id)),d.id);
  const cp=await ctx.newPage();await cp.setViewportSize({width:1700,height:820});
  await cp.setContent('<body style="margin:0;background:#111;color:#eee;font:13px sans-serif"><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:2px">'+imgs.map((s,k)=>`<div style="position:relative"><img style="width:100%;display:block" src="data:image/jpeg;base64,${s}"><span style="position:absolute;left:6px;bottom:4px;background:#000a;padding:1px 5px">${d.id} t=${times[k].toFixed(2)}</span></div>`).join('')+'</div></body>');
  await cp.waitForTimeout(100);await cp.screenshot({path:path.join(out,`${d.id}_sheet.jpg`),type:'jpeg',quality:86});await cp.close();console.log(d.id);}
 await page.evaluate(()=>{if(window.__errs.length)throw Error(window.__errs.join())});if(errors.length)throw Error(errors.join('\n'));
 await browser.close();
}catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
