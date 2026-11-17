extends RefCounted
# StageWorld driven headless: the exported log replays in build/world_cli with identical hashes;
# interpolation; stage setup invariants.

const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const Profile := preload("res://game/stage/profile.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")

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
	var setup: Dictionary = StageSetup.build(data, 7, player, garfio)
	print("  setup nest ", setup.nest, " water ", setup.water, " wild ", setup.wild.size())
	t.check(StageSetup.dry(data, setup.nest.x, setup.nest.y) and StageSetup.clear_of_water(setup.nest.x, setup.nest.y, setup.water), "the nest is dry meadow outside the water circle")
	t.check(absf(setup.water.x) <= 195.0 and absf(setup.water.y) <= 195.0, "water circle centre inside the +-195 m area")
	t.eq(setup.wild.size(), 1, "one wild creature")
	if setup.wild.size() == 1:
		var home := Vector2(setup.wild[0].home_x, setup.wild[0].home_z)
		t.check(home.distance_to(setup.nest) >= 50.0, "Garfio spawns at least 50 m from the nest")
	var no_wild: Dictionary = StageSetup.build(data, 7, player, garfio, false)
	t.eq(no_wild.wild.size(), 0, "wild = false removes Garfio")

	var sw = StageWorld.new()
	t.eq(sw.reset(setup), 0, "reset with the island setup")
	var frame := [0]
	sw.input_provider = func() -> Dictionary:
		var k: int = sw.log_inputs.size()
		if k < 60:
			return {"verb": 3, "hx": 32767, "hz": 0, "sprint": k > 30}
		if k < 120:
			return {"verb": 3, "hx": -16000, "hz": 32767}
		if k < 210:
			return {"verb": 2, "x": 30.5, "z": -12.25, "sprint": 0}
		return {"verb": 1}
	for i in 300:
		sw.step_once()
	t.eq(sw.hashes.size(), 300, "300 ticks stepped")
	print("  player after 300 ticks: ", sw.cur.entities[0].x, " ", sw.cur.entities[0].z, " err ", sw.cur.error, " order ", sw.cur.order)
	t.check(sw.cur.entities[0].x != setup.nest.x or sw.cur.entities[0].z != setup.nest.y, "the player moved")
	var text: String = sw.export_log()
	var path := "user://m0-session.log"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var cli: String = t.build_path("world_cli")
	var r: Dictionary = t.exec(cli, ["--replay", ProjectSettings.globalize_path(path)])
	t.eq(r.rc, 0, "world_cli --replay accepts the Godot log")
	var lines: PackedStringArray = str(r.out).strip_edges().split("\n")
	t.eq(lines.size(), 300, "world_cli prints 300 hashes")
	var mism := 0
	for i in mini(lines.size(), 300):
		if lines[i].strip_edges() != sw.hashes[i]:
			mism += 1
	t.eq(mism, 0, "world_cli replay hashes equal the Godot session tick for tick")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Interpolation: alpha 0, .5, 1 against prev and cur.
	sw.ground_fn = func(x: float, z: float) -> float: return 5.0
	var a: Dictionary = sw.sample(0, 0.0)
	var m: Dictionary = sw.sample(0, 0.5)
	var b: Dictionary = sw.sample(0, 1.0)
	var pe: Dictionary = sw.prev.entities[0]
	var ce: Dictionary = sw.cur.entities[0]
	t.check(absf(a.pos.x - pe.x) < 1e-9 and absf(a.pos.z - pe.z) < 1e-9, "alpha 0 is the previous tick")
	t.check(absf(b.pos.x - ce.x) < 1e-9 and absf(b.pos.z - ce.z) < 1e-9, "alpha 1 is the current tick")
	t.check(Vector2(m.pos.x - (pe.x + ce.x) / 2.0, m.pos.z - (pe.z + ce.z) / 2.0).length() < 0.15 * Vector2(ce.x - pe.x, ce.z - pe.z).length() + 1e-9, "alpha .5 is near the midpoint (Hermite, C1)")
	t.eq(m.pos.y, 5.0, "height comes from ground_fn")
	# The accumulator: 0.25 s steps two ticks and keeps 0.05 s.
	var before: int = sw.hashes.size()
	t.eq(sw.advance(0.25), 2, "0.25 s advances two ticks")
	t.check(absf(sw.acc - 0.05) < 1e-9 and sw.hashes.size() == before + 2, "remainder kept")
	t.eq(sw.advance(5.0), 3, "a long frame is clamped to 0.25 s (plus the 0.05 s remainder)")
