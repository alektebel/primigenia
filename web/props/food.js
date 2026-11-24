/* Food plants and meadow ground cover (G66).
 * Self-contained ES module: three r128. Each builder takes (THREE, seed, params)
 * and returns a THREE.Group or THREE.InstancedMesh. Fully deterministic from seed.
 *
 * Style: MeshStandardMaterial with colors matching palette C (G63),
 * roughness ~0.8, no metalness. Toon-style look achieved through lighting.
 *
 * Food plants (P4 herbivore food store):
 *   - berryBush(THREE, seed, {size, full}): round shrub with berry clusters
 *   - tuberLeaves(THREE, seed, {size, full}): broad low-lying leaf cluster
 *   - fruitingStalk(THREE, seed, {height, full}): tall thin stalk with fruit at top
 *
 * Ground cover (instanced, low draw calls):
 *   - flowerPatches(THREE, seed, {count, flowerType, full}): 4 flower types
 *   - mossPatches(THREE, seed, {count}): low irregular patches
 *   - fernPatches(THREE, seed, {count}): frond shapes
 *   - cloverPatches(THREE, seed, {count}): 3-leaf clusters
 */

/* ---- Helpers ---- */
function rng(seed) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function toon(hex, roughness) {
  const THREE = arguments[arguments.length - 1] instanceof (function(){}) ? arguments[arguments.length-1] : globalThis.THREE;
  // Actually we use the first parameter (THREE instance) which is passed by the caller
  return new THREE.MeshStandardMaterial({
    color: new THREE.Color(hex),
    roughness: roughness || 0.8,
    metalness: 0
  });
}

function ell(sx, sy, sz, THREE) {
  const g = new THREE.SphereGeometry(1, 12, 8);
  g.scale(sx, sy, sz);
  return g;
}

/* ---- Berry Bush ---- */
export function berryBush(THREE, seed, params) {
  const { size = 1, full = true } = params || {};
  const rnd = rng(seed ^ 0x4B7F);
  const s = size;
  const group = new THREE.Group();
  const woodM = toon('#4a2a15', 0.85, THREE);
  const leafM = toon('#2a6a1a', 0.8, THREE);

  // Trunk
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.08*s, 0.12*s, 0.6*s, 8), woodM);
  group.add(trunk);
  trunk.position.set(0, 0.3*s, 0);

  // Branches
  const bc = 3 + Math.round(rnd() * 2);
  for (let i = 0; i < bc; i++) {
    const a = (i / bc) * Math.PI * 2 + rnd() * 0.5;
    const len = (0.3 + rnd() * 0.25) * s;
    const branch = new THREE.Mesh(new THREE.CylinderGeometry(0.03*s, 0.05*s, len, 6), woodM);
    branch.position.set(Math.cos(a) * 0.15*s, (0.4 + 0.15 + rnd() * 0.15) * s, Math.sin(a) * 0.15*s);
    branch.rotation.z = Math.sin(a) * 0.6;
    branch.rotation.x = Math.cos(a) * 0.6;
    group.add(branch);
  }

  // Leaf clusters
  const cc = full ? 6 : 3;
  for (let i = 0; i < cc; i++) {
    const a = (i / cc) * Math.PI * 2 + rnd() * 0.8;
    const cx = Math.cos(a) * (0.35 + rnd() * 0.15) * s;
    const cy = (0.55 + rnd() * 0.15) * s;
    const cz = Math.sin(a) * (0.35 + rnd() * 0.15) * s;
    const sc = (0.15 + rnd() * 0.1) * s;
    const cluster = new THREE.Mesh(ell(sc*1.2, sc*0.7, sc*1.2, THREE), leafM);
    cluster.position.set(cx, cy, cz);
    group.add(cluster);
  }

  // Berries
  if (full) {
    const berryCount = 18 + Math.round(rnd() * 8);
    const berryGeo = ell(0.02*s, 0.02*s, 0.02*s, THREE);
    const berryMat = toon('#6a1535', 0.65, THREE);
    const berryMesh = new THREE.InstancedMesh(berryGeo, berryMat, berryCount);
    const d = new THREE.Object3D();
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

  // Stubs (depleted)
  if (!full) {
    const stubCount = 5 + Math.round(rnd() * 3);
    const stubMesh = new THREE.InstancedMesh(ell(0.01*s, 0.01*s, 0.01*s, THREE), toon('#3a4a25', 0.85, THREE), stubCount);
    const d = new THREE.Object3D();
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

/* ---- Tuber Leaves ---- */
export function tuberLeaves(THREE, seed, params) {
  const { size = 1, full = true } = params || {};
  const rnd = rng(seed ^ 0xA3D1);
  const s = size;
  const group = new THREE.Group();
  const leafM = full ? toon('#3a8a2a', 0.75, THREE) : toon('#5a6a30', 0.85, THREE);
  const midribM = toon('#1a5a15', 0.75, THREE);

  const lc = full ? 7 : 4;
  for (let i = 0; i < lc; i++) {
    const a = (i / lc) * Math.PI * 2 + rnd() * 0.4;
    const len = (0.25 + rnd() * 0.1) * s;
    const width = (0.1 + rnd() * 0.06) * s;
    const posArr = [], norArr = [], uvArr = [], idxArr = [];
    const segs = 6;
    for (let j = 0; j <= segs; j++) {
      const t = j / segs, lw = width * (1 - Math.pow(t, 0.7)), ex = t * len;
      posArr.push(-lw, 0, ex, lw, 0, ex);
      norArr.push(0, 1, 0, 0, 1, 0);
      uvArr.push(0, t, 1, t);
      if (j < segs) { const b = j * 2; idxArr.push(b, b+2, b+1, b+1, b+2, b+3); }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(posArr, 3));
    geo.setAttribute('normal', new THREE.Float32BufferAttribute(norArr, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uvArr, 2));
    geo.setIndex(idxArr);
    geo.computeVertexNormals();
    const leaf = new THREE.Mesh(geo, leafM);
    leaf.position.set(Math.cos(a) * len * 0.2, (0.04 + rnd() * 0.03) * s, Math.sin(a) * len * 0.2);
    leaf.rotation.y = a + Math.PI / 2;
    leaf.rotation.z = -0.25 - rnd() * 0.2;
    group.add(leaf);
    const midrib = new THREE.Mesh(new THREE.CylinderGeometry(0.003*s, 0.005*s, len * 0.85, 4), midribM);
    midrib.position.copy(leaf.position);
    midrib.position.y += 0.002 * s;
    group.add(midrib);
  }

  // Grass tufts
  for (let i = 0; i < 6; i++) {
    const a = rnd() * Math.PI * 2, r = 0.15 + rnd() * 0.15, h = (0.06 + rnd() * 0.06) * s;
    const tuft = new THREE.Mesh(new THREE.ConeGeometry(0.015*s, h, 5), toon('#3a7020', 0.8, THREE));
    tuft.position.set(Math.cos(a) * r * s, h * 0.4, Math.sin(a) * r * s);
    tuft.rotation.x = (rnd()-0.5)*0.3;
    tuft.rotation.z = (rnd()-0.5)*0.3;
    group.add(tuft);
  }

  return group;
}

/* ---- Fruiting Stalk ---- */
export function fruitingStalk(THREE, seed, params) {
  const { height = 1.5, full = true } = params || {};
  const rnd = rng(seed ^ 0xC7E2);
  const s = 1, stalkH = (height || 1.5) * s;
  const group = new THREE.Group();
  const stalkM = full ? toon('#3a7020', 0.75, THREE) : toon('#6a7a30', 0.85, THREE);

  const stalk = new THREE.Mesh(new THREE.CylinderGeometry(0.02*s, 0.035*s, stalkH, 8), stalkM);
  stalk.position.y = stalkH / 2;
  group.add(stalk);

  // Ridge details
  const rc = 8 + Math.round(rnd() * 4);
  for (let i = 0; i < rc; i++) {
    const t = 0.15 + (i / rc) * 0.8;
    const ridge = new THREE.Mesh(ell(0.045*s, 0.008*s, 0.045*s, THREE), stalkM);
    ridge.position.y = t * stalkH;
    ridge.rotation.x = Math.PI / 2;
    group.add(ridge);
  }

  // Leaf blades
  const lcc = 4 + Math.round(rnd() * 3);
  for (let i = 0; i < lcc; i++) {
    const t = 0.3 + (i / lcc) * 0.55, a = rnd() * Math.PI * 2, lLen = (0.12 + rnd() * 0.08) * s;
    const leaf = new THREE.Mesh(new THREE.BoxGeometry(0.02*s, 0.005*s, lLen), toon('#2a6018', 0.75, THREE));
    leaf.position.set(Math.cos(a)*0.03*s, t*stalkH, Math.sin(a)*0.03*s);
    leaf.rotation.y = a;
    leaf.rotation.z = 0.4;
    group.add(leaf);
  }

  // Fruit cluster at top
  if (full) {
    const fruitCount = 8 + Math.round(rnd() * 5);
    const fruitMat = toon('#c06020', 0.65, THREE);
    const fruitMesh = new THREE.InstancedMesh(ell(0.035*s, 0.03*s, 0.035*s, THREE), fruitMat, fruitCount);
    const d = new THREE.Object3D();
    let fi = 0;
    for (let i = 0; i < 3 && fi < fruitCount; i++) {
      const a = (i/3) * Math.PI * 2 + rnd() * 0.5;
      for (let j = 0; j < 3 && fi < fruitCount; j++) {
        const fa = a + (j-1) * 0.5, fr = 0.04 + rnd() * 0.03;
        d.position.set(Math.cos(fa)*fr*s, (0.85+rnd()*0.1)*stalkH, Math.sin(fa)*fr*s);
        d.scale.setScalar(0.7+rnd()*0.5);
        d.updateMatrix();
        fruitMesh.setMatrixAt(fi++, d.matrix);
      }
    }
    fruitMesh.instanceMatrix.needsUpdate = true;
    fruitMesh.frustumCulled = false;
    group.add(fruitMesh);
    const tip = new THREE.Mesh(new THREE.ConeGeometry(0.015*s, 0.08*s, 6), stalkM);
    tip.position.y = stalkH + 0.04*s;
    group.add(tip);
  }

  return group;
}

/* ---- Flower Patches ---- */
export function flowerPatches(THREE, seed, params) {
  const { count = 30, flowerType = 0, full = true } = params || {};
  const rnd = rng(seed ^ 0x1F9A + (flowerType || 0) * 1000);
  count = count || 30;

  const types = [
    { petals: 5, petalColor: '#d02060', centerColor: '#c0a020', stemColor: '#2a6a1a', size: 0.04 },
    { petals: 5, petalColor: '#3050d0', centerColor: '#c0a020', stemColor: '#2a6a1a', size: 0.035 },
    { petals: 6, petalColor: '#d07020', centerColor: '#501515', stemColor: '#2a6a1a', size: 0.05 },
    { petals: 4, petalColor: '#a030c0', centerColor: '#d0d020', stemColor: '#2a6a1a', size: 0.03 },
  ];
  const ft = types[flowerType] || types[0];
  const fullScale = full !== false ? 1 : 0.5;

  const stemGeo = new THREE.CylinderGeometry(0.002, 0.003, 0.08, 4);
  const stemMat = toon(ft.stemColor, undefined, THREE);
  const petalGeo = ell(0.012, 0.001, 0.006, THREE);
  const petalMat = toon(ft.petalColor, undefined, THREE);
  const centerGeo = ell(0.008, 0.003, 0.008, THREE);
  const centerMat = toon(ft.centerColor, undefined, THREE);

  const stemMesh = new THREE.InstancedMesh(stemGeo, stemMat, count);
  const petalMesh = new THREE.InstancedMesh(petalGeo, petalMat, count * ft.petals);
  const centerMesh = new THREE.InstancedMesh(centerGeo, centerMat, count);

  const d = new THREE.Object3D();
  let si = 0, pi = 0, ci = 0;

  for (let i = 0; i < count; i++) {
    const x = (rnd()-0.5) * 8, z = (rnd()-0.5) * 6, h = 0.06 + rnd() * 0.06;
    d.position.set(x, h/2, z);
    d.rotation.set((rnd()-0.5)*0.15, rnd()*Math.PI*2, (rnd()-0.5)*0.15);
    d.updateMatrix();
    stemMesh.setMatrixAt(si++, d.matrix);

    const topY = h + 0.005;
    for (let p = 0; p < ft.petals; p++) {
      const a = (p / ft.petals) * Math.PI * 2, pr = ft.size * 0.6;
      d.position.set(x + Math.cos(a)*pr, topY, z + Math.sin(a)*pr);
      d.scale.setScalar(fullScale);
      d.rotation.set(Math.PI/2, a, 0);
      d.updateMatrix();
      petalMesh.setMatrixAt(pi++, d.matrix);
    }
    d.position.set(x, topY + 0.001, z);
    d.scale.setScalar(fullScale);
    d.updateMatrix();
    centerMesh.setMatrixAt(ci++, d.matrix);
  }

  stemMesh.instanceMatrix.needsUpdate = true;
  petalMesh.instanceMatrix.needsUpdate = true;
  centerMesh.instanceMatrix.needsUpdate = true;
  [stemMesh, petalMesh, centerMesh].forEach(m => m.frustumCulled = false);

  const group = new THREE.Group();
  group.add(stemMesh, petalMesh, centerMesh);
  return group;
}

/* ---- Moss Patches ---- */
export function mossPatches(THREE, seed, params) {
  const { count = 40 } = params || {};
  const rnd = rng(seed ^ 0x3E7B);
  count = count || 40;

  const mossGeo = ell(1, 0.04, 1, THREE);
  const mossMat = toon('#2a5a15', 0.85, THREE);
  const mossMesh = new THREE.InstancedMesh(mossGeo, mossMat, count);
  const d = new THREE.Object3D();
  for (let i = 0; i < count; i++) {
    const x = (rnd()-0.5) * 8, z = (rnd()-0.5) * 6, sc = 0.15 + rnd() * 0.35;
    d.position.set(x, 0.02, z);
    d.scale.set(sc*(0.8+rnd()*0.6), 0.5+rnd()*0.5, sc*(0.8+rnd()*0.6));
    d.rotation.set(0, rnd()*Math.PI*2, 0);
    d.updateMatrix();
    mossMesh.setMatrixAt(i, d.matrix);
  }
  mossMesh.instanceMatrix.needsUpdate = true;
  mossMesh.frustumCulled = false;
  return mossMesh;
}

/* ---- Fern Patches ---- */
export function fernPatches(THREE, seed, params) {
  const { count = 25 } = params || {};
  const rnd = rng(seed ^ 0x5D2C);
  count = count || 25;

  function makeFernGeo() {
    const posArr = [], idxArr = [];
    const leaflets = 4, stemH = 0.15;
    for (let i = 0; i < leaflets; i++) {
      const t = (i+1)/(leaflets+1), y = t * stemH, lLen = (1-t*0.5) * 0.12;
      for (const side of [-1, 1]) {
        const base = posArr.length / 3;
        posArr.push(side*0.005, y, 0, side*lLen*0.5, y+0.01, 0.01, side*lLen*0.3, y-0.01, 0.005);
        idxArr.push(base, base+1, base+2, base, base+2, base+3);
      }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(posArr, 3));
    geo.setIndex(idxArr);
    geo.computeVertexNormals();
    return geo;
  }

  const fernGeo = makeFernGeo();
  const fernMat = toon('#1a5a0a', 0.8, THREE);
  const fernMesh = new THREE.InstancedMesh(fernGeo, fernMat, count);
  const d = new THREE.Object3D();
  for (let i = 0; i < count; i++) {
    const x = (rnd()-0.5)*8, z = (rnd()-0.5)*6, sc = 0.8 + rnd()*1.0;
    d.position.set(x, 0.02, z);
    d.scale.setScalar(sc);
    d.rotation.set(0, rnd()*Math.PI*2, (rnd()-0.5)*0.3);
    d.updateMatrix();
    fernMesh.setMatrixAt(i, d.matrix);
  }
  fernMesh.instanceMatrix.needsUpdate = true;
  fernMesh.frustumCulled = false;
  return fernMesh;
}

/* ---- Clover Patches ---- */
export function cloverPatches(THREE, seed, params) {
  const { count = 35 } = params || {};
  const rnd = rng(seed ^ 0x7F4E);
  count = count || 35;

  function makeCloverGeo() {
    const posArr = [], idxArr = [];
    for (let l = 0; l < 3; l++) {
      const a = (l/3)*Math.PI*2 - Math.PI/2;
      const cx = Math.cos(a)*0.015, cz = Math.sin(a)*0.015, lw = 0.018, lh = 0.025;
      const base = posArr.length / 3;
      posArr.push(
        cx, 0.005, cz,
        cx+Math.sin(a)*lw, 0.015, cz+Math.cos(a)*lw,
        cx, 0.005+lh, cz,
        cx-Math.sin(a)*lw, 0.015, cz-Math.cos(a)*lw
      );
      idxArr.push(base, base+1, base+2, base, base+2, base+3);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(posArr, 3));
    geo.setIndex(idxArr);
    geo.computeVertexNormals();
    return geo;
  }

  const cloverGeo = makeCloverGeo();
  const cloverMat = toon('#3a7020', 0.8, THREE);
  const cloverMesh = new THREE.InstancedMesh(cloverGeo, cloverMat, count);
  const d = new THREE.Object3D();
  for (let i = 0; i < count; i++) {
    const x = (rnd()-0.5)*8, z = (rnd()-0.5)*6, sc = 0.7 + rnd()*0.8;
    d.position.set(x, 0.005, z);
    d.scale.setScalar(sc);
    d.rotation.set(0, rnd()*Math.PI*2, 0);
    d.updateMatrix();
    cloverMesh.setMatrixAt(i, d.matrix);
  }
  cloverMesh.instanceMatrix.needsUpdate = true;
  cloverMesh.frustumCulled = false;
  return cloverMesh;
}

/* ---- Builder: all food props ---- */
export function foodScene(THREE, seed, params) {
  const group = new THREE.Group();

  group.add(berryBush(THREE, seed+1, {size: 0.8, full: true}));
  group[group.children.length-1].position.set(-2, 0, -1.5);
  group.add(berryBush(THREE, seed+2, {size: 0.6, full: false}));
  group[group.children.length-1].position.set(2, 0, -1);
  group.add(tuberLeaves(THREE, seed+3, {size: 0.7, full: true}));
  group[group.children.length-1].position.set(-1, 0, 1.5);
  group.add(fruitingStalk(THREE, seed+4, {height: 1.2, full: true}));
  group[group.children.length-1].position.set(1.5, 0, 1);
  group.add(flowers(THREE, seed+10, {count: 20, flowerType: 0}));
  group[group.children.length-1].position.set(-3, 0, -2);
  group.add(flowers(THREE, seed+11, {count: 20, flowerType: 1}));
  group[group.children.length-1].position.set(3, 0, -2);
  group.add(flowers(THREE, seed+12, {count: 20, flowerType: 2}));
  group[group.children.length-1].position.set(0, 0, 2.5);
  group.add(flowers(THREE, seed+13, {count: 20, flowerType: 3}));
  group[group.children.length-1].position.set(-2.5, 0, 2);
  group.add(mossPatches(THREE, seed+20, {count: 30}));
  group[group.children.length-1].position.set(-3, 0, 0);
  group.add(fernPatches(THREE, seed+30, {count: 20}));
  group[group.children.length-1].position.set(3, 0, 1);
  group.add(cloverPatches(THREE, seed+40, {count: 30}));
  group[group.children.length-1].position.set(0, 0, -3);

  return group;
}

/* Alias for backward compat */
export function flowers(THREE, seed, params) {
  return flowerPatches(THREE, seed, params);
}