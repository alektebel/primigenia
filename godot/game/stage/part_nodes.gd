extends Node3D
## Surface finds. E inspects a nearby node; the 20-tick completion and loot stay in C.
const Strings := preload("res://ui/strings.gd")
var stage: Node
var markers := {}
func setup(bridge: Node, ground: Callable) -> void:
	stage = bridge
	for node in stage.cur.get("parts", {}).get("nodes", []):
		var mesh := MeshInstance3D.new()
		var stone := SphereMesh.new()
		stone.radius = 0.65
		stone.height = 0.45
		mesh.mesh = stone
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("cbb68b") if int(node.kind) == 3 else Color("e6d9b8")
		material.roughness = 1.0
		mesh.material_override = material
		mesh.position = Vector3(node.x, ground.call(node.x, node.z) + 0.2, node.z)
		add_child(mesh)
		var label := Label3D.new()
		label.text = "E · " + Strings.t("fossil" if int(node.kind) == 3 else "bones")
		label.position.y = 1.5
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
