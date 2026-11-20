extends SceneTree
# make godot-flight-test / godot-flight-evidence: a scripted flight of the test creature on the real island (scenario
# flight_cliff): takeoff, glide, flap, dive, flare, landing. Headless it asserts; under xvfb with software GL it also writes
# contact sheets of the takeoff, glide, flap and landing (and a CSV of the flight).
#   godot --headless --fixed-fps 30 --path godot --script res://game/tests/flight_evidence.gd
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --path godot --script res://game/tests/flight_evidence.gd -- <out dir>

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Scenario := preload("res://devtools/scenario.gd")

const TW := 427
const TH := 240

var out_dir := ""
var drawing := false
var game
var island: Node3D
var checks := 0
var failures := 0
var rows: PackedStringArray = PackedStringArray(["t,mode,speed,alt,vy,stamina,x,z,y"])
var t_now := 0.0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", what)

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TW, TH, Image.INTERPOLATE_BILINEAR)
	return img

func sheet(frames: Array, cols: int, name: String) -> void:
	if frames.is_empty() or out_dir == "":
		return
	var r := int(ceil(frames.size() / float(cols)))
	var im := Image.create(TW * cols, TH * r, false, Image.FORMAT_RGB8)
	for k in frames.size():
		im.blit_rect(frames[k], Rect2i(0, 0, TW, TH), Vector2i((k % cols) * TW, (k / cols) * TH))
	im.save_png(out_dir.path_join(name))
	print("wrote ", name)

# Plays `secs` of game time with these keys, collecting a frame every `every` seconds (drawing only).
func fly(secs: float, keys: Dictionary, every := 0.0, into: Array = []) -> void:
	var f = island.flight
	f.keys_override = keys
	var t := 0.0
	var next := 0.0
	var dt := 1.0 / 30.0
	while t < secs - 1e-6:
		if drawing and every > 0.0 and t >= next - 1e-6:
			RenderingServer.render_loop_enabled = true
			into.append(await shot())
			next += every
		else:
			if drawing:
				RenderingServer.render_loop_enabled = false      # game time without drawing (software GL is slow)
			await process_frame
		t += dt
		t_now += dt
		var m = f.model
		if m != null:
			rows.append("%.2f,%s,%.2f,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f" % [t_now, m.mode, m.vel.length(), f.altitude(), m.vel.y, m.stamina, m.pos.x, m.pos.z, m.pos.y])
		if f.model != null and not f.active() and t > 0.5 and keys.get("stop_on_ground", false):
			break

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	drawing = DisplayServer.get_name() != "headless" and out_dir != ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	var parsed := Scenario.read("creature/flight_cliff")
	check(parsed.ok, "the flight_cliff scenario reads (%s)" % parsed.get("error", ""))
	if not parsed.ok:
		quit(1)
		return
	game.pending_scenario = parsed
	island = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	await settle(20)
	check(game.startup_error == "", "the scenario loads (%s)" % game.startup_error)
	if drawing:
		island.stage_ui.ui.visible = false
	var f = island.flight
	check(f != null and f.has_wings(), "the player is the winged test creature")
	if f == null or not f.has_wings():
		quit(1)
		return
	var rep: Dictionary = f.model.report()
	print("flyer: mass %.1f kg, S %.2f m2, AR %.1f, loading %.0f N/m2, stall %.1f m/s, L/D %.1f, power %.0f W (needs %.0f), %s" % [float(f.model.spec.mass), rep.area, rep.ar, rep.wing_loading, rep.stall, rep.ld, rep.power, rep.p_req, rep.capability])
	check(rep.capability == "flap", "the test creature can flap")
	var teleports0: int = island.stage.log_debug.size()
	var ground_y0: float = island.player_pos.y
	var tp := Vector3(island.player_pos)
	var take: Array = []
	var glide: Array = []
	var flap: Array = []
	var land: Array = []
	await settle(10)
	var bs: Dictionary = island.stage.sample(0)
	var fwd := Vector3(sin(bs.yaw), 0, cos(bs.yaw))
	print("start at ", bs.pos, " yaw ", bs.yaw, " ground ahead at 5/15/30/60 m: ", [game.visual_ground(bs.pos.x + fwd.x * 5, bs.pos.z + fwd.z * 5), game.visual_ground(bs.pos.x + fwd.x * 15, bs.pos.z + fwd.z * 15), game.visual_ground(bs.pos.x + fwd.x * 30, bs.pos.z + fwd.z * 30), game.visual_ground(bs.pos.x + fwd.x * 60, bs.pos.z + fwd.z * 60)])
	# ---- takeoff: Space on the ground (a burst launch: the test creature cannot run to 11 m/s)
	f.keys_override = {"flap": false, "dive": false, "pitch": 0.0, "turn": 0.0}
	f.press_space()
	await fly(2.5, {"flap": true, "dive": false, "pitch": 0.0, "turn": 0.0}, 0.25, take)
	check(f.active(), "Space on the ground takes off")
	var alt_takeoff: float = f.altitude()
	check(alt_takeoff > 1.0, "airborne after 2.5 s of flapping (altitude %.1f m)" % alt_takeoff)
	check(island.player_input.suspended, "C is told to wait while flying")
	# ---- glide from the climb
	await fly(6.0, {"flap": false, "dive": false, "pitch": 0.0, "turn": 0.0}, 1.0, glide)
	check(f.model.mode in ["glide", "flare"], "released Space: gliding (%s)" % f.model.mode)
	var alt_glide0: float = f.altitude()
	# ---- flap for 5 s, then dive, then glide down, flare and land
	await fly(5.0, {"flap": true, "dive": false, "pitch": 0.0, "turn": 0.0}, 0.8, flap)
	check(f.model.mode == "flap" or f.model.mode == "glide", "flapping (%s)" % f.model.mode)
	check(f.model.stamina < 0.8, "flapping costs stamina (%.2f)" % f.model.stamina)
	await fly(1.5, {"flap": false, "dive": true, "pitch": 0.0, "turn": 0.0}, 0.5, glide)
	check(f.model.mode == "dive", "Ctrl dives")
	var speed_dive: float = f.model.vel.length()
	await fly(1.0, {"flap": false, "dive": false, "pitch": 0.0, "turn": 1.0}, 0.5, glide)
	var guard := 0
	while f.active() and guard < 120:
		await fly(0.5, {"flap": false, "dive": false, "pitch": 0.0, "turn": 0.0, "stop_on_ground": true}, 0.5, land if f.altitude() < 14.0 else [])
		guard += 1
	check(not f.active(), "the flight ends on the ground")
	check(f.landings >= 1, "a landing was recorded")
	check(f.last_landing.get("damage", 1.0) == 0.0, "a flared landing costs nothing (%s)" % [f.last_landing])
	check(not island.player_input.suspended, "C is given the creature back")
	await settle(10)
	var c_pos := Vector2(island.stage.cur.entities[0].x, island.stage.cur.entities[0].z)
	var flyer_pos := Vector2(f.model.pos.x, f.model.pos.z)
	check(c_pos.distance_to(flyer_pos) < 4.0, "C's player stands where the flyer landed (%.1f m apart)" % c_pos.distance_to(flyer_pos))
	check(f.teleports_sent > 20, "teleports were sent every tick (%d)" % f.teleports_sent)
	check(f.teleports_rejected * 4 <= f.teleports_sent, "the world accepted most teleports (%d of %d refused: rocks and trees refuse a spot, the next tick tries again)" % [f.teleports_rejected, f.teleports_sent])
	check(island.stage.log_debug.size() > teleports0 + 20, "the teleports are in the replay log (%d ops)" % (island.stage.log_debug.size() - teleports0))
	# the session replays: the exported log parses and replays to the same final hash
	var WorldLog := preload("res://game/stage/world_log.gd")
	var text: String = island.stage.export_log()
	var rec: Dictionary = WorldLog.parse(text)
	check(rec.ok, "the session log parses")
	if rec.ok:
		var StageWorld := preload("res://game/stage/stage_world.gd")
		var sw = StageWorld.new()
		sw.world.set_field(entry)
		var rc := 0
		if island.stage.start_snapshot.size() > 0:
			rc = sw.restore_from(island.stage.start_snapshot)
			var dbg: Array = rec.get("debug", [])
			var di := 0
			for inp in rec.inputs:
				while di < dbg.size() and int(dbg[di].tick) == int(sw.cur.tick):
					sw.debug_now(dbg[di].op)
					di += 1
				sw.queue_order(inp)
				sw.step_once()
			while di < dbg.size() and int(dbg[di].tick) == int(sw.cur.tick):
				sw.debug_now(dbg[di].op)
				di += 1
		else:
			rc = sw.replay_recipe(rec)
		check(rc == 0 and sw.cur.hash == island.stage.cur.hash, "the flight replays to the same world hash (rc %d, tick %d vs %d)" % [rc, int(sw.cur.tick), int(island.stage.cur.tick)])
	await settle(10)
	# wings are back at rest
	var w = island.hosts[0].body
	var wing_ok := true
	for e in w.parts:
		if e.hooks.has("wing") and (e.hooks.wing as Node3D).basis.get_scale().x < 0.9:
			wing_ok = false
	check(wing_ok, "the wings are unfolded to the ground pose after landing")
	print("dive speed %.1f m/s, altitude after glide start %.1f m, ground y %.1f" % [speed_dive, alt_glide0, ground_y0])
	RenderingServer.render_loop_enabled = true
	if out_dir != "":
		var fcsv := FileAccess.open(out_dir.path_join("flight.csv"), FileAccess.WRITE)
		fcsv.store_string("\n".join(rows) + "\n")
		fcsv.close()
		sheet(take, 4, "takeoff.png")
		sheet(glide, 4, "glide.png")
		sheet(flap, 4, "flap.png")
		sheet(land, 4, "land.png")
	print("flight: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
