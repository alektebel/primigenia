const $=id=>document.getElementById(id);
const stages=['Shaping the valley and mountain ring','Water is carving the gullies','Loose stone is settling','Tracing the drainage network','Landscape ready'];
let terrain,mesh,lake,busy=false,readyResolve;
window.terrainReady=new Promise(resolve=>{readyResolve=resolve;});
const worker=new Worker(new URL('./worker.mjs',import.meta.url),{type:'module'});
window.addEventListener('error',event=>failure(event.message));
const THREE=window.THREE;
if (!THREE) throw Error('Three.js did not load. Check the network and reload.');
const renderer=new THREE.WebGLRenderer({canvas:$('scene'),antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.outputEncoding=THREE.sRGBEncoding;
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
const scene=new THREE.Scene();scene.background=new THREE.Color('#cbd9d4');scene.fog=new THREE.Fog('#cbd9d4',3000,6500);
const camera=new THREE.PerspectiveCamera(43,1,1,10000);
scene.add(new THREE.HemisphereLight('#e3efff','#546349',1.6));
const sun=new THREE.DirectionalLight('#ffdfad',2.8);sun.position.set(-1000,1500,700);scene.add(sun);
let yaw=.65,pitch=.78,distance=2700;
function cameraReset(){yaw=.65;pitch=.78;distance=2700;draw();}
function draw(){
  const box=$('vista').getBoundingClientRect();renderer.setSize(box.width,box.height,false);
  camera.aspect=box.width/box.height;camera.updateProjectionMatrix();
  const fit=distance*Math.max(1,1/camera.aspect);
  camera.position.set(Math.sin(yaw)*Math.cos(pitch)*fit,150+Math.sin(pitch)*fit,Math.cos(yaw)*Math.cos(pitch)*fit);
  camera.lookAt(0,150,0);renderer.render(scene,camera);
}
new ResizeObserver(draw).observe($('vista'));
const palette={grass:[.39,.48,.28],rock:[.44,.44,.39],scree:[.63,.54,.37],wet:[.19,.32,.29],snow:[.9,.94,.92]};
function blend(a,b,t){t=Math.max(0,Math.min(1,t));return a.map((x,i)=>x+(b[i]-x)*t);}
function sample(i){
  const {height:h,n,size}=terrain,x=i%n,y=Math.floor(i/n),cell=size/n;
  const gx=(h[y*n+Math.min(n-1,x+1)]-h[y*n+Math.max(0,x-1)])/(cell*(x===0||x===n-1?1:2));
  const gy=(h[Math.min(n-1,y+1)*n+x]-h[Math.max(0,y-1)*n+x])/(cell*(y===0||y===n-1?1:2));
  return {gx,gy,slope:Math.hypot(gx,gy)};
}
function groundColor(i,mode){
  const h=terrain.height[i],flow=terrain.flow[i],sed=terrain.sediment[i],{slope,gy}=sample(i);
  if(mode==='height')return blend([.17,.35,.24],[.97,.9,.67],h/600);
  if(mode==='slope')return blend([.83,.87,.66],[.42,.22,.16],slope/1.4);
  if(mode==='flow')return blend([.86,.88,.77],[.02,.30,.50],Math.log2(1+flow*terrain.n*terrain.n)/11);
  if(mode==='sediment')return blend([.24,.33,.29],[.98,.68,.24],Math.sqrt(sed)*.8);
  let c=blend(palette.grass,palette.rock,(slope-.3)/.55);
  c=blend(c,palette.scree,Math.min(.85,sed*.2)*Math.max(0,1-slope));
  c=blend(c,palette.wet,Math.min(.7,flow*160)*(1-Math.min(1,slope)));
  // +y in the map points south; positive gy faces north and retains snow.
  const snow=(h-420+Math.max(-1,Math.min(1,gy))*35)/90;
  return blend(c,palette.snow,Math.max(0,snow)*Math.max(0,1-slope*.6));
}
function recolor(){
  if(!mesh)return;
  const colors=mesh.geometry.attributes.color,source=mesh.userData.source,c=new THREE.Color();
  for(let j=0;j<source.length;j++){
    const rgb=groundColor(source[j],$('shading').value);c.setRGB(...rgb).convertSRGBToLinear();colors.setXYZ(j,c.r,c.g,c.b);
  }
  colors.needsUpdate=true;draw();
}
function buildMesh(){
  if(mesh){scene.remove(mesh);mesh.geometry.dispose();mesh.material.dispose();}
  if(lake){scene.remove(lake);lake.geometry.dispose();lake.material.dispose();}
  const {n,height,size}=terrain;
  // Fixed 256²-cell preview mesh. Full maps drive shading and hillshade.
  const segments=Math.min(n-1,distance>3800?128:256),v=segments+1;
  const g=new THREE.BufferGeometry(),positions=new Float32Array(v*v*3),colors=new Float32Array(v*v*3),indices=[],source=[];
  for(let y=0;y<v;y++)for(let x=0;x<v;x++){
    const sx=Math.round(x*(n-1)/segments),sy=Math.round(y*(n-1)/segments),i=sy*n+sx,j=y*v+x;
    positions.set([(sx+.5)*size/n-size/2,height[i],(sy+.5)*size/n-size/2],j*3);source.push(i);
    if(x<segments&&y<segments){indices.push(j,j+v,j+1,j+1,j+v,j+v+1);}
  }
  g.setAttribute('position',new THREE.BufferAttribute(positions,3));g.setAttribute('color',new THREE.BufferAttribute(colors,3));g.setIndex(indices);g.computeVertexNormals();
  mesh=new THREE.Mesh(g,new THREE.MeshStandardMaterial({vertexColors:true,roughness:1}));mesh.userData.source=source;mesh.userData.far=distance>3800;scene.add(mesh);
  lake=new THREE.Mesh(new THREE.CircleGeometry(42,48),new THREE.MeshStandardMaterial({color:'#397e8a',roughness:.32,metalness:.12}));
  lake.rotation.x=-Math.PI/2;lake.position.set(-150,26,70);scene.add(lake);recolor();
}
function hillshade(){
  if(!terrain)return;
  const canvas=$('map'),ctx=canvas.getContext('2d'),w=canvas.width,img=ctx.createImageData(w,w),{n}=terrain;
  for(let y=0;y<w;y++)for(let x=0;x<w;x++){
    const sx=Math.min(n-1,Math.floor(x*n/w)),sy=Math.min(n-1,Math.floor(y*n/w)),i=sy*n+sx,{gx,gy}=sample(i);
    const light=Math.max(0,(-gx*-.58+1*.70-gy*.41)/Math.sqrt(1+gx*gx+gy*gy));
    let c=blend([.26,.34,.26],[.9,.89,.74],.22+.78*light);
    if(terrain.height[i]<26)c=[.22,.48,.55];
    if($('drainage').checked){
      // Preserve narrow channels when downsampling, rather than missing every other pixel.
      let f=0;const step=Math.max(1,Math.ceil(n/w));
      for(let dy=0;dy<step;dy++)for(let dx=0;dx<step;dx++)f=Math.max(f,terrain.flow[Math.min(n-1,sy+dy)*n+Math.min(n-1,sx+dx)]);
      if(f*terrain.size*terrain.size>=8000)c=[.04,.34,.55];
    }
    img.data.set([...c.map(v=>Math.round(v*255)),255],(y*w+x)*4);
  }
  ctx.putImageData(img,0,0);
}
function failure(message){busy=false;$('generate').disabled=false;document.body.dataset.error='true';$('status').textContent=`${message} Adjust the parameters or reload to try again.`;}
worker.onerror=event=>failure(event.message||'The terrain worker could not start.');
worker.onmessage=({data})=>{
  if(data.type==='error'){failure(data.message);return;}
  if(data.type==='progress'){$('status').textContent=stages[data.stage];$('progress').value=Math.min(100,(data.stage+data.done/data.total)*25);return;}
  if(data.type==='terrain'){
    terrain=data;buildMesh();hillshade();busy=false;$('generate').disabled=false;$('progress').value=100;
    $('status').textContent=`${data.base?'Base only':'Eroded'} · generated in ${data.seconds.toFixed(2)} s in a Web Worker`;
    $('summary').textContent=`Seed ${data.seed} · ${data.n} × ${data.n} · 2 km · generator v${data.version}`;$('hash').textContent=data.hash;
    window.terrainResult={seed:data.seed,n:data.n,hash:data.hash,seconds:data.seconds,base:data.base};readyResolve(window.terrainResult);
    window.dispatchEvent(new CustomEvent('terrain-ready',{detail:window.terrainResult}));
  }
};
for(const id of ['warp','ridge','droplets','erosion','thermal'])$(id).addEventListener('input',()=>{$(`${id}-value`).value=Number($(id).value).toLocaleString('en-US')+(id==='warp'?' m':'');});
$('controls').addEventListener('submit',event=>{
  event.preventDefault();if(busy||!$('controls').reportValidity())return;
  busy=true;document.body.dataset.error='false';$('generate').disabled=true;$('status').textContent='A world is taking shape…';$('progress').value=0;
  worker.postMessage({seed:Number($('seed').value),n:Number($('resolution').value),base:$('base').checked,
    warp:Number($('warp').value),ridge:Number($('ridge').value),droplets:Number($('droplets').value),erosion:Number($('erosion').value),thermal:Number($('thermal').value)});
});
$('shading').addEventListener('change',recolor);$('drainage').addEventListener('change',hillshade);$('reset').addEventListener('click',cameraReset);
let drag;
$('scene').addEventListener('pointerdown',e=>{drag=[e.clientX,e.clientY];$('scene').setPointerCapture(e.pointerId);});
$('scene').addEventListener('pointerup',()=>{drag=null;});$('scene').addEventListener('pointercancel',()=>{drag=null;});
$('scene').addEventListener('pointermove',e=>{if(!drag)return;yaw-=(e.clientX-drag[0])*.005;pitch=Math.max(.15,Math.min(1.5,pitch+(e.clientY-drag[1])*.005));drag=[e.clientX,e.clientY];draw();});
function zoom(factor){distance=Math.max(750,Math.min(5800,distance*factor));if(mesh&&mesh.userData.far!==(distance>3800))buildMesh();draw();}
$('scene').addEventListener('wheel',e=>{e.preventDefault();zoom(Math.exp(e.deltaY*.001));},{passive:false});
$('scene').addEventListener('keydown',e=>{
  if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','+','=','-'].includes(e.key))return;e.preventDefault();
  if(e.key==='ArrowLeft')yaw-=.08;if(e.key==='ArrowRight')yaw+=.08;
  if(e.key==='ArrowUp')pitch=Math.min(1.5,pitch+.06);if(e.key==='ArrowDown')pitch=Math.max(.15,pitch-.06);
  if(e.key==='+'||e.key==='=')zoom(.9);if(e.key==='-')zoom(1.1);draw();
});
window.addEventListener('pagehide',()=>{worker.terminate();renderer.dispose();},{once:true});
// Query parameters are also the capture interface: no second terrain implementation.
const query=new URLSearchParams(location.search);
if(query.has('seed'))$('seed').value=query.get('seed');if(query.has('n'))$('resolution').value=query.get('n');
$('base').checked=query.get('base')==='1';draw();$('controls').requestSubmit();
