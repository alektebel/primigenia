# Brief (Codex): why does the hero limp after L1 posture?

Worktree `/home/diego/Desarrollo/cpore-wt/limp`, branch `anim/limp` (from main 6644d86). Your sandbox cannot write git metadata: **do not commit**; leave work uncommitted and write `docs/evidence/loco/limp.md` (diagnosis, numbers, intended commit message). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout. Read `AGENTS.md`, `docs/canon/MOTION.md`, `docs/evidence/loco/l1-posture.md`, `.claude/skills/cpore-motion/SKILL.md`.

Tracker test: M1 (posture) — owner, watching the before/after clip: "looks good, but why does it limp so much?"

## Hypotheses to check (Claude's, from the scorecard)
1. The vertical bob (and/or roll) in `godot/locomotion/loco_controller.gd` / `loco_rig_adapter.gd` repeats once per **stride** instead of once per **step**, so the body dips on only one side's footfall: the classic limp look.
2. Duty factor is 0.41 per foot in hero walk (a walk should be > 0.5): feet spend too little time on the ground, so the walk looks springy/hoppy.
3. The scorecard footfall diagram is broken: `footfall.contact` rows are all true in `docs/evidence/loco/score/ffea2c1/hero_walk.json` even though duty is 0.41. Fix the recording in `godot/devtools/zoo/loco_score_core.gd` so the diagram shows real contacts.

## Do
- Add a **limp index** metric to the scorecard: body-root vertical drop (and roll) measured at each footfall, left vs right side, ratio max/min (1.0 = even). Target ≤ 1.15 (starting value). Add it to `docs/research/loco-reference.json` as universal.
- Fix the footfall recording.
- Fix the cause(s) of the limp, visual GDScript only (no `core/`, no C state, same trajectories).
- Measure: `make godot-loco-score LOCO_LABEL=limp` (headless, ~32 s, `nice -n 10`, `timeout`) and `python3 tools/loco/compare.py ffea2c1 limp`. Keep L1's gains (head pitch, slip, roll targets).
- Suites (headless): `make godot-loco-test`, `make godot-devtools-test`, `make godot-test`, `make godot-feel-test`, `make godot-actions-test`, `make godot-play-test`. Run `make godot` first if the extension is missing.

## Report in docs/evidence/loco/limp.md
Root cause with numbers, limp index before/after per 4-leg body, compare table, suites with counts, files changed.
