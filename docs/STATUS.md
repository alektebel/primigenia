# Status

Updated 2026-11-24 (late). Session: creature-stage loop + island realism. Rewritten at the end of every session; keep it to one page. **Resume rule:** the owner asked to stop at 93% of the weekly Claude quota and resume from this file.

## Focus now
1. **Island realism** (`docs/plans/island-realism.md`, DESIGN A95–A99): freeze Star massif → climate → jungle study → Godot build → **loop re-tune** on the new island (the creature-loop focus resumes there; `make godot-loop-score`).
2. Owner picks come from the phone page https://claude.ai/artifact/XNaa8QYk3TqHHSwZdwk5XE (six labs; stars and notes saved to its db collection `picks`, read with ArtifactData). When a lab changes, rebuild its copy (scratchpad build + injected pick script) and republish.

## Main: `claude/v0.1-restore`
Merged today, after the jump merge:
- **Plans:** befriend port (A82), night sky, island realism.
- **Loop and world:** loop tune 1 (40 m flee leash, bot fixes), ambient fliers (visual only), bellow-stride (A75).
- **Labs:** sing notes, mood card, signature v2 and v3, engulf, ice, oil/fire, island layouts.
- **Island P0:** `make godot-island-path`; baseline sheet in `docs/evidence/island/path/`.
- **Island F0:** island desc, exact layout-1 parity.
- **Island F1:** splines, masks, protect, trails, **terrain v5**. Goldens, routes and creature scenarios re-pinned.
- **Sky H0:** Compatibility spike (`docs/evidence/sky/h0-spike.md`).
- **Sky H1:** Hillaire LUTs on CPU (`make godot-atmo-test`).
- **Climate M0–M1:** Smith–Barstad kernel (`make climate-test`).

`godot/bin` rebuilt after F1 (rc 0).

**Signature lab:** owner picked 11 (A94). Mantis and chameleon approved (A96; the mantis breaks any armour in one hit). Death roll redone twice (body flips first, head follows); waiting for the owner.

## Agents in flight (worktrees in `/home/diego/Desarrollo/cpore-wt/<name>`)
| Branch (worktree) | Step | Next |
|---|---|---|
| `island/f2-editor` (island-f2) | F2 phone map editor, WASM preview | review, merge, wire into the phone page (A99 (11)) |
| `climate/m2-pipeline` (climate-m2) | M2 climate maps on Star massif, region gates | review maps, merge |
| `lab/forest` (forest-lab) | L0 refs + L1 jungle lab, 4 versions (cloud forest, A99 (5)) | review, owner pick (L2) |
| `lore/exoplanets-40` (lore-exo) | council autoloop | Opus review step 4 |

Next waves:
1. F3 owner tuning
2. F4, M3 and H2
3. B1: switch the game to Star massif; re-record scenarios
4. T and G steps
5. R: loop re-tune

Max 3 implementation agents.

## Waiting on the owner
- **A100 torn in two:** 6 questions asked:
  - gripping jaws only
  - triggers with 2+ gripping attackers and HP < ⅓
  - instant death, body split in two
  - documentary-level gore
  - the player's pack can do it too
  - a warning cue
- Out-of-combat HP regen (Garfio wins 8/8 at full HP; deaths come from arriving hurt).
- Night sky's 12 questions (`docs/plans/night-sky.md`).
- Lab stars on the phone page: engulf, ice, oil, social duel feel, death roll v3.
- `sudo systemctl enable --now nvidia-powerd`; fps on the RTX (sky cost, A99 (14)).

## Known issues
- `make terrain-test` → `terrain-metrics` fails on seed 31337 (Rb 6.0036 > 5.5). The pin has been stale since the v4 rivers; the 4-point Strahler fit is noisy. Recommend widening the pin.
- OG9 on layout 1 shows a sky-coloured band below the nest (fix in B1).

## Design queue (one study at a time, A60)
rolling (A90) → v1 giant (A88) → lasing crystal (A87) → three-worlds feel lab (A93) → torn-in-two study (A100, after the owner's answers). DESIGN entries this session: A80–A100.

## Background jobs (die on shutdown)
- Lore exoplanets autoloop: `cd cpore-wt/lore-exo && nice -n 10 python3 tools/lore/council/autoloop.py --no-wait-opus`.
- Agent logs: `/home/diego/Desarrollo/cpore-wt/_agent/`.

## Next free ids
- C events: next free **32**.
- Snapshot: main = 16 (in the island plan, only W1 weather bumps it).
- Terrain version: 5.
- `CP_STAGE_VERSION`: 3 (M3 → 4).
