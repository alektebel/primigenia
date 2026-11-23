#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/befriend_capture.cjs [outdir]
// file://, local three.js, SwiftShader only (never GPU flags). Free-play check first (no ?test=1), then self-check JSON, page grids at the success frame
// in three cameras, a 6-frame strip per version (both animals) and a 6-frame close-on-B strip per version.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/befriend');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const URL_=pathToFileURL(path.join(root,'web/gaitlab/befriend.html')).href;
const only=process.env.ONLY?process.env.ONLY.split(','):null;
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1920,height:1180}}),errors=[];
 // free play (no ?test=1): must animate for 4.5 s with zero page errors; two screenshots must differ
 {const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});fp.on('request',r=>{if(/^https?:/.test(r.url()))fe.push('network '+r.url());});
  await fp.goto(URL_,{timeout:120000});await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});
  await fp.waitForTimeout(900);const a=await fp.screenshot({type:'jpeg',quality:80}),T1=await fp.evaluate(()=>[BF.S.T,window.__frames]);
  await fp.waitForTimeout(3800);const b=await fp.screenshot({type:'jpeg',quality:80}),T2=await fp.evaluate(()=>[BF.S.T,window.__frames,window.__errs.slice()]);
  fs.writeFileSync(path.join(out,'freeplay_a.jpg'),a);fs.writeFileSync(path.join(out,'freeplay_b.jpg'),b);
  const moved=Buffer.compare(a,b)!==0,adv=T2[1]-T1[1]>=4&&T2[0]-T1[0]>500,errs=fe.concat(T2[2]);
  const res={errors:errs,frames:[T1[1],T2[1]],T:[T1[0],T2[0]],screenshotsDiffer:moved,pass:errs.length===0&&moved&&adv};
  fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',res.pass?'PASS':'FAIL',JSON.stringify(res));
  await fp.close();if(!res.pass)throw Error('free-play check failed '+JSON.stringify(res));}
 const page=await ctx.newPage();page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto(URL_+'?test=1',{timeout:120000});await page.waitForFunction(()=>window.__ready&&window.__stylesCheck,null,{timeout:120000});
 const chk=await page.evaluate(()=>window.__stylesCheck);fs.writeFileSync(path.join(out,'check.json'),JSON.stringify(chk,null,1));
 console.log(chk.pass?'SELF-CHECK PASS':'SELF-CHECK FAIL',chk.fails.join('\n'));
 const acts=['sing','dance','charm','pose'];
 const info=await page.evaluate(()=>BF.VERSIONS.map(v=>({id:v.id,act:v.act,name:v.name,pre:v.pre,tb:v.tb,ts:v.ts,W:v.W,A:v.A,end:v.endReal})));
 const setPage=async p=>{await page.evaluate(p=>{BF.setPage(p);},p);};
 // grids at the success frame (+150 ms), three cameras
 for(let p=0;p<4;p++){if(only&&!only.includes(acts[p]))continue;await setPage(p);
  for(const cam of ['game','side','front']){
   await page.evaluate(([c,p])=>{BF.setCam(c);const vs=BF.pageCells().map(x=>x.ver);BF.setOver(vs.map(v=>v.ts+150));BF.render();},[cam,p]);await page.waitForTimeout(120);
   await page.screenshot({path:path.join(out,`grid_${acts[p]}_${cam}.jpg`),type:'jpeg',quality:88});}
  await page.evaluate(()=>BF.setCam('game'));
  // beat-time grid (arrival on the beat)
  await page.evaluate(()=>{BF.setOver(BF.pageCells().map(x=>x.ver.tb));BF.render();});await page.waitForTimeout(120);
  await page.screenshot({path:path.join(out,`grid_${acts[p]}_beat.jpg`),type:'jpeg',quality:88});
 }
 // strips: focus each version
 const strip=async(ver,kind)=>{
  const cells=await page.evaluate(()=>BF.pageCells().length);const idx=await page.evaluate(id=>BF.pageCells().findIndex(c=>c.ver.id===id),ver.id);
  await page.evaluate(i=>BF.toggleFocus(BF.pageCells()[i]),idx);
  const offs=kind==='B'?[ver.pre+Math.round(ver.W/2),ver.tb,ver.tb+Math.round(ver.A*.35),ver.tb+Math.round(ver.A*.7),ver.ts-60,ver.ts+400]:[ver.tb-250,ver.tb,ver.tb+Math.round(ver.A*.5),ver.ts-60,ver.ts+250,ver.ts+1000];
  await page.evaluate(k=>BF.setTight(k==='B'?1:0),kind);
  const box=await page.locator('#stage').boundingBox(),imgs=[];
  for(const t of offs){await page.evaluate(([i,t])=>{const o=[0,0,0,0];o[i]=t;BF.setOver(o);BF.render();},[idx,t]);
   const b=await page.screenshot({type:'jpeg',quality:86,clip:{x:box.x,y:box.y,width:box.width,height:box.height}});imgs.push('data:image/jpeg;base64,'+b.toString('base64'));}
  await page.evaluate(i=>BF.toggleFocus(BF.pageCells()[i]),idx);await page.evaluate(()=>BF.setTight(0));
  const comp=await ctx.newPage();await comp.setViewportSize({width:1920,height:kind==='B'?640:700});
  await comp.setContent(`<body style="margin:0;background:#111;color:#eee;font:15px system-ui"><div style="padding:6px 12px">${ver.name} (${ver.act}/${ver.id}) ${kind==='B'?'close on B':'both animals'}: real ms ${offs.join(', ')} (beat tick ${ver.tb}, success ${ver.ts})</div><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:3px">${imgs.map((s,k)=>`<div style="position:relative"><img src="${s}" style="width:100%;display:block;aspect-ratio:${box.width}/${box.height};object-fit:cover;object-position:50% 52%;height:${kind==='B'?280:300}px"><span style="position:absolute;left:8px;top:6px;background:#000a;padding:1px 6px;border-radius:3px">${k+1} · ${offs[k]} ms${offs[k]===ver.tb?' (beat)':''}${offs[k]>=ver.ts?' (after success)':''}</span></div>`).join('')}</div></body>`);
  fs.writeFileSync(path.join(out,`${kind==='B'?'close':'strip'}_${ver.act}_${ver.id}.jpg`),await comp.screenshot({type:'jpeg',quality:88}));await comp.close();await page.bringToFront();
  console.log(kind==='B'?'close':'strip',ver.id);
 };
 for(const v of info){if(only&&!only.includes(v.act)&&!only.includes(v.id))continue;await setPage(acts.indexOf(v.act));await strip(v,'both');await strip(v,'B');}
 await page.evaluate(()=>{if(window.__errs.length)throw Error(window.__errs.join())});if(errors.length)throw Error(errors.join('\n'));
 await browser.close();process.exitCode=chk.pass?0:1;
}catch(e){console.error('Capture failed:',e.message);if(browser)await browser.close();process.exitCode=1;}})();
