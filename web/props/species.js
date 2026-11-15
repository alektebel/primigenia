/* web/props/species.js — Procedural species renderer for Primigenia.

Builds cpore.creature/4 genomes into Three.js Object3Ds / InstancedMeshes.
Self-contained: no dependency on rig.js or studio.js.  Reuses the same skin
material pattern (physically lit skin with clearcoat, furrow noise, pattern)
so creatures match the valley aesthetic.

Usage
-----
  import * as THREE from 'three';
  import { buildLineup, buildOne, skinMaterial } from './species.js';

  // Single creature
  const c = buildOne(THREE, genome, { size: 1, yaw: 0 });

  // Full lineup (returns a group)
  const lineup = buildLineup(THREE, [garfioGenome, rondoGenome, …], { size: 1 });

  // Custom skin material (shared between creatures for low draw-call count)
  const skinMat = skinMaterial(THREE, { cA: '#9a3b28', cB: '#2a1414', cC: '#e6cfa0', pat: 1, wet: 0.3 });

Exports
-------
  buildOne       (T, genome, opts?) → THREE.Object3D
  buildLineup    (T, genomes, opts?) → THREE.Group
  skinMaterial   (T, params?)        → THREE.MeshPhysicalMaterial
  buildLeg       (T, pose, origin)   → { up, lo, ft }
  partLib        (T)                 → { LIB, skinMaterial, boneMaterial, … }
*/

/* ---------- helpers ----------------------------------------------------- */
const V  = (x = 0, y = 0, z = 0) => new Vector3(x, y, z);
const lerp  = (a, b, t) => a + (b - a) * t;
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const sstep = (a, b, x) => { x = clamp((x - a) / (b - a), 0, 1); return x * x * (3 - 2 * x); };
const col   = h => new Color(h).convertSRGBToLinear();

/* Linear RNG (mulberry32) for deterministic variation from a seed. */
function rngFrom(seed) {
  let s = seed | 0;
  return () => { s = (s + 0x6D2B79F5) | 0; let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

/* ---------- skin material (matches rig.js) ------------------------------ */
const SKIN_GLSL = `
uniform vec3 cA, cB, cC;
uniform float uPat, uWet, uScale;
varying vec4 vSkin;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float n3(vec3 x) { vec3 i = floor(x), f = fract(x); f = f * f * (3. - 2. * f);
  return mix(mix(mix(h3(i), h3(i + vec3(1.,0.,0.)), f.x), mix(h3(i + vec3(0.,1.,0.)), h3(i + vec3(1.,1.,0.)), f.x), f.y),
             mix(mix(h3(i + vec3(0.,0.,1.)), h3(i + vec3(1.,0.,1.)), f.x), mix(h3(i + vec3(0.,1.,1.)), h3(i + vec3(1.,1.,1.)), f.x), f.y), f.z); }
vec2 wor(vec3 x) { vec3 p = floor(x), f = fract(x); float a = 8., b = 8.;
  for (int k = -1; k <= 1; k++) for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec3 g = vec3(float(i), float(j), float(k)); vec3 o = vec3(h3(p+g), h3(p+g+17.3), h3(p+g+41.7));
    vec3 r = g + o - f; float d = dot(r, r); if (d < a) { b = a; a = d; } else if (d < b) { b = d; } }
  return sqrt(vec2(a, b)); }
vec3 pN(vec3 sp, vec3 sn, vec2 dH) { vec3 sx = dFdx(sp), sy = dFdy(sp), r1 = cross(sy, sn), r2 = cross(sn, sx);
  float det = dot(sx, r1); vec3 g = sign(det) * (dH.x * r1 + dH.y * r2); return normalize(abs(det) * sn - g); }
`;

export function skinMaterial(T, o = {}) {
  const kind = o.kind || 'skin', membraneStyle = o.membraneStyle || '';
  const params = { ...o }; delete params.kind; delete params.membraneStyle;
  const m = new T.MeshPhysicalMaterial({ roughness: 0.6, metalness: 0, clearcoat: 0.3, clearcoatRoughness: 0.4, envMapIntensity: 0.9, ...params });
  m.customProgramCacheKey = () => kind + membraneStyle + o.cA + o.cB + o.cC + o.pat + o.wet;
  m.onBeforeCompile = s => {
    const SU = { cA: { value: col(o.cA) || new T.Color('#888888') }, cB: { value: col(o.cB) || new T.Color('#444444') },
                 cC: { value: col(o.cC) || new T.Color('#cccccc') }, uPat: { value: o.pat ?? 1 },
                 uWet: { value: o.wet ?? 0.3 }, uScale: { value: o.scale ?? 7 } };
    Object.assign(s.uniforms, SU);
    s.vertexShader = 'attribute vec4 skin;varying vec4 vSkin;\n' + s.vertexShader.replace('#include <begin_vertex>',
      '#include <begin_vertex>\nvSkin=skin;');
    const backlight = kind === 'membrane' ? '' : '';
    s.fragmentShader = SKIN_GLSL + s.fragmentShader
      .replace('#include <color_fragment>', `vec3 rp=vSkin.xyz;float dd=vSkin.w,nn=n3(rp*1.3)+.5*n3(rp*2.9),mk=0.;
        if(uPat>.5&&uPat<1.5)mk=smoothstep(.42,.62,.5+.5*sin(rp.z*4.6+(nn-.75)*3.2));
        else if(uPat>1.5&&uPat<2.5){vec2 w0=wor(rp*1.5);mk=1.-smoothstep(.2,.33,w0.x);}
        else if(uPat>2.5)mk=smoothstep(.5,.72,nn*.66+dd*.12);
        mk*=smoothstep(-.4,.2,dd);vec3 sk=mix(cA,cB,mk);sk=mix(sk,cC,1.-smoothstep(-.85,-.2,dd));sk*=mix(1.,.72,smoothstep(.7,1.,dd));
        vec2 w1=wor(rp*uScale);float sh=smoothstep(0.,.2,w1.y-w1.x),bp=smoothstep(0.,.45,w1.y-w1.x)*.007+n3(rp*3.)*.015;sk*=mix(.7,1.,sh)*(.9+.2*n3(rp*11.));${kind==='membrane'?(membraneStyle?`sk=mix(sk,cC,.58);${membraneStyle==='insect'?'sk=mix(sk,mix(vec3(.14,.58,.7),vec3(.58,.3,.74),pow(1.-abs(dot(normalize(vNormal),normalize(vViewPosition))),2.)),.42);':''}`:'sk=mix(sk,cB,.35+.15*n3(rp*5.5));sk=mix(sk,cC,.12)*.65;'):''}diffuseColor.rgb=sk;`);
    s.fragmentShader = s.fragmentShader.replace('#include <roughnessmap_fragment>',
      `#include <roughnessmap_fragment>\nroughnessFactor=clamp(mix(.82,.3,uWet)*mix(1.25,.9,sh),.06,1.);`)
      .replace('#include <normal_fragment_maps>', '#include <normal_fragment_maps>\nnormal=pN(-vViewPosition,normal,vec2(dFdx(bp),dFdy(bp)));')
      .replace('#include <emissivemap_fragment>', '#include <emissivemap_fragment>\ntotalEmissiveRadiance+=sk*pow(1.-clamp(dot(normalize(vViewPosition),normal),0.,1.),3.)*.5;' + backlight);
  };
  return m;
}

/* ---------- keratin / bone material ------------------------------------ */
function boneMaterial(T, c = '#bfae8a', r = 0.5, cc = 0.25) {
  return new T.MeshPhysicalMaterial({ color: col(c), roughness: r, clearcoat: cc, clearcoatRoughness: 0.2, envMapIntensity: 1 });
}
const _boneM_cache = new Map();
function getBoneM(T, c, r, cc) { const k = c + r + cc; if (!_boneM_cache.has(k)) _boneM_cache.set(k, boneMaterial(T, c, r, cc)); return _boneM_cache.get(k); }

/* ---------- glow material ----------------------------------------------- */
function glowMaterial(T) {
  return new T.MeshStandardMaterial({ color: 0x7fe8ff, emissive: 0x35c8ff, emissiveIntensity: 2.2, roughness: 0.3 });
}

/* ---------- membrane material ------------------------------------------- */
function membraneMaterial(T, opts = {}) {
  const m = new T.MeshPhysicalMaterial({ roughness: 0.94, metalness: 0, clearcoat: 0, clearcoatRoughness: 1, envMapIntensity: 0.12, transparent: true, opacity: 0.82, depthWrite: true, ...opts });
  m.customProgramCacheKey = () => 'membrane';
  return m;
}

/* ---------- geometry helpers ------------------------------------------- */
function allocTube(n, rad) {
  const g = new T.BufferGeometry();
  g.setAttribute('position', new T.BufferAttribute(new Float32Array(n * rad * 3), 3));
  g.setAttribute('normal', new T.BufferAttribute(new Float32Array(n * rad * 3), 3));
  const idx = [];
  for (let i = 0; i < n - 1; i++) for (let j = 0; j < rad; j++) {
    const a = i * rad + j, b = i * rad + (j + 1) % rad, c = a + rad, d = b + rad;
    idx.push(a, c, b, b, c, d);
  }
  g.setIndex(idx); return g;
}

const _t = V(), _s = V(), _u = V(), _n = V(), _X0 = V(1, 0, 0);

function fillTube(g, pts, rad, RN, ref, shape, frames) {
  const pa = g.attributes.position.array, na = g.attributes.normal.array, n = pts.length;
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(i - 1, 0)], b = pts[Math.min(i + 1, n - 1)];
    _t.subVectors(b, a).normalize();
    if (ref) { _s.crossVectors(ref, _t).normalize(); _u.crossVectors(_t, _s) }
    else { _u.crossVectors(_t, _X0).normalize(); _s.crossVectors(_u, _t) }
    const r = rad[i], p = pts[i], dr = clamp((rad[Math.min(i + 1, n - 1)] - rad[Math.max(i - 1, 0)]) / (b.distanceTo(_t) || 1), -4, 4);
    if (frames) { frames[i].s.copy(_s); frames[i].u.copy(_u); frames[i].t.copy(_t); frames[i].dr = dr }
    for (let j = 0; j < RN; j++) {
      const an = j / RN * 6.28318, cx = Math.sin(an), cy = Math.cos(an), wy = shape ? (cy < 0 ? 0.9 : 1.06) : 1, k = (i * RN + j) * 3;
      pa[k] = p.x + (_s.x * cx + _u.x * cy * wy) * r;
      pa[k + 1] = p.y + (_s.y * cx + _u.y * cy * wy) * r;
      pa[k + 2] = p.z + (_s.z * cx + _u.z * cy * wy) * r;
      _n.set(_s.x * cx + _u.x * cy - _t.x * dr, _s.y * cx + _u.y * cy - _t.y * dr, _s.z * cx + _u.z * cy - _t.z * dr).normalize();
      na[k] = _n.x; na[k + 1] = _n.y; na[k + 2] = _n.z;
    }
  }
  g.attributes.position.needsUpdate = true; g.attributes.normal.needsUpdate = true;
}

function curveTube(fn, r0, n, rn, ref) {
  const pts = [], rad = [];
  for (let i = 0; i < n; i++) { const u = i / (n - 1); pts.push(fn(u)); rad.push(Math.max(0.004, r0 * Math.pow(1 - u, 0.85))) }
  const g = allocTube(n, rn); fillTube(g, pts, rad, rn, ref, false); return g;
}

function ell(sx, sy, sz, x = 0, y = 0, z = 0) {
  const g = new T.SphereGeometry(1, 22, 16); g.scale(sx, sy, sz); g.computeVertexNormals(); g.translate(x, y, z); return g;
}

function skinify(g, off, d) {
  const p = g.attributes.position, n = g.attributes.normal, a = new Float32Array(p.count * 4);
  for (let i = 0; i < p.count; i++) a.set([p.getX(i) + off[0], p.getY(i) + off[1], p.getZ(i) + off[2], d == null ? n.getY(i) * 0.9 : d], i * 4);
  g.setAttribute('skin', new T.BufferAttribute(a, 4)); return g;
}

function mesh(g, m, par) {
  const o = new T.Mesh(g, m); o.castShadow = true; o.receiveShadow = true; o.frustumCulled = false;
  if (par) par.add(o); return o;
}

/* ---------- sweep / tissue (keratin / membrane shapes) ----------------- */
function sweep(points, radii) {
  const path = new T.CatmullRomCurve3(points.map(p => V(...p))), ps = [], rs = [], n = 26;
  for (let i = 0; i < n; i++) { const u = i / (n - 1), k = u * (radii.length - 1), j = Math.min(k | 0, radii.length - 2);
    ps.push(path.getPoint(u)); rs.push(Math.max(0.002, lerp(radii[j], radii[j + 1], k - j))) }
  const d = ps.at(-1).clone().sub(ps[0]), ref = Math.abs(d.x) > Math.abs(d.y) + Math.abs(d.z) ? V(0, 1, 0) : V(1, 0, 0);
  const geo = allocTube(n, 12); fillTube(geo, ps, rs, 12, ref, false); return geo;
}

function tissue(geo, region, parent, T) {
  let mat;
  if (region === 'skin') mat = skinMaterial(T);
  else if (region === 'keratin') mat = getBoneM(T);
  else if (region === 'membrane') mat = membraneMaterial(T);
  else if (region === 'glow') mat = glowMaterial(T);
  else mat = skinMaterial(T);
  const m = mesh(geo, mat, parent); m.userData.materialRegion = region; return m;
}

function sail(outline, parent, material, T) {
  const curve = new T.CatmullRomCurve3(outline.map(p => V(...p)), true, 'catmullrom', 0.25);
  const n = 48; const pos = [outline.reduce((a, p) => a.add(V(...p)), V()).multiplyScalar(1 / outline.length).add(V(0, 0.045, 0)).toArray()];
  const idx = [];
  for (let i = 0; i < n; i++) pos.push(...curve.getPoint(i / n).toArray());
  for (let i = 0; i < n; i++) idx.push(0, i + 1, (i + 1) % n + 1);
  const geo = new T.BufferGeometry(); geo.setAttribute('position', new T.Float32BufferAttribute(pos, 3));
  geo.setIndex(idx); geo.computeVertexNormals();
  const m = tissue(geo, 'membrane', parent, T); m.material = material; return m;
}

/* ---------- leg builder ------------------------------------------------- */
function creatorFoot(T, kind, w, o, lo, ft, b) {
  const add = (geo, region, par = ft) => { skinify(geo, o, region === 'skin' ? -0.3 : null); return tissue(geo, region, par, T) };
  if (kind === 'cloven') {
    for (const side of [-1, 1]) { add(ell(w * 0.68, w * 0.65, w * 1.15, side * w * 0.7, w * 0.65, w * 0.65), 'keratin');
      add(sweep([[side * w * 0.7, w * 1.4, -w * 0.2], [side * w * 0.9, w * 0.8, -w * 0.85]], [w * 0.22, 0.003]), 'keratin'); }
    add(ell(w, w * 0.7, w * 0.8, 0, w * 1.4, 0), 'skin'); return;
  }
  add(ell(w * 1.25, w * 0.6, w * 1.4, 0, w * 0.6, w * 0.8), 'skin');
  if (kind === 'spring') add(sweep([[w * 0.6, 0, 0], [w * 0.65, -b * 0.5, -w * 0.3], [w * 0.4, -b, w * 0.1]], [w * 0.22, w * 0.18, w * 0.13]), 'keratin', lo);
  const count = kind === 'gecko' ? 5 : kind === 'sucker' ? 4 : 3;
  for (let i = 0; i < count; i++) {
    const a = (i - (count - 1) / 2) * 0.42, L = w * 3.3, x = Math.sin(a) * L, z = w * 0.9 + Math.cos(a) * L;
    add(sweep([[0, w * 0.55, w * 0.8], [x * 0.65, w * 0.4, z * 0.7], [x, w * 0.3, z]], [w * 0.32, w * 0.24, w * 0.15]), 'skin');
    add(sweep([[x, w * 0.3, z], [x * 1.06, w * 0.18, z + w * 0.85]], [w * 0.22, 0.003]), 'keratin');
  }
}

function legMeshes(T, p, o, a, b) {
  const w = p.w, LIB_PARTS = getPartLib(T), kind = LIB_PARTS[p.type]?.foot || 'garra';
  const up = new T.Group(), lo = new T.Group(), ft = new T.Group();
  const skinM = skinMaterial(T);
  mesh(skinify(new T.CylinderGeometry(w * 1.5, w * 1.02, a, 14, 4).translate(0, -a / 2, 0), o, 0.15), skinM, up);
  mesh(skinify(ell(w * 1.75, a * 0.42, w * 2, 0, -a * 0.24, 0), o, 0.3), skinM, up);
  mesh(skinify(new T.CylinderGeometry(w, w * 0.6, b, 14, 4).translate(0, -b / 2, 0), o, 0.05), skinM, lo);
  mesh(skinify(ell(w * 1.08, w * 1.08, w * 1.08), o, 0.1), skinM, lo);
  if (['runner', 'sucker', 'spring', 'cloven', 'gecko'].includes(kind)) creatorFoot(T, kind, w, o, lo, ft, b);
  else {
    mesh(skinify(ell(w * 1.2, w * 0.62, w * 1.8, 0, w * 0.5, w * 0.75), o, 0.05), skinM, ft);
    mesh(skinify(ell(w * 0.7, w * 0.7, w * 0.7, 0, w * 0.6, 0), o, 0.05), skinM, ft);
    for (const cx of [-0.75, 0, 0.75]) {
      const c = mesh(new T.ConeGeometry(w * 0.27, w * 0.95, 8).translate(0, w * 0.45, 0), boneMaterial(T), ft);
      c.position.set(cx * w, w * 0.3, w * (2.25 - Math.abs(cx) * 0.4)); c.rotation.set(1.85, 0, -cx * 0.35);
    }
  }
  return { up, lo, ft };
}

/* ---------- part builders (from rig.js LIB) ---------------------------- */
function getPartLib(T) {
  const boneM = getBoneM(T);
  const toothM = new T.MeshPhysicalMaterial({ color: col('#f7f1df'), roughness: 0.28, clearcoat: 0.5, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  const beakM  = new T.MeshPhysicalMaterial({ color: col('#d9952f'), roughness: 0.35, clearcoat: 0.6, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  const eyeW   = new T.MeshPhysicalMaterial({ color: col('#f4efe6'), roughness: 0.08, clearcoat: 1, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  const irisM  = new T.MeshPhysicalMaterial({ color: col('#e8a41c'), roughness: 0.2, clearcoat: 1, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  const pupM   = new T.MeshPhysicalMaterial({ color: col('#050505'), roughness: 0.05, clearcoat: 1, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  const darkM  = new T.MeshPhysicalMaterial({ color: col('#1a1210'), roughness: 0.5, clearcoat: 0.2, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  const glowM  = glowMaterial(T);
  const skinM  = skinMaterial(T);
  const membraneM = membraneMaterial(T);

  return { makeParts: (T, part, o, mountR, context) => {
    const p = part, s = p.size * (mountR || 0.6) / 0.6;
    /* mouth */
    if (p.type === 'romo') {
      const hr = 0.55 * p.size, g = new T.Group();
      mesh(skinify(ell(hr * 0.8, hr * 0.52, hr * 0.8, 0, hr * 0.08, hr * 0.25), o, 0.3), skinM, g);
      const jaw = new T.Group(); g.add(jaw); jaw.position.set(0, -hr * 0.22, -hr * 0.25);
      mesh(skinify(ell(hr * 0.7, hr * 0.24, hr * 0.75, 0, 0, hr * 0.5), o, -0.7), skinM, jaw);
      for (const sx of [-1, 1]) mesh(ell(hr * 0.07, hr * 0.045, hr * 0.05, sx * hr * 0.24, hr * 0.3, hr * 0.98), darkM, g);
      return g;
    }
    if (p.type === 'pico') {
      const hr = 0.55 * p.size, g = new T.Group();
      mesh(curveTube(u => V(0, hr * 0.05 - hr * 0.6 * u * u, hr * (-0.2 + 1.7 * u)), hr * 0.58, 12, 14, V(1, 0, 0)), beakM, g);
      const jaw = new T.Group(); g.add(jaw); jaw.position.set(0, -hr * 0.25, -hr * 0.2);
      mesh(curveTube(u => V(0, hr * 0.1 * u, hr * (1.3 * u)), hr * 0.38, 10, 12, V(1, 0, 0)), beakM, jaw);
      return g;
    }
    if (p.type === 'fauces') {
      const hr = 0.55 * p.size, g = new T.Group();
      mesh(skinify(ell(hr * 0.62, hr * 0.44, hr * 1.3, 0, hr * 0.1, hr * 0.55), o, 0.3), skinM, g);
      const jaw = new T.Group(); g.add(jaw); jaw.position.set(0, -hr * 0.2, -hr * 0.3);
      mesh(skinify(ell(hr * 0.52, hr * 0.2, hr * 1.15, 0, 0, hr * 0.75), o, -0.7), skinM, jaw);
      for (const sx of [-1, 1]) mesh(ell(hr * 0.05, hr * 0.035, hr * 0.07, sx * hr * 0.17, hr * 0.3, hr * 1.68), darkM, g);
      return g;
    }
    /* eyes */
    if (p.type === 'ojo') {
      const g = new T.Group(), er = 0.2 * p.size, e = new T.Group(); g.add(e); e.position.z = er * 0.3;
      mesh(new T.SphereGeometry(er, 20, 14), eyeW, e);
      mesh(ell(er * 0.64, er * 0.64, er * 0.3, 0, 0, er * 0.76), irisM, e);
      mesh(ell(er * 0.17, er * 0.5, er * 0.2, 0, 0, er * 0.93), pupM, e);
      return g;
    }
    if (p.type === 'tallo') {
      const g = new T.Group(), er = 0.2 * p.size, L = p.len || 0.7, e = new T.Group(); g.add(e);
      mesh(skinify(curveTube(u => V(0, L * 0.35 * u * u, L * u), 0.09 * p.size, 10, 10, V(1, 0, 0)), o, 0.3), skinM, g);
      e.position.set(0, L * 0.35, L); e.position.z = er * 0.3;
      mesh(new T.SphereGeometry(er, 20, 14), eyeW, e);
      mesh(ell(er * 0.64, er * 0.64, er * 0.3, 0, 0, er * 0.76), irisM, e);
      mesh(ell(er * 0.17, er * 0.5, er * 0.2, 0, 0, er * 0.93), pupM, e);
      return g;
    }
    /* antennae */
    if (p.type === 'antena') {
      const g = new T.Group(), L = p.len || 1.1; g.add(g);
      mesh(curveTube(u => V(0, L * 0.45 * u * u, L * u - 0.05), 0.045 * p.size, 12, 8, V(1, 0, 0)), darkM, g);
      const b = mesh(ell(0.09 * p.size, 0.09 * p.size, 0.09 * p.size), glowM, g); b.position.set(0, L * 0.45, L - 0.05);
      b.castShadow = false; return g;
    }
    /* ears */
    if (p.type === 'oreja') {
      const g = new T.Group(), sw = new T.Group(), s = p.size;
      g.add(sw); g.userData.sway = sw;
      mesh(skinify(ell(0.07 * s, 0.3 * s, 0.55 * s, 0, 0.08 * s, 0.42 * s), o, 0.35), skinM, sw);
      mesh(ell(0.05 * s, 0.2 * s, 0.4 * s, 0.04 * s, 0.08 * s, 0.42 * s), beakM, sw);
      return g;
    }
    /* horns / horns */
    if (p.type === 'cuerno') {
      const g = new T.Group(), L = p.len || 0.9, c = p.curve || 0.5;
      mesh(curveTube(u => V(0, -c * L * 0.7 * u * u, L * u * (1 - 0.2 * c * u) - 0.06), 0.2 * p.size, 14, 12, V(1, 0, 0)), boneM, g);
      return g;
    }
    if (p.type === 'asta') {
      const g = new T.Group(), L = p.len || 1.2, r = 0.11 * p.size;
      mesh(curveTube(u => V(0, -0.25 * L * u * u, L * u - 0.06), r, 14, 10, V(1, 0, 0)), boneM, g);
      for (const [a, d] of [[0.4, 0.5], [0.68, 0.36]]) {
        const m = curveTube(u => V(0, a + d * L * u, a + d * L * 0.35 * u * u), r * 0.7, 8, 8, V(1, 0, 0));
        mesh(m, boneM, g);
      }
      return g;
    }
    /* spikes / pua */
    if (p.type === 'pua') {
      const g = new T.Group();
      mesh(new T.ConeGeometry(0.16 * p.size, p.len || 0.55, 8).rotateX(Math.PI / 2).translate(0, 0, 0.55 * p.size - 0.06), boneM, g);
      return g;
    }
    /* plates / placa */
    if (p.type === 'placa') {
      const g = new T.Group(), s = p.size;
      const ge = new T.OctahedronGeometry(1, 0).scale(0.06 * s, 0.34 * s, 0.52 * s).translate(0, 0, 0.36 * s);
      ge.computeVertexNormals(); mesh(ge, boneM, g); return g;
    }
    /* crest / cresta */
    if (p.type === 'cresta') {
      const g = new T.Group(), sw = new T.Group(), s = p.size; g.add(sw); g.userData.sway = sw;
      for (let k = -2; k <= 2; k++) {
        const f = mesh(new T.ConeGeometry(0.075 * s, (0.95 - Math.abs(k) * 0.12) * s, 6).translate(0, (0.48 - Math.abs(k) * 0.06) * s, 0).scale(0.45, 1, 1),
          k % 2 ? irisM : beakM, sw);
        f.rotation.x = Math.PI / 2 - k * 0.33;
      }
      return g;
    }
    /* glow bulb / bulbo */
    if (p.type === 'bulbo') {
      const g = new T.Group(), s = p.size;
      mesh(skinify(new T.CylinderGeometry(0.07 * s, 0.12 * s, 0.3 * s, 10).rotateX(Math.PI / 2).translate(0, 0, 0.12 * s), o, 0.3), skinM, g);
      const b = mesh(ell(0.22 * s, 0.22 * s, 0.24 * s, 0, 0, 0.42 * s), glowM, g); b.castShadow = false; return g;
    }
    /* fin / aleta */
    if (p.type === 'aleta') {
      const g = new T.Group(), sw = new T.Group(), n = 14, pos = [], sk = [], idx = [], s = p.size;
      g.add(sw); g.userData.sway = sw;
      for (let k = 0; k < n; k++) {
        const y = (k / (n - 1) * 2 - 1) * 0.8 * s, h = s * 1.15 * Math.pow(Math.max(0, 1 - (y / (0.8 * s)) ** 2), 0.55) * (1 + 0.08 * Math.sin(k * 2.4));
        pos.push(0, y, -0.05, 0, y - h * 0.25, h);
        sk.push(0, 0, 0.5, 0.9, 0, 0, h, 0.2);
        if (k < n - 1) { const q = k * 2; idx.push(q, q + 1, q + 2, q + 2, q + 1, q + 3); }
      }
      const ge = new T.BufferGeometry();
      ge.setAttribute('position', new T.Float32BufferAttribute(pos, 3));
      ge.setAttribute('skin', new T.Float32BufferAttribute(sk, 4));
      ge.setIndex(idx); ge.computeVertexNormals();
      mesh(ge, skinMaterial(T, { kind: 'membrane', side: T.DoubleSide, transparent: true, opacity: 0.82, depthWrite: true, roughness: 0.94 }), sw);
      return g;
    }
    /* tail parts */
    if (p.type === 'tail_spike') {
      const g = new T.Group(), s = p.size;
      tissue(sweep([[0, 0, 0.025], [0, 0, -0.18], [0, 0.02, -0.45], [0, 0.03, -0.72]], [s * 0.75, 0.09, 0.085, 0.06]), 'keratin', g, T);
      for (const x of [-0.15, 0, 0.15])
        tissue(sweep([[x, 0.07, -0.85], [x * 1.4, 0.22, -1.15], [x * 1.7, 0.4, -1.48]], [0.065, 0.045, 0.003]), 'keratin', g, T);
      return g;
    }
    if (p.type === 'tail_paddle') {
      const g = new T.Group(), s = p.size, tail = new T.Group(); g.add(tail);
      tissue(sweep([[0, 0, 0.025], [0, 0, -0.18], [0, 0.02, -0.45], [0, 0.03, -0.72]], [s * 0.75, 0.09, 0.085, 0.06]), 'skin', tail, T);
      sail([[0, 0.03, -0.35], [0, 0.48, -0.67], [0, 0.52, -1.14], [0, 0.03, -1.42], [0, -0.48, -1.14], [0, -0.42, -0.67]], tail,
        skinMaterial(T, { kind: 'membrane', side: T.DoubleSide, transparent: true, opacity: 0.9, roughness: 0.8, envMapIntensity: 0.25 }), T);
      return g;
    }
    /* arm grasper */
    if (p.type === 'arm_grasper') {
      const g = new T.Group(), arm = new T.Group(), s = p.size; g.add(arm);
      tissue(sweep([[0, 0, 0], [0.32, -0.24 * s, 0.08 * s], [0.65, -0.38 * s, 0.25 * s]], [0.2 * s, 0.17 * s, 0.14 * s]), 'skin', arm, T);
      mesh(ell(0.17 * s, 0.17 * s, 0.17 * s, 0.65 * s, -0.38 * s, 0.25 * s), skinM, arm);
      tissue(sweep([[0.65 * s, -0.38 * s, 0.25 * s], [0.75 * s, -0.4 * s, 0.55 * s], [0.38 * s, -0.65 * s, 0.98 * s]], [0.14 * s, 0.13 * s, 0.11 * s]), 'skin', arm, T);
      mesh(ell(0.21 * s, 0.15 * s, 0.2 * s, 0.38 * s, -0.65 * s, 1.03 * s), skinM, arm);
      for (const side of [-1, 1])
        tissue(sweep([[0.38 * s + side * 0.12 * s, -0.65 * s, 1.08 * s], [0.38 * s + side * 0.29 * s, -0.61 * s, 1.31 * s], [0.38 * s + side * 0.06 * s, -0.61 * s, 1.52 * s]], [0.085 * s, 0.06 * s, 0.004 * s]), 'keratin', arm, T);
      return g;
    }
    /* default: nothing */
    return new T.Group();
  }};
}

/* ---------- part placement helpers ------------------------------------- */
const _A1 = V(), _A2 = V(), _m = new T.Matrix4(), _q = new T.Quaternion(), _a = V(), _b = V(), _c = V(), _fwd = V(0, 0, 1), _DOWN = V(0, -1, 0);
const Y = V(0, 1, 0);

/* Place a single part on the spine */
function placePart(T, part, pts, RAD, frames, NS, mountRadius, context) {
  const partLib = getPartLib(T);
  const g = partLib.makeParts(T, part, [0, 0, 0], mountRadius, context);
  if (!g || g.children.length === 0) return g;

  const t = clamp(part.t, 0, 1) * (NS - 1);
  const i = Math.min(t | 0, NS - 2), k = t - i, fr = frames[Math.round(t)];
  const r = lerp(RAD[i], RAD[i + 1], k);
  const sa = Math.sin(part.ang), ca = Math.cos(part.ang);
  const wy = ca < 0 ? 0.9 : 1.06;

  const px = lerp(pts[i].x, pts[i + 1].x, k) + fr.s.x * sa * r;
  const py = lerp(pts[i].y, pts[i + 1].y, k) + fr.s.y * sa * r;
  const pz = lerp(pts[i].z, pts[i + 1].z, k) + fr.s.z * sa * r;
  g.position.set(px, py, pz);

  /* Orient: tangent, normal, up */
  const a1 = pts[Math.max(i, 0)], a2 = pts[Math.min(i + 2, NS - 1)];
  const tan = V(a2.x - a1.x, a2.y - a1.y, a2.z - a1.z).normalize();
  const norm = V(fr.s.x * sa, fr.s.y * sa * wy, fr.s.z * sa).normalize();
  const up = V().crossVectors(tan, norm).normalize();

  _m.makeBasis(up, norm, tan);
  g.quaternion.setFromRotationMatrix(_m);

  /* Part-specific rotation / tilt */
  if (part.rot) g.quaternion.multiply(_q.setFromAxisAngle(V(0, 0, 1), part.rot));
  if (part.tilt) g.quaternion.multiply(_q.setFromAxisAngle(V(1, 0, 0), part.tilt));

  /* Scale from the anatomical spine */
  const s = (part.size || 1) * (mountRadius || 0.6) / 0.6;
  g.scale.setScalar(s);

  return g;
}

/* ---------- skeleton builder (spine tube) ------------------------------ */
function buildSpine(T, nodes, NC, NSP, RN) {
  const NS = NSP + 2 * NC, pts = [], RAD = [];
  /* Sample the spine curve */
  const curve = new T.CatmullRomCurve3(nodes.map(n => V(n.r, n.y, n.z)), false, 'catmullrom', 0.5);
  const NSP_actual = nodes.length - 1;
  for (let i = 0; i < NSP_actual; i++) {
    const p = curve.getPoint(i / (NSP_actual - 1));
    pts.push(p); RAD.push(Math.max(0.03, p.x));
  }

  /* End caps */
  const capLen = NC;
  const startCap = nodes[0], endCap = nodes[nodes.length - 1];
  const startOut = V(pts[0].x - (nodes[1]?.r || startCap.r) * 0.3, startCap.y - 0.1, startCap.z - 0.3).normalize();
  for (let k = 1; k <= capLen; k++) {
    const ph = k / capLen * Math.PI / 2;
    pts.unshift(V(startCap.r * Math.sin(ph) * -startOut.x, startCap.y - startCap.r * Math.sin(ph) * startOut.y, startCap.z - startCap.r * Math.sin(ph) * startOut.z));
    RAD.unshift(Math.max(0.004, startCap.r * Math.cos(ph)));
  }
  const endOut = V(0, 1, 0.3).normalize();
  for (let k = 1; k <= capLen; k++) {
    const ph = k / capLen * Math.PI / 2;
    pts.push(V(endCap.r * Math.sin(ph) * endOut.x, endCap.y + endCap.r * Math.sin(ph) * 0.5, endCap.z + endCap.r * Math.sin(ph) * endOut.z));
    RAD.push(Math.max(0.004, endCap.r * Math.cos(ph)));
  }

  /* Build frames */
  const frames = pts.map(() => ({ s: V(), u: V(), t: V(), dr: 0 }));

  /* Build tube geometry */
  const geo = allocTube(pts.length, RN);
  fillTube(geo, pts, RAD, RN, null, false, frames);

  /* Add skin attribute */
  const pa = geo.attributes.position.array, sk = new Float32Array(pts.length * RN * 4);
  for (let i = 0; i < pts.length; i++) for (let j = 0; j < RN; j++) {
    const idx = i * RN + j;
    sk[idx * 4] = pa[idx * 3]; sk[idx * 4 + 1] = pa[idx * 3 + 1]; sk[idx * 4 + 2] = pa[idx * 3 + 2];
    sk[idx * 4 + 3] = Math.cos(j / RN * 6.28318);
  }
  geo.setAttribute('skin', new T.BufferAttribute(sk, 4));

  return { geo, pts, RAD, frames, NS: pts.length, NSP: NSP_actual, spineLen: pts[pts.length - 1].distanceTo(pts[0]) };
}

/* ---------- LEG IK (simplified, no terrain) ---------------------------- */
function buildLeggedCreature(T, genome, ctx) {
  const { geo, pts, RAD, frames, NS, NSP, spineLen } = buildSpine(T, genome.nodes, 6, NSP, 22);
  const group = new T.Group();
  const skinM = skinMaterial(T, genome.skin);
  const body = mesh(geo, skinM, group);

  const context = { head: genome.nodes.at(-1).r, body: Math.max(...genome.nodes.map(n => n.r)), height: pts[NS - 2].y, mouthHeight: genome.nodes.at(-1).y };
  const legCount = genome.parts.filter(p => ['pata', 'zanca', 'pezuna'].includes(p.type)).length;

  if (legCount === 0) {
    /* No-leg creature: just spine + parts */
    for (const part of genome.parts) {
      const g = placePart(T, part, pts, RAD, frames, NS, Math.max(0.03, Math.sin(Math.PI * part.t) * Math.max(...RAD)), context);
      if (g) group.add(g);
    }
    return { group, body, parts: [], legs: [] };
  }

  /* Build legs */
  const legs = [];
  for (const part of genome.parts) {
    if (!['pata', 'zanca', 'pezuna'].includes(part.type)) continue;
    const o = V(pts[Math.round(part.t * (NS - 1))].x, pts[Math.round(part.t * (NS - 1))].y, pts[Math.round(part.t * (NS - 1))].z);
    const pose = { ...part, w: part.w || 0.16 };
    const height = context.height;
    const s = pose.w;
    const rot = pose.ang || 0;
    const kx = (pose.k?.[0] ?? 0.25) * s, ky = (pose.k?.[1] ?? -height * 0.48), kz = (pose.k?.[2] ?? 0.34) * s;
    const fx = (pose.f?.[0] ?? 0.35) * s, fy = (pose.f?.[1] ?? -height * 0.48 - s * 0.6), fz = (pose.f?.[2] ?? 0.12) * s;
    const legGeo = V(kx, ky, kz), footGeo = V(fx, fy, fz);
    const a = legGeo.length(), b = footGeo.length();

    const m = legMeshes(T, { ...pose, type: pose.type }, [0, 0, 0], a, b);
    m.up.position.set(o.x, o.y, o.z); m.lo.position.set(o.x + kx, o.y + ky, o.z + kz); m.ft.position.set(o.x + fx, o.y + fy, o.z + fz);

    group.add(m.up, m.lo, m.ft);
    legs.push({ pose, m, a, b });
  }

  /* Place body parts */
  for (const part of genome.parts) {
    if (['pata', 'zanca', 'pezuna'].includes(part.type)) continue;
    const g = placePart(T, part, pts, RAD, frames, NS, Math.max(0.03, Math.sin(Math.PI * part.t) * Math.max(...RAD)), context);
    if (g) group.add(g);
  }

  /* Body bob */
  group.position.y = -RAD[3] * 0.5 + 0.03;

  return { group, body, parts: genome.parts, legs };
}

/* ---------- No-leg creature (Rondo-style) ------------------------------ */
function buildCrawlingCreature(T, genome, ctx) {
  const { geo, pts, RAD, frames, NS, NSP, spineLen } = buildSpine(T, genome.nodes, 6, NSP, 22);
  const group = new T.Group();
  const skinM = skinMaterial(T, genome.skin);
  const body = mesh(geo, skinM, group);

  const context = { head: genome.nodes.at(-1).r, body: Math.max(...genome.nodes.map(n => n.r)), height: pts[NS - 2].y, mouthHeight: genome.nodes.at(-1).y };

  /* Place body parts */
  for (const part of genome.parts) {
    const g = placePart(T, part, pts, RAD, frames, NS, Math.max(0.03, Math.sin(Math.PI * part.t) * Math.max(...RAD)), context);
    if (g) group.add(g);
  }

  /* Position on ground: bottom of body - radius */
  let bottomY = 1e9;
  for (let i = 0; i < pts.length; i++) bottomY = Math.min(bottomY, pts[i].y - RAD[i]);
  group.position.y = -bottomY + 0.03;

  return { group, body, parts: genome.parts, legs: [] };
}

/* ---------- Main builder ------------------------------------------------ */
/**
 * Build a single creature Object3D from a genome.
 *
 * @param {typeof import('three')} T — THREE r128 instance
 * @param {object} genome — cpore.creature/4 genome
 * @param {object} [opts]
 * @param {number} [opts.size=1] — global size
 * @param {number} [opts.yaw=0] — facing angle
 * @param {number} [opts.seed=0] — deterministic seed
 * @param {THREE.MeshPhysicalMaterial} [opts.skinMat] — pre-built skin material (shared)
 * @returns {THREE.Object3D}
 */
export function buildOne(T, genome, opts = {}) {
  const { size = 1, yaw = 0, seed = 0, skinMat: sharedSkin } = opts;
  const rng = rngFrom(seed);

  const skinParams = { ...genome.skin };
  const skinM = sharedSkin || skinMaterial(T, skinParams);

  /* Check if creature has legs */
  const hasLegs = genome.parts.some(p => ['pata', 'zanca', 'pezuna'].includes(p.type));
  const legCount = genome.parts.filter(p => ['pata', 'zanca', 'pezuna'].includes(p.type)).length;

  let result;
  if (hasLegs) {
    result = buildLeggedCreature(T, genome, { size, yaw, rng });
  } else {
    result = buildCrawlingCreature(T, genome, { size, yaw, rng });
  }

  /* Scale */
  if (size !== 1) {
    result.group.scale.setScalar(size);
  }

  /* Face direction */
  if (yaw !== 0) {
    result.group.rotation.y = yaw;
  }

  return result.group;
}

/**
 * Build a lineup of creatures.
 *
 * @param {typeof import('three')} T — THREE r128 instance
 * @param {object[]} genomes — cpore.creature/4 genomes
 * @param {object} [opts]
 * @param {number} [opts.size=1]
 * @returns {THREE.Group}
 */
export function buildLineup(T, genomes, opts = {}) {
  const group = new T.Group();
  const { size = 1 } = opts;
  const skinM = skinMaterial(T, genomes[0]?.skin || {});
  const spacing = 6;

  genomes.forEach((genome, i) => {
    const c = buildOne(T, genome, { size, yaw: 0, seed: i + 42, skinMat: skinM });
    c.position.x = (i - (genomes.length - 1) / 2) * spacing;
    c.name = genome.name || 'creature-' + i;
    group.add(c);
  });

  return group;
}

/* ---------- Count triangles in a creature ----------------------------- */
export function countTriangles(obj) {
  let total = 0;
  obj.traverse(child => {
    if (child.isMesh && child.geometry) {
      const idx = child.geometry.index;
      total += idx ? idx.count / 3 : child.geometry.attributes.position.count / 3;
    }
  });
  return Math.round(total);
}

/* ---------- Draw-call count -------------------------------------------- */
export function countDrawCalls(obj) {
  let count = 0;
  obj.traverse(child => { if (child.isMesh) count++; });
  return count;
}