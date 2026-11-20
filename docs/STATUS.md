# Status

Updated 2026-11-21. Rewritten at the end of every session; keep it to one page.

## Focus now
**Procedural creature movement that looks like the references.** Order (research plan `docs/research/procedural-locomotion.md`, tracker stages M0–M6):
1. **L0 scorecard** — measure each body × scenario in the zoo (head pitch, shoulder/hip ratio, torso roll vs hand plants, foot slip, footfall diagram, turn radius) and compare against keypoints measured on the reference clips. Owner approved 2026-11-21 (D-01).
2. L1 posture and head → torso roll → arms that walk (D-12, reach rule) → turning → gallop → slopes → eat/dig/idle → many legs/perf.

Reference clips: gorilla knuckle-walk (tracker X3, owner's Downloads) and Spore captures in `~/Desarrollo/cpore-refs/spore-captures/` (never commit). Capture tool: `docs/research/loco_review.gd`.

## Main
`claude/v0.1-restore` at 6301006. Last suite counts: M0 1138, ui 882, play 237, actions 383, entry 23, menu 33, bridge 42, studio 914 (3 SCRIPT ERROR lines in M0/ui, unverified whether pre-existing).

## Branches in flight
| Branch | Worktree | State | Next step |
|---|---|---|---|
| `c2/moves-recipes` | cpore-wt/c2-moves | WIP b0ed502, main merged, clean | Run godot play, flight, devtools, bridge, menu, moves-recipes, studio; finish MOVES-RECIPES-REPORT table; merge |
| `c2/first-quest` | cpore-wt/first-quest | WIP ab2cefd, e2e green (chain ends tick 2904), clean | After moves merges: renumber DUG/MOVE_USED after 29, snapshot 10; flame evidence; results table |
| `c2/species-v8` | cpore-wt/species-v8 | Codex, 34 dirty files | Sonnet commits + integrates; events after first-quest |
| `art/wl6-cave-mesher` | cpore-wt/wl6-cave | Codex C++ mesher, uncommitted | Sonnet art + integration |
| `tools/gaitopt` | cpore-wt/gaitopt | Codex, pilot failed (6/10 bodies fall) | Paused; M1b balance spike pending owner (D-02) |
| `docs/continuity` | cpore-wt/continuity | this setup | Owner approval to merge |
| `tools/loco-score` | cpore-wt/loco-score | Sonnet subagent building the L0 scorecard (brief `docs/briefs/loco-score.md`, 9095d8c), started 2026-11-21 | Review evidence; then the blind A/B page in the tracker |

**Old unmerged branches (5+ days, need triage: merge, or close):** art-food, art-meteor, art-nest, art-remains, art-species, art-underwater (78 dirty), dem, feel-camera (10 dirty), idol, loco (5 dirty), m-e2e, m-ecology, m-garfio, m-vista, w11-alpine. Run `tools/agents/agents.sh status` for the live list.

## Background jobs (die on shutdown)
- Lore autoloop: `tools/agents/agents.sh restart lore` (worktree lore-autoloop2).
- Codex resume of species-v8 / gaitopt: only when the owner wants them continued.

## Next free ids
- C events: moves takes FELL=27, RECIPE=28, VOLLEY=29 → next free **30** (first-quest DUG, MOVE_USED).
- Snapshot version: moves = 9 → next **10**.

## Waiting on the owner (tracker)
- Decisions D-02 … D-20 (D-12 arms reach rule, D-19 game-design skill as brief template, D-20 Blender props trial).
- Tests marked "ready": 14 merged features never tried by hand (M0, C, F, W rows).
- WL1: low tier 40 m cascade? terrain casting shadows later? meadow/spring look on RTX.
- First quest: wing bed also gives fire gland; flame role Poke; DNA rewards 10/10/5/20/25 (D-13).
