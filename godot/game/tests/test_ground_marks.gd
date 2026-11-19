extends RefCounted
# Ground marks (docs/godot/PLAN-ui-diegetic.md S1): the patch lies on the visual ground, the move marker's life cycle.

const TerrainData := preload("res://game/island/terrain_data.gd")
const GroundMark := preload("res://game/island/ground_mark.gd")
const GroundMarks := preload("res://game/island/ground_marks.gd")

func run(t) -> void:
	var params: Dictionary = CporeTerrain.defaults()
	params.n = 128
	params.seed = 3
	var entry: Dictionary = CporeTerrain.new().generate(params)
	TerrainData.prepare(entry)
	var game = t.root.get_node("Game")
	var old = game.data
	game.set_island(entry)
	# the patch follows Game.ground at its 289 vertices, on flat ground and on a slope
	var worst := 0.0
	var worst_slope := 0.0
	var steepest := 0.0
	var steep_at := Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for s in 200:
		var x := rng.randf_range(-1500.0, 1500.0)
		var z := rng.randf_range(-1500.0, 1500.0)
		var n: Vector3 = game.data.normal(x, z)
		var slope := 1.0 - n.y
		if slope > steepest:
			steepest = slope
			steep_at = Vector3(x, 0, z)
	var spots := [Vector3(0, 0, 0), steep_at]
	for pos in spots:
		var m = GroundMark.new()
		m.place(pos, 1.5)
		for j in GroundMark.N:
			for i in GroundMark.N:
				var w: Vector3 = m.vertex_world(i, j)
				var err := absf(w.y - GroundMark.visual_ground(w.x, w.z))
				worst = maxf(worst, err)
		m.free()
	t.check(worst < 0.01, "the 289 patch heights equal the visual ground (terrain, or the water surface) within 1 cm (worst %.4f m)" % worst)
	t.check(steepest > 0.03, "one of the patches lies on a real slope (1 - n.y = %.3f)" % steepest)
	# re-sampling only when it moved
	var mk = GroundMark.new()
	mk.place(Vector3(10, 0, 10), 1.0)
	var sampled_a: Variant = mk._sampled
	mk.place(Vector3(10.02, 0, 10.0), 1.0)
	t.check(mk._sampled == sampled_a, "a move under 5 cm does not re-sample")
	mk.place(Vector3(10.2, 0, 10.0), 1.0)
	t.check(mk._sampled != sampled_a, "a larger move re-samples")
	mk.free()
	# the move marker's life: appears, follow replaces it, arrival fades it within 0.4 s
	var gm = GroundMarks.new()
	gm._ready()
	gm.move_marker(Vector3(5, 0, 5))
	t.check(gm.move_visible() and not gm.follow_visible(), "a click shows the solid marker only")
	gm.follow_marker(Vector3(8, 0, 5))
	t.check(gm.follow_visible() and not gm.move_visible(), "following shows the soft marker and never both")
	gm.follow_release()
	t.check(gm.move_visible() and not gm.follow_visible(), "releasing the hold makes the solid marker")
	gm.clear_move(true)
	for k in 5:
		gm.move_mark._process(0.1)
	t.check(not gm.move_mark.visible and gm.move_mark.alpha < 0.01, "arrival fades the marker within 0.4 s")
	gm.move_blocked(Vector3(7, 0, 7))
	t.check(gm._blocked_mark.is_shown() and not gm.move_visible(), "a blocked click shows the cut ring")
	gm.free()
	game.data = old
