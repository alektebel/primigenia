import { createTerrain } from './terrain.mjs';
/* engine "v1" is the phase-A module, built by hand into build/wasm-v1 for
 * before/after evidence. It runs with its own defaults, not this lab's. */
const V1 = { url: '../../build/wasm-v1/cpore_terrain.mjs', params: { droplets: 70000, thermal: 5, warp: 280, ridge: .72, erosion: .32 } };
const engines = {};
self.onmessage = async ({ data }) => {
  try {
    const { engine: name = 'current', ...request } = data;
    const progress = { onTerrainProgress: (stage, done, total) => self.postMessage({type:'progress',stage,done,total}) };
    engines[name] ??= await (name === 'v1' ? createTerrain(progress, V1.url) : name === 'v2' ? createTerrain(progress, '../../build/wasm-v2/cpore_terrain.mjs') : createTerrain(progress));
    const terrain=engines[name].generate(name === 'v1' ? { ...request, ...V1.params } : request);
    self.postMessage({type:'terrain',...terrain},[terrain.height.buffer,terrain.flow.buffer,terrain.sediment.buffer,terrain.level.buffer]);
  } catch(error) { self.postMessage({type:'error',message:error.message}); }
};
