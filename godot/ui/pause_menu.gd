extends Control
## Pause menu: master / music / sfx / ambience volume, mute, resume.
## bind_audio(audio_manager) wires the sliders to the audio system (which persists them).

const Palette := preload("res://ui/palette.gd")

signal resume_requested
signal menu_requested
signal setting_changed(bus: String, value)

const ROWS := [["master", "Master"], ["music", "Music"], ["sfx", "Sound effects"], ["ambience", "Ambience"]]
var sliders: Dictionary = {}
var mute_box: Button
var audio

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var back := ColorRect.new()
	back.color = Palette.BACKDROP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 18, Palette.BORDER, 22))
	centre.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(380, 0)
	panel.add_child(v)
	var title := Label.new()
	title.text = "The valley can wait."
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Audio"
	sub.add_theme_color_override("font_color", Palette.GOLD)
	v.add_child(sub)
	for r in ROWS:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = r[1]
		l.custom_minimum_size = Vector2(130, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(0, 28)
		s.value = _val(r[0])
		var bus: String = r[0]
		s.value_changed.connect(func(val: float) -> void: _put(bus, val))
		h.add_child(s)
		v.add_child(h)
		sliders[bus] = s
	mute_box = Button.new()
	mute_box.toggle_mode = true
	mute_box.custom_minimum_size = Vector2(0, 40)
	mute_box.text = "Mute all audio: off"
	mute_box.button_pressed = bool(_val("mute"))
	mute_box.toggled.connect(func(on: bool) -> void:
		mute_box.text = "Mute all audio: " + ("on" if on else "off")
		_put("mute", on))
	v.add_child(mute_box)
	var b := Button.new()
	b.text = "Return to the valley"
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func() -> void: resume_requested.emit())
	v.add_child(b)
	var m := Button.new()
	m.text = "Back to the main menu"
	m.custom_minimum_size = Vector2(0, 40)
	m.pressed.connect(func() -> void: menu_requested.emit())
	v.add_child(m)

func bind_audio(a) -> void:
	audio = a
	refresh()

func refresh() -> void:
	for bus in sliders:
		sliders[bus].set_value_no_signal(_val(bus))
	if mute_box:
		mute_box.set_pressed_no_signal(bool(_val("mute")))
		mute_box.text = "Mute all audio: " + ("on" if mute_box.button_pressed else "off")

func _val(key: String):
	if audio:
		return audio.is_muted() if key == "mute" else audio.get_volume(key)
	return false if key == "mute" else 0.5

func _put(key: String, v) -> void:
	if audio:
		audio.set_volume(key, v)
	setting_changed.emit(key, v)
