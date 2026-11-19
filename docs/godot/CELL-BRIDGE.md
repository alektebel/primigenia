# Cell -> creature bridge (A26, A32)

Branch `c2/cell-bridge`. The colony end card hands the cell's legacy to a NEW creature game.

## Flow
1. Colony end card ("La colonia se convierte en criatura"): primary button **Continuar como criatura** (Volver al menu and Seguir mirando stay).
   Press: `Game.creature_legacy = the card's legacy`, a 500 ms ease-out fade through the water colour (`0F2229`, the cell scene's), then
   `Game.enter_island_new()`: the same entry as the menu (island in memory, terrain cache, or the loading screen drawn under the veil).
2. `island.gd` `_build_stage` consumes `Game.creature_legacy` once, only for a game that is not a loaded scenario (Continue ignores it):
   - **size**: `CellLegacy.apply_genome` scales the hatchling genome 0.9 / 1.0 / 1.1 (small / medium / large), clamped to the creature module's floors
     (node r 0.03, leg w 0.05, part size 0.1), so the camera floor (1.6 m / `h + 0.45`) and the 0.05 m near plane hold; the C radius stays 45-55 cm.
   - **part**: espinas -> `pua`, placas -> `placa`, added to the body (equipped) and owned in C.
   - **diet** (C): `CporeWorld.apply_legacy(diet, part)` right after the reset: cazador -> carnivore, herbivoro -> herbivore, carronero -> omnivore
     (the C sim has three diets and the scavenger eats carcasses and anything else; the default stays omnivore).
3. A whisper at the first frames: "Tu linaje empezo como una celula cazadora con espinas" (EN: "Your lineage began as a hunter cell with spines").
4. The journal's family tree (T) starts with a drawn **ORIGEN** column: the cell, its diet/defence line and the size it passed on.
5. Scenario saves carry `legacy`, so Continue keeps the family root (the body scale and part are in the saved genome, diet and ownership in the C snapshot).

## C change (the only one)
`cp_stage_legacy_apply(w, diet, part)` in `core/src/stage_parts.c`, bound as `CporeWorld.apply_legacy(diet, part_id)`. It sets `social.diet` and
marks one part owned, discovered, starter, level 1, and raises the `used` flags only when something is applied: a world that never calls it
hashes exactly as before (goldens unchanged; `tests/test_parts_nest.c` checks the no-op and the apply). Nothing else in `core/` changed.
It is applied after the reset and is not in the setup, so a `CPORE_WORLD_LOG` replay of a legacy game needs the legacy applied by hand.

## Menu
The Criatura card: "Nueva partida" (the card) uses the saved legacy when there is one ("Herencia de tu celula: ..."); a small **Sin herencia**
action next to Creador/Continuar starts a plain hatchling. Without a legacy file the option is not shown.

## Dev
`cell finish [carronero|cazador|herbivoro] [espinas|placas|ninguna] [small|medium|large]` (console, defaults cazador espinas medium): opens the cell
stage straight on its end card with that legacy (it is saved), ready for Continuar como criatura.

## Motion (Emil Kowalski)
Button: press scale 0.97 / 120 ms ease-out (the cell's existing `_pressable`), colour change on hover only; the stage fade is 500 ms QUINT ease-out
(the one motion over 250 ms), the veil lifts in 250 ms ease-out, nothing starts from scale 0, keyboard focus is instant. Reduced motion: the veil is a fade, so it stays.

## Tests
`make godot-bridge-test` (`game/tests/test_bridge.gd`): the cell demo colony to its end -> button -> fade -> island with diet, owned and equipped
part, scale, whisper, family-tree root, scenario context; then a plain start and the menu option. Added checks in cell_ui_test (button) and
test_menu (Sin herencia, begin_creature).
Evidence: `docs/evidence/godot/cell-bridge/` (`make` target not added; run `game/tests/bridge_evidence.gd` as its header says).
