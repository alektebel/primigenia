extends RefCounted
# ActorHost: placeholder fallback, the dynamic module hook (proved with a fake module), placement.

const ActorHost := preload("res://game/actors/actor_host.gd")
const Profile := preload("res://game/stage/profile.gd")

const FAKE := "user://m0-fake-creature.gd"
const FAKE_BAD := "user://m0-fake-creature-bad.gd"

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func run(t) -> void:
	var genome: Dictionary = Profile.load_json("res://game/data/merodeador.json")
	var ground := func(x: float, z: float) -> float: return 7.0 + 0.01 * x
	var host = ActorHost.new()
	host.module_path = "res://creature/__absent__.gd"
	host.setup(genome, 0, {}, ground)
	t.eq(host.uses_module, false, "the placeholder is used when the creature module is absent")
	var h: float = host.height()
	t.check(h >= 1.5 and h <= 4.0, "Merodeador placeholder height %.2f m is within [1.5, 4]" % h)
	var s := {"pos": Vector3(20.0, 7.2, 5.0), "yaw": PI / 2.0, "speed": 3.0, "vel": Vector3.ZERO}
	host.update(0.1, s)
	var box: AABB = host.body.rest_aabb()
	t.check(absf(box.position.y) < 0.05, "the lowest point of the placeholder touches the ground (min y %.3f)" % box.position.y)
	t.check(absf(host.position.y - 7.2) < 1e-5, "host stands on the given ground height")
	var fwd: Vector3 = host.basis * Vector3(0, 0, 1)
	t.check(fwd.distance_to(Vector3(1, 0, 0)) < 1e-6, "yaw pi/2 turns +Z forward to +X")
	var occ: Array = host.occluders()
	t.check(occ.size() >= 8 and occ.size() <= 12, "8 to 12 occluders (%d)" % occ.size())

	# The module hook, proved with a fake module that exposes the g-creature surface.
	_write(FAKE, "extends Node3D\nvar legs := []\nfunc load_genome(doc):\n\treturn {\"ok\": true}\nfunc rest_aabb():\n\treturn AABB(Vector3.ZERO, Vector3(1, 2.5, 3))\nfunc solve_legs():\n\tpass\nfunc pose_legs_rest():\n\tpass\n")
	var fake_host = ActorHost.new()
	fake_host.module_path = FAKE
	fake_host.setup(genome, 0, {}, ground)
	t.eq(fake_host.uses_module, true, "a module that loads the genome is used")
	t.eq(fake_host.height(), 2.5, "camera height comes from rest_aabb().size.y")
	fake_host.update(0.1, s)
	t.check(fake_host.body.get_script() != null, "the module node is the body")
	# A module that rejects the genome falls back to the placeholder.
	_write(FAKE_BAD, "extends Node3D\nfunc load_genome(doc):\n\treturn {\"ok\": false, \"error\": \"bad\"}\n")
	var bad_host = ActorHost.new()
	bad_host.module_path = FAKE_BAD
	bad_host.setup(genome, 0, {}, ground)
	t.eq(bad_host.uses_module, false, "a rejected genome falls back to the placeholder")
	for path in [FAKE, FAKE_BAD]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	host.free()
	fake_host.free()
	bad_host.free()
