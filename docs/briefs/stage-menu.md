# Brief: main menu redesign — pick the stage to play (Célula or Criatura)

Worktree `/home/diego/Desarrollo/cpore-wt/stage-menu`, branch `ui/stage-menu`. Work and commit only here (small commits,
end each message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). Never touch `.codex/`, `.kimi-code/`,
other worktrees or the main checkout. Do not merge; Claude reviews and merges.

## Why
The owner wants to play now and test either stage: the new **cell stage** (another agent is porting it on branch
`c2/cell-stage`, entry `Game.goto_cell()` → `res://cell/cell_stage.tscn`) or the **creature stage** (the island,
`Game.goto_island()`). Today `godot/game/menu/main_menu.gd` is a plain panel (Play, Creator, Quit) over a gradient, and
`godot/game/main.gd` generates/loads the island terrain *before* showing the menu.

## What
1. **Stage picker.** Redesign `godot/game/menu/main_menu.gd` (+ .tscn): title "Primigenia", the tagline, and a row of
   stage cards using the owner's arc art already copied to `godot/game/menu/art/primigenia-3d-0{1..6}-*.jpg`
   (cell, creature, band, realm, industry, space). Célula and Criatura are playable; Banda, Reino, Industria, Espacio show
   as dimmed "próximamente" cards (smaller, not focusable, or a single collapsed strip — your call, keep it calm).
   Each playable card: image, name, one line ("Construye el metabolismo de tu célula." / "Evoluciona en la isla."), and
   for Criatura the current creature name (`Game.player_genome().name`) plus secondary actions Creador (studio) and
   Continuar if a save exists (check how saves are found in the code). Footer: Ajustes if a settings path exists, Salir.
   Spanish by default with English via the strings layer (`godot/ui/strings.gd`), follow `Game.settings` language.
   If `res://cell/cell_stage.tscn` does not exist (this branch alone), the Célula card stays visible but says
   "en construcción" and is disabled — so this branch is mergeable before or after the cell stage.
2. **Menu first.** The menu should appear immediately at boot; the island terrain loads only when Criatura is chosen
   (cache hit → straight in; miss → the existing loading screen). Keep `--play`, `--agent`, `--scenario` behaviour
   exactly as today (they skip the menu). Add `--menu` nothing else. Check `godot/game/tests/*` and devtools tests that
   rely on the boot order and keep them green.
3. **In-game way back.** The pause menu (`godot/ui/menu.gd`) already has main_menu; make sure it returns to this menu
   cleanly. Add a "Cambiar de fase" entry only if trivial.
4. **Feel** (Emil Kowalski's design-engineering skills are installed: read `~/.claude/skills/emil-design-eng/SKILL.md`
   and `~/.claude/skills/apple-design/SKILL.md` and apply them, translated to Godot Tweens):
   - Card hover: lift 4 px + image brightens slightly, 150 ms ease-out (`TRANS_QUINT, EASE_OUT`); press: scale 0.97, 120 ms;
     release springs back. Pivot at the card centre.
   - Entrance (first time the menu opens): title fades in, cards rise 12 px + fade with a 40 ms stagger, total < 500 ms.
     No entrance when returning from a stage? (keep it, but ≤ 300 ms). Nothing appears from scale 0; never ease-in.
   - Keyboard/gamepad: Left/Right moves focus between playable cards, Enter plays, focus ring visible (copper, like
     `godot/ui/menu.gd`), focus changes from keyboard are instant (no animation on keyboard-triggered actions).
   - Transition into a stage: a quick 200 ms fade to the background colour, then change scene.
   - Respect a reduced-motion setting if `Game.settings` has one (else add `reduced_motion` default false): no movement, only fades.
   Use the existing palette and fonts (`godot/ui/palette.gd`, `godot/ui/style.gd`, `godot/ui/fonts`), dark sky backdrop,
   no hard borders: soft shadows / semi-transparent edges. Must look right at 1024×600, 1280×720 and 1920×1080.

## Tests and evidence
- A headless test (add to the existing UI or play test target, or `make godot-menu-test`): menu builds, both playable
  cards exist, Criatura calls goto_island, Célula disabled when the cell scene is missing, keyboard focus moves, `--play`
  still skips the menu.
- Screenshots with xvfb (software rendering, as other evidence targets do) into `docs/evidence/godot/stage-menu/`:
  rest state, Criatura hovered, Célula focused, at the three sizes. Look at them yourself and fix anything ugly
  (clipped text, low contrast, crowded cards).
- Run `make godot-test`, `make godot-ui-test`, `make godot-play-test` (or the Makefile equivalents) and report.
- Godot rules: always `timeout`, `--check-only` first, headless or xvfb, `nice -n 10`, kill only your own pids, never `pkill -f`.
- Short report `docs/godot/STAGE-MENU.md`.
