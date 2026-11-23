#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/bite_capture.cjs [outdir]
// file://, local three.js, SwiftShader only (never GPU flags). Grid still at the contact frame, one 6-frame strip per version, focus and camera stills.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/bite');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1920,height:1180}}),page=await ctx.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 page.on('request',r=>{if(/^https?:/.test(r.url()))errors.push('network '+r.url());});
 await page.goto(pathToFileURL(path.join(root,'web/gaitlab/bite.html')).href+'?test=1',{timeout:120000});
 await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:120000});
 const chk=await page.evaluate(()=>window.__stylesCheck);
 fs.writeFileSync(path.join(out,'check.json'),JSON.stringify(chk,null,1));
 console.log(chk.pass?'PASS':'FAIL',chk.fails.join('\n'));
 const shot=async(name,clip)=>{const b=await page.screenshot({type:'jpeg',quality:90,clip});if(name)fs.writeFileSync(path.join(out,name),b);return b;};
 // grid at each version's contact frame (inside the hit-pause)
 for(const cam of ['game','side','front']){
  await page.evaluate(c=>{BITE.setCam(c);BITE.setOver(BITE.VERSIONS.map(v=>v.tc+Math.min(35,v.pause/2)));BITE.render();},cam);
  await shot(`grid_contact_${cam}.jpg`);
 }
 await page.evaluate(()=>BITE.setCam('game'));
 // 6-frame strips: focus each version, capture the stage only, compose in a second page
 const strips=[];
 for(let i=0;i<4;i++){
  await page.evaluate(i=>{BITE.toggleFocus(i);},i);
  const frames=await page.evaluate(i=>BITE.VERSIONS[i].strip,i),imgs=[];
  const box=await page.locator('#stage').boundingBox();
  for(const t of frames){
   await page.evaluate(([i,t])=>{const o=[0,0,0,0];o[i]=t;BITE.setOver(o);BITE.render();},[i,t]);
   const b=await page.screenshot({type:'jpeg',quality:88,clip:{x:box.x,y:box.y,width:box.width,height:box.height}});imgs.push('data:image/jpeg;base64,'+b.toString('base64'));
  }
  await page.evaluate(i=>BITE.toggleFocus(i),i);
  const name=await page.evaluate(i=>BITE.VERSIONS[i].name+' ('+BITE.VERSIONS[i].id+')',i);
  const comp=await ctx.newPage();await comp.setViewportSize({width:1920,height:900});
  await comp.setContent(`<body style="margin:0;background:#111;color:#eee;font:15px system-ui"><div style="padding:6px 12px">${name}: frames at real ms ${frames.join(', ')}</div><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:3px">${imgs.map((s,k)=>`<div style="position:relative"><img src="${s}" style="width:100%;display:block;aspect-ratio:${box.width}/${box.height};object-fit:cover;object-position:50% 35%;height:420px"><span style="position:absolute;left:8px;top:6px;background:#000a;padding:1px 6px;border-radius:3px">${k+1} · ${frames[k]} ms</span></div>`).join('')}</div></body>`);
  const id=await page.evaluate(i=>BITE.VERSIONS[i].id,i);
  fs.writeFileSync(path.join(out,`strip_${id}.jpg`),await comp.screenshot({type:'jpeg',quality:90}));await comp.close();await page.bringToFront();
  console.log('strip',id);
 }
 // focus still + 0.25x state
 await page.evaluate(()=>{BITE.toggleFocus(2);BITE.setOver([0,0,470,0]);BITE.render();});await shot('focus_grab.jpg');await page.evaluate(()=>BITE.toggleFocus(2));
 if(errors.length)throw Error(errors.join('\n'));
 await browser.close();process.exitCode=chk.pass?0:1;
}catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
