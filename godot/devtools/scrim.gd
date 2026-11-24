extends RefCounted
## Readability of dev HUDs on a bright sky (F10 options, owner-question cards): a dark translucent scrim behind the text and a firmer
## outline on every label. Same look as the F1 sheet otherwise (Alegreya, bone text). Measured in docs/evidence/godot/owner-questions/.

const Palette := preload("res://ui/palette.gd")

const SCRIM_ALPHA := 0.78

## The scrim panel: ink at 78 %, a hairline border, no shadow spill.
static func box(radius := 10, pad := 10) -> StyleBoxFlat:
	var s := Palette.box(Color(Palette.INK, SCRIM_ALPHA), radius, Color(Palette.BONE, 0.14), pad)
	s.shadow_size = 0
	return s

## A label that stays readable on white: ink outline 5 px at 90 %.
static func readable(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(Palette.INK, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l
