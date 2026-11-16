extends Control
# First-run island generation with progress. Generation runs on a worker Thread; this node only
# polls progress() each frame and never lets the thread touch the scene tree.

const TerrainCache := preload("res://game/island/terrain_cache.gd")

signal finished(entry: Dictionary)

# Stage labels from web/terrain-lab/lab.mjs, plus the derived-map pass.
const STAGE_TEXT := [
	"Raising the range and cutting its valleys",
	"Rain is carving the gullies",
	"Loose stone is settling into scree",
	"Tracing the drainage network",
	"Landscape ready",
	"Building the island",
]
# Share of the wall-clock time of each stage at N=1024 (measured once: 1838, 286, 996, 228 ms for
# the four generator stages; ~100 ms for the derived maps and the cache write). Sums to 1.
const STAGE_WEIGHT := [0.533, 0.083, 0.289, 0.066, 0.0, 0.029]
# Placeholder copy (W13 panspermia story); owner to approve.
const TITLE := "Primigenia"
const TAGLINE := "Seeds from the dark between stars are taking root."

var _params: Dictionary
var _gen := CporeTerrain.new()
var _thread: Thread
var _box := {"entry": {}, "prep": false}
var _bar: ProgressBar
var _label: Label
var _fraction := 0.0
var _done := false
var _started_ms := 0
var _prev_auto_quit := true

func start(params: Dictionary) -> void:
	_params = params
	_started_ms = Time.get_ticks_msec()
	_build_ui()
	_prev_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_thread = Thread.new()
	_thread.start(_work)

func _work() -> void:
	var entry := TerrainCache.build(_params, _gen)
	_box["entry"] = entry

func _build_ui() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.13, 0.39, 0.84))
	grad.set_color(1, Color(0.95, 0.84, 0.70))
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
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title)
	var tag := Label.new()
	tag.text = TAGLINE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", Color(1, 0.97, 0.9, 0.9))
	box.add_child(tag)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(560, 14)
	box.add_child(_bar)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	box.add_child(_label)
	_update_ui(0.0, 0)

# Overall fraction from the stage index and its done/total. Monotonic by construction.
static func overall_fraction(stage: int, done: int, total: int) -> float:
	var acc := 0.0
	for s in mini(stage, STAGE_WEIGHT.size()):
		acc += STAGE_WEIGHT[s]
	var within := 0.0
	if stage < STAGE_WEIGHT.size() and total > 0 and stage != 0:
		within = clampf(float(done) / float(total), 0.0, 1.0)
	elif stage == 0:
		within = 0.0
	if stage < STAGE_WEIGHT.size():
		acc += STAGE_WEIGHT[stage] * within
	return clampf(acc, 0.0, 1.0)

func _update_ui(fraction: float, stage: int) -> void:
	_fraction = maxf(_fraction, fraction)
	_bar.value = _fraction
	_label.text = STAGE_TEXT[clampi(stage, 0, STAGE_TEXT.size() - 1)]

func _process(_delta: float) -> void:
	if _done or _thread == null:
		return
	if _thread.is_alive():
		var p: Dictionary = _gen.progress()
		_update_ui(overall_fraction(p.stage, p.done, p.total), p.stage)
		return
	_thread.wait_to_finish()
	_done = true
	_update_ui(1.0, 4)
	var entry: Dictionary = _box["entry"]
	get_tree().auto_accept_quit = _prev_auto_quit
	finished.emit(entry)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _thread != null and not _done:
		_thread.wait_to_finish()  # at most the ~4 s of a generation
		_done = true
		get_tree().quit()
