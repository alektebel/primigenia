
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

/* ---------- materiales de la criatura ---------- */
const SU={cA:{value:lin('#888888')},cB:{value:lin('#444444')},cC:{value:lin('#cccccc')},uPat:{value:1},uWet:{value:.3},uScale:{value:7}};
const SKIN_GLSL=`uniform vec3 cA,cB,cC;uniform float uPat,uWet,uScale;varying vec4 vSkin;
float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1.,0.,0.)),f.x),mix(h3(i+vec3(0.,1.,0.)),h3(i+vec3(1.,1.,0.)),f.x),f.y),mix(mix(h3(i+vec3(0.,0.,1.)),h3(i+vec3(1.,0.,1.)),f.x),mix(h3(i+vec3(0.,1.,1.)),h3(i+vec3(1.,1.,1.)),f.x),f.y),f.z);}
vec2 wor(vec3 x){vec3 p=floor(x),f=fract(x);float a=8.,b=8.;for(int k=-1;k<=1;k++)for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){vec3 g=vec3(float(i),float(j),float(k));vec3 o=vec3(h3(p+g),h3(p+g+17.3),h3(p+g+41.7));vec3 r=g+o-f;float d=dot(r,r);if(d<a){b=a;a=d;}else if(d<b){b=d;}}return sqrt(vec2(a,b));}
vec3 pN(vec3 sp,vec3 sn,vec2 dH){vec3 sx=dFdx(sp),sy=dFdy(sp),r1=cross(sy,sn),r2=cross(sn,sx);float det=dot(sx,r1);vec3 g=sign(det)*(dH.x*r1+dH.y*r2);return normalize(abs(det)*sn-g);}
`;
function skinMaterial(o){const m=new T.MeshPhysicalMaterial({roughness:.6,metalness:0,clearcoat:.3,clearcoatRoughness:.4,envMapIntensity:.9,...o});m.extensions={derivatives:true};m.customProgramCacheKey=()=>'skin';
  m.onBeforeCompile=s=>{Object.assign(s.uniforms,SU);
    s.vertexShader='attribute vec4 skin;varying vec4 vSkin;\n'+s.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nvSkin=skin;');
    s.fragmentShader=SKIN_GLSL+s.fragmentShader
     .replace('#include <color_fragment>',`vec3 rp=vSkin.xyz;float dd=vSkin.w,nn=n3(rp*1.3)+.5*n3(rp*2.9),mk=0.;
       if(uPat>.5&&uPat<1.5)mk=smoothstep(.42,.62,.5+.5*sin(rp.z*4.6+(nn-.75)*3.2));
       else if(uPat>1.5&&uPat<2.5){vec2 w0=wor(rp*1.5);mk=1.-smoothstep(.2,.33,w0.x);}
       else if(uPat>2.5)mk=smoothstep(.5,.72,nn*.66+dd*.12);
       mk*=smoothstep(-.4,.2,dd);vec3 sk=mix(cA,cB,mk);sk=mix(sk,cC,1.-smoothstep(-.85,-.2,dd));sk*=mix(1.,.72,smoothstep(.7,1.,dd));
       vec2 w1=wor(rp*uScale);float sh=smoothstep(0.,.2,w1.y-w1.x),bp=smoothstep(0.,.45,w1.y-w1.x)*.007+n3(rp*3.)*.015;sk*=mix(.7,1.,sh)*(.9+.2*n3(rp*11.));diffuseColor.rgb=sk;`)
     .replace('#include <roughnessmap_fragment>','#include <roughnessmap_fragment>\nroughnessFactor=clamp(mix(.82,.3,uWet)*mix(1.25,.9,sh),.06,1.);')
     .replace('#include <normal_fragment_maps>','#include <normal_fragment_maps>\nnormal=pN(-vViewPosition,normal,vec2(dFdx(bp),dFdy(bp)));')
     .replace('#include <emissivemap_fragment>','#include <emissivemap_fragment>\ntotalEmissiveRadiance+=sk*pow(1.-clamp(dot(normalize(vViewPosition),normal),0.,1.),3.)*.5;')};
  return m}
const skinM=skinMaterial({}),skinM2=skinMaterial({side:T.DoubleSide});
const phys=(c,r,cc)=>new T.MeshPhysicalMaterial({color:lin(c),roughness:r,clearcoat:cc,clearcoatRoughness:.2,envMapIntensity:1});
const boneM=phys('#bfae8a',.5,.25),toothM=phys('#f7f1df',.28,.5),beakM=phys('#d9952f',.35,.6),eyeW=phys('#f4efe6',.08,1),irisM=phys('#e8a41c',.2,1),pupM=phys('#050505',.05,1),darkM=phys('#1a1210',.5,.2);
irisM.emissive=lin('#6a3a00');

/* ---------- geometría ---------- */
function allocTube(n,rad){const g=new T.BufferGeometry();g.setAttribute('position',new T.BufferAttribute(new Float32Array(n*rad*3),3));g.setAttribute('normal',new T.BufferAttribute(new Float32Array(n*rad*3),3));const idx=[];
  for(let i=0;i<n-1;i++)for(let j=0;j<rad;j++){const a=i*rad+j,b=i*rad+(j+1)%rad,c=a+rad,d=b+rad;idx.push(a,c,b,b,c,d)}g.setIndex(idx);return g}
const _t=V(),_s=V(),_u=V(),_n=V(),X0=V(1,0,0);
function fillTube(g,pts,rad,RN,ref,shape,frames){const pa=g.attributes.position.array,na=g.attributes.normal.array,n=pts.length;
  for(let i=0;i<n;i++){const a=pts[Math.max(i-1,0)],b=pts[Math.min(i+1,n-1)];_t.subVectors(b,a).normalize();if(ref){_s.crossVectors(ref,_t).normalize();_u.crossVectors(_t,_s)}else{_u.crossVectors(_t,X0).normalize();_s.crossVectors(_u,_t)}
    const r=rad[i],p=pts[i],dr=clamp((rad[Math.min(i+1,n-1)]-rad[Math.max(i-1,0)])/(b.distanceTo(a)||1),-4,4);
    if(frames){frames[i].s.copy(_s);frames[i].u.copy(_u);frames[i].t.copy(_t);frames[i].dr=dr}
    for(let j=0;j<RN;j++){const an=j/RN*6.28318,cx=Math.sin(an),cy=Math.cos(an),wy=shape?(cy<0?.9:1.06):1,k=(i*RN+j)*3;
      pa[k]=p.x+(_s.x*cx+_u.x*cy*wy)*r;pa[k+1]=p.y+(_s.y*cx+_u.y*cy*wy)*r;pa[k+2]=p.z+(_s.z*cx+_u.z*cy*wy)*r;
      _n.set(_s.x*cx+_u.x*cy-_t.x*dr,_s.y*cx+_u.y*cy-_t.y*dr,_s.z*cx+_u.z*cy-_t.z*dr).normalize();na[k]=_n.x;na[k+1]=_n.y;na[k+2]=_n.z}}
  g.attributes.position.needsUpdate=g.attributes.normal.needsUpdate=true}
function curveTube(fn,r0,n,rn,ref){const pts=[],rad=[];for(let i=0;i<n;i++){const u=i/(n-1);pts.push(fn(u));rad.push(Math.max(.004,r0*Math.pow(1-u,.85)))}const g=allocTube(n,rn);fillTube(g,pts,rad,rn,ref,false);return g}
const ell=(sx,sy,sz,x=0,y=0,z=0)=>{const g=new T.SphereGeometry(1,22,16);g.scale(sx,sy,sz);g.computeVertexNormals();g.translate(x,y,z);return g};
function skinify(g,off,d){const p=g.attributes.position,n=g.attributes.normal,a=new Float32Array(p.count*4);for(let i=0;i<p.count;i++)a.set([p.getX(i)+off[0],p.getY(i)+off[1],p.getZ(i)+off[2],d==null?n.getY(i)*.9:d],i*4);g.setAttribute('skin',new T.BufferAttribute(a,4));return g}
const mesh=(g,m,par)=>{const o=new T.Mesh(g,m);o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;if(par)par.add(o);return o};

/* ---------- biblioteca de piezas ---------- */
const hornM=boneM,glowM=new T.MeshStandardMaterial({color:lin('#7fe8ff'),emissive:lin('#35c8ff'),emissiveIntensity:2.2,roughness:.3});
const cone=(r,h,z)=>new T.ConeGeometry(r,h,10).rotateX(Math.PI/2).translate(0,0,z);
function mouth(kind,p,off){const g=new T.Group(),hr=.55*p.size,jaw=new T.Group();g.userData.jaw=jaw;g.add(jaw);
  const teeth=(par,zs,xw,y,up)=>{for(const sx of[-1,1])zs.forEach((z,i)=>{const t=mesh(new T.ConeGeometry(hr*.055,hr*(.2+.06*(i%2)),8).translate(0,hr*.1,0),toothM,par);t.position.set(sx*xw*(1-i*.07),y,z);t.rotation.x=up?0:Math.PI;t.rotation.z=sx*(up?-.12:.12)})};
  if(kind==='fauces'){mesh(skinify(ell(hr*.62,hr*.44,hr*1.3,0,hr*.1,hr*.55),off,.3),skinM,g);jaw.position.set(0,-hr*.2,-hr*.3);mesh(skinify(ell(hr*.52,hr*.2,hr*1.15,0,0,hr*.75),off,-.7),skinM,jaw);
    const zs=[.35,.65,.95,1.25,1.5,1.7].map(z=>z*hr);teeth(g,zs,hr*.47,-hr*.12,false);teeth(jaw,zs.map(z=>z+hr*.1),hr*.4,hr*.1,true);
    for(const sx of[-1,1])mesh(ell(hr*.05,hr*.035,hr*.07,sx*hr*.17,hr*.3,hr*1.68),darkM,g)}
  else if(kind==='romo'){mesh(skinify(ell(hr*.8,hr*.52,hr*.8,0,hr*.08,hr*.25),off,.3),skinM,g);jaw.position.set(0,-hr*.22,-hr*.25);mesh(skinify(ell(hr*.7,hr*.24,hr*.75,0,0,hr*.5),off,-.7),skinM,jaw);
    for(const sx of[-1,1])mesh(ell(hr*.07,hr*.045,hr*.05,sx*hr*.24,hr*.3,hr*.98),darkM,g)}
  else{mesh(curveTube(u=>V(0,hr*.05-hr*.6*u*u,hr*(-.2+1.7*u)),hr*.58,12,14,Y).scale(.8,1,1),beakM,g);jaw.position.set(0,-hr*.25,-hr*.2);mesh(curveTube(u=>V(0,hr*.1*u,hr*(1.3*u)),hr*.38,10,12,Y).scale(.85,.6,1),beakM,jaw)}
  return g}
function eye(p,off,stalk){const g=new T.Group(),er=.2*p.size,e=new T.Group();g.add(e);
  if(stalk){const L=p.len;mesh(skinify(curveTube(u=>V(0,L*.35*u*u,L*u),.09*p.size,10,10,X0),off,.3),skinM,g);e.position.set(0,L*.35,L);}
  else e.position.z=er*.3;
  mesh(new T.SphereGeometry(er,20,14),eyeW,e);mesh(ell(er*.64,er*.64,er*.3,0,0,er*.76),irisM,e);mesh(ell(er*.17,er*.5,er*.2,0,0,er*.93),pupM,e);
  const lid=mesh(skinify(new T.SphereGeometry(er*1.13,18,10,0,6.2832,0,1.25),off,.6),skinM,e);lid.rotation.x=-.3;g.userData.lid=lid;return g}
const LIB={
 fauces:{cat:'Bocas',name:'Fauces',cost:25,bite:3,sing:1,p:['size'],make:(p,o)=>mouth('fauces',p,o)},
 romo:{cat:'Bocas',name:'Hocico',cost:15,bite:1,sing:3,p:['size'],make:(p,o)=>mouth('romo',p,o)},
 pico:{cat:'Bocas',name:'Pico',cost:20,bite:2,sing:2,p:['size'],make:(p,o)=>mouth('pico',p,o)},
 ojo:{cat:'Sentidos',name:'Ojo',cost:5,p:['size'],make:(p,o)=>eye(p,o,false)},
 tallo:{cat:'Sentidos',name:'Ojo en tallo',cost:10,sing:1,p:['size','len'],len:.7,make:(p,o)=>eye(p,o,true)},
 antena:{cat:'Sentidos',name:'Antena',cost:10,sing:1,p:['size','len'],len:1.1,make:p=>{const g=new T.Group(),L=p.len,sw=new T.Group();g.add(sw);g.userData.sway=sw;mesh(curveTube(u=>V(0,L*.45*u*u,L*u-.05),.045*p.size,12,8,X0),darkM,sw);const b=mesh(ell(.09*p.size,.09*p.size,.09*p.size),glowM,sw);b.position.set(0,L*.45,L-.05);b.castShadow=false;return g}},
 trompa:{cat:'Bocas',name:'Trompa',cost:15,bite:0,sing:3,p:['size'],make:(p,o)=>{const g=new T.Group(),s=p.size;g.userData.sway=g.userData.jaw=new T.Group();mesh(skinify(curveTube(u=>V(0,-.55*s*u*u,(-.2+1.35*u)*s),.3*s,16,14,X0),o,.3),skinM,g);mesh(ell(.07*s,.07*s,.05*s,0,-.5*s,1.1*s),darkM,g);return g}},
 pinzas:{cat:'Bocas',name:'Pinzas',cost:25,bite:4,sing:0,p:['size'],make:(p,o)=>{const g=new T.Group(),s=p.size;mesh(skinify(ell(.46*s,.3*s,.34*s),o,.3),skinM,g);g.userData.pinch=[-1,1].map(sx=>{const q=new T.Group();q.position.x=sx*.2*s;g.add(q);mesh(curveTube(u=>V(sx*.42*Math.sin(u*2.7)*s,0,(.05+.95*u)*s),.13*s,14,10,Y),darkM,q);q.userData.sx=sx;return q});return g}},
 oreja:{cat:'Sentidos',name:'Oreja',cost:5,sing:1,p:['size'],make:(p,o)=>{const g=new T.Group(),s=p.size,sw=new T.Group();g.add(sw);g.userData.sway=sw;mesh(skinify(ell(.07*s,.3*s,.55*s,0,.08*s,.42*s),o,.35),skinM,sw);mesh(ell(.05*s,.2*s,.4*s,.04*s,.08*s,.42*s),beakM,sw);return g}},
 pata:{cat:'Patas',name:'Pata con garras',cost:25,leg:1,foot:'garra',p:['w'],w:.2,k:[.28,-.72,.12],f:[.38,-1.4,-.02]},
 zanca:{cat:'Patas',name:'Zanca',cost:25,leg:1,foot:'dedos',p:['w'],w:.13,k:[.1,-1.1,-.3],f:[.18,-2.35,.05]},
 pezuna:{cat:'Patas',name:'Pata de pezuña',cost:20,leg:1,foot:'pezuna',p:['w'],w:.3,k:[.08,-.62,.1],f:[.1,-1.2,0]},
 asta:{cat:'Armas',name:'Asta',cost:18,bite:1,p:['size','len'],len:1.2,make:p=>{const g=new T.Group(),L=p.len,r=.11*p.size,m=u=>V(0,-.25*L*u*u,L*u-.06);mesh(curveTube(m,r,14,10,X0),hornM,g);for(const[a,d]of[[.4,.5],[.68,.36]]){const b=m(a);mesh(curveTube(u=>V(0,b.y+d*L*u,b.z+d*L*.35*u*u),r*.7,8,8,X0),hornM,g)}return g}},
 aguijon:{cat:'Armas',name:'Aguijón',cost:18,bite:2,p:['size'],make:p=>{const g=new T.Group(),s=p.size,sw=new T.Group();g.add(sw);g.userData.sway=sw;[[.2,.24],[.5,.2],[.78,.16]].forEach(([u,r])=>mesh(ell(r*s,r*s,r*s*1.15,0,.75*s*u*u,.95*s*u),darkM,sw));const c=mesh(new T.ConeGeometry(.09*s,.5*s,10).translate(0,.25*s,0),beakM,sw);c.position.set(0,.5*s,.82*s);c.rotation.x=.5;return g}},
 cuerno:{cat:'Armas',name:'Cuerno',cost:15,bite:1,p:['size','len','curve'],len:.9,make:p=>{const g=new T.Group(),L=p.len,c=p.curve;mesh(curveTube(u=>V(0,-c*L*.7*u*u,L*u*(1-.2*c*u)-.06),.2*p.size,14,12,X0),hornM,g);return g}},
 pua:{cat:'Armas',name:'Púa',cost:8,hp:.34,p:['size','len'],len:.55,make:p=>{const g=new T.Group();mesh(cone(.16*p.size,p.len,p.len/2-.06),hornM,g);return g}},
 maza:{cat:'Armas',name:'Maza',cost:20,bite:1,hp:1,p:['size'],make:p=>{const g=new T.Group(),s=p.size;mesh(ell(.42*s,.36*s,.44*s,0,0,.3*s),hornM,g);for(let k=0;k<6;k++){const a=k*1.047,c=mesh(new T.ConeGeometry(.1*s,.4*s,8).translate(0,.2*s,0),hornM,g);c.position.set(Math.cos(a)*.34*s,Math.sin(a)*.28*s,.3*s);c.rotation.z=a-Math.PI/2}return g}},
 placa:{cat:'Adornos',name:'Placa',cost:10,hp:.5,p:['size'],make:p=>{const g=new T.Group(),s=p.size,ge=new T.OctahedronGeometry(1,0).scale(.06*s,.34*s,.52*s).translate(0,0,.36*s);ge.computeVertexNormals();mesh(ge,hornM,g);return g}},
 cresta:{cat:'Adornos',name:'Cresta',cost:10,sing:1,p:['size'],make:p=>{const g=new T.Group(),s=p.size,sw=new T.Group();g.add(sw);g.userData.sway=sw;for(let k=-2;k<=2;k++){const f=mesh(new T.ConeGeometry(.075*s,(.95-Math.abs(k)*.12)*s,6).translate(0,(.48-Math.abs(k)*.06)*s,0).scale(.45,1,1),k%2?irisM:beakM,sw);f.rotation.x=Math.PI/2-k*.33}return g}},
 bulbo:{cat:'Adornos',name:'Bulbo luminoso',cost:12,sing:1,p:['size'],make:(p,o)=>{const g=new T.Group(),s=p.size;mesh(skinify(new T.CylinderGeometry(.07*s,.12*s,.3*s,10).rotateX(Math.PI/2).translate(0,0,.12*s),o,.3),skinM,g);const b=mesh(ell(.22*s,.22*s,.24*s,0,0,.42*s),glowM,g);b.castShadow=false;return g}},
 aleta:{cat:'Adornos',name:'Aleta',cost:12,sing:1,p:['size'],make:(p,o)=>{const g=new T.Group(),s=p.size,n=14,pos=[],sk=[],idx=[],sw=new T.Group();g.add(sw);g.userData.sway=sw;
   for(let k=0;k<n;k++){const y=(k/(n-1)*2-1)*.8*s,h=s*1.15*Math.pow(Math.max(0,1-(y/(.8*s))**2),.55)*(1+.08*Math.sin(k*2.4));pos.push(0,y,-.05,0,y-h*.25,h);sk.push(o[0],o[1],o[2]+y,.9,o[0],o[1]+h,o[2]+y,.2);if(k<n-1){const q=k*2;idx.push(q,q+1,q+2,q+2,q+1,q+3)}}
   const ge=new T.BufferGeometry();ge.setAttribute('position',new T.Float32BufferAttribute(pos,3));ge.setAttribute('skin',new T.Float32BufferAttribute(sk,4));ge.setIndex(idx);ge.computeVertexNormals();mesh(ge,skinM2,sw);return g}}};
LIB.excavadora={cat:'Excavar',name:'Garra excavadora',cost:18,p:['size'],make:p=>{const g=new T.Group();mesh(skinify(ell(.26*p.size,.2*p.size,.34*p.size),[0,0,0],.2),skinM,g);for(const x of [-.2,0,.2])mesh(cone(.08*p.size,.8*p.size,.35*p.size).translate(x*p.size,0,0),boneM,g);return g}};
const glbTemplates={};
const membraneM=skinMaterial({side:T.DoubleSide,transparent:true,opacity:.66,depthWrite:false});
const convention=partManifest.coordinate_convention;
if(convention.blender.up!=='+Z'||convention.blender.forward!=='+X'||convention.gltf.up!=='+Y'||convention.gltf.units!=='meters')throw Error('Unsupported part coordinate convention');
const loader=new T.GLTFLoader();
let assetFailures=[];
await Promise.all(partTable.parts.filter(p=>p.source==='glb').map(async entry=>{
 try{
  const gltf=await loader.loadAsync('parts/'+entry.file);gltf.scene.updateMatrixWorld(true);
  const template=new T.Group();
  gltf.scene.traverse(o=>{if(!o.isMesh)return;
    const geo=o.geometry.clone().applyMatrix4(o.matrixWorld).rotateY(-Math.PI/2);
    // The exporter already converts Z-up to Y-up. Keep the anatomical origin.
    if(entry.mount==='radial'&&entry.category!=='mouths'&&entry.id!=='sac_spitter')geo.rotateX(Math.PI/2);
    const name=o.material.name||'',fallback=entry.category==='wings'||entry.category==='fins'?'membrane':entry.category==='weapons'||entry.category==='digging_claws'?'keratin':entry.category==='senses'?'eye':'skin';
    const region=entry.id==='beak_crusher'?'keratin':entry.category==='wings'&&name==='Warm sand underside'?'membrane':partTable.material_regions[name]||fallback;
    const mat=region==='skin'?skinM:region==='membrane'?membraneM:region==='eye'?(name.includes('iris')?irisM:pupM):entry.id.includes('beak')&&!name.includes('Ivory')?beakM:boneM;
    skinify(geo,[0,0,0],null);const m=mesh(geo,mat,template);m.userData.materialRegion=region;
  });
  glbTemplates[entry.id]=template;
 }catch(e){assetFailures.push(entry.id);}
}));
for(const entry of partTable.parts){
 if(entry.source==='glb')LIB[entry.id]={cat:entry.category,name:entry.name.es,cost:entry.dna_cost,p:['size'],glb:true,mount:entry.mount,make:(p,off)=>{
   const g=new T.Group();if(!glbTemplates[entry.id])return g;
   glbTemplates[entry.id].children.forEach(m=>{const c=m.clone();c.geometry=m.geometry.clone();c.geometry.scale(p.size,p.size,p.size);skinify(c.geometry,off,null);g.add(c)});return g}};
 if(LIB[entry.id]){LIB[entry.id].category=entry.category;LIB[entry.id].name=entry.name.es;}
}
function legMeshes(p,o,a,b){const w=p.w,kind=LIB[p.type].foot,up=new T.Group(),lo=new T.Group(),ft=new T.Group();
  mesh(skinify(new T.CylinderGeometry(w*1.5,w*1.02,a,14,4).translate(0,-a/2,0),o,.15),skinM,up);mesh(skinify(ell(w*1.75,a*.42,w*2,0,-a*.24,0),o,.3),skinM,up);
  mesh(skinify(new T.CylinderGeometry(w,w*.6,b,14,4).translate(0,-b/2,0),o,.05),skinM,lo);mesh(skinify(ell(w*1.08,w*1.08,w*1.08),o,.1),skinM,lo);
  if(kind==='pezuna'){mesh(new T.CylinderGeometry(w*.72,w*1.05,w*1.1,14).translate(0,w*.55,w*.12),darkM,ft);mesh(skinify(ell(w*.75,w*.55,w*.75,0,w*1.1,0),o,.05),skinM,ft)}
  else if(kind==='dedos'){mesh(skinify(ell(w*.8,w*.7,w*.8,0,w*.6,0),o,.05),skinM,ft);for(const cx of[-1,0,1,2]){const c=mesh(new T.ConeGeometry(w*.34,w*(cx===2?1.8:3.4),8).rotateX(Math.PI/2).translate(0,0,w*(cx===2?.9:1.7)),beakM,ft);c.position.y=w*.3;c.rotation.y=cx===2?Math.PI:-cx*.6}}
  else{mesh(skinify(ell(w*1.2,w*.62,w*1.8,0,w*.5,w*.75),o,.05),skinM,ft);mesh(skinify(ell(w*.7,w*.7,w*.7,0,w*.6,0),o,.05),skinM,ft);
    for(const cx of[-.75,0,.75]){const c=mesh(new T.ConeGeometry(w*.27,w*.95,8).translate(0,w*.45,0),boneM,ft);c.position.set(cx*w,w*.3,w*(2.25-Math.abs(cx)*.4));c.rotation.set(1.85,0,-cx*.35)}}
  return{up,lo,ft}}
const hyp=v=>Math.hypot(v[0],v[1],v[2]),legLens=p=>[Math.max(.12,hyp(p.k)),Math.max(.12,hyp([p.f[0]-p.k[0],p.f[1]-p.k[1],p.f[2]-p.k[2]]))];
const defaults=type=>{const L=LIB[type];return{type,t:L.category==='mouths'?1: L.category==='fins'&&type.startsWith('tail')?.08:L.leg?.5:.62,ang:L.category==='mouths'?0:L.leg?2.1:L.category==='wings'?1.3:L.category==='arms'?1.4:L.category==='legs'?2.1:0,...(L.leg?{w:L.w,k:[...L.k],f:[...L.f]}:{size:1}),...(L.len?{len:L.len}:{}),...(type==='cuerno'?{curve:.5}:{})}};
const PLBL={rot:['Giro',-3.14,3.14],tilt:['Inclinación',-1.3,1.3],size:['Tamaño',.5,2.2],len:['Largo',.3,3.2],curve:['Curva',0,1.3],w:['Grosor',.1,.45]},BUDGET=320;

/* ---------- genoma ---------- */
const SEEDS={
 Merodeador:{name:'Merodeador',nodes:[{y:1.6,z:-3.3,r:.06},{y:1.7,z:-2.4,r:.2},{y:1.85,z:-1.5,r:.4},{y:2.0,z:-.6,r:.7},{y:2.05,z:.4,r:.78},{y:2.15,z:1.3,r:.62},{y:2.5,z:2,r:.46},{y:2.75,z:2.7,r:.56}],
  parts:[{type:'fauces',t:1,ang:0,size:1.15},{type:'ojo',t:.9,ang:.95,size:1},{type:'cuerno',t:.87,ang:.4,size:1,len:.9,curve:.6},{type:'pata',t:.44,ang:2.1,w:.23,k:[.3,-.55,.4],f:[.4,-1.35,-.05]},{type:'pata',t:.7,ang:2.1,w:.2,k:[.25,-.7,-.3],f:[.35,-1.45,.05]},{type:'pua',t:.5,ang:0,size:1,len:.5},{type:'pua',t:.58,ang:0,size:1,len:.6},{type:'pua',t:.66,ang:0,size:1,len:.5}],
  skin:{pat:1,cA:'#9a3b28',cB:'#2a1414',cC:'#e6cfa0',wet:.3,scale:7}},
 Zancuda:{name:'Zancuda',nodes:[{y:2.8,z:-1.9,r:.08},{y:2.9,z:-1.1,r:.35},{y:2.9,z:-.2,r:.72},{y:3.0,z:.6,r:.6},{y:3.6,z:1.1,r:.3},{y:4.4,z:1.25,r:.24},{y:5.1,z:1.5,r:.26},{y:5.35,z:2,r:.36}],
  parts:[{type:'pico',t:1,ang:0,size:1},{type:'ojo',t:.92,ang:1.1,size:1.25},{type:'zanca',t:.4,ang:2.2,w:.14,k:[.1,-1.05,.45],f:[.18,-2.2,.05]},{type:'aleta',t:.42,ang:0,size:1.3},{type:'antena',t:.9,ang:.35,size:1,len:.9},{type:'cresta',t:.93,ang:0,size:.9}],
  skin:{pat:3,cA:'#3d5fa8',cB:'#8a4fb0',cC:'#f0e6c8',wet:.45,scale:9}},
 Babosa:{name:'Babosa',nodes:[{y:.5,z:-2,r:.15},{y:.6,z:-1.1,r:.5},{y:.7,z:-.1,r:.72},{y:.8,z:.9,r:.66},{y:1.2,z:1.6,r:.5},{y:1.5,z:2.1,r:.5}],
  parts:[{type:'romo',t:1,ang:0,size:1.2},{type:'tallo',t:.88,ang:.5,size:1.2,len:.8},{type:'maza',t:0,ang:0,size:.9},{type:'placa',t:.4,ang:0,size:1},{type:'placa',t:.55,ang:0,size:1.1}],
  skin:{pat:2,cA:'#5d8a3a',cB:'#203818',cC:'#e9e2a8',wet:.7,scale:11}}};
Object.values(SEEDS).forEach(g=>Object.assign(g,{schema:'cpore.creature/4',regions:[]}));
let G=JSON.parse(JSON.stringify(SEEDS.Merodeador)),mode='build',sel=null,hist=[],fut=[];
/* ---------- criatura ---------- */
const NSP=60,NC=6,NS=NSP+2*NC,RN=22,Y=V(0,1,0);
const pts=[...Array(NS)].map(()=>V()),rest=[...Array(NS)].map(()=>V()),frames=[...Array(NS)].map(()=>({s:V(),u:V(),t:V(),dr:0})),RAD=new Float32Array(NS);
const creature=new T.Group(),partsG=new T.Group(),handlesG=new T.Group(),limbs=new T.Group();scene.add(creature,limbs);creature.add(partsG,handlesG);
const body=mesh(allocTube(NS,RN),skinM,creature);body.geometry.setAttribute('skin',new T.BufferAttribute(new Float32Array(NS*RN*4),4));
let objs=[],legs=[],off=0,theta=0,phase=0,clock=0,speed=0,stride=1,biteT=0,singT=0,run=false,stats={};
const ringM=new T.MeshBasicMaterial({color:0xffc04a,depthTest:false,transparent:true,opacity:.95}),selRings=[0,1].map(()=>{const m=new T.Mesh(new T.TorusGeometry(1,.035,8,40),ringM);m.renderOrder=20;m.visible=false;creature.add(m);return m});
function sampleSpine(){const c=new T.CatmullRomCurve3(G.nodes.map(n=>V(n.r,n.y,n.z)),false,'catmullrom',.5);
  for(let i=0;i<NSP;i++){const p=c.getPoint(i/(NSP-1));RAD[NC+i]=Math.max(.03,p.x);rest[NC+i].set(0,p.y,p.z)}
  for(const[a,d]of[[NC,-1],[NC+NSP-1,1]]){const out=rest[a].clone().sub(rest[a-d]).normalize(),r0=RAD[a];for(let k=1;k<=NC;k++){const ph=k/NC*Math.PI/2;rest[a+d*k].copy(rest[a]).addScaledVector(out,r0*Math.sin(ph));RAD[a+d*k]=Math.max(.004,r0*Math.cos(ph))}}}
const A1={p:V(),n:V(),t:V(),u:V()},A2={p:V(),n:V(),t:V(),u:V()};
function anchor(arr,t,ang,o){const f=clamp(t,0,1)*(NS-1),i=Math.min(f|0,NS-2),k=f-i,fr=frames[Math.round(f)],r=lerp(RAD[i],RAD[i+1],k),sa=Math.sin(ang),ca=Math.cos(ang),wy=ca<0?.9:1.06;
  o.p.lerpVectors(arr[i],arr[i+1],k).addScaledVector(fr.s,sa*r).addScaledVector(fr.u,ca*wy*r);
  o.n.copy(fr.s).multiplyScalar(sa).addScaledVector(fr.u,ca).addScaledVector(fr.t,-fr.dr).normalize();o.t.copy(fr.t);o.u.copy(fr.u);return o}
function clear(g){for(const c of[...g.children]){g.remove(c);c.traverse(o=>{if(o.geometry)o.geometry.dispose()})}}
const centered=p=>!LIB[p.type].leg&&Math.abs(Math.sin(p.ang))<.14;
function buildParts(freeze){clear(partsG);clear(limbs);objs=[];legs=[];
  /* con patas, la altura del cuerpo es la que marca la columna y cada pata se estira hasta el suelo; sin patas, el cuerpo se posa */
  if(!freeze){let bottom=1e9;for(let i=0;i<NS;i++)bottom=Math.min(bottom,rest[i].y-RAD[i]);off=G.parts.some(p=>LIB[p.type].leg)?Math.max(0,.03-bottom):.03-bottom}
  for(const p of G.parts){const L=LIB[p.type];
    for(const sg of centered(p)?[1]:[1,-1]){anchor(rest,p.t,sg*p.ang,A1);const o=[A1.p.x,A1.p.y,A1.p.z];
      if(L.leg){const pose={...p,k:[...p.k],f:[...p.f]};pose.f[1]=-(A1.p.y+off)+p.w*.6;pose.k[1]=Math.max(pose.k[1],pose.f[1]+.12);const[a,b]=legLens(pose),m=legMeshes(pose,o,a,b);limbs.add(m.up,m.lo,m.ft);for(const q of[m.up,m.lo,m.ft])q.traverse(x=>x.userData.part=p);
        legs.push({p,pose,sg,...m,a,b,w:p.w,home:V(),foot:V(),from:V(),sw:false,grp:0,front:false})}
      else{const g=L.make(p,o);if(!L.glb&&L.category==='mouths'){const inner=new T.Group();inner.position.z=-.3*p.size;inner.add(...g.children.slice());g.add(inner)}g.traverse(x=>x.userData.part=p);partsG.add(g);objs.push({p,sg,g})}}}
  layout(freeze)}
function layout(freeze){/* altura del cuerpo, postura de reposo de cada pata y reparto de la zancada */
  let bottom=1e9,low=1e9;for(let i=0;i<NS;i++)bottom=Math.min(bottom,rest[i].y-RAD[i]);
  for(const l of legs){anchor(rest,l.p.t,l.sg*l.p.ang,A1);l.h0=A1.p.clone();l.rk=V(l.pose.k[0]*l.sg,l.pose.k[1],l.pose.k[2]);l.rf=V(l.pose.f[0]*l.sg,l.pose.f[1],l.pose.f[2]);l.sole=A1.p.y+l.rf.y-l.w*.6;low=Math.min(low,l.sole);
    const fd=l.rf.clone().normalize();l.pole=l.rk.clone().addScaledVector(fd,-l.rk.dot(fd));if(l.pole.length()<.03)l.pole.set(0,0,1);l.pole.normalize();l.home.set(A1.p.x+l.rf.x,0,A1.p.z+l.rf.z)}
  let st=1e9;for(const l of legs){l.hang=Math.max(0,l.sole+off);const L=l.a+l.b,hh=l.h0.y+off-l.w*.6-l.hang,mh=Math.sqrt(Math.max(L*L-hh*hh,0));if(l.hang<.08)st=Math.min(st,1.25*L,2.9*mh)}
  stride=st<1e8?Math.max(.25,st):1;
  const ts=[...new Set(legs.map(l=>l.p.t))].sort((a,b)=>a-b);for(const l of legs){const k=ts.indexOf(l.p.t);l.grp=(k+(l.sg>0?0:1))%2;l.front=ts.length>1&&k>=ts.length/2}
  placeBody();for(const l of legs){poseAt(theta,l.home,l.foot);l.foot.y=l.hang}computeStats()}
let spineG=null,spineOn=false,spineA=0;
const vertM=new T.MeshStandardMaterial({color:lin('#eadfc2'),emissive:lin('#4a3c24'),roughness:.5,depthTest:false,transparent:true,opacity:0}),cordM=new T.MeshBasicMaterial({color:0xffc04a,depthTest:false,transparent:true,opacity:0});
function drawHandles(){clear(handlesG);spineG=null;if(mode!=='build')return;
  /* columna: una vértebra por nodo, orientada según la curva y con el tamaño del cuerpo en ese punto */
  spineG=new T.Group();spineG.visible=spineA>.02;handlesG.add(spineG);const N=G.nodes,vm=(geo,par,i)=>{const m=new T.Mesh(geo,vertM);m.renderOrder=15;m.userData.node=i;par.add(m);return m};
  N.forEach((n,i)=>{const a=N[Math.max(i-1,0)],b=N[Math.min(i+1,N.length-1)],t=V(0,b.y-a.y,b.z-a.z).normalize(),r=.06+n.r*.24,g=new T.Group();g.userData.node=i;g.position.set(0,n.y,n.z);g.quaternion.setFromUnitVectors(Y,t);
    vm(new T.CylinderGeometry(r,r,.13,20),g,i);vm(new T.CylinderGeometry(r*1.12,r*1.12,.025,20).translate(0,.065,0),g,i);vm(new T.CylinderGeometry(r*1.12,r*1.12,.025,20).translate(0,-.065,0),g,i);
    vm(new T.ConeGeometry(.04+r*.14,.1+r*.75,8).rotateX(-Math.PI/2).translate(0,0,-(r+.05+r*.37)),g,i);
    for(const sx of[-1,1])vm(new T.ConeGeometry(.03+r*.1,.06+r*.5,8).rotateZ(-sx*Math.PI/2).translate(sx*(r+.03+r*.25),0,0),g,i);
    spineG.add(g);
    if(i){const q=N[i-1],d=Math.hypot(n.y-q.y,n.z-q.z),c=new T.Mesh(new T.CylinderGeometry(.028,.028,d,8),cordM);c.position.set(0,(n.y+q.y)/2,(n.z+q.z)/2);c.quaternion.setFromUnitVectors(Y,V(0,n.y-q.y,n.z-q.z).normalize());c.renderOrder=14;spineG.add(c)}});
  if(sel&&LIB[sel.type].leg){const jm=new T.MeshBasicMaterial({color:0x6fd3ff,depthTest:false,transparent:true,opacity:.95});
    for(const l of legs)if(l.p===sel){const K=l.h0.clone().add(l.rk),F=l.h0.clone().add(l.rf);
      for(const[j,P]of[['k',K],['f',F]]){const h=new T.Mesh(new T.SphereGeometry(.13,14,10),jm);h.position.copy(P);h.renderOrder=17;h.userData={joint:j,sg:l.sg};handlesG.add(h)}
      const jl=new T.Line(new T.BufferGeometry().setFromPoints([l.h0,K,F]),new T.LineBasicMaterial({color:0x6fd3ff,depthTest:false,transparent:true,opacity:.75}));jl.renderOrder=16;handlesG.add(jl)}}}
function refresh(full){sampleSpine();fillTube(body.geometry,rest,RAD,RN,null,true,frames);
  const pa=body.geometry.attributes.position.array,sk=body.geometry.attributes.skin;for(let i=0;i<NS;i++)for(let j=0;j<RN;j++){const k=i*RN+j;sk.array.set([pa[k*3],pa[k*3+1],pa[k*3+2],Math.cos(j/RN*6.28318)],k*4)}sk.needsUpdate=true;
  buildParts();rebuildGrowth();drawHandles()}
function computeStats(){const P=G.parts,has=t=>P.filter(p=>p.type===t).length,m=P.filter(p=>LIB[p.type].category==='mouths'),lg=P.filter(p=>LIB[p.type].leg);
  let vol=0;for(let i=NC;i<NC+NSP-1;i++)vol+=RAD[i]*RAD[i]*rest[i].distanceTo(rest[i+1])*3.14;
  const avg=legs.length?legs.reduce((a,l)=>a+l.a+l.b,0)/legs.length*.95:0,sum=k=>P.reduce((a,p)=>a+(LIB[p.type].category==='mouths'?0:LIB[p.type][k]||0),0);
  stats={dna:P.reduce((a,p)=>a+LIB[p.type].cost,0)+Math.max(0,G.nodes.length-6)*5,
    vel:lg.length?clamp(Math.round(1.4+avg*.95+(lg.length===1?.5:0)-Math.max(0,vol-7)*.12),1,5):1,
    bite:clamp(Math.round(Math.max(0,...m.map(p=>LIB[p.type].bite||0))+sum('bite')),0,5),sing:clamp(Math.round(Math.max(0,...m.map(p=>LIB[p.type].sing||0))+sum('sing')),0,5),
    hp:clamp(Math.round(1+vol*.3+sum('hp')),1,5),warn:[!m.length&&'Sin boca no puede comer ni cantar',!has('ojo')&&!has('tallo')&&'Sin ojos va a ciegas',!lg.length&&'Sin patas se arrastra']};
  speed=lg.length?1+stats.vel*.55:.7;drawStats()}
const ZA=V(0,0,1),rotH=new T.Mesh(new T.SphereGeometry(.1,14,10),new T.MeshBasicMaterial({color:0x9fd45c,depthTest:false,transparent:true}));rotH.renderOrder=22;rotH.visible=false;creature.add(rotH);
const _m=new T.Matrix4(),_q=new T.Quaternion(),_a=V(),_b=V(),_c=V(),_d=V(),_e=V(),DOWN=V(0,-1,0);
function placeBody(bob){creature.position.set(CX+RC*Math.cos(theta),off+(bob||0),RC*Math.sin(theta));creature.rotation.y=-theta;creature.updateMatrixWorld(true)}
const poseAt=(th,loc,o)=>o.set(loc.x,0,loc.z).applyAxisAngle(Y,-th).add(_e.set(CX+RC*Math.cos(th),0,RC*Math.sin(th)));
const selAx={x:V(),y:V(),p:V(),n:V()};
function orient(g,A,sink,rot,tilt,keep){_b.copy(A.u).addScaledVector(A.n,-A.n.dot(A.u)).addScaledVector(A.t,A.n.dot(A.u));_b.addScaledVector(A.n,-_b.dot(A.n));if(_b.lengthSq()<1e-4)_b.copy(A.t);_b.normalize();_a.crossVectors(_b,A.n);if(keep){selAx.x.copy(_a);selAx.y.copy(_b);selAx.p.copy(A.p);selAx.n.copy(A.n)}_m.makeBasis(_a,_b,A.n);g.quaternion.setFromRotationMatrix(_m);if(rot)g.quaternion.multiply(_q.setFromAxisAngle(ZA,rot));if(tilt)g.quaternion.multiply(_q.setFromAxisAngle(X0,tilt));g.position.copy(A.p).addScaledVector(A.n,-sink)}
function update(dt){
  clock+=dt;grassU.uTime.value=clock;const test=mode==='test',sp=test?speed*(run?1.8:1):0,freq=sp/stride,SW=.38;
  if(test){theta+=sp*dt/RC;phase+=freq*dt;biteT=Math.max(0,biteT-dt);singT=Math.max(0,singT-dt)}
  const w=phase*6.28318,len=rest[NS-1].distanceTo(rest[0]),amp=len*(legs.length?.03:.075),bob=test?Math.sin(w*2)*.03*stride+(singT>0?Math.abs(Math.sin(clock*9))*.18:0):0;
  for(let i=0;i<NS;i++){pts[i].copy(rest[i]);if(test){const q=1-i/(NS-1),k=Math.pow(q,1.4);pts[i].x+=Math.sin(w-3.2*q)*amp*(legs.length?k:1)+Math.sin(clock*1.3-2*q)*amp*.5*k}}
  fillTube(body.geometry,pts,RAD,RN,null,true,frames);placeBody(bob);
  const jawA=.06+.04*Math.sin(clock*2.1)+(biteT>0?Math.sin(Math.PI*biteT/.6)*.75:0)+(singT>0?.3+.25*Math.sin(clock*14):0),bl=Math.max(0,Math.sin(clock*1.6))**60;
  for(const o of objs){anchor(pts,o.p.t,o.sg*o.p.ang,A1);orient(o.g,A1,.015,(o.p.rot||0)*o.sg,o.p.tilt||0,o.p===sel&&o.sg===1);if(LIB[o.p.type].mount==='body'){_m.makeBasis(frames[Math.round(o.p.t*(NS-1))].s,A1.u,A1.t);o.g.quaternion.setFromRotationMatrix(_m);if(o.p.rot)o.g.quaternion.multiply(_q.setFromAxisAngle(ZA,o.p.rot*o.sg));if(o.p.tilt)o.g.quaternion.multiply(_q.setFromAxisAngle(X0,o.p.tilt));o.g.scale.x=o.sg;}const ud=o.g.userData;
    if(ud.jaw)ud.jaw.rotation.x=jawA;if(ud.pinch)for(const q of ud.pinch)q.rotation.y=q.userData.sx*(.25-jawA*1.1);if(ud.lid)ud.lid.rotation.x=-.3+bl*1.5;if(ud.sway)ud.sway.rotation.x=Math.sin(clock*2.2+o.p.t*9)*.12}
  const fwd=_c.set(-Math.sin(theta),0,Math.cos(theta));
  for(const l of legs){const ph=((phase+l.grp*.5)%1+1)%1,H=anchor(pts,l.p.t,l.sg*l.p.ang,A2).p.clone(),K=_u,A=_b;
    if(!test){K.copy(H).add(l.rk).applyMatrix4(creature.matrixWorld);A.copy(H).add(l.rf).applyMatrix4(creature.matrixWorld);H.applyMatrix4(creature.matrixWorld);l.sw=false}
    else{if(ph<SW){if(!l.sw){l.sw=true;l.from.copy(l.foot)}poseAt(theta+sp*((SW-ph)/freq+(1-SW)/freq*.5)/RC,l.home,_a);_a.y=l.hang;const q=ph/SW;l.foot.lerpVectors(l.from,_a,q*q*(3-2*q));l.foot.y=l.hang+Math.sin(Math.PI*q)*.2*(l.a+l.b)}
      else{l.sw=false;l.foot.y=l.hang}
      H.applyMatrix4(creature.matrixWorld);A.copy(l.foot);A.y+=l.w*.6;const dv=_d.subVectors(A,H);let d=dv.length();dv.normalize();d=clamp(d,.08,l.a+l.b-.01);const x=(l.a*l.a-l.b*l.b+d*d)/(2*d),h=Math.sqrt(Math.max(l.a*l.a-x*x,0));
      const pole=_n.copy(l.pole).applyAxisAngle(Y,-theta);pole.addScaledVector(dv,-pole.dot(dv));if(pole.lengthSq()<1e-4)pole.copy(fwd);pole.normalize();K.copy(H).addScaledVector(dv,x).addScaledVector(pole,h);A.copy(H).addScaledVector(dv,d)}
    l.up.position.copy(H);l.up.quaternion.setFromUnitVectors(DOWN,_t.subVectors(K,H).normalize());l.lo.position.copy(K);l.lo.quaternion.setFromUnitVectors(DOWN,_t.subVectors(A,K).normalize());
    l.ft.position.set(A.x,A.y-l.w*.6,A.z);l.ft.rotation.set(l.sw?-.5*Math.sin(Math.PI*clamp(ph/SW,0,1)):0,-theta+l.sg*.18,0,'YXZ')}
  spineA=lerp(spineA,mode==='build'&&(spineOn||(drag&&drag.k==='node'))?1:0,1-Math.pow(.0004,dt));vertM.opacity=spineA*.96;cordM.opacity=spineA*.85;if(spineG)spineG.visible=spineA>.02;
  positionGrowth();
  const show=mode==='build'&&sel;selRings.forEach((r,i)=>{const sg=i?-1:1;r.visible=!!show&&(i===0||!centered(sel));if(!r.visible)return;anchor(pts,sel.t,sg*sel.ang,A1);r.position.copy(A1.p).addScaledVector(A1.n,.03);r.quaternion.setFromUnitVectors(V(0,0,1),A1.n);r.scale.setScalar(LIB[sel.type].leg?sel.w*2.4:.32*(sel.size||1))});
  rotH.visible=!!show&&!LIB[sel.type].leg;if(rotH.visible){const rr=.32*(sel.size||1),a=sel.rot||0;rotH.position.copy(selAx.p).addScaledVector(selAx.x,-Math.sin(a)*rr).addScaledVector(selAx.y,Math.cos(a)*rr).addScaledVector(selAx.n,.03)}
}

/* ---------- cámara ---------- */
let camYaw=2.2,camPitch=.14,camDist=13;const tgt=V(0,1.5,0),want=V();
function frameCam(dt,snap){want.copy(pts[NS>>1]).applyMatrix4(creature.matrixWorld);if(snap)tgt.copy(want);else tgt.lerp(want,1-Math.pow(.01,dt));
  const a=camYaw-theta,cp=Math.cos(camPitch),distance=camDist*Math.max(1,.9/camera.aspect);camera.position.set(tgt.x+Math.sin(a)*cp*distance,Math.max(.3,tgt.y+Math.sin(camPitch)*distance),tgt.z+Math.cos(a)*cp*distance);camera.lookAt(tgt);sky.position.copy(camera.position)}
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
function hitNode(){if(!spineG)return -1;const h=ray.intersectObjects(spineG.children.filter(c=>c.userData.node!=null),true)[0];return h?h.object.userData.node:-1}
const overBody=()=>{body.geometry.computeBoundingSphere();return ray.intersectObject(body).length>0};
function hitPart(){const h=ray.intersectObjects([partsG,limbs],true)[0];return h?h.object.userData.part:null}
function place(p,h){const was=centered(p);let a=Math.abs(h.ang);if(LIB[p.type].leg){if(Math.abs(Math.sin(a))<.2)a=a<1.57?.2:Math.PI-.2}else if(Math.abs(Math.sin(a))<.14)a=Math.cos(a)>0?0:Math.PI;p.t=clamp(h.t,0,1);p.ang=a;if(was!==centered(p))buildParts();else if(LIB[p.type].leg)buildParts(true)}
function snapshot(){return JSON.stringify(G)}
function save(){try{localStorage.setItem('cpore.creature.v4',snapshot())}catch(e){}if($('json')&&document.activeElement!==$('json'))$('json').value=JSON.stringify(G,null,1);syncHistory()}
function syncHistory(){$('undo').disabled=hist.length<2;$('redo').disabled=!fut.length}
function commit(){const next=snapshot();if(hist.at(-1)===next)return;hist.push(next);if(hist.length>100)hist.shift();fut=[];save()}
function loadG(g,keep){G=JSON.parse(typeof g==='string'?g:JSON.stringify(g));$('name').value=G.name||'';sel=null;selectedRegionId=G.regions.some(r=>r.id===selectedRegionId)?selectedRegionId:G.regions[0]?.id||null;theta=0;phase=0;refresh(true);syncSkin();drawPanel();if(!keep){const len=rest[NS-1].distanceTo(rest[0]);camDist=5+len*1.15}}
function undo(){if(hist.length<2)return;fut.push(hist.pop());loadG(hist.at(-1),true);save()}
function redo(){if(!fut.length)return;const next=fut.pop();hist.push(next);loadG(next,true);save()}
function importGenome(input){const result=StudioDocument.parse(input,tableById);loadG(result.genome,true);commit();report(result.warnings.length?result.warnings.map(w=>tr(w)).join(' · '):tr('Diseño cargado'));return result}
function removePart(p){G.parts=G.parts.filter(q=>q!==p);if(sel===p)sel=null;buildParts();drawPanel();commit()}
function newPart(type){return defaults(type)}
function moveNode(i,y,z){const N=G.nodes,n=N[i];_a.set(0,y,z);for(const j of[i-1,i+1]){if(j<0||j>=N.length)continue;_b.set(0,N[j].y,N[j].z);const d=_a.distanceTo(_b);if(d<.3||d>1.95)_a.sub(_b).setLength(clamp(d,.3,1.95)).add(_b)}n.y=clamp(_a.y,n.r+.1,20);n.z=clamp(_a.z,-30,30);
  const end=i===0||i===N.length-1;if(end){const j=i===0?1:N.length-2,m=N[j],d=Math.hypot(n.y-m.y,n.z-m.z);
    if(d>1.5&&N.length<14){N.splice(i===0?1:N.length-1,0,{y:(n.y+m.y)/2,z:(n.z+m.z)/2,r:(n.r+m.r)/2});if(i!==0)drag.node=N.length-1}
    else if(d<.34&&N.length>4){const k=i===0?2:N.length-3,q=N[k];if(Math.hypot(n.y-q.y,n.z-q.z)<1.45){N.splice(j,1);if(i!==0)drag.node=N.length-1}}}
  refresh(false)}
let gestureStart=null;
gl.addEventListener('pointerdown',e=>{
 gestureStart=snapshot();
 if(mode!=='build')return;
 setRay(e);
 if(editTool==='orbit'){gl.setPointerCapture(e.pointerId);drag={k:'cam',x:e.clientX,y:e.clientY,moved:false};e.stopImmediatePropagation();return}
 const rh=ray.intersectObjects(growthG.children,true)[0];
 if(rh&&editTool!=='growth'){selectedRegionId=rh.object.userData.region;editTool='growth';sel=null;drawPanel();e.stopImmediatePropagation();return}
 if(editTool==='growth'&&selectedRegion()){drag={k:'growth'};gl.setPointerCapture(e.pointerId);moveGrowth(e);e.stopImmediatePropagation();return}
 if(pendingPart){const h=hitBody();if(h){const p=newPart(pendingPart);G.parts.push(p);place(p,h);sel=p;pendingPart=null;buildParts();drawPanel();commit()}e.stopImmediatePropagation();return}
},true);
function moveGrowth(e){if(!setRay(e))return;const h=hitBody(),r=selectedRegion();if(!h||!r)return;const [a,b]=regionRange(r.surface);r.position=clamp((h.t-a)/(b-a),0,1);r.angle=Math.abs(h.ang);r.coverage=Math.min(r.coverage,.3);positionGrowth()}
addEventListener('pointermove',e=>{if(drag?.k==='growth'){moveGrowth(e);e.stopImmediatePropagation()}},true);
addEventListener('pointerup',e=>{if(drag?.k==='growth'){drag=null;drawPanel();commit();e.stopImmediatePropagation()}},true);
addEventListener('pointercancel',()=>{if(gestureStart){drag=null;loadG(gestureStart,true);ghost.style.display='none'}});
gl.addEventListener('pointerdown',e=>{setRay(e);gl.setPointerCapture(e.pointerId);if(mode==='build')spineOn=hitNode()>=0||overBody();
  if(mode==='build'){if(rotH.visible&&ray.intersectObject(rotH)[0]){drag={k:'rot',p:sel};return}
    const jt=hitJoint();if(jt){drag={k:'joint',j:jt.userData.joint,sg:jt.userData.sg,p:sel,plane:new T.Plane().setFromNormalAndCoplanarPoint(camera.getWorldDirection(V()),jt.getWorldPosition(V()))};return}
    const n=hitNode();if(n>=0){drag={k:'node',node:n};return}const p=hitPart();if(p){sel=p;drawPanel();drag={k:'part',p,x:e.clientX,y:e.clientY,moved:false,over:true};return}}
  drag={k:'cam',x:e.clientX,y:e.clientY,moved:false};gl.style.cursor='grabbing'});
addEventListener('pointermove',e=>{const inside=setRay(e);
  if(!drag){if(mode==='build'){const n=hitNode();spineOn=e.target===gl&&(n>=0||overBody());if(n!==hoverNode){hoverNode=n;if(spineG)spineG.children.forEach(h=>{if(h.userData.node!=null)h.scale.setScalar(h.userData.node===n?1.3:1)})}gl.style.cursor=n>=0||hitJoint()||(rotH.visible&&ray.intersectObject(rotH)[0])?'move':hitPart()?'pointer':'grab'}return}
  if(drag.k==='cam'){camYaw-=(e.clientX-drag.x)*.006;camPitch=clamp(camPitch+(e.clientY-drag.y)*.004,-.02,1.2);if(Math.abs(e.movementX)+Math.abs(e.movementY)>1)drag.moved=true;drag.x=e.clientX;drag.y=e.clientY}
  else if(drag.k==='rot'){const pl=new T.Plane().setFromNormalAndCoplanarPoint(selAx.n,_e.copy(selAx.p).add(creature.position)),w=ray.ray.intersectPlane(pl,_a);if(w){w.sub(creature.position).sub(selAx.p);drag.p.rot=Math.atan2(-w.dot(selAx.x),w.dot(selAx.y));const el=$('p-rot');if(el)el.value=drag.p.rot;setHint('Gira la pieza alrededor de su base')}}
  else if(drag.k==='joint'){const l=legs.find(l=>l.p===drag.p&&l.sg===drag.sg);let wp=null;
    if(drag.j==='f'){const o=ray.ray.origin,d=ray.ray.direction,q=(l.w*.6-o.y)/d.y;if(d.y<-1e-3&&q>0)wp=_a.copy(o).addScaledVector(d,q)}else wp=ray.ray.intersectPlane(drag.plane,_a);
    if(wp&&l){const r=wp.sub(creature.position).sub(l.h0),v=[r.x*drag.sg,r.y,r.z];
      if(drag.j==='k'){if(hyp(v)>.15)drag.p.k=v}else if(Math.hypot(v[0],v[2])<6)drag.p.f=[v[0],drag.p.f[1],v[2]];buildParts(true);drawHandles();setHint(drag.j==='f'?'El pie se desliza por el suelo':'Suelta para fijar la rodilla')}}
  else if(drag.k==='node'){const o=ray.ray.origin,d=ray.ray.direction;if(Math.abs(d.x)>1e-4){const s=-o.x/d.x;if(s>0)moveNode(drag.node,o.y+d.y*s-off,o.z+d.z*s)}}
  else if(drag.k==='part'){if(!drag.moved&&!drag.isNew&&Math.hypot(e.clientX-drag.x,e.clientY-drag.y)<5)return;drag.moved=true;const h=inside&&hitBody();
    if(h){if(drag.isNew&&!G.parts.includes(drag.p)){G.parts.push(drag.p);sel=drag.p;place(drag.p,h);buildParts();drawPanel()}else place(drag.p,h);drag.over=true}else drag.over=false;
    for(const o of objs)if(o.p===drag.p)o.g.visible=drag.over;for(const l of legs)if(l.p===drag.p)l.up.visible=l.lo.visible=l.ft.visible=drag.over;ghostAt(e,!drag.over,drag.p.type);setHint(drag.over?'Suelta para colocar':drag.isNew&&!G.parts.includes(drag.p)?'Llévala hasta el cuerpo de la criatura':'Suelta fuera del cuerpo para quitar la pieza')}});
addEventListener('pointerup',e=>{if(!drag)return;const d=drag;drag=null;gl.style.cursor='grab';ghost.style.display='none';setHint();
  if(d.k==='cam'){if(!d.moved&&sel&&mode==='build'){sel=null;drawPanel()}return}
  if(d.k==='rot'){commit();return}
  if(d.k==='node'||d.k==='joint'){buildParts();drawHandles();commit();return}
  if(d.k==='part'){if(d.isNew&&!d.moved){pendingPart=d.p.type;flashOk('Toca el cuerpo para colocar');return}
    if(d.moved){if(!d.over&&G.parts.includes(d.p))removePart(d.p);else if(G.parts.includes(d.p)){buildParts();drawPanel();commit()}}}});

gl.addEventListener('wheel',e=>{e.preventDefault();setRay(e);
  if(mode==='build'){const n=hitNode();if(n>=0){G.nodes[n].r=clamp(G.nodes[n].r*(1-e.deltaY*.0012),.05,1.7);refresh(false);clearTimeout(gl._t);gl._t=setTimeout(commit,400);return}
    const p=hitPart();if(p&&p===sel&&p.size){p.size=clamp(p.size*(1-e.deltaY*.001),.5,2.2);buildParts();drawPanel();clearTimeout(gl._t);gl._t=setTimeout(commit,400);return}}
  camDist=clamp(camDist*(1+e.deltaY*.001),3,60)},{passive:false});
addEventListener('keydown',e=>{if(['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName))return;
 if(e.key==='Escape'){if(drag&&gestureStart){drag=null;loadG(gestureStart,true);ghost.style.display='none'}pendingPart=null;return}
 if((e.ctrlKey||e.metaKey)&&['z','y'].includes(e.key.toLowerCase())){e.preventDefault();if(e.shiftKey||e.key.toLowerCase()==='y')redo();else undo();return}
 if(mode==='build'&&(e.key==='Delete'||e.key==='Backspace')&&sel){e.preventDefault();removePart(sel)}
 if(mode==='build'&&e.key.startsWith('Arrow')){const r=editTool==='growth'&&selectedRegion(),p=sel;if(r||p){e.preventDefault();if(r){if(['ArrowLeft','ArrowRight'].includes(e.key))r.position=clamp(r.position+(e.key==='ArrowRight'?.02:-.02),0,1);else r.angle=clamp(r.angle+(e.key==='ArrowUp'?-.05:.05),-Math.PI,Math.PI);positionGrowth()}else{p.t=clamp(p.t+(e.key==='ArrowRight'?.02:e.key==='ArrowLeft'?-.02:0),0,1);p.ang=clamp(p.ang+(e.key==='ArrowUp'?-.05:e.key==='ArrowDown'?.05:0),0,Math.PI);buildParts()}commit();drawPanel()}}
});

/* ---------- interfaz ---------- */
const PATS=['liso','rayas','manchas','veteado'],HINTS={build:'Pasa el cursor por el cuerpo para ver la columna · arrastra una vértebra para esculpir · rueda sobre ella para engordar',paint:'Arrastra para girar la cámara',test:'Tu criatura camina sola: nada está animado a mano'};
let flashT=0;function setHint(t){$('hint').textContent=tr(t||HINTS[mode])}function flash(t){setHint(t);clearTimeout(flashT);flashT=setTimeout(setHint,2200);$('meter').classList.add('over');setTimeout(()=>$('meter').classList.remove('over'),600)}
function syncSkin(){const s=G.skin;SU.cA.value.copy(lin(s.cA));SU.cB.value.copy(lin(s.cB));SU.cC.value.copy(lin(s.cC));SU.uPat.value=s.pat;SU.uWet.value=s.wet;SU.uScale.value=s.scale;skinM.clearcoat=skinM2.clearcoat=membraneM.clearcoat=s.wet*.8;clearTimeout(syncSkin.t);syncSkin.t=setTimeout(()=>typeof drawThumbs==='function'&&drawThumbs(),120)}
const pips=n=>'<span class="pips">'+[1,2,3,4,5].map(i=>`<i class="${i<=n?'on':''}"></i>`).join('')+'</span>';
function drawStats(){$('dna').textContent=`${stats.dna} / ${BUDGET}`;$('meter').firstElementChild.style.width=clamp(stats.dna/BUDGET*100,0,100)+'%';if(!$('caps'))return;
  $('caps').innerHTML=[['Velocidad',stats.vel],['Mordisco',stats.bite],['Canto',stats.sing],['Salud',stats.hp]].map(([n,v])=>`<div class="cap"><span>${tr(n)}</span>${pips(v)}</div>`).join('')+stats.warn.filter(Boolean).map(w=>`<div class="warn">${tr(w)}</div>`).join('')}
function drawPanel(){let h='';
  if(mode==='build'){h+=`<section><h2>Capacidades</h2><div id="caps"></div></section>`;
    if(sel){const L=LIB[sel.type];h+=`<section><h2>${tr(L.name)}</h2>${(L.leg?L.p:[...L.p,'rot','tilt']).map(k=>`<div class="row"><label for="p-${k}">${PLBL[k][0]}</label><input type="range" id="p-${k}" data-pk="${k}" min="${PLBL[k][1]}" max="${PLBL[k][2]}" step=".01" value="${sel[k]||0}"></div>`).join('')}${L.leg?'':'<p class="note">Arrastra la cuenta verde para girar la pieza.</p>'}${L.leg?'<p class="note">El pie se desliza por el suelo y la rodilla es libre. Sube o baja el cuerpo con las vértebras: las patas se estiran para seguir apoyadas.</p>':''}<div class="chips"><button id="del">Quitar pieza</button></div></section>`}
    else h+=`<section><h2>Pieza</h2><p class="note">Toca una pieza de la criatura para ajustarla. Arrástrala fuera del cuerpo para quitarla.</p></section>`;
    h+=`<section><h2>Criatura</h2><div class="chips">${Object.keys(SEEDS).map(n=>`<button data-seed="${n}">${n}</button>`).join('')}</div><div class="chips"><button id="rand">Al azar</button><button id="copy">Copiar genoma</button></div></section>`}
  if(mode==='paint'){const s=G.skin;h+=`<section><h2>Piel</h2><div class="row"><span>Dibujo</span><div class="seg">${PATS.map((n,i)=>`<button id="pat-${i}" data-pat="${i}" aria-pressed="${s.pat===i}">${n}</button>`).join('')}</div></div>
    <div class="row"><span>Colores</span><div class="colors">${['cA','cB','cC'].map((q,i)=>`<input type="color" id="c-${q}" data-col="${q}" value="${s[q]}" aria-label="${['Color base','Color del dibujo','Color del vientre'][i]}">`).join('')}</div></div>
    <div class="row"><label for="s-scale">Escama</label><input type="range" id="s-scale" data-sk="scale" min="3" max="14" step=".5" value="${s.scale}"></div><div class="row"><label for="s-wet">Brillo</label><input type="range" id="s-wet" data-sk="wet" min="0" max="1" step=".01" value="${s.wet}"></div></section>
    <section><h2>Combinaciones</h2><div class="chips">${PALS.map((p,i)=>`<button data-pal="${i}" aria-label="${tr('Combinaciones')} ${i+1}" style="background:linear-gradient(90deg,${p[0]} 0 50%,${p[1]} 50% 78%,${p[2]} 78%);width:54px;height:26px"></button>`).join('')}</div></section>`}
  if(mode==='test')h+=`<section><h2>Capacidades</h2><div id="caps"></div></section><section><h2>Acciones</h2><div class="chips"><button data-act="bite">Morder</button><button data-act="sing">Cantar</button><button data-act="run" aria-pressed="${run}">${run?'Andar':'Correr'}</button></div><p class="note">La zancada, el reparto de patas y la ondulación del cuerpo salen de las piezas que has puesto.</p></section>`;
  $('panel').innerHTML=h+(mode==='build'?growthPanel():'');drawStats();document.body.dataset.mode=mode;drawHandles();translateUI();syncHistory()}
const PALS=[['#9a3b28','#2a1414','#e6cfa0'],['#2f8a5a','#12382c','#e9e2a8'],['#3d5fa8','#8a4fb0','#f0e6c8'],['#c9892b','#4a2a12','#f3e3b8'],['#6c7440','#2f3320','#d8cfa6'],['#22313f','#d9a441','#c8d2d8'],['#b84a6a','#3a1830','#f2d9c9']];
$('panel').addEventListener('input',e=>{const t=e.target;if(t.dataset.pk&&sel){sel[t.dataset.pk]=+t.value;if(!['rot','tilt'].includes(t.dataset.pk))buildParts()}if(t.dataset.sk){G.skin[t.dataset.sk]=+t.value;syncSkin()}if(t.dataset.col){G.skin[t.dataset.col]=t.value;syncSkin()}});
$('panel').addEventListener('change',()=>commit());
$('panel').addEventListener('click',e=>{const t=e.target.closest('button');if(!t)return;const d=t.dataset;
  if(t.id==='del'&&sel)removePart(sel);if(t.id==='rand'){loadG(randomCreature());commit()}if(d.seed){loadG(SEEDS[d.seed]);commit()}
  if(t.id==='copy')navigator.clipboard.writeText(JSON.stringify(G)).then(()=>flashOk('Genoma copiado'),()=>flashOk('El navegador no ha permitido copiar'));
  if(d.pat){G.skin.pat=+d.pat;syncSkin();drawPanel();commit()}if(d.pal){const p=PALS[+d.pal];Object.assign(G.skin,{cA:p[0],cB:p[1],cC:p[2]});syncSkin();drawPanel();commit()}
  if(d.act==='bite')biteT=.6;if(d.act==='sing')singT=1.6;if(d.act==='run'){run=!run;drawPanel()}});
function flashOk(t){setHint(t);clearTimeout(flashT);flashT=setTimeout(setHint,2000)}
/* miniaturas 3D de la paleta: se dibujan con el render principal y giran al pasar el cursor */
const TH=112,thRT=new T.WebGLRenderTarget(TH,TH),thScene=new T.Scene(),thCam=new T.PerspectiveCamera(30,1,.05,60),thBuf=new Uint8Array(TH*TH*4),thModels={};
thRT.texture.encoding=T.sRGBEncoding;thScene.environment=scene.environment;thScene.add(new T.HemisphereLight(0xffffff,0x665544,.55));{const d=new T.DirectionalLight(0xfff2e0,1.5);d.position.set(2,4,3);thScene.add(d)}
function thumbModel(k){if(thModels[k])return thModels[k];const L=LIB[k],p=defaults(k),piv=new T.Group(),inner=new T.Group();
  if(L.leg){const[a,b]=legLens(p),m=legMeshes(p,[0,0,0],a,b),K=V(...p.k),F=V(...p.f);m.up.quaternion.setFromUnitVectors(DOWN,K.clone().normalize());m.lo.position.copy(K);m.lo.quaternion.setFromUnitVectors(DOWN,F.clone().sub(K).normalize());m.ft.position.set(F.x,F.y-p.w*.6,F.z);inner.add(m.up,m.lo,m.ft)}
  else{inner.add(L.make(p,[0,1,0]));if(!L.glb&&(L.cat==='Armas'||L.cat==='Adornos'||k==='antena'||k==='tallo'))inner.rotation.x=-Math.PI/2}
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
$('palette').addEventListener('click',e=>{const b=e.target.closest('[data-part]');if(b&&e.detail===0&&mode==='build'){pendingPart=b.dataset.part;editTool='sculpt';flashOk('Toca el cuerpo para colocar');gl.focus({preventScroll:true})}});
$('palette').addEventListener('pointerdown',e=>{const t=e.target.closest('[data-part]');if(!t||mode!=='build')return;e.preventDefault();const p=newPart(t.dataset.part);if(p){gestureStart=snapshot();pendingPart=null;editTool='sculpt';drag={k:'part',p,isNew:true,moved:false,over:false,x:e.clientX,y:e.clientY};hoverKey=null;ghostAt(e,true,p.type)}});
$('name').addEventListener('input',e=>{G.name=e.target.value.replace(/[<>\x00-\x1f]/g,'').slice(0,80)});$('name').addEventListener('change',commit);
function setMode(m){mode=m;if(m!=='build')sel=null;theta=0;phase=0;run=false;document.querySelectorAll('#modes button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.mode===m));refresh(false);drawPanel();setHint()}
$('modes').addEventListener('click',e=>{const m=e.target.dataset.mode;if(m)setMode(m)});

let last=0;function loop(t){requestAnimationFrame(loop);const dt=Math.min(.05,(t-last)/1000||0);last=t;update(dt);frameCam(dt);if(hoverKey){thRot+=dt*2.4;renderThumb(hoverKey,thRot,tctx(hoverKey))}renderer.render(scene,camera)}
const growthG=new T.Group();creature.add(growthG);
const regionViews=new Map();let growthBuilds=0;
const regionDefaults={schema:CreatureGrowth.VERSION,family:'horns',seed:17,count:7,length:1,curve:.45,branches:1,surface:'torso',position:.6,coverage:.4,angle:.55,mirror:true};
function selectedRegion(){return G.regions.find(r=>r.id===selectedRegionId)}
function regionRange(surface){return surface==='tail'?[.08,.35]:surface==='neck'?[.75,.96]:[.35,.75]}
function rebuildGrowth(){
 const ids=new Set(G.regions.map(r=>r.id));
 for(const [id,v]of regionViews)if(!ids.has(id)){v.items.forEach(m=>{growthG.remove(m);clear(m)});regionViews.delete(id)}
 for(const r of G.regions){const key=JSON.stringify([r.family,r.seed,r.count,r.length,r.curve,r.branches]);let view=regionViews.get(r.id);if(view?.key===key)continue;
  if(view)view.items.forEach(m=>{growthG.remove(m);clear(m)});
  view={key,items:[],builds:(view?.builds||0)+1};growthBuilds++;
  const generated=CreatureGrowth.generate(r);
  for(const piece of generated.pieces)for(const side of [1,-1]){
   const geo=new T.BufferGeometry();geo.setAttribute('position',new T.BufferAttribute(piece.positions.slice(),3));geo.setAttribute('normal',new T.BufferAttribute(piece.normals.slice(),3));geo.setIndex(new T.BufferAttribute(piece.indices,1));
   skinify(geo,[0,0,0],.5);const root=new T.Group();root.userData={offset:piece.offset,side};const m=mesh(geo,r.family==='tendrils'?skinM:boneM,root);m.userData.region=r.id;
   growthG.add(root);view.items.push(root);
  }
  regionViews.set(r.id,view);
 }
 positionGrowth();
}
function positionGrowth(){for(const r of G.regions){const v=regionViews.get(r.id);if(!v)continue;const [a,b]=regionRange(r.surface);
 for(const root of v.items){const {offset,side}=root.userData;root.visible=side===1||(r.mirror&&Math.abs(r.angle)>.04);const along=(1-r.coverage)*r.position+r.coverage*(offset+.5),t=lerp(a,b,along);
  anchor(pts,t,r.angle*side,A1);orient(root,A1,.01,0,0,false);root.quaternion.multiply(_q.setFromAxisAngle(X0,Math.PI/2));root.scale.x=side;
  const geo=root.children[0].geometry,sk=geo.attributes.skin,pa=geo.attributes.position;
  // Stable body-relative skin coordinates; shape stays cached during placement.
  for(let k=0;k<pa.count;k++)sk.setXYZW(k,pa.getX(k)+A1.p.x,pa.getY(k)+A1.p.y,pa.getZ(k)+A1.p.z,Math.cos(r.angle));sk.needsUpdate=true;
 }
}}
function growthPanel(){const r=selectedRegion();return `<section><h2>${tr('Regiones')}</h2><div class="chips">${['sculpt','orbit','growth'].map((v,i)=>`<button data-tool="${v}" aria-pressed="${editTool===v}">${tr(['Esculpir','Girar cámara','Regiones'][i])}</button>`).join('')}</div><div class="chips">${G.regions.map((r,i)=>`<button data-region="${r.id}" aria-pressed="${r.id===selectedRegionId}">${tr(({horns:'Cuernos',plates:'Placas',tendrils:'Filamentos'})[r.family])} ${i+1}</button>`).join('')}</div><div class="chips"><button data-growth-action="add" ${G.regions.length>=64?'disabled':''}>${tr('Añadir región')}</button>${r?`<button data-growth-action="duplicate" ${G.regions.length>=64?'disabled':''}>${tr('Duplicar')}</button><button data-growth-action="delete">${tr('Eliminar')}</button>`:''}</div>${r?`
 <div class="row"><label for="growth-family">${tr('Forma')}</label><select id="growth-family" data-region-key="family">${['horns','plates','tendrils'].map((f,i)=>`<option value="${f}" ${f===r.family?'selected':''}>${tr(['Cuernos','Placas','Filamentos'][i])}</option>`).join('')}</select></div>
 <div class="row"><label for="growth-surface">${tr('Superficie')}</label><select id="growth-surface" data-region-key="surface">${['torso','neck','tail'].map((v,i)=>`<option value="${v}" ${v===r.surface?'selected':''}>${tr(['Torso','Cuello','Cola'][i])}</option>`).join('')}</select></div>
 ${[['position','Posición',0,1,.01],['coverage','Cobertura',0,1,.01],['angle','Ángulo',-3.14,3.14,.01],['length','Largo',.2,2.4,.05],['count','Cantidad',1,18,1],['curve','Curvatura',-1,1,.05],['branches','Ramas',0,3,1]].map(([k,n,a,b,step])=>`<div class="row"><label for="growth-${k}">${tr(n)}</label><input id="growth-${k}" data-region-key="${k}" type="range" min="${a}" max="${b}" step="${step}" value="${r[k]}"></div>`).join('')}
 <label><input type="checkbox" data-region-key="mirror" ${r.mirror?'checked':''}> ${tr('Espejo')}</label><p class="note">${tr('Semilla')}: ${r.seed}</p><div class="chips"><button id="placeGrowth" data-tool="growth" aria-pressed="${editTool==='growth'}">${tr('Colocar en el cuerpo')}</button><button data-growth-action="vary">${tr('Nueva variante')}</button></div>`:''}<p class="note">${tr('Detalles artísticos; no cambian las capacidades.')}</p></section>`}
$('panel').addEventListener('input',e=>{const k=e.target.dataset.regionKey,r=selectedRegion();if(k&&r){r[k]=k==='mirror'?e.target.checked:['family','surface'].includes(k)?e.target.value:+e.target.value;rebuildGrowth()}});
$('panel').addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;
 if(b.dataset.tool){editTool=b.dataset.tool;pendingPart=null;drawPanel();gl.focus({preventScroll:true})}
 if(b.dataset.region){selectedRegionId=b.dataset.region;editTool='growth';sel=null;drawPanel()}
 const action=b.dataset.growthAction;if(!action)return;const r=selectedRegion();
 if(['add','duplicate'].includes(action)&&G.regions.length<64){let n=1;while(G.regions.some(r=>r.id==='region-'+n))n++;const next={...(action==='duplicate'?r:regionDefaults),id:'region-'+n};G.regions.push(next);selectedRegionId=next.id;editTool='growth'}
 if(action==='delete'&&r){G.regions=G.regions.filter(x=>x!==r);selectedRegionId=G.regions[0]?.id||null}
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
 $('json').value=JSON.stringify(G,null,1);
 const text=$('message').textContent;for(const [es,en]of Object.entries(EN)){if(text.startsWith(es+':'))$('message').textContent=tr(es)+text.slice(es.length);if(text.startsWith(en+':'))$('message').textContent=tr(es)+text.slice(en.length)}
 setHint();
}
function report(message){$('message').textContent=message}
function assetBounds(type){const box=new T.Box3().setFromObject(glbTemplates[type]);return {min:box.min.toArray(),max:box.max.toArray()}}
function shareLink(){const bytes=new TextEncoder().encode(snapshot());let binary='';for(const b of bytes)binary+=String.fromCharCode(b);return location.href.split('#')[0]+'#g='+btoa(binary)}
function bootDocument(){
 try{const hash=location.hash.slice(1);if(hash.startsWith('g=')){const raw=atob(decodeURIComponent(hash.slice(2)));G=StudioDocument.parse(new TextDecoder('utf-8',{fatal:true}).decode(Uint8Array.from(raw,c=>c.charCodeAt(0))),tableById).genome}
 else if(hash.startsWith('preset=')&&SEEDS[decodeURIComponent(hash.slice(7))])G=StudioDocument.clone(SEEDS[decodeURIComponent(hash.slice(7))]);
 else {const saved=localStorage.getItem('cpore.creature.v4');if(saved)G=StudioDocument.parse(saved,tableById).genome}
 }catch(e){report(tr('Genoma no válido')+': '+e.message)}
 if(G.migration)report(G.migration.warnings.map(tr).join(' · '));
 if(assetFailures.length)report(tr('Piezas no disponibles')+': '+assetFailures.join(', '));
}
$('undo').onclick=undo;$('redo').onclick=redo;
$('lang').onclick=()=>{lang=lang==='es'?'en':'es';localStorage.setItem('cpore.lang',lang);drawPanel();if(G.migration)report(G.migration.warnings.map(tr).join(' · '))};
$('documents').addEventListener('click',async e=>{const a=e.target.dataset.doc;if(!a)return;
 try{if(a==='load')importGenome($('json').value);
 if(a==='file')$('import-file').click();
 if(a==='share'){const link=shareLink();$('json').value=link;await navigator.clipboard.writeText(link);report(tr('Enlace copiado'))}
 if(a==='download'){const url=URL.createObjectURL(new Blob([snapshot()],{type:'application/json'})),link=document.createElement('a');link.href=url;link.download='primigenia-creature.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);report(tr('Archivo descargado'))}
 }catch(err){report(tr('Genoma no válido')+': '+err.message)}
});
$('documents').addEventListener('change',async e=>{if(e.target.id==='import-file'&&e.target.files[0])try{importGenome(await e.target.files[0].text())}catch(err){report(tr('Genoma no válido')+': '+err.message)}});
function randomCreature(seed=Math.floor(Math.random()*4294967296)){const rnd=rngFrom(seed),g=StudioDocument.clone(Object.values(SEEDS)[seed%3]);g.name='Creature '+seed;g.nodes.forEach(n=>{n.r=clamp(n.r*(.8+rnd()*.4),.05,1.7);n.y+=rnd()*.15});g.skin.pat=Math.floor(rnd()*4);return g}
window.CreatureStudio={genome:()=>StudioDocument.clone(G),load:importGenome,presets:Object.keys(SEEDS),random:seed=>{loadG(randomCreature(seed));commit()},preset:name=>{loadG(SEEDS[name]);commit()},shareLink,
 parts:partTable,ready:true,undo,redo,assetBounds,defaults:type=>StudioDocument.clone(defaults(type)),
 addPart:(type,attachment={})=>{if(!LIB[type])throw Error('parts.type');const p={...defaults(type),...attachment};const next=StudioDocument.clone(G);next.parts.push(p);StudioDocument.validate(next,tableById);G.parts.push(p);sel=p;buildParts();drawPanel();commit();return G.parts.length-1},
 diagnostics:()=>({assetFailures,loadedGLBs:Object.keys(glbTemplates).length,selectedRegionId,growthBuilds,geometryCount:renderer.info.memory.geometries,regions:[...regionViews].map(([id,v])=>({id,builds:v.builds})),cosmetic:true}),
 projectPoint:(t,ang)=>{anchor(pts,t,ang,A1);const p=creature.localToWorld(A1.p.clone()).project(camera),r=gl.getBoundingClientRect();return [r.left+(p.x+1)*r.width/2,r.top+(1-p.y)*r.height/2]},
 attachmentRoots:()=>{
  update(0);creature.updateMatrixWorld(true);const result=[];
  for(const o of objs){anchor(pts,o.p.t,o.sg*o.p.ang,A1);result.push({type:o.p.type,root:o.g.position.toArray(),surface:A1.p.toArray(),error:o.g.position.distanceTo(A1.p)})}
  for(const l of legs){anchor(pts,l.p.t,l.sg*l.p.ang,A1);const root=creature.worldToLocal(l.up.position.clone());result.push({type:l.p.type,root:root.toArray(),surface:A1.p.toArray(),error:root.distanceTo(A1.p)})}
  const pa=body.geometry.attributes.position,ix=body.geometry.index,triangle=new T.Triangle(),closest=V();
  for(const item of result){const root=V(...item.root);let distance=Infinity;
   for(let i=0;i<ix.count;i+=3){triangle.a.fromBufferAttribute(pa,ix.getX(i));triangle.b.fromBufferAttribute(pa,ix.getX(i+1));triangle.c.fromBufferAttribute(pa,ix.getX(i+2));triangle.closestPointToPoint(root,closest);distance=Math.min(distance,root.distanceTo(closest))}
   item.meshDistance=distance;
  }
  return result;
 },setMode,
};

window.Creador={_art:(j,sg)=>{const h=j==='rot'?rotH:handlesG.children.find(c=>c.userData.joint===j&&c.userData.sg===sg);if(!h)return null;const v=h.getWorldPosition(V()).project(camera),r=gl.getBoundingClientRect();return[r.left+(v.x+1)/2*r.width,r.top+(1-v.y)/2*r.height]},_sel:i=>{sel=G.parts[i];drawPanel()},_dbg:(x,y)=>{setRay({clientX:x,clientY:y});const j=hitJoint(),p=hitPart();return{joint:j&&j.userData,part:p&&p.type+p.t.toFixed(2),nj:handlesG.children.filter(c=>c.userData.joint).length,el:document.elementFromPoint(x,y).id||document.elementFromPoint(x,y).tagName}},_suelas:()=>legs.map(l=>+l.ft.position.y.toFixed(3)),_alt:()=>legs.map(l=>+(l.a+l.b).toFixed(2)),get genoma(){return JSON.parse(JSON.stringify(G))},cargar:importGenome,modo:setMode};
bootDocument();resize();showCat(cats[0]);loadG(G);commit();setHint();drawThumbs();update(0);frameCam(0,true);requestAnimationFrame(loop);
})().catch(e=>{document.getElementById('message').textContent='No se pudo abrir el estudio / Could not open studio: '+e.message;console.error(e)});
