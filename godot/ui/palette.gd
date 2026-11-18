extends RefCounted
## HUD colours. The diegetic tokens (docs/godot/UI-DIEGETIC.md section 2) come first; the older panel colours below
## are kept only for the dev tools, the studio and the main menu, which keep their own look.

# Diegetic UI tokens.
const BONE := Color("F4EDE0")      # every neutral mark
const FOG := Color("C9D3D4")       # secondary text, disabled marks
const INK := Color("0E1715")       # the halo behind marks, never a panel
const LICHEN := Color("86D9B0")    # social: befriend, trust
const EMBER_HOT := Color("F0704A") # aggressive: attack, hostile, low health
const OCHRE := Color("EBCB7A")     # observe, hunger, eating
const DUSK := Color("CDBDF2")      # intimidate
const COPPER := Color("E09A5F")    # DNA, progress, the one accent
const MIST := Color("9CC4DD")      # stamina, guard, dodge

## Mode -> colour and the line style of its ring (section 4).
const MODE_COLORS := {&"befriend": LICHEN, &"attack": EMBER_HOT, &"observe": OCHRE, &"intimidate": DUSK, &"eat": OCHRE}
const MODE_STYLES := {&"befriend": &"smooth", &"attack": &"teeth", &"observe": &"dots", &"intimidate": &"double", &"eat": &"smooth"}
## Role -> outline shape (section 7.14); the role colours below are for the journal only.
const ROLE_SHAPES := {"basic": &"circle", "engage": &"triangle", "poke": &"diamond", "control": &"square", "defence": &"dome", "signature": &"hexagon"}

# Legacy tokens (web/stage/stage.css palette).
const PANEL := Color("13241edb")
const PANEL_SOLID := Color("17281f")
const PANEL_HOVER := Color("344c35")
const PANEL_ACTIVE := Color("566745")
const BORDER := Color("d2dcbd3a")
const BORDER_BTN := Color("e5e3bd44")
const TEXT := Color("f4ecd9")
const MUTED := Color("d7d3ae")
const GOLD := Color("ffdb86")
const LEAF := Color("a8c56a")
const EMBER := Color("e5bc6f")
const DANGER := Color("e38b6a")
const GUARD := Color("8fb8d8")
const SHADOW := Color("14201880")
const BACKDROP := Color("101a15d9")

## Move roles (docs/COMBAT-MOVES.md): the colour of a move's slot in the hotbar and the loadout panel.
const ROLE_COLORS := {
	"basic": Color("a8c56a"),
	"engage": Color("e38b6a"),
	"poke": Color("e5c04f"),
	"control": Color("b79ae0"),
	"defence": Color("8fb8d8"),
	"signature": Color("ff7aa6"),
}

static func role_color(role: String) -> Color:
	return ROLE_COLORS.get(role, BORDER_BTN)

static func box(bg: Color = PANEL, radius: int = 14, border: Color = BORDER, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = border
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = SHADOW
	s.shadow_size = 6
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_font_size("font_size", "Label", 15)
	for cls in ["Button", "CheckBox"]:
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, GOLD)
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_focus_color", cls, GOLD)
	t.set_stylebox("normal", "Button", box(PANEL_SOLID, 12, BORDER_BTN, 8))
	t.set_stylebox("hover", "Button", box(PANEL_HOVER, 12, EMBER, 8))
	t.set_stylebox("pressed", "Button", box(PANEL_ACTIVE, 12, GOLD, 8))
	t.set_stylebox("disabled", "Button", box(PANEL_SOLID.darkened(0.2), 12, BORDER, 8))
	var focus := box(Color(0, 0, 0, 0), 12, GOLD, 8)
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("ffffff18")
	track.set_corner_radius_all(6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = EMBER
	fill.set_corner_radius_all(6)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return t

static func bar(color: Color, height: int = 9) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0
	b.max_value = 100
	b.value = 100
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("ffffff22")
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(8)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

## Theme of the diegetic UI: the Alegreya fonts and bone text, no style boxes at all.
static func make_diegetic_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://ui/fonts/AlegreyaSans-Regular.ttf")
	t.default_font_size = 16
	t.set_color("font_color", "Label", BONE)
	t.set_color("font_outline_color", "Label", Color(INK, 0.55))
	t.set_constant("outline_size", "Label", 4)
	return t
