extends RefCounted
# profile.gd equals the JS projection (fixtures generated from web/engine/profile.js); data copies
# are byte-equal to their web sources.

const Profile := preload("res://game/stage/profile.gd")

func run(t) -> void:
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var expected: Dictionary = Profile.load_json("res://game/tests/fixtures/profile_expected.json")
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	for name in expected:
		var e: Dictionary = expected[name]
		var path: String = e.source
		var genome: Dictionary = Profile.load_json(root.path_join(path))
		var r: Dictionary = Profile.from_studio(genome, manifest)
		if e.has("error"):
			t.check(not r.ok and r.error == e.error, "%s: same error as JS (%s)" % [name, e.error])
			continue
		t.check(r.ok, name + " projects")
		for k in ["mouth", "charge", "spit", "tail", "guard", "hp", "stamina", "speed"]:
			t.eq(r.profile[k], e.profile[k], "%s.%s" % [name, k])
		t.eq(r.profile.radius_cm, e.profile.radiusCm, name + ".radius_cm")
	t.eq(Profile.js_round(2.5), 3, "js_round half up")
	var bad: Dictionary = Profile.from_studio({"schema": "x"}, manifest)
	t.check(not bad.ok, "wrong schema is rejected")
	# The Godot part table is the web one plus the Godot-only parts (wing_vane, wing_flap, fire_gland: procedural, no web builder).
	var gp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/parts.json"))
	var wp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("web/studio/parts.json")))
	var extras := ["wing_vane", "wing_flap", "fire_gland"]
	var kept: Array = gp.parts.filter(func(e): return not (e.id in extras))
	t.eq(kept, wp.parts, "res://game/data/parts.json holds every web part unchanged")
	t.eq(gp.parts.size() - kept.size(), extras.size(), "and exactly the Godot-only wings on top")
	for k in gp:
		if k != "parts":
			t.eq(gp[k], wp[k], "parts.json key %s is the web one" % k)
	var pairs := {"res://game/data/garfio.json": "web/stage/species/garfio.json",
		"res://game/data/garfio-combat.json": "web/stage/species/garfio-combat.json"}
	for copy in pairs:
		t.eq(FileAccess.get_file_as_bytes(copy), FileAccess.get_file_as_bytes(root.path_join(pairs[copy])), copy + " is byte-equal to " + pairs[copy])
