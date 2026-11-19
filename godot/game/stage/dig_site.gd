extends Node3D
## What digging looks like (first-quest, docs/godot/FIRST-QUEST.md). C owns the beds, the holes and the dig itself (core/src/stage_dig.c);
## this draws them. A fossil bed reads before you dig it: cracked dry soil, a patch of paler grass, bone splinters and glassy flecks
## sticking out, a faint dust puff now and then, and (close up) the key. A hole is a dark pit with a rim and soil piles. While you
## dig, soil flies from under your front feet. Presentation only: nothing here feeds back into the world except the order itself.

const Strings := preload("res://ui/strings.gd")

const NEAR_LABEL := 7.0       # metres within which a bed shows its key
const PUFF_RANGE := 80.0      # metres within which a bed puffs dust

var stage: Node
var ground: Callable
var _beds := {}               # bed id -> {root, puff, label}
var _holes := {}              # "x,z" -> Node3D
var _dig_fx: CPUParticles3D
var _was_digging := 0

static func _mat(color: Color, rough := 0.95, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _piece(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func setup(bridge: Node, ground_fn: Callable) -> void:
	stage = bridge
	ground = ground_fn
	for b in stage.cur.get("dig", {}).get("beds", []):
		_build_bed(b)
	for h in stage.cur.get("dig", {}).get("holes", []):
		_build_hole(h)
	_dig_fx = _soil_burst()
	add_child(_dig_fx)
	stage.ticked.connect(_tick)

# --- the bed ---------------------------------------------------------------------------------------------------------

func _build_bed(b: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + int(b.id) * 131
	var root := Node3D.new()
	root.name = "Bed%d" % int(b.id)
	add_child(root)
	var cx: float = b.x
	var cz: float = b.z
	var wing := int(b.kind) == 0
	var patch := _mat(Color("8b8a4d") if wing else Color("7c8a52"), 1.0)         # paler, drier grass than the meadow
	var dry := _mat(Color("b9a47a"), 1.0)
	var crack := _mat(Color("2a2118"), 1.0)
	var bone := _mat(Color("e4d8b9"), 0.75)
	var glass := _mat(Color("1b2128"), 0.12, 0.55)
	var r: float = b.r
	# patches of dry soil, each on the ground under it
	for i in 9:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.85
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		var disc := CylinderMesh.new()
		disc.top_radius = rng.randf_range(0.55, 1.0)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.03
		disc.radial_segments = 14
		_piece(root, disc, dry if i % 3 else patch, Vector3(x, ground.call(x, z) + 0.03, z), Vector3(0, rng.randf() * TAU, 0))
	# cracks: thin dark slivers fanning out from the middle
	for i in 11:
		var a := rng.randf() * TAU
		var len := rng.randf_range(0.7, 1.9)
		var d0 := rng.randf_range(0.2, r * 0.6)
		var x := cx + cos(a) * d0
		var z := cz + sin(a) * d0
		var box := BoxMesh.new()
		box.size = Vector3(len, 0.012, 0.045)
		var mi := _piece(root, box, crack, Vector3(x, ground.call(x, z) + 0.05, z), Vector3(0, -a + rng.randf_range(-0.4, 0.4), 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# bone splinters sticking out of the ground
	for i in (7 if wing else 4):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, r * 0.55)
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		var cap := CapsuleMesh.new()
		cap.radius = rng.randf_range(0.035, 0.06)
		cap.height = rng.randf_range(0.35, 0.7)
		cap.radial_segments = 8
		cap.rings = 3
		_piece(root, cap, bone, Vector3(x, ground.call(x, z) + 0.12, z), Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(-0.9, 0.9)))
	# the burnt, glassy flecks of the wing bed
	if wing:
		for i in 6:
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.1, r * 0.5)
			var x := cx + cos(a) * d
			var z := cz + sin(a) * d
			var chip := PrismMesh.new()
			chip.size = Vector3(rng.randf_range(0.1, 0.22), rng.randf_range(0.08, 0.2), rng.randf_range(0.08, 0.16))
			_piece(root, chip, glass, Vector3(x, ground.call(x, z) + 0.05, z), Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
	var puff := CPUParticles3D.new()
	puff.position = Vector3(cx, ground.call(cx, cz) + 0.2, cz)
	puff.amount = 6
	puff.lifetime = 3.0
	puff.explosiveness = 0.0
	puff.randomness = 0.8
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = r * 0.5
	puff.direction = Vector3(0.2, 1, 0.1)
	puff.spread = 30.0
	puff.initial_velocity_min = 0.08
	puff.initial_velocity_max = 0.3
	puff.gravity = Vector3(0.05, 0.04, 0)
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(0.78, 0.7, 0.52, 0.0), Color(0.78, 0.7, 0.52, 0.28), Color(0.78, 0.7, 0.52, 0.0)])
	puff.color_ramp = g
	puff.mesh = _soft_quad(0.6)
	add_child(puff)
	var label := Label3D.new()
	label.text = Strings.t("dig_prompt")
	label.font_size = 30
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(cx, ground.call(cx, cz) + 1.4, cz)
	label.visible = false
	add_child(label)
	_beds[int(b.id)] = {"root": root, "puff": puff, "label": label, "x": cx, "z": cz}

static var _soft_tex: Texture2D

func _soft_quad(size: float) -> QuadMesh:
	if _soft_tex == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = gr
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 48
		t.height = 48
		_soft_tex = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	return q

# --- holes -----------------------------------------------------------------------------------------------------------

func _build_hole(h: Dictionary) -> void:
	var key := "%.2f,%.2f" % [float(h.x), float(h.z)]
	if _holes.has(key):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(float(h.x) * 100.0) * 31 + int(float(h.z) * 100.0)
	var root := Node3D.new()
	var x: float = h.x
	var z: float = h.z
	var gy: float = ground.call(x, z)
	root.position = Vector3(x, gy, z)
	root.rotation.y = rng.randf() * TAU
	# a lathe: dark floor, a rolled lip, a skirt that blends back to the ground (everything stays above the surface so the
	# terrain never hides it: the pit reads as a dark bowl inside a raised rim)
	var profile := [Vector2(0.0, 0.05), Vector2(0.38, 0.05), Vector2(0.5, 0.11), Vector2(0.66, 0.2), Vector2(0.84, 0.17), Vector2(1.05, 0.08), Vector2(1.3, 0.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 22
	for i in profile.size() - 1:
		for s in seg:
			var a0 := TAU * s / seg
			var a1 := TAU * (s + 1) / seg
			var p00 := Vector3(cos(a0) * profile[i].x, profile[i].y, sin(a0) * profile[i].x)
			var p01 := Vector3(cos(a1) * profile[i].x, profile[i].y, sin(a1) * profile[i].x)
			var p10 := Vector3(cos(a0) * profile[i + 1].x, profile[i + 1].y, sin(a0) * profile[i + 1].x)
			var p11 := Vector3(cos(a1) * profile[i + 1].x, profile[i + 1].y, sin(a1) * profile[i + 1].x)
			var c := Color("1d1610") if i < 2 else (Color("3b2d1f") if i < 4 else Color("5b4a36"))
			for tri in [[p00, p10, p01], [p01, p10, p11]]:
				for v in tri:
					st.set_color(c)
					st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_piece(root, mesh, mat, Vector3.ZERO)
	var soil := _mat(Color("5b4a36"), 1.0)
	for i in 7:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.85, 1.35)
		var clod := SphereMesh.new()
		clod.radius = rng.randf_range(0.12, 0.26)
		clod.height = clod.radius * 1.4
		clod.radial_segments = 8
		clod.rings = 4
		var px := x + cos(a + root.rotation.y) * d
		var pz := z + sin(a + root.rotation.y) * d
		_piece(root, clod, soil, Vector3(cos(a) * d, ground.call(px, pz) - gy + clod.radius * 0.35, sin(a) * d), Vector3(0, rng.randf() * TAU, 0), Vector3(1, 0.7, 1))
	add_child(root)
	_holes[key] = root

# --- the dig itself --------------------------------------------------------------------------------------------------------

func _soil_burst() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(0.36, 0.28, 0.2, 0.95), Color(0.3, 0.23, 0.16, 0.8), Color(0.3, 0.23, 0.16, 0.0)])
	p.color_ramp = g
	p.mesh = _soft_quad(0.22)
	p.emitting = false
	return p

func _tick(state: Dictionary) -> void:
	var dig: Dictionary = state.get("dig", {})
	var me: Dictionary = state.entities[0]
	for b in dig.get("beds", []):
		var id := int(b.id)
		if not _beds.has(id):
			_build_bed(b)
		var e: Dictionary = _beds[id]
		var d := Vector2(float(me.x) - float(e.x), float(me.z) - float(e.z)).length()
		e.root.visible = not bool(b.dug)
		e.puff.emitting = (not bool(b.dug)) and d < PUFF_RANGE
		e.label.visible = (not bool(b.dug)) and d < NEAR_LABEL
	var keep := {}
	for h in dig.get("holes", []):
		_build_hole(h)
		keep["%.2f,%.2f" % [float(h.x), float(h.z)]] = true
	for k in _holes.keys():                     # a load that goes back in time drops the holes dug since
		if not keep.has(k):
			_holes[k].queue_free()
			_holes.erase(k)
	var digging := int(dig.get("digging", 0))
	if digging > 0:
		# soil flies from just in front of the creature, in the direction it faces
		var fwd := Vector2(float(me.fx), float(me.fz))
		var gx: float = float(me.x) + fwd.x * 0.9
		var gz: float = float(me.z) + fwd.y * 0.9
		_dig_fx.global_position = Vector3(gx, float(ground.call(gx, gz)) + 0.1, gz)
		_dig_fx.emitting = (digging % 4) < 3
	else:
		_dig_fx.emitting = false
	_was_digging = digging
