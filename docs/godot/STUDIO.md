# Godot studio (M2, G42-G45, G48, G76)

Folder: `godot/studio/` (standalone project for tests; integration moves it under the M0 project and
keeps relative `preload` paths, so no `res://` path is hard-coded except in the test scripts and `ui/studio.tscn`).

## Files
- `genome.gd` port of `web/studio/genome.js` (validate, migrate /1 /2 /3, parse). Returns `{ok, error, genome, warnings}`.
- `parts_db.gd` + `data/parts.json` (identical copy of `web/studio/parts.json`, a test enforces it); part defaults and slider ranges from `web/creature/rig.js`.
- `model.gd` document model, selection, mode, and every edit action. History is transactions: `begin()`/`end()`; a drag or slider gesture is one undo step; `cancel()` aborts (Escape).
- `storage.gd` saves `cpore.creature/4` JSON to `user://studio/`, import/export of any path.
- `i18n.gd` es/en (Spanish source strings as in `web/studio/i18n.js`, part names from parts.json).
- `creature_view.gd` the interface; `placeholder/placeholder_view.gd` the stand-in (capsule spine, part markers).
- `ui/studio.gd` the shell (script-built UI, `ui/theme_factory.gd` for the look), `thumbnails.gd` procedural thumbnail slots.
- `tests/test_studio.gd`, `tests/node_check.js`, `tests/evidence.gd`.

## Interface the creature builder must satisfy (`creature_view.gd`)
A `Node3D`, view-local space +Y up, +Z along the spine, spine nodes in x=0.
- `set_genome(doc: Dictionary)`, `get_genome() -> Dictionary` (cpore.creature/4).
- `attach_part(type, t, ang, params) -> int`, `remove_part(i)`, `update_part(i, fields)`.
- `spine_node_positions() -> PackedVector3Array`.
- `hit_body(origin, dir) -> {t, ang, point}` or `{}`; `ang` signed, 0 = up, +X positive. `hit_part(origin, dir) -> int`, `hit_node(origin, dir) -> int`.
- `part_anchor(i) -> {pos, normal, up}` for the handles.
- `set_selection(i)`, `set_spine_visible(bool)`, `set_playing(bool)` (Test mode play/stop hook).
Parts with ang off the midline (|sin ang| >= .14, and all legs) render mirrored, as in the web studio.
The studio calls `set_genome(model.doc)` after every change; pass a view to `Studio.new(db, view)` to replace the placeholder.
Thumbnails: `studio.set_thumbnail(part_id, texture)`.

## Run
- `make godot-studio-test` (headless GDScript tests, then `node godot/studio/tests/node_check.js` which loads what Godot wrote with `web/studio/genome.js`).
- Evidence: `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --path godot/studio --rendering-driver opengl3 --script res://tests/evidence.gd -- docs/evidence/godot/studio`.

## Controls
Mouse: drag palette item onto the body (or click it, then click the body); click a part to select; drag it to move, outside the body to delete; green handle rotates, blue handle tilts; drag a vertebra (amber ball) to sculpt, wheel on it to thicken, wheel on the selected part to resize; drag empty space or right/middle button to orbit; wheel to zoom.
Keys: Ctrl+Z, Ctrl+Y / Ctrl+Shift+Z, Delete/Backspace, arrows (move selected part), Escape, Ctrl+S save, Ctrl+O import.

## Realism pilot controls (creature/realism-pilot)
Paint panel, "Biologia": countershading slider, pattern size and contrast sliders (when a pattern is on), rosettes toggle (spots).
Build panel, under Capacidades: "Actuacion: <class> - <reason>" and, when the parts allow several classes, a selector (Automatica
or one class). Stored as optional `skin` keys `cs`, `ps`, `pc`, `ros`, `act` (`creature_genome.gd` and `studio/genome.gd` accept
them; the web genome.js does not). The player's colours are never altered. See `CREATURE-REALISM.md`.
