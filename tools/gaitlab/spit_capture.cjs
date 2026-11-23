#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/spit_capture.cjs [outdir]
// file://, local three.js, SwiftShader only (never GPU flags). Contact grid, one 6-frame strip per version, release stills.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/spit');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1920,height:1180}}),page=await ctx.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 page.on('request',r=>{if(/^https?:/.test(r.url()))errors.push('network '+r.url());});

 // free play (no ?test=1): must animate for 4.5 s with zero page errors; two screenshots must differ
 {const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});
  await fp.goto(pathToFileURL(path.join(root,'web/gaitlab/spit.html')).href,{timeout:120000});
  await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});
  await fp.waitForTimeout(900);const a=await fp.screenshot({type:'jpeg',quality:80}),T1=await fp.evaluate(()=>[SPIT.S.T,window.__frames]);
  await fp.waitForTimeout(3800);const b=await fp.screenshot({type:'jpeg',quality:80}),T2=await fp.evaluate(()=>[SPIT.S.T,window.__frames,window.__errs.slice()]);
  fs.writeFileSync(path.join(out,'freeplay_a.jpg'),a);fs.writeFileSync(path.join(out,'freeplay_b.jpg'),b);
  const moved=Buffer.compare(a,b)!==0,adv=T2[1]-T1[1]>8&&T2[0]-T1[0]>500,errs=fe.concat(T2[2]);
  const res={errors:errs,frames:[T1[1],T2[1]],T:[T1[0],T2[0]],screenshotsDiffer:moved,pass:errs.length===0&&moved&&adv};
  fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',res.pass?'PASS':'FAIL',JSON.stringify(res));
  await fp.close();if(!res.pass)throw Error('free-play check failed '+JSON.stringify(res));}
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/spit.html')).href+'?test=1',{timeout:120000});
 await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:120000});
 const chk=await page.evaluate(()=>window.__stylesCheck);
 fs.writeFileSync(path.join(out,'check.json'),JSON.stringify(chk,null,1));
 console.log(chk.pass?'PASS':'FAIL',chk.fails.join('\n'));
 const shot=async(name,clip)=>{const b=await page.screenshot({type:'jpeg',quality:90,clip});if(name)fs.writeFileSync(path.join(out,name),b);return b;};
 // grid at each version's contact frame (inside the hit-pause)
 for(const cam of ['game','side','front']){
  await page.evaluate(c=>{SPIT.setCam(c);SPIT.setOver(SPIT.VERSIONS.map(v=>v.tc+Math.max(40,Math.min(35,v.pause/2))));SPIT.render();},cam);
  await shot(`grid_contact_${cam}.jpg`);
 }
 await page.evaluate(()=>SPIT.setCam('game'));
 // 6-frame strips: focus each version, capture the stage only, compose in a second page
 const strips=[];
 for(let i=0;i<4;i++){
  await page.evaluate(i=>{SPIT.toggleFocus(i);},i);
  const frames=await page.evaluate(i=>SPIT.VERSIONS[i].strip,i),imgs=[];
  const box=await page.locator('#stage').boundingBox();
  for(const t of frames){
   await page.evaluate(([i,t])=>{const o=[0,0,0,0];o[i]=t;SPIT.setOver(o);SPIT.render();},[i,t]);
   const b=await page.screenshot({type:'jpeg',quality:88,clip:{x:box.x,y:box.y,width:box.width,height:box.height}});imgs.push('data:image/jpeg;base64,'+b.toString('base64'));
  }
  await page.evaluate(i=>SPIT.toggleFocus(i),i);
  const name=await page.evaluate(i=>SPIT.VERSIONS[i].name+' ('+SPIT.VERSIONS[i].id+')',i);
  const comp=await ctx.newPage();await comp.setViewportSize({width:1920,height:900});
  await comp.setContent(`<body style="margin:0;background:#111;color:#eee;font:15px system-ui"><div style="padding:6px 12px">${name}: frames at real ms ${frames.join(', ')}</div><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:3px">${imgs.map((s,k)=>`<div style="position:relative"><img src="${s}" style="width:100%;display:block;aspect-ratio:${box.width}/${box.height};object-fit:cover;object-position:50% 35%;height:420px"><span style="position:absolute;left:8px;top:6px;background:#000a;padding:1px 6px;border-radius:3px">${k+1} · ${frames[k]} ms</span></div>`).join('')}</div></body>`);
  const id=await page.evaluate(i=>SPIT.VERSIONS[i].id,i);
  fs.writeFileSync(path.join(out,`strip_${id}.jpg`),await comp.screenshot({type:'jpeg',quality:90}));await comp.close();await page.bringToFront();
  console.log('strip',id);
 }
 // focus still + 0.25x state
 for(const k of [0,1,2,3]){await page.evaluate(k=>{SPIT.toggleFocus(k);const o=[0,0,0,0];o[k]=SPIT.VERSIONS[k].strip[4]+45;SPIT.setOver(o);SPIT.render();},k);await shot(`focus_${await page.evaluate(k=>SPIT.VERSIONS[k].id,k)}_contact.jpg`);await page.evaluate(k=>SPIT.toggleFocus(k),k);}
 await page.evaluate(()=>{if(window.__errs.length)throw Error(window.__errs.join())});if(errors.length)throw Error(errors.join('\n'));
 await browser.close();process.exitCode=chk.pass?0:1;
}catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
