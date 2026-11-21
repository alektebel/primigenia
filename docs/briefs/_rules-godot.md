## Shared rules (all tracks)
- Work and commit only in your worktree (small commits; end messages with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`).
  Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout. Do not merge; Claude reviews and merges.
- Setup in a fresh worktree: `make godot` (or symlink `godot/bin/libcpore.linux.template_debug.x86_64.so` from
  /home/diego/Desarrollo/cpore/godot/bin), `make build/terrain_cli build/world_cli`, then `godot --headless --path godot --import`.
- Godot runs: always `timeout`, `--check-only` first, headless or `xvfb-run -a` with software GL (LIBGL_ALWAYS_SOFTWARE=1,
  `--rendering-driver opengl3`), `nice -n 10`, kill only your own pids, never `pkill -f`. Never use the GPU, the owner is playing on it.
- Determinism: C core uses integer/fixed math, `+ - * / sqrtf`, no libm trig; goldens byte-identical unless the brief says otherwise.
- UI motion follows Emil Kowalski's skills (`~/.claude/skills/emil-design-eng/SKILL.md`): ease-out for entering, never ease-in,
  UI motion ≤ 250 ms, press = scale 0.97, no animation on keyboard-triggered actions, nothing appears from scale 0.
- Before handing back: `make godot-test`, `make godot-ui-test`, `make godot-play-test` and the suites you touched green (exact counts),
  xvfb evidence under `docs/evidence/godot/<track>/` that you have looked at yourself, a short report `docs/godot/<TRACK>.md`.
