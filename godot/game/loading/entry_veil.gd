extends CanvasLayer
## The one loading screen of an island entry (menu, cell bridge, studio, load): terrain generation when it is not cached, then the
## island build phases. It lives under the root (Game owns it) so it survives the scene change; the island reports each finished
## phase (Game.entry_phase) and the bar eases between those real values. The bar never shows 100% before the island is ready.
## Design: the menu's dark sky, the title, a rotating line of tips (ES/EN), a thin progress line. Hand-off: fade out in FADE_S.

const Strings := preload("res://ui/strings.gd")
const Style := preload("res://ui/style.gd")
const Loading := preload("res://game/loading/loading_screen.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")

signal terrain_done(entry: Dictionary)
signal faded

const SKY_TOP := Color("0b1a21")
const SKY_BOTTOM := Color("070d11")
const GOLD := Color("e8d9a8")
const FADE_S := 0.25
const TIP_S := 4.5
## Share of the whole bar given to terrain generation when it has to run (4 s against ~11 s of island build).
const TERRAIN_SHARE := 0.3
## Milliseconds of each island phase (measured, docs/godot/EAT-LOADING.md): the weights of the bar.
const PHASE_MS := {"environment": 5, "kit_reused": 400, "terrain_meshes": 107, "water": 2118, "rivers": 375, "grass": 105, "camera": 1,
	"stage_setup": 57, "props_flora": 1574, "stage_reset": 124, "nav_warm": 4432, "creatures": 1282, "ui_and_rest": 731}
const PHASE_TEXT := {"environment": "load_island", "kit_reused": "load_island", "terrain_meshes": "load_island", "water": "load_water",
	"rivers": "load_water", "grass": "load_flora", "camera": "load_flora", "stage_setup": "load_flora", "props_flora": "load_world",
	"stage_reset": "load_world", "nav_warm": "load_creatures", "creatures": "load_creatures", "ui_and_rest": "load_ready"}

var shown := 0.0                      # the displayed fraction (monotonic, < 1 until the island is ready)
var target := 0.0                     # the real fraction of the finished phases
var plan: Array = []                  # island phases expected, in order
var done_phases: Array = []
var terrain_share := 0.0
var generating := false
var finished := false
var fade_started := false
var from := ""
var log: Array = []                   # [{t_ms, shown, target}] a sample per frame (tests: monotonic)
var _root: Control
var _bar_fill: ColorRect
var _bar_back: ColorRect
var _label: Label
var _tip: Label
var _tip_i := 0
var _tip_t := 0.0
var _creep_t := 0.0
var _t0 := 0
var _gen_thread: Thread
var _gen_params := {}
var _gen_gen
var _gen_box := {"entry": {}}
var _fade_t := 0.0
var _prev_auto_quit := true

func _init() -> void:
	layer = 90
	name = "EntryVeil"
	process_mode = Node.PROCESS_MODE_ALWAYS

func begin(from_name: String, params: Dictionary = {}, need_terrain := false) -> void:
	from = from_name
	_t0 = Time.get_ticks_msec()
	_build_ui()
	if need_terrain:
		generating = true
		terrain_share = TERRAIN_SHARE
		_gen_params = params
		_gen_gen = CporeTerrain.new()
		_prev_auto_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
		_gen_thread = Thread.new()
		_gen_thread.start(func() -> void: _gen_box["entry"] = TerrainCache.build(_gen_params, _gen_gen))
		_set_label("load_terrain")

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP      # nothing underneath is clickable while the island builds
	add_child(_root)
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
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := _lbl("Primigenia", 54, GOLD)
	box.add_child(title)
	_tip = _lbl("", 18, Color(0.85, 0.88, 0.82, 0.8))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(520, 52)
	_tip_i = int(Time.get_ticks_msec() / 1000) % 6
	box.add_child(_tip)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(1, 1, 1, 0.10)
	_bar_back.custom_minimum_size = Vector2(520, 3)
	box.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = GOLD
	_bar_fill.size = Vector2(0, 3)
	_bar_back.add_child(_bar_fill)
	_label = _lbl("", 15, Color(0.85, 0.88, 0.82, 0.55))
	box.add_child(_label)
	_show_tip()
	_apply()

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Style.font_sans(size >= 40))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _set_label(key: String) -> void:
	if _label != null:
		_label.text = Strings.t(key)

func _show_tip() -> void:
	_tip.text = Strings.t("tip_%d" % (_tip_i % 6 + 1))
	_tip_t = 0.0

# ---- progress -------------------------------------------------------------------------------------------------------------

func set_plan(phases: Array) -> void:
	plan = phases.duplicate()
	done_phases.clear()
	_creep_t = 0.0

func _weight_sum() -> float:
	var s := 0.0
	for p in plan:
		s += float(PHASE_MS.get(p, 50))
	return maxf(s, 1.0)

## A finished island phase (the island's own build_ms keys): the real fraction moves up to it.
func phase_done(name: String) -> void:
	if finished or done_phases.has(name):
		return
	done_phases.append(name)
	var acc := 0.0
	for p in done_phases:
		acc += float(PHASE_MS.get(p, 50))
	var frac := clampf(acc / _weight_sum(), 0.0, 1.0)
	target = maxf(target, terrain_share + (1.0 - terrain_share) * frac * 0.98)
	_creep_t = 0.0
	_set_label(PHASE_TEXT.get(_next_phase(), "load_world"))

func _next_phase() -> String:
	for p in plan:
		if not done_phases.has(p):
			return p
	return "ui_and_rest"

## Where the bar may drift to while the next phase runs: a share of that phase, never its end.
func _cap() -> float:
	var nxt := _next_phase()
	var w := float(PHASE_MS.get(nxt, 50)) / _weight_sum() * (1.0 - terrain_share) * 0.98
	var secs := maxf(0.4, float(PHASE_MS.get(nxt, 50)) / 1000.0)
	return target + w * 0.8 * (1.0 - exp(-_creep_t / secs))

func _process(dt: float) -> void:
	if generating:
		_process_terrain()
	if finished:
		return
	_creep_t += dt
	_tip_t += dt
	if _tip_t >= TIP_S:
		_tip_i += 1
		_show_tip()
	var goal := minf(_cap(), 0.995) if not generating else minf(terrain_share, shown + 0.0)
	if generating:
		goal = target
	shown = maxf(shown, lerpf(shown, goal, 1.0 - exp(-5.0 * dt)))
	shown = minf(shown, 0.995)
	_apply()
	log.append({"t": Time.get_ticks_msec() - _t0, "shown": shown, "target": target, "phase": _next_phase()})
	if fade_started:
		_fade_t += dt
		var u := clampf(_fade_t / FADE_S, 0.0, 1.0)
		_root.modulate.a = 1.0 - (1.0 - pow(1.0 - u, 3.0))      # ease-out: it leaves quickly, then settles
		if u >= 1.0:
			faded.emit()
			queue_free()

func _process_terrain() -> void:
	if _gen_thread == null:
		return
	if _gen_thread.is_alive():
		var p: Dictionary = _gen_gen.progress()
		target = maxf(target, Loading.overall_fraction(p.stage, p.done, p.total) * terrain_share * 0.98)
		var idx := clampi(int(p.stage), 0, Loading.STAGE_TEXT.size() - 1)
		if _label != null:
			_label.text = Strings.t("load_terrain")
		return
	_gen_thread.wait_to_finish()
	_gen_thread = null
	generating = false
	get_tree().auto_accept_quit = _prev_auto_quit
	target = maxf(target, terrain_share)
	terrain_done.emit(_gen_box["entry"])

func _apply() -> void:
	if _bar_fill == null:
		return
	_bar_fill.size = Vector2(_bar_back.size.x * shown, 3)

## The island is built and its first frame is ready: the bar completes and the screen fades out.
func island_ready() -> void:
	if finished:
		return
	finished = true
	# the first frame of the island is drawn behind the screen before it leaves
	await get_tree().process_frame
	await get_tree().process_frame
	shown = 1.0
	target = 1.0
	_apply()
	_set_label("load_ready")
	fade_started = true
	set_process(true)
	# _process returns early when finished: drive the fade from here
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void:
		faded.emit()
		queue_free())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _gen_thread != null:
		_gen_thread.wait_to_finish()
		get_tree().quit()
