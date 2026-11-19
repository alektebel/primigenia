extends Node
## The pictures of the field journal, drawn by the game's own creature and part builders (no external art):
## a side-view portrait of each species and a thumbnail of each part, rendered once into small transparent
## SubViewports and kept as textures. A silhouette (the same picture flattened to one ink tone) stands in for
## what the player has not met or found. In a headless run nothing can be rendered: `portrait()` and `part()`
## return null and the pages draw a plain placeholder.

const Baker := preload("res://studio/thumb_baker.gd")

signal changed

const PORTRAIT_SIZE := Vector2i(360, 240)
const SILHOUETTE := Color("#3b382d")

var textures := {}                 # "s:<body>" -> Texture2D
var silhouettes := {}              # "s:<body>" / "p:<id>" -> Texture2D
var baker: Node
var enabled := false
var _queue: Array = []
var _queued := {}
var _busy := false
var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _creature: Node3D               # a Creature kept for the part baker
var _gen := 0

func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	_vp = SubViewport.new()
	_vp.size = PORTRAIT_SIZE
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.93, 1.0)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = e
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff0dc")
	sun.light_energy = 2.0
	_vp.add_child(sun)
	sun.look_at_from_position(Vector3(-2.5, 4.0, 3.5), Vector3.ZERO)
	_cam = Camera3D.new()
	_cam.fov = 38
	_vp.add_child(_cam)
	_cam.current = true
	_pivot = Node3D.new()
	_vp.add_child(_pivot)

# --- species portraits ------------------------------------------------------------------------------------------------

## Ask for the portrait of a species body (res://game/data/<body>.json); it arrives later (signal `changed`).
func request_portrait(body: String) -> void:
	var key := "s:" + body
	if not enabled or textures.has(key) or _queued.has(key):
		return
	if not FileAccess.file_exists("res://game/data/%s.json" % body):
		return
	_queued[key] = true
	_queue.append(body)

func portrait(body: String, silhouette: bool) -> Texture2D:
	var key := "s:" + body
	return (silhouettes if silhouette else textures).get(key, null)

func _process(_dt: float) -> void:
	if not enabled or _busy or _queue.is_empty():
		return
	_busy = true
	_bake_portrait(String(_queue.pop_front()), _gen)

func _bake_portrait(body: String, gen: int) -> void:
	var key := "s:" + body
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % body))
	var c := Creature.new()
	_pivot.add_child(c)
	var r: Dictionary = c.load_genome(g) if g is Dictionary else {"ok": false}
	if bool(r.get("ok", false)):
		# side view framed on the body's bounds (a tall Zanco and a long Espinodo both fit the 3:2 picture)
		var bb: AABB = c.rest_aabb()
		var mid := bb.get_center()
		var half_t := tan(deg_to_rad(_cam.fov * 0.5))
		var aspect := float(PORTRAIT_SIZE.x) / PORTRAIT_SIZE.y
		var dist := maxf(bb.size.y * 1.12 * 0.5 / half_t, bb.size.z * 1.12 * 0.5 / (half_t * aspect)) + bb.size.x * 0.5 + 0.4
		_cam.look_at_from_position(mid + Vector3(dist, dist * 0.05, 0.0), mid)
		for i in 3:
			await get_tree().process_frame
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if gen == _gen:
			var img := _vp.get_texture().get_image()
			if img != null and not img.is_empty():
				img.convert(Image.FORMAT_RGBA8)
				textures[key] = ImageTexture.create_from_image(img)
				silhouettes[key] = ImageTexture.create_from_image(flatten(img))
				changed.emit()
	c.queue_free()
	_queued.erase(key)
	_busy = false

# --- part thumbnails --------------------------------------------------------------------------------------------------

func request_parts(ids: Array) -> void:
	if not enabled:
		return
	if baker == null:
		_creature = Creature.new()
		_creature.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_creature)
		_creature.load_genome(Creature.seeds()["Merodeador"])      # the part maker exists once a body is built
		baker = Baker.new(_creature)
		baker.baked.connect(_on_part_baked)
		add_child(baker)
	if baker.enabled:
		baker.request_front(ids)

func part(id: String, silhouette: bool) -> Texture2D:
	if baker == null or not baker.has_texture(id):
		return null
	if not silhouette:
		return baker.textures[id]
	var key := "p:" + id
	if not silhouettes.has(key):
		var img: Image = (baker.textures[id] as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		silhouettes[key] = ImageTexture.create_from_image(flatten(img))
	return silhouettes[key]

func _on_part_baked(_id: String) -> void:
	changed.emit()

# --- silhouettes ------------------------------------------------------------------------------------------------------

## The picture as one flat ink tone, alpha kept (a shape to be discovered).
static func flatten(img: Image) -> Image:
	var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, img.get_data())
	var d := out.get_data()
	var r := int(SILHOUETTE.r8)
	var g := int(SILHOUETTE.g8)
	var b := int(SILHOUETTE.b8)
	for i in range(0, d.size(), 4):
		d[i] = r
		d[i + 1] = g
		d[i + 2] = b
		d[i + 3] = int(d[i + 3] * 0.82)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
