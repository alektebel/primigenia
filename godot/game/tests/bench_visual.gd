extends SceneTree
# Visual erosion timings and memory (terrain v5): godot --headless --path godot --script res://game/tests/bench_visual.gd -- [seed] [out.json]
# Sim generation, visual maps (1 thread and all threads), cache save and load, textures. CPU only; the figures scale with the core count.
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v: int = int(args[0]) if args.size() > 0 else 1
	var out: String = args[1] if args.size() > 1 else ""
	var r := {"cores": OS.get_processor_count()}
	var t0 := Time.get_ticks_msec()
	var m0 := OS.get_static_memory_usage()
	var e: Dictionary = CporeTerrain.new().generate(TerrainCache.resolve({"seed": seed_v}))
	r["sim_ms"] = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	var maps: Dictionary = CporeTerrain.surface_maps(e)
	r["surface_maps_ms"] = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	var v1: Dictionary = CporeTerrain.visual_maps(e, {"factor": 4, "threads": 1})
	r["visual_1_thread_ms"] = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	var vn: Dictionary = CporeTerrain.visual_maps(e, {"factor": 4})
	r["visual_ms"] = Time.get_ticks_msec() - t0
	r["visual_threads"] = vn.vstats.threads
	r["identical_1_vs_n_threads"] = v1.vhash == vn.vhash and v1.vheight == vn.vheight
	r["vheight_mb"] = vn.vheight.size() / 1048576.0
	r["vmaps_mb"] = vn.vmaps.size() / 1048576.0
	var entry := e.duplicate()
	for k in maps:
		entry[k] = maps[k]
	for key in ["vn", "vheight", "vh_min", "vh_range", "vmaps", "vhash", "vstats"]:
		entry[key] = vn[key]
	entry["render_prep"] = TerrainData.RENDER_PREP_VERSION
	var dir := "user://bench_visual_cache"
	var p := TerrainCache.resolve({"seed": seed_v})
	t0 = Time.get_ticks_msec()
	TerrainCache.save_entry(p, entry, dir)
	r["cache_save_ms"] = Time.get_ticks_msec() - t0
	var path := TerrainCache.cache_path(p, dir)
	r["cache_file_mb"] = FileAccess.get_file_as_bytes(path).size() / 1048576.0
	t0 = Time.get_ticks_msec()
	var back := TerrainCache.load_entry(p, dir)
	r["cache_load_ms"] = Time.get_ticks_msec() - t0
	r["cache_hit"] = not back.is_empty()
	DirAccess.remove_absolute(path)
	var d = TerrainData.new()
	t0 = Time.get_ticks_msec()
	d.setup(entry, false)
	r["setup_ms"] = Time.get_ticks_msec() - t0
	r["ram_added_mb"] = (OS.get_static_memory_usage() - m0) / 1048576.0
	r["vram_visual_mb_r16"] = 4096.0 * 4096.0 * 2.0 / 1048576.0 + 2048.0 * 2048.0 * 4.0 / 1048576.0
	print(JSON.stringify(r, "  "))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(r, "  "))
	quit()
