extends "creature_view.gd"
## The creature_view.gd interface backed by godot/creature (the real rig) instead of the placeholder.
## View space equals genome space (+Y up, +Z along the spine, x = 0 on the spine): the Creature node sits at
## y = -ground_offset so its BodyRoot space is the genome's. Parts off the midline and all legs are mirrored
## by the builder itself. Test mode walks the creature in a circle with godot/locomotion.
##
## Everything from res://creature and res://locomotion is loaded at run time (no class names), so this file
## compiles in a project that does not contain them; `make_default()` then returns the placeholder.

const CREATURE := "res://creature/creature.gd"
const LOCO := ["res://locomotion/loco_controller.gd", "res://locomotion/loco_morphology.gd", "res://locomotion/loco_rig_adapter.gd"]
const Placeholder := preload("placeholder/placeholder_view.gd")

var creature: Node3D = null
var genome: Dictionary = {}          # last parsed /4 genome
var node_count := 0
var _doc_key := ""
var _selected := -1
var _spine_on := true
var _playing := false
var _handles: Node3D
var _ground: MeshInstance3D
var _highlight: StandardMaterial3D
var _tri := {}                        # MeshInstance3D instance id -> TriangleMesh (cleared on rebuild)
var _ctl = null
var _adapter = null
var _desc := {}
var _time := 0.0

## The real view when the creature module is present, else the placeholder.
static func make_default(db: RefCounted = null) -> Node3D:
	if ResourceLoader.exists(CREATURE) and ResourceLoader.exists("res://studio/creature_view_real.gd"):
		return load("res://studio/creature_view_real.gd").new(db)
	return Placeholder.new(db)

func _init(_db: RefCounted = null) -> void:
	creature = (load(CREATURE) as GDScript).new()
	creature.name = "Creature"
	add_child(creature)
	_handles = Node3D.new()
	_handles.name = "SpineHandles"
	add_child(_handles)
	_highlight = StandardMaterial3D.new()
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight.albedo_color = Color(1.0, 0.75, 0.29, 0.38)
	_highlight.no_depth_test = true
	_ground = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.0
	cm.height = 0.05
	_ground.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("2b3a2f")
	gm.roughness = 1.0
	_ground.material_override = gm
	add_child(_ground)

# ------------------------------------------------------------------ interface
func set_genome(doc: Dictionary) -> void:
	var key := JSON.stringify(doc)
	if key == _doc_key and not genome.is_empty():
		return
	var res: Dictionary = creature.load_genome(doc)
	if not res.get("ok", false):
		push_warning("creature view: genome rejected: %s" % [res.get("error", "?")])
		return
	_doc_key = key
	genome = creature.genome
	node_count = genome.nodes.size()
	_tri.clear()
	_place()
	_build_handles()
	_apply_selection()
	if _playing:
		_start_loco()
	genome_applied.emit()

func get_genome() -> Dictionary:
	return genome.duplicate(true)

func attach_part(type: String, t: float, ang: float, params: Dictionary = {}) -> int:
	var d := genome.duplicate(true)
	var p: Dictionary = creature.default_part(type)
	p["t"] = t
	p["ang"] = ang
	for k in params:
		p[k] = params[k]
	d["parts"].append(p)
	set_genome(d)
	return d["parts"].size() - 1

func remove_part(index: int) -> void:
	if index < 0 or index >= genome.parts.size():
		return
	var d := genome.duplicate(true)
	d["parts"].remove_at(index)
	if _selected == index:
		_selected = -1
	set_genome(d)

func update_part(index: int, fields: Dictionary) -> void:
	if index < 0 or index >= genome.parts.size():
		return
	var d := genome.duplicate(true)
	for k in fields:
		d["parts"][index][k] = fields[k]
	set_genome(d)

func spine_node_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in genome.get("nodes", []):
		out.append(Vector3(0.0, float(n.y), float(n.z)))
	return out

func hit_body(origin: Vector3, dir: Vector3) -> Dictionary:
	if creature.body_mesh == null:
		return {}
	var h := _ray_mesh(creature.body_mesh, origin, dir)
	if h.is_empty():
		return {}
	var p: Vector3 = to_local(h.point)
	var rest: Array = creature.rest
	var best := INF
	var bt := 0.0
	var bpos := Vector3.ZERO
	for i in rest.size() - 1:
		var a: Vector3 = rest[i]
		var ab: Vector3 = rest[i + 1] - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var c := a + ab * u
		var d := p.distance_squared_to(c)
		if d < best:
			best = d
			bt = (i + u) / float(rest.size() - 1)
			bpos = c
	var fr: Dictionary = creature.frames[int(round(bt * (rest.size() - 1)))]
	var v := p - bpos
	return {"t": bt, "ang": atan2(v.dot(fr.s), v.dot(fr.u)), "point": p}

func hit_part(origin: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_t := INF
	for e in creature.parts:
		var hit := _hit_nodes([e.node], origin, dir)
		if hit >= 0.0 and hit < best_t:
			best_t = hit
			best = e.index
	for l in creature.legs:
		var hit := _hit_nodes([l.upper, l.lower, l.foot], origin, dir)
		if hit >= 0.0 and hit < best_t:
			best_t = hit
			best = l.part_index
	return best

func hit_node(origin: Vector3, dir: Vector3) -> int:
	var pts := spine_node_positions()
	var o := to_global(origin)
	var d := (global_transform.basis * dir).normalized()
	var best := -1
	var best_d := INF
	for i in pts.size():
		var c := to_global(pts[i])
		var oc := o - c
		var b := oc.dot(d)
		var disc := b * b - (oc.dot(oc) - 0.04)
		if disc < 0.0:
			continue
		var s := -b - sqrt(disc)
		if s >= 0.0 and s < best_d:
			best_d = s
			best = i
	return best

func part_anchor(index: int) -> Dictionary:
	if index < 0 or index >= genome.get("parts", []).size():
		return {}
	var p: Dictionary = genome.parts[index]
	var a: Dictionary = creature.anchor(float(p.t), float(p.ang))
	return {"pos": a.p, "normal": a.n, "up": a.u}

func set_selection(index: int) -> void:
	_selected = index
	_apply_selection()

func set_spine_visible(on: bool) -> void:
	_spine_on = on
	_handles.visible = on and not _playing

func set_playing(on: bool) -> void:
	if on == _playing:
		return
	_playing = on
	_handles.visible = _spine_on and not on
	if on:
		_start_loco()
	else:
		_ctl = null
		_place()
		creature.reset_spine_pose()
		creature.pose_legs_rest()

# ------------------------------------------------------------------ internals
func _place() -> void:
	creature.transform = Transform3D(Basis(), Vector3(0.0, -creature.ground_offset, 0.0))
	_ground.position = Vector3(0, -creature.ground_offset - 0.03, 1)

func _build_handles() -> void:
	for c in _handles.get_children():
		c.queue_free()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffc04a")
	m.no_depth_test = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for p in spine_node_positions():
		var h := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.24
		h.mesh = s
		h.material_override = m
		h.position = p
		_handles.add_child(h)
	_handles.visible = _spine_on and not _playing

func _part_meshes(index: int) -> Array:
	var out := []
	for e in creature.parts:
		if e.index == index:
			out.append_array(_meshes_under(e.node))
	for l in creature.legs:
		if l.part_index == index:
			for n in [l.upper, l.lower, l.foot]:
				out.append_array(_meshes_under(n))
	return out

func _meshes_under(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes_under(c))
	return out

func _apply_selection() -> void:
	for mi in creature.mesh_instances():
		(mi as MeshInstance3D).material_overlay = null
	if _selected >= 0:
		for mi in _part_meshes(_selected):
			(mi as MeshInstance3D).material_overlay = _highlight

func _tri_for(mi: MeshInstance3D) -> TriangleMesh:
	var id := mi.get_instance_id()
	if not _tri.has(id):
		_tri[id] = mi.mesh.generate_triangle_mesh() if mi.mesh != null else null
	return _tri[id]

# Ray in view space against one mesh. Returns {t (distance along dir), point (global)} or {}.
func _ray_mesh(mi: MeshInstance3D, origin: Vector3, dir: Vector3) -> Dictionary:
	var tm := _tri_for(mi)
	if tm == null:
		return {}
	var to_mesh := mi.global_transform.affine_inverse()
	var o := to_global(origin)
	var d := (global_transform.basis * dir).normalized()
	var lo: Vector3 = to_mesh * o
	var ld: Vector3 = (to_mesh.basis * d)
	var scale_len := ld.length()
	if scale_len < 1e-9:
		return {}
	var h: Dictionary = tm.intersect_ray(lo, ld / scale_len)
	if h.is_empty():
		return {}
	var gp: Vector3 = mi.global_transform * h.position
	return {"t": o.distance_to(gp), "point": gp}

func _hit_nodes(nodes: Array, origin: Vector3, dir: Vector3) -> float:
	var best := -1.0
	for n in nodes:
		if n == null:
			continue
		for mi in _meshes_under(n):
			var h := _ray_mesh(mi, origin, dir)
			if not h.is_empty() and (best < 0.0 or h.t < best):
				best = h.t
	return best

# ------------------------------------------------------------------ test mode (locomotion)
func _start_loco() -> void:
	_ctl = null
	for p in LOCO:
		if not ResourceLoader.exists(p):
			return
	var morph = load(LOCO[1])
	_adapter = load(LOCO[2])
	_desc = _adapter.loco_describe(creature, 1.0)
	_ctl = load(LOCO[0]).new(morph.analyse(_desc), func(_x: float, _z: float) -> float: return -creature.ground_offset)
	_time = 0.0
	_loco_step(0.0)
	_ctl.reset(Vector3(3.0, -creature.ground_offset, 0.0), PI * 0.5)

func _loco_step(dt: float) -> void:
	_time += dt
	var r := 3.2
	var speed := clampf(float(_ctl.morph.hip_height) * 1.4, 0.6, 4.0) if _ctl.morph.legs.size() > 0 else 0.8
	var w := speed / r
	var a := _time * w
	var pos := Vector3(cos(a) * r, -creature.ground_offset, sin(a) * r * 0.6)
	var vel := Vector3(-sin(a) * r * w, 0.0, cos(a) * r * 0.6 * w)
	_ctl.step(maxf(dt, 1e-4), pos, atan2(vel.x, vel.z), vel)
	_adapter.loco_apply(creature, _ctl.pose, _desc)

func _process(dt: float) -> void:
	if _playing and _ctl != null:
		_loco_step(minf(dt, 0.1))
