extends Control
# Main menu: Play (the island stage), Creator (the studio), Quit. The sky gradient and the title copy
# are the loading screen's; the creature name shows which genome Play will use.

const Palette := preload("res://ui/palette.gd")

var play_button: Button
var creator_button: Button
var quit_button: Button
var genome_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Palette.make_theme()
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
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 18, Palette.BORDER, 26))
	centre.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(360, 0)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Primigenia"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tag := Label.new()
	tag.text = "Seeds from the dark between stars are taking root."
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Palette.MUTED)
	v.add_child(tag)
	play_button = _button("Play", func() -> void: Game.goto_island())
	v.add_child(play_button)
	genome_label = Label.new()
	genome_label.add_theme_color_override("font_color", Palette.MUTED)
	genome_label.add_theme_font_size_override("font_size", 13)
	genome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	genome_label.text = "Your creature: %s" % str(Game.player_genome().get("name", "Merodeador"))
	v.add_child(genome_label)
	creator_button = _button("Creator", func() -> void: Game.goto_studio())
	v.add_child(creator_button)
	quit_button = _button("Quit", func() -> void: get_tree().quit())
	v.add_child(quit_button)
	play_button.grab_focus()

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b
