# Brief: a procedural run gait (and less clumsy locomotion)
Worktree `/home/diego/Desarrollo/cpore-wt/run-gait`, branch `loco-run-gait`. Code in `godot/locomotion/` and the creature rig.
Owner: "I want to have the option to run, and make a procedural animation for it as well." "The game lacks dynamism because
we can't run fast." "Procedural animation is still a little clumsy."
A separate Codex task adds running to the C sim (`CporeWorld.set_run(bool)`, `state().player.running`, `stamina`), not merged
yet. Your part is the **animation**, driven by speed so it also serves wild creatures (Garfio's charge, fleeing herds):
1. Gait transitions by speed and morphology: walk → trot → run/gallop (bound/gallop for quadrupeds, running with an aerial
   phase for bipeds, metachronal ripple faster for hexapods/octopods), using Froude number (v²/(g·leg length)) to pick the gait
   and stride length/frequency (Alexander's scaling). Smooth blending, no foot sliding: stride length × frequency = speed.
2. Run posture: body pitches forward, spine flexion/extension for gallop, head stabilised, tail as counterbalance, arms swing for bipeds.
3. Fix the clumsy parts you can see: foot skating, feet popping on slopes, body bob too mechanical, turning in place. Look at
   xvfb frame sequences of the Merodeador and 3 other morphologies at walk/trot/run and fix what looks wrong.
4. For testing before the Codex part lands: a debug key / devtools toggle that lets the player move at run speed visually
   (Godot side only, behind a dev flag), plus the zoo (`godot/devtools/zoo`) courses at run speed.
Tests: `make godot-loco-test`, creature tests; evidence: contact sheets per morphology and gait.
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
