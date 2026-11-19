# Parts, nest and eggs — C2 report

Worktree: `c2-parts-nest`, branch `c2/parts-nest`. All changes are uncommitted. No screenshots were taken. The implementation uses the existing fixed nest, social DNA account, creator, diegetic whisper API and `cp_stage_evolve` ancestry path.

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
