# Brief: speed by body size (A39 / D-26) and gait port from the lab (main line M2+M3)

Worktree `/home/diego/Desarrollo/cpore-wt/speed-gait`, branch `anim/speed-gait`. Tracker: M1 (movement looks like the references), D-26 (decided 2026-11-22).
Read first:
- `AGENTS.md`
- `docs/DESIGN.md` A29, A34, A39
- `docs/canon/MOTION.md`
- `.claude/skills/cpore-motion/SKILL.md`
- `docs/evidence/loco/gaitlab.md`: the 9 port rules, the source of truth
- `web/gaitlab/index.html` (reference implementation)
- `docs/evidence/loco/limp.md`
- `godot/locomotion/loco_gait.gd` and `loco_controller.gd`

## Part 1 — C core: speed from body size (critical code, deterministic, fixed-point)
- The owner's decision: the hero cruises at **about 2 m/s, a calm walk** (hip height about 1.7 m, so Fr ≈ 0.24). Chasing or fleeing (pursue or flee AI states, and the player's sprint input if one exists, otherwise the current run speed path) uses a **trot or run, Fr ≈ 1.5** (starting value).
- Every other body moves at the same Fr: v = √(Fr·g·h), with h the hip or leg length from the body/genome. Keep the existing global multiplier. Mass still slows acceleration and turning (A29).
- Find where the C sim sets creature speed today (5.1 m/s for the hero). Replace it with this law in fixed-point. Mark the numbers as starting values, citing Alexander & Jayes 1983.
- **Determinism:** goldens will change. Regenerate them once, with the reason in the commit. If the snapshot layout changes, use snapshot 12 (next free; next free event 32).
- Re-run winnability (Garfio, `winnability_c.gd`) and `make godot-feel-test`. Report chase and escape outcomes before and after. If the player can no longer escape or catch, tune Fr_run (not the walk) and say so.

## Part 2 — Godot: port the gait lab rules (visual only)
In `loco_gait.gd` and `loco_controller.gd`, port rules 1–9 of `docs/evidence/loco/gaitlab.md`:
- gait from Fr with hysteresis
- duty curves
- stride law, with Fr capped at about 6 and the spacing cap for many-legged bodies
- footfall offsets
- pinned stance feet and the swing arc
- bob phase from the stance state
- reach safety
- one-stride blends
- roll and lean

Enable the F10 option `gait` (today / froude), so the owner can compare live. Default: froude.

## Measure
- `make godot-loco-score LOCO_LABEL=<step>`, then `tools/loco/compare.py ffea2c1 <step>`, after each part.
- Targets (MOTION.md §5): hero walk bob ≤ 8%, leg extension ≥ 0.9, slip p95 < 3 cm, gallop airborne > 0.05, knee flips 0.
- Clips: hero walk and hero run with `godot/devtools/zoo/loco_clip.gd`, software GL, to `/home/diego/Desarrollo/cpore-wt/_agent/loco-clips/`.
- Suites: `make test`, `make godot-test`, `make godot-play-test`, `make godot-feel-test`, `make godot-loco-test`, `make godot-devtools-test`, and the first-quest e2e.

## Rules
- Software GL only, `timeout`, `nice -n 10`, `--check-only` first, kill only your own pids.
- Long runs: start them detached and wait with loops under 9 minutes. Do not hand back while a run is going.
- Commit after each part. Do not merge. Report: before/after speeds per body, the scorecard compare, winnability, suites, clip paths.
