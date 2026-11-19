extends SceneTree
## Radial body plan tests (S2, docs/godot/CREATURE-RADIAL.md).
##   godot --headless --path godot --script res://creature/tests/test_radial.gd
const MeshHashes := preload("res://creature/tools/mesh_hashes.gd")
const SPECIES := ["brujula", "cuarteta", "corona"]

var checks := 0
var failures: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run()


func _genome(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))


func _build(g: Dictionary) -> Creature:
	var c := Creature.new()
	root.add_child(c)
	var r := c.load_genome(g)
	check(r["ok"], "genome %s loads (%s)" % [g.get("name"), r["error"]])
	return c


func _run() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	_test_bilateral_guard()
	for id in SPECIES:
		_test_species(id)
	_test_copies()
	_test_rotation()
	_test_ground()
	_test_uv_symmetry()
	_test_every_part()
	_test_folds()
	_test_build_time()
	_test_rig()
	_test_driver()
	print("radial tests: %d checks, %d failures (%d ms)" % [checks, failures.size(), Time.get_ticks_msec() - t0])
	quit(0 if failures.is_empty() else 1)


## The hash fixture was recorded before the radial work; bilateral bodies must be byte-identical.
func _test_bilateral_guard() -> void:
	var want = JSON.parse_string(FileAccess.get_file_as_string(MeshHashes.FIXTURE))
	var cur: Dictionary = MeshHashes.compute(root)
	check(want.size() >= 10, "bilateral hash fixture present")
	for k in want:
		check(cur.get(k) == want[k], "bilateral mesh unchanged: " + k)


func _test_species(id: String) -> void:
	var c := _build(_genome(id))
	check(c.plan_kind == "radial" and c.radial != null, id + " is radial")
	check(c.legs.is_empty(), id + " has no legs")
	var fold: int = int(_genome(id)["plan"]["fold"])
	check(c.radial.arm_bones.size() == fold and c.radial.arm_bones[0].size() == 6, id + " has fold arms of 6 bones")
	var arr: Array = c.body_mesh.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var bad := 0
	for i in range(0, idx.size(), 3):
		var fn := (v[idx[i + 2]] - v[idx[i]]).cross(v[idx[i + 1]] - v[idx[i]])
		if fn.length() > 1e-9 and fn.normalized().dot(n[idx[i]]) <= 0:
			bad += 1
	check(bad * 50 < idx.size() / 3, "%s faces wound outward (%d wrong of %d)" % [id, bad, idx.size() / 3])
	var finite := true
	for p in v:
		finite = finite and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
	check(finite, id + " finite vertices")
	check(v.size() <= 72 * fold * 12 + fold * 21 * 12, "%s vertex budget (%d)" % [id, v.size()])
	check(arr[Mesh.ARRAY_BONES] != null and arr[Mesh.ARRAY_BONES].size() == v.size() * 4, id + " skinned")
	var md := c.mass_data()
	check(md.has("arms") and md["arms"].size() == fold and c.body_volume() > 0.0, id + " mass data has arms")
	check(c.bio["legs"] == 0 and c.bio["arms"] == fold, id + " bio: no legs, fold arms")
	c.queue_free()


## A non-axial part is replicated `fold` times at 2 pi k / fold; axial parts and `single` give one copy.
func _test_copies() -> void:
	var g := _genome("brujula")
	g["parts"].append({"type": "ojo", "t": .5, "ang": .3, "size": 1.0, "level": 1, "tier": 0, "single": 1})
	var c := _build(g)
	var fold := 5
	for pi in g["parts"].size():
		var es: Array = c.parts.filter(func(e): return e["index"] == pi)
		var p: Dictionary = g["parts"][pi]
		var axial := float(p["t"]) <= .04 or float(p["t"]) >= .96
		var want := 1 if (axial or p.get("single", 0) != 0) else fold
		check(es.size() == want, "part %d (%s) has %d copies (got %d)" % [pi, p["type"], want, es.size()])
		if want == fold:
			var bearings := []
			for e in es:
				var q: Vector3 = c.skeleton.get_bone_global_rest(e["bone"]) * (e["node"] as Node3D).position
				bearings.append(fposmod(atan2(q.x, q.z) - float(p["ang"]), TAU))
			for b in bearings:
				var off := fposmod(float(b) + 1e-3, TAU / fold)
				check(off < 2e-3, "part %d copy at a bearing 2 pi k/fold (off %f)" % [pi, off])
			bearings = bearings.map(func(b): return snappedf(float(b) / (TAU / fold), .01))
			bearings = bearings.map(func(b): return fposmod(float(b) + .005, float(fold)))
			var seen := {}
			for b in bearings:
				seen[int(float(b))] = true
			check(seen.size() == fold, "part %d copies cover all %d sectors" % [pi, fold])
	c.queue_free()


func _part_points(c: Creature) -> Array:
	var pts := []
	for e in c.parts:
		var q: Vector3 = c.skeleton.get_bone_global_rest(e["bone"]) * (e["node"] as Node3D).position
		pts.append("%d:%.3f,%.3f,%.3f" % [e["index"], q.x, q.y, q.z])
	pts.sort()
	return pts


## Rotating every part by one sector gives the same set of parts, and the body mesh does not depend on it.
func _test_rotation() -> void:
	var g := _genome("corona")
	var fold := int(g["plan"]["fold"])
	var a := _build(g)
	var g2 := g.duplicate(true)
	for p in g2["parts"]:
		var ang := float(p["ang"]) + TAU / fold
		p["ang"] = ang - TAU if ang > PI else ang
	var b := _build(g2)
	check(_part_points(a) == _part_points(b), "rotating parts by 2 pi/fold gives the same parts")
	check(a.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == b.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "same body mesh")
	a.queue_free()
	b.queue_free()


func _test_ground() -> void:
	for id in ["brujula", "corona"]:
		var g := _genome(id)
		var c := _build(g)
		var v: PackedVector3Array = c.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var low := 1e9
		for p in v:
			low = minf(low, p.y + c.ground_offset)
		check(low >= .01 and low <= .04, "%s lowest vertex %.3f m above the ground" % [id, low])
		# Arm tips: the vertices beyond the disc margin at each arm bearing stay near the ground plane.
		var tip_low := 0.0
		for k in c.radial.fold:
			var ext := 0.0
			for p in v:
				ext = maxf(ext, RadialDir.dot(p, TAU * k / c.radial.fold))
			var bottom := 1e9
			for p in v:
				var d := RadialDir.dot(p, TAU * k / c.radial.fold)
				if d > ext - .08 and absf(p.x * cos(TAU * k / c.radial.fold) - p.z * sin(TAU * k / c.radial.fold)) < .05:
					bottom = minf(bottom, p.y + c.ground_offset)
			tip_low = maxf(tip_low, bottom)
		if id == "brujula":
			check(tip_low <= .02 + .03, "%s arm tips within 3 cm of the ground plane (%.3f)" % [id, tip_low])
		c.queue_free()


## The pattern coordinate is mirrored inside each sector: uv(theta) == uv(2 pi/fold - theta) (D_fold symmetry).
func _test_uv_symmetry() -> void:
	for id in SPECIES:
		var c := _build(_genome(id))
		var rn: int = c.radial.rn
		var uv: PackedVector2Array = c.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var worst := 0.0
		for i in Creature.NS:
			for j in rn:
				worst = maxf(worst, absf(uv[i * rn + j].y - uv[i * rn + (rn - j) % rn].y))
				worst = maxf(worst, absf(uv[i * rn + j].x - uv[i * rn + (rn - j) % rn].x))
		check(worst < 1e-5, "%s pattern UV is mirror-symmetric (%f)" % [id, worst])
		c.queue_free()


func _test_every_part() -> void:
	var lib := CreatureParts.library()
	var base := _genome("brujula")
	var c := Creature.new()
	root.add_child(c)
	c.build(base)
	var count := 0
	for entry in lib["table"]["parts"]:
		var id: String = entry["id"]
		if id in CreatureGenome.RADIAL_LEG_TYPES:
			continue
		var g := base.duplicate(true)
		var dp := c.default_part(id)
		dp["level"] = 1
		dp["tier"] = 0
		dp["t"] = .6 if float(dp["t"]) > .96 or float(dp["t"]) < .04 else dp["t"]
		g["parts"].append(dp)
		var r := CreatureGenome.parse(g, lib["types"])
		check(r["ok"], "%s validates on a radial body (%s)" % [id, r["error"]])
		if not r["ok"]:
			continue
		c.build(r["genome"])
		var pi: int = g["parts"].size() - 1
		var nodes := 0
		var verts := 0
		for e in c.parts:
			if e["index"] == pi:
				nodes += 1
				for mi in c.mesh_instances():
					pass
				verts += _faces(e["node"])
		check(nodes == 5, "%s is replicated 5 times (got %d)" % [id, nodes])
		check(verts > 0, id + " has geometry on a radial body")
		check(c.body_mesh != null and c.plan_kind == "radial", id + " body ok")
		count += 1
	check(count >= 36, "%d non-leg parts built on a radial body" % count)
	c.queue_free()


func _faces(n: Node) -> int:
	var f := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		f += (n as MeshInstance3D).mesh.get_faces().size()
	for ch in n.get_children():
		f += _faces(ch)
	return f


## Every fold 3..8 builds with a body mesh whose ring count matches.
func _test_folds() -> void:
	for fold in [3, 4, 6, 7, 8]:
		var g := _genome("brujula")
		g["plan"]["fold"] = fold
		var c := _build(g)
		check(c.radial.arm_bones.size() == fold and c.radial.rn == fold * 12, "fold %d builds" % fold)
		c.queue_free()


## Warm build budget (plan S2: <= 1.3 x the hero's 23.6 ms; the test bound is loose because machines vary).
func _test_build_time() -> void:
	for id in SPECIES:
		var c := _build(_genome(id))
		var ts := []
		for i in 5:
			var t0 := Time.get_ticks_usec()
			c.build(_genome(id))
			ts.append((Time.get_ticks_usec() - t0) / 1000.0)
		ts.sort()
		print("radial build time %s: median %.1f ms" % [id, ts[2]])
		check(ts[2] < 90.0, "%s warm build %.1f ms" % [id, ts[2]])
		c.queue_free()


## S3 on the real rig: describe, step the gait generator, write the pose into the skeleton.
func _test_rig() -> void:
	var Adapter = load("res://locomotion/loco_rig_adapter.gd")
	var Radial = load("res://locomotion/loco_radial.gd")
	for id in SPECIES:
		var c := _build(_genome(id))
		var desc: Dictionary = Adapter.radial_describe(c, 1.0)
		check(desc.problems.is_empty() and desc.radial.fold == c.radial.fold, id + " radial_describe contract")
		var loco = Radial.new(desc, func(_x, _z): return 0.0)
		loco.reset(Vector3.ZERO, 0.3)
		var rest_tip: Vector3 = c.skeleton.get_bone_global_pose(c.radial.arm_bones[0][5]).origin
		var moved := 0.0
		var ok := true
		for i in 240:
			loco.step(1.0 / 60.0, Vector3(0, 0, i / 60.0), 0.3, Vector3(sin(.3), 0, cos(.3)) * (1.2 if id == "brujula" else .3))
			Adapter.loco_apply(c, loco.pose, desc)
			for k in c.radial.fold:
				var o: Vector3 = c.skeleton.get_bone_global_pose(c.radial.arm_bones[k][5]).origin
				ok = ok and o.is_finite()
				moved = maxf(moved, o.distance_to(c.skeleton.get_bone_global_rest(c.radial.arm_bones[k][5]).origin))
		check(ok, id + " arm bones stay finite while moving")
		check(moved > .001, "%s arms move (%.3f m)" % [id, moved])
		var reach: float = c.rest_aabb().size.x
		check(is_finite(reach) and reach > .3, id + " mesh stays sane while posed")
		c.queue_free()


## The actor driver picks loco_radial for a radial body (S3), and a legged body still gets the usual controller.
func _test_driver() -> void:
	var Driver = load("res://game/actors/actor_driver.gd")
	var c := _build(_genome("brujula"))
	var host := Node3D.new()
	root.add_child(host)
	var d = Driver.new()
	d.setup(host, c, false, func(_x, _z): return 0.0)
	check(d.controller != null and d.controller.get_script() == load("res://locomotion/loco_radial.gd"), "ActorDriver uses loco_radial for a radial body")
	check(d.layer == null and d.problems.is_empty(), "no action layer for radial bodies yet, no contract problems")
	var before := c.global_position
	for i in 120:
		d.update(1.0 / 60.0, {"pos": Vector3(0, 0, i * .02), "yaw": 0.0, "speed": 1.2, "vel": Vector3(0, 0, 1.2)})
	check(c.global_position.is_finite() and c.global_position.distance_to(before) > .5, "the driven creature follows the world position")
	host.queue_free()
	c.queue_free()
	var m := _build(Creature.seeds()["Merodeador"])
	var h2 := Node3D.new()
	root.add_child(h2)
	var d2 = Driver.new()
	d2.setup(h2, m, false, func(_x, _z): return 0.0)
	check(d2.controller != null and d2.controller.get_script() == load("res://locomotion/loco_controller.gd"), "a bilateral body still gets the legged controller")
	h2.queue_free()
	m.queue_free()


class RadialDir:
	static func dot(p: Vector3, ang: float) -> float:
		return p.x * sin(ang) + p.z * cos(ang)
