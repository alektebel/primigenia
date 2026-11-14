/* G48 geometry/animation checks run against the actual studio closure. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const fixture=JSON.parse(fs.readFileSync('tests/fixtures/studio/v4-glb-parts.json'));
const inspect=`window.__partsTest={step:update,inspect:()=>{
 creature.updateMatrixWorld(true);limbs.updateMatrixWorld(true);
 const objects=objs.map(o=>{
  let finite=true,vertices=0,regions={},membranes=[],localBox=new T.Box3(),inverse=o.g.matrixWorld.clone().invert();
  o.g.traverse(m=>{if(!m.isMesh)return;const p=m.geometry.attributes.position,n=m.geometry.attributes.normal;vertices+=p.count;
   finite=finite&&[...p.array,...n.array].every(Number.isFinite);localBox.union(new T.Box3().setFromBufferAttribute(p).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,m.matrixWorld)));
   const r=m.userData.materialRegion||'unknown';regions[r]=(regions[r]||0)+1;
   if(r==='membrane')membranes.push({shared:m.material===membraneM,side:m.material.side,transparent:m.material.transparent,opacity:m.material.opacity});
  });
  const ud=o.g.userData,box=new T.Box3().setFromObject(o.g);
  return {type:o.p.type,side:o.sg,vertices,finite,regions,membranes,radius:ud.mountRadius,localSize:localBox.getSize(V()).toArray(),size:box.getSize(V()).toArray(),min:box.min.toArray(),max:box.max.toArray(),jaw:ud.jaw?.rotation.x,wing:ud.wing?.rotation.toArray().slice(0,3),sacs:ud.sacs?.map(s=>s.scale.x),arm:ud.arm?.rotation.x,tail:ud.tail?.rotation.y,sway:ud.sway?.rotation.x};
 });
 return {objects,legs:legs.map(l=>({type:l.p.type,side:l.sg,width:l.w,knee:l.lo.position.toArray(),foot:l.ft.position.toArray(),sole:l.ft.position.y,height:l.a+l.b,finite:[...l.up.position.toArray(),...l.lo.position.toArray(),...l.ft.position.toArray()].every(Number.isFinite)}))};
}};`;
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/studio.js',async route=>{
   const response=await route.fetch();let source=(await response.text()).replaceAll('requestAnimationFrame(loop);','/* manual test clock */');
   source=source.replace('bootDocument();resize();',inspect+'\nbootDocument();resize();');
   await route.fulfill({response,body:source});
  });
  await page.goto(base+'/web/studio/');await page.waitForFunction(()=>window.CreatureStudio?.ready,{timeout:90000});
  const result=await page.evaluate(fixture=>{
   const S=CreatureStudio,H=__partsTest,check=(x,m)=>{if(!x)throw Error(m)},ids=S.parts.parts.filter(e=>e.shape_ref).map(e=>e.id);
   let placements=0;
   S.load(fixture);H.step(0);check(JSON.stringify(S.genome())===JSON.stringify(fixture),'old /4 changed');
   const legacyViews=H.inspect();for(const p of fixture.parts)check([...legacyViews.objects,...legacyViews.legs].some(v=>v.type===p.type&&v.finite),'old /4 missing '+p.type);
   for(const seed of ['Merodeador','Zancuda'])for(const id of ids){
    S.preset(seed);const base=S.genome();base.parts=[S.defaults(id)];S.load(base);H.step(0);
    const before=H.inspect(),views=[...before.objects,...before.legs].filter(v=>v.type===id);
    check(views.length>0&&views.every(v=>v.finite),'nonfinite/missing '+id);
    check(S.attachmentRoots().every(r=>r.meshDistance<.045),'root '+id);
    if(before.legs.length){check(before.legs.length===2,'leg pair '+id);check(before.legs.every(l=>Math.abs(l.sole)<1e-6),'foot above ground '+id)}
    if(before.objects[0]?.membranes.length)check(before.objects.every(o=>o.membranes.every(m=>m.shared&&m.side===2&&m.transparent&&m.opacity>0&&m.opacity<1)),'membrane material '+id);
    if(id.startsWith('wing_')||id.startsWith('arm_')){
     const [a,b]=before.objects;check(a&&b,'missing pair '+id);
     check(Math.abs(a.min[0]+b.max[0])<1e-5&&Math.abs(a.max[0]+b.min[0])<1e-5,'unmirrored '+id);
    }
    // Girth and size affect actual geometry independently, without genome edits.
    const larger=structuredClone(base);larger.nodes.forEach(n=>n.r*=1.4);S.load(larger);H.step(0);const grown=H.inspect();
    if(before.objects.length)check(Math.abs(grown.objects[0].localSize[0]/before.objects[0].localSize[0]-1.4)<.002,'radius sizing '+id);
    else check(Math.abs(grown.legs[0].width/before.legs[0].width-1.4)<1e-6,'leg radius sizing '+id);
    const bigger=structuredClone(base);bigger.parts[0].size*=1.5;S.load(bigger);H.step(0);const sized=H.inspect();
    if(before.objects.length)check(Math.abs(sized.objects[0].localSize[0]/before.objects[0].localSize[0]-1.5)<.002,'size control '+id);
    else check(Math.abs(sized.legs[0].width/before.legs[0].width-1.5)<1e-6,'leg size control '+id);
    const turned=structuredClone(base);turned.parts[0].rot=.41;turned.parts[0].tilt=.27;S.load(turned);H.step(0);check(JSON.stringify(H.inspect())!==JSON.stringify(before),'rot/tilt controls '+id);
    S.load(base);S.setMode('test');H.step(0);const start=H.inspect();H.step(.19);const moved=H.inspect();
    const a=start.objects[0],b=moved.objects[0];
    for(const key of ['jaw','wing','sacs','arm','tail','sway'])if(a?.[key]!==undefined)check(JSON.stringify(a[key])!==JSON.stringify(b[key]),'static '+key+' '+id);
    if(start.legs.length)check(JSON.stringify(start.legs)!==JSON.stringify(moved.legs),'static gait '+id);
    check(JSON.stringify(S.genome())===JSON.stringify(base),'render modified /4 '+id);
    S.setMode('build');H.step(0);placements++;
   }
   return {placements,ids,legacy:'24 saved GLB ids rendered without migration',checks:'finite meshes; skin-surface roots; paired reflection; girth/size response; grounded feet; shared membranes; Test animations; unchanged genomes'};
  },fixture);
  // Every replacement remains adjustable through the real selection panel.
  for(const id of result.ids){
   await page.evaluate(id=>{CreatureStudio.preset('Merodeador');CreatureStudio.addPart(id)},id);
   for(const [key,value]of [['size',1.3],['rot',.41],['tilt',.27]]){
    assert.equal(await page.locator('#p-'+key).count(),1,id+' '+key);
    const before=await page.evaluate(()=>{__partsTest.step(0);return __partsTest.inspect()});
    await page.locator('#p-'+key).fill(String(value));await page.locator('#p-'+key).dispatchEvent('input');
    const after=await page.evaluate(()=>{__partsTest.step(0);return __partsTest.inspect()});
    assert.notDeepEqual(after,before,id+' live '+key);
   }
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync('docs/evidence/g48-tests.json',JSON.stringify({...result,errors},null,2)+'\n');console.log('PASS',result);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
