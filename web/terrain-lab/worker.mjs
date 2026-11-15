import { createTerrain } from './terrain.mjs';
let engine;
self.onmessage = async ({ data }) => {
  try {
    engine ??= await createTerrain({ onTerrainProgress: (stage, done, total) => self.postMessage({type:'progress',stage,done,total}) });
    const terrain=engine.generate(data);
    self.postMessage({type:'terrain',...terrain},[terrain.height.buffer,terrain.flow.buffer,terrain.sediment.buffer]);
  } catch(error) { self.postMessage({type:'error',message:error.message}); }
};
