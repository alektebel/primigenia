extends Control
## The verb bar (docs/briefs/verb-target.md): pick WHAT to do first, then the creature. Five hairline circles in a column on the
## left edge, each a glyph with its key cap: Attack (F), Befriend (B), Eat (N), Observe (O), Intimidate (I). One verb is armed at
## a time; pressing its key again or the bar's circle keeps it armed (Esc or a right click cancels, the stage does that).
## Not modal: a click outside a circle is a normal world click. Fades 180 ms ease-out, never from scale 0; keys animate nothing.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")
const Modes := preload("res://ui/modes.gd")

signal verb_chosen(mode: StringName)

## mode, glyph, key cap, input action.
const SLOTS := [
	{"mode": Modes.ATTACK, "glyph": "attack", "key": "F", "action": "verb_attack"},
	{"mode": Modes.BEFRIEND, "glyph": "befriend", "key": "B", "action": "verb_befriend"},
	{"mode": Modes.EAT, "glyph": "eat", "key": "N", "action": "verb_eat"},
	{"mode": Modes.OBSERVE, "glyph": "observe", "key": "O", "action": "verb_observe"},
	{"mode": Modes.INTIMIDATE, "glyph": "intimidate", "key": "I", "action": "verb_intimidate"},
]

var armed: StringName = Modes.NONE
var hover := -1
var _arm_a := PackedFloat32Array([0, 0, 0, 0, 0])      # per slot 0..1: how armed it looks
var _press := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func radius() -> float:
	return Style.u(22.0)

func gap() -> float:
	return Style.u(14.0)

## Screen centre of slot i: a column on the left edge, vertically centred a little low, clear of the player's ring, the hotbar
## petals around a target, the task card (top left) and the minimap (top right).
func slot_pos(i: int) -> Vector2:
	var step := radius() * 2.0 + gap()
	var h := step * float(SLOTS.size() - 1)
	return Vector2(Style.u(44.0), size.y * 0.56 - h * 0.5 + step * i)

func slot_at(p: Vector2) -> int:
	for i in SLOTS.size():
		if p.distance_to(slot_pos(i)) <= radius() + Style.u(4.0):
			return i
	return -1

func index_of(mode: StringName) -> int:
	for i in SLOTS.size():
		if SLOTS[i].mode == mode:
			return i
	return -1

func arm(mode: StringName) -> void:
	armed = mode
	queue_redraw()

func choose(i: int) -> void:
	if i < 0 or i >= SLOTS.size():
		return
	verb_chosen.emit(SLOTS[i].mode)

## Mouse: hover and press on a circle. Returns true when the bar used the event.
func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		var h := slot_at(e.position)
		if h != hover:
			hover = h
			queue_redraw()
		return false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var s := slot_at(e.position)
		if e.pressed and s >= 0:
			_press = s
			choose(s)
			return true
		if not e.pressed and _press >= 0:
			_press = -1
			queue_redraw()
			return true
	return false

func _process(dt: float) -> void:
	var changed := false
	for i in SLOTS.size():
		var want := 1.0 if SLOTS[i].mode == armed else 0.0
		var a := Style.approach(_arm_a[i], want, dt, 0.18)
		if a != _arm_a[i]:
			_arm_a[i] = a
			changed = true
	if changed or _press >= 0:
		queue_redraw()

func _draw() -> void:
	for i in SLOTS.size():
		var slot: Dictionary = SLOTS[i]
		var mode: StringName = slot.mode
		var col: Color = Palette.EMBER_HOT if mode == Modes.ATTACK else (Palette.LICHEN if mode == Modes.BEFRIEND else Palette.MODE_COLORS[mode])
		var c := slot_pos(i)
		var k := Style.ease_out(_arm_a[i])
		var r := radius() * (0.97 if _press == i else 1.0)         # the press scale of 0.97
		var base := Color(Palette.BONE, 0.55 if hover == i else 0.34)
		Style.circle_outline(self, c, r, base.lerp(Color(col, 0.95), k), Style.u(1.6) + Style.u(1.2) * k, Color(col, 0.22 * k) if k > 0.0 else Color(Palette.INK, 0.28))
		Glyphs.draw(self, String(slot.glyph), c, 22.0, Color(Palette.BONE, 0.95).lerp(col, k))
		var kw := Style.key_cap(self, String(slot.key), c + Vector2(r + Style.u(14.0), Style.u(4.5)), Style.u(12.0), Color(Palette.FOG, 0.85))
		if hover == i or armed == mode:
			var s := Strings.t(String(mode))
			var f := Style.font_sans(true)
			Style.text(self, f, c + Vector2(r + Style.u(14.0) + kw * 0.5 + Style.u(8.0), Style.u(5.0)), s, Style.u(15.0), Color(Palette.BONE, 0.95))
