extends Control
# Main menu: the stage picker. Celula and Criatura are playable cards; the later arcs are a calm "proximamente" strip.
# Menu-first boot: the island terrain is only loaded when Criatura is chosen (cache hit -> straight in, miss -> the
# loading screen). Motion follows docs/godot/STAGE-MENU.md: hover 150 ms ease-out, press 0.97 / 120 ms, entrance < 500 ms,
# keyboard focus is instant, a 200 ms fade out before the scene changes, Game.settings.reduced_motion = fades only.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")
const Scenario := preload("res://devtools/scenario.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const LoadingScene := preload("res://game/loading/loading_screen.tscn")

const ART := "res://game/menu/art/primigenia-3d-0%d-%s.jpg"
const CELL_SCENE := "res://cell/cell_stage.tscn"
const SKY_TOP := Color("0b1a21")
const SKY_BOTTOM := Color("070d11")
const FADE_MS := 0.20
const HOVER_S := 0.15
const PRESS_S := 0.12

const CARD_SHADER := """
shader_type canvas_item;
uniform vec2 size = vec2(100.0);
uniform float radius = 16.0;
void fragment() {
	vec2 p = UV * size;
	float r = radius;
	vec2 q = vec2(min(p.x, size.x - p.x), p.y);   // round the top corners only
	float a = 1.0;
	if (q.x < r && q.y < r) {
		a = 1.0 - smoothstep(r - 1.0, r, length(q - vec2(r)));
	}
	COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, a) * COLOR;
}
"""

static var _entered_once := false        # the full entrance plays the first time the menu opens in a session

var play_button: Button      # the Criatura card (kept by that name: the play test presses it)
var cell_button: Button      # the Celula card
var legacy_label: Label      # "Herencia de tu celula: ..." on the Criatura card, only when Game.cell_legacy() exists
var creator_button: Button
var plain_button: Button     # "Sin herencia": a new creature game that ignores the cell's legacy; null without a legacy
var continue_button: Button  # null without a save
var quit_button: Button
var genome_label: Label
var cards: Array[Button] = []
var cell_available := false
var assume_cell_scene := false   # evidence only: draw the Celula card as playable before the cell scene exists
var fading := false
var reduced := false

var _fade: ColorRect
var _title: Label
var _tagline: Label
var _rise: Array[Control] = []           # entrance targets: the cards and the strip
var _loading: Node = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Palette.make_theme()
	reduced = Style.reduced_motion()
	cell_available = assume_cell_scene or ResourceLoader.exists(CELL_SCENE)
	_build()
	_entrance()
	(cell_button if cell_available else play_button).grab_focus.call_deferred()

func _build() -> void:
	var grad := Gradient.new()
	grad.set_color(0, SKY_TOP)
	grad.set_color(1, SKY_BOTTOM)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var bg := TextureRect.new()
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vp := get_viewport_rect().size
	var cw := clampf(vp.x * 0.33, 340.0, 520.0)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_title = _label("Primigenia", 54, Palette.GOLD, true)
	col.add_child(_title)
	_tagline = _label(Strings.t("tagline"), 18, Palette.MUTED)
	col.add_child(_tagline)
	col.add_child(_spacer(6))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	# Celula
	cell_button = _card(cw, 1, "cell", Strings.t("stage_cell"), Strings.t("stage_cell_line") if cell_available else Strings.t("under_construction"), cell_available)
	cell_button.pressed.connect(_play_cell)
	row.add_child(cell_button)
	# Criatura
	var genome_name := str(Game.player_genome().get("name", "Merodeador"))
	play_button = _card(cw, 2, "creature", Strings.t("stage_creature"), Strings.t("stage_creature_line"), true)
	play_button.pressed.connect(play_creature)
	row.add_child(play_button)
	var body: VBoxContainer = play_button.get_meta("text_box")
	genome_label = _label(Strings.t("your_creature", [genome_name]), 15, Palette.COPPER)
	genome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	genome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(genome_label)
	var leg: Dictionary = Game.cell_legacy()
	if not leg.is_empty():
		legacy_label = _label(Strings.t("cell_legacy", [" · ".join([Strings.t("leg_diet_" + str(leg.diet)), Strings.t("leg_def_" + str(leg.defense)), Strings.t("leg_size_" + str(leg.size_class))])]), 14, Palette.MUTED)
		legacy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		legacy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		legacy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(legacy_label)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	body.add_child(acts)
	creator_button = _action(Strings.t("creator"), func() -> void: _leave(Game.goto_studio))
	acts.add_child(creator_button)
	if not leg.is_empty():
		plain_button = _action(Strings.t("no_legacy"), play_plain)
		acts.add_child(plain_button)
	if _save_exists():
		continue_button = _action(Strings.t("continue"), continue_game)
		acts.add_child(continue_button)
	cards = [cell_button, play_button]
	_wire_focus()

	col.add_child(_spacer(12))
	# the later arcs: one quiet strip of dimmed thumbnails
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 22)
	strip.modulate = Color(1, 1, 1, 0.8)
	col.add_child(strip)
	var soon := [[3, "band", "stage_band"], [4, "realm", "stage_realm"], [5, "industry", "stage_industry"], [6, "space", "stage_space"]]
	for s in soon:
		strip.add_child(_soon_item(s[0], s[1], Strings.t(s[2])))
	_rise = [cell_button, play_button, strip]

	col.add_child(_spacer(4))
	# footer
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(foot)
	quit_button = _action(Strings.t("quit"), func() -> void: get_tree().quit())
	foot.add_child(quit_button)
	quit_button.focus_neighbor_top = play_button.get_path()

	_fade = ColorRect.new()
	_fade.color = SKY_BOTTOM
	_fade.color.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

# --- widgets -----------------------------------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, medium := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.font_sans(medium))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(Palette.INK, 0.6))
	l.add_theme_constant_override("outline_size", 3 if size >= 40 else 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func _flat() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _action(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Style.font_sans(true))
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Palette.BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 1, 1, 0.07)
	n.set_corner_radius_all(10)
	n.content_margin_left = 16
	n.content_margin_right = 16
	n.content_margin_top = 6
	n.content_margin_bottom = 6
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(1, 1, 1, 0.14)
	var f := n.duplicate() as StyleBoxFlat
	f.bg_color = Color(Palette.COPPER, 0.16)
	f.set_border_width_all(2)
	f.border_color = Palette.COPPER
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", f)
	b.pressed.connect(cb)
	return b

func _soon_item(idx: int, key: String, name: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := TextureRect.new()
	img.texture = load(ART % [idx, key])
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(88, 36)
	img.modulate = Color(0.5, 0.5, 0.55, 0.7)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.material = _round_mat(Vector2(88, 36), 8.0)
	h.add_child(img)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _label(name, 16, Color(Palette.BONE, 0.55), true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(n)
	var s := _label(Strings.t("coming_soon"), 13, Color(Palette.FOG, 0.5))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(s)
	h.add_child(v)
	return h

func _round_mat(size: Vector2, radius: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CARD_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("radius", radius)
	return m

# A stage card: a Button (so pressed / focus / disabled all work) holding a "lift" body that animates.
func _card(width: float, idx: int, key: String, title: String, line: String, enabled: bool) -> Button:
	var img_h := width * 0.40
	var c := Button.new()
	c.flat = true
	c.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	c.disabled = not enabled
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		c.add_theme_stylebox_override(n, _flat())
	c.custom_minimum_size = Vector2(width, img_h + 140)
	var lift := Control.new()                    # animated: position.y and scale
	lift.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lift)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.09, 0.11, 0.78)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_child(panel)
	var img := TextureRect.new()
	img.texture = load(ART % [idx, key])
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	img.offset_bottom = img_h
	img.material = _round_mat(Vector2(width, img_h), 18.0)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_child(img)
	var ring := Panel.new()                      # the copper focus ring: a soft edge, not a border box
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color(0, 0, 0, 0)
	rb.set_corner_radius_all(18)
	rb.set_border_width_all(2)
	rb.border_color = Palette.COPPER
	ring.add_theme_stylebox_override("panel", rb)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.modulate.a = 0.0
	lift.add_child(ring)
	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_top = img_h + 10
	text.offset_left = 18
	text.offset_right = -18
	text.offset_bottom = -10
	text.add_theme_constant_override("separation", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_child(text)
	var t := _label(title, 28, Palette.BONE if enabled else Color(Palette.BONE, 0.6), true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(t)
	var l := _label(line, 16, Palette.FOG if enabled else Color(Palette.FOG, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(l)
	var base := 0.8 if enabled else 0.38
	img.modulate = Color(base, base, base, 1)
	c.set_meta("lift", lift)
	c.set_meta("image", img)
	c.set_meta("ring", ring)
	c.set_meta("text_box", text)
	c.set_meta("base", base)
	c.set_meta("state", {"hover": false, "down": false, "t": 0.0, "tween": null})
	lift.resized.connect(func() -> void: lift.pivot_offset = lift.size / 2.0)
	if enabled:
		c.mouse_entered.connect(_hover.bind(c, true))
		c.mouse_exited.connect(_hover.bind(c, false))
		c.button_down.connect(_press.bind(c, true))
		c.button_up.connect(_press.bind(c, false))
		c.focus_entered.connect(_focus.bind(c, true))
		c.focus_exited.connect(_focus.bind(c, false))
	return c

func _wire_focus() -> void:
	var enabled_cards: Array[Button] = []
	for c in cards:
		if not c.disabled:
			enabled_cards.append(c)
	for i in enabled_cards.size():
		var c := enabled_cards[i]
		c.focus_neighbor_left = enabled_cards[maxi(i - 1, 0)].get_path()
		c.focus_neighbor_right = enabled_cards[mini(i + 1, enabled_cards.size() - 1)].get_path()
	# Down from the Criatura card goes to its actions, Up comes back
	play_button.focus_neighbor_bottom = creator_button.get_path()
	creator_button.focus_neighbor_top = play_button.get_path()
	var acts: Array[Button] = [creator_button]
	for extra in [plain_button, continue_button]:
		if extra != null:
			acts.append(extra)
	for i in acts.size():
		acts[i].focus_neighbor_left = acts[maxi(i - 1, 0)].get_path()
		acts[i].focus_neighbor_right = acts[mini(i + 1, acts.size() - 1)].get_path()
		acts[i].focus_neighbor_top = play_button.get_path()

# --- card motion -------------------------------------------------------------------------------------------------

# The visual state of a card, t 0..1 (rest..raised) and `down` (pressed).
func _apply(c: Button, t: float, down: bool) -> void:
	var lift: Control = c.get_meta("lift")
	var img: TextureRect = c.get_meta("image")
	var base: float = c.get_meta("base")
	lift.position.y = 0.0 if reduced else -4.0 * t
	var s := 0.97 if (down and not reduced) else 1.0
	lift.scale = Vector2(s, s)
	var b := lerpf(base, 1.0, t)
	img.modulate = Color(b, b, b, 1)

func _state(c: Button) -> Dictionary:
	return c.get_meta("state")

func _animate_to(c: Button, target: float, seconds: float, down: bool) -> void:
	var st := _state(c)
	if st.tween != null and (st.tween as Tween).is_valid():
		(st.tween as Tween).kill()
	var from: float = st.t
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		st.t = v
		_apply(c, v, st.down), from, target, seconds).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	st.tween = tw

func _target_t(c: Button) -> float:
	var st := _state(c)
	return 1.0 if (st.hover or c.has_focus()) else 0.0

func _hover(c: Button, on: bool) -> void:
	if fading:
		return
	_state(c).hover = on
	_animate_to(c, _target_t(c), HOVER_S, _state(c).down)

func _press(c: Button, down: bool) -> void:
	if fading:
		return
	var st := _state(c)
	st.down = down
	var tw_t: float = st.t
	if st.tween != null and (st.tween as Tween).is_valid():
		(st.tween as Tween).kill()
	_apply(c, tw_t, down)
	# the scale springs back from the press; the rest of the state is unchanged
	if not down:
		var lift: Control = c.get_meta("lift")
		var tw := create_tween()
		tw.tween_property(lift, "scale", Vector2.ONE, PRESS_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.tween = tw
	else:
		var lift2: Control = c.get_meta("lift")
		var tw2 := create_tween()
		tw2.tween_property(lift2, "scale", Vector2(0.97, 0.97), PRESS_S).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		st.tween = tw2

# Keyboard / gamepad focus is instant: no tween on a keyboard-triggered action.
func _focus(c: Button, on: bool) -> void:
	var st := _state(c)
	var ring: Control = c.get_meta("ring")
	ring.modulate.a = 1.0 if on else 0.0
	if st.tween != null and (st.tween as Tween).is_valid():
		(st.tween as Tween).kill()
	st.t = _target_t(c)
	_apply(c, st.t, false)

# --- entrance and exit -------------------------------------------------------------------------------------------

func _entrance() -> void:
	var full := not _entered_once
	_entered_once = true
	var span := 0.45 if full else 0.28
	var items: Array[Control] = [_title, _tagline]
	items.append_array(_rise)
	var n := items.size()
	var step := minf(0.04, (span - 0.18) / maxf(n - 1, 1))
	var dur := 0.18 if not full else 0.24
	for i in n:
		var it := items[i]
		it.modulate.a = 0.0 if it != _rise[2] else 0.0
		var rises := (it is Button) and not reduced
		var node: Control = it
		var lift: Control = null
		if it is Button:
			lift = it.get_meta("lift")
		var target: Control = lift if lift != null else it
		var y0 := target.position.y
		if rises:
			target.position.y = y0 + 12.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_interval(step * i)
		tw.chain().tween_property(node, "modulate:a", 1.0 if it != _rise[2] else 0.8, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		if rises:
			tw.tween_property(target, "position:y", y0, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

# 200 ms fade to the background colour, then run `go`.
func _leave(go: Callable) -> void:
	if fading:
		return
	fading = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_MS).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(go)

# --- actions -----------------------------------------------------------------------------------------------------

func _play_cell() -> void:
	if not cell_available:
		return
	_leave(func() -> void:
		var g := get_node_or_null("/root/Game")
		if g != null and g.has_method("goto_cell"):
			g.goto_cell()
		else:
			get_tree().change_scene_to_file(CELL_SCENE))

## Criatura: the terrain is loaded only now. A cache hit goes straight in; a miss shows the loading screen.
func play_creature() -> void:
	Game.begin_creature()          # a new game uses the cell's legacy when there is one
	_leave(_enter_island)

## Criatura without the legacy: the plain hatchling.
func play_plain() -> void:
	Game.begin_creature(true)
	_leave(_enter_island)

func continue_game() -> void:
	var parsed := Scenario.read("%s/%s" % [Scenario.save_dir, Scenario.SAVE_SLOT])
	if not parsed.ok:
		push_warning("continue: %s" % parsed.error)
		return
	Game.pending_scenario = parsed
	Game.creature_legacy = {}
	var isl: Dictionary = parsed.dict.get("island", {})
	if isl.has("seed") and int(isl.seed) != int(Game.settings.seed):
		Game.settings.seed = int(isl.seed)
		Game.data = null                       # a different island than the one in memory
	_leave(_enter_island)

func _enter_island() -> void:
	var params := {"seed": int(Game.settings.seed)}
	if Game.data != null and int(Game.terrain.get("seed", Game.settings.seed)) == int(Game.settings.seed):
		Game.goto_island()
		return
	var entry := TerrainCache.load_entry(params)
	if not entry.is_empty():
		Game.set_island(entry)
		Game.goto_island()
		return
	var screen := LoadingScene.instantiate()
	_loading = screen
	add_child(screen)
	screen.finished.connect(_on_generated)
	screen.start(params)

func _on_generated(entry: Dictionary) -> void:
	if entry.get("error", -1) != 0:
		push_error("terrain generation failed: %s" % [entry.get("error")])
		get_tree().quit(1)
		return
	Game.set_island(entry)
	Game.goto_island()

func _save_exists() -> bool:
	return FileAccess.file_exists("%s/%s.json" % [Scenario.save_dir, Scenario.SAVE_SLOT])
