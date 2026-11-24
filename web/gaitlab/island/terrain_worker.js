// Web Worker: the real C terrain generator (WASM) plus the analysis, off the UI thread.
// Request:  { type: 'run', id, rev, level: 'shape' | 'full' | 'bake', blob, seed, n, meta, canopy }
// Reply:    { type: 'result', id, rev, level, n, size, seconds, terrainHash, descHash, height, cls, reach, rgba, shade, stats, analysisMs }
//           { type: 'progress', id, level, stage, done, total } | { type: 'error', id, message } | { type: 'ready' }
// Only the newest request of each level is answered: a request that is still queued when a newer one of its level arrives is dropped
// (reply { type: 'dropped', id }). Shape runs go first, then full, then bake.
import createModule from './wasm/cpore_terrain.mjs';
import { createEngine } from './engine.js';
import { analyse } from './analysis.js';
import { sampleMask } from './model.js';

let current = null;
const ready = createEngine(createModule, { onTerrainProgress: (stage, done, total) => { if (current) self.postMessage({ type: 'progress', id: current.id, level: current.level, stage, done, total }); } })
  .then((e) => { self.postMessage({ type: 'ready' }); return e; });
const pending = { shape: null, full: null, bake: null };
let draining = false;

self.onmessage = (ev) => {
  const m = ev.data;
  if (m.type !== 'run') return;
  if (pending[m.level]) self.postMessage({ type: 'dropped', id: pending[m.level].id });
  pending[m.level] = m;
  if (!draining) { draining = true; setTimeout(drain, 0); }   // let a burst of messages land, then take the newest
};

async function drain() {
  const engine = await ready;
  for (;;) {
    const m = pending.shape || pending.full || pending.bake;
    if (!m) break;
    pending[m.level] = null; current = m;
    try {
      const r = engine.run({ blob: m.blob, seed: m.seed, n: m.n, mode: m.level === 'shape' ? 'shape' : 'full' });
      const t0 = performance.now();
      const canopy = m.canopy ? (x, y) => sampleMask(m.canopy, r.size, x, y) : null;
      const a = analyse({ height: r.height, river: r.river, material: r.material, n: m.n, size: r.size, meta: m.meta, canopy });
      const analysisMs = performance.now() - t0;
      const out = { type: 'result', id: m.id, rev: m.rev, level: m.level, n: m.n, size: r.size, seconds: r.seconds, terrainHash: r.terrainHash, descHash: r.descHash,
        height: r.height, cls: a.cls, reach: a.reach, rgba: a.rgba, shade: a.shade, stats: a.stats, analysisMs };
      self.postMessage(out, [r.height.buffer, a.cls.buffer, a.reach.buffer, a.rgba.buffer, a.shade.buffer]);
    } catch (e) { self.postMessage({ type: 'error', id: m.id, level: m.level, message: String(e && e.message || e) }); }
    current = null;
    await new Promise((res) => setTimeout(res, 0));
  }
  draining = false;
}
