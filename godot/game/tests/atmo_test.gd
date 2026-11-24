extends SceneTree
# H1 gate (docs/plans/island-realism.md 7.5): the CPU atmosphere LUTs in the extension (godot/extension/atmosphere.cpp).
#   make godot-atmo-test
# or by hand (software GL; the texture round trip needs a real renderer, headless skips only that one check):
#   LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 300 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/atmo_test.gd
# Checks:
#   1. C++ vs tools/atmo/ref.py (plain-Python port of Hillaire 2020 eqs. 1-11): transmittance and Psi_ms within 1 %, canon and Earth.
#   2. Transmittance texels against a 4000-step integral (report; the paper's 40 uniform steps are coarse near the horizon).
#   3. Earth parameters reproduce the paper's Figure 7 trend: Psi_ms broadly uniform in height, smooth in sun angle.
#   4. LUT images are FORMAT_RGBAF and a texel below 6e-5 survives the upload (RGBAH flushes it to 0, H0 finding 1).
#   5. Build time at load <= 40 ms.

const REL_TOL := 0.01
const BUILD_MS_GATE := 40.0
const TW := 256
const TH := 64
const MW := 32
const MH := 32

var checks := 0
var failures := 0

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL %s" % what)
	return ok

func _init() -> void:
	var rc := _run()
	print("atmo_test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func sci(x: float) -> String:
	return String.num_scientific(x)

func _run() -> int:
	if not ClassDB.class_exists("CporeAtmosphere"):
		check(false, "CporeAtmosphere is not registered (build the extension: make godot)")
		return 1
	var results := {}
	for preset in ["canon", "earth"]:
		var params: Dictionary = CporeAtmosphere.params_canon() if preset == "canon" else CporeAtmosphere.params_earth()
		var built: Dictionary = CporeAtmosphere.build(params, 0)
		results[preset] = built
		print("  %s first build in this process: %.1f ms (transmittance %.1f, multi-scattering %.1f, %d threads)" % [preset, built["ms_total"], built["ms_transmittance"], built["ms_multiscatter"], built["threads"]])
		if preset == "canon":
			check(built["ms_total"] <= BUILD_MS_GATE, "first (cold) canon build <= %.0f ms (%.1f)" % [BUILD_MS_GATE, built["ms_total"]])
		_check_against_ref(preset, built)
	_check_figure7(results["earth"])
	_check_canon_sanity(results["canon"])
	_check_upload(results["canon"])
	_check_timing()
	return 0

# ---------------------------------------------------------------- reference
func _ref(preset: String) -> Dictionary:
	var out := ProjectSettings.globalize_path("res://").path_join("../build/atmo_ref_%s.json" % preset).simplify_path()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/atmo/ref.py").simplify_path()
	var log: Array = []
	var t0 := Time.get_ticks_msec()
	var rc := OS.execute("python3", PackedStringArray([script, "--preset", preset, "--out", out, "--jobs", "6"]), log, true)
	if not check(rc == 0, "ref.py %s exits 0 (rc %d, %s)" % [preset, rc, str(log)]):
		return {}
	var f := FileAccess.open(out, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	print("  ref.py %s: %d ms" % [preset, Time.get_ticks_msec() - t0])
	return data if data is Dictionary else {}

func _compare(a: PackedFloat32Array, b: Array, w: int, h: int) -> Dictionary:
	# a: RGBAF data from C++, b: flat rgb list from Python. Relative error per channel (floor 1e-30 only guards the division).
	var worst := 0.0
	var worst_at := Vector3i()
	var sum := 0.0
	var n := 0
	for j in h:
		for i in w:
			for c in 3:
				var x: float = a[(j * w + i) * 4 + c]
				var y: float = b[(j * w + i) * 3 + c]
				var rel: float = absf(x - y) / maxf(absf(y), 1e-30)
				sum += rel
				n += 1
				if rel > worst:
					worst = rel
					worst_at = Vector3i(i, j, c)
	return {"max": worst, "at": worst_at, "mean": sum / n}

func _check_against_ref(preset: String, built: Dictionary) -> void:
	var ref := _ref(preset)
	if ref.is_empty():
		return
	var timg: Image = built["transmittance"]
	var mimg: Image = built["multiscatter"]
	check(timg.get_format() == Image.FORMAT_RGBAF and timg.get_width() == TW and timg.get_height() == TH, "%s transmittance image is RGBAF 256x64" % preset)
	check(mimg.get_format() == Image.FORMAT_RGBAF and mimg.get_width() == MW and mimg.get_height() == MH, "%s multiscatter image is RGBAF 32x32" % preset)
	var tdata := timg.get_data().to_float32_array()
	var mdata := mimg.get_data().to_float32_array()
	var ct := _compare(tdata, ref["trans"], TW, TH)
	var cm := _compare(mdata, ref["ms"], MW, MH)
	print("  %s transmittance C++ vs Python: max rel %s at %s, mean %s" % [preset, sci(ct["max"]), str(ct["at"]), sci(ct["mean"])])
	print("  %s Psi_ms        C++ vs Python: max rel %s at %s, mean %s" % [preset, sci(cm["max"]), str(cm["at"]), sci(cm["mean"])])
	check(ct["max"] <= REL_TOL, "%s transmittance within 1 %% of Python (max %s)" % [preset, sci(ct["max"])])
	check(cm["max"] <= REL_TOL, "%s Psi_ms within 1 %% of Python (max %s)" % [preset, sci(cm["max"])])
	# Independent of the 40-step marcher: 4000-step integral at 24 texels.
	var worst_all := 0.0
	var worst_ok := 0.0
	for e in ref["fine"]:
		var k: int = (int(e["j"]) * TW + int(e["i"])) * 4
		for c in 3:
			var y: float = e["t"][c]
			var rel: float = absf(tdata[k + c] - y) / maxf(y, 1e-30)
			worst_all = maxf(worst_all, rel)
			if y > 1e-3:
				worst_ok = maxf(worst_ok, rel)
	print("  %s transmittance vs 4000-step integral: max rel %s where T > 1e-3, %s over all 24 texels (grazing, deep)" % [preset, sci(worst_ok), sci(worst_all)])
	check(worst_ok <= 0.03, "%s 40-step transmittance within 3 %% of the converged integral where T > 1e-3 (%s)" % [preset, worst_ok])

# ---------------------------------------------------------------- Figure 7 trend
func _check_figure7(built: Dictionary) -> void:
	# Paper figure 7 (Earth): the multiple-scattering LUT varies slowly with altitude and smoothly with the sun angle; it is
	# NOT a strong function of height (that is why a 32x32 table is enough). Measure it on the Earth LUT (G channel).
	var d := (built["multiscatter"] as Image).get_data().to_float32_array()
	var worst_ratio := 0.0
	var worst_u := 0
	for i in range(MW):
		var u := i / float(MW - 1)
		if u < 0.75:
			continue  # sun more than 60 degrees from the zenith: the term itself goes to 0 at the horizon
		var lo := 1e30
		var hi := 0.0
		for j in MH:
			var v: float = d[(j * MW + i) * 4 + 1]
			lo = minf(lo, v)
			hi = maxf(hi, v)
		if hi / lo > worst_ratio:
			worst_ratio = hi / lo
			worst_u = i
	# Smooth in sun angle: no jump larger than 25 % between neighbouring columns for the sun above 30 degrees elevation.
	var worst_step := 0.0
	for j in MH:
		for i in range(MW / 2 + 3, MW - 1):
			var a: float = d[(j * MW + i) * 4 + 1]
			var b: float = d[(j * MW + i + 1) * 4 + 1]
			worst_step = maxf(worst_step, absf(a - b) / maxf(a, b))
	var zen: float = d[((MH / 2) * MW + MW - 1) * 4 + 1]
	var dark: float = d[((MH / 2) * MW + 0) * 4 + 1]
	var rgb_top: Vector3 = Vector3(d[(MH / 2 * MW + MW - 1) * 4], d[(MH / 2 * MW + MW - 1) * 4 + 1], d[(MH / 2 * MW + MW - 1) * 4 + 2])
	print("  Earth Psi_ms: height max/min <= %.2f for sun above 60 deg from zenith (worst column %d); worst neighbour step %.1f %%; mid height, sun at zenith %s, sun at nadir %s" % [worst_ratio, worst_u, worst_step * 100.0, str(rgb_top), sci(dark)])
	check(worst_ratio <= 2.5, "Earth Psi_ms is broadly uniform in height (max/min %.2f <= 2.5)" % worst_ratio)
	check(worst_step <= 0.25, "Earth Psi_ms is smooth in sun angle (worst step %.2f)" % worst_step)
	check(zen > 0.005 and zen < 0.5, "Earth Psi_ms at noon is of the order of the paper's figure (%.4f)" % zen)
	check(dark < 1e-6, "Earth Psi_ms is ~0 with the sun at the nadir (%s)" % sci(dark))
	check(rgb_top.z > rgb_top.x, "Earth Psi_ms is bluish (B %.4f > R %.4f)" % [rgb_top.z, rgb_top.x])

func _check_canon_sanity(built: Dictionary) -> void:
	# Canon: Rayleigh x1.6 reddens a long slant path more than Earth: compare B/R transmittance at the same texel.
	var earth: Dictionary = CporeAtmosphere.build(CporeAtmosphere.params_earth(), 1)
	var c := (built["transmittance"] as Image).get_data().to_float32_array()
	var e := (earth["transmittance"] as Image).get_data().to_float32_array()
	var k := (0 * TW + 160) * 4  # ground level, 62 % of the way to the horizon distance
	var cr: float = c[k + 2] / c[k]
	var er: float = e[k + 2] / e[k]
	print("  ground, texel (160,0): B/R transmittance canon %.4f, Earth %.4f (smaller = redder)" % [cr, er])
	check(cr < er, "canon (Rayleigh x1.6) is redder than Earth along the same ray")
	var zenith := c[1]  # texel (0, 0): ground level, straight up
	check(zenith > 0.5 and zenith < 1.0, "canon ground zenith green transmittance is a plausible clear sky (%.3f)" % zenith)

# ---------------------------------------------------------------- upload
func _check_upload(built: Dictionary) -> void:
	var timg: Image = built["transmittance"]
	var data := timg.get_data().to_float32_array()
	var small := 0
	var smallest := 1.0
	for k in range(0, data.size(), 4):
		for c in 3:
			var v := data[k + c]
			if v < 6e-5:
				small += 1
			smallest = minf(smallest, v)
	print("  canon transmittance texels below 6e-5: %d of %d channels, smallest %s" % [small, TW * TH * 3, sci(smallest)])
	check(small > 0 and smallest > 0.0, "canon LUT has real texels below 6e-5 to test with (%d)" % small)
	# 1. Image level: the RGBAF image keeps them.
	var survived := 0
	for j in TH:
		for i in TW:
			var px := timg.get_pixel(i, j)
			if px.b < 6e-5 and px.b > 0.0:
				survived += 1
	check(survived > 0, "texels below 6e-5 survive in the RGBAF image (%d)" % survived)
	# 2. Control: the half-float conversion flushes them (the H0 bug). Informational: only warn if Godot fixed it.
	var half := timg.duplicate() as Image
	half.convert(Image.FORMAT_RGBAH)
	var flushed := 0
	for j in TH:
		for i in TW:
			var px := half.get_pixel(i, j)
			var orig := timg.get_pixel(i, j)
			if orig.b < 6e-5 and orig.b > 0.0 and px.b == 0.0:
				flushed += 1
	print("  control: RGBAH conversion flushed %d texels that RGBAF keeps" % flushed)
	# 3. Texture level: through a real ImageTexture (needs a renderer; the dummy headless driver cannot read it back).
	if RenderingServer.get_video_adapter_name() == "" or DisplayServer.get_name() == "headless":
		print("  ImageTexture round trip skipped (headless dummy renderer); run under xvfb with --rendering-driver opengl3")
		return
	var tex := ImageTexture.create_from_image(timg)
	var back := tex.get_image()
	check(back != null and back.get_format() == Image.FORMAT_RGBAF, "ImageTexture keeps FORMAT_RGBAF (%s)" % (str(back.get_format()) if back else "null"))
	if back == null:
		return
	var kept := 0
	var worst := 0.0
	for j in TH:
		for i in TW:
			var a := timg.get_pixel(i, j)
			var b := back.get_pixel(i, j)
			if a.b < 6e-5 and a.b > 0.0:
				if b.b > 0.0:
					kept += 1
				worst = maxf(worst, absf(a.b - b.b) / a.b)
	print("  ImageTexture round trip: %d texels below 6e-5 kept, worst rel error %s" % [kept, sci(worst)])
	check(kept == survived, "all %d texels below 6e-5 survive the ImageTexture upload (%d kept)" % [survived, kept])
	check(worst < 1e-6, "ImageTexture round trip is exact for small values (%s)" % sci(worst))

# ---------------------------------------------------------------- timing
func _check_timing() -> void:
	var params := CporeAtmosphere.params_canon()
	var one: Array = []
	var multi: Array = []
	for rep in 7:
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = CporeAtmosphere.build(params, 0)
		multi.append((Time.get_ticks_usec() - t0) / 1000.0)
		if rep == 0:
			print("  threaded split: transmittance %.1f ms, multi-scattering %.1f ms (%d threads)" % [r["ms_transmittance"], r["ms_multiscatter"], r["threads"]])
	for rep in 3:
		var t0 := Time.get_ticks_usec()
		CporeAtmosphere.build(params, 1)
		one.append((Time.get_ticks_usec() - t0) / 1000.0)
	multi.sort()
	one.sort()
	var median: float = multi[3]
	print("  build time, threaded: median %.1f ms (min %.1f, max %.1f); single thread: median %.1f ms" % [median, multi[0], multi[-1], one[1]])
	check(median <= BUILD_MS_GATE, "LUTs build in <= %.0f ms at load (median %.1f ms, threaded)" % [BUILD_MS_GATE, median])
