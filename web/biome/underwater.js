/** web/biome/underwater.js — Underwater biome look (G64).
 *
 * Three.js r128 ES module.  Given { scene, waterLevel, heightmap, palette,
 *   renderer, camera, sun, hemi, fogColor, fogNear, fogFar } it adds:
 *   - Caustics projected on the sea floor
 *   - Underwater fog with depth-based absorption (blue-green)
 *   - Light shafts from the surface (volumetric god rays via sprite)
 *   - Wavy surface with TIR from below
 *   - Kelp forests (instanced, swaying)
 *   - Coral clusters (instanced)
 *   - Rock clusters
 *   - Sea grass (instanced, swaying)
 *   - Fish schools (boids, instanced)
 *   - Floating particles (plankton / detritus)
 *   - One shipwreck-like landmark on the sea floor
 *
 * Effects activate when camera.y < waterLevel.  A public `toggle(v)` and
 * `setWaterLevel(l)` let callers control visibility.
 */

/* ── helpers ─────────────────────────────────────────────────────────── */
const lerp = (a, b, t) => a + (b - a) * Math.max(0, Math.min(1, t));
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const rand = (() => {
  let s = 42;
  return () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; };
})();

/* ── palette data (palette C "Current+" extended for underwater) ─────── */
const PAL = {
  /* surface → deep colour progression (linear) */
  waterDeep:  [0.02, 0.08, 0.22],
  waterMid:   [0.06, 0.20, 0.38],
  waterShallow: [0.12, 0.42, 0.56],
  causticBright: [0.55, 0.75, 0.82],
  causticDim:    [0.22, 0.38, 0.50],
  shaftWarm:   [1.0, 0.78, 0.42],   /* golden light from above */
  shaftCool:   [0.35, 0.55, 0.78],  /* scattered blue */
  kelpDark:    [0.06, 0.14, 0.04],
  kelpLight:   [0.14, 0.32, 0.10],
  coralBase:   [0.55, 0.18, 0.14],
  coralAccent: [0.82, 0.35, 0.22],
  coralYellow: [0.85, 0.65, 0.12],
  rockUW:      [0.12, 0.15, 0.18],
  sand:        [0.55, 0.48, 0.35],
  sandBright:  [0.72, 0.65, 0.48],
  fishBody:    [0.60, 0.72, 0.85],
  fishFin:     [0.80, 0.55, 0.30],
  particle:    [0.70, 0.82, 0.78],
};

/* ── GLSL shared ─────────────────────────────────────────────────────── */
const SAMP = `
float hsh(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float vn(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hsh(i),hsh(i+vec2(1.,0.)),f.x),mix(hsh(i+vec2(0.,1.)),hsh(i+vec2(1.,1.)),f.x),f.y);}
`;

/* ── caustics shader (2D noise flow → brightness mask) ───────────────── */
function causticShader() {
  const vertexShader = `
varying vec2 vUv;
varying vec3 vWorldPos;
void main(){
  vUv = uv;
  vWorldPos = (modelMatrix * vec4(position,1.0)).xyz;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0);
}`;

  const fragmentShader = `
uniform float uTime;
uniform vec3 uSunDir;
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;
uniform vec3 uCausticBright, uCausticDim;
uniform vec3 uShaftWarm, uShaftCool;
uniform float uWaterLevel;

varying vec2 vUv;
varying vec3 vWorldPos;

${SAMP}

/* Simplex-ish 2D noise */
vec3 hash(vec3 p){
  p=vec3(dot(p,vec3(127.1,311.7,74.7)),
         dot(p,vec3(269.5,183.3,246.3)),
         dot(p,vec3(113.5,271.9,124.6)));
  return fract(sin(p)*43758.5453123);
}

float causticField(vec2 p, float t){
  float c = 0.0;
  for(int i = 0; i < 5; i++){
    float fi = float(i);
    vec2 dir = normalize(vec2(cos(fi*1.8+t*0.08), sin(fi*2.3+t*0.06)));
    float speed = 0.3 + fi * 0.12;
    float freq = 1.5 + fi * 0.7;
    c += sin(dot(p, dir)*freq + t*speed) / (1.0 + fi*0.5);
  }
  return c;
}

float causticPattern(vec2 uv, float t){
  vec2 p = uv * 12.0;
  float c = causticField(p, t);
  float c2 = causticField(p*1.5 + vec2(t*0.05), t);
  c = c*c*1.2 + c2*0.4;
  c = pow(clamp(c, 0.0, 1.0), 1.5);
  return c;
}

void main(){
  vec3 dir = vWorldPos - camPos;
  float depth = length(dir);

  vec2 uv = vWorldPos.xz;
  float depthBelowSurface = uWaterLevel - vWorldPos.y;
  float depthFade = 1.0 - smoothstep(0.0, 15.0, depthBelowSurface);

  float caustic = causticPattern(uv, uTime) * depthFade;

  vec3 causticColor = mix(uCausticDim, uCausticBright, caustic);
  float shaftInfluence = smoothstep(0.3, 0.7, caustic);
  causticColor = mix(causticColor, uShaftWarm, shaftInfluence * 0.5);

  float fogF = smoothstep(fogNear, fogFar, depth);
  vec3 c = mix(causticColor, uFogColor, fogF);

  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── surface shader (wavy, TIR from below) ────────────────────────────── */
function surfaceShader() {
  const vertexShader = `
uniform float uTime;
varying vec3 vWorldPos;
varying vec3 vNormal;

void main(){
  vec3 pos = position;
  /* Multi-sine wave displacement */
  float wave = sin(pos.x*0.8 + uTime*1.3)*0.15
             + sin(pos.z*1.2 + uTime*0.9)*0.12
             + sin((pos.x+pos.z)*1.5 + uTime*2.0)*0.06
             + sin(pos.x*2.5 - pos.z*1.8 + uTime*3.0)*0.03;
  pos.y += wave;

  /* Compute approximate normal from wave derivatives */
  float dx = cos(pos.x*0.8 + uTime*1.3)*0.8*0.15
           + cos((pos.x+pos.z)*1.5 + uTime*2.0)*1.5*0.06
           + cos(pos.x*2.5 - pos.z*1.8 + uTime*3.0)*2.5*0.03;
  float dz = cos(pos.z*1.2 + uTime*0.9)*1.2*0.12
           + cos((pos.x+pos.z)*1.5 + uTime*2.0)*1.5*0.06
           + cos(pos.x*2.5 - pos.z*1.8 + uTime*3.0)*(-1.8)*0.03;
  vec3 normal = normalize(vec3(-dx, 1.0, -dz));

  vWorldPos = (modelMatrix * vec4(pos,1.0)).xyz;
  vNormal = normalize(normalMatrix * normal);
  gl_Position = projectionMatrix * modelViewMatrix * vec4(vWorldPos,1.0);
}`;

  const fragmentShader = `
uniform float uTime;
uniform vec3 uSunDir;
uniform vec3 camPos;
uniform vec3 uWaterShallow;
uniform vec3 uWaterMid;
uniform vec3 uShaftWarm;

varying vec3 vWorldPos;
varying vec3 vNormal;

void main(){
  vec3 normal = normalize(vNormal);
  vec3 viewDir = normalize(camPos - vWorldPos);

  /* Fresnel — strong reflection when looking up at grazing angle */
  float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 4.0);

  /* TIR from below: at steep angles water reflects everything */
  float tilt = dot(normal, vec3(0.0, -1.0, 0.0)); /* how much normal points down */
  float tir = smoothstep(0.0, 0.3, tilt) * 0.5; /* only below surface */

  /* Base water colour (lighter near camera) */
  float depthFade = smoothstep(0.0, 5.0, camPos.y - vWorldPos.y);
  vec3 waterColor = mix(uWaterShallow, uWaterMid, depthFade);

  /* Sun glitter on surface */
  vec3 halfDir = normalize(uSunDir + viewDir);
  float spec = pow(max(dot(normal, halfDir), 0.0), 128.0);

  /* Compose */
  vec3 c = waterColor;
  c += uShaftWarm * (1.0 - fresnel) * 0.3; /* subsurface transmission */
  c = mix(c, vec3(0.85, 0.92, 0.95), fresnel * (1.0 - tir)); /* reflection above */
  c += vec3(1.0) * spec * 0.6; /* specular highlights */

  /* Alpha: transparent but more opaque at grazing angle */
  float a = 0.35 + fresnel * 0.55 + tir * 0.3;

  gl_FragColor = vec4(c, clamp(a, 0.0, 0.95));
}`;

  return { vertexShader, fragmentShader };
}

/* ── kelp shader (instanced blade with sway) ──────────────────────────── */
function kelpShader() {
  const vertexShader = `
uniform float uTime;
attribute float kelpIndex;
attribute vec3 offset;
attribute float height;
attribute vec3 kelpColor;
varying float vHeight;
varying vec3 vColor;
varying vec3 vWorldPos;

void main(){
  vColor = kelpColor;
  float h = position.y / height; /* 0=base, 1=top */
  vHeight = h;

  /* Sway: sinusoidal wave from base to top, varying by index */
  float phase = kelpIndex * 0.7 + uTime * 0.8;
  float sway = h * h * sin(phase + position.x * 0.5) * 0.4;

  vec3 pos = position;
  pos.x += sway;
  pos.z += h * h * sin(phase * 0.7 + 1.3) * 0.25;

  vec4 worldPos = modelMatrix * vec4(pos + offset, 1.0);
  vWorldPos = worldPos.xyz;
  gl_Position = projectionMatrix * viewMatrix * worldPos;
}`;

  const fragmentShader = `
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;
uniform float uWaterLevel;

varying float vHeight;
varying vec3 vColor;
varying vec3 vWorldPos;

void main(){
  /* Darker at base, lighter at top */
  vec3 c = mix(vColor * 0.7, vColor, vHeight);

  /* Fog */
  vec3 dir = vWorldPos - camPos;
  float depth = length(dir);
  float fogF = smoothstep(fogNear, fogFar, depth);
  c = mix(c, uFogColor, fogF);

  /* Depth fade */
  float depthBelowSurface = uWaterLevel - vWorldPos.y;
  float depthFade = 1.0 - smoothstep(0.0, 12.0, depthBelowSurface);
  c *= 0.5 + 0.5 * depthFade;

  gl_FragColor = vec4(c, 0.9);
}`;

  return { vertexShader, fragmentShader };
}

/* ── coral shader ─────────────────────────────────────────────────────── */
function coralShader() {
  const vertexShader = `
attribute vec3 coralColor;
varying vec3 vColor;
varying vec3 vNormal;
varying vec3 vWorldPos;
void main(){
  vColor = coralColor;
  vNormal = normalize(normalMatrix * normal);
  vec4 wp = modelMatrix * vec4(position, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = `
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;
uniform vec3 sun;

varying vec3 vColor;
varying vec3 vNormal;
varying vec3 vWorldPos;

void main(){
  vec3 c = vColor;
  float light = max(dot(normalize(vNormal), normalize(sun)), 0.0);
  /* Sunlight barely reaches deep — only at surface */
  float sunFactor = smoothstep(0.0, 5.0, vWorldPos.y) * 0.3 + 0.05;
  c *= sunFactor + light * sunFactor * 0.5 + 0.15;

  /* Subtle emissive glow */
  c += vec3(0.15, 0.05, 0.03);

  /* Fog */
  float depth = length(vWorldPos - camPos);
  float fogF = smoothstep(fogNear, fogFar, depth);
  c = mix(c, uFogColor, fogF);

  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── sea grass shader (instanced blade) ───────────────────────────────── */
function seaGrassShader() {
  const vertexShader = `
uniform float uTime;
attribute float sgIndex;
attribute vec3 offset;
attribute float height;
varying float vHeight;
varying vec3 vWorldPos;
void main(){
  vHeight = position.y / height;
  float phase = sgIndex * 1.1 + uTime * 1.0;
  float sway = vHeight * vHeight * sin(phase) * 0.3;
  vec3 pos = position;
  pos.x += sway;
  vec4 wp = modelMatrix * vec4(pos + offset, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = `
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;

varying float vHeight;
varying vec3 vWorldPos;

void main(){
  vec3 c = vec3(0.08, 0.20, 0.06) * (0.6 + 0.4 * vHeight);
  float depth = length(vWorldPos - camPos);
  float fogF = smoothstep(fogNear, fogFar, depth);
  c = mix(c, uFogColor, fogF);
  gl_FragColor = vec4(c, 0.85);
}`;

  return { vertexShader, fragmentShader };
}

/* ── fish shader (instanced boid) ─────────────────────────────────────── */
function fishShader() {
  const vertexShader = `
uniform float uTime;
attribute vec3 fishOffset;
attribute float fishIdx;
attribute float fishSize;
attribute float fishSchool;
attribute vec3 fishTarget;
attribute float fishPhase;
varying vec3 vFishWorld;
varying float vFishSize;
varying float vFishIdx;

/* Simple 3D noise for boid wandering */
vec3 noise3(vec3 p){
  p = fract(p * 0.3183099);
  p *= 17.0;
  return fract(sin(p * vec3(12.9898,78.233,45.164)) * 43758.5453);
}

void main(){
  vFishIdx = fishIdx;
  vFishSize = fishSize;

  /* Boid target with wandering */
  float t = uTime * 0.15;
  vec3 wander = (noise3(vec3(fishPhase + t, fishSchool, 0.0)) - 0.5) * 4.0;
  vec3 wander2 = (noise3(vec3(fishPhase, fishSchool, t * 0.5)) - 0.5) * 2.0;

  vec3 pos = position * fishSize;
  /* Tail wag */
  float wag = sin(uTime * 8.0 + fishIdx) * 0.15 * position.z;
  pos.x += wag;

  vec4 wp = modelMatrix * vec4(pos + fishOffset + wander, 1.0);
  vFishWorld = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = `
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;
uniform vec3 uFishBody, uFishFin;

varying vec3 vFishWorld;
varying float vFishSize;
varying float vFishIdx;

void main(){
  /* Simple gradient along body */
  float gradient = fract(vFishIdx * 0.618033988);
  vec3 c = mix(uFishBody, uFishFin, gradient * 0.5);

  /* Eye */
  float eye = smoothstep(0.15, 0.18, vFishWorld.x) * smoothstep(-0.05, -0.02, vFishWorld.x);
  if(eye > 0.01 && abs(vFishWorld.y) < 0.02 && abs(vFishWorld.z) < 0.02){
    c = vec3(0.05);
  }

  /* Fog */
  float depth = length(vFishWorld - camPos);
  float fogF = smoothstep(fogNear, fogFar, depth);
  c = mix(c, uFogColor, fogF);

  gl_FragColor = vec4(c, 0.95);
}`;

  return { vertexShader, fragmentShader };
}

/* ── particle shader (plankton / detritus) ────────────────────────────── */
function particleShader() {
  const vertexShader = `
uniform float uTime;
attribute vec3 particleOffset;
attribute float particleIdx;
attribute float particleSize;
attribute float particleSpeed;
attribute float particlePhase;
varying float vAlpha;

void main(){
  vec3 pos = position;
  /* Gentle drift */
  float t = uTime * particleSpeed;
  pos += vec3(
    sin(particlePhase + t * 0.3) * 0.3,
    sin(particlePhase * 1.3 + t * 0.2) * 0.15,
    cos(particlePhase + t * 0.4) * 0.2
  );

  vec4 wp = modelMatrix * vec4(pos + particleOffset, 1.0);
  gl_Position = projectionMatrix * viewMatrix * wp;

  /* Size attenuation */
  float dist = length(wp.xyz - (modelViewMatrix * vec4(particleOffset, 0.0)).xyz);
  gl_PointSize = particleSize * (200.0 / max(dist, 1.0));

  /* Fade by depth */
  float depthFade = 1.0 - smoothstep(5.0, 20.0, dist);
  vAlpha = (0.3 + 0.7 * sin(particlePhase * 6.28)) * depthFade;
}`;

  const fragmentShader = `
uniform vec3 uParticleColor;
uniform vec3 uFogColor;
uniform vec3 camPos;

varying float vAlpha;

void main(){
  /* Soft circle */
  vec2 center = gl_PointCoord - 0.5;
  float d = length(center);
  if(d > 0.5) discard;
  float a = smoothstep(0.5, 0.1, d) * vAlpha;

  vec3 c = uParticleColor;
  float depth = length(gl_PointCoord.x * 100.0); /* rough depth estimate */
  c = mix(c, uFogColor, 0.3);

  gl_FragColor = vec4(c, a * 0.6);
}`;

  return { vertexShader, fragmentShader };
}

/* ── shaft shader (volumetric god rays via transparent plane strip) ──── */
function shaftShader() {
  const vertexShader = `
varying vec2 vUv;
void main(){
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

  const fragmentShader = `
uniform float uTime;
uniform vec3 uShaftColor;
uniform float uOpacity;
varying vec2 vUv;

void main(){
  /* Fade at edges: stronger in center */
  float center = 1.0 - abs(vUv.x - 0.5) * 2.0;
  center = pow(center, 2.0);
  /* Fade at top and bottom */
  float topFade = 1.0 - pow(vUv.y, 0.5);
  float bottomFade = smoothstep(0.0, 0.15, vUv.y);

  /* Subtle temporal shimmer */
  float shimmer = 0.8 + 0.2 * sin(vUv.y * 20.0 + uTime * 0.5);

  float a = center * topFade * bottomFade * shimmer * uOpacity;
  gl_FragColor = vec4(uShaftColor, a * 0.12);
}`;

  return { vertexShader, fragmentShader };
}

/* ── wreck / landmark shader ──────────────────────────────────────────── */
function wreckShader() {
  const vertexShader = `
varying vec3 vNormal;
varying vec3 vWorldPos;
void main(){
  vNormal = normalize(normalMatrix * normal);
  vec4 wp = modelMatrix * vec4(position, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = `
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;
uniform vec3 sun;
uniform vec3 uWreckColor;

varying vec3 vNormal;
varying vec3 vWorldPos;

void main(){
  float light = max(dot(normalize(vNormal), normalize(sun)), 0.0);
  /* Very dim light deep down */
  float depthBelowSurface = 20.0 - vWorldPos.y;
  float lightPenetration = smoothstep(0.0, 8.0, vWorldPos.y) * 0.15 + 0.03;

  vec3 c = uWreckColor * (lightPenetration + light * lightPenetration * 0.8);
  /* Moss / algae growth on top */
  if(vNormal.y > 0.5) c += vec3(0.04, 0.08, 0.02);

  /* Fog */
  float depth = length(vWorldPos - camPos);
  float fogF = smoothstep(fogNear, fogFar, depth);
  c = mix(c, uFogColor, fogF);

  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── sea floor shader (rippled sand) ──────────────────────────────────── */
function seaFloorShader() {
  const vertexShader = `
varying vec2 vUv;
varying vec3 vWorldPos;
varying vec3 vNormal;
void main(){
  vUv = uv;
  vWorldPos = (modelMatrix * vec4(position,1.0)).xyz;
  vNormal = normalize(normalMatrix * normal);
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0);
}`;

  const fragmentShader = `
uniform float uTime;
uniform vec3 uFogColor;
uniform float fogNear, fogFar;
uniform vec3 camPos;
uniform vec3 uSandColor, uSandBright;
uniform vec3 uCausticBright, uCausticDim;
uniform vec3 sun;

varying vec2 vUv;
varying vec3 vWorldPos;
varying vec3 vNormal;

${SAMP}

void main(){
  /* Ripple texture */
  vec2 uv = vWorldPos.xz * 2.0;
  float ripple = sin(uv.x*4.0 + sin(uv.y*2.0)*0.5) * 0.5 + 0.5;
  ripple *= sin(uv.y*3.0 + cos(uv.x*1.5)*0.3) * 0.5 + 0.5;

  vec3 sand = mix(uSandColor, uSandBright, ripple * 0.3);

  /* Light normal for specular */
  vec3 lightNormal = normalize(vNormal + vec3(
    sin(uv.x*8.0 + uTime*0.3)*0.03,
    1.0,
    cos(uv.y*6.0 + uTime*0.2)*0.03
  ));
  float light = max(dot(lightNormal, normalize(sun)), 0.0);

  /* Caustic overlay */
  float depthBelowSurface = 10.0 - vWorldPos.y;
  float depthFade = 1.0 - smoothstep(0.0, 12.0, depthBelowSurface);
  float causticNoise = vn(uv * 3.0 + uTime * 0.4);
  vec3 causticOverlay = mix(uCausticDim, uCausticBright, causticNoise) * depthFade * 0.25;

  sand *= (0.15 + light * 0.5) + causticOverlay;

  /* Fog */
  float depth = length(vWorldPos - camPos);
  float fogF = smoothstep(fogNear, fogFar, depth);
  sand = mix(sand, uFogColor, fogF);

  gl_FragColor = vec4(sand, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── instanced geometry builders ──────────────────────────────────────── */

/** Build a kelp frond: vertical blade that tapers to a point. */
function buildKelpBlade() {
  const segH = 8;
  const positions = [];
  const normals = [];
  const uvs = [];
  for (let i = 0; i <= segH; i++) {
    const t = i / segH;
    const y = t * 3.0;
    const w = (1.0 - t * 0.85) * 0.12;
    const z = t * 0.02; /* slight curve */
    const u = 0, v = t;
    positions.push(-w, y, z, w, y, z);
    const nx = -1, nz = 0.07;
    normals.push(nx, 0, nz, -nx, 0, -nz);
    uvs.push(u, v, u + 0.01, v);
  }
  const indices = [];
  for (let i = 0; i < segH; i++) {
    const a = i * 2, b = a + 1, c = a + 2, d = a + 3;
    indices.push(a, c, b, b, c, d);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geo.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geo.setIndex(indices);
  return geo;
}

/** Build a simple fish mesh (elongated diamond). */
function buildFishMesh() {
  const positions = [];
  const normals = [];
  /* Body: elongated ellipsoid approximated with quads */
  const segments = 6;
  for (let i = 0; i < segments; i++) {
    const a0 = (i / segments) * Math.PI * 2;
    const a1 = ((i + 1) / segments) * Math.PI * 2;
    const r0 = 0.03 * Math.cos((i / segments) * Math.PI * 0.5 + Math.PI * 0.5);
    const r1 = 0.03 * Math.cos(((i + 1) / segments) * Math.PI * 0.5 + Math.PI * 0.5);
    const x0 = Math.cos(a0) * 0.15;
    const x1 = Math.cos(a1) * 0.15;
    const y0 = Math.sin(a0) * r0;
    const y1 = Math.sin(a1) * r1;
    const z0 = Math.sin(a0) * r0;
    const z1 = Math.sin(a1) * r1;
    /* Two triangles per segment ring */
    const k = positions.length / 3;
    positions.push(x0, y0, z0, x1, y1, z1, x0, -y0, z0);
    positions.push(x0, -y0, z0, x1, y1, z1, x1, -y1, z1);
    const nx = Math.cos(a0), nz = Math.sin(a0);
    normals.push(nx, 0, nz, nx, 0, nz, nx, 0, nz);
    normals.push(nx, 0, nz, nx, 0, nz, nx, 0, nz);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  return geo;
}

/** Build a simple coral shape (branching tubes). */
function buildCoralShape() {
  const group = [];
  const segs = 4;
  const rings = 6;

  /* Main trunk */
  for (let r = 0; r < rings; r++) {
    const t = r / (rings - 1);
    const y = t * 0.6;
    const rad = 0.04 * (1 - t * 0.3);
    for (let s = 0; s < segs; s++) {
      const a = (s / segs) * Math.PI * 2;
      const nextA = ((s + 1) / segs) * Math.PI * 2;
      const nx = Math.cos(a), nz = Math.sin(a);
      const nx2 = Math.cos(nextA), nz2 = Math.sin(nextA);
      const k = group.length / 3;
      group.push(nx, y, nz, nx2, y, nz2, nx, y + 0.1, nz);
      group.push(nx, y + 0.1, nz, nx2, y, nz2, nx2, y + 0.1, nz2);
    }
  }
  /* Branches */
  const branches = [[0.3, 0.35, 0.3], [0.5, -0.25, 0.2], [0.7, 0.2, -0.3]];
  branches.forEach(([by, bx, bz], bi) => {
    for (let r = 0; r < 4; r++) {
      const t = r / 3;
      const ang = bi * 2.1 + t * 0.5;
      const rad = 0.025 * (1 - t * 0.5);
      const a0 = ang, a1 = ang + 0.8;
      const k = group.length / 3;
      group.push(Math.cos(a0)*rad, by + r*0.04, Math.sin(a0)*rad,
                 Math.cos(a1)*rad, by + r*0.04, Math.sin(a1)*rad,
                 Math.cos(a0)*rad, by + (r+1)*0.04, Math.sin(a0)*rad);
      group.push(Math.cos(a0)*rad, by + (r+1)*0.04, Math.sin(a0)*rad,
                 Math.cos(a1)*rad, by + r*0.04, Math.sin(a1)*rad,
                 Math.cos(a1)*rad, by + (r+1)*0.04, Math.sin(a1)*rad);
    }
  });

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(group, 3));
  geo.computeVertexNormals();
  return geo;
}

/** Build a simple rock shape (irregular blob). */
function buildRock() {
  const geo = new THREE.IcosahedronGeometry(1, 1);
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const n = 1.0 + (Math.sin(x * 5) * Math.cos(z * 3) * 0.15);
    pos.setXYZ(i, x * n, y * (0.6 + Math.sin(y * 3) * 0.15), z * n);
  }
  pos.needsUpdate = true;
  geo.computeVertexNormals();
  return geo;
}

/** Build a simple sea grass blade (thin triangle). */
function buildSeaGrassBlade() {
  const h = 0.8;
  const w = 0.03;
  return new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(-w, 0, 0),
    new THREE.Vector3(w, 0, 0),
    new THREE.Vector3(0, h, 0.02),
  ]);
}

/** Build a simple wreck (ship hull + mast fragment). */
function buildWreck() {
  const group = [];
  /* Hull: curved bottom plate */
  const hullLen = 4, hullW = 1.2, hullH = 0.8;
  const segs = 8, rings = 4;
  for (let r = 0; r < rings; r++) {
    const t = r / (rings - 1);
    const y = t * hullH;
    const w = hullW * (1 - t * 0.5) * Math.cos(t * Math.PI * 0.5);
    for (let s = 0; s < segs; s++) {
      const a0 = (s / segs) * Math.PI * 2;
      const a1 = ((s + 1) / segs) * Math.PI * 2;
      const r0 = w * 0.5, r1 = w * 0.5;
      const k = group.length / 3;
      group.push(Math.cos(a0)*r0, y, Math.sin(a0)*r0,
                 Math.cos(a1)*r0, y, Math.sin(a1)*r0,
                 Math.cos(a0)*r1, y+0.05, Math.sin(a0)*r1);
      group.push(Math.cos(a0)*r1, y+0.05, Math.sin(a0)*r1,
                 Math.cos(a1)*r0, y, Math.sin(a1)*r0,
                 Math.cos(a1)*r1, y+0.05, Math.sin(a1)*r1);
    }
  }
  /* Mast fragment */
  for (let r = 0; r < 6; r++) {
    const t = r / 5;
    const y = t * 3;
    const rad = 0.04 * (1 - t * 0.2);
    const a0 = 0, a1 = Math.PI * 0.5;
    const k = group.length / 3;
    group.push(Math.cos(a0)*rad, y, Math.sin(a0)*rad,
               Math.cos(a1)*rad, y, Math.sin(a1)*rad,
               Math.cos(a0)*rad, y+0.5, Math.sin(a0)*rad);
    group.push(Math.cos(a0)*rad, y+0.5, Math.sin(a0)*rad,
               Math.cos(a1)*rad, y, Math.sin(a1)*rad,
               Math.cos(a1)*rad, y+0.5, Math.sin(a1)*rad);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(group, 3));
  geo.computeVertexNormals();
  return geo;
}

/* ── scatter helper (like Valle's scatter, but simpler) ───────────────── */
function scatter(baseGeo, positions, material, colorFn) {
  const count = positions.length;
  if (count === 0) return null;

  const offsets = new Float32Array(count * 3);
  const scales = new Float32Array(count);
  const colors = new Float32Array(count * 3);

  positions.forEach((p, i) => {
    offsets[i * 3] = p.x;
    offsets[i * 3 + 1] = p.y;
    offsets[i * 3 + 2] = p.z;
    scales[i] = p.s || 1;
    const c = colorFn ? colorFn(p, i) : new THREE.Color(1, 1, 1);
    colors[i * 3] = c.r;
    colors[i * 3 + 1] = c.g;
    colors[i * 3 + 2] = c.b;
  });

  const geo = baseGeo.clone();
  geo.setAttribute('offset', new THREE.InstancedBufferAttribute(offsets, 3));
  geo.setAttribute('scale', new THREE.InstancedBufferAttribute(scales, 1));

  const mat = typeof material === 'function' ? material() : material;
  const mesh = new THREE.InstancedMesh(geo, mat, count);

  for (let i = 0; i < count; i++) {
    mesh.setMatrixAt(i, new THREE.Matrix4().makeScale(scales[i], scales[i], scales[i]).
      multiply(new THREE.Matrix4().makeTranslation(offsets[i*3], offsets[i*3+1], offsets[i*3+2])));
  }

  if (material && colorFn) {
    mesh.instanceColor = new THREE.InstancedBufferAttribute(colors, 3);
  }

  return mesh;
}


/* ── main underwater module ──────────────────────────────────────────── */
class UnderwaterBiome {
  /**
   * @param {Object} ctx — runtime context
   * @param {THREE.Scene} ctx.scene
   * @param {number} ctx.waterLevel — Y height of the water surface
   * @param {Function} ctx.heightmap — heightmap(x, z) → surface Y (or 0)
   * @param {Object} [ctx.palette] — palette overrides (deep, shallow, etc.)
   * @param {THREE.WebGLRenderer} ctx.renderer
   * @param {THREE.Camera} ctx.camera
   * @param {THREE.DirectionalLight} ctx.sun
   * @param {THREE.Color} [ctx.fogColor]
   * @param {number} [ctx.fogNear]
   * @param {number} [ctx.fogFar]
   */
  constructor(ctx) {
    this.scene = ctx.scene;
    this.waterLevel = ctx.waterLevel || 3;
    this.heightmap = ctx.heightmap || (() => 0);
    this.renderer = ctx.renderer;
    this.camera = ctx.camera;
    this.sun = ctx.sun || new THREE.DirectionalLight(0xffffff, 1);
    this.fogColor = ctx.fogColor ? ctx.fogColor.clone() : new THREE.Color(0.78, 0.90, 0.96);
    this.fogNear = ctx.fogNear || 110;
    this.fogFar = ctx.fogFar || 760;
    this._pal = Object.assign({}, PAL, ctx.palette || {});

    this.enabled = true;
    this._groups = []; /* all added objects, for enable/disable */
    this._causticPlane = null;
    this._surfacePlane = null;
    this._shaftMeshes = [];
    this._underwaterFogMesh = null;

    this._build();
  }

  /* ── sea floor ──────────────────────────────────────────────────────── */
  _buildSeaFloor() {
    /* Create a ground plane at the maximum expected sea depth */
    const size = 200;
    const segs = 80;
    const geo = new THREE.PlaneGeometry(size, size, segs, segs);
    geo.rotateX(-Math.PI / 2);

    /* Displace vertices by terrain height, clamp to below water */
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), z = pos.getZ(i);
      const h = this.heightmap(x, z);
      /* Sea floor: at the heightmap height or at a base depth */
      const floorY = Math.min(h, this.waterLevel - 0.5);
      pos.setY(i, Math.max(floorY, this.waterLevel - 20));
    }
    geo.computeVertexNormals();

    const uniforms = {
      uTime: { value: 0 },
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      uSandColor: { value: new THREE.Color(...this._pal.sand) },
      uSandBright: { value: new THREE.Color(...this._pal.sandBright) },
      uCausticBright: { value: new THREE.Color(...this._pal.causticBright) },
      uCausticDim: { value: new THREE.Color(...this._pal.causticDim) },
      sun: { value: new THREE.Vector3() },
    };

    const sh = seaFloorShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
    });

    const mesh = new THREE.Mesh(geo, mat);
    mesh.receiveShadow = true;
    mesh.renderOrder = 10;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── caustics projector (billboard plane that projects onto floor) ──── */
  _buildCaustics() {
    const size = 120;
    const geo = new THREE.PlaneGeometry(size, size);
    geo.rotateX(-Math.PI / 2);

    const uniforms = {
      uTime: { value: 0 },
      uSunDir: { value: new THREE.Vector3() },
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      uCausticBright: { value: new THREE.Color(...this._pal.causticBright) },
      uCausticDim: { value: new THREE.Color(...this._pal.causticDim) },
      uShaftWarm: { value: new THREE.Color(...this._pal.shaftWarm) },
      uWaterLevel: { value: this.waterLevel },
    };

    const sh = causticShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });

    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.y = this.waterLevel - 0.2;
    mesh.renderOrder = 20;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── water surface ──────────────────────────────────────────────────── */
  _buildSurface() {
    const size = 250;
    const segs = 80;
    const geo = new THREE.PlaneGeometry(size, size, segs, segs);
    geo.rotateX(-Math.PI / 2);

    const uniforms = {
      uTime: { value: 0 },
      uSunDir: { value: new THREE.Vector3() },
      camPos: { value: new THREE.Vector3() },
      uWaterShallow: { value: new THREE.Color(...this._pal.waterShallow) },
      uWaterMid: { value: new THREE.Color(...this._pal.waterMid) },
      uShaftWarm: { value: new THREE.Color(...this._pal.shaftWarm) },
    };

    const sh = surfaceShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
      transparent: true,
      depthWrite: false,
      side: THREE.DoubleSide,
      blending: THREE.NormalBlending,
    });

    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.y = this.waterLevel;
    mesh.renderOrder = 5;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── light shafts (volumetric strips) ───────────────────────────────── */
  _buildShafts() {
    const shafts = [];
    const count = 5;

    for (let i = 0; i < count; i++) {
      const x = (Math.random() - 0.5) * 60;
      const z = (Math.random() - 0.5) * 60;
      const width = 2 + Math.random() * 4;
      const height = this.waterLevel + 5;

      const geo = new THREE.PlaneGeometry(width, height);
      geo.rotateX(-Math.PI / 2);
      geo.translate(0, height / 2, 0);

      const uniforms = {
        uTime: { value: 0 },
        uShaftColor: { value: new THREE.Color(
          ...this._pal.shaftWarm
        ) },
        uOpacity: { value: 0.4 + Math.random() * 0.3 },
      };

      const sh = shaftShader();
      const mat = new THREE.ShaderMaterial({
        uniforms,
        vertexShader: sh.vertexShader,
        fragmentShader: sh.fragmentShader,
        transparent: true,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
        side: THREE.DoubleSide,
      });

      const mesh = new THREE.Mesh(geo, mat);
      mesh.position.set(x, this.waterLevel - 2, z);
      mesh.rotation.y = Math.random() * Math.PI;
      mesh.renderOrder = 8;
      this.scene.add(mesh);
      shafts.push({ mesh, uniforms });
    }

    return shafts;
  }

  /* ── kelp ───────────────────────────────────────────────────────────── */
  _buildKelp(count = 120) {
    const baseGeo = buildKelpBlade();
    const positions = [];
    const colors = [];
    const dr = (() => { let s = 77; return () => { s = (s * 16807) % 2147483647; return (s-1)/2147483646; }; })();

    for (let i = 0; i < count; i++) {
      const x = (dr() - 0.5) * 120;
      const z = (dr() - 0.5) * 120;
      const h = this.heightmap(x, z);
      const y = Math.min(h, this.waterLevel - 0.5);
      const depth = this.waterLevel - y;

      /* Only place kelp on the sea floor within a reasonable depth */
      if (depth > 15 || depth < 1) continue;

      positions.push({ x, y: y + 0.3, z, s: 0.8 + dr() * 0.6 });
      const shade = 1.0 - depth * 0.03;
      colors.push(
        this._pal.kelpDark[0] * shade + this._pal.kelpLight[0] * (1 - shade) * 0.5,
        this._pal.kelpDark[1] * shade + this._pal.kelpLight[1] * (1 - shade) * 0.5,
        this._pal.kelpDark[2] * shade + this._pal.kelpLight[2] * (1 - shade) * 0.5
      );
    }

    if (positions.length === 0) return null;

    const offsets = new Float32Array(positions.length * 3);
    const heights = new Float32Array(positions.length);
    const kelpIndices = new Float32Array(positions.length);
    const kelpColors = new Float32Array(positions.length * 3);

    positions.forEach((p, i) => {
      offsets[i * 3] = p.x;
      offsets[i * 3 + 1] = p.y;
      offsets[i * 3 + 2] = p.z;
      heights[i] = 3.0;
      kelpIndices[i] = i;
      kelpColors[i * 3] = colors[i * 3];
      kelpColors[i * 3 + 1] = colors[i * 3 + 1];
      kelpColors[i * 3 + 2] = colors[i * 3 + 2];
    });

    const geo = baseGeo.clone();
    geo.setAttribute('kelpIndex', new THREE.InstancedBufferAttribute(kelpIndices, 1));
    geo.setAttribute('offset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('height', new THREE.InstancedBufferAttribute(heights, 1));
    geo.setAttribute('kelpColor', new THREE.InstancedBufferAttribute(kelpColors, 3));

    const uniforms = {
      uTime: { value: 0 },
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      uWaterLevel: { value: this.waterLevel },
    };

    const sh = kelpShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
      transparent: true,
      side: THREE.DoubleSide,
    });

    const mesh = new THREE.InstancedMesh(geo, mat, positions.length);
    positions.forEach((p, i) => {
      mesh.setMatrixAt(i, new THREE.Matrix4().makeTranslation(p.x, p.y, p.z));
    });
    mesh.renderOrder = 15;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── coral clusters ─────────────────────────────────────────────────── */
  _buildCoral(count = 40) {
    const baseGeo = buildCoralShape();
    const positions = [];
    const dr = (() => { let s = 313; return () => { s = (s * 16807) % 2147483647; return (s-1)/2147483646; }; })();

    const coralTypes = [
      { base: new THREE.Color(...this._pal.coralBase), accent: new THREE.Color(...this._pal.coralAccent) },
      { base: new THREE.Color(...this._pal.coralBase), accent: new THREE.Color(...this._pal.coralYellow) },
      { base: new THREE.Color(0.45, 0.15, 0.20), accent: new THREE.Color(...this._pal.coralAccent) },
    ];

    for (let i = 0; i < count; i++) {
      const x = (dr() - 0.5) * 100;
      const z = (dr() - 0.5) * 100;
      const h = this.heightmap(x, z);
      const y = Math.min(h, this.waterLevel - 0.5);
      const depth = this.waterLevel - y;
      if (depth > 12 || depth < 2) continue;

      const ct = coralTypes[Math.floor(dr() * coralTypes.length)];
      positions.push({
        x, y: y + 0.2, z, s: 0.6 + dr() * 1.2,
        base: ct.base, accent: ct.accent
      });
    }

    if (positions.length === 0) return null;

    const offsets = new Float32Array(positions.length * 3);
    const coralColors = new Float32Array(positions.length * 3);
    const scales = new Float32Array(positions.length);

    positions.forEach((p, i) => {
      offsets[i * 3] = p.x;
      offsets[i * 3 + 1] = p.y;
      offsets[i * 3 + 2] = p.z;
      scales[i] = p.s;
      /* Blend base and accent */
      const blend = Math.sin(i * 0.618) * 0.5 + 0.5;
      const c = p.base.clone().lerp(p.accent, blend);
      const depthFade = 1.0 - (this.waterLevel - p.y) * 0.04;
      coralColors[i * 3] = c.r * depthFade;
      coralColors[i * 3 + 1] = c.g * depthFade;
      coralColors[i * 3 + 2] = c.b * depthFade;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('coralColor', new THREE.InstancedBufferAttribute(coralColors, 3));

    const uniforms = {
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      sun: { value: new THREE.Vector3() },
    };

    const sh = coralShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
    });

    const mesh = new THREE.InstancedMesh(geo, mat, positions.length);
    positions.forEach((p, i) => {
      const m = new THREE.Matrix4();
      m.makeScale(p.s, p.s, p.s);
      m.setPosition(p.x, p.y, p.z);
      mesh.setMatrixAt(i, m);
    });
    mesh.renderOrder = 12;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── rock clusters ──────────────────────────────────────────────────── */
  _buildRocks(count = 60) {
    const baseGeo = buildRock();
    const positions = [];
    const dr = (() => { let s = 991; return () => { s = (s * 16807) % 2147483647; return (s-1)/2147483646; }; })();

    for (let i = 0; i < count; i++) {
      const x = (dr() - 0.5) * 140;
      const z = (dr() - 0.5) * 140;
      const h = this.heightmap(x, z);
      const y = Math.min(h, this.waterLevel - 0.5);
      positions.push({ x, y: y + 0.1, z, s: 0.4 + dr() * 2.0 });
    }

    const offsets = new Float32Array(positions.length * 3);
    const scales = new Float32Array(positions.length);
    positions.forEach((p, i) => {
      offsets[i * 3] = p.x;
      offsets[i * 3 + 1] = p.y;
      offsets[i * 3 + 2] = p.z;
      scales[i] = p.s;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('offset', new THREE.InstancedBufferAttribute(offsets, 3));

    const uniforms = {
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      uRockColor: { value: new THREE.Color(...this._pal.rockUW) },
      sun: { value: new THREE.Vector3() },
    };

    const sh = coralShader(); /* reuse coral's shader (same pattern, different color) */
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
    });

    const mesh = new THREE.InstancedMesh(geo, mat, positions.length);
    positions.forEach((p, i) => {
      const m = new THREE.Matrix4();
      m.makeScale(p.s, p.s * (0.5 + dr()), p.s);
      m.setPosition(p.x, p.y, p.z);
      mesh.setMatrixAt(i, m);
    });
    mesh.renderOrder = 11;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── sea grass ──────────────────────────────────────────────────────── */
  _buildSeaGrass(count = 200) {
    const baseGeo = buildSeaGrassBlade();
    const positions = [];
    const dr = (() => { let s = 1337; return () => { s = (s * 16807) % 2147483647; return (s-1)/2147483646; }; })();

    for (let i = 0; i < count; i++) {
      const x = (dr() - 0.5) * 130;
      const z = (dr() - 0.5) * 130;
      const h = this.heightmap(x, z);
      const y = Math.min(h, this.waterLevel - 0.5);
      if (this.waterLevel - y > 10) continue;
      positions.push({ x, y: y + 0.1, z, s: 0.7 + dr() * 0.8 });
    }

    if (positions.length === 0) return null;

    const offsets = new Float32Array(positions.length * 3);
    const sgIndices = new Float32Array(positions.length);
    const heights = new Float32Array(positions.length);
    positions.forEach((p, i) => {
      offsets[i * 3] = p.x;
      offsets[i * 3 + 1] = p.y;
      offsets[i * 3 + 2] = p.z;
      sgIndices[i] = i;
      heights[i] = 0.8;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('sgIndex', new THREE.InstancedBufferAttribute(sgIndices, 1));
    geo.setAttribute('offset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('height', new THREE.InstancedBufferAttribute(heights, 1));

    const uniforms = {
      uTime: { value: 0 },
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
    };

    const sh = seaGrassShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
      transparent: true,
      side: THREE.DoubleSide,
    });

    const mesh = new THREE.InstancedMesh(geo, mat, positions.length);
    positions.forEach((p, i) => {
      mesh.setMatrixAt(i, new THREE.Matrix4().makeTranslation(p.x, p.y, p.z));
    });
    mesh.renderOrder = 14;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── fish schools (boids, instanced) ────────────────────────────────── */
  _buildFish(count = 80, schoolCount = 4) {
    const baseGeo = buildFishMesh();
    const positions = [];
    const dr = (() => { let s = 2557; return () => { s = (s * 16807) % 2147483647; return (s-1)/2147483646; }; })();

    for (let i = 0; i < count; i++) {
      const school = i % schoolCount;
      const cx = (school - schoolCount / 2) * 12;
      const cz = (school - schoolCount / 2) * 8;
      positions.push({
        x: cx + (dr() - 0.5) * 10,
        y: this.waterLevel - 2 - dr() * (this.waterLevel - 5),
        z: cz + (dr() - 0.5) * 10,
        s: 0.5 + dr() * 0.5,
        idx: i,
        school,
        phase: dr() * 100,
      });
    }

    const offsets = new Float32Array(positions.length * 3);
    const fishIdx = new Float32Array(positions.length);
    const fishSize = new Float32Array(positions.length);
    const fishSchool = new Float32Array(positions.length);
    const fishPhase = new Float32Array(positions.length);

    positions.forEach((p, i) => {
      offsets[i * 3] = p.x;
      offsets[i * 3 + 1] = p.y;
      offsets[i * 3 + 2] = p.z;
      fishIdx[i] = p.idx;
      fishSize[i] = p.s;
      fishSchool[i] = p.school;
      fishPhase[i] = p.phase;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('fishOffset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('fishIdx', new THREE.InstancedBufferAttribute(fishIdx, 1));
    geo.setAttribute('fishSize', new THREE.InstancedBufferAttribute(fishSize, 1));
    geo.setAttribute('fishSchool', new THREE.InstancedBufferAttribute(fishSchool, 1));
    geo.setAttribute('fishPhase', new THREE.InstancedBufferAttribute(fishPhase, 1));

    const uniforms = {
      uTime: { value: 0 },
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      uFishBody: { value: new THREE.Color(...this._pal.fishBody) },
      uFishFin: { value: new THREE.Color(...this._pal.fishFin) },
    };

    const sh = fishShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
      transparent: true,
    });

    const mesh = new THREE.InstancedMesh(geo, mat, positions.length);
    positions.forEach((p, i) => {
      mesh.setMatrixAt(i, new THREE.Matrix4().makeTranslation(p.x, p.y, p.z));
    });
    mesh.renderOrder = 16;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── floating particles ─────────────────────────────────────────────── */
  _buildParticles(count = 150) {
    const positions = [];
    const sizes = [];
    const speeds = [];
    const phases = [];
    const dr = (() => { let s = 4096; return () => { s = (s * 16807) % 2147483647; return (s-1)/2147483646; }; })();

    for (let i = 0; i < count; i++) {
      const x = (dr() - 0.5) * 100;
      const y = this.waterLevel - 1 - dr() * 10;
      const z = (dr() - 0.5) * 100;
      positions.push(x, y, z);
      sizes.push(2 + dr() * 6);
      speeds.push(0.1 + dr() * 0.3);
      phases.push(dr() * 100);
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geo.setAttribute('particleSize', new THREE.Float32BufferAttribute(sizes, 1));
    geo.setAttribute('particleSpeed', new THREE.Float32BufferAttribute(speeds, 1));
    geo.setAttribute('particlePhase', new THREE.Float32BufferAttribute(phases, 1));

    const uniforms = {
      uTime: { value: 0 },
      uParticleColor: { value: new THREE.Color(...this._pal.particle) },
      uFogColor: { value: this.fogColor.clone() },
      camPos: { value: new THREE.Vector3() },
    };

    const sh = particleShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });

    const points = new THREE.Points(geo, mat);
    points.renderOrder = 25;
    this.scene.add(points);
    return { points, uniforms };
  }

  /* ── wreck landmark ─────────────────────────────────────────────────── */
  _buildWreck() {
    const geo = buildWreck();

    const uniforms = {
      uFogColor: { value: this.fogColor.clone() },
      fogNear: { value: this.fogNear },
      fogFar: { value: this.fogFar },
      camPos: { value: new THREE.Vector3() },
      sun: { value: new THREE.Vector3() },
      uWreckColor: { value: new THREE.Color(0.22, 0.18, 0.14) },
    };

    const sh = wreckShader();
    const mat = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: sh.vertexShader,
      fragmentShader: sh.fragmentShader,
    });

    const mesh = new THREE.Mesh(geo, mat);
    /* Place wreck on the sea floor, slightly tilted */
    const x = (Math.random() - 0.5) * 40;
    const z = (Math.random() - 0.5) * 40;
    const h = this.heightmap(x, z);
    mesh.position.set(x, Math.min(h, this.waterLevel - 0.5) - 0.3, z);
    mesh.rotation.set(0.2, Math.random() * Math.PI, 0.1);
    const s = 1.5 + Math.random() * 1.0;
    mesh.scale.set(s, s * 0.8, s);
    mesh.renderOrder = 9;
    this.scene.add(mesh);
    return { mesh, uniforms };
  }

  /* ── build all ──────────────────────────────────────────────────────── */
  _build() {
    this._seaFloor = this._buildSeaFloor();
    this._caustics = this._buildCaustics();
    this._surface = this._buildSurface();
    this._shafts = this._buildShafts();
    this._kelp = this._buildKelp();
    this._coral = this._buildCoral();
    this._rocks = this._buildRocks();
    this._seaGrass = this._buildSeaGrass();
    this._fish = this._buildFish();
    this._particles = this._buildParticles();
    this._wreck = this._buildWreck();

    this._allUniforms = [
      this._seaFloor.uniforms,
      this._caustics.uniforms,
      this._surface.uniforms,
      this._kelp && this._kelp.uniforms,
      this._coral && this._coral.uniforms,
      this._seaGrass && this._seaGrass.uniforms,
      this._fish && this._fish.uniforms,
      this._particles && this._particles.uniforms,
    ].filter(Boolean);
  }

  /* ── update loop ────────────────────────────────────────────────────── */
  update(time) {
    if (!this.enabled) return;

    /* Update all time uniforms */
    this._allUniforms.forEach(u => { if (u && u.uTime && u.uTime.value !== undefined) u.uTime.value = time; });
    (this._shafts || []).forEach(s => { if (s.uniforms && s.uniforms.uTime) s.uniforms.uTime.value = time; });
    if (this._fish && this._fish.uniforms && this._fish.uniforms.uTime) this._fish.uniforms.uTime.value = time;
    if (this._particles && this._particles.uniforms && this._particles.uniforms.uTime) this._particles.uniforms.uTime.value = time;

    /* Update camera position uniforms */
    const camPos = this.camera.position;
    this._allUniforms.forEach(u => { if (u && u.camPos && u.camPos.value !== undefined) u.camPos.value.copy(camPos); });

    /* Update sun direction */
    const sunDir = new THREE.Vector3(-0.6, 0.8, -0.4).normalize();
    if (this.sun && this.sun.target) {
      sunDir.subVectors(this.sun.target.position, this.sun.position).normalize();
    }
    if (this._caustics && this._caustics.uniforms && this._caustics.uniforms.uSunDir) this._caustics.uniforms.uSunDir.value.copy(sunDir);
    if (this._surface && this._surface.uniforms && this._surface.uniforms.uSunDir) this._surface.uniforms.uSunDir.value.copy(sunDir);
    this._allUniforms.forEach(u => { if (u && u.sun && u.sun.value !== undefined) u.sun.value.copy(sunDir); });
  }

  /* ── API ────────────────────────────────────────────────────────────── */
  /** Enable / disable all underwater effects. */
  toggle(on) {
    this.enabled = on;
    this._groups = [
      this._seaFloor.mesh,
      this._caustics.mesh,
      this._surface.mesh,
      this._kelp && this._kelp.mesh,
      this._coral && this._coral.mesh,
      this._rocks && this._rocks.mesh,
      this._seaGrass && this._seaGrass.mesh,
      this._fish && this._fish.mesh,
      this._particles && this._particles.points,
      this._wreck && this._wreck.mesh,
      ...this._shafts.map(s => s.mesh),
    ].filter(Boolean);
    this._groups.forEach(m => { m.visible = !!on; });
  }

  setWaterLevel(level) {
    this.waterLevel = level;
    if (this._surface) {
      this._surface.mesh.position.y = level;
    }
    if (this._caustics && this._caustics.uniforms && this._caustics.uniforms.uWaterLevel) {
      this._caustics.uniforms.uWaterLevel.value = level;
    }
  }

  /** Remove all objects from scene. */
  dispose() {
    this._groups.forEach(m => {
      this.scene.remove(m);
      if (m.geometry) m.geometry.dispose();
      if (m.material) {
        if (m.material.dispose) m.material.dispose();
        if (m.material.uniforms) {
          Object.values(m.material.uniforms).forEach(u => {
            if (u.value && u.value.dispose) u.value.dispose();
          });
        }
      }
    });
  }
}

/* ── export ───────────────────────────────────────────────────────────── */
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { UnderwaterBiome };
}