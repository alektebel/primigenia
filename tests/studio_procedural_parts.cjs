/* G48 geometry/animation checks run against the actual studio closure. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const base=process.env.CPORE_STUDIO_URL||'http://127.0.0.1:8765';
const fixture=JSON.parse(fs.readFileSync('tests/fixtures/studio/v4-glb-parts.json'));
const inspect=`window.__partsTest={step:update,inspect:()=>{
 creature.updateMatrixWorld(true);limbs.updateMatrixWorld(true);
 const objects=objs.map(o=>{
  let finite=true,vertices=0,regions={},meshes=[],membranes=[],localBox=new T.Box3(),inverse=o.g.matrixWorld.clone().invert();
  o.g.traverse(m=>{if(!m.isMesh)return;const p=m.geometry.attributes.position,n=m.geometry.attributes.normal;vertices+=p.count;
   finite=finite&&[...p.array,...n.array].every(Number.isFinite);localBox.union(new T.Box3().setFromBufferAttribute(p).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,m.matrixWorld)));
   const r=m.userData.materialRegion||'unknown';regions[r]=(regions[r]||0)+1;const box=new T.Box3().setFromObject(m),frameBox=new T.Box3().setFromBufferAttribute(p).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,m.matrixWorld));
   meshes.push({name:m.name,region:r,min:box.min.toArray(),max:box.max.toArray(),size:box.getSize(V()).toArray(),frameMin:frameBox.min.toArray(),frameMax:frameBox.max.toArray(),ivory:m.material===toothM,darkTip:m.material===beakM});
   if(r==='membrane')membranes.push({shared:[membraneM,typeof gliderM!=='undefined'&&gliderM,typeof insectM!=='undefined'&&insectM,typeof sacM!=='undefined'&&sacM].includes(m.material),side:m.material.side,transparent:m.material.transparent,opacity:m.material.opacity});
  });
  const ud=o.g.userData,box=new T.Box3().setFromObject(o.g);
  return {type:o.p.type,side:o.sg,vertices,finite,regions,meshes,membranes,radius:ud.mountRadius,localSize:localBox.getSize(V()).toArray(),size:box.getSize(V()).toArray(),min:box.min.toArray(),max:box.max.toArray(),jaw:ud.jaw?.rotation.x,wing:ud.wing?.rotation.toArray().slice(0,3),sacs:ud.sacs?.map(s=>s.scale.x),arm:ud.arm?.rotation.x,tail:ud.tail?.rotation.y,sway:ud.sway?.rotation.x};
 });
 return {objects,legs:legs.map(l=>({type:l.p.type,side:l.sg,width:l.w,knee:l.lo.position.toArray(),foot:l.ft.position.toArray(),sole:l.ft.position.y,height:l.a+l.b,finite:[...l.up.position.toArray(),...l.lo.position.toArray(),...l.ft.position.toArray()].every(Number.isFinite)}))};
}};`;
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
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
   // World-space bounds at the reviewed default anatomy, with seed IK legs.
   // Keep every measured value so a failed silhouette has an actionable size.
   const geometry=[],failures=[],expect=(ok,message)=>{if(!ok)failures.push(message)};
   for(const seed of ['Merodeador','Zancuda'])for(const id of ['beak_crusher','tail_paddle','tail_hammer','tail_spike','arm_grasper','arm_smasher']){
    S.preset(seed);const g=S.genome(),head=g.nodes.at(-1),maxRadius=Math.max(...g.nodes.map(n=>n.r));
    g.parts=g.parts.filter(p=>['pata','zanca','ojo'].includes(p.type));g.parts.push(S.defaults(id));S.load(g);H.step(0);
    const scene=H.inspect(),a=scene.objects.find(o=>o.type===id),root=S.attachmentRoots().find(r=>r.type===id).root;
    const skin=a.meshes.filter(m=>m.region==='skin'),keratin=a.meshes.filter(m=>m.region==='keratin'),label=seed+' '+id;
    const measured={seed,id,maxRadius,headEndRadius:head.r,ground:0,bounds:{min:a.min,max:a.max},root};
    if(id==='beak_crusher'){
     const upper=keratin.find(m=>m.name==='upper mandible')||keratin[0],lower=keratin.find(m=>m.name==='lower mandible')||keratin[1];
     measured.width=a.size[0];measured.forward=upper.frameMax[2];measured.backward=upper.frameMin[2];
     expect(a.size[0]<=head.r*2+.001,label+' width <= head diameter: '+a.size[0]);
     expect(upper.frameMin[2]>=-head.r*.1,label+' starts at snout end: '+upper.frameMin[2]);
     expect(upper.frameMax[2]>=head.r*.8&&upper.frameMax[2]<=head.r*1.2,label+' projects 0.8–1.2 head radii: '+upper.frameMax[2]);
     expect(lower.frameMax[2]<upper.frameMax[2]-.1*head.r,label+' shorter lower mandible');
     expect(upper.ivory&&keratin.some(m=>m.darkTip),label+' ivory upper and darker keratin edges/tip');
     measured.resized=[];
     for(const size of [.5,2.2]){
      const resized=structuredClone(g);resized.parts.at(-1).size=size;S.load(resized);H.step(0);
      const beak=H.inspect().objects.find(o=>o.type===id);measured.resized.push({size,width:beak.size[0]});
      expect(beak.size[0]<=head.r*2+.001,label+' width never exceeds head at size '+size+': '+beak.size[0]);
     }
    }else if(id.startsWith('tail_')){
     expect(g.parts.at(-1).t>0&&g.parts.at(-1).t<=.15,label+' attaches within rear 15%');
     expect(skin.some(m=>m.frameMin[2]<=0&&m.frameMax[2]>=0),label+' skin shaft crosses attachment without gap');
     const terminal=a.meshes.find(m=>m.region===(id==='tail_paddle'?'membrane':'keratin'));
     expect(skin.some(m=>m.min.every((v,i)=>v<=terminal.max[i]&&m.max[i]>=terminal.min[i])),label+' shaft overlaps terminal organ without gap');
     if(id==='tail_paddle'){
      const blade=a.meshes.find(m=>m.region==='membrane');measured.bladeSpan=blade.size[1];measured.bladeThickness=blade.size[0];
      expect(blade.size[1]>=maxRadius*.8,label+' vertical blade span >= 0.8 max radius: '+blade.size[1]);
      expect(blade.size[1]>blade.size[0]*3,label+' blade lies in vertical plane');
      expect(keratin.length>=2,label+' membrane has spars');
     }else if(id==='tail_hammer'){
      measured.hammerWidth=Math.max(...keratin.map(m=>m.max[0]))-Math.min(...keratin.map(m=>m.min[0]));
      expect(measured.hammerWidth>=maxRadius*.45,label+' hammer width >= 0.45 max radius: '+measured.hammerWidth);
      expect(keratin.length>=6,label+' lobes and ridges');
     }else{
      measured.barbLengths=keratin.slice(-3).map(m=>Math.hypot(...m.size));
      expect(measured.barbLengths.every(n=>n>=maxRadius*.3),label+' barbs >= 0.3 max radius: '+measured.barbLengths.join(','));
     }
     const thin=structuredClone(g);thin.nodes[0].r=Math.max(.05,thin.nodes[0].r*.5);thin.nodes[1].r*=.5;S.load(thin);H.step(0);
     const tip=H.inspect().objects.find(o=>o.type===id).meshes.filter(m=>m.region!=='skin');
     measured.thinTailTipSizes=tip.map(m=>m.size);
     expect(tip.every((m,i)=>m.size.every((v,j)=>Math.abs(v-a.meshes.filter(m=>m.region!=='skin')[i].size[j])<1e-5)),label+' terminal sizes independent of tail-tip radius');
    }else if(id==='arm_grasper'&&seed==='Merodeador'){
     const shoulder=skin.find(m=>m.name==='shoulder')||skin[0],upper=skin.find(m=>m.name==='upper arm')||skin[1],fore=skin.find(m=>m.name==='forearm')||skin[3];
     const hand=skin.find(m=>m.name==='palm')||skin.at(-1),pincers=keratin;
     measured.shoulder=shoulder;measured.upperArm=upper;measured.forearm=fore;measured.pincers=pincers;
     expect((shoulder.min[1]+shoulder.max[1])/2<root[1]-maxRadius*.15,label+' lower shoulder');
     expect(upper.max[0]>head.r+maxRadius*.25&&fore.min[0]>head.r,label+' arm segments clear wide head');
     expect((hand.min[1]+hand.max[1])/2<(upper.min[1]+upper.max[1])/2-maxRadius*.1,label+' forearm reaches down');
     expect(pincers.every(m=>m.min[2]>root[2]+maxRadius*.6&&m.max[1]<head.y-head.r*.25),label+' pincers forward of chest below jaw');
    }else if(id==='arm_smasher'){
     const club=keratin.find(m=>m.name==='club head')||keratin[0],knee=Math.max(...scene.legs.map(l=>l.knee[1]));
     measured.club=club;measured.kneeHeight=knee;
     expect(club.size[0]>=maxRadius*.5,label+' club width >= 0.5 max radius: '+club.size[0]);
     expect(club.min[1]>knee,label+' raised club above knees: '+club.min[1]+' vs '+knee);
     expect(club.max[2]>root[2]+maxRadius*.5&&club.min[1]>root[1]-maxRadius*.5,label+' club carried forward at chest height');
    }
    geometry.push(measured);
   }
   check(!failures.length,failures.join('\n'));
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
    if(before.objects.length){const axis=id==='tail_paddle'?1:0,ratio=sized.objects[0].localSize[axis]/before.objects[0].localSize[axis];check(id==='beak_crusher'?Math.abs(ratio-1)<.03&&sized.objects[0].localSize[2]>before.objects[0].localSize[2]:id.startsWith('arm_')?ratio>1&&ratio<=1.502:Math.abs(ratio-1.5)<.002,'size control '+id);}
    else check(Math.abs(sized.legs[0].width/before.legs[0].width-1.5)<1e-6,'leg size control '+id);
    const turned=structuredClone(base);turned.parts[0].rot=.41;turned.parts[0].tilt=.27;S.load(turned);H.step(0);check(JSON.stringify(H.inspect())!==JSON.stringify(before),'rot/tilt controls '+id);
    S.load(base);S.setMode('test');H.step(0);const start=H.inspect();H.step(.19);const moved=H.inspect();
    const a=start.objects[0],b=moved.objects[0];
    for(const key of ['jaw','wing','sacs','arm','tail','sway'])if(a?.[key]!==undefined)check(JSON.stringify(a[key])!==JSON.stringify(b[key]),'static '+key+' '+id);
    if(start.legs.length)check(JSON.stringify(start.legs)!==JSON.stringify(moved.legs),'static gait '+id);
    check(JSON.stringify(S.genome())===JSON.stringify(base),'render modified /4 '+id);
    S.setMode('build');H.step(0);placements++;
   }
   // Default anatomy regressions retain the seed legs: rest height matters here.
   const anatomy=[];
   for(const seed of ['Merodeador','Zancuda']){
    let wings={};
    for(const id of ['beak_crusher','arm_smasher','arm_grasper','sac_spitter','wing_glider','wing_insect','tail_paddle','tail_spike','tail_hammer']){
     S.preset(seed);const g=S.genome(),head=g.nodes.at(-1),tail=g.nodes[0];
     g.parts=g.parts.filter(p=>['pata','zanca','ojo'].includes(p.type));const p=S.defaults(id);g.parts.push(p);S.load(g);H.step(0);
     const v=H.inspect().objects.filter(o=>o.type===id),a=v[0];
     if(id==='beak_crusher'){
      const collar=a.meshes.find(m=>m.region==='skin');
      check(collar.size[0]>=head.r*1.7,'beak collar must match head-end width '+seed);
      check(a.localSize[2]<=head.r*1.65,'beak must stay head-sized '+seed);
     }
     if(id.startsWith('arm_')){
      check(a.regions.skin>=4,'upper arm, elbow and forearm must be skin '+seed+' '+id);
      check(a.min[1]>.45,'arm must clear floor at rest '+seed+' '+id);
      check(a.size[0]>.3,'arm must read at body scale '+seed+' '+id);
      const root=S.attachmentRoots().find(r=>r.type===id).root;
      check(root[1]>g.nodes[3].y,'arm must mount at upper chest '+seed);
      if(id==='arm_smasher'){
       check(a.meshes.filter(m=>m.region==='keratin').every(m=>Math.max(...m.size)<=head.r*2),'club must not exceed head '+seed);
       for(const size of [.5,2.2]){
        const resized=structuredClone(g);resized.parts.at(-1).size=size;S.load(resized);H.step(0);
        const club=H.inspect().objects.find(o=>o.type===id);
        check(club.min[1]>.35,'club floor clearance at size '+size+' '+seed);
        check(club.meshes.find(m=>m.name==='club head').min[1]>Math.max(...H.inspect().legs.map(l=>l.knee[1])),'club above knees at size '+size+' '+seed);
        check(club.meshes.filter(m=>m.region==='keratin').every(m=>Math.max(...m.size)<=head.r*2),'club head clamp at size '+size+' '+seed);
       }
      }
      else {check(a.max[2]>root[2]+.7,'pincers must reach forward from chest '+seed);if(seed==='Zancuda')check(a.max[1]>=head.y-head.r*2,'tall-body pincers must reach mouth height '+seed);}
     }
     if(id==='sac_spitter'){
      check(v.length===1,'one twin-sac assembly '+seed);
      const sacs=a.meshes.filter(m=>m.region==='membrane');check(sacs.length===2,'two sacs '+seed);
      check(sacs.every(m=>m.size[0]>=head.r&&m.size[0]<=head.r*1.45),'sacs sized to head '+seed);
      check(a.regions.glow>=3,'sac highlights and nozzle visible '+seed);
     }
     if(id.startsWith('wing_'))wings[id]=a;
     if(id.startsWith('tail_')){
      check(p.t>0&&p.t<=.15&&p.ang===0,'tail must merge with rear 15% '+seed);
      const root=S.attachmentRoots().find(r=>r.type===id).root;
      check(a.max[2]<=root[2]+.15,'tail must extend rearward from a small root overlap '+seed+' '+id);
      check(a.size[2]>=tail.r*8,'tail silhouette must read '+seed+' '+id);
     }
     anatomy.push({seed,id,min:a.min,max:a.max});
    }
    check(wings.wing_glider.membranes.length===1&&wings.wing_insect.membranes.length===2,'one broad glider versus two insect sails');
    check(wings.wing_glider.membranes[0].opacity>wings.wing_insect.membranes[0].opacity+.2,'distinct wing transparency');
    check(wings.wing_glider.size[1]>.5,'glider membrane must rise above edge-on view '+seed);
   }
   return {placements,ids,anatomy,geometry,legacy:'24 saved GLB ids rendered without migration',checks:'world-space beak/fin/hammer/barb/arm/club bounds; finite meshes; skin-surface roots; paired reflection; girth/size response; grounded feet; shared membranes; Test animations; unchanged genomes'};
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
  fs.writeFileSync(process.env.G48_TEST_OUTPUT||'docs/evidence/g48-tests.json',JSON.stringify({...result,errors},null,2)+'\n');console.log('PASS',result);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
