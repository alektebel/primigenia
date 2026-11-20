extends SceneTree
# Health lines over creatures (brief creature-fixes 2): hostile, selected and a far herd, plus a hit mid tick-down.
# LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/bars_evidence.gd -- <out dir>
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(out: String, name: String, n: int = 6) -> void:
	await settle(n)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(name), 0.9)
	print("saved ", name)

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	var island = current_scene
	var st = game.stage
	st.debug_now({"op": 6, "a": 2})     # freeze the wild: nothing wanders off
	var p: Dictionary = st.cur.entities[0]
	var f := Vector2(p.fx, p.fz).normalized()
	var perp := Vector2(-f.y, f.x)
	var made := []
	for i in 6:
		var k := (i + 1) / 2
		var pos := Vector2(p.x, p.z) + f * (9.0 + k * 3.0) + perp * (7.0 * k * (1.0 if i % 2 == 0 else -1.0))
		var sp := 2 + (i % 3)
		if st.debug_now({"op": 2, "a": sp, "x": pos.x, "z": pos.y}) == 0:
			made.append(sp)
	# a far herd: eight more, 80 m out
	for i in 8:
		st.debug_now({"op": 2, "a": 1, "x": p.x - f.x * 80.0 + perp.x * i * 3.0, "z": p.z - f.y * 80.0 + perp.y * i * 3.0})
	await settle(20)
	var ents: Array = st.cur.entities
	for i in range(1, ents.size()):
		print("entity ", i, " species ", ents[i].species, " hostile ", ents[i].get("hostile", false), " hp ", ents[i].hp, "/", ents[i].hp_max)
	await shot(out, "bars_hostile.jpg", 30)
	var pick := 1
	for i in range(1, ents.size()):
		if not bool(ents[i].get("hostile", false)):
			pick = i
			break
	island.stage_ui.select_id(pick)
	await shot(out, "bars_selected.jpg", 20)
	st.debug_now({"op": 4, "id": pick, "x": ents[pick].hp_max * 0.45, "z": -1.0})
	await settle(2)
	await shot(out, "bars_hit_mid.jpg", 1)
	await shot(out, "bars_hit_after.jpg", 40)
	print("bars visible ", island.stage_ui.ui.bars.visible_count())
	quit()
