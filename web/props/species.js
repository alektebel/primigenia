/* web/props/species.js — Procedural species renderer for Primigenia.

Builds cpore.creature/4 genomes into Three.js Object3Ds / InstancedMeshes.
Self-contained: no dependency on rig.js or studio.js.  Reuses the same skin
material pattern (physically lit skin with clearcoat, furrow noise, pattern)
so creatures match the valley aesthetic.

Usage
-----
  import * as THREE from 'three';
  import { buildLineup, buildOne } from './species.js';

  // Single creature
  const c = buildOne(THREE, genome, { size: 1, yaw: 0 });

  // Full lineup (returns a group)
  const lineup = buildLineup(THREE, [garfioGenome, rondoGenome, …], { size: 1 });

Exports
-------
  buildOne       (T, genome, opts?) → THREE.Object3D
  buildLineup    (T, genomes, opts?) → THREE.Group
  buildSkinMat   (T, params?)        → THREE.MeshPhysicalMaterial
  countTriangles (obj)               → number
  countDrawCalls (obj)               → number
*/
// console.log('[species.js] module loaded');

/* ---------- helpers ----------------------------------------------------- */
function _makeHelpers(T) {
  return {
    Vector3: T.Vector3, Color: T.Color, SphereGeometry: T.SphereGeometry,
    BufferGeometry: T.BufferGeometry, Float32BufferAttribute: T.Float32BufferAttribute,
    BufferAttribute: T.BufferAttribute, ConeGeometry: T.ConeGeometry,
    CylinderGeometry: T.CylinderGeometry, CatmullRomCurve3: T.CatmullRomCurve3,
    Matrix4: T.Matrix4, Quaternion: T.Quaternion, Mesh: T.Mesh,
    Group: T.Group, MeshPhysicalMaterial: T.MeshPhysicalMaterial,
    MeshStandardMaterial: T.MeshStandardMaterial, InstancedBufferGeometry: T.InstancedBufferGeometry,
    InstancedMesh: T.InstancedMesh, Object3D: T.Object3D,
  };
}

const V  = (T, x = 0, y = 0, z = 0) => new T.Vector3(x, y, z);
const lerp  = (a, b, t) => a + (b - a) * t;
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const sstep = (a, b, x) => { x = clamp((x - a) / (b - a), 0, 1); return x * x * (3 - 2 * x); };
const col   = (T, h) => new T.Color(h).convertSRGBToLinear();

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

/* Build a shared skin material from genome skin params. */
export function buildSkinMat(T, o = {}) {
  const { cA, cB, cC, pat, wet, scale, ...rest } = o;
  const m = new T.MeshPhysicalMaterial({ roughness: 0.6, metalness: 0, clearcoat: 0.3, clearcoatRoughness: 0.4, envMapIntensity: 0.9, ...rest });
  m.customProgramCacheKey = () => 'skin_' + (o.cA || '') + '_' + (o.cB || '') + '_' + (o.pat ?? 1);
  m.onBeforeCompile = s => {
    const SU = {
      cA: { value: col(T, o.cA) || new T.Color('#888888') },
      cB: { value: col(T, o.cB) || new T.Color('#444444') },
      cC: { value: col(T, o.cC) || new T.Color('#cccccc') },
      uPat: { value: o.pat ?? 1 },
      uWet: { value: o.wet ?? 0.3 },
      uScale: { value: o.scale ?? 7 }
    };
    Object.assign(s.uniforms, SU);
    s.vertexShader = 'attribute vec4 skin;varying vec4 vSkin;\n' + s.vertexShader.replace('#include <begin_vertex>',
      '#include <begin_vertex>\nvSkin=skin;');
    s.fragmentShader = SKIN_GLSL + s.fragmentShader
      .replace('#include <color_fragment>', `vec3 rp=vSkin.xyz;float dd=vSkin.w,nn=n3(rp*1.3)+.5*n3(rp*2.9),mk=0.;
        if(uPat>.5&&uPat<1.5)mk=smoothstep(.42,.62,.5+.5*sin(rp.z*4.6+(nn-.75)*3.2));
        else if(uPat>1.5&&uPat<2.5){vec2 w0=wor(rp*1.5);mk=1.-smoothstep(.2,.33,w0.x);}
        else if(uPat>2.5)mk=smoothstep(.5,.72,nn*.66+dd*.12);
        mk*=smoothstep(-.4,.2,dd);vec3 sk=mix(cA,cB,mk);sk=mix(sk,cC,1.-smoothstep(-.85,-.2,dd));sk*=mix(1.,.72,smoothstep(.7,1.,dd));
        vec2 w1=wor(rp*uScale);float sh=smoothstep(0.,.2,w1.y-w1.x),bp=smoothstep(0.,.45,w1.y-w1.x)*.007+n3(rp*3.)*.015;sk*=mix(.7,1.,sh)*(.9+.2*n3(rp*11.));diffuseColor.rgb=sk;`);
    s.fragmentShader = s.fragmentShader.replace('#include <roughnessmap_fragment>',
      `#include <roughnessmap_fragment>\nroughnessFactor=clamp(mix(.82,.3,uWet)*mix(1.25,.9,sh),.06,1.);`)
      .replace('#include <normal_fragment_maps>', '#include <normal_fragment_maps>\nnormal=pN(-vViewPosition,normal,vec2(dFdx(bp),dFdy(bp)));')
      .replace('#include <emissivemap_fragment>', '#include <emissivemap_fragment>\ntotalEmissiveRadiance+=sk*pow(1.-clamp(dot(normalize(vViewPosition),normal),0.,1.),3.)*.5;');
  };
  return m;
}

/* ---------- Keratin / bone material ------------------------------------ */
function boneMaterial(T, c, r, cc) {
  return new T.MeshPhysicalMaterial({ color: c || new T.Color('#bfae8a'), roughness: r, clearcoat: cc, clearcoatRoughness: 0.2, envMapIntensity: 1 });
}

/* ---------- Glow material ----------------------------------------------- */
function glowMaterial(T) {
  return new T.MeshStandardMaterial({ color: 0x7fe8ff, emissive: 0x35c8ff, emissiveIntensity: 2.2, roughness: 0.3 });
}

/* ---------- Membrane material ------------------------------------------- */
function membraneMaterial(T) {
  return new T.MeshPhysicalMaterial({
    roughness: 0.94, metalness: 0, clearcoat: 0, clearcoatRoughness: 1,
    envMapIntensity: 0.12, transparent: true, opacity: 0.82, depthWrite: true
  });
}

/* ---------- Geometry helpers ------------------------------------------- */
function allocTube(T, n, rad) {
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

function fillTube(T, g, pts, rad, RN, ref, shape, frames) {
  const pa = g.attributes.position.array, na = g.attributes.normal.array, n = pts.length;
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(i - 1, 0)], b = pts[Math.min(i + 1, n - 1)];
    const _t = V(T).subVectors(b, a).normalize();
    let _s, _u;
    if (ref) { _s = V(T).crossVectors(ref, _t).normalize(); _u = V(T).crossVectors(_t, _s) }
    else { _u = V(T).crossVectors(_t, V(T, 1, 0, 0)).normalize(); _s = V(T).crossVectors(_u, _t) }
    const r = rad[i], p = pts[i];
    const da = b.x - a.x, db = b.y - a.y, dc = b.z - a.z;
    const dist = Math.sqrt(da * da + db * db + dc * dc) || 1;
    const dr = clamp((rad[Math.min(i + 1, n - 1)] - rad[Math.max(i - 1, 0)]) / dist, -4, 4);
    if (frames) { frames[i].s.copy(_s); frames[i].u.copy(_u); frames[i].t.copy(_t); frames[i].dr = dr }
    for (let j = 0; j < RN; j++) {
      const an = j / RN * 6.28318, cx = Math.sin(an), cy = Math.cos(an), wy = shape ? (cy < 0 ? 0.9 : 1.06) : 1, k = (i * RN + j) * 3;
      pa[k] = p.x + (_s.x * cx + _u.x * cy * wy) * r;
      pa[k + 1] = p.y + (_s.y * cx + _u.y * cy * wy) * r;
      pa[k + 2] = p.z + (_s.z * cx + _u.z * cy * wy) * r;
      const _n = V(T).set(_s.x * cx + _u.x * cy - _t.x * dr, _s.y * cx + _u.y * cy - _t.y * dr, _s.z * cx + _u.z * cy - _t.z * dr).normalize();
      na[k] = _n.x; na[k + 1] = _n.y; na[k + 2] = _n.z;
    }
  }
  g.attributes.position.needsUpdate = true; g.attributes.normal.needsUpdate = true;
}

function curveTube(T, fn, r0, n, rn, ref) {
  const pts = [], rad = [];
  for (let i = 0; i < n; i++) { const u = i / (n - 1); pts.push(fn(u)); rad.push(Math.max(0.004, r0 * Math.pow(1 - u, 0.85))) }
  const g = allocTube(T, n, rn); fillTube(T, g, pts, rad, rn, ref, false, null); return g;
}

function ell(T, sx, sy, sz, x = 0, y = 0, z = 0) {
  const g = new T.SphereGeometry(1, 22, 16); g.scale(sx, sy, sz); g.computeVertexNormals(); g.translate(x, y, z); return g;
}

function skinify(T, g, off, d) {
  const p = g.attributes.position, n = g.attributes.normal, a = new Float32Array(p.count * 4);
  for (let i = 0; i < p.count; i++) a.set([p.getX(i) + off[0], p.getY(i) + off[1], p.getZ(i) + off[2], d == null ? n.getY(i) * 0.9 : d], i * 4);
  g.setAttribute('skin', new T.BufferAttribute(a, 4)); return g;
}

function mesh(T, g, m, par) {
  const o = new T.Mesh(g, m); o.castShadow = true; o.receiveShadow = true; o.frustumCulled = false;
  if (par) par.add(o); return o;
}

/* ---------- Sweep / tissue (keratin / membrane shapes) ----------------- */
function sweep(T, points, radii) {
  const path = new T.CatmullRomCurve3(points.map(p => V(T, ...p)));
  const ps = [], rs = [], n = 26;
  for (let i = 0; i < n; i++) { const u = i / (n - 1), k = u * (radii.length - 1), j = Math.min(k | 0, radii.length - 2);
    ps.push(path.getPoint(u)); rs.push(Math.max(0.002, lerp(radii[j], radii[j + 1], k - j))) }
  const last = ps[ps.length - 1], first = ps[0];
  const d = last.clone().sub(first);
  const ref = Math.abs(d.x) > Math.abs(d.y) + Math.abs(d.z) ? V(T, 0, 1, 0) : V(T, 1, 0, 0);
  const geo = allocTube(T, n, 12); fillTube(T, geo, ps, rs, 12, ref, false, null); return geo;
}

function tissue(T, geo, region, parent, skinM, boneMat, glowMat, membraneMat) {
  let mat;
  if (region === 'keratin') mat = boneMat;
  else if (region === 'glow') mat = glowMat;
  else if (region === 'membrane') mat = membraneMat;
  else mat = skinM;
  if (region !== 'skin') { skinify(T, geo, [0, 0, 0], 0.42); }
  return mesh(T, geo, mat, parent);
}

function sail(T, outline, parent, membraneMat) {
  const curve = new T.CatmullRomCurve3(outline.map(p => V(T, ...p)), true, 'catmullrom', 0.25);
  const n = 48; const pos = [outline.reduce((a, p) => a.add(V(T, ...p)), V(T)).multiplyScalar(1 / outline.length).add(V(T, 0, 0.045, 0)).toArray()];
  const idx = [];
  for (let i = 0; i < n; i++) pos.push(...curve.getPoint(i / n).toArray());
  for (let i = 0; i < n; i++) idx.push(0, i + 1, (i + 1) % n + 1);
  const geo = new T.BufferGeometry(); geo.setAttribute('position', new T.BufferAttribute(pos, 3));
  geo.setIndex(idx); geo.computeVertexNormals();
  const m = mesh(T, geo, membraneMat, parent); m.userData.materialRegion = 'membrane'; return m;
}

/* ---------- Leg builder ------------------------------------------------- */
function creatorFoot(T, kind, w, o, lo, ft, b, skinM, boneM) {
  const add = (geo, region, par = ft) => { skinify(T, geo, o, region === 'skin' ? -0.3 : null); return mesh(T, geo, region === 'keratin' ? boneM : skinM, par) };
  if (kind === 'cloven') {
    for (const side of [-1, 1]) { add(ell(T, w * 0.68, w * 0.65, w * 1.15, side * w * 0.7, w * 0.65, w * 0.65), 'keratin');
      add(sweep(T, [[side * w * 0.7, w * 1.4, -w * 0.2], [side * w * 0.9, w * 0.8, -w * 0.85]], [w * 0.22, 0.003]), 'keratin'); }
    add(ell(T, w, w * 0.7, w * 0.8, 0, w * 1.4, 0), 'skin'); return;
  }
  add(ell(T, w * 1.25, w * 0.6, w * 1.4, 0, w * 0.6, w * 0.8), 'skin');
  if (kind === 'spring') add(sweep(T, [[w * 0.6, 0, 0], [w * 0.65, -b * 0.5, -w * 0.3], [w * 0.4, -b, w * 0.1]], [w * 0.22, w * 0.18, w * 0.13]), 'keratin', lo);
  const count = 3;
  for (let i = 0; i < count; i++) {
    const a2 = (i - (count - 1) / 2) * 0.42, L = w * 3.3, x = Math.sin(a2) * L, z = w * 0.9 + Math.cos(a2) * L;
    add(sweep(T, [[0, w * 0.55, w * 0.8], [x * 0.65, w * 0.4, z * 0.7], [x, w * 0.3, z]], [w * 0.32, w * 0.24, w * 0.15]), 'skin');
    add(sweep(T, [[x, w * 0.3, z], [x * 1.06, w * 0.18, z + w * 0.85]], [w * 0.22, 0.003]), 'keratin');
  }
}

function legMeshes(T, p, o, a, b, skinM, boneM, membraneM) {
  const w = p.w;
  const up = new T.Group(), lo = new T.Group(), ft = new T.Group();
  mesh(T, skinify(T, new T.CylinderGeometry(w * 1.5, w * 1.02, a, 14, 4).translate(0, -a / 2, 0), o, 0.15), skinM, up);
  mesh(T, skinify(T, ell(T, w * 1.75, a * 0.42, w * 2, 0, -a * 0.24, 0), o, 0.3), skinM, up);
  mesh(T, skinify(T, new T.CylinderGeometry(w, w * 0.6, b, 14, 4).translate(0, -b / 2, 0), o, 0.05), skinM, lo);
  mesh(T, skinify(T, ell(T, w * 1.08, w * 1.08, w * 1.08), o, 0.1), skinM, lo);

  /* Foot — varies by leg type */
  const type = p.type || '';
  if (type === 'zanca') {
    /* Long-legged wader: thin skin pad + long toes */
    mesh(T, skinify(T, ell(T, w * 0.8, w * 0.7, w * 0.8, 0, w * 0.6, 0), o, 0.05), skinM, ft);
    for (const cx of [-1, 0, 1, 2]) {
      const c = mesh(T, new T.ConeGeometry(w * 0.34, w * (cx === 2 ? 1.8 : 3.4), 8).rotateX(Math.PI / 2).translate(0, 0, w * (cx === 2 ? 0.9 : 1.7)), boneM, ft);
      c.position.y = w * 0.3; c.rotation.y = cx === 2 ? Math.PI : -cx * 0.6;
    }
  } else {
    /* Default: clawed foot (pata) */
    mesh(T, skinify(T, ell(T, w * 1.2, w * 0.62, w * 1.8, 0, w * 0.5, w * 0.75), o, 0.05), skinM, ft);
    mesh(T, skinify(T, ell(T, w * 0.7, w * 0.7, w * 0.7, 0, w * 0.6, 0), o, 0.05), skinM, ft);
    for (const cx of [-0.75, 0, 0.75]) {
      const c = mesh(T, new T.ConeGeometry(w * 0.27, w * 0.95, 8).translate(0, w * 0.45, 0), boneM, ft);
      c.position.set(cx * w, w * 0.3, w * (2.25 - Math.abs(cx) * 0.4)); c.rotation.set(1.85, 0, -cx * 0.35);
    }
  }
  return { up, lo, ft };
}

/* ---------- Part builders (from rig.js LIB, adapted) ------------------- */
function buildPart(T, type, p, skinM, boneM, toothM, beakM, eyeW, irisM, pupM, darkM, glowM, membraneM) {
  const g = new T.Group();
  const hr = 0.55 * p.size;

  /* mouth: romo */
  if (type === 'romo') {
    mesh(T, skinify(T, ell(T, hr * 0.8, hr * 0.52, hr * 0.8, 0, hr * 0.08, hr * 0.25), [0, 0, 0], 0.3), skinM, g);
    const jaw = new T.Group(); g.add(jaw); jaw.position.set(0, -hr * 0.22, -hr * 0.25);
    mesh(T, skinify(T, ell(T, hr * 0.7, hr * 0.24, hr * 0.75, 0, 0, hr * 0.5), [0, 0, 0], -0.7), skinM, jaw);
    for (const sx of [-1, 1]) mesh(T, ell(T, hr * 0.07, hr * 0.045, hr * 0.05, sx * hr * 0.24, hr * 0.3, hr * 0.98), darkM, g);
    return g;
  }
  if (type === 'pico') {
    mesh(T, curveTube(T, u => V(T, 0, hr * 0.05 - hr * 0.6 * u * u, hr * (-0.2 + 1.7 * u)), hr * 0.58, 12, 14, V(T, 1, 0, 0)), beakM, g);
    const jaw = new T.Group(); g.add(jaw); jaw.position.set(0, -hr * 0.25, -hr * 0.2);
    mesh(T, curveTube(T, u => V(T, 0, hr * 0.1 * u, hr * (1.3 * u)), hr * 0.38, 10, 12, V(T, 1, 0, 0)), beakM, jaw);
    return g;
  }
  if (type === 'fauces') {
    mesh(T, skinify(T, ell(T, hr * 0.62, hr * 0.44, hr * 1.3, 0, hr * 0.1, hr * 0.55), [0, 0, 0], 0.3), skinM, g);
    const jaw = new T.Group(); g.add(jaw); jaw.position.set(0, -hr * 0.2, -hr * 0.3);
    mesh(T, skinify(T, ell(T, hr * 0.52, hr * 0.2, hr * 1.15, 0, 0, hr * 0.75), [0, 0, 0], -0.7), skinM, jaw);
    for (const sx of [-1, 1]) mesh(T, ell(T, hr * 0.05, hr * 0.035, hr * 0.07, sx * hr * 0.17, hr * 0.3, hr * 1.68), darkM, g);
    return g;
  }
  /* eyes */
  if (type === 'ojo') {
    const er = 0.2 * p.size, e = new T.Group(); g.add(e); e.position.z = er * 0.3;
    mesh(T, new T.SphereGeometry(er, 20, 14), eyeW, e);
    mesh(T, ell(T, er * 0.64, er * 0.64, er * 0.3, 0, 0, er * 0.76), irisM, e);
    mesh(T, ell(T, er * 0.17, er * 0.5, er * 0.2, 0, 0, er * 0.93), pupM, e);
    return g;
  }
  if (type === 'tallo') {
    const er = 0.2 * p.size, L = p.len || 0.7, e = new T.Group(); g.add(e);
    mesh(T, skinify(T, curveTube(T, u => V(T, 0, L * 0.35 * u * u, L * u), 0.09 * p.size, 10, 10, V(T, 1, 0, 0)), [0, 0, 0], 0.3), skinM, g);
    e.position.set(0, L * 0.35, L); e.position.z = er * 0.3;
    mesh(T, new T.SphereGeometry(er, 20, 14), eyeW, e);
    mesh(T, ell(T, er * 0.64, er * 0.64, er * 0.3, 0, 0, er * 0.76), irisM, e);
    mesh(T, ell(T, er * 0.17, er * 0.5, er * 0.2, 0, 0, er * 0.93), pupM, e);
    return g;
  }
  /* antennae */
  if (type === 'antena') {
    const L = p.len || 1.1;
    mesh(T, curveTube(T, u => V(T, 0, L * 0.45 * u * u, L * u - 0.05), 0.045 * p.size, 12, 8, V(T, 1, 0, 0)), darkM, g);
    const b = mesh(T, ell(T, 0.09 * p.size, 0.09 * p.size, 0.09 * p.size), glowM, g); b.position.set(0, L * 0.45, L - 0.05);
    b.castShadow = false; return g;
  }
  /* ears */
  if (type === 'oreja') {
    const sw = new T.Group(), s = p.size; g.add(sw); g.userData.sway = sw;
    mesh(T, skinify(T, ell(T, 0.07 * s, 0.3 * s, 0.55 * s, 0, 0.08 * s, 0.42 * s), [0, 0, 0], 0.35), skinM, sw);
    mesh(T, ell(T, 0.05 * s, 0.2 * s, 0.4 * s, 0.04 * s, 0.08 * s, 0.42 * s), beakM, sw);
    return g;
  }
  /* horns: cuerno */
  if (type === 'cuerno') {
    const L = p.len || 0.9, c = p.curve || 0.5;
    mesh(T, curveTube(T, u => V(T, 0, -c * L * 0.7 * u * u, L * u * (1 - 0.2 * c * u) - 0.06), 0.2 * p.size, 14, 12, V(T, 1, 0, 0)), boneM, g);
    return g;
  }
  if (type === 'asta') {
    const L = p.len || 1.2, r = 0.11 * p.size;
    mesh(T, curveTube(T, u => V(T, 0, -0.25 * L * u * u, L * u - 0.06), r, 14, 10, V(T, 1, 0, 0)), boneM, g);
    for (const [a2, d] of [[0.4, 0.5], [0.68, 0.36]]) {
      const m = curveTube(T, u => V(T, 0, a2 + d * L * u, a2 + d * L * 0.35 * u * u), r * 0.7, 8, 8, V(T, 1, 0, 0));
      mesh(T, m, boneM, g);
    }
    return g;
  }
  /* spikes: pua */
  if (type === 'pua') {
    mesh(T, new T.ConeGeometry(0.16 * p.size, p.len || 0.55, 8).rotateX(Math.PI / 2).translate(0, 0, (p.len || 0.55) * p.size * 0.5 - 0.06), boneM, g);
    return g;
  }
  /* plates: placa */
  if (type === 'placa') {
    const s = p.size;
    const ge = new T.OctahedronGeometry(1, 0).scale(0.06 * s, 0.34 * s, 0.52 * s).translate(0, 0, 0.36 * s);
    ge.computeVertexNormals(); mesh(T, ge, boneM, g); return g;
  }
  /* crest: cresta */
  if (type === 'cresta') {
    const sw = new T.Group(), s = p.size; g.add(sw); g.userData.sway = sw;
    for (let k = -2; k <= 2; k++) {
      const f = mesh(T, new T.ConeGeometry(0.075 * s, (0.95 - Math.abs(k) * 0.12) * s, 6).translate(0, (0.48 - Math.abs(k) * 0.06) * s, 0).scale(0.45, 1, 1),
        k % 2 ? irisM : beakM, sw);
      f.rotation.x = Math.PI / 2 - k * 0.33;
    }
    return g;
  }
  /* glow bulb: bulbo */
  if (type === 'bulbo') {
    const s = p.size;
    mesh(T, skinify(T, new T.CylinderGeometry(0.07 * s, 0.12 * s, 0.3 * s, 10).rotateX(Math.PI / 2).translate(0, 0, 0.12 * s), [0, 0, 0], 0.3), skinM, g);
    const b = mesh(T, ell(T, 0.22 * s, 0.22 * s, 0.24 * s, 0, 0, 0.42 * s), glowM, g); b.castShadow = false; return g;
  }
  /* fin: aleta */
  if (type === 'aleta') {
    const sw = new T.Group(), n = 14, pos = [], sk = [], idx = [], s = p.size;
    g.add(sw); g.userData.sway = sw;
    for (let k = 0; k < n; k++) {
      const y = (k / (n - 1) * 2 - 1) * 0.8 * s;
      const h = s * 1.15 * Math.pow(Math.max(0, 1 - (y / (0.8 * s)) ** 2), 0.55) * (1 + 0.08 * Math.sin(k * 2.4));
      pos.push(0, y, -0.05, 0, y - h * 0.25, h);
      sk.push(0, 0, 0.5, 0.9, 0, 0, h, 0.2);
      if (k < n - 1) { const q = k * 2; idx.push(q, q + 1, q + 2, q + 2, q + 1, q + 3); }
    }
    const ge = new T.BufferGeometry();
    ge.setAttribute('position', new T.Float32BufferAttribute(pos, 3));
    ge.setAttribute('skin', new T.Float32BufferAttribute(sk, 4));
    ge.setIndex(idx); ge.computeVertexNormals();
    mesh(T, ge, membraneM, sw);
    return g;
  }
  /* tail spike */
  if (type === 'tail_spike') {
    const s = p.size;
    tissue(T, sweep(T, [[0, 0, 0.025], [0, 0, -0.18], [0, 0.02, -0.45], [0, 0.03, -0.72]], [s * 0.75, 0.09, 0.085, 0.06]), 'keratin', g, skinM, boneM, glowM, membraneM);
    for (const x of [-0.15, 0, 0.15])
      tissue(T, sweep(T, [[x, 0.07, -0.85], [x * 1.4, 0.22, -1.15], [x * 1.7, 0.4, -1.48]], [0.065, 0.045, 0.003]), 'keratin', g, skinM, boneM, glowM, membraneM);
    return g;
  }
  /* tail paddle */
  if (type === 'tail_paddle') {
    const s = p.size, tail = new T.Group(); g.add(tail);
    tissue(T, sweep(T, [[0, 0, 0.025], [0, 0, -0.18], [0, 0.02, -0.45], [0, 0.03, -0.72]], [s * 0.75, 0.09, 0.085, 0.06]), 'skin', tail, skinM, boneM, glowM, membraneM);
    sail(T, [[0, 0.03, -0.35], [0, 0.48, -0.67], [0, 0.52, -1.14], [0, 0.03, -1.42], [0, -0.48, -1.14], [0, -0.42, -0.67]], tail, membraneM);
    return g;
  }
  /* arm grasper */
  if (type === 'arm_grasper') {
    const arm = new T.Group(); g.add(arm);
    tissue(T, sweep(T, [[0, 0, 0], [0.32, -0.24, 0.08], [0.65, -0.38, 0.25]], [0.2, 0.17, 0.14]), 'skin', arm, skinM, boneM, glowM, membraneM);
    mesh(T, ell(T, 0.17, 0.17, 0.17, 0.65, -0.38, 0.25), skinM, arm);
    tissue(T, sweep(T, [[0.65, -0.38, 0.25], [0.75, -0.4, 0.55], [0.38, -0.65, 0.98]], [0.14, 0.13, 0.11]), 'skin', arm, T, skinM, boneM, glowM, membraneM);
    mesh(T, ell(T, 0.21, 0.15, 0.2, 0.38, -0.65, 1.03), skinM, arm);
    for (const side of [-1, 1])
      tissue(T, sweep(T, [[0.38 + side * 0.12, -0.65, 1.08], [0.38 + side * 0.29, -0.61, 1.31], [0.38 + side * 0.06, -0.61, 1.52]], [0.085, 0.06, 0.004]), 'keratin', arm, T, skinM, boneM, glowM, membraneM);
    return g;
  }
  /* default: nothing */
  return g;
}

/* ---------- Skeleton builder (spine tube) ------------------------------ */
function buildSpine(T, nodes, RN) {
  const NC = 6;
  const curve = new T.CatmullRomCurve3(nodes.map(n => V(T, n.r, n.y, n.z)), false, 'catmullrom', 0.5);
  const NSP_actual = nodes.length - 1;
  const pts = [], RAD = [];
  for (let i = 0; i < NSP_actual; i++) {
    const u = NSP_actual <= 1 ? 0.5 : i / (NSP_actual - 1);
    const p = curve.getPoint(u);
    pts.push(p); RAD.push(Math.max(0.03, p.x));
  }

  /* End caps */
  const capLen = NC;
  const startCap = nodes[0], endCap = nodes[nodes.length - 1];
  const startOut = V(T, pts[0].x - (nodes[1]?.r || startCap.r) * 0.3, startCap.y - 0.1, startCap.z - 0.3).normalize();
  for (let k = 1; k <= capLen; k++) {
    const ph = k / capLen * Math.PI / 2;
    pts.unshift(V(T, startCap.r * Math.sin(ph) * -startOut.x, startCap.y - startCap.r * Math.sin(ph) * startOut.y, startCap.z - startCap.r * Math.sin(ph) * startOut.z));
    RAD.unshift(Math.max(0.004, startCap.r * Math.cos(ph)));
  }
  const endOut = V(T, 0, 1, 0.3).normalize();
  for (let k = 1; k <= capLen; k++) {
    const ph = k / capLen * Math.PI / 2;
    pts.push(V(T, endCap.r * Math.sin(ph) * endOut.x, endCap.y + endCap.r * Math.sin(ph) * 0.5, endCap.z + endCap.r * Math.sin(ph) * endOut.z));
    RAD.push(Math.max(0.004, endCap.r * Math.cos(ph)));
  }

  /* Build frames */
  const frames = pts.map(() => ({ s: V(T), u: V(T), t: V(T), dr: 0 }));

  /* Build tube geometry */
  const geo = allocTube(T, pts.length, RN);
  fillTube(T, geo, pts, RAD, RN, null, false, frames);

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

/* ---------- Part placement on the spine --------------------------------- */
function placePartOnSpine(T, part, pts, RAD, frames, NS, skinM, boneM, toothM, beakM, eyeW, irisM, pupM, darkM, glowM, membraneM) {
  /* Build the part geometry */
  const g = buildPart(T, part.type, part, skinM, boneM, toothM, beakM, eyeW, irisM, pupM, darkM, glowM, membraneM);
  if (!g || g.children.length === 0) return g;

  /* Position on spine */
  const t = clamp(part.t, 0, 1) * (NS - 1);
  const i = Math.min(t | 0, NS - 2), k = t - i;
  const px = lerp(pts[i].x, pts[i + 1].x, k);
  const py = lerp(pts[i].y, pts[i + 1].y, k);
  const pz = lerp(pts[i].z, pts[i + 1].z, k);
  const fr = frames[Math.round(t)];
  const r = lerp(RAD[i], RAD[i + 1], k);
  const sa = Math.sin(part.ang), ca = Math.cos(part.ang);
  const wy = ca < 0 ? 0.9 : 1.06;

  g.position.set(
    px + fr.s.x * sa * r + fr.u.x * ca * wy * r,
    py + fr.s.y * sa * r + fr.u.y * ca * wy * r,
    pz + fr.s.z * sa * r + fr.u.z * ca * wy * r
  );

  /* Orientation: tangent, normal, up */
  const a1 = pts[Math.max(i, 0)], a2 = pts[Math.min(i + 2, NS - 1)];
  const tan = V(T, a2.x - a1.x, a2.y - a1.y, a2.z - a1.z).normalize();
  const norm = V(T, fr.s.x * sa, fr.s.y * sa * wy, fr.s.z * sa).normalize();
  const up = V(T).crossVectors(tan, norm).normalize();

  const _m = new T.Matrix4(); _m.makeBasis(up, norm, tan);
  g.quaternion.setFromRotationMatrix(_m);

  /* Part-specific rotation / tilt */
  if (part.rot) g.quaternion.multiply(new T.Quaternion().setFromAxisAngle(V(T, 0, 0, 1), part.rot));
  if (part.tilt) g.quaternion.multiply(new T.Quaternion().setFromAxisAngle(V(T, 1, 0, 0), part.tilt));

  /* Scale */
  g.scale.setScalar(part.size || 1);

  return g;
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
 * @param {THREE.MeshPhysicalMaterial} [opts.sharedSkin] — pre-built shared skin material
 * @returns {THREE.Object3D}
 */
export function buildOne(T, genome, opts = {}) {
  const { size = 1, yaw = 0 } = opts;

  /* Build materials */
  let skinM, boneM, toothM, beakM, eyeW, irisM, pupM, darkM, glowM, membraneM;
  if (opts.sharedSkin) {
    skinM = opts.sharedSkin;
  } else {
    skinM = buildSkinMat(T, genome.skin);
  }
  boneM = boneMaterial(T, new T.Color('#bfae8a'), 0.5, 0.25);
  toothM = new T.MeshPhysicalMaterial({ color: new T.Color('#f7f1df'), roughness: 0.28, clearcoat: 0.5, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  beakM  = new T.MeshPhysicalMaterial({ color: new T.Color('#d9952f'), roughness: 0.35, clearcoat: 0.6, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  eyeW   = new T.MeshPhysicalMaterial({ color: new T.Color('#f4efe6'), roughness: 0.08, clearcoat: 1, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  irisM  = new T.MeshPhysicalMaterial({ color: new T.Color('#e8a41c'), roughness: 0.2, clearcoat: 1, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  pupM   = new T.MeshPhysicalMaterial({ color: new T.Color('#050505'), roughness: 0.05, clearcoat: 1, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  darkM  = new T.MeshPhysicalMaterial({ color: new T.Color('#1a1210'), roughness: 0.5, clearcoat: 0.2, clearcoatRoughness: 0.2, envMapIntensity: 1 });
  glowM  = glowMaterial(T);
  membraneM = membraneMaterial(T);

  const matLib = { skinM, boneM, toothM, beakM, eyeW, irisM, pupM, darkM, glowM, membraneM };

  /* Check if creature has legs */
  const hasLegs = genome.parts.some(p => ['pata', 'zanca', 'pezuna'].includes(p.type));

  /* Build spine */
  const { geo, pts, RAD, frames, NS } = buildSpine(T, genome.nodes, 22);

  /* Build the body mesh */
  const group = new T.Group();
  const body = mesh(T, geo, skinM, group);

  const context = {
    head: genome.nodes.at(-1).r,
    body: Math.max(...genome.nodes.map(n => n.r)),
    height: pts[NS - 2]?.y || 0,
    mouthHeight: genome.nodes.at(-1)?.y || 0
  };

  if (hasLegs) {
    /* Build legs */
    for (const part of genome.parts) {
      if (!['pata', 'zanca', 'pezuna'].includes(part.type)) continue;
      const oi = Math.round(part.t * (NS - 1));
      const o = [pts[oi].x, pts[oi].y, pts[oi].z];
      const pose = { ...part, w: part.w || 0.16 };

      const s = pose.w;
      const kx = (pose.k?.[0] ?? 0.25) * s, ky = (pose.k?.[1] ?? -context.height * 0.48), kz = (pose.k?.[2] ?? 0.34) * s;
      const fx = (pose.f?.[0] ?? 0.35) * s, fy = (pose.f?.[1] ?? -context.height * 0.48 - s * 0.6), fz = (pose.f?.[2] ?? 0.12) * s;
      const a2 = Math.sqrt(kx * kx + ky * ky + kz * kz);
      const b = Math.sqrt(fx * fx + fy * fy + fz * fz);

      const m = legMeshes(T, { ...pose, type: pose.type }, [0, 0, 0], a2, b, skinM, boneM, membraneM);
      m.up.position.set(o[0], o[1], o[2]);
      m.lo.position.set(o[0] + kx, o[1] + ky, o[2] + kz);
      m.ft.position.set(o[0] + fx, o[1] + fy, o[2] + fz);

      group.add(m.up, m.lo, m.ft);
    }

    /* Place non-leg parts */
    for (const part of genome.parts) {
      if (['pata', 'zanca', 'pezuna'].includes(part.type)) continue;
      const g = placePartOnSpine(T, part, pts, RAD, frames, NS, ...Object.values(matLib));
      if (g) group.add(g);
    }

    /* Position on ground */
    const bottom = Math.min(...RAD.map((rad, i) => pts[i].y - rad));
    group.position.y = -bottom + 0.03;

  } else {
    /* No-leg creature */
    for (const part of genome.parts) {
      const g = placePartOnSpine(T, part, pts, RAD, frames, NS, ...Object.values(matLib));
      if (g) group.add(g);
    }

    const bottom = Math.min(...RAD.map((rad, i) => pts[i].y - rad));
    group.position.y = -bottom + 0.03;
  }

  /* Scale */
  if (size !== 1) group.scale.setScalar(size);
  /* Face direction */
  if (yaw !== 0) group.rotation.y = yaw;

  return group;
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
  /* Use first genome's skin params for shared material */
  const skinM = buildSkinMat(T, genomes[0]?.skin || {});
  const spacing = 6;

  genomes.forEach((genome, i) => {
    const c = buildOne(T, genome, { size, yaw: 0, sharedSkin: skinM });
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