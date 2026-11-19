extends SceneTree
# Stretch test of the rock mapping (PLAN-rock step 1): godot --rendering-driver opengl3 --script res://game/tests/rock_stretch_test.gd
# (xvfb + software GL; make godot-rock-stretch-test). A 60 degree cone on a flat ring is drawn with the terrain shader in
# debug mode 1 (4 m grid through the active mapping) and mode 5 (the legacy planar xz grid), seen from an orthographic
# top-down camera. Along radial (downslope) and circumferential (contour) lines the total variation of the grid's sawtooth
# gives texel density relative to the surface metre: 1 = undistorted. Writes docs/evidence/godot/rock/stretch.json.

const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainChunks := preload("res://game/island/terrain_chunks.gd")
const EnvironmentFactory := preload("res://game/island/environment.gd")

const N := 256
const CELL := 1.0
const PX := 1024
const SCALE := 0.25                    # metres per pixel
const R_CONE := 110.0
const SLOPE := 60.0
const SAW := 0.97                      # the shader scales its debug values by this
const GRID := 4.0

var checks := 0
var failures := 0
var sv: SubViewport
var chunks: Node3D
var out := {}

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + what)
	return ok

# Synthetic island data: material id 1 (rock) everywhere, a cone of the given slope on flat ground.
static func cone_entry(height_fn: Callable) -> Dictionary:
	var h := PackedFloat32Array()
	h.resize(N * N)
	var half := N * CELL * 0.5
	for j in N:
		for i in N:
			h[j * N + i] = height_fn.call((i + 0.5) * CELL - half, (j + 0.5) * CELL - half)
	var surf := PackedByteArray()
	surf.resize(N * N * 4)
	for k in N * N:
		surf[k * 4] = 1
	var cps := N / TerrainData.CHUNK_CELLS
	var bounds := PackedFloat32Array()
	bounds.resize(cps * cps * 2)
	for cj in cps:
		for ci in cps:
			var mn := 1e9
			var mx := -1e9
			for j in range(cj * 64, cj * 64 + 65):
				for i in range(ci * 64, ci * 64 + 65):
					var v: float = h[mini(j, N - 1) * N + mini(i, N - 1)]
					mn = minf(mn, v)
					mx = maxf(mx, v)
			bounds[(cj * cps + ci) * 2] = mn
			bounds[(cj * cps + ci) * 2 + 1] = mx
	var mat := PackedByteArray()
	mat.resize(N * N)
	mat.fill(1)
	var zeros := PackedFloat32Array()
	zeros.resize(N * N)
	# Terrain v5 renders from the visual heightfield (4x finer, uint16) and its erosion maps: the same cone sampled finely, neutral maps.
	var vn := N * 4
	var vcell := N * CELL / float(vn)
	var vmax := 1.0
	for v in h:
		vmax = maxf(vmax, v)
	var vh := PackedByteArray()
	vh.resize(vn * vn * 2)
	for j in vn:
		for i in vn:
			var hv: float = height_fn.call((i + 0.5) * vcell - half, (j + 0.5) * vcell - half)
			vh.encode_u16((j * vn + i) * 2, clampi(roundi(hv / vmax * 65535.0), 0, 65535))
	var vmaps := PackedByteArray()
	vmaps.resize(vn / 2 * vn / 2 * 4)
	for k in vn / 2 * vn / 2:
		vmaps[k * 4 + 3] = 128
	return {"n": N, "size_m": N * CELL, "height": h, "flow": zeros, "water_level": h.duplicate(), "sediment": zeros, "material": mat,
		"surface": surf, "chunk_bounds": bounds, "chunks_per_side": cps, "caves": [], "volcano": Vector4.ZERO, "relief": relief_flat(),
		"vn": vn, "vheight": vh, "vh_min": 0.0, "vh_range": vmax, "vmaps": vmaps}

static func relief_flat() -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(N * N * 4)
	for k in N * N:
		r[k * 4] = 128
		r[k * 4 + 1] = 128
		r[k * 4 + 3] = 255
	return r

static func cone_height(x: float, z: float) -> float:
	return maxf(0.0, (R_CONE - sqrt(x * x + z * z)) * tan(deg_to_rad(SLOPE)))

func _initialize() -> void:
	_run.call_deferred()

func build_scene(entry: Dictionary, cam_y: float = 400.0) -> void:
	var td := TerrainData.new()
	td.setup(entry)
	sv = SubViewport.new()
	sv.size = Vector2i(PX, PX)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(sv)
	var we := WorldEnvironment.new()
	we.environment = EnvironmentFactory.make_environment()
	we.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR     # debug colours are read back as written
	we.environment.tonemap_exposure = 1.0
	sv.add_child(we)
	chunks = TerrainChunks.new()
	sv.add_child(chunks)
	chunks.set_process(false)
	chunks.build(td)
	chunks.update_lods(Vector3(0, cam_y - 250.0, 0), true)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = PX * SCALE
	cam.near = 1.0
	cam.far = cam_y + 300.0
	cam.position = Vector3(0, cam_y, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)    # image up = -z, image right = +x
	sv.add_child(cam)
	cam.current = true

func capture(mode: int) -> Image:
	chunks.set_rock_debug(mode)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

# Value of a channel (0 R, 1 G, 2 B) at a world (x, z), nearest pixel (bilinear would invent values across a wrap), in 0..1 of the saw.
func sample(img: Image, x: float, z: float, ch: int) -> float:
	var px := clampi(floori((x + N * CELL * 0.5) / SCALE), 0, PX - 1)
	var pz := clampi(floori((z + N * CELL * 0.5) / SCALE), 0, PX - 1)
	return img.get_pixel(px, pz)[ch] / SAW

# Total variation of a sawtooth channel along a polyline, wraps unwrapped, seam jumps (> 0.2) skipped.
func tv(img: Image, pts: Array, ch: int) -> float:
	var total := 0.0
	var prev: float = sample(img, pts[0].x, pts[0].y, ch)
	for k in range(1, pts.size()):
		var cur: float = sample(img, pts[k].x, pts[k].y, ch)
		var d := cur - prev
		if d > 0.5:
			d -= 1.0
		elif d < -0.5:
			d += 1.0
		if absf(d) <= 0.2:
			total += absf(d)
		prev = cur
	return total

func radial(az: float, r0: float, r1: float) -> Array:
	var pts := []
	var d := Vector2(cos(az), sin(az))
	var steps := int((r1 - r0) / SCALE)
	for k in steps + 1:
		pts.append(d * (r0 + (r1 - r0) * k / steps))
	return pts

func arc(az: float, r: float, half_width: float) -> Array:
	var pts := []
	var steps := int(2.0 * half_width * r / SCALE)
	for k in steps + 1:
		var a := az - half_width + 2.0 * half_width * k / steps
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _run() -> void:
	var tier := ""
	for a in OS.get_cmdline_user_args():
		tier = a
	if tier != "":
		root.get_node("Game").settings.quality = tier
	build_scene(cone_entry(Callable(self, "cone_height")))
	var img1 := await capture(1)
	var img5 := await capture(5)
	var down := []
	var contour := []
	var legacy := []
	var flat := []
	var s60 := sin(deg_to_rad(SLOPE))
	var c60 := cos(deg_to_rad(SLOPE))
	for k in 8:
		# Triplanar's debug checker shows the dominant axis, which flips at exact 45 degree ties: the High tier is read 7 degrees off.
		var az := k * PI / 4.0 + (deg_to_rad(7.0) if tier == "high" else 0.0)
		var cs := absf(cos(az)) + absf(sin(az))
		var ls := (95.0 - 35.0) / c60                       # surface length of the radial line
		down.append(tv(img1, radial(az, 35.0, 95.0), 1) / (ls / GRID))
		contour.append(tv(img1, arc(az, 65.0, deg_to_rad(15.0)), 0) / (2.0 * deg_to_rad(15.0) * 65.0 / GRID))
		var tv5 := tv(img5, radial(az, 35.0, 95.0), 0) + tv(img5, radial(az, 35.0, 95.0), 1)
		legacy.append(tv5 / (ls / GRID) / cs)
		var tf := tv(img1, radial(az, 113.0, 126.0), 0) + tv(img1, radial(az, 113.0, 126.0), 1)
		flat.append(tf / ((126.0 - 113.0) / GRID) / cs)
	out = {"tier": tier, "downslope_biplanar": down, "contour_biplanar": contour, "downslope_legacy_planar": legacy, "flat_ring": flat}
	print("azimuth (deg)      ", [0, 45, 90, 135, 180, 225, 270, 315])
	for key in out:
		if out[key] is Array:
			print("%-24s" % key, out[key].map(func(v): return snappedf(v, 0.01)))
	for k in 8:
		check(absf(flat[k] - 1.0) <= 0.03, "flat ring density 1.00 +- 0.03 at azimuth %d (got %.3f)" % [k * 45, flat[k]])
		check(down[k] >= 0.85 and down[k] <= 1.10, "downslope ratio in [0.85, 1.10] at azimuth %d (got %.3f)" % [k * 45, down[k]])
		check(contour[k] >= 0.68, "contour ratio >= 0.68 at azimuth %d (got %.3f)" % [k * 45, contour[k]])
		check(absf(legacy[k] - 0.5) <= 0.05, "legacy planar mapping measures 0.50 +- 0.05 downslope at azimuth %d (got %.3f)" % [k * 45, legacy[k]])
	await sign_test()
	await strata_test()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/godot/rock"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://../docs/evidence/godot/rock/stretch%s.json" % ("-" + tier if tier != "" else "")), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	if true:
		img1.save_png(ProjectSettings.globalize_path("res://../docs/evidence/godot/rock/stretch_mode1.png"))
		img5.save_png(ProjectSettings.globalize_path("res://../docs/evidence/godot/rock/stretch_mode5_legacy.png"))
	print("rock stretch test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# The sign test drives the shader's synthetic ridge (rock_photo.gdshaderinc, `ph_synth`): one raised horizontal ridge per tile of the andesite
# macro scale (1.7 m x 7 = 11.9 m), centred at v = 0.5, with the tilt convention of the photographic sheets (normal green = +dh/dv).
const PHOTO_PERIOD := 11.9

# PLAN-rock step 4, sign test: on the cone, mode 4 (rock light with the detail normal) must brighten the up-facing side of the
# ridge, or darken it, exactly as the geometry says. For a face whose normal has elevation theta, a sun of elevation el and
# c = cos(angle between the face azimuth and the sun azimuth), d(light)/d(theta) = -sin(theta) cos(el) c + cos(theta) sin(el):
# tilting the normal up brightens faces turned away from the sun and darkens faces turned to it (the plan's "up-facing side is
# brighter at all azimuths" holds only for the first kind, so the check is the sign of this derivative).
func sign_test() -> void:
	chunks.set_uniform("ph_synth", 1)
	var img4 := await capture(4)
	var sun: Vector3 = preload("res://game/island/look.gd").sun_dir()
	var sun_az := atan2(sun.z, sun.x)
	var theta := deg_to_rad(90.0 - SLOPE)
	var el := asin(sun.y)
	var period := PHOTO_PERIOD
	var tan60 := tan(deg_to_rad(SLOPE))
	var diffs := []
	var preds := []
	for k in 8:
		var az := k * PI / 4.0
		var up := 0.0
		var dn := 0.0
		var nu := 0
		var nd := 0
		for pt in radial(az, 35.0, 95.0):
			var r: float = pt.length()
			var ph := fposmod((R_CONE - r) * tan60, period)
			var v := sample(img4, pt.x, pt.y, 0)
			if ph > period * 0.5 + 0.45 and ph < period * 0.5 + 1.3:
				up += v
				nu += 1
			elif ph > period * 0.5 - 1.3 and ph < period * 0.5 - 0.45:
				dn += v
				nd += 1
		var c := cos(az - sun_az)
		var pred := -sin(theta) * cos(el) * c + cos(theta) * sin(el)
		diffs.append((up / maxf(nu, 1) - dn / maxf(nd, 1)))
		preds.append(pred)
		if absf(pred) > 0.08:
			check(diffs[k] * pred > 0.0 and absf(diffs[k]) > 0.004, "ridge sign: up-facing side %s than down-facing at azimuth %d (diff %.3f, predicted %.2f)" % ["brighter" if pred > 0.0 else "darker", k * 45, diffs[k], pred])
	out["sign_test_up_minus_down"] = diffs
	out["sign_test_predicted"] = preds
	print("ridge up-down light  ", diffs.map(func(v): return snappedf(v, 0.001)))
	print("predicted derivative ", preds.map(func(v): return snappedf(v, 0.01)))
	img4.save_png(ProjectSettings.globalize_path("res://../docs/evidence/godot/rock/sign_test_mode4.png"))

# GDScript replica of the shader's cap-rock mask (rock.gdshaderinc: rockHash, rockNoise, rock_cap).
static func fract_(x: float) -> float:
	return x - floorf(x)

static func rock_hash(p: Vector2) -> float:
	var a := Vector3(fract_(p.x * 0.1031), fract_(p.y * 0.1031), fract_(p.x * 0.1031))
	var d := a.dot(Vector3(a.y, a.z, a.x) + Vector3(33.33, 33.33, 33.33))
	a += Vector3(d, d, d)
	return fract_((a.x + a.y) * a.z)

static func rock_noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(rock_hash(i), rock_hash(i + Vector2(1, 0)), f.x), lerpf(rock_hash(i + Vector2(0, 1)), rock_hash(i + Vector2(1, 1)), f.x), f.y)

static func cap_phase(p: Vector3) -> float:
	return (p.y + 0.025 * p.x - 0.018 * p.z + 10.0 * rock_noise(Vector2(p.x, p.z) / 400.0)) / 47.0

static func cap_mask(p: Vector3) -> float:
	var t := fract_(cap_phase(p))
	return smoothstep(0.10, 0.14, t) * (1.0 - smoothstep(0.60, 0.64, t)) * smoothstep(342.0, 375.0, p.y)

# PLAN-rock step 5: debug mode 3 (R = cap rock) over a cone lifted to 350 m must agree with the GDScript replica of the phase.
func strata_test() -> void:
	sv.queue_free()
	await process_frame
	var lift := 350.0
	build_scene(cone_entry(func(x, z): return lift + cone_height(x, z)), 1000.0)
	var img3 := await capture(3)
	var agree := 0
	var total := 0
	var ones := 0
	var fixed := []
	for iz in range(-100, 101, 7):
		for ix in range(-100, 101, 7):
			var x := float(ix)
			var z := float(iz)
			var y := lift + cone_height(x, z)
			var m := cap_mask(Vector3(x, y, z))
			if m > 0.02 and m < 0.98:
				continue      # on a band edge, where fp32 and double may differ by a pixel
			var got := sample(img3, x, z, 0)
			total += 1
			ones += 1 if m > 0.5 else 0
			if (got > 0.5) == (m > 0.5):
				agree += 1
			if fixed.size() < 5:
				fixed.append([snappedf(x, 0.1), snappedf(z, 0.1), snappedf(y, 0.1), m, snappedf(got, 0.01)])
	print("cap rock replica: %d of %d sample points agree (%d on the band); first five (x, z, y, replica, shader): %s" % [agree, total, ones, str(fixed)])
	check(ones > 50 and ones < total - 50, "the cap band covers part of the sample (%d on)" % ones)
	check(total >= 100 and agree >= total * 97 / 100, "mode 3 cap rock matches the GDScript phase at >= 97%% of %d points (got %d)" % [total, agree])
	var lit := 0
	for p in 40:
		lit += 1 if cap_mask(Vector3(p * 13.7 - 200.0, 360.0 + p * 11.3, p * 9.1 - 150.0)) > 0.5 else 0
	check(lit > 5 and lit < 35, "the replica's cap band is neither empty nor everywhere (%d of 40)" % lit)
	out["cap_rock_agreement"] = [agree, total]
	img3.save_png(ProjectSettings.globalize_path("res://../docs/evidence/godot/rock/strata_mode3.png"))
