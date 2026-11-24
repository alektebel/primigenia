#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/attack_context_capture.cjs [outdir]
// file://, local three.js, SwiftShader only (never GPU flags). Free-play check first (no ?test=1), then self-check JSON, grid stills, per-attack
// 2x2 pages and 6-frame strips per attack x option x context (strips are tiled with ImageMagick montage when it is installed).
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),cp=require('child_process');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/attack_context');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const URL_=pathToFileURL(path.join(root,'web/gaitlab/attack_context.html')).href;
const OFFS={bite:[-300,-100,0,150,500,1100],pounce:[-700,-300,-100,0,200,700],spit:[-600,-200,50,250,600,1000],roar:[-500,-100,100,400,800,1300]};
const hasMontage=(()=>{try{cp.execSync('which montage',{stdio:'ignore'});return true;}catch(e){return false;}})();
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1600,height:900}});
 // ---- free play (no ?test=1): must animate for 4.5 s with zero page errors; two screenshots must differ
 {const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});fp.on('request',r=>{if(/^https?:/.test(r.url()))fe.push('network '+r.url());});
  await fp.goto(URL_,{timeout:120000});await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});
  await fp.waitForTimeout(900);const a=await fp.screenshot({type:'jpeg',quality:80}),T1=await fp.evaluate(()=>[AC.S.T,window.__frames]);
  await fp.waitForTimeout(3800);const b=await fp.screenshot({type:'jpeg',quality:80}),T2=await fp.evaluate(()=>[AC.S.T,window.__frames,window.__errs.slice()]);
  fs.writeFileSync(path.join(out,'freeplay_a.jpg'),a);fs.writeFileSync(path.join(out,'freeplay_b.jpg'),b);
  const moved=Buffer.compare(a,b)!==0,adv=T2[1]-T1[1]>=3&&T2[0]-T1[0]>500,errs=fe.concat(T2[2]);
  const res={errors:errs,frames:[T1[1],T2[1]],T:[T1[0],T2[0]],screenshotsDiffer:moved,pass:errs.length===0&&moved&&adv};
  fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',res.pass?'PASS':'FAIL',JSON.stringify(res));
  await fp.close();if(!res.pass)throw Error('free-play check failed');}
 const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto(URL_+'?test=1',{timeout:120000});await page.waitForFunction(()=>window.__ready&&window.__check,null,{timeout:120000});
 const chk=await page.evaluate(()=>window.__check);fs.writeFileSync(path.join(out,'check.json'),JSON.stringify(chk,null,1));
 console.log(chk.pass?'SELF-CHECK PASS':'SELF-CHECK FAIL',chk.fails.join('\n'));
 const anchorMs=(i,off)=>page.evaluate(([i,off])=>{const c=AC.cells[i],s=c.spec,ra=ACSIM.anim2real(s,Math.round((s.anchor+off/1000)/ACCORE0.DT)*ACCORE0.DT);let ms=ra*ACCORE0.DT*1000;if(off===0&&s.hit&&s.hit.pause)ms+=s.hit.pause/2;return ms;},[i,off]);
 // ---- grids: all 16 at the contact/fire frame, option A and B, auto camera plus the fixed game camera
 for(const opt of ['A','B'])for(const cam of ['auto','game']){
  await page.evaluate(([o,c])=>{AC.setView('all');AC.setOpt(o);AC.setCam(c);},[opt,cam]);
  const ms=[];for(let i=0;i<16;i++)ms.push(await anchorMs(i,0));
  await page.evaluate(m=>{AC.setOver(m);AC.render();},ms);await page.waitForTimeout(150);
  await page.screenshot({path:path.join(out,`grid_${opt}_${cam}.jpg`),type:'jpeg',quality:86});}
 // ---- per-attack pages (2x2, large cells), strips per context
 for(const far of ['standing','walking'])for(const opt of ['A','B']){
  await page.evaluate(([f,o])=>{AC.setFar(f);AC.setOpt(o);AC.setCam('auto');},[far,opt]);
  for(const at of ['bite','pounce','spit','roar']){
   await page.evaluate(a=>AC.setView(a),at);
   const rects=await page.evaluate(a=>AC.cells.filter(c=>c.at===a).map(c=>{const r=c.el.getBoundingClientRect();return {i:c.idx,cx:c.cx,x:r.left,y:r.top,w:r.width,h:r.height};}),at);
   const offs=OFFS[at];
   const farTag=far==='walking'?'_farwalk':'';
   if(far==='standing'||true){
    const ms=new Array(16).fill(0);for(const r of rects)ms[r.i]=await anchorMs(r.i,0);
    await page.evaluate(m=>{AC.setOver(m);AC.render();},ms);await page.waitForTimeout(120);
    if(far==='standing')await page.screenshot({path:path.join(out,`page_${at}_${opt}.jpg`),type:'jpeg',quality:86});}
   for(const r of rects){
    if(far==='walking'&&r.cx!=='far')continue;
    const files=[];
    for(let k=0;k<offs.length;k++){const ms=new Array(16).fill(0);ms[r.i]=await anchorMs(r.i,offs[k]);await page.evaluate(m=>{AC.setOver(m);AC.render();},ms);await page.waitForTimeout(40);
     const f=path.join(out,`.tmp_${at}_${opt}_${r.cx}${farTag}_${k}.jpg`);await page.screenshot({path:f,type:'jpeg',quality:84,clip:{x:r.x,y:r.y,width:r.w,height:r.h}});files.push(f);}
    const dest=path.join(out,`strip_${at}_${opt}_${r.cx}${farTag}.jpg`);
    if(hasMontage)cp.execSync(`montage ${files.join(' ')} -tile 3x -geometry 520x+2+2 -background '#111' ${dest}`);else fs.copyFileSync(files[3],dest);
    files.forEach(f=>fs.unlinkSync(f));}
  }}
 // ---- focus still on the follow camera of one moving cell
 await page.evaluate(()=>{AC.setFar('standing');AC.setOpt('A');AC.setView('all');AC.setCam('follow');AC.toggleFocus(3);});
 const ms=new Array(16).fill(0);ms[3]=await anchorMs(3,-200);await page.evaluate(m=>{AC.setOver(m);AC.render();},ms);await page.waitForTimeout(150);
 await page.screenshot({path:path.join(out,'focus_charge_follow.jpg'),type:'jpeg',quality:88});
 fs.writeFileSync(path.join(out,'page_errors.json'),JSON.stringify(errors,null,1));
 if(errors.length)throw Error('page errors: '+errors.join(' | '));
 console.log('DONE',out);
}catch(e){console.error('FAIL',e.message);process.exitCode=1;}finally{if(browser)await browser.close();}})();
