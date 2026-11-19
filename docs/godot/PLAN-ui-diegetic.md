# Plan: the diegetic UI (for the implementing agent)

Design: [UI-DIEGETIC.md](UI-DIEGETIC.md) (the source of truth for every look, size, colour and timing; section numbers
below refer to it). Mockups to match: `docs/godot/ui-mockups/render/*.jpg`. Branch: `ui/diegetic-redesign`.

Scope: Godot only (`godot/ui/`, `godot/game/`, `godot/devtools/legend*`, tests, docs). **Do not touch** `core/` (the C
world, its verbs, the observation), `godot/creature/`, the terrain shaders, or the agent face. Every order still goes
to C exactly as today (`stage_ui.gd`); only how things are shown and chosen changes.

Rules for every slice:

- Each slice ends with all of these green: `make godot-ui-test`, `make godot-devtools-test`, `make godot-test`,
  `make godot-play-test`, `make godot-social-test`. Update a test in the same commit that changes what it checks; never
  delete a behaviour check, re-point it at the new node.
- Software GL only for captures (`LIBGL_ALWAYS_SOFTWARE=1`, xvfb, as the existing evidence targets). No GPU flags.
- All sizes go through `Style.u()` (design units, section "All sizes..."), all colours through `Palette`, all strings
  through `Strings.t()`. No literal pixel sizes, hex colours or English text in the new files.
- No `PanelContainer`, no `StyleBoxFlat` with a background, no `Button` with a visible box in the new UI.
- Evidence is JPG (quality 88), 1280 x 720, in `docs/evidence/godot/ui-diegetic/`.

## Files

### New

| File | What |
|---|---|
| `godot/ui/fonts/AlegreyaSans-Regular.ttf`, `AlegreyaSans-Medium.ttf`, `Alegreya-Italic.ttf`, `OFL-AlegreyaSans.txt`, `OFL-Alegreya.txt` | copied from `docs/godot/ui-mockups/fonts/` |
| `godot/ui/glyphs/*.svg` (33) | copied from `docs/godot/ui-mockups/glyphs/` (regenerate with `node export-glyphs.js`). Import as textures, SVG scale 2 (192 px), mipmaps on, filter linear. White strokes: tint with `modulate` / the `color` argument |
| `godot/ui/style.gd` | `Style`: `u(x)` = `x * viewport_h / 720 * ui_scale`; motion constants (`IN`, `OUT`, `SWAP`, `GROW`, `REST`, `MOTE`, `PULSE`, `BREATH`) and `tween_in(node)`, `tween_out(node)`; `reduced_motion`, `strong_outlines`, `names_always`, `numbers` flags read from `Game.settings`; `font_sans(weight)`, `font_italic()`; `draw_halo_line(...)`, `draw_arc_styled(canvas, centre, radius, a0, a1, style, color, width, count)` for the five line styles (section 4) in screen space |
| `godot/ui/glyphs.gd` | `Glyphs.tex(name) -> Texture2D` (cached `load`), `Glyphs.draw(canvas, name, centre, size_u, color)`; `Glyphs.for_move(id)`, `for_skill(id)`, `for_item(i)`, `for_mode(mode)`; a move without a glyph falls back to `attack` and logs once |
| `godot/ui/strings.gd` | `Strings.t(key, args := [])`: a two-column table en / es (the table of section 10 plus every other visible string), language from `Game.settings["language"]` (default from `OS.get_locale_language()`: `es` or `en`). Plain dictionary; no CSV import step |
| `godot/game/shaders/ground_mark.gdshader` | the one shader for all ground rings (below) |
| `godot/game/island/ground_mark.gd` | `GroundMark` (`MeshInstance3D`): a 17 x 17 vertex grid over [-1, 1]^2, world size `2 * extent`; `place(pos: Vector3, extent: float)` re-samples the 289 heights from `Game.ground` (only when it moved more than 0.05 m or the extent changed); setters for the shader parameters; `fade_in()`, `fade_out(free := false)` |
| `godot/game/island/ground_marks.gd` | `GroundMarks` (`Node3D`, child of the island): owns the marks and their animations. API below |
| `godot/ui/mode_ring.gd` | replaces `radial_menu.gd` (7.3) |
| `godot/ui/petals.gd` | ability petals and the gift petal (7.4), cooldown ring (replaces `cooldown_sweep.gd`) |
| `godot/ui/defence_marks.gd` | guard / dodge marks at the player's feet (7.6), screen-space, anchored to the player's ground ring |
| `godot/ui/field_note.gd` | replaces `creature_card.gd` in play (7.2); `snapshot()` kept for tests |
| `godot/ui/quiet_signs.gd` | seed, vitals lines, DNA + pips, compass (7.7, 7.9, 7.13); replaces the panels of `hud.gd` |
| `godot/ui/words.gd` | whisper line, moment line, onboarding hint, optional numbers (7.10, 7.15) |
| `godot/ui/motes.gd` | motes flying from a world point to a screen sign (7.9) |
| `godot/ui/veil.gd` | full-screen veils: menu, loadout, low-health vignette, death fog (one `ColorRect` with a small canvas shader `godot/ui/veil.gdshader`: flat tint + radial vignette with inner and outer radius) |
| `godot/ui/menu.gd` | replaces `pause_menu.gd` (7.13), with the settings column |
| `godot/ui/loadout_sheet.gd` | replaces `loadout_panel.gd` (7.14) |
| `godot/ui/onboarding.gd` | the hint sequence and its saved progress (7.15) |
| `godot/tests/ui_diegetic_evidence.gd` | the eight captures (below) |

### Changed

| File | Change |
|---|---|
| `godot/ui/palette.gd` | new tokens `BONE FOG INK LICHEN EMBER OCHRE DUSK COPPER MIST` (hex in section 2), `MODE_COLORS`, `MODE_STYLES`; keep `ROLE_COLORS` and `role_color()`; add `ROLE_SHAPES`; delete `PANEL*`, `BORDER*`, `BACKDROP`, `box()`, `bar()`, and reduce `make_theme()` to fonts and font colours (no style boxes). Keep `TEXT`, `GOLD`, `LEAF`, `DANGER`, `GUARD`, `MUTED`, `EMBER` as aliases of the new tokens until the last slice (`devtools/` uses some) |
| `godot/ui/modes.gd` | unchanged data; add `NONE := &""`; `is_mode` accepts it |
| `godot/ui/game_ui.gd` | builds the new nodes; same public calls and signals (table below), so `stage_ui.gd` changes little |
| `godot/ui/hud.gd` | shrinks to a thin layer that owns `quiet_signs`, `petals`, `defence_marks`, `words`, `motes`, optional numbers; all panel building deleted |
| `godot/ui/target_rings.gd` | deleted in S5 (its drawing moves to ground marks); keep `in_window()` as a static in `ground_marks.gd` |
| `godot/game/stage/stage_ui.gd` | feed `GroundMarks` (selection, trust, beat, health, wind-up, bites, threats), start-of-fight auto-select, no default mode, refusals as marks (7.10), outcome texts via `Strings`, motes with world sources |
| `godot/game/island/island.gd` | create `GroundMarks`; call `move_marker` / `follow_marker` in `_click_ground` and clear on arrival; pass the hovered entity for 7.16 |
| `godot/game/game.gd` | settings keys `ui_scale` (1.0), `language` (""), `names_always` (false), `numbers` (false), `strong_outlines` (false), `reduced_motion` (false), `onboarding` (0 bitmask); `legend_context()` unchanged |
| `godot/project.godot` | InputMap: add `journal` (J), `family_tree` (T); remove `radial_attack`, `radial_befriend`, `radial_observe`, `radial_intimidate` (the ring uses `move_*`); default font = Alegreya Sans Regular |
| `godot/devtools/legend.gd`, `legend.json` | restyle the F1 sheet (no panel, veil, Alegreya, key caps as outlines); the corner hint is no longer shown in play (`corner_visible` default false; `corner_rows()` stays, onboarding uses it); `legend.json`: drop the four `radial_*` actions, add `journal`, `family_tree`, add four gesture rows for the ring ("Observe / Befriend / Intimidate / Attack", keys taken from `move_forward` / `move_left` / `move_back` / `move_right`, context `radial`) |
| `docs/godot/UI.md` | rewritten in the last slice to describe what exists; link to UI-DIEGETIC.md |
| `Makefile` | target `godot-ui-diegetic-evidence` |

### Deleted (in the slice named)

`godot/ui/radial_menu.gd` (S2), `godot/ui/creature_card.gd` (S2; its text rows become the journal page data, keep the
arrays `TEMPERAMENTS`, `DIETS`, `RELATIONSHIPS`, `TEMPERAMENT_NOTES` by moving them to `godot/ui/journal_data.gd`),
`godot/ui/cooldown_sweep.gd` (S3), `godot/ui/target_rings.gd` (S5), `godot/ui/pause_menu.gd` (S6),
`godot/ui/loadout_panel.gd` (S7). Remove each `.gd.uid` with its script.

## GameUI: calls kept, calls added

Kept with the same signature (the stage keeps working): `set_camera`, `bind_audio`, `set_player`, `select`,
`update_target`, `clear_selection`, `set_mode`, `set_abilities`, `set_loadout_abilities`, `set_cooldowns`,
`open_radial`, `show_damage` (draws only when `numbers` is on; always triggers the hit flash on the ring),
`show_message` (routes to a whisper line; `kind` kept for the sound), `show_dna(amount, source, world_pos := null)`
(mote from `world_pos`, or from the player if null), `set_meters`, `set_rings` (forwards to `GroundMarks`),
`show_float` (numbers only), `set_windup` (forwards to `GroundMarks`; the label is ignored), `flash` (ripple on the
player's ring), `set_paused`.

Added: `set_ground_marks(gm)`, `show_moment(text, glyph)`, `set_gift(item, count)`, `set_threats(ids)`,
`set_fight(on)`, `refuse(kind)` (7.10), `set_compass(yaw, marks)`.

Changed behaviour: `mode` starts as `Modes.NONE`; `select()` sets `NONE` and opens the ring (carcass included);
`select(info, false)` with `info.fight == true` sets attack mode directly. `_unhandled_input`: with the ring open,
`move_forward / move_left / move_back / move_right` choose (and are marked handled so the creature does not walk);
`journal` and `family_tree` emit `journal_requested` / `family_tree_requested` (the views are stubs: a veil, the
title, "Esc"; their content is a later design).

Accessors for tests (replace `ui.hud.slots`, `ui.card`, `ui.radial`):
`ui.ring` (`visible`, `centre`, `choose(i)`, `mode_at(i)`, `enabled_at(i)`, `sector_at(offset)`, `carcass`),
`ui.petals` (`count()`, `id_at(i)`, `glyph_at(i)`, `state_at(i)` in `ready / cooling / off / empty / active`,
`cooldown_at(i)`, `shape_at(i)`), `ui.note` (`visible`, `snapshot()` -> `{name, diet, relationship, sub}`),
`ui.signs` (`hp_frac`, `food_frac`, `stamina_visible`, `dna_text`, `pips_total`, `pips_filled`, `low_health`),
`ui.words` (`whisper_text`, `moment_text`, `hint_text`).

## The ground mark shader

`shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;`
Mesh UV runs 0..1 over the patch; `p = (UV - 0.5) * 2.0` is -1..1; all radii are fractions of the patch half-size
(the script sets the patch extent to 2.0 x the largest radius so teeth and the beat ring fit).

Uniforms: `color` (vec4), `radius` (0..1), `width`, `style` (0 smooth, 1 teeth, 2 dots, 3 double, 4 cut),
`count` (teeth, dots or segments), `lit` (segments lit, style 4), `frac` (0..1 arc length), `start` (radians, the
creature's front), `dir` (+1 clockwise, -1), `track` (alpha of the unlit part), `wash` (alpha of the inside),
`dot_r` (centre dot), `disc` (0..1 wind-up disc radius as a fraction of `radius`), `disc_color`, `ring2` (second ring
radius, 0 = off), `ring2_alpha`, `thick` (extra width for the rhythm window), `halo` (dark edge strength), `alpha`.

Fragment, in words (write it with `smoothstep` over `fwidth` for anti-aliasing):

1. `d = length(p)`, `ang = atan(p.x, -p.y)` turned by `start` and `dir`, wrapped to 0..TAU; `t = ang / TAU`.
2. Line mask: `line = 1 - smoothstep(w, w + aa, abs(d - radius))` with `w = max(width + thick, 1.5 * fwidth(d)) / 2`.
3. `style 1`: add triangles outside the line: for the nearest tooth centre angle `ac`, a triangle of base
   `0.12 * TAU / count` and height `3 * width` pointing outwards; drop the teeth when `fwidth(d) * 3 > width * 3`.
   `style 2`: replace the line by dots: `length(vec2((fract(t * count) - 0.5) * TAU * radius / count, d - radius))`
   against `0.75 * width`. `style 3`: add a second line at `radius + 2.4 * width` with 0.7 of the width.
   `style 4`: cut gaps of 14 degrees between `count` segments; segment index `i = floor(t * count)`; lit if `i < lit`.
4. Arc: lit where `t <= frac` (style 4: where the segment is lit); elsewhere multiply alpha by `track`.
5. Add `wash` inside `radius`, the centre dot, the disc (`d < disc * radius`, colour `disc_color`, alpha 0.30, with a
   line at its edge), the second ring at `ring2` with `ring2_alpha`.
6. Halo: the same masks widened by `2 * width`, in `INK`, at `halo * 0.6`, drawn under the colour.
7. `ALBEDO = mixed colour; ALPHA = mask * alpha`.

Vertex: move each vertex 0.04 m up and 0.02 x its camera distance towards the camera (in view space) so the mark
never z-fights with the terrain but creatures still hide it. The script, not the shader, puts the vertices on the
terrain. Render priority above the grass material. Check on the real island that river ribbons and wet banks do not
cover it; if they do, raise the offset over water only.

`GroundMarks` API (all radii in metres, entity radius = `max(0.6, radius_cm / 100)` as in `Pointer.pick_entity`):

```
move_marker(pos: Vector3)                 # 7.1 solid marker, IN contraction
follow_marker(pos: Vector3)               # 7.1 soft marker, glides
move_blocked(pos: Vector3)                # 7.1 cut ring, shake
clear_move(arrived: bool)                 # OUT (arrived: expand and fade)
select(id: int, radius_m: float)          # 7.2 bone ring; follows the entity every frame
set_mode_style(mode: StringName)          # 7.2 table
set_value(frac: float)                    # trust, health, observe progress
set_segments(total: int, lit: int)        # carcass bites
set_beat(beat_in: int, beat_ticks: int, in_window: bool)   # 7.5
ripple(); wobble(); set_pearls(n: int)
set_windup(progress: float)               # 7.6 disc; < 0 hides
hit(lost_frac: float); break_ring()
deselect()
set_threats(ids: Array)                   # 7.6, 7.16 thin toothed rings
set_hover(id: int)                        # 7.16
set_player_ring(on: bool, guard: bool)    # 7.6
shock(from_pos: Vector3, to_pos: Vector3, ok: bool)        # 7.8
```

The pearls, the bite piece flying off and the sound arcs of singing are small screen-space draws in `hud.gd` anchored
to projected points (cheaper than more shader modes).

## Slices

Each slice is one or more commits and leaves the game playable. Order matters: S1 to S3 already remove most of the
"AI-ish" look.

### S0. Foundations (no visible change)

Fonts, glyph SVGs (+ `.import` by running the editor import once headless), `style.gd`, `glyphs.gd`, `strings.gd`,
new `Palette` tokens next to the old ones, settings keys in `game.gd`, default font in `project.godot`.
Tests (`ui_test.gd`): every glyph named in `Glyphs.for_*` loads; every `Strings` key has both languages and no es
string is longer than 1.6 x its en string + 4 characters; `Style.u()` scales with viewport height and `ui_scale`;
both OFL files exist next to the fonts.

### S1. Ground marks and the move marker (7.1, section 8)

`ground_mark.gdshader`, `ground_mark.gd`, `ground_marks.gd`; island wiring (`_click_ground`, follow, arrival, WASD
cancels, blocked destination).
Tests: new `godot/game/tests/test_ground_marks.gd` in the m0 runner: the mesh heights equal `Game.ground` at the 289
points within 1 cm after `place`; a click sets a visible marker at the destination; `follow_to` moves the soft marker
and never shows both; arrival fades it within 0.4 s; a click on a creature clears it. Render test: the ring is visible
(bone pixels in the expected screen ellipse) at z = 0.15 and z = 0.40 on a slope and on flat ground, and is hidden
behind the player's body.
Evidence: `move_marker.jpg` (strip: click, travelling, arriving, follow, blocked).

### S2. Selection: ground ring, mode ring, field note, no default mode (7.2, 7.3, section 9)

`mode_ring.gd`, `field_note.gd`, `journal_data.gd`; `game_ui.gd` (mode `NONE`, WASD choose, Esc order, Tab reopen,
non-modal: `mouse_filter = PASS` and manual hit test so world clicks pass); delete `radial_menu.gd`,
`creature_card.gd`; `stage_ui.gd` passes the entity radius and sets the ring style; InputMap and `legend.json` updates.
Tests to update:
- `godot/tests/ui_test.gd`: the radial block (`sector_at`, `mode_at`, `enabled_at`, carcass) re-pointed at `ui.ring`
  with the new angles (north observe, east attack/eat, south intimidate, west befriend; a carcass has only east and
  north, and `enabled_at` is false for the other two); the card block re-pointed at `ui.note.snapshot()` and at
  `journal_data` for the moved rows; new: after `select()` `ui.mode == Modes.NONE` and keys 1-4 emit nothing; `move_left`
  with the ring open chooses befriend and is handled; Esc closes the ring and keeps the selection; a click outside
  the hit zones is not consumed.
- `godot/devtools/tests/test_inputmap.gd`: drop the four `radial_*` actions from the list; the Ctrl+B case becomes
  "Ctrl+A with the ring open does not choose" on `mode_ring`.
- `godot/devtools/tests/test_legend.gd`: the `radial` context rows now come from the gesture rows.
- `godot/game/tests/social_flow.gd`, `play_test.gd`: `ui.card.visible` -> `ui.note.visible`, `ui.radial` -> `ui.ring`,
  `radial.choose(i)` indices remapped (attack 1 east, befriend 3 west, observe 0 north, intimidate 2 south: use a
  helper `ring.choose_mode(mode)` and call that instead of indices), "choosing Attack ... sets the attack mode" kept.
Evidence: `selected_ring.jpg`, `selected_ring_es_names.jpg`.

### S3. Petals, cooldowns, gift, guard and dodge (7.4, 7.6)

`petals.gd`, `defence_marks.gd`; delete the hotbar (`move_row`, `slots`, `guard_btn`, `sweeps`) and
`cooldown_sweep.gd`; `stage_ui.gd`: `set_gift`, start-of-fight auto-select in attack mode, `set_fight`.
Tests: `ui_test.gd` hotbar checks re-pointed (`ui.petals.id_at`, `state_at`, `cooldown_at`; "the hotbar shows key and
name" becomes "the petal shows the glyph of its move and its key"; role border colour becomes the signature double
outline; observe shows one petal, intimidate two, eat one; petals are hidden with no selection and with mode `NONE`);
`play_test.gd` (`ui.hud.slots[0].text.contains("Bite")` -> `ui.petals.id_at(0) == "bite"`); new: a click on a petal
emits `ability_pressed`; a fight starting with no selection selects the attacker in attack mode; defence marks are
visible only in a fight or in attack mode; the gift petal shows the item and count and H changes its glyph.
Evidence: `combat.jpg` (with a hand-fed 60 % cooldown as the loadout evidence does), `befriend_petals.jpg`.

### S4. The quiet signs (7.7, 7.9, 7.13 seed)

`quiet_signs.gd`, `motes.gd`; delete the title, the Pause button, the meters panel, the vitals panel.
`stage_ui.gd`: compass marks (nest, selection), DNA source positions for motes.
Tests: `play_test.gd` (`player_hp_text` -> `ui.signs.hp_frac` within 0.01 of the world's hp / max; the name check
goes away with the name label: assert the name is in the journal data instead); `ui_test.gd`: resting opacity returns
after `REST`; stamina line hidden at full and shown below; low health sets `low_health` and the ember style;
`dna_text` is the balance; pips = species present, filled = resolved; a `show_dna` creates one mote and the number
changes when it lands (or at once with reduced motion); the seed click emits `pause_toggled(true)`.
Evidence: `idle.jpg`, `low_health.jpg` (S5 adds the vignette).

### S5. Feedback on the world (7.5, 7.6, 7.8, 7.10, 7.11, 7.12, 7.16)

`words.gd`, `veil.gd`; `ground_marks.gd` gets beat, pearls, ripple, wind-up disc, hits, threats, hover, shock;
delete `target_rings.gd`, the toast boxes, the wind-up bar, the target name plate, the screen-edge flash.
`stage_ui.gd`: `_social_event` maps events to marks (trust arc growth, pearls for the combo, wobble off rhythm,
observe dots, clue mote + whisper, intimidate shock and result, eat segments, bone glyph), refusal table (7.10),
outcomes (7.12), low-health veil.
Tests: `social_flow.gd` ("the card shows the trust" -> the ground ring's `frac` equals trust / 100; the beat ring is
on in befriend mode and `in_window` matches `GroundMarks.in_window(beat_in)`; the observe ring's `frac` follows
`observe_ticks`; a carcass ring has `total == 4` and `lit == meat`); `play_test.gd` (`windup_bar.visible` -> the
selection mark's `disc > 0` during a wind-up; `flash_rect` -> the player ring's ripple or the hit veil; `_numbers`
only with `numbers` on: set the setting in that test); `ui_test.gd` ("toasts shown" -> `ui.words.whisper_text`; one
whisper at a time; a moment line queues).
Evidence: `befriend_rhythm.jpg` (in the window, with pearls), `observe.jpg`, `intimidate.jpg`, `carcass_eat.jpg`,
`low_health.jpg`, `death_fog.jpg`.

### S6. Menu, settings, key sheet, onboarding (7.13, 7.15)

`menu.gd`, `onboarding.gd`; delete `pause_menu.gd`; restyle `legend.gd` (sheet only; corner off).
Signals kept: `resume_requested`, `menu_requested`, `save_requested`, `load_requested`, `setting_changed`.
Tests: `ui_test.gd` pause block re-pointed (sliders by bus key still write through `AudioManager`; save / load
availability as `slot_exists()`); new: keyboard navigation reaches every item; changing Language switches a visible
string at once; `ui_scale` changes `Style.u(10)`; Loadout is disabled away from the nest; onboarding shows hint 1 at
start, advances after the action is done twice, never shows in a fight, and is silent when `onboarding` is complete.
`test_legend.gd`: the sheet rows are unchanged in content; `corner_visible` defaults to false; `legend.png` evidence
regenerated.
Evidence: `menu.jpg`, `menu_settings_es.jpg`, `keys_sheet.jpg`, `onboarding_hint.jpg`.

### S7. Loadout sheet (7.14)

`loadout_sheet.gd`; delete `loadout_panel.gd`. Same signals (`assign(slot, move)`, `closed`) and the same `setup` /
`refresh(lo)` / `is_known` / `choose` / `open_panel` / `close_panel` / `toggle` so `stage_ui.gd` is untouched.
Tests: the loadout block of `ui_test.gd` re-pointed (tokens instead of `OptionButton`s: a known move is a token with
a glyph, an unknown one has no glyph, a move the body cannot do is disabled and `choose` still sends it for C to
refuse); role -> shape mapping covers the six roles; keys 1-4 on a focused token emit `assign`.
`loadout_evidence.gd` regenerated.
Evidence: `loadout.jpg`.

### S8. Clean-up and documents

Remove the alias colours left in `palette.gd` once nothing uses them (grep `Palette.` in `godot/devtools/`,
`godot/studio/`: the studio keeps its own look and must not change; give it a private copy of what it needs if it
used `Palette.box`). Rewrite `docs/godot/UI.md` (interface tables, keys, what the settings do). Add the evidence
strip `docs/evidence/godot/ui-diegetic/strip.jpg` (the eight states in one image, same order as the mockups) and a
short "mockup vs game" note listing every intended difference. Update `docs/godot/DEVTOOLS.md` (D13: legend sheet
only) and add a line to `docs/DESIGN.md` under A14 / G75 pointing to UI-DIEGETIC.md.

## Evidence script

`godot/tests/ui_diegetic_evidence.gd` (island + UI + C, like `social_flow.gd`), one capture per mockup state, each
set up through the real stage (select by id, choose a mode, send the order, advance ticks):
`idle`, `selected_ring`, `befriend_rhythm`, `combat`, `carcass_eat`, `low_health`, `menu`, `loadout`, at midday, plus
`befriend_rhythm` at dawn with fog (`fog_amount` high) and `combat` at evening, because bone-white on fog and ember on
a copper sky are the two hard cases. Makefile:

```
godot-ui-diegetic-evidence: godot
	@mkdir -p docs/evidence/godot/ui-diegetic
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://tests/ui_diegetic_evidence.gd -- $(CURDIR)/docs/evidence/godot/ui-diegetic
```

Look at every capture next to its mockup before calling a slice done. The check list: no box or panel anywhere; no
text in play except a name, keys and at most one line; every mark readable on fog and on the evening sky; nothing in
the centre of the screen that is not attached to a creature; the four permanent signs clearly quieter than the marks
of the current action.

## Risks and how to handle them

- **Rings on steep or broken ground** (cliffs, river banks): a 17 x 17 patch can cut through sharp terrain. Accept
  small cuts; if a ring is more than half hidden, raise the vertex lift for that mark up to 0.15 m.
- **Grass over the rings**: wanted at chase distance, but a far thin ring can disappear in tall grass. The 1.5 px
  floor and the halo help; if not enough, fade grass alpha inside the selected ring (a later change in the grass
  shader, ask first: terrain shaders are out of scope here).
- **Petals over a moving target**: smooth the anchor (0.1 s) and clamp to the safe margin so they do not jitter with
  the gait.
- **Performance**: at most 12 ground marks alive (1 move, 1 selection, 1 player, up to 8 threats, 1 hover); each is
  289 vertices and one draw. Re-sample heights only for marks that moved.
- **Tests that read text** (`slots[0].text`, card rows): replaced by ids and state names; do not keep hidden labels
  only to satisfy old tests.
- **The agent face and replays** are untouched: no order is added or changed, the auto-select at fight start is UI
  state only. If a test of the benchmark fails, the slice is wrong.

## Out of scope (later designs)

The journal pages and the family tree view (only their entry points and stub screens here), creature posture
animations for mood (7.16 lists what is needed), the white hit rim on creature bodies, the strategic-zoom icons
(they should adopt the glyph language later), the main menu and loading screens, the studio.
