import assert from 'node:assert/strict';
import { readFileSync, readdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { Combat, LAYOUT, MOVE, VERB, defaultProfile } from '../web/engine/cpcombat.js';
import { profileFromStudio } from '../web/engine/profile.js';
import { Encounter } from '../web/engine/encounter.js';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const manifest = JSON.parse(read('../web/studio/parts.json'));
const StudioDocument = createRequire(import.meta.url)('../web/studio/genome.js');
const studioTypes = Object.fromEntries(manifest.parts.map(p => [p.id, p]));
const pair = (hp = 100) => ({ seed: 42, flat: true, creatures: [
  { profile: { ...defaultProfile(), hp }, x: 17, y: 20, fx: 1, fy: 0, team: 0 },
  { profile: { ...defaultProfile(), hp }, x: 23, y: 20, fx: -1, fy: 0, team: 1 },
] });
const engine = await Combat.create();
assert.equal(engine.module._cb_layout(0), LAYOUT.length);
for (let i = 0; i < LAYOUT.length; i++) assert.equal(engine.module._cb_layout(i + 1), LAYOUT[i], `ABI field ${i}`);
assert.throws(() => engine.assertLayout({ ...engine.module, _cb_layout: () => 999 }), /layout/);
for (const file of readdirSync(new URL('./fixtures/combat/', import.meta.url))) {
  const fixture = JSON.parse(read(`./fixtures/combat/${file}`));
  StudioDocument.validate(fixture.creature, studioTypes);
  assert.deepEqual(profileFromStudio(fixture.creature, manifest), fixture.expected, file);
}
const cosmetic = { schema: 'cpore.creature/4', parts: [{ type: 'sac_spitter' }] };
assert.equal(profileFromStudio(cosmetic, manifest).spit, 0);
assert.throws(() => profileFromStudio({ ...cosmetic, schema: 'bad' }, manifest), /schema/);
assert.throws(() => profileFromStudio({ ...cosmetic, parts: [{ type: 'missing' }] }, manifest), /part/);

let goldenTicks = 0;
for (const file of readdirSync(new URL('./golden/', import.meta.url)).filter(x => x.endsWith('.log'))) {
  const [seed, ...lines] = read(`./golden/${file}`).trim().split('\n');
  const expected = read(`./golden/${file.replace('.log', '.hashes')}`).trim().split('\n');
  engine.reset({ seed: Number(seed), flat: false, creatures: Array.from({ length: 8 }, (_, i) => ({
    profile: { ...defaultProfile(), hp: 100000 }, x: -1, y: -1, team: i % 2, medium: +(i % 3 === 0),
  })) });
  const log = lines.map(line => line.split(/\s+/).map(Number));
  let j = 0;
  for (let t = 0; t < expected.length; t++) {
    while (j < log.length && log[j][0] === t) {
      const [, id, verb, move, target, dir] = log[j++];
      assert.equal(engine.order(id, { verb, move, target, dir }), 0);
    }
    assert.equal(engine.step(), expected[t], `${file} tick ${t}`);
    goldenTicks++;
  }
  assert.equal(j, log.length);
}
console.log(`JS golden replays: 5 logs, ${goldenTicks} matching tick hashes`);

const other = await Combat.create();
engine.reset(pair(100000)); other.reset(pair(100000));
engine.botInit(1, 1, 123); other.botInit(1, 1, 123);
let eventCount = 0;
for (let t = 0; t < 600; t++) {
  for (const e of [engine, other]) {
    e.order(0, { verb: VERB.ATTACK, move: t % 3 ? MOVE.BITE : MOVE.SPIT, target: 1 });
    const action = e.botDecision(1, 0);
    if (action) e.order(1, action);
  }
  assert.equal(engine.step(), other.step());
  assert.deepEqual(engine.states(), other.states());
  assert.deepEqual(engine.events(), other.events());
  eventCount += engine.events().length;
}
assert.ok(eventCount > 0);
assert.ok(Number.isFinite(engine.preview(0, MOVE.BITE, 1).damage));
assert.throws(() => engine.reset({ ...pair(), creatures: [] }), /creatures/);
assert.throws(() => engine.order(256, { verb: VERB.IDLE }), /id/);
assert.equal(engine.module._cb_order(0, 256, 0, 1, 0), -3);
engine.reset(pair());
const before = engine.states()[0].x;
assert.equal(engine.order(0, { verb: VERB.MOVE, dir: 0 }), 0);
engine.step();
assert.ok(engine.states()[0].x > before);
assert.equal(engine.order(0, { verb: VERB.MOVE, dir: 8 }), -7);

// Validate all exposed queries and rejection paths before replaying encounters.
assert.equal(engine.preview(0, MOVE.SPIT, 1).reach, 6);
assert.throws(() => engine.preview(0, MOVE.BITE, 0), /target/);
assert.throws(() => engine.preview(9, MOVE.BITE, 1), /id/);
assert.throws(() => engine.botInit(0, 8, 0), /bot/);
assert.equal(engine.module._cb_bot_init(99, 0, 0, 0), -1);
assert.equal(engine.module._cb_bot_decide(0, 0), 0);
assert.equal(engine.module._cb_preview(0, 99, 1), 0);
assert.equal(engine.module._cb_layout(-1), -1);
assert.throws(() => engine.reset({ ...pair(), seed: -1 }), /seed/);
assert.throws(() => engine.reset({ ...pair(), creatures: [{ profile: { hp: NaN } }] }), /hp/);
assert.throws(() => engine.reset({ ...pair(), creatures: [{ profile: { mouth: 6 } }] }), /mouth/);
assert.throws(() => engine.reset({ ...pair(), creatures: [{ x: Infinity }] }), /spawn/);
assert.throws(() => engine.reset({ ...pair(), creatures: [{ medium: 2 }] }), /medium/);
const setupPointer = engine.module._cb_setup();
const setupBytes = engine.module.HEAPU8.slice(setupPointer, setupPointer + LAYOUT[1]);
engine.module.HEAPU8[setupPointer + 4] = 0;
assert.equal(engine.module._cb_reset(), -1);
engine.module.HEAPU8.set(setupBytes, setupPointer);
assert.throws(() => profileFromStudio({ ...cosmetic, parts: null }, manifest), /parts/);
assert.throws(() => profileFromStudio(cosmetic, {}), /manifest/);
// Size, spine and procedural decorations cannot grant levels.
const ignored = { ...cosmetic, parts: [{ type: 'ojo', size: 4 }], regions: [{ family: 'horns', count: 18 }] };
assert.equal(profileFromStudio(ignored, manifest).charge, 0);
const newRules = { schema: 'cpore.creature/4', parts: [{ type: 'new-mouth' }] };
assert.equal(profileFromStudio(newRules, { parts: [{ id: 'new-mouth', c_type: 'CP4_MOUTH_C', category: 'mouths' }] }).mouth, 2);

// Eight directional intents move in the documented absolute octants; zero
// stops, and a committed attack cannot be cancelled by a move order.
for (const [i, move] of [[1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0], [-1, 1], [0, 1], [1, 1]].entries()) {
  const e = new Encounter(engine, { point: { x: 0, z: 0 }, setup: pair(), enemyBot: 0 });
  const start = e.current[0];
  e.advance(.1, { move });
  assert.equal(e.log[0].dir, i);
  assert.equal(Math.sign(e.current[0].x - start.x), Math.sign(move[0]));
  assert.equal(Math.sign(e.current[0].y - start.y), Math.sign(move[1]));
  e.advance(.1, {});
  assert.equal(e.current[0].x, e.previous[0].x);
}
assert.throws(() => new Encounter(engine, { point: null, setup: pair() }), /point/);
assert.throws(() => new Encounter(engine, { point: { x: 0, z: 0 }, setup: pair(), enemy: 0 }), /distinct/);
const held = new Encounter(engine, { point: { x: 0, z: 0 }, setup: pair(100000), enemyBot: 0 });
held.advance(.5, { attack: MOVE.SPIT });
const committed = held.current[0].move;
held.advance(.1, { move: [1, 0] });
assert.equal(held.current[0].move, committed);
held.advance(.1, { dodge: true });
assert.equal(held.log.at(-1).dir, 0);
held.advance(.1, { dodge: false, attack: null });
assert.equal(held.log.at(-1).verb, VERB.IDLE);
assert.throws(() => held.advance(.1, { move: [NaN, 0] }), /vector/);

// Input is a time-indexed timeline: tick-boundary sampling cannot depend on render FPS.
const sequence = time => {
  const second = Math.floor(time + 1e-8) % 10;
  if (second < 2) return { move: [1, -1] };
  if (second < 4) return { attack: MOVE.SPIT };
  if (second === 4) return { guard: true };
  if (second === 5) return { dodge: 2 };
  if (second < 8) return { attack: MOVE.BITE };
  return { flee: true };
};
const runs = [];
for (const fps of [60, 37]) {
  const combat = await Combat.create();
  const encounter = new Encounter(combat, { point: { x: 101, z: -55 }, setup: pair(100000), enemyBot: 3 });
  assert.deepEqual(encounter.toArena(encounter.toValley({ x: 12, y: 27 })), { x: 12, y: 27 });
  for (let f = 0; f < 60 * fps; f++) encounter.advance(1 / fps, sequence);
  assert.equal(encounter.tick, 600);
  assert.ok(encounter.alpha >= 0 && encounter.alpha < 1);
  assert.equal(encounter.current.length, 2);
  assert.equal(encounter.previous.length, 2);
  assert.throws(() => encounter.advance(-1, {}), /delta/);
  runs.push(encounter);
}
assert.deepEqual(runs[0].log, runs[1].log);
assert.deepEqual(runs[0].hashes, runs[1].hashes);
const dir = mkdtempSync(join(tmpdir(), 'cpore-replay-'));
try {
  const file = join(dir, 'encounter.log');
  writeFileSync(file, runs[0].exportLog());
  const native = execFileSync('build/combat_parity', ['--replay', file], { encoding: 'utf8' }).trim().split('\n');
  assert.deepEqual(native, runs[0].hashes);
} finally { rmSync(dir, { recursive: true }); }
console.log('Instances: 600 identical ticks; encounters: 60 seconds at 60/37 FPS, 600 identical ticks and native replay');
