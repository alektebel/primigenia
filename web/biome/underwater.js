/** web/biome/underwater.js — Underwater biome look (G64), round 2.
 *
 * Three.js r128 (non-module global build, same vendored copy the preview uses).
 * Given { scene, waterLevel, heightmap, palette, renderer, camera, sun } it adds:
 *   - Wavy surface seen from below with a Snell's window (bright disc straight
 *     up, total internal reflection beyond ~48.6° — no sky/horizon sideways)
 *   - Exponential depth fog / absorption (blue-green, darker with depth) shared
 *     by every material; scene background is the fog colour, never the sky
 *   - Animated caustics on a pale rippled sand floor (pebbles, shells, dappled)
 *   - God rays fanning down from the surface
 *   - Kelp forests (instanced fronds with leaves, translucent, swaying, 3–8 m)
 *   - Coral clusters (pink/orange/purple/yellow/red), rocks, sea grass
 *   - Fish schools (instanced, silver/blue/yellow, travelling in coherent
 *     schools with per-fish drift — boid-like)
 *   - Floating particles (marine snow)
 *   - One shipwreck landmark: hull ribs + planked hull, keel, mast stump,
 *     broken planks, encrusted, tilted, half-buried
 *
 * All materials share a common uniform block (uTime, camPos, uSunDir,
 * uWaterLevel, uFloorY, uFogDensity, uFogShallow, uFogDeep) so the whole look
 * can be re-atmospherised per preset with setAtmosphere().
 */

/* ── helpers ─────────────────────────────────────────────────────────── */
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

/* Deterministic RNG (seeded) so previews and captures are reproducible. */
function mulberry(seed) {
  let s = seed >>> 0;
  return function () {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/* ── palette data (palette C "Current+" extended for underwater) ─────── */
const PAL = {
  waterDeep:    [0.010, 0.070, 0.130],
  waterMid:     [0.040, 0.180, 0.300],
  waterShallow: [0.100, 0.400, 0.500],
  causticBright:[0.85, 0.95, 0.90],
  causticDim:   [0.30, 0.50, 0.52],
  shaftWarm:    [1.00, 0.88, 0.62],
  kelpDark:     [0.13, 0.24, 0.08],
  kelpLight:    [0.26, 0.42, 0.14],
  coralRed:     [0.72, 0.22, 0.16],
  coralYellow:  [0.90, 0.68, 0.12],
  coralPink:    [0.88, 0.32, 0.52],
  coralOrange:  [0.94, 0.52, 0.16],
  coralPurple:  [0.58, 0.24, 0.62],
  rockUW:       [0.18, 0.21, 0.20],
  rockAlgae:    [0.11, 0.20, 0.10],
  sand:         [0.80, 0.72, 0.54],
  sandBright:   [0.95, 0.90, 0.74],
  particle:     [0.72, 0.82, 0.80],
};

/* ── GLSL shared chunk (uniforms + exponential underwater fog) ───────── */
const UW_COMMON = `
uniform float uTime;
uniform vec3  camPos;
uniform vec3  uSunDir;      /* unit vector pointing TOWARD the sun (upward) */
uniform float uWaterLevel;
uniform float uFloorY;
uniform float uFogDensity;  /* absorption per metre near the surface */
uniform vec3  uFogShallow;  /* water colour just under the surface */
uniform vec3  uFogDeep;     /* water colour far down */

/* Water colour at a given depth below the surface (continuous, no band). */
vec3 uwFogColor(float depthBelow){
  return mix(uFogShallow, uFogDeep, clamp(depthBelow / 22.0, 0.0, 1.0));
}

/* Exponential absorption + in-scatter of the water colour. */
vec3 applyUWFog(vec3 c, vec3 worldPos){
  float d = length(worldPos - camPos);
  float depthBelow = max(uWaterLevel - worldPos.y, 0.0);
  float k = uFogDensity * (1.0 + depthBelow * 0.10);
  float f = 1.0 - exp(-d * k);
  return mix(c, uwFogColor(depthBelow), f);
}

float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p){
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x),
             mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
mat3 rotY(float a){ float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }
`;

/* ── surface: wavy, seen from below, Snell's window + TIR ────────────── */
function surfaceShader() {
  const vertexShader = `
${UW_COMMON}
varying vec3 vWorldPos;
varying vec3 vNormal;

void main(){
  vec3 pos = position;
  /* Multi-sine wave displacement (world XZ plane, waves lift Y). */
  float wave = sin(pos.x*0.55 + uTime*1.1)*0.14
             + sin(pos.z*0.80 + uTime*0.8)*0.11
             + sin((pos.x+pos.z)*1.30 + uTime*1.7)*0.05
             + sin(pos.x*2.40 - pos.z*1.70 + uTime*2.6)*0.025;
  pos.y += wave;

  /* Analytical normal from wave gradients */
  float dx = cos(pos.x*0.55 + uTime*1.1)*0.55*0.14
           + cos((pos.x+pos.z)*1.30 + uTime*1.7)*1.30*0.05
           + cos(pos.x*2.40 - pos.z*1.70 + uTime*2.6)*2.40*0.025;
  float dz = cos(pos.z*0.80 + uTime*0.8)*0.80*0.11
           + cos((pos.x+pos.z)*1.30 + uTime*1.7)*1.30*0.05
           + cos(pos.x*2.40 - pos.z*1.70 + uTime*2.6)*(-1.70)*0.025;
  vec3 normal = normalize(vec3(-dx, 1.0, -dz));

  vWorldPos = (modelMatrix * vec4(pos, 1.0)).xyz;
  vNormal = normalize(normalMatrix * normal);
  gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}`;

  const fragmentShader = UW_COMMON + `
uniform vec3 uSunGlow;   /* bright sky colour seen through Snell's window */
uniform vec3 uShaftGlow; /* golden shaft colour for glitter */

/* Manual refraction (no refract() builtin).
   Light goes from water (n≈1.33) to air (n≈1.0):
   refract(I, N, n_water / n_air) where I = cam→surface, N = surface normal. */
vec3 manualRefract(vec3 I, vec3 N, float eta){
  float NdotI = dot(N, I);
  float k = 1.0 - eta * eta * (1.0 - NdotI * NdotI);
  if (k < 0.0) return vec3(0.0); /* TIR — no refracted direction */
  return eta * I + (eta * NdotI - sqrt(k)) * N;
}

varying vec3 vWorldPos;
varying vec3 vNormal;

void main(){
  vec3 n = normalize(vNormal);
  vec3 d = normalize(vWorldPos - camPos);  /* camera → surface point */

  /* Snell's window: a bright disc straight up (~48.6° half-angle).
     cos(48.6°) ≈ 0.66; light within this cone is refracted from above. */
  float cosAngle = d.y; /* angle from vertical (up) */
  float win = smoothstep(0.58, 0.72, cosAngle);

  /* Refraction for sun glitter — only valid within Snell's window. */
  vec3 refr = manualRefract(d, vec3(0.0, -1.0, 0.0), 1.0 / 1.33);
  float glitter = 0.0;
  if (dot(refr, refr) > 0.01){
    glitter = pow(max(dot(refr, uSunDir), 0.0), 60.0);
  }

  /* Transmitted content: bright sky-glow + sun glitter. */
  vec3 windowCol = uSunGlow * (0.50 + 0.50 * pow(cosAngle, 2.0));
  windowCol += uShaftGlow * glitter * 3.0 * win;

  /* Total internal reflection beyond the window: darker water-colour.
     This is the correct look when looking sideways — you see the water
     below, NOT the sky. The TIR surface acts like a mirror reflecting
     the underwater scene. */
  float depthBelow = max(uWaterLevel - vWorldPos.y, 0.0);
  vec3 tirCol = uwFogColor(depthBelow + 3.0) * 0.75;

  /* Mix: window (sky) for the center disc, TIR (water) for the edges. */
  vec3 c = mix(tirCol, windowCol, win);

  /* Wavy sparkle on the surface where light hits head-on. */
  c += uShaftGlow * 0.25 * pow(max(dot(n, uSunDir), 0.0), 4.0) * win;

  /* Edge fog absorption on the surface mesh itself. */
  float dist = length(vWorldPos - camPos);
  float f = 1.0 - exp(-dist * uFogDensity * 1.2);
  c = mix(c, uwFogColor(depthBelow), f);

  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── sea floor: pale rippled sand, pebbles, shells, animated caustics ── */
function floorShader() {
  const vertexShader = `
${UW_COMMON}
varying vec3 vWorldPos;
varying vec3 vNormal;
void main(){
  vWorldPos = position;
  vNormal = normalize(normalMatrix * normal);
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

  const fragmentShader = UW_COMMON + `
uniform vec3 uSandColor;
uniform vec3 uSandBright;
uniform vec3 uCausticBright;
uniform vec3 uCausticDim;
uniform float uCausticAmp;

varying vec3 vWorldPos;
varying vec3 vNormal;

/* Ripple / fine sand noise */
float sandNoise(vec2 p){
  return vn(p * 3.0) * 0.3 + vn(p * 8.0) * 0.15 + vn(p * 20.0) * 0.05;
}

void main(){
  vec3 worldPos = vWorldPos;
  float depthBelow = max(uWaterLevel - worldPos.y, 0.0);

  /* Animated caustics: multi-layer sine flow */
  vec2 p = worldPos.xz * 0.4;
  float c1 = sin(p.x * 3.0 + sin(p.y * 2.0 + uTime * 0.9) * 1.2 + uTime * 0.5);
  float c2 = sin(p.y * 2.5 + cos(p.x * 1.8 + uTime * 0.7) * 1.0 + uTime * 0.6);
  float c3 = sin((p.x + p.y) * 2.0 + uTime * 1.1 + sin(p.x * 3.0 + p.y * 2.0) * 0.5);
  float caustic = (c1 * c1 * 0.5 + c2 * c2 * 0.35 + c3 * 0.15) * uCausticAmp;

  /* Depth fade: caustics strongest near surface, fade with depth */
  float depthFade = 1.0 - smoothstep(0.0, 14.0, depthBelow);
  caustic *= depthFade;

  /* Caustic pattern on sand */
  vec2 uv = worldPos.xz * 0.5;
  float causticPattern = pow(clamp(caustic, 0.0, 1.0), 1.3);
  vec3 causticColor = mix(uCausticDim, uCausticBright, causticPattern);

  /* Base sand with ripple height variation */
  float ripple = sin(worldPos.x * 0.8 + worldPos.z * 0.6) * 0.5 + 0.5;
  float sandTex = sandNoise(worldPos.xz);
  vec3 sand = mix(uSandColor * 0.9, uSandColor, 0.5 + sandTex * 0.5);
  sand = mix(sand, uSandBright, ripple * 0.25 * depthFade);

  /* Combine: sand base + caustic overlay */
  vec3 c = mix(sand * 0.85, causticColor, causticPattern * 0.65);

  /* Pebbles / shells: bright spots scattered */
  float pebble = step(0.92, vn(worldPos.xz * 4.5 + vec2(7.3, 13.7)));
  float shell = step(0.95, vn(worldPos.xz * 6.0 + vec2(23.1, 5.2)));
  c += (pebble * 0.06 + shell * 0.10) * uSandBright;

  /* Exponential underwater fog */
  c = applyUWFog(c, worldPos);

  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── kelp: instanced frond with leaves, translucent, swaying ─────────── */
function kelpShader() {
  const vertexShader = `
uniform float uTime;
attribute vec3 kelpOffset;
attribute float kelpHeight;   /* Y scale (3–8 m) */
attribute float kelpWidth;    /* XZ scale */
attribute float kelpPhase;
attribute vec3 kelpColor;
varying vec3 vColor;
varying vec3 vWorldPos;
varying vec3 vN;
varying float vH;

void main(){
  vColor = kelpColor;
  float hn = position.y;              /* unit frond: 0 base → 1 tip */
  vH = hn;

  vec3 pos = position;
  /* Sway: amplitude grows quadratically from the base. */
  float sw = hn * hn;
  float phase = kelpPhase + uTime * 0.9 + kelpOffset.x * 0.35 + kelpOffset.z * 0.30;
  pos.x += sin(phase) * sw * 0.55;
  pos.z += sin(phase * 0.80 + 1.7) * sw * 0.35;

  pos.x *= kelpWidth;
  pos.z *= kelpWidth;
  pos.y *= kelpHeight;

  vec4 wp = modelMatrix * vec4(pos + kelpOffset, 1.0);
  vWorldPos = wp.xyz;
  /* Ribbon faces ~X before instance rotation; normalish for translucency. */
  vN = normalize(normalMatrix * normalize(vec3(0.0, 0.15, 1.0)));
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = UW_COMMON + `
varying vec3 vColor;
varying vec3 vWorldPos;
varying vec3 vN;
varying float vH;

void main(){
  vec3 V = normalize(camPos - vWorldPos);
  /* Translucency: glow when the frond is between the camera and the sun. */
  float back = pow(max(dot(V, uSunDir), 0.0), 3.0);
  float wrap = max(dot(vN, uSunDir) * 0.5 + 0.5, 0.0);

  float depthBelow = max(uWaterLevel - vWorldPos.y, 0.0);
  float sunReach = exp(-depthBelow * 0.10);

  vec3 c = vColor * (0.30 + 0.55 * wrap * sunReach + 0.25 * vH);
  c += vColor * back * 0.9 * sunReach;      /* backlit glow */
  c = mix(c, vColor * 1.35, vH * 0.25);     /* brighter tips */

  c = applyUWFog(c, vWorldPos);
  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── coral: clustered, per-instance colour, sun-lit ──────────────────── */
function coralShader() {
  const vertexShader = `
attribute vec3 instOffset;
attribute float instScale;
attribute vec3 instColor;
varying vec3 vColor;
varying vec3 vN;
varying vec3 vWorldPos;
void main(){
  vColor = instColor;
  vN = normalize(normalMatrix * normal);
  vec4 wp = modelMatrix * vec4(position * instScale + instOffset, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = UW_COMMON + `
varying vec3 vColor;
varying vec3 vN;
varying vec3 vWorldPos;

void main(){
  float depthBelow = max(uWaterLevel - vWorldPos.y, 0.0);
  float sunReach = exp(-depthBelow * 0.12);
  float wrap = max(dot(vN, uSunDir) * 0.5 + 0.5, 0.0);

  vec3 c = vColor * (0.40 + 0.85 * wrap * sunReach);
  c += vColor * 0.25 * pow(max(dot(vN, uSunDir), 0.0), 2.0) * sunReach;

  c = applyUWFog(c, vWorldPos);
  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── rocks: dark stone with algae on top ─────────────────────────────── */
function rockShader() {
  const vertexShader = `
attribute vec3 instOffset;
attribute vec3 instScale;
varying vec3 vN;
varying vec3 vWorldPos;
void main(){
  vN = normalize(normalMatrix * normal);
  vec4 wp = modelMatrix * vec4(position * instScale + instOffset, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = UW_COMMON + `
uniform vec3 uRockColor;
uniform vec3 uAlgaeColor;

varying vec3 vN;
varying vec3 vWorldPos;

void main(){
  float depthBelow = max(uWaterLevel - vWorldPos.y, 0.0);
  float sunReach = exp(-depthBelow * 0.10);
  float wrap = max(dot(vN, uSunDir) * 0.5 + 0.5, 0.0);

  /* Algae on upward faces, patched by noise. */
  float algae = smoothstep(0.25, 0.75, vN.y) * smoothstep(0.45, 0.75, vn(vWorldPos.xz * 1.7));
  vec3 base = mix(uRockColor, uAlgaeColor, algae * 0.8);

  vec3 c = base * (0.40 + 0.80 * wrap * sunReach);
  c = applyUWFog(c, vWorldPos);
  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── sea grass: thin blades ──────────────────────────────────────────── */
function seaGrassShader() {
  const vertexShader = `
uniform float uTime;
attribute vec3 instOffset;
attribute float instScale;
attribute float instPhase;
varying vec3 vWorldPos;
varying float vH;
void main(){
  float hn = position.y;
  vH = hn;
  vec3 pos = position;
  pos.x += hn * hn * sin(instPhase + uTime * 1.2) * 0.18;
  pos.z += hn * hn * sin(instPhase * 0.7 + uTime * 0.9) * 0.12;
  pos *= instScale;
  vec4 wp = modelMatrix * vec4(pos + instOffset, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = UW_COMMON + `
varying vec3 vWorldPos;
varying float vH;

void main(){
  float depthBelow = max(uWaterLevel - vWorldPos.y, 0.0);
  float sunReach = exp(-depthBelow * 0.10);
  vec3 c = mix(vec3(0.10, 0.22, 0.09), vec3(0.24, 0.44, 0.16), vH * sunReach);
  c = applyUWFog(c, vWorldPos);
  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── fish: instanced, coherent schools + per-fish drift ──────────────── */
function fishShader() {
  const vertexShader = `
uniform float uTime;
attribute vec3 fishLocal;    /* position relative to the school centre */
attribute float fishIdx;
attribute float fishSize;
attribute float fishSchool;
attribute float fishPhase;
attribute vec3 fishColor;
varying vec3 vLocal;
varying vec3 vWorldPos;
varying float vShade;
varying vec3 vFishCol;

vec3 noise3(vec3 p){
  p = fract(p * 0.3183099);
  p *= 17.0;
  return fract(sin(p * vec3(12.9898, 78.233, 45.164)) * 43758.5453);
}

void main(){
  /* School centre follows a closed loop; per school offset/radius. */
  float sa = uTime * 0.22 + fishSchool * 2.09;
  float rr = 9.0 + fishSchool * 2.3;
  float midY = clamp((uFloorY + uWaterLevel) * 0.5 + sin(uTime * 0.40 + fishSchool * 1.9) * 1.6,
                     uFloorY + 1.5, uWaterLevel - 1.5);
  vec3 center = vec3(cos(sa) * rr, midY, sin(sa * 0.8) * rr * 0.7);
  vec3 tang = normalize(vec3(-sin(sa) * rr,
                             cos(uTime * 0.40 + fishSchool * 1.9) * 1.6 * 0.4,
                             cos(sa * 0.8) * rr * 0.7 * 0.8));
  float yaw = atan(-tang.z, tang.x);

  /* Per-fish slow orbit inside the school + wander (boid feel). */
  vec3 local = rotY(uTime * 0.15 * sin(fishPhase) + fishPhase) * fishLocal;
  local += (noise3(vec3(fishPhase + uTime * 0.4, fishSchool * 0.7, fishIdx * 0.13)) - 0.5) * 1.1;

  vLocal = position;
  vShade = 0.85 + 0.30 * fract(fishIdx * 0.618033988);
  vFishCol = fishColor;

  vec3 pos = position * fishSize;
  /* Tail wag: more toward the tail (−X). */
  float wag = sin(uTime * 7.0 + fishIdx * 1.7) * 0.14 * clamp(-position.x * 6.0, 0.0, 1.0);
  pos.z += wag;
  pos.y += wag * 0.35;

  vec4 wp = modelMatrix * vec4(rotY(yaw) * pos + center + local, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = UW_COMMON + `
varying vec3 vLocal;
varying vec3 vWorldPos;
varying float vShade;
varying vec3 vFishCol;

void main(){
  /* Per-school colour set from JS; slight per-fish shading. */
  vec3 c = vFishCol * vShade;
  /* Belly lighter, back darker. */
  c *= 1.0 + clamp(-vLocal.y * 8.0, -0.25, 0.35);
  /* Eye. */
  if (vLocal.x > 0.095 && abs(vLocal.y) < 0.030 && abs(vLocal.z) < 0.040) c = vec3(0.03);

  c = applyUWFog(c, vWorldPos);
  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader, extraUniforms: { vFishCol: null } };
}

/* ── marine snow: floating particles ─────────────────────────────────── */
function particleShader() {
  const vertexShader = UW_COMMON + `
attribute float pSize;
attribute float pSpeed;
attribute float pPhase;
varying float vA;

void main(){
  /* Slow sink with wrap inside a band, plus gentle drift. */
  float bandH = 14.0;
  float bandC = (uFloorY + uWaterLevel) * 0.5;
  float sink = fract(pPhase + uTime * pSpeed * 0.02);
  vec3 pos = position;
  pos.y = bandC + (sink - 0.5) * bandH;
  pos.x += sin(pPhase * 17.0 + uTime * 0.25) * 0.5;
  pos.z += cos(pPhase * 23.0 + uTime * 0.20) * 0.4;

  vec4 wp = modelMatrix * vec4(pos, 1.0);
  gl_Position = projectionMatrix * viewMatrix * wp;

  float dist = length(wp.xyz - camPos);
  gl_PointSize = pSize * (140.0 / max(dist, 1.0));
  vA = (0.35 + 0.65 * fract(pPhase * 6.28)) * (1.0 - smoothstep(18.0, 34.0, dist));
}`;

  const fragmentShader = `
uniform vec3 uParticleColor;
varying float vA;

void main(){
  vec2 center = gl_PointCoord - 0.5;
  float d = length(center);
  if (d > 0.5) discard;
  float a = smoothstep(0.5, 0.12, d) * vA;
  gl_FragColor = vec4(uParticleColor, a * 0.5);
}`;

  return { vertexShader, fragmentShader };
}

/* ── god rays: tapered additive shafts fanning down from the surface ─── */
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
  float center = pow(1.0 - abs(vUv.x - 0.5) * 2.0, 1.6);
  /* Strong near the surface (vUv.y = 1), fading with depth. */
  float vert = mix(0.15, 1.0, vUv.y);
  float shimmer = 0.75 + 0.25 * sin(vUv.y * 14.0 - uTime * 1.1 + vUv.x * 3.0);
  float a = center * vert * shimmer * uOpacity;
  gl_FragColor = vec4(uShaftColor, a);
}`;

  return { vertexShader, fragmentShader };
}

/* ── shipwreck landmark ──────────────────────────────────────────────── */
function wreckShader() {
  const vertexShader = `
varying vec3 vN;
varying vec3 vWorldPos;
void main(){
  vN = normalize(normalMatrix * normal);
  vec4 wp = modelMatrix * vec4(position, 1.0);
  vWorldPos = wp.xyz;
  gl_Position = projectionMatrix * viewMatrix * wp;
}`;

  const fragmentShader = UW_COMMON + `
uniform vec3 uWreckColor;

varying vec3 vN;
varying vec3 vWorldPos;

void main(){
  float depthBelow = max(uWaterLevel - vWorldPos.y, 0.0);
  float sunReach = exp(-depthBelow * 0.10);
  float wrap = max(dot(vN, uSunDir) * 0.5 + 0.5, 0.0);

  /* Algae on up faces, barnacle patches, dark crevices. */
  float algae = smoothstep(0.30, 0.75, vN.y) * smoothstep(0.40, 0.70, vn(vWorldPos.xz * 2.3));
  float barnacle = smoothstep(0.72, 0.78, vn(vWorldPos.xz * 3.4 + 21.0)) * smoothstep(0.0, 0.6, vN.y);
  vec3 base = mix(uWreckColor, vec3(0.10, 0.18, 0.08), algae * 0.7);
  base = mix(base, vec3(0.70, 0.68, 0.58), barnacle * 0.55);

  vec3 c = base * (0.42 + 0.80 * wrap * sunReach);
  c = applyUWFog(c, vWorldPos);
  gl_FragColor = vec4(c, 1.0);
}`;

  return { vertexShader, fragmentShader };
}

/* ── instanced geometry builders ──────────────────────────────────────── */

/** Kelp frond: tapered stalk ribbon + alternating leaves. Unit height 1. */
function buildKelpFrond(rng) {
  const P = [], I = [];
  const v = (x, y, z) => { P.push(x, y, z); return P.length / 3 - 1; };
  const tri = (a, b, c) => I.push(a, b, c);
  const quadI = (a, b, c, d) => I.push(a, b, c, a, c, d);

  /* Stalk: 11 rows, width 0.09 → 0.03, slight S-curve. */
  const rows = 10;
  const stalk = [];
  for (let i = 0; i <= rows; i++) {
    const t = i / rows;
    const w = 0.09 * (1.0 - t * 0.65) + 0.015;
    const z = t * t * 0.10 - t * 0.03;
    stalk.push(P.length / 3);
    P.push(-w, t, z, w, t, z);
  }
  /* rows: a=row_i left, b=row_i right, c=row_{i+1} left, d=row_{i+1} right */
  for (let i = 0; i < rows; i++) {
    const a = stalk[i], b = stalk[i] + 1;
    const c = stalk[i + 1], d = stalk[i + 1] + 1;
    quadI(a, c, b, b, c, d);
  }

  /* Leaves: drooping triangles, alternating sides, two per level. */
  for (let li = 3; li <= rows - 1; li += 2) {
    const t = li / rows;
    const w = 0.09 * (1.0 - t * 0.65) + 0.015;
    const z0 = t * t * 0.10 - t * 0.03;
    const len = 0.26 + 0.12 * (1.0 - t);
    for (const side of [1, -1]) {
      const a = v(side * w * 0.4, t, z0);
      const b = v(side * (w + len * 0.65), t + 0.09, z0 + 0.05);
      const c = v(side * (w + len), t - 0.03, z0 + 0.18);
      tri(a, b, c);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  geo.setIndex(I);
  geo.computeVertexNormals();
  return geo;
}

/** Small diamond fish (body along +X, nose forward) with tail + dorsal fin. */
function buildFishMesh() {
  const P = [], I = [];
  const tri = (a, b, c) => I.push(a, b, c);
  const v = (x, y, z) => { P.push(x, y, z); return P.length / 3 - 1; };

  const nose = v(0.16, 0, 0);
  const tail = v(-0.10, 0, 0);
  /* Ring at x=0.03 */
  const r1 = [v(0.03, 0.045, 0), v(0.03, 0, 0.040), v(0.03, -0.045, 0), v(0.03, 0, -0.040)];
  /* Ring at x=-0.04 */
  const r2 = [v(-0.04, 0.040, 0), v(-0.04, 0, 0.035), v(-0.04, -0.040, 0), v(-0.04, 0, -0.035)];

  for (let i = 0; i < 4; i++) {
    const j = (i + 1) % 4;
    tri(nose, r1[i], r1[j]);
    tri(r1[i], r2[i], r2[j]);
    tri(r1[i], r2[j], r2[i]);
    tri(tail, r2[j], r2[i]);
  }
  /* Tail fin */
  const tf1 = v(-0.20, 0.075, 0), tf2 = v(-0.20, -0.075, 0);
  tri(tail, tf1, tf2);
  /* Dorsal fin */
  const d1 = v(-0.02, 0.095, 0);
  tri(v(0.01, 0.040, 0), d1, v(-0.07, 0.038, 0));

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  geo.setIndex(I);
  geo.computeVertexNormals();
  return geo;
}

/** Branching coral tube cluster (unit size ~0.7 m). */
function buildCoralShape() {
  const P = [], I = [];
  const tube = (px, py, pz, dx, dy, dz, len, r0, r1, segs) => {
    const base = P.length / 3;
    const dir = new THREE.Vector3(dx, dy, dz).normalize();
    const ortho = Math.abs(dir.y) < 0.9 ? new THREE.Vector3(0, 1, 0) : new THREE.Vector3(1, 0, 0);
    const t1 = new THREE.Vector3().crossVectors(dir, ortho).normalize();
    const t2 = new THREE.Vector3().crossVectors(dir, t1).normalize();
    const start = new THREE.Vector3(px, py, pz);
    const end = start.clone().addScaledVector(dir, len);
    const ring = [];
    for (let s = 0; s <= segs; s++) {
      const a = (s / segs) * Math.PI * 2;
      const off = new THREE.Vector3().addScaledVector(t1, Math.cos(a)).addScaledVector(t2, Math.sin(a));
      const pA = start.clone().addScaledVector(off, r0);
      const pB = end.clone().addScaledVector(off, r1);
      ring.push([P.length / 3, P.length / 3 + 1]);
      P.push(pA.x, pA.y, pA.z, pB.x, pB.y, pB.z);
    }
    for (let s = 0; s < segs; s++) {
      const [a0, b0] = ring[s], [a1, b1] = ring[s + 1];
      I.push(a0, a1, b0, b0, a1, b1);
    }
  };

  tube(0, 0, 0, 0.02, 1, 0.02, 0.55, 0.075, 0.045, 6);
  tube(0.02, 0.18, 0.0, 0.55, 0.65, 0.15, 0.34, 0.05, 0.02, 6);
  tube(0.0, 0.22, 0.02, -0.45, 0.60, -0.35, 0.30, 0.05, 0.02, 6);
  tube(0.03, 0.34, 0.02, 0.15, 0.95, -0.35, 0.26, 0.035, 0.015, 6);
  /* Base blob: low dome (centre + ring). */
  {
    const centre = P.length / 3;
    P.push(0, 0.02, 0);
    const ringStart = P.length / 3;
    for (let s = 0; s < 8; s++) {
      const a = (s / 8) * Math.PI * 2;
      P.push(Math.cos(a) * 0.12, 0.0, Math.sin(a) * 0.12);
    }
    for (let s = 0; s < 8; s++) {
      const j = (s + 1) % 8;
      I.push(centre, ringStart + j, ringStart + s);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  geo.setIndex(I);
  geo.computeVertexNormals();
  return geo;
}

/** Irregular rock blob. */
function buildRock(rng) {
  const geo = new THREE.IcosahedronGeometry(1, 1);
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const n = 1.0 + (rng() - 0.5) * 0.25 + Math.sin(x * 4.0 + z * 3.0) * 0.08;
    pos.setXYZ(i, x * n, y * n * (0.55 + rng() * 0.25), z * n);
  }
  pos.needsUpdate = true;
  geo.computeVertexNormals();
  return geo;
}

/** Thin sea-grass blade (two triangles). */
function buildSeaGrassBlade() {
  const h = 0.85, w = 0.028;
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute([
    -w, 0, 0,  w, 0, 0,  0, h, 0.03,
  ], 3));
  geo.setIndex([0, 1, 2]);
  geo.computeVertexNormals();
  return geo;
}

/** Tapered vertical shaft quad (top edge offset = lean). uv.y=1 at top. */
function buildShaftGeo(wTop, wBottom, h, lean) {
  const off = lean * h;
  const hwT = wTop / 2, hwB = wBottom / 2;
  const P = [
    -hwT + off, h, 0,  hwT + off, h, 0,  hwB, 0, 0,
    -hwT + off, h, 0,  hwB, 0, 0,  -hwB, 0, 0,
  ];
  const uv = [0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0];
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  return geo;
}

/**
 * Shipwreck: planked half-ellipse hull on ribs, keel, tilted mast stump,
 * scattered broken planks, encrustation. Half-buried (below y=0 is sand).
 */
function buildWreck(rng) {
  const P = [], I = [];
  const v = (x, y, z) => { P.push(x, y, z); return P.length / 3 - 1; };
  const tri = (a, b, c) => I.push(a, b, c);
  const quad = (a, b, c, d) => I.push(a, b, c, a, c, d);

  /* Hull: ribs along Z, half-ellipse cross-sections, some ribs/panels missing. */
  const nR = 9, nSeg = 7;
  const rings = [];
  for (let i = 0; i < nR; i++) {
    const t = i / (nR - 1);
    const z = -2.3 + t * 4.6;
    const fullness = Math.sin(Math.min(t / 0.22, (1 - t) / 0.22, 1) * Math.PI * 0.5 + Math.PI * 0.5);
    const len = Math.sin(Math.min(1, t / 0.18, (1 - t) / 0.18) * Math.PI * 0.5);
    const R = 0.10 + 1.00 * len;
    const H = 0.08 + 0.60 * len;
    const ring = [];
    for (let j = 0; j <= nSeg; j++) {
      const a = Math.PI * j / nSeg;
      ring.push(v(Math.cos(a) * R, Math.sin(a) * H - 0.34, z));
    }
    rings.push({ ring, z });
  }
  /* Skin between ribs; a hole mid-port side (broken planks). */
  for (let i = 0; i < nR - 1; i++) {
    for (let j = 0; j < nSeg; j++) {
      if (i >= 3 && i <= 4 && j >= 3 && j <= 4) continue; /* hull breach */
      quad(rings[i].ring[j], rings[i].ring[j + 1], rings[i + 1].ring[j + 1], rings[i + 1].ring[j]);
    }
  }

  /* Boxes (keel, planks, mast, beams). Axis-aligned then optionally rotated. */
  const box = (cx, cy, cz, w, h, d, yaw) => {
    const c = Math.cos(yaw || 0), s = Math.sin(yaw || 0);
    const rot = (x, z) => [cx + x * c - z * s, cz + x * s + z * c];
    const corners = [];
    for (const sy of [-1, 1]) for (const sz of [-1, 1]) {
      const [x, z] = rot(w / 2, sz * d / 2); corners.push(v(x, cy + sy * h / 2, z));
    }
    for (const sy of [-1, 1]) for (const sz of [-1, 1]) {
      const [x, z] = rot(-w / 2, sz * d / 2); corners.push(v(x, cy + sy * h / 2, z));
    }
    /* corners: 0..3 = +x side (±y, ∓z), 4..7 = −x side */
    const [f0, f1, f2, f3, b0, b1, b2, b3] = corners;
    /* +z face (f0,f1 bottom?) — corners order: (-y,-z),(+y,-z),(-y,+z),(+y,+z) for +x; same for −x */
    quad(f0, f2, f3, f1);           /* +z face (x = +w/2 rotated) */
    quad(b0, b1, b3, b2);           /* −z face */
    quad(f0, f1, b1, b0);           /* bottom (−y) */
    quad(f2, b2, b3, f3);           /* top (+y) */
    quad(f0, b0, b2, f2);           /* −x rotated... side */
    quad(f1, f3, b3, b1);           /* other side */
  };

  /* Keel (half buried) */
  box(0, -0.32, 0, 0.16, 0.12, 4.8, 0);
  /* Deck beam stumps */
  box(-0.4, 0.30, -0.8, 0.10, 0.10, 0.9, 0.1);
  box(0.5, 0.26, 1.2, 0.10, 0.10, 0.8, -0.15);
  /* Broken planks on the sand */
  box(-2.9, -0.30, 1.1, 1.1, 0.05, 0.24, 0.7);
  box(2.6, -0.30, -1.4, 0.9, 0.05, 0.22, 1.9);
  box(1.4, -0.30, 2.5, 1.3, 0.05, 0.26, 0.35);
  box(-1.8, -0.30, -2.6, 0.8, 0.05, 0.20, 2.6);
  /* Mast stump: tall, leaning */
  {
    const mh = 2.3, mx = 0.15, mz = 0.55, lean = 0.38;
    const b = v(mx - 0.07, -0.2, mz - 0.07);
    const t = v(mx - 0.07 + lean, mh, mz - 0.07);
    const c1 = v(mx + 0.07 + lean, mh, mz - 0.07);
    const c2 = v(mx + 0.07, -0.2, mz - 0.07);
    const c3 = v(mx - 0.07 + lean, mh, mz + 0.07);
    const c4 = v(mx + 0.07 + lean, mh, mz + 0.07);
    const c5 = v(mx + 0.07, -0.2, mz + 0.07);
    quad(b, c2, c1, t); quad(t, c1, c4, c3); quad(c3, c4, c5, b);
    quad(c2, c1, c4, c5);   /* +x face of the mast */
    /* crossbeam fragment */
    const y = 1.6;
    quad(v(mx - 0.55 + lean * y / mh, y, mz - 0.05), v(mx + 0.55 + lean * y / mh, y, mz - 0.05),
         v(mx + 0.55 + lean * y / mh, y + 0.07, mz - 0.05), v(mx - 0.55 + lean * y / mh, y + 0.07, mz - 0.05));
    quad(v(mx - 0.55 + lean * y / mh, y, mz + 0.05), v(mx - 0.55 + lean * y / mh, y + 0.07, mz + 0.05),
         v(mx + 0.55 + lean * y / mh, y + 0.07, mz + 0.05), v(mx + 0.55 + lean * y / mh, y, mz + 0.05));
    quad(v(mx - 0.55 + lean * y / mh, y + 0.07, mz - 0.05), v(mx - 0.55 + lean * y / mh, y + 0.07, mz + 0.05),
         v(mx + 0.55 + lean * y / mh, y + 0.07, mz + 0.05), v(mx + 0.55 + lean * y / mh, y + 0.07, mz - 0.05));
  }
  /* Encrustation bumps on the hull top */
  for (let i = 0; i < 7; i++) {
    const a = Math.PI * (0.25 + rng() * 0.5);
    const R = 0.9 * (0.5 + rng() * 0.5);
    const z = -2.0 + rng() * 4.0;
    box(Math.cos(a) * R, Math.sin(a) * R * 0.55 - 0.28, z, 0.18 + rng() * 0.14, 0.12, 0.18 + rng() * 0.1, rng() * 3.0);
  }

  /* Bake a roll tilt (ship lying over) around Z. */
  const roll = -0.20, pitch = 0.06;
  const cr = Math.cos(roll), sr = Math.sin(roll);
  const cp = Math.cos(pitch), sp = Math.sin(pitch);
  for (let i = 0; i < P.length; i += 3) {
    let x = P[i], y = P[i + 1], z = P[i + 2];
    let x1 = x * cr - y * sr, y1 = x * sr + y * cr;   /* roll */
    let y2 = y1 * cp - z * sp, z2 = y1 * sp + z * cp; /* pitch */
    P[i] = x1; P[i + 1] = y2; P[i + 2] = z2;
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  geo.setIndex(I);
  geo.computeVertexNormals();
  return geo;
}

/* ── main underwater module ──────────────────────────────────────────── */
class UnderwaterBiome {
  constructor(ctx) {
    this.scene = ctx.scene;
    this.waterLevel = ctx.waterLevel || 3;
    this.heightmap = ctx.heightmap || (() => 0);
    this.renderer = ctx.renderer;
    this.camera = ctx.camera;
    this.sun = ctx.sun || new THREE.DirectionalLight(0xffffff, 1);
    this._pal = Object.assign({}, PAL, ctx.palette || {});
    this.floorY = ctx.floorY != null ? ctx.floorY : -2;

    this.enabled = true;
    this._groups = [];
    this._mats = [];      /* all ShaderMaterials, for uniform updates */

    /* Shared uniform values (referenced by every material). */
    this._u = {
      uTime: { value: 0 },
      camPos: { value: new THREE.Vector3() },
      uSunDir: { value: new THREE.Vector3(0.42, 0.68, 0.51).normalize() },
      uWaterLevel: { value: this.waterLevel },
      uFloorY: { value: this.floorY },
      uFogDensity: { value: 0.035 },
      uFogShallow: { value: new THREE.Color(...this._pal.waterShallow) },
      uFogDeep: { value: new THREE.Color(...this._pal.waterDeep) },
    };

    this._build();
    this.update(0);
  }

  _material(sh, extraUniforms, opts) {
    const uniforms = Object.assign({}, this._u, extraUniforms || {});
    const mat = new THREE.ShaderMaterial(Object.assign({ uniforms }, opts || {}));
    this._mats.push(mat);
    return mat;
  }

  _sunDirToLight() {
    /* Direction pointing TOWARD the light (from any point up to the sun). */
    const d = new THREE.Vector3();
    if (this.sun && this.sun.position) {
      d.subVectors(this.sun.position, this.sun.target ? this.sun.target.position : new THREE.Vector3());
    }
    if (d.lengthSq() < 1e-6) d.set(0.42, 0.68, 0.51);
    return d.normalize();
  }

  /* ── sea floor ──────────────────────────────────────────────────────── */
  _buildFloor() {
    const size = 240, segs = 96;
    const geo = new THREE.PlaneGeometry(size, size, segs, segs);
    geo.rotateX(-Math.PI / 2);
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), z = pos.getZ(i);
      const h = this.heightmap(x, z);
      pos.setY(i, Math.min(h, this.waterLevel - 0.5));
    }
    geo.computeVertexNormals();

    const dr = mulberry(4242);
    const mat = this._material(floorShader(), {
      uSandColor: { value: new THREE.Color(...this._pal.sand) },
      uSandBright: { value: new THREE.Color(...this._pal.sandBright) },
      uCausticBright: { value: new THREE.Color(...this._pal.causticBright) },
      uCausticDim: { value: new THREE.Color(...this._pal.causticDim) },
      uCausticAmp: { value: 1.0 },
    });
    const mesh = new THREE.Mesh(geo, mat);
    this.scene.add(mesh);
    this._floor = mesh;
    return mesh;
  }

  /* ── water surface (Snell's window) ─────────────────────────────────── */
  _buildSurface() {
    const size = 1200, segs = 144;
    const geo = new THREE.PlaneGeometry(size, size, segs, segs);
    geo.rotateX(-Math.PI / 2);

    const mat = this._material(surfaceShader(), {
      uSunGlow: { value: new THREE.Color(0.95, 0.98, 1.0) },
      uShaftGlow: { value: new THREE.Color(...this._pal.shaftWarm) },
    }, { side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.y = this.waterLevel;
    mesh.renderOrder = 4;
    this.scene.add(mesh);
    this._surface = mesh;
    return mesh;
  }

  /* ── god rays ───────────────────────────────────────────────────────── */
  _buildShafts() {
    const dr = mulberry(9001);
    const sunDir = this._sunDirToLight();
    /* Rays travel opposite the sun direction; lean matches its horizontal part. */
    const lean = clamp(Math.atan2(Math.hypot(sunDir.x, sunDir.z), Math.max(sunDir.y, 0.3)) * 0.6, 0.12, 0.5);
    const az = Math.atan2(-sunDir.x, -sunDir.z); /* lean azimuth (lean dir = −sun horizontal) */

    const shafts = [];
    for (let i = 0; i < 9; i++) {
      const wTop = 1.2 + dr() * 2.4;
      const h = this.waterLevel + 28;
      const geo = buildShaftGeo(wTop, wTop * (2.2 + dr() * 1.4), h, lean);
      geo.rotateY(az);
      const mat = this._material(shaftShader(), {
        uShaftColor: { value: new THREE.Color(...this._pal.shaftWarm) },
        uOpacity: { value: 0.05 + dr() * 0.07 },
      }, {
        transparent: true, depthWrite: false,
        blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
      });
      const mesh = new THREE.Mesh(geo, mat);
      const spread = 46;
      mesh.position.set((dr() - 0.5) * spread, this.waterLevel + 1.5, (dr() - 0.5) * spread);
      mesh.renderOrder = 8;
      this.scene.add(mesh);
      shafts.push(mesh);
    }
    this._shafts = shafts;
    return shafts;
  }

  /* ── kelp forest ────────────────────────────────────────────────────── */
  _buildKelp() {
    const dr = mulberry(777);
    const baseGeo = buildKelpFrond(dr);

    /* Clumps of fronds. */
    const items = [];
    const clumps = 15;
    for (let c = 0; c < clumps; c++) {
      const cx = (dr() - 0.5) * 90;
      const cz = (dr() - 0.5) * 90;
      const rad = 2.5 + dr() * 3.5;
      const n = 7 + Math.floor(dr() * 8);
      for (let k = 0; k < n; k++) {
        const a = dr() * Math.PI * 2, r = Math.sqrt(dr()) * rad;
        const x = cx + Math.cos(a) * r, z = cz + Math.sin(a) * r;
        const h = this.heightmap(x, z);
        const y = Math.min(h, this.waterLevel - 0.5);
        const depth = this.waterLevel - y;
        if (depth < 1.5 || depth > 16) continue;
        items.push({
          x, y: y - 0.05, z,
          height: 3.0 + dr() * 5.0,   /* 3–8 m */
          width: 0.75 + dr() * 0.55,
          phase: dr() * Math.PI * 2,
        });
      }
    }
    if (!items.length) return null;

    const n = items.length;
    const offsets = new Float32Array(n * 3);
    const heights = new Float32Array(n);
    const widths = new Float32Array(n);
    const phases = new Float32Array(n);
    const colors = new Float32Array(n * 3);
    items.forEach((p, i) => {
      offsets[i * 3] = p.x; offsets[i * 3 + 1] = p.y; offsets[i * 3 + 2] = p.z;
      heights[i] = p.height;
      widths[i] = p.width;
      phases[i] = p.phase;
      const v = 0.85 + dr() * 0.3;
      colors[i * 3] = this._pal.kelpDark[0] * 0.4 + this._pal.kelpLight[0] * v;
      colors[i * 3 + 1] = this._pal.kelpDark[1] * 0.4 + this._pal.kelpLight[1] * v;
      colors[i * 3 + 2] = this._pal.kelpDark[2] * 0.4 + this._pal.kelpLight[2] * v;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('kelpOffset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('kelpHeight', new THREE.InstancedBufferAttribute(heights, 1));
    geo.setAttribute('kelpWidth', new THREE.InstancedBufferAttribute(widths, 1));
    geo.setAttribute('kelpPhase', new THREE.InstancedBufferAttribute(phases, 1));
    geo.setAttribute('kelpColor', new THREE.InstancedBufferAttribute(colors, 3));

    const mat = this._material(kelpShader(), {}, { side: THREE.DoubleSide });
    const mesh = new THREE.InstancedMesh(geo, mat, n);
    mesh.renderOrder = 12;
    this.scene.add(mesh);
    this._kelp = mesh;
    return mesh;
  }

  /* ── coral clusters ─────────────────────────────────────────────────── */
  _buildCoral() {
    const dr = mulberry(3131);
    const baseGeo = buildCoralShape();

    const colorChoices = [
      this._pal.coralRed, this._pal.coralYellow, this._pal.coralPink,
      this._pal.coralOrange, this._pal.coralPurple,
    ];

    /* Clusters near the wreck/rocks + scattered pairs. */
    const items = [];
    const clusterCenters = [
      [3.5, -8.5], [-6, -3], [10, 4], [-12, 6], [7, 9], [-3, 12],
    ];
    clusterCenters.forEach(([cx, cz], ci) => {
      const n = 8 + Math.floor(dr() * 8);
      for (let k = 0; k < n; k++) {
        const a = dr() * Math.PI * 2, r = Math.sqrt(dr()) * 3.2;
        const x = cx + Math.cos(a) * r, z = cz + Math.sin(a) * r;
        const h = this.heightmap(x, z);
        const y = Math.min(h, this.waterLevel - 0.5);
        if (this.waterLevel - y < 1.0) continue;
        items.push({ x, y: y + 0.02, z, s: 0.7 + dr() * 1.3,
                     c: colorChoices[Math.floor(dr() * colorChoices.length)] });
      }
    });
    if (!items.length) return null;

    const n = items.length;
    const offsets = new Float32Array(n * 3);
    const scales = new Float32Array(n);
    const colors = new Float32Array(n * 3);
    items.forEach((p, i) => {
      offsets[i * 3] = p.x; offsets[i * 3 + 1] = p.y; offsets[i * 3 + 2] = p.z;
      scales[i] = p.s;
      const v = 0.85 + dr() * 0.3;
      colors[i * 3] = p.c[0] * v; colors[i * 3 + 1] = p.c[1] * v; colors[i * 3 + 2] = p.c[2] * v;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('instOffset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('instScale', new THREE.InstancedBufferAttribute(scales, 1));
    geo.setAttribute('instColor', new THREE.InstancedBufferAttribute(colors, 3));

    const mat = this._material(coralShader(), {});
    const mesh = new THREE.InstancedMesh(geo, mat, n);
    mesh.frustumCulled = false;
    mesh.renderOrder = 11;
    this.scene.add(mesh);
    this._coral = mesh;
    return mesh;
  }

  /* ── rocks ──────────────────────────────────────────────────────────── */
  _buildRocks() {
    const dr = mulberry(991);
    const baseGeo = buildRock(dr);
    const items = [];

    /* Big boulders near the wreck + scattered field. */
    for (let i = 0; i < 5; i++) {
      const a = dr() * Math.PI * 2, r = 4 + dr() * 5;
      const x = 2 + Math.cos(a) * r, z = -6 + Math.sin(a) * r;
      const h = this.heightmap(x, z);
      items.push({ x, z, y: Math.min(h, this.waterLevel - 0.5) - 0.15, s: 1.4 + dr() * 1.8 });
    }
    for (let i = 0; i < 34; i++) {
      const x = (dr() - 0.5) * 110, z = (dr() - 0.5) * 110;
      const h = this.heightmap(x, z);
      if (this.waterLevel - Math.min(h, this.waterLevel - 0.5) < 1.0) continue;
      items.push({ x, z, y: Math.min(h, this.waterLevel - 0.5) - 0.15, s: 0.4 + dr() * 1.4 });
    }

    const n = items.length;
    const offsets = new Float32Array(n * 3);
    const scales = new Float32Array(n * 3);
    items.forEach((p, i) => {
      offsets[i * 3] = p.x; offsets[i * 3 + 1] = p.y != null ? p.y : this.floorY - 0.15; offsets[i * 3 + 2] = p.z;
      scales[i * 3] = p.s;
      scales[i * 3 + 1] = p.s * (0.55 + dr() * 0.5);
      scales[i * 3 + 2] = p.s * (0.75 + dr() * 0.4);
    });

    const geo = baseGeo.clone();
    geo.setAttribute('instOffset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('instScale', new THREE.InstancedBufferAttribute(scales, 3));

    const mat = this._material(rockShader(), {
      uRockColor: { value: new THREE.Color(...this._pal.rockUW) },
      uAlgaeColor: { value: new THREE.Color(...this._pal.rockAlgae) },
    });
    const mesh = new THREE.InstancedMesh(geo, mat, n);
    mesh.frustumCulled = false;
    mesh.renderOrder = 10;
    this.scene.add(mesh);
    this._rocks = mesh;
    return mesh;
  }

  /* ── sea grass ──────────────────────────────────────────────────────── */
  _buildSeaGrass() {
    const dr = mulberry(1337);
    const baseGeo = buildSeaGrassBlade();
    const items = [];
    for (let i = 0; i < 260; i++) {
      const x = (dr() - 0.5) * 100, z = (dr() - 0.5) * 100;
      const h = this.heightmap(x, z);
      const y = Math.min(h, this.waterLevel - 0.5);
      if (this.waterLevel - y > 10) continue;
      items.push({ x, y: y + 0.02, z, s: 0.7 + dr() * 0.9, ph: dr() * 6.28 });
    }
    if (!items.length) return null;

    const n = items.length;
    const offsets = new Float32Array(n * 3);
    const scales = new Float32Array(n);
    const phases = new Float32Array(n);
    items.forEach((p, i) => {
      offsets[i * 3] = p.x; offsets[i * 3 + 1] = p.y; offsets[i * 3 + 2] = p.z;
      scales[i] = p.s;
      phases[i] = p.ph;
    });

    const geo = baseGeo.clone();
    geo.setAttribute('instOffset', new THREE.InstancedBufferAttribute(offsets, 3));
    geo.setAttribute('instScale', new THREE.InstancedBufferAttribute(scales, 1));
    geo.setAttribute('instPhase', new THREE.InstancedBufferAttribute(phases, 1));

    const mat = this._material(seaGrassShader(), {}, { side: THREE.DoubleSide });
    const mesh = new THREE.InstancedMesh(geo, mat, n);
    mesh.frustumCulled = false;
    mesh.renderOrder = 13;
    this.scene.add(mesh);
    this._seaGrass = mesh;
    return mesh;
  }

  /* ── fish schools: 3 schools (silver / blue / yellow) ────────────────── */
  _buildFish() {
    const dr = mulberry(2557);
    const baseGeo = buildFishMesh();

    /* School definitions: 20–60 fish each, one hue per school. */
    const schools = [
      { hue: [0.82, 0.86, 0.90], count: 45 },  /* silver */
      { hue: [0.35, 0.55, 0.85], count: 55 },  /* blue */
      { hue: [0.92, 0.78, 0.28], count: 40 },  /* yellow */
    ];

    const items = [];
    schools.forEach((s, si) => {
      for (let i = 0; i < s.count; i++) {
        const a = dr() * Math.PI * 2, r = Math.sqrt(dr()) * 2.6;
        items.push({
          local: [Math.cos(a) * r, (dr() - 0.5) * 1.4, Math.sin(a) * r * 0.7],
          size: 0.8 + dr() * 0.8,
          school: si,
          phase: dr() * 6.28,
          idx: items.length,
          color: s.hue.map(c => c * (0.85 + dr() * 0.3)),
        });
      }
    });

    const n = items.length;
    const locals = new Float32Array(n * 3);
    const idxs = new Float32Array(n);
    const sizes = new Float32Array(n);
    const schoolsA = new Float32Array(n);
    const phases = new Float32Array(n);
    const colors = new Float32Array(n * 3);
    items.forEach((p, i) => {
      locals[i * 3] = p.local[0]; locals[i * 3 + 1] = p.local[1]; locals[i * 3 + 2] = p.local[2];
      idxs[i] = p.idx;
      sizes[i] = p.size;
      schoolsA[i] = p.school;
      phases[i] = p.phase;
      colors[i * 3] = p.color[0]; colors[i * 3 + 1] = p.color[1]; colors[i * 3 + 2] = p.color[2];
    });

    const geo = baseGeo.clone();
    geo.setAttribute('fishLocal', new THREE.InstancedBufferAttribute(locals, 3));
    geo.setAttribute('fishIdx', new THREE.InstancedBufferAttribute(idxs, 1));
    geo.setAttribute('fishSize', new THREE.InstancedBufferAttribute(sizes, 1));
    geo.setAttribute('fishSchool', new THREE.InstancedBufferAttribute(schoolsA, 1));
    geo.setAttribute('fishPhase', new THREE.InstancedBufferAttribute(phases, 1));
    geo.setAttribute('fishColor', new THREE.InstancedBufferAttribute(colors, 3));

    const mat = this._material(fishShader(), {});
    const mesh = new THREE.InstancedMesh(geo, mat, n);
    mesh.frustumCulled = false;
    mesh.renderOrder = 14;
    this.scene.add(mesh);
    this._fish = mesh;
    return mesh;
  }

  /* ── marine snow ────────────────────────────────────────────────────── */
  _buildParticles() {
    const dr = mulberry(4096);
    const n = 260;
    const positions = new Float32Array(n * 3);
    const sizes = new Float32Array(n);
    const speeds = new Float32Array(n);
    const phases = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      positions[i * 3] = (dr() - 0.5) * 70;
      positions[i * 3 + 1] = 0; /* band handled in shader */
      positions[i * 3 + 2] = (dr() - 0.5) * 70;
      sizes[i] = 1.5 + dr() * 3.5;
      speeds[i] = 0.4 + dr() * 0.8;
      phases[i] = dr();
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geo.setAttribute('pSize', new THREE.BufferAttribute(sizes, 1));
    geo.setAttribute('pSpeed', new THREE.BufferAttribute(speeds, 1));
    geo.setAttribute('pPhase', new THREE.BufferAttribute(phases, 1));

    const mat = this._material(particleShader(), {
      uParticleColor: { value: new THREE.Color(...this._pal.particle) },
    }, {
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    });
    const points = new THREE.Points(geo, mat);
    points.frustumCulled = false;
    points.renderOrder = 16;
    this.scene.add(points);
    this._particles = points;
    return points;
  }

  /* ── wreck landmark ─────────────────────────────────────────────────── */
  _buildWreck() {
    const dr = mulberry(606);
    const geo = buildWreck(dr);
    const mat = this._material(wreckShader(), {
      uWreckColor: { value: new THREE.Color(0.34, 0.27, 0.20) },
    });
    const mesh = new THREE.Mesh(geo, mat);
    const x = 2, z = -6;
    const h = this.heightmap(x, z);
    mesh.position.set(x, Math.min(h, this.waterLevel - 0.5) + 0.05, z);
    mesh.rotation.y = 0.6;
    mesh.scale.set(1.5, 1.5, 1.5);
    mesh.renderOrder = 9;
    this.scene.add(mesh);
    this._wreck = mesh;
    return mesh;
  }

  /* ── build all ──────────────────────────────────────────────────────── */
  _build() {
    this._buildFloor();
    this._buildSurface();
    this._buildShafts();
    this._buildKelp();
    this._buildCoral();
    this._buildRocks();
    this._buildSeaGrass();
    this._buildFish();
    this._buildParticles();
    this._buildWreck();
  }

  /* ── update loop ────────────────────────────────────────────────────── */
  update(time) {
    if (!this.enabled) return;
    this._u.uTime.value = time;
    this._u.camPos.value.copy(this.camera.position);
    this._u.uSunDir.value.copy(this._sunDirToLight());
    this._u.uWaterLevel.value = this.waterLevel;
    this._u.uFloorY.value = this.floorY;
  }

  /* ── API ────────────────────────────────────────────────────────────── */
  /** Enable / disable all underwater objects. */
  toggle(on) {
    this.enabled = !!on;
    this._groups = [
      this._floor, this._surface, this._kelp, this._coral, this._rocks,
      this._seaGrass, this._fish, this._particles, this._wreck,
      ...(this._shafts || []),
    ].filter(Boolean);
    this._groups.forEach(m => { m.visible = this.enabled; });
  }

  setWaterLevel(level) {
    this.waterLevel = level;
    this._u.uWaterLevel.value = level;
    if (this._surface) this._surface.position.y = level;
  }

  /** Re-tune the shared atmosphere (per preset). */
  setAtmosphere(o) {
    if (o.density != null) this._u.uFogDensity.value = o.density;
    if (o.shallowColor) this._u.uFogShallow.value.copy(o.shallowColor);
    if (o.deepColor) this._u.uFogDeep.value.copy(o.deepColor);
    if (o.floorY != null) this.floorY = o.floorY;
  }

  setCaustics(v) {
    /* uCausticAmp lives on the floor material only. */
    const mat = this._floor && this._floor.material;
    if (mat && mat.uniforms && mat.uniforms.uCausticAmp) mat.uniforms.uCausticAmp.value = v;
  }

  setShafts(v) {
    (this._shafts || []).forEach(s => {
      if (s.material && s.material.uniforms && s.material.uniforms.uOpacity) {
        s.material.uniforms.uOpacity.value = v * s.userData.baseOpacity;
      }
    });
  }

  /** Remove all objects from the scene. */
  dispose() {
    [...this._groups].forEach(m => {
      this.scene.remove(m);
      if (m.geometry) m.geometry.dispose();
      if (m.material && m.material.dispose) m.material.dispose();
    });
  }
}

/* ── export ───────────────────────────────────────────────────────────── */
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { UnderwaterBiome };
}