/* Browser contracts shared by test.html and the Playwright runner. */
async function studioContracts(S,fixtures=[]){
 const checks=[];let maxRootDistance=0,placements=0;
 const check=(ok,message)=>{if(!ok)throw Error(message);checks.push(message)};
 const hash=async g=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(g))))).map(x=>x.toString(16).padStart(2,'0')).join('');
 const roundTrip=async name=>{const g=S.genome(),before=await hash(g);S.load(JSON.stringify(g));check(await hash(S.genome())===before,'hash round trip '+name)};
 for(const [id,axis,direction,limit]of [['jaw_nipper',2,1,.7],['leg_sprinter',1,-1,.8],['wing_glider',0,1,1.5],['tail_hammer',2,-1,1],['horn_crown',2,1,.4],['lure_lantern',2,1,.8]]){const b=S.assetBounds(id),source=S.parts.parts.find(p=>p.id===id).source;check(direction>0?b.max[axis]>limit:b.min[axis]<-limit,(source==='glb'?'exporter':'creator')+' orientation '+id)}
 for(const name of S.presets){S.preset(name);await roundTrip(name);
  const base=S.genome();
  for(const entry of S.parts.parts){const g=structuredClone(base);g.parts=[S.defaults(entry.id)];S.load(g);
   const roots=S.attachmentRoots();check(roots.length>0,'placed '+entry.id+' on '+name);
   check(roots.every(r=>r.meshDistance<.045&&Number.isFinite(r.meshDistance)),'surface roots '+entry.id+' on '+name);
   maxRootDistance=Math.max(maxRootDistance,...roots.map(r=>r.meshDistance));placements++;
   check(JSON.stringify(S.genome())===JSON.stringify(g),'render preserves '+entry.id+' on '+name);
  }
 }
 for(let i=0;i<20;i++){S.random(i*7919+17);await roundTrip('random '+i)}
 const good=S.genome(),original=JSON.stringify(good);
 const invalid=[g=>g.schema='bad',g=>g.nodes[0].r=-1,g=>g.nodes[0].x=1,g=>g.parts[0].type='missing',g=>g.parts[0].t=NaN,g=>g.skin.cA='red',g=>g.regions=null,g=>g.parts=[null],g=>g.name='<img>'];
 for(const mutate of invalid){const g=structuredClone(good);mutate(g);let threw=false;try{S.load(g)}catch{threw=true}check(threw,'invalid document rejected');check(JSON.stringify(S.genome())===original,'invalid import is atomic')}
 for(const legacy of fixtures){const result=S.load(legacy);check(result.warnings.length>0,'migration reports /'+legacy.schema.split('/')[1]);check(JSON.stringify(result.genome.migration.source)===JSON.stringify(legacy),'migration preserves original');await roundTrip(legacy.schema)}
 return {checks,placements,maxRootDistance};
}
