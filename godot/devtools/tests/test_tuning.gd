extends RefCounted
# Step 10: tuning registry and A/B.

const StageWorld := preload("res://game/stage/stage_world.gd")
const Registry := preload("res://devtools/tuning/registry.gd")
const ChaseCamera := preload("res://game/player/chase_camera.gd")
const FakeCtl := preload("res://devtools/tests/fake_ctl.gd")

func _world() -> Node:
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	sw.reset(setup)
	sw.input_provider = func() -> Dictionary: return {"verb": 3, "hx": 20000, "hz": 20000, "sprint": 0}
	return sw

func run(t) -> void:
	var sw = _world()
	var ctl = FakeCtl.new()
	var island := {"chase": ChaseCamera.new(1.5, 0.0, Callable()), "hosts": {0: {"driver": {"controller": ctl}}}}
	var tn = Registry.new()
	tn.dev_dir = "res://definitely-missing"
	tn.user_dir = "user://devtools-test/tuning"
	tn.bind_sim(sw)
	tn.bind_island(island)
	t.eq(tn.order.size(), 28 + 10 + 5, "28 sim + 10 camera + 5 locomotion parameters")
	t.eq(tn.current_values(), {}, "nothing changed at the start")
	# set/get for every GDScript entry
	for k in tn.order:
		var e: Dictionary = tn.entries[k]
		if e.sim:
			continue
		var target: float = lerpf(e.min, e.max, 0.7)
		t.eq(tn.set_value(k, target), "", "set %s" % k)
		t.check(absf(tn.value(k) - target) < 1e-4, "%s reads back %s" % [k, target])
		tn.reset(k)
		t.check(absf(tn.value(k) - e.default) < 1e-6, "%s resets" % k)
	t.check(absf(island.chase.YAW_MAX - 1.74) < 1e-6 and ctl.vault_gain == 1.0, "defaults restored")
	t.check(tn.set_value("nope/x", 1.0) != "", "unknown key is an error")
	# a sim entry reaches C after one tick and is in the v3 log
	t.eq(tn.set_value("sim/jog_k", 2.0), "", "sim/jog_k = 2")
	sw.step_once()
	t.check(absf(sw.world.param(0) - 2.0) < 1e-6, "CporeWorld.param(0) changed")
	t.check(sw.log_debug.size() == 1 and sw.export_log().contains("\n" + str(0) + " 7 0 0 "), "and the PARAM op is in the log")
	t.check(tn.set_value("sim/jog_k", 99.0) == "" and absf(tn.value("sim/jog_k") - tn.entries["sim/jog_k"].max) < 1e-6, "values clamp to the range")
	# diff round trip
	tn.set_value("camera/yaw_max", 3.0)
	var d := tn.diff("test")
	t.check(d.values.has("sim/jog_k") and d.values.has("camera/yaw_max") and d.format == "primigenia.tuning/1", "diff holds the changed entries")
	var path := tn.save_file("unit")
	t.check(path != "" and FileAccess.file_exists(path), "diff saved to %s" % path)
	tn.apply({"format": Registry.FORMAT, "values": {}})
	t.eq(tn.current_values(), {}, "applying an empty diff resets everything")
	t.eq(tn.load_file("unit"), "", "diff loads")
	t.check(absf(tn.value("camera/yaw_max") - 3.0) < 1e-4, "loaded value applied")
	t.check(tn.load_file("missing-one") != "", "missing file is an error sentence")
	# A/B: swap twice returns to identical values
	tn.apply({"format": Registry.FORMAT, "values": {}})
	tn.set_value("camera/lead", 0.3)
	tn.store_active()
	var before := tn.current_values()
	tn.swap()
	t.eq(tn.active, "B", "swap activates B")
	t.eq(tn.current_values(), {}, "B starts empty")
	tn.set_value("camera/pos_tau", 0.3)
	tn.swap()
	t.eq(tn.current_values(), before, "A again")
	tn.swap()
	tn.swap()
	t.eq(tn.current_values(), before, "swap twice is the identity")
	t.check(tn.chip().begins_with("Tuning A"), "chip names the slot: %s" % tn.chip())
	var st := tn.state()
	t.eq(st.active, "A", "state records the active slot")
	# defaults leave the hash equal to an untuned run
	tn.apply({"format": Registry.FORMAT, "values": {}})
	var a = _world()
	var b = _world()
	var tb = Registry.new()
	tb.bind_sim(b)
	tb.set_value("sim/jog_k", 2.0)
	tb.reset("sim/jog_k")
	for i in 100:
		a.step_once()
		b.step_once()
	t.eq(b.world.hash(), a.world.hash(), "tuning that ends at the defaults leaves the world hash equal to an untuned run")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://devtools-test/tuning/unit.json"))
