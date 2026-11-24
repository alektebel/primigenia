extends SceneTree
# THROWAWAY spike H0 (docs/plans/island-realism.md §7.5): can the Hillaire 2020 sky LUTs live in SubViewports and be sampled
# from sky and spatial shaders, in Compatibility (and Forward+)? Known values are written, sampled and read back.
#   LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a godot --rendering-driver opengl3 --resolution 640x360 \
#     --path godot --script res://game/tests/atmo_spike.gd -- [out=<json>] [nobench]
# Forward+ needs Vulkan (no software ICD in the build environment): run the same command with `--rendering-method forward_plus`
# on a machine with a GPU. The script is renderer-agnostic and prints which renderer it ran on.
# Not a gate: it prints results and always exits 0 unless the harness itself breaks.

const W_T := 256
const H_T := 64
const SZ_MS := 32
const W_SV := 192
const H_SV := 108
const SZ_AP := 32

var results := {}
var flip_cache := {}

# ---------------------------------------------------------------- shader sources
# Source pattern f(ix, iy): R = 10^(-5 + 7 ix/(w-1)) (1e-5 .. 100), G = (ix+.5)/w, B = 8 (iy+.5)/h (up to 8), A = 1.
const GEN_CANVAS := """shader_type canvas_item;
render_mode blend_disabled;
uniform vec2 size;
void fragment() {
	vec2 p = floor(UV * size);
	COLOR = vec4(pow(10.0, -5.0 + 7.0 * p.x / (size.x - 1.0)), (p.x + 0.5) / size.x, 8.0 * (p.y + 0.5) / size.y, 1.0);
}
"""

# Consumers sample the LUT, compare with the analytic value in-shader and output the relative error encoded as
# 0.25 + 0.75 (log10(rel) + 6) / 6 (rel clamped to 1e-6..1). Reason: a 3D scene rendered into an HDR SubViewport comes back through
# a non-identity curve in Compatibility (values below ~0.03 crushed, above 1 inflated, see the calibration), whereas 0.25..1 is
# identity within 1e-3. Decoding the error therefore gives +-2 % on the error itself, which is plenty.
const CHECK_COMMON := """
uniform vec2 size;
uniform vec2 off;
vec3 expected_at(vec2 p) {
	return vec3(pow(10.0, -5.0 + 7.0 * p.x / (size.x - 1.0)), (p.x + 0.5) / size.x, 8.0 * (p.y + 0.5) / size.y);
}
vec3 enc(vec3 rel) {
	vec3 e = clamp(log(max(rel, vec3(1e-6))) / 2.302585093, vec3(-6.0), vec3(0.0));
	return 0.25 + 0.75 * (e + 6.0) / 6.0;
}
vec3 check(sampler2D tex, vec2 pix_uv, bool rgbm) {
	vec2 p = floor(pix_uv * size);
	vec4 v = texture(tex, pix_uv + off / size);
	if (rgbm) { v = vec4(v.rgb * v.a * 8.0, 1.0); }
	vec3 ex = mix(expected_at(p), expected_at(vec2(min(p.x + 1.0, size.x - 1.0), p.y)), off.x);
	return enc(abs(v.rgb - ex) / ex);
}
"""

func consumer_shader(kind: String, rgbm: bool, global_lut: bool) -> String:
	var decl := "uniform sampler2D lut : filter_linear, repeat_disable;\n"
	if global_lut:
		decl = "global uniform sampler2D atmo_lut : filter_linear, repeat_disable;\n#define lut atmo_lut\n"
	var rg := "true" if rgbm else "false"
	match kind:
		"canvas":
			return "shader_type canvas_item;\n" + decl + CHECK_COMMON + "void fragment() { COLOR = vec4(check(lut, UV, %s), 1.0); }\n" % rg
		"sky":
			return "shader_type sky;\n" + decl + CHECK_COMMON + "void sky() { COLOR = check(lut, FRAGCOORD.xy / size, %s); }\n" % rg
		_:
			return "shader_type spatial;\nrender_mode unshaded;\n" + decl + CHECK_COMMON + "void fragment() { ALBEDO = check(lut, UV, %s); }\n" % rg

# ---------------------------------------------------------------- harness
func settle(n: int = 3) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw

func expected(ix: int, iy: int, w: int, h: int) -> Vector3:
	return Vector3(pow(10.0, -5.0 + 7.0 * ix / (w - 1.0)), (ix + 0.5) / w, 8.0 * (iy + 0.5) / h)

func make_cpu_lut(w: int, h: int, fmt: int, rgbm: bool = false) -> ImageTexture:
	var img := Image.create(w, h, false, fmt)
	for y in h:
		for x in w:
			var e := expected(x, y, w, h)
			if rgbm:
				var m: float = maxf(maxf(e.x, e.y), e.z) / 8.0
				var a: float = ceilf(clampf(m, 1e-6, 1.0) * 255.0) / 255.0
				img.set_pixel(x, y, Color(e.x / (a * 8.0), e.y / (a * 8.0), e.z / (a * 8.0), a))
			else:
				img.set_pixel(x, y, Color(e.x, e.y, e.z, 1.0))
	return ImageTexture.create_from_image(img)

# A SubViewport rendering a canvas shader (generator). Returns the viewport (kept alive for the caller).
func make_gpu_lut(w: int, h: int, hdr: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.use_hdr_2d = hdr
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(w, h)
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = GEN_CANVAS
	m.set_shader_parameter("size", Vector2(w, h))
	r.material = m
	vp.add_child(r)
	root.add_child(vp)
	return vp

# Render `kind` consumer into an HDR viewport w x h and read it back.
func consume(kind: String, lut: Texture2D, w: int, h: int, rgbm: bool = false, off := Vector2.ZERO, global_lut: bool = false) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = consumer_shader(kind, rgbm, global_lut)
	if not global_lut:
		mat.set_shader_parameter("lut", lut)
	mat.set_shader_parameter("size", Vector2(w, h))
	mat.set_shader_parameter("off", off)
	if kind == "canvas":
		var r := ColorRect.new()
		r.size = Vector2(w, h)
		r.material = mat
		vp.add_child(r)
	else:
		vp.own_world_3d = true
		if kind == "sky":
			var sky := Sky.new()
			sky.sky_material = mat
			sky.process_mode = Sky.PROCESS_MODE_REALTIME
			var env := Environment.new()
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			var we := WorldEnvironment.new()
			we.environment = env
			vp.add_child(we)
			var cam := Camera3D.new()
			vp.add_child(cam)
		else:
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 2.0
			cam.position = Vector3(0, 0, 1)
			vp.add_child(cam)
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(2.0 * w / h, 2.0)
			mi.mesh = q
			mi.material_override = mat
			vp.add_child(mi)
	root.add_child(vp)
	await settle()
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

func dec(c: float) -> float:
	return pow(10.0, (c - 0.25) / 0.75 * 6.0 - 6.0)

# Decode an image written by a check shader: per-channel max relative error (R = log-spread value, G = linear ramp, B = 0..8 ramp),
# and the number of texels whose error exceeds 1 % in any channel (flushed / wrong).
func check_stats(img: Image, w: int, h: int) -> Dictionary:
	var m := Vector3.ZERO
	var bad := 0
	var m99 := []
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var r := Vector3(dec(c.r), dec(c.g), dec(c.b))
			m = Vector3(maxf(m.x, r.x), maxf(m.y, r.y), maxf(m.z, r.z))
			if maxf(r.x, maxf(r.y, r.z)) > 0.01:
				bad += 1
	return {"format": img.get_format(), "max_rel_R": snappedf(m.x, 1e-5), "max_rel_G": snappedf(m.y, 1e-5), "max_rel_B": snappedf(m.z, 1e-5), "texels_over_1pct": bad, "of": w * h}

# Direct readback of a generator viewport: relative error against expected(); flushed = expected normal-range value read as 0.
func direct_stats(img: Image, w: int, h: int) -> Dictionary:
	var mr := 0.0
	var mg := 0.0
	var mb := 0.0
	var flushed := 0
	var maxv := 0.0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var e := expected(x, y, w, h)
			maxv = maxf(maxv, c.r)
			if e.x > 6.2e-5:
				mr = maxf(mr, absf(c.r - e.x) / e.x)
			if c.r <= 0.0:
				flushed += 1
			mg = maxf(mg, absf(c.g - e.y) / e.y)
			mb = maxf(mb, absf(c.b - e.z) / e.z)
	return {"format": img.get_format(), "max_rel_R_normal_range": mr, "max_rel_G": mg, "max_rel_B": mb, "R_read_as_zero": flushed, "max_R": maxv}

func fmt_name(f: int) -> String:
	var names := {Image.FORMAT_L8: "L8", Image.FORMAT_RGB8: "RGB8", Image.FORMAT_RGBA8: "RGBA8", Image.FORMAT_RF: "RF", Image.FORMAT_RGF: "RGF",
		Image.FORMAT_RGBF: "RGBF", Image.FORMAT_RGBAF: "RGBAF", Image.FORMAT_RH: "RH", Image.FORMAT_RGH: "RGH", Image.FORMAT_RGBH: "RGBH",
		Image.FORMAT_RGBAH: "RGBAH", Image.FORMAT_RGBE9995: "RGBE9995"}
	return names.get(f, str(f))

func log_result(key: String, d: Dictionary) -> void:
	if d.has("format"):
		d["format"] = fmt_name(d["format"])
	results[key] = d
	print("[", key, "] ", JSON.stringify(d))

# ---------------------------------------------------------------- tests
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var do_bench := true
	var calib_only := false
	for a in args:
		if a == "calib":
			calib_only = true
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		elif a == "nobench":
			do_bench = false
	var rd := RenderingServer.get_current_rendering_driver_name()
	var rm := RenderingServer.get_current_rendering_method()
	results["env"] = {"driver": rd, "method": rm, "adapter": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info()["string"]}
	print("ENV ", JSON.stringify(results["env"]))
	if DisplayServer.get_name() == "headless":
		print("headless display server: no rendering, nothing to measure. Run under xvfb-run with --rendering-driver opengl3.")
		quit(0)
		return

	if calib_only:
		await range_test()
		await calib()
		quit(0)
		return
	# 0. Direct readback of a GPU-written viewport: format, clamp, range, tiny values (the base question).
	for hdr in [true, false]:
		var gv := make_gpu_lut(W_T, H_T, hdr)
		await settle()
		var img := gv.get_texture().get_image()
		log_result("direct_viewport_hdr=%s" % hdr, direct_stats(img, W_T, H_T))
		gv.queue_free()
	await range_test()

	rgbm_stats()
	# 1. Source x consumer matrix at exact texel centres (256x64 transmittance size).
	var sources := {}
	sources["cpu_RGBAH"] = make_cpu_lut(W_T, H_T, Image.FORMAT_RGBAH)
	sources["cpu_RGBH"] = make_cpu_lut(W_T, H_T, Image.FORMAT_RGBH)
	sources["cpu_RGBAF"] = make_cpu_lut(W_T, H_T, Image.FORMAT_RGBAF)
	sources["cpu_RGBA8_RGBM"] = make_cpu_lut(W_T, H_T, Image.FORMAT_RGBA8, true)
	var gpu_hdr := make_gpu_lut(W_T, H_T, true)
	var gpu_ldr := make_gpu_lut(W_T, H_T, false)
	await settle()
	sources["gpu_viewport_hdr"] = gpu_hdr.get_texture()
	sources["gpu_viewport_ldr"] = gpu_ldr.get_texture()
	for sname in sources:
		for kind in ["canvas", "sky", "spatial"]:
			var img: Image = await consume(kind, sources[sname], W_T, H_T, sname.ends_with("RGBM"))
			log_result("%s -> %s" % [sname, kind], check_stats(img, W_T, H_T))

	# 2. Bilinear filtering of float data (half-texel shift = average of two texels).
	for sname in ["cpu_RGBAH", "cpu_RGBAF", "gpu_viewport_hdr"]:
		for kind in ["canvas", "sky", "spatial"]:
			var img: Image = await consume(kind, sources[sname], W_T, H_T, false, Vector2(0.5, 0.0))
			log_result("filter %s -> %s" % [sname, kind], check_stats(img, W_T, H_T))

	# 3. Global shader uniform sampler (the plan's atmo_* globals), sky and spatial.
	RenderingServer.global_shader_parameter_add("atmo_lut", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, sources["gpu_viewport_hdr"])
	await settle()
	for kind in ["canvas", "sky", "spatial"]:
		var img: Image = await consume(kind, null, W_T, H_T, false, Vector2.ZERO, true)
		log_result("global sampler (gpu hdr) -> %s" % kind, check_stats(img, W_T, H_T))
	RenderingServer.global_shader_parameter_set("atmo_lut", sources["cpu_RGBAH"])
	await settle()
	for kind in ["sky", "spatial"]:
		var img: Image = await consume(kind, null, W_T, H_T, false, Vector2.ZERO, true)
		log_result("global sampler (cpu RGBAH) -> %s" % kind, check_stats(img, W_T, H_T))
	gpu_hdr.queue_free()
	gpu_ldr.queue_free()

	# 4. The other LUT sizes through GPU HDR viewports, sampled from the sky shader (multi-scattering, sky-view).
	for sz in [Vector2i(SZ_MS, SZ_MS), Vector2i(W_SV, H_SV)]:
		var gv := make_gpu_lut(sz.x, sz.y, true)
		await settle()
		for kind in ["sky", "spatial"]:
			var img: Image = await consume(kind, gv.get_texture(), sz.x, sz.y)
			log_result("lut %dx%d gpu hdr -> %s" % [sz.x, sz.y, kind], check_stats(img, sz.x, sz.y))
		gv.queue_free()

	# 5. Aerial perspective: 32x32x32 as a 1024x32 atlas, GPU-written with alpha, sampled with manual trilinear.
	await ap_test()
	await ap_3d_test()

	# 6. Relative cost (software GL: CPU rasteriser, so only the ratios mean anything).
	if do_bench:
		await bench()

	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("wrote ", out)
	print("SPIKE DONE")
	quit(0)

# Output transfer curve of a 3D consumer (sky or spatial) rendered into an HDR SubViewport and read back: constants x -> y.
# The test shaders write the constant through a uniform into a 1x1 viewport.
func make_const_vp(kind: String, mat: ShaderMaterial, w: int, h: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.own_world_3d = true
	if kind == "sky":
		var sky := Sky.new()
		sky.sky_material = mat
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		vp.add_child(Camera3D.new())
	else:
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 2.0
		cam.position = Vector3(0, 0, 1)
		vp.add_child(cam)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.0 * w / h, 2.0)
		mi.mesh = q
		mi.material_override = mat
		vp.add_child(mi)
	return vp

var curves := {}

func calib() -> void:
	var xs := [1e-5, 1e-4, 1e-3, 0.01, 0.03, 0.0625, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0, 8.0, 16.0, 100.0]
	for kind in ["sky", "spatial"]:
		var sh := "shader_type %s;\n" % kind
		if kind == "spatial":
			sh += "render_mode unshaded;\nuniform float val;\nvoid fragment() { ALBEDO = vec3(val); }\n"
		else:
			sh += "uniform float val;\nvoid sky() { COLOR = vec3(val); }\n"
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = sh
		var pts := []
		for x in xs:
			mat.set_shader_parameter("val", x)
			var vp := make_const_vp(kind, mat, 4, 4)
			root.add_child(vp)
			await settle()
			var img := vp.get_texture().get_image()
			vp.queue_free()
			pts.append([x, img.get_pixel(2, 2).r])
		curves[kind] = pts
		log_result("curve %s (x -> y)" % kind, {"pts": pts})
	# uv mapping, ramp encoded as 0.25 + 0.75 u (the identity part of the curve), 16x8
	for variant in ["sky SCREEN_UV", "sky FRAGCOORD", "spatial UV"]:
		var kind: String = variant.split(" ")[0]
		var uvn: String = {"sky SCREEN_UV": "SCREEN_UV", "sky FRAGCOORD": "(FRAGCOORD.xy / vec2(16.0, 8.0))", "spatial UV": "UV"}[variant]
		var sh2 := "shader_type %s;\n" % kind
		if kind == "spatial":
			sh2 += "render_mode unshaded;\nvoid fragment() { vec2 q = %s; ALBEDO = vec3(0.25 + 0.75 * q.x, 0.25 + 0.75 * q.y, 0.25); }\n" % uvn
		else:
			sh2 += "void sky() { vec2 q = %s; COLOR = vec3(0.25 + 0.75 * q.x, 0.25 + 0.75 * q.y, 0.25); }\n" % uvn
		var mat2 := ShaderMaterial.new()
		mat2.shader = Shader.new()
		mat2.shader.code = sh2
		var vp2 := make_const_vp(kind, mat2, 16, 8)
		root.add_child(vp2)
		await settle()
		var img2 := vp2.get_texture().get_image()
		vp2.queue_free()
		var px := []
		for pt in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 7), Vector2i(15, 7)]:
			var c := img2.get_pixel(pt.x, pt.y)
			px.append([pt.x, pt.y, snappedf((c.r - 0.25) / 0.75, 0.001), snappedf((c.g - 0.25) / 0.75, 0.001)])
		log_result("uv ramp %s (expect u=.031/.969 v=.0625/.9375)" % variant, {"px": px})

# CPU-only: RGBM (range 8) round trip on sky-like colours (channels within a factor ~3 of each other), L log-spaced 1e-3 .. 8.
func rgbm_stats() -> void:
	var worst := 0.0
	var worst_dim := 0.0
	for i in 400:
		var l := pow(10.0, -3.0 + 3.9 * i / 399.0)
		var c := Vector3(0.6, 0.8, 1.0) * l
		var m := clampf(maxf(c.x, maxf(c.y, c.z)) / 8.0, 1e-6, 1.0)
		var a := ceilf(m * 255.0) / 255.0
		var q := Color(roundf(c.x / (a * 8.0) * 255.0) / 255.0, roundf(c.y / (a * 8.0) * 255.0) / 255.0, roundf(c.z / (a * 8.0) * 255.0) / 255.0, a)
		var d := Vector3(q.r, q.g, q.b) * q.a * 8.0
		var rel := maxf(absf(d.x - c.x) / c.x, maxf(absf(d.y - c.y) / c.y, absf(d.z - c.z) / c.z))
		if l >= 0.01:
			worst = maxf(worst, rel)
		else:
			worst_dim = maxf(worst_dim, rel)
	log_result("rgbm_roundtrip_sky_like", {"max_rel_err_L_0.01_to_8": worst, "max_rel_err_L_0.001_to_0.01": worst_dim})

# Range limits of a half-float target: 1000, 60000 (near the 65504 max), 70000 (overflow), 1e-8 (below half min subnormal 6e-8)
# and 1e-6 (subnormal).
func range_test() -> void:
	var sh := "shader_type canvas_item;\nrender_mode blend_disabled;\nvoid fragment() {\n\tfloat i = floor(UV.x * 6.0);\n\tfloat v = i < 0.5 ? 1000.0 : i < 1.5 ? 60000.0 : i < 2.5 ? 70000.0 : i < 3.5 ? 1e-8 : i < 4.5 ? 1e-6 : 3.0e-5;\n\tCOLOR = vec4(v, v, v, 1.0);\n}\n"
	var vp := SubViewport.new()
	vp.size = Vector2i(6, 1)
	vp.use_hdr_2d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(6, 1)
	var rm := ShaderMaterial.new()
	rm.shader = Shader.new()
	rm.shader.code = sh
	r.material = rm
	vp.add_child(r)
	root.add_child(vp)
	await settle()
	var img := vp.get_texture().get_image()
	var names := ["1000", "60000", "70000", "1e-8", "1e-6", "3e-5"]
	var d := {"format": img.get_format()}
	for i in 6:
		d[names[i]] = img.get_pixel(i, 0).r
	log_result("range_hdr_viewport", d)
	vp.queue_free()

const AP_GEN := """shader_type canvas_item;
render_mode blend_disabled;
void fragment() {
	vec2 p = floor(UV * vec2(1024.0, 32.0));
	float k = floor(p.x / 32.0);
	float i = p.x - k * 32.0;
	COLOR = vec4((i + 0.5) / 32.0, (p.y + 0.5) / 32.0, (k + 0.5) / 32.0, 0.25 + 0.5 * k / 31.0);
}
"""

# Consumer: reads the atlas at (u, v, w) with manual trilinear between two slices, compares with the analytic value
# (u, v, w clamped to texel centres; A linear in the slice index) and outputs the encoded relative error.
const AP_SAMPLE := """
uniform sampler2D ap : filter_linear, repeat_disable;
uniform float wz;
vec4 ap_sample(vec3 uvw) {
	float z = uvw.z * 32.0 - 0.5;
	float k0 = clamp(floor(z), 0.0, 31.0);
	float k1 = min(k0 + 1.0, 31.0);
	float f = clamp(z - k0, 0.0, 1.0);
	vec2 uvc = clamp(uvw.xy * 32.0, vec2(0.5), vec2(31.5));
	vec4 a = texture(ap, vec2((k0 * 32.0 + uvc.x) / 1024.0, uvc.y / 32.0));
	vec4 b = texture(ap, vec2((k1 * 32.0 + uvc.x) / 1024.0, uvc.y / 32.0));
	return mix(a, b, f);
}
vec3 enc(vec3 rel) {
	vec3 e = clamp(log(max(rel, vec3(1e-6))) / 2.302585093, vec3(-6.0), vec3(0.0));
	return 0.25 + 0.75 * (e + 6.0) / 6.0;
}
vec3 ap_check(vec2 uv) {
	vec4 v = ap_sample(vec3(uv, wz));
	vec2 c = clamp(uv, vec2(0.5 / 32.0), vec2(31.5 / 32.0));
	float wc = clamp(wz, 0.5 / 32.0, 31.5 / 32.0);
	float a_exp = 0.25 + 0.5 * (wc * 32.0 - 0.5) / 31.0;
	return enc(vec3(max(abs(v.r - c.x) / c.x, abs(v.g - c.y) / c.y), abs(v.b - wc) / wc, abs(v.a - a_exp) / a_exp));
}
"""

func ap_test() -> void:
	var atlas := SubViewport.new()
	atlas.size = Vector2i(1024, 32)
	atlas.use_hdr_2d = true
	atlas.transparent_bg = true
	atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(1024, 32)
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = AP_GEN
	r.material = gm
	atlas.add_child(r)
	root.add_child(atlas)
	await settle()
	var aimg := atlas.get_texture().get_image()
	var ca := aimg.get_pixel(5 * 32 + 3, 7)
	var ea := Color((3 + 0.5) / 32.0, (7 + 0.5) / 32.0, (5 + 0.5) / 32.0, 0.25 + 0.5 * 5.0 / 31.0)
	log_result("ap_atlas_direct", {"format": aimg.get_format(), "alpha_got": ca.a, "alpha_expected": ea.a, "rgb_err": maxf(absf(ca.r - ea.r), maxf(absf(ca.g - ea.g), absf(ca.b - ea.b)))})
	var amax := 0.0
	for k in 32:
		amax = maxf(amax, absf(aimg.get_pixel(k * 32 + 1, 1).a - (0.25 + 0.5 * k / 31.0)))
	log_result("ap_atlas_alpha_all_slices", {"max_abs_alpha_err": amax})
	for kind in ["sky", "spatial"]:
		for wz in [0.37, 0.0, 1.0]:
			var w := 32
			var h := 32
			var vp := SubViewport.new()
			vp.size = Vector2i(w, h)
			vp.use_hdr_2d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			vp.own_world_3d = true
			var sh := "shader_type %s;\n" % kind
			if kind == "spatial":
				sh += "render_mode unshaded;\n"
			sh += AP_SAMPLE
			if kind == "sky":
				sh += "void sky() { COLOR = ap_check(FRAGCOORD.xy / vec2(32.0)); }\n"
			else:
				sh += "void fragment() { ALBEDO = ap_check(UV); }\n"
			var mat := ShaderMaterial.new()
			mat.shader = Shader.new()
			mat.shader.code = sh
			mat.set_shader_parameter("ap", atlas.get_texture())
			mat.set_shader_parameter("wz", wz)
			if kind == "sky":
				var sky := Sky.new()
				sky.sky_material = mat
				var env := Environment.new()
				env.background_mode = Environment.BG_SKY
				env.sky = sky
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
				var we := WorldEnvironment.new()
				we.environment = env
				vp.add_child(we)
				vp.add_child(Camera3D.new())
			else:
				var cam := Camera3D.new()
				cam.projection = Camera3D.PROJECTION_ORTHOGONAL
				cam.size = 2.0
				cam.position = Vector3(0, 0, 1)
				vp.add_child(cam)
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(2, 2)
				mi.mesh = q
				mi.material_override = mat
				vp.add_child(mi)
			root.add_child(vp)
			await settle()
			var img := vp.get_texture().get_image()
			vp.queue_free()
			var st := check_stats(img, w, h)
			st["note"] = "R = max(u,v) err, G = w err, B = alpha err"
			log_result("ap_atlas_trilinear %s w=%.2f" % [kind, wz], st)
	atlas.queue_free()

# Native 3D texture (static upload only; render targets cannot be 3D in Compatibility).
func ap_3d_test() -> void:
	var slices: Array[Image] = []
	for k in 32:
		var im := Image.create(32, 32, false, Image.FORMAT_RGBAH)
		for y in 32:
			for x in 32:
				im.set_pixel(x, y, Color((x + 0.5) / 32.0, (y + 0.5) / 32.0, (k + 0.5) / 32.0, 1.0))
		slices.append(im)
	var t3 := ImageTexture3D.new()
	var err := t3.create(Image.FORMAT_RGBAH, 32, 32, 32, false, slices)
	for kind in ["sky", "spatial"]:
		var sh := "shader_type %s;\n" % kind
		if kind == "spatial":
			sh += "render_mode unshaded;\n"
		sh += "uniform sampler3D ap : filter_linear, repeat_disable;\n"
		if kind == "sky":
			sh += "vec3 enc(vec3 rel) { vec3 e = clamp(log(max(rel, vec3(1e-6))) / 2.302585093, vec3(-6.0), vec3(0.0)); return 0.25 + 0.75 * (e + 6.0) / 6.0; }\nvoid sky() { vec2 uv = FRAGCOORD.xy / vec2(32.0); vec3 v = texture(ap, vec3(uv, 0.37)).rgb; COLOR = enc(abs(v - vec3(uv, 0.37)) / vec3(uv, 0.37)); }\n"
		else:
			sh += "vec3 enc(vec3 rel) { vec3 e = clamp(log(max(rel, vec3(1e-6))) / 2.302585093, vec3(-6.0), vec3(0.0)); return 0.25 + 0.75 * (e + 6.0) / 6.0; }\nvoid fragment() { vec3 v = texture(ap, vec3(UV, 0.37)).rgb; ALBEDO = enc(abs(v - vec3(UV, 0.37)) / vec3(UV, 0.37)); }\n"
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = sh
		mat.set_shader_parameter("ap", t3)
		var vp := SubViewport.new()
		vp.size = Vector2i(32, 32)
		vp.use_hdr_2d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.own_world_3d = true
		if kind == "sky":
			var sky := Sky.new()
			sky.sky_material = mat
			var env := Environment.new()
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			var we := WorldEnvironment.new()
			we.environment = env
			vp.add_child(we)
			vp.add_child(Camera3D.new())
		else:
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 2.0
			cam.position = Vector3(0, 0, 1)
			vp.add_child(cam)
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(2, 2)
			mi.mesh = q
			mi.material_override = mat
			vp.add_child(mi)
		root.add_child(vp)
		await settle()
		var img := vp.get_texture().get_image()
		vp.queue_free()
		var st := check_stats(img, 32, 32)
		log_result("texture3d_static_RGBAH %s (create err=%d)" % [kind, err], st)

# ---------------------------------------------------------------- cost
# Reduced Hillaire-style passes (single scattering, Bruneton transmittance parameterisation), same loop counts as Table 2.
const ATMO_COMMON := """
const float Rg = 6614.0;
const float Rt = 6714.0;
const vec3 SIG_R = vec3(5.802, 13.558, 33.1) * 1.6e-3;
const float SIG_M_S = 3.996e-3 * 1.5;
const float SIG_M_A = 4.40e-3 * 1.5;
const vec3 SIG_O = vec3(0.650, 1.881, 0.085) * 1e-3;
vec3 ext_at(float h) {
	return SIG_R * exp(-h / 7.6) + vec3(SIG_M_S + SIG_M_A) * exp(-h / 1.2) + SIG_O * max(0.0, 1.0 - abs(h - 25.0) / 15.0);
}
float far_hit(float r, float mu, float R) {
	float disc = r * r * (mu * mu - 1.0) + R * R;
	return disc < 0.0 ? -1.0 : -r * mu + sqrt(disc);
}
vec2 trans_uv(float r, float mu) {
	float H = sqrt(Rt * Rt - Rg * Rg);
	float rho = sqrt(max(r * r - Rg * Rg, 0.0));
	float dmin = Rt - r;
	float dmax = rho + H;
	float d = far_hit(r, mu, Rt);
	return vec2(clamp((d - dmin) / (dmax - dmin), 0.0, 1.0), clamp(rho / H, 0.0, 1.0));
}
"""

const TRANS_GEN := "shader_type canvas_item;\nrender_mode blend_disabled;\n" + ATMO_COMMON + """
void fragment() {
	float H = sqrt(Rt * Rt - Rg * Rg);
	float rho = UV.y * H;
	float r = sqrt(rho * rho + Rg * Rg);
	float dmin = Rt - r;
	float dmax = rho + H;
	float d = dmin + UV.x * (dmax - dmin);
	float mu = d < 1e-4 ? 1.0 : clamp((H * H - rho * rho - d * d) / (2.0 * r * d), -1.0, 1.0);
	vec3 od = vec3(0.0);
	float dt = d / 40.0;
	for (int i = 0; i < 40; i++) {
		float t = (float(i) + 0.5) * dt;
		float rr = sqrt(r * r + t * t + 2.0 * r * mu * t);
		od += ext_at(rr - Rg) * dt;
	}
	COLOR = vec4(exp(-od), 1.0);
}
"""

const MS_GEN := "shader_type canvas_item;\nrender_mode blend_disabled;\n" + ATMO_COMMON + """
uniform sampler2D trans : filter_linear;
void fragment() {
	float mu_s = UV.x * 2.0 - 1.0;
	float r = Rg + UV.y * (Rt - Rg);
	vec3 sun = vec3(sqrt(1.0 - mu_s * mu_s), 0.0, mu_s);
	vec3 L2 = vec3(0.0);
	vec3 fms = vec3(0.0);
	for (int j = 0; j < 64; j++) {
		float fj = (float(j) + 0.5) / 64.0;
		float mu = 1.0 - 2.0 * fj;
		float ph = 2.399963 * float(j);
		vec3 dir = vec3(sqrt(1.0 - mu * mu) * cos(ph), sqrt(1.0 - mu * mu) * sin(ph), mu);
		float tmax = far_hit(r, mu, Rt);
		float tg = far_hit(r, mu, Rg);
		if (tg > 0.0) { tmax = min(tmax, tg - 1e-3); }
		float dt = max(tmax, 0.0) / 20.0;
		vec3 th = vec3(1.0);
		for (int i = 0; i < 20; i++) {
			float t = (float(i) + 0.5) * dt;
			vec3 p = vec3(0.0, 0.0, r) + dir * t;
			float rr = length(p);
			vec3 e = ext_at(rr - Rg);
			vec3 sc = SIG_R * exp(-(rr - Rg) / 7.6) + vec3(SIG_M_S) * exp(-(rr - Rg) / 1.2);
			vec3 tt = exp(-e * dt);
			float mus = dot(p / rr, sun);
			vec3 ts = texture(trans, trans_uv(rr, mus)).rgb;
			vec3 s_int = (sc - sc * tt) / max(e, vec3(1e-7));
			L2 += th * s_int * ts / (4.0 * 3.14159) ;
			fms += th * s_int / (4.0 * 3.14159);
			th *= tt;
		}
	}
	L2 /= 64.0;
	fms /= 64.0;
	COLOR = vec4(L2 / (vec3(1.0) - fms), 1.0);
}
"""

const SV_GEN := "shader_type canvas_item;\nrender_mode blend_disabled;\n" + ATMO_COMMON + """
uniform sampler2D trans : filter_linear;
uniform sampler2D ms : filter_linear;
uniform float mu_sun = 0.17;
uniform float cam_h = 0.5;
void fragment() {
	float phi = UV.x * 6.2831853;
	float q = UV.y * 2.0 - 1.0;
	float l = sign(q) * q * q * 1.5707963;
	vec3 dir = vec3(cos(l) * cos(phi), cos(l) * sin(phi), sin(l));
	vec3 sun = vec3(sqrt(1.0 - mu_sun * mu_sun), 0.0, mu_sun);
	float r = Rg + cam_h;
	float tmax = far_hit(r, dir.z, Rt);
	float tg = far_hit(r, dir.z, Rg);
	if (tg > 0.0) { tmax = min(tmax, tg); }
	float dt = tmax / 30.0;
	float cs = dot(dir, sun);
	float pr = 3.0 * (1.0 + cs * cs) / (16.0 * 3.14159);
	float g = 0.8;
	float pm = 3.0 / (8.0 * 3.14159) * (1.0 - g * g) * (1.0 + cs * cs) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * cs, 1.5));
	vec3 L = vec3(0.0);
	vec3 th = vec3(1.0);
	for (int i = 0; i < 30; i++) {
		float t = (float(i) + 0.5) * dt;
		vec3 p = vec3(0.0, 0.0, r) + dir * t;
		float rr = length(p);
		float h = rr - Rg;
		vec3 e = ext_at(h);
		vec3 sr = SIG_R * exp(-h / 7.6);
		vec3 sm = vec3(SIG_M_S) * exp(-h / 1.2);
		float mus = dot(p / rr, sun);
		vec3 ts = texture(trans, trans_uv(rr, mus)).rgb;
		vec3 psi = texture(ms, vec2(mus * 0.5 + 0.5, h / (Rt - Rg))).rgb;
		vec3 s = (sr * pr + sm * pm) * ts + (sr + sm) * psi;
		vec3 tt = exp(-e * dt);
		L += th * (s - s * tt) / max(e, vec3(1e-7));
		th *= tt;
	}
	COLOR = vec4(L * 20.0, 1.0);
}
"""

const AP_PASS := "shader_type canvas_item;\nrender_mode blend_disabled;\n" + ATMO_COMMON + """
uniform sampler2D trans : filter_linear;
uniform sampler2D ms : filter_linear;
uniform float mu_sun = 0.17;
void fragment() {
	vec2 p = floor(UV * vec2(1024.0, 32.0));
	float k = floor(p.x / 32.0);
	vec2 s = (vec2(p.x - k * 32.0, p.y) + 0.5) / 32.0 * 2.0 - 1.0;
	vec3 dir = normalize(vec3(s.x * 0.8, 1.0, s.y * 0.5));
	float dmax = (k + 1.0) / 32.0 * 32.0;
	float dt = dmax / 30.0;
	float r = Rg + 0.5;
	vec3 L = vec3(0.0);
	vec3 th = vec3(1.0);
	vec3 sun = vec3(sqrt(1.0 - mu_sun * mu_sun), 0.0, mu_sun);
	for (int i = 0; i < 30; i++) {
		float t = (float(i) + 0.5) * dt;
		vec3 pp = vec3(0.0, 0.0, r) + dir * t;
		float rr = length(pp);
		float h = rr - Rg;
		vec3 e = ext_at(h);
		vec3 sc = SIG_R * exp(-h / 7.6) + vec3(SIG_M_S) * exp(-h / 1.2);
		float mus = dot(pp / rr, sun);
		vec3 ts = texture(trans, trans_uv(rr, mus)).rgb;
		vec3 psi = texture(ms, vec2(mus * 0.5 + 0.5, h / (Rt - Rg))).rgb;
		vec3 sct = sc * (ts * 0.1 + psi);
		vec3 tt = exp(-e * dt);
		L += th * (sct - sct * tt) / max(e, vec3(1e-7));
		th *= tt;
	}
	COLOR = vec4(L * 20.0, dot(th, vec3(0.3333)));
}
"""

const SKY_USE := """shader_type sky;
uniform sampler2D skyview : filter_linear;
void sky() {
	vec3 d = EYEDIR;
	float l = asin(clamp(d.y, -1.0, 1.0));
	float v = 0.5 + 0.5 * sign(l) * sqrt(abs(l) / 1.5707963);
	float u = atan(d.x, -d.z) / 6.2831853 + 0.5;
	COLOR = texture(skyview, vec2(u, 1.0 - v)).rgb;
}
"""
const SKY_CONST := "shader_type sky;\nvoid sky() { COLOR = vec3(0.2, 0.3, 0.6) * (0.5 + 0.5 * EYEDIR.y); }\n"

const SPATIAL_AP := """shader_type spatial;
render_mode unshaded;
uniform sampler2D ap : filter_linear, repeat_disable;
uniform sampler2D trans : filter_linear;
void fragment() {
	float z = UV.x * 31.0;
	float k0 = floor(z);
	float f = z - k0;
	vec2 uvc = clamp(UV * 32.0, vec2(0.5), vec2(31.5));
	vec4 a = texture(ap, vec2((k0 * 32.0 + uvc.x) / 1024.0, uvc.y / 32.0));
	vec4 b = texture(ap, vec2((min(k0 + 1.0, 31.0) * 32.0 + uvc.x) / 1024.0, uvc.y / 32.0));
	vec4 ap_v = mix(a, b, f);
	vec3 lin = vec3(0.3) * ap_v.a + ap_v.rgb;
	ALBEDO = lin;
}
"""
const SPATIAL_PLAIN := "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(0.3) * (0.5 + 0.5 * UV.x); }\n"

func canvas_pass(code: String, size: Vector2i, params: Dictionary, always: bool = true) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.use_hdr_2d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if always else SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(size)
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	for k in params:
		m.set_shader_parameter(k, params[k])
	r.material = m
	vp.add_child(r)
	root.add_child(vp)
	return vp

# Median of 5 batches of n frames (the machine is shared and the rasteriser is a CPU one, so single batches are noisy).
func frame_ms(n: int) -> float:
	for i in 3:
		await process_frame
	var batches := []
	for k in 5:
		var t0 := Time.get_ticks_usec()
		for i in n:
			await process_frame
		batches.append((Time.get_ticks_usec() - t0) / 1000.0 / n)
	batches.sort()
	return batches[2]

func sync_gpu(vp: SubViewport) -> void:
	# a 1x1 readback forces the software rasteriser to finish this frame's work
	var img := vp.get_texture().get_image()
	img = null

func bench() -> void:
	var n := 20
	var cost := {}
	var base := await frame_ms(n)
	cost["empty_frame_ms"] = base
	print("bench base frame (%d frames) %.2f ms" % [n, base])

	# One-time LUTs (static)
	var trans := canvas_pass(TRANS_GEN, Vector2i(W_T, H_T), {}, false)
	await settle()
	var ms := canvas_pass(MS_GEN, Vector2i(SZ_MS, SZ_MS), {"trans": trans.get_texture()}, false)
	await settle()
	var sv_static := canvas_pass(SV_GEN, Vector2i(W_SV, H_SV), {"trans": trans.get_texture(), "ms": ms.get_texture()}, false)
	await settle()

	# Per pass: UPDATE_ALWAYS for n frames, minus the empty frame. Each pass is measured alone.
	var passes := {
		"transmittance_256x64_40steps": [TRANS_GEN, Vector2i(W_T, H_T), {}],
		"multiscatter_32x32_64dirs_20steps": [MS_GEN, Vector2i(SZ_MS, SZ_MS), {"trans": trans.get_texture()}],
		"skyview_192x108_30steps": [SV_GEN, Vector2i(W_SV, H_SV), {"trans": trans.get_texture(), "ms": ms.get_texture()}],
		"ap_atlas_1024x32_30steps": [AP_PASS, Vector2i(1024, 32), {"trans": trans.get_texture(), "ms": ms.get_texture()}],
		"skyview_96x50_8steps_low": [SV_GEN.replace("30", "8").replace("float(i) + 0.5) * dt", "float(i) + 0.5) * dt"), Vector2i(96, 50), {"trans": trans.get_texture(), "ms": ms.get_texture()}],
	}
	for name in passes:
		var p: Array = passes[name]
		var vp := canvas_pass(p[0], p[1], p[2])
		var t := await frame_ms(n)
		sync_gpu(vp)
		cost[name] = {"frame_ms": t, "delta_ms": t - base}
		print("bench %s: %.2f ms/frame (delta %.2f)" % [name, t, t - base])
		vp.queue_free()
		await settle()

	# Consumers in the main window (640x360 by --resolution): sky shader sampling the sky-view LUT vs a constant gradient.
	var sky_cam := Camera3D.new()
	root.add_child(sky_cam)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	root.add_child(we)
	for variant in ["sky_const", "sky_sample_skyview"]:
		var sm := ShaderMaterial.new()
		sm.shader = Shader.new()
		sm.shader.code = SKY_USE if variant == "sky_sample_skyview" else SKY_CONST
		if variant == "sky_sample_skyview":
			sm.set_shader_parameter("skyview", sv_static.get_texture())
		var sky := Sky.new()
		sky.sky_material = sm
		env.sky = sky
		var t := await frame_ms(n)
		cost[variant] = {"frame_ms": t, "delta_ms": t - base}
		print("bench %s (%dx%d): %.2f ms/frame (delta %.2f)" % [variant, root.size.x, root.size.y, t, t - base])
	we.queue_free()
	sky_cam.queue_free()

	# Spatial consumer: full-window quad, plain vs sampling the AP atlas (2 slice fetches) per fragment.
	var ap_vp := canvas_pass(AP_PASS, Vector2i(1024, 32), {"trans": trans.get_texture(), "ms": ms.get_texture()}, false)
	await settle()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0, 0, 1)
	root.add_child(cam)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0 * root.size.x / root.size.y, 2.0)
	mi.mesh = q
	root.add_child(mi)
	for variant in ["spatial_plain", "spatial_sample_ap_atlas"]:
		var sm := ShaderMaterial.new()
		sm.shader = Shader.new()
		sm.shader.code = SPATIAL_AP if variant == "spatial_sample_ap_atlas" else SPATIAL_PLAIN
		if variant == "spatial_sample_ap_atlas":
			sm.set_shader_parameter("ap", ap_vp.get_texture())
			sm.set_shader_parameter("trans", trans.get_texture())
		mi.material_override = sm
		var t := await frame_ms(n)
		cost[variant] = {"frame_ms": t, "delta_ms": t - base}
		print("bench %s: %.2f ms/frame (delta %.2f)" % [variant, t, t - base])
	mi.queue_free()
	cam.queue_free()
	results["cost"] = cost
