extends Control
## Motes (docs/godot/UI-DIEGETIC.md 7.9): a copper point that rises from a place in the world and flies on a curve to a sign
## (DNA, the seed). It replaces the "+3 DNA (carcass)" toast: the source is where the mote came from. 0.7 s, ease in-out.
## With Less motion the mote is replaced by an immediate landing (the sign brightens for 0.3 s).

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")

signal landed(tag: Variant, amount: int)

var motes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func active() -> int:
	return motes.size()

## Fly a mote from screen position `from` to `to`; `tag` and `amount` come back with `landed`.
func fly(from: Vector2, to: Vector2, tag: Variant = null, amount: int = 0, color: Color = Palette.COPPER) -> void:
	if Style.reduced_motion():
		landed.emit(tag, amount)
		return
	var side := 1.0 if from.x < to.x else -1.0
	var mid := (from + to) * 0.5 + Vector2(-(to - from).y, (to - from).x).normalized() * (to - from).length() * 0.25 * side
	motes.append({"from": from, "to": to, "ctrl": mid, "t": 0.0, "tag": tag, "amount": amount, "color": color, "trail": []})
	set_process(true)

static func bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _process(dt: float) -> void:
	for i in range(motes.size() - 1, -1, -1):
		var m: Dictionary = motes[i]
		m.t += dt / Style.MOTE
		var k := Style.ease_in_out(m.t)
		var p := bezier(m.from, m.ctrl, m.to, k)
		m.trail.append(p)
		if m.trail.size() > 6:
			m.trail.pop_front()
		if m.t >= 1.0:
			motes.remove_at(i)
			landed.emit(m.tag, m.amount)
	queue_redraw()

func _draw() -> void:
	for m in motes:
		var col: Color = m.color
		var n: int = m.trail.size()
		for j in n:
			var a := float(j + 1) / (n + 1) * 0.35
			draw_circle(m.trail[j], Style.u(2.4) * (0.4 + 0.6 * float(j) / maxf(n, 1)), Color(col, a))
		if n > 0:
			var p: Vector2 = m.trail[n - 1]
			draw_circle(p, Style.u(9.0), Color(col, 0.18))
			draw_circle(p, Style.u(4.5), Color(col, 0.95))
