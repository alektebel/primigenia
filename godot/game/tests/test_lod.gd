extends RefCounted
# Terrain chunks: LOD thresholds with hysteresis, mesh sizes, winding, culling boxes.

const Chunks := preload("res://game/island/terrain_chunks.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")

func run(t) -> void:
	t.eq(Chunks.lod_for(260.0, 0), 0, "260 m stays LOD 0 (hysteresis)")
	t.eq(Chunks.lod_for(276.0, 0), 1, "276 m from LOD 0 goes to LOD 1")
	t.eq(Chunks.lod_for(1000.0, 0), 2, "1 km is LOD 2")
	t.eq(Chunks.lod_for(240.0, 1), 1, "240 m stays LOD 1 coming from 1 (10 % margin)")
	t.eq(Chunks.lod_for(224.0, 1), 0, "224 m returns to LOD 0")
	t.eq(Chunks.lod_for(9000.0, 0), 4, "far is LOD 4")
	var sizes := [65, 33, 17, 9, 5]
	for i in 5:
		var mesh: ArrayMesh = Chunks.build_lod_mesh(Chunks.STEPS[i], 3.5)
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
			var box := AABB(Vector3(0, mn - 64, 0), Vector3(64 * d.cell, mx - mn + 64, 64 * d.cell))
			for b in range(0, 65, 4):
				for a in range(0, 65, 4):
					var hv: float = d.height[mini(cj * 64 + b, 127) * 128 + mini(ci * 64 + a, 127)]
					if hv < box.position.y or hv > box.end.y:
						out += 1
	t.eq(out, 0, "chunk culling boxes contain their heights")
