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
var _handles: Node3D                  # vertebrae + cords (spine overlay)
var _verts: Array = []                # Node3D per vertebra
var _vert_mats: Array = []            # StandardMaterial3D shared by all vertebra meshes, cord material
var _cord_mat: StandardMaterial3D
var _vert_mat: StandardMaterial3D
var _spine_alpha := 0.0
var _hover_node := -1
var _active_node := -1
var _hover_part := -1
var _hover_mat: StandardMaterial3D
var _sel_group: Node3D                # selection rings, rotation bead, leg handles
var _rings: Array = []
var _rot_bead: MeshInstance3D
var _bead_hot := false
signal handle_shown(kind: String, fade_ms: float)
signal head_target_changed(part: int)
const BREATH_PERIOD := 3.4            # s per breath
const LOOK_DELAY := .3                # s between a part landing and the head starting to turn (the reference shows ~0.33 s)
const LOOK_HOLD := 2.6                # s the head stays on the part before it relaxes
const POSE_GAP := 3.0                 # one-shot pose at most once per 3 s
const YAW_MAX := .6                   # rad, head turn clamp
var _alive_t := 0.0
var _look_part := -1
var _look_wait := -1.0                # >=0 while waiting LOOK_DELAY
var _look_hold := 0.0
var _yaw := 0.0
var _yaw_goal := 0.0
var _pose_t := -1.0                   # >=0 while the one-shot pose plays (0..POSE_LEN)
var _last_pose := -100.0
const POSE_LEN := .55
const HANDLE_FADE := .12              # s, handles reach full opacity in 120 ms (linear: it is only an opacity ramp)
const SPHERE_PX := 11.0               # vertebra sphere radius on screen, constant at any camera distance
var _sphere_group: Node3D
var _spheres: Array = []              # MeshInstance3D per vertebra
var _sphere_mat: StandardMaterial3D
var _sphere_hot_mat: StandardMaterial3D
var _sphere_alpha := 0.0
var _ring_green: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_alpha := 0.0
var _ring_part := -1
var _leg_group: Node3D
var _hover_leg := -1
var _hidden_part := -1
var _pulses := {}                     # part index -> seconds left
var _sel_time := 0.0
var _highlight: StandardMaterial3D
var _tri := {}                        # MeshInstance3D instance id -> TriangleMesh (cleared on rebuild)
var _ctl = null
var _adapter = null
var _desc := {}
var _time := 0.0
var _actions := {}
var _run := false

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
	_hover_mat = StandardMaterial3D.new()
	_hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_mat.albedo_color = Color(1.0, 0.85, 0.5, 0.2)
	_hover_mat.no_depth_test = true
	_vert_mat = StandardMaterial3D.new()
	_vert_mat.albedo_color = Color("eadfc2", 0.0)
	_vert_mat.emission_enabled = true
	_vert_mat.emission = Color("4a3c24")
	_vert_mat.roughness = .5
	_vert_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vert_mat.no_depth_test = true
	_vert_mat.render_priority = 15
	_cord_mat = StandardMaterial3D.new()
	_cord_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cord_mat.albedo_color = Color("ffc04a", 0.0)
	_cord_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cord_mat.no_depth_test = true
	_cord_mat.render_priority = 14
	_sphere_group = Node3D.new()
	_sphere_group.name = "VertebraSpheres"
	add_child(_sphere_group)
	_sphere_mat = _handle_mat(Color("3d8bff"))
	_sphere_hot_mat = _handle_mat(Color("ffd23f"))
	_ring_mat = _handle_mat(Color("6fe05a"))
	_ring_green = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = .93
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	_ring_green.mesh = tm
	_ring_green.material_override = _ring_mat
	_ring_green.visible = false
	_ring_green.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_green)
	_sel_group = Node3D.new()
	_sel_group.name = "SelectionHandles"
	add_child(_sel_group)
	_build_sel_nodes()

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
	_update_sel_nodes()
	_apply_hidden()
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
		var rr := maxf(.2, _vert_radius(i) + .06) if i < genome.nodes.size() else .2
		var disc := b * b - (oc.dot(oc) - rr * rr)
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
	_sel_time = 0.0
	_apply_selection()
	_update_sel_nodes()

func set_spine_visible(on: bool) -> void:
	_spine_on = on

func set_playing(on: bool) -> void:
	if on == _playing:
		return
	_playing = on
	if on:
		_start_loco()
	else:
		_ctl = null
		_place()
		creature.reset_spine_pose()
		creature.pose_legs_rest()
	_update_sel_nodes()

# ------------------------------------------------------------------ internals
func _place() -> void:
	creature.transform = Transform3D(Basis(), Vector3(0.0, -creature.ground_offset, 0.0))

func _vert_radius(i: int) -> float:
	return .06 + float(genome.nodes[i].r) * .24

func _handle_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 24
	return m

func _build_handles() -> void:
	for c in _handles.get_children():
		c.queue_free()
	_verts.clear()
	for c in _sphere_group.get_children():
		c.queue_free()
	_spheres.clear()
	for nd in genome.get("nodes", []):
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 20
		sm.rings = 10
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = _sphere_mat
		mi.position = Vector3(0, float(nd.y), float(nd.z))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sphere_group.add_child(mi)
		_spheres.append(mi)
	var N: Array = genome.get("nodes", [])
	for i in N.size():
		var n = N[i]
		var a = N[maxi(i - 1, 0)]
		var b = N[mini(i + 1, N.size() - 1)]
		var t := Vector3(0, float(b.y) - float(a.y), float(b.z) - float(a.z)).normalized()
		var r := _vert_radius(i)
		var g := Node3D.new()
		g.position = Vector3(0, n.y, n.z)
		g.basis = Basis(Quaternion(Vector3.UP, t)) if t.dot(Vector3.UP) > -0.999 else Basis(Vector3.RIGHT, PI)
		_vert_part(g, r, r, .13, 0.0)
		_vert_part(g, r * 1.12, r * 1.12, .025, .065)
		_vert_part(g, r * 1.12, r * 1.12, .025, -.065)
		var sp := _vert_part(g, .0, .04 + r * .14, .1 + r * .75, 0.0)
		sp.rotation.x = -PI / 2
		sp.position = Vector3(0, 0, -(r + .05 + r * .37))
		for sx in [-1.0, 1.0]:
			var sc := _vert_part(g, .0, .03 + r * .1, .06 + r * .5, 0.0)
			sc.rotation.z = -sx * PI / 2
			sc.position = Vector3(sx * (r + .03 + r * .25), 0, 0)
		_handles.add_child(g)
		_verts.append(g)
		if i > 0:
			var q = N[i - 1]
			var d := Vector2(float(n.y) - float(q.y), float(n.z) - float(q.z)).length()
			var cm := CylinderMesh.new()
			cm.top_radius = .028
			cm.bottom_radius = .028
			cm.height = maxf(d, .001)
			cm.radial_segments = 8
			cm.rings = 1
			var c := MeshInstance3D.new()
			c.mesh = cm
			c.material_override = _cord_mat
			c.position = Vector3(0, (float(n.y) + float(q.y)) / 2, (float(n.z) + float(q.z)) / 2)
			var dir := Vector3(0, float(n.y) - float(q.y), float(n.z) - float(q.z)).normalized()
			if dir.length() > .5:
				c.basis = Basis(Quaternion(Vector3.UP, dir)) if dir.dot(Vector3.UP) > -0.999 else Basis(Vector3.RIGHT, PI)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_handles.add_child(c)
	_handles.visible = _spine_alpha > .02 and not _playing

## A cylinder / cone piece of a vertebra: bottom radius, top radius, height. (top 0 = cone apex up.)
func _vert_part(parent: Node3D, top: float, bottom: float, h: float, y: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = cm
	m.material_override = _vert_mat
	m.position.y = y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

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
	if _hover_part >= 0 and _hover_part != _selected:
		for mi in _part_meshes(_hover_part):
			(mi as MeshInstance3D).material_overlay = _hover_mat
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
	_ctl.reset(Vector3(PATH_C.x + PATH_R, -creature.ground_offset, 0.0), 0.0)

const PATH_C := Vector2(-7.0, 0.0)
const PATH_R := 7.0

func _loco_step(dt: float) -> void:
	_time += dt
	var speed := clampf(float(_ctl.morph.hip_height) * 1.4, 0.6, 4.0) if _ctl.morph.legs.size() > 0 else 0.8
	if _run:
		speed *= 1.8
	var w := speed / PATH_R
	var a := _time * w
	var pos := Vector3(PATH_C.x + cos(a) * PATH_R, -creature.ground_offset, PATH_C.y + sin(a) * PATH_R)
	var vel := Vector3(-sin(a) * PATH_R * w, 0.0, cos(a) * PATH_R * w)
	_ctl.step(maxf(dt, 1e-4), pos, atan2(vel.x, vel.z), vel)
	_adapter.loco_apply(creature, _ctl.pose, _desc)
	_tick_actions(dt)

## Bite swings the jaw hooks, sing pulses the sacs (hooks from creature.animation_hooks()).
func _tick_actions(dt: float) -> void:
	for k in _actions.keys():
		_actions[k] -= dt
		if _actions[k] <= 0.0:
			_actions.erase(k)
	var bite: float = sin(clampf(float(_actions.get("bite", 0.0)) / 1.2, 0.0, 1.0) * PI) * .6
	var sing: float = sin(clampf(float(_actions.get("sing", 0.0)) / 1.2, 0.0, 1.0) * PI)
	for e in creature.animation_hooks():
		for hk in e.hooks:
			var node = e.hooks[hk] if e.hooks is Dictionary else null
			if node is Node3D:
				if hk == "jaw":
					(node as Node3D).rotation.x = bite
				elif hk == "sacs":
					(node as Node3D).scale = Vector3.ONE * (1.0 + .35 * sing)

func action_active(a: String) -> bool:
	return _actions.has(a)

func _process(dt: float) -> void:
	if _playing and _ctl != null:
		_loco_step(minf(dt, 0.1))
	_tick_spine(dt)
	_tick_handles(dt)
	_tick_alive(dt)
	_tick_selection(dt)
	_tick_pulses(dt)

# ------------------------------------------------------------------ spine overlay (fade, hover)
func set_hover_node(i: int) -> void:
	_hover_node = i

func set_active_node(i: int) -> void:
	_active_node = i

func _tick_spine(dt: float) -> void:
	var want := 1.0 if (_spine_on and not _playing) or _active_node >= 0 else 0.0
	_spine_alpha = lerpf(_spine_alpha, want, 1.0 - pow(.0004, dt))
	_vert_mat.albedo_color.a = _spine_alpha * .96
	_cord_mat.albedo_color.a = _spine_alpha * .85
	_handles.visible = _spine_alpha > .02 and not _playing
	for i in _verts.size():
		var target := 1.3 if (i == _hover_node or i == _active_node) else 1.0
		var g: Node3D = _verts[i]
		g.scale = g.scale.lerp(Vector3.ONE * target, 1.0 - pow(.001, dt))

## Blue vertebra spheres (yellow when hovered or dragged) and the green part ring: fade in 120 ms, constant screen size.
func _tick_handles(dt: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var want := 1.0 if ((_spine_on and not _playing) or _active_node >= 0) else 0.0
	if want > 0.0 and _sphere_alpha <= .01:
		handle_shown.emit("vertebra_sphere", HANDLE_FADE * 1000.0)
	_sphere_alpha = move_toward(_sphere_alpha, want, dt / HANDLE_FADE)
	_sphere_mat.albedo_color.a = _sphere_alpha
	_sphere_hot_mat.albedo_color.a = _sphere_alpha
	_sphere_group.visible = _sphere_alpha > .01
	if _sphere_group.visible and cam != null:
		var px := 2.0 * tan(deg_to_rad(cam.fov) / 2.0) / maxf(get_viewport().get_visible_rect().size.y, 1.0) * SPHERE_PX
		for i in _spheres.size():
			var sp: MeshInstance3D = _spheres[i]
			var hot := i == _hover_node or i == _active_node
			sp.material_override = _sphere_hot_mat if hot else _sphere_mat
			var d := cam.global_position.distance_to(sp.global_position)
			sp.scale = Vector3.ONE * d * px * (1.3 if hot else 1.0)
	var rp := _hover_part if _hover_part >= 0 else _selected
	var want_ring := 1.0 if (rp >= 0 and rp < genome.get("parts", []).size() and not _playing) else 0.0
	if want_ring > 0.0 and _ring_alpha <= .01:
		handle_shown.emit("part_ring", HANDLE_FADE * 1000.0)
	_ring_alpha = move_toward(_ring_alpha, want_ring, dt / HANDLE_FADE)
	_ring_mat.albedo_color.a = _ring_alpha * .95
	if want_ring > 0.0:
		_ring_part = rp
	_ring_green.visible = _ring_alpha > .01 and _ring_part >= 0 and _ring_part < genome.get("parts", []).size()
	if _ring_green.visible and cam != null:
		var ax := surface_axes(_ring_part)
		if ax.is_empty():
			_ring_green.visible = false
		else:
			var p: Dictionary = genome.parts[_ring_part]
			var rad: float = float(p.get("w", .2)) * 2.6 if _is_leg(p.type) else .42 * float(p.get("size", 1.0))
			var pos: Vector3 = ax.p + ax.n * .03
			var toc: Vector3 = (cam.global_position - to_global(pos)).normalized()
			var b := Basis.looking_at(-toc, Vector3.UP)   # torus lies in XZ: rotate so its axis faces the camera
			b = b * Basis(Vector3.RIGHT, PI / 2)
			_ring_green.transform = Transform3D(b.scaled(Vector3.ONE * rad), pos)

## The head turns to the part that was just placed (after a short reaction delay) and the creature flexes once.
func look_at_part(i: int) -> void:
	_look_part = i
	_look_wait = LOOK_DELAY

## Idle breathing, head turn and one-shot pose. Visual only (bone poses on the editor skeleton); the sim never sees it.
func _tick_alive(dt: float) -> void:
	if creature == null or _playing:
		_yaw = 0.0
		return
	_alive_t += dt
	var br := sin(TAU * _alive_t / BREATH_PERIOD)
	creature.scale = Vector3(1.0 + .004 * br, 1.0 + .009 * br, 1.0 + .004 * br)
	if _look_wait >= 0.0:
		_look_wait -= dt
		if _look_wait < 0.0:
			_look_hold = LOOK_HOLD
			var goal := _look_goal()
			_yaw_goal = goal
			head_target_changed.emit(_look_part)
			if _alive_t - _last_pose >= POSE_GAP:
				_pose_t = 0.0
				_last_pose = _alive_t
	elif _look_hold > 0.0:
		_look_hold -= dt
		if _look_hold <= 0.0:
			_yaw_goal = 0.0
	_yaw = lerpf(_yaw, _yaw_goal, 1.0 - exp(-dt / .09))
	var pitch := 0.0
	if _pose_t >= 0.0:
		_pose_t += dt
		if _pose_t >= POSE_LEN:
			_pose_t = -1.0
		else:
			pitch = -.28 * sin(PI * _pose_t / POSE_LEN)
	var sk: Skeleton3D = creature.get("skeleton")
	var hb: int = int(creature.get("head_bone")) if creature.get("head_bone") != null else -1
	var neck = creature.get("neck_bones")
	if sk == null or hb < 0 or hb >= sk.get_bone_count() or neck == null:
		return
	var chain: Array = []
	for b in neck:
		chain.append(int(b))
	chain.append(hb)
	var share := 1.0 / float(chain.size())
	for b in chain:
		if b < 0 or b >= sk.get_bone_count():
			continue
		var rest := sk.get_bone_rest(b)
		var q := Basis(Vector3.UP, _yaw * share) * Basis(Vector3.RIGHT, pitch * share)
		sk.set_bone_pose(b, Transform3D(rest.basis * q, rest.origin))

## Yaw (clamped) from the head's rest direction to the part, in the head bone's own frame.
func _look_goal() -> float:
	var sk: Skeleton3D = creature.get("skeleton")
	var hb: int = int(creature.get("head_bone")) if creature.get("head_bone") != null else -1
	if sk == null or hb < 0 or _look_part < 0 or _look_part >= genome.get("parts", []).size():
		return 0.0
	var ax := surface_axes(_look_part)
	if ax.is_empty():
		return 0.0
	var gr := sk.get_bone_global_rest(hb)
	var dir: Vector3 = gr.basis.inverse() * ((ax.p as Vector3) - gr.origin)
	return clampf(atan2(dir.x, dir.z), -YAW_MAX, YAW_MAX)

## Probe for the scorecard.
func sphere_count() -> int:
	return _spheres.size() if _sphere_alpha > .5 else 0

func ring_visible() -> bool:
	return _ring_green.visible and _ring_alpha > .5

func spine_alpha() -> float:
	return _spine_alpha

func hovered_node() -> int:
	return _hover_node

func vertebra_scale(i: int) -> float:
	return (_verts[i] as Node3D).scale.x if i >= 0 and i < _verts.size() else 0.0

# ------------------------------------------------------------------ hover highlight, drag helpers
func set_hover_part(i: int) -> void:
	if i == _hover_part:
		return
	_hover_part = i
	_apply_selection()

## Hide (true) or show a part while it is dragged off the body.
func hide_part(i: int, hidden: bool) -> void:
	_hidden_part = i if hidden else -1
	_apply_hidden()

func _apply_hidden() -> void:
	for e in creature.parts:
		if e.get("node") != null:
			e.node.visible = e.index != _hidden_part
	for l in creature.legs:
		for n in [l.upper, l.lower, l.foot]:
			n.visible = l.part_index != _hidden_part

func is_part_hidden(i: int) -> bool:
	return _hidden_part == i

## Drop animation: the part pops (scale overshoot) for a moment.
func pulse_part(i: int) -> void:
	_pulses[i] = .45

func _tick_pulses(dt: float) -> void:
	for i in _pulses.keys():
		_pulses[i] -= dt
		var k: float = clampf(_pulses[i] / .45, 0.0, 1.0)
		var sc := 1.0 + .28 * sin(k * PI) * k
		for e in creature.parts:
			if e.index == i:
				(e.node as Node3D).scale = Vector3.ONE * sc
		if _pulses[i] <= 0.0:
			_pulses.erase(i)
			for e in creature.parts:
				if e.index == i:
					(e.node as Node3D).scale = Vector3.ONE

func pulsing(i: int) -> bool:
	return _pulses.has(i)

# ------------------------------------------------------------------ selection rings, rotation bead, leg handles
func _build_sel_nodes() -> void:
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("ffc04a", .95)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.no_depth_test = true
	rm.render_priority = 20
	for k in 2:
		var tm := TorusMesh.new()
		tm.inner_radius = .965
		tm.outer_radius = 1.035
		tm.rings = 40
		tm.ring_segments = 8
		var r := MeshInstance3D.new()
		r.mesh = tm
		r.material_override = rm
		r.visible = false
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sel_group.add_child(r)
		_rings.append(r)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color("9fd45c")
	bm.no_depth_test = true
	bm.render_priority = 22
	var sm := SphereMesh.new()
	sm.radius = .1
	sm.height = .2
	_rot_bead = MeshInstance3D.new()
	_rot_bead.mesh = sm
	_rot_bead.material_override = bm
	_rot_bead.visible = false
	_rot_bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sel_group.add_child(_rot_bead)
	_leg_group = Node3D.new()
	_sel_group.add_child(_leg_group)

func _is_leg(type: String) -> bool:
	return creature.maker != null and creature.maker.is_leg(type)

## Surface frame at a part's anchor (same maths as rig.js orient()): {p, n, x, y}.
func surface_axes(index: int, side := 1) -> Dictionary:
	if index < 0 or index >= genome.get("parts", []).size():
		return {}
	var p: Dictionary = genome.parts[index]
	var A: Dictionary = creature.anchor(float(p.t), side * float(p.ang))
	var n: Vector3 = A.n
	var u: Vector3 = A.u
	var b: Vector3 = u - n * n.dot(u) + A.t * n.dot(u)
	b -= n * b.dot(n)
	if b.length_squared() < 1e-4:
		b = A.t
	b = b.normalized()
	return {"p": A.p, "n": n, "x": b.cross(n), "y": b}

func _update_sel_nodes() -> void:
	for r in _rings:
		(r as Node3D).visible = false
	_rot_bead.visible = false
	for c in _leg_group.get_children():
		c.queue_free()
	if _playing:
		return
	var hl := handle_leg()
	if hl >= 0:
		_build_leg_handles(hl)
	if _selected < 0 or _selected >= genome.get("parts", []).size():
		return
	var p: Dictionary = genome.parts[_selected]
	var leg := _is_leg(p.type)
	var centered := not leg and absf(sin(float(p.ang))) < .14
	for i in 2:
		var sg := 1 if i == 0 else -1
		var r: MeshInstance3D = _rings[i]
		r.visible = i == 0 or not centered
		if not r.visible:
			continue
		var ax := surface_axes(_selected, sg)
		var sc: float = float(p.get("w", .2)) * 2.4 if leg else .32 * float(p.get("size", 1.0))
		var yv: Vector3 = ax.n
		var q := Quaternion(Vector3.UP, yv) if yv.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
		r.transform = Transform3D(Basis(q).scaled(Vector3.ONE * sc), ax.p + ax.n * .03)
	if not leg:
		_rot_bead.visible = true
		_rot_bead.position = rot_handle_pos(_selected)

func _tick_selection(dt: float) -> void:
	_sel_time += dt
	if _rot_bead.visible:
		var s := 1.4 if _bead_hot else 1.0
		_rot_bead.scale = _rot_bead.scale.lerp(Vector3.ONE * s, 1.0 - pow(.001, dt))

func set_bead_hot(on: bool) -> void:
	_bead_hot = on

## View-space position of the green rotation bead for part `index` ({} part => Vector3.ZERO).
func rot_handle_pos(index: int) -> Vector3:
	var ax := surface_axes(index)
	if ax.is_empty():
		return Vector3.ZERO
	var p: Dictionary = genome.parts[index]
	var rr := .32 * float(p.get("size", 1.0))
	var a := float(p.get("rot", 0.0))
	return ax.p + ax.x * (-sin(a) * rr) + ax.y * (cos(a) * rr) + ax.n * .03

## New `rot` for a ray dragged on the part's surface plane (NAN when the ray misses it).
func rot_from_ray(index: int, origin: Vector3, dir: Vector3) -> float:
	var ax := surface_axes(index)
	if ax.is_empty():
		return NAN
	var pl := Plane(ax.n, (ax.p as Vector3).dot(ax.n))
	var hit = pl.intersects_ray(origin, dir)
	if hit == null:
		return NAN
	var w: Vector3 = hit - ax.p
	return atan2(-w.dot(ax.x), w.dot(ax.y))

func _joint_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 17
	return m

## Knee and foot handles of the selected leg, both sides: [{joint: "k"|"f", side, pos, hip}].
func leg_handles(index: int) -> Array:
	var out := []
	if index < 0 or index >= genome.get("parts", []).size():
		return out
	for l in creature.legs:
		if l.part_index != index:
			continue
		var hip: Vector3 = creature.anchor(float(genome.parts[index].t), l.side * float(genome.parts[index].ang)).p
		out.append({"joint": "k", "side": l.side, "pos": hip + l.rest_knee, "hip": hip})
		out.append({"joint": "f", "side": l.side, "pos": hip + l.rest_foot, "hip": hip})
	return out

## Joint handles belong to the hovered leg, else to the selected leg: any limb can be grabbed without selecting it.
func set_hover_leg(i: int) -> void:
	if i == _hover_leg:
		return
	_hover_leg = i
	_update_sel_nodes()

func handle_leg() -> int:
	if _hover_leg >= 0 and _hover_leg < genome.get("parts", []).size():
		return _hover_leg
	if _selected >= 0 and _selected < genome.get("parts", []).size() and _is_leg(genome.parts[_selected].type):
		return _selected
	return -1

func _build_leg_handles(index: int) -> void:
	var m := _joint_mat(Color("6fd3ff", .95))
	var hs := leg_handles(index)
	var by_side := {}
	for h in hs:
		var sm := SphereMesh.new()
		sm.radius = .13
		sm.height = .26
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = m
		mi.position = h.pos
		mi.name = "Joint_%s_%d" % [h.joint, h.side]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_leg_group.add_child(mi)
		by_side[h.side] = by_side.get(h.side, [h.hip])
		by_side[h.side].append(h.pos)
	for side in by_side:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for pt in by_side[side]:
			im.surface_add_vertex(pt)
		im.surface_end()
		var lm := _joint_mat(Color("6fd3ff", .75))
		var line := MeshInstance3D.new()
		line.mesh = im
		line.material_override = lm
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_leg_group.add_child(line)

## Ray drag of a leg joint. Returns {} or {key: "k"|"f", value: [x, y, z]} to store in the part (web joint drag rules).
func leg_drag(index: int, joint: String, side: int, origin: Vector3, dir: Vector3, cam_forward: Vector3) -> Dictionary:
	var hs := leg_handles(index)
	for h in hs:
		if h.joint != joint or h.side != side:
			continue
		var p: Dictionary = genome.parts[index]
		var wp = null
		if joint == "f":
			var plane_y: float = -creature.ground_offset + float(p.get("w", .2)) * .6
			if dir.y < -1e-3:
				wp = Plane(Vector3.UP, plane_y).intersects_ray(origin, dir)
		else:
			wp = Plane(cam_forward, (h.pos as Vector3).dot(cam_forward)).intersects_ray(origin, dir)
		if wp == null:
			return {}
		var r: Vector3 = wp - h.hip
		var v := [r.x * side, r.y, r.z]
		if joint == "k":
			if Vector3(v[0], v[1], v[2]).length() > .15:
				return {"key": "k", "value": v}
		elif Vector2(v[0], v[2]).length() < 6.0:
			return {"key": "f", "value": [v[0], float(p.f[1]), v[2]]}
		return {}
	return {}

# ------------------------------------------------------------------ misc for the shell
func floor_y() -> float:
	return -creature.ground_offset

## Creature body position in view space (it walks along the path in Test mode).
func body_position() -> Vector3:
	if _playing and _ctl != null:
		return creature.position + Vector3(0, creature.ground_offset, 0)
	return Vector3.ZERO

func is_playing() -> bool:
	return _playing

func stats() -> Dictionary:
	return creature.stats

## Test mode actions: bite (jaw), sing (puffing sacs) timers, run toggle.
func trigger(action: String) -> void:
	_actions[action] = 1.2

func set_run(on: bool) -> void:
	_run = on

## View-space surface point at (t, ang): where a part would be placed (also used by tests and evidence).
func part_anchor_at(t: float, ang: float) -> Vector3:
	return creature.anchor(t, ang).p
