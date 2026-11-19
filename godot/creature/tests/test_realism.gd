extends SceneTree
## Headless tests of the realism pilot (CreatureBio, CreatureTuring, keratin UVs, actuation wiring).
##   godot --headless --path godot --script res://creature/tests/test_realism.gd
const Creatures := preload("res://creature/tools/realism_creatures.gd")

var checks := 0
var failures: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run()


func _build(g: Dictionary) -> Creature:
	var c := Creature.new()
	var r := c.load_genome(g)
	check(r["ok"], "genome builds: %s" % r.get("error", ""))
	return c


func _run() -> void:
	await process_frame
	# Turing: deterministic, different seeds differ, value range, tileable.
	var a := CreatureTuring.image(7, 2).get_data()
	var b := CreatureTuring.image(7, 2).get_data()
	var c := CreatureTuring.image(8, 2).get_data()
	check(a == b, "turing deterministic per seed")
	check(a != c, "turing differs between seeds")
	check(CreatureTuring.image(7, 1).get_data() != a, "turing differs between kinds")
	var f := CreatureTuring.field(7, 1)
	var lo := 1.0
	var hi := -1.0
	for v in f:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(lo >= -1.001 and hi <= 1.001 and hi - lo > 1.5, "turing field spans [-1,1] (%.2f..%.2f)" % [lo, hi])
	var ms: Array = []
	for i in 5:
		var t0 := Time.get_ticks_usec()
		CreatureTuring.field(100 + i, 1 + i % 3)
		ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	ms.sort()
	print("turing field build (48x48, 16 iterations): median %.1f ms" % ms[2])
	check(ms[2] < 50.0, "turing under 50 ms (%.1f)" % ms[2])
	# Renderer choice (A24): discrete GPUs go Forward+, software and integrated parts stay on Compatibility.
	var RC = load("res://game/render_choice.gd")
	check(RC.looks_discrete("NVIDIA GeForce RTX 5070 Ti", 0), "RTX is discrete")
	check(RC.looks_discrete("AMD Radeon RX 7800 XT", 0), "Radeon RX is discrete")
	check(not RC.looks_discrete("Mesa - llvmpipe (LLVM 23)", 0), "llvmpipe is not")
	check(not RC.looks_discrete("AMD Radeon 860M Graphics", 0), "integrated Radeon is not")
	check(not RC.looks_discrete("Intel(R) UHD Graphics", 0), "Intel UHD is not")
	check(RC.looks_discrete("Some GPU", RenderingDevice.DEVICE_TYPE_DISCRETE_GPU), "adapter type discrete wins")
	check(RC.decide()["relaunch"] == false, "a script run never relaunches")
	# Bio rules.
	# A24: skeleton per body, actuation per limb.
	var ids := {"hero": ["endo", "muscle"], "giant": ["endo", "muscle"], "spider": ["exo", "hydraulic"], "beetle": ["exo", "muscle"], "stilt": ["endo", "tendon"], "slug": ["hydro", ""]}
	for id in ids:
		var cr := _build(Creatures.genome(id))
		check(cr.bio["skeleton"] == ids[id][0], "%s skeleton %s (got %s)" % [id, ids[id][0], cr.bio["skeleton"]])
		if ids[id][1] != "":
			var leg_act := ""
			for i in cr.bio["limbs"]:
				if cr.bio["limbs"][i]["kind"] == "leg":
					leg_act = cr.bio["limbs"][i]["act"]
			check(leg_act == ids[id][1], "%s legs actuation %s (got %s)" % [id, ids[id][1], leg_act])
		var pal: Dictionary = cr.bio["palette"]
		var sk: Dictionary = cr.genome["skin"]
		check((pal["cA"] as Color).is_equal_approx(Color(sk["cA"])) and (pal["cB"] as Color).is_equal_approx(Color(sk["cB"])), "%s keeps the player's colours" % id)
		cr.free()
	# Venom parts mark a creature toxic (informational); colours are never touched.
	var gt := Creatures.genome("hero")
	gt.parts.append({"type": "aguijon", "t": 0.0, "ang": 0, "size": 1.0})
	var toxic := _build(gt)
	check(toxic.bio["toxic"] > .5, "aguijon makes a creature toxic")
	toxic.free()
	# Per-limb choice, skeleton choice, single part and pupil override survive validation and reach the build.
	var gl := Creatures.genome("hero")
	gl.parts[3]["act"] = "spring"
	gl.skin["sk"] = "exo"
	gl.parts[0]["pupil"] = "bar"
	var cl := _build(gl)
	check(cl.bio["skeleton"] == "endo" or cl.bio["skel_cands"].size() == 1, "skeleton choice ignored when not a candidate")
	var legs_act: Array = []
	for i in cl.bio["limbs"]:
		legs_act.append(cl.bio["limbs"][i]["act"])
	check("spring" in legs_act, "stored per-limb act is honoured when the skeleton allows it")
	cl.free()
	var gs := Creatures.genome("hero")
	var n_before := 0
	var cb := _build(gs)
	for e in cb.parts:
		if e["type"] == "cuerno":
			n_before += 1
	var horn_i := -1
	for i in gs.parts.size():
		if gs.parts[i]["type"] == "cuerno":
			horn_i = i
	gs.parts[horn_i]["single"] = 1
	var cs := _build(gs)
	var n_after := 0
	for e in cs.parts:
		if e["type"] == "cuerno":
			n_after += 1
	check(n_before == 2 and n_after == 1, "a single part builds one copy (%d -> %d)" % [n_before, n_after])
	cb.free()
	cs.free()
	var gb := Creatures.genome("hero")
	gb.parts[1]["single"] = 5
	check(not Creature.parse_genome(gb)["ok"], "single out of range is rejected")
	var gp := Creatures.genome("hero")
	gp.parts[1]["pupil"] = "star"
	check(not Creature.parse_genome(gp)["ok"], "unknown pupil is rejected")
	var herb := _build(Creatures.genome("giant"))
	check(herb.bio["pupil"] == "slit" and Creatures.genome("giant").parts.any(func(p): return p.type == "fauces"), "carnivore (fauces) gets slit pupils")
	herb.free()
	# Optional creator keys validate and reach the shader.
	var gk := Creatures.genome("hero")
	gk.skin["cs"] = .9
	gk.skin["ps"] = 1.5
	gk.skin["pc"] = .4
	gk.skin["ros"] = 1
	var ck := _build(gk)
	check(is_equal_approx(float(ck.materials.skin_body.get_shader_parameter("cs")), .9) and is_equal_approx(float(ck.materials.skin_body.get_shader_parameter("pc")), .4), "cs / pc reach the skin shader")
	var gbad := Creatures.genome("hero")
	gbad.skin["cs"] = 3
	check(not Creature.parse_genome(gbad)["ok"], "cs out of range is rejected")
	ck.free()
	# Seed is stable across edits that do not rename the creature, and differs per name.
	var h1 := _build(Creatures.genome("hero"))
	var gh := Creatures.genome("hero")
	gh.parts.append({"type": "pua", "t": .5, "ang": 0, "size": 1, "len": .5})
	var h2 := _build(gh)
	check(h1.bio["seed"] == h2.bio["seed"], "pattern seed survives part edits")
	check(h1.bio["seed"] != _seed_of("giant"), "pattern seed differs per creature")
	# Keratin parts get an along-axis UV, the body gets tube UVs.
	var any_uv := false
	for mi in h1.mesh_instances():
		if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader.resource_path.ends_with("keratin.gdshader"):
			var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
			any_uv = any_uv or (arr[Mesh.ARRAY_TEX_UV] != null and (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0)
	check(any_uv, "keratin meshes carry the along-axis UV")
	var body := (h1.body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	check(body[Mesh.ARRAY_TEX_UV] != null and body[Mesh.ARRAY_TEX_UV2] != null, "body tube has UV and UV2")
	# Limb copies: legs have their own flex material, updated by the solver.
	var leg: CreatureLegChain = h1.legs[0]
	check(leg.upper_mat != null and leg.upper_mat != h1.materials.skin, "leg segment has its own skin material")
	leg.solve_local(leg.home + Vector3(0, leg.upper_length * .6, 0))
	check(float(leg.upper_mat.get_shader_parameter("flex")) > .05, "knee flexion drives the muscle swell")
	# Build cost of the realism layer.
	var t0 := Time.get_ticks_usec()
	for i in 5:
		var tmp := _build(Creatures.genome("hero"))
		tmp.free()
	print("realism build (hero, cached pattern): %.1f ms per build" % ((Time.get_ticks_usec() - t0) / 5000.0))
	h1.free()
	h2.free()
	print("realism tests: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _seed_of(id: String) -> int:
	var cr := _build(Creatures.genome(id))
	var s: int = cr.bio["seed"]
	cr.free()
	return s
