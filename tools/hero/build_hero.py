#!/usr/bin/env python3
"""Build web/hero/index.html: the valley reference with a creator creature in it.

P0 hero shot (docs/DESIGN.md §9, G45-G47). The two references stay untouched;
this script copies art/reference/valle-primigenio.html, patches its lighting
into one ACES pipeline with four time-of-day presets, and grafts the creature
code of art/reference/creador-de-criaturas.html onto it. Every patch asserts
that its target text exists, so a changed reference fails loudly.

URL parameters: t=golden|noon|overcast|night, cam=close|mid|far|vista,
creature=Merodeador|Zancuda|Babosa, exp=<exposure override>, live=1 (animate).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
VALLEY = (ROOT / "art/reference/valle-primigenio.html").read_text(encoding="utf-8")
CREATOR = (ROOT / "art/reference/creador-de-criaturas.html").read_text(encoding="utf-8")
OUT = ROOT / "web/hero/index.html"


def between(text, start, end, include_start=True):
    a = text.index(start)
    b = text.index(end, a)
    return text[a if include_start else a + len(start):b]


def patch(text, old, new, count=1):
    n = text.count(old)
    if n != count:
        sys.exit(f"patch target found {n}x (expected {count}): {old[:80]!r}")
    return text.replace(old, new)


# ---- creature code from the creator -------------------------------------
cr_lines = CREATOR.split("\n")
materials_geometry_lib = between(
    CREATOR, "/* ---------- materiales de la criatura ---------- */",
    "/* ---------- genoma ---------- */")
seeds = between(CREATOR, "const SEEDS={", "let G=JSON.parse")
creature = between(CREATOR, "/* ---------- criatura ---------- */",
                   "/* ---------- cámara ---------- */")
creature = patch(
    creature,
    "function placeBody(bob){creature.position.set(CX+RC*Math.cos(theta),off+(bob||0),RC*Math.sin(theta));creature.rotation.y=-theta;creature.updateMatrixWorld(true)}",
    "function placeBody(bob){creature.position.set(HERO.x,HERO.y+off+(bob||0),HERO.z);creature.rotation.y=HERO.yaw;creature.updateMatrixWorld(true)}")
creature = patch(creature, "clock+=dt;grassU.uTime.value=clock;", "clock+=dt;")

CREATURE_MODULE = r"""
<script>
/* Creature from art/reference/creador-de-criaturas.html, placed on the valley terrain. */
window.__heroBuild=function(env){
const T=env.T,scene=env.scene,V=(x,y,z)=>new T.Vector3(x,y,z),$=id=>document.getElementById(id);
const lerp=(a,b,t)=>a+(b-a)*t,clamp=(x,a,b)=>Math.min(b,Math.max(a,x)),sstep=(a,b,x)=>{x=clamp((x-a)/(b-a),0,1);return x*x*(3-2*x)};
const lin=h=>new T.Color(h).convertSRGBToLinear();
const CX=0,RC=7,HP=window.__heroParams,HX=env.W.p.x+Math.sin(env.W.p.a)*10,HZ=env.W.p.z+Math.cos(env.W.p.a)*10,SAZ=Math.atan2(env.SUN.x,env.SUN.z),CAZ=SAZ+(+(new URLSearchParams(location.search).get('sunside')||1.1)),HERO={x:HX,z:HZ,y:env.groundY(HX,HZ),yaw:CAZ-HP.yaw};
let mode='hero',sel=null,drag=null;const drawStats=()=>{};
""" + materials_geometry_lib + seeds + "let G=JSON.parse(JSON.stringify(SEEDS[HP.creature]||SEEDS.Merodeador));\n" + creature + r"""
/* environment light for the physical materials only: the toon world keeps its own */
{const L=window.__heroLight,es=new T.Scene(),sg=new T.SphereGeometry(50,32,20),p=sg.attributes.position,c=new Float32Array(p.count*3),
   hz=new T.Color(...L.envHz),mid=new T.Color(...L.envMid),top=new T.Color(...L.envTop),gd=new T.Color(...L.envGd),tc=new T.Color();
 for(let i=0;i<p.count;i++){const h=p.getY(i)/50;if(h<0)tc.copy(hz).lerp(gd,sstep(0,.15,-h));else tc.copy(hz).lerp(mid,sstep(0,.3,h)).lerp(top,sstep(.25,.95,h));c.set([tc.r,tc.g,tc.b],i*3)}
 sg.setAttribute('color',new T.BufferAttribute(c,3));es.add(new T.Mesh(sg,new T.MeshBasicMaterial({vertexColors:true,side:T.BackSide})));
 const sm=new T.Mesh(new T.SphereGeometry(5,16,12),new T.MeshBasicMaterial({color:new T.Color(...L.envSun)}));sm.position.copy(env.SUN).multiplyScalar(44);es.add(sm);
 const pm=new T.PMREMGenerator(env.renderer),tex=pm.fromScene(es,.03).texture;pm.dispose();
 for(const m of[skinM,skinM2,boneM,toothM,beakM,eyeW,irisM,pupM,darkM,glowM]){m.envMap=tex;m.needsUpdate=true}}
const s=G.skin;SU.cA.value.copy(lin(s.cA));SU.cB.value.copy(lin(s.cB));SU.cC.value.copy(lin(s.cC));SU.uPat.value=s.pat;SU.uWet.value=s.wet;SU.uScale.value=s.scale;skinM.clearcoat=skinM2.clearcoat=s.wet*.8;
refresh(true);update(0);
env.W.p.vis.root.visible=false;
/* tighter shadow frustum around the hero creature */
{const sc=env.sun.shadow.camera;sc.left=sc.bottom=-22;sc.right=sc.top=22;sc.updateProjectionMatrix();env.sun.shadow.normalBias=.05;if(window.__heroLight.shR)env.sun.shadow.radius=window.__heroLight.shR;env.sun.shadow.bias=-.0004}
const CAM={close:[7.5,.10],mid:[13,.16],far:[30,.22],vista:[125,.40]}[HP.cam]||[13,.16];
/* Choose the lowest broad saddle in the actual bowl, looking out from the hero.
   Average across a 20-degree opening so a narrow notch cannot win the view. */
let vistaAz=CAZ,vistaHorizon=Infinity;
if(HP.cam==='vista')for(let k=0;k<96;k++){
 const a=k*Math.PI*2/96;let horizon=0;
 for(const da of[-.17,0,.17]){let ridge=0;
  for(let d=160;d<=460;d+=12){const x=HX-Math.sin(a+da)*d,z=HZ-Math.cos(a+da)*d;
   if(Math.max(Math.abs(x),Math.abs(z))>318)break;
   ridge=Math.max(ridge,(env.groundY(x,z)-HERO.y)/d)}horizon+=ridge/3}
 const cameraGround=env.groundY(HX+Math.sin(a)*115,HZ+Math.cos(a)*115);
 horizon+=Math.max(0,cameraGround-HERO.y-35)*.01;
 // Keep both the creature and nest clear of foreground tree crowns.
 const eye=V(HX+Math.sin(a)*115,HERO.y+3+Math.sin(CAM[1])*CAM[0],HZ+Math.cos(a)*115);
 for(const target of[V(HX,HERO.y+2,HZ),V(env.W.spawn[0],env.groundY(...env.W.spawn)+1,env.W.spawn[1])]){
  const dx=eye.x-target.x,dz=eye.z-target.z,len2=dx*dx+dz*dz;
  for(const o of env.vistaTrees){
   const t=((o.x-target.x)*dx+(o.z-target.z)*dz)/len2;if(t<=0||t>=1)continue;
   const y=target.y+t*(eye.y-target.y),r=4*o.s*(o.rk||1)+2;
   if(y<o.y-1||y>o.y+(o.k===1?14:10)*o.s+1)continue;
   const distance=Math.hypot(o.x-target.x-t*dx,o.z-target.z-t*dz);
   horizon+=Math.max(0,1-distance/r)*.4;
  }
 }
 if(horizon<vistaHorizon){vistaHorizon=horizon;vistaAz=a}
}
const OCC=env.hU.occ.value,_w=V();function feedOcc(){for(let k=0;k<8;k++){const i=NC+Math.round(k*(NSP-1)/7);_w.copy(pts[i]).applyMatrix4(creature.matrixWorld);OCC[k].set(_w.x,_w.y,_w.z,RAD[i]*1.05)}for(let k=0;k<4;k++){const l=legs[k];if(l){_w.copy(l.ft.position);OCC[8+k].set(_w.x,_w.y,_w.z,l.w*2.2)}else OCC[8+k].set(0,-999,0,0)}env.hU.center.value.set(HERO.x+(window.__heroCenterShift||0),0,HERO.z)}
window.__heroFrame=dt=>{if(window.Hero)Hero.frame++;if(HP.live)update(dt);feedOcc();
  const c=V(0,0,0);for(let i=0;i<NS;i++)c.add(pts[i]);c.multiplyScalar(1/NS).applyMatrix4(creature.matrixWorld);
  const a=HP.cam==='vista'?vistaAz:CAZ,cp=Math.cos(CAM[1]),d=CAM[0];const cam=env.camera;cam.fov=HP.cam==='vista'?62:42;
  cam.position.set(c.x+Math.sin(a)*cp*d,c.y+Math.sin(CAM[1])*d,c.z+Math.cos(a)*cp*d);
  cam.position.y=Math.max(cam.position.y,env.groundY(cam.position.x,cam.position.z)+.6);cam.lookAt(c.x,c.y+(HP.cam==='vista'?36:-.2),c.z);cam.updateProjectionMatrix()};
/* Capture hooks (tools/hero/capture_grid.cjs). The creature mask is the pixel difference between two renders:
   setCreatureVisible(false) hides the creature's pixels; with keepShadow=true it still casts its shadow and
   parts the grass, so the difference is the body only. setSkyFlat(true) paints the sky dome pure magenta
   (clouds hidden) so sky pixels can be told apart. Both are reversible. */
const maskedMats=new Set(),skyMagenta=new T.MeshBasicMaterial({color:new T.Color(1,0,1),side:T.BackSide,depthWrite:false,fog:false,toneMapped:false});let skyOrig=null;
window.Hero={ready:true,frame:0,params:HP,light:window.__heroLight.name,creature:G.name,trees:window.__heroTrees,
  vista:{azimuth:vistaAz,selectionScore:vistaHorizon},
  setMountainDebug:env.setMountainDebug,
  mountainGeometrySamples(){
    const ray=new T.Raycaster(),bowl=scene.getObjectByName('bowl-terrain'),samples=[];
    for(const y of[.99,.9,.7,.4,0])for(const x of[-.9,-.6,-.3,0,.3,.6,.9]){
      ray.setFromCamera(new T.Vector2(x,y),env.camera);const hit=ray.intersectObject(bowl)[0];
      if(hit)samples.push({ndc:[x,y],height:hit.point.y,distance:hit.distance,position:hit.point.toArray()});
    }return samples;
  },
  setCreatureVisible(v,keepShadow){
    for(const m of maskedMats){m.colorWrite=m.depthWrite=true}maskedMats.clear();
    creature.visible=limbs.visible=v||!!keepShadow;
    if(!v&&keepShadow)for(const root of[creature,limbs])root.traverse(o=>{if(!o.material)return;for(const m of[].concat(o.material)){m.colorWrite=m.depthWrite=false;maskedMats.add(m)}})},
  setSkyFlat(v){if(v&&!skyOrig){skyOrig=env.sky.material;env.sky.material=skyMagenta}else if(!v&&skyOrig){env.sky.material=skyOrig;skyOrig=null}
    for(const c of env.clouds)c.visible=!v}};
};
</script>
"""

# ---- lighting presets ----------------------------------------------------
PRESETS = r"""
<script>
/* One ACES pipeline (G46). Golden hour is the look (G47); the others are checks.
   Fog/sky colours are display-space values, as in both references. */
(()=>{const q=new URLSearchParams(location.search),P={
 golden:{exp:1.0,air:{density:.00052,start:140,falloff:240,cool:[.36,.59,.86],warm:[.96,.73,.44]},sun:[-.62,.28,-.72],sunC:'#ffd2a0',sunI:3.1,hemi:['#bfe0ff','#6f8a4a',.5],fog:[.86,.88,.88],
   sky:{hz:[.95,.84,.70],mid:[.55,.72,.92],top:[.16,.42,.82],glow:[1,.62,.3],disc:3},
   envHz:[.9,.55,.3],envMid:[.32,.42,.62],envTop:[.08,.16,.4],envGd:[.12,.09,.06],envSun:[14,8,3.5],ramp:[54,54,83,83,108,108],grass:[1.04,.95,.80]},
 noon:{exp:1.0,air:{density:.00048,start:140,falloff:260,cool:[.43,.65,.91],warm:[.90,.88,.72]},sun:[-.4,.85,-.35],sunC:'#fff2dc',sunI:3.0,hemi:['#bfe0ff','#6f8a4a',.6],fog:[.78,.90,.96],
   sky:{hz:[.78,.90,.96],mid:[.34,.58,.92],top:[.07,.27,.74],glow:[1,.85,.6],disc:3},
   envHz:[.7,.8,.9],envMid:[.4,.55,.8],envTop:[.15,.3,.7],envGd:[.15,.17,.1],envSun:[16,15,13],ramp:[54,54,83,83,108,108],grass:[1,1,1]},
 overcast:{exp:1.1,air:{density:.00085,start:110,falloff:210,cool:[.54,.65,.79],warm:[.81,.79,.69]},sun:[-.3,.8,-.4],sunC:'#e8eef2',sunI:.35,hemi:['#d3dbe2','#6a7060',2.2],fog:[.74,.77,.80],shade:.3,pcf:1,shR:7,
   sky:{hz:[.76,.79,.82],mid:[.66,.69,.73],top:[.55,.58,.63],glow:[.2,.2,.2],disc:0},
   envHz:[.6,.62,.65],envMid:[.55,.57,.6],envTop:[.5,.52,.56],envGd:[.12,.12,.1],envSun:[1.5,1.5,1.5],ramp:[54,54,83,83,108,108],grass:[.78,.82,.84]},
 night:{exp:1.25,air:{density:.0006,start:120,falloff:240,cool:[.055,.09,.19],warm:[.16,.18,.28]},sun:[.4,.55,.3],sunC:'#9fb4ff',sunI:.7,hemi:['#2a3a60','#151a20',.6],fog:[.07,.09,.16],
   sky:{hz:[.10,.13,.22],mid:[.05,.07,.15],top:[.02,.03,.08],glow:[.3,.35,.5],disc:1.2},
   envHz:[.06,.08,.14],envMid:[.04,.05,.1],envTop:[.02,.02,.06],envGd:[.02,.02,.02],envSun:[2,2.3,3],ramp:[54,54,83,83,108,108],grass:[.16,.2,.32]}};
 const name=P[q.get('t')]?q.get('t'):'golden',L=Object.assign({name},P[name]);if(q.get('exp'))L.exp=+q.get('exp');
 const v=a=>'vec3('+a.map(x=>(+x).toFixed(3)).join(',')+')',s=L.sky;
 L.shK=(+(1-.58*(L.shade==null?1:L.shade)).toFixed(3));
 L.skyGLSL='vec3 c=mix('+v(s.hz)+','+v(s.mid)+',smoothstep(0.,.28,h));c=mix(c,'+v(s.top)+',smoothstep(.2,.95,h));float s=max(dot(n,sun),0.);c+='+v(s.glow)+'*pow(s,7.)*.55+vec3(1.,.97,.9)*smoothstep(.9988,.9995,s)*'+(+s.disc).toFixed(2)+';';
 window.__heroLight=L;
 window.__heroParams={creature:q.get('creature')||'Merodeador',cam:q.get('cam')||'mid',yaw:+(q.get('yaw')||2.2),live:q.get('live')==='1'};
 window.__heroFreeze=true;window.__heroTime=q.get('live')==='1'?null:3;})();
</script>
"""

# ---- valley patches ------------------------------------------------------
h = VALLEY
h = patch(h, "<title>Valle Primigenio</title>", "<title>Primigenia hero shot</title>")
h = patch(h, '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>',
          PRESETS + '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
          + "\n<style>body #stage>*:not(#view),body aside,#hudc{display:none!important}</style>")
h = patch(h, "const T=THREE,$=id=>document.getElementById(id);",
          "const T=THREE,$=id=>document.getElementById(id),HL=window.__heroLight;")
h = patch(h, "renderer.outputEncoding=T.sRGBEncoding;renderer.shadowMap.type=T.PCFSoftShadowMap;",
          "renderer.outputEncoding=T.sRGBEncoding;renderer.shadowMap.type=HL.pcf?T.PCFShadowMap:T.PCFSoftShadowMap;"
          "renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=HL.exp;")
h = patch(h, "const SUN=new T.Vector3(-.55,.5,-.5).normalize();", "const SUN=new T.Vector3(...HL.sun).normalize();")
h = patch(h, "new Uint8Array([120,120,185,185,240,255])", "new Uint8Array(HL.ramp)")
h = patch(h, "scene.add(new T.HemisphereLight(col(low?'#cfe4ff':'#bfe0ff'),col(low?'#7a6a48':'#6f8a4a'),low?.75:.72));",
          "scene.add(new T.HemisphereLight(col(HL.hemi[0]),col(HL.hemi[1]),HL.hemi[2]));")
h = patch(h, "sun=new T.DirectionalLight(col(low?'#ffffff':'#fff0d2'),low?.9:1.2);",
          "sun=new T.DirectionalLight(col(HL.sunC),HL.sunI);")
h = patch(h, "gl_FragColor=vec4(mix(c,fogColor,smoothstep(fogNear,fogFar,vD)),1.);}",
          "c*=vec3(${HL.grass.join(',')});gl_FragColor=vec4(mix(c,fogColor,smoothstep(fogNear,fogFar,vD)),1.);}")
h = patch(h, "const FOGC=[.78,.90,.96];", "const FOGC=HL.fog;")
h = patch(h, "scene.fog=new T.Fog(col('#c7e6f5'),110,760);", "scene.fog=new T.Fog(new T.Color(...HL.fog),110,760);")
h = patch(h, "vec3 c=mix(vec3(.78,.90,.96),vec3(.16,.42,.82),pow(h,.6));float s=max(dot(n,sun),0.);c+=vec3(1.,.85,.6)*pow(s,5.)*.3+vec3(1.,.97,.88)*smoothstep(.9985,.9994,s);",
          "'+HL.skyGLSL+'")
h = patch(h, "W.p.vis=buildCreature(W.p.g,low);scene.add(W.p.vis.root);",
          "W.p.vis=buildCreature(W.p.g,low);scene.add(W.p.vis.root);"
          "if(window.__heroBuild&&!low)window.__heroBuild({T,scene,renderer,camera,groundY,W,SUN,sun});")
h = patch(h, "  renderer.render(scene,camera);\n}\n\n/* ---------- HUD",
          "  if(window.__heroFrame&&!low)window.__heroFrame(frameDt||0);renderer.render(scene,camera);\n}\n\n/* ---------- HUD")
h = patch(h, "for(const c of clouds){c.position.x+=(frameDt||0)*3;",
          "for(const c of clouds){c.position.x+=(window.__heroTime!=null?0:frameDt||0)*3;")
h = patch(h, "acc+=dt;while(acc>=DT)", "acc+=window.__heroFreeze?0:dt;while(acc>=DT)")
h = patch(h, "uTime.value+=frameDt||0;",
          "uTime.value=window.__heroTime!=null?window.__heroTime:uTime.value+(frameDt||0);")
h = patch(h, "<script>\n(()=>{\nconst T=THREE", CREATURE_MODULE + "<script>\n(()=>{\nconst T=THREE")


# ---- V1-V3: grass lit by the terrain normal, shadowed and pushed by the creature, gust bands ----
h = patch(h, "hU={hmap:{value:null},", "hU={occ:{value:[...Array(12)].map(()=>new T.Vector4())},hmap:{value:null},")
h = patch(h, "attribute vec3 offset;uniform vec3 center;uniform float uTime;varying float vH;varying vec3 vT;varying float vD;void main(){const float R=44.;",
          "attribute vec3 offset;uniform vec3 center;uniform float uTime;uniform vec4 occ[12];uniform vec3 sun;varying float vH;varying vec3 vT;varying float vD;varying float vL;varying float vS;varying float vBk;void main(){const float R=44.;")
h = patch(h, "vec3 p=position;float bend=(.12+.2*gust)*p.y*p.y*hg,wd=.2*(.6+rnd)*step(.02,hg);",
          "float hx=samp(base+vec2(1.,0.)).r-samp(base-vec2(1.,0.)).r,hz=samp(base+vec2(0.,1.)).r-samp(base-vec2(0.,1.)).r;vec3 gn=normalize(vec3(-hx,2.,-hz));vL=max(dot(gn,sun),0.);"
          "vec3 gp=vec3(base.x,t.r,base.y);float sh=1.,push=0.;vec2 pd=vec2(0.);"
          "for(int i=0;i<12;i++){vec3 oc=occ[i].xyz-gp;float r=occ[i].w;if(r<=0.)continue;float tca=dot(oc,sun),d2=dot(oc,oc)-tca*tca;"
          "sh*=mix(1.,smoothstep(r*r*.5,r*r*1.4,d2),step(0.,tca));vec2 q=base-occ[i].xz;float dq=length(q),inf=(1.-smoothstep(r*.7,r*1.7,dq))*step(occ[i].y-r,t.r+.6);"
          "push=max(push,inf);pd+=q/(dq+1e-3)*inf;}vS=sh;hg*=1.-.6*push;"
          "float band=smoothstep(.55,1.,sin(dot(base,vec2(.8,.6))*.045-uTime*1.1));"
          "vec3 p=position;float bend=(.12+.2*gust+.3*band)*p.y*p.y*hg,wd=.2*(.6+rnd)*step(.02,hg);")
h = patch(h, "vH=p.y;vT=vec3(t.b,t.a,gust);",
          "wp.x+=pd.x*p.y*hg*.9;wp.z+=pd.y*p.y*hg*.9;vBk=pow(max(dot(normalize(wp-cameraPosition),sun),0.),4.)*p.y;vH=p.y;vT=vec3(t.b,t.a,gust*.35+band*1.3);")
h = patch(h, "fragmentShader:`uniform vec3 fogColor;uniform float fogNear,fogFar;varying float vH;varying vec3 vT;varying float vD;void main(){",
          "fragmentShader:`uniform vec3 fogColor;uniform float fogNear,fogFar;varying float vH;varying vec3 vT;varying float vD;varying float vL;varying float vS;varying float vBk;void main(){")
h = patch(h, "vec3 c=mix(b,tp,vH*vH)*mix(.5,1.,vT.y)+vec3(.12,.13,.03)*max(vT.z,0.)*vH;",
          "vec3 c=mix(b,tp,vH*vH)*mix(.5,1.,vT.y)*mix(.62,1.12,vL)*mix(${HL.shK},1.,vS)+vec3(.12,.13,.03)*max(vT.z,0.)*vH+vec3(1.,.78,.45)*vBk*.3*vS;")
h = patch(h, "window.__heroBuild({T,scene,renderer,camera,groundY,W,SUN,sun});", "window.__heroBuild({T,scene,renderer,camera,groundY,W,SUN,sun,hU,sky,clouds,setMountainDebug,vistaTrees:[...broad,...conif]});")


# ---- BotW-style meadow: thin dense blades, soft root, large colour patches ----
h = patch(h, "const RG=44,NB=80000,", "const RG=44,NB=200000,")
h = patch(h, "wd=.2*(.6+rnd)*step(.02,hg);", "wd=.1*(.6+rnd)*step(.02,hg);")
h = patch(h, "vec3 b=mix(vec3(.17,.40,.10),vec3(.33,.55,.13),vT.x),tp=mix(vec3(.40,.68,.18),vec3(.66,.80,.28),vT.x);",
          "vec3 b=mix(vec3(.30,.52,.13),vec3(.42,.60,.16),vT.x),tp=mix(vec3(.46,.70,.20),vec3(.70,.78,.30),vT.x);"
          "float pt=smoothstep(.5,.78,vT.x);b=mix(b,vec3(.50,.55,.20),pt*.6);tp=mix(tp,vec3(.80,.78,.36),pt*.7);")
h = patch(h, "vec3 c=mix(b,tp,vH*vH)*mix(.5,1.,vT.y)*mix(.62,1.12,vL)*mix(${HL.shK},1.,vS)+vec3(.12,.13,.03)*max(vT.z,0.)*vH",
          "vec3 c=mix(b,tp,.25+.75*vH)*mix(.5,1.,vT.y)*mix(.62,1.12,vL)*mix(${HL.shK},1.,vS)+vec3(.17,.17,.07)*max(vT.z,0.)*vH")


# ---- V4: leaf-card canopies on darker blob cores, per-tree hue, backlit glow ----
LEAF_JS = r"""
let leafTex=null,leafMat=null;
function leafTexture(){if(leafTex)return leafTex;const c=document.createElement('canvas');c.width=c.height=128;const x=c.getContext('2d'),r=rngFrom(77);x.fillStyle='#fff';
  for(let i=0;i<11;i++){const a=r()*6.283,d=8+r()*34,px=64+Math.cos(a)*d,py=64+Math.sin(a)*d;x.save();x.translate(px,py);x.rotate(a+(r()-.5));x.beginPath();x.ellipse(0,0,15+r()*7,7+r()*3,0,0,6.283);x.fill();x.restore()}
  leafTex=new T.CanvasTexture(c);return leafTex}
function leafMaterial(){if(leafMat)return leafMat;leafMat=toon({vertexColors:true,map:leafTexture(),alphaTest:.5,side:T.DoubleSide},true);const ob=leafMat.onBeforeCompile;
  leafMat.onBeforeCompile=s=>{ob(s);s.fragmentShader=s.fragmentShader.replace('float rim=pow(1.-max(dot(normalize(vViewPosition),normal),0.),3.);','float rim=0.;').replace('#include <normal_fragment_begin>',T.ShaderChunk.normal_fragment_begin.split('normal = normal * faceDirection;').join('')).replace('#include <tonemapping_fragment>',
   '#if NUM_DIR_LIGHTS>0\nfloat bk=pow(max(dot(-normalize(vViewPosition),directionalLights[0].direction),0.),4.);gl_FragColor.rgb+=diffuseColor.rgb*directionalLights[0].color*bk*.22;\n#endif\n#include <tonemapping_fragment>')};
  leafMat.customProgramCacheKey=()=>'leafw';return leafMat}
function leafCanopy(blobs){const pos=[],nor=[],uv=[],cl=[],idx=[],r=rngFrom(4242),q=new T.Quaternion(),e=new T.Euler(),v=new T.Vector3(),up=new T.Vector3(0,1,0);
  for(const[c,sc,hex,dn]of blobs){const base=col(hex),n=Math.round(62*sc[0]*(dn||1));
    for(let i=0;i<n;i++){let dx=r()*2-1,dy=r()*2-1,dz=r()*2-1;const l=Math.hypot(dx,dy,dz)||1;dx/=l;dy/=l;dz/=l;dy=dy*.8+.2;
      const rad=.82+r()*.26,p=[c[0]+dx*sc[0]*rad,c[1]+dy*sc[1]*rad,c[2]+dz*sc[2]*rad],sz=1.0+r()*.5;
      const nn=new T.Vector3(dx/sc[0],dy/sc[1]+.35,dz/sc[2]).normalize();
      e.set(r()*6.283,r()*6.283,r()*6.283);q.setFromEuler(e);const k=pos.length/3;
      const ao=.5+.45*Math.max(0,Math.min(1,dy*.5+.5))*rad,tint=.9+r()*.2;
      for(const[ux,uy]of[[0,0],[1,0],[1,1],[0,1]]){v.set((ux-.5)*sz,(uy-.5)*sz,0).applyQuaternion(q);pos.push(p[0]+v.x,p[1]+v.y,p[2]+v.z);nor.push(nn.x,nn.y,nn.z);uv.push(ux,uy);cl.push(base.r*ao*tint,base.g*ao*tint,base.b*ao)}
      idx.push(k,k+1,k+2,k,k+2,k+3)}}
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(pos,3));g.setAttribute('normal',new T.Float32BufferAttribute(nor,3));g.setAttribute('uv',new T.Float32BufferAttribute(uv,2));g.setAttribute('color',new T.Float32BufferAttribute(cl,3));g.setIndex(idx);return g}
const hueJit=o=>{const h=Math.sin(o.x*12.9898+o.z*78.233)*43758.5453,f=h-Math.floor(h);return new T.Color().setHSL(.0,0,1).multiplyScalar(1).setRGB(.88+.2*f,.92+.14*Math.sin(f*9),.8+.3*(1-f))};
"""
h = patch(h, "function buildScene(){", LEAF_JS + "function buildScene(){")
BROAD_OLD = "scene.add(scatter(merged([[tr,'#5a4030',[.45,4.4,.45],[0,0,0]],[ico2,'#4f9a2e',[2.9,2.3,2.9],[0,5.4,0],0,1],[ico2,'#62ad38',[2.1,1.8,2.1],[1.7,4.5,.7],0,1],[ico2,'#3f8a2c',[2.2,1.8,2.2],[-1.5,4.6,-.8],0,1],[ico2,'#74bb44',[1.7,1.4,1.7],[.2,6.9,-.4],0,1],[ico2,'#58a334',[1.6,1.3,1.6],[-.4,5,1.7],0,1]]),broad,true,TV()));"
# V5: three broadleaf shapes (round, poplar, gnarled), chosen per tree from a hash of its position.
# The hash is pure arithmetic on x,z: it never touches the valley's dr() stream, so nothing else moves.
TREES_JS = r"""
{const cn0=new T.ConeGeometry(1,1,6).translate(0,.5,0),
 /* flared base: n buttress cones start inside the trunk and run outward and slightly down into the soil */
 roots=(n,r0,len,thick,hex,a0)=>{const o=[];for(let i=0;i<n;i++){const a=a0+i*6.283/n+(i%2)*.35,j=((i*7)%5)/4;o.push([cn0,hex,[thick*(.8+.4*j),len*(.8+.4*(1-j)),thick],[Math.cos(a)*r0,.6,Math.sin(a)*r0],[0,-a,-1.8]])}return o},
 /* blob = [centre, radii, core colour, leaf colour, card density]; a dark ico core carries the leaf cards */
 mk=(trunk,blobs)=>({core:merged([...trunk,...blobs.map(([c,s,ch])=>[ico2,ch,s.map(v=>v*.88),c,0,1])]),leaves:leafCanopy(blobs.map(([c,s,,lh,d])=>[c,s,lh,d]))}),
 KINDS=[
  {sc:1,rk:1,...mk([[tr,'#5a4030',[.45,4.4,.45],[0,0,0]],...roots(5,.22,1.7,.4,'#4d3626',.3)],
   [[[0,5.4,0],[2.9,2.3,2.9],'#2f6a22','#3f8226'],[[1.7,4.5,.7],[2.1,1.8,2.1],'#356f24','#4c9430'],[[-1.5,4.6,-.8],[2.2,1.8,2.2],'#2b6420','#367a26'],[[.2,6.9,-.4],[1.7,1.4,1.7],'#3a7628','#5a9e36'],[[-.4,5,1.7],[1.6,1.3,1.6],'#336c22','#468a2c']])},
  /* tall narrow poplar: slim straight trunk, stacked columnar blobs */
  {sc:.8,rk:.55,...mk([[tr,'#6a5a48',[.26,5.4,.26],[0,0,0]],...roots(4,.14,1.1,.26,'#55483a',1.1)],
   [[[0,6.2,0],[1.35,2.4,1.35],'#2c6322','#3f8a2a',1.7],[[.15,8.4,-.1],[1.25,2.5,1.25],'#2f6a24','#4a9632',1.7],[[-.1,10.6,.1],[1.0,2.2,1.0],'#336f26','#559f38',1.7],[[.1,12.4,0],[.65,1.6,.65],'#3a7a2a','#68ae42',1.7],[[.6,5.4,.4],[.95,1.5,.95],'#285c20','#37802a',1.5],[[-.6,5,-.4],[.95,1.4,.95],'#285c20','#3a842c',1.5]])},
  /* wide low gnarled tree: thick leaning trunk, two limbs, flat spreading canopy */
  {sc:.85,rk:1.3,...mk([[tr,'#4a3626',[.8,3.8,.8],[0,0,0],[0,0,-.3]],[tr,'#4a3626',[.42,2.7,.42],[.55,2.4,.1],[0,0,.85]],[tr,'#4a3626',[.38,2.3,.38],[.7,2.9,.2],[.8,0,0]],...roots(6,.4,2.6,.75,'#42301f',.2)],
   [[[1.1,4.5,.1],[3.4,1.15,3.1],'#2d6422','#3e7f27',1.1],[[-1.9,4.6,.6],[2.7,1.0,2.5],'#32692a','#487f2e',1.1],[[.7,4.9,2.2],[2.6,1.0,2.4],'#2b6220','#3b7a26',1.1],[[2.4,4.2,-1.9],[2.3,.9,2.2],'#336e26','#4d8e30',1.1],[[-.5,5.2,-1.3],[2.4,.9,2.3],'#2f6824','#52943a',1.1]])}],
 kindOf=o=>{const q=Math.sin(o.x*37.719+o.z*11.131)*24634.6345,f=q-Math.floor(q);return f<.4?0:f<.7?1:2};
 for(const o of broad){o.k=kindOf(o);o.s*=KINDS[o.k].sc;o.rk=KINDS[o.k].rk}
 KINDS.forEach((K,k)=>{const its=broad.filter(o=>o.k===k);
  /* poplar cores do not cast shadow-map shadows: low golden sun stretches them into thin lines that the grass
     (which only sees the height-map tree shadow) cannot receive, so they read as mown stripes on the meadow */
  scene.add(scatter(K.core,its,k!==1,TV()));
  const cm=scatter(K.leaves,its.map(o=>({...o,c:hueJit(o)})),false,leafMaterial());cm.receiveShadow=true;scene.add(cm)});
 window.__heroTrees=KINDS.map((K,k)=>broad.filter(o=>o.k===k).length)}
"""
BROAD_NEW = TREES_JS
h = patch(h, BROAD_OLD, BROAD_NEW)
h = patch(h, "for(const o of[...broad,...conif]){const r=3.6*o.s,cx=", "for(const o of[...broad,...conif]){const r=3.6*o.s*(o.rk||1),cx=")

# ---- V8: a continuous meadow, alpine relief and height-aware aerial perspective ----
# GLSL is assembled once here and shared by the ground, blades, water and all
# built-in materials. No height(), groundY(), scatter or simulation changes.
LAND_JS = r"""
const glv=a=>'vec3('+a.map(x=>Number(x).toFixed(4)).join(',')+')';
const AERIAL=`
vec3 aerial(vec3 c,vec3 wp){
 vec3 ray=wp-cameraPosition;float d=length(ray);vec3 dir=ray/max(d,.001);
 // Three samples of the exponential height density along the view ray.
 vec3 heights=max(vec3(cameraPosition.y,mix(cameraPosition.y,wp.y,.5),wp.y),vec3(0.));
 vec3 rho=exp(-heights/${HL.air.falloff.toFixed(1)});
 float path=max(d-${HL.air.start.toFixed(1)},0.);
 float optical=path*(1.-exp(-path/240.))*${HL.air.density.toFixed(6)}*dot(rho,vec3(.1667,.6666,.1667));
 float sunward=pow(max(dot(dir,normalize(${glv(HL.sun)})),0.),3.);
 vec3 haze=mix(${glv(HL.air.cool)},${glv(HL.air.warm)},sunward);
 return mix(c,haze,1.-exp(-optical));
}
`;
T.ShaderChunk.fog_pars_vertex='#ifdef USE_FOG\nvarying vec3 vAerialPosition;\n#endif';
T.ShaderChunk.fog_vertex=`#ifdef USE_FOG
 vec4 aerialLocal=vec4(transformed,1.);
 #ifdef USE_INSTANCING
 aerialLocal=instanceMatrix*aerialLocal;
 #endif
 vAerialPosition=(modelMatrix*aerialLocal).xyz;
#endif`;
T.ShaderChunk.fog_pars_fragment='#ifdef USE_FOG\nvarying vec3 vAerialPosition;\n'+AERIAL+'\n#endif';
T.ShaderChunk.fog_fragment='#ifdef USE_FOG\ngl_FragColor.rgb=aerial(gl_FragColor.rgb,vAerialPosition);\n#endif';
const MEADOW=`
uniform vec3 sun,center;uniform vec4 occ[12];
float landHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float landNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(landHash(i),landHash(i+vec2(1.,0.)),f.x),mix(landHash(i+vec2(0.,1.)),landHash(i+1.),f.x),f.y);}
float meadowWave(vec2 p,float time){return smoothstep(.45,.98,sin(dot(p,vec2(.8,.6))*.085-time*1.1));}
float landRamp(float light){return .60+.25*smoothstep(.18,.25,light)+.23*smoothstep(.53,.61,light);}
// Linear light, followed by the same ACES + sRGB chunks for every surface.
// t.b is the exact CPU fbm patch field stored in the shared height map.
vec3 meadowColor(vec4 t,float light,float wave,vec2 xz){
 vec3 c=mix(vec3(.115,.265,.037),vec3(.235,.390,.075),smoothstep(.22,.80,t.b));
 c*=mix(.56,1.,t.a)*landRamp(light)*${glv(HL.grass)};
 return c*(.78+.30*landNoise(xz*.19)+.14*landNoise(xz*.63))*(1.+wave*.12);
}
float meadowShadow(vec3 wp){
 if(distance(wp.xz,center.xz)>24.)return 1.;
 float sh=1.;for(int i=0;i<12;i++){
  vec3 oc=occ[i].xyz-wp;float r=occ[i].w;if(r<=0.)continue;
  float tca=dot(oc,sun),d2=dot(oc,oc)-tca*tca;
  sh*=mix(1.,smoothstep(r*r*.5,r*r*1.4,d2),step(0.,tca));
 }return sh;
}
`;
function landMaterial(material){
 material.onBeforeCompile=s=>{
  Object.assign(s.uniforms,hU);
  s.vertexShader='attribute float cavity;varying float vCavity;varying vec3 vLandPosition,vLandNormal;\n'+s.vertexShader.replace('#include <begin_vertex>',
   '#include <begin_vertex>\nvLandPosition=position;vLandNormal=normal;vCavity=cavity;');
  s.fragmentShader='varying float vCavity;varying vec3 vLandPosition,vLandNormal;\nuniform float uTime;\n'+SAMP+MEADOW+s.fragmentShader;
  const output='gl_FragColor = vec4( outgoingLight, diffuseColor.a );';
  if(!s.fragmentShader.includes(output))throw new Error('land shader output target changed');
  s.fragmentShader=s.fragmentShader.replace(output,`
   vec3 wp=vLandPosition,gn=normalize(vLandNormal);float light=max(dot(gn,sun),0.);
   vec4 field=samp(wp.xz);
   bool backdrop=max(abs(wp.x),abs(wp.z))>S*.5;
   if(backdrop)field=vec4(wp.y,0.,landNoise(wp.xz*.008),1.);
   float wave=meadowWave(wp.xz,uTime);
   // A shaded, saturated base beneath the brighter blade mid-tone.
   vec3 meadow=meadowColor(field,light,wave,wp.xz)*vec3(.60,.68,.54)*mix(${HL.shK},1.,meadowShadow(wp));
   float grain=landNoise(wp.xz*.17);
   float mineral=landNoise(wp.xz*.023),erosion=landNoise(wp.xz*.081);
   float steep=1.-smoothstep(.48,.76,gn.y);
   float strata=sin(wp.y*(.075+.035*landNoise(wp.xz*.012))+erosion*6.+mineral*8.);
   strata*=steep*smoothstep(.40,.72,landNoise(wp.xz*.044));
   vec3 rock=mix(vec3(.17,.18,.19),vec3(.30,.225,.13),smoothstep(.25,.78,mineral));
   rock=mix(rock,vec3(.19,.135,.085),smoothstep(.57,.87,erosion)*.4);
   rock*=1.+strata*.045+(grain-.5)*.16+(landNoise(wp.xz*.63+wp.y*.04)-.5)*.10;
   float rockLight=.36+.56*smoothstep(.12,.22,light)+.48*smoothstep(.50,.60,light);
   rock*=mix(vec3(.78,.88,1.12),vec3(1.22,1.08,.86),smoothstep(.18,.52,light))*rockLight;
   rock*=mix(1.,.64,vCavity);
   // Scree collects on ledges, turf grows on gentle faces below the snow line.
   float ledge=smoothstep(.70,.90,gn.y);
   rock=mix(rock,vec3(.27,.23,.16)*rockLight,ledge*erosion*.24);
   float snow=smoothstep(120.,145.,wp.y+(grain-.5)*28.)*smoothstep(.48,.80,gn.y);
   if(backdrop)snow=smoothstep(480.,680.,wp.y+(grain-.5)*100.)*smoothstep(.34,.72,gn.y);
   rock=mix(rock,vec3(.73,.84,.91)*landRamp(light),snow);
   rock*=${glv(HL.grass)};
   // Alpine turf on gentle low slopes; the actual blade mask has priority.
   float turf=(1.-smoothstep(58.,118.,wp.y))*smoothstep(.74,.94,gn.y)*(1.-snow);
   vec3 land=mix(rock,meadow,turf);
   float shore=smoothstep(.7,2.4,wp.y);
   outgoingLight=mix(outgoingLight,land,backdrop?1.:shore);
   outgoingLight=mix(outgoingLight,meadow,field.g);
   ${output}`);
 };
 material.customProgramCacheKey=()=>'land-v9';return material;
}
// Debug colors bypass tone mapping, encoding and fog. R = N.L, G = cavity,
// B = bowl rock eligibility. Other scene objects remain depth occluders in black.
const mountainSaved=new Map(),mountainBlack=new T.MeshBasicMaterial({color:0,side:T.DoubleSide,fog:false,toneMapped:false}),
 mountainSkyBlack=new T.MeshBasicMaterial({color:0,side:T.DoubleSide,depthWrite:false,fog:false,toneMapped:false}),
 mountainDebug=new T.ShaderMaterial({side:T.DoubleSide,toneMapped:false,fog:false,uniforms:{sun:{value:SUN},minMountainDistance:{value:0}},
 vertexShader:'attribute float cavity;varying vec3 wp,gn;varying float cv;void main(){wp=position;gn=normal;cv=cavity;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',
 fragmentShader:SAMP+MEADOW+`uniform float minMountainDistance;varying vec3 wp,gn;varying float cv;
  void main(){
   vec3 n=normalize(gn);float d=distance(cameraPosition,wp),grain=landNoise(wp.xz*.17);
   float snow=smoothstep(120.,145.,wp.y+(grain-.5)*28.)*smoothstep(.48,.80,n.y);
   float turf=(1.-smoothstep(58.,118.,wp.y))*smoothstep(.74,.94,n.y)*(1.-snow);
   float eligible=step(20.,wp.y)*step(minMountainDistance,d)*(1.-step(500.,d))*(1.-step(.02,snow))*(1.-step(.10,turf))*(1.-step(.05,samp(wp.xz).g));
   gl_FragColor=vec4(max(dot(n,sun),0.),cv,eligible,1.);
  }`});
function setMountainDebug(enabled,minDistance=150){
 if(!enabled){for(const[o,s]of mountainSaved){o.material=s.material;o.visible=s.visible}mountainSaved.clear();return}
 if(mountainSaved.size)return;
 Object.assign(mountainDebug.uniforms,hU);mountainDebug.uniforms.minMountainDistance.value=minDistance;
 scene.traverse(o=>{if(!o.material)return;mountainSaved.set(o,{material:o.material,visible:o.visible});
  if(o.name==='bowl-terrain')o.material=mountainDebug;
  else if(o.name==='meadow-252k')o.visible=false;
  else o.material=o===sky?mountainSkyBlack:mountainBlack;
 });
}
function distantRanges(){
 // Render-only ring meshes: independent of the gameplay surface and its RNG.
 for(let layer=0;layer<3;layer++){
  const radius=[900,1550,2450][layer],segments=384,positions=[],indices=[];
  for(let row=0;row<4;row++)for(let i=0;i<=segments;i++){
   const a=i/segments*Math.PI*2,phase=a+layer*1.73;
   const ridge=1.-Math.abs(Math.sin(phase*5.+.5)*.55+Math.sin(phase*13.+1.7)*.29+Math.sin(phase*29.)*.16);
   const crown=Math.pow(ridge,2.3),peak=radius*(.17+crown*.20)+layer*50;
   const r=radius*[.75,.89,1.,1.17][row],y=[-70,peak*.46,peak,-35][row];
   positions.push(Math.sin(a)*r,y,Math.cos(a)*r);
  }
  for(let row=0;row<3;row++)for(let i=0;i<segments;i++){
   const k=row*(segments+1)+i,b=k+segments+1;indices.push(k,b,k+1,b,b+1,k+1);
  }
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));g.setAttribute('cavity',new T.Float32BufferAttribute(new Float32Array(positions.length/3),1));g.setIndex(indices);g.computeVertexNormals();
  const m=new T.Mesh(g,landMaterial(new T.MeshStandardMaterial({roughness:1,side:T.DoubleSide})));m.name='distant-range-'+layer;scene.add(m);
 }
}
"""
h = patch(h, 'function buildScene(){', LAND_JS + '\nfunction buildScene(){')
h = patch(h, 'const camera=new T.PerspectiveCamera(60,1,.5,3000);',
          'const camera=new T.PerspectiveCamera(60,1,.5,8000);')
h = patch(h, 'new T.SphereGeometry(2000,24,16)', 'new T.SphereGeometry(6000,24,16)')
terrain_hook = between(h, '  if(!low)terrain.material.onBeforeCompile=', '\n\n  scene.add(new T.HemisphereLight')
h = patch(h, terrain_hook, "  terrain.name='bowl-terrain';if(!low)landMaterial(terrain.material);")
# Positive heightfield Laplacian marks concave gullies. Cache it once per vertex,
# at two scales to retain broad erosion as well as small crevices.
h = patch(h, "  tg.setAttribute('color',new T.BufferAttribute(C,3));", r"""
  tg.setAttribute('color',new T.BufferAttribute(C,3));
  const cavity=new Float32Array(P.count);
  if(!low)for(let i=0;i<P.count;i++){
   const x=P.getX(i),z=P.getZ(i),y=P.getY(i);let curvature=0;
   for(const r of[cs*2,cs*5]){
    const lap=(height(x-r,z)+height(x+r,z)+height(x,z-r)+height(x,z+r)-4*y)/(r*r);
    curvature+=Math.max(0,lap)*r*.5;
   }cavity[i]=sstep(.025,.26,curvature);
  }
  tg.setAttribute('cavity',new T.BufferAttribute(cavity,1));""")
h = patch(h, '    sky.renderOrder=-1;scene.add(sky)}',
          '    sky.renderOrder=-1;scene.add(sky);distantRanges()}')
# Clouds also receive the shared atmosphere. The sky dome itself is the endpoint.
h = patch(h, "const cm=toon({color:col('#ffffff'),fog:false});",
          "const cm=toon({color:col('#ffffff'),fog:true});")
h = patch(h, 'fragmentShader:SAMP+`varying vec3 vW;', 'fragmentShader:SAMP+AERIAL+`varying vec3 vW;')
h = patch(h, 'float f=smoothstep(fogNear,fogFar,distance(cameraPosition,vW));gl_FragColor=vec4(mix(c,fogColor,f),a);',
          'gl_FragColor=vec4(c,a);\n#include <tonemapping_fragment>\n#include <encodings_fragment>\ngl_FragColor.rgb=aerial(gl_FragColor.rgb,vW);')
# Remove obsolete linear-fog uniforms; scene.fog only enables the shared chunks.
h = patch(h, 'fogNear:{value:110},fogFar:{value:760}', 'aerialDensity:{value:HL.air.density}')
h = patch(h, 'uniform float fogNear,fogFar;', '', count=2)

GRASS_V9 = r"""
    // Smooth radial bias concentrates near tufts without a density ring.
    // Separate seeded stream avoids changing any existing scatter.
    const nearCount=200000,farCount=52000,NB=nearCount+farCount,gr=rngFrom(W.seed+8808);
    const off=new Float32Array(NB*4),clump=new Float32Array(NB);
    let cx=0,cz=0,ch=0;
    for(let i=0;i<NB;i++){
     const lod=i>=nearCount,n=lod?4:8,j=lod?i-nearCount:i;
     if(j%n===0){const a=gr()*Math.PI*2,u=gr(),r=lod?Math.sqrt(34*34+u*(140*140-34*34)):44*Math.pow(u,.72);
      cx=Math.cos(a)*r;cz=Math.sin(a)*r;ch=gr();}
     const a=gr()*Math.PI*2,r=Math.sqrt(gr())*(lod?.52:.25);
     off.set([cx+Math.cos(a)*r,cz+Math.sin(a)*r,gr(),lod?1:0],i*4);clump[i]=ch;
    }
    const bg=new T.InstancedBufferGeometry();
    bg.setAttribute('position',new T.Float32BufferAttribute([-.5,0,0,.5,0,0,-.23,.55,0,.23,.55,0,0,1,0],3));
    bg.setIndex([0,1,2,2,1,3,2,3,4]);bg.setAttribute('offset',new T.InstancedBufferAttribute(off,4));
    bg.setAttribute('clump',new T.InstancedBufferAttribute(clump,1));bg.instanceCount=NB;
    const gm=new T.Mesh(bg,new T.ShaderMaterial({side:T.DoubleSide,uniforms:hU,
     vertexShader:SAMP+MEADOW+`
      attribute vec4 offset;attribute float clump;uniform float uTime;
      varying vec3 vGrassWorld;varying vec4 vField;varying vec4 vBlade;varying float vTuft;
      void main(){
       float lod=offset.w;
       // World-anchored blades: wrap each offset toroidally onto a world grid of period 2R around center.
       float R=lod>.5?140.:44.;vec2 o=offset.xy,base=o+floor((center.xz-o)/(2.*R)+.5)*(2.*R);vec4 t=samp(base);
       float d=length(base-center.xz),fade=lod>.5?(1.-smoothstep(110.,140.,d))*smoothstep(30.,48.,d):1.-smoothstep(30.,44.,d);
       float rolling=.65+.55*sin(base.x*.033+sin(base.y*.027))*.5+t.b*.4;
       float hg=mix(.48+.75*clump,.30+.40*clump,lod)*rolling*t.g*fade;
       float hx=samp(base+vec2(1.,0.)).r-samp(base-vec2(1.,0.)).r,hz=samp(base+vec2(0.,1.)).r-samp(base-vec2(0.,1.)).r;
       float light=max(dot(normalize(vec3(-hx,2.,-hz)),sun),0.);
       vec3 gp=vec3(base.x,t.r,base.y);float sh=1.,push=0.;vec2 pd=vec2(0.);
       if(lod<.5)for(int i=0;i<12;i++){
        vec3 oc=occ[i].xyz-gp;float r=occ[i].w;if(r<=0.)continue;
        float tca=dot(oc,sun),d2=dot(oc,oc)-tca*tca;
        sh*=mix(1.,smoothstep(r*r*.5,r*r*1.4,d2),step(0.,tca));
        vec2 q=base-occ[i].xz;float dq=length(q),inf=(1.-smoothstep(r*.7,r*1.7,dq))*step(occ[i].y-r,t.r+.6);
        push=max(push,inf);pd+=q/(dq+.001)*inf;
       }
       hg*=1.-.6*push;
       float wave=meadowWave(base,uTime),gust=sin(base.x*.12+base.y*.09+uTime*1.6);
       vec3 p=position;float ang=offset.z*44.,bend=(.10+.15*gust+.3*wave)*p.y*p.y*hg;
       float wd=mix(.12,.25,lod)*(.65+offset.z*.6)*fade*step(.008,hg);
       vec3 wp=vec3(base.x+p.x*cos(ang)*wd+bend*.85,t.r-.025+p.y*hg,base.y+p.x*sin(ang)*wd+bend*.5);
       wp.xz+=pd*p.y*hg*.9;
       float back=pow(max(dot(normalize(wp-cameraPosition),sun),0.),4.);
       vGrassWorld=wp;vField=t;vBlade=vec4(p.y,light,sh,back);vTuft=clump;
       gl_Position=projectionMatrix*viewMatrix*vec4(wp,1.);
      }`,
     fragmentShader:MEADOW+AERIAL+`
      uniform float uTime;varying vec3 vGrassWorld;varying vec4 vField,vBlade;varying float vTuft;
      void main(){
       float h=vBlade.x,wave=meadowWave(vGrassWorld.xz,uTime);
       vec3 c=meadowColor(vField,vBlade.y,wave,vGrassWorld.xz);
       c*=mix(vec3(.85,.92,.74),vec3(1.10,1.04,.96),vTuft);
       c*=mix(.70,1.42,smoothstep(0.,1.,h))*mix(${HL.shK},1.,vBlade.z);
       c+=vec3(.14,.20,.035)*pow(h,2.)*vBlade.w*vBlade.z;
       gl_FragColor=vec4(c,1.);
       #include <tonemapping_fragment>
       #include <encodings_fragment>
       gl_FragColor.rgb=aerial(gl_FragColor.rgb,vGrassWorld);
      }`}));
    gm.frustumCulled=false;gm.name='meadow-252k';scene.add(gm);
"""
grass_block = between(h, '    const RG=44,NB=200000,', '\n  }\n  /* nidos */')
h = patch(h, grass_block, GRASS_V9.rstrip())

# These functions are gameplay contracts: all landscape additions are cosmetic.
for start, end in [("function height(x,z){", "\nconst walkable="),
                   ("function groundY(x,z){", "\nfunction terrainColor(")]:
    if between(h, start, end) != between(VALLEY, start, end):
        sys.exit(f"gameplay terrain changed: {start}")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(h, encoding="utf-8")
print(f"wrote {OUT.relative_to(ROOT)} ({len(h)} bytes)")
