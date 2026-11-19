extends Control
## Small screen-space marks that belong to the target's ground ring (docs/godot/UI-DIEGETIC.md 7.5): the pearls of a
## rhythm combo, one bone dot (3.2 u) per step up to 5 on the ring at the creature's front-left; they fall off when the
## rhythm is lost. Anchored to the world points GroundMarks computes, so they sit on the ring from any camera angle.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")

var camera: Camera3D
var ground_marks
var _fall := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if camera == null or ground_marks == null or ground_marks.pearls <= 0:
		return
	for p in ground_marks.pearl_points():
		if camera.is_position_behind(p):
			continue
		var s: Vector2 = camera.unproject_position(p)
		draw_circle(s, Style.u(3.2) + 1.6, Color(Palette.INK, 0.55))
		draw_circle(s, Style.u(3.2), Palette.BONE)
