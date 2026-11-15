/* Shared rendering-free wrapper for Node parity and the browser Worker. */
import createModule from '../../build/wasm/cpore_terrain.mjs';
export async function createTerrain(options = {}) {
  const module = await createModule(options);
  return {
    module,
    generate({ seed = 1, n = 1024, droplets = 70000, thermal = 5,
      warp = 280, ridge = .72, erosion = .32, base = false } = {}) {
      if (!Number.isInteger(seed) || seed < 0 || seed > 0xffffffff) throw Error('Seed must be an integer from 0 to 4294967295.');
      if (!Number.isInteger(n) || n < 8 || n > 1024) throw Error('Map size must be an integer from 8 to 1024.');
      if (!Number.isInteger(droplets) || droplets < 0 || droplets > 2000000 ||
          !Number.isInteger(thermal) || thermal < 0 || thermal > 48 ||
          ![warp, ridge, erosion].every(Number.isFinite)) throw Error('Terrain parameters must be finite; work counts must be integers.');
      const rc = module._ct_config(seed, n, base ? 0 : droplets, base ? 0 : thermal, warp, ridge, erosion);
      if (rc) throw Error(`Invalid terrain parameters (${rc}).`);
      const start = performance.now();
      const result = module._ct_generate();
      const seconds = (performance.now() - start) / 1000;
      if (result) throw Error(`Terrain generation failed (${result}).`);
      const words = module._ct_hash() >>> 2;
      const hash = module.HEAPU32[words + 1].toString(16).padStart(8, '0') + module.HEAPU32[words].toString(16).padStart(8, '0');
      const maps = [0, 1, 2].map(layer => {
        const at = module._ct_map(layer) >>> 2;
        return module.HEAPF32.slice(at, at + n * n);
      });
      return { seed, n, size: 2000, version: module._ct_version(), base, hash, seconds,
        height: maps[0], flow: maps[1], sediment: maps[2] };
    },
  };
}
