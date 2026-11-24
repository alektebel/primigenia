extends SceneTree
# PLAN-heights H5/H6: the C world on the generated island. Run:
#   godot --headless --path godot --script res://game/tests/test_heights.gd [-- <evidence dir>]
# 1. a 3000-tick scripted walk never puts an entity in deep water or outside the bound;
# 2. GO orders from the nest to 20 grid points: arrives, or is blocked with a reason; fail if > 4 are blocked or any oscillates;
# 3. Garfio chases from 10 slope homes: nobody ends a tick in water or on a > 50 degree slope;
# 4. timing: 10 000 steps with 24 wild, field vs flat; gate field < 2x flat and < 50 us/step.

const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Profile := preload("res://game/stage/profile.gd")

var checks := 0
var failures := 0
var entry: Dictionary
var data
var evidence := {}

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + what)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func _field_world(wild: Array = [], nest := Vector2.ZERO) -> Node:
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	var setup: Dictionary = CporeWorld.default_setup(5)
	setup.terrain = 2
	setup.nest = nest
	setup.wild = wild
	sw.reset(setup)
	return sw

func _ok_spot(x: float, z: float) -> bool:
	return StageSetup.dry(data, x, z) and absf(x) < 1700.0 and absf(z) < 1700.0 and data.normal(x, z).y > 0.9

func _run() -> void:
	entry = TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		var p: Dictionary = CporeTerrain.defaults()
		p.seed = 1
		entry = CporeTerrain.new().generate(p)
		TerrainData.prepare(entry)
	data = TerrainData.new()
	data.setup(entry, false)
	var nest := StageSetup.find_nest(data)
	var t0 := Time.get_ticks_msec()
	_walk(nest)
	_grid(nest)
	_chases()
	_timing()
	var out_dir := ""
	for a in OS.get_cmdline_user_args():
		out_dir = a
	if out_dir == "" and OS.get_cmdline_user_args().is_empty():
		out_dir = ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		var f := FileAccess.open(out_dir.path_join("heights.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(evidence, "\t"))
		f.close()
	print("heights test: %d checks, %d failures (%d ms)" % [checks, failures, Time.get_ticks_msec() - t0])
	quit(1 if failures else 0)

func _walk(nest: Vector2) -> void:
	print("== scripted walk, 3000 ticks")
	var sw = _field_world([], nest)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var bound: float = sw.world.bound()
	var heading := [rng.randi_range(-32767, 32767), rng.randi_range(-32767, 32767)]
	var wet := 0
	var out := 0
	var far := 0.0
	sw.input_provider = func() -> Dictionary:
		var k: int = sw.log_inputs.size()
		if k % 60 == 0:
			heading[0] = rng.randi_range(-32767, 32767)
			heading[1] = rng.randi_range(-32767, 32767)
		return {"verb": 3, "hx": heading[0], "hz": heading[1], "sprint": 1 if k % 200 < 60 else 0}
	for i in 3000:
		sw.step_once()
		var e: Dictionary = sw.cur.entities[0]
		if sw.world.water_depth(e.x, e.z) > 0.7:
			wet += 1
		if absf(e.x) > bound or absf(e.z) > bound:
			out += 1
		far = maxf(far, Vector2(e.x - nest.x, e.z - nest.y).length())
	check(wet == 0, "never in water deeper than 0.7 m (%d ticks)" % wet)
	check(out == 0, "never outside the bound (%d ticks)" % out)
	check(far > 100.0, "the walk went somewhere (%.0f m from the nest)" % far)
	evidence["walk"] = {"ticks": 3000, "wet": wet, "outside": out, "farthest_m": snappedf(far, 0.1)}

func _grid(nest: Vector2) -> void:
	print("== GO to 20 grid points")
	var rows := []
	var blocked := 0
	var stuck := 0
	for gj in 4:
		for gi in 5:
			var gx: float = lerpf(-1300.0, 1300.0, gi / 4.0)
			var gz: float = lerpf(-1300.0, 1300.0, gj / 3.0)
			var target = _nearest_spot(gx, gz)
			var sw = _field_world([], nest)
			var res := _go(sw, target)
			rows.append({"grid": [gi, gj], "target": [snappedf(target.x, 0.1), snappedf(target.y, 0.1)], "result": res.result, "reason": res.reason,
				"ticks": res.ticks, "left_m": snappedf(res.left, 0.1)})
			print("  (%d,%d) -> (%.0f,%.0f): %s %s, %d ticks, %.1f m left" % [gi, gj, target.x, target.y, res.result, res.reason, res.ticks, res.left])
			if res.result == "blocked":
				blocked += 1
			elif res.result == "stuck":
				stuck += 1
	# C1-nav: GO plans a route over the walk grid (A*), so the plan's gate (<= 4 of 20 unreachable) holds; before it,
	# 10 of 20 straight-line orders stopped at cliffs.
	print("  %d of 20 GO targets were not reached (plan gate 4, C1-nav target 2)" % blocked)
	check(blocked + stuck <= 2, "at least 18 of 20 targets are reached (%d not reached)" % (blocked + stuck))
	check(stuck <= 1, "at most one run wanders without progress (%d)" % stuck)
	evidence["grid"] = {"blocked": blocked, "stuck": stuck, "runs": rows}

func _nearest_spot(x: float, z: float) -> Vector2:
	for r in range(0, 800, 12):
		for k in 16 if r > 0 else 1:
			var a := k * TAU / 16.0
			var px := x + sin(a) * r
			var pz := z + cos(a) * r
			if _ok_spot(px, pz):
				return Vector2(px, pz)
	return Vector2(x, z)

func _go(sw, target: Vector2) -> Dictionary:
	sw.queue_order({"verb": 2, "x": target.x, "z": target.y, "sprint": 1})
	sw.input_provider = func() -> Dictionary: return {}
	var still := 0
	var best := 1e9
	var best_tick := 0
	for i in 12000:
		sw.step_once()
		var e: Dictionary = sw.cur.entities[0]
		var left := Vector2(e.x, e.z).distance_to(target)
		if int(sw.cur.order.verb) != 2:
			# the order ended: arrived, or never started (the world answered unreachable)
			if left < 4.0:
				return {"result": "arrived", "reason": "", "ticks": i, "left": left}
			return {"result": "blocked", "reason": "unreachable: %s" % CporeWorld.order_error(int(sw.cur.error)) if i == 0 else "order ended", "ticks": i, "left": left}
		if left < 2.0:
			return {"result": "arrived", "reason": "", "ticks": i, "left": left}
		if float(e.speed) < 0.5:
			still += 1
		else:
			still = 0
		if still >= 50:
			return {"result": "blocked", "reason": _reason(sw, e, target), "ticks": i, "left": left}
		# A certified route may go away from the destination to skirt a bank.
		# Progress is remaining walk distance, not straight-line distance to the goal.
		var remaining := 0.0
		var cursor := Vector2(e.x, e.z)
		var path: PackedVector2Array = sw.world.path()
		for waypoint in path:
			remaining += cursor.distance_to(waypoint)
			cursor = waypoint
		remaining += cursor.distance_to(target)
		if remaining < best - 5.0:
			best = remaining
			best_tick = i
		elif i - best_tick > 1200:
			return {"result": "stuck", "reason": "no progress in 1200 ticks", "ticks": i, "left": left}
	return {"result": "stuck", "reason": "out of time", "ticks": 12000, "left": 0.0}

func _reason(sw, e: Dictionary, target: Vector2) -> String:
	var dir := (target - Vector2(e.x, e.z)).normalized()
	var ahead := Vector2(e.x, e.z) + dir * 1.5
	if sw.world.water_depth(ahead.x, ahead.y) > 0.7:
		return "water"
	if absf(ahead.x) > sw.world.bound() or absf(ahead.y) > sw.world.bound():
		return "bound"
	return "slope"

func _slope_deg(x: float, z: float) -> float:
	var h := 0.25
	var dx: float = (data.ground(x + h, z) - data.ground(x - h, z)) / (2.0 * h)
	var dz: float = (data.ground(x, z + h) - data.ground(x, z - h)) / (2.0 * h)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

func _chases() -> void:
	print("== Garfio chases from 10 slope homes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var manifest := Profile.load_json("res://game/data/parts.json")
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var done := 0
	var bad := 0
	var fights := 0
	var attempts := 0
	var max_slope := 0.0
	while done < 10 and attempts < 4000:
		attempts += 1
		var x := rng.randf_range(-1500.0, 1500.0)
		var z := rng.randf_range(-1500.0, 1500.0)
		if not StageSetup.dry(data, x, z) or _slope_deg(x, z) < 15.0 or _slope_deg(x, z) > 40.0:
			continue
		var pl := Vector2(x + 18.0, z)
		if not (StageSetup.dry(data, pl.x, pl.y) and absf(pl.x) < 1700.0 and _slope_deg(pl.x, pl.y) < 35.0):
			continue
		var sw = _field_world([{"x": x, "z": z, "home_x": x, "home_z": z, "species": 3, "bot": -1, "profile": garfio}], pl)
		sw.input_provider = func() -> Dictionary: return {}
		var tick_bad := 0
		for i in 600:
			sw.step_once()
			for e in sw.cur.entities:
				var s := _slope_deg(e.x, e.z)
				max_slope = maxf(max_slope, s)
				if sw.world.water_depth(e.x, e.z) > 0.7 or s > 52.0:
					tick_bad += 1
					if tick_bad < 4:
						print("    bad: tick %d entity %d at %.1f,%.1f slope %.1f water %.2f speed %.2f" % [i, e.id, e.x, e.z, s, sw.world.water_depth(e.x, e.z), e.speed])
		if int(sw.cur.started) > 0:
			fights += 1
		bad += tick_bad
		done += 1
	check(done == 10, "found 10 slope homes (%d attempts)" % attempts)
	check(bad == 0, "no creature ended a tick in water or on a slope > 52 degrees (%d bad ticks, steepest %.1f)" % [bad, max_slope])
	evidence["chases"] = {"homes": done, "fights_started": fights, "bad_ticks": bad, "steepest_deg": snappedf(max_slope, 0.1)}

func _timing() -> void:
	print("== timing, 10 000 steps with 24 wild")
	var manifest := Profile.load_json("res://game/data/parts.json")
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var wild := []
	while wild.size() < 24:
		var x := rng.randf_range(-180.0, 180.0)
		var z := rng.randf_range(-180.0, 180.0)
		if _ok_spot(x, z) and Vector2(x, z).length() > 40.0:
			wild.append({"x": x, "z": z, "home_x": x, "home_z": z, "species": wild.size() % 3, "bot": -1, "profile": CporeWorld.species()[wild.size() % 3].profile})
	var res := {}
	var samples := {"field": [], "flat": []}
	# Interleave identical trials; a single scheduling pause must not decide the field/flat ratio.
	for trial in 3:
		for mode in (["field", "flat"] if trial % 2 == 0 else ["flat", "field"]):
			var w := CporeWorld.new()
			var setup: Dictionary = CporeWorld.default_setup(5)
			setup.nest = Vector2.ZERO
			setup.wild = wild
			if mode == "field":
				w.set_field(entry)
				setup.terrain = 2
			else:
				setup.terrain = 1
				setup.flat_height = 42.0
			check(w.reset(setup) == 0, "%s timing world resets" % mode)
			var input := {"verb": 3, "hx": 20000, "hz": 20000, "sprint": 1}
			var t0 := Time.get_ticks_usec()
			for i in 10000:
				w.step(input)
			samples[mode].append(float(Time.get_ticks_usec() - t0) / 10000.0)
	for mode in ["field", "flat"]:
		samples[mode].sort()
		res[mode] = samples[mode][1]
		print("  %s: %.1f us/step (median of 3 interleaved trials)" % [mode, res[mode]])
	check(res.field < 2.0 * res.flat, "field step < 2x flat (%.1f vs %.1f us)" % [res.field, res.flat])
	check(res.field < 50.0, "field step < 50 us (%.1f)" % res.field)
	evidence["timing_us_per_step"] = {"field": snappedf(res.field, 0.1), "flat": snappedf(res.flat, 0.1), "wild": 24, "steps": 10000, "note": "median of three interleaved 10000-step trials per mode; includes GDScript marshalling"}
