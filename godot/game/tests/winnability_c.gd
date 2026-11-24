extends SceneTree
## Winnability of a genome against Garfio on the native C stage world (50 seeds, scripted competent player).
## The web test (tests/stage_winnability.mjs) cannot run: its World ABI is v2 and the C world is v3. Same idea: the
## player walks to Garfio, dodges charges, guards if it can, attacks in the recovery window. Window: 35-80 %.
##   godot --headless --path godot --script res://game/tests/winnability_c.gd -- [genome=res://game/data/hatchling.json]...
const Profile := preload("res://game/stage/profile.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const PRIORITY := [1, 4, 0, 3]   # charge, tail strike, spit, bite (CB_*)

func _initialize() -> void:
	var paths: Array = []
	var full := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("genome="): paths.append(a.substr(7))
		elif a == "full": full = true   # keep every part (mouths, horns, tail...) instead of the pico/pata/ojo starter loadout
	if paths.is_empty():
		paths = ["res://game/data/hatchling.json", "res://game/data/merodeador.json"]
	var manifest := Profile.load_json("res://game/data/parts.json")
	var garfio := StageSetup.garfio_profile(manifest)
	var bad := false
	for path in paths:
		for starter in [true]:
			var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not full:
				var cat := {}
				for mp in manifest.parts:
					cat[str(mp.id)] = str(mp.category)
				# the in-game starter loadout (island.gd): pico/pata/ojo plus the starter's own legs and details (mouths and weapons come from the nest)
				g.parts = g.parts.filter(func(p): return p.type in ["pico", "pata", "ojo"] or not cat.get(str(p.type), "") in ["mouths", "weapons"])
				if not g.parts.any(func(p): return p.type == "pico"):
					g.parts.append({"type": "pico", "t": 1.0, "ang": 0.0, "size": 1.0, "level": 1, "tier": 0})
			for p in g.parts: p["level"] = 1; p["tier"] = 0
			g.schema = "cpore.creature/5"
			var pr: Dictionary = Profile.from_studio(g, manifest).profile
			var out := {"victory": 0, "death": 0, "none": 0}
			for seed in 50:
				out[_fight(pr, garfio, seed)] += 1
			var rate: float = out.victory / 50.0
			var ok: bool = rate >= 0.35 and rate <= 0.80
			bad = bad or not ok
			print("%-34s %d/%d/%d/%d/%d hp %d r %d: %d/50 = %.0f %% %s %s" % [path.get_file(), pr.mouth, pr.charge, pr.spit, pr.tail, pr.guard, pr.hp, pr.radius_cm, out.victory, rate * 100.0, str(out), "OK" if ok else "OUT OF WINDOW"])
	quit(1 if bad else 0)

func _fight(player: Dictionary, garfio: Dictionary, seed: int) -> String:
	var w := CporeWorld.new()
	var s: Dictionary = CporeWorld.default_setup(seed)
	s.terrain = 1
	s.nest = Vector2(0, 0)
	s.player = player
	s.wild = [{"x": 0.0, "z": 12.0, "home_x": 0.0, "home_z": 12.0, "species": 3, "bot": -1, "profile": garfio}]
	if w.reset(s) != 0:
		return "none"
	for t in 900:
		var st: Dictionary = w.state()
		var o := int(st.outcome)
		if o != 0 and int(st.active) < 0:
			return "victory" if o == 1 else ("death" if o == 2 else "none")
		w.step(_policy(st, player))
	return "none"

func _policy(st: Dictionary, prof: Dictionary) -> Dictionary:
	if int(st.active) < 0:
		return {"verb": 4, "target": 1}
	var fs: Array = st.combat.fighters
	if fs.size() < 2:
		return {"verb": 4, "target": 1}
	var me: Dictionary = fs[0]
	var foe: Dictionary = fs[1]
	if int(foe.phase) == 1 and int(foe.move) == 1:
		return {"verb": 9, "dir": 1}
	if int(foe.phase) == 1 and int(prof.guard) > 0:
		return {"verb": 8}
	if int(foe.phase) == 3:
		var avail := [int(prof.charge) > 0, int(prof.mouth) > 0, int(prof.spit) > 0, int(prof.tail) > 0]
		var cd: Array = me.cooldowns
		for m in PRIORITY:
			var has: bool = (m == 1 and avail[0]) or (m == 0 and avail[1]) or (m == 3 and avail[2]) or (m == 4 and avail[3])
			if has and int(cd[m]) == 0:
				return {"verb": 5, "target": 1, "move": m}
		return {"verb": 5, "target": 1, "move": 0}
	return {"verb": 4, "target": 1}
