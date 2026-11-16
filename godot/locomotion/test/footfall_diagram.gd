extends Node2D
## Hildebrand-style footfall diagram: one row per foot, a bar while it is on
## the ground, over two strides. Panels: [{title, labels:[..], rows:[[ [a,b],.. ],..], note}]

var panels: Array = []
var title := ""
const W := 380.0
const ROW := 20.0

func size() -> Vector2i:
	var rows := 0
	for p in panels:
		rows = max(rows, p.labels.size())
	return Vector2i(int(30 + panels.size() * (W + 30)), int(92 + rows * ROW + 30))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var sz := size()
	draw_rect(Rect2(Vector2.ZERO, Vector2(sz)), Color(0.98, 0.98, 0.96))
	draw_string(font, Vector2(20, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.1, 0.1, 0.1))
	for k in range(panels.size()):
		var p: Dictionary = panels[k]
		var x0 := 60.0 + k * (W + 30)
		var y0 := 78.0
		draw_string(font, Vector2(x0, 50), p.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))
		draw_string(font, Vector2(x0, 68), p.note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.35, 0.35, 0.35))
		var bw := W - 60.0
		for i in range(p.labels.size()):
			var y := y0 + i * ROW
			draw_string(font, Vector2(x0 - 34, y + 13), p.labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.2, 0.2))
			draw_rect(Rect2(x0, y + 2, bw, ROW - 5), Color(0.9, 0.9, 0.88))
			for seg in p.rows[i]:
				var a: float = clamp(seg[0] / 2.0, 0.0, 1.0)
				var b: float = clamp(seg[1] / 2.0, 0.0, 1.0)
				if b > a:
					draw_rect(Rect2(x0 + a * bw, y + 2, (b - a) * bw, ROW - 5), Color(0.15, 0.17, 0.2))
		var yb: float = y0 + p.labels.size() * ROW
		for t in range(9):
			var x := x0 + bw * t / 8.0
			draw_line(Vector2(x, y0), Vector2(x, yb + 3), Color(0, 0, 0, 0.18 if t % 4 else 0.5), 1.0)
			if t % 2 == 0:
				draw_string(font, Vector2(x - 8, yb + 16), "%.1f" % (t / 4.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
		draw_string(font, Vector2(x0 + bw + 4, yb + 16), "strides", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
