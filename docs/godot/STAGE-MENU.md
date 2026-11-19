# Stage menu

`godot/game/menu/main_menu.gd` is the stage picker. Evidence: `docs/evidence/godot/stage-menu/` (rest, Criatura hovered, Celula focused, Celula missing; 1024x600, 1280x720, 1920x1080). Tests: `make godot-menu-test`; screenshots: `make godot-menu-evidence`.

## Boot
- `main.gd` opens the menu at once. The island terrain is loaded only when Criatura (or Continuar) is chosen: cache hit goes straight in, a miss shows the existing loading screen (inside the menu scene). Terrain stays in `Game` when you come back from the island.
- `--play`, `--agent` and `--scenario` skip the menu and keep the old order (cache or loading screen, then the island). `--menu` forces the menu back on.
- Coming back from the pause menu ("Main menu") calls `Game.goto_menu()`, which loads this scene.

## Cards
- Celula: playable when `res://cell/cell_stage.tscn` exists (calls `Game.goto_cell()` if defined, else changes scene to it); otherwise visible, dimmed, disabled, "en construccion". Mergeable before or after the cell stage.
- Criatura: image, name, one line, `Game.player_genome().name`, Creador (studio) and Continuar (only if `user://saves/slot1.json` exists; loads it as the pending scenario).
- Banda, Reino, Industria, Espacio: one calm dimmed strip, not focusable.
- Spanish by default, English via `ui/strings.gd` (keys `stage_*`, `tagline`, `creator`, `continue`, `quit`...), follows `Game.settings.language`.
- No Ajustes: settings only exist inside the game's pause menu, so the footer is just Salir.

## Motion
Hover: 4 px lift + image brightens, 150 ms QUINT ease-out. Press: scale 0.97, 120 ms; release springs back (TRANS_BACK). Pivot at the card centre. Entrance: title, tagline and cards fade, cards rise 12 px, 40 ms stagger, about 450 ms first time and about 280 ms on return. Keyboard/gamepad focus (Left/Right between playable cards, Down/Up to the Criatura actions, Enter) is instant with a copper ring. Leaving: 200 ms fade to the background colour, then the scene change. `Game.settings.reduced_motion` removes the lift, press scale and rise (fades only).

## Tests
`test_menu.gd` (23 checks, plus a `-- --play` run asserting that the menu is skipped): cards, disabled Celula without the scene, Criatura wired to `play_creature`, keyboard focus, instant focus feedback, hover/press/release values, entrance, Spanish/English, reduced motion. `play_test.gd` was unchanged and still boots main -> menu -> Criatura.
