/* Shared rendering-free wrapper for Node parity and the browser Worker.
 * `url` lets the lab load another build of the same ABI (the phase-A module,
 * for before/after evidence); extra arguments to an older ct_config are ignored. */
export const DEFAULTS = Object.freeze({ seed: 1, n: 1024, stream: 48, droplets: 80000, thermal: 8,
  warp: 240, ridge: .6, erosion: .3, base: false, gentle: 1, variety: 1, bands: 1 });
export async function createTerrain(options = {}, url = '../../build/wasm/cpore_terrain.mjs') {
  const createModule = (await import(url)).default;
  const module = await createModule(options);
  return {
    module,
    generate(request = {}) {
      const { seed, n, stream, droplets, thermal, warp, ridge, erosion, base, gentle, variety, bands } = { ...DEFAULTS, ...request };
      if (!Number.isInteger(seed) || seed < 0 || seed > 0xffffffff) throw Error('Seed must be an integer from 0 to 4294967295.');
      if (!Number.isInteger(n) || n < 8 || n > 1024) throw Error('Map size must be an integer from 8 to 1024.');
      if (!Number.isInteger(droplets) || droplets < 0 || droplets > 2000000 ||
          !Number.isInteger(thermal) || thermal < 0 || thermal > 48 ||
          !Number.isInteger(stream) || stream < 0 || stream > 256 ||
          ![warp, ridge, erosion].every(Number.isFinite)) throw Error('Terrain parameters must be finite; work counts must be integers.');
      const rc = module._ct_config(seed, n, base ? 0 : droplets, base ? 0 : thermal, warp, ridge, erosion, base ? 0 : stream);
      if (rc) throw Error(`Invalid terrain parameters (${rc}).`);
      if (![gentle,variety,bands].every(v => Number.isFinite(v) && v >= 0 && v <= 1)) throw Error('Terrain deltas must be from 0 to 1.');
      if (module._ct_deltas && module._ct_deltas(gentle,variety,bands)) throw Error('Invalid terrain deltas.');
      const start = performance.now();
      const result = module._ct_generate();
      const seconds = (performance.now() - start) / 1000;
      if (result) throw Error(`Terrain generation failed (${result}).`);
      const words = module._ct_hash() >>> 2;
      const hash = module.HEAPU32[words + 1].toString(16).padStart(8, '0') + module.HEAPU32[words].toString(16).padStart(8, '0');
      const maps = [0, 1, 2, 3].map(layer => {
        const at = module._ct_map(layer) >>> 2;
        return at ? module.HEAPF32.slice(at, at + n * n) : null;
      });
      return { seed, n, size: module._ct_size ? module._ct_size() : 2000, version: module._ct_version(), base, gentle, variety, bands, hash, seconds,
        height: maps[0], flow: maps[1], sediment: maps[2], level: maps[3] || maps[0].slice() };
    },
  };
}
