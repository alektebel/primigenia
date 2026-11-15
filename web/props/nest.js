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
  g0:      [0.10, 0.24, 0.05],     // dark grass
  g1:      [0.20, 0.38, 0.09],     // light grass
  tuft0:   [0.55, 0.62, 0.25],     // bright grass tuft
  tuft1:   [0.70, 0.72, 0.35],     // pale tuft
  r0:      [0.16, 0.17, 0.19],     // dark rock
  r1:      [0.26, 0.22, 0.15],     // mid rock
  earth:   [0.18, 0.12, 0.05],     // dark earth / twig base
  twig:    [0.28, 0.20, 0.11],     // twig brown
  twigL:   [0.38, 0.28, 0.16],     // lighter twig
  grass:   [0.22, 0.35, 0.10],     // nest grass thatch
  grassP:  [0.45, 0.50, 0.22],     // dried grass
  stone:   [0.22, 0.20, 0.18],     // grey stone
  stoneL:  [0.34, 0.32, 0.28],
  stoneW:  [0.32, 0.25, 0.16],
  egg1:    [0.74, 0.64, 0.38],     // warm cream (Rondo)
  egg2:    [0.38, 0.55, 0.48],     // cool blue-green (Zanco)
  egg3:    [0.54, 0.30, 0.20],     // red-brown (Espinodo)
  caveD:   [0.08, 0.07, 0.06],     // deep cave wall
  caveM:   [0.13, 0.11, 0.09],     // cave ledge
};

const EGG_COLORS = { rondo: PAL.egg1, zanco: PAL.egg2, espinodo: PAL.egg3 };

// ── Material helper ──────────────────────────────────────────────────────────
let _toonGrad = null;

function makeToon(T, color, opts) {
  opts = opts || {};
  const extra = opts.extra || {};
  if (!_toonGrad) {
    _toonGrad = new T.DataTexture(new Uint8Array([46, 46, 82, 82, 112, 112]), 6, 1, T.LuminanceFormat);
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

// ── Geometry factories ───────────────────────────────────────────────────────

/** Build an organic mound (scaled-down: ~1.2m wide, ~0.4m tall). */
function buildMoundGeometry(T, seed, p) {
  p = p || {};
  const radius = p.radius || 0.7, detail = p.detail || 1, hScale = p.heightScale || 0.2;
  const geo = new T.SphereGeometry(radius, 10, 5);  // Reduced: 10×5 = ~200 verts
  const pos = geo.attributes.position, colors = new Float32Array(pos.count * 3);

  for (let i = 0; i < pos.count; i++) {
    let x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const len = Math.hypot(x, y, z) || 1;
    const nx = x / len, ny = y / len, nz = z / len;

    // Squash sphere into flatter mound (total height ~radius * 0.5)
    y *= 0.45;

    let d = 0;
    if (ny < -0.25) {
      d = fbm(nx * 3, nz * 3, 0, 2) * 0.06 * (1 + (y / radius) * 2);
    } else {
      d = fbm(nx * 2.5, ny * 2.5, nz * 2.5, 3) * hScale;
      const rd = Math.sqrt(nx * nx + nz * nz);
      d += Math.max(0, (1 - rd * 1.3)) * 0.10 * hScale;
      // Top depression for eggs
      if (ny > 0.2) {
        const depress = (ny - 0.2) / 0.8;
        d -= depress * 0.06 * (0.5 + fbm(nx * 4, nz * 4, 0, 2) * 0.5);
      }
    }
    pos.setXYZ(i, x + nx * d * 0.4, y + ny * d * 0.4, z + nz * d * 0.4);

    // Vertex colour: height-based earth tones (more earthy, less grass-green)
    const nv = (fbm(nx * 3, ny * 3, nz * 3, 2) + 1) * 0.5;
    const isBottom = y < 0;
    const isSide = !isBottom && y < radius * 0.15;
    let cr, cg, cb;
    if (isBottom) {
      // Dark earth: warm brown, almost black-green
      cr = lerp(0.20, 0.30, nv); cg = lerp(0.14, 0.20, nv); cb = lerp(0.08, 0.12, nv);
    } else if (isSide) {
      // Side: earth-brown with some green (grass thatch beginning)
      cr = lerp(0.30, 0.40, nv); cg = lerp(0.22, 0.28, nv); cb = lerp(0.12, 0.16, nv);
    } else {
      // Top: grassy-brown (mix of green grass and dried grass)
      cr = lerp(0.35, 0.48, nv); cg = lerp(0.42, 0.52, nv); cb = lerp(0.16, 0.24, nv);
    }
    colors[i * 3] = cr; colors[i * 3 + 1] = cg; colors[i * 3 + 2] = cb;
    if (isBottom) { colors[i * 3] *= 0.6; colors[i * 3 + 1] *= 0.6; colors[i * 3 + 2] *= 0.6; }
  }
  geo.setAttribute('color', new T.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  return geo;
}

/** Build a nest egg: asymmetric ellipsoid, pointier at top. */
function buildEggGeometry(T, seed, color, hatch) {
  hatch = hatch || 'whole';
  const r = rngFrom(seed), sw = 10, sh = 8;  // Reduced for triangle budget
  const posA = [], idxA = [], colA = [];
  const c = new T.Color(color[0], color[1], color[2]);

  for (let iy = 0; iy <= sh; iy++) {
    const v = iy / sh, t = v;
    // Egg shape: wider at bottom, narrower/pointier at top
    const baseY = (v - 0.4) * 0.32;  // shift so wider part is at bottom
    const y = baseY;
    // Width: exponential taper from bottom to top (more egg-like)
    const bottomW = 0.075;  // wider base
    const topW = 0.025;     // narrow top
    const widthFactor = Math.pow(1 - t, 1.3);  // exponential taper
    const wR = bottomW + topW * (1 - widthFactor);
    for (let ix = 0; ix <= sw; ix++) {
      const u = ix / sw, a = u * Math.PI * 2;
      posA.push(Math.cos(a) * wR, y, Math.sin(a) * wR * 0.82);
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
  mesh.castShadow = true; mesh.receiveShadow = true; mesh.name = 'egg';
  mesh.userData.hatchState = hatch;

  if (hatch === 'crack') {
    // Store crack data for rendering as thin box segments in the nest builder
    mesh.userData.crackPts = [];
    let cx = 0, cy = 0.02, cz = 0.065;
    for (let i = 0; i < 5; i++) {
      const nx = cx + (r() - 0.5) * 0.035, ny = cy + 0.025 + r() * 0.012, nz = cz + (r() - 0.5) * 0.03;
      mesh.userData.crackPts.push({ sx: cx, sy: cy, sz: cz, ex: nx, ey: ny, ez: nz });
      cx = nx; cy = ny; cz = nz;
    }
  }
  return mesh;
}

/** Build woven twigs around the nest rim (instanced). */
function buildTwigs(T, seed, mR) {
  mR = mR || 0.7;
  const r = rngFrom(seed + 1), count = 25;  // Reduced from 35
  // Thin twigs: 0.10m long, 0.003m thick, 3 radial segments (minimal)
  const geo = new T.CylinderGeometry(0.003, 0.005, 0.10, 3);
  geo.rotateZ(Math.PI / 2); geo.translate(0.05, 0, 0);
  const mat = new T.MeshToonMaterial({
    color: 0xffffff, gradientMap: _toonGrad, flatShading: true, vertexColors: true,
  });
  const origOC = mat.onBeforeCompile;
  mat.onBeforeCompile = function (shader) {
    if (origOC) origOC(shader);
    shader.fragmentShader = shader.fragmentShader.replace(
      '#include <tonemapping_fragment>',
      'float rim=pow(1.-max(dot(normalize(vViewPosition),normal),0.),3.);\n' +
      'gl_FragColor.rgb+=rim*vec3(.5,.66,.8)*.15;\n' +
      '#include <tonemapping_fragment>'
    );
  };
  const mesh = new T.InstancedMesh(geo, mat, count);
  mesh.castShadow = true; mesh.receiveShadow = true; mesh.name = 'twigs';
  const M = new T.Matrix4(), col = new T.Color(), euler = new T.Euler(), pos = new T.Vector3();

  for (let i = 0; i < count; i++) {
    const ang = (i / count) * Math.PI * 2 + r() * 0.5;
    const rr = mR * (0.40 + r() * 0.7);
    const ht = mR * (0.10 + r() * 0.25);
    pos.set(Math.cos(ang) * rr, ht, Math.sin(ang) * rr);
    const tilt = 0.35 + r() * 0.7;
    euler.set(-tilt * (r() > 0.5 ? 1 : -1), ang + Math.PI / 2 + r() * 0.6 - 0.3, r() * 0.5 - 0.25);
    M.compose(pos, new T.Quaternion().setFromEuler(euler), new T.Vector3(
      0.7 + r() * 0.5, 0.6 + r() * 0.4, 0.7 + r() * 0.5
    ));
    mesh.setMatrixAt(i, M);
    const em = r();
    if (em < 0.35) col.setRGB(0.20 + r() * 0.07, 0.13 + r() * 0.05, 0.06 + r() * 0.03);
    else if (em < 0.7) col.setRGB(0.28 + r() * 0.08, 0.19 + r() * 0.06, 0.10 + r() * 0.04);
    else col.setRGB(0.36 + r() * 0.08, 0.26 + r() * 0.06, 0.13 + r() * 0.04);
    mesh.setColorAt(i, col);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

/** Build grass thatch strands (instanced). */
function buildGrassThatch(T, seed, mR) {
  mR = mR || 0.7;
  const r = rngFrom(seed + 2), count = 30;  // Reduced from 50
  const geo = new T.PlaneGeometry(0.010, 0.15); geo.translate(0, 0.075, 0);
  const mat = makeToon(T, 0xffffff, { extra: { side: T.DoubleSide } });
  const mesh = new T.InstancedMesh(geo, mat, count); mesh.name = 'thatch';
  const M = new T.Matrix4(), col = new T.Color(), euler = new T.Euler(), pos = new T.Vector3();

  for (let i = 0; i < count; i++) {
    const ang = r() * Math.PI * 2, rad = r() * mR * 0.85;
    pos.set(Math.cos(ang) * rad, 0.02, Math.sin(ang) * rad);
    euler.set(-0.25 - r() * 0.4, ang + r() * 0.8, r() * 0.25);
    M.compose(pos, new T.Quaternion().setFromEuler(euler), new T.Vector3(0.7 + r() * 0.4, 1, 0.7 + r() * 0.4));
    mesh.setMatrixAt(i, M);
    if (r() < 0.4) col.setRGB(PAL.grass[0] + r() * 0.08, PAL.grass[1] + r() * 0.08, PAL.grass[2] + r() * 0.04);
    else col.setRGB(PAL.grassP[0] + r() * 0.08, PAL.grassP[1] + r() * 0.06, PAL.grassP[2] + r() * 0.03);
    mesh.setColorAt(i, col);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

/** Build stones embedded in the nest rim (instanced). */
function buildStones(T, seed, mR) {
  mR = mR || 0.7;
  const r = rngFrom(seed + 3), count = 3;
  const geo = new T.IcosahedronGeometry(1, 0);
  const mat = makeToon(T, 0xffffff, { extra: { flatShading: true } });
  const mesh = new T.InstancedMesh(geo, mat, count);
  mesh.castShadow = true; mesh.receiveShadow = true; mesh.name = 'stones';
  const M = new T.Matrix4(), col = new T.Color();

  for (let i = 0; i < count; i++) {
    const ang = (i / count) * Math.PI * 2 + 0.5, rad = mR * (0.55 + r() * 0.2);
    const sz = 0.025 + r() * 0.04;
    M.compose(new T.Vector3(Math.cos(ang) * rad, sz * 0.2, Math.sin(ang) * rad), new T.Quaternion(),
      new T.Vector3(sz * (0.7 + r() * 0.5), sz * (0.5 + r() * 0.3), sz * (0.6 + r() * 0.4)));
    mesh.setMatrixAt(i, M);
    if (r() < 0.33) col.setRGB(PAL.stone[0] + r() * 0.04, PAL.stone[1] + r() * 0.04, PAL.stone[2] + r() * 0.03);
    else if (r() < 0.66) col.setRGB(PAL.stoneL[0] + r() * 0.04, PAL.stoneL[1] + r() * 0.04, PAL.stoneL[2] + r() * 0.03);
    else col.setRGB(PAL.stoneW[0] + r() * 0.04, PAL.stoneW[1] + r() * 0.04, PAL.stoneW[2] + r() * 0.03);
    mesh.setColorAt(i, col);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

// ── Site variant builders ────────────────────────────────────────────────────

function buildPlainGround(T, size) {
  size = size || 4;
  const geo = new T.PlaneGeometry(size, size, 8, 8);  // Reduced from 12x12
  const pos = geo.attributes.position, colors = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getY(i);
    const n = (hash3(Math.floor(x * 2), Math.floor(z * 2), 42) - 0.5) * 0.025;
    const hf = Math.exp(-(x * x + z * z) / 16);
    colors[i * 3] = 0.18 * hf + 0.09 * (1 - hf) + n;
    colors[i * 3 + 1] = 0.36 * hf + 0.16 * (1 - hf) + n;
    colors[i * 3 + 2] = 0.10 * hf + 0.05 * (1 - hf) + n;
  }
  geo.setAttribute('color', new T.BufferAttribute(colors, 3));
  geo.rotateX(-Math.PI / 2);
  const mesh = new T.Mesh(geo, makeToon(T, 0xffffff, { extra: { vertexColors: true } }));
  mesh.receiveShadow = true; mesh.name = 'ground-plain';
  return mesh;
}

function buildLedgeGround(T) {
  const geo = new T.BoxGeometry(2.5, 0.28, 2.2, 2, 1, 2);
  const pos = geo.attributes.position, colors = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const nv = (hash3(Math.floor(x * 3), Math.floor(y * 5), Math.floor(z * 3)) - 0.5) * 0.06;
    if (y > 0.1) {
      const grass = hash3(Math.floor(x * 2), Math.floor(z * 2), 100) > 0.5;
      const base = grass ? PAL.g1 : PAL.r1;
      colors[i * 3] = base[0] + nv; colors[i * 3 + 1] = base[1] + nv; colors[i * 3 + 2] = base[2] + nv;
    } else {
      colors[i * 3] = PAL.r0[0] + nv; colors[i * 3 + 1] = PAL.r0[1] + nv; colors[i * 3 + 2] = PAL.r0[2] + nv;
    }
  }
  geo.setAttribute('color', new T.BufferAttribute(colors, 3));
  geo.translate(0, 0.14, 0);
  const mesh = new T.Mesh(geo, makeToon(T, 0xffffff, { extra: { vertexColors: true, flatShading: true } }));
  mesh.receiveShadow = true; mesh.castShadow = true; mesh.name = 'ground-ledge';
  return mesh;
}

function buildBurrowGround(T) {
  const group = new T.Group(); group.name = 'ground-burrow';
  group.add(buildPlainGround(T));

  const tGeo = new T.CylinderGeometry(0.22, 0.20, 1.0, 6, 1, true);  // 6 radial instead of 8
  tGeo.rotateZ(Math.PI / 2);
  const tPos = tGeo.attributes.position, tCol = new Float32Array(tPos.count * 3);
  for (let i = 0; i < tPos.count; i++) {
    tCol[i * 3] = PAL.caveM[0] + (Math.random() - 0.5) * 0.02;
    tCol[i * 3 + 1] = PAL.caveM[1] + (Math.random() - 0.5) * 0.02;
    tCol[i * 3 + 2] = PAL.caveM[2] + (Math.random() - 0.5) * 0.02;
  }
  tGeo.setAttribute('color', new T.BufferAttribute(tCol, 3));
  const tunnel = new T.Mesh(tGeo, makeToon(T, 0xffffff, { extra: { side: T.DoubleSide } }));
  tunnel.position.set(1.0, -0.1, 0); tunnel.receiveShadow = true; group.add(tunnel);

  const dirtGeo = buildMoundGeometry(T, 9999, { radius: 0.25, detail: 1, heightScale: 0.1 });
  const dirt = new T.Mesh(dirtGeo, makeToon(T, 0xffffff, { extra: { vertexColors: true } }));
  dirt.position.set(0.4, -0.06, 0); dirt.scale.set(1.5, 0.5, 1); dirt.receiveShadow = true; group.add(dirt);
  return group;
}

function buildCaveGround(T) {
  const group = new T.Group(); group.name = 'ground-cave';
  const wallMat = makeToon(T, 0xffffff, { extra: { vertexColors: true, flatShading: true } });

  // Small floor
  const fGeo = new T.PlaneGeometry(3.5, 3.5, 2, 2);
  const fPos = fGeo.attributes.position, fCol = new Float32Array(fPos.count * 3);
  for (let i = 0; i < fPos.count; i++) {
    const nv = (hash3(Math.floor(fPos.getX(i)), Math.floor(fPos.getY(i)), 77) - 0.5) * 0.02;
    fCol[i * 3] = PAL.caveM[0] + nv; fCol[i * 3 + 1] = PAL.caveM[1] + nv; fCol[i * 3 + 2] = PAL.caveM[2] + nv;
  }
  fGeo.setAttribute('color', new T.BufferAttribute(fCol, 3));
  fGeo.rotateX(-Math.PI / 2);
  group.add(new T.Mesh(fGeo, wallMat));

  // Back wall (lower)
  const bGeo = new T.PlaneGeometry(3.5, 1.5, 3, 2);
  const bPos = bGeo.attributes.position, bCol = new Float32Array(bPos.count * 3);
  for (let i = 0; i < bPos.count; i++) {
    const nv = (hash3(Math.floor(bPos.getX(i) * 2), Math.floor(bPos.getY(i) * 2), 11) - 0.5) * 0.03;
    bCol[i * 3] = PAL.caveD[0] + nv; bCol[i * 3 + 1] = PAL.caveD[1] + nv; bCol[i * 3 + 2] = PAL.caveD[2] + nv;
  }
  bGeo.setAttribute('color', new T.BufferAttribute(bCol, 3));
  bGeo.translate(0, 0.75, -1.75); group.add(new T.Mesh(bGeo, wallMat));

  // Side walls
  const sGeo = new T.PlaneGeometry(3.5, 1.5, 2, 2);
  const sPos = sGeo.attributes.position, sCol = new Float32Array(sPos.count * 3);
  for (let i = 0; i < sPos.count; i++) {
    const nv = (hash3(Math.floor(sPos.getX(i) * 2), Math.floor(sPos.getY(i) * 2), 14) - 0.5) * 0.03;
    sCol[i * 3] = PAL.caveD[0] + nv; sCol[i * 3 + 1] = PAL.caveD[1] + nv; sCol[i * 3 + 2] = PAL.caveD[2] + nv;
  }
  sGeo.setAttribute('color', new T.BufferAttribute(sCol, 3));
  sGeo.rotateY(Math.PI / 2);
  const lw = new T.Mesh(sGeo, wallMat); lw.position.set(-1.75, 0.75, 0); group.add(lw);
  const rw = new T.Mesh(sGeo, wallMat); rw.position.set(1.75, 0.75, 0); rw.rotation.y = Math.PI; group.add(rw);

  // Ceiling (low)
  const cGeo = new T.PlaneGeometry(3.5, 3.5, 1, 1);
  const cPos = cGeo.attributes.position, cCol = new Float32Array(cPos.count * 3);
  for (let i = 0; i < cPos.count; i++) { cCol[i * 3] = PAL.caveD[0]; cCol[i * 3 + 1] = PAL.caveD[1]; cCol[i * 3 + 2] = PAL.caveD[2]; }
  cGeo.setAttribute('color', new T.BufferAttribute(cCol, 3));
  cGeo.rotateX(Math.PI / 2); cGeo.translate(0, 1.5, 0); group.add(new T.Mesh(cGeo, wallMat));

  return group;
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

  // Mound (centered)
  const mound = new T.Mesh(buildMoundGeometry(T, seed + 100), makeToon(T, 0xffffff, { extra: { vertexColors: true } }));
  mound.castShadow = true; mound.receiveShadow = true;
  group.add(mound);

  // Twigs, thatch, stones
  const twigs = buildTwigs(T, seed + 200, 0.7); twigs.position.y = 0.02; group.add(twigs);
  const thatch = buildGrassThatch(T, seed + 300, 0.7); thatch.position.y = 0; group.add(thatch);
  group.add(buildStones(T, seed + 400, 0.7));

  // 3 Eggs on top of mound (Y positions adjusted to sit on mound surface)
  const eggColor = EGG_COLORS[species] || EGG_COLORS.rondo;
  const eggPos = [
    { x: -0.10, y: 0.36, z: 0.04, rz: -0.08 },
    { x: 0.01, y: 0.38, z: -0.06, rz: 0.04 },
    { x: 0.12, y: 0.35, z: 0.07, rz: 0.10 },
  ];
  for (let i = 0; i < 3; i++) {
    const egg = buildEggGeometry(T, seed + 500 + i, eggColor,
      (hatch === 'crack' && i === 1) ? 'crack' : 'whole');
    egg.position.set(eggPos[i].x, eggPos[i].y, eggPos[i].z);
    egg.rotation.z = eggPos[i].rz;
    egg.rotation.y = r() * 0.3;
    group.add(egg);

    if (egg.userData.crackPts) {
      // Build thin box segments for each crack (1 draw call per crack)
      egg.userData.crackPts.forEach((seg) => {
        const dx = seg.ex - seg.sx, dy = seg.ey - seg.sy, dz = seg.ez - seg.sz;
        const len = Math.hypot(dx, dy, dz) || 0.005;
        const crGeo = new T.BoxGeometry(len, 0.002, 0.003);
        crGeo.translate(len / 2, 0, 0);
        const crMat = makeToon(T, 0x000000, { extra: { transparent: true, opacity: 0.5, flatShading: false } });
        const crMesh = new T.Mesh(crGeo, crMat);
        crMesh.position.set((seg.sx + seg.ex) / 2, (seg.sy + seg.ey) / 2, (seg.sz + seg.ez) / 2);
        if (len > 0.001) crMesh.lookAt(seg.ex, seg.ey, seg.ez);
        crMesh.rotation.x = Math.PI / 2;
        egg.add(crMesh);
      });
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
  const spacing = 2.8;

  for (let i = 0; i < 4; i++) {
    const nest = buildNest(T, baseSeed + i * 777, { variant: variants[i], species: species[i] });
    nest.position.x = (i - 1.5) * spacing; group.add(nest);

    // Hatching variant below, to the right
    const hatchNest = buildNest(T, baseSeed + i * 777 + 100, {
      variant: variants[i], species: species[(i + 1) % 4], hatch: 'crack'
    });
    hatchNest.position.x = (i - 1.5) * spacing;
    hatchNest.position.z = 1.2; hatchNest.position.y = -0.02;
    group.add(hatchNest);
  }

  // Center
  const box = new T.Box3().setFromObject(group);
  const center = box.getCenter(new T.Vector3());
  for (let i = 0; i < group.children.length; i++) {
    group.children[i].position.sub(center);
    group.children[i].position.y -= box.min.y - 0.02;
  }

  return group;
}

export default { buildNest, allVariants };