extends CanvasLayer
## D1 console UI: opens with the dev_console action (the key left of 1, or F12), Esc closes. Enter runs a line
## through registry.execute, Tab completes, Up/Down walk the history. While open it owns the keyboard
## (Game.console_open: movement and the other dev keys are blocked).

const Palette := preload("res://ui/palette.gd")
const Registry := preload("res://devtools/console/registry.gd")
const Commands := preload("res://devtools/console/commands_creature.gd")

var registry
var panel: PanelContainer
var log_view: RichTextLabel
var input: LineEdit
var is_open := false
var _hist := -1
var _draft := ""

func _init() -> void:
	layer = 30

func _ready() -> void:
	registry = Registry.new()
	registry.stage_provider = func(): return Game.stage
	registry.dev_enabled = Dev.enabled
	Commands.register_all(registry)
	registry.load_history()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Color(Palette.PANEL_SOLID, 0.94), 0, Palette.BORDER, 8))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.anchor_bottom = 0.42
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	var box := VBoxContainer.new()
	panel.add_child(box)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.add_theme_color_override("default_color", Palette.TEXT)
	log_view.add_theme_font_size_override("normal_font_size", 14)
	log_view.selection_enabled = true
	box.add_child(log_view)
	input = LineEdit.new()
	input.placeholder_text = "command (help lists them)"
	input.caret_blink = true
	input.text_submitted.connect(submit)
	box.add_child(input)
	add_child(panel)

func open() -> void:
	if is_open:
		return
	is_open = true
	panel.visible = true
	Game.console_open = true
	_hist = -1
	input.text = ""
	input.grab_focus()
	if log_view.get_parsed_text() == "":
		print_line("[color=#a8c56a]Dev console.[/color] help lists the commands; Tab completes; Esc closes.")

func close() -> void:
	if not is_open:
		return
	is_open = false
	panel.visible = false
	Game.console_open = false
	input.release_focus()
	registry.save_history()

func toggle() -> void:
	close() if is_open else open()

func print_line(bbcode: String) -> void:
	log_view.append_text(bbcode + "\n")

func submit(text: String) -> void:
	input.text = ""
	_hist = -1
	if text.strip_edges() == "":
		return
	print_line("[color=#e5bc6f]> %s[/color]" % text.replace("[", "[lb]"))
	var res: Dictionary = registry.execute(text)
	if res.get("clear", false):
		log_view.clear()
	elif res.ok:
		if str(res.out) != "":
			print_line(str(res.out).replace("[", "[lb]"))
	else:
		print_line("[color=#e38b6a]%s[/color]" % str(res.error).replace("[", "[lb]"))

func _complete() -> void:
	var cands: Array = registry.complete(input.text)
	if cands.is_empty():
		return
	var tok := Registry.tokenize(input.text)
	var head := input.text.substr(0, input.text.length() - (tok[tok.size() - 1].length() if tok.size() > 0 and not input.text.ends_with(" ") else 0))
	if cands.size() == 1:
		input.text = head + str(cands[0]) + " "
	else:
		var common: String = str(cands[0])
		for c in cands:
			while not str(c).to_lower().begins_with(common.to_lower()):
				common = common.left(common.length() - 1)
		input.text = head + common
		print_line("[color=#d7d3ae]%s[/color]" % "  ".join(PackedStringArray(cands.map(func(c): return str(c)))))
	input.caret_column = input.text.length()

func _history(dir: int) -> void:
	var h: PackedStringArray = registry.history
	if h.is_empty():
		return
	if _hist == -1:
		_draft = input.text
		_hist = h.size()
	_hist = clampi(_hist + dir, 0, h.size())
	input.text = _draft if _hist == h.size() else h[_hist]
	input.caret_column = input.text.length()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.is_action_pressed("dev_console") and Dev.enabled:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if e.keycode == KEY_ESCAPE:
		close()
	elif e.keycode == KEY_TAB:
		_complete()
	elif e.keycode == KEY_UP:
		_history(-1)
	elif e.keycode == KEY_DOWN:
		_history(1)
	else:
		return
	get_viewport().set_input_as_handled()
