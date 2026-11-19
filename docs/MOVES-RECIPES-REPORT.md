# C2 moves, recipes, resource meters, bone spines and rock armour — report

Branch `c2/moves-recipes` (worktree `c2-moves`). Codex (gpt-6.1-sol) wrote slices S1-S4 and ran out of usage before committing or reporting; Claude finished, reviewed, tuned, committed per slice, merged `claude/v0.1-restore` (field journal, flora lore) and produced the evidence. Specs: `docs/P4.md` §2.6/§3, `docs/COMBAT-MOVES.md`, `docs/DESIGN.md` G50-G54, G68.

## Slices and commits

| Slice | Commit | Content |
| --- | --- | --- |
| S1 | `feat(combat): C2 moves ...` | Move ids 6-13 as data rows in `CP_COMBAT_MOVES`: claw_swipe, peck, pounce (gap-closer dash, stun), quill_volley (ranged, bleed), roar (fear, 360 deg sweep), stomp (knockdown, sweep), curl_up (guard, reduces damage), spine_volley (signature, calcium cost). New parts/extra[8] profile levels, statuses fear and knockdown, `CB_EFF_PIERCE`, `meter_cost`/`max_targets`/`cooldown` columns, counter rows, `CB_ERR_NO_METER`. Bots, tourney matrix (14 moves) and the P4 spines field (B3-B7). WASM combat layout bumped (cpcombat.js). |
| S2+S3 | `feat(world): recipes ...` | `core/src/stage_recipes.c` (new file, isolated): recipe `bone_spines` (espinas_dorsales L2 + fauces L2 + carnivore diet), states unknown/hinted/known/mastered, clue sources (spined fossil, quill-wounded old carcass, observing the Espinodo gnaw bones), calcium meter (old carcass bite +20, cap 100, volley spends 20, cooldown 30 ticks, wild Espinodo carries 40), mastery on the first landed volley. Rock armour: up to 6 stone nodes on the alpine slopes, 4 bites each, +25 mineral per bite, cap 100; mineral m gives damage x (1 - 0.0025 m) (max -25%) and speed x (1 - 0.003 m) (max -30%). Own RNG stream `stone_rng`; route-probe fallback (`cp_stage_route_from_nest`, at most 12 planner probes) so stones behind river bends are still reachable on foot (seeds 7 and 42). New code in `stage_world.c` is hooks only. |
| S4 | `feat(godot,python,wasm): ...` | world-2 exposes `recipes` ({bone_spines{state,clues,parts_have,parts_need,diet_ok,ready,...}, meters{calcium,mineral}, stones[], old_carcasses[]}); Python binding and `moves_recipes_smoke.py`; Godot extension, diegetic meter lines in `quiet_signs.gd` (bone-white calcium, mist mineral), 8 new move glyphs, whispers `recipe_hinted/known/mastered`, E to eat stones (`part_nodes.gd`), `moves_recipes_test.gd`. |
| golden | `test(golden): regenerate ...` | see Goldens. |
| merge | `Merge branch 'claude/v0.1-restore'` | one conflict (Makefile: both target sets kept). |
| journal | `feat(godot): journal Recipes page ...` | `journal_model.gd` accepts the world-2 dictionary and turns it into the journal's recipe array; parts_have/need and diet_ok now come from C. Expected part count 46 -> 47 (the new `espinas_dorsales`) in `ui_test.gd` and `test_creature.gd`. |

## What Codex had done vs what I finished

Done by Codex: all of S1-S4 code, the C tests (`tests/test_moves_recipes.c`), Python smoke, Godot headless test, goldens regenerated once, the stone route-probe fallback. Missing or wrong when I took over: nothing was committed; `make tourney` failed; the journal still read the old placeholder; two Godot suites counted 46 parts.
Done by me: determinism/RNG review (no libm trig in the new files, `+ - * / sqrtf` only; stones draw from their own `stone_rng`, fixed draw budget; hash block is folded in only after use so untouched worlds keep their hash), tourney tuning, golden regeneration, merge, journal adaptation, `get recipes -> parts_have/diet_ok` JSON fields, evidence harness (`godot/game/tests/moves_recipes_evidence.gd`), this report.

## Tunable numbers

`CP_COMBAT_MOVES[spine_volley]`: windup 5, active 1, recovery 3 ticks, reach 7 m, arc 0.3 rad, stamina 6 (was 8), damage 16, bleed 8 ticks, calcium 20, 2 targets, cooldown 30. Meters in `CP_STAGE_METERS` (cap 100; stone refill 25; carcass refill 20). Mineral: `.0025` damage and `.003` speed per point (combat.c, stage_world.c). Stone count 6, 4 units each. Recipe levels in `CP_STAGE_RECIPES`.

## Verification

| Check | Result |
| --- | --- |
| `make test` | PASS (exit 0), includes `moves_recipes_test`, world replay/snapshot, social, parts/nest, combat goldens, routes certification 144/144 reached and replayed identically for seeds 1, 7, 42. |
| `make smoke` | PASS (lineage, social, parts/nest, moves/recipes Python smokes). |
| `make tourney` | **FAILS on one gate family** (see below); everything else passes. |
| Godot `--check-only` | clean for all changed scripts. |
| `godot-test` | 593 checks, 0 failures |
| `godot-ui-test` | 716 checks, 0 failures (after updating the part count to 47) |
| `godot-play-test` | 217 checks, 0 failures |
| `godot-parts-nest-test` | PASS |
| `godot-moves-recipes-test` (new) | PASS |
| `godot-creature-test` | 1494 + 64 realism checks, 0 failures (part count 47) |
| `godot-actions-test` | 345 checks, 0 failures |

## Tourney matrix (14 moves) and gates

All pre-existing gates still pass: idle/random/greedy/counter canaries, strategy Elo (counter 1696, greedy 1557, random 1003, idle -257), build field cap (worst 62.3% spitter) and pair cap (worst 72.2%), raw and resource payoff dominance ("no move weakly dominates another" in both matrices), >= 4 moves in each equilibrium (7/14 raw, 6/14 resource). P4 spines field: B4 full-meter field mean max 61.5% (skirmisher), pair max under 90% PASS; B5 spiner vs informed counter 0.500, vs naive 0.981, surprise premium 48 points PASS; B6 calcium 60 allows at most 3 volleys in 900 ticks PASS, an exhausted spiner (meter 0, field mean 0.356) falls below the allrounder PASS; B7 tiers disabled (flag), not exercised.
Field matrix with the spiner (meter 100): spiner mean 0.450, Elo 970; brawler 1013, spitter 994, tank 901, skirmisher 1069, allrounder 1052.

**Unmet gate: B3 "spine_volley weight in [1%, 35%]"** in both the raw and the resource equilibrium (regret matching): the signature volley is used by neither mix (0.0%). Raw payoff row mean -30.6 hp, resource row mean -53. I ran about 150 configurations of windup (4-9), reach (4.5-7), stamina (3-12), damage (12-32), cooldown (16-40), bleed (6-40), a dodge-cost counter row, a spit-interrupt counter row and the calcium price in the resource matrix (0, 0.1, 0.25, 0.5 of nominal). No setting satisfied B3 in both matrices together while keeping B4 and B5: making the volley strong enough to enter the equilibrium either pushes a build's field mean above 65% (B4) or erases the informed/naive gap (B5), because in this harness ranged spacers pay sprint stamina to kite and the volley cannot be priced as free. Settings that pass B3 raw (cooldown 16-18, damage 15.5-16, bleed 10) fail B4 on one build. I kept the configuration that passes every gate except B3 (stamina 6; the original 8 additionally failed the resource dominance gate). The calcium price in the resource matrix is 0.25 of the nominal volley value (a harness choice, in `apps/combat_tourney.c`). This is the one open balance item; see open questions.

## Goldens

`world-1`, `world-field-1` unchanged. `world-42`, `world-987654321`, `world-debug-42` regenerated once: first changed hash line versus main at ticks 1767, 1661 and 2265 respectively, the first fight against a spined Espinodo (it now carries the volley, extra[7]=2, carnivore) and the first bleed from it. Reason: new wild loadout and the recipe block entering the world hash once recipes or meters are used. The final regeneration (committed separately) moved the first differing line to 1774 / 1672 / 2272 only because spine_volley stamina went 8 -> 6. Combat goldens unchanged except through the 14-move table (`combat_golden` passes).

## Evidence (xvfb software GL, JPG, `docs/evidence/godot/moves-recipes/`)

Harness: `godot/game/tests/moves_recipes_evidence.gd` (14 checks, 0 failures). Run `... --script res://game/tests/moves_recipes_evidence.gd -- <out> [lang] [recipes]`.
- `01_hotbar_c2_kit_target`: the radial with quill, pounce, roar and claw glyphs on a target.
- `02_quill_volley_*`, `03_roar_fear_*`, `04_pounce_*`: each move at its active frame and a few ticks later (the "Blocked: on_cooldown" line in some shots is the harness re-sending the order, not a game fault).
- `10-13_journal_recipe_*`: the journal Recipes page unknown, hinted, known and after use (real `state().recipes`).
- `11_recipe_*`: world views at each state; `20-24_calcium_*`: calcium 20, 40 from old-carcass bites, 40 before and 20 after a volley; `23_bone_spines_*` the volley (the wild is winded first: a Rondo with stamina dodges the volley, a legitimate counter) and the journal flips to Mastered after the first landed hit (`13_journal_recipe_after_use`).
- `30-32_stone_*`: the labelled stone node, chewing, mineral 50; `40_meters_closeup.jpg` enlarges the bottom-left meter lines for calcium and mineral.
Observed: meters are thin lines in the stamina stack and legible only when enlarged; no projectile is visible in still frames (the dart tween lasts 0.18 s of real time and the harness stage is paused). On seed 1 only 3 stone nodes were placed.

## Open questions

1. B3 for `spine_volley`: accept a waiver (the move is a surprise secret, B5 premium 48 points, field mean 45%) or redefine B3 for signature moves; or give the volley a second niche (multi-target pierce vs guard beyond the current row). Owner call.
2. Is the Espinodo supposed to carry the volley in the open world from the start (it now does, which is why three goldens moved)?
3. Meter HUD: bars are small; a stronger diegetic cue (bone dust, cheek bulge) is art work.
4. `make tourney` currently exits 1 because of B3; `make test` does not run it.
