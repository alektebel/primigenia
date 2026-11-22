extends SceneTree
## Chase and escape on the C stage (A39 / D-26): per body, walk and run speed of the player and Garfio, and whether a player
## fleeing Garfio at walk or sprint is caught, and whether a player sprinting at a timid Rondo reaches it.
##   godot --headless --path godot --script res://game/tests/chase_probe.gd
const Profile := preload("res://game/stage/profile.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")

func _initialize() -> void:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var garfio := StageSetup.garfio_profile(manifest)
	var species: Array = CporeWorld.species()
	print("PROBE garfio r_cm %s speed(profile) %.1f" % [str(garfio.get("radius_cm", 0)), float(garfio.speed)])
	for path in ["res://game/data/hatchling.json", "res://game/data/merodeador.json"]:
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		g.parts = g.parts.filter(func(p): return p.type in ["pico", "pata", "ojo"])
		if not g.parts.any(func(p): return p.type == "pico"):
			g.parts.append({"type": "pico", "t": 1.0, "ang": 0.0, "size": 1.0, "level": 1, "tier": 0})
		for p in g.parts: p["level"] = 1; p["tier"] = 0
		g.schema = "cpore.creature/5"
		var pr: Dictionary = Profile.from_studio(g, manifest).profile
		var name: String = path.get_file()
		for sprint in [false, true]:
			var r := _flee(pr, garfio, sprint)
			print("PROBE %s flee from Garfio sprint=%s: player v %.2f, Garfio v %.2f, start gap %.1f m, caught after %s of 600 ticks, end gap %.1f m" % [name, str(sprint), r.pv, r.wv, r.d0, str(r.caught), r.d1])
		for sprint in [false, true]:
			var r := _catch(pr, species[0].profile, sprint)
			print("PROBE %s chase Rondo sprint=%s: player v %.2f, Rondo v %.2f, final gap %.1f m, reached %s" % [name, str(sprint), r.pv, r.wv, r.gap, str(r.reached)])
	quit(0)

func _world(player: Dictionary, wild: Dictionary, species: int, z: float) -> CporeWorld:
	var w := CporeWorld.new()
	var s: Dictionary = CporeWorld.default_setup(3)
	s.terrain = 1
	s.nest = Vector2(0, 0)
	s.player = player
	s.wild = [{"x": 0.0, "z": z, "home_x": 0.0, "home_z": z, "species": species, "bot": -1, "profile": wild}]
	w.reset(s)
	return w

func _flee(player: Dictionary, garfio: Dictionary, sprint: bool) -> Dictionary:
	var w := _world(player, garfio, 3, 24.0)
	var pv := 0.0
	var wv := 0.0
	var n := 0
	var caught = "no"
	for t in 620:
		w.step({"verb": 1})   # WAIT through the 60 s patrol grace; Garfio roams meanwhile
	var d0 := _gap(w)
	for t in 600:
		var st: Dictionary = w.state()
		if int(st.active) >= 0:
			caught = str(t)
			break
		w.step({"verb": 3, "hx": 0, "hz": -32767, "sprint": sprint})
		st = w.state()
		pv = maxf(pv, float(st.entities[0].speed))
		wv = maxf(wv, float(st.entities[1].speed))
	return {"pv": pv, "wv": wv, "caught": caught, "d0": d0, "d1": _gap(w)}

func _gap(w: CporeWorld) -> float:
	var st: Dictionary = w.state()
	return Vector2(st.entities[0].x - st.entities[1].x, st.entities[0].z - st.entities[1].z).length()

func _catch(player: Dictionary, rondo: Dictionary, sprint: bool) -> Dictionary:
	var w := _world(player, rondo, 0, 30.0)
	var pv := 0.0
	var wv := 0.0
	var gap := 99.0
	var reached = "no"
	for t in 600:
		var st: Dictionary = w.state()
		var p: Dictionary = st.entities[0]
		var e: Dictionary = st.entities[1]
		gap = Vector2(p.x - e.x, p.z - e.z).length()
		if int(st.active) >= 0 or gap < 5.5:
			reached = str(t)
			break
		w.step({"verb": 4, "target": 1, "sprint": sprint})
		st = w.state()
		pv = maxf(pv, float(st.entities[0].speed))
		wv = maxf(wv, float(st.entities[1].speed))
	return {"pv": pv, "wv": wv, "gap": gap, "reached": reached}
