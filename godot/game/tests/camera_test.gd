extends SceneTree
# make godot-camera-test: the follow camera never hides the player and never snaps (creature-loop T4).
# A bot plays the real island through click-walk orders along routes through forest, rock fields and slopes. Every frame the test
# casts from the camera to the player's body centre and head against the terrain heightfield and the camera-only occluder proxies
# (trunks, bushes, rocks), and compares the camera's motion with the player's.
#   occluded frame: the centre OR the head is blocked from the camera (frames where the player stands inside a proxy are ignored)
#   snap: the camera moves more than SNAP_REL_M relative to the player in one 1/60 s frame, or turns more than SNAP_DEG
# Gates: occluded < 2 % of frames, 0 snaps, camera never under the ground, at least MIN_FRAMES measured.
#   godot --headless --fixed-fps 60 --path godot --script res://game/tests/camera_test.gd -- [seed=1] [z=0|0.15] [legacy] [out=<json>] [shots=<dir>] [frames=<json of frame ids to photograph>]
# `legacy` runs the terrain-only instant-boom camera of before T4 (the "before" numbers); `shots` needs a rendering driver (xvfb, software GL).

const CameraOccluders := preload("res://game/player/camera_occluders.gd")

const MAX_OCCLUDED_PCT := 2.0
const SNAP_REL_M := 0.4
const SNAP_DEG := 6.0
const MIN_FRAMES := 3000
const LEG_FRAMES := 2400
const MAX_FRAMES := 14000
const WARMUP := 90
const CIRCLE_DX := 4.0             # px of drag per frame (about 1.4 degrees per frame, a quick drag)
const CIRCLE_FRAMES := 270         # one full turn and a bit

var checks := 0
var failures := 0
var game
var island
var seed_n := 1
var zoom := -1.0
var legacy := false
var out_path := ""
var shots_dir := ""
var shot_ids := {}
var meas                          # CameraOccluders for measuring (always built, also in legacy mode)
var route: Array = []
var circle := true                 # nocircle: skip the full-turn orbit next to a prop
var orbit_stress := false         # the player also swings the camera by hand (right-drag) while walking: it ends up behind trees and rocks
var trace_lo := -1
var trace_hi := -1
var max_frames := MAX_FRAMES
var verbose := OS.get_environment("CAM_VERBOSE") != ""

var frames_n := 0
var occluded := 0
var occl_center := 0
var occl_head := 0
var skipped_inside := 0
var skipped_cave := 0
var snaps := 0
var worst_rel := 0.0
var worst_deg := 0.0
var rels: Array = []
var degs: Array = []
var underground := 0
var min_clear := 1e9
var runs: Array = []              # [start frame, length, what] of occlusion runs
var _run_start := -1
var snap_log: Array = []
var kinds := {}
var prev_cam = null
var prev_fwd = null
var prev_pl = null
var cur_leg := ""

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_n = int(a.substr(5))
		elif a.begins_with("z="):
			zoom = float(a.substr(2))
		elif a == "legacy":
			legacy = true
		elif a.begins_with("max="):
			max_frames = int(a.substr(4))
		elif a == "nocircle":
			circle = false
		elif a == "orbit":
			orbit_stress = true
		elif a.begins_with("trace="):
			trace_lo = int(a.substr(6).split("-")[0])
			trace_hi = int(a.substr(6).split("-")[1])
			max_frames = trace_hi + 5
		elif a.begins_with("out="):
			out_path = a.substr(4)
		elif a.begins_with("shots="):
			shots_dir = a.substr(6)
		elif a.begins_with("frames="):
			var j = JSON.parse_string(FileAccess.get_file_as_string(a.substr(7)))
			for id in j:
				shot_ids[int(id)] = true
	_run.call_deferred()

func until(cond: Callable, budget_ms := 120000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < budget_ms:
		await process_frame
	return cond.call()

func _scene_is(script_name: String) -> bool:
	if script_name == "island.gd" and current_scene != null and "_building" in current_scene and current_scene._building:
		return false
	return current_scene != null and current_scene.get_script() != null and current_scene.get_script().resource_path.ends_with(script_name)

func _run() -> void:
	game = root.get_node("Game")
	root.size = Vector2i(1280, 720)
	game.persist_settings = false
	game.settings.seed = seed_n
	game.settings.grass = 3000
	game.settings.wild = false          # nothing to fight or flee: the bot only walks
	game.settings["onboarding"] = 0x1ff
	change_scene_to_file("res://game/main.tscn")
	if not await until(func(): return _scene_is("main_menu.gd"), 60000):
		return _finish("main did not boot")
	current_scene.play_button.pressed.emit()
	if not await until(func(): return _scene_is("island.gd")):
		return _finish("the island did not open")
	island = current_scene
	for i in 5:
		await process_frame
	game.stage.timescale = 1.0
	if shots_dir != "":
		RenderingServer.render_loop_enabled = false
	var chase = island.chase
	chase.legacy = legacy
	if legacy:
		chase.occluders = null
	if zoom >= 0.0:
		chase.set_zoom(zoom, true)
	meas = CameraOccluders.new()
	meas.build(island.props.records, island.props)
	print("camera test: seed %d z %.2f %s, %d occluder proxies from %d plant records, boom %.2f m" % [seed_n, chase.z, "LEGACY camera" if legacy else "new camera", meas.count, island.props.records.size(), chase.distance])
	route = _plan_route()
	print("  route: ", route.map(func(w): return "%s (%.0f,%.0f)" % [w.kind, w.p.x, w.p.y]))
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": true, "run": true}
	for w in route:
		if frames_n >= max_frames:
			break
		await _leg(w)
	island.player_input.keys_override = null
	_report()

# ---- routes ------------------------------------------------------------------------------------------------------

func _me() -> Vector2:
	var e: Dictionary = game.stage.cur.entities[0]
	return Vector2(float(e.x), float(e.z))

func _plan_route() -> Array:
	var d = game.data
	var ground: Callable = island.chase.ground
	var nest: Vector2 = island._nest
	var trees := {}
	var rocks := {}
	var recipe: Dictionary = island.props.recipe
	for r in island.props.records:
		var id: String = r.id
		var form := "rock" if id in CameraOccluders.ROCKS else String(recipe.get(id, {}).get("form", ""))
		if form != "tree" and form != "rock":
			continue
		var bin: Dictionary = trees if form == "tree" else rocks
		var p: Vector3 = r.p
		var key := Vector2i(floori(p.x / 30.0), floori(p.z / 30.0))
		bin[key] = int(bin.get(key, 0)) + 1
	var out: Array = []
	var near := func(c: Vector2i) -> bool: return Vector2((c.x + 0.5) * 30.0, (c.y + 0.5) * 30.0).distance_to(nest) < 520.0
	var best := func(bin: Dictionary, n: int) -> Array:
		var cells: Array = bin.keys().filter(near)
		cells.sort_custom(func(a, b): return bin[a] > bin[b])
		var picked: Array = []
		for c: Vector2i in cells:
			var ctr := Vector2((c.x + 0.5) * 30.0, (c.y + 0.5) * 30.0)
			var far := true
			for q: Vector2 in picked:
				if q.distance_to(ctr) < 90.0:
					far = false
			if far:
				picked.append(ctr)
			if picked.size() >= n:
				break
		return picked
	for ctr: Vector2 in best.call(trees, 4):
		out.append({"kind": "forest", "p": _clear_spot(ctr)})
	for ctr: Vector2 in best.call(rocks, 3):
		out.append({"kind": "rocks", "p": _clear_spot(ctr)})
	# slopes: the steepest walkable grades within reach of the nest, spread out
	var steep: Array = []
	var step := 14.0
	var x := nest.x - 480.0
	while x <= nest.x + 480.0:
		var z := nest.y - 480.0
		while z <= nest.y + 480.0:
			if absf(x) < d.half - 40.0 and absf(z) < d.half - 40.0 and Vector2(x, z).distance_to(nest) > 60.0:
				var g := Vector2(ground.call(x + 4.0, z) - ground.call(x - 4.0, z), ground.call(x, z + 4.0) - ground.call(x, z - 4.0)).length() / 8.0
				var y: float = ground.call(x, z)
				if g > 0.45 and g < 0.8 and y > 4.0:
					steep.append({"p": Vector2(x, z), "g": g})
			z += step
		x += step
	steep.sort_custom(func(a, b): return a.g > b.g)
	var picked_s: Array = []
	for s in steep:
		var ok := true
		for q in picked_s:
			if q.p.distance_to(s.p) < 120.0:
				ok = false
		if ok:
			picked_s.append(s)
		if picked_s.size() >= 4:
			break
	for s in picked_s:
		out.append({"kind": "slope %.2f" % s.g, "p": s.p})
	# order by a short tour from the nest
	var tour: Array = []
	var here := nest
	out.sort_custom(func(a, b): return (0 if not String(a.kind).begins_with("slope") else 1) < (0 if not String(b.kind).begins_with("slope") else 1))
	var left := out.duplicate()
	for phase in 2:
		var group: Array = left.filter(func(w): return (1 if String(w.kind).begins_with("slope") else 0) == phase)
		while not group.is_empty():
			group.sort_custom(func(a, b): return a.p.distance_to(here) < b.p.distance_to(here))
			var w: Dictionary = group.pop_front()
			tour.append(w)
			here = w.p
	return tour

# the spot nearest to `c` that is not inside a trunk or rock proxy
func _clear_spot(c: Vector2) -> Vector2:
	var ground: Callable = island.chase.ground
	for r in range(0, 60, 3):
		for k in 8:
			var q := c + Vector2.from_angle(k * TAU / 8.0) * float(r)
			if not meas.contains(Vector3(q.x, ground.call(q.x, q.y) + 0.6, q.y), 0.6):
				return q
	return c

func _leg(w: Dictionary) -> void:
	cur_leg = w.kind
	var t0 := frames_n
	var arrived := false
	var stuck_ref := _me()
	var stuck_at := frames_n
	var last_send := -1000
	while frames_n - t0 < LEG_FRAMES and frames_n < max_frames:
		var me := _me()
		if me.distance_to(w.p) < 4.0:
			arrived = true
			break
		if frames_n - last_send > 90:
			island.player_input.set_destination(w.p)
			last_send = frames_n
		if frames_n - stuck_at > 300:
			if me.distance_to(stuck_ref) < 3.0:
				break                    # not getting anywhere (water, a cliff): next leg
			stuck_ref = me
			stuck_at = frames_n
		if orbit_stress:
			_orbit_by_hand()
		await process_frame
		await _measure()
		if verbose and frames_n % 300 == 0:
			print("   f%d leg %s me %s dest %s cam %s boom %.2f lift %.2f" % [frames_n, cur_leg, _me(), w.p, island.camera.global_position, island.chase.boom, island.chase.lift])
	island.player_input.clear_destination()
	if circle and (w.kind == "forest" or w.kind == "rocks") and frames_n < max_frames:
		await _circle(w)

# The hard case: stand right next to the nearest trunk or rock and swing the camera a full turn by hand, so it passes behind the prop.
func _circle(w: Dictionary) -> void:
	cur_leg = "circle " + String(w.kind)
	var best := -1
	var bd := 1e9
	for i in meas.count:
		var o: int = i * 8
		if meas.rows[o + 7] - meas.rows[o + 6] < 0.8:
			continue
		var d := Vector2(meas.rows[o], meas.rows[o + 1]).distance_to(_me())
		if d < bd:
			bd = d
			best = i
	if best < 0 or bd > 60.0:
		return
	var o := best * 8
	var obj := Vector2(meas.rows[o], meas.rows[o + 1])
	var rad := maxf(1.0 / meas.rows[o + 2], 1.0 / meas.rows[o + 3])
	var me := _me()
	var spot := obj + (me - obj).normalized() * (rad + 1.3)
	var t0 := frames_n
	island.player_input.set_destination(spot)
	while frames_n - t0 < 1200 and frames_n < max_frames and _me().distance_to(spot) > 0.9:
		await process_frame
		await _measure()
	island.player_input.clear_destination()
	for i in 40:
		await process_frame
		await _measure()
	if true:
		print("   circle: obj %s r %.2f top %.2f me %s dist %.2f cam %s" % [obj, rad, meas.rows[o + 7] - meas.rows[o + 6], _me(), _me().distance_to(obj), island.camera.global_position])
	var close := 0
	for i in CIRCLE_FRAMES:
		island.chase.orbit(CIRCLE_DX, 0.0)
		await process_frame
		await _measure()
		var cp: Vector3 = island.camera.global_position
		var a2 := Vector2(cp.x, cp.z)
		var b2 := _me()
		var ab := b2 - a2
		var tt := clampf((obj - a2).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if (a2 + ab * tt).distance_to(obj) < rad:
			close += 1
	if true:
		print("   circle: frames with the camera line through the footprint: %d, occluded so far %d" % [close, occluded])
	for i in 40:
		await process_frame
		await _measure()

# A hand orbit: 70 frames of drag (about 25 degrees), then 170 frames of rest, alternating sides; the vertical drag nudges the pitch.
func _orbit_by_hand() -> void:
	var ph := frames_n % 240
	if ph < 70:
		var dir := 1.0 if (frames_n / 240) % 2 == 0 else -1.0
		island.chase.orbit(dir * 10.0, 0.0 if ph > 5 else (3.0 if (frames_n / 240) % 3 == 0 else -2.0))

# ---- measuring -----------------------------------------------------------------------------------------------------

func _blocked(cam: Vector3, pt: Vector3) -> bool:
	var ground: Callable = island.chase.ground
	var d := pt - cam
	var n := maxi(2, ceili(d.length() / 0.2))
	for i in range(1, n):
		var q := cam + d * (float(i) / n)
		if q.y < float(ground.call(q.x, q.z)) + 0.02:
			return true
	return meas.cast(cam, pt, 0.0) < 1.0

func _measure() -> void:
	var chase = island.chase
	var cam: Vector3 = island.camera.global_position
	var fwd: Vector3 = -island.camera.global_transform.basis.z
	var p: Vector2 = _me()
	var gy: float = chase.ground.call(p.x, p.y)
	var pl := Vector3(p.x, gy, p.y)
	var h: float = chase.height
	var center := pl + Vector3(0, h * 0.5, 0)
	var head := pl + Vector3(0, h, 0)
	var cave_on: bool = island.cave_site != null and island.cave_site.on and island.cave_site.zone(p.x, p.y) != 0
	var fid := frames_n
	frames_n += 1
	if fid >= trace_lo and fid <= trace_hi:
		print("TRACE f%d cam %s pl %s boom %.2f cap %.2f lift %.3f act %.2f yaw %.3f" % [fid, cam, pl, chase.boom, chase._cap, chase.lift, (cam - chase.target).length(), chase.view_yaw])
	if frames_n < WARMUP:
		prev_cam = cam
		prev_fwd = fwd
		prev_pl = pl
		return
	if shot_ids.has(fid) and shots_dir != "":
		await _shot(fid)
	if prev_cam != null:
		var rel: float = ((cam - prev_cam) - (pl - prev_pl)).length()
		var deg: float = rad_to_deg(fwd.angle_to(prev_fwd))
		worst_rel = maxf(worst_rel, rel)
		worst_deg = maxf(worst_deg, deg)
		rels.append(rel)
		degs.append(deg)
		if rel > SNAP_REL_M or deg > SNAP_DEG:
			snaps += 1
			if snap_log.size() < 12:
				snap_log.append({"frame": fid, "rel_m": snappedf(rel, 0.01), "deg": snappedf(deg, 0.1), "leg": cur_leg})
	prev_cam = cam
	prev_fwd = fwd
	prev_pl = pl
	var ground_here: float = chase.ground.call(cam.x, cam.z)
	min_clear = minf(min_clear, cam.y - ground_here)
	if cam.y < ground_here - 0.01:
		underground += 1
	if cave_on:
		skipped_cave += 1
		return
	if meas.contains(center, 0.0) or meas.contains(head, 0.0) or meas.contains(cam, 0.0):
		skipped_inside += 1
		return
	var bc := _blocked(cam, center)
	var bh := _blocked(cam, head)
	if bc:
		occl_center += 1
	if bh:
		occl_head += 1
	var seen := bc or bh
	kinds[cur_leg] = kinds.get(cur_leg, [0, 0])
	kinds[cur_leg][0] += 1
	if seen:
		occluded += 1
		kinds[cur_leg][1] += 1
		if _run_start < 0:
			_run_start = fid
	elif _run_start >= 0:
		runs.append([_run_start, fid - _run_start, cur_leg])
		_run_start = -1

func _shot(fid: int) -> void:
	RenderingServer.render_loop_enabled = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots_dir)
	img.save_jpg("%s/%s_%05d.jpg" % [shots_dir, "before" if legacy else "after", fid], 0.88)
	RenderingServer.render_loop_enabled = false       # only the photographed frames are drawn (software GL is slow)

func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, int(q * s.size()))])

func _report() -> void:
	var measured := frames_n - WARMUP - skipped_inside - skipped_cave
	var pct := 100.0 * occluded / maxf(1.0, measured)
	runs.sort_custom(func(a, b): return a[1] > b[1])
	var res := {
		"label": "legacy" if legacy else "new", "seed": seed_n, "zoom": snappedf(island.chase.z, 0.01), "frames": frames_n, "measured": measured,
		"occluded_frames": occluded, "occluded_pct": snappedf(pct, 0.01), "center_blocked": occl_center, "head_blocked": occl_head,
		"skipped_player_inside_prop": skipped_inside, "skipped_cave": skipped_cave, "longest_runs": runs.slice(0, 6),
		"snaps": snaps, "worst_rel_m": snappedf(worst_rel, 0.001), "worst_turn_deg": snappedf(worst_deg, 0.01),
		"p99_rel_m": snappedf(_pct(rels, 0.99), 0.001), "p99_turn_deg": snappedf(_pct(degs, 0.99), 0.01),
		"camera_underground_frames": underground, "min_camera_ground_clear_m": snappedf(min_clear, 0.01), "snap_log": snap_log,
		"by_leg": kinds, "occluders": meas.count, "route": route.map(func(w): return {"kind": w.kind, "x": snappedf(w.p.x, 0.1), "z": snappedf(w.p.y, 0.1)}),
	}
	print(JSON.stringify(res, "  "))
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "  "))
		f.close()
	if shots_dir != "" and not shot_ids.is_empty():
		pass
	if shots_dir == "" and out_path != "" and legacy:
		var ids: Array = []
		for r in runs.slice(0, 12):
			ids.append(int(r[0]) + int(r[1]) / 2)
		var f2 := FileAccess.open(out_path.get_basename() + "_frames.json", FileAccess.WRITE)
		f2.store_string(JSON.stringify(ids))
		f2.close()
	if not legacy:
		check(frames_n >= MIN_FRAMES, "enough frames were measured (%d >= %d)" % [frames_n, MIN_FRAMES])
		check(pct < MAX_OCCLUDED_PCT, "the player is hidden in %.2f %% of frames (< %.1f %%)" % [pct, MAX_OCCLUDED_PCT])
		check(snaps == 0, "no camera snaps (worst %.3f m relative, %.2f deg per frame; %d over %.1f m or %.0f deg)" % [worst_rel, worst_deg, snaps, SNAP_REL_M, SNAP_DEG])
		check(underground == 0, "the camera is never under the ground (min clearance %.2f m)" % min_clear)
	_finish("")

func _finish(why: String) -> void:
	if why != "":
		check(false, why)
	print("camera test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
