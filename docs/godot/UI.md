# Godot UI and audio

The look and the rules are in [UI-DIEGETIC.md](UI-DIEGETIC.md) (the design of record) and its plan
[PLAN-ui-diegetic.md](PLAN-ui-diegetic.md); this file says what exists in `godot/ui/` and how to drive it. The in-play UI is
**minimal and diegetic**: rings on the ground, a few quiet signs, words only when they are needed. No panels, no boxes.
Owner answers that override the doc where they differ are listed under "Decisions" below.

Tests: `make godot-ui-test` (headless), `make godot-play-test`, `make godot-social-test`, `make godot-devtools-test`.
Evidence (JPG, real island, software GL under xvfb): `make godot-ui-diegetic-evidence` writes `docs/evidence/godot/ui-diegetic/`
(`godot/tests/ui_diegetic_evidence.gd`).

## What is on screen

| Sign | File | What it is |
|---|---|---|
| Move marker | `game/island/ground_marks.gd`, `ground_mark.gd`, `game/shaders/ground_mark.gdshader` | A white circle on the ground where you click; contracts in, breathes, expands and fades on arrival. Holding the button shows the softer moving marker (four short arcs). Deep water and ground steeper than 51.6 degrees order nothing and show the cut "cannot go there" ring. |
| Selection ring | same | A ring under the selected creature, in the style of the chosen mode: smooth lichen (trust), ember teeth (its health, emptying), ochre dots (observe progress), dusk double line (intimidate), ochre ring cut into the bites left (a carcass). While befriending a second ring closes in on each beat and the trust ring thickens in the +-2 tick window. Ember disc = the wind-up. Rings follow the visual ground, i.e. the water surface over rivers. |
| Mode ring | `mode_ring.gd` | A hairline circle round the selected creature, four arcs: **click** the west half (Befriend), east half (Attack, or Eat on a carcass), north (Observe), south (Intimidate). Mouse only; W A S D keep walking while it is open; it is not modal. |
| Field note | `field_note.gd` | The species name (Alegreya Italic), the diet glyph and four relationship dashes. The old card's other rows are in `journal_data.gd`. |
| Petals | `petals.gd` | The moves on keys 1-4 as glyph discs on an arc above the target, a gift petal (G, H cycles) in Befriend. Role = outline shape; cooldown = a ring that closes. Click or key. |
| Guard and dodge | `defence_marks.gd` | Three small marks at your creature's feet (Q, E, Space), in a fight or in Attack mode. |
| Quiet signs | `quiet_signs.gd` | Bottom-left: the seed (menu) and three hairlines (stamina, health, hunger). Top-left: DNA (spendable balance only) and one ring per species present. Low health turns the line ember and pulses. Numbers only with "Numbers: On". |
| Round map | `minimap.gd` | Top-right, north-up, about 420 m to the edge: coastline, rivers, the nest, the selected creature, your heading, discovered `?` places when the game has any. Fades out when the strategic camera is on. |
| Words | `words.gd` | One whisper line at a time (3.5 s), a rare moment line (Alegreya Italic, with its glyph), the onboarding hint, numbers (Numbers: On). |
| Motes | `motes.gd` | DNA flies from where it came from to the DNA sign; clues fly to the seed. |
| Veils | `veil.gd`, `veil.gdshader` | Menu (0.62), loadout (0.42), the ember vignette of low health and hits, the fog of death. |
| Menu | `menu.gd` | Opened by the seed or Esc: a text list (Resume, Journal, Family tree, Loadout, Settings, Keys, Save, Load, Main menu) and a settings column (Language, Size of the signs, Names on signs, Numbers, Stronger outlines, Less motion, Round map, the four audio buses, Mute). |
| Loadout | `loadout_sheet.gd` | Key L at the nest: tokens of the moves you know, four slots; click a token then a slot, or Left/Right and 1-4. |
| Journal, family tree | `stub_view.gd` | J and T open a veil with a title (the journal also shows DNA earned). The pages are a later design. |
| Onboarding | `onboarding.gd` | One hint at a time (walk, look, select, choose on the ring, keys 1-4, guard, eat, loadout, F1), progress saved in `Game.settings["onboarding"]`; "Show the hints again" is the menu's reset. |

`style.gd` holds sizes (`Style.u()`), motion constants and the line-drawing helpers; `glyphs.gd` the 33 SVG glyphs (`godot/ui/glyphs/`);
`strings.gd` every visible string in English and Spanish; `palette.gd` the colour tokens (the old panel colours stay only for the
dev tools, the studio and the main menu). Fonts: Alegreya Sans and Alegreya Italic (`godot/ui/fonts/`, OFL).

## GameUI interface (`godot/ui/game_ui.gd`)

```gdscript
var ui := GameUI.new()                 # CanvasLayer, layer 10; a child of the island
ui.set_camera(camera)                  # projects the ring, the petals, the motes
ui.set_ground_marks(island.ground_marks)
ui.anchor_fn = Callable(...)           # (id) -> {pos, height}: the creature's rendered position
ui.bind_audio(audio)                   # menu sliders, UI click, pause
```

| Call | Meaning |
|---|---|
| `set_player(name, hp, hp_max, stamina, stamina_max)` | The vitals lines and the low-health veil. |
| `set_meters(dna_total, dna_balance, resolved, present, food, food_max)` | DNA balance (the number), species rings, hunger. The total goes to the journal. |
| `select(info, open_menu=true, menu_pos=null)` | Field note, ground ring, mode ring open, **no mode**. With `open_menu=false` and `info.fight` it goes straight to Attack. |
| `update_target(info)` / `clear_selection()` | Live fields; hides note, rings and petals. |
| `set_mode(mode)` | `Modes.NONE` (default), attack, befriend, observe, intimidate, eat. Puts that mode's moves on keys 1-4 (none for NONE). |
| `set_loadout_abilities(list)` / `set_cooldowns(fracs)` | The four Attack petals (`{id, name, move, role, stamina, cooldown, empty?}`) and their cooldown fractions. |
| `set_gift(item, count)` / `set_fight(on)` | The gift petal; guard and dodge marks in a fight. |
| `set_rings(beat, beat_in, observe, trust, carcass)` | Feeds the ground ring (trust, observe progress, health, bites) and the beat ring. |
| `set_windup(progress)` | The ember disc on the selected creature's ring; negative hides it. |
| `show_message(text, kind)` | A whisper line. `show_moment(text, glyph)` a moment line. `show_clue(world_pos, text)` whisper plus a mote to the seed. |
| `show_dna(amount, source, world_pos)` | A mote from `world_pos`; the number waits for it. |
| `show_damage(pos, amount, on_player)` / `show_float(pos, text, color)` | Numbers: only with "Numbers: On". |
| `flash(kind)` | `hit`: the ember edge and the health line; `guard` / `dodge`: a ripple on your ring. |
| `set_paused(on)` | The menu over the veil; also pauses audio. |
| `open_radial(pos)` | Opens the ring on the selection (Tab does the same). |

Signals: `mode_changed`, `ability_pressed(index, ability)`, `gift_pressed`, `gift_cycle_pressed`, `guard_pressed`, `dodge_pressed(dir)`,
`selection_changed(id)`, `pause_toggled(bool)`, `menu_requested`, `save_requested`, `load_requested`, `loadout_requested`,
`loadout_assign(slot, move)`, `journal_requested`, `family_tree_requested`, `ui_click`.

Accessors the tests use: `ui.ring` (`visible`, `sector_at`, `mode_at`, `enabled_at`, `choose`, `choose_mode`, `carcass`, `handle_input`),
`ui.petals` (`count`, `id_at`, `glyph_at`, `state_at`, `cooldown_at`, `shape_at`, `gift_visible`), `ui.note.snapshot()`, `ui.signs`
(`hp_frac`, `food_frac`, `stamina_visible`, `low_health`, `dna_text()`, `pips_total`, `pips_filled`, `sign_alpha`), `ui.words`
(`whisper_text`, `moment_text`), `ui.menu`, `ui.loadout_panel`, `ui.veil`, `ui.defence`, `ui.minimap`, `ui.onboarding`.

`info` dictionary: `id`, `name`, `species`, `temperament`, `diet` (0 herbivore, 1 carnivore, 2 omnivore), `relationship` (0 stranger ... 3 ally),
`resolved`, `likes`, `dislikes`, `hp`, `hp_max`, `carcass_meat` (-1 for a living creature), `radius_m`, `height`, `body_pos`, `refuses`, `fight`.
`ui/mock_source.gd` builds sample data.

## Keys

| Key | Does |
|---|---|
| Left click | Walk there (white circle); a creature: select it (the ring opens). Hold: follow the pointer. |
| Click on the ring | Choose Befriend (west), Attack or Eat (east), Observe (north), Intimidate (south). |
| 1-4 | The moves of the chosen mode (nothing until a mode is chosen). G / H: give / change the gift (Befriend). |
| Space, Q, E | Guard, dodge left, dodge right. |
| Tab | Reopen the ring on the selection. |
| Esc | Closes the ring, then deselects, then opens the menu. |
| L | The loadout, at the nest. J: the journal. T: the family tree. |
| F1 (hold) | The key sheet (also the menu's "Keys"). The corner hint is off by default. |

## Decisions (owner, 2026-11-19)

1. Mode selection is mouse only; no letter or W A S D mode keys. (A "keyboard modes" setting is deferred.)
2. No default mode: after selecting, keys 1-4 do nothing until a mode is chosen; a fight selects the attacker in Attack mode.
3. A small round map top-right instead of the compass strip.
4. Numbers are off by default ("Numbers: On" brings back trust, damage and vitals values); DNA always shows its number.
5. DNA shows the spendable balance; the total earned is on the journal stub.
6. The long creature card is the journal's; in play only the field note.

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
* Deviations from the plan, and what is deferred: see "Implemented" in [UI-DIEGETIC.md](UI-DIEGETIC.md).
