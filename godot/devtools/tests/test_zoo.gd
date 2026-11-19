extends RefCounted
# The locomotion zoo (devtools/zoo): genomes load, the courses run, the runs are deterministic, bigger bodies turn wider.

const Genomes := preload("res://devtools/zoo/zoo_genomes.gd")
const Course := preload("res://devtools/zoo/zoo_course.gd")
const Zoo := preload("res://devtools/zoo/zoo.gd")

func _zoo(ids: Array, course: String, parent: Node):
	var z = Zoo.new()
	z.with_visuals = false
	z.auto_build = false
	z.morph_ids = ids
	z.course_name = course
	parent.add_child(z)
	z.build()
	return z

func run(t) -> void:
	var creature = load("res://creature/creature.gd")
	var legs := {"mite": 2, "trotter": 4, "hero": 4, "giant": 4, "longneck": 4, "centipede": 8, "hexapod": 6}
	for id in legs:
		var g := Genomes.genome(id)
		var parsed = creature.parse_genome(JSON.stringify(g))
		t.check(parsed.ok, "zoo genome %s is valid (%s)" % [id, parsed.get("error", "")])
		t.eq(Genomes.leg_count(g), legs[id], "zoo %s has %d legs" % [id, legs[id]])
	var host: Node = t.root
	var z = _zoo(["mite", "giant"], "uturn", host)
	t.eq(z.runners.size(), 2, "two runners")
	var max_w := [0.0, 0.0]
	var min_r := [1e9, 1e9]
	for tick in 700:
		z.step_ticks(1)
		for i in 2:
			var s: Dictionary = z.stats(i)
			max_w[i] = maxf(max_w[i], absf(s.omega))
			if s.speed > 3.0 and absf(s.omega) > 0.5:
				min_r[i] = minf(min_r[i], s.turn_radius)
	t.check(max_w[0] > max_w[1] + 0.3, "the mite turns faster than the giant (%.2f vs %.2f rad/s)" % [max_w[0], max_w[1]])
	t.check(min_r[1] > min_r[0], "the giant's tightest turn radius is wider (%.1f vs %.1f m)" % [min_r[1], min_r[0]])
	var moved: float = Vector2(z.stats(0).x - Course.lane_x(0, 2), z.stats(0).z - Course.START_Z).length()
	t.check(moved > 30.0, "the runner followed its course (%.0f m)" % moved)
	t.check(is_finite(z.stats(1).speed) and is_finite(z.stats(1).omega), "stats are finite")
	var h1: String = z.runners[0].sw.hashes[-1]
	var h2: String = z.runners[1].sw.hashes[-1]
	z.queue_free()
	var z2 = _zoo(["mite", "giant"], "uturn", host)
	for tick in 700:
		z2.step_ticks(1)
	t.check(z2.runners[0].sw.hashes[-1] == h1 and z2.runners[1].sw.hashes[-1] == h2, "the same zoo run twice gives the same hashes")
	z2.queue_free()
	# the ramps: a 2 legged body cannot climb 40 degrees, an 8 legged one can
	var zr = _zoo(["mite", "centipede"], "ramps", host)
	var top := [0.0, 0.0]
	for tick in 2600:
		zr.step_ticks(1)
		if tick % 5 == 0:
			for i in 2:
				var s: Dictionary = zr.stats(i)
				if absf(s.x - (Course.lane_x(i, 2) + Course.ramp_x(3))) < 1.5:
					top[i] = maxf(top[i], zr.runners[i].ground.call(s.x, s.z))
	t.check(top[1] > Course.BASE_H + 5.0, "the 8 legged body climbs the 40 degree ramp (%.1f m)" % top[1])
	t.check(top[0] < Course.BASE_H + 2.5, "the 2 legged body stalls at the foot of the 40 degree ramp (%.1f m)" % top[0])
	zr.queue_free()
	t.check(Zoo.parse_args(PackedStringArray(["--zoo=mite,giant", "--course=uturn"])).morphs == ["mite", "giant"], "zoo arguments parse")
	# run mode: sprint orders and a visual speed multiplier; the C hashes are the sprint run's, the shown speed is bigger
	var zw = _zoo(["trotter"], "figure8", host)
	var zs = Zoo.new()
	zs.with_visuals = false
	zs.auto_build = false
	zs.morph_ids = ["trotter"]
	zs.course_name = "figure8"
	zs.run_speed = 2.0
	host.add_child(zs)
	zs.build()
	var sw_walk = zw.runners[0].sw
	var sw_run = zs.runners[0].sw
	for tick in 120:
		zw.step_ticks(1)
		zs.step_ticks(1)
	var d_walk: float = Vector2(zw.stats(0).x - Course.lane_x(0, 1), zw.stats(0).z - Course.START_Z).length()
	var d_c: float = Vector2(zs.stats(0).x - Course.lane_x(0, 1), zs.stats(0).z - Course.START_Z).length()
	t.check(d_c > d_walk * 1.2, "run mode sends sprint orders: the C world covers more ground (%.1f vs %.1f m)" % [d_c, d_walk])
	var seen: Vector3 = sw_run.sample(0, 1.0).pos
	var c_pos := Vector3(sw_run.cur.entities[0].x, seen.y, sw_run.cur.entities[0].z)
	t.check(seen.distance_to(c_pos) > 1.0, "the shown position runs ahead of the C one by the visual multiplier (%.1f m)" % seen.distance_to(c_pos))
	t.check(sw_run.sample(0, 0.5).speed > sw_run.cur.entities[0].speed * 1.5, "the shown speed is multiplied")
	sw_run.set_vis_speed(1.0)
	t.check(sw_run.sample(0, 1.0).pos.distance_to(c_pos) < 0.01, "runvis off drops the offset")
	t.check(sw_walk.sample(0, 1.0).pos.distance_to(Vector3(sw_walk.cur.entities[0].x, sw_walk.sample(0, 1.0).pos.y, sw_walk.cur.entities[0].z)) < 0.01, "without it the shown position is the C one")
	zw.queue_free()
	zs.queue_free()
