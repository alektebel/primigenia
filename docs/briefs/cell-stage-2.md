# Brief: cell stage, phases 5 Threats and 6 Colony, and the carry-over sheet (DESIGN.md A26)
Worktree `/home/diego/Desarrollo/cpore-wt/cell-stage-2`, branch `c2/cell-stage-2`. Read `docs/CELL-STAGE.md`, `godot/cell/*`,
DESIGN.md A26, the owner's prototypes `art/reference/cell/fase-celula-escala.html` and `art/reference/cell/malos-tiempos.html`
(read its script: the four threat scenes, CRISPR/Cas, efflux pump, ribosomes, genome ring, fluid lipids).
Keep it "like Factorio, without getting out of hand": few pieces, readable bottlenecks.
1. **Phase 5 Amenazas**: unlocked after phase 4. Threat events arrive on a readable schedule with a warning (an incoming phage
   drifting in, an antibiotic tide colouring the water, an oxidation flash, an amoeba approaching) and hit the factory you built:
   phage injects and hijacks ribosomes (counter: Cas/CRISPR piece, learns after the first infection); antibiotic blocks a piece
   type (counter: efflux pump on the membrane, costs ATP per pumped molecule); oxidation damages membrane and enzymes
   (counter: catalase + more flippases); amoeba tries to engulf (counter: size tier ≥ 3 or spines on the membrane). New pieces:
   ribosomes (show as the prototype draws them; they build the counter proteins and cost ATP), Cas, efflux pump, catalase,
   spines. Goal: survive one wave of each with membrane ≥ 60%. Port the prototype's drawings and motion for each threat.
2. **Phase 6 Colonia**: after aggregation, a small board where you place specialised cells as blocks around the founder:
   energy cell, motile cell (flagellum), defensive cell (spines/thick membrane), and later photosynthetic (locked, "próximamente").
   Each block reuses the founder's stats sheet; neighbours share ATP. Goal: a colony of 7 that moves toward light/food and
   survives one threat wave. End card: "La colonia se convierte en criatura".
3. **Carry-over sheet**: the aggregation/colony end card shows what passes to the creature: metabolism → starting diet
   (fermentation-heavy = carroñero, efficient glycolysis = cazador, photosynthesis later = herbívoro), defence → one starting part
   (spines → espinas, thick membrane/flippases → placas), size → starter size class. Save it as `user://cell_legacy.json`
   (versioned) and expose `Game.cell_legacy()`; the creature stage does not consume it yet (next slice), but the main menu's
   Criatura card shows "Herencia de tu célula: …" when it exists.
Tests in `godot/cell/tests/` (each threat and its counter, wave survival, colony goal, legacy file round-trip, determinism by
seed); `make godot-cell-test` green; xvfb evidence of each threat, the colony board and the end card under
`docs/evidence/godot/cell2/`, compared against Chromium renders of malos-tiempos.html. Update `docs/CELL-STAGE.md`.
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
