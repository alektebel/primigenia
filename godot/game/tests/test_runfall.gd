extends RefCounted
# Run and fall through the Godot layer: the run intent latched in C, the stamina in the state, and a slide off a cliff face with
# its fell event (type 27) reaching StageWorld.

const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const Profile := preload("res://game/stage/profile.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const RockViews := preload("res://game/tests/rock_views.gd")

func run(t) -> void:
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 256
	p.seed = 1
	var entry: Dictionary = CporeTerrain.new().generate(p)
	TerrainData.prepare(entry)
	var data = TerrainData.new()
	data.setup(entry, false)
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var genome: Dictionary = Profile.load_json("res://game/data/merodeador.json")
	var player: Dictionary = Profile.from_studio(genome, manifest).profile
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	var setup: Dictionary = StageSetup.build(data, 7, player, garfio, false, sw.world)
	t.eq(sw.reset(setup), 0, "run/fall session resets")
	# walking, then running: the C speed is 1.8x and the stamina drains
	var heading := {"verb": 3, "hx": 32767, "hz": 0, "sprint": 0, "run": 0}
	sw.input_provider = func() -> Dictionary: return heading
	for i in 25:
		sw.step_once()
	var walk_speed: float = sw.cur.entities[0].speed
	t.check(not bool(sw.cur.player.running) and int(sw.cur.player.stamina) == 1000, "not running: full run stamina")
	heading["run"] = 1
	for i in 25:
		sw.step_once()
	var run_speed: float = sw.cur.entities[0].speed
	t.check(bool(sw.cur.player.running) and int(sw.cur.player.stamina) < 1000, "run intent: running, stamina drains (%d)" % int(sw.cur.player.stamina))
	t.check(walk_speed > 0.5 and absf(run_speed / walk_speed - 1.8) < 0.1, "run speed is 1.8x walk (%.2f vs %.2f)" % [run_speed, walk_speed])
	heading["run"] = 0
	for i in 5:
		sw.step_once()
	t.check(not bool(sw.cur.player.running), "releasing Shift stops running")
	# a cliff face: the body falls instead of walking, and lands with a fell event
	var cliff: Dictionary = RockViews.find_cliff(data, true)
	if cliff.is_empty():
		cliff = RockViews.find_cliff(data, false)
	t.check(not cliff.is_empty(), "the seed-1 island has a cliff face")
	if cliff.is_empty():
		return
	t.eq(sw.debug_now({"op": 1, "id": 0, "x": cliff.x, "z": cliff.z}), 0, "teleport onto the cliff face")
	heading["run"] = 0
	var fell := false
	var saw_falling := false
	var damage := 0.0
	for i in 200:
		sw.step_once()
		saw_falling = saw_falling or bool(sw.cur.player.falling)
		for ev in sw.cur.get("social_events", []):
			if int(ev.type) == 27:
				fell = true
				damage = float(ev.value)
		if fell:
			break
	t.check(saw_falling, "direct movement on a 55-65 degree face starts a fall")
	t.check(fell and not bool(sw.cur.player.falling), "the fall ends with a fell event (type 27), damage %.1f" % damage)
	t.check(sw.sample(0).has("pos"), "sample() still interpolates after a fall")
