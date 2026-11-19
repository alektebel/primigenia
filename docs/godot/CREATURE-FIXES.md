# Creature-mode fixes (branch `ui/creature-fixes`)

The owner's list, played on the island. One commit per item.

## 1. The left button never moves the camera

Every path was removed, not just the drag:

- a left drag (more than 6 px) used to orbit: it is now classified by `pointer_gesture.gd` and ignored (`island.gd _on_motion`);
- a double click on a strategic icon or the map zoomed back down: gone;
- clicking the ground made the creature walk, and the chase camera then swung behind it as it turned: while a left click or
  hold is walking the creature (`player_input.destination != null`) `chase.mouse_walk` is true and the auto-follow does not turn the
  camera (keys still do);
- selection, the radial ring and the card never touched the camera (checked); the family tree's "show on the map" pin still
  zooms to the map (it is a journal button, not a click in the world; see the open question in the report).

Tests: `test_camera.gd` (`_mouse_walk`), `play_test.gd` ("the left button never moves the camera": drag, double click, 69 frames of
walking to a click without a yaw change).

## 2. Health lines (`ui/creature_bars.gd`)

A hairline over every creature that is hostile, in the fight or selected (bone, EMBER for hostile; track 24 %, round caps, INK halo,
a tick at the end), sized from the body's on-screen height (26 to 64 u). Distance fades it (full to 28 m, gone at 55 m; the fight and
the selection keep at least 80 %), at most 8 at once (focus first, then nearest), so a far herd draws nothing. The value goes down
with an ease-out of 200 ms and leaves a lighter "lost" segment that waits 0.35 s and then closes; Less motion is instant. The ground
ring and the field note are unchanged. Tests in `ui_test.gd` (`test_creature_bars`). Evidence: `bars_*.jpg`.

## 3. Clouds

The clouds are one sky shader layer (`sky.gdshader` + `clouds.gdshaderinc`, no billboards). The square look came from the noise: value
noise on the world axes with every octave on the same grid, so a patch of coverage had square corners, and the same coverage
darkens the ground (`cloud_shadow`), where it showed as a straight-edged dark band. Now: a trig-free hash, quintic fade, every octave
rotated and offset differently, a mild domain warp of the lookup, threshold moved to keep the same cover. Same cost (three or five noise
reads; the low tier uses the three-octave version for the shadow as before). Evidence: `clouds_before_*.jpg` / `clouds_after_*.jpg`.

## 4. `edit_anywhere`

Setting `edit_anywhere` (default **on** for now; "Edit anywhere" in the pause settings). C: `cp_stage_can_edit(w)` is `cp_stage_at_nest(w)`
or the flag with no fight, no respawn and no lineage loss; `cp_stage_part_buy`, `cp_stage_edit`, `cp_stage_apply`, `cp_stage_start_genome`
and the parts state's `can_edit` use it. `cp_stage_at_nest` and the 12 m radius are untouched (they still gate the loadout). The flag
lives in the former `reserved` int of `CpStageWorld`, is never hashed and not part of any golden; the binding is
`CporeWorld.set_edit_anywhere(bool)` and `StageWorld.edit_anywhere` tells the world again after every reset and restore (a snapshot would
otherwise bring back its own value). DNA cost is unchanged. Tests: `tests/test_parts_nest.c` (hash unchanged by the flag, fight blocks it,
off restores the rule), `ui_test.gd` (settings row, menu), `make test` green.

## 5. Playing with the creature you made; not rebuilding the island

- Studio: "Jugar con esta criatura" saves and enters the island (`Studio.play_with_creature`, `Game.enter_island_now`; the island takes
  the newest saved genome as before, with the starter-parts rule of A25).
- `Game.entry_log` and the console line `island entry (...)` give the milliseconds of each build phase; `game/tests/entry_bench.gd`
  runs cold, menu again and studio.
- `Game.park_island()` runs before every scene change; the terrain meshes and materials, water, rivers, grass and the flora/rock batches
  (`island.kit_nodes()`) leave the scene tree and wait in memory, and the next island takes them back (`Game.take_kit()`), keyed by the
  terrain data, grass count, quality, sun shadows, flora settings and wild flag. The terrain itself was already kept in `Game.data`.

Headless on a machine with load average 25 to 50 (so the absolute values are inflated several times; the ratios and the phase table are
what to read):

| entry | before | after |
|---|---|---|
| cold start (menu to island, no kit) | 24.2 s | 19.4 s (nav_warm 6 s of it, a one-time C walk grid) |
| island to menu to island | 11.4 s | 3.2 s |
| studio to Jugar con esta criatura | 13.0 s | 5.8 s (2.7 s in a calmer run) |

Phases of the 11.4 s re-entry before (ms): water 3767, props/flora 2691, creatures 2014, ui and rest 2002, stage reset 556, rivers 197,
terrain meshes 94, grass 10. After: water, rivers, terrain, grass and props 0 (kit); what is left is the creatures (about 1.5 s: the
player and the wild bodies are built from their genomes, Turing patterns included), the UI and the rest (about 1.5 to 2 s) and the stage
reset (0.1 s). Caching the creature bodies is the next step and needs the creature module to share built meshes.

## 6. Observing plants

Resting the pointer on a plant for 2.5 s (not while it is over a creature, in a fight, with a creature selected, holding a button or
with a window open) writes it into a new Plants section of the journal (name, habitat, the lore line from `lore/flora/*.json`,
copied into `flora.json` as `lore`) and whispers "Nueva planta: ...". Visual only: `game/island/plant_gaze.gd` picks the plant from
the placed flora records (spatial index, a stick with a radius that grows with distance) and the known list is saved in the
scenario (`"plants"`). Tests: `test_plant_gaze.gd`, `ui_test.gd`, `play_test.gd`.
