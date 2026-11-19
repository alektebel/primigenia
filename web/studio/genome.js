/* Portable authoring document. Validation is pure and completes before scene mutation. */
const StudioDocument = (() => {
  const Growth=typeof module==='object'?require('./growth.js'):CreatureGrowth;
  const clone=x=>JSON.parse(JSON.stringify(x));
  const fail=path=>{throw new Error(path)};
  const object=(x,path)=>{if(!x||typeof x!=='object'||Array.isArray(x))fail(path);return x};
  const number=(x,min,max,path)=>{if(!Number.isFinite(x)||x<min||x>max)fail(path);return x};
  const integer=(x,min,max,path)=>{number(x,min,max,path);if(!Number.isInteger(x))fail(path);return x};
  const keys=(o,allowed,path)=>{object(o,path);for(const k of Object.keys(o))if(!allowed.includes(k))fail(path+'.'+k)};
  function region(r) {
    keys(r,['id','schema','family','seed','count','length','curve','branches','surface','position','coverage','angle','mirror'],'regions');
    if(typeof r.id!=='string'||!/^[-\w]{1,64}$/.test(r.id)||r.schema!==Growth.VERSION||!['torso','neck','tail'].includes(r.surface)||typeof r.mirror!=='boolean')fail('regions');
    if(!['horns','plates','tendrils'].includes(r.family))fail('regions.family');
    for(const [k,min,max]of [['seed',0,4294967295],['count',1,18],['length',.2,2.4],['curve',-1,1],['branches',0,3]])number(r[k],min,max,'regions.'+k);
    Growth.validate(r);number(r.position,0,1,'regions.position');number(r.coverage,0,1,'regions.coverage');number(r.angle,-Math.PI,Math.PI,'regions.angle');
    return clone(r);
  }
  function validate(g,types) {
    keys(g,['schema','name','nodes','parts','skin','regions','migration'],'document');
    if(!['cpore.creature/4','cpore.creature/5'].includes(g.schema))fail('schema');
    if(typeof g.name!=='string'||g.name.length>80||/[<>\x00-\x1f]/.test(g.name))fail('name');
    if(!Array.isArray(g.nodes)||g.nodes.length<4||g.nodes.length>32)fail('nodes');
    g.nodes.forEach((n,i)=>{keys(n,['y','z','r'],'nodes');number(n.y,-5,20,'nodes.y');number(n.z,-30,30,'nodes.z');number(n.r,.03,3,'nodes.r');if(i&&Math.hypot(n.y-g.nodes[i-1].y,n.z-g.nodes[i-1].z)<.05)fail('nodes.distance')});
    if(!Array.isArray(g.parts)||g.parts.length>256)fail('parts');
    g.parts.forEach(p=>{keys(p,['type','t','ang','size','len','curve','w','k','f','rot','tilt','level','tier','act','single','pupil'],'parts');if(!Object.hasOwn(types,p.type))fail('parts.type');
      if(g.schema==='cpore.creature/5'){integer(p.level,1,5,'parts.level');integer(p.tier,0,2,'parts.tier')}
      number(p.t,0,1,'parts.t');number(p.ang,-Math.PI,Math.PI,'parts.ang');
      for(const [k,min,max]of [['size',.1,4],['len',.1,5],['curve',-1.5,1.5],['w',.05,.8],['rot',-Math.PI,Math.PI],['tilt',-1.5,1.5]])if(p[k]!==undefined)number(p[k],min,max,'parts.'+k);
      if(['pata','zanca','pezuna'].includes(p.type)){number(p.w,.05,.8,'parts.w');for(const k of ['k','f']){if(!Array.isArray(p[k])||p[k].length!==3)fail('parts.'+k);p[k].forEach(v=>number(v,-20,20,'parts.'+k))}}
      else {number(p.size,.1,4,'parts.size');if(['cuerno','asta','pua','tallo','antena'].includes(p.type))number(p.len,.1,5,'parts.len');if(p.type==='cuerno')number(p.curve,-1.5,1.5,'parts.curve')}
    });
    keys(g.skin,['pat','cA','cB','cC','wet','scale'],'skin');integer(g.skin.pat,0,3,'skin.pat');number(g.skin.wet,0,1,'skin.wet');number(g.skin.scale,3,14,'skin.scale');
    for(const k of ['cA','cB','cC'])if(!/^#[0-9a-f]{6}$/i.test(g.skin[k]))fail('skin.'+k);
    if(!Array.isArray(g.regions)||g.regions.length>64)fail('regions');const ids=new Set();g.regions.forEach(r=>{region(r);if(ids.has(r.id))fail('regions.id');ids.add(r.id)});
    if(g.migration){keys(g.migration,['from','warnings','source'],'migration');if(![1,2,3].includes(g.migration.from)||!Array.isArray(g.migration.warnings)||g.migration.warnings.some(w=>typeof w!=='string'))fail('migration');object(g.migration.source,'migration.source')}
    return clone(g);
  }
  function migrate(g) {
    const v=Number(g.schema.split('/')[1]), b=object(g.body,'body'), l=object(g.legs,'legs'),h=object(g.head,'head'),s=object(g.skin,'skin');
    for(const [x,min,max,path]of [[b.torso,1.6,5,'body.torso'],[b.girth,.45,1.5,'body.girth'],[b.neck,.4,3.4,'body.neck'],[b.tail,.8,5.5,'body.tail'],[l.length,.8,3.2,'legs.length'],[l.width,.12,.42,'legs.width'],[l.stride,0,4.5,'legs.stride'],[h.size,.4,1,'head.size'],[h.eyes,.14,.38,'head.eyes'],[g.arms?.length??.7,.3,1.4,'arms.length']])number(x,min,max,path);
    integer(l.pairs,1,3,'legs.pairs');
    const warnings=['migration.body','migration.motion','migration.levels','migration.projection'];
    const baseY=l.length*.84+b.girth*.3, nodes=[];
    // Sample a single vertical chain. Legacy sliders have no exact spine inverse.
    for(const [y,z,r]of [[baseY,-b.tail,.06],[baseY,-b.tail*.5,b.girth*.4],[baseY,0,b.girth*.8],[baseY+b.torso*.05,b.torso*.5,b.girth],[baseY+b.torso*.05,b.torso,b.girth*.8],[baseY+b.neck*.5,b.torso+b.neck*.6,h.size*.65],[baseY+b.neck*.7,b.torso+b.neck,h.size]])nodes.push({y,z,r});
    const parts=[{type:'ojo',t:.94,ang:.9,size:h.eyes/.2}];
    for(let i=0;i<l.pairs;i++)parts.push({type:'pata',t:.42+i*.27/Math.max(1,l.pairs-1),ang:2.1,w:l.width,k:[.25,-l.length*.5,.1],f:[.35,-l.length,0]});
    const mapping={mouth:{blunt:'romo',jaws:'fauces',beak:'pico'},arms:{claws:'arm_grasper',hands:'arm_grasper',none:null},horns:{none:null,pair:'cuerno',nasal:'cuerno',crown:'asta'},back:{none:null,spikes:'pua',plates:'placa',sail:'aleta'},tailTip:{none:null,club:'maza',spikes:'pua'}};
    const seen=new Set();if(!Array.isArray(g.parts))fail('parts');
    for(const p of g.parts){object(p,'parts');integer(p.level,1,5,'parts.level');if(!mapping[p.slot]||!Object.hasOwn(mapping[p.slot],p.type)||seen.has(p.slot))fail('parts.type');seen.add(p.slot);
      const type=mapping[p.slot][p.type];if(!type)continue;
      const n={type,t:p.slot==='mouth'?1:p.slot==='arms'?.72:p.slot==='tailTip'?.05:p.slot==='horns'?.9:.58,ang:p.slot==='mouth'?0:p.slot==='arms'?1.4:p.slot==='horns'&&p.type==='pair'?.5:0,size:.8+.1*p.level};
      if(['cuerno','asta','pua'].includes(type))n.len=type==='pua'?.55:.9;if(type==='cuerno')n.curve=.5;parts.push(n);
    }
    if(!seen.has('mouth'))fail('parts.mouth');
    const pattern=['plain','stripes','spots','marbled'].indexOf(s.pattern);if(pattern<0)fail('skin.pattern');object(s.colors,'skin.colors');
    let regions=[];
    if(v===3){if(!Array.isArray(g.regions))fail('regions');regions=g.regions.map(region)}
    if(v===2){object(g.growth,'growth');const r=region({...g.growth,family:g.growth.family==='none'?'horns':g.growth.family,id:'region-1',surface:'torso'});if(g.growth.family!=='none')regions=[r]}
    if(v===1&&g.growth!==undefined)warnings.push('migration.extra:growth');
    if(v!==3&&g.regions!==undefined)warnings.push('migration.extra:regions');
    for(const [path,source,allowed]of [['body',b,['torso','girth','neck','tail']],['legs',l,['pairs','length','width','stride']],['head',h,['size','eyes']],['arms',g.arms||{},['length']],['skin',s,['pattern','colors','scale','gloss']]])for(const key of Object.keys(source))if(!allowed.includes(key))warnings.push('migration.extra:'+path+'.'+key);
    for(const k of Object.keys(g))if(!['schema','body','legs','head','arms','parts','skin','regions','growth','dna','abilities','name'].includes(k))warnings.push('migration.extra:'+k);
    return {schema:'cpore.creature/4',name:g.name||'Migrada',nodes,parts,skin:{pat:pattern,cA:s.colors.base,cB:s.colors.pattern,cC:s.colors.belly,wet:s.gloss,scale:s.scale},regions,migration:{from:v,warnings,source:clone(g)}};
  }
  function parse(input,types) {
    const g=typeof input==='string'?JSON.parse(input):input;object(g,'document');
    if(!['cpore.creature/1','cpore.creature/2','cpore.creature/3','cpore.creature/4','cpore.creature/5'].includes(g.schema))fail('schema');
    const doc=clone(['cpore.creature/4','cpore.creature/5'].includes(g.schema)?g:migrate(g));
    if(doc.schema==='cpore.creature/4'){doc.schema='cpore.creature/5';for(const p of doc.parts){p.level=1;p.tier=0}}
    const genome=validate(doc,types);
    return {genome,warnings:genome.migration?.warnings||[]};
  }
  return {parse,validate,clone};
})();
if(typeof module==='object')module.exports=StudioDocument;
