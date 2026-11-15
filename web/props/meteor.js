/* meteor.js — panspermia meteor shards and the impact crater kit.
 *
 * Gap G65 (meteor shards that tell the story), G13 / W10 (the start-valley
 * landmark is the panspermia meteor crater).
 *
 * Three.js r128 · ES module · deterministic from a seed.
 *
 * The valley (art/reference/valle-primigenio.html, patched by
 * tools/hero/build_hero.py) is a toon world: one 6-band gradient ramp, a cool
 * rim light on every material, palette C "Current+" (G63) and an ACES +
 * aerial-fog pipeline.  These props speak the same language:
 *
 *   - world props are toon materials on the shared ramp.  The crater floor is
 *     the one exception and it is the shared meadow material, so the
 *     depression reads as scorched meadow rather than as a grey disc dropped
 *     on the grass;
 *   - every colour comes from palette C (g0/g1 meadow, r0/r1/r2 rock, warm
 *     light) — no neon, no off-palette hues;
 *   - the glyph is carved, not painted: a procedural height field is turned
 *     into a normal map plus a darkened albedo, so the groove is lit like a
 *     groove, and a faint warm emissive leaks out of its floor.
 *
 * Public API (the THREE instance is passed in, the module imports nothing):
 *
 *   buildMeteorShard(THREE, seed, variant, params) -> THREE.Mesh
 *   buildCraterKit(THREE, seed, params)           -> THREE.Group
 *   buildMeteorProps(THREE, seed, params)         -> THREE.Group
 *   makeGroundMaterial(THREE, params)             -> THREE.MeshStandardMaterial
 *   craterHeight(radius, depth, r)                -> number
 *   countTriangles(object) / countDrawCalls(object)
 */

const TAU = Math.PI * 2;

/* ------------------------------------------------------------------------- *
 * Palette C "Current+" — the default golden look of web/hero/index.html.
 * Land colours are linear (the shared land shader works in linear space).
 * ------------------------------------------------------------------------- */
export const STYLE = {
  ramp: [46, 46, 82, 82, 112, 112],   // palette C toon ramp (build_hero.py PAL.C.light.ramp)
  sun: [-0.62, 0.28, -0.72],          // palette C golden sun direction
  sunColor: '#ffd6a0',
  hemiSky: '#a8ccf8',
  hemiGround: '#6a6a5c',
  airCool: [0.34, 0.58, 0.88],
  airWarm: [0.96, 0.74, 0.46],
  grassTint: [1.03, 0.96, 0.86],      // palette C HL.grass
  /* meadow (linear) */
  g0: [0.090, 0.225, 0.040],
  g1: [0.185, 0.335, 0.075],
  /* rock (linear) */
  r0: [0.150, 0.165, 0.190],
  r1: [0.280, 0.215, 0.140],
  r2: [0.190, 0.135, 0.085],
  /* scorched earth: the meadow/rock range pushed to char (linear) */
  scorch: [0.052, 0.040, 0.028],
  /* the meteor itself: dark cool glass, warm light inside */
  shard: [0.052, 0.049, 0.066],
  shardWarm: [0.140, 0.115, 0.120],
  glow: [0.7455, 0.3515, 0.0513],     // #e0a040, linear
  glass: [0.038, 0.034, 0.048],
  rimRock: [0.105, 0.112, 0.125],     // scorched valley rock
};

/* ------------------------------------------------------------------------- *
 * Small helpers
 * ------------------------------------------------------------------------- */
function rng(seed) {
  let s = seed | 0;
  return function () {
    s |= 0; s = s + 0x6D2B79F5 | 0;
    let t = Math.imul(s ^ s >>> 15, 1 | s);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const smoothstep = (e0, e1, x) => {
  const t = clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
};

/** Linear RGB triple -> THREE.Color (the valley's `col()` convention). */
export function linColor(THREE, rgb) {
  return new THREE.Color(rgb[0], rgb[1], rgb[2]);
}

/** sRGB hex -> linear RGB triple. */
export function hexToLinear(hex) {
  const c = new THREE.Color(hex);           // r128: legacy mode, no auto conversion
  c.convertSRGBToLinear();
  return [c.r, c.g, c.b];
}

/* ------------------------------------------------------------------------- *
 * The shared toon ramp (the valley's toon(): 6 bands, nearest filtered)
 * ------------------------------------------------------------------------- */
const RAMP_CACHE = new WeakMap();
export function rampTexture(THREE, ramp = STYLE.ramp) {
  let perThree = RAMP_CACHE.get(THREE);
  if (!perThree) { perThree = new Map(); RAMP_CACHE.set(THREE, perThree); }
  const key = ramp.join(',');
  if (perThree.has(key)) return perThree.get(key);
  const t = new THREE.DataTexture(new Uint8Array(ramp), ramp.length, 1, THREE.LuminanceFormat);
  t.minFilter = THREE.NearestFilter;
  t.magFilter = THREE.NearestFilter;
  t.needsUpdate = true;
  perThree.set(key, t);
  return t;
}

/**
 * Toon material with the valley's cool rim light.  `key` must differ whenever
 * the injected shader code differs, because three.js caches programs by it.
 */
export function makeToonMaterial(THREE, opts = {}) {
  const {
    color = [1, 1, 1], ramp = STYLE.ramp, vertexColors = false, key = 'prop',
    rim = 0.28, rimColor = [0.5, 0.66, 0.8], ...rest
  } = opts;
  const m = new THREE.MeshToonMaterial({
    gradientMap: rampTexture(THREE, ramp),
    color: linColor(THREE, color),
    vertexColors,
    ...rest
  });
  m.onBeforeCompile = (shader) => {
    shader.fragmentShader = shader.fragmentShader.replace('#include <tonemapping_fragment>',
      `float rim=pow(1.-max(dot(normalize(vViewPosition),normal),0.),3.);gl_FragColor.rgb+=rim*vec3(${rimColor.map(v => v.toFixed(3)).join(',')})*${rim.toFixed(3)};\n#include <tonemapping_fragment>`);
  };
  m.customProgramCacheKey = () => 'meteor-' + key;
  return m;
}

/* ------------------------------------------------------------------------- *
 * The shared meadow material (the crater floor and the preview ground).
 * Same maths as the valley's land shader: g0/g1 meadow, patch noise, the same
 * light ramp, plus the scorch ring that belongs to the impact.  The standard
 * shadow map is kept, so the props cast shadows on the meadow.
 * ------------------------------------------------------------------------- */
const GROUND_NOISE = `
float mHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float mNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mHash(i),mHash(i+vec2(1.,0.)),f.x),mix(mHash(i+vec2(0.,1.)),mHash(i+1.),f.x),f.y);}
float mRamp(float light){return .60+.25*smoothstep(.18,.25,light)+.23*smoothstep(.53,.61,light);}
`;

export function makeGroundMaterial(THREE, opts = {}) {
  const {
    sun = STYLE.sun, crater = [0, 0], craterRadius = 7.5, scorch = 1.0,
    shade = 0.45, key = 'ground',
  } = opts;
  const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, metalness: 0 });
  m.userData.shader = null;          // the compiled shader, handy when debugging
  m.onBeforeCompile = (shader) => {
    m.userData.shader = shader;
    shader.uniforms.uSun = { value: new THREE.Vector3(...sun).normalize() };
    shader.uniforms.uG0 = { value: linColor(THREE, STYLE.g0) };
    shader.uniforms.uG1 = { value: linColor(THREE, STYLE.g1) };
    shader.uniforms.uScorch = { value: linColor(THREE, STYLE.scorch) };
    shader.uniforms.uTint = { value: linColor(THREE, STYLE.grassTint) };
    shader.uniforms.uCrater = { value: new THREE.Vector2(crater[0], crater[1]) };
    shader.uniforms.uCraterR = { value: craterRadius };
    shader.uniforms.uScorchAmt = { value: scorch };
    shader.uniforms.uShade = { value: shade };
    shader.vertexShader = 'varying vec3 vLandPos;\nvarying vec3 vLandNrm;\n' +
      shader.vertexShader.replace('#include <begin_vertex>',
        '#include <begin_vertex>\nvLandPos=(modelMatrix*vec4(position,1.)).xyz;vLandNrm=normalize(mat3(modelMatrix)*normal);');
    shader.fragmentShader = 'varying vec3 vLandPos;\nvarying vec3 vLandNrm;\n' +
      'uniform vec3 uSun,uG0,uG1,uScorch,uTint;uniform vec2 uCrater;uniform float uCraterR,uScorchAmt,uShade;\n' +
      GROUND_NOISE + shader.fragmentShader;
    // the standard shader has no shadow-mask helper of its own; bring it in
    // so the meadow can be lit by the shared shadow map
    shader.fragmentShader = shader.fragmentShader.replace('#include <shadowmap_pars_fragment>',
      '#include <shadowmap_pars_fragment>\n#include <shadowmask_pars_fragment>');
    const out = 'gl_FragColor = vec4( outgoingLight, diffuseColor.a );';
    if (!shader.fragmentShader.includes(out)) throw new Error('ground shader output target changed');
    shader.fragmentShader = shader.fragmentShader.replace(out, `
    vec2 xz=vLandPos.xz;
    float light=max(dot(normalize(vLandNrm),uSun),0.);
    float tone=mNoise(xz*.03);
    vec3 land=mix(uG0,uG1,smoothstep(.22,.80,tone));
    land*=(.78+.30*mNoise(xz*.19)+.14*mNoise(xz*.63));
    land*=mRamp(light)*uTint;
    // scorched ring: the impact cooked the meadow in a wide, noisy circle
    float d=distance(xz,uCrater);
    float sc=1.-smoothstep(uCraterR*.08,uCraterR*1.30,d);
    sc*=.50+.50*mNoise(xz*.45);
    land=mix(land,uScorch,clamp(sc*uScorchAmt,0.,1.));
    // the valley ground keeps its own value ramp; only the shadow is applied
    // on top, so the crater floor stays meadow and the props still cast on it
    float shadow=getShadowMask();
    outgoingLight=land*mix(uShade,1.,shadow);
    ${out}`);
  };
  m.customProgramCacheKey = () => 'meteor-' + key;
  return m;
}

/* ------------------------------------------------------------------------- *
 * The glyph atlas — a carved rune per shard.
 *
 * Six cells (five shards + the crater core) and one blank cell.  Each cell is
 * drawn as a stroke pattern, blurred into a height field, and turned into
 * three textures: albedo (the groove floor is darker), normal (the groove is
 * a groove) and emissive (a faint warm light leaks out of it).
 * ------------------------------------------------------------------------- */
const CELL = 256, ATLAS_COLS = 4, ATLAS_ROWS = 2, ATLAS_W = CELL * ATLAS_COLS, ATLAS_H = CELL * ATLAS_ROWS;
const PAD = 30;                                  // blank margin inside a cell
const GLYPH_SCALE = 0.62;                        // the rune covers the middle of the face
const BLANK_CELL = 7;

function glyphStrokes(kind, r) {
  const j = () => (r() - 0.5) * 0.035;
  const jit = (p) => [p[0] + j(), p[1] + j()];
  switch (kind) {
    case 'spine':
      return [[[0.5, 0.10], [0.5, 0.90]], [[0.39, 0.30], [0.61, 0.30]],
        [[0.41, 0.50], [0.59, 0.50]], [[0.39, 0.70], [0.61, 0.70]]].map(s => s.map(jit));
    case 'zigzag':
      return [[[0.20, 0.86], [0.46, 0.62], [0.26, 0.42], [0.52, 0.16], [0.78, 0.32]]].map(s => s.map(jit));
    case 'dome': {
      const pts = [];
      for (let i = 0; i <= 12; i++) {
        const a = Math.PI * (0.10 + 0.80 * i / 12);
        pts.push([0.5 + 0.28 * Math.cos(a), 0.44 + 0.30 * Math.sin(a)]);
      }
      return [pts.map(jit), [[0.32, 0.18], [0.68, 0.18]].map(jit)];
    }
    case 'cross':
      return [[[0.5, 0.14], [0.5, 0.86]], [[0.22, 0.43], [0.78, 0.57]]].map(s => s.map(jit));
    case 'ring': {
      const pts = [];
      for (let i = 0; i <= 6; i++) {
        const a = Math.PI / 6 + i * Math.PI / 3;
        pts.push([0.5 + 0.25 * Math.cos(a), 0.5 + 0.25 * Math.sin(a)]);
      }
      return [pts.map(jit), [[0.5, 0.30], [0.5, 0.70]].map(jit)];
    }
    case 'spiral': {
      const pts = [];
      for (let i = 0; i <= 18; i++) {
        const t = i / 18, a = t * Math.PI * 3.4, rad = 0.04 + t * 0.21;
        pts.push([0.5 + rad * Math.cos(a), 0.5 + rad * Math.sin(a)]);
      }
      return [pts.map(jit)];
    }
    default:
      return [[[0.5, 0.15], [0.5, 0.85]]];
  }
}

function boxBlur(src, w, h, radius, passes) {
  let a = src, b = new Float32Array(src.length);
  for (let p = 0; p < passes; p++) {
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let sum = 0, n = 0;
        for (let k = -radius; k <= radius; k++) {
          const xx = x + k;
          if (xx < 0 || xx >= w) continue;
          sum += a[y * w + xx]; n++;
        }
        b[y * w + x] = sum / n;
      }
    }
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        let sum = 0, n = 0;
        for (let k = -radius; k <= radius; k++) {
          const yy = y + k;
          if (yy < 0 || yy >= h) continue;
          sum += b[yy * w + x]; n++;
        }
        a[y * w + x] = sum / n;
      }
    }
  }
  return a;
}

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}

const ATLAS_CACHE = new WeakMap();
/** Glyph atlas for a seed: { map, normalMap, emissiveMap }. Shared by all shards. */
export function glyphAtlas(THREE, seed) {
  let perThree = ATLAS_CACHE.get(THREE);
  if (!perThree) { perThree = new Map(); ATLAS_CACHE.set(THREE, perThree); }
  if (perThree.has(seed)) return perThree.get(seed);
  const r = rng(seed ^ 0x5eed);

  /* 1. draw the strokes into a mask canvas */
  const shape = makeCanvas(ATLAS_W, ATLAS_H);
  const sx = shape.getContext('2d');
  sx.fillStyle = '#fff';
  sx.fillRect(0, 0, ATLAS_W, ATLAS_H);
  sx.strokeStyle = '#000';
  sx.lineCap = 'round';
  sx.lineJoin = 'round';
  sx.lineWidth = 14;
  const kinds = ['spine', 'zigzag', 'dome', 'cross', 'ring', 'spiral'];
  kinds.forEach((kind, cell) => {
    const cx = (cell % ATLAS_COLS) * CELL, cy = Math.floor(cell / ATLAS_COLS) * CELL;
    for (const poly of glyphStrokes(kind, r)) {
      sx.beginPath();
      poly.forEach((p, i) => {
        const px = cx + PAD + (GLYPH_SCALE * 0.5 + p[0] * GLYPH_SCALE) * (CELL - 2 * PAD);
        const py = cy + CELL - PAD - (GLYPH_SCALE * 0.5 + p[1] * GLYPH_SCALE) * (CELL - 2 * PAD);
        if (i === 0) sx.moveTo(px, py); else sx.lineTo(px, py);
      });
      sx.stroke();
    }
  });

  /* 2. height field: 1 inside a stroke, blurred to a soft shoulder */
  const img = sx.getImageData(0, 0, ATLAS_W, ATLAS_H).data;
  const h = new Float32Array(ATLAS_W * ATLAS_H);
  for (let i = 0; i < h.length; i++) {
    const o = i * 4;
    const lum = (img[o] * 0.299 + img[o + 1] * 0.587 + img[o + 2] * 0.114) / 255;
    h[i] = 1 - lum;
  }
  const hb = boxBlur(h, ATLAS_W, ATLAS_H, 4, 2);

  /* 3. albedo (darker groove floor), normal map, emissive (warm leak) */
  const alb = makeCanvas(ATLAS_W, ATLAS_H), actx = alb.getContext('2d');
  const aimg = actx.createImageData(ATLAS_W, ATLAS_H);
  const nrm = makeCanvas(ATLAS_W, ATLAS_H), nctx = nrm.getContext('2d');
  const nimg = nctx.createImageData(ATLAS_W, ATLAS_H);
  const emi = makeCanvas(ATLAS_W, ATLAS_H), ectx = emi.getContext('2d');
  const eimg = ectx.createImageData(ATLAS_W, ATLAS_H);
  const S = 3.2;                                  // normal strength (stronger groove)
  for (let y = 0; y < ATLAS_H; y++) {
    for (let x = 0; x < ATLAS_W; x++) {
      const i = y * ATLAS_W + x, o = i * 4;
      const hh = hb[i];
      const gx = (hb[y * ATLAS_W + Math.min(ATLAS_W - 1, x + 1)] - hb[y * ATLAS_W + Math.max(0, x - 1)]) * S;
      const gy = (hb[Math.min(ATLAS_H - 1, y + 1) * ATLAS_W + x] - hb[Math.max(0, y - 1) * ATLAS_W + x]) * S;
      // the surface dips into the groove, so the normal tilts towards it;
      // image y grows downwards while texture v grows upwards -> gy is negated
      let nx = gx, ny = -gy, nz = 1;
      const len = Math.hypot(nx, ny, nz);
      nx /= len; ny /= len; nz /= len;
      const dark = 1 - 0.80 * hh;                 // albedo of the groove floor (deeper)
      aimg.data[o] = 255 * dark; aimg.data[o + 1] = 255 * dark; aimg.data[o + 2] = 255 * dark; aimg.data[o + 3] = 255;
      nimg.data[o] = (nx * 0.5 + 0.5) * 255; nimg.data[o + 1] = (ny * 0.5 + 0.5) * 255;
      nimg.data[o + 2] = (nz * 0.5 + 0.5) * 255; nimg.data[o + 3] = 255;
      const e = smoothstep(0.35, 0.95, hh);       // emissive more pronounced in groove center
      eimg.data[o] = 255 * e; eimg.data[o + 1] = 255 * e; eimg.data[o + 2] = 255 * e; eimg.data[o + 3] = 255;
    }
  }
  actx.putImageData(aimg, 0, 0);
  nctx.putImageData(nimg, 0, 0);
  ectx.putImageData(eimg, 0, 0);

  const tex = (canvas, srgb) => {
    const t = new THREE.CanvasTexture(canvas);
    t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping;
    t.minFilter = THREE.LinearMipmapLinearFilter;
    t.magFilter = THREE.LinearFilter;
    t.generateMipmaps = true;
    t.anisotropy = 4;
    if (srgb) t.encoding = THREE.sRGBEncoding;
    return t;
  };
  const atlas = { map: tex(alb, true), normalMap: tex(nrm, false), emissiveMap: tex(emi, true) };
  perThree.set(seed, atlas);
  return atlas;
}

/**
 * UV rect of a cell inside the atlas.  Canvas textures are flipped (flipY),
 * so canvas row 0 is the top of the texture: v runs from the bottom of the
 * cell upwards.
 */
function cellRect(cell) {
  const cx = (cell % ATLAS_COLS) * CELL, cy = Math.floor(cell / ATLAS_COLS) * CELL;
  return {
    x0: cx / ATLAS_W, x1: (cx + CELL) / ATLAS_W,
    y0: 1 - (cy + CELL) / ATLAS_H, y1: 1 - cy / ATLAS_H,
  };
}

/* ------------------------------------------------------------------------- *
 * Shard shapes — five crystals, one carved glyph each.
 *
 * A shard is a prism with an irregular cross section, a tapered shoulder and
 * a pointed tip: unmistakably a chipped crystal from every angle.  The
 * longest side of the cross section is the carved face.
 * cross: unit cross section points [x,z]; w: [base, shoulder] scale;
 * hBody: height of the shoulder; h: tip height; tip: tip offset.
 * ------------------------------------------------------------------------- */
export const SHARD_SPECS = [
  {
    id: 'spire', h: 1.05, cell: 0, glyph: 'spine',
    cross: [[0.52, 0], [0, 0.30], [-0.52, 0], [0, -0.30]],
    w: [1, 0.52], hBody: 0.70, tip: [0, 0], twist: 0.18,
  },
  {
    id: 'blade', h: 0.88, cell: 1, glyph: 'zigzag',
    cross: [[0.58, 0.10], [-0.50, 0.13], [-0.56, -0.11], [0.52, -0.14]],
    w: [1, 0.86], hBody: 0.52, tip: [0.16, 0], twist: -0.10,
  },
  {
    id: 'tablet', h: 0.78, cell: 2, glyph: 'dome',
    cross: [[0.46, 0.20], [0.04, 0.44], [-0.42, 0.26], [-0.50, -0.18], [-0.02, -0.44], [0.44, -0.26]],
    w: [1, 0.92], hBody: 0.58, tip: [-0.05, 0.04], twist: 0.12,
  },
  {
    id: 'cluster', h: 0.95, cell: 3, glyph: 'cross', parts: [
      {
        offset: [-0.16, 0, 0], h: 0.95, hBody: 0.62,
        cross: [[0.44, 0], [0, 0.28], [-0.44, 0], [0, -0.28]],
        w: [1, 0.5], tip: [0, 0], twist: 0.2,
      },
      {
        offset: [0.17, 0, 0.05], h: 0.63, hBody: 0.42,
        cross: [[0.40, 0], [0, 0.26], [-0.40, 0], [0, -0.26]],
        w: [1, 0.55], tip: [0.05, 0], twist: -0.3,
      },
      {
        offset: [0.01, 0, -0.12], h: 0.39, hBody: 0.26,
        cross: [[0.38, 0], [0, 0.24], [-0.38, 0], [0, -0.24]],
        w: [1, 0.6], tip: [0, 0], twist: 0.5,
      },
    ],
  },
  {
    id: 'dart', h: 0.94, cell: 4, glyph: 'ring',
    cross: [[0.44, 0.16], [-0.26, 0.36], [-0.48, -0.10], [-0.06, -0.36], [0.42, -0.22]],
    w: [1, 0.44], hBody: 0.58, tip: [0.06, 0], twist: 0.22,
  },
];

/** Push one crystal (prism + tip) into the shared arrays. */
function pushCrystal(part, cell, into) {
  const { cross, w, hBody, tip, twist = 0 } = part;
  const K = cross.length;
  const { pos, idx, uv, col } = into;
  const rect = cellRect(cell);
  const blank = cellRect(BLANK_CELL);
  const bl = [blank.x0 + (blank.x1 - blank.x0) * 0.5, blank.y0 + (blank.y1 - blank.y0) * 0.5];
  const off = part.offset || [0, 0, 0];

  const base = cross.map(([x, z]) => [x * w[0], 0, z * w[0]]);
  const ca = Math.cos(twist), sa = Math.sin(twist);
  const sh = cross.map(([x, z]) => {
    const X = (x * ca - z * sa) * w[1], Z = (x * sa + z * ca) * w[1];
    return [X, hBody, Z];
  });
  const tipP = [(tip[0] + 0) * w[1], part.h, (tip[1] + 0) * w[1]];

  // the carved face is the longest edge of the cross section
  let face = 0, faceLen = -1;
  for (let k = 0; k < K; k++) {
    const a = base[k], b = base[(k + 1) % K];
    const len = Math.hypot(b[0] - a[0], b[2] - a[2]);
    if (len > faceLen) { faceLen = len; face = k; }
  }
  const e0 = base[face], e1 = base[(face + 1) % K];
  const ed = [(e1[0] - e0[0]) / faceLen, 0, (e1[2] - e0[2]) / faceLen];
  // outward normal of the carved face (used to aim the shard at the reader)
  let cx = 0, cz = 0;
  for (const p of base) { cx += p[0]; cz += p[2]; }
  cx /= K; cz /= K;
  let fn = [e1[2] - e0[2], -(e1[0] - e0[0])];
  const mx = (e0[0] + e1[0]) * 0.5 - cx, mz = (e0[2] + e1[2]) * 0.5 - cz;
  if (fn[0] * mx + fn[1] * mz < 0) fn = [-fn[0], -fn[1]];
  const fnl = Math.hypot(fn[0], fn[1]) || 1;
  into.glyphNormal = [fn[0] / fnl, fn[1] / fnl];
  const faceUV = (u, v) => [
    rect.x0 + (rect.x1 - rect.x0) * clamp(u, 0, 1),
    rect.y0 + (rect.y1 - rect.y0) * clamp(v, 0, 1),
  ];
  // the carved face is a trapezoid: the top edge is shorter, so the rune is
  // squeezed towards the middle instead of being stretched sideways
  const e0s = sh[face], e1s = sh[(face + 1) % K];
  const topLen = Math.hypot(e1s[0] - e0s[0], e1s[2] - e0s[2]);
  const shrink = Math.max(0, (1 - topLen / faceLen) * 0.5);
  const faceU = (k, top) => {
    if (k === face) return top ? shrink : 0;
    if (k === (face + 1) % K) return top ? 1 - shrink : 1;
    return null;
  };
  const push = (p, uvv, shade) => {
    pos.push(p[0] + off[0], p[1] + off[1], p[2] + off[2]);
    uv.push(uvv[0], uvv[1]);
    col.push(shade, shade, shade);
    return pos.length / 3 - 1;
  };
  const bIdx = base.map((p, k) => {
    const u = faceU(k, false);
    return push(p, u === null ? bl : faceUV(u, 0), 1);
  });
  const sIdx = sh.map((p, k) => {
    const u = faceU(k, true);
    return push(p, u === null ? bl : faceUV(u, 1), 0.84);
  });
  const tIdx = push(tipP, bl, 0.9);

  for (let k = 0; k < K; k++) {
    const k2 = (k + 1) % K;
    // side facet (outward winding) and the tip facet
    idx.push(bIdx[k], sIdx[k], sIdx[k2], bIdx[k], sIdx[k2], bIdx[k2]);
    idx.push(sIdx[k], tIdx, sIdx[k2]);
  }
  // base cap
  for (let k = 1; k < K - 1; k++) idx.push(bIdx[0], bIdx[k + 1], bIdx[k]);
}

/** Geometry of one shard variant (all its crystals merged). */
export function shardGeometry(THREE, variant) {
  const spec = SHARD_SPECS[variant % SHARD_SPECS.length];
  const into = { pos: [], idx: [], uv: [], col: [], glyphNormal: [0, 1] };
  const parts = spec.parts || [spec];
  for (const p of parts) pushCrystal(p, spec.cell, into);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(into.pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(into.uv, 2));
  g.setAttribute('color', new THREE.Float32BufferAttribute(into.col, 3));
  g.setIndex(into.idx);
  g.computeVertexNormals();
  g.userData.glyphNormal = into.glyphNormal;
  return g;
}

/* ------------------------------------------------------------------------- *
 * Shard material: dark glass with a faint warm heart and a carved glyph.
 * ------------------------------------------------------------------------- */
function shardMaterial(THREE, atlas, glow, opts = {}) {
  const { spec = 0.10, rim = 0.22, key = 'shard' } = opts;
  const m = new THREE.MeshToonMaterial({
    gradientMap: rampTexture(THREE),
    color: linColor(THREE, STYLE.shard),
    map: atlas.map,
    normalMap: atlas.normalMap,
    normalScale: new THREE.Vector2(3.6, 3.6),
    emissive: linColor(THREE, STYLE.glow),
    emissiveMap: atlas.emissiveMap,
    emissiveIntensity: glow,
    vertexColors: true,
    flatShading: true,
  });
  m.onBeforeCompile = (shader) => {
    shader.fragmentShader = shader.fragmentShader.replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      // light bleeding through the thin crystal edges — glassy Fresnel
      float fres=pow(1.-abs(dot(normalize(vViewPosition),normal)),2.5);
      totalEmissiveRadiance+=diffuseColor.rgb*vec3(1.,.62,.28)*fres*1.5;
      #if NUM_DIR_LIGHTS > 0
        vec3 hdir=normalize(directionalLights[0].direction+normalize(vViewPosition));
        totalEmissiveRadiance+=vec3(1.,.94,.82)*smoothstep(0.975,0.995,dot(normal,hdir))*${spec.toFixed(3)};
      #endif`);
    // a crystal edge catches the light in a thin line, not in a broad band
    shader.fragmentShader = shader.fragmentShader.replace('#include <tonemapping_fragment>',
      `float rim=pow(1.-max(dot(normalize(vViewPosition),normal),0.),5.);gl_FragColor.rgb+=rim*vec3(.55,.70,.86)*${rim.toFixed(3)};\n#include <tonemapping_fragment>`);
  };
  m.customProgramCacheKey = () => 'meteor-' + key;
  return m;
}

/**
 * One meteor shard.  variant 0..4 picks the shape; the seed decides the rest
 * (glow, scale, tint).  Deterministic: the same seed always gives the same
 * shard.
 */
export function buildMeteorShard(THREE, seed, variant = 0, opts = {}) {
  const v = variant % SHARD_SPECS.length;
  const spec = SHARD_SPECS[v];
  const r = rng((seed | 0) ^ Math.imul(v + 1, 0x9E3779B1));
  const atlas = opts.atlas || glyphAtlas(THREE, seed | 0);
  const glow = opts.glow != null ? opts.glow : 0.05 + r() * 0.09;
  const scale = opts.scale != null ? opts.scale : 0.82 + r() * 0.46;
  const geo = opts.geometry || shardGeometry(THREE, v);
  const mat = shardMaterial(THREE, atlas, glow, { key: 'shard' });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.name = 'meteor-shard-' + spec.id;
  mesh.scale.setScalar(scale);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  mesh.userData = {
    variant: v, id: spec.id, glow, scale, tris: countTriangles(mesh),
    glyphNormal: geo.userData.glyphNormal || [0, 1],
  };
  return mesh;
}

/* ------------------------------------------------------------------------- *
 * Crater kit
 * ------------------------------------------------------------------------- */

/** Height of the crater bowl at radius r (0 at the rim, -depth in the middle). */
export function craterHeight(radius, depth, r) {
  const t = clamp(r / radius, 0, 1);
  const bowl = -depth * Math.pow(1 - t * t, 1.6);
  const lip = 0.30 * Math.exp(-Math.pow((t - 0.86) / 0.11, 2)) * (1 - smoothstep(0.86, 1.0, t));
  return bowl + lip;
}

/** A shattered slab of the valley floor: an irregular prism, flat and tilted. */
function rockGeometry(THREE, seed) {
  const K = 7, r = rng(seed);
  const pts = [];
  for (let i = 0; i < K; i++) {
    const a = (i / K) * TAU + (r() - 0.5) * 0.30;
    const rad = 0.78 + r() * 0.40;
    pts.push([Math.cos(a) * rad, Math.sin(a) * rad]);
  }
  const pos = [], idx = [];
  const H = 0.5;
  for (let i = 0; i < K; i++) {
    const [x, z] = pts[i];
    pos.push(x, -H * 0.5, z);
    pos.push(x * (0.82 + r() * 0.3), H * 0.5, z * (0.82 + r() * 0.3));
  }
  for (let i = 0; i < K; i++) {
    const a = i * 2, b = ((i + 1) % K) * 2;
    idx.push(a, a + 1, b + 1, a, b + 1, b);
  }
  for (let i = 1; i < K - 1; i++) {
    idx.push(1, (i * 2 + 1) % (K * 2), (i * 2 + 3) % (K * 2));   // top cap
    idx.push(0, (i * 2 + 2) % (K * 2), i * 2);                    // base cap
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
}

/** Instanced scattered rocks: the rim ring and the crater floor debris, merged
 * into a single draw call by using one geometry and two size ranges. */
function rockField(THREE, seed, opts) {
  const {
    count, radius, depth, ring = true, sizeMin = 0.45, sizeMax = 1.6,
    color = STYLE.r0, key = 'rock', name = 'rocks', tilt = 0.5,
    innerMin = 0, innerMax = 0, innerCount = 0,
  } = opts;
  const r = rng(seed);
  const geo = rockGeometry(THREE, seed ^ 0x51ed);
  const n = geo.attributes.position.count;
  geo.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(n * 3).fill(1), 3));
  const mat = makeToonMaterial(THREE, {
    color, vertexColors: true, key, rim: 0.20, flatShading: true,
  });
  const mesh = new THREE.InstancedMesh(geo, mat, count);
  mesh.name = name;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  const d = new THREE.Object3D();
  // rim ring rocks (outer)
  for (let i = 0; i < count - innerCount; i++) {
    const a = (i / count) * TAU + (r() - 0.5) * (TAU / count) * 1.8;
    const rad = radius * (0.90 + r() * 0.12);
    const s = sizeMin + r() * (sizeMax - sizeMin);
    const y = craterHeight(radius, depth, rad) + s * 0.10;
    d.position.set(Math.cos(a) * rad, y, Math.sin(a) * rad);
    d.rotation.set((r() - 0.5) * tilt, r() * TAU, (r() - 0.5) * tilt);
    d.scale.set(s * (0.9 + r() * 0.5), s * (0.45 + r() * 0.45), s * (0.9 + r() * 0.5));
    d.updateMatrix();
    mesh.setMatrixAt(i, d.matrix);
    const tint = 0.55 + r() * 0.7;
    mesh.setColorAt(i, new THREE.Color(tint * (0.95 + r() * 0.15), tint * (0.93 + r() * 0.12), tint * (0.92 + r() * 0.12)));
  }
  // inner/debris rocks (floor)
  for (let i = count - innerCount; i < count; i++) {
    const a = r() * TAU;
    const rad = radius * Math.sqrt(r()) * 0.72;
    const s = innerMin + r() * (innerMax - innerMin);
    const y = craterHeight(radius, depth, rad) + s * 0.05;
    d.position.set(Math.cos(a) * rad, y, Math.sin(a) * rad);
    d.rotation.set((r() - 0.5) * (tilt * 1.3), r() * TAU, (r() - 0.5) * (tilt * 1.3));
    d.scale.set(s * (0.9 + r() * 0.5), s * (0.45 + r() * 0.45), s * (0.9 + r() * 0.5));
    d.updateMatrix();
    mesh.setMatrixAt(i, d.matrix);
    const tint = 0.55 + r() * 0.7;
    mesh.setColorAt(i, new THREE.Color(tint * (0.95 + r() * 0.15), tint * (0.93 + r() * 0.12), tint * (0.92 + r() * 0.12)));
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

/** The depression itself: a radial bowl that meets the meadow at y = 0.
 * Uses DoubleSide so the underside reads as shadow (a real hollow). */
function craterBowl(THREE, radius, depth, segments, rings, material) {
  const pos = [], idx = [], uv = [];
  for (let i = 0; i <= rings; i++) {
    const t = i / rings, rad = radius * t;
    for (let j = 0; j <= segments; j++) {
      const a = (j / segments) * TAU;
      const x = Math.cos(a) * rad, z = Math.sin(a) * rad;
      pos.push(x, craterHeight(radius, depth, rad), z);
      uv.push(x * 0.1, z * 0.1);
    }
  }
  for (let i = 0; i < rings; i++) {
    for (let j = 0; j < segments; j++) {
      const a = i * (segments + 1) + j, b = a + 1, c = a + segments + 1, d = c + 1;
      idx.push(a, b, c, b, d, c);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  const mesh = new THREE.Mesh(g, material);
  mesh.name = 'crater-bowl';
  mesh.material.side = THREE.DoubleSide;
  mesh.receiveShadow = true;
  return mesh;
}

/** A soft, scorched patch of ground (the impact's spatter). */
function scorchTexture(THREE) {
  const c = makeCanvas(128, 128);
  const x = c.getContext('2d');
  const g = x.createRadialGradient(64, 64, 4, 64, 64, 62);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.55, 'rgba(255,255,255,0.85)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = g;
  x.fillRect(0, 0, 128, 128);
  const t = new THREE.CanvasTexture(c);
  t.encoding = THREE.sRGBEncoding;
  return t;
}

/**
 * The crater rim kit: shattered rock ring, fused glass, scorched spatter and
 * the half buried meteor core in the middle.
 */
export function buildCraterKit(THREE, seed, params = {}) {
  const {
    radius = 7.5, depth = 1.15, segments = 32, rings = 9,
    rimRocks = 24, floorRocks = 12, surfacePatches = 16,
    glassPatches = 7, scorchPatches = 9,
    bowl = false, ground = null, key = 'crater',
  } = params;
  const group = new THREE.Group();
  group.name = 'meteor-crater';
  const r = rng((seed | 0) ^ 0x0c7a7e);

  const groundMat = ground || makeGroundMaterial(THREE, { crater: [0, 0], craterRadius: radius, key });

  // One shallow bowl for the depression — merges with meadow via same material.
  // The bowl geometry is placed *below* y=0 so it reads as a depression,
  // with the ground material already containing the scorched-ring logic.
  if (bowl) {
    const b = craterBowl(THREE, radius, depth * 0.65, segments, rings, groundMat);
    group.add(b);
  }

  // Rim + debris in a single draw call (instanced).
  // The rim rocks are slightly darker to match the scorched palette.
  const rocks = rockField(THREE, seed ^ 0x11, {
    count: rimRocks + floorRocks, radius, depth,
    sizeMin: 0.35, sizeMax: 0.95, innerMin: 0.16, innerMax: 0.55, innerCount: floorRocks,
    color: STYLE.rimRock, key: 'rocks', name: 'crater-rocks', tilt: 0.8,
  });
  group.add(rocks);

  // Fused glass: the impact melted the ground into dark sheets.
  // Separate from scorched so we can use different geometry counts.
  {
    const g = new THREE.CircleGeometry(1, 9);
    g.rotateX(-Math.PI / 2);
    const n = g.attributes.position.count;
    g.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(n * 3).fill(1), 3));
    const glassMat = makeToonMaterial(THREE, {
      color: STYLE.glass, vertexColors: true, key: 'glass2', rim: 0.03,
      transparent: true, opacity: 0.50, depthWrite: false,
      polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3,
    });
    const glassMesh = new THREE.InstancedMesh(g, glassMat, glassPatches);
    glassMesh.name = 'crater-glass';
    glassMesh.receiveShadow = true;
    const d = new THREE.Object3D();
    for (let i = 0; i < glassPatches; i++) {
      const a = r() * TAU, rad = radius * (0.12 + r() * 0.62);
      const s = 0.35 + r() * 1.25;
      d.position.set(Math.cos(a) * rad, craterHeight(radius, depth, rad) + 0.015 + r() * 0.02, Math.sin(a) * rad);
      d.rotation.set(0, r() * TAU, 0);
      d.scale.set(s * (0.7 + r() * 0.8), 1, s * (0.5 + r() * 0.7));
      d.updateMatrix();
      glassMesh.setMatrixAt(i, d.matrix);
      const tint = 0.55 + r() * 0.5;
      glassMesh.setColorAt(i, new THREE.Color(tint, tint * 0.92, tint * 1.02));
    }
    glassMesh.instanceMatrix.needsUpdate = true;
    if (glassMesh.instanceColor) glassMesh.instanceColor.needsUpdate = true;
    group.add(glassMesh);
  }

  // Scorched spatter: a thin overlay that bakes dark colour into the meadow.
  {
    const g = new THREE.CircleGeometry(1, 14);
    g.rotateX(-Math.PI / 2);
    const n = g.attributes.position.count;
    g.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(n * 3).fill(1), 3));
    const scorchMat = makeToonMaterial(THREE, {
      color: STYLE.scorch, vertexColors: true, key: 'scorch2', rim: 0.02,
      transparent: true, opacity: 0.65, depthWrite: false,
      polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4,
    });
    const scorchMesh = new THREE.InstancedMesh(g, scorchMat, scorchPatches);
    scorchMesh.name = 'crater-scorch';
    scorchMesh.receiveShadow = true;
    const d = new THREE.Object3D();
    for (let i = 0; i < scorchPatches; i++) {
      const a = r() * TAU, rad = radius * (0.1 + Math.sqrt(r()) * 0.95);
      const s = 0.4 + r() * 1.1;
      d.position.set(Math.cos(a) * rad, craterHeight(radius, depth, rad) + 0.02, Math.sin(a) * rad);
      d.rotation.set(0, r() * TAU, 0);
      d.scale.set(s, 1, s * (0.6 + r() * 0.7));
      d.updateMatrix();
      scorchMesh.setMatrixAt(i, d.matrix);
      const tint = 0.65 + r() * 0.5;
      scorchMesh.setColorAt(i, new THREE.Color(tint * 0.55, tint * 0.42, tint * 0.30));
    }
    scorchMesh.instanceMatrix.needsUpdate = true;
    if (scorchMesh.instanceColor) scorchMesh.instanceColor.needsUpdate = true;
    group.add(scorchMesh);
  }

  // the half buried meteor core: the reason the valley has a crater
  {
    const core = buildMeteorShard(THREE, seed ^ 0x33, 3, {
      atlas: glyphAtlas(THREE, seed | 0), glow: 0.12, scale: 2.1,
    });
    core.name = 'meteor-core';
    core.rotation.set(0.22, r() * TAU, 0.30);
    core.position.set(0, craterHeight(radius, depth, 0) + 0.55, 0);
    group.add(core);
  }

  return group;
}

/* ------------------------------------------------------------------------- *
 * The whole set: the crater plus the five shards, placed on the valley floor.
 * ------------------------------------------------------------------------- */
export function buildMeteorProps(THREE, seed, params = {}) {
  const {
    radius = 7.5, depth = 1.15, shardDistance = null, ground = null,
  } = params;
  const group = new THREE.Group();
  group.name = 'meteor-props';
  const r = rng((seed | 0) ^ 0x5eed);
  const atlas = glyphAtlas(THREE, seed | 0);
  const kit = buildCraterKit(THREE, seed, { ...params, ground });
  group.add(kit);

  const dist = shardDistance != null ? shardDistance : radius * 1.35;
  for (let i = 0; i < 5; i++) {
    const shard = buildMeteorShard(THREE, seed, i, { atlas });
    const a = (i / 5) * TAU + 0.55 + (r() - 0.5) * 0.5;
    const rad = dist * (0.72 + r() * 0.5);
    const inCrater = i < 2;
    const x = Math.cos(a) * rad, z = Math.sin(a) * rad;
    const y = inCrater ? craterHeight(radius, depth, rad) + 0.12 : -0.10;
    shard.position.set(x, y, z);
    // the glyph faces outwards: the shards are meant to be read when found
    shard.rotation.set((r() - 0.5) * 0.4, -a + Math.PI * 0.5 + (r() - 0.5) * 0.7, (r() - 0.5) * 0.35);
    group.add(shard);
  }
  return group;
}

/* ------------------------------------------------------------------------- *
 * Evidence helpers
 * ------------------------------------------------------------------------- */
export function countTriangles(object) {
  let tris = 0;
  object.traverse((o) => {
    if (!o.isMesh || !o.geometry) return;
    const g = o.geometry;
    const n = g.index ? g.index.count : (g.attributes.position ? g.attributes.position.count : 0);
    tris += (n / 3) * (o.isInstancedMesh ? o.count : 1);
  });
  return Math.round(tris);
}
export function countDrawCalls(object) {
  let n = 0;
  object.traverse((o) => { if (o.isMesh && o.visible) n++; });
  return n;
}
