/* Plain ES module; serve the repository root so ../../build/wasm is available.
 * All typed views are borrowed scratch buffers. Copy before the next query. */
export const LAYOUT = Object.freeze([
  1, 332, 0, 4, 8, 12, 40, 0, 20, 24, 28, 32, 36, 37,
  20, 0, 1, 2, 3, 4, 8, 12, 16, 4, 0, 1, 2, 3, 17, 5, 14, 8, 64, 10, 40, 40,
]);
export const MOVE = Object.freeze({ BITE: 0, CHARGE: 1, GUARD: 2, SPIT: 3, TAIL: 4, DODGE: 5 });
export const VERB = Object.freeze({ IDLE: 0, APPROACH: 1, ATTACK: 2, GUARD: 3, DODGE: 4, FLEE: 5, MOVE: 6 });
export const STATE_FIELDS = Object.freeze(['x', 'y', 'fx', 'fy', 'hp', 'stamina', 'move', 'phase', 'ptick', 'plen', 'stun', 'bleed', 'slow', 'alive', 'medium', 'team', 'verb']);
const EVENT_FIELDS = ['type', 'a', 'b', 'move', 'amount'];
const PREVIEW_FIELDS = ['x', 'y', 'fx', 'fy', 'reach', 'arc', 'gap', 'inReach', 'inArc', 'flank', 'height', 'counter', 'damage', 'effect'];
const objectRow = (fields, row) => Object.fromEntries(fields.map((key, i) => [key, row[i]]));
const integer = (x, min, max, name) => {
  if (!Number.isInteger(x) || x < min || x > max) throw new RangeError(name);
  return x;
};
const finite = (x, name) => {
  if (!Number.isFinite(x) || !Number.isFinite(Math.fround(x))) throw new RangeError(name);
  return x;
};
export const defaultProfile = () => ({ mouth: 2, charge: 2, spit: 2, tail: 2, guard: 2, hp: 100, stamina: 100, speed: 4 });

export class Combat {
  static async create(options = {}) {
    const { default: factory } = await import('../../build/wasm/cpore_combat.mjs');
    return new Combat(await factory(options));
  }
  constructor(module) { this.assertLayout(module); this.module = module; }
  assertLayout(module = this.module) {
    if (module._cb_layout(0) !== LAYOUT.length || LAYOUT.some((x, i) => module._cb_layout(i + 1) !== x))
      throw new Error('combat WASM layout mismatch; rebuild WASM and wrapper together');
  }
  reset(setup) {
    integer(setup.seed, 0, 0xffffffff, 'seed');
    if (!Array.isArray(setup.creatures) || setup.creatures.length < 1 || setup.creatures.length > 8)
      throw new RangeError('creatures must contain 1..8 spawns');
    // Build locally first: validation failure never partially mutates WASM setup.
    const bytes = new Uint8Array(LAYOUT[1]);
    const view = new DataView(bytes.buffer);
    view.setUint32(0, setup.seed, true); view.setInt32(4, setup.creatures.length, true);
    view.setUint8(8, setup.flat ? 1 : 0);
    setup.creatures.forEach((c, i) => {
      const base = 12 + i * 40;
      const p = { ...defaultProfile(), ...c.profile };
      ['mouth', 'charge', 'spit', 'tail', 'guard'].forEach((k, j) => view.setUint8(base + j, integer(p[k], 0, 5, k)));
      ['hp', 'stamina', 'speed'].forEach((k, j) => view.setFloat32(base + 8 + j * 4, finite(p[k], k), true));
      [c.x ?? -1, c.y ?? -1, c.fx ?? 0, c.fy ?? 0].forEach((v, j) => view.setFloat32(base + 20 + j * 4, finite(v, 'spawn'), true));
      view.setUint8(base + 36, integer(c.medium ?? 0, 0, 1, 'medium'));
      view.setUint8(base + 37, integer(c.team ?? i, 0, 255, 'team'));
    });
    this.module.HEAPU8.set(bytes, this.module._cb_setup());
    if (this.module._cb_reset() !== 0) throw new Error('invalid combat setup');
    return this;
  }
  get tick() { return this.module._cb_tick(); }
  get count() { return this.module._cb_count(); }
  order(id, { verb, move = 0, target = -1, dir = 0 }) {
    integer(id, 0, this.count - 1, 'id');
    for (const [key, value] of Object.entries({ verb, move, target, dir })) integer(value, -2147483648, 2147483647, key);
    return this.module._cb_order(id, verb, move, target, dir);
  }
  step() { this.module._cb_step(); return this.hash(); }
  hash() {
    const p = this.module._cb_hash() >>> 2, words = this.module.HEAPU32;
    return words[p + 1].toString(16).padStart(8, '0') + words[p].toString(16).padStart(8, '0');
  }
  stateView() { return new Float32Array(this.module.HEAPU8.buffer, this.module._cb_states(), this.count * 17); }
  states() {
    const view = this.stateView();
    return Array.from({ length: this.count }, (_, i) => objectRow(STATE_FIELDS, view.subarray(i * 17, (i + 1) * 17)));
  }
  eventView() { return new Float32Array(this.module.HEAPU8.buffer, this.module._cb_events(), this.module._cb_event_count() * 5); }
  events() {
    const view = this.eventView();
    return Array.from({ length: view.length / 5 }, (_, i) => objectRow(EVENT_FIELDS, view.subarray(i * 5, (i + 1) * 5)));
  }
  preview(id, move, target) {
    integer(id, 0, this.count - 1, 'id'); integer(move, 0, 5, 'move'); integer(target, 0, this.count - 1, 'target');
    const ptr = this.module._cb_preview(id, move, target);
    if (!ptr) throw new RangeError('invalid preview target');
    return objectRow(PREVIEW_FIELDS, new Float32Array(this.module.HEAPU8.buffer, ptr, 14));
  }
  botInit(id, kind, seed, spamMove = MOVE.BITE) {
    integer(id, 0, this.count - 1, 'id'); integer(kind, 0, 4, 'bot'); integer(seed, 0, 0xffffffff, 'seed'); integer(spamMove, 0, 5, 'move');
    if (this.module._cb_bot_init(id, kind, seed, spamMove)) throw new Error('invalid bot');
  }
  botDecision(id, foe) {
    integer(id, 0, this.count - 1, 'id'); integer(foe, 0, this.count - 1, 'foe');
    const p = this.module._cb_bot_decide(id, foe);
    if (!p) return null;
    const a = this.module.HEAP8;
    return { verb: a[p], move: a[p + 1], target: a[p + 2], dir: a[p + 3] };
  }
}
