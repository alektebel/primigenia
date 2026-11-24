extends CanvasLayer
## D7 time control: pause (P), step one tick (. while paused), slower / faster ([ and ], ladder below).
## Presentation only: it sets StageWorld.timescale / paused and steps through StageWorld.step_ticks, so the
## simulation, its log and its hashes do not know about it. HUD chip top-right while not at x1.

const Palette := preload("res://ui/palette.gd")
const LADDER := [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 100.0]

var stage = null            # StageWorld
var chip: Label
var _idx := 3

func _init() -> void:
	layer = 21

func _ready() -> void:
	chip = Label.new()
	chip.add_theme_color_override("font_color", Palette.GOLD)
	chip.add_theme_stylebox_override("normal", Palette.box(Color(Palette.PANEL, 0.85), 10, Palette.BORDER, 5))
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -14
	chip.offset_top = 10
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.visible = false
	add_child(chip)

func bind(s) -> void:
	stage = s
	_idx = _nearest(s.timescale) if s != null else 3

static func _nearest(v: float) -> int:
	var best := 0
	for i in LADDER.size():
		if absf(LADDER[i] - v) < absf(LADDER[best] - v):
			best = i
	return best

func set_timescale(v: float) -> void:
	if stage == null:
		return
	_idx = _nearest(v)
	stage.timescale = LADDER[_idx]

func faster() -> void:
	set_timescale(LADDER[mini(_idx + 1, LADDER.size() - 1)])

func slower() -> void:
	set_timescale(LADDER[maxi(_idx - 1, 0)])

func toggle_pause() -> void:
	if stage != null:
		stage.paused = not stage.paused

func step_one() -> void:
	if stage != null and stage.paused:
		stage.step_ticks(1)

func text() -> String:
	if stage == null:
		return ""
	if stage.paused:
		return "PAUSED · tick %d" % int(stage.cur.tick)
	if absf(stage.timescale - 1.0) > 1e-6:
		var t := "x%s" % [String.num(stage.timescale, 2).trim_suffix("0").trim_suffix(".") if "." in String.num(stage.timescale, 2) else String.num(stage.timescale, 0)]
		if stage.achieved_scale > 0.0 and stage.achieved_scale < stage.timescale * 0.95:
			t += " (x%d achieved)" % int(round(stage.achieved_scale))
		return t
	return ""

func _process(_dt: float) -> void:
	var s = Game.stage
	if s != stage:
		bind(s)
	var txt := text()
	chip.visible = txt != ""
	chip.text = " " + txt + " "

func _unhandled_input(e: InputEvent) -> void:
	if stage == null or Game.console_open or Game.options_open or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.is_action_pressed("time_pause"):
		toggle_pause()
	elif e.is_action_pressed("time_step"):
		step_one()
	elif e.is_action_pressed("time_faster"):
		faster()
	elif e.is_action_pressed("time_slower"):
		slower()
	else:
		return
	get_viewport().set_input_as_handled()
