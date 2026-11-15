
(async()=>{
const T=THREE,$=id=>document.getElementById(id),V=(x,y,z)=>new T.Vector3(x,y,z);
const lerp=(a,b,t)=>a+(b-a)*t,clamp=(x,a,b)=>Math.min(b,Math.max(a,x)),sstep=(a,b,x)=>{x=clamp((x-a)/(b-a),0,1);return x*x*(3-2*x)};
const lin=h=>new T.Color(h).convertSRGBToLinear();

const [partTable,partManifest]=await Promise.all(['parts.json','parts/manifest.json'].map(url=>fetch(url).then(r=>{if(!r.ok)throw Error(url);return r.json()})));
const tableById=Object.fromEntries(partTable.parts.map(p=>[p.id,p]));
let lang=localStorage.getItem('cpore.lang')==='en'?'en':'es',editTool='sculpt',selectedRegionId=null,pendingPart=null;
const EN=StudioI18n.en;for(const entry of partTable.parts)EN[entry.name.es]=entry.name.en;
const ABILITY_ES={perception:'Percepción','wide gaze':'Visión amplia',bite:'Mordisco',charge:'Embestida',armor:'Armadura',sprint:'Carrera',climb:'Escalada',swim:'Natación',grasp:'Agarre',counterattack:'Contraataque',glide:'Planeo',display:'Exhibición',sing:'Canto',charm:'Encanto',strike:'Golpe','ranged capture':'Captura a distancia','ranged spit':'Escupitajo',jump:'Salto',dance:'Baile',sneak:'Sigilo',defense:'Defensa',burrow:'Excavación'};
for(const [en,es]of Object.entries(ABILITY_ES))if(!EN[es])EN[es]=en;
const tr=t=>t.startsWith('migration.extra:')?(lang==='en'?'Preserved without conversion: ':'Se conserva sin migrar: ')+t.slice(16):lang==='en'?(EN[t]||t):(StudioI18n.es[t]||t);
/* ---------- render y escena ---------- */
const renderer=new T.WebGLRenderer({canvas:$('gl'),antialias:true});
renderer.outputEncoding=T.sRGBEncoding;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
const scene=new T.Scene(),camera=new T.PerspectiveCamera(42,1,.1,2000);
const FOG=[.93,.74,.56],SUN=V(-.62,.3,-.72).normalize();
scene.fog=new T.Fog(new T.Color(...FOG),35,560);
const skyMat=()=>new T.ShaderMaterial({side:T.BackSide,depthWrite:false,fog:false,toneMapped:false,uniforms:{sun:{value:SUN}},
  vertexShader:'varying vec3 d;void main(){d=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',
  fragmentShader:'varying vec3 d;uniform vec3 sun;void main(){vec3 n=normalize(d);float h=n.y;vec3 c=mix(vec3(.93,.74,.56),vec3(.50,.60,.78),smoothstep(0.,.28,h));c=mix(c,vec3(.17,.30,.58),smoothstep(.2,.95,h));c=mix(c,vec3(.30,.24,.18),step(h,0.)*.6);float s=max(dot(n,sun),0.);c+=vec3(1.,.62,.28)*pow(s,7.)*.55+vec3(1.,.9,.7)*pow(s,60.)*.5+vec3(1.,.97,.9)*smoothstep(.9988,.9995,s)*3.;gl_FragColor=vec4(c,1.);}'});
const sky=new T.Mesh(new T.SphereGeometry(1500,32,20),skyMat());sky.renderOrder=-1;scene.add(sky);
{const es=new T.Scene(),sg=new T.SphereGeometry(50,32,20),p=sg.attributes.position,c=new Float32Array(p.count*3),hz=new T.Color(.9,.55,.3),mid=new T.Color(.32,.42,.62),top=new T.Color(.08,.16,.4),gd=new T.Color(.12,.09,.06),tc=new T.Color();
  for(let i=0;i<p.count;i++){const h=p.getY(i)/50;if(h<0)tc.copy(hz).lerp(gd,sstep(0,.15,-h));else tc.copy(hz).lerp(mid,sstep(0,.3,h)).lerp(top,sstep(.25,.95,h));c.set([tc.r,tc.g,tc.b],i*3)}
  sg.setAttribute('color',new T.BufferAttribute(c,3));es.add(new T.Mesh(sg,new T.MeshBasicMaterial({vertexColors:true,side:T.BackSide})));
  const sm=new T.Mesh(new T.SphereGeometry(5,16,12),new T.MeshBasicMaterial({color:new T.Color(14,8,3.5)}));sm.position.copy(SUN).multiplyScalar(44);es.add(sm);
  const pm=new T.PMREMGenerator(renderer);scene.environment=pm.fromScene(es,.03).texture;pm.dispose()}
scene.add(new T.HemisphereLight(lin('#9db8e8'),lin('#5a4630'),.35));
const sun=new T.DirectionalLight(lin('#ffcf9a'),3.1);sun.position.copy(SUN).multiplyScalar(80);sun.castShadow=true;sun.shadow.mapSize.set(2048,2048);
{const c=sun.shadow.camera;c.left=c.bottom=-17;c.right=c.top=17;c.near=10;c.far=200;sun.shadow.bias=-.0004;sun.shadow.normalBias=.05;sun.shadow.radius=3}scene.add(sun);

const NOISE='float hsh(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}float vn(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hsh(i),hsh(i+vec2(1.,0.)),f.x),mix(hsh(i+vec2(0.,1.)),hsh(i+vec2(1.,1.)),f.x),f.y);}\n';
const RC=7,CX=-7; /* sendero circular que pasa por el origen */
const ground=new T.Mesh(new T.CircleGeometry(700,72).rotateX(-Math.PI/2),new T.MeshStandardMaterial({roughness:1}));ground.receiveShadow=true;scene.add(ground);
ground.material.onBeforeCompile=s=>{s.vertexShader='varying vec3 vWp;\n'+s.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nvWp=(modelMatrix*vec4(transformed,1.)).xyz;');
  s.fragmentShader='varying vec3 vWp;\n'+NOISE+s.fragmentShader.replace('#include <color_fragment>',`float r=length(vWp.xz-vec2(-7.,0.)),n=vn(vWp.xz*.6)*.6+vn(vWp.xz*2.9)*.4;float tr=smoothstep(5.3,6.1,r+n*.8)*(1.-smoothstep(7.9,8.7,r-n*.8));
   vec3 dirt=mix(vec3(.13,.085,.05),vec3(.26,.18,.11),n)*(.8+.4*vn(vWp.xz*11.));vec3 gr=mix(vec3(.035,.085,.02),vec3(.08,.15,.035),n);diffuseColor.rgb=mix(gr,dirt,tr);`)};
/* hierba: brizna instanciada con viento, no cubre el sendero */
{const N=120000,a=new Float32Array(N*4),r0=rngFrom(5);let k=0;
 while(k<N){const an=r0()*6.2832,rr=Math.sqrt(r0())*64,gx=Math.sin(an)*rr,gz=Math.cos(an)*rr,r=Math.hypot(gx-CX,gz);if(r>5.5&&r<8.5)continue;const e=Math.min(Math.abs(r-5.5),Math.abs(r-8.5));a.set([gx,gz,r0(),(.35+r0()*.6)*(.45+.55*sstep(0,2.5,e))],k*4);k++}
 const g=new T.InstancedBufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute([-.5,0,0,.5,0,0,-.34,.5,0,.34,.5,0,0,1,0],3));g.setIndex([0,1,2,2,1,3,2,3,4]);g.setAttribute('inst',new T.InstancedBufferAttribute(a,4));g.instanceCount=N;
 var grassU={uTime:{value:0},fogC:{value:V(...FOG)}};
 const m=new T.Mesh(g,new T.ShaderMaterial({side:T.DoubleSide,toneMapped:false,uniforms:grassU,
  vertexShader:`attribute vec4 inst;uniform float uTime;varying float vH;varying float vD;varying float vR;void main(){vec2 b=inst.xy;float rnd=inst.z,hg=inst.w,ang=rnd*44.;
   float gust=sin(b.x*.14+b.y*.1+uTime*1.5)+sin(b.x*.33-b.y*.29+uTime*2.2)*.5;vec3 p=position;float bend=(.1+.16*gust)*p.y*p.y*hg,wd=.08*(.6+rnd);
   vec3 wp=vec3(b.x+p.x*cos(ang)*wd+bend*.85,p.y*hg,b.y+p.x*sin(ang)*wd+bend*.5);vH=p.y;vR=rnd+gust*.15;vec4 mv=viewMatrix*vec4(wp,1.);vD=-mv.z;gl_Position=projectionMatrix*mv;}`,
  fragmentShader:`uniform vec3 fogC;varying float vH;varying float vD;varying float vR;void main(){vec3 c=mix(vec3(.10,.19,.05),mix(vec3(.50,.56,.17),vec3(.78,.66,.26),vR*.6),vH*vH);gl_FragColor=vec4(mix(c,fogC,smoothstep(35.,560.,vD)),1.);}`}));
 m.frustumCulled=false;scene.add(m)}
function rngFrom(a){return()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
/* rocas y sierras */
{const r0=rngFrom(11),rm=new T.MeshStandardMaterial({vertexColors:true,roughness:.92});
 const rock=(x,z,s,sy)=>{const g=new T.SphereGeometry(1,26,18),p=g.attributes.position,c=new Float32Array(p.count*3),o=r0()*50;
   for(let i=0;i<p.count;i++){const x0=p.getX(i),y0=p.getY(i),z0=p.getZ(i),d=1+.22*Math.sin(x0*3+o)*Math.cos(z0*2.6+o)+.13*Math.sin(y0*5+x0*4+o);p.setXYZ(i,x0*d,y0*d*sy,z0*d)}
   g.computeVertexNormals();const n=g.attributes.normal,gr=lin('#6f675c'),ms=lin('#4a5a28');for(let i=0;i<p.count;i++){const t=sstep(.55,.9,n.getY(i)),v=.8+.3*r0();c.set([lerp(gr.r,ms.r,t)*v,lerp(gr.g,ms.g,t)*v,lerp(gr.b,ms.b,t)*v],i*3)}
   g.setAttribute('color',new T.BufferAttribute(c,3));const m=new T.Mesh(g,rm);m.position.set(x,s*sy*.25,z);m.scale.setScalar(s);m.rotation.y=r0()*6;m.castShadow=m.receiveShadow=true;scene.add(m)};
 rock(-7,0,1.7,.75);rock(-5.1,.9,.8,.7);rock(-8.5,1.4,.6,.6);
 for(let i=0;i<34;i++){const a=r0()*6.28,r=11+r0()*30,qx=CX+Math.sin(a)*r,qz=Math.cos(a)*r;if(Math.hypot(qx,qz)<19)continue;rock(qx,qz,.5+r0()*r0()*3.2,.6+r0()*.5)}
 for(const[R,hh,colr,sd]of[[250,55,'#52604a',3],[380,120,'#4b5870',8],[520,200,'#5a6688',15]]){const n=420,pos=[],idx=[];
   for(let i=0;i<=n;i++){const a=i/n*6.2832,h=hh*(.45+.3*Math.sin(a*3+sd)+.22*Math.sin(a*7+sd*2)+.12*Math.sin(a*13+sd)+.07*Math.sin(a*29+sd*3)+.04*Math.sin(a*61+sd));pos.push(Math.sin(a)*R,-4,Math.cos(a)*R,Math.sin(a)*(R+hh*.6),h,Math.cos(a)*(R+hh*.6))}
   for(let i=0;i<n;i++){const a=i*2;idx.push(a,a+1,a+2,a+2,a+1,a+3)}
   const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(pos,3));g.setIndex(idx);g.computeVertexNormals();scene.add(new T.Mesh(g,new T.MeshStandardMaterial({color:lin(colr),roughness:1,side:T.DoubleSide})))}}

const {createCreatureRig}=await import('../creature/rig.js');
const rig=await createCreatureRig({T,scene,SUN,partTable,partManifest,assetBase:'./',onStats:()=>drawStats(),getDrag:()=>drag});
const {loader,SU,skinM,skinM2,boneM,toothM,beakM,eyeW,irisM,pupM,darkM,membraneM,gliderM,insectM,sacM,glowM,LIB,glbTemplates,materialSlots,assetFailures,NSP,NC,NS,RN,Y,pts,rest,frames,RAD,creature,partsG,handlesG,limbs,body,selRings,A1,A2,rotH,ZA,X0,DOWN,_a,_b,_c,_d,_e,_m,_q,_t,_s,_u,_n,selAx,PLBL,BUDGET,SEEDS,regionViews,regionDefaults,growthG,mesh,legLens,legMeshes,defaults,anchor,centered,hasLeg,buildParts,drawHandles,refresh,clear,update,rebuildGrowth,positionGrowth,orient,regionRange}=rig;
let hist=[],fut=[];
/* ---------- cámara ---------- */
let camYaw=2.2,camPitch=.14,camDist=13;const tgt=V(0,1.5,0),want=V();
function frameCam(dt,snap){want.copy(pts[NS>>1]).applyMatrix4(creature.matrixWorld);if(snap)tgt.copy(want);else tgt.lerp(want,1-Math.pow(.01,dt));
  const a=camYaw-rig.theta,cp=Math.cos(camPitch),distance=camDist*Math.max(1,.9/camera.aspect);camera.position.set(tgt.x+Math.sin(a)*cp*distance,Math.max(.3,tgt.y+Math.sin(camPitch)*distance),tgt.z+Math.cos(a)*cp*distance);camera.lookAt(tgt);sky.position.copy(camera.position)}
function resize(){const s=$('gl'),w=s.clientWidth||800,h=s.clientHeight||600;renderer.setPixelRatio(Math.min(devicePixelRatio||1,2));renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix()}
addEventListener('resize',resize);

/* ---------- edición directa ---------- */
const gl=$('gl'),ray=new T.Raycaster(),ndc=new T.Vector2(),ghost=$('ghost'),gctx=ghost.getContext('2d');let drag=null,hoverNode=-1;
/* la pieza viaja pegada al cursor hasta que toca el cuerpo */
function ghostAt(e,on,type){if(on&&ghost.dataset.t!==type){renderThumb(type,.6,gctx);ghost.dataset.t=type}ghost.style.display=on?'block':'none';ghost.style.left=e.clientX+'px';ghost.style.top=e.clientY+'px'}
function setRay(e){const r=gl.getBoundingClientRect();ndc.set((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1);ray.setFromCamera(ndc,camera);return e.clientX>=r.left&&e.clientX<=r.right&&e.clientY>=r.top&&e.clientY<=r.bottom}
function hitBody(){body.geometry.computeBoundingSphere();const h=ray.intersectObject(body)[0];if(!h)return null;const lp=creature.worldToLocal(h.point.clone()),pa=body.geometry.attributes.position,f=h.face;
  const bc=T.Triangle.getBarycoord(lp,_a.fromBufferAttribute(pa,f.a),_b.fromBufferAttribute(pa,f.b),_c.fromBufferAttribute(pa,f.c),V()),rg=i=>Math.floor(i/RN),ja=f.a%RN,dj=i=>((i%RN-ja+RN*1.5)%RN)-RN/2;
  let ang=(ja+dj(f.b)*bc.y+dj(f.c)*bc.z)/RN*6.28318;ang=Math.atan2(Math.sin(ang),Math.cos(ang));return{t:(rg(f.a)*bc.x+rg(f.b)*bc.y+rg(f.c)*bc.z)/(NS-1),ang}}
function hitJoint(){const h=ray.intersectObjects(handlesG.children.filter(c=>c.userData.joint))[0];return h?h.object:null}
function hitNode(){if(!rig.spineG)return -1;const h=ray.intersectObjects(rig.spineG.children.filter(c=>c.userData.node!=null),true)[0];return h?h.object.userData.node:-1}
const overBody=()=>{body.geometry.computeBoundingSphere();return ray.intersectObject(body).length>0};
function hitPart(){const h=ray.intersectObjects([partsG,limbs],true)[0];return h?h.object.userData.part:null}
function place(p,h){const was=centered(p);let a=Math.abs(h.ang);if(hasLeg(p)){if(Math.abs(Math.sin(a))<.2)a=a<1.57?.2:Math.PI-.2}else if(Math.abs(Math.sin(a))<.14)a=Math.cos(a)>0?0:Math.PI;p.t=clamp(h.t,0,1);p.ang=a;if(was!==centered(p))buildParts();else if(hasLeg(p))buildParts(true)}
function snapshot(){return JSON.stringify(rig.G)}
function save(){try{localStorage.setItem('cpore.creature.v4',snapshot())}catch(e){}if($('json')&&document.activeElement!==$('json'))$('json').value=JSON.stringify(rig.G,null,1);syncHistory()}
function syncHistory(){$('undo').disabled=hist.length<2;$('redo').disabled=!fut.length}
function commit(){const next=snapshot();if(hist.at(-1)===next)return;hist.push(next);if(hist.length>100)hist.shift();fut=[];save()}
function loadG(g,keep){rig.G=JSON.parse(typeof g==='string'?g:JSON.stringify(g));$('name').value=rig.G.name||'';rig.sel=null;selectedRegionId=rig.G.regions.some(r=>r.id===selectedRegionId)?selectedRegionId:rig.G.regions[0]?.id||null;rig.theta=0;rig.phase=0;refresh(true);syncSkin();drawPanel();if(!keep){const len=rest[NS-1].distanceTo(rest[0]);camDist=5+len*1.15}}
function undo(){if(hist.length<2)return;fut.push(hist.pop());loadG(hist.at(-1),true);save()}
function redo(){if(!fut.length)return;const next=fut.pop();hist.push(next);loadG(next,true);save()}
function importGenome(input){const result=StudioDocument.parse(input,tableById);loadG(result.genome,true);commit();report(result.warnings.length?result.warnings.map(w=>tr(w)).join(' · '):tr('Diseño cargado'));return result}
function removePart(p){rig.G.parts=rig.G.parts.filter(q=>q!==p);if(rig.sel===p)rig.sel=null;buildParts();drawPanel();commit()}
function newPart(type){return defaults(type)}
function moveNode(i,y,z){const N=rig.G.nodes,n=N[i];_a.set(0,y,z);for(const j of[i-1,i+1]){if(j<0||j>=N.length)continue;_b.set(0,N[j].y,N[j].z);const d=_a.distanceTo(_b);if(d<.3||d>1.95)_a.sub(_b).setLength(clamp(d,.3,1.95)).add(_b)}n.y=clamp(_a.y,n.r+.1,20);n.z=clamp(_a.z,-30,30);
  const end=i===0||i===N.length-1;if(end){const j=i===0?1:N.length-2,m=N[j],d=Math.hypot(n.y-m.y,n.z-m.z);
    if(d>1.5&&N.length<14){N.splice(i===0?1:N.length-1,0,{y:(n.y+m.y)/2,z:(n.z+m.z)/2,r:(n.r+m.r)/2});if(i!==0)drag.node=N.length-1}
    else if(d<.34&&N.length>4){const k=i===0?2:N.length-3,q=N[k];if(Math.hypot(n.y-q.y,n.z-q.z)<1.45){N.splice(j,1);if(i!==0)drag.node=N.length-1}}}
  refresh(false)}
let gestureStart=null;
gl.addEventListener('pointerdown',e=>{
 gestureStart=snapshot();
 if(rig.mode!=='build')return;
 setRay(e);
 if(editTool==='orbit'){gl.setPointerCapture(e.pointerId);drag={k:'cam',x:e.clientX,y:e.clientY,moved:false};e.stopImmediatePropagation();return}
 const rh=ray.intersectObjects(growthG.children,true)[0];
 if(rh&&editTool!=='growth'){selectedRegionId=rh.object.userData.region;editTool='growth';rig.sel=null;drawPanel();e.stopImmediatePropagation();return}
 if(editTool==='growth'&&selectedRegion()){drag={k:'growth'};gl.setPointerCapture(e.pointerId);moveGrowth(e);e.stopImmediatePropagation();return}
 if(pendingPart){const h=hitBody();if(h){const p=newPart(pendingPart);rig.G.parts.push(p);place(p,h);rig.sel=p;pendingPart=null;buildParts();drawPanel();commit()}e.stopImmediatePropagation();return}
},true);
function moveGrowth(e){if(!setRay(e))return;const h=hitBody(),r=selectedRegion();if(!h||!r)return;const [a,b]=regionRange(r.surface);r.position=clamp((h.t-a)/(b-a),0,1);r.angle=Math.abs(h.ang);r.coverage=Math.min(r.coverage,.3);positionGrowth()}
addEventListener('pointermove',e=>{if(drag?.k==='growth'){moveGrowth(e);e.stopImmediatePropagation()}},true);
addEventListener('pointerup',e=>{if(drag?.k==='growth'){drag=null;drawPanel();commit();e.stopImmediatePropagation()}},true);
addEventListener('pointercancel',()=>{if(gestureStart){drag=null;loadG(gestureStart,true);ghost.style.display='none'}});
gl.addEventListener('pointerdown',e=>{setRay(e);gl.setPointerCapture(e.pointerId);if(rig.mode==='build')rig.spineOn=hitNode()>=0||overBody();
  if(rig.mode==='build'){if(rotH.visible&&ray.intersectObject(rotH)[0]){drag={k:'rot',p:rig.sel};return}
    const jt=hitJoint();if(jt){drag={k:'joint',j:jt.userData.joint,sg:jt.userData.sg,p:rig.sel,plane:new T.Plane().setFromNormalAndCoplanarPoint(camera.getWorldDirection(V()),jt.getWorldPosition(V()))};return}
    const n=hitNode();if(n>=0){drag={k:'node',node:n};return}const p=hitPart();if(p){rig.sel=p;drawPanel();drag={k:'part',p,x:e.clientX,y:e.clientY,moved:false,over:true};return}}
  drag={k:'cam',x:e.clientX,y:e.clientY,moved:false};gl.style.cursor='grabbing'});
addEventListener('pointermove',e=>{const inside=setRay(e);
  if(!drag){if(rig.mode==='build'){const n=hitNode();rig.spineOn=e.target===gl&&(n>=0||overBody());if(n!==hoverNode){hoverNode=n;if(rig.spineG)rig.spineG.children.forEach(h=>{if(h.userData.node!=null)h.scale.setScalar(h.userData.node===n?1.3:1)})}gl.style.cursor=n>=0||hitJoint()||(rotH.visible&&ray.intersectObject(rotH)[0])?'move':hitPart()?'pointer':'grab'}return}
  if(drag.k==='cam'){camYaw-=(e.clientX-drag.x)*.006;camPitch=clamp(camPitch+(e.clientY-drag.y)*.004,-.02,1.2);if(Math.abs(e.movementX)+Math.abs(e.movementY)>1)drag.moved=true;drag.x=e.clientX;drag.y=e.clientY}
  else if(drag.k==='rot'){const pl=new T.Plane().setFromNormalAndCoplanarPoint(selAx.n,_e.copy(selAx.p).add(creature.position)),w=ray.ray.intersectPlane(pl,_a);if(w){w.sub(creature.position).sub(selAx.p);drag.p.rot=Math.atan2(-w.dot(selAx.x),w.dot(selAx.y));const el=$('p-rot');if(el)el.value=drag.p.rot;if(LIB[drag.p.type].fittedLeg)buildParts(true);setHint('Gira la pieza alrededor de su base')}}
  else if(drag.k==='joint'){const l=rig.legs.find(l=>l.p===drag.p&&l.sg===drag.sg);let wp=null;
    if(drag.j==='f'){const o=ray.ray.origin,d=ray.ray.direction,q=(l.w*.6-o.y)/d.y;if(d.y<-1e-3&&q>0)wp=_a.copy(o).addScaledVector(d,q)}else wp=ray.ray.intersectPlane(drag.plane,_a);
    if(wp&&l){const r=wp.sub(creature.position).sub(l.h0),v=[r.x*drag.sg,r.y,r.z];
      if(drag.j==='k'){if(hyp(v)>.15)drag.p.k=v}else if(Math.hypot(v[0],v[2])<6)drag.p.f=[v[0],drag.p.f[1],v[2]];buildParts(true);drawHandles();setHint(drag.j==='f'?'El pie se desliza por el suelo':'Suelta para fijar la rodilla')}}
  else if(drag.k==='node'){const o=ray.ray.origin,d=ray.ray.direction;if(Math.abs(d.x)>1e-4){const s=-o.x/d.x;if(s>0)moveNode(drag.node,o.y+d.y*s-rig.off,o.z+d.z*s)}}
  else if(drag.k==='part'){if(!drag.moved&&!drag.isNew&&Math.hypot(e.clientX-drag.x,e.clientY-drag.y)<5)return;drag.moved=true;const h=inside&&hitBody();
    if(h){if(drag.isNew&&!rig.G.parts.includes(drag.p)){rig.G.parts.push(drag.p);rig.sel=drag.p;place(drag.p,h);buildParts();drawPanel()}else place(drag.p,h);drag.over=true}else drag.over=false;
    for(const o of rig.objs)if(o.p===drag.p)o.g.visible=drag.over;for(const l of rig.legs)if(l.p===drag.p)l.up.visible=l.lo.visible=l.ft.visible=drag.over;ghostAt(e,!drag.over,drag.p.type);setHint(drag.over?'Suelta para colocar':drag.isNew&&!rig.G.parts.includes(drag.p)?'Llévala hasta el cuerpo de la criatura':'Suelta fuera del cuerpo para quitar la pieza')}});
addEventListener('pointerup',e=>{if(!drag)return;const d=drag;drag=null;gl.style.cursor='grab';ghost.style.display='none';setHint();
  if(d.k==='cam'){if(!d.moved&&rig.sel&&rig.mode==='build'){rig.sel=null;drawPanel()}return}
  if(d.k==='rot'){commit();return}
  if(d.k==='node'||d.k==='joint'){buildParts();drawHandles();commit();return}
  if(d.k==='part'){if(d.isNew&&!d.moved){pendingPart=d.p.type;flashOk('Toca el cuerpo para colocar');return}
    if(d.moved){if(!d.over&&rig.G.parts.includes(d.p))removePart(d.p);else if(rig.G.parts.includes(d.p)){buildParts();drawPanel();commit()}}}});

gl.addEventListener('wheel',e=>{e.preventDefault();setRay(e);
  if(rig.mode==='build'){const n=hitNode();if(n>=0){rig.G.nodes[n].r=clamp(rig.G.nodes[n].r*(1-e.deltaY*.0012),.05,1.7);refresh(false);clearTimeout(gl._t);gl._t=setTimeout(commit,400);return}
    const p=hitPart();if(p&&p===rig.sel&&p.size){p.size=clamp(p.size*(1-e.deltaY*.001),.5,2.2);buildParts();drawPanel();clearTimeout(gl._t);gl._t=setTimeout(commit,400);return}}
  camDist=clamp(camDist*(1+e.deltaY*.001),3,60)},{passive:false});
addEventListener('keydown',e=>{if(['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName))return;
 if(e.key==='Escape'){if(drag&&gestureStart){drag=null;loadG(gestureStart,true);ghost.style.display='none'}pendingPart=null;return}
 if((e.ctrlKey||e.metaKey)&&['z','y'].includes(e.key.toLowerCase())){e.preventDefault();if(e.shiftKey||e.key.toLowerCase()==='y')redo();else undo();return}
 if(rig.mode==='build'&&(e.key==='Delete'||e.key==='Backspace')&&rig.sel){e.preventDefault();removePart(rig.sel)}
 if(rig.mode==='build'&&e.key.startsWith('Arrow')){const r=editTool==='growth'&&selectedRegion(),p=rig.sel;if(r||p){e.preventDefault();if(r){if(['ArrowLeft','ArrowRight'].includes(e.key))r.position=clamp(r.position+(e.key==='ArrowRight'?.02:-.02),0,1);else r.angle=clamp(r.angle+(e.key==='ArrowUp'?-.05:.05),-Math.PI,Math.PI);positionGrowth()}else{p.t=clamp(p.t+(e.key==='ArrowRight'?.02:e.key==='ArrowLeft'?-.02:0),0,1);p.ang=clamp(p.ang+(e.key==='ArrowUp'?-.05:e.key==='ArrowDown'?.05:0),0,Math.PI);buildParts()}commit();drawPanel()}}
});

/* ---------- interfaz ---------- */
const PATS=['liso','rayas','manchas','veteado'],HINTS={build:'Pasa el cursor por el cuerpo para ver la columna · arrastra una vértebra para esculpir · rueda sobre ella para engordar',paint:'Arrastra para girar la cámara',test:'Tu criatura camina sola: nada está animado a mano'};
let flashT=0;function setHint(t){$('hint').textContent=tr(t||HINTS[rig.mode])}function flash(t){setHint(t);clearTimeout(flashT);flashT=setTimeout(setHint,2200);$('meter').classList.add('over');setTimeout(()=>$('meter').classList.remove('over'),600)}
function syncSkin(){const s=rig.G.skin;SU.cA.value.copy(lin(s.cA));SU.cB.value.copy(lin(s.cB));SU.cC.value.copy(lin(s.cC));SU.uPat.value=s.pat;SU.uWet.value=s.wet;SU.uScale.value=s.scale;skinM.clearcoat=skinM2.clearcoat=s.wet*.8;membraneM.clearcoat=s.wet*.12;clearTimeout(syncSkin.t);syncSkin.t=setTimeout(()=>typeof drawThumbs==='function'&&drawThumbs(),120)}
const pips=n=>'<span class="pips">'+[1,2,3,4,5].map(i=>`<i class="${i<=n?'on':''}"></i>`).join('')+'</span>';
function drawStats(){$('dna').textContent=`${rig.stats.dna} / ${BUDGET}`;$('meter').firstElementChild.style.width=clamp(rig.stats.dna/BUDGET*100,0,100)+'%';if(!$('caps'))return;
  $('caps').innerHTML=[['Velocidad',rig.stats.vel],['Mordisco',rig.stats.bite],['Canto',rig.stats.sing],['Salud',rig.stats.hp]].map(([n,v])=>`<div class="cap"><span>${tr(n)}</span>${pips(v)}</div>`).join('')+rig.stats.warn.filter(Boolean).map(w=>`<div class="warn">${tr(w)}</div>`).join('')}
function drawPanel(){let h='';
  if(rig.mode==='build'){h+=`<section><h2>Capacidades</h2><div id="caps"></div></section>`;
    if(rig.sel){const L=LIB[rig.sel.type];h+=`<section><h2>${tr(L.name)}</h2>${(L.leg?L.p:[...L.p,'rot','tilt']).map(k=>`<div class="row"><label for="p-${k}">${PLBL[k][0]}</label><input type="range" id="p-${k}" data-pk="${k}" min="${PLBL[k][1]}" max="${PLBL[k][2]}" step=".01" value="${rig.sel[k]||0}"></div>`).join('')}${L.leg?'':'<p class="note">Arrastra la cuenta verde para girar la pieza.</p>'}${L.leg?'<p class="note">El pie se desliza por el suelo y la rodilla es libre. Sube o baja el cuerpo con las vértebras: las patas se estiran para seguir apoyadas.</p>':''}<div class="chips"><button id="del">Quitar pieza</button></div></section>`}
    else h+=`<section><h2>Pieza</h2><p class="note">Toca una pieza de la criatura para ajustarla. Arrástrala fuera del cuerpo para quitarla.</p></section>`;
    h+=`<section><h2>Criatura</h2><div class="chips">${Object.keys(SEEDS).map(n=>`<button data-seed="${n}">${n}</button>`).join('')}</div><div class="chips"><button id="rand">Al azar</button><button id="copy">Copiar genoma</button></div></section>`}
  if(rig.mode==='paint'){const s=rig.G.skin;h+=`<section><h2>Piel</h2><div class="row"><span>Dibujo</span><div class="seg">${PATS.map((n,i)=>`<button id="pat-${i}" data-pat="${i}" aria-pressed="${s.pat===i}">${n}</button>`).join('')}</div></div>
    <div class="row"><span>Colores</span><div class="colors">${['cA','cB','cC'].map((q,i)=>`<input type="color" id="c-${q}" data-col="${q}" value="${s[q]}" aria-label="${['Color base','Color del dibujo','Color del vientre'][i]}">`).join('')}</div></div>
    <div class="row"><label for="s-scale">Escama</label><input type="range" id="s-scale" data-sk="scale" min="3" max="14" step=".5" value="${s.scale}"></div><div class="row"><label for="s-wet">Brillo</label><input type="range" id="s-wet" data-sk="wet" min="0" max="1" step=".01" value="${s.wet}"></div></section>
    <section><h2>Combinaciones</h2><div class="chips">${PALS.map((p,i)=>`<button data-pal="${i}" aria-label="${tr('Combinaciones')} ${i+1}" style="background:linear-gradient(90deg,${p[0]} 0 50%,${p[1]} 50% 78%,${p[2]} 78%);width:54px;height:26px"></button>`).join('')}</div></section>`}
  if(rig.mode==='test')h+=`<section><h2>Capacidades</h2><div id="caps"></div></section><section><h2>Acciones</h2><div class="chips"><button data-act="bite">Morder</button><button data-act="sing">Cantar</button><button data-act="run" aria-pressed="${rig.run}">${rig.run?'Andar':'Correr'}</button></div><p class="note">La zancada, el reparto de patas y la ondulación del cuerpo salen de las piezas que has puesto.</p></section>`;
  $('panel').innerHTML=h+(rig.mode==='build'?growthPanel():'');drawStats();document.body.dataset.mode=rig.mode;drawHandles();translateUI();syncHistory()}
const PALS=[['#9a3b28','#2a1414','#e6cfa0'],['#2f8a5a','#12382c','#e9e2a8'],['#3d5fa8','#8a4fb0','#f0e6c8'],['#c9892b','#4a2a12','#f3e3b8'],['#6c7440','#2f3320','#d8cfa6'],['#22313f','#d9a441','#c8d2d8'],['#b84a6a','#3a1830','#f2d9c9']];
$('panel').addEventListener('input',e=>{const t=e.target;if(t.dataset.pk&&rig.sel){rig.sel[t.dataset.pk]=+t.value;if(LIB[rig.sel.type].fittedLeg||!['rot','tilt'].includes(t.dataset.pk))buildParts()}if(t.dataset.sk){rig.G.skin[t.dataset.sk]=+t.value;syncSkin()}if(t.dataset.col){rig.G.skin[t.dataset.col]=t.value;syncSkin()}});
$('panel').addEventListener('change',()=>commit());
$('panel').addEventListener('click',e=>{const t=e.target.closest('button');if(!t)return;const d=t.dataset;
  if(t.id==='del'&&rig.sel)removePart(rig.sel);if(t.id==='rand'){loadG(randomCreature());commit()}if(d.seed){loadG(SEEDS[d.seed]);commit()}
  if(t.id==='copy')navigator.clipboard.writeText(JSON.stringify(rig.G)).then(()=>flashOk('Genoma copiado'),()=>flashOk('El navegador no ha permitido copiar'));
  if(d.pat){rig.G.skin.pat=+d.pat;syncSkin();drawPanel();commit()}if(d.pal){const p=PALS[+d.pal];Object.assign(rig.G.skin,{cA:p[0],cB:p[1],cC:p[2]});syncSkin();drawPanel();commit()}
  if(d.act==='bite')rig.biteT=.6;if(d.act==='sing')rig.singT=1.6;if(d.act==='run'){rig.run=!rig.run;drawPanel()}});
function flashOk(t){setHint(t);clearTimeout(flashT);flashT=setTimeout(setHint,2000)}
/* miniaturas 3D de la paleta: se dibujan con el render principal y giran al pasar el cursor */
const TH=112,thRT=new T.WebGLRenderTarget(TH,TH),thScene=new T.Scene(),thCam=new T.PerspectiveCamera(30,1,.05,60),thBuf=new Uint8Array(TH*TH*4),thModels={};
thRT.texture.encoding=T.sRGBEncoding;thScene.environment=scene.environment;thScene.add(new T.HemisphereLight(0xffffff,0x665544,.55));{const d=new T.DirectionalLight(0xfff2e0,1.5);d.position.set(2,4,3);thScene.add(d)}
function thumbModel(k){if(thModels[k])return thModels[k];const L=LIB[k],p=defaults(k),piv=new T.Group(),inner=new T.Group();
  if(L.leg){const[a,b]=legLens(p),m=legMeshes(p,[0,0,0],a,b),K=V(...p.k),F=V(...p.f);m.up.quaternion.setFromUnitVectors(DOWN,K.clone().normalize());m.lo.position.copy(K);m.lo.quaternion.setFromUnitVectors(DOWN,F.clone().sub(K).normalize());m.ft.position.set(F.x,F.y-p.w*.6,F.z);inner.add(m.up,m.lo,m.ft)}
  else{inner.add(L.make(p,[0,1,0]));if(!L.glb&&(L.cat==='Armas'||L.cat==='Adornos'||k==='antena'||k==='tallo'||k==='frill_fan'))inner.rotation.x=-Math.PI/2;else if(L.responsive&&(L.category==='wings'||L.category==='fins'))inner.rotation.x=-.65}
  piv.add(inner);piv.updateMatrixWorld(true);const box=new T.Box3().setFromObject(piv);inner.position.sub(box.getCenter(V()));piv.userData.r=box.getSize(V()).length()/2;piv.visible=false;thScene.add(piv);return thModels[k]=piv}
function renderThumb(k,rot,ctx){const m=thumbModel(k);for(const q in thModels)thModels[q].visible=q===k;m.rotation.y=rot;const d=m.userData.r/Math.sin(.262)*1.08;thCam.position.set(0,d*.32,d);thCam.lookAt(0,0,0);
  renderer.setRenderTarget(thRT);renderer.setClearColor(0x000000,0);renderer.clear();renderer.render(thScene,thCam);renderer.readRenderTargetPixels(thRT,0,0,TH,TH,thBuf);renderer.setRenderTarget(null);renderer.setClearColor(0x000000,1);
  const im=ctx.createImageData(TH,TH);for(let y=0;y<TH;y++)im.data.set(thBuf.subarray((TH-1-y)*TH*4,(TH-y)*TH*4),y*TH*4);ctx.putImageData(im,0,0)}
const cats=partTable.categories;let hoverKey=null,thRot=.6;
$('tabs').innerHTML=cats.map((c,i)=>`<button data-cat="${c}" aria-label="${c}" title="${c}" aria-pressed="${!i}"><canvas width="${TH}" height="${TH}"></canvas></button>`).join('');
$('palette').innerHTML=Object.entries(LIB).map(([k,l])=>`<button data-part="${k}" data-c="${l.category}" aria-label="${l.name}, ${l.cost} ADN"><canvas width="${TH}" height="${TH}"></canvas><span>${l.name}</span><em>${l.cost}</em></button>`).join('');
const tctx=k=>$('palette').querySelector(`[data-part="${k}"] canvas`).getContext('2d');
let activeCat=cats[0];
function showCat(c){activeCat=c;$('catname').textContent=tr(CAT_NAMES[c]);document.querySelectorAll('#tabs button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.cat===c));document.querySelectorAll('#palette button').forEach(b=>b.hidden=b.dataset.c!==c)}
function drawThumbs(){ghost.dataset.t='';for(const k in LIB)if(k!==hoverKey)renderThumb(k,.6,tctx(k));document.querySelectorAll('#tabs button').forEach(b=>{const k=Object.keys(LIB).find(k=>LIB[k].category===b.dataset.cat),x=b.firstChild.getContext('2d');x.clearRect(0,0,TH,TH);x.drawImage($('palette').querySelector(`[data-part="${k}"] canvas`),0,0)})}
$('tabs').addEventListener('click',e=>{const b=e.target.closest('[data-cat]');if(b)showCat(b.dataset.cat)});
$('palette').addEventListener('pointerover',e=>{const t=e.target.closest('[data-part]');if(t&&t.dataset.part!==hoverKey){if(hoverKey)renderThumb(hoverKey,.6,tctx(hoverKey));hoverKey=t.dataset.part;thRot=.6}});
$('palette').addEventListener('pointerleave',()=>{if(hoverKey)renderThumb(hoverKey,.6,tctx(hoverKey));hoverKey=null});
$('palette').addEventListener('click',e=>{const b=e.target.closest('[data-part]');if(b&&e.detail===0&&rig.mode==='build'){pendingPart=b.dataset.part;editTool='sculpt';flashOk('Toca el cuerpo para colocar');gl.focus({preventScroll:true})}});
$('palette').addEventListener('pointerdown',e=>{const t=e.target.closest('[data-part]');if(!t||rig.mode!=='build')return;e.preventDefault();const p=newPart(t.dataset.part);if(p){gestureStart=snapshot();pendingPart=null;editTool='sculpt';drag={k:'part',p,isNew:true,moved:false,over:false,x:e.clientX,y:e.clientY};hoverKey=null;ghostAt(e,true,p.type)}});
$('name').addEventListener('input',e=>{rig.G.name=e.target.value.replace(/[<>\x00-\x1f]/g,'').slice(0,80)});$('name').addEventListener('change',commit);
function setMode(m){rig.mode=m;if(m!=='build')rig.sel=null;rig.theta=0;rig.phase=0;rig.run=false;document.querySelectorAll('#modes button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.mode===m));refresh(false);drawPanel();setHint()}
$('modes').addEventListener('click',e=>{const m=e.target.dataset.mode;if(m)setMode(m)});

let last=0;function loop(t){requestAnimationFrame(loop);const dt=Math.min(.05,(t-last)/1000||0);last=t;update(dt);frameCam(dt);if(hoverKey){thRot+=dt*2.4;renderThumb(hoverKey,thRot,tctx(hoverKey))}renderer.render(scene,camera)}
function selectedRegion(){return rig.G.regions.find(r=>r.id===selectedRegionId)}
function growthPanel(){const r=selectedRegion();return `<section><h2>${tr('Regiones')}</h2><div class="chips">${['sculpt','orbit','growth'].map((v,i)=>`<button data-tool="${v}" aria-pressed="${editTool===v}">${tr(['Esculpir','Girar cámara','Regiones'][i])}</button>`).join('')}</div><div class="chips">${rig.G.regions.map((r,i)=>`<button data-region="${r.id}" aria-pressed="${r.id===selectedRegionId}">${tr(({horns:'Cuernos',plates:'Placas',tendrils:'Filamentos'})[r.family])} ${i+1}</button>`).join('')}</div><div class="chips"><button data-growth-action="add" ${rig.G.regions.length>=64?'disabled':''}>${tr('Añadir región')}</button>${r?`<button data-growth-action="duplicate" ${rig.G.regions.length>=64?'disabled':''}>${tr('Duplicar')}</button><button data-growth-action="delete">${tr('Eliminar')}</button>`:''}</div>${r?`
 <div class="row"><label for="growth-family">${tr('Forma')}</label><select id="growth-family" data-region-key="family">${['horns','plates','tendrils'].map((f,i)=>`<option value="${f}" ${f===r.family?'selected':''}>${tr(['Cuernos','Placas','Filamentos'][i])}</option>`).join('')}</select></div>
 <div class="row"><label for="growth-surface">${tr('Superficie')}</label><select id="growth-surface" data-region-key="surface">${['torso','neck','tail'].map((v,i)=>`<option value="${v}" ${v===r.surface?'selected':''}>${tr(['Torso','Cuello','Cola'][i])}</option>`).join('')}</select></div>
 ${[['position','Posición',0,1,.01],['coverage','Cobertura',0,1,.01],['angle','Ángulo',-3.14,3.14,.01],['length','Largo',.2,2.4,.05],['count','Cantidad',1,18,1],['curve','Curvatura',-1,1,.05],['branches','Ramas',0,3,1]].map(([k,n,a,b,step])=>`<div class="row"><label for="growth-${k}">${tr(n)}</label><input id="growth-${k}" data-region-key="${k}" type="range" min="${a}" max="${b}" step="${step}" value="${r[k]}"></div>`).join('')}
 <label><input type="checkbox" data-region-key="mirror" ${r.mirror?'checked':''}> ${tr('Espejo')}</label><p class="note">${tr('Semilla')}: ${r.seed}</p><div class="chips"><button id="placeGrowth" data-tool="growth" aria-pressed="${editTool==='growth'}">${tr('Colocar en el cuerpo')}</button><button data-growth-action="vary">${tr('Nueva variante')}</button></div>`:''}<p class="note">${tr('Detalles artísticos; no cambian las capacidades.')}</p></section>`}
$('panel').addEventListener('input',e=>{const k=e.target.dataset.regionKey,r=selectedRegion();if(k&&r){r[k]=k==='mirror'?e.target.checked:['family','surface'].includes(k)?e.target.value:+e.target.value;rebuildGrowth()}});
$('panel').addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;
 if(b.dataset.tool){editTool=b.dataset.tool;pendingPart=null;drawPanel();gl.focus({preventScroll:true})}
 if(b.dataset.region){selectedRegionId=b.dataset.region;editTool='growth';rig.sel=null;drawPanel()}
 const action=b.dataset.growthAction;if(!action)return;const r=selectedRegion();
 if(['add','duplicate'].includes(action)&&rig.G.regions.length<64){let n=1;while(rig.G.regions.some(r=>r.id==='region-'+n))n++;const next={...(action==='duplicate'?r:regionDefaults),id:'region-'+n};rig.G.regions.push(next);selectedRegionId=next.id;editTool='growth'}
 if(action==='delete'&&r){rig.G.regions=rig.G.regions.filter(x=>x!==r);selectedRegionId=rig.G.regions[0]?.id||null}
 if(action==='vary'&&r)r.seed=(r.seed+1)>>>0;
 rebuildGrowth();drawPanel();commit();
});
const CAT_NAMES={mouths:'Bocas',senses:'Sentidos',legs:'Patas',arms:'Brazos',weapons:'Armas',wings:'Alas',fins:'Aletas',digging_claws:'Excavar',details:'Detalles'};
function translateUI(){
 document.documentElement.lang=lang;document.title='Primigenia · '+(lang==='en'?'Creature studio':'Estudio de criaturas');
 const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let node;
 while((node=walker.nextNode())){if(['SCRIPT','STYLE','TEXTAREA','OPTION'].includes(node.parentElement.tagName))continue;const raw=node._es||node.textContent.trim();if(EN[raw]||StudioI18n.es[raw]){node._es=raw;node.textContent=tr(raw)}}
 for(const el of document.querySelectorAll('[aria-label],[placeholder],[title]'))for(const attr of ['aria-label','placeholder','title'])if(el.hasAttribute(attr)){const key=attr.replace('-','')+'Es',raw=el.dataset[key]||el.getAttribute(attr);el.dataset[key]=raw;el.setAttribute(attr,tr(raw))}
 for(const b of document.querySelectorAll('[data-part]')){const p=tableById[b.dataset.part];b.querySelector('span').textContent=p.name[lang];b.setAttribute('aria-label',`${p.name[lang]}, ${p.dna_cost} ${tr('ADN')}`);b.title=tr('Cosmético')+(p.illustrative_abilities.length?' · '+p.illustrative_abilities.map(a=>lang==='es'?(ABILITY_ES[a]||a):a).join(', '):'');}
 for(const b of document.querySelectorAll('[data-cat]')){b.setAttribute('aria-label',tr(CAT_NAMES[b.dataset.cat]));b.title=tr(CAT_NAMES[b.dataset.cat])}
 $('catname').textContent=tr(CAT_NAMES[activeCat]);$('lang').textContent=lang==='es'?'EN':'ES';$('lang').setAttribute('aria-label',lang==='es'?'Switch to English':'Cambiar a español');
 $('documents').innerHTML=`<h2>${tr('Guardar y compartir')}</h2><div class="chips"><button data-doc="download">${tr('Descargar JSON')}</button><button data-doc="share">${tr('Enlace')}</button><button data-doc="file">${tr('Importar JSON')}</button></div><label for="json">JSON</label><textarea id="json" spellcheck="false"></textarea><div class="chips"><button data-doc="load">${tr('Cargar JSON')}</button></div><input type="file" id="import-file" accept=".json,application/json" hidden><p class="note">${tr('Vista artística · capacidades ilustrativas · sin validar en C')}</p>`;
 $('json').value=JSON.stringify(rig.G,null,1);
 const text=$('message').textContent;for(const [es,en]of Object.entries(EN)){if(text.startsWith(es+':'))$('message').textContent=tr(es)+text.slice(es.length);if(text.startsWith(en+':'))$('message').textContent=tr(es)+text.slice(en.length)}
 setHint();
}
function report(message){$('message').textContent=message}
function assetBounds(type){const model=glbTemplates[type]||LIB[type]?.make(defaults(type),[0,0,0]);if(!model)throw Error('parts.type');const box=new T.Box3().setFromObject(model);if(!glbTemplates[type])model.traverse(o=>o.geometry?.dispose());return {min:box.min.toArray(),max:box.max.toArray()}}
function shareLink(){const bytes=new TextEncoder().encode(snapshot());let binary='';for(const b of bytes)binary+=String.fromCharCode(b);return location.href.split('#')[0]+'#g='+btoa(binary)}
function bootDocument(){
 try{const hash=location.hash.slice(1);if(hash.startsWith('g=')){const raw=atob(decodeURIComponent(hash.slice(2)));rig.G=StudioDocument.parse(new TextDecoder('utf-8',{fatal:true}).decode(Uint8Array.from(raw,c=>c.charCodeAt(0))),tableById).genome}
 else if(hash.startsWith('preset=')&&SEEDS[decodeURIComponent(hash.slice(7))])rig.G=StudioDocument.clone(SEEDS[decodeURIComponent(hash.slice(7))]);
 else {const saved=localStorage.getItem('cpore.creature.v4');if(saved)rig.G=StudioDocument.parse(saved,tableById).genome}
 }catch(e){report(tr('Genoma no válido')+': '+e.message)}
 if(rig.G.migration)report(rig.G.migration.warnings.map(tr).join(' · '));
 if(assetFailures.length)report(tr('Piezas no disponibles')+': '+assetFailures.join(', '));
}
$('undo').onclick=undo;$('redo').onclick=redo;
$('lang').onclick=()=>{lang=lang==='es'?'en':'es';localStorage.setItem('cpore.lang',lang);drawPanel();if(rig.G.migration)report(rig.G.migration.warnings.map(tr).join(' · '))};
$('documents').addEventListener('click',async e=>{const a=e.target.dataset.doc;if(!a)return;
 try{if(a==='load')importGenome($('json').value);
 if(a==='file')$('import-file').click();
 if(a==='share'){const link=shareLink();$('json').value=link;await navigator.clipboard.writeText(link);report(tr('Enlace copiado'))}
 if(a==='download'){const url=URL.createObjectURL(new Blob([snapshot()],{type:'application/json'})),link=document.createElement('a');link.href=url;link.download='primigenia-creature.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);report(tr('Archivo descargado'))}
 }catch(err){report(tr('Genoma no válido')+': '+err.message)}
});
$('documents').addEventListener('change',async e=>{if(e.target.id==='import-file'&&e.target.files[0])try{importGenome(await e.target.files[0].text())}catch(err){report(tr('Genoma no válido')+': '+err.message)}});
function randomCreature(seed=Math.floor(Math.random()*4294967296)){const rnd=rngFrom(seed),g=StudioDocument.clone(Object.values(SEEDS)[seed%3]);g.name='Creature '+seed;g.nodes.forEach(n=>{n.r=clamp(n.r*(.8+rnd()*.4),.05,1.7);n.y+=rnd()*.15});g.skin.pat=Math.floor(rnd()*4);return g}
window.CreatureStudio={genome:()=>StudioDocument.clone(rig.G),load:importGenome,presets:Object.keys(SEEDS),random:seed=>{loadG(randomCreature(seed));commit()},preset:name=>{loadG(SEEDS[name]);commit()},shareLink,
 parts:partTable,ready:true,undo,redo,assetBounds,defaults:type=>StudioDocument.clone(defaults(type)),
 addPart:(type,attachment={})=>{if(!LIB[type])throw Error('parts.type');const p={...defaults(type),...attachment};const next=StudioDocument.clone(rig.G);next.parts.push(p);StudioDocument.validate(next,tableById);rig.G.parts.push(p);rig.sel=p;buildParts();drawPanel();commit();return rig.G.parts.length-1},
 diagnostics:()=>({assetFailures,loadedGLBs:Object.keys(glbTemplates).length,selectedRegionId,growthBuilds:rig.growthBuilds,geometryCount:renderer.info.memory.geometries,regions:[...regionViews].map(([id,v])=>({id,builds:v.builds})),materialSlots,cosmetic:true}),
 view:(yaw,pitch,dist)=>{if(yaw!=null)camYaw=yaw;if(pitch!=null)camPitch=pitch;if(dist!=null)camDist=dist;rig.sel=null;selRings.forEach(r=>r.visible=false);frameCam(0,true);renderer.render(scene,camera)},
 projectPoint:(t,ang)=>{anchor(pts,t,ang,A1);const p=creature.localToWorld(A1.p.clone()).project(camera),r=gl.getBoundingClientRect();return [r.left+(p.x+1)*r.width/2,r.top+(1-p.y)*r.height/2]},
 attachmentRoots:()=>{
  update(0);creature.updateMatrixWorld(true);const result=[];
  for(const o of rig.objs){anchor(pts,o.p.t,o.sg*o.p.ang,A1);result.push({type:o.p.type,root:o.g.position.toArray(),surface:A1.p.toArray(),error:o.g.position.distanceTo(A1.p)})}
  for(const l of rig.legs){anchor(pts,l.p.t,l.sg*l.p.ang,A1);const root=creature.worldToLocal(l.up.position.clone());result.push({type:l.p.type,root:root.toArray(),surface:A1.p.toArray(),error:root.distanceTo(A1.p)})}
  const pa=body.geometry.attributes.position,ix=body.geometry.index,triangle=new T.Triangle(),closest=V();
  for(const item of result){const root=V(...item.root);let distance=Infinity;
   for(let i=0;i<ix.count;i+=3){triangle.a.fromBufferAttribute(pa,ix.getX(i));triangle.b.fromBufferAttribute(pa,ix.getX(i+1));triangle.c.fromBufferAttribute(pa,ix.getX(i+2));triangle.closestPointToPoint(root,closest);distance=Math.min(distance,root.distanceTo(closest))}
   item.meshDistance=distance;
  }
  return result;
 },setMode,
};

window.Creador={_art:(j,sg)=>{const h=j==='rot'?rotH:handlesG.children.find(c=>c.userData.joint===j&&c.userData.sg===sg);if(!h)return null;const v=h.getWorldPosition(V()).project(camera),r=gl.getBoundingClientRect();return[r.left+(v.x+1)/2*r.width,r.top+(1-v.y)/2*r.height]},_sel:i=>{rig.sel=rig.G.parts[i];drawPanel()},_dbg:(x,y)=>{setRay({clientX:x,clientY:y});const j=hitJoint(),p=hitPart();return{joint:j&&j.userData,part:p&&p.type+p.t.toFixed(2),nj:handlesG.children.filter(c=>c.userData.joint).length,el:document.elementFromPoint(x,y).id||document.elementFromPoint(x,y).tagName}},_suelas:()=>rig.legs.map(l=>+l.ft.position.y.toFixed(3)),_alt:()=>rig.legs.map(l=>+(l.a+l.b).toFixed(2)),get genoma(){return JSON.parse(JSON.stringify(rig.G))},cargar:importGenome,modo:setMode};
bootDocument();resize();showCat(cats[0]);loadG(rig.G);commit();setHint();drawThumbs();update(0);frameCam(0,true);requestAnimationFrame(loop);
})().catch(e=>{document.getElementById('message').textContent='No se pudo abrir el estudio / Could not open studio: '+e.message;console.error(e)});
