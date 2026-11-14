#!/usr/bin/env python3
"""Build web/hero/index.html: the valley reference with a creator creature in it.

P0 hero shot (docs/DESIGN.md §9, G45-G47). The two references stay untouched;
this script copies art/reference/valle-primigenio.html, patches its lighting
into one ACES pipeline with four time-of-day presets, and grafts the creature
code of art/reference/creador-de-criaturas.html onto it. Every patch asserts
that its target text exists, so a changed reference fails loudly.

URL parameters: t=golden|noon|overcast|night, cam=close|mid|far,
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
{const sc=env.sun.shadow.camera;sc.left=sc.bottom=-22;sc.right=sc.top=22;sc.updateProjectionMatrix();env.sun.shadow.normalBias=.05;env.sun.shadow.bias=-.0004}
const CAM={close:[7.5,.10],mid:[13,.16],far:[30,.22]}[HP.cam]||[13,.16];
const OCC=env.hU.occ.value,_w=V();function feedOcc(){for(let k=0;k<8;k++){const i=NC+Math.round(k*(NSP-1)/7);_w.copy(pts[i]).applyMatrix4(creature.matrixWorld);OCC[k].set(_w.x,_w.y,_w.z,RAD[i]*1.05)}for(let k=0;k<4;k++){const l=legs[k];if(l){_w.copy(l.ft.position);OCC[8+k].set(_w.x,_w.y,_w.z,l.w*2.2)}else OCC[8+k].set(0,-999,0,0)}env.hU.center.value.set(HERO.x,0,HERO.z)}
window.__heroFrame=dt=>{if(HP.live)update(dt);feedOcc();
  const c=V(0,0,0);for(let i=0;i<NS;i++)c.add(pts[i]);c.multiplyScalar(1/NS).applyMatrix4(creature.matrixWorld);
  const a=CAZ,cp=Math.cos(CAM[1]),d=CAM[0];const cam=env.camera;cam.fov=42;
  cam.position.set(c.x+Math.sin(a)*cp*d,c.y+Math.sin(CAM[1])*d,c.z+Math.cos(a)*cp*d);
  cam.position.y=Math.max(cam.position.y,env.groundY(cam.position.x,cam.position.z)+.6);cam.lookAt(c.x,c.y-.2,c.z);cam.updateProjectionMatrix()};
window.Hero={ready:true,params:HP,light:window.__heroLight.name,creature:G.name,
  luminance(){/* creature vs environment mask is built by the capture script from two renders */return null},
  setCreatureVisible(v){creature.visible=v;limbs.visible=v}};
};
</script>
"""

# ---- lighting presets ----------------------------------------------------
PRESETS = r"""
<script>
/* One ACES pipeline (G46). Golden hour is the look (G47); the others are checks.
   Fog/sky colours are display-space values, as in both references. */
(()=>{const q=new URLSearchParams(location.search),P={
 golden:{exp:1.0,sun:[-.62,.28,-.72],sunC:'#ffd2a0',sunI:3.1,hemi:['#bfe0ff','#6f8a4a',.5],fog:[.86,.88,.88],
   sky:{hz:[.95,.84,.70],mid:[.55,.72,.92],top:[.16,.42,.82],glow:[1,.62,.3],disc:3},
   envHz:[.9,.55,.3],envMid:[.32,.42,.62],envTop:[.08,.16,.4],envGd:[.12,.09,.06],envSun:[14,8,3.5],ramp:[54,54,83,83,108,108],grass:[1.04,.95,.80]},
 noon:{exp:1.0,sun:[-.4,.85,-.35],sunC:'#fff2dc',sunI:3.0,hemi:['#bfe0ff','#6f8a4a',.6],fog:[.78,.90,.96],
   sky:{hz:[.78,.90,.96],mid:[.45,.66,.90],top:[.16,.42,.82],glow:[1,.85,.6],disc:3},
   envHz:[.7,.8,.9],envMid:[.4,.55,.8],envTop:[.15,.3,.7],envGd:[.15,.17,.1],envSun:[16,15,13],ramp:[54,54,83,83,108,108],grass:[1,1,1]},
 overcast:{exp:1.1,sun:[-.3,.8,-.4],sunC:'#e8eef2',sunI:.8,hemi:['#d3dbe2','#6a7060',1.7],fog:[.74,.77,.80],
   sky:{hz:[.76,.79,.82],mid:[.66,.69,.73],top:[.55,.58,.63],glow:[.2,.2,.2],disc:0},
   envHz:[.6,.62,.65],envMid:[.55,.57,.6],envTop:[.5,.52,.56],envGd:[.12,.12,.1],envSun:[1.5,1.5,1.5],ramp:[54,54,83,83,108,108],grass:[.78,.82,.84]},
 night:{exp:1.25,sun:[.4,.55,.3],sunC:'#9fb4ff',sunI:.7,hemi:['#2a3a60','#151a20',.6],fog:[.07,.09,.16],
   sky:{hz:[.10,.13,.22],mid:[.05,.07,.15],top:[.02,.03,.08],glow:[.3,.35,.5],disc:1.2},
   envHz:[.06,.08,.14],envMid:[.04,.05,.1],envTop:[.02,.02,.06],envGd:[.02,.02,.02],envSun:[2,2.3,3],ramp:[54,54,83,83,108,108],grass:[.16,.2,.32]}};
 const name=P[q.get('t')]?q.get('t'):'golden',L=Object.assign({name},P[name]);if(q.get('exp'))L.exp=+q.get('exp');
 const v=a=>'vec3('+a.map(x=>(+x).toFixed(3)).join(',')+')',s=L.sky;
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
          "renderer.outputEncoding=T.sRGBEncoding;renderer.shadowMap.type=T.PCFSoftShadowMap;"
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
          "vec3 c=mix(b,tp,vH*vH)*mix(.5,1.,vT.y)*mix(.62,1.12,vL)*mix(.42,1.,vS)+vec3(.12,.13,.03)*max(vT.z,0.)*vH+vec3(1.,.78,.45)*vBk*.3*vS;")
h = patch(h, "window.__heroBuild({T,scene,renderer,camera,groundY,W,SUN,sun});", "window.__heroBuild({T,scene,renderer,camera,groundY,W,SUN,sun,hU});")


# ---- BotW-style meadow: thin dense blades, soft root, large colour patches ----
h = patch(h, "const RG=44,NB=80000,", "const RG=44,NB=200000,")
h = patch(h, "wd=.2*(.6+rnd)*step(.02,hg);", "wd=.1*(.6+rnd)*step(.02,hg);")
h = patch(h, "vec3 b=mix(vec3(.17,.40,.10),vec3(.33,.55,.13),vT.x),tp=mix(vec3(.40,.68,.18),vec3(.66,.80,.28),vT.x);",
          "vec3 b=mix(vec3(.30,.52,.13),vec3(.42,.60,.16),vT.x),tp=mix(vec3(.46,.70,.20),vec3(.70,.78,.30),vT.x);"
          "float pt=smoothstep(.5,.78,vT.x);b=mix(b,vec3(.50,.55,.20),pt*.6);tp=mix(tp,vec3(.80,.78,.36),pt*.7);")
h = patch(h, "vec3 c=mix(b,tp,vH*vH)*mix(.5,1.,vT.y)*mix(.62,1.12,vL)*mix(.42,1.,vS)+vec3(.12,.13,.03)*max(vT.z,0.)*vH",
          "vec3 c=mix(b,tp,.25+.75*vH)*mix(.5,1.,vT.y)*mix(.62,1.12,vL)*mix(.42,1.,vS)+vec3(.17,.17,.07)*max(vT.z,0.)*vH")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(h, encoding="utf-8")
print(f"wrote {OUT.relative_to(ROOT)} ({len(h)} bytes)")
