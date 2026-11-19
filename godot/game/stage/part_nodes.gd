extends Node3D
## Surface finds. E inspects a nearby node; the 20-tick completion and loot stay in C.
const Strings := preload("res://ui/strings.gd")
var stage: Node
var markers := {}

func _mat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _piece(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)

## A surface find reads as weathered remains half sunk in a low mound of turned earth, not a disc:
## kind 3 = a fossil (tilted stone slab with a ribbed spiral), otherwise a few bones (shafts with knobbed ends).
## Still pale against the meadow so it stays readable; seeded by the node id so every find differs.
func _find_marker(node: Dictionary, ground: Callable) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(node.id) * 7919 + 13
	var root := Node3D.new()
	var gy: float = ground.call(node.x, node.z)
	root.position = Vector3(node.x, gy, node.z)
	root.rotation.y = rng.randf() * TAU
	var soil := SphereMesh.new()
	soil.radius = 0.8
	soil.height = 1.6
	soil.radial_segments = 24
	soil.rings = 12
	var soil_mat := _mat(Color("5b4a36"), 1.0)
	_piece(root, soil, soil_mat, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1.0, 0.3, 0.85))
	for i in 5:
		var clod := SphereMesh.new()
		clod.radius = 0.16
		clod.height = 0.22
		clod.radial_segments = 8
		clod.rings = 4
		var a := rng.randf() * TAU
		var r := 0.7 + rng.randf() * 0.25
		_piece(root, clod, soil_mat, Vector3(cos(a) * r, 0.0, sin(a) * r * 0.85), Vector3(0, rng.randf() * TAU, 0), Vector3(1, 0.7, 1) * (0.7 + rng.randf() * 0.6))
	if int(node.kind) == 3:
		var rock := _mat(Color("a89a7c"), 0.9)
		var slab := SphereMesh.new()
		slab.radius = 0.55
		slab.height = 1.1
		slab.radial_segments = 20
		slab.rings = 10
		_piece(root, slab, rock, Vector3(0, 0.02, 0), Vector3(deg_to_rad(-12), 0, deg_to_rad(9)), Vector3(1.0, 0.32, 0.85))
		var rib := _mat(Color("d9ccaa"), 0.8)
		for k in 3:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.09 + 0.12 * k
			ring.outer_radius = ring.inner_radius + 0.045
			ring.rings = 24
			ring.ring_segments = 6
			_piece(root, ring, rib, Vector3(0.02, 0.15 + 0.01 * k, 0.0), Vector3(deg_to_rad(-12), 0, deg_to_rad(9)), Vector3(1, 0.9, 1))
	else:
		var bone := _mat(Color("e4d8b9"), 0.75)
		var count := 3 + rng.randi() % 2
		for k in count:
			var shaft := CapsuleMesh.new()
			shaft.radius = 0.055 + rng.randf() * 0.025
			shaft.height = 0.7 + rng.randf() * 0.35
			shaft.radial_segments = 10
			shaft.rings = 3
			var a := -0.9 + k * (1.8 / count) + rng.randf() * 0.3
			var pos := Vector3(cos(a) * 0.15 * k - 0.2, 0.12 + 0.03 * k, sin(a) * 0.35)
			var rot := Vector3(deg_to_rad(90 + rng.randf_range(-12, 12)), a * 0.6 + rng.randf_range(-0.5, 0.5), deg_to_rad(rng.randf_range(-12, 12)))
			_piece(root, shaft, bone, pos, rot)
			var yaw := Basis.from_euler(rot)
			var half := shaft.height * 0.5
			for sgn in [-1.0, 1.0]:
				var knob := SphereMesh.new()
				knob.radius = shaft.radius * 1.55
				knob.height = knob.radius * 2.0
				knob.radial_segments = 10
				knob.rings = 5
				_piece(root, knob, bone, pos + yaw * Vector3(0, half * sgn, 0), Vector3.ZERO)
		var skull := SphereMesh.new()
		skull.radius = 0.2
		skull.height = 0.3
		skull.radial_segments = 14
		skull.rings = 7
		_piece(root, skull, bone, Vector3(0.38, 0.05, -0.15), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	return root
func setup(bridge: Node, ground: Callable) -> void:
	stage = bridge
	for node in stage.cur.get("parts", {}).get("nodes", []):
		var mesh := _find_marker(node, ground)
		add_child(mesh)
		var label := Label3D.new()
		label.text = "E · " + Strings.t("fossil" if int(node.kind) == 3 else "bones")
		label.position.y = 1.4
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mesh.add_child(label)
		markers[int(node.id)] = {"mesh": mesh, "label": label}
	stage.ticked.connect(_tick)
func _tick(state: Dictionary) -> void:
	var player: Dictionary = state.entities[0]
	for node in state.get("parts", {}).get("nodes", []):
		if not markers.has(int(node.id)):
			continue
		var marker: Dictionary = markers[int(node.id)]
		marker.mesh.visible = not node.inspected
		marker.label.visible = Vector2(player.x - node.x, player.z - node.z).length() < 8.0
func _unhandled_key_input(event: InputEvent) -> void:
	if stage == null or stage.paused or not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_E:
		return
	var state: Dictionary = stage.world.state()
	var player: Dictionary = state.entities[0]
	for node in state.parts.nodes:
		if not node.inspected and Vector2(player.x - node.x, player.z - node.z).length() <= 2.5:
			stage.queue_order({"verb": 16, "target": int(node.id)})
			get_viewport().set_input_as_handled()
			return
