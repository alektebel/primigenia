extends SceneTree
# Software-GL screenshots of flag mode: hovering a creature, the note box, pins. Usage:
# xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://devtools/tests/notes_evidence.gd -- <output dir> <scratch notes dir>

const TerrainCache := preload("res://game/island/terrain_cache.gd")
var out_dir := ""

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shot(name: String) -> void:
	await settle(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir.path_join(name), 0.9)
	print("wrote ", name)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/notes-evidence"
	var scratch: String = args[1] if args.size() > 1 else "/tmp/notes-scratch"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	var dev = root.get_node("Dev")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 600:
		await process_frame
		if game.stage != null and dev.sites != null:
			break
	await settle(30)
	var flag = dev.flag
	flag.base_dir = scratch
	print("spawn: ", dev.console.registry.execute("spawn garfio").out)
	await settle(40)
	game.stage.paused = true          # hold the world still so the cursor stays on the creature
	await settle(10)
	var scene := current_scene
	var ents: Array = game.stage.cur.entities
	var gid := ents.size() - 1
	var e: Dictionary = ents[gid]
	var pos := Vector3(e.x, game.visual_ground(e.x, e.z) + 0.6, e.z)
	var cam: Camera3D = scene.camera
	var sp := cam.unproject_position(pos)
	print("garfio #", gid, " at screen ", sp)
	flag.enter()
	root.warp_mouse(sp)
	await settle(30)
	print("hover: ", flag.hover.get("kind"), " ", flag.hover.get("name"))
	await shot("flag-hover.jpg")
	flag.open_box(flag.hover)
	flag._edit.text = "legs cross when it turns toward the water"
	flag.cycle_tag()
	flag.cycle_tag()
	flag._update_box()
	await shot("flag-note-box.jpg")
	var err: String = await flag.commit_box()
	print("saved: ", err, " ", flag.last_saved)
	# two more notes (a terrain spot and the player) so the pins show
	flag.save_note("grass blades float over the stream", ["look"], 1, {"kind": "terrain", "id": -1, "name": "ground (2, 3)", "pos": Vector3(e.x - 4.0, game.visual_ground(e.x - 4.0, e.z), e.z + 2.0)}, false)
	flag.save_note("idea: show the nest radius here", ["idea"], 3, {"kind": "prop", "id": 0, "name": "nest", "pos": Vector3(game.stage.cur.entities[0].x + 3.0, game.visual_ground(game.stage.cur.entities[0].x + 3.0, game.stage.cur.entities[0].z), game.stage.cur.entities[0].z)}, false)
	root.warp_mouse(Vector2(640, 600))
	await settle(20)
	await shot("flag-pins.jpg")
	flag.exit()
	# the sample note files (no scenario binaries) for the evidence folder
	var d := DirAccess.open(scratch)
	for sub in d.get_directories():
		var n = JSON.parse_string(FileAccess.get_file_as_string(scratch.path_join(sub).path_join("note.json")))
		if n.text.begins_with("legs cross"):
			DirAccess.make_dir_recursive_absolute(out_dir.path_join("note-sample"))
			DirAccess.copy_absolute(scratch.path_join(sub).path_join("note.json"), out_dir.path_join("note-sample/note.json"))
			DirAccess.copy_absolute(scratch.path_join(sub).path_join("crop.jpg"), out_dir.path_join("note-sample/crop.jpg"))
			print("files: ", d.get_files(), " ", DirAccess.open(scratch.path_join(sub)).get_files())
	quit(0)
