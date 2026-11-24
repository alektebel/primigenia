// The editor's data model: island state, units, editing helpers, undo history, JSON export and import.
// Pure functions, no DOM, so tools/island/editor_check.cjs runs it in node. The state IS the island JSON (primigenia.island/1,
// docs/plans/island-realism.md 3.1), except that the four masks live as Uint8Array in `maskData` and are written as base64 on export.
import { packIsland, FORMAT, MASK_RES, MASK_KEYS, LIMITS } from './pack.js';
export { FORMAT, MASK_RES, MASK_KEYS, LIMITS };

export const POLY_KINDS = ['range', 'channel'];
export const FEATURE_KINDS = ['massif', 'range', 'ring', 'plateau', 'terrace', 'badlands', 'channel', 'islet', 'cone'];
export const REGION_KINDS = ['nest', 'forest', 'canyon', 'badlands', 'plateau', 'islet', 'coast', 'terraces', 'mountain', 'cliffs', 'reef', 'trench'];
export const BIOMES = ['meadow', 'mountain', 'jungle', 'desert', 'tundra', 'cliffs', 'reef', 'trench', 'none'];
export const TRAIL_KINDS = ['exit', 'game_trail', 'path'];
export const MARK_KINDS = ['peak', 'crater', 'spire', 'tree', 'arch', 'plateau', 'volcano', 'reactor'];
export const MASK_LABEL = { climate_bias: 'Climate bias (wetter / drier)', canopy: 'Canopy (forest allowed / barred)', erosion: 'Erosion strength', protect: 'Protect (keep authored height)' };

// Field tables for the inspector. `u` is the unit of the stored integer; `w` says how the value maps to world metres:
// 'len' = design length (x scale), 'wlen' = already world metres, 'h' = heights (cm, not scaled), 'deg' = millidegrees, 'pm' = permille.
export const FIELDS = {
  massif: [['x_dm', 'Centre x', 'dm', 'len', -40000, 40000], ['y_dm', 'Centre y', 'dm', 'len', -40000, 40000], ['across_dm', 'Across', 'dm', 'len', 100, 40000], ['along_dm', 'Along', 'dm', 'len', 100, 40000], ['axis_mdeg', 'Axis angle', 'mdeg', 'deg', -360000, 360000], ['h_cm', 'Height', 'cm', 'h', 0, 200000]],
  range: [['rugged_pm', 'Ruggedness', 'pm', 'pm', 0, 3000]],
  ring: [['r_dm', 'Ring radius (world)', 'dm', 'wlen', 100, 80000], ['half_dm', 'Half width (world)', 'dm', 'wlen', 10, 40000], ['h_cm', 'Height', 'cm', 'h', 0, 200000]],
  plateau: [['x_dm', 'Centre x', 'dm', 'len', -40000, 40000], ['y_dm', 'Centre y', 'dm', 'len', -40000, 40000], ['r_dm', 'Flat radius', 'dm', 'len', 100, 40000], ['cliff_dm', 'Cliff width', 'dm', 'len', 10, 20000], ['top_cm', 'Top height', 'cm', 'h', 0, 200000]],
  terrace: [['x_dm', 'Centre x', 'dm', 'len', -40000, 40000], ['y_dm', 'Centre y', 'dm', 'len', -40000, 40000], ['r_dm', 'Radius', 'dm', 'len', 100, 40000], ['feather_dm', 'Feather', 'dm', 'len', 10, 20000], ['step_cm', 'Tread step', 'cm', 'h', 100, 10000], ['k_pm', 'Strength', 'pm', 'pm', 0, 1000]],
  badlands: [['x_dm', 'Centre x', 'dm', 'len', -40000, 40000], ['y_dm', 'Centre y', 'dm', 'len', -40000, 40000], ['r_dm', 'Radius', 'dm', 'len', 100, 40000], ['amp_cm', 'Amplitude', 'cm', 'h', 0, 60000], ['freq_pm', 'Frequency', 'pm', 'pm', 100, 4000]],
  channel: [['wall_dm', 'Wall width', 'dm', 'len', 10, 20000]],
  islet: [['x_dm', 'Centre x', 'dm', 'len', -40000, 40000], ['y_dm', 'Centre y', 'dm', 'len', -40000, 40000], ['r_dm', 'Radius', 'dm', 'len', 50, 20000], ['bay_dm', 'Bay radius', 'dm', 'len', 50, 20000], ['top_cm', 'Peak height', 'cm', 'h', 0, 100000]],
  cone: [['x_dm', 'Centre x', 'dm', 'len', -40000, 40000], ['y_dm', 'Centre y', 'dm', 'len', -40000, 40000], ['reach_dm', 'Reach', 'dm', 'len', 100, 40000], ['h_cm', 'Height at centre', 'cm', 'h', 0, 100000]],
};
export const POINT_FIELDS = [['x', 'x', 'dm', 'len', -40000, 40000], ['y', 'y', 'dm', 'len', -40000, 40000], ['hw', 'Half width', 'dm', 'len', 1, 20000], ['h', 'Height', 'cm', 'h', -5000, 200000]];

export const scaleOf = (s) => s.scale_pm / 1000;
const f32 = Math.fround;
// printf("%.0f"): round half to even
const r0 = (v) => { const r = Math.round(v); return Math.abs(v % 1) === 0.5 && r % 2 ? r - 1 : r; };
// design decimetres -> world metres (C: f10(v) * scale, in float)
export const wm = (s, dm) => f32(f32(dm / 10) * f32(s.scale_pm / 1000));
export const dmOf = (s, m) => Math.round(m / scaleOf(s) * 10);
export const worldToStr = (v) => (Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(1));
// the world metres a field value stands for, or null
export function worldValue(s, kind, v) {
  if (kind === 'len') return wm(s, v);
  if (kind === 'wlen') return v / 10;
  if (kind === 'h') return v / 100;
  if (kind === 'deg') return v / 1000;
  return null;
}

// ---- state --------------------------------------------------------------------------------------------------------------------
export function emptyMasks() { return MASK_KEYS.map(() => new Uint8Array(MASK_RES * MASK_RES).fill(128)); }
export const maskIsNeutral = (u) => { for (let i = 0; i < u.length; i++) if (u[i] !== 128) return false; return true; };

function b64enc(u) { let s = ''; for (let i = 0; i < u.length; i += 8192) s += String.fromCharCode.apply(null, u.subarray(i, i + 8192)); return btoa(s); }
function b64dec(t) { const bin = atob(t), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; }
const b64cache = new WeakMap();
const maskB64 = (u) => { let v = b64cache.get(u); if (!v) { v = b64enc(u); b64cache.set(u, v); } return v; };

// A state from island JSON (an object). Throws a readable Error when the JSON is not a valid island (the packer's own checks).
export function stateFromJSON(j) {
  const s = JSON.parse(JSON.stringify(j));
  const md = emptyMasks();
  if (s.masks) {
    MASK_KEYS.forEach((k, i) => { if (s.masks[k] !== undefined) { const u = b64dec(s.masks[k]); if (u.length !== MASK_RES * MASK_RES) throw new Error(`masks.${k}: ${u.length} bytes, need ${MASK_RES * MASK_RES}`); md[i] = u; } });
  }
  delete s.masks;
  for (const k of ['features', 'trails', 'regions', 'marks']) if (!Array.isArray(s[k])) s[k] = [];
  s.maskData = md;
  packIsland(contractOf(s));   // validates: throws with the field that is wrong
  return s;
}
// The contract JSON object (masks as base64, only the slots up to the last one that is not neutral).
export function contractOf(s) {
  const o = {};
  for (const k of Object.keys(s)) if (k !== 'maskData') o[k] = s[k];
  let last = -1;
  s.maskData.forEach((u, i) => { if (!maskIsNeutral(u)) last = i; });
  if (last >= 0) { o.masks = { res: MASK_RES }; for (let i = 0; i <= last; i++) o.masks[MASK_KEYS[i]] = maskB64(s.maskData[i]); }
  return o;
}
export const packState = (s) => packIsland(contractOf(s));
export function cloneState(s) { const c = JSON.parse(JSON.stringify({ ...s, maskData: undefined })); c.maskData = s.maskData.slice(); return c; }

// ---- JSON export / import: the API the artifact store and the Copy button use --------------------------------------------------
const J = JSON.stringify;
const line = (v) => J(v);
const KEY_ORDER = ['format', 'id', 'size_dm', 'island_radius_dm', 'n', 'scale_pm', 'wind', 'climate', 'coast', 'erosion', 'nest', 'features', 'trails', 'regions', 'marks', 'masks'];
// Stable, diff-friendly: one top-level key per line, one feature / trail / region / mark per line, point arrays inline, integers only.
export function exportJSON(s) {
  const o = contractOf(s), keys = KEY_ORDER.filter((k) => o[k] !== undefined).concat(Object.keys(o).filter((k) => !KEY_ORDER.includes(k)));
  const rows = keys.map((k) => {
    const v = o[k];
    if (['features', 'trails', 'regions', 'marks'].includes(k)) return `  ${J(k)}: [${v.length ? '\n' + v.map((e) => '    ' + line(e)).join(',\n') + '\n  ' : ''}]`;
    if (k === 'masks') return `  "masks": {${Object.keys(v).map((m) => `${J(m)}: ${J(v[m])}`).join(', ')}}`;
    return `  ${J(k)}: ${line(v)}`;
  });
  return `{\n${rows.join(',\n')}\n}\n`;
}
export function importJSON(text) {
  let j;
  try { j = typeof text === 'string' ? JSON.parse(text) : text; } catch (e) { throw new Error(`Not JSON: ${e.message}`); }
  if (!j || j.format !== FORMAT) throw new Error(`Not a ${FORMAT} island (format is ${J(j && j.format)}).`);
  return stateFromJSON(j);
}

// ---- meta for the analysis: what cp_island_meta_json writes (world metres, rounded like its %.0f) -------------------------------
export function toMeta(s) {
  const sc = f32(s.scale_pm / 1000), pt = ([x, y]) => [r0(f32(f32(x / 10) * (x === 0 && y === 0 ? 1 : sc))), r0(f32(f32(y / 10) * sc))];
  const nestR = r0(s.nest.r_dm / 10);
  return {
    id: s.id, nest_r: nestR, size_m: s.size_dm / 10,
    regions: s.regions.map((r) => ({ name: r.name || '', kind: r.kind || '', biome: r.biome || '', gate: r.gate || 0, w: r0(f32(f32((r.w_dm || 0) / 10) * sc)), pts: r.pts.map(pt) })),
    routes: s.trails.map((t) => ({ name: 'trail', kind: t.kind || '', pts: t.pts.map(pt) })),
    marks: s.marks.map((m) => ({ name: m.name || '', kind: m.kind || '', x: r0(f32(f32(m.x_dm / 10) * sc)), y: r0(f32(f32(m.y_dm / 10) * sc)) })),
  };
}

// mask sample in world metres, bilinear like cp_island_mask (the canopy rule of the validation panel)
export function sampleMask(u, size, x, y) {
  const R = MASK_RES, fx = (x + size / 2) / size * R - 0.5, fy = (y + size / 2) / size * R - 0.5;
  let x0 = Math.floor(fx), y0 = Math.floor(fy); const tx = Math.min(1, Math.max(0, fx - x0)), ty = Math.min(1, Math.max(0, fy - y0));
  const cl = (v) => Math.min(R - 1, Math.max(0, v)); x0 = cl(x0); y0 = cl(y0); const x1 = cl(x0 + 1), y1 = cl(y0 + 1);
  const a = u[y0 * R + x0], b = u[y0 * R + x1], c = u[y1 * R + x0], d = u[y1 * R + x1];
  return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty;
}

// A soft round brush on a mask. strength 0..1 is the blend toward `target` at the centre; the falloff is a raised cosine.
export function paintMask(u, size, cx, cy, radiusM, strength, target) {
  const R = MASK_RES, tex = size / R, r = radiusM / tex;
  const i0 = Math.max(0, Math.floor((cx + size / 2) / tex - r - 1)), i1 = Math.min(R - 1, Math.ceil((cx + size / 2) / tex + r + 1));
  const j0 = Math.max(0, Math.floor((cy + size / 2) / tex - r - 1)), j1 = Math.min(R - 1, Math.ceil((cy + size / 2) / tex + r + 1));
  let changed = false;
  for (let j = j0; j <= j1; j++) for (let i = i0; i <= i1; i++) {
    const d = Math.hypot((i + 0.5) * tex - size / 2 - cx, (j + 0.5) * tex - size / 2 - cy) / radiusM;
    if (d >= 1) continue;
    const w = strength * 0.5 * (1 + Math.cos(Math.PI * d)), v = u[j * R + i], nv = Math.round(v + (target - v) * w);
    if (nv !== v) { u[j * R + i] = nv; changed = true; }
  }
  return changed;
}

// ---- undo / redo (50 steps) -----------------------------------------------------------------------------------------------------
export class History {
  constructor(limit = 50) { this.limit = limit; this.past = []; this.future = []; }
  snap(s) { return { j: J({ ...s, maskData: undefined }), masks: s.maskData.slice() }; }
  restore(sn) { const s = JSON.parse(sn.j); s.maskData = sn.masks.slice(); return s; }
  // call BEFORE a change with the current state; returns nothing
  push(s) { this.past.push(this.snap(s)); if (this.past.length > this.limit) this.past.shift(); this.future.length = 0; }
  canUndo() { return this.past.length > 0; }
  canRedo() { return this.future.length > 0; }
  undo(s) { if (!this.past.length) return null; this.future.push(this.snap(s)); return this.restore(this.past.pop()); }
  redo(s) { if (!this.future.length) return null; this.past.push(this.snap(s)); return this.restore(this.future.pop()); }
}

// ---- editing helpers ------------------------------------------------------------------------------------------------------------
// A point of a polyline feature is [x, y, hw, h]; trails and regions hold [x, y].
export function pointsOf(s, sel) {
  if (sel.type === 'feature') return s.features[sel.i].pts || null;
  if (sel.type === 'trail') return s.trails[sel.i].pts;
  if (sel.type === 'region') return s.regions[sel.i].pts;
  return null;
}
// Index at which a new world point (x, y) joins a polyline: inside the nearest segment, or at an end when it is nearer to it than to any segment.
export function insertIndex(s, pts, x, y) {
  const P = pts.map(([a, b]) => [wm(s, a), wm(s, b)]);
  if (P.length < 2) return P.length;
  let best = 0, bd = Infinity, bu = 0;
  for (let i = 0; i + 1 < P.length; i++) {
    const [ax, ay] = P[i], [bx, by] = P[i + 1], sx = bx - ax, sy = by - ay, l2 = sx * sx + sy * sy;
    const u = l2 ? Math.min(1, Math.max(0, ((x - ax) * sx + (y - ay) * sy) / l2)) : 0, d = Math.hypot(x - ax - u * sx, y - ay - u * sy);
    if (d < bd) { bd = d; best = i; bu = u; }
  }
  if (best === 0 && bu === 0) return 0;                       // beyond the first end: extend the start
  if (best === P.length - 2 && bu === 1) return P.length;     // beyond the last end: extend the end
  return best + 1;
}
export function addPoint(s, sel, x, y) {
  const pts = pointsOf(s, sel); if (!pts) return -1;
  const at = insertIndex(s, pts, x, y), X = dmOf(s, x), Y = dmOf(s, y);
  let p;
  if (sel.type === 'feature') {
    const a = pts[Math.max(0, at - 1)], b = pts[Math.min(pts.length - 1, at)];
    p = [X, Y, Math.round((a[2] + b[2]) / 2), Math.round((a[3] + b[3]) / 2)];
  } else p = [X, Y];
  pts.splice(at, 0, p);
  return at;
}
export const minPoints = (sel) => (sel.type === 'region' ? 1 : 2);
export function deletePoint(s, sel, k) { const pts = pointsOf(s, sel); if (!pts || pts.length <= minPoints(sel)) return false; pts.splice(k, 1); return true; }

export function newFeature(s, kind, x, y) {
  const X = dmOf(s, x), Y = dmOf(s, y), d = (m) => Math.round(m / scaleOf(s) * 10);
  switch (kind) {
    case 'massif': return { kind, x_dm: X, y_dm: Y, across_dm: d(1500), along_dm: d(2000), axis_mdeg: 0, h_cm: 30000, name: 'New massif' };
    case 'range': return { kind, pts: [[X - d(300), Y, d(250), 12000], [X + d(300), Y, d(250), 12000]], rugged_pm: 800, name: 'New range' };
    case 'ring': return { kind, r_dm: 2000, half_dm: 500, h_cm: 4000, name: 'New ring' };
    case 'plateau': return { kind, x_dm: X, y_dm: Y, r_dm: d(500), cliff_dm: d(80), top_cm: 20000, name: 'New plateau' };
    case 'terrace': return { kind, x_dm: X, y_dm: Y, r_dm: d(800), feather_dm: d(400), step_cm: 2400, k_pm: 900, name: 'New terraces' };
    case 'badlands': return { kind, x_dm: X, y_dm: Y, r_dm: d(600), amp_cm: 8000, freq_pm: 1000, name: 'New badlands' };
    case 'channel': return { kind, pts: [[X - d(300), Y, d(120), 2400], [X + d(300), Y, d(120), 1200]], wall_dm: d(260), name: 'New channel' };
    case 'islet': return { kind, x_dm: X, y_dm: Y, r_dm: d(250), bay_dm: d(600), top_cm: 12000, name: 'New islet' };
    default: return { kind: 'cone', x_dm: X, y_dm: Y, reach_dm: d(800), h_cm: 15000, name: 'New cone' };
  }
}
// where a feature's centre handle sits (world metres), or null for polylines and the ring
export function centreOf(s, f) {
  if (f.kind === 'range' || f.kind === 'channel' || f.kind === 'ring') return null;
  return [wm(s, f.x_dm), wm(s, f.y_dm)];
}
// the radius field of a feature (for its second handle), or null
export const RADIUS_KEY = { massif: 'across_dm', plateau: 'r_dm', terrace: 'r_dm', badlands: 'r_dm', islet: 'r_dm', cone: 'reach_dm' };
