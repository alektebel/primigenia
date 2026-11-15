/* Headless winnability: a scripted player vs the valley predator, 50 seeds per fixture.
 * Uses the stage simulation and the C/WASM core. No browser. */
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { Combat, MOVE } from '../web/engine/cpcombat.js';
import { profileFromStudio } from '../web/engine/profile.js';
import { StageSimulation } from '../web/stage/simulation.js';

const manifest = JSON.parse(readFileSync('web/studio/parts.json', 'utf8'));
const enemyProfile = {
  ...profileFromStudio(JSON.parse(readFileSync('web/stage/species/garfio.json', 'utf8')), manifest),
  ...JSON.parse(readFileSync('web/stage/species/garfio-combat.json', 'utf8')),
};
const combat = await Combat.create();
const DURATION = { [MOVE.BITE]: 6, [MOVE.CHARGE]: 17, [MOVE.SPIT]: 11, [MOVE.TAIL]: 9 };

function policy(sim) {
  if (!sim.encounter) return { move: [sim.enemy.x - sim.player.x, sim.enemy.z - sim.player.z] };
  const foe = sim.encounter.current[1], me = sim.encounter.current[0];
  if (!foe.alive || !me.alive) return {};
  if (foe.phase === 1 && foe.move === MOVE.CHARGE) return { dodge: 2 };
  if (foe.phase === 1 && sim.profile.guard > 0) return { guard: true };
  if (foe.phase === 3) {
    const options = [];
    if (sim.profile.mouth > 0) options.push(MOVE.BITE);
    if (sim.profile.charge > 0) options.push(MOVE.CHARGE);
    if (sim.profile.spit > 0) options.push(MOVE.SPIT);
    if (sim.profile.tail > 0) options.push(MOVE.TAIL);
    let best = options[0] ?? MOVE.BITE, score = -1;
    for (const move of options) {
      const preview = sim.combat.preview(0, move, 1);
      const value = preview.damage / DURATION[move] * (preview.inReach ? 1.6 : 0.45);
      if (value > score) { score = value; best = move; }
    }
    return { attack: best };
  }
  return { move: [foe.x - me.x, foe.y - me.y] };
}

function fight(profile, seed) {
  const sim = new StageSimulation({
    combat, profile, enemyProfile, seed,
    nest: { x: 0, z: 0 }, home: { x: 0, z: 12 }, groundY: () => 2,
  });
  for (let t = 0; t < 900 && !sim.outcome; t++) sim.advance(0.1, () => policy(sim));
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
