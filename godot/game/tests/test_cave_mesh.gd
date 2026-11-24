extends SceneTree

const CaveSite := preload("res://game/island/cave_site.gd")
var failed := false

func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		printerr("FAIL cave mesh: ", message)
	return ok

func digest(mesh: Dictionary) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for key in ["vertices", "normals", "indices"]:
		ctx.update(mesh[key].to_byte_array())
	return ctx.finish().hex_encode()

func local_point(site, world: Vector3) -> Vector3:
	var uv: Vector2 = site.frame(world.x, world.z)
	return Vector3(uv.y, world.y-site.floor_h, uv.x)

# Conservative test of the entire projected triangle, including its edges.
# Its local AABB must miss both the box and the disc whenever it spans headroom.
func overlaps_clearance(a: Vector3, b: Vector3, c: Vector3, site) -> bool:
	var lo := a.min(b).min(c)
	var hi := a.max(b).max(c)
	if hi.y <= 0.0001 or lo.y >= 2.5:
		return false
	var centre: float = site.length + site.radius
	if lo.z < centre and hi.z >= 0 and lo.x < site.half and hi.x > -site.half:
		return true
	var closest := Vector2(clampf(0, lo.x, hi.x), clampf(centre, lo.z, hi.z)-centre)
	return closest.length_squared() < site.radius*site.radius

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var params := {"enabled": true, "seed": 42, "x": 31.5, "z": -63.0, "fx": 0.6, "fz": -0.8,
		"floor": -6.375, "half": 4.0, "length": 14.0, "radius": 10.0, "chamber_x": 17.1,
		"chamber_z": -43.8, "mouth_half": 6.1, "mouth_height": 5.25}
	var site = CaveSite.from_state(params)
	var mesh := CporeTerrain.cave_mesh(params)
	var vertices: PackedVector3Array = mesh.vertices
	var normals: PackedVector3Array = mesh.normals
	var indices: PackedInt32Array = mesh.indices
	var triangles := indices.size() / 3
	check(triangles >= 20000 and triangles <= 60000, "triangle budget (%d)" % triangles)
	var sha := digest(mesh)
	var again := CporeTerrain.cave_mesh(params)
	check(digest(again) == sha and again == mesh, "repeatable mesh and anchors")
	var variant := params.duplicate()
	variant.seed += 1
	check(digest(CporeTerrain.cave_mesh(variant)) != sha, "seed changes the surface")

	var local := PackedVector3Array()
	for p in vertices:
		local.append(local_point(site, p))
	check(normals.size() == vertices.size(), "one normal per vertex")
	for n in normals:
		if not check(absf(n.length()-1) < 0.001, "unit shading normal"):
			break
	var faces := PackedVector3Array()
	var edges := {}
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		if overlaps_clearance(local[a], local[b], local[c], site):
			check(false, "triangle %d overlaps walkable clearance" % (i/3))
			break
		if maxf(local[a].y, maxf(local[b].y, local[c].y)) < 0.0001:
			var cross := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			if not check(cross.y < 0, "floor winds clockwise from above"):
				break
		faces.append(vertices[a])
		faces.append(vertices[b])
		faces.append(vertices[c])
		for j in 3:
			var v1 := indices[i+j]
			var v2 := indices[i+(j+1)%3]
			var key := Vector2i(mini(v1,v2), maxi(v1,v2))
			var incidence: Vector2i = edges.get(key, Vector2i.ZERO)
			edges[key] = incidence + Vector2i(1, 1 if v1 < v2 else -1)
	var rim_edges := 0
	for edge: Vector2i in edges:
		var count: Vector2i = edges[edge]
		if count.x == 1 and absf(local[edge.x].z) < 0.0001 and absf(local[edge.y].z) < 0.0001:
			rim_edges += 1
		elif not check(count == Vector2i(2,0), "inconsistent interior edge %s (%s)" % [edge, count]):
			break
	check(rim_edges > 0, "open rim at entrance")

	var surface := TriangleMesh.new()
	if not check(surface.create_from_faces(faces), "raycast acceleration structure"):
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1713
	var sampled := 0
	var blended := 0
	var worst := 0.0
	while sampled < 500:
		var uv := Vector2(rng.randf_range(0.001, 33.999), rng.randf_range(-10, 10))
		var pos: Vector2 = site._world(uv.x, uv.y)
		if site.zone(pos.x, pos.y) == 0:
			continue
		var floor_point := Vector3(pos.x, site.floor_h, pos.y)
		var hit := surface.intersect_segment(floor_point+Vector3.UP, floor_point+Vector3.DOWN)
		if not check(hit.has("position"), "missing floor at %s" % pos):
			break
		# adjust() takes raw height as input. Use raised terrain wherever the
		# override is full. In the 0.8 m blend band, check the specified flat floor.
		var expected: float = site.adjust(pos.x, pos.y, site.floor_h+12)
		if absf(expected-site.floor_h) > 0.00001:
			blended += 1
			if not check(absf(hit.position.y-site.floor_h) < 0.02, "flat floor in the terrain blend band"):
				break
			continue
		worst = maxf(worst, absf(hit.position.y-expected))
		sampled += 1
	check(sampled == 500 and worst <= 0.02, "500 floor hits within 2 cm")
	var lip: Vector2 = site._world(0.05, 0)
	var at_lip := Vector3(lip.x, site.floor_h, lip.y)
	var roof := surface.intersect_segment(at_lip+Vector3.UP, at_lip+Vector3.UP*10)
	check(roof.has("position") and absf(roof.position.y-at_lip.y-params.mouth_height) < 0.02, "mouth height")
	var across := Vector3(-site.fz, 0, site.fx)
	var side := surface.intersect_segment(at_lip+Vector3.UP, at_lip+Vector3.UP+across*10)
	check(side.has("position") and absf((side.position-at_lip).dot(across)-params.mouth_half) < 0.02, "mouth width")
	var forward := Vector3(-site.fx, 0, -site.fz)
	check(surface.intersect_segment(at_lip+Vector3.UP-forward, at_lip+Vector3.UP+forward*3).is_empty(), "open mouth")
	for pair in [["stalactites","stalactite_normals"], ["flowstone","flowstone_normals"]]:
		check(mesh[pair[0]].size() > 0 and mesh[pair[0]].size() == mesh[pair[1]].size(), "paired " + pair[0])
	for n in mesh.stalactite_normals:
		check(n.y < -0.72, "stalactite normal faces down")
	for n in mesh.flowstone_normals:
		check(absf(n.y) < 0.28, "flowstone normal faces sideways")
	check(mesh.wet_patches.size() > 0, "floor wet patches")
	print("Cave mesh: %d triangles, %d vertices, %d floor samples (plus %d blend band), max error %.6f m, SHA-256 %s" %
		[triangles, vertices.size(), sampled, blended, worst, sha])
	quit(1 if failed else 0)
