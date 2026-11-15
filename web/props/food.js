/* Food plants and meadow ground cover (G66).
 * Self-contained ES module: three r128. Each builder takes (THREE, seed, params)
 * and returns an Object3D or InstancedMesh. Fully deterministic from seed.
 *
 * Style: toon materials with the valley's 3-band ramp and rim light,
 * palette C (Current+, G63) for the world. No creature skin materials.
 *
 * Food plants (P4 herbivore food store):
 *   - berryBush({size?, full?, depleted?}): round shrub with berry clusters
 *   - tuberLeaves({size?}): broad low-lying leaf cluster
 *   - fruitingStalk({height?}): tall thin stalk with fruit at top
 *
 * Ground cover (instanced, low draw calls):
 *   - flowerPatches({count?, flowerType?, full?}): 4 flower types, instanced
 *   - mossPatches({count?}): low irregular patches, instanced
 *   - fernPatches({count?}): frond shapes, instanced
 *   - cloverPatches({count?}): 3-leaf clusters, instanced
 */

export function rng(seed) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));
const sstep = (a, b, x) => { x = clamp((x - a) / (b - a), 0, 1); return x * x * (3 - 2 * x) };
let _T = null;

/* Set the THREE.js constructor reference (call from the HTML before using). */
export function setThree(T) { _T = T; }

/* Shared gradient map texture (created once). */
let _gradTex = null;
function getGradTex() {
  if (_gradTex) return _gradTex;
  _gradTex = new _T.DataTexture(new Uint8Array([46, 46, 82, 82, 112, 112]), 6, 1, _T.LuminanceFormat);
  _gradTex.minFilter = _gradTex.magFilter = _T.NearestFilter;
  _gradTex.needsUpdate = true;
  return _gradTex;
}

/* Create a toon-style material matching the valley's aesthetic.
 * MeshStandardMaterial with the right color, roughness, and lighting
 * achieves the BotW-like look. */
function toon(o) {
  return new _T.MeshStandardMaterial({ color: o.color || 0xffffff, roughness: 0.85, metalness: 0, ...o });
}

/* ---- Simple geometry helpers ---- */
function ell(sx, sy, sz) {
  const g = new _T.SphereGeometry(1, 12, 8);
  g.scale(sx, sy, sz);
  return g;
}

function cyl(rT, rB, h, seg) { return new _T.CylinderGeometry(rT, rB, h, seg || 8); }

/* ---- Berry Bush (G2: herbivore plant — berries) ---- */
export function berryBush(T, seed, params = {}) {
  _T = T;
  const { size = 1, full = true } = params;
  const rnd = rng(seed ^ 0x4B7F);
  const group = new _T.Group();
  const s = size;

  const woodM = toon({ color: col('#5a3a22') });
  const leafM = toon({ color: col('#4a7a2a') });

  // Main trunk
  group.add(Object.assign(new _T.Mesh(cyl(0.08*s, 0.12*s, 0.6*s, 8), woodM), { position: new _T.Vector3(0, 0.3*s, 0) }));

  // Main branches (3–4)
  const branchCount = 3 + Math.round(rnd() * 2);
  for (let i = 0; i < branchCount; i++) {
    const a = (i / branchCount) * Math.PI * 2 + rnd() * 0.5;
    const len = (0.3 + rnd() * 0.25) * s;
    const branch = new _T.Mesh(cyl(0.03*s, 0.05*s, len, 6), woodM);
    branch.position.set(Math.cos(a) * 0.15*s, (0.4 + 0.15 + rnd() * 0.15) * s, Math.sin(a) * 0.15*s);
    branch.rotation.z = Math.cos(a) * 0.6;
    branch.rotation.x = Math.sin(a) * 0.6;
    group.add(branch);
  }

  // Leaf clusters (ellipsoids on branch tips)
  const clusterCount = full ? 6 : 3;
  for (let i = 0; i < clusterCount; i++) {
    const a = (i / clusterCount) * Math.PI * 2 + rnd() * 0.8;
    const cx = Math.cos(a) * (0.35 + rnd() * 0.15) * s;
    const cy = (0.55 + rnd() * 0.15) * s;
    const cz = Math.sin(a) * (0.35 + rnd() * 0.15) * s;
    const sc = (0.15 + rnd() * 0.1) * s;
    group.add(Object.assign(new _T.Mesh(ell(sc*1.2, sc*0.7, sc*1.2), leafM), { position: new _T.Vector3(cx, cy, cz) }));
  }

  // Berry clusters
  if (full) {
    const berryCount = 18 + Math.round(rnd() * 8);
    const berryGeo = ell(0.02*s, 0.02*s, 0.02*s);
    const berryM = toon({ color: col('#7a2040') });
    const berryMesh = new _T.InstancedMesh(berryGeo, berryM, berryCount);
    const d = new _T.Object3D();
    let ci = 0;
    for (let i = 0; i < 5 && ci < berryCount; i++) {
      const a = (i / 5) * Math.PI * 2;
      const br = 0.28 * s;
      for (let j = 0; j < 4 && ci < berryCount; j++) {
        const ba = a + (j - 1.5) * 0.4 + rnd() * 0.2;
        d.position.set(Math.cos(ba) * br, (0.52 + rnd() * 0.08) * s, Math.sin(ba) * br);
        d.scale.setScalar(0.8 + rnd() * 0.5);
        d.updateMatrix();
        berryMesh.setMatrixAt(ci++, d.matrix);
      }
    }
    berryMesh.instanceMatrix.needsUpdate = true;
    berryMesh.frustumCulled = false;
    group.add(berryMesh);
  }

  // Depleted: stubs where berries were eaten
  if (!full) {
    const stubCount = 5 + Math.round(rnd() * 3);
    const stubM = toon({ color: col('#4a5a30') });
    const stubMesh = new _T.InstancedMesh(ell(0.01*s, 0.01*s, 0.01*s), stubM, stubCount);
    const d = new _T.Object3D();
    for (let i = 0; i < stubCount; i++) {
      const a = rnd() * Math.PI * 2;
      d.position.set(Math.cos(a) * 0.25*s, (0.5 + rnd() * 0.15) * s, Math.sin(a) * 0.25*s);
      d.updateMatrix();
      stubMesh.setMatrixAt(i, d.matrix);
    }
    stubMesh.instanceMatrix.needsUpdate = true;
    stubMesh.frustumCulled = false;
    group.add(stubMesh);
  }

  return group;
}

/* ---- Tuber Leaves (G2: herbivore plant — broad leaves, tuber underground) ---- */
export function tuberLeaves(T, seed, params = {}) {
  _T = T;
  const { size = 1, full = true } = params;
  const rnd = rng(seed ^ 0xA3D1);
  const group = new _T.Group();
  const s = size;
  const leafM = full ? toon({ color: col('#3a8830') }) : toon({ color: col('#5a7040') });

  // Broad leaf cluster (5–7 leaves radiating from center)
  const leafCount = full ? 7 : 4;
  for (let i = 0; i < leafCount; i++) {
    const a = (i / leafCount) * Math.PI * 2 + rnd() * 0.4;
    const len = (0.25 + rnd() * 0.1) * s;
    const width = (0.1 + rnd() * 0.06) * s;

    // Leaf blade: flat elongated shape
    const pos = [], nor = [], uv = [], idx = [];
    const segs = 6;
    for (let j = 0; j <= segs; j++) {
      const t = j / segs;
      const lw = width * (1 - Math.pow(t, 0.7));
      const ex = t * len;
      pos.push(-lw, 0, ex, lw, 0, ex);
      nor.push(0, 1, 0, 0, 1, 0);
      uv.push(0, t, 1, t);
      if (j < segs) {
        const b = j * 2;
        idx.push(b, b + 2, b + 1, b + 1, b + 2, b + 3);
      }
    }
    const geo = new _T.BufferGeometry();
    geo.setAttribute('position', new _T.Float32BufferAttribute(pos, 3));
    geo.setAttribute('normal', new _T.Float32BufferAttribute(nor, 3));
    geo.setAttribute('uv', new _T.Float32BufferAttribute(uv, 2));
    geo.setIndex(idx);
    geo.computeVertexNormals();

    const leaf = new _T.Mesh(geo, leafM);
    leaf.position.set(Math.cos(a) * len * 0.2, (0.04 + rnd() * 0.03) * s, Math.sin(a) * len * 0.2);
    leaf.rotation.y = a + Math.PI / 2;
    leaf.rotation.z = -0.25 - rnd() * 0.2;
    group.add(leaf);

    // Leaf midrib bump
    const midrib = new _T.Mesh(cyl(0.003*s, 0.005*s, len * 0.85, 4), toon({ color: col('#2a6a20') }));
    midrib.position.copy(leaf.position);
    midrib.rotation.copy(leaf.rotation);
    midrib.position.y += 0.002 * s;
    group.add(midrib);
  }

  // Small grass tufts around the base
  for (let i = 0; i < 6; i++) {
    const a = rnd() * Math.PI * 2;
    const r = 0.15 + rnd() * 0.15;
    const h = (0.06 + rnd() * 0.06) * s;
    const tuft = new _T.Mesh(new _T.ConeGeometry(0.015*s, h, 5), toon({ color: col('#4a7a30') }));
    tuft.position.set(Math.cos(a) * r * s, h * 0.4, Math.sin(a) * r * s);
    tuft.rotation.x = (rnd() - 0.5) * 0.3;
    tuft.rotation.z = (rnd() - 0.5) * 0.3;
    group.add(tuft);
  }

  return group;
}

/* ---- Fruiting Stalk (G2: tall herbivore food — tall fruiting plant) ---- */
export function fruitingStalk(T, seed, params = {}) {
  _T = T;
  const { height = 1.5, full = true } = params;
  const rnd = rng(seed ^ 0xC7E2);
  const group = new _T.Group();
  const s = 1;
  const stalkH = height * s;

  const stalkM = full ? toon({ color: col('#5a8030') }) : toon({ color: col('#7a8a50') });

  // Main stalk
  group.add(Object.assign(new _T.Mesh(cyl(0.02*s, 0.035*s, stalkH, 8), stalkM), { position: new _T.Vector3(0, stalkH / 2, 0) }));

  // Ridge details along the stalk
  const ridgeCount = 8 + Math.round(rnd() * 4);
  for (let i = 0; i < ridgeCount; i++) {
    const t = 0.15 + (i / ridgeCount) * 0.8;
    const ridge = new _T.Mesh(ell(0.045*s, 0.008*s, 0.045*s), stalkM);
    ridge.position.y = t * stalkH;
    ridge.rotation.x = Math.PI / 2;
    group.add(ridge);
  }

  // Small leaf blades along the stalk
  const leafCount = 4 + Math.round(rnd() * 3);
  for (let i = 0; i < leafCount; i++) {
    const t = 0.3 + (i / leafCount) * 0.55;
    const a = rnd() * Math.PI * 2;
    const lLen = (0.12 + rnd() * 0.08) * s;
    const leaf = new _T.Mesh(new _T.BoxGeometry(0.02*s, 0.005*s, lLen), toon({ color: col('#4a8030') }));
    leaf.position.set(Math.cos(a) * 0.03*s, t * stalkH, Math.sin(a) * 0.03*s);
    leaf.rotation.y = a;
    leaf.rotation.z = 0.4;
    group.add(leaf);
  }

  // Fruit cluster at the top
  if (full) {
    const fruitCount = 8 + Math.round(rnd() * 5);
    const fruitM = toon({ color: col('#d08030') });
    const fruitMesh = new _T.InstancedMesh(ell(0.035*s, 0.03*s, 0.035*s), fruitM, fruitCount);
    const d = new _T.Object3D();
    let fi = 0;
    for (let i = 0; i < 3 && fi < fruitCount; i++) {
      const a = (i / 3) * Math.PI * 2 + rnd() * 0.5;
      for (let j = 0; j < 3 && fi < fruitCount; j++) {
        const fa = a + (j - 1) * 0.5;
        const fr = 0.04 + rnd() * 0.03;
        d.position.set(Math.cos(fa) * fr*s, (0.85 + rnd() * 0.1) * stalkH, Math.sin(fa) * fr*s);
        d.scale.setScalar(0.7 + rnd() * 0.5);
        d.updateMatrix();
        fruitMesh.setMatrixAt(fi++, d.matrix);
      }
    }
    fruitMesh.instanceMatrix.needsUpdate = true;
    fruitMesh.frustumCulled = false;
    group.add(fruitMesh);

    // Stalk tip
    group.add(Object.assign(new _T.Mesh(new _T.ConeGeometry(0.015*s, 0.08*s, 6), stalkM), { position: new _T.Vector3(0, stalkH + 0.04*s, 0) }));
  }

  return group;
}

/* ---- Flower Patches (instanced, 4 types) ---- */
export function flowerPatches(T, seed, params = {}) {
  _T = T;
  const { count = 30, flowerType = 0, full = true } = params;
  const rnd = rng(seed ^ 0x1F9A + flowerType * 1000);

  const types = [
    { petals: 5, petalColor: '#e84080', centerColor: '#d0c040', stemColor: '#3a7030', size: 0.04 },
    { petals: 5, petalColor: '#6070e8', centerColor: '#d0c040', stemColor: '#3a7030', size: 0.035 },
    { petals: 6, petalColor: '#e8a030', centerColor: '#602020', stemColor: '#3a7030', size: 0.05 },
    { petals: 4, petalColor: '#c060e0', centerColor: '#e0e040', stemColor: '#3a7030', size: 0.03 },
  ];
  const ft = types[flowerType] || types[0];

  const stemGeo = cyl(0.002, 0.003, 0.08, 4);
  const stemMat = toon({ color: col(ft.stemColor) });
  const petalGeo = ell(0.012, 0.001, 0.006);
  const petalMat = toon({ color: col(ft.petalColor) });
  const centerGeo = ell(0.008, 0.003, 0.008);
  const centerMat = toon({ color: col(ft.centerColor) });

  const stemMesh = new _T.InstancedMesh(stemGeo, stemMat, count);
  const petalMesh = new _T.InstancedMesh(petalGeo, petalMat, count * ft.petals);
  const centerMesh = new _T.InstancedMesh(centerGeo, centerMat, count);

  const d = new _T.Object3D();
  let si = 0, pi = 0, ci = 0;

  for (let i = 0; i < count; i++) {
    const x = (rnd() - 0.5) * 8;
    const z = (rnd() - 0.5) * 6;
    const h = 0.06 + rnd() * 0.06;

    // Stem
    d.position.set(x, h / 2, z);
    d.rotation.set((rnd() - 0.5) * 0.15, rnd() * Math.PI * 2, (rnd() - 0.5) * 0.15);
    d.updateMatrix();
    stemMesh.setMatrixAt(si++, d.matrix);

    // Petals
    const topY = h + 0.005;
    for (let p = 0; p < ft.petals; p++) {
      const a = (p / ft.petals) * Math.PI * 2;
      const pr = ft.size * 0.6;
      d.position.set(x + Math.cos(a) * pr, topY, z + Math.sin(a) * pr);
      d.scale.setScalar(full ? 1 : 0.5);
      d.rotation.set(Math.PI / 2, a, 0);
      d.updateMatrix();
      petalMesh.setMatrixAt(pi++, d.matrix);
    }

    // Center
    d.position.set(x, topY + 0.001, z);
    d.scale.setScalar(full ? 1 : 0.5);
    d.updateMatrix();
    centerMesh.setMatrixAt(ci++, d.matrix);
  }

  stemMesh.instanceMatrix.needsUpdate = true;
  petalMesh.instanceMatrix.needsUpdate = true;
  centerMesh.instanceMatrix.needsUpdate = true;
  [stemMesh, petalMesh, centerMesh].forEach(m => { m.frustumCulled = false; });

  const group = new _T.Group();
  group.add(stemMesh, petalMesh, centerMesh);
  return group;
}

/* ---- Moss Patches (instanced) ---- */
export function mossPatches(T, seed, params = {}) {
  _T = T;
  const { count = 40 } = params;
  const rnd = rng(seed ^ 0x3E7B);

  const mossGeo = ell(1, 0.04, 1);
  const mossMat = toon({ color: col('#4a7025') });
  const mossMesh = new _T.InstancedMesh(mossGeo, mossMat, count);
  const d = new _T.Object3D();

  for (let i = 0; i < count; i++) {
    const x = (rnd() - 0.5) * 8;
    const z = (rnd() - 0.5) * 6;
    const sc = 0.15 + rnd() * 0.35;
    d.position.set(x, 0.02, z);
    d.scale.set(sc * (0.8 + rnd() * 0.6), 0.5 + rnd() * 0.5, sc * (0.8 + rnd() * 0.6));
    d.rotation.set(0, rnd() * Math.PI * 2, 0);
    d.updateMatrix();
    mossMesh.setMatrixAt(i, d.matrix);
  }
  mossMesh.instanceMatrix.needsUpdate = true;
  mossMesh.frustumCulled = false;
  return mossMesh;
}

/* ---- Fern Patches (instanced) ---- */
export function fernPatches(T, seed, params = {}) {
  _T = T;
  const { count = 25 } = params;
  const rnd = rng(seed ^ 0x5D2C);

  function makeFernGeometry() {
    const pos = [], idx = [];
    const leaflets = 4;
    const stemH = 0.15;
    for (let i = 0; i < leaflets; i++) {
      const t = (i + 1) / (leaflets + 1);
      const y = t * stemH;
      const lLen = (1 - t * 0.5) * 0.12;
      for (const side of [-1, 1]) {
        const base = pos.length / 3;
        pos.push(side * 0.005, y, 0, side * lLen * 0.5, y + 0.01, 0.01, side * lLen * 0.3, y - 0.01, 0.005);
        idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
      }
    }
    const geo = new _T.BufferGeometry();
    geo.setAttribute('position', new _T.Float32BufferAttribute(pos, 3));
    geo.setIndex(idx);
    geo.computeVertexNormals();
    return geo;
  }

  const fernGeo = makeFernGeometry();
  const fernMat = toon({ color: col('#2a6a18') });
  const fernMesh = new _T.InstancedMesh(fernGeo, fernMat, count);
  const d = new _T.Object3D();

  for (let i = 0; i < count; i++) {
    const x = (rnd() - 0.5) * 8;
    const z = (rnd() - 0.5) * 6;
    const sc = 0.8 + rnd() * 1.0;
    d.position.set(x, 0.02, z);
    d.scale.setScalar(sc);
    d.rotation.set(0, rnd() * Math.PI * 2, (rnd() - 0.5) * 0.3);
    d.updateMatrix();
    fernMesh.setMatrixAt(i, d.matrix);
  }
  fernMesh.instanceMatrix.needsUpdate = true;
  fernMesh.frustumCulled = false;
  return fernMesh;
}

/* ---- Clover Patches (instanced) ---- */
export function cloverPatches(T, seed, params = {}) {
  _T = T;
  const { count = 35 } = params;
  const rnd = rng(seed ^ 0x7F4E);

  function makeCloverGeometry() {
    const pos = [], idx = [];
    for (let l = 0; l < 3; l++) {
      const a = (l / 3) * Math.PI * 2 - Math.PI / 2;
      const cx = Math.cos(a) * 0.015, cz = Math.sin(a) * 0.015;
      const lw = 0.018, lh = 0.025;
      const base = pos.length / 3;
      pos.push(cx, 0.005, cz, cx + Math.sin(a) * lw, 0.015, cz + Math.cos(a) * lw, cx, 0.005 + lh, cz, cx - Math.sin(a) * lw, 0.015, cz - Math.cos(a) * lw);
      idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
    }
    const geo = new _T.BufferGeometry();
    geo.setAttribute('position', new _T.Float32BufferAttribute(pos, 3));
    geo.setIndex(idx);
    geo.computeVertexNormals();
    return geo;
  }

  const cloverGeo = makeCloverGeometry();
  const cloverMat = toon({ color: col('#3a8020') });
  const cloverMesh = new _T.InstancedMesh(cloverGeo, cloverMat, count);
  const d = new _T.Object3D();

  for (let i = 0; i < count; i++) {
    const x = (rnd() - 0.5) * 8;
    const z = (rnd() - 0.5) * 6;
    const sc = 0.7 + rnd() * 0.8;
    d.position.set(x, 0.005, z);
    d.scale.setScalar(sc);
    d.rotation.set(0, rnd() * Math.PI * 2, 0);
    d.updateMatrix();
    cloverMesh.setMatrixAt(i, d.matrix);
  }
  cloverMesh.instanceMatrix.needsUpdate = true;
  cloverMesh.frustumCulled = false;
  return cloverMesh;
}

/* ---- Label sprite helper ---- */
export function makeLabel(T, text, x, y, z) {
  const canvas = document.createElement('canvas');
  canvas.width = 128; canvas.height = 32;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.font = '14px system-ui, sans-serif';
  ctx.fillText(text, 4, 22);
  const tex = new T.CanvasTexture(canvas);
  const mat = new T.SpriteMaterial({ map: tex, transparent: true, depthTest: false });
  const sprite = new T.Sprite(mat);
  sprite.position.set(x, y, z);
  sprite.scale.set(1.2, 0.3, 1);
  return sprite;
}

/* ---- Builder: creates all food props in one group ---- */
export function foodScene(T, seed, params = {}) {
  _T = T;
  const group = new _T.Group();

  // Food plants
  group.add(
    (() => { const p = berryBush(T, seed + 1, { size: 0.8, full: true }); p.position.set(-2, 0, -1.5); return p; })()
  );
  group.add(
    (() => { const p = berryBush(T, seed + 2, { size: 0.6, full: false }); p.position.set(2, 0, -1); return p; })()
  );
  group.add(
    (() => { const p = tuberLeaves(T, seed + 3, { size: 0.7, full: true }); p.position.set(-1, 0, 1.5); return p; })()
  );
  group.add(
    (() => { const p = fruitingStalk(T, seed + 4, { height: 1.2, full: true }); p.position.set(1.5, 0, 1); return p; })()
  );

  // Ground cover
  group.add(
    (() => { const p = flowerPatches(T, seed + 10, { count: 20, flowerType: 0 }); p.position.set(-3, 0, -2); return p; })()
  );
  group.add(
    (() => { const p = flowerPatches(T, seed + 11, { count: 20, flowerType: 1 }); p.position.set(3, 0, -2); return p; })()
  );
  group.add(
    (() => { const p = flowerPatches(T, seed + 12, { count: 20, flowerType: 2 }); p.position.set(0, 0, 2.5); return p; })()
  );
  group.add(
    (() => { const p = flowerPatches(T, seed + 13, { count: 20, flowerType: 3 }); p.position.set(-2.5, 0, 2); return p; })()
  );
  group.add(
    (() => { const p = mossPatches(T, seed + 20, { count: 30 }); p.position.set(-3, 0, 0); return p; })()
  );
  group.add(
    (() => { const p = fernPatches(T, seed + 30, { count: 20 }); p.position.set(3, 0, 1); return p; })()
  );
  group.add(
    (() => { const p = cloverPatches(T, seed + 40, { count: 30 }); p.position.set(0, 0, -3); return p; })()
  );

  return group;
}