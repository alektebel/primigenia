// Regenerates profile_expected.json from the web implementation (the source of truth):
//   node godot/game/tests/fixtures/gen_profile_expected.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { profileFromStudio } from '../../../../web/engine/profile.js';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '../../../..');
const read = p => JSON.parse(readFileSync(join(root, p), 'utf8'));
const manifest = read('web/studio/parts.json');
const out = {};
const cases = {
  merodeador: 'godot/game/data/merodeador.json',
  garfio: 'web/stage/species/garfio.json',
  studio_v4_glb_parts: 'tests/fixtures/studio/v4-glb-parts.json',
};
for (const [name, path] of Object.entries(cases)) {
  try { out[name] = { source: path, profile: profileFromStudio(read(path), manifest) }; }
  catch (e) { out[name] = { source: path, error: String(e.message) }; }
}
writeFileSync(join(here, 'profile_expected.json'), JSON.stringify(out, null, 2) + '\n');
