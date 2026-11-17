extends Node
## Real 3D palette thumbnails (port of the thumbnail renderer in web/studio/studio.js).
## Two small off-screen worlds: one bakes still thumbnails (one part per frame, current category first),
## the other renders the hovered part live while it spins (2.4 rad/s, like the web studio).
## It needs the creature module (`creature.maker`, `creature.default_part`); with the placeholder view
## `enabled` is false and the studio keeps its procedural thumbnails.

signal baked(id: String)

const SIZE := 112
const SPIN := 2.4
const REST_YAW := .6

var creature = null                   # Creature instance (res://creature/creature.gd)
var enabled := false
var textures := {}                    # part id -> ImageTexture
var hover_id := ""
var hover_yaw := REST_YAW
var hover_texture: Texture2D
var bake_count := 0
var _queue: Array = []
var _queued := {}
var _bake: Dictionary
var _hover: Dictionary
var _models := {}                     # id -> {node, radius}
var _current := ""
var _generation := 0

func _init(creature_node = null) -> void:
	name = "ThumbBaker"
	creature = creature_node
	enabled = creature != null and "maker" in creature and DisplayServer.get_name() != "headless"
	_bake = _make_world(SubViewport.UPDATE_DISABLED)
	_hover = _make_world(SubViewport.UPDATE_DISABLED, 168)
	hover_texture = (_hover.vp as SubViewport).get_texture()

func _make_world(mode: int, px := SIZE * 2) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = mode
	vp.msaa_3d = Viewport.MSAA_DISABLED   # MSAA + transparent_bg renders nothing in the Compatibility renderer
	add_child(vp)
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.9, .92, 1.0)
	e.ambient_light_energy = .9
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = .95
	var we := WorldEnvironment.new()
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff2e0")
	sun.light_energy = 2.2
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(2, 4, 3), Vector3.ZERO)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.current = true
	var pivot := Node3D.new()
	vp.add_child(pivot)
	return {"vp": vp, "cam": cam, "pivot": pivot, "shown": ""}

# ------------------------------------------------------------------ models
func _aabb_of(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_aabb_of(c, xf, acc)

func _quat_between(a: Vector3, b: Vector3) -> Quaternion:
	if a.dot(b) < -0.9999:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(a, b)

## Build (once) the model of a part at its defaults, centred on its bounds. Returns {node, radius}.
func model_for(id: String, slot := "bake") -> Dictionary:
	var key := id + "@" + slot
	if _models.has(key):
		return _models[key]
	var p: Dictionary = creature.default_part(id)
	var maker = creature.maker
	var pivot := Node3D.new()
	var inner := Node3D.new()
	pivot.add_child(inner)
	if maker.is_leg(id):
		if not p.has("k"):                  # fitted legs have no stored joints: use the rig.js fittedPose at hip height 2
			p["w"] = .16
			p["k"] = [.32, -.96, .34]
			p["f"] = [.35, -2.0 + .096, .12]
		var K := Vector3(p.k[0], p.k[1], p.k[2])
		var F := Vector3(p.f[0], p.f[1], p.f[2])
		var segs: Dictionary = maker.make_leg(id, p, Vector3.ZERO, K.length(), (F - K).length())
		var down := Vector3(0, -1, 0)
		segs.up.basis = Basis(_quat_between(down, K.normalized()))
		segs.lo.position = K
		segs.lo.basis = Basis(_quat_between(down, (F - K).normalized()))
		segs.ft.position = Vector3(F.x, F.y - float(p.w) * .6, F.z)
		for k in ["up", "lo", "ft"]:
			inner.add_child(segs[k])
	else:
		var m: Dictionary = maker.meta(id)
		inner.add_child(maker.make(p, Vector3(0, 1, 0)))
		if m.get("responsive", false) and m.get("category", "") in ["wings", "fins"]:
			inner.rotation.x = -.65
	maker.finalize(pivot)                 # meshes are built from the geometry once the part tree is final
	var acc := [null]
	_aabb_of(pivot, Transform3D.IDENTITY, acc)
	var bb: AABB = acc[0] if acc[0] != null else AABB(Vector3(-.3, -.3, -.3), Vector3(.6, .6, .6))
	inner.position -= bb.get_center()
	var out := {"node": pivot, "radius": maxf(bb.size.length() / 2.0, .05)}
	_models[key] = out
	return out

func _show(world: Dictionary, id: String, yaw: float, slot: String) -> void:
	var m := model_for(id, slot)
	var pivot: Node3D = world.pivot
	if world.shown != id:
		for c in pivot.get_children():
			pivot.remove_child(c)
		pivot.add_child(m.node)
		world.shown = id
	(m.node as Node3D).rotation.y = yaw
	var d: float = float(m.radius) / sin(.262) * 1.08
	var cam: Camera3D = world.cam
	cam.look_at_from_position(Vector3(0, d * .32, d), Vector3.ZERO)

## Forget cached models and textures (skin changed or genome rebuilt) and re-bake in the background.
func invalidate() -> void:
	_generation += 1
	for id in _models:
		if is_instance_valid(_models[id].node):
			(_models[id].node as Node).queue_free()
	_models.clear()
	_bake.shown = ""
	_hover.shown = ""
	var ids := textures.keys()
	textures.clear()
	_queue.clear()
	_queued.clear()
	for id in ids:
		request(id)

func request(id: String) -> void:
	if not enabled or textures.has(id) or _queued.has(id):
		return
	_queued[id] = true
	_queue.append(id)

func request_front(ids: Array) -> void:
	for id in ids:
		if enabled and not textures.has(id):
			if _queued.has(id):
				_queue.erase(id)
			_queued[id] = true
	var rev := ids.duplicate()
	rev.reverse()
	for id in rev:
		if enabled and not textures.has(id):
			_queue.push_front(id)

func has_texture(id: String) -> bool:
	return textures.has(id)

# ------------------------------------------------------------------ hover
func start_hover(id: String) -> void:
	if not enabled:
		hover_id = id
		hover_yaw = REST_YAW
		return
	hover_id = id
	hover_yaw = REST_YAW
	_show(_hover, id, hover_yaw, "hover")
	(_hover.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS

func stop_hover() -> void:
	hover_id = ""
	hover_yaw = REST_YAW
	if enabled:
		(_hover.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(dt: float) -> void:
	if hover_id != "":
		hover_yaw += dt * SPIN
		if enabled and not _hover.is_empty():
			_show(_hover, hover_id, hover_yaw, "hover")
	if not enabled or _queue.is_empty() or _current != "":
		return
	_current = _queue.pop_front()
	_bake_one(_current, _generation)

func _bake_one(id: String, gen: int) -> void:
	_show(_bake, id, REST_YAW, "bake")
	var vp: SubViewport = _bake.vp
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if gen == _generation:
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)   # supersampled: the viewport has no MSAA
			textures[id] = ImageTexture.create_from_image(img)
			bake_count += 1
			baked.emit(id)
	_queued.erase(id)
	_current = ""
