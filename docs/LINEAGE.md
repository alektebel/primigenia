# Lineage ledger (L0)

The opt-in C ledger is part of `CpStageWorld`, its hash and its scenario snapshot.
Call `cp_stage_lineage_begin` once for a new game. Old harnesses remain untracked;
unchanged world and combat goldens are intentionally retained. The raw snapshot
layout fingerprint changes; old snapshots need their scenario recipe rebuilt.

`cp_stage_lineage_award(world, deed, amount, cause)` is the integration boundary:
call once on a successful award, never on an attempted action. The social-loop
merge should connect befriends, intimidations, observations, gifts, meat and
plants here. This branch does not implement those mechanics. Kills are hooked
in finish(), distance/nest/night in a separate end-of-tick adapter. Fights started
and fled are recorded at the existing fight boundaries. Integer L1 centimetres
measure distance; displacements over 5m per tick (respawns/teleports) are ignored.
Night activity means movement during the last quarter of the 12,000-tick day.
Nest time is within 12m. Initial values are tunable.

Traits persist across generations: hunter = 3 kills; social = 3 befriends;
nocturnal = 600 active night ticks; burrower = 20 digging actions. Future rules:
aquatic = 600 swimming ticks; flyer = 600 flight ticks; void-adapted = 600 void
exposure ticks. Those three deed kinds currently reject, so cannot earn traits
before the media exist. These numbers are tunable, not approved balance.

The 1,536-entry ledger never edits or removes an entry. At 384 entries, new deeds
aggregate into saturating uint32 lifetime and generation counters; `deeds_aggregated`
counts omitted deed records. The remaining 1,152 slots are reserved for traits, part
diffs, types and evolution. Evolution must reject atomically if those slots run
out. This reservation fits all 64 part diffs plus type/evolved entries for 15
evolutions, plus all seven traits. Saturation is UINT32_MAX. At most 16 generations are retained.

## Band interchange: `cpore.lineage/1`

`cp_ledger_export` writes UTF-8 JSON into a caller-owned buffer, returning bytes
excluding NUL or -1 for insufficient capacity. world-2 exposes it as `lineage`;
Python `StageWorld.lineage()` reads it. Scenarios include that same block for
inspection; the authoritative restore source is the hashed `.cpstate`.

Fields: `format`, `enabled`, `generation` (1-based), `traits` (stable names),
`deeds` and `current_deeds` (named integer counters), `deeds_aggregated`, `entries`.
Each entry has `tick`, `kind` (`trait_earned`, `part_gained`, `part_lost`, `evolved`,
`deed`, `type`), numeric `id`, `value`, `x`, `z` (signed centimetres), `cause`
(unsigned originating entity/event id, 0 for world). Deed and trait ids are the
public enums in `ledger.h`; no float math or random draws are used by the ledger.
Consumers must ignore unknown additive fields and reject unknown major versions.

## Evolution and cousins (A13)

C: install a validated `CpLineageForm` with `cp_stage_lineage_form(w, form, 0)`,
then call `cp_stage_evolve`. Godot's console accepts `evolve <creature-file>`.
The adapter validates the studio body, computes its combat profile, and maps part
ids to manifest positions (v1: append only, no reordering). The C API treats body
JSON as opaque UTF-8 supplied by a validated frontend; part counts and profile
are the deterministic simulation projection. Bodies are capped at 16KiB, names
at 79 bytes, part kinds at 64. Evolution rejects atomically during a fight,
respawn, full island, full ledger, or after generation 16. No oldest-generation
replacement occurs. Type finalization is recorded alongside each evolution.

Each old generation spawns one cousin (population cap 15 across a lineage).
Its logical species id is `4 + generation`; the existing base-species field is
only an AI template. `cp_stage_cousin_generation` and
`cp_stage_species_counts_progress` are the social merge boundary. **Cousins do
not count toward Q43**: neither P4 nor A13 explicitly grants them progress credit.
An initial +20 trust bonus is exported for the social system to consume once,
not repeatedly per tick. It is metadata until that branch wires trust awards.

The cousin retains the entire old body and profile. Meat-mouth count determines
carnivore/omnivore/herbivore; offensive deeds vs friendly deeds determine
aggressive temperament, otherwise armour means territorial, otherwise timid.
AI uses the matching existing template. It spawns at a valid candidate roughly 32m from its home (48m on the second
ring), rotating the eight candidate directions across generations, so it does not
appear inside the player. Its home is the first visited position
in the most occupied 64m cell of that generation (ties: first visited; up to
128 visited cells, further cells ignored). If all eight nearby spawn candidates are invalid, evolution is rejected. Existing roaming and combat act on the spawned cousin.
Independent genome drift, breeding and later-stage domestication remain later
A13 work; historical portrait bodies never mutate.

Full export adds `generations`: generation, cousin entity id (0 for the current
form), logical species id, `counts_progress:false`, home in centimetres, initial
trust bonus, temperament, diet, trait mask, type index and body JSON string.
Bodies are JSON-escaped strings so export does not inject untrusted text.

Evolution starts a new snapshot-backed replay segment, like loading a scenario.
That snapshot includes every historical form and deed, and later inputs replay
bit-exactly from it. It does not claim to encode body files in the old numeric
input-log format; keep the segment's start snapshot beside its log.

## Part-id contract for `cpore.lineage/1`

Part events use these ids (the current `godot/game/data/parts.json` order).
Append additions; do not reorder ids without a new interchange version.

| Id | Studio part id |
|---|---|
| 0 | `fauces` |
| 1 | `romo` |
| 2 | `pico` |
| 3 | `ojo` |
| 4 | `tallo` |
| 5 | `antena` |
| 6 | `trompa` |
| 7 | `pinzas` |
| 8 | `oreja` |
| 9 | `pata` |
| 10 | `zanca` |
| 11 | `pezuna` |
| 12 | `asta` |
| 13 | `aguijon` |
| 14 | `cuerno` |
| 15 | `pua` |
| 16 | `maza` |
| 17 | `placa` |
| 18 | `cresta` |
| 19 | `bulbo` |
| 20 | `aleta` |
| 21 | `excavadora` |
| 22 | `eye_stalk` |
| 23 | `eye_triad` |
| 24 | `jaw_nipper` |
| 25 | `horn_crown` |
| 26 | `shell_plate` |
| 27 | `leg_sprinter` |
| 28 | `leg_sucker` |
| 29 | `arm_grasper` |
| 30 | `tail_paddle` |
| 31 | `tail_spike` |
| 32 | `wing_glider` |
| 33 | `frill_fan` |
| 34 | `beak_crusher` |
| 35 | `mandible_shear` |
| 36 | `snout_trumpet` |
| 37 | `tongue_spring` |
| 38 | `sac_spitter` |
| 39 | `arm_smasher` |
| 40 | `foot_spring` |
| 41 | `foot_hoof` |
| 42 | `foot_gecko` |
| 43 | `lure_lantern` |
| 44 | `wing_insect` |
| 45 | `tail_hammer` |

Type scoring, dead zone, names, perks and type-entry ids: [CREATURE-TYPES.md](CREATURE-TYPES.md).
