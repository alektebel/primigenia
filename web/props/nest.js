/* web/props/nest.js — Procedural nest marker for P4 (Q-6, G24).

Self-contained ES module for Three.js r128.
Exports builder functions that accept (THREE, seed, params) and return
Object3D / InstancedMesh.  Deterministic from the seed.

Usage:
  import { buildNest, allVariants } from './nest.js';

  const nest = buildNest(THREE, 42, { variant: 'plain' });
  scene.add(nest);

  const scene3d = allVariants(THREE, 99);
  scene.add(scene3d);

Art style rules (DESIGN.md §9, G63–G66):
  - World props use the 6-band toon ramp (palette C): [46,46,82,82,112,112].
  - Colours drawn from PAL.C land palette and earth tones.
  - Creature objects (eggs) use toon material with vertex colours; nest stays toon.
  - No imports from tools/hero, web/hero, web/stage, web/creature, core.
*/

// ── Seeded PRNG (same family as valle-primigenio.html, line 152) ────────────
function rngFrom(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));
const sstep = (edge0, edge1, x) => {
  const t = clamp((x - edge0) / (edge1 - edge0), 0, 1);
  return t * t * (3 - 2 * t);
};

/** Simple 3-D hash noise (value noise with smooth interpolation). */
function hash3(x, y, z) {
  let h = (x * 374761393 + y * 668265263 + z * 1274126177) | 0;
  h = Math.imul(h ^ (h >>> 13), 1103515245);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
function noise3(x, y, z) {
  const ix = Math.floor(x), iy = Math.floor(y), iz = Math.floor(z);
  const fx = x - ix, fy = y - iy, fz = z - iz;
  const sx = fx * fx * (3 - 2 * fx);
  const sy = fy * fy * (3 - 2 * fy);
  const sz = fz * fz * (3 - 2 * fz);
  const l = (a, b, t) => a + (b - a) * t;
  const n00 = l(hash3(ix, iy, iz), hash3(ix + 1, iy, iz), sx);
  const n10 = l(hash3(ix, iy + 1, iz), hash3(ix + 1, iy + 1, iz), sx);
  const n01 = l(hash3(ix, iy, iz + 1), hash3(ix + 1, iy, iz + 1), sx);
  const n11 = l(hash3(ix, iy + 1, iz + 1), hash3(ix + 1, iy + 1, iz + 1), sx);
  return l(l(n00, n10, sy), l(n01, n11, sy), sz);
}
/** Fractional Brownian Motion for organic displacement. */
function fbm(x, y, z, octaves) {
  let val = 0, amp = 0.5, freq = 1;
  for (let i = 0; i < octaves; i++) {
    val += amp * (noise3(x * freq, y * freq, z * freq) - 0.5);
    amp *= 0.5;
    freq *= 2;
  }
  return val;
}

/** Palette C land colours (G63) + nest-specific earth palette. */
const PAL = {
  g0:      [0.090, 0.225, 0.040],    // dark grass
  g1:      [0.185, 0.335, 0.075],    // light grass
  tuft0:   [0.82, 0.90, 0.78],      // bright grass tuft
  tuft1:   [1.04, 1.02, 0.98],      // pale tuft
  r0:      [0.15, 0.165, 0.19],     // dark rock
  r1:      [0.28, 0.215, 0.14],     // mid rock
  earth:   [0.22, 0.14, 0.06],      // dark earth / twig base
  twig:    [0.32, 0.22, 0.12],      // twig brown
  twigL:   [0.44, 0.30, 0.16],      // lighter twig
  grass:   [0.28, 0.42, 0.12],      // nest grass thatch
  grassP:  [0.52, 0.58, 0.28],      // dried grass
  stone:   [0.24, 0.22, 0.20],      // grey stone
  stoneL:  [0.38, 0.34, 0.30],
  stoneW:  [0.36, 0.28, 0.18],
  egg1:    [0.78, 0.68, 0.42],      // warm cream (Rondo)
  egg2:    [0.42, 0.58, 0.52],      // cool blue-green (Zanco)
  egg3:    [0.58, 0.32, 0.22],      // red-brown (Espinodo)
  caveD:   [0.08, 0.07, 0.06],      // deep cave wall
  caveM:   [0.14, 0.12, 0.10],      // cave ledge
};

const EGG_COLORS = { rondo: PAL.egg1, zanco: PAL.egg2, espinodo: PAL.egg3 };

// ── Geometry factories (all accept T = THREE namespace as 1st arg) ───────────

/** Build an organic mound mesh (icosahedron displaced by FBM). */
function buildMoundGeometry(T, seed, p) {
  p = p || {};
  const radius = p.radius || 1.6, detail = p.detail || 2, hScale = p.heightScale || 0.35;
  const geo = new T.IcosahedronGeometry(radius, detail);
  const pos = geo.attributes.position, colors = new Float32Array(pos.count * 3);

  for (let i = 0; i < pos.count; i++) {
    let x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const len = Math.hypot(x, y, z) || 1;
    const nx = x / len, ny = y / len, nz = z / len;
    let d = 0;
    if (ny < -0.2) {
      d = fbm(nx * 3, nz * 3, 0, 2) * 0.15 * (1 + ny * 2);
    } else {
      d = fbm(nx * 2, ny * 2, nz * 2, 3) * hScale;
      const rd = Math.sqrt(nx * nx + nz * nz);
      d += Math.max(0, (1 - rd) * 0.2) * hScale;
      if (ny > 0.6) d -= ((ny - 0.6) / 0.4) * 0.12 * (0.5 + fbm(nx * 5, nz * 5, 0, 2) * 0.5);
    }
    pos.setXYZ(i, x + nx * d, y + ny * d, z + nz * d);

    // Vertex colour: height-based earth tones
    const nv = (fbm(nx * 4, ny * 4, nz * 4, 2) + 1) * 0.5;
    let cr, cg, cb;
    if (ny < -0.3) { cr = lerp(PAL.earth[0], PAL.twig[0], nv); cg = lerp(PAL.earth[1], PAL.twig[1], nv); cb = lerp(PAL.earth[2], PAL.twig[2], nv); }
    else if (ny < 0.0) { cr = lerp(PAL.twig[0], PAL.grass[0], nv * 0.5); cg = lerp(PAL.twig[1], PAL.grass[1], nv * 0.5); cb = lerp(PAL.twig[2], PAL.grass[2], nv * 0.5); }
    else { cr = lerp(PAL.grass[0], PAL.tuft1[0], nv); cg = lerp(PAL.grass[1], PAL.tuft1[1], nv); cb = lerp(PAL.grass[2], PAL.tuft1[2], nv); }
    colors[i * 3] = cr * (ny < 0 ? 0.6 : 1);
    colors[i * 3 + 1] = cg * (ny < 0 ? 0.6 : 1);
    colors[i * 3 + 2] = cb * (ny < 0 ? 0.6 : 1);
  }
  geo.setAttribute('color', new T.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  return geo;
}

/** Build a nest egg: asymmetric ellipsoid, pointier at top. */
function buildEggGeometry(T, seed, color, hatch) {
  hatch = hatch || 'whole';
  const r = rngFrom(seed), sw = 14, sh = 12;
  const posA = [], idxA = [], colA = [];
  const c = new T.Color(color[0], color[1], color[2]);

  for (let iy = 0; iy <= sh; iy++) {
    const v = iy / sh, y = (v - 0.45) * 0.55, t = v;
    const wR = Math.pow(1 - t, 0.65) * 0.14;
    for (let ix = 0; ix <= sw; ix++) {
      const u = ix / sw, a = u * Math.PI * 2;
      posA.push(Math.cos(a) * wR, y + t * 0.12, Math.sin(a) * wR * 0.85);
      const n = hash3(ix * 7, iy * 13, 42);
      const sh2 = 0.85 + n * 0.15;
      colA.push(c.r * sh2, c.g * sh2, c.b * sh2);
    }
  }
  for (let iy = 0; iy < sh; iy++) {
    for (let ix = 0; ix < sw; ix++) {
      const a = iy * (sw + 1) + ix, b = a + 1, c2 = a + sw + 1, d = c2 + 1;
      idxA.push(a, c2, b, b, c2, d);
    }
  }

  const geo = new T.BufferGeometry();
  geo.setAttribute('position', new T.Float32BufferAttribute(posA, 3));
  geo.setAttribute('color', new T.Float32BufferAttribute(colA, 3));
  geo.setIndex(idxA);
  geo.computeVertexNormals();

  const mat = makeToon(T, 0xffffff, { extra: { vertexColors: true } });
  const mesh = new T.Mesh(geo, mat);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  mesh.name = 'egg';
  mesh.userData.hatchState = hatch;

  // Crack segments as data (added by nest builder)
  if (hatch === 'crack') {
    mesh.userData.crackSegs = [];
    let cx = 0, cy = 0.05, cz = 0.13;
    for (let i = 0; i < 6; i++) {
      const nx = cx + (r() - 0.5) * 0.08, ny = cy + 0.05 + r() * 0.02, nz = cz + (r() - 0.5) * 0.05;
      mesh.userData.crackSegs.push({ x: (cx + nx) / 2, y: (cy + ny) / 2, z: (cz + nz) / 2, dx: nx - cx, dy: ny - cy, dz: nz - cz });
      cx = nx; cy = ny; cz = nz;
    }
  }
  return mesh;
}

/** Build the woven twigs around the nest rim (instanced). */
function buildTwigs(T, seed, mR) {
  mR = mR || 1.6;
  const r = rngFrom(seed + 1), count = 60;
  const geo = new T.CylinderGeometry(0.012, 0.018, 0.4, 5);
  geo.rotateZ(Math.PI / 2); geo.translate(0.2, 0, 0);
  const mat = makeToon(T, 0xffffff, { extra: { vertexColors: true } });
  const mesh = new T.InstancedMesh(geo, mat, count);
  mesh.castShadow = true; mesh.receiveShadow = true; mesh.name = 'twigs';
  const M = new T.Matrix4(), col = new T.Color(), euler = new T.Euler(), pos = new T.Vector3();

  for (let i = 0; i < count; i++) {
    const ang = (i / count) * Math.PI * 2 + r() * 0.4;
    const rr = mR * (0.55 + r() * 0.5), ht = mR * (0.15 + r() * 0.25);
    pos.set(Math.cos(ang) * rr, ht + 0.08, Math.sin(ang) * rr);
    const tilt = 0.3 + r() * 0.6;
    euler.set(-tilt * (r() > 0.5 ? 1 : -1), ang + Math.PI / 2 + r() * 0.5, r() * 0.4);
    M.compose(pos, new T.Quaternion().setFromEuler(euler), new T.Vector3(0.7 + r() * 0.6, 0.6 + r() * 0.4, 0.7 + r() * 0.6));
    mesh.setMatrixAt(i, M);

    const em = r();
    if (em < 0.3) col.setRGB(PAL.earth[0] + r() * 0.1, PAL.earth[1] + r() * 0.08, PAL.earth[2] + r() * 0.05);
    else if (em < 0.6) col.setRGB(PAL.twig[0] + r() * 0.1, PAL.twig[1] + r() * 0.08, PAL.twig[2] + r() * 0.05);
    else col.setRGB(PAL.twigL[0] + r() * 0.1, PAL.twigL[1] + r() * 0.08, PAL.twigL[2] + r() * 0.05);
    mesh.setColorAt(i, col);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

/** Build grass thatch strands (instanced). */
function buildGrassThatch(T, seed, mR) {
  mR = mR || 1.6;
  const r = rngFrom(seed + 2), count = 80;
  const geo = new T.PlaneGeometry(0.015, 0.28); geo.translate(0, 0.14, 0);
  const mat = makeToon(T, 0xffffff, { extra: { side: T.DoubleSide } });
  const mesh = new T.InstancedMesh(geo, mat, count); mesh.name = 'thatch';
  const M = new T.Matrix4(), col = new T.Color(), euler = new T.Euler(), pos = new T.Vector3();

  for (let i = 0; i < count; i++) {
    const ang = r() * Math.PI * 2, rad = r() * mR * 0.9;
    pos.set(Math.cos(ang) * rad, 0.03, Math.sin(ang) * rad);
    euler.set(-0.3 - r() * 0.5, ang + r() * 1.0, r() * 0.3);
    M.compose(pos, new T.Quaternion().setFromEuler(euler), new T.Vector3(0.8 + r() * 0.4, 1, 0.8 + r() * 0.4));
    mesh.setMatrixAt(i, M);
    if (r() < 0.4) col.setRGB(PAL.grass[0] + r() * 0.1, PAL.grass[1] + r() * 0.1, PAL.grass[2] + r() * 0.05);
    else col.setRGB(PAL.grassP[0] + r() * 0.1, PAL.grassP[1] + r() * 0.08, PAL.grassP[2] + r() * 0.05);
    mesh.setColorAt(i, col);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

/** Build stones embedded in the nest rim (instanced). */
function buildStones(T, seed, mR) {
  mR = mR || 1.6;
  const r = rngFrom(seed + 3), count = 4;
  const geo = new T.IcosahedronGeometry(1, 0);
  const mat = makeToon(T, 0xffffff, { extra: { flatShading: true } });
  const mesh = new T.InstancedMesh(geo, mat, count);
  mesh.castShadow = true; mesh.receiveShadow = true; mesh.name = 'stones';
  const M = new T.Matrix4(), col = new T.Color();

  for (let i = 0; i < count; i++) {
    const ang = (i / count) * Math.PI * 2 + 0.5, rad = mR * (0.65 + r() * 0.25);
    const sz = 0.05 + r() * 0.08;
    M.compose(new T.Vector3(Math.cos(ang) * rad, sz * 0.25, Math.sin(ang) * rad), new T.Quaternion(),
      new T.Vector3(sz * (0.8 + r() * 0.5), sz * (0.6 + r() * 0.4), sz * (0.7 + r() * 0.5)));
    mesh.setMatrixAt(i, M);
    if (r() < 0.33) col.setRGB(PAL.stone[0] + r() * 0.05, PAL.stone[1] + r() * 0.05, PAL.stone[2] + r() * 0.05);
    else if (r() < 0.66) col.setRGB(PAL.stoneL[0] + r() * 0.05, PAL.stoneL[1] + r() * 0.05, PAL.stoneL[2] + r() * 0.05);
    else col.setRGB(PAL.stoneW[0] + r() * 0.05, PAL.stoneW[1] + r() * 0.05, PAL.stoneW[2] + r() * 0.05);
    mesh.setColorAt(i, col);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

// ── Site variant builders ────────────────────────────────────────────────────

function buildPlainGround(T, size) {
  size = size || 6;
  const geo = new T.PlaneGeometry(size, size, 8, 8);
  const pos = geo.attributes.position, colors = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getY(i);
    const n = (hash3(Math.floor(x * 2), Math.floor(z * 2), 42) - 0.5) * 0.04;
    const hf = Math.exp(-(x * x + z * z) / 12);
    colors[i * 3] = lerp(PAL.g0[0], PAL.g1[0], hf) + n;
    colors[i * 3 + 1] = lerp(PAL.g0[1], PAL.g1[1], hf) + n;
    colors[i * 3 + 2] = lerp(PAL.g0[2], PAL.g1[2], hf) + n;
  }
  geo.setAttribute('color', new T.BufferAttribute(colors, 3));
  geo.rotateX(-Math.PI / 2);
  const mesh = new T.Mesh(geo, makeToon(T, 0xffffff, { extra: { vertexColors: true } }));
  mesh.receiveShadow = true; mesh.name = 'ground-plain';
  return mesh;
}

function buildLedgeGround(T) {
  const geo = new T.BoxGeometry(12, 0.5, 6, 4, 1, 4);
  const pos = geo.attributes.position, colors = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const nv = (hash3(Math.floor(x * 3), Math.floor(y * 5), Math.floor(z * 3)) - 0.5) * 0.1;
    if (y > 0.2) {
      const grass = hash3(Math.floor(x * 2), Math.floor(z * 2), 100) > 0.6;
      const base = grass ? PAL.g1 : PAL.r1;
      colors[i * 3] = base[0] + nv; colors[i * 3 + 1] = base[1] + nv; colors[i * 3 + 2] = base[2] + nv;
    } else {
      colors[i * 3] = PAL.r0[0] + nv; colors[i * 3 + 1] = PAL.r0[1] + nv; colors[i * 3 + 2] = PAL.r0[2] + nv;
    }
  }
  geo.setAttribute('color', new T.BufferAttribute(colors, 3));
  geo.translate(0, 0.25, 0);
  const mesh = new T.Mesh(geo, makeToon(T, 0xffffff, { extra: { vertexColors: true, flatShading: true } }));
  mesh.receiveShadow = true; mesh.castShadow = true; mesh.name = 'ground-ledge';
  return mesh;
}

function buildBurrowGround(T) {
  const group = new T.Group(); group.name = 'ground-burrow';
  group.add(buildPlainGround(T));

  // Tunnel hole
  const tGeo = new T.CylinderGeometry(0.45, 0.42, 2.2, 10, 1, true);
  tGeo.rotateZ(Math.PI / 2);
  const tPos = tGeo.attributes.position, tCol = new Float32Array(tPos.count * 3);
  for (let i = 0; i < tPos.count; i++) {
    tCol[i * 3] = PAL.caveM[0] + (Math.random() - 0.5) * 0.03;
    tCol[i * 3 + 1] = PAL.caveM[1] + (Math.random() - 0.5) * 0.03;
    tCol[i * 3 + 2] = PAL.caveM[2] + (Math.random() - 0.5) * 0.03;
  }
  tGeo.setAttribute('color', new T.BufferAttribute(tCol, 3));
  const tunnel = new T.Mesh(tGeo, makeToon(T, 0xffffff, { extra: { side: T.DoubleSide } }));
  tunnel.position.set(2, -0.25, 0); tunnel.receiveShadow = true; group.add(tunnel);

  // Dirt mound
  const dirtGeo = buildMoundGeometry(T, 9999, { radius: 0.6, detail: 1, heightScale: 0.2 });
  const dirt = new T.Mesh(dirtGeo, makeToon(T, 0xffffff, { extra: { vertexColors: true } }));
  dirt.position.set(0.8, -0.15, 0); dirt.scale.set(1.5, 0.5, 1); dirt.receiveShadow = true; group.add(dirt);
  return group;
}

function buildCaveGround(T) {
  const group = new T.Group(); group.name = 'ground-cave';
  const wallMat = makeToon(T, 0xffffff, { extra: { vertexColors: true, flatShading: true } });

  // Floor
  const fGeo = new T.PlaneGeometry(8, 8, 4, 4);
  const fPos = fGeo.attributes.position, fCol = new Float32Array(fPos.count * 3);
  for (let i = 0; i < fPos.count; i++) {
    const nv = (hash3(Math.floor(fPos.getX(i)), Math.floor(fPos.getY(i)), 77) - 0.5) * 0.03;
    fCol[i * 3] = PAL.caveM[0] + nv; fCol[i * 3 + 1] = PAL.caveM[1] + nv; fCol[i * 3 + 2] = PAL.caveM[2] + nv;
  }
  fGeo.setAttribute('color', new T.BufferAttribute(fCol, 3));
  fGeo.rotateX(-Math.PI / 2);
  const floor = new T.Mesh(fGeo, wallMat); floor.receiveShadow = true; group.add(floor);

  // Back wall
  const bGeo = new T.PlaneGeometry(8, 4, 4, 3);
  const bPos = bGeo.attributes.position, bCol = new Float32Array(bPos.count * 3);
  for (let i = 0; i < bPos.count; i++) {
    const nv = (hash3(Math.floor(bPos.getX(i) * 2), Math.floor(bPos.getY(i) * 2), 11) - 0.5) * 0.05;
    bCol[i * 3] = PAL.caveD[0] + nv; bCol[i * 3 + 1] = PAL.caveD[1] + nv; bCol[i * 3 + 2] = PAL.caveD[2] + nv;
  }
  bGeo.setAttribute('color', new T.BufferAttribute(bCol, 3));
  bGeo.translate(0, 2, -4); group.add(new T.Mesh(bGeo, wallMat));

  // Side walls
  const sGeo = new T.PlaneGeometry(8, 4, 2, 3);
  const sPos = sGeo.attributes.position, sCol = new Float32Array(sPos.count * 3);
  for (let i = 0; i < sPos.count; i++) {
    const nv = (hash3(Math.floor(sPos.getX(i) * 2), Math.floor(sPos.getY(i) * 2), 14) - 0.5) * 0.05;
    sCol[i * 3] = PAL.caveD[0] + nv; sCol[i * 3 + 1] = PAL.caveD[1] + nv; sCol[i * 3 + 2] = PAL.caveD[2] + nv;
  }
  sGeo.setAttribute('color', new T.BufferAttribute(sCol, 3));
  sGeo.rotateY(Math.PI / 2);
  const lw = new T.Mesh(sGeo, wallMat); lw.position.set(-4, 2, 0); group.add(lw);
  const rw = new T.Mesh(sGeo, wallMat); rw.position.set(4, 2, 0); rw.rotation.y = Math.PI; group.add(rw);

  // Ceiling
  const cGeo = new T.PlaneGeometry(8, 8, 2, 2);
  const cPos = cGeo.attributes.position, cCol = new Float32Array(cPos.count * 3);
  for (let i = 0; i < cPos.count; i++) { cCol[i * 3] = PAL.caveD[0]; cCol[i * 3 + 1] = PAL.caveD[1]; cCol[i * 3 + 2] = PAL.caveD[2]; }
  cGeo.setAttribute('color', new T.BufferAttribute(cCol, 3));
  cGeo.rotateX(Math.PI / 2); cGeo.translate(0, 3.5, 0); group.add(new T.Mesh(cGeo, wallMat));

  // Stalactites
  const stGeo = new T.ConeGeometry(0.08, 0.4, 5); stGeo.rotateX(Math.PI);
  const r2 = rngFrom(7777);
  for (let i = 0; i < 5; i++) {
    const st = new T.Mesh(stGeo, wallMat);
    st.position.set(-2 + r2() * 4, 3.3, -2 + r2() * 4);
    st.scale.set(0.5 + r2(), 0.5 + r2() * 1.5, 0.5 + r2());
    group.add(st);
  }
  return group;
}

// ── Material helper ──────────────────────────────────────────────────────────

/** Cache for the shared toon gradient texture. */
let _toonGrad = null;

function makeToon(T, color, opts) {
  opts = opts || {};
  const extra = opts.extra || {};
  if (!_toonGrad) {
    _toonGrad = new T.DataTexture(new T.Uint8Array([46, 46, 82, 82, 112, 112]), 6, 1, T.LuminanceFormat);
    _toonGrad.minFilter = T.NearestFilter;
    _toonGrad.magFilter = T.NearestFilter;
    _toonGrad.needsUpdate = true;
  }
  const m = new T.MeshToonMaterial({ color, gradientMap: _toonGrad, flatShading: true, ...extra });
  const origOC = m.onBeforeCompile;
  m.onBeforeCompile = function (shader) {
    if (origOC) origOC(shader);
    shader.fragmentShader = shader.fragmentShader.replace(
      '#include <tonemapping_fragment>',
      'float rim=pow(1.-max(dot(normalize(vViewPosition),normal),0.),3.);\n' +
      'gl_FragColor.rgb+=rim*vec3(.5,.66,.8)*.28;\n' +
      '#include <tonemapping_fragment>'
    );
  };
  return m;
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Build a single nest with eggs for a given site variant.
 * @param {typeof THREE} T - THREE.js namespace
 * @param {number} seed - Integer seed for determinism
 * @param {Object} params
 * @param {string} params.variant - 'plain' | 'ledge' | 'burrow' | 'cave'
 * @param {string} params.species - Egg tint: 'rondo' | 'zanco' | 'espinodo'
 * @param {string} params.hatch - 'whole' | 'crack'
 * @returns {THREE.Object3D}
 */
export function buildNest(T, seed, params) {
  params = params || {};
  const variant = params.variant || 'plain';
  const species = params.species || 'rondo';
  const hatch = params.hatch || 'whole';
  const r = rngFrom(seed);
  const group = new T.Group();
  group.name = 'nest-' + variant;

  // Ground
  let ground;
  switch (variant) {
    case 'ledge': ground = buildLedgeGround(T); break;
    case 'burrow': ground = buildBurrowGround(T); break;
    case 'cave': ground = buildCaveGround(T); break;
    default: ground = buildPlainGround(T);
  }
  group.add(ground);

  // Mound
  const mound = new T.Mesh(buildMoundGeometry(T, seed + 100), makeToon(T, 0xffffff, { extra: { vertexColors: true } }));
  mound.position.y = 0.05; mound.castShadow = true; mound.receiveShadow = true;
  group.add(mound);

  // Twigs, thatch, stones
  const twigs = buildTwigs(T, seed + 200, 1.6); twigs.position.y = 0.1; group.add(twigs);
  const thatch = buildGrassThatch(T, seed + 300, 1.6); thatch.position.y = 0.05; group.add(thatch);
  group.add(buildStones(T, seed + 400, 1.6));

  // 3 Eggs
  const eggColor = EGG_COLORS[species] || EGG_COLORS.rondo;
  const eggPos = [
    { x: -0.22, y: 0.32, z: 0.05, rz: -0.1 },
    { x: 0.05, y: 0.34, z: -0.1, rz: 0.05 },
    { x: 0.25, y: 0.31, z: 0.1, rz: 0.15 },
  ];
  for (let i = 0; i < 3; i++) {
    const egg = buildEggGeometry(T, seed + 500 + i, eggColor,
      (hatch === 'crack' && i === 1) ? 'crack' : 'whole');
    egg.position.set(eggPos[i].x, eggPos[i].y, eggPos[i].z);
    egg.rotation.z = eggPos[i].rz;
    egg.rotation.y = r() * 0.3;
    group.add(egg);

    // Crack segments
    if (egg.userData.crackSegs) {
      for (const seg of egg.userData.crackSegs) {
        const len = Math.hypot(seg.dx, seg.dy, seg.dz) || 0.01;
        const crGeo = new T.BoxGeometry(len, 0.003, 0.004);
        crGeo.translate(len / 2, 0, 0);
        const crMesh = new T.Mesh(crGeo, makeToon(T, 0x000000, { extra: { transparent: true, opacity: 0.7 } }));
        crMesh.position.set(seg.x, seg.y, seg.z);
        crMesh.lookAt(seg.x + seg.dx, seg.y + seg.dy, seg.z + seg.dz);
        crMesh.rotation.x = Math.PI / 2;
        egg.add(crMesh);
      }
    }
  }

  return group;
}

/**
 * Build all four variants side by side for the preview page.
 * @param {typeof THREE} T - THREE.js namespace
 * @param {number} baseSeed - Base seed (each variant gets a different sub-seed)
 * @returns {THREE.Object3D} A group containing all variants
 */
export function allVariants(T, baseSeed) {
  baseSeed = baseSeed || 42;
  const group = new T.Group(); group.name = 'nest-all-variants';
  const variants = ['plain', 'ledge', 'burrow', 'cave'];
  const species = ['rondo', 'zanco', 'espinodo', 'rondo'];
  const spacing = 4.0;

  for (let i = 0; i < 4; i++) {
    const nest = buildNest(T, baseSeed + i * 777, { variant: variants[i], species: species[i] });
    nest.position.x = (i - 1.5) * spacing; group.add(nest);

    // Hatching variant below
    const hatchNest = buildNest(T, baseSeed + i * 777 + 100, {
      variant: variants[i], species: species[(i + 1) % 4], hatch: 'crack'
    });
    hatchNest.position.x = (i - 1.5) * spacing;
    hatchNest.position.z = 2.0; hatchNest.position.y = -0.05;
    group.add(hatchNest);
  }

  // Center
  const box = new T.Box3().setFromObject(group);
  const center = box.getCenter(new T.Vector3());
  for (let i = 0; i < group.children.length; i++) {
    group.children[i].position.sub(center);
    group.children[i].position.y -= box.min.y - 0.05;
  }

  return group;
}

export default { buildNest, allVariants };