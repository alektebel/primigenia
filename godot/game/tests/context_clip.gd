extends SceneTree
# A74 context attacks: a close-camera recording of starter B doing one attack in one context in the real game (real C world, real island).
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 \
#     --write-movie <out>.avi --path godot --script res://game/tests/context_clip.gd -- <bite|pounce|spit|roar> <stand|walk|gallop|far> <out>.csv [hold] [set_b]
# stand: pressed 1.9 m from the Rondo; walk / gallop: pressed while walking (jog) or running toward it from 9 m;
# far: pressed standing 11 m away. A script-owned input provider drives the player (a heading toward the Rondo, then the attack order).
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const ActionClock := preload("res://actions/action_clock.gd")
const MOVES := {"bite": 0, "spit": 3, "pounce": 8, "roar": 10}
const V_HEADING := 3
const V_ATTACK := 5

var game
var island
var stage
var sui
var rows: Array = []
var _attack_now := false
var _heading := Vector2.ZERO
var _run := 0

func _initialize() -> void:
	_run_clip.call_deferred()

func st() -> Dictionary:
	return stage.world.state()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _provider() -> Dictionary:
	if _attack_now:
		return {"verb": V_ATTACK, "target": _target, "move": MOVES[_attack], "dir": 1 if _hold or (_attack == "roar" and ActionClock.attack_set == "b") else 0, "run": _run}
	if _heading != Vector2.ZERO:
		return {"verb": V_HEADING, "hx": int(_heading.x * 32767.0), "hz": int(_heading.y * 32767.0), "run": _run}
	return {"verb": 1}

var _attack := "bite"
var _target := -1
var _hold := false

func _camera(rondo: int, follow: bool) -> void:
	var p: Dictionary = st().entities[0]
	var w: Dictionary = st().entities[rondo]
	var a := Vector3(float(p.x), game.ground(float(p.x), float(p.z)), float(p.z))
	var b := Vector3(float(w.x), game.ground(float(w.x), float(w.z)), float(w.z))
	var mid := (a + b) * 0.5 + Vector3.UP * 0.35
	var d := (b - a)
	d.y = 0.0
	var dir := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP).normalized()
	island.camera.fov = 42.0
	var dist := 5.0 + clampf(a.distance_to(b) * 0.45, 0.0, 6.0)
	island.camera.position = mid + side * dist + Vector3.UP * 1.0 - dir * 0.4 + island._landing_shake(1.0 / 30.0)
	island.camera.look_at(mid)

func _run_clip() -> void:
	var args := OS.get_cmdline_user_args()
	_attack = args[0] if args.size() > 0 else "bite"
	var ctx: String = args[1] if args.size() > 1 else "stand"
	var csv_path: String = args[2] if args.size() > 2 else "/tmp/context_clip.csv"
	_hold = args.has("hold")
	var target_name := "Rondo"
	for a in args:
		if str(a).begins_with("target="):
			target_name = str(a).substr(7)
	ActionClock.attack_set = "b" if args.has("set_b") else "a"
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
	stage.debug_now({"op": 6, "a": 3})            # god mode, wild AI off: the Rondo stands and takes it
	var rondo := -1
	var best := 1e9
	var p0: Dictionary = st().entities[0]
	for i in range(1, st().entities.size()):
		var e: Dictionary = st().entities[i]
		var sp: Dictionary = sui.species[int(e.species)] if int(e.species) >= 0 and int(e.species) < sui.species.size() else {}
		var dd := Vector2(float(e.x) - float(p0.x), float(e.z) - float(p0.z)).length()
		if str(sp.get("name", "")) == target_name and not bool(e.dead) and dd < best:
			best = dd
			rondo = i
	_target = rondo
	print("rondo #", rondo, " loadout ", st().loadout.slots, " known ", st().loadout.known)
	var w: Dictionary = st().entities[rondo]
	var start_gap: float = {"stand": {"bite": 1.9, "pounce": 3.4, "spit": 4.2, "roar": 2.8}[_attack], "walk": 5.0, "gallop": 6.5, "far": 11.0}[ctx]
	var rc := -1
	var base_ang := 0.0
	for ang in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
		rc = stage.debug_now({"op": 1, "id": 0, "x": float(w.x) + cos(ang) * start_gap, "z": float(w.z) + sin(ang) * start_gap})
		if rc == 0:
			base_ang = ang
			break
	print("teleport rc ", rc)
	stage.step_ticks(2)
	sui.selected_id = rondo
	island.chase_enabled = false
	stage.input_provider = Callable(self, "_provider")
	await settle(40)
	stage.paused = false
	await settle(20)
	var frame := 0
	var press_gap: float = {"stand": 99.0, "walk": 3.4, "gallop": 3.6, "far": 99.0}[ctx]
	var pressed_frame := -1
	var hit_frame := -1
	var hold_pos := Vector2(float(st().entities[rondo].x), float(st().entities[rondo].z))
	_run = 1 if ctx == "gallop" else 0
	while frame < 200:
		var s: Dictionary = st()
		var pe: Dictionary = s.entities[0]
		var re: Dictionary = s.entities[rondo]
		var gap := Vector2(float(pe.x) - float(re.x), float(pe.z) - float(re.z)).length() - 0.6
		if pressed_frame < 0:
			if ctx == "walk" or ctx == "gallop":
				_heading = (Vector2(float(re.x), float(re.z)) - Vector2(float(pe.x), float(pe.z))).normalized()
				if gap <= press_gap and float(pe.speed) > (0.45 if ctx == "walk" else 1.4):
					pressed_frame = frame
					_attack_now = true
			elif frame >= 10:
				pressed_frame = frame
				_attack_now = true
		var f: Dictionary = s.combat.fighters[0] if s.combat.fighters.size() > 0 else {}
		for ev in s.combat.events:
			if int(ev.type) == 1 and int(ev.a) == 0 and hit_frame < 0:
				hit_frame = frame
		if int(s.active) < 0:
			stage.debug_now({"op": 1, "id": rondo, "x": hold_pos.x, "z": hold_pos.y})     # the prey stands its ground until the hit lands
		_camera(rondo, ctx == "gallop" or ctx == "far")
		rows.append("%d,%d,%d,%d,%d,%d,%.2f,%.2f,%.1f,o%d/e%d/a%d,p%.2f;%.2f f%.2f;%.2f w%.2f;%.2f,%s" % [frame, int(s.combat.tick), int(f.get("move", -9)), int(f.get("phase", -9)), int(f.get("ctx", -9)),
			1 if hit_frame == frame else 0, float(pe.speed), gap, float(re.hp), int(s.order.verb), int(s.get("error", 0)), int(s.active), float(pe.x), float(pe.z), float(pe.fx), float(pe.fz), float(re.x), float(re.z), str(s.combat.events.map(func(e): return "%d:%d>%d" % [int(e.type), int(e.a), int(e.b)]))])
		if frame % 30 == 0:
			stage.debug_now({"op": 4, "id": rondo, "x": 100.0, "z": -1.0})
		if pressed_frame >= 0 and frame > pressed_frame + 60 and f.get("move", -1) == -1 and (s.combat.fighters.size() == 0 or int(f.get("phase", 0)) == 0) and frame > pressed_frame + 90:
			break
		frame += 1
		await process_frame
	var fa := FileAccess.open(csv_path, FileAccess.WRITE)
	fa.store_line("frame,tick,move,phase,ctx,hit,player_speed,gap,rondo_hp,order_err_active,events")
	for r in rows:
		fa.store_line(r)
	fa.close()
	print("frames ", frame, " pressed ", pressed_frame, " hit_frame ", hit_frame)
	quit()
