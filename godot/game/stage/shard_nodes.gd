extends Node3D
## The five meteor shards (W10, G68). The C world places them and counts them (state().shards); this draws a glowing iron-nickel
## cluster at each one that is still on the ground, a small cold light, and the E prompt within 8 m. E collects within 2.5 m:
## the story line comes back as the shard_found event (stage_ui.gd). The Hierroflor violet is the glow colour.
const Strings := preload("res://ui/strings.gd")
const GLOW := Color(0.62, 0.36, 1.0)
var stage: Node
var markers := {}
var _t := 0.0

func setup(bridge: Node, ground: Callable) -> void:
	stage = bridge
	name = "Shards"
	for item in stage.cur.get("shards", {}).get("items", []):
		var root := Node3D.new()
		root.position = Vector3(item.x, ground.call(item.x, item.z), item.z)
		root.rotation.y = float(item.index) * 1.3
		add_child(root)
		root.add_child(_cluster(int(item.index)))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 1.0, 0)
		light.light_color = GLOW
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.shadow_enabled = false
		root.add_child(light)
		var label := Label3D.new()
		label.text = "E · " + Strings.t("shard")
		label.position.y = 2.4
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		root.add_child(label)
		markers[int(item.id)] = {"root": root, "label": label, "light": light}
	stage.ticked.connect(_tick)

# A cluster of tapered six-sided prisms leaning out of the ground: dark metal with a violet glow along the ridges.
func _cluster(index: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + index * 131
	var prisms := 5
	for k in prisms:
		var lean := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		var base := Vector3(rng.randf_range(-0.35, 0.35), -0.1, rng.randf_range(-0.35, 0.35))
		var h := (1.5 if k == 0 else rng.randf_range(0.55, 1.15))
		var r := (0.24 if k == 0 else rng.randf_range(0.1, 0.18))
		var top := base + Vector3(0, h, 0) + lean * h
		var ring := []
		for i in 6:
			var a := TAU * float(i) / 6.0
			ring.append(base + Vector3(cos(a) * r, 0, sin(a) * r))
		var tip := top + Vector3(0, 0.0, 0)
		var shoulder := []
		for i in 6:
			var a := TAU * float(i) / 6.0
			shoulder.append(base.lerp(top, 0.72) + Vector3(cos(a) * r * 0.55, 0, sin(a) * r * 0.55))
		for i in 6:
			var j := (i + 1) % 6
			_quad(st, ring[i], ring[j], shoulder[j], shoulder[i], Color(0.11, 0.10, 0.14))
			_tri(st, shoulder[i], shoulder[j], tip, Color(0.34, 0.2, 0.62))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.85
	mat.roughness = 0.32
	mat.emission_enabled = true
	mat.emission = GLOW
	mat.emission_energy_multiplier = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "Cluster"
	return mi

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)

func _process(delta: float) -> void:
	_t += delta
	for id in markers:
		var m: Dictionary = markers[id]
		if m.light.visible:
			m.light.light_energy = 1.1 + 0.5 * sin(_t * 1.7 + float(id))

func _tick(state: Dictionary) -> void:
	var p: Dictionary = state.entities[0]
	for item in state.get("shards", {}).get("items", []):
		var m = markers.get(int(item.id))
		if m == null:
			continue
		m.root.visible = not bool(item.found)
		m.light.visible = not bool(item.found)
		m.label.visible = not bool(item.found) and Vector2(float(p.x) - float(item.x), float(p.z) - float(item.z)).length() < 8.0

func _unhandled_key_input(event: InputEvent) -> void:
	if stage == null or stage.paused or not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_E:
		return
	var state: Dictionary = stage.world.state()
	var p: Dictionary = state.entities[0]
	for item in state.get("shards", {}).get("items", []):
		if not bool(item.found) and Vector2(float(p.x) - float(item.x), float(p.z) - float(item.z)).length() <= 2.5:
			stage.queue_order({"verb": 16, "target": int(item.id)})
			get_viewport().set_input_as_handled()
			return
