# Brief (Codex Astra): M1 gait optimiser pilot (MuJoCo + CMA-ES)
Worktree `/home/diego/Desarrollo/cpore-wt/gaitopt`, branch `tools/gaitopt`. **Your sandbox cannot write git metadata and has no
X11: do NOT commit.** Leave work uncommitted; write `tools/gaitopt/README.md` + `docs/GAITOPT-REPORT.md` (intended commit
messages, results, open questions). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.
Implement slice **M1** of `/home/diego/Desarrollo/cpore-wt/_agent/briefs/motion-flight-plan.md` (read §1 fully: the 14-parameter
set, the cost, the realism yardstick; and the M1 slice). The owner approved D1 (DESIGN.md A29). The venv already exists with
mujoco 4.0.1, cma 4.6.0, numpy: use `/home/diego/Desarrollo/cpore-wt/_agent/gaitopt-venv/bin/python` (do not pip install).
Godot headless for `export_bodies.gd`: `timeout 600 nice -n 10 godot --headless --path godot --script res://...` (the GDExtension
library: symlink `godot/bin/libcpore.linux.template_debug.x86_64.so` from /home/diego/Desarrollo/cpore/godot/bin if missing).
**CPU budget: the owner is playing on this laptop.** At most 6 worker processes, all under `nice -n 19`; run the 10-body pilot
only (not the 200-body run). MuJoCo rendering offscreen with OSMesa/EGL software only (`MUJOCO_GL=osmesa` or `egl` on CPU); if
software rendering is unavailable, write per-frame joint traces instead of videos and say so. Results (JSON per body: best params,
cost breakdown, Froude, duty factor, CoT vs Taylor 1982) under `tools/gaitopt/results/pilot/` (small files only).
