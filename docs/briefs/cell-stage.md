# Brief: the cell stage in Godot (port of the owner's prototype)

Worktree `/home/diego/Desarrollo/cpore-wt/cell-stage`, branch `c2/cell-stage`. Work and commit only here (small commits,
end each message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). Never touch `.codex/`, `.kimi-code/`,
other worktrees or the main checkout. Do not merge; Claude reviews and merges.

## What
The owner designed the cell stage as a small Factorio-like throughput puzzle ("like Factorio, without it getting out of hand").
The design of record is the owner's HTML prototype, already copied into the worktree:
- `art/reference/cell/fase-celula-escala.html`: **the game**. 4 phases (1 Energía: glycolysis loop, invest 2 ATP get 4,
  produce 40 ATP; 2 Residuos: lactate dehydrogenase + exporter, export 12 lactates; 3 Membrana: lipid synthase + flippases,
  membrane ≥95% for 60 s; 4 Crecer: growth tiers 0/5, then "Agregación: empieza la colonia" card with the cell's stats
  sheet, "Seguir con esta célula" / "Empezar de nuevo"). Place pieces (tap a piece, then the cell; enzymes inside, transporters/
  exporters/flippases on the membrane), molecules (glucose, intermediates, ATP, lactate, lipids) travel as dots, each enzyme
  shows status (trabaja, recibe, sin entrada, atasco, inhibida, falta ATP) and usage %, a "Líneas" panel lists use and
  bottleneck hint, stats row (ATP libre, ATP/min, Glucosa/min, Membrana %, Talla), speed ×1/×3, labels toggle, Quitar,
  Montar ejemplo, Reiniciar, product inhibition of hexokinase and lipid-synthesis brake when energy is low.
  Read its whole `<script>` (≈34 KB, ~420 lines) and CSS: port the rules, numbers and hints **faithfully**.
- `art/reference/cell/malos-tiempos.html`: "Malos tiempos para la célula": 4 threat scenes (Fagos, Antibiótico, Oxidación,
  Ameba) with CRISPR/Cas, ribosomes, genome ring, fluid membrane lipids. This is the **next** design; for now implement it
  only as slice S4 below if time allows.
- `art/reference/cell/primigenia-3d-01-cell.jpg`: the owner's 3D mood frame of the cell stage (later art target, not now).

## Slices
S1 **Sim.** `godot/cell/cell_sim.gd` (RefCounted, no nodes): the full prototype logic, stepped with a fixed dt (e.g. 1/60)
from the view, with a seeded RandomNumberGenerator (seed param) so tests are reproducible. Keep it separate from drawing.
Public API: `reset(phase)`, `set_phase(n)`, `place(kind, pos) -> bool/error`, `remove_at(pos)`, `demo()`, `step(dt)`,
`stats()`, `lines()` (per-enzyme use/status), `goal()`, `hint()`, `aggregation()`. Pieces data as a const dict mirroring
`PIECES` (cost in ATP, phase unlocked, colour, name es/en).
S2 **View + UI.** `godot/cell/cell_stage.tscn` + `cell_stage.gd`: a full-screen scene matching the prototype's layout and
look (dark teal water background with drifting specks, the bilayer membrane drawn with lipid heads + tails, cream cytoplasm,
enzymes as blobby shapes, molecules as dots, floating "+2 ATP" texts, bursts) using `_draw()` on a Control/Node2D; the right
column panels (phase tabs 1–4, phase card with hint and goal progress bar, Crear tools grid with cost, actions, stats row,
Líneas panel, note). Cream panels `#FBF6EA`-ish with ink `#3A352D`, as in the CSS. Text in Spanish by default with an
English table (use `godot/ui/strings.gd` patterns; `Game.settings` language if present). Mouse: click a tool then the cell;
right-click or Quitar mode removes; hover shows a tooltip with the piece's role. Keys: 1–4 phase, Space pause, F speed,
L labels, Esc opens a small pause list (Resume, Restart, Main menu → `Game.goto_menu()`). Must scale to 1280×720 and
1920×1080 and stay readable at 1024×600.
UI polish rules (Emil Kowalski's skills, installed at `~/.claude/skills/emil-design-eng/SKILL.md`, read it): buttons press
to scale 0.97 in ~120 ms, ease-out (Tween TRANS_QUINT or TRANS_EXPO, EASE_OUT) for things entering, never ease-in, UI
motion ≤ 250 ms, no animation on keyboard-triggered actions, the phase card text cross-fades (150 ms), the goal bar tweens,
the aggregation card enters with scale 0.96→1 + fade (300 ms). Nothing appears from scale 0.
S3 **Entry point.** Add `Game.goto_cell()` in `godot/game/game.gd` (change scene to `res://cell/cell_stage.tscn`) and a
`--cell` user arg in `godot/game/main.gd` that boots straight into the cell stage (skip terrain load) for tests/evidence.
Another agent (branch `ui/stage-menu`) is redesigning the main menu and will call `Game.goto_cell()`; do not edit
`godot/game/menu/*`. Add a `make godot-cell` target that runs the cell stage (`godot --path godot -- --cell`).
S4 (optional, only if S1–S3 are done and green) **Threats**: a phase 5 "Amenazas" porting malos-tiempos scenes as events
that hit your built cell (phage injects, antibiotic blocks a piece type, oxidation damages membrane, amoeba engulfs), with
the counters in that prototype (CRISPR/Cas, more flippases, …). Keep it small; report what you did.

## Tests and evidence
- `godot/cell/tests/cell_test.gd` headless (follow how other `godot/*/tests` are run in the Makefile; add `make godot-cell-test`):
  demo() at each phase reaches its goal within a time budget; costs are paid; hexokinase inhibits at its threshold; removing
  a piece works; pieces of phase N are not placeable in phase N−1; aggregation triggers after tier 5 sustained; same seed → same stats.
- Screenshots with xvfb (`xvfb-run -a`, software rendering as the other evidence targets do) into `docs/evidence/godot/cell/`:
  each phase after demo() ran 20 s, the aggregation card, 1024×600 and 1920×1080. Look at them and compare against the
  prototype yourself (render the HTML with headless chromium:
  `~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome --headless --use-angle=swiftshader --enable-unsafe-swiftshader
  --screenshot=... --window-size=1280,800 file://...`). Fix what looks worse than the prototype.
- Run `make godot-test` and `make godot-ui-test` (or the equivalents in the Makefile) to show nothing else broke.
- Godot rules: always `timeout`, `--check-only` first, headless or xvfb, `nice -n 10`, kill only your own pids, never `pkill -f`.
- Write `docs/CELL-STAGE.md`: what the stage is (from the prototype), how to run it, what was ported, open questions for the owner.
