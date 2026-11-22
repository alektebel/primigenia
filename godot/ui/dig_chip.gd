extends Control
## The dig progress ring at the player's feet (first-quest). A54: there is no dig button or prompt on screen any more: X digs anywhere, and
## a one-time hint ("X: dig") is the only prompt. While the dig runs, a hairline ring with a shovel fills in front of the feet (the dig takes
## 2 s on soft soil, 3.5 s on hard ground and 5 s on rock, so the player sees it is working). It fades in over 180 ms (ease-out) and never
## grows from nothing; it takes no clicks.

const Style := preload("res://ui/style.gd")
const Palette := preload("res://ui/palette.gd")
const Glyphs := preload("res://ui/glyphs.gd")

signal pressed                     # kept for the UI's wiring; nothing emits it any more

var digging := 0.0                 # 0..1 progress of the dig in C (the ring fills)
var centre := Vector2.ZERO         # screen position of the ring (the stage projects the player's feet)
var _a := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func radius() -> float:
	return Style.u(22.0)

func hit(_p: Vector2) -> bool:
	return false

func handle_input(_e: InputEvent) -> bool:
	return false

func _process(dt: float) -> void:
	var target := 1.0 if digging > 0.0 else 0.0
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
	Style.circle_outline(self, centre, r, Color(Palette.OCHRE, a * 0.9), Style.u(1.6), Color(Palette.INK, 0.28 * a))
	if digging > 0.0:
		Style.arc(self, centre, r + Style.u(4.0), 0.0, 360.0 * clampf(digging, 0.0, 0.999), Color(Palette.COPPER, a), Style.u(2.4))
	Glyphs.draw(self, "dig", centre, 22.0, Color(Palette.BONE, a))
