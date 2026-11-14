/* G48 evidence: one frozen frame per part/preset, no animation render loop. */
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const output=process.argv[2];
const config={ids:process.env.G48_PARTS?.split(','),yaw:+(process.env.G48_YAW||1.1),pitch:+(process.env.G48_PITCH||.23),distance:process.env.G48_DISTANCE?+process.env.G48_DISTANCE:null};
if(!output)throw Error('Usage: node tests/studio_parts_contact.cjs output.png');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/studio.js',async route=>{
   const response=await route.fetch();
   await route.fulfill({response,body:(await response.text()).replaceAll('requestAnimationFrame(loop);','/* Frozen evidence frame. */')});
  });
  await page.goto(base+'/web/studio/');
  await page.waitForFunction(()=>window.CreatureStudio?.ready,{timeout:90000});
  await page.addStyleTag({content:'#gl{width:420px!important;height:300px!important}'});
  const cells=await page.evaluate(config=>{
   dispatchEvent(new Event('resize'));
   const S=CreatureStudio,cells=[];
   for(const entry of S.parts.parts.filter(p=>p.file&&(!config.ids||config.ids.includes(p.id)))){
    const views=[];
    for(const seed of ['Merodeador','Zancuda']){
     S.preset(seed);const g=S.genome();
     // Keep the seed anatomy, remove its ornaments and competing mouth.
     g.parts=g.parts.filter(p=>['pata','zanca','ojo'].includes(p.type));
     g.parts.push(S.defaults(entry.id));S.load(g);S.attachmentRoots();
     S.view(config.yaw,config.pitch,config.distance||(seed==='Zancuda'?10.5:11));
     views.push(document.getElementById('gl').toDataURL());
    }
    cells.push({id:entry.id,views});
   }
   return cells;
  },config);
  if(errors.length)throw Error(errors.join('\n'));
  await page.setViewportSize({width:1680,height:Math.ceil(cells.length/2)*337});
  await page.setContent('<style>body{margin:0;background:#101c24;color:#f3e5c8;font:17px sans-serif}main{display:grid;grid-template-columns:repeat(2,840px)}article{height:337px}h3{font-size:18px;margin:8px 12px}img{width:420px;height:300px}span{font-size:13px;color:#b8cbd5;margin-left:20px}</style><main>'+cells.map(c=>'<article><h3>'+c.id+'<span>Merodeador / Zancuda · default mount</span></h3>'+c.views.map(src=>'<img src="'+src+'">').join('')+'</article>').join('')+'</main>');
  await page.screenshot({path:output,fullPage:true,timeout:90000});
  fs.writeFileSync(output.replace(/\.png$/,'.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',camera:{yaw:config.yaw,pitch:config.pitch,distances:config.distance?[config.distance,config.distance]:[11,10.5]},parts:cells.map(c=>c.id),errors},null,2)+'\n');
  console.log('PASS: '+cells.length+' parts × 2 presets captured to '+path.resolve(output));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
