extends Control
## "E: Edit creature" at the nest (docs/briefs/verb-target.md, part 3). Shown while the player is inside the nest radius and not
## fighting; a second line in copper names the parts found since the last edit ("New: wing vane"). Fades 180 ms ease-out, no
## scale animation. E (or a click on the text) opens the nest editor through the stage.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")

signal pressed

var want := false                    # at the nest and free to edit
var new_parts: Array = []            # display names found since the last edit
var _a := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func shown() -> bool:
	return _a > 0.5

## Bottom left, above the health and stamina lines: clear of the player's own ring and of the verb bar column.
func centre() -> Vector2:
	return Vector2(Style.u(34.0) + Style.u(70.0), size.y - Style.u(104.0))

func hit(p: Vector2) -> bool:
	var c := centre()
	return _a > 0.5 and absf(p.x - c.x) < Style.u(90.0) and absf(p.y - c.y) < Style.u(24.0)

func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hit(e.position):
		pressed.emit()
		return true
	return false

func line() -> String:
	return Strings.t("nest_edit_prompt")

func extra() -> String:
	return "" if new_parts.is_empty() else Strings.t("nest_new_parts", [", ".join(new_parts)])

func _process(dt: float) -> void:
	var a := Style.approach(_a, 1.0 if want else 0.0, dt, 0.18)
	if a != _a:
		_a = a
		queue_redraw()
	visible = _a > 0.01

func _draw() -> void:
	if _a <= 0.01:
		return
	var k := Style.ease_out(_a)
	var f := Style.font_sans(true)
	var s := line()
	var sz := Style.u(19.0)
	var c := centre()
	Style.text(self, f, c + Vector2(-Style.text_width(f, s, sz) * 0.5, 0), s, sz, Color(Palette.BONE, k))
	var x := extra()
	if x != "":
		var sz2 := Style.u(15.0)
		Style.text(self, f, c + Vector2(-Style.text_width(f, x, sz2) * 0.5, Style.u(21.0)), x, sz2, Color(Palette.COPPER, k))
