extends CanvasLayer
## Metadata overlay (F11): a small live panel with what a note would record (mode, tick, seed, build, player, gait, creature, quest,
## camera, fps and p95, renderer, F10 choices, the creatures near you), plus a line under the cursor for the entity it points at.
## Presentation only: it reads the game, never writes it. Refreshes 4 times a second; never animates (a key toggles it).

const Palette := preload("res://ui/palette.gd")
const Scrim := preload("res://devtools/scrim.gd")
const Meta := preload("res://devtools/notes/note_meta.gd")

const REFRESH := 0.25
const HOVER_REFRESH := 0.05

var is_on := false
var last_meta: Dictionary = {}
var hover_text := ""
var hover_provider: Callable = Callable()    # (screen) -> pick dictionary; tests, else Dev.flag.pick_at
var _panel: PanelContainer
var _label: Label
var _hover: Label
var _t := 0.0
var _ht := 0.0

func _init() -> void:
	layer = 30

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", Scrim.box(8, 8))
	_panel.position = Vector2(14, 190)    # under the quest card (top left)
	_panel.visible = false
	root.add_child(_panel)
	_label = Scrim.readable(Label.new())
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Palette.BONE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_hover = Scrim.readable(Label.new())
	_hover.add_theme_font_size_override("font_size", 14)
	_hover.add_theme_color_override("font_color", Palette.GOLD)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.visible = false
	root.add_child(_hover)
	set_process(false)

func set_on(on: bool) -> void:
	is_on = on
	if on:
		Meta.git_info()           # the first call asks git once; later calls are cached
		refresh()
	elif _panel != null:
		_panel.visible = false
		_hover.visible = false
	hover_text = "" if not on else hover_text
	set_process(on)

func toggle() -> void:
	set_on(not is_on)

func refresh() -> void:
	last_meta = Meta.collect(get_tree() if is_inside_tree() else null, false)
	if _label != null:
		_label.text = "\n".join(Meta.lines(last_meta))
		_panel.visible = true
		_panel.reset_size()

## The line for the entity under the cursor: "creature Zanco #3  12.4 m  idle  timid  hp 70/70" (plants, props, terrain: kind and name).
static func hover_line(pick: Dictionary, entities: Array, names: Dictionary, px: float, pz: float) -> String:
	if pick.is_empty():
		return ""
	if str(pick.kind) == "creature" and int(pick.id) >= 0 and int(pick.id) < entities.size():
		var rows := Meta.nearby([entities[int(pick.id)]], names, px, pz, 1, 1e9) if int(pick.id) != 0 else []
		if rows.is_empty():
			return "creature %s (you)" % str(pick.name) if int(pick.id) == 0 else "creature %s" % str(pick.name)
		var r: Dictionary = rows[0]
		return "creature %s #%d  %s m  %s  %s  hp %s/%s" % [r.species, int(r.id), String.num(r.dist, 1), r.state,
			r.temperament if r.temperament != "" else "-", String.num(r.hp, 0), String.num(r.hp_max, 0)]
	return "%s %s" % [str(pick.kind), str(pick.name)]

func _pick(m: Vector2) -> Dictionary:
	if hover_provider.is_valid():
		return hover_provider.call(m)
	return Dev.flag.pick_at(m) if Dev.flag != null and is_inside_tree() else {}

func _process(dt: float) -> void:
	if not is_on:
		return
	_t += dt
	_ht += dt
	if _t >= REFRESH:
		_t = 0.0
		refresh()
	if _ht >= HOVER_REFRESH:
		_ht = 0.0
		var blocked: bool = (Dev.note_card != null and (Dev.note_card.is_open or Dev.note_card.pinning)) or (Dev.browser != null and Dev.browser.is_open) or Game.console_open
		var st = Game.stage
		var m := get_viewport().get_mouse_position()
		hover_text = ""
		if not blocked and st != null and not st.cur.is_empty() and not st.cur.entities.is_empty():
			var p: Dictionary = st.cur.entities[0]
			hover_text = hover_line(_pick(m), st.cur.entities, Meta.species_names(), float(p.x), float(p.z))
		_hover.visible = hover_text != ""
		_hover.text = hover_text
		_hover.position = m + Vector2(16, 22)

func _input(e: InputEvent) -> void:
	if not Dev.enabled or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.is_action_pressed("dev_meta") and not Game.console_open and not _typing():
		toggle()
		get_viewport().set_input_as_handled()

func _typing() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and (f is LineEdit or f is TextEdit)
