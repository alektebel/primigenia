/* The studio and playable stage use this single anatomy/material/IK implementation.
 * World placement is optional: the studio retains its circular test path. */
export async function createCreatureRig({T,scene,SUN,partTable,partManifest,
  assetBase='../studio/',onStats=()=>{},getDrag=()=>null}) {
const V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z);
const lerp=(a,b,t)=>a+(b-a)*t,clamp=(x,a,b)=>Math.min(b,Math.max(a,x)),sstep=(a,b,x)=>{x=clamp((x-a)/(b-a),0,1);return x*x*(3-2*x)};
const lin=h=>new T.Color(h).convertSRGBToLinear();
const RC=7,CX=-7,grassU={uTime:{value:0}};
/* ---------- materiales de la criatura ---------- */
const SU={cA:{value:lin('#888888')},cB:{value:lin('#444444')},cC:{value:lin('#cccccc')},uPat:{value:1},uWet:{value:.3},uScale:{value:7}};
const SKIN_GLSL=`uniform vec3 cA,cB,cC;uniform float uPat,uWet,uScale;varying vec4 vSkin;
float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1.,0.,0.)),f.x),mix(h3(i+vec3(0.,1.,0.)),h3(i+vec3(1.,1.,0.)),f.x),f.y),mix(mix(h3(i+vec3(0.,0.,1.)),h3(i+vec3(1.,0.,1.)),f.x),mix(h3(i+vec3(0.,1.,1.)),h3(i+vec3(1.,1.,1.)),f.x),f.y),f.z);}
vec2 wor(vec3 x){vec3 p=floor(x),f=fract(x);float a=8.,b=8.;for(int k=-1;k<=1;k++)for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){vec3 g=vec3(float(i),float(j),float(k));vec3 o=vec3(h3(p+g),h3(p+g+17.3),h3(p+g+41.7));vec3 r=g+o-f;float d=dot(r,r);if(d<a){b=a;a=d;}else if(d<b){b=d;}}return sqrt(vec2(a,b));}
vec3 pN(vec3 sp,vec3 sn,vec2 dH){vec3 sx=dFdx(sp),sy=dFdy(sp),r1=cross(sy,sn),r2=cross(sn,sx);float det=dot(sx,r1);vec3 g=sign(det)*(dH.x*r1+dH.y*r2);return normalize(abs(det)*sn-g);}
`;
function skinMaterial(o={}){const kind=o.kind||'skin',membraneStyle=o.membraneStyle||'',params={...o};delete params.kind;delete params.membraneStyle;
  const m=new T.MeshPhysicalMaterial({roughness:.6,metalness:0,clearcoat:.3,clearcoatRoughness:.4,envMapIntensity:.9,...params});m.extensions={derivatives:true};m.customProgramCacheKey=()=>kind+membraneStyle;
  m.onBeforeCompile=s=>{Object.assign(s.uniforms,SU);if(kind==='membrane')s.uniforms.uSun={value:SUN};
    s.vertexShader='attribute vec4 skin;varying vec4 vSkin;\n'+s.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nvSkin=skin;');
    const backlight=kind==='membrane'?`vec3 Lw=normalize(mat3(viewMatrix)*uSun);float ndl=dot(normal,Lw);float thru=pow(clamp(-ndl,0.,1.),1.2);float rim=pow(1.-abs(dot(normalize(vViewPosition),normal)),2.4);totalEmissiveRadiance+=sk*(thru*.65+rim*.16);`:'';
    s.fragmentShader=(kind==='membrane'?'uniform vec3 uSun;\n':'')+SKIN_GLSL+s.fragmentShader
     .replace('#include <color_fragment>',`vec3 rp=vSkin.xyz;float dd=vSkin.w,nn=n3(rp*1.3)+.5*n3(rp*2.9),mk=0.;
       if(uPat>.5&&uPat<1.5)mk=smoothstep(.42,.62,.5+.5*sin(rp.z*4.6+(nn-.75)*3.2));
       else if(uPat>1.5&&uPat<2.5){vec2 w0=wor(rp*1.5);mk=1.-smoothstep(.2,.33,w0.x);}
       else if(uPat>2.5)mk=smoothstep(.5,.72,nn*.66+dd*.12);
       mk*=smoothstep(-.4,.2,dd);vec3 sk=mix(cA,cB,mk);sk=mix(sk,cC,1.-smoothstep(-.85,-.2,dd));sk*=mix(1.,.72,smoothstep(.7,1.,dd));
       vec2 w1=wor(rp*uScale);float sh=smoothstep(0.,.2,w1.y-w1.x),bp=smoothstep(0.,.45,w1.y-w1.x)*.007+n3(rp*3.)*.015;sk*=mix(.7,1.,sh)*(.9+.2*n3(rp*11.));${kind==='membrane'?(membraneStyle?`sk=mix(sk,cC,.58);${membraneStyle==='insect'?'sk=mix(sk,mix(vec3(.14,.58,.7),vec3(.58,.3,.74),pow(1.-abs(dot(normalize(vNormal),normalize(vViewPosition))),2.)),.42);':''}`:'sk=mix(sk,cB,.35+.15*n3(rp*5.5));sk=mix(sk,cC,.12)*.65;'):''}diffuseColor.rgb=sk;`)
     .replace('#include <roughnessmap_fragment>',kind==='membrane'?'#include <roughnessmap_fragment>\nroughnessFactor='+ (membraneStyle?params.roughness:.94)+';':'#include <roughnessmap_fragment>\nroughnessFactor=clamp(mix(.82,.3,uWet)*mix(1.25,.9,sh),.06,1.);')
     .replace('#include <normal_fragment_maps>','#include <normal_fragment_maps>\nnormal=pN(-vViewPosition,normal,vec2(dFdx(bp),dFdy(bp)));')
     .replace('#include <emissivemap_fragment>','#include <emissivemap_fragment>\ntotalEmissiveRadiance+=sk*pow(1.-clamp(dot(normalize(vViewPosition),normal),0.,1.),3.)*.5;'+backlight)};
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
const glbTemplates={},materialSlots=[];
/* Thin skin: creature colours on both faces, a little see-through, lit from behind.
   Transmission is a full extra scene pass in r128; the backlight term stays in this shader. */
const membraneM=skinMaterial({kind:'membrane',side:T.DoubleSide,transparent:true,opacity:.82,depthWrite:true,roughness:.94,clearcoat:0,clearcoatRoughness:1,envMapIntensity:.12});
// Separate thin-tissue finishes keep the accepted frill material unchanged.
const gliderM=skinMaterial({kind:'membrane',membraneStyle:'glider',side:T.DoubleSide,transparent:true,opacity:.9,roughness:.8,envMapIntensity:.25});
const insectM=skinMaterial({kind:'membrane',membraneStyle:'insect',side:T.DoubleSide,transparent:true,opacity:.48,depthWrite:false,roughness:.42,clearcoat:.65});
const sacM=skinMaterial({kind:'membrane',membraneStyle:'sac',side:T.DoubleSide,transparent:true,opacity:.74,roughness:.48});
/* G48: normalized creator anatomy. +Z is out of the skin; body mounts use
   +Y up / +Z forward. Scale from the anatomical spine, excluding its end caps. */
function sweep(points,radii){
 const path=new T.CatmullRomCurve3(points.map(p=>V(...p))),ps=[],rs=[],n=26;
 for(let i=0;i<n;i++){const u=i/(n-1),k=u*(radii.length-1),j=Math.min(k|0,radii.length-2);ps.push(path.getPoint(u));rs.push(Math.max(.002,lerp(radii[j],radii[j+1],k-j)))}
 const d=ps.at(-1).clone().sub(ps[0]),ref=Math.abs(d.x)>Math.abs(d.y)+Math.abs(d.z)?Y:X0;
 const geo=allocTube(n,12);fillTube(geo,ps,rs,12,ref,false);return geo;
}
function tissue(geo,region,parent){
 const mat={skin:skinM,keratin:boneM,membrane:membraneM,glow:glowM,eye:pupM,iris:irisM}[region];
 const m=mesh(geo,mat,parent);m.userData.materialRegion=region;
 if(region==='glow')m.castShadow=m.receiveShadow=false;
 return m;
}
function sail(outline,parent,material=membraneM){
 // Curved fan with a raised centre: both faces receive the membrane backlight.
 const curve=new T.CatmullRomCurve3(outline.map(p=>V(...p)),true,'catmullrom',.25),n=48,pos=[...outline.reduce((a,p)=>a.add(V(...p)),V()).multiplyScalar(1/outline.length).add(V(0,.045,0)).toArray()],idx=[];
 for(let i=0;i<n;i++)pos.push(...curve.getPoint(i/n).toArray());
 for(let i=0;i<n;i++)idx.push(0,i+1,(i+1)%n+1);
 const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(pos,3));geo.setIndex(idx);geo.computeVertexNormals();const m=tissue(geo,'membrane',parent);m.material=material;return m;
}
function creatorPart(id,options,make){
 LIB[id]={p:['size'],responsive:true,...options,make:(p,off,r=.6,context={head:.6,body:.6,height:2,mouthHeight:2.2})=>{
  const radius=options.bodyMinimum?Math.max(r,context.body*options.bodyMinimum):r,s=p.size*radius/.6,g=make(p,r,s,context);
  g.traverse(o=>{if(o!==g)o.position.multiplyScalar(s);if(o.isMesh){o.geometry.scale(s,s,s);skinify(o.geometry,off,o.userData.materialRegion==='membrane'?.42:null)}});
  g.userData.mountRadius=r;g.userData.partScale=s;return g;
 }};
}
creatorPart('beak_crusher',{bite:3,sing:2,mount:'body'},(p)=>{
 const g=new T.Group(),jaw=new T.Group();g.add(jaw);g.userData.jaw=jaw;
 // Start at the snout end, with a narrow skin seam and a forward hooked wedge.
 // Width is capped at the head diameter even when the size control is enlarged.
 const width=.57/Math.max(1,p.size),length=.6*clamp(.8+.2*p.size,.8,1.2)/p.size;
 tissue(ell(width,.36/Math.max(1,p.size),.025,0,0,0),'skin',g);
 const shell=(lower,parent)=>{
  const pos=[],idx=[],rings=21,sides=24,L=length*(lower?.74:1),edges=[[],[]];
  for(let i=0;i<rings;i++){
   const u=i/(rings-1),z=L*u,w=width*Math.pow(1-u,.8),seam=lower?-.075+.035*u:.025+.06*Math.sin(Math.PI*u)-.18*u**5;
   const h=(lower?.23:.36)*(1-u)*(.9+.5*Math.sin(Math.PI*u))/Math.max(1,p.size);
   for(let j=0;j<=sides;j++){const a=j/sides*Math.PI;pos.push(w*Math.cos(a),seam+(lower?-1:1)*h*Math.sin(a),z)}
   edges[0].push([-w,seam,z]);edges[1].push([w,seam,z]);
  }
  for(let i=0;i<rings-1;i++)for(let j=0;j<sides;j++){const k=i*(sides+1)+j;idx.push(k,k+1,k+sides+1,k+1,k+sides+2,k+sides+1)}
  if(lower)for(let i=0;i<idx.length;i+=3)[idx[i+1],idx[i+2]]=[idx[i+2],idx[i+1]];
  const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(pos,3));geo.setIndex(idx);geo.computeVertexNormals();
  const m=tissue(geo,'keratin',parent);m.name=lower?'lower mandible':'upper mandible';m.material=lower?boneM:toothM;
  for(const edge of edges){const rim=tissue(sweep(edge,[.012,.012,.005]),'keratin',parent);rim.material=beakM;rim.name='cutting edge'}
  if(!lower){const tip=geo.clone();tip.setIndex(idx.slice(16*sides*6));const m=tissue(tip,'keratin',parent);m.material=beakM;m.name='hook tip'}
 };
 shell(false,g);shell(true,jaw);
 for(const u of [.2,.4,.6]){const w=width*(1-u)*.8;tissue(sweep([[-w,-.065,length*u],[0,-.045,length*u],[w,-.065,length*u]],[.012,.022,.012]),'keratin',jaw)}
 return g;
});
creatorPart('eye_triad',{},()=>{
 const g=new T.Group();tissue(ell(.48,.18,.15,0,0,.025),'skin',g);
 for(const x of [-.3,0,.3]){
  const e=new T.Group();e.position.set(x,0,x===0?.23:.16);g.add(e);
  tissue(ell(.17,.16,.16),'skin',e);tissue(ell(.11,.11,.045,0,0,.14),'iris',e);tissue(ell(.055,.075,.018,0,0,.18),'eye',e);
 }
 return g;
});
for(const id of ['wing_glider','wing_insect'])creatorPart(id,{mount:'upright',bodyMinimum:.8},()=>{
 const g=new T.Group(),wing=new T.Group();g.add(wing);g.userData.wing=wing;
 tissue(ell(.16,.18,.22),'skin',g);
 if(id==='wing_glider'){
  // Five spread fingers, with scalloped trailing webs returning to the flank.
  const fingers=[[.5,.5,.35],[1.35,.85,.15],[2.25,.9,-.5],[1.85,.6,-1.3],[.9,.25,-1.65]];
  sail([[0,0,.08],fingers[0],fingers[1],fingers[2],[1.75,.65,-.75],fingers[3],[1.25,.34,-1.15],fingers[4],[.35,.06,-1.2],[0,-.12,-.8]],wing,gliderM);
  for(const p of fingers)tissue(sweep([[0,0,0],[p[0]*.48,p[1]*.65+.08,p[2]*.48],p],[.045,.032,.009]),'keratin',wing);
 }else{
  // Fore- and hindwings fan apart, leaving a visible notch between the sails.
  const fore=[[0,0,0],[.7,.6,.6],[1.65,.92,.7],[2.25,1,.35],[1.55,.65,.15],[.45,.2,-.05]];
  const hind=[[0,-.04,-.12],[.5,.1,-.45],[1.3,.4,-.75],[1.7,.48,-1.2],[1.1,.2,-1.35],[.3,-.05,-.65]];
  sail(fore,wing,insectM);sail(hind,wing,insectM);
  for(const p of [fore[2],fore[3],fore[4],hind[2],hind[3]]){
   tissue(sweep([[0,0,0],[p[0]*.5,p[1]*.5,p[2]*.5],p],[.023,.016,.005]),'keratin',wing);
   tissue(sweep([[p[0]*.45,p[1]*.45,p[2]*.45],[p[0]*.72,p[1]*.7,p[2]*.72+.1],[p[0]*.85,p[1]*.85,p[2]*.85+.14]],[.009,.007,.003]),'keratin',wing);
  }
 }
 return g;
});
creatorPart('frill_fan',{},()=>{
 const g=new T.Group(),fan=new T.Group();g.add(fan);g.userData.sway=fan;
 tissue(ell(.2,.16,.15),'skin',g);
 const edge=[];for(let i=0;i<=24;i++){const a=(-110+220*i/24)*Math.PI/180;edge.push([.93*Math.sin(a),-.1,.18+.93*Math.cos(a)])}
 sail([[0,0,0],...edge],fan);
 for(const i of [0,6,12,18,24])tissue(sweep([[0,0,0],edge[i].map(v=>v*.5),edge[i]],[.035,.027,.008]),'keratin',fan);
 return g;
});
creatorPart('sac_spitter',{mount:'body'},()=>{
 const g=new T.Group();tissue(ell(.24,.18,.16,0,-.12,-.06),'skin',g);
 g.userData.sacs=[];
 for(const side of [-1,1]){
  const sac=new T.Group();sac.position.set(side*.5,-.18,-.32);g.add(sac);g.userData.sacs.push(sac);
  tissue(sweep([[0,-.12,-.06],[side*.3,-.16,-.25],[side*.5,-.18,-.32]],[.14,.12,.1]),'skin',g);
  const m=tissue(ell(.36,.37,.39),'membrane',sac);m.material=sacM;
  for(const z of [-.1,.15])tissue(ell(.07,.065,.07,side*.3,.09,z),'glow',sac);
 }
 tissue(sweep([[0,-.13,-.04],[0,-.12,.25],[0,-.08,.55]],[.15,.1,.045]),'keratin',g);
 tissue(ell(.046,.046,.018,0,-.08,.55),'glow',g);return g;
});
for(const id of ['arm_grasper','arm_smasher'])creatorPart(id,{mount:'upright',bodyMinimum:.65},(p,r,s,context)=>{
 const g=new T.Group(),arm=new T.Group();g.add(arm);g.userData.arm=arm;
 const smash=id==='arm_smasher';
 if(smash){
  tissue(ell(.24,.25,.24),'skin',g);
  // Bent elbow carries the club up in front of the chest, clear of the knees.
  const club=Math.min(context.body*.34*p.size,context.head*.72)/s;
  const y=-Math.min(context.body*.12*p.size,context.height*.1)/s,z=.85;
  tissue(sweep([[0,0,0],[.32,-.24,.08],[.55,-.38,.25]],[.2,.17,.14]),'skin',arm).name='upper arm';
  tissue(ell(.17,.17,.17,.55,-.38,.25),'skin',arm);
  tissue(sweep([[.55,-.38,.25],[.65,y-.1,.55],[.6,y,z]],[.14,.13,.12]),'skin',arm).name='forearm';
  tissue(ell(club,club*.9,club*1.2,.6,y,z+club*.65),'keratin',arm).name='club head';
  for(const dz of [-.5,.1,.7])tissue(sweep([[.6-club*.8,y+club*.55,z+club*(.65+dz)],[.6,y+club*1.05,z+club*(.65+dz)],[.6+club*.8,y+club*.55,z+club*(.65+dz)]],[.025,.035,.025]),'keratin',arm);
 }else if(context.mouthHeight-context.height<context.head*1.2){
  // Low bodies need an exposed shoulder below/outside the wide jaw. The
  // forearm reaches forward and down; the tall-body grasper below is retained.
  tissue(sweep([[0,0,0],[.15,-.15,0],[.3,-.3,0]],[.2,.2,.19]),'skin',g);
  tissue(ell(.23,.22,.23,.3,-.3,0),'skin',g).name='shoulder';
  arm.position.set(.3,-.3,0);
  tissue(sweep([[0,0,0],[.35,-.05,.2],[.65,-.15,.45]],[.2,.17,.14]),'skin',arm).name='upper arm';
  tissue(ell(.17,.17,.17,.65,-.15,.45),'skin',arm);
  tissue(sweep([[.65,-.15,.45],[.8,-.4,.8],[.7,-.65,1.15]],[.14,.13,.11]),'skin',arm).name='forearm';
  tissue(ell(.21,.15,.2,.7,-.65,1.2),'skin',arm).name='palm';
  for(const side of [-1,1])tissue(sweep([[.7+side*.12,-.65,1.25],[.7+side*.29,-.61,1.48],[.7+side*.06,-.61,1.69]],[.085,.06,.004]),'keratin',arm);
 }else{
  tissue(ell(.24,.25,.24),'skin',g);
  const hand=clamp((context.mouthHeight-context.height-context.head*.4)/s,-.26,1.6),elbow=hand*.45-.35;
  tissue(sweep([[0,0,0],[.32,elbow*.6,.12],[.65,elbow,.35]],[.2,.17,.14]),'skin',arm);
  tissue(ell(.17,.17,.17,.65,elbow,.35),'skin',arm);
  tissue(sweep([[.65,elbow,.35],[.75,lerp(elbow,hand,.5),.67],[.38,hand,.98]],[.14,.13,.11]),'skin',arm);
  tissue(ell(.21,.15,.2,.38,hand,1.03),'skin',arm);
  for(const side of [-1,1])tissue(sweep([[.38+side*.12,hand,1.08],[.38+side*.29,hand+.04,1.31],[.38+side*.06,hand+.04,1.52]],[.085,.06,.004]),'keratin',arm);
 }
 return g;
});
for(const id of ['tail_paddle','tail_spike','tail_hammer'])creatorPart(id,{mount:'body',bodyMinimum:1},(p,r,s)=>{
 const g=new T.Group(),tail=new T.Group();g.add(tail);g.userData.tail=tail;
 // A tail-radius root merges with the rear 15%; the terminal organ scales
 // from max spine radius, so a slender tail never reduces it to a dot.
 tissue(sweep([[0,0,.025],[0,0,-.18],[0,.02,-.45],[0,.03,-.72]],[r*.75/s,.09,.085,.06]),'skin',tail);
 if(id==='tail_paddle'){
  sail([[0,.03,-.35],[0,.48,-.67],[0,.52,-1.14],[0,.03,-1.42],[0,-.48,-1.14],[0,-.42,-.67]],tail,gliderM).name='vertical paddle';
  for(const side of [-1,1])tissue(sweep([[0,.03,-.4],[0,side*.32,-.76],[0,side*.45,-1.13]],[.035,.025,.008]),'keratin',tail);
 }else if(id==='tail_spike'){
  tissue(ell(.19,.16,.25,0,.03,-.77),'keratin',tail);
  for(const x of [-.15,0,.15])tissue(sweep([[x,.07,-.85],[x*1.4,.22,-1.15],[x*1.7,.4,-1.48]],[.065,.045,.003]),'keratin',tail).name='tail barb';
 }else{
  tissue(ell(.29,.23,.28,0,.03,-.88),'keratin',tail);
  for(const side of [-1,1]){
   tissue(ell(.23,.21,.23,side*.25,.03,-.92),'keratin',tail);
   tissue(sweep([[side*.36,.07,-.93],[side*.56,.15,-.96]],[.065,.003]),'keratin',tail);
  }
  for(const x of [-.26,0,.26])tissue(sweep([[x,.2,-.78],[x,.29,-.93],[x,.19,-1.1]],[.035,.045,.015]),'keratin',tail);
 }
 return g;
});
for(const [id,foot]of [['leg_sprinter','runner'],['leg_sucker','sucker'],['foot_spring','spring'],['foot_hoof','cloven'],['foot_gecko','gecko']]){
 creatorPart(id,{fittedLeg:true,foot},p=>{
  const pose={...p,w:.16},m=legMeshes(pose,[0,0,0],.7,.8),g=new T.Group();m.lo.position.y=-.7;m.ft.position.y=-1.5;g.add(m.up,m.lo,m.ft);return g;
 });
}

const convention=partManifest.coordinate_convention;
if(convention.blender.up!=='+Z'||convention.blender.forward!=='+X'||convention.gltf.up!=='+Y'||convention.gltf.units!=='meters')throw Error('Unsupported part coordinate convention');
const loader=new T.GLTFLoader();
let assetFailures=[];
function slotRegion(entry,meshName,materialName,source){
 const name=materialName||'',mesh=meshName||'';
 const emissive=source?.emissive,glowing=!!(emissive&&emissive.r+emissive.g+emissive.b>.25&&(source.emissiveIntensity??1)>=1);
 if(glowing||/lantern|chartreuse|\bglow\b/i.test(name))return 'glow';
 if(entry.id==='beak_crusher')return 'keratin';
 if((entry.category==='wings'||/wing|membrane|fan/i.test(mesh))&&name==='Warm sand underside')return 'membrane';
 const listed=partTable.material_regions[name];
 if(typeof listed==='string')return listed;
 if(/membrane/i.test(name))return 'membrane';
 if(/iris|obsidian|\beye/i.test(name))return 'eye';
 if(/keratin|ivory|chitin/i.test(name))return 'keratin';
 if(/skin|underside/i.test(name))return 'skin';
 if(/dark/i.test(name))return 'dark';
 if(entry.category==='wings'||entry.category==='fins')return 'membrane';
 if(entry.category==='weapons'||entry.category==='digging_claws')return 'keratin';
 if(entry.category==='senses')return 'eye';
 return 'skin';
}
function regionMaterial(entry,name,region){
 if(region==='skin')return skinM;
 if(region==='membrane')return membraneM;
 if(region==='glow')return glowM;
 if(region==='eye')return name.includes('iris')?irisM:pupM;
 if(region==='dark')return darkM;
 return entry.id.includes('beak')&&!name.includes('Ivory')?beakM:boneM;
}
await Promise.all(partTable.parts.filter(p=>p.source==='glb').map(async entry=>{
 try{
  const gltf=await loader.loadAsync(assetBase+'parts/'+entry.file);gltf.scene.updateMatrixWorld(true);
  const template=new T.Group();
  gltf.scene.traverse(o=>{if(!o.isMesh)return;
    const geo=o.geometry.clone().applyMatrix4(o.matrixWorld).rotateY(-Math.PI/2);
    // The exporter already converts Z-up to Y-up. Keep the anatomical origin.
    if(entry.mount==='radial'&&entry.category!=='mouths'&&entry.id!=='sac_spitter')geo.rotateX(Math.PI/2);
    const name=o.material?.name||'',meshName=(o.name||'').replace(/_\d+$/,'');
    const region=slotRegion(entry,meshName,name,o.material);
    const mat=regionMaterial(entry,name,region);
    skinify(geo,[0,0,0],region==='membrane'?0.42:null);const m=mesh(geo,mat,template);m.userData.materialRegion=region;
    if(region==='glow')m.castShadow=m.receiveShadow=false;
    materialSlots.push({part:entry.id,category:entry.category,mesh:meshName,material:name||'(unnamed)',region});
  });
  glbTemplates[entry.id]=template;
 }catch(e){assetFailures.push(entry.id);}
}));
for(const entry of partTable.parts){
 if(entry.source==='glb')LIB[entry.id]={cat:entry.category,name:entry.name.es,cost:entry.dna_cost,p:['size'],glb:true,mount:entry.mount,make:(p,off)=>{
   const g=new T.Group();if(!glbTemplates[entry.id])return g;
   glbTemplates[entry.id].children.forEach(src=>{const c=src.clone();c.geometry=src.geometry.clone();c.geometry.scale(p.size,p.size,p.size);const region=src.userData.materialRegion;c.userData.materialRegion=region;skinify(c.geometry,off,region==='membrane'?0.42:null);g.add(c)});return g}};
 if(LIB[entry.id]){LIB[entry.id].category=entry.category;LIB[entry.id].name=entry.name.es;LIB[entry.id].cost=entry.dna_cost;}
}
function creatorFoot(kind,w,o,lo,ft,b){
 const add=(geo,region,par=ft)=>{skinify(geo,o,region==='skin'?-.3:null);return tissue(geo,region,par)};
 if(kind==='cloven'){
  for(const side of [-1,1]){
   add(ell(w*.68,w*.65,w*1.15,side*w*.7,w*.65,w*.65),'keratin');
   add(sweep([[side*w*.7,w*1.4,-w*.2],[side*w*.9,w*.8,-w*.85]],[w*.22,.003]),'keratin');
  }
  add(ell(w,w*.7,w*.8,0,w*1.4,0),'skin');return;
 }
 add(ell(w*1.25,w*.6,w*1.4,0,w*.6,w*.8),'skin');
 if(kind==='spring')add(sweep([[w*.6,0,0],[w*.65,-b*.5,-w*.3],[w*.4,-b,w*.1]],[w*.22,w*.18,w*.13]),'keratin',lo);
 const count=kind==='gecko'?5:kind==='sucker'?4:kind==='spring'?2:3;
 for(let i=0;i<count;i++){
  const a=(i-(count-1)/2)*(kind==='gecko'?.48:.42),L=w*(kind==='runner'?3.9:3.3),x=Math.sin(a)*L,z=w*.9+Math.cos(a)*L;
  add(sweep([[0,w*.55,w*.8],[x*.65,w*.4,z*.7],[x,w*.3,z]],[w*.32,w*.24,w*.15]),'skin');
  if(kind==='gecko'||kind==='sucker'){
   add(ell(w*.6,w*.27,w*.78,x,w*.28,z),'skin');
   for(const dz of [-.35,0,.35])add(sweep([[x-w*.43,w*.49,z+dz*w],[x+w*.43,w*.49,z+dz*w]],[w*.055,w*.055]),'keratin');
  }else add(sweep([[x,w*.3,z],[x*1.06,w*.18,z+w*.85]],[w*.22,.003]),'keratin');
 }
}
function fittedPose(p,height,r){
 // Saved /4 GLB legs have size, never IK fields. Derive a rig without editing
 // that document; the foot target stays on the floor as the spine changes.
 const s=p.size*r/.6,w=.16*s,rot=p.rot||0,tilt=p.tilt||0;
 const k=V(.32*s,-height*.48,.34*s+tilt*.3*s).applyAxisAngle(Y,rot),f=V(.35*s,-height+w*.6,.12*s).applyAxisAngle(Y,rot);
 return {...p,w,k:k.toArray(),f:f.toArray()};
}

function legMeshes(p,o,a,b){const w=p.w,kind=LIB[p.type].foot,up=new T.Group(),lo=new T.Group(),ft=new T.Group();
  mesh(skinify(new T.CylinderGeometry(w*1.5,w*1.02,a,14,4).translate(0,-a/2,0),o,.15),skinM,up);mesh(skinify(ell(w*1.75,a*.42,w*2,0,-a*.24,0),o,.3),skinM,up);
  mesh(skinify(new T.CylinderGeometry(w,w*.6,b,14,4).translate(0,-b/2,0),o,.05),skinM,lo);mesh(skinify(ell(w*1.08,w*1.08,w*1.08),o,.1),skinM,lo);
  if(['runner','sucker','spring','cloven','gecko'].includes(kind))creatorFoot(kind,w,o,lo,ft,b);
  else if(kind==='pezuna'){mesh(new T.CylinderGeometry(w*.72,w*1.05,w*1.1,14).translate(0,w*.55,w*.12),darkM,ft);mesh(skinify(ell(w*.75,w*.55,w*.75,0,w*1.1,0),o,.05),skinM,ft)}
  else if(kind==='dedos'){mesh(skinify(ell(w*.8,w*.7,w*.8,0,w*.6,0),o,.05),skinM,ft);for(const cx of[-1,0,1,2]){const c=mesh(new T.ConeGeometry(w*.34,w*(cx===2?1.8:3.4),8).rotateX(Math.PI/2).translate(0,0,w*(cx===2?.9:1.7)),beakM,ft);c.position.y=w*.3;c.rotation.y=cx===2?Math.PI:-cx*.6}}
  else{mesh(skinify(ell(w*1.2,w*.62,w*1.8,0,w*.5,w*.75),o,.05),skinM,ft);mesh(skinify(ell(w*.7,w*.7,w*.7,0,w*.6,0),o,.05),skinM,ft);
    for(const cx of[-.75,0,.75]){const c=mesh(new T.ConeGeometry(w*.27,w*.95,8).translate(0,w*.45,0),boneM,ft);c.position.set(cx*w,w*.3,w*(2.25-Math.abs(cx)*.4));c.rotation.set(1.85,0,-cx*.35)}}
  return{up,lo,ft}}
const hyp=v=>Math.hypot(v[0],v[1],v[2]),legLens=p=>[Math.max(.12,hyp(p.k)),Math.max(.12,hyp([p.f[0]-p.k[0],p.f[1]-p.k[1],p.f[2]-p.k[2]]))];
function shoulderT(a=.2){
 const nodes=G.nodes;let i=1;for(let j=2;j<nodes.length-2;j++)if(nodes[j].r>nodes[i].r)i=j;
 return clamp((NC+i/(nodes.length-1)*(NSP-1))/(NS-1)+a,.3,.8);
}
const defaults=type=>{const L=LIB[type];return{type,t:L.category==='mouths'?1:type.startsWith('tail_')?.12:type==='eye_triad'?.92:type==='sac_spitter'?1:type.startsWith('arm_')?shoulderT():['wing_glider','wing_insect'].includes(type)?shoulderT(.14):(L.leg||L.fittedLeg)?.5:.62,ang:L.category==='mouths'||type==='eye_triad'?0:(L.leg||L.fittedLeg)?2.1:L.category==='wings'?1.3:type.startsWith('arm_')?.95:0,...(L.leg?{w:L.w,k:[...L.k],f:[...L.f]}:{size:1}),...(L.len?{len:L.len}:{}),...(type==='cuerno'?{curve:.5}:{})}};
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
let G=JSON.parse(JSON.stringify(SEEDS.Merodeador)),mode='build',sel=null;
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
function mountRadius(t){const f=clamp(t*(NS-1),NC,NC+NSP-1),i=Math.min(f|0,NC+NSP-2);return lerp(RAD[i],RAD[i+1],f-i)}
const hasLeg=p=>LIB[p.type].leg||LIB[p.type].fittedLeg;
const centered=p=>!hasLeg(p)&&Math.abs(Math.sin(p.ang))<.14;
function buildParts(freeze){clear(partsG);clear(limbs);objs=[];legs=[];
  /* con patas, la altura del cuerpo es la que marca la columna y cada pata se estira hasta el suelo; sin patas, el cuerpo se posa */
  if(!freeze){let bottom=1e9;for(let i=0;i<NS;i++)bottom=Math.min(bottom,rest[i].y-RAD[i]);off=G.parts.some(hasLeg)?Math.max(0,.03-bottom):.03-bottom}
  for(const p of G.parts){const L=LIB[p.type];
    for(const sg of centered(p)?[1]:[1,-1]){anchor(rest,p.t,sg*p.ang,A1);const o=[A1.p.x,A1.p.y,A1.p.z];
      if(L.leg||L.fittedLeg){const pose=L.fittedLeg?fittedPose(p,A1.p.y+off,mountRadius(p.t)):{...p,k:[...p.k],f:[...p.f]};pose.f[1]=-(A1.p.y+off)+pose.w*.6;pose.k[1]=Math.max(pose.k[1],pose.f[1]+.12);const[a,b]=legLens(pose),m=legMeshes(pose,o,a,b);if(L.fittedLeg)for(const part of [m.up,m.lo,m.ft])part.scale.x=sg;limbs.add(m.up,m.lo,m.ft);for(const q of[m.up,m.lo,m.ft])q.traverse(x=>x.userData.part=p);
        legs.push({p,pose,sg,...m,a,b,w:pose.w,home:V(),foot:V(),from:V(),sw:false,grp:0,front:false})}
      else{const g=L.make(p,o,mountRadius(p.t),{head:G.nodes.at(-1).r,body:Math.max(...G.nodes.map(n=>n.r)),height:A1.p.y+off,mouthHeight:G.nodes.at(-1).y+off});if(!L.glb&&!L.responsive&&L.category==='mouths'){const inner=new T.Group();inner.position.z=-.3*p.size;inner.add(...g.children.slice());g.add(inner)}g.traverse(x=>x.userData.part=p);partsG.add(g);objs.push({p,sg,g})}}}
  layout(freeze)}
function layout(freeze){/* altura del cuerpo, postura de reposo de cada pata y reparto de la zancada */
  let bottom=1e9,low=1e9;for(let i=0;i<NS;i++)bottom=Math.min(bottom,rest[i].y-RAD[i]);
  for(const l of legs){anchor(rest,l.p.t,l.sg*l.p.ang,A1);l.h0=A1.p.clone();l.rk=V(l.pose.k[0]*l.sg,l.pose.k[1],l.pose.k[2]);l.rf=V(l.pose.f[0]*l.sg,l.pose.f[1],l.pose.f[2]);l.sole=A1.p.y+l.rf.y-l.w*.6;low=Math.min(low,l.sole);
    const fd=l.rf.clone().normalize();l.pole=l.rk.clone().addScaledVector(fd,-l.rk.dot(fd));if(l.pole.length()<.03)l.pole.set(0,0,1);l.pole.normalize();l.home.set(A1.p.x+l.rf.x,0,A1.p.z+l.rf.z)}
  let st=1e9;for(const l of legs){l.hang=Math.max(0,l.sole+off);const L=l.a+l.b,hh=l.h0.y+off-l.w*.6-l.hang,mh=Math.sqrt(Math.max(L*L-hh*hh,0));if(l.hang<.08)st=Math.min(st,1.25*L,2.9*mh)}
  stride=st<1e8?Math.max(.25,st):1;
  const ts=[...new Set(legs.map(l=>l.p.t))].sort((a,b)=>a-b);for(const l of legs){const k=ts.indexOf(l.p.t);l.grp=(k+(l.sg>0?0:1))%2;l.front=ts.length>1&&k>=ts.length/2}
  placeBody();for(const l of legs){poseAt(theta,l.home,l.foot);l.foot.y=(world?world.groundY(l.foot.x,l.foot.z):0)+l.hang}computeStats()}
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
function computeStats(){const P=G.parts,has=t=>P.filter(p=>p.type===t).length,m=P.filter(p=>LIB[p.type].category==='mouths'),lg=P.filter(hasLeg);
  let vol=0;for(let i=NC;i<NC+NSP-1;i++)vol+=RAD[i]*RAD[i]*rest[i].distanceTo(rest[i+1])*3.14;
  const avg=legs.length?legs.reduce((a,l)=>a+l.a+l.b,0)/legs.length*.95:0,sum=k=>P.reduce((a,p)=>a+(LIB[p.type].category==='mouths'?0:LIB[p.type][k]||0),0);
  stats={dna:P.reduce((a,p)=>a+LIB[p.type].cost,0)+Math.max(0,G.nodes.length-6)*5,
    vel:lg.length?clamp(Math.round(1.4+avg*.95+(lg.length===1?.5:0)-Math.max(0,vol-7)*.12),1,5):1,
    bite:clamp(Math.round(Math.max(0,...m.map(p=>LIB[p.type].bite||0))+sum('bite')),0,5),sing:clamp(Math.round(Math.max(0,...m.map(p=>LIB[p.type].sing||0))+sum('sing')),0,5),
    hp:clamp(Math.round(1+vol*.3+sum('hp')),1,5),warn:[!m.length&&'Sin boca no puede comer ni cantar',!has('ojo')&&!has('tallo')&&'Sin ojos va a ciegas',!lg.length&&'Sin patas se arrastra']};
  speed=lg.length?1+stats.vel*.55:.7;onStats()}
const ZA=V(0,0,1),rotH=new T.Mesh(new T.SphereGeometry(.1,14,10),new T.MeshBasicMaterial({color:0x9fd45c,depthTest:false,transparent:true}));rotH.renderOrder=22;rotH.visible=false;creature.add(rotH);
const _m=new T.Matrix4(),_q=new T.Quaternion(),_a=V(),_b=V(),_c=V(),_d=V(),_e=V(),DOWN=V(0,-1,0);
let world=null,worldTravel=0,worldTurn=0,tailLag=0,lookYaw=0;
function placeBody(bob){
 if(world){creature.position.set(world.x,world.groundY(world.x,world.z)+off+(bob||0),world.z);creature.rotation.set(world.pitch||0,world.yaw,world.roll||0,'YXZ')}
 else{creature.position.set(CX+RC*Math.cos(theta),off+(bob||0),RC*Math.sin(theta));creature.rotation.y=-theta}
 creature.updateMatrixWorld(true)
}
const poseAt=(th,loc,o)=>{
 if(world){o.set(loc.x,0,loc.z).applyAxisAngle(Y,world.yaw).add(_e.set(world.x,0,world.z));const lead=(th-theta)*RC;o.x+=Math.sin(world.yaw)*lead;o.z+=Math.cos(world.yaw)*lead;o.y=world.groundY(o.x,o.z);return o}
 return o.set(loc.x,0,loc.z).applyAxisAngle(Y,-th).add(_e.set(CX+RC*Math.cos(th),0,RC*Math.sin(th)))
};
const selAx={x:V(),y:V(),p:V(),n:V()};
function orient(g,A,sink,rot,tilt,keep){_b.copy(A.u).addScaledVector(A.n,-A.n.dot(A.u)).addScaledVector(A.t,A.n.dot(A.u));_b.addScaledVector(A.n,-_b.dot(A.n));if(_b.lengthSq()<1e-4)_b.copy(A.t);_b.normalize();_a.crossVectors(_b,A.n);if(keep){selAx.x.copy(_a);selAx.y.copy(_b);selAx.p.copy(A.p);selAx.n.copy(A.n)}_m.makeBasis(_a,_b,A.n);g.quaternion.setFromRotationMatrix(_m);if(rot)g.quaternion.multiply(_q.setFromAxisAngle(ZA,rot));if(tilt)g.quaternion.multiply(_q.setFromAxisAngle(X0,tilt));g.position.copy(A.p).addScaledVector(A.n,-sink)}
function update(dt){
  clock+=dt;grassU.uTime.value=clock;const test=mode==='test',sp=world?world.speed:test?speed*(run?1.8:1):0,freq=Math.max(.001,sp/stride),SW=.38;
  if(test){if(!world){theta+=sp*dt/RC;phase+=freq*dt}else{phase+=(worldTravel+Math.abs(worldTurn)*stride*.22)/stride;worldTravel=0;worldTurn=0} biteT=Math.max(0,biteT-dt);singT=Math.max(0,singT-dt)}
  const look=world?.lookTarget;
  let desiredLook=look?Math.atan2(look.x-world.x,look.z-world.z)-world.yaw:sp<.1?Math.sin(clock*.47)*Math.max(0,Math.sin(clock*.19))*.4:0;
  desiredLook=Math.atan2(Math.sin(desiredLook),Math.cos(desiredLook));
  lookYaw+=(clamp(desiredLook,-.65,.65)-lookYaw)*(1-Math.exp(-dt*5));
  tailLag+=((world?.turnRate||0)*-.12-tailLag)*(1-Math.exp(-dt*4));
  const w=phase*6.28318,len=rest[NS-1].distanceTo(rest[0]),amp=len*(legs.length?.03:.075),bob=test?Math.sin(clock*1.7)*.012+Math.sin(w*2)*.022*stride*Math.min(1,sp)+(singT>0?Math.abs(Math.sin(clock*9))*.18:0):0;
  for(let i=0;i<NS;i++){pts[i].copy(rest[i]);if(test){const q=1-i/(NS-1),k=Math.pow(q,1.4);pts[i].x+=Math.sin(w-3.2*q)*amp*(legs.length?k:1)+Math.sin(clock*1.3-2*q)*amp*.5*k;
    if(world){const neck=sstep(.68,1,i/(NS-1)),base=rest[Math.floor(NS*.68)],z=rest[i].z-base.z;pts[i].x+=Math.sin(lookYaw*neck)*z;pts[i].z+= (Math.cos(lookYaw*neck)-1)*z;pts[i].x+=tailLag*k*.35}
  }}
  fillTube(body.geometry,pts,RAD,RN,null,true,frames);placeBody(bob);
  const jawA=.06+.04*Math.sin(clock*2.1)+(biteT>0?Math.sin(Math.PI*biteT/.6)*.75:0)+(singT>0?.3+.25*Math.sin(clock*14):0),bl=Math.max(0,Math.sin(clock*1.6))**60;
  for(const o of objs){anchor(pts,o.p.t,o.sg*o.p.ang,A1);orient(o.g,A1,o.p.type.startsWith('tail_')?0:.015,(o.p.rot||0)*o.sg,o.p.tilt||0,o.p===sel&&o.sg===1);if(['body','upright'].includes(LIB[o.p.type].mount)){const upright=LIB[o.p.type].mount==='upright';_m.makeBasis(upright?X0:frames[Math.round(o.p.t*(NS-1))].s,upright?Y:A1.u,upright?ZA:A1.t);o.g.quaternion.setFromRotationMatrix(_m);if(o.p.rot)o.g.quaternion.multiply(_q.setFromAxisAngle(ZA,o.p.rot*o.sg));if(o.p.tilt)o.g.quaternion.multiply(_q.setFromAxisAngle(X0,o.p.tilt));o.g.scale.x=o.sg;}const ud=o.g.userData;
    if(ud.jaw)ud.jaw.rotation.x=jawA;if(ud.pinch)for(const q of ud.pinch)q.rotation.y=q.userData.sx*(.25-jawA*1.1);if(ud.lid)ud.lid.rotation.x=-.3+bl*1.5;if(ud.sway)ud.sway.rotation.x=Math.sin(clock*2.2+o.p.t*9)*.12;
    if(ud.wing){ud.wing.rotation.z=(test?.12+Math.sin(clock*(run?8:4))*.32:.12);ud.wing.rotation.y=(test?.12+.1*Math.sin(clock*2):.32)}
    if(ud.sacs)for(const sac of ud.sacs)sac.scale.setScalar(test?1+.07*Math.sin(clock*3.4):1);
    if(ud.arm)ud.arm.rotation.x=test?Math.sin(w+o.sg*Math.PI)*.26:0;
    if(ud.tail)ud.tail.rotation.y=test?Math.sin(w-1.2)*.12+tailLag:0;
  }
  const facing=world?world.yaw:-theta,fwd=_c.set(Math.sin(facing),0,Math.cos(facing));
  for(const l of legs){const ph=world&&sp<.015?SW:((phase+l.grp*.5)%1+1)%1,H=anchor(pts,l.p.t,l.sg*l.p.ang,A2).p.clone(),K=_u,A=_b;
    if(!test){K.copy(H).add(l.rk).applyMatrix4(creature.matrixWorld);A.copy(H).add(l.rf).applyMatrix4(creature.matrixWorld);H.applyMatrix4(creature.matrixWorld);l.sw=false}
    else{if(ph<SW){if(!l.sw){l.sw=true;l.from.copy(l.foot)}poseAt(theta+sp*((SW-ph)/freq+(1-SW)/freq*.5)/RC,l.home,_a);_a.y+=l.hang;const q=ph/SW;l.foot.lerpVectors(l.from,_a,q*q*(3-2*q));l.foot.y=(world?world.groundY(l.foot.x,l.foot.z):0)+l.hang+Math.sin(Math.PI*q)*.2*(l.a+l.b)}
      else{if(l.sw&&world)world.onFootContact?.(l.foot);l.sw=false;l.foot.y=(world?world.groundY(l.foot.x,l.foot.z):0)+l.hang}
      H.applyMatrix4(creature.matrixWorld);A.copy(l.foot);A.y+=l.w*.6;const dv=_d.subVectors(A,H);let d=dv.length();dv.normalize();
      // Terrain changes the reach required of a leg. Keep the sole at its
      // ground target and stretch the existing bones only as much as needed;
      // the flat studio path retains its original lengths and transforms.
      const extension=world?Math.max(1,(d+.01)/(l.a+l.b)):1,la=l.a*extension,lb=l.b*extension;
      if(world)l.up.scale.y=l.lo.scale.y=extension;
      d=clamp(d,.08,la+lb-.01);const x=(la*la-lb*lb+d*d)/(2*d),h=Math.sqrt(Math.max(la*la-x*x,0));
      const pole=_n.copy(l.pole).applyAxisAngle(Y,facing);pole.addScaledVector(dv,-pole.dot(dv));if(pole.lengthSq()<1e-4)pole.copy(fwd);pole.normalize();K.copy(H).addScaledVector(dv,x).addScaledVector(pole,h);A.copy(H).addScaledVector(dv,d)}
    l.up.position.copy(H);l.up.quaternion.setFromUnitVectors(DOWN,_t.subVectors(K,H).normalize());l.lo.position.copy(K);l.lo.quaternion.setFromUnitVectors(DOWN,_t.subVectors(A,K).normalize());
    l.ft.position.set(A.x,A.y-l.w*.6,A.z);l.ft.rotation.set(l.sw?-.5*Math.sin(Math.PI*clamp(ph/SW,0,1)):0,facing+l.sg*.18,0,'YXZ')}
  spineA=lerp(spineA,mode==='build'&&(spineOn||(getDrag()?.k==='node'))?1:0,1-Math.pow(.0004,dt));vertM.opacity=spineA*.96;cordM.opacity=spineA*.85;if(spineG)spineG.visible=spineA>.02;
  positionGrowth();
  const show=mode==='build'&&sel;selRings.forEach((r,i)=>{const sg=i?-1:1;r.visible=!!show&&(i===0||!centered(sel));if(!r.visible)return;anchor(pts,sel.t,sg*sel.ang,A1);r.position.copy(A1.p).addScaledVector(A1.n,.03);r.quaternion.setFromUnitVectors(V(0,0,1),A1.n);r.scale.setScalar(LIB[sel.type].leg?sel.w*2.4:.32*(sel.size||1))});
  rotH.visible=!!show&&!LIB[sel.type].leg;if(rotH.visible){const rr=.32*(sel.size||1),a=sel.rot||0;rotH.position.copy(selAx.p).addScaledVector(selAx.x,-Math.sin(a)*rr).addScaledVector(selAx.y,Math.cos(a)*rr).addScaledVector(selAx.n,.03)}
}

const growthG=new T.Group();creature.add(growthG);
const regionViews=new Map();let growthBuilds=0;
const regionDefaults={schema:CreatureGrowth.VERSION,family:'horns',seed:17,count:7,length:1,curve:.45,branches:1,surface:'torso',position:.6,coverage:.4,angle:.55,mirror:true};
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

return {
loader,SU,skinM,skinM2,boneM,toothM,beakM,eyeW,irisM,pupM,darkM,membraneM,gliderM,insectM,sacM,glowM,LIB,glbTemplates,materialSlots,assetFailures,NSP,NC,NS,RN,Y,pts,rest,frames,RAD,creature,partsG,handlesG,limbs,body,selRings,A1,A2,rotH,ZA,X0,DOWN,_a,_b,_c,_d,_e,_m,_q,_t,_s,_u,_n,selAx,PLBL,BUDGET,SEEDS,regionViews,regionDefaults,growthG,mesh,legLens,legMeshes,defaults,anchor,centered,hasLeg,buildParts,drawHandles,refresh,clear,update,rebuildGrowth,positionGrowth,orient,regionRange,
get G(){return G},set G(value){G=value},
get mode(){return mode},set mode(value){mode=value},
get sel(){return sel},set sel(value){sel=value},
get objs(){return objs},set objs(value){objs=value},
get legs(){return legs},set legs(value){legs=value},
get off(){return off},set off(value){off=value},
get theta(){return theta},set theta(value){theta=value},
get phase(){return phase},set phase(value){phase=value},
get clock(){return clock},set clock(value){clock=value},
get speed(){return speed},set speed(value){speed=value},
get stride(){return stride},set stride(value){stride=value},
get biteT(){return biteT},set biteT(value){biteT=value},
get singT(){return singT},set singT(value){singT=value},
get run(){return run},set run(value){run=value},
get stats(){return stats},set stats(value){stats=value},
get spineG(){return spineG},set spineG(value){spineG=value},
get spineOn(){return spineOn},set spineOn(value){spineOn=value},
get spineA(){return spineA},set spineA(value){spineA=value},
get growthBuilds(){return growthBuilds},set growthBuilds(value){growthBuilds=value},
 setWorld(pose){
  const travel=world?Math.hypot(pose.x-world.x,pose.z-world.z):0,reset=!world||travel>3;
  if(!reset){worldTravel+=travel;worldTurn+=Math.atan2(Math.sin(pose.yaw-world.yaw),Math.cos(pose.yaw-world.yaw))}
  else{worldTravel=worldTurn=0}
  world={...pose};mode='test';placeBody();
  if(reset)for(const l of legs){poseAt(theta,l.home,l.foot);l.foot.y+=l.hang;l.sw=false}
 },
 load(genome){G=structuredClone(genome);sel=null;phase=0;refresh(true);const s=G.skin;SU.cA.value.copy(lin(s.cA));SU.cB.value.copy(lin(s.cB));SU.cC.value.copy(lin(s.cC));SU.uPat.value=s.pat;SU.uWet.value=s.wet;SU.uScale.value=s.scale;skinM.clearcoat=skinM2.clearcoat=s.wet*.8;membraneM.clearcoat=s.wet*.12;update(0)},
};
}
