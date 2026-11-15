/* Headless winnability: a scripted player vs the valley predator, 50 seeds per fixture.
 * Uses the stage simulation and the C/WASM core. No browser. */
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { Combat } from '../web/engine/cpcombat.js';
import { profileFromStudio } from '../web/engine/profile.js';
import { StageSimulation } from '../web/stage/simulation.js';
import { stagePlayerPolicy } from './stage_policy.mjs';

const manifest = JSON.parse(readFileSync('web/studio/parts.json', 'utf8'));
const enemyProfile = {
  ...profileFromStudio(JSON.parse(readFileSync('web/stage/species/garfio.json', 'utf8')), manifest),
  ...JSON.parse(readFileSync('web/stage/species/garfio-combat.json', 'utf8')),
};
const combat = await Combat.create();

function fight(profile, seed) {
  const sim = new StageSimulation({
    combat, profile, enemyProfile, seed,
    nest: { x: 0, z: 0 }, home: { x: 0, z: 12 }, groundY: () => 2,
  });
  for (let t = 0; t < 900 && !sim.outcome; t++) sim.advance(0.1, () => stagePlayerPolicy(sim));
  return sim.outcome;
}

const files = ['biter.json', 'guard.json', 'spitter.json'];
console.log('enemy', enemyProfile);
let failed = false;
for (const file of files) {
  const fixture = JSON.parse(readFileSync(`tests/fixtures/combat/${file}`, 'utf8'));
  const profile = profileFromStudio(fixture.creature, manifest);
  assert.deepEqual(profile, fixture.expected, `${file} unchanged player projection`);
  const outcomes = { victory: 0, death: 0, fled: 0, none: 0 };
  for (let seed = 0; seed < 50; seed++) outcomes[fight(profile, seed) ?? 'none']++;
  assert.equal(outcomes.none, 0, `${file} every duel finishes within 90 seconds`);
  assert.equal(outcomes.fled, 0, `${file} policy completes the duel`);
  const rate = outcomes.victory / 50;
  const ok = rate >= 0.35 && rate <= 0.80;
  failed ||= !ok;
  console.log(`${file} player ${profile.mouth}/${profile.charge}/${profile.spit}/${profile.tail}/${profile.guard} hp ${profile.hp} r ${profile.radiusCm}: ${outcomes.victory}/50 = ${(rate * 100).toFixed(1)}% (${JSON.stringify(outcomes)}) ${ok ? 'OK' : 'OUT OF RANGE'}`);
}
if (failed) process.exit(1);
console.log('PASS winnability 35–80% on every fixture');
