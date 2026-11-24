// Island JSON -> "ISL1" blob (core/include/cpore/island.h). One packer, shared by node and the browser:
// no node imports at module level. CLI: node tools/island/pack.mjs in.island.json out.isl
// Integers only; every number in the JSON must already be an integer in the unit its key names.

export const FORMAT = 'primigenia.island/1';
export const LIMITS = { feat: 96, pt: 1024, trail: 32, trailPt: 256, region: 24, regionPt: 96, mark: 32, mask: 4 };
export const MASK_RES = 128;
export const MASK_KEYS = ['climate_bias', 'canopy', 'erosion', 'protect'];
const KIND = { massif: 1, range: 2, ring: 3, plateau: 4, terrace: 5, badlands: 6, channel: 7, islet: 8, cone: 9 };
const FLAG_SEA = 1, FLAG_RIVER = 2;
const INT_LIM = 1 << 24;

// JSON key per C field, by kind. Fields not named stay 0.
const FIELDS = {
  massif: { x: 'x_dm', y: 'y_dm', across: 'across_dm', along: 'along_dm', k: 'axis_mdeg', h: 'h_cm' },
  range: { k: 'rugged_pm' },
  ring: { across: 'r_dm', along: 'half_dm', h: 'h_cm' },
  plateau: { x: 'x_dm', y: 'y_dm', across: 'r_dm', along: 'cliff_dm', h: 'top_cm' },
  terrace: { x: 'x_dm', y: 'y_dm', across: 'r_dm', along: 'feather_dm', h: 'step_cm', k: 'k_pm' },
  badlands: { x: 'x_dm', y: 'y_dm', across: 'r_dm', h: 'amp_cm', k: 'freq_pm' },
  channel: { along: 'wall_dm' },
  islet: { x: 'x_dm', y: 'y_dm', across: 'r_dm', along: 'bay_dm', h: 'top_cm' },
  cone: { x: 'x_dm', y: 'y_dm', across: 'reach_dm', h: 'h_cm' },
};
export const FIELD_KEYS = FIELDS;

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
export function crc32(bytes, skipFrom = -1, skipTo = -1) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < bytes.length; i++) { if (i >= skipFrom && i < skipTo) continue; c = CRC_TABLE[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8); }
  return (~c) >>> 0;
}

function int(v, what, lo = -INT_LIM, hi = INT_LIM) {
  if (!Number.isInteger(v)) throw new Error(`${what}: ${JSON.stringify(v)} is not an integer`);
  if (v < lo || v > hi) throw new Error(`${what}: ${v} outside ${lo}..${hi}`);
  return v;
}
function str(v, n, what) {
  if (v === undefined || v === null) v = '';
  if (typeof v !== 'string' || !/^[\x20-\x7e]*$/.test(v) || v.length > n - 1) throw new Error(`${what}: need printable ASCII of at most ${n - 1} chars, got ${JSON.stringify(v)}`);
  return v;
}
function b64(s, what) {
  const bin = atob(s);
  if (bin.length !== MASK_RES * MASK_RES) throw new Error(`${what}: ${bin.length} bytes, need ${MASK_RES * MASK_RES}`);
  const a = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) a[i] = bin.charCodeAt(i);
  return a;
}

class Writer {
  constructor() { this.parts = []; this.n = 0; }
  i32(...vs) { const b = new Uint8Array(4 * vs.length), dv = new DataView(b.buffer); vs.forEach((v, i) => dv.setInt32(4 * i, v, true)); this.push(b); }
  str(s, n) { const b = new Uint8Array(n); for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i); this.push(b); }
  bytes(a) { this.push(a); }
  push(b) { this.parts.push(b); this.n += b.length; }
  concat() { const o = new Uint8Array(this.n); let p = 0; for (const b of this.parts) { o.set(b, p); p += b.length; } return o; }
}

export function packIsland(j) {
  if (j.format !== FORMAT) throw new Error(`format must be ${FORMAT}`);
  const wind = j.wind || {}, clim = j.climate || {}, nest = j.nest || {}, lake = nest.lake || {}, coast = j.coast || {}, ero = j.erosion || {};
  const reef = coast.reef_pm || [0, 0], cliff = coast.cliff_pm || [0, 0];
  const feats = j.features || [], trails = j.trails || [], regions = j.regions || [], marks = j.marks || [];
  if (feats.length > LIMITS.feat) throw new Error('too many features');
  if (trails.length > LIMITS.trail) throw new Error('too many trails');
  if (regions.length > LIMITS.region) throw new Error('too many regions');
  if (marks.length > LIMITS.mark) throw new Error('too many marks');

  const pts = [], fr = [];
  for (const [i, f] of feats.entries()) {
    const kind = KIND[f.kind]; if (!kind) throw new Error(`feature ${i}: unknown kind ${f.kind}`);
    const keys = FIELDS[f.kind], what = `feature ${i} (${f.kind})`;
    const r = { kind, x: 0, y: 0, across: 0, along: 0, h: 0, k: 0, pt0: 0, npts: 0, flags: 0, name: str(f.name, 32, `${what} name`) };
    for (const [slot, key] of Object.entries(keys)) r[slot] = int(f[key], `${what} ${key}`);
    if (f.kind === 'range' || f.kind === 'channel') {
      if (!Array.isArray(f.pts) || f.pts.length < 2) throw new Error(`${what}: pts needs at least 2 points`);
      r.pt0 = pts.length; r.npts = f.pts.length;
      for (const [s, p] of f.pts.entries()) {
        if (!Array.isArray(p) || p.length !== 4) throw new Error(`${what}: point ${s} is [x_dm, y_dm, half_width_dm, h_cm]`);
        pts.push(p.map((v, q) => int(v, `${what} point ${s}[${q}]`)));
      }
      if (f.sea) r.flags |= FLAG_SEA;
      if (f.river) r.flags |= FLAG_RIVER;
      if (f.spline) throw new Error(`${what}: spline arrives in F1`);
    } else if (f.sea || f.river || f.pts) throw new Error(`${what}: sea, river and pts belong to range and channel features`);
    fr.push(r);
  }
  if (pts.length > LIMITS.pt) throw new Error('too many polyline points');

  const tpts = [], trs = trails.map((t, i) => {
    if (!Array.isArray(t.pts) || t.pts.length < 2) throw new Error(`trail ${i}: pts needs at least 2 points`);
    const o = { pt0: tpts.length, npts: t.pts.length, kind: str(t.kind, 16, `trail ${i} kind`) };
    t.pts.forEach((p, s) => tpts.push([int(p[0], `trail ${i}.${s} x`), int(p[1], `trail ${i}.${s} y`)]));
    return o;
  });
  if (tpts.length > LIMITS.trailPt) throw new Error('too many trail points');
  const rpts = [], rgs = regions.map((g, i) => {
    if (!Array.isArray(g.pts) || g.pts.length < 1) throw new Error(`region ${i}: pts needs at least 1 point`);
    const o = { gate: int(g.gate ?? 0, `region ${i} gate`, 0, 2), w: int(g.w_dm ?? 0, `region ${i} w_dm`, 0), pt0: rpts.length, npts: g.pts.length,
      name: str(g.name, 32, `region ${i} name`), kind: str(g.kind, 16, `region ${i} kind`), biome: str(g.biome, 16, `region ${i} biome`) };
    g.pts.forEach((p, s) => rpts.push([int(p[0], `region ${i}.${s} x`), int(p[1], `region ${i}.${s} y`)]));
    return o;
  });
  if (rpts.length > LIMITS.regionPt) throw new Error('too many region points');

  const masks = [];
  if (j.masks) {
    if (j.masks.res !== undefined && j.masks.res !== MASK_RES) throw new Error(`masks.res must be ${MASK_RES}`);
    for (const key of MASK_KEYS) { if (j.masks[key] === undefined) break; masks.push(b64(j.masks[key], `masks.${key}`)); }
    for (const key of MASK_KEYS.slice(masks.length)) if (j.masks[key] !== undefined) throw new Error(`masks: ${key} given after a gap`);
  }

  const w = new Writer();
  w.i32(int(j.size_dm, 'size_dm'), int(j.island_radius_dm, 'island_radius_dm'), int(j.n, 'n'), int(j.scale_pm, 'scale_pm'),
    int(wind.dir_mdeg ?? 0, 'wind.dir_mdeg'), int(wind.speed_cms ?? 0, 'wind.speed_cms'),
    int(reef[0], 'coast.reef_pm'), int(reef[1], 'coast.reef_pm'), int(cliff[0], 'coast.cliff_pm'), int(cliff[1], 'coast.cliff_pm'),
    int(nest.r_dm, 'nest.r_dm'), int(nest.floor_cm, 'nest.floor_cm'),
    int(lake.x_dm, 'nest.lake.x_dm'), int(lake.y_dm, 'nest.lake.y_dm'), int(lake.r_dm, 'nest.lake.r_dm'), int(lake.depth_cm, 'nest.lake.depth_cm'),
    int(ero.stream_iters ?? 0, 'erosion.stream_iters'), int(ero.droplets ?? 0, 'erosion.droplets'),
    int(clim.scale_h_pm ?? 0, 'climate.scale_h_pm'), int(clim.scale_z_pm ?? 0, 'climate.scale_z_pm'),
    int(clim.t_sea_cC ?? 0, 'climate.t_sea_cC'), int(clim.lapse_cK_per_km ?? 0, 'climate.lapse_cK_per_km'));
  w.str(str(j.id, 32, 'id'), 32);
  w.i32(fr.length, pts.length, trs.length, tpts.length, rgs.length, rpts.length, marks.length, masks.length);
  for (const r of fr) { w.i32(r.kind, r.x, r.y, r.across, r.along, r.h, r.k, r.pt0, r.npts, r.flags); w.str(r.name, 32); }
  for (const p of pts) w.i32(...p);
  for (const t of trs) { w.i32(t.pt0, t.npts); w.str(t.kind, 16); }
  for (const p of tpts) w.i32(...p);
  for (const g of rgs) { w.i32(g.gate, g.w, g.pt0, g.npts); w.str(g.name, 32); w.str(g.kind, 16); w.str(g.biome, 16); }
  for (const p of rpts) w.i32(...p);
  marks.forEach((m, i) => { w.i32(int(m.x_dm, `mark ${i} x_dm`), int(m.y_dm, `mark ${i} y_dm`)); w.str(str(m.name, 32, `mark ${i} name`), 32); w.str(str(m.kind, 16, `mark ${i} kind`), 16); });
  for (const m of masks) w.bytes(m);
  const body = w.concat();

  const out = new Uint8Array(16 + body.length), dv = new DataView(out.buffer);
  out.set([0x49, 0x53, 0x4c, 0x31], 0);        // "ISL1"
  dv.setUint16(4, 1, true); dv.setUint16(6, 0, true); dv.setUint32(8, body.length, true);
  out.set(body, 16);
  dv.setUint32(12, crc32(out, 12, 16), true);
  return out;
}

if (typeof process !== 'undefined' && process.versions?.node && process.argv[1] && /pack\.mjs$/.test(process.argv[1])) {
  const fs = await import('node:fs');
  const [, , inp, outp] = process.argv;
  if (!inp || !outp) { console.error('usage: node tools/island/pack.mjs in.island.json out.isl'); process.exit(2); }
  const blob = packIsland(JSON.parse(fs.readFileSync(inp, 'utf8')));
  fs.writeFileSync(outp, blob);
  console.log(`${outp}: ${blob.length} bytes, crc ${crc32(blob, 12, 16).toString(16).padStart(8, '0')}`);
}
