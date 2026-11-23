extends SceneTree
# A59 bridge, studio projection and adapted replay contract. Software/headless.
const Profile := preload("res://game/stage/profile.gd")
const WorldLog := preload("res://game/stage/world_log.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL A59: ", label)
func _initialize() -> void:
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	for row in [["a_grazer", 51], ["b_runner", 51], ["c_sprawler", 56], ["d_knuckle", 51]]:
		var g: Dictionary = Profile.load_json("res://game/data/starters/%s.json" % row[0])
		var p: Dictionary = Profile.from_studio(g, manifest).profile
		print("A59 starter ", row[0], " grip=", p.grip_deg)
		check(int(p.grip_deg) == row[1], row[0] + " C projection")
		var setup: Dictionary = CporeWorld.default_setup(1)
		setup.terrain = 0
		setup.wild = []
		setup.player = p
		var w := CporeWorld.new()
		check(w.reset(setup) == 0, "adapted reset")
		check(float(w.state().entities[0].grip_deg) == float(p.grip_deg), "preview equals live C state")
		check(w.state().player.has("sliding"), "slip animation state")
		var log_text := WorldLog.write(setup, [{"verb": 1}])
		var parsed: Dictionary = WorldLog.parse(log_text)
		check(parsed.ok, "grip log parses")
		check(parsed.setup.player.grip_traits == p.grip_traits and parsed.setup.player.grip_legs == p.grip_legs, "grip survives log")
		var twin := CporeWorld.new()
		check(twin.reset(parsed.setup) == 0, "replay reset")
		check(w.state().hash == twin.state().hash, "adapted log initial hash")
		var f := FileAccess.open("/tmp/grip-%s.log" % row[0], FileAccess.WRITE)
		f.store_string(log_text)
		f.close()
		print("A59 replay hash ", row[0], " ", w.step({"verb": 1}))
	print("A59 grip: ", failures, " failures")
	call_deferred("quit", 1 if failures else 0)
