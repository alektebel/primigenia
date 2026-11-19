extends SceneTree
# C2 secrets evidence: each meteor shard with its line, the cave (mouth, passage, chamber), the nocturnal Acechalunas at night and
# hidden by day, the sixth species (Babosa) and the island at dusk. xvfb JPG, one island seed.
# xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/secrets_evidence.gd -- <out dir> [seed]
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(out: String, name: String) -> void:
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(name), 0.9)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var seed_n := int(args[1]) if args.size() > 1 else 1
	var only: Array = Array(args.slice(2))    # optional: shards cave night babosa
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(960, 540)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 4000
	game.settings.seed = seed_n
	# a cache directory of its own: the shared user://terrain can hold an island made before the route-certification terrain curation
	var entry := TerrainCache.load_entry({"seed": seed_n}, "user://terrain-secrets")
	if entry.is_empty():
		entry = TerrainCache.build({"seed": seed_n}, CporeTerrain.new(), "user://terrain-secrets")
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	var island = current_scene
	var stage = game.stage
	stage.debug_now({"op": 6, "a": 2})    # freeze the wild
	island.chase_enabled = false
	var cam: Camera3D = island.debug_camera
	var st: Dictionary = stage.world.state()
	print("shards ", st.shards.items.size(), " cave ", st.cave.enabled, " species ", st.species.size())
	# --- the five shards, each with its line (the UI whisper)
	for it in (st.shards.items if only.is_empty() or only.has("shards") else []):
		var x := float(it.x)
		var z := float(it.z)
		var rc: int = stage.debug_now({"op": 1, "id": 0, "x": x - 2.2, "z": z - 0.6})
		var look := Vector3(x, game.visual_ground(x, z) + 1.0, z)
		var p := Vector3(x + 3.6, 0, z + 5.5)
		p.y = game.visual_ground(p.x, p.z) + 2.0
		cam.position = p
		cam.look_at(look)
		await settle(6)
		if int(it.index) == 0:
			island.hosts[0].visible = false
			await shot(out, "shard_%d_ground.jpg" % int(it.index))
			island.hosts[0].visible = true
		stage.queue_order({"verb": 16, "target": int(it.id)})
		await settle(20)
		cam.look_at(look)
		await shot(out, "shard_%d_line.jpg" % int(it.index))
		print("shard ", it.index, " tp ", rc, " at ", x, " ", z)
	# --- the fossil node inside the chamber, the player waiting in the passage
	if only.has("cavefossil"):
		var cv2: Dictionary = st.cave
		var nodes: Array = stage.world.state().parts.nodes
		var node: Dictionary = nodes[nodes.size() - 1]
		stage.debug_now({"op": 1, "id": 0, "x": float(cv2.x) - float(cv2.fx) * 6.0, "z": float(cv2.z) - float(cv2.fz) * 6.0})
		island.chase_enabled = false
		var from := Vector3(float(node.x) + float(cv2.fx) * 4.5 + float(cv2.fz) * 2.0, float(cv2.floor) + 2.0, float(node.z) + float(cv2.fz) * 4.5 - float(cv2.fx) * 2.0)
		cam.position = from
		cam.look_at(Vector3(float(node.x), float(cv2.floor) + 0.4, float(node.z)))
		await settle(20)
		await shot(out, "cave_fossil.jpg")
	# --- a shard by day and by night, the player out of the frame (the glow shows in the dark)
	if only.has("shardglow"):
		for k in [0, 3]:
			var it2: Dictionary = st.shards.items[k]
			var sx := float(it2.x)
			var sz := float(it2.z)
			stage.debug_now({"op": 1, "id": 0, "x": sx - 40.0, "z": sz - 40.0})
			var cp := Vector3(sx + 3.2, 0, sz + 4.4)
			cp.y = game.visual_ground(cp.x, cp.z) + 1.5
			var lk := Vector3(sx, game.visual_ground(sx, sz) + 0.9, sz)
			for phase in [["day", 4500], ["night", 11500]]:
				stage.debug_now({"op": 5, "a": int(phase[1])})
				await settle(25)
				cam.position = cp
				cam.look_at(lk)
				await settle(6)
				await shot(out, "shard_%d_%s.jpg" % [k, phase[0]])
	# --- the cave: outside the mouth, in the passage, in the chamber (dark inside)
	if only.is_empty() or only.has("cave"):
		var cv: Dictionary = stage.world.state().cave
		var fx := float(cv.fx)
		var fz := float(cv.fz)
		var mouth := Vector3(float(cv.x), 0, float(cv.z))
		stage.debug_now({"op": 1, "id": 0, "x": mouth.x + fx * 7.0, "z": mouth.z + fz * 7.0})
		var pp := Vector3(mouth.x + fx * 16.0 - fz * 5.0, 0, mouth.z + fz * 16.0 + fx * 5.0)
		pp.y = game.visual_ground(pp.x, pp.z) + 2.2
		cam.position = pp
		cam.look_at(Vector3(mouth.x, float(cv.floor) + 1.5, mouth.z))
		await settle(20)
		await shot(out, "cave_mouth.jpg")
		island.chase_enabled = true
		stage.debug_now({"op": 1, "id": 0, "x": mouth.x - fx * 7.0, "z": mouth.z - fz * 7.0})
		await settle(30)
		await shot(out, "cave_passage.jpg")
		stage.debug_now({"op": 1, "id": 0, "x": float(cv.chamber_x), "z": float(cv.chamber_z)})
		await settle(20)
		await shot(out, "cave_chamber.jpg")
		print("cave inside ", stage.world.state().cave.inside, " cam ", cam.position, " player ", island.player_pos, " zone cam ", island.cave_site.zone(cam.position.x, cam.position.z))
	# --- day, dusk, night over the same valley; Acechalunas hidden by day, out at night
	if only.is_empty() or only.has("night"):
		island.chase_enabled = false
		var ids := []
		for i in range(1, st.entities.size()):
			if int(st.entities[i].species) == 4:
				ids.append(i)
		var c := Vector2.ZERO
		for i in ids:
			c += Vector2(st.entities[i].x, st.entities[i].z)
		c /= maxi(ids.size(), 1)
		print("acechalunas ", ids.size(), " centre ", c)
		island.hosts[0].visible = false
		stage.debug_now({"op": 1, "id": 0, "x": c.x + float(st.cave.fx) * 26.0, "z": c.y + float(st.cave.fz) * 26.0})
		var look := Vector3(c.x, game.visual_ground(c.x, c.y) + 1.0, c.y)
		for phase in [["day", 4500], ["night", 11500]]:
			stage.debug_now({"op": 5, "a": int(phase[1])})
			await settle(25)
			for view in ([["wide", 14.0, 0.8]] if phase[0] == "day" else [["wide", 14.0, 0.8], ["close", 6.5, 0.8]]):
				# on the open side of the group, away from the cave mouth, looking back at them
				var outward := Vector2(float(st.cave.fx), float(st.cave.fz))
				var side := Vector2(-outward.y, outward.x)
				var p2 := Vector3(c.x + (outward.x * 0.9 + side.x * 0.4) * float(view[1]), 0, c.y + (outward.y * 0.9 + side.y * 0.4) * float(view[1]))
				p2.y = game.visual_ground(p2.x, p2.z) + 2.0
				cam.position = p2
				cam.look_at(look)
				await settle(8)
				var now: Dictionary = stage.world.state()
				for i in ids:
					var e: Dictionary = now.entities[i]
					print("  ", phase[0], " id ", i, " at ", Vector2(e.x, e.z), " hidden ", e.hidden, " hp ", e.hp, " cam ", p2, " look ", look)
				await shot(out, "acechalunas_%s_%s.jpg" % [phase[0], view[0]])
	# --- the sixth species
	if only.is_empty() or only.has("babosa"):
		stage.debug_now({"op": 5, "a": 4500})
		await settle(20)
		var babs := []
		for i in range(1, st.entities.size()):
			if int(st.entities[i].species) == 5:
				babs.append(i)
		if not babs.is_empty():
			var bc := Vector2.ZERO
			for i in babs:
				bc += Vector2(st.entities[i].x, st.entities[i].z)
			bc /= babs.size()
			island.hosts[0].visible = false
			stage.debug_now({"op": 1, "id": 0, "x": bc.x - 14.0, "z": bc.y - 14.0})
			print("babosa ", babs.size(), " centre ", bc)
			var bl := Vector3(bc.x, game.visual_ground(bc.x, bc.y) + 0.6, bc.y)
			for phase in [["noon", 4500], ["dusk", 9500]]:
				stage.debug_now({"op": 5, "a": int(phase[1])})
				await settle(20)
				for view in ([["wide", 13.0]] if phase[0] == "noon" else [["close", 5.5]]):
					var p3 := Vector3(bc.x + sin(0.8) * float(view[1]), 0, bc.y + cos(0.8) * float(view[1]))
					p3.y = game.visual_ground(p3.x, p3.z) + 1.8
					cam.position = p3
					cam.look_at(bl)
					await settle(8)
					await shot(out, "babosa_%s_%s.jpg" % [phase[0], view[0]])
	print("done")
	quit()
