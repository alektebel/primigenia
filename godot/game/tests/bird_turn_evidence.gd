extends SceneTree
# Bird-turn evidence: left and right turns of the flyer on the real island, seen from behind (the chase camera, which rolls 30 % of the bank) and
# from the side (a fixed side camera). Contact sheets plus the numbers (bank, heading rate, head roll). Under xvfb with software GL only:
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --path godot --script res://game/tests/bird_turn_evidence.gd -- <out dir>
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

func side_cam() -> void:
	var m = island.flight.model
	var r: Basis = m.orientation()
	var yaw := Basis(Vector3.UP, atan2(m.yaw_dir.x, m.yaw_dir.y))
	var right := yaw * Vector3.RIGHT
	var cam: Camera3D = island.camera
	cam.global_position = m.pos + right * -9.0 + Vector3(0, 0.5, 0) - yaw * Vector3.BACK * 1.0
	cam.look_at(m.pos, Vector3.UP)

func turn_seq(label: String, key: float, side: bool, into: Array) -> void:
	var f = island.flight
	island.chase_enabled = not side
	var dt := 1.0 / 30.0
	var plan := [[1.6, key], [1.8, 0.0]]
	var next := 0.0
	var t := 0.0
	var max_bank := 0.0
	var max_head := 0.0
	var yaw0: float = f.model.yaw_dir.angle()
	for ph in plan:
		var tt := 0.0
		f.keys_override = {"flap": false, "dive": false, "pitch": 0.0, "turn": ph[1]}
		while tt < float(ph[0]) - 1e-6:
			if t >= next - 1e-6:
				RenderingServer.render_loop_enabled = true
				if side:
					await process_frame
					side_cam()
				into.append(await shot())
				next += 0.3
			else:
				RenderingServer.render_loop_enabled = false
				await process_frame
			tt += dt
			t += dt
			t_now += dt
			var m = f.model
			if not f.active():
				return
			max_bank = maxf(max_bank, absf(atan(m.bank_t)))
			max_head = maxf(max_head, absf(m.head_roll()))
			rows.append("%s,%.2f,%.1f,%.3f,%.3f,%.2f,%.1f" % [label, t, rad_to_deg(atan(m.bank_t)), rad_to_deg(m.yaw_rate), rad_to_deg(m.head_roll()), m.vel.length(), f.altitude()])
	check(max_bank > deg_to_rad(40.0), "%s: the bank builds (%.0f deg)" % [label, rad_to_deg(max_bank)])
	check(max_head < deg_to_rad(6.0), "%s: the head stays within %.1f deg of level" % [label, rad_to_deg(max_head)])
	check(absf(f.model.bank_t) < 0.15, "%s: rolled back out (tan %.2f)" % [label, f.model.bank_t])
	var dyaw := wrapf(f.model.yaw_dir.angle() - yaw0, -PI, PI)
	print(label, ": heading turned ", rad_to_deg(dyaw), " deg")
	island.chase_enabled = true

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	drawing = DisplayServer.get_name() != "headless" and out_dir != ""
	if not drawing:
		print("bird_turn_evidence: needs a display (run it with xvfb and software GL); nothing to do headless")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	rows = PackedStringArray(["seq,t,bank_deg,yaw_rate_deg_s,head_roll_deg,speed,alt"])
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	var parsed := Scenario.read("creature/flight_cliff")
	game.pending_scenario = parsed
	island = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	await settle(20)
	island.stage_ui.ui.visible = false
	var f = island.flight
	f.keys_override = {"flap": false, "dive": false, "pitch": 0.0, "turn": 0.0}
	f.press_space()
	await fly(7.0, {"flap": true, "dive": false, "pitch": 0.0, "turn": 0.0})
	var seqs := {}
	for spec in [["left_behind", -1.0, false], ["right_behind", 1.0, false], ["left_side", -1.0, true], ["right_side", 1.0, true]]:
		var frames: Array = []
		await turn_seq(spec[0], spec[1], spec[2], frames)
		sheet(frames, 4, "turn_%s.png" % spec[0])
		await fly(5.5, {"flap": true, "dive": false, "pitch": 0.0, "turn": 0.0})
	var fa := FileAccess.open(out_dir.path_join("turn.csv"), FileAccess.WRITE)
	fa.store_string("\n".join(rows) + "\n")
	fa.close()
	print("bird_turn_evidence: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
