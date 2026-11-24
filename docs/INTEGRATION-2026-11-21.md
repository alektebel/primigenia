# Integration 2026-11-21 (branch integrate/wip-2026-11-21, from main 6644d86)

Software GL / headless only. Nothing pushed, main (`claude/v0.1-restore`) untouched.

## Step 0: stranded work committed (inside the worktrees, "committed by integrator")
species-v8 8027b40, wl6-cave 4c6e902, art-underwater f85542b (tracked changes + kelp render only; ~71 untracked debug scripts/pages left in that worktree, delete them there), feel-camera 60f43d7, loco e47dcd6, gaitopt d17315b, lore-autoloop2 c17403f, dem 7ab5a12.

## Merges
| Branch | Result | Conflicts | Suites after | Ids / snapshot |
|---|---|---|---|---|
| c2/moves-recipes | merged | none | make test (routes 288/288), smoke, tourney PASS; godot M0 1138/0, ui 896/0, play 237/0, flight 22/0, devtools 895/0, bridge 42/0, menu 32+1/0, moves-recipes PASS, studio 926/0 | snapshot 9; events FELL 27, RECIPE 28, VOLLEY 29 |
| c2/first-quest | merged | 37 files: combat.h/c, world.h, stage_world/parts/genome, lineage_world, tourney, Makefile, DESIGN, 3 parts.json, ui/test files, 20 scenario files | make test, smoke, tourney, first-quest-test PASS; M0 1218/0, ui 963/0, play 237/0, devtools 914/0, creature 1600+/0, moves-recipes PASS, studio 938/0, actions 386/0, first-quest e2e 29/0 (replay identical) | snapshot 10; events DUG 30, MOVE_USED 31; errors HARD_GROUND -27, ALREADY_DUG -28 (-25 is CB_ERR_NO_METER); flame = move 14 (tourney excludes it via CB_TOURNEY_MOVES); parts 49 (C), 50 in parts.json; DESIGN A32 -> A38 |
| c2/species-v8 | merged | Makefile, world.h, stage_world.c, 3 goldens | make test, smoke, tourney PASS; M0 1266/0, ui 972/0, play 237/0, devtools 914/0, creature/radial 286/0, bridge 42/0, studio 938/0, actions 386/0, e2e 29/0 | snapshot 11 (no new events); v7 migration dropped (see below) |
| art/wl6-cave-mesher | merged (mesher only, not wired into the island) | none | godot-cave-mesh-test PASS (31540 tris, hash c59dc0ab...), M0, play | none |
| art-food, art-meteor, art-nest, art-remains, art-species, art-underwater, dem, feel-camera, idol, loco, m-e2e, m-ecology, m-vista, tools/gaitopt, lore/autoloop-2 | merged | none (web/docs/tools only) | node test_stage_camera, test_stage_boot, test_locomotion (7/0) PASS; godot-loco-test 299/0; Godot suites unchanged | none |
| m-garfio | merged, content reverted | none | M0 failed byte-equality (web vs Godot garfio-combat.json); reverted the file | A31 tuning wins, as the brief says |
| w11-alpine | SKIPPED | 14 files incl. core/terrain.c, terrain.h, 3 terrain goldens, tests | n/a | (a) its own report says drainage acceptance is unresolved; (c) it rewrites terrain heights (gameplay, goldens) on top of main's terrain v4; needs an owner call |

## Decisions I took that the owner may want to revisit
1. First-quest renumbering (above), goldens regenerated once after all merges: world-42/987654321/debug-42 after first-quest (first change at tick 1773/1671/2271: the drop table depends on part count) and again after species-v8 (changed from tick 0: new roster); world-1 and world-field-1 never changed. Ten curated scenarios regenerated for snapshot 11.
2. species-v8 snapshot migration from v7 removed (a frozen v7 prefix cannot be copied into a layout with recipes, dig and run state; project rule is exact-version snapshots).
3. Evolving spawns a cousin and needs a free wild slot (max 24). species-v8 filled all 24. Radial animals now stop at 23 (Corona first, so a Brujula is trimmed 4 -> 3). Owner: how many free slots should be reserved for cousins (up to 7 generations)?
4. Garfio's grace minute and "no hunting until first evolve" mean it no longer charges the player: play_test starts its fight by attacking.
5. Test fixes after the merges: moves table is 15 (flame = 14), first-quest json move 14, e2e/evidence flame id 14, e2e waits on the loading screen by wall clock, legend strings in Spanish for dig and the task card, part counts (50 in parts.json).

## Final state of the suites on the integration branch
make test PASS (routes 288/288 reached, replays identical), make smoke PASS, make tourney PASS (all gates, exit 0), first-quest-test PASS; Godot: M0 1266/0, ui 972/0, play 237/0, devtools 914/0, creature 1600/0 + realism 64/0 + radial 286/0, moves-recipes PASS, bridge 42/0, menu 32+1/0, studio 938/0, actions 386/0, flight 22/0, cave-mesh PASS, loco 299/0, first-quest e2e 29/0 with identical replay. Pre-existing SCRIPT ERROR lines in M0/ui/flight tests (same as before the merges). Not run: wasm suites (no emsdk), browser tests (Playwright/Firefox), godot-loco-score compare, look/loco evidence.

## Needs the owner
- w11-alpine: merge or close (see table).
- Cousin slot reserve (item 3) and the 7 -> 15 move table surfacing flame in the hotbar slot 4 by default.
- Cave mesher is not wired into the island or art yet (mesher + test only; no flag).
- art-underwater worktree has ~71 untracked debug files to delete.
- New DESIGN entry A38 is the first quest (was A32 in its branch; main took A37).

## Main merged in (claude/v0.1-restore adc205b: skin v1, creature fit, L1 posture, look-score, starter candidates)
Merge commit 4e5c5f1. Conflicts: `docs/DESIGN.md` (main took A37, the first quest is now A38) and `lore/references.json` (union of both appended blocks, 528 entries, no duplicate ids). No C change: no golden regeneration; next free event 32, snapshot 12. Suites after: make test PASS (routes certified), godot-test 1266/0, ui 972/0, play 237/0, studio 942/0 (45 web files), loco-test 299/0, creature-fit PASS, first-quest e2e 29/0. `make godot-loco-score LOCO_LABEL=integrate` then `tools/loco/compare.py ffea2c1 integrate`: improved 0, regressed 0, unchanged 575 (35 cases). anim/limp not merged.
