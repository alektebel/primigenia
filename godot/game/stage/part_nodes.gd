extends Node3D
## Surface finds. E inspects a nearby node; the 20-tick completion and loot stay in C.
const Strings := preload("res://ui/strings.gd")
var stage: Node
var markers := {}
func setup(bridge: Node, ground: Callable) -> void:
	stage = bridge
	var nodes: Array = stage.cur.get("parts", {}).get("nodes", []).duplicate()
	nodes.append_array(stage.cur.get("recipes", {}).get("stones", []))
	for node in nodes:
		var mesh := MeshInstance3D.new()
		var stone := SphereMesh.new()
		stone.radius = 0.65
		stone.height = 0.45
		mesh.mesh = stone
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("cbb68b") if int(node.get("kind", -1)) == 3 else Color("e6d9b8")
		material.roughness = 1.0
		mesh.material_override = material
		mesh.position = Vector3(node.x, ground.call(node.x, node.z) + 0.2, node.z)
		add_child(mesh)
		if str(node.get("clue", "")) == "spined_fossil":
			for k in 3:
				var spike := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.09
				cone.height = 0.55
				spike.mesh = cone
				spike.material_override = material
				spike.position = Vector3((k - 1) * 0.25, 0.35, 0)
				mesh.add_child(spike)
		var label := Label3D.new()
		label.text = _label(node)
		label.position.y = 1.5
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mesh.add_child(label)
		markers[int(node.id)] = {"mesh": mesh, "label": label}
	stage.ticked.connect(_tick)
func _label(node: Dictionary) -> String:
	var key: String = str(node.get("clue", ""))
	if bool(node.get("edible", false)):
		key = "eat_bones"
	elif int(node.id) >= 4000:
		key = "stones"
	elif key == "":
		key = "fossil" if int(node.get("kind", -1)) == 3 else "bones"
	return "E · " + Strings.t(key)

func _nodes(state: Dictionary) -> Array:
	var nodes: Array = state.get("parts", {}).get("nodes", []).duplicate(true)
	var remains: Array = state.get("recipes", {}).get("old_carcasses", [])
	for node in nodes:
		if bool(node.get("inspected", false)):
			for old in remains:
				if int(old.id) == int(node.id) and int(old.units) > 0:
					node.inspected = false
					node.edible = true
	nodes.append_array(state.get("recipes", {}).get("stones", []))
	return nodes

func _tick(state: Dictionary) -> void:
	var player: Dictionary = state.entities[0]
	var nodes: Array = _nodes(state)
	for node in nodes:
		if not markers.has(int(node.id)):
			continue
		var marker: Dictionary = markers[int(node.id)]
		marker.label.text = _label(node)
		marker.mesh.visible = not bool(node.get("inspected", int(node.get("units", 0)) <= 0))
		marker.label.visible = Vector2(player.x - node.x, player.z - node.z).length() < 8.0
func _unhandled_key_input(event: InputEvent) -> void:
	if stage == null or stage.paused or not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_E:
		return
	var state: Dictionary = stage.world.state()
	var player: Dictionary = state.entities[0]
	var nodes: Array = _nodes(state)
	for node in nodes:
		if not bool(node.get("inspected", int(node.get("units", 0)) <= 0)) and Vector2(player.x - node.x, player.z - node.z).length() <= 2.5:
			stage.queue_order({"verb": 15 if int(node.id) >= 4000 or bool(node.get("edible", false)) else 16, "target": int(node.id)})
			get_viewport().set_input_as_handled()
			return
