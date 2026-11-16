extends Node3D
## Scripted clip: 0 -> walk -> fast gait -> turn -> stop over 10 s, with a label.
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --path godot --rendering-driver opengl3 \
##     --resolution 640x360 --write-movie /tmp/x.avi --fixed-fps 30 --quit-after 300 \
##     res://locomotion/test/movie.tscn -- plan=biped
## Without --write-movie it plays in a window (fixed 30 fps steps all the same).

const Stage = preload("stage.gd")
const FAST := {"biped": 1.5, "horizontal_biped": 1.8, "light_quadruped": 5.0, "heavy_quadruped": 0.8, "hexapod": 1.0, "wader": 1.5}

var stage
var label: Label
var plan := "biped"
var t := 0.0
var _v_target := 0.0
var _v := 0.0
var _h := 1.0
var _frames := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("plan="):
			plan = a.substr(5)
	stage = Stage.new()
	add_child(stage)
	stage.setup(plan)
	_h = stage.rig.morph.hip_height
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(10, 6)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	layer.add_child(label)

func _v_for(fr: float) -> float:
	return sqrt(fr * 9.81 * _h)

func _process(_delta: float) -> void:
	var dt := 1.0 / 30.0
	t += dt
	# schedule: stand 0.5 s, ramp to walk, hold, ramp to the fast gait, turn, slow, stop
	var fr_fast: float = FAST.get(plan, 1.5)
	var fr := 0.0
	if t < 0.5:
		fr = 0.0
	elif t < 2.0:
		fr = lerpf(0.0, 0.25, (t - 0.5) / 1.5)
	elif t < 4.0:
		fr = 0.25
	elif t < 5.5:
		fr = lerpf(0.25, fr_fast, smoothstep(0.0, 1.0, (t - 4.0) / 1.5))
	elif t < 7.5:
		fr = fr_fast
	elif t < 9.0:
		fr = lerpf(fr_fast, 0.0, smoothstep(0.0, 1.0, (t - 7.5) / 1.5))
	var wr := 0.0
	if t > 6.0 and t < 8.5:
		wr = 0.9
	var v: float = _v_for(fr)
	stage.advance(dt, v, wr)
	var c = stage.ctl
	label.text = "%s   gait %s   Fr %.2f   %.1f m/s   duty %.2f" % [plan, c.gait, c.fr, c._speed_f, c.duty]
