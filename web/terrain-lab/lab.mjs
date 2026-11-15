const $=id=>document.getElementById(id);
const stages=['Raising the range and cutting its valleys','Rain is carving the gullies','Loose stone is settling into scree','Tracing the drainage network','Landscape ready'];
const query=new URLSearchParams(location.search);
let terrain,light,mesh,sea,caveMarkers,busy=false,readyResolve;
window.terrainReady=new Promise(resolve=>{readyResolve=resolve;});
const worker=new Worker(new URL('./worker.mjs',import.meta.url),{type:'module'});
window.addEventListener('error',event=>failure(event.message));
const THREE=window.THREE;
if (!THREE) throw Error('Three.js did not load. Check the network and reload.');
const renderer=new THREE.WebGLRenderer({canvas:$('scene'),antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.outputEncoding=THREE.sRGBEncoding;
const SKY=[.72,.81,.90],ZENITH=[.36,.56,.82];
const scene=new THREE.Scene();scene.fog=new THREE.Fog(new THREE.Color(...SKY).convertSRGBToLinear(),2500,16000);
{ // Sky: a vertical gradient. Lighting is baked into the ground texture, so the scene needs no lamps.
  const c=document.createElement('canvas');c.width=4;c.height=256;const g=c.getContext('2d'),grad=g.createLinearGradient(0,0,0,256);
  const css=v=>`rgb(${v.map(x=>Math.round(x*255)).join(',')})`;
  grad.addColorStop(0,css(ZENITH));grad.addColorStop(.62,css(SKY));grad.addColorStop(1,css(SKY));g.fillStyle=grad;g.fillRect(0,0,4,256);
  scene.background=new THREE.CanvasTexture(c);scene.background.encoding=THREE.sRGBEncoding;
}
const camera=new THREE.PerspectiveCamera(40,1,2,40000);
// Sun from the north-west, 38 degrees up. Map +y is south; three.js z is map y.
const SUN=(()=>{const v=[-.52,.62,-.59],l=Math.hypot(...v);return v.map(x=>x/l);})();
const views={orbit:{yaw:.62,pitch:.50,distance:1.32},valley:{yaw:-2.11,pitch:.13}};
let view=query.get('view')==='valley'?'valley':'orbit',yaw,pitch,distance;
function cameraReset(){({yaw,pitch}=views[view]);distance=views.orbit.distance;$('view').value=view;draw();}
function groundAt(x,z){
  if(!terrain)return 0;const {n,size,height}=terrain;
  const i=Math.max(0,Math.min(n-1,Math.floor((x/size+.5)*n))),j=Math.max(0,Math.min(n-1,Math.floor((z/size+.5)*n)));return height[j*n+i];
}
function draw(){
  const box=$('vista').getBoundingClientRect();renderer.setSize(box.width,box.height,false);
  camera.aspect=box.width/box.height;const size=terrain?terrain.size:3200;
  if(view==='valley'){
    // Standing on the valley floor, eye 2.2 m up, looking at the range.
    const ex=60,ez=40,ey=groundAt(ex,ez)+2.2;camera.fov=62;camera.position.set(ex,ey,ez);
    camera.lookAt(ex+Math.sin(yaw)*Math.cos(pitch)*100,ey+Math.sin(pitch)*100,ez+Math.cos(yaw)*Math.cos(pitch)*100);
  }else{
    const fit=distance*size*Math.max(1,1/camera.aspect);camera.fov=40;
    camera.position.set(Math.sin(yaw)*Math.cos(pitch)*fit,60+Math.sin(pitch)*fit,Math.cos(yaw)*Math.cos(pitch)*fit);camera.lookAt(0,60,0);
  }
  camera.updateProjectionMatrix();renderer.render(scene,camera);
}
new ResizeObserver(draw).observe($('vista'));

/* ---- shading -------------------------------------------------------------
 * Everything the eye judges is computed from the generator's maps at full
 * resolution: slope and aspect, ambient occlusion and the sun's cast shadow
 * from the height field, then ground materials from height, slope, aspect,
 * flow and sediment. The result is one texture; the mesh only carries shape. */
const mix=(a,b,t)=>{t=t<0?0:t>1?1:t;return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t];};
const step=(a,b,x)=>{const t=Math.max(0,Math.min(1,(x-a)/(b-a)));return t*t*(3-2*t);};
const WATER_DEPTH=.5,CHANNEL_M2=8000;
function bakeLight(t){
  const {n,size,height:h,level}=t,cell=size/n,nn=n*n;
  const gx=new Float32Array(nn),gy=new Float32Array(nn),ao=new Float32Array(nn),sun=new Float32Array(nn),water=new Uint8Array(nn);
  let hmin=Infinity;for(let i=0;i<nn;i++)if(h[i]<hmin)hmin=h[i];
  const hasSea=hmin<=0;
  // Displayed surface: the ground, or the water standing on it.
  const z=new Float32Array(nn);
  for(let i=0;i<nn;i++){
    const pond=level[i]-h[i]>WATER_DEPTH&&h[i]>0;water[i]=h[i]<=0&&hasSea?2:pond?1:0;z[i]=pond?level[i]:h[i];
  }
  const at=(x,y)=>z[(y<0?0:y>=n?n-1:y)*n+(x<0?0:x>=n?n-1:x)];
  const lx=SUN[0],ly=SUN[2],lh=Math.hypot(lx,ly),sx=lx/lh,sy=ly/lh,rise=SUN[1]/lh;
  const dirs=[];for(let d=0;d<8;d++)dirs.push([Math.cos(d*Math.PI/4),Math.sin(d*Math.PI/4)]);
  for(let y=0;y<n;y++)for(let x=0;x<n;x++){
    const i=y*n+x,z0=z[i];
    if(water[i]!==2){gx[i]=(at(x+1,y)-at(x-1,y))/(2*cell);gy[i]=(at(x,y+1)-at(x,y-1))/(2*cell);}
    let occ=0;
    for(const [dx,dy] of dirs){
      let m=0;for(let s=1,r=1.5;s<=5;s++,r*=2){const e=(at(Math.round(x+dx*r),Math.round(y+dy*r))-z0)/(r*cell);if(e>m)m=e;}
      occ+=m/Math.sqrt(1+m*m);
    }
    ao[i]=1-occ/8;
    // Cast shadow: walk toward the sun; lit unless the ground rises above the ray.
    let lit=1;
    for(let s=1,r=1.5;s<70;s++,r+=1+s*.08){
      const px=x+sx*r,py=y+sy*r;if(px<0||py<0||px>n-1||py>n-1)break;
      const over=at(Math.round(px),Math.round(py))-(z0+rise*r*cell);
      if(over>0){lit=Math.min(lit,Math.max(0,1-over/(1.5+r*cell*.03)));if(lit===0)break;}
    }
    sun[i]=lit;
  }
  return {gx,gy,ao,sun,water,z,hasSea};
}
const C={meadow:[.36,.50,.20],forest:[.17,.30,.14],alp:[.47,.50,.27],rock:[.66,.62,.56],dark:[.42,.40,.39],scree:[.70,.66,.58],
  gravel:[.68,.64,.52],sand:[.78,.73,.58],snow:[.95,.96,.98],river:[.24,.45,.58],lake:[.17,.40,.52],shallow:[.33,.62,.66],deep:[.10,.30,.47]};
const MATERIAL_COLORS=[[.36,.50,.20],[.48,.44,.40],[.72,.60,.44],[.18,.15,.20],[.88,.76,.48],[.94,.96,1]];
function albedo(i,mode){
  const t=terrain,h=t.height[i],sed=t.sediment[i],area=t.flow[i]*t.size*t.size;
  const gx=light.gx[i],gy=light.gy[i],slope=Math.hypot(gx,gy),w=light.water[i];
  if(mode==='classification')return w===2?C.deep:w===1?C.lake:MATERIAL_COLORS[t.material?.[i]??0];
  if(mode==='height')return w===2?C.deep:mix(mix([.20,.38,.24],[.86,.80,.55],h/260),[.98,.97,.95],(h-260)/300);
  if(mode==='slope')return mix(mix([.90,.92,.78],[.86,.55,.25],slope/.9),[.35,.12,.14],(slope-.9)/1.2);
  if(mode==='flow')return mix([.90,.90,.82],[.02,.26,.52],Math.log2(1+area/(t.size*t.size)*t.n*t.n)/12);
  if(mode==='sediment')return mix([.22,.30,.28],[.99,.72,.25],Math.sqrt(sed)*.45);
  if(w===2)return mix(C.sand,[.30,.42,.40],-h/10);
  if(w===1)return C.lake;
  // +y is south: positive gy faces north, keeps snow lower and grass thinner.
  const north=Math.max(-1,Math.min(1,gy));
  let c=mix(C.meadow,C.forest,step(.22,.5,slope)*(1-step(170,250,h))*.85);
  c=mix(c,C.alp,step(200,300,h+north*30));
  // Bare rock where it is too steep or too high for turf; banded like bedded stone.
  const band=.5+.5*Math.sin(h*.55+Math.sin(i*.0137)*1.3);
  const highFace=step(302,332,h)*step(.8391,1.4281,slope)*(t.bands??1);
  const tone=t.version<3 ? .35+.65*band : .675+.12*(band-.5)*highFace;
  const stone=mix(C.dark,C.rock,tone);
  c=mix(c,stone,step(1.05,1.55,slope));
  c=mix(c,stone,step(270,380,h)*.75);
  // Loose material the generator moved: scree where it lies steep, gravel where it lies flat.
  const loose=step(.25,1.6,sed);
  c=mix(c,C.scree,loose*step(.30,.55,slope)*(1-step(1.0,1.4,slope))*.9);
  c=mix(c,C.gravel,loose*(1-step(.12,.35,slope))*.55);
  c=mix(c,C.sand,1-step(1.5,6,h));
  const snowline=325-north*50-Math.min(30,sed*10);
  c=mix(c,C.snow,step(snowline,snowline+60,h)*(1-step(1.5,2.6,slope)*.85));
  if(t.material?.[i]===3)c=mix([.20,.18,.18],[.32,.27,.25],step(.5,1.5,slope));
  if(area>=CHANNEL_M2)c=mix(c,C.river,.55+.25*step(8e3,2e5,area));
  else c=mix(c,[c[0]*.82,c[1]*.9,c[2]*.84],step(1500,CHANNEL_M2,area)*.6);
  return c;
}
function shade(i,c){
  const gx=light.gx[i],gy=light.gy[i],il=1/Math.sqrt(1+gx*gx+gy*gy);
  const lam=Math.max(0,(-gx*SUN[0]+SUN[1]-gy*SUN[2])*il)*light.sun[i],a=light.ao[i];
  const sky=(.32+.14*il)*a*a,sunl=1.0*lam;
  return [c[0]*(sky*.86+sunl*1.0+.05*a),c[1]*(sky*.95+sunl*.95+.05*a),c[2]*(sky*1.12+sunl*.84+.04*a)];
}
const toByte=v=>Math.round(255*Math.pow(v<0?0:v>1?1:v,1/2.2));
function groundTexture(mode){
  const {n}=terrain,data=new Uint8Array(n*n*4);
  for(let i=0;i<n*n;i++){const c=mode==='classification'?albedo(i,mode):shade(i,albedo(i,mode));data[i*4]=toByte(c[0]);data[i*4+1]=toByte(c[1]);data[i*4+2]=toByte(c[2]);data[i*4+3]=255;}
  const tex=new THREE.DataTexture(data,n,n,THREE.RGBAFormat);tex.encoding=THREE.sRGBEncoding;tex.magFilter=THREE.LinearFilter;
  tex.minFilter=THREE.LinearMipmapLinearFilter;tex.generateMipmaps=true;tex.anisotropy=renderer.capabilities.getMaxAnisotropy();tex.needsUpdate=true;return tex;
}
function recolor(){
  if(!mesh)return;const old=mesh.material.map;mesh.material.map=groundTexture($('shading').value);mesh.material.needsUpdate=true;if(old)old.dispose();hillshade();draw();
}
function buildMesh(){
  if(caveMarkers){scene.remove(caveMarkers);caveMarkers.traverse(o=>{o.geometry?.dispose();o.material?.map?.dispose();o.material?.dispose();});}
  if(mesh){scene.remove(mesh);mesh.geometry.dispose();mesh.material.map?.dispose();mesh.material.dispose();}
  if(sea){scene.remove(sea);sea.geometry.dispose();sea.material.dispose();sea=null;}
  const {n,size}=terrain;
  // The mesh carries shape only; ?mesh=N overrides the 512-segment default.
  const segments=Math.min(n-1,Number(query.get('mesh'))||512),v=segments+1;
  const g=new THREE.BufferGeometry(),positions=new Float32Array(v*v*3),uvs=new Float32Array(v*v*2),indices=new Uint32Array(segments*segments*6);
  let k=0;
  for(let y=0;y<v;y++)for(let x=0;x<v;x++){
    const sx=Math.round(x*(n-1)/segments),sy=Math.round(y*(n-1)/segments),i=sy*n+sx,j=y*v+x;
    positions.set([(sx+.5)*size/n-size/2,light.z[i],(sy+.5)*size/n-size/2],j*3);uvs.set([(sx+.5)/n,(sy+.5)/n],j*2);
    if(x<segments&&y<segments){indices.set([j,j+v,j+1,j+1,j+v,j+v+1],k);k+=6;}
  }
  g.setAttribute('position',new THREE.BufferAttribute(positions,3));g.setAttribute('uv',new THREE.BufferAttribute(uvs,2));g.setIndex(new THREE.BufferAttribute(indices,1));
  mesh=new THREE.Mesh(g,new THREE.MeshBasicMaterial({map:groundTexture($('shading').value)}));scene.add(mesh);
  if(light.hasSea){
    // The ground runs on under the sea; a translucent sheet at sea level shows the shallows.
    sea=new THREE.Mesh(new THREE.PlaneGeometry(60000,60000),new THREE.MeshBasicMaterial({color:new THREE.Color(.16,.40,.55).convertSRGBToLinear(),transparent:true,opacity:.86}));
    sea.rotation.x=-Math.PI/2;scene.add(sea);
  }
  caveMarkers=new THREE.Group();
  for(const [i,v] of (terrain.entrances||[]).entries()) {
    const label=document.createElement('canvas');label.width=64;label.height=64;
    const ctx=label.getContext('2d');ctx.fillStyle=v.waterfall?'#44dcff':'#fff3ad';
    ctx.beginPath();ctx.arc(32,32,26,0,Math.PI*2);ctx.fill();ctx.strokeStyle='#16251d';ctx.lineWidth=4;ctx.stroke();
    ctx.fillStyle='#16251d';ctx.font='bold 36px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(String(i+1),32,33);
    const tex=new THREE.CanvasTexture(label);
    const marker=new THREE.Sprite(new THREE.SpriteMaterial({map:tex,depthTest:false}));
    marker.position.set(v.position[0],v.position[2]+18,v.position[1]);marker.scale.set(42,42,1);marker.renderOrder=2;caveMarkers.add(marker);
  }
  scene.add(caveMarkers);
  draw();
}
function hillshade(){
  if(!terrain)return;
  const canvas=$('map'),ctx=canvas.getContext('2d'),w=canvas.width,img=ctx.createImageData(w,w),{n,size}=terrain,k=Math.max(1,Math.round(n/w));
  const drainage=$('drainage').checked;
  for(let y=0;y<w;y++)for(let x=0;x<w;x++){
    const sx=Math.min(n-1,Math.floor(x*n/w)),sy=Math.min(n-1,Math.floor(y*n/w));
    let r=0,g=0,b=0,f=0,wet=0,count=0;
    for(let dy=0;dy<k;dy++)for(let dx=0;dx<k;dx++){
      const i=Math.min(n-1,sy+dy)*n+Math.min(n-1,sx+dx);
      const c=$('shading').value==='classification'?albedo(i,'classification'):shade(i,light.water[i]===2?[.42,.60,.72]:light.water[i]===1?[.30,.52,.66]:[.80,.79,.73]);
      r+=c[0];g+=c[1];b+=c[2];count++;if(light.water[i])wet++;else f=Math.max(f,terrain.flow[i]);
    }
    let c=[r/count,g/count,b/count];
    // Channels keep their line when downsampled, and are not drawn across standing water.
    const area=f*size*size;
    if(drainage&&area>=CHANNEL_M2&&wet<count)c=mix(c,[.02,.24,.60],.62+.3*step(8e3,3e5,area));
    img.data.set([toByte(c[0]),toByte(c[1]),toByte(c[2]),255],(y*w+x)*4);
  }
  ctx.putImageData(img,0,0);
  for(const [i,v] of (terrain.entrances||[]).entries()) {
    const x=(v.position[0]/size+.5)*w,y=(v.position[1]/size+.5)*w,r=Math.max(7,w/90);
    ctx.lineWidth=2;ctx.strokeStyle='#12241c';ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+v.facing[0]*r*2.5,y+v.facing[1]*r*2.5);ctx.stroke();
    ctx.fillStyle=v.waterfall?'#44dcff':'#fff3ad';ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();ctx.stroke();
    ctx.fillStyle='#12241c';ctx.font=`bold ${r*1.5}px sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(String(i+1),x,y);
  }
}
function failure(message){busy=false;$('generate').disabled=false;document.body.dataset.error='true';$('status').textContent=`${message} Adjust the parameters or reload to try again.`;}
worker.onerror=event=>failure(event.message||'The terrain worker could not start.');
worker.onmessage=({data})=>{
  if(data.type==='error'){failure(data.message);return;}
  if(data.type==='progress'){
    // Stage 0 is every level's base and stream-power pass: most of the work.
    const from=[0,45,85,92,100][data.stage],to=[45,85,92,100,100][data.stage];
    $('status').textContent=stages[data.stage];$('progress').value=from+(to-from)*data.done/data.total;return;
  }
  if(data.type==='terrain'){
    terrain=data;light=bakeLight(terrain);buildMesh();hillshade();busy=false;$('generate').disabled=false;$('progress').value=100;
    const km=(data.size/1000).toLocaleString('en-US',{maximumFractionDigits:1});
    $('status').textContent=`${data.base?'Base only':'Eroded'} · generated in ${data.seconds.toFixed(2)} s in a Web Worker`;
    $('summary').textContent=`Seed ${data.seed} · ${data.n} × ${data.n} · ${km} km · generator v${data.version}`;$('hash').textContent=data.hash;
    $('map-title').textContent=`Terrain map · ${km} km square`;
    $('cave-key').textContent=`${data.entrances.length} entrances · numbered circles and outward lines; cyan = behind a waterfall. `+data.entrances.map((v,i)=>`${i+1}: ${v.size[0].toFixed(1)} × ${v.size[1].toFixed(1)} m${v.waterfall?' (waterfall)':''}`).join(' · ');
    window.terrainResult={seed:data.seed,n:data.n,hash:data.hash,seconds:data.seconds,base:data.base,version:data.version,size:data.size,entrances:data.entrances,landmark:data.landmark,
      materialCounts:data.material?Array.from({length:6},(_,id)=>data.material.reduce((a,v)=>a+(v===id),0)):null};readyResolve(window.terrainResult);
    window.dispatchEvent(new CustomEvent('terrain-ready',{detail:window.terrainResult}));
  }
};
const unit={warp:' m'};
for(const id of ['warp','ridge','stream','droplets','erosion','thermal'])$(id).addEventListener('input',()=>{$(`${id}-value`).value=Number($(id).value).toLocaleString('en-US')+(unit[id]||'');});
$('controls').addEventListener('submit',event=>{
  event.preventDefault();if(busy||!$('controls').reportValidity())return;
  busy=true;document.body.dataset.error='false';$('generate').disabled=true;$('status').textContent='A world is taking shape…';$('progress').value=0;
  worker.postMessage({engine:['v1','v2'].includes(query.get('engine'))?query.get('engine'):'current',seed:Number($('seed').value),n:Number($('resolution').value),base:$('base').checked,
    coast:Number($('coast').checked),rock:Number($('rock').checked),volcano:Number($('volcano').checked),caves:Number($('caves').checked),
    gentle:Number(query.get('gentle')??1),variety:Number(query.get('variety')??1),bands:Number(query.get('bands')??1),
    warp:Number($('warp').value),ridge:Number($('ridge').value),stream:Number($('stream').value),droplets:Number($('droplets').value),erosion:Number($('erosion').value),thermal:Number($('thermal').value)});
});
$('shading').addEventListener('change',recolor);$('drainage').addEventListener('change',hillshade);$('reset').addEventListener('click',cameraReset);
$('view').addEventListener('change',()=>{view=$('view').value;cameraReset();});
let drag;
$('scene').addEventListener('pointerdown',e=>{drag=[e.clientX,e.clientY];$('scene').setPointerCapture(e.pointerId);});
$('scene').addEventListener('pointerup',()=>{drag=null;});$('scene').addEventListener('pointercancel',()=>{drag=null;});
const pitchLimit=()=>view==='valley'?[-.3,1.2]:[.08,1.5];
function turn(dy,dp){yaw+=dy;const [lo,hi]=pitchLimit();pitch=Math.max(lo,Math.min(hi,pitch+dp));}
$('scene').addEventListener('pointermove',e=>{if(!drag)return;const s=view==='valley'?-.003:.005;turn(-(e.clientX-drag[0])*s,(e.clientY-drag[1])*s);drag=[e.clientX,e.clientY];draw();});
function zoom(factor){distance=Math.max(.3,Math.min(2.6,distance*factor));draw();}
$('scene').addEventListener('wheel',e=>{e.preventDefault();zoom(Math.exp(e.deltaY*.001));},{passive:false});
$('scene').addEventListener('keydown',e=>{
  if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','+','=','-'].includes(e.key))return;e.preventDefault();
  if(e.key==='ArrowLeft')turn(-.08,0);if(e.key==='ArrowRight')turn(.08,0);
  if(e.key==='ArrowUp')turn(0,.06);if(e.key==='ArrowDown')turn(0,-.06);
  if(e.key==='+'||e.key==='=')zoom(.9);if(e.key==='-')zoom(1.1);draw();
});
window.addEventListener('pagehide',()=>{worker.terminate();renderer.dispose();},{once:true});
// Query parameters are also the capture interface: no second terrain implementation.
// seed, n, base=1, view=valley, map=<pixels>, mesh=<segments>, engine=v1 (phase-A module, if built).
if(query.has('seed'))$('seed').value=query.get('seed');if(query.has('n'))$('resolution').value=query.get('n');
if(query.has('map')){const px=Math.max(64,Math.min(2048,Number(query.get('map'))||512));$('map').width=px;$('map').height=px;}
for(const id of ['coast','rock','volcano','caves'])if(query.has(id))$(id).checked=query.get(id)!=='0';
if(query.has('shading'))$('shading').value=query.get('shading');
$('base').checked=query.get('base')==='1';cameraReset();$('controls').requestSubmit();
