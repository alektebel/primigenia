extends RefCounted

const Placement := preload("res://game/island/flora_placement.gd")
const Generator := preload("res://game/island/flora_mesh.gd")
const Terrain := preload("res://game/island/terrain_data.gd")
const Cache := preload("res://game/island/terrain_cache.gd")

func run(t) -> void:
	var rows := Placement.recipes()
	var ids := {}
	var props := preload("res://game/island/island_props.gd").new()
	for r in rows:
		t.check(not ids.has(r.id),"unique flora id "+r.id)
		ids[r.id] = true
		var canon: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../lore/flora/"+r.id+".json"))
		t.eq(r.form, canon.growth_form,"growth form "+r.id)
		t.eq(r.name, canon.name,"bilingual name "+r.id)
		t.eq(r.height, [canon.generator.height_m.min, canon.generator.height_m.max],"height "+r.id)
		var a := Generator.new().plant(r, 7, true)
		var b := Generator.new().plant(r, 7, true)
		t.eq(hash(a.surface_get_arrays(0)), hash(b.surface_get_arrays(0)),"identical mesh "+r.id)
		t.check(a.get_aabb().size.y > 0,"mesh extent "+r.id)
		if r.form == "moss_lichen":
			t.eq(a.surface_get_array_index_len(0), 36, "one thin colony fan " + r.id)
			var mat := a.surface_get_material(0) as ShaderMaterial
			t.eq(mat.shader, Generator.GROUND_COVER, "terrain layer material " + r.id)
			t.eq(mat.get_shader_parameter("moss"), r.has("glow"), "colony pigment " + r.id)
			t.check(r.relief_mm > 0 and r.relief_mm <= 3.0, "millimetre-scale colony relief " + r.id)
			t.check(is_equal_approx(mat.get_shader_parameter("relief_mm"), r.relief_mm), "colony relief uniform " + r.id)
		if r.id == "rodela_de_nieve":
			var mat := a.surface_get_material(0) as ShaderMaterial
			t.eq(mat.get_shader_parameter("leaf_margin"), Color(r.margin), "Snowshield margin pigment")
			var arrays := a.surface_get_arrays(0)
			var styles: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var has_column := false
			var has_skirt := false
			var cupped := false
			for ix in points.size():
				if styles[ix].x == -1 and points[ix].y >= r.caudex - 0.001:
					has_column = true
				if styles[ix].x == 0 and points[ix].y < r.caudex * 0.5:
					has_skirt = true
			for i in range(0, indices.size(), 3):
				var ix := indices[i]
				if styles[ix].x == -2 and normals[ix].dot(normals[indices[i+1]]) < 0.99:
					cupped = true
			t.check(has_column, "bark reaches the Snowshield crown")
			t.check(has_skirt, "retained leaves insulate the lower stem")
			t.check(cupped, "interpolated normals across living Snowshield blades")
			t.check(absf(a.get_aabb().end.y - 1.0) < 0.01, "living blades reach recipe height")
		if r.form in ["tree", "shrub"]:
			t.check(r.droop > 0 and r.droop < 1, "species limb droop " + r.id)
		if r.id == "nieblon":
			var upright: Dictionary = r.duplicate()
			upright.droop = 0.0
			t.check(hash(Generator.new().plant(upright, 7, true).surface_get_arrays(0)) != hash(a.surface_get_arrays(0)),
				"droop changes the baked limb geometry")
			props.recipe[r.id] = r
			var previous := 0
			var far_mesh := props.geometry(r.id, 0, false)
			for q in 3:
				props.tier = q
				var mesh := props.geometry(r.id, 0, true)
				var triangles := mesh.surface_get_array_index_len(0) / 3
				t.check(triangles > previous, "tier increases near tree detail %d" % q)
				t.eq(mesh, props.geometry(r.id, 0, true), "shared near mesh %d" % q)
				t.eq(far_mesh, props.geometry(r.id, 0, false), "shared distant silhouette %d" % q)
				previous = triangles
			props.tier = 0
			var arrays := props.geometry(r.id, 0, true).surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var styles: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var rounded_bark := false
			var rounded_leaves := false
			for i in range(0, indices.size(), 3):
				var first := indices[i]
				if normals[first].dot(normals[indices[i + 1]]) < 0.99:
					rounded_bark = rounded_bark or styles[first].x < 0.0
					rounded_leaves = rounded_leaves or styles[first].x > 1.5
			t.check(rounded_bark and rounded_leaves, "interpolated bark and crown normals")
	var canon_files := DirAccess.get_files_at(ProjectSettings.globalize_path("res://").path_join("../lore/flora").simplify_path())
	t.check(canon_files.size() >= rows.size(),"read lore directory")
	for file in canon_files:
		if file.ends_with(".json"):
			t.check(ids.has(file.get_basename()),"recipe for "+file)
	var d := Terrain.new()
	d.setup(Cache.get_or_build({"seed":1}).entry, false)
	var setup := {"nest": Vector2.ZERO,"wild":[{"x":64,"z":0}]}
	props.build_nest(d, setup.nest, 1)
	var nest_mesh: ArrayMesh = props.get_node("Nest").mesh
	var nest_styles: PackedVector2Array = nest_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	var has_down := false
	var has_scrape := false
	for uv in nest_styles:
		has_down = has_down or uv.x == -3
		has_scrape = has_scrape or uv.x == -4
	t.check(has_down and has_scrape, "nest down and scraped-earth hollow")
	t.eq(nest_mesh.get_surface_count(), 1, "nest weave shares a single surface")
	props.free()
	var start := Time.get_ticks_usec()
	var a := Placement.generate(d, setup, 1, 0.34, rows)
	print("  flora low placement %d instances in %.1f ms" % [a.size(), (Time.get_ticks_usec() - start) * 0.001])
	t.eq(hash(a), hash(Placement.generate(d, setup, 1, 0.34, rows)),"ordered instance list repeats")
	t.check(hash(a) != hash(Placement.generate(d, setup, 7, 0.34, rows)),"different seed changes layout")
	var violations := 0
	var counts := {}
	for obj in a:
		counts[obj.id] = counts.get(obj.id, 0) + 1
		var p: Vector3 = obj.p
		var k := d.cell_index(p.x, p.z)
		var normal := Placement.facet(d, Vector2(p.x, p.z))
		if d.is_pond(k) or d.is_river(k) or p.y < -0.65 or (d.is_sea(k) and obj.id != "cinta_de_marea"):
			violations += 1
		if absf(p.y - d.visual_ground(p.x, p.z)) > 0.0002 or normal.y < 1 / sqrt(1 + 1.26 * 1.26):
			violations += 1
		if not Placement.clear(Vector2(p.x, p.z), [setup.nest, Vector2(64, 0)]):
			violations += 1
	t.eq(violations, 0,"all roots clear water, steep facets, nest and spawns")
	t.eq(counts.get("madre_de_agua", 0), 1,"single spring tree")
	for id in ["nieblon","paja_dulce","scree","outcrop","boulder","velilla","vetirroja","perlilla","caramillo"]:
		t.check(counts.get(id, 0)>0,"placed "+id)
	print("  flora seed 1 ", counts)
	lava_habitats(t, d)

# Probe actual volcanic substrate across a controlled moisture gradient. Seed 1's
# shipped terrain disables the cone, so a default-island-only test misses this path.
func lava_habitats(t, d) -> void:
	var seen := {}
	var noise := FastNoiseLite.new()
	noise.seed = 7
	for x in range(-300, 300, 2):
		var p := Vector2(x, 400.0)
		var k: int = d.cell_index(p.x, p.y)
		var old_material: int = d.material[k]
		var old_wet: int = d.surface[k * 4 + 3]
		d.material[k] = 3
		for wet in [16, 100, 185]:
			d.surface[k * 4 + 3] = wet
			for zone in Placement.habitats(d, {"p":p,"k":k,"h":150,"sea":false,"up":Vector3.UP}, noise, Vector2.INF):
				seen[zone] = true
		d.material[k] = old_material
		d.surface[k * 4 + 3] = old_wet
	for zone in ["bare_lava","lava_crack","lava_seep","mineral_seep"]:
		t.check(seen.has(zone),"lava supports "+zone)
