extends Control
## The dig entry on the player's own ground ring (first-quest). Where the mode ring opens around a creature, this small hairline ring
## with a shovel and its key cap sits just in front of your feet whenever the ground under you is soft and nothing else asks for
## your attention. A click on it (or X) digs. It fades in over 180 ms (ease-out) and never grows from nothing.

const Style := preload("res://ui/style.gd")
const Palette := preload("res://ui/palette.gd")
const Glyphs := preload("res://ui/glyphs.gd")

signal pressed

var want := false                  # the world says: soft soil here, free to dig
var digging := 0.0                 # 0..1 progress of the dig in C (the ring fills)
var centre := Vector2.ZERO         # screen position of the chip (the stage projects the player's feet)
var _a := 0.0
var _hover := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func radius() -> float:
	return Style.u(22.0)

func hit(p: Vector2) -> bool:
	return _a > 0.5 and p.distance_to(centre) <= radius() + Style.u(6.0)

func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		var h := hit(e.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		return false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hit(e.position):
		pressed.emit()
		return true
	return false

func _process(dt: float) -> void:
	var target := 1.0 if (want or digging > 0.0) else 0.0
	var a := Style.approach(_a, target, dt, 0.18)
	if a != _a or digging > 0.0:
		_a = a
		queue_redraw()
	visible = _a > 0.01

func _draw() -> void:
	if _a <= 0.01:
		return
	var a := Style.ease_out(_a)
	var r := radius()
	var col := Color(Palette.OCHRE if not _hover else Palette.BONE, a * 0.9)
	Style.circle_outline(self, centre, r, col, Style.u(1.6), Color(Palette.INK, 0.28 * a))
	if digging > 0.0:
		Style.arc(self, centre, r + Style.u(4.0), 0.0, 360.0 * clampf(digging, 0.0, 0.999), Color(Palette.COPPER, a), Style.u(2.4))
	Glyphs.draw(self, "dig", centre, 22.0, Color(Palette.BONE, a))
	Style.key_cap(self, "X", centre + Vector2(0, r + Style.u(16.0)), Style.u(13.0), Color(Palette.FOG, a * 0.9))
