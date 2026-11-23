extends SceneTree
# A64 bite-port: a close-camera recording of starter B biting a Rondo in the real game (real C world, real UI, real island).
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 \
#     --write-movie <out>.avi --path godot --script res://game/tests/bite_clip.gd -- <bite|chain> <out>.csv [yaw_deg]
# mode bite : one bite, then the recovery plays out
# mode peck : the galloping peck from 4 m (A65)
# mode chain: one bite, and the bite key pressed again right after the contact (the chained peck)
# The csv has one row per frame: time, C tick, player move/phase/ptick, wild hp, the impact and pause flags.
const TerrainCache := preload("res://game/island/terrain_cache.gd")

var game
var island
var stage
var sui
var rows: Array = []
var mode := "bite"

func _initialize() -> void:
	_run.call_deferred()

func st() -> Dictionary:
	return stage.world.state()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _camera(rondo: int, side_deg: float) -> void:
	var p: Dictionary = st().entities[0]
	var w: Dictionary = st().entities[rondo]
	var a := Vector3(float(p.x), game.ground(float(p.x), float(p.z)), float(p.z))
	var b := Vector3(float(w.x), game.ground(float(w.x), float(w.z)), float(w.z))
	var mid := (a + b) * 0.5 + Vector3.UP * 0.35
	var d := (b - a)
	d.y = 0.0
	var dir := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP).normalized().rotated(Vector3.UP, deg_to_rad(side_deg - 55.0) * 0.0)
	island.camera.fov = 42.0
	island.camera.position = mid + side * 5.0 + Vector3.UP * 0.9 - dir * 0.4 + island._landing_shake(1.0 / 30.0)
	island.camera.look_at(mid)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "bite"
	var csv_path: String = args[1] if args.size() > 1 else "/tmp/bite_clip.csv"
	var yaw_deg: float = float(args[2]) if args.size() > 2 else 55.0
	root.size = Vector2i(960, 540)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 1500
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
	island = current_scene
	stage = game.stage
	sui = island.stage_ui
	stage.paused = true
	stage.debug_now({"op": 6, "a": 3})            # god mode, wild AI off: the Rondo stands and takes the bites
	# the nearest living Rondo
	var rondo := -1
	for i in range(1, st().entities.size()):
		var e: Dictionary = st().entities[i]
		var sp: Dictionary = sui.species[int(e.species)] if int(e.species) >= 0 and int(e.species) < sui.species.size() else {}
		if str(sp.get("name", "")) == "Rondo" and not bool(e.dead):
			rondo = i
			break
	print("rondo #", rondo, " loadout ", st().loadout.slots, " player radius ", st().entities[0].radius_cm)
	var w: Dictionary = st().entities[rondo]
	var n: Vector2 = stage.world.get_setup().nest
	var rc := -1
	for ang in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
		rc = stage.debug_now({"op": 1, "id": 0, "x": float(w.x) + cos(ang) * (4.0 if mode == "peck" else 1.9), "z": float(w.z) + sin(ang) * (4.0 if mode == "peck" else 1.9)})
		if rc == 0:
			break
	print("teleport rc ", rc)
	stage.step_ticks(2)
	sui.selected_id = rondo
	island.chase_enabled = false              # a close side camera, set by hand every frame (below); the island's shake is added to it
	await settle(40)
	stage.paused = false
	# the bite slot
	var bite_slot := -1
	for i in sui.ui.abilities.size():
		if int(sui.ui.abilities[i].get("move", -1)) == 0:
			bite_slot = i
	print("bite slot ", bite_slot, " abilities ", sui.ui.abilities.size())
	# let the camera settle behind the player, then bite
	await settle(30)
	var t0 := Time.get_ticks_msec()
	var frame := 0
	var hit_frame := -1
	var chained := false
	var bit := false
	while frame < 120:
		if frame == 6 and not bit:
			bit = true
			sui._pending_attack = {"target": rondo, "move": 7 if mode == "peck" else 0, "chain": false, "tick": int(st().tick)}
		var s: Dictionary = st()
		var f: Dictionary = s.combat.fighters[0] if s.combat.fighters.size() > 0 else {}
		for ev in s.combat.events:
			if int(ev.type) == 1 and int(ev.a) == 0 and hit_frame < 0:
				hit_frame = frame
		if mode == "chain" and hit_frame >= 0 and not chained and frame >= hit_frame + 4:
			chained = true
			sui._pending_attack = {"target": rondo, "move": 7, "chain": true, "tick": int(st().tick)}   # what the bite key sends inside the chain window
		var pl = island.hosts[0].layer() if island.hosts.has(0) else null
		_camera(rondo, yaw_deg)
		rows.append("%d,%d,%d,%d,%d,%.1f,%d,%d" % [frame, int(s.combat.tick), int(f.get("move", -9)), int(f.get("phase", -9)), int(f.get("phase_tick", -9)),
			float(s.entities[rondo].hp), 1 if (pl != null and pl.paused()) else 0, 1 if hit_frame == frame else 0])
		if frame % 30 == 0:
			stage.debug_now({"op": 4, "id": rondo, "x": 100.0, "z": -1.0})   # keep the Rondo healthy
		frame += 1
		await process_frame
	var fa := FileAccess.open(csv_path, FileAccess.WRITE)
	fa.store_line("frame,tick,move,phase,ptick,wild_hp,paused,hit")
	for r in rows:
		fa.store_line(r)
	fa.close()
	print("frames ", frame, " hit_frame ", hit_frame, " chained ", chained, " wall ", Time.get_ticks_msec() - t0, " ms")
	quit()
