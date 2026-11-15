/* Carcasses and surface fossils (G3, G4).
 * Procedural JS in the style of rig.js / build_hero.py.
 * Three.js r128. ES module. Deterministic from seed.
 *
 * Style rules (DESIGN.md G63, G65–G66):
 * - World props (fossils, bones in ground) use the 3-band toon ramp
 *   [46,46,82,82,112,112] and Palette C colours.
 * - Creature-like parts (flesh on carcasses) use physical materials
 *   with the creature's palette (matching rig.js skinM / boneM style).
 * - Fossils are half-buried, biome-tinted, readable at 5 m and 30 m.
 * - Carcasses keep the creature's colour identity (cA/cB/cC).
 *
 * API — all builder functions take (T, seed, params) and return THREE.Object3D.
 */

/* ---------- helpers (internal) ---------- */

function rngFrom(seed) {
  var s = seed | 0;
  return function () {
    s = (s * 1664525 + 1013904223) | 0;
    return (s >>> 0) / 4294967296;
  };
}

function lerp(a, b, t) { return a + (b - a) * t; }
function clamp(x, a, b) { return Math.min(b, Math.max(a, x)); }

/* Shared toon material factory — matches valle-primigenio.html toon()
   using G63 palette C ramp [46,46,82,82,112,112]. */
var _gradTex = null;

function toonMat(opts, T) {
  opts = opts || {};
  try {
    _gradTex = _gradTex || function () {
      var t = new T.DataTexture(
        new Uint8Array([46, 46, 82, 82, 112, 112]), 6, 1, T.LuminanceFormat);
      t.minFilter = t.magFilter = T.NearestFilter;
      t.needsUpdate = true;
      return t;
    }();
  } catch (e) { /* DataTexture not available; plain color used */ }

  var m = new T.MeshStandardMaterial({
    color: opts.color || 0xffffff,
    roughness: opts.roughness !== undefined ? opts.roughness : 0.7,
    metalness: opts.metalness !== undefined ? opts.metalness : 0,
  });
  if (_gradTex) {
    m = new T.MeshToonMaterial({ color: opts.color || 0xffffff });
    m.gradientMap = _gradTex;
  }
  m.customProgramCacheKey = function () { return 'remains'; };
  return m;
}

/* Build a generic creature silhouette body (slumped on ground).
   Returns a Group with named children: body, neck, head, snout, tail, legs[]. */
function buildSilhouette(T, seed, params) {
  var g = new T.Group();
  var bodyLen = params.bodyLen || 2.2;
  var bodyRad = params.bodyRad || 0.55;

  /* Body: elongated ellipsoid on the ground */
  var bodyGeo = new T.SphereGeometry(1, 12, 10);
  bodyGeo.scale(bodyLen, bodyRad, bodyRad * 1.3);
  var body = new T.Mesh(bodyGeo);
  body.position.set(0, bodyRad * 0.6, 0);
  body.name = 'body';
  g.add(body);

  /* Neck: tube arching forward */
  var neckPts = [];
  for (var i = 0; i <= 6; i++) {
    var t = i / 6;
    neckPts.push(new T.Vector3(
      bodyLen * 0.35 + t * bodyLen * 0.25,
      bodyRad * 0.6 + t * 1.2,
      Math.sin(t * 0.8) * 0.15
    ));
  }
  var neckCurve = new T.CatmullRomCurve3(neckPts);
  var neckGeo = new T.TubeGeometry(neckCurve, 8, bodyRad * 0.45, 8, false);
  var neck = new T.Mesh(neckGeo);
  neck.name = 'neck';
  g.add(neck);

  /* Head */
  var headEnd = neckPts[6];
  var headGeo = new T.SphereGeometry(1, 10, 8);
  headGeo.scale(0.45, 0.35, 0.4);
  var head = new T.Mesh(headGeo);
  head.position.set(headEnd.x, headEnd.y, headEnd.z);
  head.name = 'head';
  g.add(head);

  /* Snout */
  var snoutGeo = new T.ConeGeometry(0.12, 0.3, 8);
  snoutGeo.rotateZ(-Math.PI / 2);
  var snout = new T.Mesh(snoutGeo);
  snout.position.set(headEnd.x + 0.35, headEnd.y - 0.05, headEnd.z);
  snout.name = 'snout';
  g.add(snout);

  /* Tail: tapering curve behind */
  var tailPts = [];
  for (var i2 = 0; i2 <= 8; i2++) {
    var t2 = i2 / 8;
    tailPts.push(new T.Vector3(
      -bodyLen * 0.35 - t2 * bodyLen * 0.4,
      bodyRad * 0.6 - t2 * 0.3,
      Math.sin(t2 * 1.2) * 0.1
    ));
  }
  var tailCurve = new T.CatmullRomCurve3(tailPts);
  var tailGeo = new T.TubeGeometry(tailCurve, 8, bodyRad * 0.3, 8, false);
  var tail = new T.Mesh(tailGeo);
  tail.name = 'tail';
  g.add(tail);

  /* Four legs (splayed outward) */
  var legs = [];
  var legDefs = [
    { x: bodyLen * 0.25,  z: bodyRad * 1.0 },
    { x: bodyLen * 0.25,  z: -bodyRad * 1.0 },
    { x: -bodyLen * 0.25, z: bodyRad * 1.0 },
    { x: -bodyLen * 0.25, z: -bodyRad * 1.0 },
  ];
  for (var li = 0; li < legDefs.length; li++) {
    var legGeo = new T.CylinderGeometry(0.08, 0.06, bodyRad * 2.2, 6);
    var leg = new T.Mesh(legGeo);
    leg.position.set(legDefs[li].x, -bodyRad * 0.5, legDefs[li].z);
    leg.name = 'leg';
    legs.push(leg);
    g.add(leg);
  }

  /* Eye */
  var eyeGeo = new T.SphereGeometry(0.06, 8, 6);
  var eye = new T.Mesh(eyeGeo);
  eye.position.set(headEnd.x + 0.1, headEnd.y + 0.15, 0.2);
  eye.name = 'eye';
  g.add(eye);

  return g;
}


/* ===================== CARCASSES ===================== */

/* Create a carcass material from a hex color string.
   MeshLambertMaterial works well with SwiftShader and responds to lights. */
function carcassMaterial(T, hex, opts) {
  opts = opts || {};
  var m = new T.MeshLambertMaterial({
    color: new T.Color(hex),
  });
  m.customProgramCacheKey = function () { return 'carcass'; };
  return m;
}

/**
 * Build a fresh carcass: dead creature with skin intact.
 * The body is slumped on the ground, colour matches the creature palette.
 */
export function buildFreshCarcass(T, seed, params) {
  params = params || {};
  var skinMatA = carcassMaterial(T, params.cA || '#884433', { roughness: 0.65, clearcoat: 0.15, clearcoatRoughness: 0.5 });
  var skinMatB = carcassMaterial(T, params.cB || '#221111', { roughness: 0.7, clearcoat: 0.1, clearcoatRoughness: 0.6 });
  var skinMatC = carcassMaterial(T, params.cC || '#ccaa88', { roughness: 0.6, clearcoat: 0.05, clearcoatRoughness: 0.7 });
  var eyeMat = carcassMaterial(T, '#1a1210', { roughness: 0.3 });

  var sil = buildSilhouette(T, seed, params);

  sil.traverse(function (child) {
    if (!child.isMesh || !child.geometry) return;
    var n = child.name;
    if (n === 'head' || n === 'snout' || n === 'neck') {
      child.material = skinMatC;
    } else if (n === 'eye') {
      child.material = eyeMat;
    } else if (n === 'leg') {
      child.material = skinMatB;
    } else {
      child.material = skinMatA;
    }
  });

  sil.position.y = -0.15;

  var result = new T.Group();
  result.name = 'freshCarcass';
  result.add(sil);
  return result;
}

/**
 * Build a picked-over carcass: skeleton with exposed ribs, spine, leg bones.
 * Flesh mostly gone — a few tattered strips remain.
 */
export function buildPickedCarcass(T, seed, params) {
  params = params || {};
  var bodyLen = params.bodyLen || 2.2;
  var bodyRad = params.bodyRad || 0.55;

  var g = new T.Group();
  g.name = 'pickedCarcass';

  var boneMat = carcassMaterial(T, '#bfae8a', { roughness: 0.5 });
  var meatMat = carcassMaterial(T, '#6b3a2a', { roughness: 0.8 });

  /* --- spine: curved tube along body axis --- */
  var spinePts = [];
  for (var i = 0; i <= 14; i++) {
    var t = i / 14;
    spinePts.push(new T.Vector3(
      bodyLen * 0.45 - t * bodyLen * 0.9,
      bodyRad * 0.35 - t * 0.1,
      Math.sin(t * Math.PI * 1.5) * 0.06
    ));
  }
  var spineCurve = new T.CatmullRomCurve3(spinePts);
  var spineGeo = new T.TubeGeometry(spineCurve, 12, bodyRad * 0.1, 8, false);
  var spine = new T.Mesh(spineGeo, boneMat);
  g.add(spine);

  /* --- ribs: paired arcs from spine to sides --- */
  var ribCount = 8;
  for (var ri = 0; ri < ribCount; ri++) {
    var rt = (ri + 1) / (ribCount + 1);
    var spinePos = spineCurve.getPoint(rt);
    var ribW = bodyRad * (0.8 + 0.2 * Math.sin(rt * Math.PI));

    /* Right rib */
    var rPts = [];
    for (var rj = 0; rj <= 6; rj++) {
      var ru = rj / 6;
      var rA = ru * Math.PI;
      var rR = ribW * Math.sin(ru * Math.PI);
      rPts.push(new T.Vector3(
        spinePos.x, spinePos.y - rR * 0.5,
        spinePos.z + Math.cos(rA) * ribW * 0.5
      ));
    }
    var rGeo = new T.TubeGeometry(
      new T.CatmullRomCurve3(rPts), 6, 0.025, 6, false);
    var ribR = new T.Mesh(rGeo, boneMat);
    g.add(ribR);

    /* Left rib */
    var lPts = [];
    for (var rj2 = 0; rj2 <= 6; rj2++) {
      var ru2 = rj2 / 6;
      var rA2 = ru2 * Math.PI;
      var rR2 = ribW * Math.sin(ru2 * Math.PI);
      lPts.push(new T.Vector3(
        spinePos.x, spinePos.y - rR2 * 0.5,
        spinePos.z - Math.cos(rA2) * ribW * 0.5
      ));
    }
    var lGeo = new T.TubeGeometry(
      new T.CatmullRomCurve3(lPts), 6, 0.025, 6, false);
    var ribL = new T.Mesh(lGeo, boneMat);
    g.add(ribL);
  }

  /* --- skull: boxy shape --- */
  var skullGeo = new T.BoxGeometry(0.5, 0.35, 0.4, 2, 2, 2);
  var skull = new T.Mesh(skullGeo, boneMat);
  skull.position.set(bodyLen * 0.45, bodyRad * 0.35 + 0.25, 0);
  g.add(skull);

  /* Jaw */
  var jawGeo = new T.BoxGeometry(0.35, 0.12, 0.3, 2, 1, 2);
  var jaw = new T.Mesh(jawGeo, boneMat);
  jaw.position.set(bodyLen * 0.45 + 0.2, bodyRad * 0.35 + 0.08, 0);
  g.add(jaw);

  /* Teeth (small cones along the jaw edge) */
  var toothMat = carcassMaterial(T, '#f7f1df', { roughness: 0.28 });
  for (var ti = -2; ti <= 2; ti++) {
    var toothGeo = new T.ConeGeometry(0.02, 0.08, 6);
    var tooth = new T.Mesh(toothGeo, toothMat);
    tooth.position.set(bodyLen * 0.45 + 0.2 + ti * 0.06,
                       bodyRad * 0.35 + 0.18, ti * 0.06);
    g.add(tooth);
  }

  /* --- leg bones (femur + tibia) --- */
  var legDefs = [
    { x: bodyLen * 0.25,  z: bodyRad * 1.0 },
    { x: bodyLen * 0.25,  z: -bodyRad * 1.0 },
    { x: -bodyLen * 0.25, z: bodyRad * 1.0 },
    { x: -bodyLen * 0.25, z: -bodyRad * 1.0 },
  ];
  for (var li = 0; li < legDefs.length; li++) {
    var femurGeo = new T.CylinderGeometry(0.04, 0.035, bodyRad * 1.2, 6);
    var femur = new T.Mesh(femurGeo, boneMat);
    femur.position.set(legDefs[li].x, -bodyRad * 0.3, legDefs[li].z);
    g.add(femur);

    var tibiaGeo = new T.CylinderGeometry(0.03, 0.025, bodyRad * 1.4, 6);
    var tibia = new T.Mesh(tibiaGeo, boneMat);
    tibia.position.set(legDefs[li].x + 0.08, -bodyRad * 1.0, legDefs[li].z);
    g.add(tibia);
  }

  /* --- tattered skin remnants (a few strips on the belly) --- */
  for (var si = 0; si < 3; si++) {
    var stripGeo = new T.PlaneGeometry(0.15, 0.6, 3, 6);
    var strip = new T.Mesh(stripGeo, meatMat);
    strip.position.set(bodyLen * 0.1 + si * 0.4, 0.01, 0);
    strip.rotation.x = Math.PI / 2;
    strip.rotation.z = (Math.random() - 0.5) * 0.3;
    g.add(strip);
  }

  g.position.y = -0.08;
  return g;
}


/* ===================== FOSSILS ===================== */

function boneColorForBiome(biome) {
  switch (biome) {
    case 'meadow': return '#a8b088';
    case 'alpine': return '#8a90a0';
    case 'beach':  return '#c4b48a';
    default:       return '#bfae8a';
  }
}

function rockColorForBiome(biome) {
  switch (biome) {
    case 'meadow': return '#6a7054';
    case 'alpine': return '#686870';
    case 'beach':  return '#a09070';
    default:       return '#6a6868';
  }
}

/** Build a low-poly rock geometry (randomised icosahedron). */
function buildRock(T, size, seed, biome) {
  var r = rngFrom(seed);
  /* Use an icosahedron with random vertex perturbation for organic shape */
  var geo = new T.IcosahedronGeometry(size * 0.5, 1);
  var pos = geo.attributes.position.array;
  for (var i = 0; i < pos.length; i += 3) {
    var variation = r() * 0.25;
    pos[i]     += (r() - 0.5) * variation * size;
    pos[i + 1] += (r() - 0.5) * variation * size * 0.35;  // flatten vertically
    pos[i + 2] += (r() - 0.5) * variation * size;
  }
  geo.computeVertexNormals();

  var mat = toonMat({ color: new T.Color(rockColorForBiome(biome)) }, T);
  return { geo: geo, mat: mat };
}

/**
 * Build a fossil skull half-buried in rock.
 */
export function buildSkullFossil(T, seed, params) {
  params = params || {};
  var biome = params.biome || 'meadow';
  var boneCol = boneColorForBiome(biome);

  var g = new T.Group();
  g.name = 'skullFossil_' + biome;

  /* Rock base (half-buried) */
  var rock = buildRock(T, 1.0, seed, biome);
  var rockMesh = new T.Mesh(rock.geo, rock.mat);
  rockMesh.position.y = -0.2;
  g.add(rockMesh);

  /* Skull dome */
  var skullGeo = new T.SphereGeometry(0.35, 10, 8);
  skullGeo.scale(1, 0.85, 0.9);
  var skullMat = toonMat({ color: new T.Color(boneCol) }, T);
  var skull = new T.Mesh(skullGeo, skullMat);
  skull.position.set(0, 0.15, 0.15);
  g.add(skull);

  /* Snout */
  var jawGeo = new T.SphereGeometry(0.2, 8, 6);
  jawGeo.scale(1, 0.6, 0.7);
  var jaw = new T.Mesh(jawGeo, skullMat);
  jaw.position.set(0.15, -0.05, 0.28);
  g.add(jaw);

  /* Eye sockets (dark) */
  var socketGeo = new T.SphereGeometry(0.08, 8, 6);
  var socketMat = toonMat({ color: new T.Color('#1a1815') }, T);
  var lSoc = new T.Mesh(socketGeo, socketMat);
  lSoc.position.set(0.08, 0.22, 0.42);
  g.add(lSoc);
  var rSoc = new T.Mesh(socketGeo, socketMat);
  rSoc.position.set(-0.08, 0.22, 0.42);
  g.add(rSoc);

  /* Teeth along jaw */
  for (var ti = -2; ti <= 1; ti++) {
    var toothGeo = new T.ConeGeometry(0.025, 0.1, 5);
    var tooth = new T.Mesh(toothGeo, skullMat);
    tooth.position.set(0.15 + ti * 0.055, -0.12, 0.3);
    tooth.rotation.z = Math.PI;
    g.add(tooth);
  }

  /* Tilt skull into rock */
  skull.rotation.x = -0.3;
  jaw.rotation.x = -0.15;

  g.position.y = -0.15;
  return g;
}

/**
 * Build a fossil ribcage half-buried in rock.
 */
export function buildRibcageFossil(T, seed, params) {
  params = params || {};
  var biome = params.biome || 'meadow';
  var boneCol = boneColorForBiome(biome);

  var g = new T.Group();
  g.name = 'ribcageFossil_' + biome;

  /* Rock base */
  var rock = buildRock(T, 0.8, seed, biome);
  var rockMesh = new T.Mesh(rock.geo, rock.mat);
  rockMesh.position.y = -0.25;
  g.add(rockMesh);

  /* Central spine fragment */
  var spineGeo = new T.CylinderGeometry(0.04, 0.035, 0.7, 6);
  var spineMat = toonMat({ color: new T.Color(boneCol) }, T);
  var spine = new T.Mesh(spineGeo, spineMat);
  spine.position.set(0, 0.05, 0);
  spine.rotation.z = Math.PI / 2;
  g.add(spine);

  /* Rib pairs: 6 pairs curving from spine to sides */
  var ribCount = 6;
  for (var ri = 0; ri < ribCount; ri++) {
    var t = ri / (ribCount - 1);
    var x = -0.25 + t * 0.5;
    var ribW = 0.25 * Math.sin(t * Math.PI);

    /* Right rib */
    var rGeo = new T.TubeGeometry(
      new T.CatmullRomCurve3([
        new T.Vector3(x, 0.05, 0),
        new T.Vector3(x, -0.05, ribW * 0.5),
        new T.Vector3(x, -0.15, ribW),
      ]), 6, 0.02, 6, false
    );
    var ribR = new T.Mesh(rGeo, spineMat);
    g.add(ribR);

    /* Left rib */
    var lGeo = new T.TubeGeometry(
      new T.CatmullRomCurve3([
        new T.Vector3(x, 0.05, 0),
        new T.Vector3(x, -0.05, -ribW * 0.5),
        new T.Vector3(x, -0.15, -ribW),
      ]), 6, 0.02, 6, false
    );
    var ribL = new T.Mesh(lGeo, spineMat);
    g.add(ribL);
  }

  /* Vertebral nodes (small spheres along spine) */
  for (var vi = 0; vi < ribCount; vi++) {
    var vt = vi / (ribCount - 1);
    var vx = -0.25 + vt * 0.5;
    var vertGeo = new T.SphereGeometry(0.04, 6, 4);
    vertGeo.scale(1, 0.7, 1);
    var vert = new T.Mesh(vertGeo, spineMat);
    vert.position.set(vx, 0.05, 0);
    g.add(vert);
  }

  g.position.y = -0.12;
  return g;
}

/**
 * Build a fossil spine half-buried in rock.
 * A curved row of vertebrae emerging from the rock at an angle.
 */
export function buildSpineFossil(T, seed, params) {
  params = params || {};
  var biome = params.biome || 'meadow';
  var boneCol = boneColorForBiome(biome);

  var g = new T.Group();
  g.name = 'spineFossil_' + biome;

  /* Rock base: wider, flatter */
  var rock = buildRock(T, 1.2, seed, biome);
  var rockMesh = new T.Mesh(rock.geo, rock.mat);
  rockMesh.position.y = -0.3;
  rockMesh.scale.y = 0.5;
  g.add(rockMesh);

  /* Spine curve: emerges from rock at an angle */
  var spineLen = 1.2;
  var vertCount = 12;
  var boneMat = toonMat({ color: new T.Color(boneCol) }, T);

  for (var vi = 0; vi < vertCount; vi++) {
    var t = vi / (vertCount - 1);
    var angle = t * 0.8; // tilt out of ground
    var x = Math.sin(angle) * spineLen * t;
    var y = Math.sin(angle) * spineLen * 0.5 * t - t * 0.1;
    var z = Math.cos(angle) * spineLen * 0.3 * Math.sin(t * Math.PI * 0.5);
    var size = 0.06 + 0.02 * Math.sin(t * Math.PI);

    /* Vertebra body */
    var vertGeo = new T.SphereGeometry(size, 6, 5);
    vertGeo.scale(1.3, 0.8, 1.0);
    var vert = new T.Mesh(vertGeo, boneMat);
    vert.position.set(x, y, z);
    g.add(vert);

    /* Inter-vertebral disc */
    if (vi > 0) {
      var pt = (vi - 1) / (vertCount - 1);
      var pa = pt * 0.8;
      var px = Math.sin(pa) * spineLen * pt;
      var py = Math.sin(pa) * spineLen * 0.5 * pt - pt * 0.1;
      var pz = Math.cos(pa) * spineLen * 0.3 * Math.sin(pt * Math.PI * 0.5);
      var discGeo = new T.CylinderGeometry(size * 0.7, size * 0.7, 0.04, 6);
      var disc = new T.Mesh(discGeo, boneMat);
      disc.position.set((px + x) / 2, (py + y) / 2, (pz + z) / 2);
      disc.lookAt(new T.Vector3(x, y, z));
      disc.rotateX(Math.PI / 2);
      g.add(disc);
    }

    /* Transverse processes (side protrusions) */
    if (vi > 2 && vi < vertCount - 3) {
      for (var side = -1; side <= 1; side += 2) {
        var procGeo = new T.CylinderGeometry(0.012, 0.01, 0.08, 4);
        var proc = new T.Mesh(procGeo, boneMat);
        proc.position.set(x, y, z);
        proc.position.x += side * 0.04;
        proc.rotation.z = side * 0.5;
        g.add(proc);
      }
    }
  }

  g.position.y = -0.08;
  return g;
}


/* ===================== CONVENIENCE ===================== */

/** All carcass variants (fresh + picked) on one group. */
export function buildAllCarcasses(T, seed) {
  var g = new T.Group();
  g.name = 'allCarcasses';

  var fresh = buildFreshCarcass(T, seed, {
    cA: '#884433', cB: '#221111', cC: '#ccaa88',
  });
  fresh.name = 'fresh';
  g.add(fresh);

  var picked = buildPickedCarcass(T, seed + 100);
  picked.name = 'picked';
  g.add(picked);

  return g;
}

/** All fossil variants across all biomes. */
export function buildAllFossils(T, seed) {
  var biomes = ['meadow', 'alpine', 'beach'];
  var g = new T.Group();
  g.name = 'allFossils';

  for (var bi = 0; bi < biomes.length; bi++) {
    var biome = biomes[bi];
    var bg = new T.Group();
    bg.name = biome;

    var skull = buildSkullFossil(T, seed, { biome: biome });
    skull.name = 'skull';
    bg.add(skull);

    var rib = buildRibcageFossil(T, seed + 1, { biome: biome });
    rib.name = 'ribcage';
    bg.add(rib);

    var spine = buildSpineFossil(T, seed + 2, { biome: biome });
    spine.name = 'spine';
    bg.add(spine);

    g.add(bg);
  }

  return g;
}