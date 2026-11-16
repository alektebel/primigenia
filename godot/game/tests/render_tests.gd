extends SceneTree
# Software-GL render tests: godot --rendering-driver opengl3 --script res://game/tests/render_tests.gd
# (make godot-render-test). Calibrates Godot's ACES against three.js and checks the look pipeline.

const Look := preload("res://game/island/look.gd")
const EnvironmentFactory := preload("res://game/island/environment.gd")
const CALIBRATE := preload("res://game/shaders/calibrate.gdshader")

var checks := 0
var failures := 0
var results := {}
var cam: Camera3D
var world_root: Node3D
var env: Environment

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + what)
	return ok

# ---- reference curves (three.js r128), in doubles -------------------------------------------
static func rrt(v: float) -> float:
	return (v * (v + 0.0245786) - 0.000090537) / (v * (0.983729 * v + 0.4329510) + 0.238081)

static func three_aces(c: Vector3) -> Vector3:
	var x := c / 0.6
	var i := Vector3(0.59719 * x.x + 0.35458 * x.y + 0.04823 * x.z,
		0.07600 * x.x + 0.90834 * x.y + 0.01566 * x.z,
		0.02840 * x.x + 0.13383 * x.y + 0.83777 * x.z)
	var r := Vector3(rrt(i.x), rrt(i.y), rrt(i.z))
	var o := Vector3(1.60475 * r.x - 0.53108 * r.y - 0.07367 * r.z,
		-0.10208 * r.x + 1.10813 * r.y - 0.00605 * r.z,
		-0.00327 * r.x - 0.07276 * r.y + 1.07602 * r.z)
	return Vector3(clampf(o.x, 0, 1), clampf(o.y, 0, 1), clampf(o.z, 0, 1))

static func srgb_enc(v: float) -> float:
	return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055

static func srgb_enc3(c: Vector3) -> Vector3:
	return Vector3(srgb_enc(c.x), srgb_enc(c.y), srgb_enc(c.z))

# ---- rig -------------------------------------------------------------------------------------
func build_rig() -> void:
	root.size = Vector2i(1280, 720)
	world_root = Node3D.new()
	root.add_child(world_root)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 9.0
	cam.position = Vector3(0, 0, 10)
	cam.near = 0.1
	cam.far = 50.0
	world_root.add_child(cam)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	world_root.add_child(we)

func settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw

func capture() -> Image:
	await settle()
	return root.get_texture().get_image()

# Patch grid: unshaded quads in `cols` columns; cell size fits 16 x 9 world units.
func grid_cell(count: int, cols: int) -> float:
	return minf(16.0 / cols, 9.0 / ceili(float(count) / cols))

func grid_center(k: int, count: int, cols: int) -> Vector2:
	var cell := grid_cell(count, cols)
	var rows := ceili(float(count) / cols)
	return Vector2(-cols * cell * 0.5 + (k % cols + 0.5) * cell, rows * cell * 0.5 - (k / cols + 0.5) * cell)

func show_patches(values: Array, cols: int, mode: int) -> Image:
	for c in world_root.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	await process_frame
	var cell := grid_cell(values.size(), cols)
	for k in values.size():
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(cell * 0.9, cell * 0.9)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = CALIBRATE
		m.set_shader_parameter("value", values[k])
		m.set_shader_parameter("mode", mode)
		mi.material_override = m
		var c2 := grid_center(k, values.size(), cols)
		mi.position = Vector3(c2.x, c2.y, 0)
		world_root.add_child(mi)
	return await capture()

func patch_pixel(img: Image, k: int, count: int, cols: int) -> Color:
	var c := grid_center(k, count, cols)
	return img.get_pixel(int((c.x + 8.0) / 16.0 * img.get_width()), int((4.5 - c.y) / 9.0 * img.get_height()))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	build_rig()
	await settle(3)
	await calibrate_tonemap()
	await round_trip()
	await sky_test()
	await island_checks()
	write_json()
	print("render tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# ---- 1. ACES calibration ----------------------------------------------------------------------
func calibrate_tonemap() -> void:
	var levels := [0.02, 0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2]
	var tints := [Vector3(1, 1, 1), Vector3(1.0, 0.5, 0.25), Vector3(0.3, 0.8, 1.0), Vector3(0.2, 1.0, 0.3)]
	var values := []
	var expected := []
	for t in tints:
		for l in levels:
			var v: Vector3 = t * l
			values.append(v)
			expected.append(srgb_enc3(three_aces(v)))
	var best := {"err": 1e9}
	var log_rows := []
	for white in [15.4, 14.3, 12.0, 16.5, 20.0]:
		var r = await _measure(values, expected, 0.926, white)
		log_rows.append(r)
		if r.err < best.err:
			best = r
	# Refine exposure around the best white.
	for exposure in [0.9, 0.915, 0.94, 0.96]:
		var r = await _measure(values, expected, exposure, best.white)
		log_rows.append(r)
		if r.err < best.err:
			best = r
	for r in log_rows:
		print("  candidate exposure %.3f white %.1f error %.2f/255" % [r.exposure, r.white, r.err * 255.0])
	print("ACES calibration best: exposure %.3f white %.2f max error %.2f/255" % [best.exposure, best.white, best.err * 255.0])
	results["calibration"] = {"best": best, "tried": log_rows,
		"reference": "three.js r128 ACESFilmic, exposure 1, sRGB-encoded", "gate_255": 3.0}
	check(best.err * 255.0 <= 3.0, "ACES fit gate: max error %.2f/255 <= 3" % (best.err * 255.0))

func _measure(values: Array, expected: Array, exposure: float, white: float) -> Dictionary:
	env.tonemap_exposure = exposure
	env.tonemap_white = white
	var img := await show_patches(values, 8, 0)
	var worst := 0.0
	for k in values.size():
		var px := patch_pixel(img, k, values.size(), 8)
		var ex: Vector3 = expected[k]
		worst = maxf(worst, maxf(absf(px.r - ex.x), maxf(absf(px.g - ex.y), absf(px.b - ex.z))))
	return {"exposure": exposure, "white": white, "err": worst}

# ---- 4. island: contact shadow, water vs land, no cracks ----------------------------------
func window_luma(img: Image, p: Vector2, r: int = 3) -> float:
	var sum := 0.0
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := img.get_pixel(clampi(int(p.x) + dx, 0, img.get_width() - 1), clampi(int(p.y) + dy, 0, img.get_height() - 1))
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return sum / n

func island_checks() -> void:
	for c in world_root.get_children():
		c.queue_free()
	await process_frame
	var game = root.get_node("Game")
	var rig = load("res://game/tests/island_rig.gd")
	game.settings.wild = false
	var island = rig.load_island(self, 1, 8000)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var player: Vector3 = island.player_pos
	var sun_h := Vector2(Look.sun_dir().x, Look.sun_dir().z).normalized()
	var shade_pt := player + Vector3(-sun_h.x, 0, -sun_h.y) * 5.0
	var lit_pt := player + Vector3(sun_h.x, 0, sun_h.y) * 3.0
	shade_pt.y = game.ground(shade_pt.x, shade_pt.z)
	lit_pt.y = game.ground(lit_pt.x, lit_pt.z)
	var img := await capture()
	var a := window_luma(img, island.camera.unproject_position(shade_pt))
	var b := window_luma(img, island.camera.unproject_position(lit_pt))
	print("contact shadow: shaded %.3f vs lit %.3f" % [a, b])
	check(a < b * 0.92, "the ground on the sun-opposite side of the creature is darker than 3 m away on the sun side")
	island.occluders_enabled = false
	for i in 3:
		await process_frame
	island._update_actors(0.0)
	img = await capture()
	var a2 := window_luma(img, island.camera.unproject_position(shade_pt))
	print("contact shadow off: %.3f" % a2)
	check(a2 > a * 1.05, "without occluders the same ground is brighter")
	results["contact_shadow"] = {"shaded": a, "lit": b, "shaded_without_occluders": a2}

	# Land is not water: the valley seen from above is green, not blue.
	island.chase_enabled = false
	island.camera.position = Vector3(0, 400, 0.01)
	island.camera.look_at(Vector3(0, 42, 0), Vector3(0, 0, -1))
	island.terrain_chunks.update_lods(island.camera.global_position, true)
	img = await capture()
	var land_pt := Vector3(30, game.ground(30, 30), 30)
	var land_px: Vector2 = island.camera.unproject_position(land_pt)
	var c := img.get_pixel(int(land_px.x), int(land_px.y))
	check(c.g > c.b and c.g > c.r * 0.9, "land at the valley centre is not covered by water (pixel %s)" % c)
	results["land_pixel"] = [c.r, c.g, c.b]

	# No cracks: with the water hidden, a top-down view at LOD 4 shows no sky pixels in the island square.
	island.water.visible = false
	island.grass.visible = false
	for ch in island.terrain_chunks.chunks:
		ch.lod = 4
		ch.node.mesh = island.terrain_chunks.lod_meshes[4]
	island.terrain_chunks.set_process(false)
	island.camera.position = Vector3(0, 4600, 0.01)
	island.camera.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	img = await capture()
	var sky := Look.SKY_HZ
	var sky_px := 0
	var total := 0
	var half := 1700.0 / (4600.0 * tan(deg_to_rad(24.0))) * 0.5 * img.get_height()   # px half-size of 1700 m
	for y in range(int(img.get_height() / 2 - half), int(img.get_height() / 2 + half), 3):
		for x in range(int(img.get_width() / 2 - half), int(img.get_width() / 2 + half), 3):
			var p := img.get_pixel(x, y)
			total += 1
			if absf(p.r - sky.x) < 0.012 and absf(p.g - sky.y) < 0.012 and absf(p.b - sky.z) < 0.012:
				sky_px += 1
	print("cracks: %d sky pixels of %d inside the island square" % [sky_px, total])
	check(sky_px == 0, "no sky shows through the terrain at LOD 4 (%d of %d)" % [sky_px, total])
	results["cracks"] = {"sky_pixels": sky_px, "sampled": total}
	island.queue_free()
	await process_frame

func write_json() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/evidence/godot/m0").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/calibration.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	f.close()

# ---- 3. sky --------------------------------------------------------------------------------
func sky_test() -> void:
	for c in world_root.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	var cal: Dictionary = results["calibration"]["best"]
	var sky_env := EnvironmentFactory.make_environment(cal.exposure, cal.white)
	for c in world_root.get_children():
		if c is WorldEnvironment:
			c.environment = sky_env
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 48.0
	cam.near = 0.25
	cam.far = 12000.0
	var sun := Look.sun_dir()
	cam.position = Vector3.ZERO
	cam.basis = Basis.looking_at(sun, Vector3.UP)
	var img := await capture()
	var w := img.get_width()
	var h := img.get_height()
	# The sun's projected position is the frame centre: it must be the brightest pixel region.
	var best := Vector2i.ZERO
	var best_v := -1.0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var p := img.get_pixel(x, y)
			var v := p.r + p.g + p.b
			if v > best_v:
				best_v = v
				best = Vector2i(x, y)
	var centre := img.get_pixel(w / 2, h / 2)
	print("sky: brightest pixel at %s (frame centre is %s), centre %s" % [best, Vector2i(w / 2, h / 2), centre])
	check(centre.r + centre.g + centre.b >= best_v - 0.02, "sun disc is the brightest region at the projected sun position")
	# The glow saturates a wide area, so test symmetry: the camera looks exactly at the sun, hence
	# the left and right sides of the frame (above the horizon) must be mirror images.
	var asym := 0.0
	for dy in [-200, -120, -60, 0]:
		var l := img.get_pixel(w / 2 - 250, h / 2 + dy)
		var r := img.get_pixel(w / 2 + 250, h / 2 + dy)
		asym = maxf(asym, maxf(absf(l.r - r.r), maxf(absf(l.g - r.g), absf(l.b - r.b))))
	print("sky: left/right asymmetry %.3f" % asym)
	check(asym < 0.02, "the sky is symmetric about the sun direction (the shader sun equals SUN_DIR)")
	# Horizon opposite the sun: the hero's horizon colour, within 3/255.
	var away := Vector3(-sun.x, 0, -sun.z).normalized()
	cam.basis = Basis.looking_at(away, Vector3.UP)
	img = await capture()
	var hz := img.get_pixel(w / 2, h / 2)
	var want := Look.SKY_HZ
	var err := maxf(absf(hz.r - want.x), maxf(absf(hz.g - want.y), absf(hz.b - want.z))) * 255.0
	print("sky horizon %s expected %s error %.2f/255" % [hz, want, err])
	results["sky"] = {"horizon_err_255": err, "sun_pixel": [best.x, best.y]}
	check(err <= 3.0, "sky horizon colour equals the hero's (%.2f/255)" % err)

# ---- 2. display_out round trip ---------------------------------------------------------------
const OUT_INV := [[0.643038249, 0.311186752, 0.045775457], [0.059268690, 0.931436487, 0.009294916], [0.005961901, 0.063929016, 0.930118384]]
const IN_INV := [[1.764740972, -0.675777678, -0.088963294], [-0.147027852, 1.160251512, -0.013223660], [-0.036336830, -0.162436437, 1.198773267]]

static func mul(m: Array, v: Vector3) -> Vector3:
	return Vector3(m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z, m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z,
		m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z)

static func srgb_dec(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

# A display colour is reachable when some non-negative linear scene colour tone-maps to it
# (the hero's tone mapper desaturates bright colours, so e.g. (.25, 1, 0) can never occur).
static func reachable(d: Vector3) -> bool:
	var t := Vector3(srgb_dec(d.x), srgb_dec(d.y), srgb_dec(d.z))
	if t.x > 0.985 or t.y > 0.985 or t.z > 0.985:
		return false
	var y := mul(OUT_INV, t)
	for c in [y.x, y.y, y.z]:
		if c < 0.0 or c > 0.99:
			return false
	var x := Vector3()
	for i in 3:
		var yi: float = y[i]
		var p := 0.0245786 - 0.432951 * yi
		var q := 1.0 - 0.983729 * yi
		x[i] = (-p + sqrt(p * p + 4.0 * q * (0.000090537 + 0.238081 * yi))) / (2.0 * q)
	var lin := mul(IN_INV, x)
	return lin.x >= -1e-4 and lin.y >= -1e-4 and lin.z >= -1e-4

func round_trip() -> void:
	var cal: Dictionary = results["calibration"]["best"]
	env.tonemap_exposure = cal.exposure
	env.tonemap_white = cal.white
	var values := []
	var skipped := 0
	for r in 5:
		for g in 5:
			for b in 5:
				var v := Vector3(r, g, b) / 4.0
				if reachable(v):
					values.append(v)
				else:
					skipped += 1
	# The palette's own display-space colours (sky dome) must be reachable and round-trip too.
	for c in [Look.SKY_HZ, Look.SKY_MID, Look.SKY_TOP, Look.AIR_COOL, Look.AIR_WARM]:
		check(reachable(c), "palette colour %s is reachable" % c)
		values.append(c)
	var cols := 12
	var img := await show_patches(values, cols, 1)
	var worst := 0.0
	for k in values.size():
		var px := patch_pixel(img, k, values.size(), cols)
		var v: Vector3 = values[k]
		var e := maxf(absf(px.r - v.x), maxf(absf(px.g - v.y), absf(px.b - v.z)))
		worst = maxf(worst, e)
		if e * 255.0 > 2.0:
			print("  bad patch %s -> %s (%.1f)" % [v, Vector3(px.r, px.g, px.b), e * 255.0])
	print("display_out round trip: %d reachable colours (%d of the 5x5x5 grid unreachable), max error %.2f/255" % [values.size(), skipped, worst * 255.0])
	results["round_trip"] = {"patches": values.size(), "unreachable_skipped": skipped, "max_err_255": worst * 255.0, "gate_255": 2.0}
	check(worst * 255.0 <= 2.0, "display_out round-trip gate: %.2f/255 <= 2" % (worst * 255.0))
