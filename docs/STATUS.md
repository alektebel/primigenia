# Status

Updated 2026-11-25 (01:20). Session: creature-stage loop + island realism. Rewritten at the end of every session; keep it to one page. **Resume rule:** the owner asked to stop at 93% of the weekly Claude quota and resume from this file.

## Focus now (owner, 2026-11-25): the Star massif playtest feedback
**Start here:** `docs/feedback/2026-11-25-star-massif-playtest.md` (24 notes, grouped). Order: P1 rendering bugs (torn mountain sheets at night, ground vanishing when looking up) → P2 controls (selecting must not stop movement, run to attack, pack defends) → P3 debug switches (infinite stamina, ×2/×5 speed) → P4 creature look/anim → P5 grilling (befriend own species with 3 slots, camera freedom, trap burrowers).
Island realism continues in parallel (`docs/plans/island-realism.md`): M3 in flight, then H2/H3, T1 (after the forest pick), G, R.

## Main: `claude/v0.1-restore` (ac5801e6 + docs)
Merged 2026-11-24/25:
- **Island:** P0 path sheet, F0, F1 (terrain v5), F2 phone editor, F4 freeze (A101: Star massif as it is), **B1: the game island is Star massif** (nest on the dry lakeshore, star nav/routes/first-quest/secrets; layout-0 variants retired; scenarios re-recorded).
- **Climate:** M0–M2 (Smith–Barstad, WASM, region gates), M4 (flora and grass follow biome/veg).
- **Sky:** H0 spike, H1 Hillaire LUTs on CPU.
- **Labs:** forest lab (L1, 4 structures), signature redo (mantis one-hit armour break, death roll v3), plus earlier labs.
- **Lore:** autoloop-2 cleanup; council fixes on lore-exo.

`godot/bin` rebuilt after B1 (rc 0); `make godot-play-test` on main 247/0. B1 gates: make test rc 0, godot-test 2285/0, devtools 1387/0, actions 473/0, soak 32/0, routes 294/294, e2e 31/0 on seeds 1/7/42.

## Agents in flight (worktrees in `/home/diego/Desarrollo/cpore-wt/<name>`)
| Branch (worktree) | Step | Next |
|---|---|---|
| `climate/m3-sim` (climate-m3) | M3: trunks + cover in the sim (`CP_STAGE_VERSION` 4; cover/trail multipliers ship OFF). **Paused 01:30 at the owner's request**: core committed (f7a0241f), WIP tests/fixtures (6ac83bee); its last words: "scenarios re-recorded, commit core, then export route fixtures". | restart a fresh agent on the branch: finish route fixtures, run all gates, report; then review, merge, rebuild |

Everything is shut down (no agents, no Godot, council paused). Restart agents from this table on the next session.

Council (lore-exo autoloop) **paused**: all chair/referee quotas out. Recommended restart once Codex resets (2026-11-25 23:13) with Codex as chair and referee; owner hasn't confirmed.

## Waiting on the owner
- Nest-valley lake: keep (recommended) or drain.
- Council restart with Codex.
- A100 torn in two: 6 questions (jaws only; 2+ grippers and HP < ⅓; instant death; documentary gore; pack can do it; warning cue).
- Out-of-combat HP regen. Night sky's 12 questions. Lab stars on the phone page (https://claude.ai/artifact/XNaa8QYk3TqHHSwZdwk5XE): forest structure A–D, death roll v3, engulf, ice, oil, duel.
- The game ran on the AMD iGPU (`failed to load driver: nvidia-drm`); `sudo systemctl enable --now nvidia-powerd`, then fps on the RTX.

## Known issues
- See P1 of the playtest file (B1 regressions on the 8 km island).
- Loop score on Star massif fails: species by 30 min (4–5 < 8), fights per kill seed 42 (3), Garfio win rate (unmeasured). For R.
- B1 risks: far GO into the cave refused (7.8 m nav cells); 2-legged bodies can't use the three passes; uncached gen ~10.5 s (W13 limit); lake water-quad shows a pale rectangle; first cave ~370 m from the nest.
- `make terrain-test` → `terrain-metrics` seed 31337 (Rb 6.0036 > 5.5), stale pin; recommend widening.

## Design queue (one study at a time, A60)
rolling (A90) → v1 giant (A88) → lasing crystal (A87) → three-worlds feel lab (A93) → torn-in-two study (A100) → trap burrowers (note 396323) → end-of-stage recap with a 16-type creature personality (owner idea 2026-11-25, playtest file P5). DESIGN entries: up to A102.

## Background jobs (die on shutdown)
- Agent logs: `/home/diego/Desarrollo/cpore-wt/_agent/`. Owner's game log: `/tmp/claude-1000/owner-game.log`.

## Next free ids
- C events: next free **32**. Snapshot: 16. Terrain version: 5. `CP_STAGE_VERSION`: 3 (M3 → 4).
