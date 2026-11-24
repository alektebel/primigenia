#!/usr/bin/env node
// NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/social_duel_capture.cjs [outdir]
// file://, local three.js, SwiftShader only. Free play first (no ?test=1, >= 4 s, simulated key presses, zero page errors, two differing screenshots),
// then the ?test=1 self-check, then a scripted playthrough strip at brain 1 and at brain 3 (map and arrows), plus easter-egg and fail shots.
const {chromium}=require('playwright');const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const root=path.resolve(__dirname,'../..'),out=process.argv[2]||path.join(root,'docs/evidence/loco/social_duel');
const chrome=path.join(process.env.HOME,'.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');
const URL_=pathToFileURL(path.join(root,'web/gaitlab/social_duel.html')).href;
(async()=>{let browser;try{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({executablePath:fs.existsSync(chrome)?chrome:undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const ctx=await browser.newContext({viewport:{width:1600,height:900}});
 {const fp=await ctx.newPage(),fe=[];fp.on('pageerror',e=>fe.push(String(e)));fp.on('console',m=>{if(m.type()==='error')fe.push(m.text());});fp.on('request',r=>{if(/^https?:/.test(r.url()))fe.push('network '+r.url());});
  await fp.goto(URL_,{timeout:120000});await fp.waitForFunction(()=>window.__ready,null,{timeout:120000});
  await fp.waitForTimeout(900);const a=await fp.screenshot({type:'jpeg',quality:82}),T1=await fp.evaluate(()=>[SD.S.t,window.__frames,SD.S.B.x]);
  await fp.keyboard.down('KeyW');await fp.waitForTimeout(1500);await fp.keyboard.up('KeyW');
  await fp.keyboard.press('Digit1');await fp.waitForTimeout(300);const act1=await fp.evaluate(()=>SD.S.B.act&&SD.S.B.act.k);await fp.waitForTimeout(1200);
  await fp.keyboard.press('KeyO');await fp.keyboard.press('Digit2');await fp.waitForTimeout(1200);
  await fp.keyboard.press('KeyB');await fp.waitForTimeout(400);
  const T2=await fp.evaluate(()=>[SD.S.t,window.__frames,SD.S.B.x,SD.S.stats.beats,SD.S.brain,SD.S.B.pressed,window.__errs.slice()]);
  const b=await fp.screenshot({type:'jpeg',quality:82});fs.writeFileSync(path.join(out,'freeplay_a.jpg'),a);fs.writeFileSync(path.join(out,'freeplay_b.jpg'),b);
  const errs=fe.concat(T2[6]);const res={errors:errs,frames:[T1[1],T2[1]],simT:[T1[0],T2[0]],xMoved:[T1[2],T2[2]],pressedActs:T2[5],firstAct:act1,brainAfterB:T2[4],screenshotsDiffer:Buffer.compare(a,b)!==0};
  res.pass=errs.length===0&&res.screenshotsDiffer&&T2[1]-T1[1]>=4&&T2[0]-T1[0]>3&&T2[2]>T1[2]+1&&act1==='sing'&&T2[4]===2;
  fs.writeFileSync(path.join(out,'freeplay.json'),JSON.stringify(res,null,1));console.log('FREEPLAY',res.pass?'PASS':'FAIL',JSON.stringify(res));await fp.close();if(!res.pass)throw Error('free-play failed');}
 const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto(URL_+'?test=1',{timeout:120000});await page.waitForFunction(()=>window.__sdCheck,null,{timeout:200000});
 const chk=await page.evaluate(()=>window.__sdCheck);fs.writeFileSync(path.join(out,'check.json'),JSON.stringify(chk,null,1));console.log(chk.pass?'SELF-CHECK PASS':'SELF-CHECK FAIL\n'+chk.fails.join('\n'));
 // scripted playthrough strips
 const shot=async n=>{await page.evaluate(()=>{document.getElementById('summary').style.visibility='hidden';SD.renderNow();});await page.waitForTimeout(150);await page.screenshot({path:path.join(out,n+'.jpg'),type:'jpeg',quality:84});};
 const strip=async(brain,tag)=>{await page.evaluate(b=>{SD.api.setTier(1);SD.api.setBrain(b);SD.api.setEgg('none');SD.api.setNight(false);SD.setBot(true,{});SD.snapCam();},brain);
  const plan=[[.2,'start'],[9,'approach'],[8,'curious'],[6,'close'],[4,'chain'],[4,'trusting'],[8,'bonded']];let i=0;
  for(const [dt,name] of plan){await page.evaluate(d=>{SD.advance(d);},dt);i++;await shot(`${tag}_${String(i).padStart(2,'0')}_${name}`);const st=await page.evaluate(()=>[SD.C.moodState(SD.S),+SD.S.T.mx.toFixed(2),+SD.S.T.my.toFixed(2),+SD.C.dist(SD.S).toFixed(1),+SD.S.t.toFixed(1)]);console.log(tag,name,JSON.stringify(st));}
  await page.evaluate(()=>SD.setBot(false));};
 await strip(1,'brain1');await page.evaluate(()=>{document.getElementById('summary').style.visibility='visible';});await page.waitForTimeout(100);await page.screenshot({path:path.join(out,'summary_card.jpg'),type:'jpeg',quality:84});await strip(3,'brain3');
 await page.evaluate(()=>{document.getElementById('summary').style.visibility='hidden';});
 // body language contrast: wary (run at it) vs bonded
 await page.evaluate(()=>{SD.api.setTier(1);SD.api.setBrain(2);SD.setBot(true,{mode:'run'});SD.snapCam();SD.advance(1.0);});await shot('fear_run');await page.evaluate(()=>SD.setBot(false));
 await page.evaluate(()=>{SD.api.setTier(3);SD.api.setBrain(1);SD.setBot(true,{});SD.snapCam();SD.advance(80);});await shot('tier3_brain1_ignored');
 await page.evaluate(()=>{SD.setBot(false);SD.api.setTier(1);SD.api.setBrain(3);SD.api.setEgg('raid');SD.S.B.x=14;SD.S.T.noticed=true;SD.C.startRaid(SD.S);SD.snapCam();SD.advance(1.5);});await shot('raid');
 await page.evaluate(()=>{SD.api.setEgg('night');SD.api.setNight(true);SD.api.setBrain(2);SD.S.B.x=15;SD.S.T.noticed=true;SD.snapCam();SD.advance(1.5);SD.advance(2);});await shot('night');
 {const {execSync}=require('child_process');for(const tag of ['brain1','brain3']){const fs_=fs.readdirSync(out).filter(f=>f.startsWith(tag+'_')).sort().map(f=>path.join(out,f));
  try{execSync(`montage ${fs_.map(f=>'"'+f+'"').join(' ')} -tile 4x -geometry 800x450+2+2 -background '#111' "${path.join(out,'strip_'+tag+'.jpg')}"`);}catch(e){console.log('montage failed',e.message);}}}
 console.log('PAGE ERRORS',errors.length?errors.join('\n'):'none');
 fs.writeFileSync(path.join(out,'pageerrors.json'),JSON.stringify(errors));
 if(!chk.pass||errors.length)process.exitCode=1;
}catch(e){console.error('FAIL',e.message);process.exitCode=1;}finally{if(browser)await browser.close();}})();
