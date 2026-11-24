// The terrain WASM (the C generator itself, apps/terrain_wasm_api.c) behind one call. Shared by the Worker and by node (editor_check).
//   const engine = await createEngine(createModule);   // createModule = the default export of wasm/cpore_terrain.mjs
//   engine.run({ blob, seed, n, mode })                // mode: 'shape' (no erosion) | 'full' (eroded)
// The numbers are the terrain CLI's defaults, so the hash equals `terrain_cli hash --desc F --seed S --n N [--base]`.
const P = { droplets: 80000, thermal: 8, stream: 48, warp: 240, ridge: 0.6, erosion: 0.3 };
export async function createEngine(createModule, moduleOptions = {}) {
  const m = await createModule(moduleOptions);
  const hex = (w) => m.HEAPU32[w + 1].toString(16).padStart(8, '0') + m.HEAPU32[w].toString(16).padStart(8, '0');
  return {
    module: m,
    maxN: 1536,
    run({ blob, seed = 1, n, mode = 'full', keep = ['height', 'river', 'material'] }) {
      const shape = mode === 'shape';
      if (blob.length > m._ct_desc_buf_size()) throw new Error('The island blob is larger than 256 KiB.');
      m.HEAPU8.set(blob, m._ct_desc_buf());
      const drc = m._ct_desc_set(blob.length);
      if (drc) throw new Error(`The island was refused by the C parser (${drc}).`);
      const rc = m._ct_config(seed, n, shape ? 0 : P.droplets, shape ? 0 : P.thermal, P.warp, P.ridge, P.erosion, shape ? 0 : P.stream);
      if (rc) throw new Error(`Invalid terrain parameters (${rc}).`);
      m._ct_deltas(0, 0, 1); m._ct_features(1, 1, 0, 1); m._ct_rivers(1);
      const t0 = performance.now();
      const r = shape ? m._ct_shape_desc() : m._ct_generate_desc();
      const seconds = (performance.now() - t0) / 1000;
      if (r) throw new Error(`Terrain generation failed (${r}).`);
      const nn = n * n, at = m._ct_map(0) >>> 2, out = { n, mode, seconds, size: m._ct_size(), terrainHash: hex(m._ct_hash() >>> 2), descHash: hex(m._ct_desc_hash() >>> 2) };
      if (keep.includes('height')) out.height = m.HEAPF32.slice(at, at + nn);
      if (keep.includes('river')) out.river = m.HEAPU8.slice(m._ct_river(), m._ct_river() + nn);
      if (keep.includes('material')) out.material = m.HEAPU8.slice(m._ct_material(), m._ct_material() + nn);
      return out;
    },
  };
}
