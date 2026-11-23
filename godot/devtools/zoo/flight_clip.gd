extends SceneTree
## Close three-quarter clips of the player's winged creature flying the owner's picks (A56, A57): flap-glide cruise, wingover,
## flare landing, running landing. Scripted keys on the real island (scenario creature/flight_cliff), software GL only:
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 640x360 --fixed-fps 24 --write-movie out.avi \
##     --path godot --script res://devtools/zoo/flight_clip.gd -- <flapglide|wingover|land_flare|land_run> [seconds] [cam_scale]
## Writes <name>.csv (t, mode, phase, speed, alt, bank, legs, bob) next to the movie when a CSV path is the 4th argument.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Scenario := preload("res://devtools/scenario.gd")

var island: Node3D
var game
var cam: Camera3D
var yaw_s := 0.0
var pos_s := Vector3.ZERO
var look_s := Vector3.ZERO
var scale_k := 1.0
var rows: PackedStringArray = PackedStringArray(["t,mode,phase,speed,alt,bank_tan,legs_tuck,legs_fwd,bob,hz"])
var csv_path := ""

func _initialize() -> void:
	_run.call_deferred()

func _keys(mode: String, t: float, f) -> Dictionary:
	var k := {"flap": false, "dive": false, "pitch": 0.0, "turn": 0.0, "wingover": 0}
	match mode:
		"flapglide":
			k.flap = true
		"wingover":
			k.flap = t < 2.6 or t > 11.0
			if t >= 3.6 and t < 3.7:
				k.wingover = 1
		"land_flare", "land_run":
			k.flap = t < 2.4
	return k

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "flapglide"
	var secs: float = float(args[1]) if args.size() > 1 else 16.0
	scale_k = float(args[2]) if args.size() > 2 else 1.0
	csv_path = args[3] if args.size() > 3 else ""
	game = root.get_node("Game")
	game.settings.grass = 0
	game.settings.quality = "low"      # software GL: the clip is about the creature, the world only has to be there
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	var parsed := Scenario.read("creature/flight_cliff")
	game.pending_scenario = parsed
	island = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	for i in 20:
		await process_frame
	island.stage_ui.ui.visible = false
	var f = island.flight
	if mode == "land_run":
		f.landing_override = "run"
	elif mode == "land_flare":
		f.landing_override = "flare"
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.2
	cam.far = 1500.0
	root.add_child(cam)
	cam.current = true
	var bs: Dictionary = island.stage.sample(0)
	pos_s = bs.pos
	yaw_s = float(bs.yaw)
	var t := 0.0
	var dt := 1.0 / 24.0
	f.keys_override = {"flap": false, "dive": false, "pitch": 0.0, "turn": 0.0}
	f.press_space()
	var landed_t := -1.0
	var placed := false
	while t < secs:
		f.keys_override = _keys(mode, t, f)
		if not placed and t >= 2.6 and f.model.airborne() and mode != "flapglide":
			# the clip starts the manoeuvre from a set-up state (the island's cliff is tens of metres up): a wingover from 45 m at cruise
			# speed, a landing approach from 9 m at 1.3 x stall speed, both along the current heading
			placed = true
			var m0 = f.model
			var h0: Vector2 = Vector2(m0.vel.x, m0.vel.z).normalized()
			var sp: float = 1.3 * m0.stall_speed()
			var from := Vector2(m0.pos.x, m0.pos.z)
			if mode != "wingover":
				var spot := _flat_run(from, h0)
				from = spot.p
				h0 = spot.dir
				m0.pos.x = from.x
				m0.pos.z = from.y
				m0.yaw_dir = h0
			var gy: float = game.visual_ground(from.x, from.y)
			m0.pos.y = gy + float(m0.spec.com_h) + (45.0 if mode == "wingover" else 9.0)
			m0.vel = Vector3(h0.x * sp, 0.0, h0.y * sp)
			m0.bank_t = 0.0
		await process_frame
		t += dt
		_place_camera(dt, f)
		var m = f.model
		rows.append("%.2f,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.2f" % [t, m.mode, m.wo_phase, m.vel.length(), f.altitude(), m.bank_t, m.legs_tuck, m.legs_fwd, f.wing.bob() if f.wing != null else 0.0, f.beat_hz()])
		if m.mode == "ground" and t > 3.0:
			if landed_t < 0.0:
				landed_t = t
			elif t - landed_t > 2.0:
				break
	if csv_path != "":
		var fc := FileAccess.open(csv_path, FileAccess.WRITE)
		fc.store_string("\n".join(rows) + "\n")
		fc.close()
	quit(0)

# A flat stretch for the landing clips: the first start point (rings of 60 m out to 700 m, 12 headings) whose next 120 m of ground
# stays within 1.2 m of height and above the water line, so the flare has a level run-out. Falls back to the current spot.
func _flat_run(p0: Vector2, dir0: Vector2) -> Dictionary:
	# seed 1: a 140 m stretch of the valley floor within 0.7 m of height (found with a grid scan of the heightfield)
	var known := Vector2(21.2, -161.9)
	var kd := Vector2(-0.70711, 0.70711)
	var lo0 := 1e9
	var hi0 := -1e9
	for i in 15:
		var h0: float = game.visual_ground(known.x + kd.x * 10.0 * i, known.y + kd.y * 10.0 * i)
		lo0 = minf(lo0, h0)
		hi0 = maxf(hi0, h0)
	if hi0 - lo0 < 1.5:
		return {"p": known, "dir": kd}
	for d in range(0, 700, 40):
		for k in 12:
			var a := TAU * float(k) / 12.0 + atan2(dir0.x, dir0.y)
			var dir := Vector2(sin(a), cos(a))
			var p := p0 + dir * float(d)
			var lo := 1e9
			var hi := -1e9
			for i in 13:
				var q := p + dir * 10.0 * float(i)
				var h: float = game.visual_ground(q.x, q.y)
				lo = minf(lo, h)
				hi = maxf(hi, h)
			if hi - lo < 1.2 and lo > 3.0:
				return {"p": p, "dir": dir}
	return {"p": p0, "dir": dir0}

# Close three-quarter view from the creature's right-front, framing about 2.5 spans; follows heading with a lag so a wingover reads.
func _place_camera(dt: float, f) -> void:
	var p: Dictionary = island.player_sample()
	var span := 5.0
	var target: Vector3 = (p.pos as Vector3) + Vector3(0, 1.0, 0)
	if f.model != null and f.model.active():
		target = f.model.pos
		span = float(f.model.spec.span)
	var yaw := float(p.yaw)
	var k := 1.0 - exp(-dt / 0.35)
	yaw_s = lerp_angle(yaw_s, yaw, k)
	look_s = look_s.lerp(target, 1.0 - exp(-dt / 0.05)) if look_s != Vector3.ZERO else target
	var d := span * 1.55 * scale_k
	var fwd := Vector3(sin(yaw_s), 0, cos(yaw_s))
	var right := Vector3(-fwd.z, 0, fwd.x) * -1.0
	var want := look_s - fwd * d * 0.55 + right * d * 0.8 + Vector3(0, d * 0.28, 0)
	var g: float = game.visual_ground(want.x, want.z) + 0.8
	want.y = maxf(want.y, g)
	cam.global_position = want
	cam.look_at(look_s + Vector3(0, 0.0, 0), Vector3.UP)
