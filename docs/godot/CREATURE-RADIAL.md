# Radial body plans (A24 symmetry)

A genome may carry an optional top-level `plan` object (cpore.creature/5, no schema bump). Absent = bilateral:
every existing genome, mesh and golden is unchanged (`godot/creature/tests/fixtures/bilateral_mesh_hashes.json`
guards the meshes, recorded before this work; `plan_cases.json` is the validator parity table).

```json
"plan": {"sym": "radial", "fold": 5, "star": 0.45, "gel": 0,
  "arm": {"len": 2.3, "w": 0.6, "taper": 0.8, "curl": 0.1, "droop": 0, "frill": 0, "tip": "point", "eye": 1, "act": "tubefeet"}}
```

* `sym` `radial` (`bilateral` accepted, never written); `fold` integer 3..8; `star` 0..1 lobing of the disc margin
  towards the arms; `gel` 0..1 translucency (jellies); `arm.len` 0..6 in disc radii, `w` .1..1 base half-width in
  disc radii, `taper`, `curl` (+ tips up), `droop` (arms hang beneath: oral arms), `frill`, `tip` point|frill|bulb,
  `eye` optic cushion at each tip, `act` peristaltic|hydrostat|tubefeet|cilia (absent = derived).
* `nodes` are the axial profile, oral pole first: every `z` is 0 and `y` strictly increases (error `plan.nodes`),
  consecutive `y` still >= .05 apart. `parts[].t` runs along it (0 oral, 1 aboral); `ang` is the bearing from arm 0
  (+Z, towards +X). A part with t <= .04 or >= .96 is axial (one copy); every other part is replicated `fold` times;
  `single: 1` keeps one copy; `single: -1`, leg parts (`plan.legs`) and non-torso regions are rejected.
* Combat rule: a radial replica is like a mirror pair, one entry, one stat. `plan` adds nothing to the profile or
  `radius_cm` (the disc only) in v1.

Validators (same error paths): `core/src/stage_genome.c`, `creature_genome.gd`, `studio/genome.gd`, `web/studio/genome.js`.

## Mesh and skeleton (`creature_radial.gd`)

`Creature.build()` branches once on `CreatureGenome.plan_of(genome).sym`. One skinned surface holds the lathe disc
(`fold * 12` vertices per ring, 72 rings) and the `fold` swept arms (21 rings x 12). Skeleton: `disc` root,
`axis_0..2` (oral, middle, aboral), `arm{k}_0..5` chained from the root; `Creature.plan_kind`, `radial.fold`,
`radial.arm_bones`. Arms are as tall as the disc at their root, round tubes for hanging oral arms. The Turing UV is
mirrored inside each sector (D_fold symmetry); arms carry UV.x > 5 so the skin shader can draw two rows of sucker feet
under tube-foot arms. `gel > 0` swaps the body material for `skin_gel.gdshader` (alpha, rim, wrap light).
Radial bodies rest on the oral surface (`ground_offset = .02 - lowest vertex`).

## Locomotion (`godot/locomotion/loco_radial.gd`)

Same interface as `loco_controller` (`reset`, `set_intent`, `step`, `pose`, `footfall`). Modes: `glide` (tube feet),
`row` (brittle-star rowing; the arm next to the heading leads), `jet` (bell pulse), `cilia` (glide with a margin ripple,
slack-tide collapse). There is no fixed front: the visual `body_yaw` counter-rotates the body against the host yaw, so
the animal never turns more than pi/fold; it only changes its lead arm.

## The three wild species (snapshot v8)

`godot/game/data/{brujula,cuarteta,corona}.json` (cpore.creature/5 with a radial `plan`); `godot/game/island/radial_fauna.gd`
provides their deterministic habitat planner (`RadialFauna.plan(terrain, world_seed, nest)`). `StageSetup.add_radial` turns
Brujula and Corona spots into C spawns (zero-based species 6 and 7, legs 5 and 6); `island.gd` builds their normal ActorHosts
from the existing `plan` genomes. Only Cuarteta is spawned as ambient fauna by `radial_fauna.gd`, so there are no duplicate
land animals. Both simulated species support the standard social, observe, combat, loot and journal paths.

Brujula is territorial and omnivorous (detritus, mollusks and carrion), roaming at 0.3 m/s and escaping at 2.0 m/s. Corona
is timid, carnivorous (plankton, benthic invertebrates and carrion), crepuscular, with a 1.4 m/s speed. Tides remain deferred.
Snapshot v8 migrates the six-species v7 arrays and verifies the original state hash before accepting the save.

Placement is deterministic like `flora_placement.gd`:

| species | where | animals | motion |
|---|---|---|---|
| brujula (pentaradial star) | nearest intertidal shelf from the nest: ground .15..1.8 m, normal.y >= .9, within 30 m of the sea | 4, 3..6 m round a pool point | 0.3 m/s glide; 2.0 m/s rowing when driven off or provoked |
| cuarteta (4-arm bell, gel .7) | sea cells 1..6 m deep, 15..60 m off the shelf | 5, bell top at y = -0.12 | jet along a seeded loop |
| corona (6-arm disc) | a level tide-pool flat at the water's edge (ground 0.1..1.6 m, level within 25 cm over a 3 m ring, sea within 10 m), the nearest to the lowest tidal cave mouth, 20 m from the brujula pool; chosen on a 6 m grid, deterministic, logged. Caves are only notches in steep slopes, so the old cave rule (lowest entrance floor that is not `caves[0]`, 3..6 m inside) is now only the fallback when no flat exists | 2, 1.6..3.5 m round the flat | cilia glide, hunkers while waiting |

Ambient bells are culled beyond 80 m. Hooked from `island.gd` in one block (only when wild creatures are on). The lore test checks
`body_plan.arms == plan.fold`. Evidence: `make godot-radial-evidence` (docs/evidence/godot/radial/).
