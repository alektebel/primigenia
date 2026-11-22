extends RefCounted
## Pristine rigs, keyed by the complete genome and realism mode.
## Geometry and textures are immutable and shared. Skeletons, hooks, IK and all
## material uniforms belong to each instance (leg flex cannot be shared).
var _templates := {}
var builds := 0
const LIMIT := 32 # bounded session cache; arbitrary edited genomes cannot grow it forever

func instantiate(genome: Dictionary) -> Creature:
	var key := [JSON.stringify(genome), CreatureMaterials.realism]
	if not _templates.has(key):
		var template := Creature.new()
		if not template.load_genome(genome).ok:
			template.free()
			return null
		if _templates.size() >= LIMIT:
			var oldest = _templates.keys()[0]
			_templates[oldest].free()
			_templates.erase(oldest)
		_templates[key] = template
		builds += 1
	return _clone(_templates[key])

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for template in _templates.values():
			template.free()

func _map_nodes(source: Node, target: Node, mapping: Dictionary) -> void:
	mapping[source] = target
	for i in source.get_child_count():
		_map_nodes(source.get_child(i), target.get_child(i), mapping)

func _clone(source: Creature) -> Creature:
	var target: Creature = source.duplicate(Node.DUPLICATE_SCRIPTS)
	var mapping := {}
	_map_nodes(source, target, mapping)
	_copy_variables(source, target, mapping, target)
	for node in mapping.keys().duplicate():
		if not node is Node:
			continue
		var copy: Node = mapping[node]
		for key in node.get_meta_list():
			copy.set_meta(key, _copy_value(node.get_meta(key), mapping, target))
		if node is MeshInstance3D:
			# Keep the ArrayMesh itself shared, override mutable surface materials.
			copy.material_override = _copy_value(node.material_override, mapping, target)
			copy.material_overlay = _copy_value(node.material_overlay, mapping, target)
			for i in node.mesh.get_surface_count() if node.mesh != null and node.material_override == null else 0:
				copy.set_surface_override_material(i, _copy_value(node.get_active_material(i), mapping, target))
	return target

func _copy_variables(source: Object, target: Object, mapping: Dictionary, creature: Creature) -> void:
	for property in source.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			target.set(property.name, _copy_value(source.get(property.name), mapping, creature))

func _copy_value(value: Variant, mapping: Dictionary, creature: Creature) -> Variant:
	if value is Object:
		if mapping.has(value):
			return mapping[value]
		if value is Material:
			var material: Material = value.duplicate()
			mapping[value] = material
			return material
		var copy: Object
		if value is CreatureLegChain:
			copy = CreatureLegChain.new()
		elif value is CreatureRadial:
			copy = CreatureRadial.new(creature)
		elif value is CreatureMaterials:
			copy = CreatureMaterials.new(false)
		elif value is CreatureParts:
			copy = CreatureParts.new(_copy_value(value.mats, mapping, creature), creature.asset_dir)
			mapping[value] = copy
			return copy # the part library is immutable; do not deep-copy it per animal
		else:
			return value # immutable Mesh, Skin, Shader, Texture and scripts
		mapping[value] = copy
		_copy_variables(value, copy, mapping, creature)
		return copy
	if value is Array:
		var array: Array = value.duplicate()
		for i in array.size():
			array[i] = _copy_value(value[i], mapping, creature)
		return array
	if value is Dictionary:
		var dictionary := {}
		for key in value:
			dictionary[_copy_value(key, mapping, creature)] = _copy_value(value[key], mapping, creature)
		return dictionary
	return value
