# Brief: creature creator direct manipulation
Worktree `/home/diego/Desarrollo/cpore-wt/creator-ix`, branch `studio/creator-ix`. Code in `godot/studio/` (the creator). Owner's words:
1. "If I hover over an eye or part, I should reduce or augment depending on zoom out or in." Mouse wheel over a hovered part
   scales that part (clamped to its genome limits, symmetric pair together); wheel over empty space still zooms the camera.
   Show a subtle hover highlight + a small scale readout while scrolling.
2. "I should be able to move a joint whenever I want if I take it and drag it around." Joints (limb joints, spine joints)
   are always draggable: hover shows a handle, LMB-drag moves it (IK/limits respected, mirrored pair follows), no mode switch.
3. "If I hover over the column, I should see an arrow to extend both the head column and tail column, and drag it around."
   Hovering the spine shows two arrow handles, at the neck/head end and the tail end; dragging extends/shortens the neck and
   tail (adds/removes vertebra segments within limits) and bends them along the drag.
4. "Legs or arms should only change muscle type in case we make a left click, and then we get a circle around it to choose the
   type of actuators." Remove any other path that changes actuation; a click (not a drag) on a limb opens a radial ring around
   it with the actuator types (muscle, hydraulic, exoskeleton, hydrostatic — the realism layer's types, see
   `docs/DESIGN.md` A24 and `godot/creature/` realism code) with icons, the current one marked; choosing applies it; Esc/click
   outside closes. Ring: scale 0.96→1 + fade 160 ms ease-out from the limb, not from the screen centre.
Distinguish click vs drag by a 4 px / 200 ms threshold. Everything undoable (if the studio has undo; else add a simple one).
Genome output stays valid (`creature_genome.gd`, C `stage_genome.c` validation); run the studio test suite (`make` target for
studio, 857 checks) and the creature tests. Evidence: short xvfb frame sequences (PNG) of each interaction.
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
