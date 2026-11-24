#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 900 nice -n 10 node tools/gaitlab/oil_capture.cjs [outdir]
// file://, local three.js, SwiftShader only (never GPU flags). Free-play check, then a focused screenshot of every version at its key moments.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/oil');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const KEYS={vomit:{a:[1.2,1.95,2.3,2.7,3.6,4.8],b:[1.0,2.1,3.2,4.3,5.0,6.0],c:[1.5,2.1,2.6,3.0,4.0,5.3],d:[1.5,2.3,2.9,3.5,4.9,5.6]},
 ignite:{a:[1.5,1.9,2.1,2.6,3.5,4.5,6.0],b:[1.3,2.2,2.6,3.0,3.8,5.0,6.5],c:[1.0,1.9,2.6,3.5,4.4,6.0,7.6],d:[.8,1.4,2.4,3.4,4.0,5.0,7.5]},
 flame:{a:[.8,1.3,2.0,3.0,3.8,4.8,5.8],b:[1.2,1.7,2.7,3.9,4.6,5.5],c:[1.0,1.7,2.4,3.2,4.0,5.2],d:[.5,1.5,2.7,3.5,4.2,5.5]}};
(async()=>{let browser;try{fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1500,height:900}}),url=pathToFileURL(path.join(root,'web/gaitlab/oil.html')).href,allErr=[];
 // free play: animates for 4 s on every tab with zero page errors, two screenshots differ
 const res={};for(const move of Object.keys(KEYS)){const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});
  await fp.goto(url+'?move='+move,{timeout:120000});await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});await fp.waitForTimeout(900);
  const a=await fp.screenshot({type:'jpeg',quality:80}),T1=await fp.evaluate(()=>[OLab.S.T,window.__frames]);await fp.waitForTimeout(3000);
  const b=await fp.screenshot({type:'jpeg',quality:80}),T2=await fp.evaluate(()=>[OLab.S.T,window.__frames,window.__errs.slice()]);
  const errs=fe.concat(T2[2]);res[move]={errors:errs,frames:[T1[1],T2[1]],T:[T1[0],T2[0]],differ:Buffer.compare(a,b)!==0,pass:errs.length===0&&Buffer.compare(a,b)!==0&&T2[1]-T1[1]>6&&T2[0]>T1[0]};
  fs.writeFileSync(path.join(out,`freeplay_${move}.jpg`),b);await fp.close();}
 fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',JSON.stringify(res));
 const pg=await ctx.newPage();pg.on('pageerror',e=>allErr.push(String(e)));pg.on('console',m=>{if(m.type()==='error')allErr.push(m.text());});
 for(const move of Object.keys(KEYS)){await pg.goto(url+'?test=1&move='+move,{timeout:120000});await pg.waitForFunction(()=>window.__ready,null,{timeout:120000});await pg.evaluate(()=>{OLab.setLoop(false);});
  for(const id of Object.keys(KEYS[move])){await pg.evaluate(i=>{const c=OLab.cell(i);if(OLab.S.focus!==c)OLab.toggleFocus(c);},id);
   for(const t of KEYS[move][id]){await pg.evaluate(t=>{OLab.setT(t);OLab.render();},t);await pg.waitForTimeout(80);await pg.evaluate(t=>{OLab.setT(t);OLab.render();},t);
    fs.writeFileSync(path.join(out,`${move}_${id}_${String(t).replace('.','p')}.jpg`),await pg.locator('#stage').screenshot({type:'jpeg',quality:86}));}}
  allErr.push(...await pg.evaluate(()=>window.__errs));}
 console.log('PAGE ERRORS',JSON.stringify(allErr));const ok=allErr.length===0&&Object.values(res).every(r=>r.pass);console.log(ok?'PASS':'FAIL');if(!ok)process.exitCode=1;
}catch(e){console.error(e);process.exitCode=1;}finally{if(browser)await browser.close();}})();
