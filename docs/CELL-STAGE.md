# The cell stage

A small Factorio-like throughput puzzle: a protocell you equip piece by piece until it is a factory that can join a colony.
The design of record is the owner's HTML prototype, `art/reference/cell/fase-celula-escala.html`. Phase 5 ports its
second prototype, `art/reference/cell/malos-tiempos.html` (threat scenes), as events against the player's factory; phase 6
(the colony) and the carry-over sheet are the approved additions of DESIGN.md A26. `art/reference/cell/primigenia-3d-01-cell.jpg`
is the later 3D art target.

## Run

- `make godot-cell` plays it (`godot --path godot -- --cell`; the `--cell` user arg skips the terrain load).
- `Game.goto_cell()` (godot/game/game.gd) changes to `res://cell/cell_stage.tscn`; the menu branch can call it.
- `make godot-cell-test` runs the headless sim tests (`cell_test.gd`), the threat tests (`threats_test.gd`), the colony and legacy tests (`colony_test.gd`) and the UI smoke test (`cell_ui_test.gd`).
- `make godot-cell2-evidence` writes the phase 5 and 6 screenshots to `docs/evidence/godot/cell2/`.
- `make godot-cell-evidence` writes screenshots to `docs/evidence/godot/cell/` (xvfb, software GL). Extra argument
  `WxH` after the out dir renders one frame at that size (`size_1024x600.png`, `size_1920x1080.png`).
- `--cell-seed=N` after `--` fixes the sim seed (otherwise it is time based).

Keys: 1-6 phase (5 opens after the aggregation, 6 after the four threats), Space pause, F speed x1/x3, L labels, Esc closes a tool or opens the pause list (Resume, Restart,
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

## Phase 5, Amenazas (godot/cell/cell_sim.gd)

Opens after the aggregation ("Seguir con esta célula" lands here with the factory you built). Four threats come in a fixed,
published order (phage, antibiotic, oxidation, amoeba). Each one is `wait` (30 s before the first, 20 s between), `warn` (10 s,
with a sign you can see), `hit`, `settle` (8 s), then a verdict: it is survived when the membrane never fell under 60 % since the
warning; a failed one comes back after the next wait (the diagnosis line says so). The goal is the four survived. The side card
lists each threat with its counter piece (ready / missing) and its state; the top banner counts down.

| Threat | Warning | What it does | Counter |
|---|---|---|---|
| Fago | a phage drifts to your transporter, the door pulses | injects DNA that hijacks a ribosome (drains ATP, makes baby phages); uncut after 14 s the ribosome is lost and the membrane lyses (arc of 52 lipids) | Cas: cuts the DNA in the hijacked ribosome after 4 s and learns it; the second phage is cut 36 px after injection, before it arrives |
| Antibiótico | the water turns purple from the right | 8 molecules block every piece of one type (ribosomes if you have them) and prick the membrane (one hole per molecule every 1.4 s) for up to 26 s | efflux pump on the membrane: one molecule per 0.6 s, 1 free ATP each; no ATP, no pumping |
| Oxidación | a red arc glows on the side the radicals come from | 80 strong radicals in 8 s break 7 lipids each and oxidise enzymes (8 s) | catalase: neutralises one radical per 0.2 s, so three clear the wave; flippases repair the rest |
| Ameba | an amber arc and the amoeba approaching | bites an arc of the membrane every 0.5 s and swallows the cell after 9 s of holding on (arc of 3 rad) | 3 spines on the membrane: it lets go after 1.5 s without a bite. Size tier 3 or more: it cannot swallow, it bites 6 s and leaves (survivable, not clean) |

New pieces (all costs in ATP): ribosome 4 (the prototype's pink two-lobe body; it builds the counter proteins: a Cas, pump,
catalase or spines cannot be started without a built, free ribosome, and while it works it eats 1 ATP every 5 s), Cas 4, efflux
pump 4, catalase 3, spines 2. Hijacked ribosomes turn green, blocked ones grey with purple diamonds. `Sim.threat_info()` is the
read side (kind, stage, eta, results, counter); `start_threats(first, idx)` restarts the schedule (tests and evidence).
"Montar ejemplo" in phase 5 builds the phase-4 factory of the aggregation test plus two ribosomes.

## Phase 6, Colonia (godot/cell/colony_sim.gd, colony_canvas.gd)

A hex board (radius 2, 19 slots) around the founder, which is your cell: `Sim.legacy_sheet()` (ATP/min, membrane, size, piece
counts) is read once when the phase opens and every block reuses it: the sheet's ATP/min over 150 sets the income of every
cell, its membrane % the hit points. Blocks: energy cell (5 ATP, makes 2.2 ATP/s x rate), motile cell (5 ATP, burns 0.9 ATP/s
to swim), defensive cell (6 ATP, x1.6 hit points, upkeep), photosynthetic (locked, "próximamente"). A block costs ATP taken from a
neighbour and the neighbours share ATP (levels equalise, drawn as pink bridges with moving beads), so ATP is the bottleneck you
read from the bars under each cell. Speed = 40 x fed motile cells / colony size; the light is 380 units away. At the light with
7 cells an amoeba wave comes from a marked side (10 s warning: an arc and dotted rings on the front-line cells), bites the front
line four times (55 damage, 100 hit points) and leaves after two bites absorbed by defensive cells. Survived with the founder
and 7 cells: the end card "La colonia se convierte en criatura". A failed wave comes back.

## The carry-over sheet (godot/cell/cell_legacy.gd)

The end card shows what passes to the creature and writes `user://cell_legacy.json` (version 1; a provisional copy with
`source: "aggregation"` is written when you continue from the aggregation card, never over a colony one). `Game.cell_legacy()`
returns it (`{}` if missing, unreadable, another version or unknown values); the main menu's Criatura card shows
"Herencia de tu célula: cazador · espinas · mediano". The creature stage does not consume it yet.
- Diet: herbívoro if the colony has a photosynthetic cell (locked, so not yet); carroñero when waste handling (lactate DH + exporters)
  is at least 25 % of your pieces (a fermentation-heavy metabolism); otherwise cazador (lean glycolysis).
- Defence part: espinas = spines on the membrane + defensive colony cells; placas = flippases / 4 + 1 for a membrane of 95 % or more;
  espinas if they are at least as many as the plates, else placas, else none.
- Size class: growth tier 0-1 small, 2-3 medium, 4-5 large.

## Layout of the code (godot/cell)

- `cell_sim.gd`: the whole prototype logic as a RefCounted, no nodes. `Sim.new(seed, phase)`, `step(dt)` with a fixed dt
  (the view uses 1/60), `reset(phase)`, `set_phase(n)`, `place(kind, pos)` ("" or an error code: unknown, phase, where,
  colony), `remove_at(pos)`, `move_piece`, `demo()`, `stats()`, `lines()`, `goal()`, `hint()`, `diagnose()`,
  `aggregation()`, `continue_colony()`. `PIECES` mirrors the prototype table (cost in ATP, phase unlocked, colour, name and
  role [es, en]). Hints, goals and diagnoses are ids; the view turns them into text. Seeded `RandomNumberGenerator`: the
  same seed gives the same run.
- `cell_canvas.gd`: `_draw()` of the cell (water, drifting specks, bilayer with lipid heads and tails, cream cytoplasm,
  blobby enzymes, molecules as dots, floating texts, bursts, colony neighbours) and the mouse.
- `cell_stage.gd` / `cell_stage.tscn`: the screen, the cream control column, tabs, aggregation card, threats card, colony tools, carry-over card, pause list.
- `colony_sim.gd`, `colony_canvas.gd`, `cell_legacy.gd`: phase 6 and the legacy file (above).
- `cell_strings.gd`: Spanish (default) and English strings, language from `Game.settings.language` through `ui/strings.gd`.

UI motion follows the polish rules: buttons press to 0.97 in 120 ms (ease out), the hint cross-fades in 150 ms, the goal
bar tweens 200 ms, the aggregation card enters 0.96 to 1 with a fade in 300 ms, nothing animates on a key press, no ease-in.

## Ported faithfully

Every number and rule of the prototype script: piece costs, ATP-paid construction (ATP molecules travel to the piece),
passive glucose transport and leak back out without hexokinase, hexokinase `need 2`, the inhibition thresholds
(`6 x size` free glucose-6-phosphate for hexokinase, jam thresholds for the others), ATP upkeep and rescue trickle, ROS,
membrane integrity spread, leaks, growth tiers `20 + 6 x tier`, the aggregation timer, zoom. Differences: the lipids now slide sideways like the threats prototype's (0.035 rad/s, damage travels with the lipid), the cell body is
drawn with stacked circles instead of canvas gradients and shadows, the crowd texture is a list of ellipses, tooltips
are new, and placement is blocked while the colony animation runs.

## Tests

`cell_test.gd` (34 checks): demo at phases 1 to 3 reaches its goal inside a time budget, costs are paid (ATP molecules
arrive), hexokinase is inhibited at 6 free glucose-6-phosphate, removal, phase locks and placement areas, same seed same
stats, aggregation after tier 5 sustained on a large factory. `threats_test.gd` (58 checks): placement gates (a ribosome
first), counters not built while ribosomes are hijacked, each threat with and without its counter (membrane minimum, lost
ribosomes, Cas learning, pump clearing and needing ATP, catalase worth over 20 points, spines and size), a failed threat
coming back, one whole wave in order, warnings before every hit, determinism by seed. `colony_test.gd` (70 checks): board
rules, ATP cost and sharing, income from the founder's sheet, motion, the amoeba wave with and without defence, the
carry-over rules, legacy file round trip and rejection of bad files, the sheet taken from a cell. `cell_ui_test.gd`
(38 checks): keys, tool then click, right-click removal, pause list, phase 5 and 6 locks, threat card, colony tools and
clicks, the end card. `make godot-menu-test` checks the legacy line on the Criatura card. The headless window is 64 px, so
clicks are delivered to the canvas directly.

## Open questions for the owner

1. The demo only builds one line, so phase 4 growth and the aggregation need the player (or the evidence script) to add
   lines. Should "Montar ejemplo" build a bigger factory in phase 4?
2. Language: Spanish by default when the OS locale is Spanish, else English. Should the cell stage always default to Spanish?
3. The prototype lets you place pieces during the colony animation; this port blocks it. Keep?
4. Are Alegreya Sans and the cream panels the final look, or should the stage take the diegetic UI language of the island?
5. (answered by the A26 slice) Threats are in as phase 5 and ribosomes are a placeable piece (4 ATP) that gates the counter
   proteins.
6. A player reaches phase 5 at size 5, so "size 3 or more" always counters the amoeba (survivable but with bites; spines make it
   clean). Keep both counters, or should the amoeba scale with the cell?
7. The phase 5 clock (30 s before the first warning) starts when you press 5, and only runs while phase 5 is the visible
   phase (the cell sim steps only then). Should the player be able to call the first threat early or hold it back?
8. The diet thresholds (waste handling >= 25 % of pieces = carroñero) are my reading of "fermentation-heavy"; with the
   prototype's single glycolysis line every factory has similar ATP per glucose, so efficiency alone cannot tell them apart.
