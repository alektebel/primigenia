extends SceneTree
## Bilateral guard (radial-bodies plan, S2): hashes the body mesh (vertex, normal, UV, UV2, bones, weights, indices),
## the skeleton rest and every part transform of the 3 seeds and every bilateral species genome in game/data.
##   godot --headless --path godot --script res://creature/tools/mesh_hashes.gd -- --write   (records the fixture)
##   godot --headless --path godot --script res://creature/tools/mesh_hashes.gd              (compares, exit 1 on a diff)
## test_radial.gd calls `compute()` too. The fixture was recorded BEFORE the radial refactor of creature.gd.

const FIXTURE := "res://creature/tests/fixtures/bilateral_mesh_hashes.json"
const SPECIES := ["acechalunas", "babosa", "espinodo", "garfio", "merodeador", "rondo", "zanco"]


static func _add(ctx: HashingContext, v) -> void:
	if v == null:
		return
	if v is PackedVector3Array or v is PackedVector2Array or v is PackedFloat32Array or v is PackedInt32Array or v is PackedColorArray:
		ctx.update(v.to_byte_array())
	elif v is PackedByteArray:
		ctx.update(v)


static func hash_creature(c: Creature) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var mesh: ArrayMesh = c.body_mesh.mesh
	var arrays := mesh.surface_get_arrays(0)
	for a in arrays:
		_add(ctx, a)
	ctx.update(var_to_bytes([c.ground_offset, c.skeleton.get_bone_count(), c.legs.size(), c.parts.size()]))
	for b in c.skeleton.get_bone_count():
		ctx.update(var_to_bytes([c.skeleton.get_bone_rest(b), c.skeleton.get_bone_parent(b)]))
	for e in c.parts:
		ctx.update(var_to_bytes([e["index"], e["side"], e["bone"], (e["node"] as Node3D).transform]))
	for l in c.legs:
		ctx.update(var_to_bytes([l.rest_knee, l.rest_foot, l.upper_length, l.lower_length, l.hip_bone]))
	for mi in c.mesh_instances():
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null and m != mesh:
			ctx.update(var_to_bytes(m.get_aabb()))
	return ctx.finish().hex_encode()


static func compute(root: Node) -> Dictionary:
	var out := {}
	var seeds := Creature.seeds()
	for k in seeds:
		out["seed:" + k] = _one(root, seeds[k])
	for id in SPECIES:
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))
		out["species:" + id] = _one(root, g)
	return out


static func _one(root: Node, g) -> String:
	var c := Creature.new()
	root.add_child(c)
	var r: Dictionary = c.load_genome(g)
	var h := hash_creature(c) if r["ok"] else "ERR " + str(r.get("error", ""))
	c.queue_free()
	return h


func _initialize() -> void:
	await process_frame
	var cur := compute(root)
	if "--write" in OS.get_cmdline_user_args():
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(cur, "  ", true) + "\n")
		f.close()
		print("wrote ", cur.size(), " hashes")
		quit(0)
		return
	var want = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var bad := 0
	for k in want:
		if cur.get(k) != want[k]:
			bad += 1
			printerr("DIFF ", k)
	print("bilateral mesh hashes: %d compared, %d differ" % [want.size(), bad])
	quit(0 if bad == 0 else 1)
