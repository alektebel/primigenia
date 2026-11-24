// Primigenia island editor (docs/plans/island-realism.md 3.4, step F2).
// The map you see is the real C terrain generator compiled to WASM and run in a Web Worker (island/terrain_worker.js):
// shape only at 256 while you drag, eroded at 512 when you let go, a 1536 bake on demand. The data is the island JSON
// (primigenia.island/1), packed to the ISL1 blob by island/pack.js, the same module the node tools use.
import * as M from './island/model.js';
import { validate } from './island/analysis.js';

const $ = (id) => document.getElementById(id);
const el = (tag, props = {}, ...kids) => { const e = document.createElement(tag); for (const [k, v] of Object.entries(props)) { if (k === 'class') e.className = v; else if (k === 'text') e.textContent = v; else if (k.startsWith('on')) e.addEventListener(k.slice(2), v); else if (v !== false && v !== undefined) e.setAttribute(k, v === true ? '' : v); } for (const k of kids.flat()) if (k != null) e.append(k.nodeType ? k : document.createTextNode(k)); return e; };
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const DRAFT_KEY = 'primigenia.island-editor.draft', PREFS_KEY = 'primigenia.island-editor.prefs';
const store = { get(k) { try { return localStorage.getItem(k); } catch { return null; } }, set(k, v) { try { localStorage.setItem(k, v); } catch { /* private window: the draft just is not kept */ } } };
const FEAT_COLOR = { massif: '#e8b87a', range: '#d9a066', ring: '#9aa5b0', plateau: '#c58be8', terrace: '#d2aa5a', badlands: '#e86a50', channel: '#5ab4e8', islet: '#58d2e6', cone: '#ee7744' };
const REGION_COLOR = { nest: '#ffd660', forest: '#28aa46', canyon: '#f07828', badlands: '#e65a3c', plateau: '#aa5adc', islet: '#3cc8e6', coast: '#f0d25a', terraces: '#d2aa5a', mountain: '#bebec8', cliffs: '#788caa', reef: '#3ce6c8', trench: '#2846c8' };
const SLOPE_RGB = [[30, 70, 120], [140, 200, 110], [232, 214, 96], [240, 150, 60], [205, 50, 50], [90, 170, 215]];

// ---- application state ----------------------------------------------------------------------------------------------------------
const A = {
  s: null, hist: new M.History(50), sel: null, tool: 'select', seed: 1, bakeN: 1536, rev: 0, liveOpen: false, expected: null, defaultJSON: null,
  layers: { base: 'relief', features: true, regions: true, routes: true, marks: true, masks: false, grid: true, labels: true, handles: true },
  brush: { slot: 1, radius: 300, strength: 0.5, value: 255, erase: false },
  view: { cx: 0, cy: 0, ppm: 0.06 }, res: { shape: null, full: null, bake: null }, shown: null, imgs: null, errors: [], ready: false, handles: [],
  busy: { shape: false, full: false, bake: false }, progress: 0, keyboard: false, hover: null,
};
const events = new EventTarget();

// ---- the preview worker ---------------------------------------------------------------------------------------------------------
const worker = new Worker('island/terrain_worker.js', { type: 'module' });
let reqId = 0; const inflight = new Map();
worker.onmessage = (ev) => {
  const m = ev.data;
  if (m.type === 'ready') { A.ready = true; document.body.dataset.worker = 'ready'; changed({ initial: true }); return; }
  if (m.type === 'progress') { A.progress = m.done / Math.max(1, m.total); if (m.level !== 'shape') { $('busy-bar').style.width = `${Math.round(clamp(A.progress, 0, 1) * 100)}%`; } return; }
  const info = inflight.get(m.id);
  if (m.type === 'dropped') { inflight.delete(m.id); if (info) refreshBusy(); return; }
  inflight.delete(m.id);
  if (m.type === 'error') { A.busy[(info && info.level) || 'shape'] = false; showError(m.message); refreshBusy(); return; }
  if (m.type === 'result') { A.busy[m.level] = [...inflight.values()].some((q) => q.level === m.level); A.res[m.level] = m; pick(); refreshBusy(); }
};
worker.onerror = (e) => { showError(`The preview worker failed: ${e.message || 'could not load the WASM module (serve this page over http)'}`); };

function send(level) {
  if (!A.ready) return;
  let blob;
  try { blob = M.packState(A.s); } catch (e) { showError(`Not a valid island: ${e.message}`); return; }
  const n = level === 'shape' ? 256 : level === 'full' ? 512 : A.bakeN, id = ++reqId;
  inflight.set(id, { level, rev: A.rev }); A.busy[level] = true;
  worker.postMessage({ type: 'run', id, rev: A.rev, level, blob, seed: A.seed, n, meta: M.toMeta(A.s), canopy: A.s.maskData[1] });
  if (level === 'bake') $('busy-bar').style.width = '0';
  refreshBusy();
}
let shapeQueued = false, fullTimer = 0;
function queueShape() { if (shapeQueued) return; shapeQueued = true; requestAnimationFrame(() => { shapeQueued = false; send('shape'); }); }
function scheduleFull(ms) { clearTimeout(fullTimer); fullTimer = setTimeout(() => send('full'), ms); }

// The best result to show: the newest edit, and at equal edit the deepest level (bake > full > shape). A result of an older edit is shown
// only until the current one arrives (marked stale).
function pick() {
  const order = ['bake', 'full', 'shape'];
  let best = null;
  for (const lv of order) { const r = A.res[lv]; if (!r) continue; if (!best || r.rev > best.rev) best = r; }
  if (!best) return;
  if (A.shown !== best) { A.shown = best; A.imgs = null; A.validation = validate(best.stats); }
  document.body.dataset.rev = String(A.rev);
  document.body.dataset.shown = `${best.level}:${best.rev}`;
  document.body.dataset.hash = best.terrainHash;
  renderChip(); renderCheck(); renderIslandInfo(); requestDraw();
}
function refreshBusy() {
  const b = A.busy, text = b.bake ? `Baking ${A.bakeN}x${A.bakeN}` : b.full ? 'Eroding 512x512' : b.shape && A.shown == null ? 'Generating' : '';
  $('busy').classList.toggle('on', !!(b.bake || b.full));
  $('busy-text').textContent = text;
  if (!(b.bake || b.full)) $('busy-bar').style.width = '0';
  document.body.dataset.busy = Object.entries(b).filter(([, v]) => v).map(([k]) => k).join(',');
  renderChip();
}

// ---- edits, history, change notification ---------------------------------------------------------------------------------------
let saveTimer = 0;
function changed({ live = false, initial = false } = {}) {
  A.rev++;
  if (!A.ready) return;
  queueShape();
  if (live) clearTimeout(fullTimer); else scheduleFull(initial ? 0 : 250);
  if (!live) {
    updateUndo();
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => { const json = M.exportJSON(A.s); store.set(DRAFT_KEY, JSON.stringify({ json, seed: A.seed })); events.dispatchEvent(new CustomEvent('change', { detail: { json } })); }, 400);
  }
  requestDraw();
}
function edit(fn) { A.hist.push(A.s); fn(); changed(); }
function beginLive() { if (!A.liveOpen) { A.hist.push(A.s); A.liveOpen = true; } }
function live(fn) { beginLive(); fn(); changed({ live: true }); }
function endLive() { if (A.liveOpen) { A.liveOpen = false; changed(); renderEdit(false); } }
function updateUndo() { $('undo').disabled = !A.hist.canUndo(); $('redo').disabled = !A.hist.canRedo(); }
function setState(s, { keepSel = false } = {}) { A.s = s; if (!keepSel || !validSel()) A.sel = null; renderEdit(); renderIslandTab(); }
function undo() { const s = A.hist.undo(A.s); if (s) { setState(s, { keepSel: true }); changed(); } }
function redo() { const s = A.hist.redo(A.s); if (s) { setState(s, { keepSel: true }); changed(); } }
function validSel() {
  const s = A.sel; if (!s) return true;
  if (s.type === 'feature') return !!A.s.features[s.i] && (s.k == null || !A.s.features[s.i].pts || s.k < A.s.features[s.i].pts.length);
  if (s.type === 'trail' || s.type === 'region') { const o = A.s[s.type + 's'][s.i]; return !!o && (s.k == null || s.k < o.pts.length); }
  if (s.type === 'mark') return !!A.s.marks[s.i];
  return true;
}

// ---- toast and errors ----------------------------------------------------------------------------------------------------------------
let toastTimer = 0;
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('on'), 3200); }
function showError(msg) { A.errors.push(msg); toast(msg); console.warn(msg); }

// ---- view and drawing ---------------------------------------------------------------------------------------------------------------
const cv = $('map'), ctx = cv.getContext('2d');
let W = 1, H = 1, DPR = 1, drawQueued = false;
const wx2s = (x) => (x - A.view.cx) * A.view.ppm + W / 2, wy2s = (y) => (y - A.view.cy) * A.view.ppm + H / 2;
const sx2w = (x) => (x - W / 2) / A.view.ppm + A.view.cx, sy2w = (y) => (y - H / 2) / A.view.ppm + A.view.cy;
const insetBottom = () => (matchMedia('(min-width:900px)').matches || $('sheet').classList.contains('peek') ? 0 : $('sheet').offsetHeight);
function fitView() {
  const size = A.s.size_dm / 10, inset = insetBottom(), vis = Math.max(120, H - inset);
  A.view.ppm = Math.min(W, vis) / (size * 1.03); A.view.cx = 0; A.view.cy = inset / (2 * A.view.ppm);
  requestDraw();
}
function resize() {
  const r = cv.getBoundingClientRect(); DPR = Math.min(2, window.devicePixelRatio || 1);
  W = Math.max(1, Math.round(r.width)); H = Math.max(1, Math.round(r.height));
  cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
  document.documentElement.style.setProperty('--inset', insetBottom() + 'px');
  requestDraw();
}
new ResizeObserver(() => { const first = !A.fitted && A.s; resize(); if (first) { A.fitted = true; fitView(); } }).observe(cv);
function requestDraw() { if (drawQueued) return; drawQueued = true; requestAnimationFrame(() => { drawQueued = false; draw(); }); }

function canvasOf(w, h, fill) { const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d'); const id = g.createImageData(w, h); fill(id.data); g.putImageData(id, 0, 0); return c; }
function baseImage() {
  const r = A.shown; if (!r) return null;
  A.imgs = A.imgs || {};
  const kind = A.layers.base;
  if (A.imgs[kind]) return A.imgs[kind];
  const n = r.n;
  let c;
  if (kind === 'relief') c = canvasOf(n, n, (d) => d.set(r.rgba));
  else c = canvasOf(n, n, (d) => {
    for (let k = 0; k < n * n; k++) {
      const col = SLOPE_RGB[r.cls[k]] || [0, 0, 0], sh = (150 + r.shade[k] * 0.45) / 255;
      let R = col[0] * sh * 1.35, G = col[1] * sh * 1.35, B = col[2] * sh * 1.35;
      if (kind === 'reach') {
        const land = r.cls[k] !== 0 && r.cls[k] !== 4, rr = r.reach[k];
        if (rr === 1) { R = R * 0.55 + 20; G = G * 0.55 + 105; B = B * 0.55 + 40; }
        else if (rr === 2) { R = R * 0.5 + 95; G = G * 0.5 + 45; B = B * 0.5 + 135; }
        else if (r.cls[k] !== 0) { R = R * 0.45 + 125; G = G * 0.45 + 25; B = B * 0.45 + 25; }
        void land;
      }
      d[k * 4] = R; d[k * 4 + 1] = G; d[k * 4 + 2] = B; d[k * 4 + 3] = 255;
    }
  });
  A.imgs[kind] = c; return c;
}
function maskImage(slot) {
  const u = A.s.maskData[slot], key = A.maskImgKey;
  if (A.maskImg && A.maskImg.u === u && A.maskImg.slot === slot) return A.maskImg.c;
  const c = canvasOf(M.MASK_RES, M.MASK_RES, (d) => {
    for (let k = 0; k < u.length; k++) {
      const v = u[k] - 128, a = Math.min(1, Math.abs(v) / 127) * 0.7;
      if (v >= 0) { d[k * 4] = 255; d[k * 4 + 1] = 150; d[k * 4 + 2] = 40; } else { d[k * 4] = 60; d[k * 4 + 1] = 150; d[k * 4 + 2] = 255; }
      d[k * 4 + 3] = a * 255;
    }
  });
  void key; A.maskImg = { u, slot, c }; return c;
}

const sc = () => M.scaleOf(A.s);
function polyWorld(f) { return f.pts.map((p) => [M.wm(A.s, p[0]), M.wm(A.s, p[1]), M.wm(A.s, p[2] || 0)]); }
// centripetal Catmull-Rom, for drawing only (the C evaluator is what is generated)
function crSample(P, seg = 12) {
  if (P.length < 3) return P.map((p) => [p[0], p[1]]);
  const ext = (a, b) => [2 * a[0] - b[0], 2 * a[1] - b[1]], Q = [ext(P[0], P[1]), ...P, ext(P[P.length - 1], P[P.length - 2])], out = [];
  for (let i = 1; i < Q.length - 2; i++) {
    const [p0, p1, p2, p3] = [Q[i - 1], Q[i], Q[i + 1], Q[i + 2]];
    const t = (a, b) => Math.sqrt(Math.hypot(b[0] - a[0], b[1] - a[1])) || 1e-3, t0 = 0, t1 = t0 + t(p0, p1), t2 = t1 + t(p1, p2), t3 = t2 + t(p2, p3);
    for (let g = 0; g < seg; g++) {
      const tt = t1 + (t2 - t1) * g / seg, L = (a, b, ta, tb, u) => [a[0] + (b[0] - a[0]) * (u - ta) / (tb - ta), a[1] + (b[1] - a[1]) * (u - ta) / (tb - ta)];
      const A1 = L(p0, p1, t0, t1, tt), A2 = L(p1, p2, t1, t2, tt), A3 = L(p2, p3, t2, t3, tt), B1 = L(A1, A2, t0, t2, tt), B2 = L(A2, A3, t1, t3, tt);
      out.push(L(B1, B2, t1, t2, tt));
    }
  }
  out.push([P[P.length - 1][0], P[P.length - 1][1]]);
  return out;
}
function strokePath(pts, close = false) { ctx.beginPath(); pts.forEach(([x, y], i) => (i ? ctx.lineTo(wx2s(x), wy2s(y)) : ctx.moveTo(wx2s(x), wy2s(y)))); if (close) ctx.closePath(); }

function buildHandles() {
  const s = A.s, hs = [], sel = A.sel, V = A.view;
  const add = (wx, wy, sl, move, role = 'pt', color = '#fff') => hs.push({ wx, wy, sel: sl, move, role, color });
  const snapDm = (v) => M.dmOf(s, v);
  s.features.forEach((f, i) => {
    const col = FEAT_COLOR[f.kind] || '#fff';
    if (f.pts) f.pts.forEach((p, k) => add(M.wm(s, p[0]), M.wm(s, p[1]), { type: 'feature', i, k }, (x, y) => { p[0] = snapDm(x); p[1] = snapDm(y); }, 'pt', col));
    const c = M.centreOf(s, f);
    if (c) {
      add(c[0], c[1], { type: 'feature', i, k: null }, (x, y) => { f.x_dm = snapDm(x); f.y_dm = snapDm(y); }, 'pt', col);
      const rk = M.RADIUS_KEY[f.kind];
      if (rk && sel && sel.type === 'feature' && sel.i === i) add(c[0] + M.wm(s, f[rk]), c[1], { type: 'feature', i, k: null }, (x, y) => { f[rk] = Math.max(1, Math.round(Math.hypot(x - M.wm(s, f.x_dm), y - M.wm(s, f.y_dm)) / sc() * 10)); }, 'radius', col);
    }
  });
  for (const type of ['trail', 'region']) s[type + 's'].forEach((t, i) => t.pts.forEach((p, k) => add(M.wm(s, p[0]), M.wm(s, p[1]), { type, i, k }, (x, y) => { p[0] = snapDm(x); p[1] = snapDm(y); }, 'pt', type === 'trail' ? '#ffe9a0' : REGION_COLOR[t.kind] || '#fff')));
  s.marks.forEach((m, i) => add(M.wm(s, m.x_dm), M.wm(s, m.y_dm), { type: 'mark', i, k: null }, (x, y) => { m.x_dm = snapDm(x); m.y_dm = snapDm(y); }, 'mark', '#fff'));
  add(s.nest.r_dm / 10, 0, { type: 'nest' }, (x, y) => { s.nest.r_dm = Math.max(10, Math.round(Math.hypot(x, y) * 10)); }, 'radius', '#ffd660');
  const L = s.nest.lake;
  add(L.x_dm / 10, L.y_dm / 10, { type: 'nest' }, (x, y) => { L.x_dm = Math.round(x * 10); L.y_dm = Math.round(y * 10); }, 'pt', '#5ab4e8');
  void V; return hs;
}

function draw() {
  if (!A.s) return;
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
  ctx.clearRect(0, 0, W, H);
  ctx.fillStyle = '#0e1114'; ctx.fillRect(0, 0, W, H);
  const size = A.s.size_dm / 10, img = baseImage(), V = A.view;
  if (img) {
    ctx.imageSmoothingEnabled = V.ppm * size / img.width < 3; ctx.imageSmoothingQuality = 'high';
    if (A.shown && A.shown.rev !== A.rev) ctx.globalAlpha = 0.8;
    ctx.drawImage(img, wx2s(-size / 2), wy2s(-size / 2), size * V.ppm, size * V.ppm); ctx.globalAlpha = 1;
  } else { ctx.fillStyle = '#16303f'; ctx.fillRect(wx2s(-size / 2), wy2s(-size / 2), size * V.ppm, size * V.ppm); }
  const slot = A.tool === 'paint' ? A.brush.slot : A.layers.masks ? A.layers.maskSlot ?? 1 : -1;
  if (slot >= 0) { ctx.imageSmoothingEnabled = true; ctx.drawImage(maskImage(slot), wx2s(-size / 2), wy2s(-size / 2), size * V.ppm, size * V.ppm); }
  if (A.layers.grid) drawGrid(size);
  ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  const s = A.s, sel = A.sel, selIs = (type, i) => sel && sel.type === type && sel.i === i;
  if (A.layers.regions) s.regions.forEach((r, i) => {
    const col = REGION_COLOR[r.kind] || '#ffffff', rr = ((r.w_dm || 0) ? M.wm(s, r.w_dm) : s.nest.r_dm / 10) * V.ppm, P = r.pts.map(([x, y]) => [M.wm(s, x), M.wm(s, y)]);
    ctx.globalAlpha = selIs('region', i) ? 0.38 : 0.2; ctx.strokeStyle = col; ctx.fillStyle = col; ctx.lineWidth = Math.max(2, rr * 2);
    if (P.length > 1) { strokePath(P); ctx.stroke(); }
    for (const [x, y] of P) { ctx.beginPath(); ctx.arc(wx2s(x), wy2s(y), Math.max(2, rr), 0, 7); ctx.fill(); }
    ctx.globalAlpha = 1;
    if (r.gate) { ctx.setLineDash([6, 6]); ctx.lineWidth = 2; ctx.strokeStyle = col; for (const [x, y] of P) { ctx.beginPath(); ctx.arc(wx2s(x), wy2s(y), Math.max(4, rr), 0, 7); ctx.stroke(); } ctx.setLineDash([]); }
  });
  // nest and lake
  ctx.lineWidth = 2; ctx.strokeStyle = '#ffd660'; ctx.beginPath(); ctx.arc(wx2s(0), wy2s(0), s.nest.r_dm / 10 * V.ppm, 0, 7); ctx.stroke();
  ctx.strokeStyle = '#7fc4ff'; ctx.beginPath(); ctx.arc(wx2s(s.nest.lake.x_dm / 10), wy2s(s.nest.lake.y_dm / 10), s.nest.lake.r_dm / 10 * V.ppm, 0, 7); ctx.stroke();
  ctx.setLineDash([8, 8]); ctx.strokeStyle = '#ffffff55'; ctx.beginPath(); ctx.arc(wx2s(0), wy2s(0), s.island_radius_dm / 10 * V.ppm, 0, 7); ctx.stroke(); ctx.setLineDash([]);
  if (A.layers.features) s.features.forEach((f, i) => {
    const col = FEAT_COLOR[f.kind] || '#fff', on = selIs('feature', i);
    ctx.strokeStyle = col; ctx.fillStyle = col; ctx.lineWidth = on ? 3.5 : 1.8;
    if (f.pts) {
      const P = polyWorld(f), line = f.spline ? crSample(P) : P;
      if (on) { ctx.globalAlpha = 0.22; ctx.lineWidth = Math.max(4, P[0][2] * 2 * V.ppm); strokePath(line); ctx.stroke(); ctx.globalAlpha = 1; ctx.lineWidth = 3.5; }
      if (f.kind === 'channel') ctx.setLineDash([9, 5]);
      strokePath(line); ctx.stroke(); ctx.setLineDash([]);
    } else if (f.kind === 'ring') { ctx.beginPath(); ctx.arc(wx2s(0), wy2s(0), f.r_dm / 10 * V.ppm, 0, 7); ctx.stroke(); }
    else {
      const c = M.centreOf(s, f), rk = M.RADIUS_KEY[f.kind], r = rk ? M.wm(s, f[rk]) * V.ppm : 6;
      if (f.kind === 'massif') { ctx.save(); ctx.translate(wx2s(c[0]), wy2s(c[1])); ctx.rotate((f.axis_mdeg || 0) / 1000 * Math.PI / 180); ctx.beginPath(); ctx.ellipse(0, 0, M.wm(s, f.along_dm) * V.ppm, M.wm(s, f.across_dm) * V.ppm, 0, 0, 7); ctx.restore(); ctx.stroke(); }
      else { ctx.beginPath(); ctx.arc(wx2s(c[0]), wy2s(c[1]), r, 0, 7); ctx.stroke(); if (on) { ctx.globalAlpha = 0.12; ctx.fill(); ctx.globalAlpha = 1; } }
    }
  });
  if (A.layers.routes) s.trails.forEach((t, i) => {
    const P = t.pts.map(([x, y]) => [M.wm(s, x), M.wm(s, y)]), on = selIs('trail', i);
    ctx.lineWidth = on ? 5 : 3; ctx.strokeStyle = '#141414'; strokePath(P); ctx.stroke();
    ctx.lineWidth = on ? 3 : 1.6; ctx.strokeStyle = t.kind === 'exit' ? '#ffe9a0' : '#9fe0a0'; strokePath(P); ctx.stroke();
  });
  if (A.res.shape || A.res.full) drawRoutes();
  if (A.layers.labels) drawLabels();
  A.handles = A.layers.handles ? buildHandles() : [];
  const order = A.handles.slice().sort((a, b) => (isSelH(a) ? 1 : 0) - (isSelH(b) ? 1 : 0));
  for (const h of order) {
    const x = wx2s(h.wx), y = wy2s(h.wy); if (x < -20 || y < -20 || x > W + 20 || y > H + 20) continue;
    const on = isSelH(h), pt = A.sel && A.sel.type === h.sel.type && A.sel.i === h.sel.i && A.sel.k === h.sel.k && h.sel.k != null, r = h.role === 'radius' ? 6 : pt ? 9 : on ? 7 : 5;
    ctx.beginPath(); if (h.role === 'radius') ctx.rect(x - r, y - r, 2 * r, 2 * r); else ctx.arc(x, y, r, 0, 7);
    ctx.fillStyle = pt ? '#edc578' : on ? '#fff' : h.color; ctx.globalAlpha = on || pt ? 1 : 0.85; ctx.fill(); ctx.globalAlpha = 1; ctx.lineWidth = 1.5; ctx.strokeStyle = '#111'; ctx.stroke();
  }
  if (A.tool === 'paint' && A.hover) { ctx.lineWidth = 1.5; ctx.strokeStyle = '#fff'; ctx.beginPath(); ctx.arc(A.hover[0], A.hover[1], A.brush.radius * V.ppm, 0, 7); ctx.stroke(); }
}
const isSelH = (h) => A.sel && A.sel.type === h.sel.type && A.sel.i === h.sel.i;
function drawGrid(size) {
  const V = A.view, step = V.ppm * 1000 > 40 ? 1000 : 2000; ctx.lineWidth = 1; ctx.strokeStyle = '#ffffff1c'; ctx.fillStyle = '#ffffff70'; ctx.font = '10px system-ui';
  for (let m = -size / 2; m <= size / 2 + 1; m += step) {
    ctx.beginPath(); ctx.moveTo(wx2s(m), wy2s(-size / 2)); ctx.lineTo(wx2s(m), wy2s(size / 2)); ctx.moveTo(wx2s(-size / 2), wy2s(m)); ctx.lineTo(wx2s(size / 2), wy2s(m)); ctx.stroke();
    if (Math.abs(m) % 2000 < 1) ctx.fillText(`${m / 1000} km`, wx2s(m) + 3, wy2s(-size / 2) + 11);
  }
  ctx.strokeStyle = '#ffffff55'; ctx.strokeRect(wx2s(-size / 2), wy2s(-size / 2), size * V.ppm, size * V.ppm);
}
function drawRoutes() {
  const r = A.shown; if (!r || !r.stats.route_paths) return;
  r.stats.route_paths.forEach((p, i) => {
    if (!p) return;
    ctx.lineWidth = 2.4; ctx.strokeStyle = 'rgba(255,245,200,.95)'; strokePath(p); ctx.stroke();
    void i;
  });
}
function drawLabels() {
  ctx.font = '600 11px system-ui'; ctx.textBaseline = 'middle';
  const tag = (txt, x, y, col = '#eee') => { const w = ctx.measureText(txt).width + 8; ctx.fillStyle = '#0e1114c8'; ctx.fillRect(x, y - 8, w, 16); ctx.fillStyle = col; ctx.fillText(txt, x + 4, y); };
  const s = A.s;
  s.regions.forEach((r) => { const p = r.pts[r.pts.length >> 1], x = wx2s(M.wm(s, p[0])), y = wy2s(M.wm(s, p[1])); if (x > -80 && y > -20 && x < W + 80 && y < H + 20) tag(r.name, x - 20, y, '#ddd'); });
  s.marks.forEach((m) => { const x = wx2s(M.wm(s, m.x_dm)), y = wy2s(M.wm(s, m.y_dm)); if (A.view.ppm > 0.05) tag(m.name, x + 8, y - 12); });
  tag('NEST', wx2s(0) + 10, wy2s(0) - 18, '#ffd660');
}

// ---- hit testing and gestures ----------------------------------------------------------------------------------------------------
const hitRadius = (e) => (e.pointerType === 'mouse' ? 13 : 22);   // 44 px diameter for touch and pen
function hitHandle(sx, sy, R) {
  let best = null, bd = R * R;
  for (const h of A.handles) {
    const d = (wx2s(h.wx) - sx) ** 2 + (wy2s(h.wy) - sy) ** 2, bias = isSelH(h) ? 0.7 : 1;
    if (d * bias < bd) { bd = d * bias; best = h; }
  }
  return best;
}
function segDist(px, py, a, b) { const sx = b[0] - a[0], sy = b[1] - a[1], l2 = sx * sx + sy * sy, u = l2 ? clamp(((px - a[0]) * sx + (py - a[1]) * sy) / l2, 0, 1) : 0; return Math.hypot(px - a[0] - u * sx, py - a[1] - u * sy); }
function hitObject(sx, sy) {
  const s = A.s, cands = [], S = (x, y) => [wx2s(x), wy2s(y)];
  s.features.forEach((f, i) => {
    if (f.pts) { const P = polyWorld(f).map((p) => S(p[0], p[1])); let d = 1e9; for (let k = 0; k + 1 < P.length; k++) d = Math.min(d, segDist(sx, sy, P[k], P[k + 1])); cands.push({ d, sel: { type: 'feature', i, k: null } }); }
    else if (f.kind === 'ring') cands.push({ d: Math.abs(Math.hypot(sx - wx2s(0), sy - wy2s(0)) - f.r_dm / 10 * A.view.ppm), sel: { type: 'feature', i, k: null } });
    else { const c = M.centreOf(s, f), [x, y] = S(c[0], c[1]), rk = M.RADIUS_KEY[f.kind], r = rk ? M.wm(s, f[rk]) * A.view.ppm : 0; cands.push({ d: Math.abs(Math.hypot(sx - x, sy - y) - r) * 0.7, sel: { type: 'feature', i, k: null } }); }
  });
  s.trails.forEach((t, i) => { const P = t.pts.map(([x, y]) => S(M.wm(s, x), M.wm(s, y))); let d = 1e9; for (let k = 0; k + 1 < P.length; k++) d = Math.min(d, segDist(sx, sy, P[k], P[k + 1])); cands.push({ d: d + 4, sel: { type: 'trail', i, k: null } }); });
  s.regions.forEach((r, i) => { const P = r.pts.map(([x, y]) => S(M.wm(s, x), M.wm(s, y))), rad = ((r.w_dm ? M.wm(s, r.w_dm) : s.nest.r_dm / 10) * A.view.ppm); let d = 1e9; if (P.length === 1) d = Math.hypot(sx - P[0][0], sy - P[0][1]); for (let k = 0; k + 1 < P.length; k++) d = Math.min(d, segDist(sx, sy, P[k], P[k + 1])); if (d < rad) cands.push({ d: 14 + d * 0.01, sel: { type: 'region', i, k: null } }); });
  let best = null; for (const c of cands) if (c.d < 20 && (!best || c.d < best.d)) best = c;
  return best && best.sel;
}

const G = { ptrs: new Map(), mode: null, handle: null, longTimer: 0, moved: false, startT: 0, pinch: null, last: null, strokeOpen: false };
const sPos = (e) => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
cv.addEventListener('pointerdown', (e) => {
  if (e.pointerType === 'mouse' && e.button === 2) return;
  cv.setPointerCapture(e.pointerId); cv.focus({ preventScroll: true });
  G.ptrs.set(e.pointerId, sPos(e));
  if (G.ptrs.size === 2) { cancelSingle(); const [a, b] = [...G.ptrs.values()]; G.mode = 'pinch'; G.pinch = { d: Math.hypot(a[0] - b[0], a[1] - b[1]) || 1, mx: (a[0] + b[0]) / 2, my: (a[1] + b[1]) / 2, ppm: A.view.ppm, cx: A.view.cx, cy: A.view.cy }; return; }
  if (G.ptrs.size > 2) return;
  const [x, y] = sPos(e); G.moved = false; G.startT = performance.now(); G.start = [x, y]; G.last = [x, y];
  if (A.tool === 'paint') { G.mode = 'paint'; beginStroke(); paintAt(x, y); return; }
  const h = hitHandle(x, y, hitRadius(e));
  if (h) { G.mode = 'drag'; G.handle = h; selectSel(h.sel); return; }
  G.mode = 'pan'; G.pan = { cx: A.view.cx, cy: A.view.cy };
  G.longTimer = setTimeout(() => { if (!G.moved && G.mode === 'pan') { G.mode = 'long'; navigator.vibrate && navigator.vibrate(10); addPointAt(sx2w(x), sy2w(y)); } }, 500);
});
cv.addEventListener('pointermove', (e) => {
  const p = sPos(e); A.hover = p;
  if (!G.ptrs.has(e.pointerId)) { hud(p); if (A.tool === 'paint') requestDraw(); return; }
  G.ptrs.set(e.pointerId, p);
  if (G.mode === 'pinch' && G.ptrs.size >= 2) {
    const [a, b] = [...G.ptrs.values()], d = Math.hypot(a[0] - b[0], a[1] - b[1]) || 1, mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2, q = G.pinch;
    A.view.ppm = clamp(q.ppm * d / q.d, 0.02, 12);
    const wxq = (q.mx - W / 2) / q.ppm + q.cx, wyq = (q.my - H / 2) / q.ppm + q.cy;   // the world point under the first midpoint stays under the midpoint now
    A.view.cx = wxq - (mx - W / 2) / A.view.ppm; A.view.cy = wyq - (my - H / 2) / A.view.ppm; requestDraw(); return;
  }
  const dx = p[0] - G.start[0], dy = p[1] - G.start[1];
  if (!G.moved && Math.hypot(dx, dy) > (e.pointerType === 'mouse' ? 3 : 8)) { G.moved = true; clearTimeout(G.longTimer); }
  if (G.mode === 'drag' && G.moved) { const x = sx2w(p[0]), y = sy2w(p[1]); live(() => G.handle.move(x, y)); G.handle.wx = x; G.handle.wy = y; syncInspector(); hud(p); }
  else if (G.mode === 'pan' && G.moved) { A.view.cx = G.pan.cx - dx / A.view.ppm; A.view.cy = G.pan.cy - dy / A.view.ppm; requestDraw(); }
  else if (G.mode === 'paint') { paintTo(p[0], p[1]); }
  hud(p);
});
function cancelSingle() { clearTimeout(G.longTimer); if (G.mode === 'drag') endLive(); if (G.mode === 'paint') endStroke(); G.handle = null; G.mode = null; }
const up = (e) => {
  if (!G.ptrs.has(e.pointerId)) return;
  G.ptrs.delete(e.pointerId); clearTimeout(G.longTimer);
  if (G.mode === 'pinch') { if (G.ptrs.size < 2) { G.mode = null; const [only] = [...G.ptrs.keys()]; if (only !== undefined) { G.ptrs.clear(); } } return; }
  const mode = G.mode; G.mode = null;
  if (mode === 'drag') endLive();
  else if (mode === 'paint') endStroke();
  else if (mode === 'pan' && !G.moved && performance.now() - G.startT < 450) tapAt(G.start[0], G.start[1]);
  G.handle = null;
};
cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
cv.addEventListener('pointerleave', () => { A.hover = null; $('hud').textContent = ''; if (A.tool === 'paint') requestDraw(); });
cv.addEventListener('wheel', (e) => { e.preventDefault(); const [x, y] = sPos(e), w = [sx2w(x), sy2w(y)]; A.view.ppm = clamp(A.view.ppm * Math.exp(-e.deltaY * 0.0012), 0.02, 12); A.view.cx = w[0] - (x - W / 2) / A.view.ppm; A.view.cy = w[1] - (y - H / 2) / A.view.ppm; requestDraw(); }, { passive: false });
cv.addEventListener('contextmenu', (e) => e.preventDefault());
function zoomBy(f) { const c = [W / 2, (H - insetBottom()) / 2]; const w = [sx2w(c[0]), sy2w(c[1])]; A.view.ppm = clamp(A.view.ppm * f, 0.02, 12); A.view.cx = w[0] - (c[0] - W / 2) / A.view.ppm; A.view.cy = w[1] - (c[1] - H / 2) / A.view.ppm; requestDraw(); }
$('zin').onclick = () => zoomBy(1.5); $('zout').onclick = () => zoomBy(1 / 1.5); $('zfit').onclick = fitView;

function tapAt(x, y) {
  if (A.tool === 'add') { addPointAt(sx2w(x), sy2w(y)); return; }
  const sel = hitObject(x, y);
  selectSel(sel);
}
function addPointAt(wx, wy) {
  const sel = A.sel;
  if (!sel || !M.pointsOf(A.s, sel)) { toast('Select a range, channel, trail or region first, then long press the map to add a point.'); return; }
  let at = -1;
  edit(() => { at = M.addPoint(A.s, sel, wx, wy); });
  A.sel = { ...sel, k: at }; renderEdit(); requestDraw();
}
function hud(p) {
  const r = A.shown; if (!r) return;
  const x = sx2w(p[0]), y = sy2w(p[1]), size = r.size, i = Math.floor((x + size / 2) / size * r.n), j = Math.floor((y + size / 2) / size * r.n);
  if (i < 0 || j < 0 || i >= r.n || j >= r.n) { $('hud').textContent = ''; return; }
  const k = j * r.n + i, h = r.height[k], cl = ['sea', 'walk', 'steep', 'climb', 'cliff', 'shallow'][r.cls[k]];
  $('hud').textContent = `${x.toFixed(0)}, ${y.toFixed(0)} m · h ${h.toFixed(1)} m · ${cl}${r.reach[k] ? (r.reach[k] === 1 ? ' · reach: walk' : ' · reach: climb') : ''}`;
}

// ---- mask painting ---------------------------------------------------------------------------------------------------------------
function beginStroke() { A.hist.push(A.s); A.s.maskData[A.brush.slot] = A.s.maskData[A.brush.slot].slice(); G.strokeOpen = true; G.strokeChanged = false; }
function paintAt(x, y) {
  const b = A.brush, w = [sx2w(x), sy2w(y)];
  if (M.paintMask(A.s.maskData[b.slot], A.s.size_dm / 10, w[0], w[1], b.radius, b.strength, b.erase ? 128 : b.value)) { G.strokeChanged = true; A.maskImg = null; changed({ live: true }); }
  G.last = [x, y];
}
function paintTo(x, y) {
  const [lx, ly] = G.last, d = Math.hypot(x - lx, y - ly), step = Math.max(2, A.brush.radius * A.view.ppm / 4), n = Math.max(1, Math.ceil(d / step));
  for (let i = 1; i <= n; i++) paintAt(lx + (x - lx) * i / n, ly + (y - ly) * i / n);
  G.last = [x, y];
}
function endStroke() {
  if (!G.strokeOpen) return; G.strokeOpen = false;
  if (!G.strokeChanged) { A.hist.past.pop(); return; }   // a stroke that changed nothing leaves no undo step
  A.maskImg = null; changed();
}

// ---- keyboard ---------------------------------------------------------------------------------------------------------------------
document.addEventListener('keydown', (e) => {
  A.keyboard = true;
  const tag = (e.target.tagName || '').toLowerCase(), typing = tag === 'input' || tag === 'textarea' || tag === 'select';
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { if (typing && tag !== 'input') return; e.preventDefault(); e.shiftKey ? redo() : undo(); return; }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') { e.preventDefault(); redo(); return; }
  if (typing) return;
  if (e.key === 'Delete' || e.key === 'Backspace') { if (A.sel && A.sel.k != null && A.sel.k >= 0) { e.preventDefault(); deleteSelPoint(); } }
  else if (e.key === 'Escape') { selectSel(null); }
  else if (e.key === '+' || e.key === '=') zoomBy(1.3); else if (e.key === '-') zoomBy(1 / 1.3); else if (e.key === '0') fitView();
});
document.addEventListener('pointerdown', () => { A.keyboard = false; }, true);

// ---- the inspector: Edit tab --------------------------------------------------------------------------------------------------------
const bindings = [];
function selectSel(sel) {
  A.sel = sel ? { type: sel.type, i: sel.i, k: sel.k ?? null } : null; renderEdit(); requestDraw();
  if (sel && A.sel) { const sheet = $('sheet'); if (sheet.classList.contains('peek') && !matchMedia('(min-width:900px)').matches) setSheet(true); showTab('edit'); }
}
function selObj() {
  const s = A.sel; if (!s) return null;
  if (s.type === 'feature') return A.s.features[s.i]; if (s.type === 'trail') return A.s.trails[s.i]; if (s.type === 'region') return A.s.regions[s.i]; if (s.type === 'mark') return A.s.marks[s.i]; return null;
}
// One numeric field: a slider and a number box that edit the same integer, plus the world-metre echo.
function numField({ label, get, set, min, max, unit, wkind, step = 1, noSlider = false }) {
  const num = el('input', { type: 'number', step, min, max, inputmode: 'numeric', 'aria-label': `${label} (${unit})` }), rng = noSlider ? null : el('input', { type: 'range', min, max, step: Math.max(1, Math.round((max - min) / 400)), 'aria-label': `${label} slider` });
  const echo = el('span', { class: 'echo' });
  const show = () => { const v = get(); if (document.activeElement !== num) num.value = v; if (rng) rng.value = v; const w = wkind ? M.worldValue(A.s, wkind, v) : null; echo.textContent = w == null ? '' : `${unit}  =  ${M.worldToStr(w)} ${wkind === 'deg' ? 'deg' : 'm'}${wkind === 'len' ? ' in the world' : ''}`; if (w == null) echo.textContent = unit; };
  const apply = (v) => { if (!Number.isFinite(v)) return; live(() => set(Math.round(v))); show(); };
  num.addEventListener('input', () => { if (num.value !== '' && !Number.isNaN(+num.value)) apply(+num.value); });
  num.addEventListener('change', () => { if (num.value === '') { show(); return; } const v = clamp(Math.round(+num.value), min, max); live(() => set(v)); endLive(); show(); });
  if (rng) { rng.addEventListener('input', () => apply(+rng.value)); rng.addEventListener('change', () => { endLive(); show(); }); }
  bindings.push(show); show();
  return el('label', { class: 'f' + (rng ? '' : ' nr') }, el('span', { class: 'k', text: label }), rng || num, rng ? num : null, echo);
}
function textField({ label, get, set, options, maxlength = 31 }) {
  const inp = options ? el('select', { 'aria-label': label }, options.map(([v, t]) => el('option', { value: v, text: t }))) : el('input', { type: 'text', maxlength, 'aria-label': label, autocomplete: 'off', spellcheck: 'false' });
  const show = () => { if (document.activeElement !== inp) inp.value = get(); };
  inp.addEventListener(options ? 'change' : 'input', () => { const v = options && typeof options[0][0] === 'number' ? +inp.value : inp.value; if (!options && !/^[\x20-\x7e]*$/.test(v)) return; live(() => set(v)); if (options) endLive(); });
  inp.addEventListener('change', () => endLive());
  bindings.push(show); show();
  return el('label', { class: 'f nr' }, el('span', { class: 'k', text: label }), inp);
}
function checkField({ label, get, set }) {
  const c = el('input', { type: 'checkbox' });
  c.checked = !!get();
  c.addEventListener('change', () => edit(() => set(c.checked)));
  return el('label', { class: 'chk' }, c, label);
}
function syncInspector() { for (const f of bindings) f(); }
const typeName = { feature: 'Feature', trail: 'Trail', region: 'Region', mark: 'Mark', nest: 'Nest and lake' };

function renderEdit() {
  const root = $('p-edit'); bindings.length = 0; root.textContent = '';
  const s = A.s; if (!s) return;
  root.append(
    el('div', { class: 'row tools', role: 'group', 'aria-label': 'Tool' },
      toolBtn('select', 'Select'), toolBtn('add', 'Add point'), toolBtn('paint', 'Paint mask')),
  );
  if (A.tool === 'paint') root.append(paintPanel());
  else if (A.tool === 'add') root.append(el('p', { class: 'hint', text: A.sel && M.pointsOf(s, A.sel) ? 'Tap the map to add a point to the selected shape.' : 'Select a range, channel, trail or region from the list, then tap the map.' }));
  const sel = A.sel, o = selObj();
  if (sel && sel.type === 'nest') root.append(nestPanel());
  else if (o) root.append(objPanel(sel, o));
  else root.append(el('p', { class: 'hint', text: 'Tap a shape or a handle to edit it. Drag handles to reshape; long press the map to add a point to the selected shape; pinch to zoom, two fingers to pan.' }));
  const list = el('div', { class: 'list' });
  const item = (type, i, name, small) => el('button', { class: sel && sel.type === type && sel.i === i ? 'sel' : '', onclick: () => { selectSel({ type, i, k: null }); flyTo(type, i); } }, name || `(${type} ${i + 1})`, el('small', { text: small }));
  list.append(el('h2', { text: 'Shapes' }));
  s.features.forEach((f, i) => list.append(item('feature', i, f.name || `${f.kind} ${i + 1}`, f.kind)));
  list.append(el('h2', { text: 'Trails' })); s.trails.forEach((t, i) => list.append(item('trail', i, t.name || `trail ${i + 1}`, t.kind)));
  list.append(el('h2', { text: 'Regions' })); s.regions.forEach((r, i) => list.append(item('region', i, r.name, r.kind + (r.gate ? ' · gate' : ''))));
  list.append(el('h2', { text: 'Marks' })); s.marks.forEach((m, i) => list.append(item('mark', i, m.name, m.kind)));
  list.append(el('div', { class: 'row' }, el('button', { class: 'small', onclick: () => selectSel({ type: 'nest' }) }, 'Nest and lake')));
  root.append(el('details', { open: !o }, el('summary', { text: 'All shapes' }), list));
  root.append(addPanel());
}
function toolBtn(id, text) { return el('button', { 'aria-pressed': String(A.tool === id), onclick: () => { A.tool = id; cv.classList.toggle('paint', id === 'paint'); document.body.dataset.tool = id; renderEdit(); requestDraw(); } }, text); }
function flyTo(type, i) {
  const s = A.s; let p = null;
  if (type === 'feature') { const f = s.features[i]; const c = M.centreOf(s, f); p = c || (f.pts ? (() => { const P = polyWorld(f); const m = P[P.length >> 1]; return [m[0], m[1]]; })() : [0, 0]); }
  else if (type === 'trail' || type === 'region') { const q = s[type + 's'][i].pts[s[type + 's'][i].pts.length >> 1]; p = [M.wm(s, q[0]), M.wm(s, q[1])]; }
  else if (type === 'mark') p = [M.wm(s, s.marks[i].x_dm), M.wm(s, s.marks[i].y_dm)];
  if (!p) return;
  const sx = wx2s(p[0]), sy = wy2s(p[1]), vis = H - insetBottom();
  if (sx < 30 || sx > W - 30 || sy < 30 || sy > vis - 30) { A.view.cx = p[0]; A.view.cy = p[1] + insetBottom() / (2 * A.view.ppm); requestDraw(); }
}
function objPanel(sel, o) {
  const s = A.s, box = el('div'), title = typeName[sel.type];
  box.append(el('h2', { text: `${title}: ${o.name || ''}` }));
  box.append(textField({ label: 'Name', get: () => o.name || '', set: (v) => { o.name = v; } }));
  if (sel.type === 'feature') {
    for (const [key, label, unit, wk, lo, hi] of M.FIELDS[o.kind]) box.append(numField({ label, get: () => o[key], set: (v) => { o[key] = v; }, min: lo, max: hi, unit, wkind: wk }));
    if (o.pts) {
      if (o.kind === 'channel') { box.append(checkField({ label: 'Reaches the sea (beach at the end)', get: () => o.sea, set: (v) => { o.sea = v ? 1 : 0; if (!v) delete o.sea; } })); box.append(checkField({ label: 'River (floor cut 2 m deeper)', get: () => o.river, set: (v) => { o.river = v ? 1 : 0; if (!v) delete o.river; } })); }
      box.append(checkField({ label: 'Smooth curve (Catmull-Rom spline)', get: () => o.spline, set: (v) => { o.spline = v ? 1 : 0; if (!v) delete o.spline; } }));
    }
  } else if (sel.type === 'trail') {
    box.append(textField({ label: 'Kind', get: () => o.kind, set: (v) => { o.kind = v; }, options: M.TRAIL_KINDS.map((k) => [k, k]) }));
    box.append(el('p', { class: 'hint', text: o.kind === 'exit' ? 'An exit is descriptive: the Check tab asks that it can be walked.' : 'Routed through the terrain and graded walkable when generated.' }));
  } else if (sel.type === 'region') {
    box.append(textField({ label: 'Kind', get: () => o.kind, set: (v) => { o.kind = v; }, options: M.REGION_KINDS.map((k) => [k, k]) }));
    box.append(textField({ label: 'Biome', get: () => o.biome, set: (v) => { o.biome = v; }, options: M.BIOMES.map((k) => [k, k]) }));
    box.append(textField({ label: 'Gate', get: () => o.gate, set: (v) => { o.gate = v; }, options: [[0, 'open'], [1, 'climbers'], [2, 'swim or glide']] }));
    box.append(numField({ label: 'Width', get: () => o.w_dm, set: (v) => { o.w_dm = v; }, min: 0, max: 20000, unit: 'dm', wkind: 'len' }));
  } else if (sel.type === 'mark') {
    box.append(textField({ label: 'Kind', get: () => o.kind, set: (v) => { o.kind = v; }, options: M.MARK_KINDS.map((k) => [k, k]) }));
    box.append(numField({ label: 'x', get: () => o.x_dm, set: (v) => { o.x_dm = v; }, min: -40000, max: 40000, unit: 'dm', wkind: 'len' }));
    box.append(numField({ label: 'y', get: () => o.y_dm, set: (v) => { o.y_dm = v; }, min: -40000, max: 40000, unit: 'dm', wkind: 'len' }));
  }
  const pts = M.pointsOf(s, sel);
  if (pts) {
    box.append(el('h2', { text: `Points (${pts.length})` }));
    const chips = el('div', { class: 'chips' });
    pts.forEach((_, k) => chips.append(el('button', { 'aria-pressed': String(sel.k === k), class: 'small', onclick: () => { A.sel = { ...A.sel, k }; renderEdit(); requestDraw(); } }, String(k + 1))));
    box.append(chips);
    if (sel.k != null && pts[sel.k]) {
      const p = pts[sel.k], fields = sel.type === 'feature' ? M.POINT_FIELDS : M.POINT_FIELDS.slice(0, 2);
      fields.forEach(([key, label, unit, wk, lo, hi], q) => box.append(numField({ label: `${label} (point ${sel.k + 1})`, get: () => p[q], set: (v) => { p[q] = v; }, min: lo, max: hi, unit, wkind: wk })));
      box.append(el('div', { class: 'row' }, el('button', { class: 'danger', disabled: pts.length <= M.minPoints(sel), onclick: deleteSelPoint }, 'Delete point')));
    } else box.append(el('p', { class: 'hint', text: 'Tap a handle on the map or a number above to edit a point.' }));
  }
  if (sel.type !== 'region' || A.s.regions.length > 0) box.append(el('div', { class: 'row' }, el('button', { class: 'danger', onclick: deleteObject }, `Delete ${title.toLowerCase()}`)));
  return box;
}
function deleteSelPoint() {
  const sel = A.sel; if (!sel || sel.k == null) return;
  const pts = M.pointsOf(A.s, sel); if (!pts || pts.length <= M.minPoints(sel)) { toast(`A ${sel.type === 'region' ? 'region' : 'line'} keeps at least ${M.minPoints(sel)} point${M.minPoints(sel) > 1 ? 's' : ''}.`); return; }
  edit(() => M.deletePoint(A.s, sel, sel.k)); A.sel = { ...sel, k: Math.min(sel.k, pts.length - 1) }; renderEdit();
}
function deleteObject() {
  const sel = A.sel; if (!sel) return;
  edit(() => { A.s[sel.type + 's'].splice(sel.i, 1); }); A.sel = null; renderEdit();
}
function nestPanel() {
  const n = A.s.nest, L = n.lake, box = el('div');
  box.append(el('h2', { text: 'Nest valley' }));
  box.append(numField({ label: 'Nest radius', get: () => n.r_dm, set: (v) => { n.r_dm = v; }, min: 100, max: 8000, unit: 'dm (world)', wkind: 'wlen' }));
  box.append(numField({ label: 'Floor height', get: () => n.floor_cm, set: (v) => { n.floor_cm = v; }, min: 0, max: 20000, unit: 'cm', wkind: 'h' }));
  box.append(el('h2', { text: 'Lake' }));
  box.append(numField({ label: 'Lake x', get: () => L.x_dm, set: (v) => { L.x_dm = v; }, min: -5000, max: 5000, unit: 'dm (world)', wkind: 'wlen' }));
  box.append(numField({ label: 'Lake y', get: () => L.y_dm, set: (v) => { L.y_dm = v; }, min: -5000, max: 5000, unit: 'dm (world)', wkind: 'wlen' }));
  box.append(numField({ label: 'Lake radius', get: () => L.r_dm, set: (v) => { L.r_dm = v; }, min: 100, max: 4000, unit: 'dm (world)', wkind: 'wlen' }));
  box.append(numField({ label: 'Lake depth', get: () => L.depth_cm, set: (v) => { L.depth_cm = v; }, min: 0, max: 20000, unit: 'cm', wkind: 'h' }));
  return box;
}
function addPanel() {
  const box = el('details'), kinds = el('div', { class: 'row' });
  box.append(el('summary', { text: 'Add to the island' }), kinds);
  const where = () => [sx2w(W / 2), sy2w((H - insetBottom()) / 2)];
  for (const k of M.FEATURE_KINDS) kinds.append(el('button', { class: 'small', onclick: () => { const [x, y] = where(); edit(() => { A.s.features.push(M.newFeature(A.s, k, x, y)); }); selectSel({ type: 'feature', i: A.s.features.length - 1, k: null }); } }, k));
  kinds.append(el('button', { class: 'small', onclick: () => { const [x, y] = where(), X = M.dmOf(A.s, x), Y = M.dmOf(A.s, y); edit(() => { A.s.trails.push({ name: 'New trail', kind: 'game_trail', pts: [[X - 300, Y], [X + 300, Y]] }); }); selectSel({ type: 'trail', i: A.s.trails.length - 1, k: null }); } }, 'trail'));
  kinds.append(el('button', { class: 'small', onclick: () => { const [x, y] = where(), X = M.dmOf(A.s, x), Y = M.dmOf(A.s, y); edit(() => { A.s.regions.push({ name: 'New region', kind: 'forest', biome: 'jungle', gate: 0, w_dm: 2000, pts: [[X, Y]] }); }); selectSel({ type: 'region', i: A.s.regions.length - 1, k: null }); } }, 'region'));
  kinds.append(el('button', { class: 'small', onclick: () => { const [x, y] = where(); edit(() => { A.s.marks.push({ name: 'New mark', kind: 'peak', x_dm: M.dmOf(A.s, x), y_dm: M.dmOf(A.s, y) }); }); selectSel({ type: 'mark', i: A.s.marks.length - 1, k: null }); } }, 'mark'));
  return box;
}
function paintPanel() {
  const b = A.brush, box = el('div');
  box.append(el('h2', { text: 'Mask brush' }));
  box.append(textField({ label: 'Mask', get: () => b.slot, set: (v) => { b.slot = +v; A.maskImg = null; requestDraw(); }, options: M.MASK_KEYS.map((k, i) => [i, M.MASK_LABEL[k]]) }));
  const slider = (label, key, lo, hi, unit, step = 1) => { const num = el('input', { type: 'range', min: lo, max: hi, step, 'aria-label': label }), out = el('span', { class: 'echo', text: '' }); const show = () => { num.value = b[key]; out.textContent = `${key === 'strength' ? Math.round(b[key] * 100) : b[key]} ${unit}`; }; num.addEventListener('input', () => { b[key] = +num.value; show(); requestDraw(); }); show(); return el('label', { class: 'f nr' }, el('span', { class: 'k', text: label }), num, out); };
  box.append(slider('Radius', 'radius', 40, 1500, 'm'), slider('Strength', 'strength', 0.05, 1, '%', 0.05), slider('Value', 'value', 0, 255, '(128 = neutral)'));
  box.append(el('div', { class: 'row' }, el('button', { class: 'small', onclick: () => { b.value = 255; b.erase = false; renderEdit(); } }, 'High 255'), el('button', { class: 'small', onclick: () => { b.value = 0; b.erase = false; renderEdit(); } }, 'Low 0'),
    el('button', { class: 'small', 'aria-pressed': String(b.erase), onclick: () => { b.erase = !b.erase; renderEdit(); } }, 'Erase'),
    el('button', { class: 'small danger', onclick: () => edit(() => { A.s.maskData[b.slot] = new Uint8Array(M.MASK_RES * M.MASK_RES).fill(128); A.maskImg = null; }) }, 'Clear mask')));
  box.append(el('p', { class: 'hint', text: 'Paint with one finger; two fingers move the map. Orange is above neutral, blue below. Erase moves the value back to 128 (no effect).' }));
  return box;
}

// ---- Layers tab ----------------------------------------------------------------------------------------------------------------------
function renderLayers() {
  const root = $('p-layers'); root.textContent = '';
  const L = A.layers;
  const radio = (key, val, text) => el('button', { 'aria-pressed': String(L[key] === val), onclick: () => { L[key] = val; A.imgs = null; renderLayers(); requestDraw(); store.set(PREFS_KEY, JSON.stringify(L)); } }, text);
  root.append(el('h2', { text: 'Map' }), el('div', { class: 'row tools' }, radio('base', 'relief', 'Relief'), radio('base', 'slope', 'Slopes'), radio('base', 'reach', 'Reach')));
  root.append(el('p', { class: 'hint', text: L.base === 'slope' ? 'Green walk, yellow steep, orange climb (up to 51.6 degrees is walkable), red cliff, blue water.' : L.base === 'reach' ? 'Green: a plain body walks there from the nest. Purple: only with climbing parts. Red: land neither reaches.' : 'Shaded relief, as the design maps.' }));
  root.append(el('h2', { text: 'Overlays' }));
  const chk = (key, text) => { const c = el('input', { type: 'checkbox' }); c.checked = !!L[key]; c.addEventListener('change', () => { L[key] = c.checked; requestDraw(); store.set(PREFS_KEY, JSON.stringify(L)); }); return el('label', { class: 'chk' }, c, text); };
  root.append(chk('features', 'Shapes (ranges, channels, massifs, plateaus)'), chk('regions', 'Regions and gates'), chk('routes', 'Trails'), chk('marks', 'Marks'), chk('labels', 'Labels'), chk('grid', 'Grid (1 km)'), chk('handles', 'Handles'));
  root.append(el('h2', { text: 'Mask overlay' }));
  const mchk = el('input', { type: 'checkbox' }); mchk.checked = !!L.masks; mchk.addEventListener('change', () => { L.masks = mchk.checked; requestDraw(); });
  root.append(el('label', { class: 'chk' }, mchk, 'Show a mask on the map'));
  const msel = el('select', { class: 'inp', 'aria-label': 'Mask to show' }, M.MASK_KEYS.map((k, i) => el('option', { value: i, text: M.MASK_LABEL[k] })));
  msel.value = L.maskSlot ?? 1; msel.addEventListener('change', () => { L.maskSlot = +msel.value; A.maskImg = null; requestDraw(); });
  root.append(msel);
}

// ---- Check tab ----------------------------------------------------------------------------------------------------------------------------
function renderCheck() {
  const root = $('p-check'), r = A.shown; root.textContent = '';
  if (!r) { root.append(el('p', { class: 'hint', text: 'Waiting for the first preview.' })); return; }
  const rules = A.validation, bad = rules.filter((x) => !x.ok).length, dot = $('checkdot');
  dot.className = 'dot ' + (bad ? 'bad' : 'ok');
  const lv = r.level === 'shape' ? `Shape ${r.n}: no erosion yet, numbers are rough` : r.level === 'full' ? `Eroded ${r.n}` : `Baked ${r.n}`;
  root.append(el('p', { class: 'hint', text: `${lv}${r.rev !== A.rev ? ' (an edit is still being generated)' : ''}. Rules from the A83 and A95 guarantees.` }));
  for (const x of rules) root.append(el('div', { class: 'rule ' + (x.ok ? 'ok' : 'bad'), 'data-rule': x.id }, el('i'), el('b', { text: x.label }), el('span', {}, el('span', { class: 'v', text: x.value }), ' · ', x.target)));
  const st = r.stats;
  root.append(el('h2', { text: 'Numbers' }), el('table', { class: 'kv' },
    el('tr', {}, el('td', { text: 'Land' }), el('td', { text: `${st.land_km2.toFixed(2)} km2` })),
    el('tr', {}, el('td', { text: 'Reach from the nest' }), el('td', { text: `${st.plain_reach_pct}% walking, ${st.climb_reach_pct}% climbing` })),
    el('tr', {}, el('td', { text: 'Nest flat' }), el('td', { text: `${(st.valley_flat * 100).toFixed(1)}% of ${st.valley_flat_n} cells` })),
    ...st.regions.map((g) => el('tr', {}, el('td', { text: g.name }), el('td', { text: `walk ${g.plain_pct}%, climb-only ${g.climb_only_pct}% · core ${g.core_plain_pct}% / ${g.core_climb_only_pct}%` })))));
}

// ---- Island tab: hashes, seed, bake, save and load -------------------------------------------------------------------------------------
function nativeStatus() {
  const r = A.shown, e = A.expected;
  if (!r || !e) return { cls: '', text: 'no native reference loaded' };
  if (r.rev !== A.rev) return { cls: '', text: 'updating' };
  if (r.descHash !== e.desc_hash) return { cls: '', text: 'edited: no stored native hash. Check it with the command below.' };
  const hit = e.entries.find((x) => x.seed === A.seed && x.n === r.n && x.mode === r.level);
  if (!hit) return { cls: '', text: `the committed island, seed ${A.seed}: no stored native hash for this level` };
  return hit.hash === r.terrainHash ? { cls: 'ok', text: `matches native build ${e.git}` } : { cls: 'bad', text: `DIFFERS from native build ${e.git} (${hit.hash})` };
}
function renderChip() {
  const r = A.shown, c = $('chip');
  if (!r) { c.className = ''; c.textContent = A.ready ? 'generating the first preview' : 'loading the C terrain (WASM)'; return; }
  const ns = nativeStatus(), lv = r.level === 'shape' ? `shape ${r.n}` : r.level === 'full' ? `eroded ${r.n}` : `bake ${r.n}`;
  c.className = ns.cls; c.replaceChildren(el('b', { text: lv }), ` · ${r.seconds.toFixed(2)} s${r.rev !== A.rev ? ' · updating' : ''}${ns.cls === 'ok' ? ' · native match' : ns.cls === 'bad' ? ' · native MISMATCH' : ' · ' + r.terrainHash.slice(0, 8)}`);
}
let islandInfo;
function renderIslandTab() {
  const root = $('p-island'); root.textContent = '';
  const s = A.s; if (!s) return;
  islandInfo = el('div'); root.append(islandInfo);
  root.append(el('h2', { text: 'Preview' }));
  root.append(textField({ label: 'Seed', get: () => A.seed, set: (v) => { A.seed = Math.max(0, Math.min(4294967295, Math.round(+v) || 0)); }, maxlength: 10 }));
  const bakeRow = el('div', { class: 'row' }, el('button', { id: 'bake', onclick: () => { send('bake'); toast('Baking in the worker, about 20 s.'); } }, 'Bake'), el('select', { class: 'inp', id: 'bake-n', 'aria-label': 'Bake size', style: 'width:auto' }, [768, 1024, 1536].map((n) => el('option', { value: n, text: `${n} x ${n}` }))));
  root.append(bakeRow); $('bake-n').value = A.bakeN; $('bake-n').onchange = (e) => { A.bakeN = +e.target.value; };
  root.append(el('p', { class: 'hint', text: 'Shape is the authored height without erosion, 256 x 256, while you drag. Eroded is the full pipeline at 512 when you let go. Bake runs the game size.' }));
  root.append(el('h2', { text: 'Save' }));
  root.append(el('div', { class: 'row' },
    el('button', { id: 'dl', onclick: downloadJSON }, 'Download island.json'), el('button', { id: 'copy', onclick: copyIsland }, 'Copy island'),
    el('button', { id: 'dl-isl', class: 'small', onclick: downloadBlob }, 'Download .isl')));
  root.append(el('p', { class: 'hint', text: 'The JSON is the island: integers only, one shape per line, so a git diff reads. It is saved as a draft in this browser after every edit.' }));
  const area = el('textarea', { class: 'inp', id: 'paste', placeholder: 'Paste island JSON here, then Load', spellcheck: 'false', 'aria-label': 'Island JSON' });
  const file = el('input', { type: 'file', accept: '.json,application/json', id: 'file', 'aria-label': 'Open island.json', onchange: async (e) => { const f = e.target.files[0]; if (f) loadText(await f.text()); e.target.value = ''; } });
  root.append(el('h2', { text: 'Load' }), file, area, el('div', { class: 'row' }, el('button', { id: 'load', onclick: () => loadText(area.value) }, 'Load pasted JSON'), el('button', { id: 'reset', class: 'danger', onclick: resetIsland }, 'Reset to Star massif')));
  root.append(el('h2', { text: 'Island' }));
  const F = (label, get, set, min, max, unit, wkind) => numField({ label, get, set, min, max, unit, wkind, noSlider: true });
  root.append(F('Map size', () => s.size_dm, (v) => { s.size_dm = v; }, 2000, 40000, 'dm', 'wlen'), F('Island radius', () => s.island_radius_dm, (v) => { s.island_radius_dm = v; }, 500, 40000, 'dm', 'wlen'), F('Design scale', () => s.scale_pm, (v) => { s.scale_pm = v; }, 500, 4000, 'pm'), F('Wind direction', () => s.wind.dir_mdeg, (v) => { s.wind.dir_mdeg = v; }, 0, 359999, 'mdeg', 'deg'), F('Wind speed', () => s.wind.speed_cms, (v) => { s.wind.speed_cms = v; }, 0, 3000, 'cm/s'));
  root.append(el('button', { class: 'small', onclick: () => { selectSel({ type: 'nest' }); showTab('edit'); } }, 'Edit nest and lake'));
  renderIslandInfo();
}
function renderIslandInfo() {
  if (!islandInfo) return;
  const r = A.shown, ns = nativeStatus(), e = A.expected;
  const rows = [['Desc hash', r ? r.descHash : '...'], ['Terrain hash', r ? r.terrainHash : '...'], ['Level', r ? `${r.level} ${r.n} x ${r.n}, seed ${A.seed}, ${r.seconds.toFixed(2)} s` : '...'], ['Native', null]];
  const native = el('td', {}, el('b', { class: ns.cls, text: ns.text, style: `color:${ns.cls === 'ok' ? 'var(--green)' : ns.cls === 'bad' ? 'var(--red)' : 'var(--dim)'}`, id: 'native-status' }));
  const cmd = r ? `terrain_cli hash --desc island.isl --seed ${A.seed} --n ${r.n}${r.level === 'shape' ? ' --base' : ''}` : '';
  islandInfo.replaceChildren(el('h2', { text: 'Hashes' }), el('table', { class: 'kv' }, ...rows.map(([k, v]) => el('tr', {}, el('td', { text: k }), k === 'Native' ? native : el('td', {}, el('code', { text: v, id: k === 'Desc hash' ? 'desc-hash' : k === 'Terrain hash' ? 'terrain-hash' : 'level-info' }))))), el('p', { class: 'hint' }, 'Native check: ', el('code', { text: cmd })), e ? el('p', { class: 'hint', text: `Committed island hashes stored from native build ${e.git}.` }) : null);
}
function downloadFile(name, data, type) { const a = el('a', { href: URL.createObjectURL(new Blob([data], { type })), download: name }); document.body.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 4000); }
function downloadJSON() { downloadFile('island.json', M.exportJSON(A.s), 'application/json'); toast('island.json downloaded'); }
function downloadBlob() { try { downloadFile('island.isl', M.packState(A.s), 'application/octet-stream'); toast('island.isl downloaded'); } catch (e) { showError(e.message); } }
async function copyIsland() {
  const text = M.exportJSON(A.s);
  try { await navigator.clipboard.writeText(text); toast('Island JSON copied'); return; } catch { /* fall through to the textarea */ }
  const ta = $('paste'); ta.value = text; ta.focus(); ta.select();
  try { document.execCommand('copy'); toast('Island JSON copied'); } catch { toast('Select the text below and copy it.'); }
}
function loadText(text) {
  let s; try { s = M.importJSON(text); } catch (e) { showError(e.message); return; }
  A.hist.push(A.s); A.s = s; A.sel = null; changed(); renderEdit(); renderIslandTab(); fitView(); toast('Island loaded');
}
async function resetIsland() { const s = M.importJSON(A.defaultJSON); A.hist.push(A.s); A.s = s; A.sel = null; changed(); renderEdit(); renderIslandTab(); toast('Back to the Star massif (undo brings your edit back)'); }

// ---- tabs and the bottom sheet ---------------------------------------------------------------------------------------------------------
function showTab(id) { for (const t of ['edit', 'layers', 'check', 'island']) { $('tab-' + t).setAttribute('aria-selected', String(t === id)); $('p-' + t).classList.toggle('on', t === id); } }
for (const t of ['edit', 'layers', 'check', 'island']) $('tab-' + t).addEventListener('click', () => { showTab(t); if ($('sheet').classList.contains('peek')) setSheet(true); });
function setSheet(open) { const sh = $('sheet'); sh.classList.toggle('instant', A.keyboard); sh.classList.toggle('peek', !open); setTimeout(() => { resize(); }, A.keyboard ? 0 : 230); }
$('grab').addEventListener('click', () => setSheet($('sheet').classList.contains('peek')));
$('undo').onclick = undo; $('redo').onclick = redo;

// ---- boot --------------------------------------------------------------------------------------------------------------------------------------
async function boot() {
  if (matchMedia('(max-width:599px)').matches) A.layers.labels = false;
  const prefs = store.get(PREFS_KEY); if (prefs) { try { Object.assign(A.layers, JSON.parse(prefs)); } catch { /* ignore */ } }
  A.defaultJSON = await (await fetch('island/star_massif.island.json')).text();
  try { A.expected = await (await fetch('island/expected.json')).json(); } catch { A.expected = null; }
  let s = null, restored = false;
  const draft = store.get(DRAFT_KEY);
  if (draft) { try { const d = JSON.parse(draft); s = M.importJSON(d.json); A.seed = d.seed || 1; restored = M.exportJSON(s) !== M.exportJSON(M.importJSON(A.defaultJSON)); } catch { s = null; } }
  A.s = s || M.importJSON(A.defaultJSON);
  document.body.dataset.tool = A.tool;
  renderEdit(); renderLayers(); renderIslandTab(); updateUndo(); resize(); A.fitted = true; fitView();
  if (restored) toast('Restored your last draft. Island tab, Reset, starts again from the Star massif.');
  if (matchMedia('(min-width:900px)').matches) setSheet(true);
  document.body.dataset.boot = 'ready';
}
// The API for the page that hosts the editor (an artifact store, a test): the island as JSON text and back.
window.IslandEditor = {
  exportJSON: () => M.exportJSON(A.s),
  importJSON: (text) => { const s = M.importJSON(text); A.hist.push(A.s); A.s = s; A.sel = null; changed(); renderEdit(); renderIslandTab(); fitView(); return true; },
  events, state: () => A.s, status: () => ({ rev: A.rev, shown: A.shown && { level: A.shown.level, rev: A.shown.rev, n: A.shown.n, terrainHash: A.shown.terrainHash, descHash: A.shown.descHash, stats: A.shown.stats }, validation: A.validation, errors: A.errors, native: nativeStatus(), busy: { ...A.busy } }),
  results: () => Object.fromEntries(Object.entries(A.res).map(([k, r]) => [k, r && { rev: r.rev, n: r.n, terrainHash: r.terrainHash, descHash: r.descHash, seconds: r.seconds }])),
  undo, redo, select: selectSel, tab: showTab, view: A.view, toWorld: (sx, sy) => [sx2w(sx), sy2w(sy)], toScreen: (x, y) => [wx2s(x), wy2s(y)], handles: () => A.handles.map((h) => ({ sel: h.sel, role: h.role, sx: wx2s(h.wx), sy: wy2s(h.wy) })),
  setSeed: (v) => { A.seed = v; changed(); }, bake: () => send('bake'),
};
boot().catch((e) => showError(`Could not start: ${e.message}`));
