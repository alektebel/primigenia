extends Control
## Rings drawn around the selected creature: the beat pulse (hit the skill when the shrinking ring meets the solid
## one, docs/P4.md 2.1 "beat ring"), the observe progress arc and the trust arc. Pure drawing; the HUD feeds it.

const Palette := preload("res://ui/palette.gd")
const BEAT_TICKS := 12
const WINDOW := 2          # ticks either side of the beat that count as "in rhythm"

var centre := Vector2.ZERO
var show_beat := false
var beat_in := 0           # ticks until the creature's next beat (0 = on it now)
var observe := -1.0        # 0..1 while observing, negative = off
var trust := -1.0          # 0..1, negative = off
var carcass := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## True while the beat is inside the rhythm window (the ring is green).
static func in_window(ticks_to_beat: int) -> bool:
	return ticks_to_beat <= WINDOW or ticks_to_beat >= BEAT_TICKS - WINDOW

func set_state(c: Vector2, beat: bool, b_in: int, obs: float, tr: float) -> void:
	centre = c
	show_beat = beat
	beat_in = b_in
	observe = obs
	trust = tr
	queue_redraw()

func _draw() -> void:
	if centre == Vector2.ZERO:
		return
	if show_beat:
		var p := float(beat_in) / BEAT_TICKS                # 1 = just after a beat, 0 = on the beat
		var r := lerpf(26.0, 62.0, p)
		var good := in_window(beat_in)
		var col: Color = Palette.LEAF if good else Palette.GOLD
		draw_arc(centre, 26.0, 0.0, TAU, 40, Color(col, 0.9), 2.5, true)
		draw_arc(centre, r, 0.0, TAU, 48, Color(col, 0.55 if not good else 0.95), 2.0, true)
		if good:
			draw_circle(centre, 24.0, Color(Palette.LEAF, 0.18))
	if observe >= 0.0:
		draw_arc(centre, 40.0, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 5.0, true)
		draw_arc(centre, 40.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(observe, 0.0, 1.0), 48, Palette.GOLD, 5.0, true)
	if trust >= 0.0 and not carcass:
		draw_arc(centre, 72.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(trust, 0.0, 1.0), 48, Color(Palette.LEAF, 0.85), 3.0, true)
