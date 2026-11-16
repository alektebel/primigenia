extends SceneTree
## Headless tests for the creature module (M1a).
##   godot --headless --path godot --script res://creature/tests/test_creature.gd
## Exit code 0 when every check passes.

const PARITY := "res://creature/tests/parity/expected.json"
const FIXTURES := "res://../tests/fixtures/studio/"
const WEB_STUDIO := "res://../web/studio/"

var checks := 0
var failures: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	_test_assets()
	_test_genome_parity()
	_test_growth_parity()
	_test_seeds_and_fixtures()
	_test_growth_placement()
	_test_every_part()
	_test_rig()
	print("creature tests: %d checks, %d failures (%d ms)" % [checks, failures.size(), Time.get_ticks_msec() - t0])
	quit(0 if failures.is_empty() else 1)


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path).simplify_path()


# ---------------------------------------------------------------- assets

func _test_assets() -> void:
	var lib := CreatureParts.library()
	check(lib["ok"], "part library loads (failures: %s %s)" % [lib["failures"], lib["error"]])
	var table: Dictionary = lib["table"]
	check(table.get("schema") == "cpore.studio-parts/1", "parts.json schema")
	check(table["parts"].size() == 46, "46 parts in parts.json (got %d)" % table["parts"].size())
	for entry in table["parts"]:
		check(lib["entries"].has(entry["id"]), "library entry " + entry["id"])
		if entry.has("file"):
			var path: String = CreatureParts.DEFAULT_ASSET_DIR + "parts/" + entry["file"]
			check(FileAccess.get_sha256(path) == entry["sha256"], "sha256 of " + entry["file"])
		if entry["source"] == "glb":
			check(not lib["templates"][entry["id"]].is_empty(), "GLB template " + entry["id"])
	# The copies must not drift from web/studio (when the web tree is present).
	var web := _abs(WEB_STUDIO + "parts.json")
	if FileAccess.file_exists(web):
		check(FileAccess.get_sha256(web) == FileAccess.get_sha256(CreatureParts.DEFAULT_ASSET_DIR + "parts.json"), "parts.json matches web/studio")
		check(FileAccess.get_sha256(_abs(WEB_STUDIO + "parts/manifest.json")) == FileAccess.get_sha256(CreatureParts.DEFAULT_ASSET_DIR + "parts/manifest.json"), "manifest.json matches web/studio")
	# Material regions of the GLB slots, as in docs/evidence/studio-v4-materials.md.
	var want := {"eye_stalk/Golden iris": "eye", "eye_stalk/Tidal teal skin": "skin", "lure_lantern/Lantern chartreuse": "glow",
		"lure_lantern/Cobalt chitin": "keratin", "shell_plate/Plum keratin": "keratin", "tongue_spring/Coral membrane": "membrane"}
	var seen := {}
	for s in lib["material_slots"]:
		seen[s["part"] + "/" + s["material"]] = s["region"]
	for k in want:
		check(seen.get(k) == want[k], "material region %s = %s (got %s)" % [k, want[k], seen.get(k)])
	check(lib["material_slots"].size() == 25, "25 GLB material slots (got %d)" % lib["material_slots"].size())


# ---------------------------------------------------------------- genome

static func same(a, b, tol := 1e-9) -> bool:
	var na := typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT
	var nb := typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT
	if na and nb:
		return abs(float(a) - float(b)) <= tol * max(1.0, abs(float(b)))
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k], tol):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i], tol):
				return false
		return true
	return a == b


func _test_genome_parity() -> void:
	var exp = JSON.parse_string(FileAccess.get_file_as_string(PARITY))
	check(typeof(exp) == TYPE_DICTIONARY, "parity file present (run gen_parity.cjs)")
	if typeof(exp) != TYPE_DICTIONARY:
		return
	var types: Dictionary = CreatureParts.library()["types"]
	for v in [1, 2, 3]:
		var legacy = JSON.parse_string(FileAccess.get_file_as_string(_abs(FIXTURES + "v%d.json" % v)))
		var res := CreatureGenome.parse(legacy, types)
		var want: Dictionary = exp["migrations"]["v%d" % v]
		check(res["ok"], "v%d migrates (%s)" % [v, res["error"]])
		check(same(res["genome"], want["genome"]), "v%d migration equals genome.js output" % v)
		check(same(res["warnings"], want["warnings"]), "v%d warnings equal genome.js" % v)
		check(res["genome"]["regions"].size() == (0 if v == 1 else 1), "v%d regions" % v)
		var again := CreatureGenome.parse(res["genome"], types)
		check(again["ok"] and same(again["genome"], res["genome"]), "v%d migration round trip" % v)
	var glb = JSON.parse_string(FileAccess.get_file_as_string(_abs(FIXTURES + "v4-glb-parts.json")))
	var r4 := CreatureGenome.parse(glb, types)
	check(r4["ok"] and same(r4["genome"], glb) and r4["warnings"].is_empty(), "saved /4 GLB-part document stays exact")
	for c in exp["errors"]:
		var res := CreatureGenome.parse(c["doc"], types)
		if c["error"] == null:
			check(res["ok"], "case %s accepted (got %s)" % [c["label"], res["error"]])
		else:
			check(not res["ok"] and res["error"] == c["error"], "case %s rejects with %s (got %s)" % [c["label"], c["error"], res["error"]])
	check(not CreatureGenome.parse("{broken", types)["ok"], "broken JSON rejected")
	check(not CreatureGenome.parse(null, types)["ok"], "null rejected")
	var text_ok := CreatureGenome.parse(JSON.stringify(Creature.seeds()["Zancuda"]), types)
	check(text_ok["ok"], "JSON text input accepted")


func _test_growth_parity() -> void:
	var exp = JSON.parse_string(FileAccess.get_file_as_string(PARITY))
	if typeof(exp) != TYPE_DICTIONARY:
		return
	check(CreatureGrowth.imul(0x9E3779B1, 7) == (0x9E3779B1 * 7) & 0xFFFFFFFF, "imul low bits")
	for case in exp["growth"]:
		var g := CreatureGrowth.generate(case["recipe"])
		check(g["ok"], "growth generates " + str(case["recipe"]))
		if not g["ok"]:
			continue
		check(g["pieces"].size() == case["pieces"].size(), "growth piece count " + case["recipe"]["family"])
		var worst := 0.0
		var idx_ok := true
		for i in min(g["pieces"].size(), case["pieces"].size()):
			var got: PackedVector3Array = g["pieces"][i]["positions"]
			var want: Array = case["pieces"][i]["positions"]
			if got.size() * 3 != want.size():
				worst = INF
				continue
			for k in got.size():
				for c in 3:
					worst = max(worst, abs(got[k][c] - want[k * 3 + c]))
			idx_ok = idx_ok and Array(g["pieces"][i]["indices"]) == case["pieces"][i]["indices"].map(func(x): return int(x))
			check(abs(g["pieces"][i]["offset"] - case["pieces"][i]["offset"]) < 1e-9, "growth offset")
		check(worst < 1e-4, "growth %s positions match growth.js (max err %f)" % [case["recipe"]["family"], worst])
		check(idx_ok, "growth indices")
	for bad in [{"count": 0}, {"count": 1.5}, {"count": 10000}, {"length": NAN}, {"seed": -1}, {"family": "unknown"}]:
		check(not CreatureGrowth.generate(bad)["ok"], "growth rejects " + str(bad))
	var a := CreatureGrowth.generate({"count": 2})
	var b := CreatureGrowth.generate({"count": 8})
	check(a["pieces"][0]["positions"] == b["pieces"][0]["positions"], "density preserves existing shapes")


# ---------------------------------------------------------------- creatures

func _creature_ok(c: Creature, label: String) -> void:
	var meshes := c.mesh_instances()
	check(meshes.size() > 0, label + ": has meshes")
	var bad := 0
	for mi in meshes:
		var m: Mesh = mi.mesh
		if m == null or m.get_surface_count() == 0:
			bad += 1
			continue
		var arr := m.surface_get_arrays(0)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for p in pos:
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
				bad += 1
				break
	check(bad == 0, label + ": every mesh built with finite vertices (%d bad)" % bad)
	check(c.skeleton.get_bone_count() >= 10, label + ": spine skeleton")
	for l in c.legs:
		check(abs(l.foot.position.y - l.hang) < 1e-3, label + ": %s foot on the ground at rest (y=%f hang=%f)" % [l.type, l.foot.position.y, l.hang])
	var box := c.rest_aabb()
	check(box.size.length() > .5 and box.size.length() < 60, label + ": sensible bounds " + str(box))


func _test_seeds_and_fixtures() -> void:
	var c := Creature.new()
	root.add_child(c)
	var expect := {"Merodeador": [8, 4], "Zancuda": [7, 2], "Babosa": [6, 0]}
	for name in Creature.seeds():
		var r := c.load_genome(Creature.seeds()[name])
		check(r["ok"], name + " parses")
		check(c.parts.size() == expect[name][0] and c.legs.size() == expect[name][1], "%s builds %d parts and %d legs (got %d, %d)" % [name, expect[name][0], expect[name][1], c.parts.size(), c.legs.size()])
		_creature_ok(c, name)
		check(not c.stats.is_empty() and c.stats["dna"] > 0, name + " stats")
	# rig.js stats for the seeds (computed by the web rig).
	c.load_genome(Creature.seeds()["Merodeador"])
	check(c.stats["dna"] == 25 + 5 + 15 + 25 + 25 + 8 * 3 + 2 * 5, "Merodeador dna cost %d" % c.stats["dna"])
	check(c.ground_offset == 0.0, "legged creature keeps its spine height")
	c.load_genome(Creature.seeds()["Babosa"])
	var bottom := _ring_bottom(c)
	check(c.legs.size() == 0 and abs(c.ground_offset - (.03 - bottom)) < 1e-6, "Babosa (legless) ground_offset = .03 - bottom (%f vs %f)" % [c.ground_offset, .03 - bottom])
	check(c.stats["dna"] == 15 + 10 + 20 + 10 + 10, "Babosa dna cost %d" % c.stats["dna"])
	c.load_genome(Creature.seeds()["Zancuda"])
	bottom = _ring_bottom(c)
	check(c.legs.size() > 0 and c.ground_offset == maxf(0.0, .03 - bottom), "Zancuda (legged) ground_offset = max(0, .03 - bottom) (%f)" % c.ground_offset)
	check(c.stats["dna"] == 20 + 5 + 25 + 12 + 10 + 10 + 2 * 5, "Zancuda dna cost %d" % c.stats["dna"])
	c.load_genome(Creature.seeds()["Merodeador"])
	bottom = _ring_bottom(c)
	check(c.ground_offset == maxf(0.0, .03 - bottom), "Merodeador ground_offset = max(0, .03 - bottom) (%f)" % c.ground_offset)
	for f in ["v1.json", "v2.json", "v3.json", "v4-glb-parts.json"]:
		var text := FileAccess.get_file_as_string(_abs(FIXTURES + f))
		var r := c.load_genome(text)
		check(r["ok"], "fixture %s loads (%s)" % [f, r["error"]])
		if r["ok"]:
			_creature_ok(c, f)
			if f != "v4-glb-parts.json":
				check(not c.warnings.is_empty(), f + " reports migration warnings")
	c.load_genome(FileAccess.get_file_as_string(_abs(FIXTURES + "v3.json")))
	check(c.growth.size() == 18, "v3 growth: 9 horns mirrored (got %d)" % c.growth.size())
	c.queue_free()


func _ring_bottom(c: Creature) -> float:
	var b := INF
	for i in Creature.NS:
		b = minf(b, c.rest[i].y - c.rad[i])
	return b


static func growth_doc(c_seed: Dictionary) -> Dictionary:
	var g: Dictionary = c_seed.duplicate(true)
	var base := {"schema": "cpore.growth/1", "seed": 17, "count": 7, "length": 1.0, "curve": .45, "branches": 1,
		"position": .6, "coverage": .4, "angle": .55, "mirror": true}
	var specs := [["plates", "torso", true], ["tendrils", "neck", true], ["horns", "tail", false]]
	var regions := []
	for i in specs.size():
		var r := base.duplicate()
		r["id"] = "region-%d" % (i + 1)
		r["family"] = specs[i][0]
		r["surface"] = specs[i][1]
		r["mirror"] = specs[i][2]
		regions.append(r)
	g["regions"] = regions
	return g


func _test_growth_placement() -> void:
	var c := Creature.new()
	root.add_child(c)
	var r := c.load_genome(growth_doc(Creature.seeds()["Zancuda"]))
	check(r["ok"], "growth doc parses (%s)" % r["error"])
	var by_id := {}
	for rg in c.genome["regions"]:
		by_id[rg["id"]] = rg
	var sides := {}
	var maxerr := 0.0
	for e in c.growth:
		var rg: Dictionary = by_id[e["region_id"]]
		var rr := Creature.region_range(rg["surface"])
		check(e["t"] >= rr.x - 1e-6 and e["t"] <= rr.y + 1e-6, "growth %s t %.3f inside %s range" % [e["region_id"], e["t"], rg["surface"]])
		var A := c.anchor(e["t"], float(rg["angle"]) * e["side"])
		var want: Vector3 = A["p"] - A["n"] * .01
		var got: Vector3 = c.skeleton.get_bone_global_rest(e["bone"]) * e["node"].position
		maxerr = maxf(maxerr, got.distance_to(want))
		check(got.distance_to(want) < 1e-4, "growth root on the surface (%f)" % got.distance_to(want))
		var key: String = e["region_id"]
		sides[key] = sides.get(key, []) + [e["side"]]
		var mat: Material = e["node"].get_child(0).material_override
		check(mat == (c.materials.skin if e["family"] == "tendrils" else c.materials.bone), "growth %s material" % e["family"])
	for id in by_id:
		var rg: Dictionary = by_id[id]
		var s: Array = sides.get(id, [])
		check(not s.is_empty(), "region %s produced pieces" % id)
		check(s.has(-1) == (rg["mirror"] and abs(float(rg["angle"])) > .04), "region %s mirrored roots only when mirror && |angle| > .04" % id)
		check(s.count(1) == s.count(-1) or not s.has(-1), "region %s has paired sides" % id)
	# A near-zero angle never mirrors, even with mirror = true.
	var g := growth_doc(Creature.seeds()["Zancuda"])
	g["regions"][0]["angle"] = .02
	c.load_genome(g)
	check(c.growth.filter(func(e): return e["region_id"] == "region-1" and e["side"] == -1).is_empty(), "angle .02 does not mirror")
	# v3 fixture: 9 horns mirrored on the torso.
	c.load_genome(FileAccess.get_file_as_string(_abs(FIXTURES + "v3.json")))
	check(c.growth.filter(func(e): return e["side"] == -1).size() == 9, "v3 has 9 mirrored roots")
	print("growth placement max error " + str(maxerr))
	c.queue_free()


func _test_every_part() -> void:
	var lib := CreatureParts.library()
	var c := Creature.new()
	root.add_child(c)
	var count := 0
	for seed_name in ["Merodeador", "Zancuda"]:
		for entry in lib["table"]["parts"]:
			var id: String = entry["id"]
			var g: Dictionary = Creature.seeds()[seed_name].duplicate(true)
			c.build(g)
			g["parts"].append(c.default_part(id))
			var r := CreatureGenome.parse(g, lib["types"])
			check(r["ok"], "%s on %s validates (%s)" % [id, seed_name, r["error"]])
			if not r["ok"]:
				continue
			c.build(r["genome"])
			var pi: int = g["parts"].size() - 1
			var nodes := 0
			var verts := 0
			for e in c.parts:
				if e["index"] == pi:
					nodes += 1
					for mi in _meshes(e["node"]):
						verts += mi.mesh.get_faces().size() if mi.mesh else 0
					# Root sits on (or just under) the body surface.
					var A := c.anchor(e["t"], e["side"] * e["ang"])
					var root_pos: Vector3 = c.skeleton.get_bone_global_rest(e["bone"]) * e["node"].position
					check(root_pos.distance_to(A["p"]) < .02, "%s root on the skin (%f)" % [id, root_pos.distance_to(A["p"])])
			for l in c.legs:
				if l.part_index == pi:
					nodes += 1
					for n in [l.upper, l.lower, l.foot]:
						for mi in _meshes(n):
							verts += mi.mesh.get_faces().size() if mi.mesh else 0
			var expected_nodes := 1 if abs(sin(float(g["parts"][pi]["ang"]))) < .14 and not c.maker.is_leg(id) else 2
			check(nodes == expected_nodes, "%s on %s attaches %d instance(s) (got %d)" % [id, seed_name, expected_nodes, nodes])
			check(verts > 0, "%s on %s has geometry" % [id, seed_name])
			_creature_ok(c, id + "@" + seed_name)
			count += 1
	check(count == 92, "46 parts x 2 seeds built (got %d)" % count)
	c.queue_free()


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for k in n.get_children():
		out.append_array(_meshes(k))
	return out


# ---------------------------------------------------------------- rig

func _test_rig() -> void:
	var c := Creature.new()
	root.add_child(c)
	c.load_genome(Creature.seeds()["Merodeador"])
	check(c.tail_bones.size() > 0 and c.neck_bones.size() > 0 and c.torso_bones.size() > 0 and c.head_bone >= 0, "bone groups present")
	check(c.skeleton.get_bone_parent(c.root_bone) == -1, "root bone has no parent")
	var md := c.mass_data()
	check(md["segments"].size() == Creature.NS - 1 and md["volume"] > 0 and md["parts"].size() == 12 and md["legs"].size() == 4, "mass data")
	# IK: the rest foot target reproduces the rest ankle; a nearer target bends the knee.
	var reach_exact := 0
	var reach_clamped := 0
	for l in c.legs:
		var rest_ankle: Vector3 = l.ankle
		l.solve()
		if rest_ankle.distance_to(l.hip) <= l.total_length() - .011:
			reach_exact += 1
			check(l.ankle.distance_to(rest_ankle) < .02, "IK reaches the rest target (%f)" % l.ankle.distance_to(rest_ankle))
		else:
			reach_clamped += 1
			check(l.hip.distance_to(l.ankle) <= l.total_length(), "IK clamps an over-long rest target")
		check(abs(l.hip.distance_to(l.knee) - l.upper_length) < 1e-3 and abs(l.knee.distance_to(l.ankle) - l.lower_length) < 1e-3, "IK keeps bone lengths")
		l.foot_target = c.transform * (l.hip + Vector3(0, -l.total_length() * .6, .2))
		l.solve()
		check(abs(l.hip.distance_to(l.knee) - l.upper_length) < 1e-3, "IK bent pose keeps the thigh length")
		check((l.ankle - (c.transform.affine_inverse() * l.foot_target + Vector3(0, l.width * .6, 0))).length() < 1e-3, "IK reaches a near target")
		l.foot_target = c.transform * (l.hip + Vector3(0, -50, 0))
		var ratio: float = l.solve()
		check(ratio <= 1.0 and l.hip.distance_to(l.ankle) <= l.total_length(), "IK clamps an out-of-reach target")
	print("IK rest branches: %d exact, %d clamped" % [reach_exact, reach_clamped])
	# Bending the neck moves the head parts with it (BoneAttachment3D).
	var eye: Dictionary = c.parts.filter(func(e): return e["type"] == "ojo")[0]
	var before: Vector3 = eye["node"].global_position
	for b in c.neck_bones:
		c.skeleton.set_bone_pose_rotation(b, c.skeleton.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3.UP, .25))
	c.skeleton.force_update_all_bone_transforms()
	var bone_moved := c.skeleton.get_bone_global_pose(c.head_bone).origin.distance_to(c.skeleton.get_bone_global_rest(c.head_bone).origin)
	check(bone_moved > .05, "neck rotation moves the head bone (%f)" % bone_moved)
	c.reset_spine_pose()
	c.skeleton.force_update_all_bone_transforms()
	check(c.skeleton.get_bone_global_pose(c.head_bone).origin.distance_to(c.skeleton.get_bone_global_rest(c.head_bone).origin) < 1e-4, "reset_spine_pose restores the rest")
	check(before.is_finite(), "eye placed")
	check(c.animation_hooks().size() >= 3, "animation hooks (jaw, lids)")
	c.queue_free()
