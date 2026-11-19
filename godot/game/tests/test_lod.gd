extends RefCounted
# Terrain chunks: LOD thresholds with hysteresis, mesh sizes, winding, culling boxes.

const Chunks := preload("res://game/island/terrain_chunks.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")

func run(t) -> void:
	# Rock quality tiers (PLAN-rock step 8): explicit settings win, "auto" reads the adapter.
	t.eq(Chunks.resolve_tier("low", "NVIDIA GeForce RTX 4090"), 1, "quality low is tier 1")
	t.eq(Chunks.resolve_tier("medium", "NVIDIA GeForce RTX 4090"), 2, "quality medium is tier 2")
	t.eq(Chunks.resolve_tier("high", "llvmpipe (LLVM 23.1.4, 256 bits)"), 3, "quality high is tier 3")
	for a in ["AMD Radeon(TM) 860M Graphics", "AMD Radeon 780M", "AMD Radeon Graphics (radeonsi, gfx1150, LLVM 23.1.4, DRM 3.64)", "Intel(R) UHD Graphics 630", "Intel(R) Arc(TM) Graphics", "Intel Iris Xe Graphics", "llvmpipe (LLVM 23.1.4, 256 bits)", "SwiftShader"]:
		t.eq(Chunks.resolve_tier("auto", a), 2, "auto on integrated or software GPU '%s' is medium" % a)
	for a in ["NVIDIA GeForce RTX 4070 Laptop GPU", "AMD Radeon RX 7900 XTX (radeonsi, navi31)", "AMD Radeon RX 7600M XT", "Apple M2"]:
		t.eq(Chunks.resolve_tier("auto", a), 3, "auto on discrete GPU '%s' is high" % a)
	t.eq(Chunks.resolve_tier("bogus", "NVIDIA GeForce RTX 4090"), 3, "an unknown setting behaves as auto")
	for n in ["low", "medium", "high"]:
		var sh: Shader = load("res://game/shaders/terrain_%s.gdshader" % n)
		t.check(sh != null and sh.code.contains("#define ROCK_TIER") and sh.code.contains("terrain_body.gdshaderinc"), "terrain_%s.gdshader is a tier variant of the body" % n)
	t.check(not (load("res://game/shaders/terrain_high.gdshader") as Shader).code.contains("cull_disabled"), "the grid shader culls back faces (only the skirt copy does not)")
	t.eq(Chunks.lod_for(140.0, 0), 0, "140 m stays LOD 0 (hysteresis)")
	t.eq(Chunks.lod_for(150.0, 0), 1, "150 m from LOD 0 goes to LOD 1")
	t.eq(Chunks.lod_for(1000.0, 0), 3, "1 km is LOD 3")
	t.eq(Chunks.lod_for(120.0, 1), 1, "120 m stays LOD 1 coming from 1 (10 % margin)")
	t.eq(Chunks.lod_for(110.0, 1), 0, "110 m returns to LOD 0")
	t.eq(Chunks.lod_for(9000.0, 0), 6, "far is LOD 6")
	var sizes := [257, 129, 65, 33, 17, 9, 5]
	for i in 7:
		var mesh: ArrayMesh = Chunks.build_lod_mesh(Chunks.STEPS[i], 0.87890625)
		var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		t.eq(v.size(), sizes[i] * sizes[i], "LOD %d grid vertices" % i)
		var s: PackedVector3Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
		t.eq(s.size(), 2 * (4 * (sizes[i] - 1)), "LOD %d skirt vertices" % i)
		if i == 0:
			var idx: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
			var a := v[idx[0]]
			var b := v[idx[1]]
			var c := v[idx[2]]
			t.check((b - a).cross(c - a).y < 0.0, "first triangle faces up under clockwise front faces")
			var a2 := v[idx[3]]
			var b2 := v[idx[4]]
			var c2 := v[idx[5]]
			t.check((b2 - a2).cross(c2 - a2).y < 0.0, "second triangle faces up")
	# custom_aabb contains the displaced heights of its chunk (128 grid).
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 128
	p.seed = 3
	var entry: Dictionary = CporeTerrain.new().generate(p)
	TerrainData.prepare(entry)
	var d = TerrainData.new()
	d.setup(entry, false)
	var out := 0
	for cj in d.chunks_per_side:
		for ci in d.chunks_per_side:
			var mn: float = d.chunk_bounds[(cj * d.chunks_per_side + ci) * 2]
			var mx: float = d.chunk_bounds[(cj * d.chunks_per_side + ci) * 2 + 1]
			var box := AABB(Vector3(0, mn - 64, 0), Vector3(64 * d.cell, mx - mn + 80, 64 * d.cell))   # as built in terrain_chunks.gd
			for b in range(0, 65, 4):
				for a in range(0, 65, 4):
					var hv: float = d.height[mini(cj * 64 + b, 127) * 128 + mini(ci * 64 + a, 127)]
					if hv < box.position.y or hv > box.end.y:
						out += 1
			# the visual heights of the chunk (visual_ground) are inside too
			for b in range(0, 225, 16):
				for a in range(0, 225, 16):
					var hv2: float = d.visual_ground(d.cell_center(ci * 64) - d.cell * 0.5 + a * d.vcell, d.cell_center(cj * 64) - d.cell * 0.5 + b * d.vcell)
					if hv2 < box.position.y or hv2 > box.end.y:
						out += 1
	t.eq(out, 0, "chunk culling boxes contain their heights")
