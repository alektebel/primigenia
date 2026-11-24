# Status

Updated 2026-11-24. Session: creature-stage loop tuning with owner playtests. Rewritten at the end of every session; keep it to one page. **Resume rule:** the owner asked to stop at 93% of the weekly Claude quota and resume from this file.

## Focus now
Tune and perfect the **creature-stage loop**, start to finish (plan: `docs/plans/creature-loop.md`). The owner plays, leaves notes (N, F11, Shift+N) and answers question cards. Pull them every session with `python3 tools/feedback/notes.py list` and `python3 tools/feedback/questions.py pull-answers`.

**Next single focus, once the C branches below are merged:** tune the loop against `make godot-loop-score`. Baseline `docs/evidence/loop/score/baseline` fails on: befriend late (988–1178 s vs 720), few species (2–3 in 10 min vs ≥4), dead stretches (up to 180 s), deaths before evolve, 3 fights per kill, Garfio wins every fight, cousin 120 m from the nest (T13).

## Main: `claude/v0.1-restore` (8f383bf)
Merged 2026-11-23/24: creature feedback (A54), flight port (A56/A57), roster v9, slope grip (A59/A66), starter B kit (A62), context attacks (A72–A75, snapshot 15), camera T4 (0 snaps), **jump (Space, snapshot 16)**, befriend labs + sing notes (A80), social duel mood card (A81).
Last jump-branch runs: C rc 0, M0 1433/0, play 247/0, devtools 1387/0, camera 4/0, first-quest 30/0.

## Branches in flight
| Branch | Who | State | Next step |
|---|---|---|---|
| `lore/exoplanets-40` | council | Fix 3 (1b40f63): multi-key `because:`; autoloop restarted 2026-11-24 (log `_agent/lore-exo-autoloop.log`) | Opus review step 4 → `docs/lore/EXOPLANETS.md` |
| `world/ambient-fliers`, `ui/creator-c6` | paused | WIP committed, 1 commit each | Resume one by one |

**Proposed overnight (awaiting owner go):** loop tuning measuring pass, flying wildlife, signature-attack picker lab, Opus plan for porting befriending (A76–A81), then "bellow in stride" (Codex).

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
