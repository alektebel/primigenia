extends Control
## Clock-style cooldown overlay for a hotbar slot: the part of the slot still recharging is shaded,
## sweeping away clockwise from the top as the move comes back. frac 1 = just used, 0 = ready.

var frac := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_frac(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if is_equal_approx(f, frac):
		return
	frac = f
	visible = frac > 0.0
	queue_redraw()

func _draw() -> void:
	if frac <= 0.0:
		return
	var c := size * 0.5
	var r := size.length()
	var a0 := -PI * 0.5 + TAU * (1.0 - frac)     # the shaded wedge is what is left to wait: it shrinks clockwise
	var pts := PackedVector2Array([c])
	var steps := maxi(int(ceil(frac * 48.0)), 2)
	for i in steps + 1:
		var a := a0 + (TAU * frac) * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(0.04, 0.07, 0.05, 0.72))
