# Parts, nest and eggs — C2 report

Worktree: `c2-parts-nest`, branch `c2/parts-nest`. Codex's work was integrated, merged with `claude/v0.1-restore` and adjusted to the A25 owner decisions by Sonnet (see the integration section at the end, which supersedes anything above that it contradicts). The implementation uses the existing fixed nest, social DNA account, creator, diegetic whisper API and `cp_stage_evolve` ancestry path.

## Slices and intended commits

| Slice | Intended commit | Implemented |
| --- | --- | --- |
| S1 | `feat(core): discover parts from kills, alliances and surface finds` | Stable catalogue ids and costs; discovered/owned bitsets; weighted species loot; 200/350-permille drops; fourth-dry-kill pity; separate loot/fossil RNG streams; one-time ally signatures; duplicate conversion at cost/4 DNA. Existing last-bite carcass bones remain the bone-item source. Eight candidate surface/old-carcass nodes use the planner's body slope and water-clearance rules. `inspect #id` requires proximity and 20 uninterrupted ticks. Sources appear in `part_found` events and DNA accounting. |
| S2 | `feat(core): centralize fixed-nest editing availability` | The setup nest remains the fixed marker and respawn location. `cp_stage_at_nest` centralizes the 12 m shop/edit check; loadout retains its existing 12 m check. The site remains in `setup.nest_x/z`, a clean handoff for C3's later site selection. |
| S3 | `feat(core): spend DNA on parts, levels and tier forms at the nest` | Discovered-part purchase, level costs 2/4/8/16 × base cost, tier costs 60/150 and milestones 25 hits + 3 wins / 75 + 10. Placed-part usage and per-move hit/win counters. A part counts at most once per fight even if it supports multiple moves. Bounded C JSON validation derives the profile; v4 normalizes to v5 with level 1/tier 0. JS and both Godot validators understand v5. Profile projection multiplies each rule by level and clamps at 5. Confirmed edits call `cp_stage_evolve`, preserving ledger diffs and spawning the previous form as a cousin. Purchases never decrease `dna_total`; rearranging has no price or refund. Tier effects use data rows in combat, and cousins retain the tiers of their historical form. |
| S4 | `feat(core): consume eggs and respawn hatchlings at the fixed nest` | Three starting eggs; each death consumes one. Surviving deaths retain the existing 20-tick respawn delay and apply 60% maximum HP for 1,200 ticks. Another death resets the hatchling timer without compounding the HP reduction. At zero eggs, `parts.lost` freezes the stage and orders are rejected. DNA is retained. |
| S5 | `feat(godot): expose the nest shop and discovery journal` | Nest menu entry, paused in-game creator overlay, discovered-only palette, owned-part placement, DNA balance, costs, named tier forms and milestone counts, level/tier purchase, inline C rejection, confirm/evolve and scenario redressing. Purchases survive cancelling the edit. Closing starts a snapshot-backed replay segment. The creator keeps body geometry, paint, skeleton, limb actuation and asymmetry fields. New runs start with the approved pico/pata/ojo inventory; saved scenarios preserve their genome. Surface markers have an E inspection interaction. Discoveries use the existing whisper API; the journal stub lists discovered ids. |

## Public contract

- `world-2.parts`: discovery/ownership, catalogue index, base/next prices, level, tier/form, milestone counts, inspectable nodes, current inspection, eggs, hatchling duration, loss and nest availability.
- Commands: `inspect #3000` (ids 3000–3007 when placed), `buy_part <id>`, `buy_level <id>`, `buy_tier <id>`. Existing verb numbers are unchanged; new numbers are 16–19.
- C: `cp_stage_start_genome`, `cp_stage_genome_form`, `cp_stage_edit`, part discovery/purchase helpers. Nest edits accept full genome JSON, never a host-supplied combat profile.
- Python: `StageWorld.start_genome(dict)` and `.edit(dict)`; shop and inspection through `.command()` and the normal observation.
- Godot: `CporeWorld.nest_edit(body_json)` and `state().parts`. Nest → Edit creature opens the existing studio.
- Snapshot version is **6**. Combat WASM layout version is **3**, with the JS assertion updated. Zero-tier combat hashing remains unchanged. The new parts block follows the existing activation convention: it is folded into the world hash after discovery, purchase, inspection, usage or death activates it. RNG and all purchase/usage/node/egg state then enter the hash; events and padding do not.

## Verification

All logs are under `build/parts-nest/` (ignored build artifacts).

| Check | Result |
| --- | --- |
| `make test` | PASS, including world replay/snapshot tests, social/lineage, core, steering/navigation, combat tests and combat goldens. |
| `make smoke` | PASS, including new Python discovery → inspect → purchase → nest evolution smoke. |
| `make tourney` | PASS. Worst build field mean 62.3%; worst pooled build pairing 72.2%, within the existing 65%/90% gates. |
| Native `parts_nest_test` | PASS: rates/pity, alliance signature, duplicate DNA, nest boundary, prices/caps, tier milestones, C validation, v4 migration, cousin/ledger diffs, eggs/loss, timer recovery, inspection, snapshot continuation and modifier behavior. |
| Direct Emscripten build of the same C rule suite | PASS; native/WASM output and evolution/inspection/shop hashes are byte-identical. |
| Godot extension build | PASS using a worktree-local copy of godot-cpp. |
| Godot `--check-only` + `godot-parts-nest-test` | PASS. Tests load the stage UI/marker scripts, migrate v4, filter locked parts, reject an invalid edit and confirm a valid edit that produces a second generation. |
| `make godot-studio-test` | PASS: 824 checks, zero failures; eight outputs accepted by the web validator. |
| `node tests/test_studio_genome.cjs` | PASS. |
| Impeccable detector on changed UI scripts | No findings. This is not a visual review. |
| `git diff --check` | PASS. |

First-kill sample over 2,000 seeds each: **420/2,000 common (21.0%)**, **737/2,000 Garfio (36.85%)**. Pity is checked across 99 seeds. The streams are separate from spawn, terrain and social randomness.

GCOV rule-suite line coverage: **100.0%** for `stage_parts.c`, **93.42%** for `stage_genome.c` (96.43% combined). These are line figures; taken-branch coverage is lower (63.39% / 51.17%).

The wider optional `make wasm-test` built its modules but stopped in the terrain harness with Node `spawnSync nice EPERM`. The new-rule suite was therefore compiled and run directly under WASM, with native-output comparison, independently of that harness.

Godot headless import prints editor/socket permission diagnostics in this sandbox. The nest test exits successfully but reports a CanvasItem RID / ten ObjectDB instances / four retained resources during shutdown. Those cleanup diagnostics remain unresolved; they are not counted as a clean resource-leak check.

## Golden changes

Only the five death-containing world hash files changed. Inputs are unchanged. Each prefix before the first death was compared against `HEAD` and remains byte-identical:

| Golden | First changed tick = first death | Hash count |
| --- | ---: | ---: |
| `world-1` | 61 | 3,000 |
| `world-42` | 61 | 3,000 |
| `world-987654321` | 61 | 3,000 |
| `world-debug-42` | 61 | 3,000 |
| `world-field-1` | 232 | 300 |

`build/parts-nest/golden-audit.txt` records the audit. The combat goldens remain unchanged. Existing snapshot-v5 `.cpstate` artifacts require rebuilding before reuse; the version change is intentional.

## Open questions and remaining work

- **Guard milestone semantics:** the approved table offers plate tiers, but guard lands no offensive hits. Guard can accumulate fight wins; its 25/75-hit threshold cannot be reached through normal guarding. No substitute such as counting blocks was invented. This needs an explicit design decision.
- Tier names and gameplay modifiers are implemented; separate hooked/serrated/etc. meshes and a visual tier preview are not. Existing part geometry is reused. Fossil/bone markers are deliberately simple meshes, not finished environmental art.
- The existing tournament covers its existing capped profiles and T0 strategies. Modifier unit tests cover tier behavior, but a dedicated T1/T2 tournament matrix remains to be added before claiming full tier balance acceptance.
- Generation count, cousin capacity and ledger capacity remain the existing evolve limits; the creator reports a rejection when those are exhausted. No lineage history is discarded to make room.
- The journal remains a stub listing ids. It does not yet provide catalogue silhouettes, pagination or a complete codex page. Long discovered lists need a designed journal layout.
- Recipe clues/spine-volley content, raids, nest-site choice, egg hatching, stores and nest defence are outside these changes.
- Sonnet must commit/integrate, rebuild old scenario snapshots, capture the evidence below and run a human visual/playability review. No display-based evidence was attempted here.

## Sonnet capture checklist

1. Kill drop → discovery whisper → journal entry; inspect a surface fossil and an old carcass with E; show each exhausted node cannot be inspected twice.
2. Outside 12 m: editor unavailable. At the fixed nest: editor opens with the player's paint and realism choices intact, locked parts absent and discovered/unowned parts priced.
3. Buy a part and a level; show balance decreasing and lifetime DNA unchanged. Show a locked tier's milestone counts, then a tier purchase after earning the threshold.
4. Invalid confirmation shows its inline error; valid confirmation returns to the valley with the changed part, a previous-form cousin and ledger part-gain/loss entries.
5. First death: two eggs remain and max HP is 60%; recovery after 1,200 ticks. Third death: no respawn and `parts.lost` true.
6. Check the nest overlay at small-laptop size, Spanish and English, keyboard focus, cancellation, journal overflow and headless-test cleanup diagnostics.


## Integration (Sonnet): commits, merge, A25, verification, evidence

### Commits on `c2/parts-nest`

1. `feat(core): parts discovery, nest editing, DNA purchases/levels/tiers and egg lineage (S1-S4)` (core, bindings, tests, web validators, Makefile).
2. `test(golden): regenerate world hashes for egg-consuming deaths` (the five files documented above; prefixes before the first death are byte-identical to HEAD).
3. `feat(godot): nest shop, creator overlay and discovery journal (S5)` (Godot, strings, this report).
4. `Merge claude/v0.1-restore into c2/parts-nest`. The only textual conflict was the Makefile (both sides added test targets: kept `parts_nest_test` and the route-certification `routes_test` / `routes-test` / `godot-route-events-test`). `core/src/stage_world.c`, `island.gd`, `stage_ui.gd` and `cpore_world.cpp` auto-merged. The world goldens did not conflict and were not regenerated again: `make test` replays them and passes. Snapshot version stays **6**.
5. The A25 / fix commit(s) below.

### A25 owner adjustments (owner file wins over Codex)

| A25 rule | Implementation |
| --- | --- |
| 1. Few starter parts | A new run owns and has discovered only `pico`, `pata`, `ojo`, with the small starting DNA budget the stage already gives (DNA 1 at the start). `island.gd` filters the saved genome to those parts for a fresh run. Locked parts are absent from the creator palette. Test: `a25()` in `tests/test_parts_nest.c`, `parts_nest_test.gd`. |
| 2. Edit only at the nest | `cp_stage_edit` and the new `cp_stage_apply` both require `cp_stage_at_nest` (12 m, no fight, not lost); otherwise `-13`. Tested at 13 m. |
| 3. Explicit Evolve | New `cp_stage_apply(w, genome)` (Godot `nest_apply`, Python `apply`): free repaint/rearrange at the nest. It never calls `cp_stage_evolve`, never spends DNA and never creates a generation; it replaces the current form's body (and radius) and returns `-23` (`CP_STAGE_ERR_NEEDS_EVOLVE`) when parts, levels, tiers or the derived combat profile would change. `cp_stage_edit` is now the Evolve action: it prices everything the genome adds (new discovered parts, levels, tiers if enabled), checks the DNA balance (`-24` `CP_STAGE_ERR_NO_DNA`), charges it atomically, calls `cp_stage_evolve` once, and restores parts and balance if the evolve itself fails. The `buy_part/level/tier` commands still exist for agents. In the creator, trying parts and levels is a free sketch with a pending-cost line; **Aplicar (gratis)** calls `nest_apply`; **Evolucionar** is the only button that spends DNA. Leaving the creator after a free apply keeps the new paint/layout without a new generation. |
| 4. Zero eggs | C still freezes the stage (`parts.lost`, DNA kept). The stage UI now shows the end-of-lineage moment and its button returns to the last save (`island.load_game()`, no wipe, no new game); with no save it goes to the menu. Exercised in the evidence run. |
| 5. Tiers behind a flag | Tiers T1/T2 stay implemented but `parts.tiers_on` is off by default (`cp_stage_set_tiers`, Godot `set_tiers`, Python `set_tiers`; reported as `parts.tiers_enabled`). Off: `buy_tier` and genome tiers are refused and the combat tier modifiers are not applied (including cousin forms). The Tier button is hidden in the creator. Tests turn the flag on. Levels 1-5 stay active. The flag is folded into the parts hash only once on, so existing hashes and goldens are untouched. |
| 6. Clues | No recipe/clue model existed for fossils (the only clue model is observe). Added a counter: every inspected fossil or old carcass gives one clue (`parts.clues`, `parts.recipes = clues / 2`). Recipes themselves are left for the bone-spines slice. |

### Small core fix

`approach #X` during a fight on a creature other than the fight's opponent returned `-2`. It now returns `-14` (`in_fight`), like befriend/observe/gift. `attack` keeps `-2` and an invalid or dead target still returns `-2`. Test: `approach_in_fight()` in `tests/test_world.c`.

### Other integration fixes (Codex had not run these suites)

- `godot/creature/creature.gd` seeds stay `cpore.creature/4` (they had been relabelled /5 without level/tier, so they failed to parse; broke creature, play and lineage tests).
- `web/studio/genome.js`: the /4 to /5 upgrade no longer throws on a null part; the parity fixture `godot/creature/tests/parity/expected.json` was regenerated with `gen_parity.cjs`; `test_creature.gd` now expects a /4 GLB-part document to upgrade to /5 with level 1, tier 0.
- `godot/tests/ui_test.gd`: the keyboard loop uses the item count (the menu gained the Nest entry).
- `godot/game/tests/play_test.gd`: a new run starts with pico/pata/ojo, so the loadout is bite + spit and the saved creature is starter-filtered. One check tolerates the lethal last hit having no layer impact (the starter body loses the scripted fight).
- The nest panel in the creator is opaque (it sits over the stats column).

### Verification (all under `build/parts-nest/`)

| Check | Result |
| --- | --- |
| `make test` | PASS (includes world goldens and snapshots, `parts_nest_test` with the new `a25()` rules, `approach_in_fight()`, route certification, combat goldens). Goldens unchanged by the merge and by A25. |
| `make smoke` | PASS (Python parts/nest smoke now also checks the free `apply`). |
| `make tourney` | PASS: worst build field mean 62.3 percent, worst pooled pair 72.2 percent (gates 65/90). |
| `godot-test` | PASS (rc 0) |
| `godot-ui-test` | 538 checks, 0 failures |
| `godot-creature-test` | 1471 checks, 0 failures; realism 64 checks, 0 failures |
| `godot-studio-test` | 824 checks, 0 failures; web validator 8 files, 0 failures |
| `godot-parts-nest-test` | PASS (extended with free apply, needs-Evolve refusal, pending cost, tier button hidden) |
| `godot-play-test` | 217 checks, 0 failures |
| `godot-lineage-test` | 0 failures (Godot and island) |
| `godot-social-test` | 22 checks, 0 failures |
| `godot-actions-test` | 345 checks, 0 failures |
| `godot-soak` (10 sim minutes, xvfb software GL, images kept out of the repo) | 27 checks, 0 failures, no script errors |
| `parts_nest_evidence.gd` (1280x720 ES, and 1024x600 EN) | 34 checks, 0 failures each |
| `godot-agent-test` | not runnable here: cannot listen on 127.0.0.1:47110 in this sandbox (also unrelated to this change) |

The Godot suites print the usual headless shutdown diagnostics (leaked RID, ObjectDB, resources in use); they are not counted as leak checks.

### Evidence

`docs/evidence/godot/parts-nest/` (JPG, 1280x720, software GL under xvfb, driven by `godot/game/tests/parts_nest_evidence.gd`):

| File | Checklist item |
| --- | --- |
| `01_world_at_nest.jpg`, `02_creator_start_locked.jpg` | start: only pico/pata/ojo, locked parts absent, DNA 1 |
| `03_outside_nest_refused.jpg` | 16 m from the nest: editor refuses ("Only at the nest") |
| `04_fossil_marker_before.jpg`, `05_inspecting_ring.jpg`, `06_discovery_whisper.jpg` | surface find, 20-tick inspection, discovery whisper; a second inspect is refused in the run |
| `07_journal.jpg` | journal lists the discovered ids (still a stub) |
| `08_creator_discovered_priced.jpg`, `09_sketch_pending_cost.jpg` | discovered parts priced; a free sketch with a pending cost, balance unchanged |
| `10_evolve_refused_inline.jpg` | unaffordable Evolve: disabled button and inline "not enough DNA" |
| `11_valley_after_evolve.jpg`, `12_family_tree_ledger.jpg` | valley after Evolve (one generation, DNA lifetime unchanged, balance down); family tree shows the cousin branch and the `+ romo x1` ledger entry |
| `13_first_death_two_eggs.jpg` | first death: two eggs, hatchling form |
| `14_lineage_ends.jpg`, `15_back_at_last_save.jpg` | third death: end of the lineage, return to the last save |
| `small-en/` (1024x600, English) | creator, priced parts, inline refusal, valley and end of lineage at small-laptop size in English |

Not captured: keyboard focus traversal of the nest panel, journal overflow (the journal is a stub), a cousin in frame after Evolve (the cousin spawns about 32 m away; it is verified in the family tree and by the checks), and a tier purchase (tiers are off). The end-of-lineage text uses the engine default font, not the game's display font.

### Open questions and remaining work

- **Guard tier milestone semantics**: unchanged and now moot while tiers are off; needs a decision (count blocks?) before tiers are enabled.
- **T1/T2 tournament matrix**: not run; tiers are disabled, so the existing T0 tourney (worst build field mean 62.3 percent, worst pair 72.2 percent) is the acceptance gate. A dedicated tier matrix is required before the flag is turned on.
- **Journal design**: still a stub list of ids; no silhouettes, pagination, clue/recipe page or overflow handling.
- **Tier meshes**: tier forms have names and modifiers but no distinct meshes or previews.
- The creator's right-hand nest panel covers part of the stats column; a final layout pass is a design call.
- The fresh-run starter filter is applied in `island.gd` when no scenario is pending; the studio/menu flow that creates the player's genome is unchanged.
- Level-down below the owned level is not allowed (levels are never refunded); rearranging is free.
- The Godot headless shutdown diagnostics (leaked RID / ObjectDB / resources) are unchanged.
- `godot-agent-test` cannot run in this sandbox (cannot listen on 127.0.0.1:47110).
