/* G48 evidence: frozen frames, optional multi-view anatomy and standalone GLBs. */
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const output=process.argv[2];
// G48_VIEWS='[{"name":"front ¾","yaw":0.5,"pitch":0.18,"distance":7},...]'
const config={ids:process.env.G48_PARTS?.split(','),yaw:+(process.env.G48_YAW||1.1),pitch:+(process.env.G48_PITCH||.23),distance:process.env.G48_DISTANCE?+process.env.G48_DISTANCE:null,views:process.env.G48_VIEWS?JSON.parse(process.env.G48_VIEWS):null};
if(!output)throw Error('Usage: node tests/studio_parts_contact.cjs output.png');
if(config.views&&(!Array.isArray(config.views)||!config.views.length||config.views.some(v=>![v.yaw,v.pitch,v.distance].every(Number.isFinite)||v.distance<=0)))throw Error('G48_VIEWS must contain named yaw/pitch/distance objects');
const referenceHook=`camera.fov=50;camera.updateProjectionMatrix();window.__g48Reference=async file=>{
 const model=(await loader.loadAsync('parts/'+file)).scene;
 model.rotation.y=-Math.PI/2;model.updateMatrixWorld(true);
 const box=new T.Box3().setFromObject(model),r=box.getSize(V()).length()/2;
 model.position.sub(box.getCenter(V()));
 const reference=new T.Scene();reference.background=new T.Color('#172733');reference.environment=scene.environment;
 reference.add(model,new T.HemisphereLight(0xffffff,0x665544,1.4));
 const key=new T.DirectionalLight(0xfff2e0,2.8);key.position.set(3,4,5);reference.add(key);
 const cam=new T.PerspectiveCamera(36,1,.01,100),distance=r/Math.sin(Math.PI/10)*1.15;
 cam.position.set(distance*.65,distance*.52,distance*.72);cam.lookAt(0,0,0);
 const target=new T.WebGLRenderTarget(180,180);target.texture.encoding=T.sRGBEncoding;
 const pixels=new Uint8Array(180*180*4);
 try{
  renderer.setRenderTarget(target);renderer.render(reference,cam);renderer.readRenderTargetPixels(target,0,0,180,180,pixels);
  const c=document.createElement('canvas');c.width=c.height=180;const ctx=c.getContext('2d'),im=ctx.createImageData(180,180);
  for(let y=0;y<180;y++)im.data.set(pixels.subarray((179-y)*180*4,(180-y)*180*4),y*180*4);ctx.putImageData(im,0,0);return c.toDataURL();
 }finally{renderer.setRenderTarget(null);target.dispose();model.traverse(o=>{o.geometry?.dispose();if(o.material)for(const m of [].concat(o.material))m.dispose()})}
};`;
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.route('**/studio.js',async route=>{
   const response=await route.fetch();let source=(await response.text()).replaceAll('requestAnimationFrame(loop);','/* Frozen evidence frame. */');
   if(config.views)source=source.replace('bootDocument();resize();',referenceHook+'\nbootDocument();resize();');
   await route.fulfill({response,body:source});
  });
  await page.goto(base+'/web/studio/');
  await page.waitForFunction(()=>window.CreatureStudio?.ready,{timeout:90000});
  await page.addStyleTag({content:'#gl{width:420px!important;height:300px!important}'});
  const cells=await page.evaluate(async config=>{
   dispatchEvent(new Event('resize'));
   const S=CreatureStudio,cells=[];
   for(const entry of S.parts.parts.filter(p=>p.file&&(!config.ids||config.ids.includes(p.id)))){
    const views=[];
    for(const seed of ['Merodeador','Zancuda']){
     S.preset(seed);const g=S.genome();
     // Keep the seed anatomy, remove ornaments and competing mouths.
     g.parts=g.parts.filter(p=>['pata','zanca','ojo'].includes(p.type));
     g.parts.push(S.defaults(entry.id));S.load(g);S.attachmentRoots();
     for(const view of config.views||[{yaw:config.yaw,pitch:config.pitch,distance:config.distance||(seed==='Zancuda'?10.5:11)}]){
      S.view(view.yaw,view.pitch,view.distance);
      views.push({seed,name:view.name||'',image:document.getElementById('gl').toDataURL()});
     }
    }
    cells.push({id:entry.id,views,reference:config.views?await __g48Reference(entry.file):null,file:entry.file});
   }
   return cells;
  },config);
  if(errors.length)throw Error(errors.join('\n'));
  const multi=!!config.views,width=multi?180+840*config.views.length:1680;
  await page.setViewportSize({width,height:(multi?cells.length:Math.ceil(cells.length/2))*(multi?360:337)});
  const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
  await page.setContent('<style>body{margin:0;background:#101c24;color:#f3e5c8;font:17px sans-serif}main{display:grid;grid-template-columns:repeat('+(multi?1:2)+','+(multi?width:840)+'px)}article{height:'+(multi?360:337)+'px}h3{font-size:18px;margin:8px 12px}.row{display:flex}.view{width:420px}.label{font-size:13px;color:#b8cbd5;height:23px;padding-left:12px}.view img{width:420px;height:300px}.ref{width:180px}.ref img{width:180px;height:180px}span{font-size:13px;color:#b8cbd5;margin-left:20px}</style><main>'+cells.map(c=>'<article><h3>'+c.id+'<span>default mount · '+(multi?'GLB shape reference / Merodeador / Zancuda':'Merodeador / Zancuda')+'</span></h3><div class="row">'+(multi?'<div class="ref"><div class="label">GLB alone</div><img src="'+c.reference+'"></div>':'')+c.views.map(v=>'<div class="view">'+(multi?'<div class="label">'+v.seed+' · '+esc(v.name)+'</div>':'')+'<img src="'+v.image+'"></div>').join('')+'</div></article>').join('')+'</main>');
  await page.screenshot({path:output,fullPage:true,timeout:90000});
  if(process.env.G48_DETAIL_DIR){
   fs.mkdirSync(process.env.G48_DETAIL_DIR,{recursive:true});
   for(let i=0;i<cells.length;i++)await page.locator('article').nth(i).screenshot({path:path.join(process.env.G48_DETAIL_DIR,cells[i].id+'.png'),timeout:90000});
  }
  fs.writeFileSync(output.replace(/\.png$/,'.json'),JSON.stringify({browser:browser.version(),renderer:'SwiftShader software WebGL',fieldOfView:multi?50:42,camera:config.views||{yaw:config.yaw,pitch:config.pitch,distances:config.distance?[config.distance,config.distance]:[11,10.5]},parts:cells.map(c=>c.id),references:multi?cells.map(c=>({id:c.id,file:c.file})):[],errors},null,2)+'\n');
  console.log('PASS: '+cells.length+' parts × 2 presets × '+(config.views?.length||1)+' views'+(multi?' + standalone GLBs':'')+' captured to '+path.resolve(output));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
