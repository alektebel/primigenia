# The cell stage

A small Factorio-like throughput puzzle: a protocell you equip piece by piece until it is a factory that can join a colony.
The design of record is the owner's HTML prototype, `art/reference/cell/fase-celula-escala.html`. The next design, still
not ported, is `art/reference/cell/malos-tiempos.html` (threat scenes). `art/reference/cell/primigenia-3d-01-cell.jpg` is the
later 3D art target.

## Run

- `make godot-cell` plays it (`godot --path godot -- --cell`; the `--cell` user arg skips the terrain load).
- `Game.goto_cell()` (godot/game/game.gd) changes to `res://cell/cell_stage.tscn`; the menu branch can call it.
- `make godot-cell-test` runs the headless sim tests (`cell/tests/cell_test.gd`) and the UI smoke test (`cell_ui_test.gd`).
- `make godot-cell-evidence` writes screenshots to `docs/evidence/godot/cell/` (xvfb, software GL). Extra argument
  `WxH` after the out dir renders one frame at that size (`size_1024x600.png`, `size_1920x1080.png`).
- `--cell-seed=N` after `--` fixes the sim seed (otherwise it is time based).

Keys: 1-4 phase, Space pause, F speed x1/x3, L labels, Esc closes a tool or opens the pause list (Resume, Restart,
Main menu). Mouse: tap a tool, then the cell (enzymes inside, transporters/exporters/flippases on the membrane); drag a piece
to move it; right click or "Quitar" removes; hovering a piece shows what it does.

## The game (what the prototype specifies)

Four phases. 1 Energía: glycolysis loop, invest 2 ATP and get back 4, make 40 ATP. 2 Residuos: lactate dehydrogenase and
an exporter, export 12 lactates. 3 Membrana: lipid synthase and flippases, keep the membrane at 95 % or more for 60 s while
free radicals oxidise it. 4 Crecer: lipids left over after repairs grow the cell through five sizes; at the last size a
factory that sustains 150 ATP/min for 20 s triggers "Agregación", a card with the cell's stats sheet (the thing carried to
the colony stage) and "Seguir con esta célula" / "Empezar de nuevo". Each enzyme shows a status dot (trabaja, recibe, sin
entrada, atasco, inhibida, falta ATP) and its use %, the Líneas panel lists the use and a bottleneck diagnosis, hexokinase is
inhibited by its product and lipid synthesis brakes when energy is low.

## Layout of the code (godot/cell)

- `cell_sim.gd`: the whole prototype logic as a RefCounted, no nodes. `Sim.new(seed, phase)`, `step(dt)` with a fixed dt
  (the view uses 1/60), `reset(phase)`, `set_phase(n)`, `place(kind, pos)` ("" or an error code: unknown, phase, where,
  colony), `remove_at(pos)`, `move_piece`, `demo()`, `stats()`, `lines()`, `goal()`, `hint()`, `diagnose()`,
  `aggregation()`, `continue_colony()`. `PIECES` mirrors the prototype table (cost in ATP, phase unlocked, colour, name and
  role [es, en]). Hints, goals and diagnoses are ids; the view turns them into text. Seeded `RandomNumberGenerator`: the
  same seed gives the same run.
- `cell_canvas.gd`: `_draw()` of the cell (water, drifting specks, bilayer with lipid heads and tails, cream cytoplasm,
  blobby enzymes, molecules as dots, floating texts, bursts, colony neighbours) and the mouse.
- `cell_stage.gd` / `cell_stage.tscn`: the screen, the cream control column, tabs, aggregation card, pause list.
- `cell_strings.gd`: Spanish (default) and English strings, language from `Game.settings.language` through `ui/strings.gd`.

UI motion follows the polish rules: buttons press to 0.97 in 120 ms (ease out), the hint cross-fades in 150 ms, the goal
bar tweens 200 ms, the aggregation card enters 0.96 to 1 with a fade in 300 ms, nothing animates on a key press, no ease-in.

## Ported faithfully

Every number and rule of the prototype script: piece costs, ATP-paid construction (ATP molecules travel to the piece),
passive glucose transport and leak back out without hexokinase, hexokinase `need 2`, the inhibition thresholds
(`6 x size` free glucose-6-phosphate for hexokinase, jam thresholds for the others), ATP upkeep and rescue trickle, ROS,
membrane integrity spread, leaks, growth tiers `20 + 6 x tier`, the aggregation timer, zoom. Differences: the cell body is
drawn with stacked circles instead of canvas gradients and shadows, the crowd texture is a list of ellipses, tooltips
are new, and placement is blocked while the colony animation runs.

## Tests

`cell_test.gd` (34 checks): demo at phases 1 to 3 reaches its goal inside a time budget, costs are paid (ATP molecules
arrive), hexokinase is inhibited at 6 free glucose-6-phosphate, removal, phase locks and placement areas, same seed same
stats, aggregation after tier 5 sustained on a large factory. `cell_ui_test.gd` (15 checks): keys, tool then click,
right-click removal, pause list. Note the headless window is 64 px, so clicks are delivered to the canvas directly.

## Open questions for the owner

1. The demo only builds one line, so phase 4 growth and the aggregation need the player (or the evidence script) to add
   lines. Should "Montar ejemplo" build a bigger factory in phase 4?
2. Language: Spanish by default when the OS locale is Spanish, else English. Should the cell stage always default to Spanish?
3. The prototype lets you place pieces during the colony animation; this port blocks it. Keep?
4. Are Alegreya Sans and the cream panels the final look, or should the stage take the diegetic UI language of the island?
5. Threat scenes (`malos-tiempos.html`, slice S4) are not ported. That file is a looping narrated animation (phage injects
   into a ribosome and CRISPR/Cas cuts it, antibiotic blocks ribosomes and an efflux pump clears them, an oxidative wave
   breaks the membrane, an amoeba bites a patch and a capsule or flagellum answers) with ribosomes, a genome ring and an
   efflux pump that the playable stage does not have yet. Making them events against the player's cell needs those pieces
   and their costs decided first. Which should come first, and are ribosomes a placeable piece?
