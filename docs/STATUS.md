# Status

Updated 2026-11-23, ~01:30. Session: creature-stage loop tuning with owner playtests. Rewritten at the end of every session; keep it to one page. **Resume rule:** the owner asked to stop at 93% of the weekly Claude quota and resume from this file.

## Focus now
Tune and perfect the **creature-stage loop**, start to finish (plan: `docs/plans/creature-loop.md`). The owner plays, leaves notes (N, F11, Shift+N) and answers question cards. Pull them every session with `python3 tools/feedback/notes.py list` and `python3 tools/feedback/questions.py pull-answers`.

**Next single focus, once the C branches below are merged:** tune the loop against `make godot-loop-score`. Baseline `docs/evidence/loop/score/baseline` fails on: befriend late (988–1178 s vs 720), few species (2–3 in 10 min vs ≥4), dead stretches (up to 180 s), deaths before evolve, 3 fights per kill, Garfio wins every fight, cousin 120 m from the nest (T13).

## Main: `claude/v0.1-restore` (c125f37 + design commits)
Merged this session:
- speed by body size plus the gait port (A39, A44)
- owner move styles (A42–A53)
- F10 walk speed, run speed and gallop look
- creator flow, scored 63/63 by `make godot-creator-score`, plus a camera fix
- creator scorecard
- N notes, F11 overlay and Shift+N browser
- verb-first targeting (F/B/R/O/I), with the first-quest e2e at 30/0
- loop telemetry plus `make godot-loop-score`
- labs: styles 2/3/4, octopus, flight, bite

Last suite runs on main: M0 1385/0, play 237/0, devtools 1318/0. `make test` routes time out on the loaded machine; rerun when it is quiet.

## Branches in flight
| Branch | Who | State | Next step |
|---|---|---|---|
| `fix/creature-feedback-1` | Sonnet | A54 batch: shoulders (note e165fe), start/stop, close camera (committed), dig anywhere with X, faster gallop plus a dynamic gallop start | Review clips, merge |
| `feat/jump` | Sonnet | Space = jump; winged creatures press Space again in the air to fly; Space keeps its combat meaning in combat | Review, merge **before** flight-port |
| `anim/flight-port` | Sonnet | A56/A57 flight picks into flight_mode, plus the F10 wingbeat scaling option | Merge after jump |
| `sim/roster-v9` | Sonnet | T9: MAX_WILD 32, SPECIES 12, cousin and flier slots, one snapshot bump | Merge, then re-run the loop score |
| `sim/slope-grip` | Codex | A59 grip limit per creature; brief `docs/briefs/slope-grip.md`; Codex can't commit | Commit, review, merge |
| `lore/exoplanets-40` | council | Derivation fix 472c68f works; autoloop running (log `_agent/lore-exo-autoloop.log`, ~30–40 min per world) | Step 4: Opus review → `docs/lore/EXOPLANETS.md`. Épsilon Indra seed teq needs a data fix |
| `cam/occlusion` | Claude | T4 done (A76 focus): sphere-cast camera, prop proxies, eased boom, cut on teleport; `make godot-camera-test` 0.0-0.03% occluded, 0 snaps (before: 10-18 snaps) | Review, merge |
| `world/ambient-fliers`, `ui/creator-c6` | paused | WIP committed; the owner wants one focus at a time | Resume one by one |
| `anim/action-styles` | stopped | Replaced by the careful one-action-at-a-time process (A60) | — |

Merge order for the C branches: jump → creature-feedback → slope-grip → roster-v9 → flight-port. Rebuild with `make godot` and re-test after each merge.

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
- Snapshot: main = 11. roster-v9 bumps it; jump, slope-grip and creature-feedback may too. Renumber at merge.
