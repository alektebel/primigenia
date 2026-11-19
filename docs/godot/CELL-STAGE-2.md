# Cell stage 2: threats, colony, carry-over sheet

Branch `c2/cell-stage-2`. Design in `docs/CELL-STAGE.md` (phases 5 and 6, the legacy rules, the open questions); this is the
hand-back note.

## What is in
- Phase 5 Amenazas: ribosome, Cas, efflux pump, catalase and spines; phage, antibiotic, oxidation and amoeba on a visible
  schedule (wait, 10 s warning, hit, settle, verdict at membrane >= 60 %). Drawings and motion ported from malos-tiempos.html
  (phage, DNA, baby phages, antibiotic diamonds, radicals, amoeba, genome ring, fluid lipids).
- Phase 6 Colonia: hex board, energy / motile / defensive blocks (photosynthetic locked), ATP shared between neighbours,
  swimming to the light, one amoeba wave, end card "La colonia se convierte en criatura".
- Carry-over sheet: `godot/cell/cell_legacy.gd`, `user://cell_legacy.json` (version 1), `Game.cell_legacy()`, the Criatura card
  line "Herencia de tu célula: ...". The creature stage does not consume it.

## Checks (exact)
| Suite | Result |
|---|---|
| `make godot-cell-test`: cell_test.gd | 34 checks, 0 failed |
| threats_test.gd | 58 checks, 0 failed |
| colony_test.gd | 70 checks, 0 failed |
| cell_ui_test.gd | 38 checks, 0 failed |
| `make godot-menu-test` | 28 checks, 0 failures; `--play` run 1 check, 0 failures |
| godot-test (run_m0_tests.gd) | 890 checks, 0 failures |
| `make godot-ui-test` | 804 checks, 0 failures |
| godot-play-test (play_test.gd) | 217 checks, 0 failures |

`make godot` was not run (it would rebuild into the shared `libcpore` .so); `godot/bin` links to the main checkout's library and
the three Godot suites were run with the same commands the Makefile uses.

## Evidence
`docs/evidence/godot/cell2/` (xvfb, software GL, 1280x720; `size_1024x600_*` are the same scenes small): `threat1_phage_*`,
`threat2_antibiotic_*`, `threat3_oxidation_*` (with and without catalase), `threat4_amoeba_*` (bites, spines), `phase5_panel`,
`colony1..7` (founder, slots, swimming, warning with the dotted front line, bites absorbed, end card, undefended),
`ref_chromium_malos-tiempos.png` (the four scenes of the prototype rendered in Chromium with SwiftShader, scene times 9.5 / 9 /
7 / 8.5 s) to compare against.

## Choices to review
- Amoeba: three spines make it let go; tier 3 or more only stops the swallowing (it still bites for 6 s). Reaching phase 5 needs
  tier 5, so size alone always "counters" it.
- The first threat's clock only runs on the phase 5 screen.
- Diet rule uses waste-handling share (see CELL-STAGE.md question 8).
- Phase-5 "Montar ejemplo" builds the three-line factory of the aggregation test, so a demo cell can face the threats.
