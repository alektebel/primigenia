extends RefCounted
## Studio look from web/studio/studio.css + index.html: dark ink, glass cards, warm amber accent.

const INK := Color("10202b")
const GLASS := Color(14 / 255.0, 32 / 255.0, 44 / 255.0, .86)
const PAPER := Color("f2f6f4")
const MUTED := Color("9db3bb")
const LINE := Color(190 / 255.0, 225 / 255.0, 235 / 255.0, .18)
const AMBER := Color("ffc04a")
const MOSS := Color("9fd45c")
const SKY := Color("6fd3ff")
const DANGER := Color("ff7a5c")

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius := 10, bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 6; s.content_margin_bottom = 6
	return s

static func dot(color: Color, d := 16) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := (d - 1) / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x - c, y - c).length()
			img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(c + .5 - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

static func make() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", PAPER)
	t.default_font_size = 14
	for cls in ["Button", "MenuButton", "OptionButton", "CheckButton", "ColorPickerButton"]:
		t.set_stylebox("normal", cls, box(Color(1, 1, 1, .07), LINE))
		t.set_stylebox("hover", cls, box(Color(1, 1, 1, .14), LINE))
		t.set_stylebox("pressed", cls, box(Color(AMBER.r, AMBER.g, AMBER.b, .22), AMBER, 10, 2))
		t.set_stylebox("hover_pressed", cls, box(Color(AMBER.r, AMBER.g, AMBER.b, .3), AMBER, 10, 2))
		t.set_stylebox("disabled", cls, box(Color(1, 1, 1, .03), LINE))
		t.set_stylebox("focus", cls, box(Color(0, 0, 0, 0), PAPER, 10, 2))
		t.set_color("font_color", cls, PAPER)
		t.set_color("font_hover_color", cls, PAPER)
		t.set_color("font_pressed_color", cls, AMBER)
		t.set_color("font_hover_pressed_color", cls, AMBER)
		t.set_color("font_disabled_color", cls, Color(PAPER, .35))
	t.set_stylebox("panel", "PanelContainer", box(GLASS, LINE, 20))
	t.set_stylebox("normal", "LineEdit", box(Color("0b1821"), LINE))
	t.set_stylebox("focus", "LineEdit", box(Color("0b1821"), AMBER, 10, 2))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("caret_color", "LineEdit", AMBER)
	t.set_stylebox("panel", "PopupMenu", box(Color("0b1821"), LINE, 10))
	t.set_stylebox("hover", "PopupMenu", box(Color(AMBER, .2), Color(0, 0, 0, 0), 6))
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", AMBER)
	var track := box(Color(1, 1, 1, .12), Color(0, 0, 0, 0), 4)
	track.content_margin_top = 3; track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(AMBER, Color(0, 0, 0, 0), 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AMBER.lightened(.2), Color(0, 0, 0, 0), 4))
	t.set_icon("grabber", "HSlider", dot(AMBER, 18))
	t.set_icon("grabber_highlight", "HSlider", dot(PAPER, 18))
	t.set_icon("grabber_disabled", "HSlider", dot(MUTED, 18))
	t.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, .05), Color(0, 0, 0, 0), 4))
	t.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, .3), Color(0, 0, 0, 0), 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(AMBER, Color(0, 0, 0, 0), 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(AMBER, Color(0, 0, 0, 0), 4))
	t.set_stylebox("panel", "TooltipPanel", box(Color("0b1821"), AMBER, 8))
	return t
