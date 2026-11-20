extends RefCounted
# The starter hatchling (DESIGN A29, motion-flight-plan S1): a ~1 m, ~30 kg body that reaches trot/gallop at play speeds.
# Merodeador is untouched (adult form, wild species).

const Profile := preload("res://game/stage/profile.gd")
const Morph := preload("res://locomotion/loco_morphology.gd")
const Gait := preload("res://locomotion/loco_gait.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")

func run(t) -> void:
	var game_script := FileAccess.get_file_as_string("res://game/game.gd")
	t.check(game_script.contains('return _read_genome("res://game/data/hatchling.json")'), "the default player genome is the hatchling")
	var g: Dictionary = Profile.load_json("res://game/data/hatchling.json")
	var c = load("res://creature/creature.gd").new()
	t.root.add_child(c)
	var res: Dictionary = c.load_genome(g)
	t.check(res.ok, "the hatchling genome is valid (%s)" % res.get("error", ""))
	if res.ok:
		var m = Morph.analyse(Adapter.loco_describe(c, 1.0))
		t.check(m.body_length >= 1.0 and m.body_length <= 1.25, "body length 1.0-1.25 m (%.2f)" % m.body_length)
		t.check(m.mass >= 25.0 and m.mass <= 45.0, "mass 25-45 kg (%.1f)" % m.mass)
		t.check(not m.graviportal and m.plan == &"quadruped", "a light quadruped, not graviportal")
		var walk := Gait.select(m, &"walk", Gait.froude(1.0, m.hip_height))
		var trot := Gait.select(m, &"walk", Gait.froude(1.8, m.hip_height))
		var play := Gait.select(m, &"walk", Gait.froude(4.0, m.hip_height))
		var sprint := Gait.select(m, &"walk", Gait.froude(8.84, m.hip_height))
		t.check(walk == &"walk" and trot == &"trot" and play == &"gallop" and sprint == &"gallop", "gaits at 1.0 / 1.8 / 4.0 / 8.84 m/s: %s %s %s %s" % [walk, trot, play, sprint])
	c.queue_free()
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var p: Dictionary = Profile.from_studio(g, manifest)
	t.check(p.ok and p.profile.radius_cm >= 40 and p.profile.radius_cm <= 60, "combat radius 40-60 cm (%s)" % p.profile.get("radius_cm"))
	var mero: Dictionary = Profile.load_json("res://game/data/merodeador.json")
	t.check(Profile.from_studio(mero, manifest).profile.radius_cm == 300, "Merodeador keeps its 300 cm radius")
