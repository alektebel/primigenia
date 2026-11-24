# Status

Updated 2026-11-24. Session: creature-stage loop tuning with owner playtests. Rewritten at the end of every session; keep it to one page. **Resume rule:** the owner asked to stop at 93% of the weekly Claude quota and resume from this file.

## Focus now
Tune and perfect the **creature-stage loop**, start to finish (plan: `docs/plans/creature-loop.md`). The owner plays, leaves notes (N, F11, Shift+N) and answers question cards. Pull them every session with `python3 tools/feedback/notes.py list` and `python3 tools/feedback/questions.py pull-answers`.

**Next single focus, once the C branches below are merged:** tune the loop against `make godot-loop-score`. Baseline `docs/evidence/loop/score/baseline` fails on: befriend late (988–1178 s vs 720), few species (2–3 in 10 min vs ≥4), dead stretches (up to 180 s), deaths before evolve, 3 fights per kill, Garfio wins every fight, cousin 120 m from the nest (T13).

## Main: `claude/v0.1-restore` (8f383bf)
Merged 2026-11-23/24: creature feedback (A54), flight port (A56/A57), roster v9, slope grip (A59/A66), starter B kit (A62), context attacks (A72–A75, snapshot 15), camera T4 (0 snaps), **jump (Space, snapshot 16)**, befriend labs + sing notes (A80), social duel mood card (A81).
Last jump-branch runs: C rc 0, M0 1433/0, play 247/0, devtools 1387/0, camera 4/0, first-quest 30/0.

## Branches in flight (stopped 2026-11-24 night: Claude 5-hour limit, resets 05:30 Madrid; Codex limit until 2026-11-25 23:13)
Resume each from its worktree in `/home/diego/Desarrollo/cpore-wt/<name>`; all have WIP on disk.
| Branch (worktree) | State | Next step |
|---|---|---|
| `sim/loop-tune-1` (loop-tune) | Evidence + proposal 1 merged. Implementing: 40 m flee leash (derived from home, no new state), bot fixes (seed-42 hang, explore loop, deliberate Garfio duel); C tests were running | Finish suites, re-run loop score 3 seeds, merge (A33) |
| `world/ambient-fliers` | 4 visual-only flier species, 36 birds; test_fliers 816/0; clips in `_agent/fliers-clips/` partly recorded | Review clips, run all suites, merge |
| `combat/bellow-stride` | Codex started, Sonnet finishing (A75 far roar set B, layered); tests were running | Check set A goldens unchanged, merge |
| `lab/island-layouts` | 3–4 candidate islands for A83+A86 (8 biomes, ~5 km), picker `web/gaitlab/island.html`; WIP uncommitted | Finish, owner picks |
| `lab/ice` | Ice study (A85) restarted after a network outage; little or no work yet | Build 3 moves × 3–4 versions |
| `plan/night-sky` | Fable 5.2 designs the night sky + planets/moons + stargazing (owner request) → `docs/plans/night-sky.md`; restarted, little or no work yet | Finish plan, owner questions |
| `lore/exoplanets-40` | Fix 3 merged on branch (1b40f63); autoloop running (Codex chair falls back to DeepSeek) | Opus review step 4 |
| `world/ambient-fliers` paused sibling `ui/creator-c6` | paused | Resume later |

Merged today into main: jump (snapshot 16), camera T4, sing notes (A80), mood card (A81), befriend port plan (A82, `docs/plans/befriend-port.md`), signature attacks lab v2, engulf lab (A84), loop evidence.
**Owner picks waiting in labs:** `signature.html`, `engulf.html`, `social_duel.html` (feel and numbers), `befriend_bodies.html`.
**Design queue (one study at a time, A60):** ice → oil vomit + flamethrower (A89/A90) → rolling (A90) → v1 giant (A88) → lasing crystal (A87) → three-worlds feel lab (A93). Soarer + squid launch go with the real C flier species. New DESIGN entries today: A80–A93.

## Design state (all in `docs/DESIGN.md`)
- **Movement picks:** A42–A53 for B, bipeds, radial, trilateral, two-headed, snake, worm, inchworm, slug, eel, octopus (A55).
- **Flight picks:** A56 for starter B, A57 for the hatchling.
- **Arms used:** A58.
- **Slope grip:** A59.
- **Actions:** process A60. Repertoire A61/A62 in `docs/design/repertoire.md`. Pending picks:
  - starting 4: peck/bite, pounce, acid spit, roar, with dodge as a universal key
  - signature attacks
  - befriend conditions
- **Bite study:** `web/gaitlab/bite.html`, 4 versions; owner pick pending. Next: shared impact effects, then pounce, acid spit, roar.

## Waiting on the owner
- Bite version pick.
- Signature attack picks.
- Skills in v1 (48 h default: no).
- Tripo trial (needs the owner's account).
- `sudo systemctl enable --now nvidia-powerd` for 45 W.
- Confirm fps and load time on the RTX.

## Background jobs (die on shutdown)
- Lore exoplanets autoloop: `cd cpore-wt/lore-exo && nice -n 10 python3 tools/lore/council/autoloop.py --no-wait-opus` (resumable).
- Agent logs: `/home/diego/Desarrollo/cpore-wt/_agent/`.

## Next free ids
- C events: next free **32** (check the branches in flight first).
- Snapshot: main = 16. Renumber at merge.
