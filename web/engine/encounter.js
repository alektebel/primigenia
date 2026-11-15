import { MOVE, VERB, defaultProfile } from './cpcombat.js';
export const CB_HZ = 10;
export const CB_ARENA_W = 40;
export const CB_ARENA_H = 40;
const DT = 1 / CB_HZ;

// Scale by the largest component first: finite subnormal/huge inputs are safe.
export function heading([x,y]) {
  if (!Number.isFinite(x)||!Number.isFinite(y)) throw new RangeError('move vector');
  const scale=Math.max(Math.abs(x),Math.abs(y));
  return scale?{hx:Math.round(x/scale*32767),hy:Math.round(y/scale*32767)}:null;
}
export class Encounter {
  constructor(combat, { point, setup, player = 0, enemy = 1, enemyBot = 3, enemySpamMove = MOVE.BITE }) {
    if (!Number.isFinite(point?.x) || !Number.isFinite(point?.z)) throw new RangeError('encounter point');
    if (setup.creatures.length !== 2 || ![player, enemy].every(i => Number.isInteger(i) && i >= 0 && i < 2) || player === enemy)
      throw new RangeError('encounter requires two distinct creatures');
    this.combat = combat;
    this.point = { ...point };
    this.setup = structuredClone(setup);
    this.player = player; this.enemy = enemy;
    combat.reset(this.setup);
    combat.botInit(enemy, enemyBot, (setup.seed + enemy) >>> 0, enemySpamMove);
    this.accumulator = 0;
    this.log = []; this.hashes = [];
    this.current = combat.states(); this.previous = combat.states();
    this.lastOrderError = 0;
  }
  get tick() { return this.combat.tick; }
  get alpha() { return this.accumulator / DT; }
  toValley({ x, y }) { return { x: this.point.x + x - 20, z: this.point.z + y - 20 }; }
  toArena({ x, z }) { return { x: x - this.point.x + 20, y: z - this.point.z + 20 }; }
  intentAction(intent) {
    // One standing order per tick. Defensive input wins over attack, then move.
    if (intent.flee) return { verb: VERB.FLEE, target: this.enemy };
    if (intent.dodge !== undefined && intent.dodge !== false) return { verb: VERB.DODGE, dir: intent.dodge === true ? 0 : intent.dodge };
    if (intent.guard) return { verb: VERB.GUARD };
    if (intent.attack !== undefined && intent.attack !== null) return { verb: VERB.ATTACK, move: intent.attack, target: this.enemy };
    const vector = heading(intent.move ?? [0, 0]);
    return vector === null ? { verb: VERB.IDLE } : { verb: VERB.MOVE, dir:-1, ...vector };
  }
  issue(id, action) {
    const full = { verb: action.verb, move: action.move ?? 0, target: action.target ?? -1, dir: action.dir ?? 0, hx:action.hx??0, hy:action.hy??0 };
    const result = this.combat.order(id, full);
    if (result === 0) this.log.push({ tick: this.tick, id, ...full });
    return result;
  }
  advance(delta, intent = {}) {
    if (!Number.isFinite(delta) || delta < 0) throw new RangeError('frame delta must be finite and nonnegative');
    const before = this.accumulator, startTick = this.tick;
    this.accumulator += delta;
    try { this.runTicks(intent); } catch (error) {
      // A rejected intent must not bank its frame time for the next call.
      this.accumulator = Math.max(0, before - (this.tick - startTick) * DT);
      throw error;
    }
    return this.current;
  }
  runTicks(intent) {
    // Never drop elapsed ticks. Callers pause by not advancing, rather than
    // clamping frame delta. A timeline sampler supplies the same tick inputs
    // even when one frame spans multiple ticks.
    while (this.accumulator + 1e-9 >= DT) {
      const sampled = typeof intent === 'function' ? intent(this.tick * DT, this.tick) : intent;
      this.lastOrderError = this.issue(this.player, this.intentAction(sampled));
      const enemyAction = this.combat.botDecision(this.enemy, this.player);
      if (enemyAction) this.issue(this.enemy, enemyAction);
      this.previous = this.current;
      this.hashes.push(this.combat.step());
      this.current = this.combat.states();
      this.accumulator = Math.max(0, this.accumulator - DT);
    }
  }
  exportLog() {
    const s = this.setup;
    const lines = ['CPORE_COMBAT_LOG 2', `${s.seed} ${s.creatures.length} ${s.flat ? 1 : 0} ${this.tick}`];
    s.creatures.forEach((c, i) => {
      const p = { ...defaultProfile(), ...c.profile };
      lines.push([p.mouth, p.charge, p.spit, p.tail, p.guard, p.hp, p.stamina, p.speed,
        c.x ?? -1, c.y ?? -1, c.fx ?? 0, c.fy ?? 0, c.medium ?? 0, c.team ?? i, p.radiusCm ?? 0].join(' '));
    });
    for (const a of this.log) lines.push([a.tick, a.id, a.verb, a.move, a.target, a.dir, a.hx, a.hy].join(' '));
    return lines.join('\n') + '\n';
  }
}
