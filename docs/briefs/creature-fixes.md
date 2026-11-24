# Brief: creature-mode fixes the owner hit while playing
Worktree `/home/diego/Desarrollo/cpore-wt/creature-fixes`, branch `ui/creature-fixes`. Owner's words in quotes.
1. "Left click should never change camera in creature mode." Find every path where LMB moves/turns/zooms/recentres the camera
   (island camera, selection, radial, card) and remove it; LMB selects/acts only. Camera stays on RMB/keys/wheel. Test it.
2. "I want to see the health of the enemies." A readable health bar/ring over every creature that is hostile, in a fight, or
   selected/targeted (in the diegetic UI language of `docs/godot/UI-DIEGETIC.md`; fade by distance; no clutter for far herds).
   Damage ticks down smoothly (ease-out 200 ms) with a brief lighter "lost" segment.
3. "Clouds are squares? Why not make them normal?" Find the cloud renderer and make soft, round, natural clouds (noise-shaped
   billboards or a sky shader layer), no visible quad edges at any angle, cheap on the low tier.
4. "For now, I want to edit a creature wherever I want." Add setting `edit_anywhere` (default true for now, toggle in the pause
   settings) that bypasses the 12 m nest gate for editing (C `cp_stage_at_nest` check or the Godot gate: keep the C rule intact
   and add an explicit flag through the binding; goldens unchanged). Editing still costs DNA as now.
5. "I want to actually play with the creatures I create. Don't create the environment from scratch every time."
   a) In the creator (studio) add a clear "Jugar con esta criatura" action that saves and drops you into the island with it.
   b) Measure what is rebuilt each time you enter the island (from menu, from the studio, after load): terrain cache, meshes,
      grass, flora, props, water, nav_warm, creatures. Make re-entry fast: keep built island resources in memory between scene
      changes (e.g. an autoload holding the built island node/meshes, or cached meshes/MultiMesh buffers on disk keyed like the
      terrain cache). Report before/after times for cold start and for studio→island re-entry.
6. (Optional, if 1–5 are green) "Perhaps I can observe plants in creature mode in order to categorize them and know them."
   Observe works on flora (`godot/game/data/flora.json`, visual-only plants): looking at a plant for a few seconds records it
   in the journal's species/plants section (name, habitat, a lore line), with a whisper "Nueva planta: …". Plant knowledge
   saved with the game. Visual-only (no C change) is fine.
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
