extends RefCounted
## Test and evidence harness: a real Creature on flat ground, the G73 controller, the action layer and a
## ScriptedFeed standing in for the C world (no GDExtension needed).

const Morph := preload("res://locomotion/loco_morphology.gd")
const Ctl := preload("res://locomotion/loco_controller.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const BodyMap := preload("res://actions/action_body_map.gd")
const Layer := preload("res://actions/action_layer.gd")
const Feed := preload("res://actions/action_feed.gd")
const Data := preload("res://actions/data/../action_data.gd")
const Rig := preload("res://actions/action_rig.gd")
const Scripted := preload("res://actions/test/scripted_feed.gd")

var c
var desc: Dictionary
var morph
var ctl
var map
var layer
var feed
var sf
var dist := 4.0
var target_h := 1.2
var acc := 0.0
var sim_t := 0.0
var sig: Dictionary = {}
var ctx_extra: Dictionary = {}
var layer_on := true
var impacts: Array = []          # sim times of action_event("impact")
var events: Array = []
var pos := Vector3.ZERO
var yaw := 0.0
var vel := Vector3.ZERO
var speed_override := 0.0
var _raw: Dictionary

static func load_raw() -> Dictionary:
	return Data.load_all("res://actions/data")

func build(parent: Node, seed_name: String, raw: Dictionary) -> void:
	_raw = raw
	c = Creature.new()
	parent.add_child(c)
	var seeds: Dictionary = Creature.seeds()
	if seeds.has(seed_name):
		c.load_genome(seeds[seed_name])
	else:
		c.load_genome(JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % seed_name.to_lower())))
	desc = Adapter.loco_describe(c, 1.0)
	morph = Morph.analyse(desc)
	ctl = Ctl.new(morph, func(_x, _z): return 0.0)
	ctl.reset(Vector3.ZERO, 0.0)
	map = BodyMap.from_rig(c, desc, morph)
	layer = Layer.new()
	layer.setup(map, raw, c, 0)
	layer.action_event.connect(func(n: String, d: Dictionary) -> void:
		events.append([sim_t, n, d])
		if n == "impact":
			impacts.append(sim_t))
	feed = Feed.new()
	sf = Scripted.new()
	sf.pos = [Vector2(0, 0), Vector2(0, dist)]
	sf.face = [Vector2(0, 1), Vector2(0, -1)]

func ctx() -> Dictionary:
	var tgt := {"id": 1, "pos": Vector3(0, 0, dist), "radius": 0.6, "height": target_h}
	var d := {"sig": sig.get(0, {}), "tick": sf.tick, "alpha": acc / 0.1, "pos": pos, "yaw": yaw, "speed": speed_override, "vel": vel, "target": tgt, "beat_phase": 0, "mode": ""}
	d.merge(ctx_extra, true)
	return d

## One rendered frame of dt seconds. The scripted C world ticks every 0.1 s.
func frame(dt: float) -> void:
	acc += dt
	while acc >= 0.1 - 1e-9:
		acc -= 0.1
		sf.step()
		sig = feed.read(sf.prev, sf.cur, 0.0)
	var alpha := acc / 0.1
	sig = feed.read(sf.prev, sf.cur, alpha)
	sim_t += dt
	ctl.step(dt, pos, yaw, vel)
	if layer_on:
		layer.update(dt, ctx())
		layer.apply(ctl.pose, dt)
	Adapter.loco_apply(c, ctl.pose, desc)
	if layer_on:
		Rig.apply_parts(c, ctl.pose.act)

func run(seconds: float, dt := 1.0 / 60.0) -> void:
	var n := int(round(seconds / dt))
	for i in n:
		frame(dt)

func soles() -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in desc.leg_ids.size():
		out.append(c.legs[desc.leg_ids[j]].foot.global_position)
	return out

func bone_rotations() -> Array:
	var out := []
	for b in c.skeleton.get_bone_count():
		out.append(c.skeleton.get_bone_pose_rotation(b))
	return out

func mouth_world() -> Vector3:
	return layer._mouth_world

func jaw_node():
	for e in c.parts:
		if e.hooks.has("jaw") and e.hooks.jaw is Node3D:
			return e.hooks.jaw
	return null

func free_all() -> void:
	c.queue_free()
