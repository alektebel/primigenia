/* Combat-only projection of an already studio-validated cpore.creature/4.
 * c_type + category are semantic inputs; geometry and illustrative abilities
 * never grant stats. This does not certify a full C genome for game entry. */
export const PART_RULES = Object.freeze([
  { c_type: 'CP4_MOUTH_C', category: 'mouths', mouth: 2 },
  { c_type: 'CP4_MOUTH_O', category: 'mouths', mouth: 1, spit: 1 },
  { c_type: 'CP4_MOUTH_G', category: 'mouths', spit: 2 },
  { c_type: 'CP4_HORN', category: 'weapons', charge: 1 },
  { c_type: 'CP4_TAIL', category: 'weapons', tail: 1 },
  { c_type: 'CP4_PLATE', category: 'details', guard: 1 },
].map(Object.freeze));
const LEVELS = ['mouth', 'charge', 'spit', 'tail', 'guard'];
export function profileFromStudio(creature, manifest) {
  if (creature?.schema !== 'cpore.creature/4') throw new Error('expected studio schema cpore.creature/4');
  if (!Array.isArray(creature.parts) || creature.parts.length > 256) throw new Error('invalid studio parts');
  if (!Array.isArray(manifest?.parts)) throw new Error('invalid parts manifest');
  const catalog = new Map(manifest.parts.map(p => [p.id, p]));
  const result = { mouth: 0, charge: 0, spit: 0, tail: 0, guard: 0, hp: 100, stamina: 100, speed: 4 };
  for (const part of creature.parts) {
    const entry = catalog.get(part?.type);
    if (!entry) throw new Error(`unknown studio part: ${part?.type}`);
    const rule = PART_RULES.find(r => r.c_type === entry.c_type && r.category === entry.category);
    if (rule) for (const key of LEVELS) result[key] = Math.min(5, result[key] + (rule[key] ?? 0));
  }
  result.hp += result.guard * 5;
  return result;
}
