extends SceneTree
# make godot-feel-evidence (PLAN-feel S7): the figure eight and a reversal on the real island, software GL only.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --path godot \
#     --script res://game/tests/feel_evidence.gd -- <out dir>
# Writes fig8_top.png and fig8_chase.png (4x4 contact sheets over one loop, a fixed high camera and the chase
# camera), fig8_path.png (the C ticks in white, the Hermite path in orange, footfalls as cyan dots) and
# reverse_chase.png (8 chase frames of a run-then-back reversal).

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const PlayerInput := preload("res://game/player/player_input.gd")

const TW := 480
const TH := 270
const LOOP := 2.0 * PI / 1.2         # one period of the figure eight heading (cos 1.2 t, cos 2.4 t)

var out_dir := ""
var game
var island: Node3D
var tick0 := 0
var fig8_on := false
var c_pts: Array = []            # Vector2 at every C tick
var h_pts: Array = []            # Vector2 every frame (the interpolated path)
var feet: Array = []             # Vector2 footfalls

func _initialize() -> void:
	_run.call_deferred()

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

# Game time without drawing (fixed-fps frames), recording the path.
func fast(seconds: float, frame := 1.0 / 30.0) -> void:
	RenderingServer.render_loop_enabled = false
	var t := 0.0
	while t < seconds - 1e-6:
		await process_frame
		_record()
		t += frame
	RenderingServer.render_loop_enabled = true
	await process_frame

func _record() -> void:
	var p: Vector3 = island.player_pos
	h_pts.append(Vector2(p.x, p.z))

func _on_tick(state: Dictionary) -> void:
	var e: Dictionary = state.entities[0]
	c_pts.append(Vector2(e.x, e.z))

func shot() -> Image:
	await settle(2)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TW, TH, Image.INTERPOLATE_BILINEAR)
	return img

func sheet(frames: Array, cols: int, name: String) -> void:
	var rows := int(ceil(frames.size() / float(cols)))
	var im := Image.create(TW * cols, TH * rows, false, Image.FORMAT_RGB8)
	for k in frames.size():
		im.blit_rect(frames[k], Rect2i(0, 0, TW, TH), Vector2i((k % cols) * TW, (k / cols) * TH))
	im.save_png(out_dir.path_join(name))
	print("wrote ", name)

func fig8_heading() -> Dictionary:
	var t: float = (island.stage.cur.tick - tick0) * 0.1
	var h := PlayerInput.heading(Vector2(cos(1.2 * t), cos(2.4 * t)))
	return {"verb": 3, "hx": h.x, "hz": h.y, "sprint": 0}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/feel-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.settings.grass = 3000
	game.settings.wild = false
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	island = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	await settle(30)
	island.stage_ui.ui.visible = false
	island.stage.ticked.connect(_on_tick)
	for h in island.hosts.values():
		h.footfall.connect(func(id: int, pos: Vector3, _s: float) -> void:
			if id == 0:
				feet.append(Vector2(pos.x, pos.z)))
	await fast(0.5)
	# ---- figure eight: warm up one loop (the heading starts from rest), then record one loop
	var normal_provider: Callable = island.stage.input_provider
	tick0 = island.stage.cur.tick
	island.stage.input_provider = fig8_heading
	fig8_on = true
	await fast(LOOP)
	# frame the loop from the warm-up path: centre and size
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in h_pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var centre := (lo + hi) / 2.0
	var extent := maxf((hi.x - lo.x) / 1.6, hi.y - lo.y) + 10.0
	var dist := extent * 0.5 / tan(deg_to_rad(24.0)) * 1.25
	print("loop extent ", hi - lo, " camera distance ", dist)
	c_pts.clear()
	h_pts.clear()
	feet.clear()
	var top_frames: Array = []
	var chase_frames: Array = []
	var n := 16
	var step := LOOP / n
	for k in n:
		chase_frames.append(await shot())
		island.chase_enabled = false
		var gy: float = game.ground(centre.x, centre.y)
		island.camera.position = Vector3(centre.x, gy, centre.y) + Vector3(0.0, dist * 0.85, dist * 0.55)
		island.camera.look_at(Vector3(centre.x, gy + 1.5, centre.y))
		top_frames.append(await shot())
		island.chase_enabled = true
		await fast(maxf(step - 4.0 / 30.0, 0.05))
	sheet(chase_frames, 4, "fig8_chase.png")
	sheet(top_frames, 4, "fig8_top.png")
	_path_image("fig8_path.png")
	# ---- reversal: run, then hold back; the camera and the creature as in the game
	island.stage.input_provider = normal_provider
	island.player_input.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	await fast(2.5)
	island.player_input.keys_override = {"forward": false, "back": true, "left": false, "right": false, "sprint": false}
	var rev: Array = []
	for k in 8:
		rev.append(await shot())
		await fast(0.2)
	sheet(rev, 4, "reverse_chase.png")
	quit()

# The C ticks (white) against the Hermite path (orange) and the footfalls (cyan), north up, scaled to fit.
func _path_image(name: String) -> void:
	var w := 1280
	var hgt := 800
	var pts: Array = []
	pts.append_array(c_pts)
	pts.append_array(h_pts)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := hi - lo
	var scale := minf((w - 120) / maxf(span.x, 1.0), (hgt - 120) / maxf(span.y, 1.0))
	var img := Image.create(w, hgt, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.09, 0.11))
	var map := func(p: Vector2) -> Vector2i:
		return Vector2i(int(60 + (p.x - lo.x) * scale), int(60 + (p.y - lo.y) * scale))
	_polyline(img, h_pts, map, Color(1.0, 0.55, 0.1), 2)
	_polyline(img, c_pts, map, Color(1, 1, 1), 1)
	for p in c_pts:
		_dot(img, map.call(p), 4, Color(1, 1, 1))
	for p in feet:
		_dot(img, map.call(p), 3, Color(0.2, 0.9, 1.0))
	img.save_png(out_dir.path_join(name))
	print("wrote ", name, " (", c_pts.size(), " ticks, ", h_pts.size(), " frames, ", feet.size(), " footfalls)")

func _dot(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r and c.x + x >= 0 and c.y + y >= 0 and c.x + x < img.get_width() and c.y + y < img.get_height():
				img.set_pixel(c.x + x, c.y + y, col)

func _polyline(img: Image, pts: Array, map: Callable, col: Color, thick: int) -> void:
	for i in range(1, pts.size()):
		var a: Vector2i = map.call(pts[i - 1])
		var b: Vector2i = map.call(pts[i])
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in range(steps + 1):
			var q := Vector2(a).lerp(Vector2(b), s / float(maxi(steps, 1)))
			_dot(img, Vector2i(int(q.x), int(q.y)), thick, col)
