# Godot UI and audio (M3)

Standalone scenes/scripts in `godot/ui/` and `godot/audio/`, ported from `web/stage`
(HUD, `audio.js`). Palette C "Current+" colours from `web/stage/stage.css` live in
`godot/ui/palette.gd`. Desktop, mouse and keyboard. Nothing depends on the stage or the C world.

Tests: `make godot-ui-test` (132 checks, headless). Evidence: `docs/evidence/godot/ui/`
(`hud.png`, `radial_card.png`, `pause.png`), made by `godot/tests/evidence.gd` under xvfb with software GL.

## Wiring

```gdscript
const GameUI := preload("res://ui/game_ui.gd")
const AudioManager := preload("res://audio/audio_manager.gd")
var audio := AudioManager.new()        # reads/writes user://settings.cfg [audio]
var ui := GameUI.new()                 # CanvasLayer, layer 10
add_child(audio); add_child(ui)
ui.set_camera(camera)                  # for 3D-anchored damage numbers and the enemy marker
ui.bind_audio(audio)                   # pause-menu sliders + UI clicks + pause
audio.start_ambience()                 # after the first user input
```

## GameUI interface (`godot/ui/game_ui.gd`)

| Call | Meaning |
|---|---|
| `set_player(name, hp, hp_max, stamina, stamina_max)` | Vitals panel. |
| `select(info, open_menu=true, menu_pos=null)` | Show card, enemy marker; opens the radial menu. |
| `update_target(info)` | Merge live fields (hp, relationship, world_pos). |
| `clear_selection()` | Hide card, marker, tell. |
| `set_mode(mode)` | `&"attack"/&"befriend"/&"observe"/&"intimidate"`; puts that mode's abilities on keys 1-4. |
| `set_abilities(list)` | Override: array of `{id, name, stamina?, enabled?}`, max 4. |
| `show_damage(pos, amount, on_player=false)` | `pos` Vector3 world (needs `set_camera`) or Vector2 screen. |
| `show_message(text, kind="info")` | Toast; kind `info/good/bad`. |
| `show_dna(amount)` | DNA toast (`+N DNA`, placeholder number). |
| `set_windup(progress, label="")` | Enemy wind-up tell under the marker; negative hides it. |
| `flash(kind)` | Screen-edge flash: `hit`, `guard`, `dodge`. |
| `set_paused(on)` | Pause menu; also pauses audio. |
| `open_radial(pos)` / `bind_audio(a)` / `set_camera(c)` | As named. |

Signals: `mode_changed(mode)`, `ability_pressed(index, ability)`, `guard_pressed`,
`dodge_pressed(dir)` (-1 left, +1 right), `selection_changed(id)`, `pause_toggled(bool)`, `ui_click`.

Keys: 1-4 abilities, Space guard, Q/E dodge, Esc pause (or closes the radial), Tab reopens the
radial for the selected creature. In the radial: click a sector, or A / B / O / I.

`info` dictionary: `id`, `name`, `species`, `temperament` (0 timid, 1 territorial, 2 aggressive, or the
name), `diet` (0 herbivore, 1 carnivore, 2 omnivore, or name), `relationship` (0 stranger, 1 neutral,
2 trusted, 3 ally, or name), `resolved`, `resolved_total` (default 4), `likes` (hint text, empty = unknown),
`hp`, `hp_max`, `world_pos` (Vector3 anchor for the marker). `ui/mock_source.gd` builds sample data.

Mode abilities (`ui/modes.gd`): attack = bite, charge, spit, tail_strike; befriend = sing, dance, charm,
pose; observe = observe; intimidate = roar, display. `gift` (befriend) is not on a key: the stage can
swap it in with `set_abilities`. Ability ids match the C verb arguments (`attack #id <move>`, `befriend #id <skill>`).

## AudioManager interface (`godot/audio/audio_manager.gd`)

Buses `Master`, `Music`, `SFX`, `Ambience` (`default_bus_layout.tres`, also created at runtime if missing).

| Call | Meaning |
|---|---|
| `footstep(pos, speed, radius_cm=60)` | Call from the rig's foot-contact signal; cycles 3 steps, volume by speed, pitch by size. |
| `cry(kind, pos, radius_cm, volume)` | `idle/aggro/hurt/death`, pitch lower for bigger bodies. |
| `hit(pos)`, `block(pos)`, `dodge(pos)`, `spit(pos)` | Positional one-shots on SFX. |
| `combat_event(type, pos, radius_cm)` | Web event ids: 1 hit, 2/3 block, 4 dodge, 7 death. |
| `update_ambience(player_pos, height, slope, speed)` | Each frame: wind louder with height, grass rustle on gentle low ground. |
| `start_ambience()`, `set_paused(on)`, `ui_click()` | |
| `set_volume(bus, v)`, `get_volume`, `set_mute`, `is_muted` | Bus keys `master/music/sfx/ambience`; saved at once to `user://settings.cfg`. |

Positional sounds use `AudioStreamPlayer3D` (16-voice pool), so the active Camera3D is the listener.

## Notes and what is left

* Sounds were copied from `assets/audio/` to `godot/audio/sounds/` (with `CREDITS.md`) because `res://` cannot reach outside `godot/`. The test checks every file listed in the credits loads.
* `godot/project.godot` here is minimal (bus layout path only); the M0 project must keep `audio/buses/default_bus_layout`.
* Not done: gamepad/touch, localisation, real icons for abilities, the 3D enemy marker occlusion, a listening review of loudness (as in `CREDITS.md`), and wiring to the real stage and foot-contact signal.
