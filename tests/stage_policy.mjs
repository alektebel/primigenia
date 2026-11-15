/* Fixed competent player shared by the headless gate and victory capture. */
import { MOVE } from '../web/engine/cpcombat.js';

const DURATION = { [MOVE.BITE]: 6, [MOVE.CHARGE]: 17, [MOVE.SPIT]: 11, [MOVE.TAIL]: 9 };

export function stagePlayerPolicy(sim) {
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

