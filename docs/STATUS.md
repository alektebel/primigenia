# Status

Updated 2026-11-21 (integration of all WIP + limp fix merged; game relaunched for the owner). Rewritten at the end of every session; keep it to one page.

## Focus now
**Procedural creature movement that looks like the references.** Order (research plan `docs/research/procedural-locomotion.md`, tracker stages M0–M6):
1. **L0 scorecard — merged 39e28bc** (`make godot-loco-score`, 32 s; baseline label 9095d8c: every body fails head pitch, leg extension, foot slip; gallop has no flight phase; pivots on U-turns). Measures measure each body × scenario in the zoo (head pitch, shoulder/hip ratio, torso roll vs hand plants, foot slip, footfall diagram, turn radius) and compare against keypoints measured on the reference clips. Owner approved 2026-11-21 (D-01).
2. **L1 posture merged** (head level, roll, slip fixed; leg extension 0.84–0.88 and bob 13% short of target: needs C speed per body, D-26; small knee-flip rise on trotter steps). Next → torso roll → arms that walk (D-12, reach rule) → turning → gallop → slopes → eat/dig/idle → many legs/perf.

Reference clips: gorilla knuckle-walk (tracker X3, owner's Downloads) and Spore captures in `~/Desarrollo/cpore-refs/spore-captures/` (never commit). Capture tool: `docs/research/loco_review.gd`.

**Skin v1 merged ed646ab** (plastic shine 6→0 fails, night crush 8→5, flat light 8→2; night/dist readability metric is wrong: mask includes shadow+nest → fix to creature-only mask; beetle stays dark by palette; dawn/dusk warmth remainder = capture/world light, D-25).

**Creature fit merged c012d75** (part-fit check; teeth, eyes, limbs fixed). Follow-ups: limb pattern UVs along the limb axis + belly mix cap 0.5 (skin shader, next skin round); horn position via the starter genome.

**Visual scorecard merged 0c9b70d** (`make godot-look-score`, ~9 min; baseline weak spots: flat world day cycle, night readability, creature shine, bloom at the spring, forest floor noise/saturation, low/medium parity). Lab: `web/lookdev/index.html`.

**Canons:** `docs/canon/MOTION.md` (A34), `docs/canon/LOOK.md` (A36). Open with 48 h auto-accept: D-22 (motion refs), D-24 (look refs), D-25 (world day cycle next).

## Main
`claude/v0.1-restore` at df9585b: integration of 19 branches (`docs/INTEGRATION-2026-11-21.md`) + limp fix (`docs/evidence/loco/limp.md`: hero duty 0.41→0.53, slip 0, bob 23.6→19.4 cm, limp index 1.07). Suites: make test pass, M0 1266/0, ui 972/0, play 237/0, studio 942/0, loco 299/0, creature-fit pass, first-quest e2e 29/0. Loco score vs ffea2c1 unchanged before the limp merge. First quest is A38.
Launch on the RTX: `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only godot --path godot` (without it the game picks the AMD + compatibility).

## Branches in flight
| Branch | State | Next step |
|---|---|---|
| `w11-alpine` | skipped by the integrator (rewrites terrain v4 heights/goldens, drainage unresolved) | Owner: merge or close |
| `anim/gait-lab` | **merged fa67103**: lab confirms wrong gait selection at 5.1 m/s; port rules in `docs/evidence/loco/gaitlab.md`. Owner: "2 m/s seems the sweet spot" (noted on D-26) | Port to loco_gait.gd + D-26 speed once the owner confirms |
| `devtools/options` | **merged d6162ea**: F10 option mode + Shift+F8 notes (`tools/feedback/notes.py list`); devtools 1084/0. Follow-up: HUD text hard to read on bright backgrounds | Owner tries DT-OPT, DT-NOTES |
| `lore/food-web` | **merged 9eed94f**: 36 new species, every trophic level; contact sheet `docs/evidence/lore/food-web-contact-sheet.jpg` | Owner L-TROPHIC |
| `art/foodweb-flora` | **merged**: 8 plant recipes, M0 green. drifting_ash and pozo_de_agua at density 0: test_flora:140 allows only cinta_de_marea on sea cells | Owner: allow them on sea cells? |
| `art/world-light` | **merged 30971e7** (A1/D-25): light follows the day; warmth fails 39→7, saturation 8→0, noise 3→0, night ground fixed; night-specific targets in look-targets.json. Left: plastic_shine 6, tier parity 6, tiling 3, night creature ratio 9 | Owner blind A/B `docs/evidence/look/world-light-ab.jpg` (key .jpg.key.json); next art A2 |
| `lore/food-web` | **Lore lane, running** (Sonnet + council): Primigenia full food web; brief `docs/briefs/trophic-web.md` | Review validate + contact sheet; owner L-TROPHIC |
| `lore/exoplanets-40` | **Lore lane**: step 1 done abedd69 (Opus: 40 planets, NASA archive 2026-11-21, 13 water-carbon / 11 silicon); **step 2 Codex running** (exoplanet kind, derivation sheet, validator; brief `docs/briefs/exoplanets-step2-codex.md`, log `_agent/codex-lore-exo.log`) | Commit Codex work; run council step 3; Opus review step 4 |
| `tools/gaitopt` | merged as tooling; pilot failed (6/10 bodies fall) | Paused; D-02 |

Integration follow-ups (owner): wild slot reserve for cousins (radial animals capped at 23 of 24); Garfio no longer charges before the first evolve; cave mesher not wired into the island; untracked debug files in cpore-wt/art-underwater.

**Lore (`lore/autoloop-2` merged):** (0) **NEW, owner 2026-11-21: Primigenia full food web**, a random batch covering every trophic level (producers through apex, scavengers, decomposers, parasites, mutualists), brief `docs/briefs/trophic-web.md`; first lore item; (0c) **NEW, owner 2026-11-21: 40 real exoplanets, renamed, reverse-engineered for life** (Opus data/seeds/review, Codex pipeline kind `exoplanet`, council writes), brief `docs/briefs/exoplanets-40.md`, after the food web; (0b) **D-28 proposal**: oxygen gates every flame (creature flamethrower → steam/acid jet below ~16% O₂ or underwater, wildfire ≥18%, industry on charge at low O₂), in `lore/rules/technosphere.md`, 48 h auto-accept; (1) technosphere pass: every world gets its heat-path fact per A37 / `lore/rules/technosphere.md` (council proposes, astrobio referee judges); (2) resume the autoloop for the 4 paused worlds (wheels died mid-run at shutdown; orbital, metallic, deepinterior queued); (3) tech-tree council A30 on top. Fix the 2 validate errors in void/mycelia/oddities.

## Background jobs (die on shutdown)
- Lore autoloop: `tools/agents/agents.sh restart lore` (worktree lore-autoloop2).
- Codex resume of species-v8 / gaitopt: only when the owner wants them continued.

## Next free ids
- C events: next free **32** (moves FELL 27, RECIPE 28, VOLLEY 29; first-quest DUG 30, MOVE_USED 31; integration branch).
- Snapshot version: integration branch = 11 → next **12**.

## Waiting on the owner (tracker)
- Decisions D-02 … D-20 (D-12 arms reach rule, D-19 game-design skill as brief template, D-20 Blender props trial).
- Tests marked "ready": 14 merged features never tried by hand (M0, C, F, W rows).
- WL1: low tier 40 m cascade? terrain casting shadows later? meadow/spring look on RTX.
- First quest: wing bed also gives fire gland; flame role Poke; DNA rewards 10/10/5/20/25 (D-13).
