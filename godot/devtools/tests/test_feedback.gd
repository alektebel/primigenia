extends RefCounted
# Step 11: the F8 bundle writes every file, the replay reproduces its hashes in world_cli, the scenario restores.

const StageWorld := preload("res://game/stage/stage_world.gd")
const Feedback := preload("res://devtools/feedback.gd")
const Scenario := preload("res://devtools/scenario.gd")

func run(t) -> void:
	Feedback.install_logger()
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	sw.reset(setup)
	# god mode (debug op 6, flag 1): the walking player met a hostile wild creature at tick 553 and lost, which ends the world
	# (outcome 2: no more ticks, so no ring snapshot 600 ticks old). The six-species roster of snapshot v7 makes that likely.
	sw.debug_now({"op": 6, "a": 1})
	sw.input_provider = func() -> Dictionary: return {"verb": 3, "hx": (int(sw.cur.tick) % 60) * 500 - 15000, "hz": 20000}
	for i in 1000:
		if i == 300:
			sw.debug_now({"op": 5, "a": 4000})
		sw.step_once()
	push_warning("feedback test marker")
	var dir := ProjectSettings.globalize_path("user://devtools-test/feedback/one")
	var err := Feedback.write(sw, {"tuning": {"active": "A"}, "island": {}}, "the creature jitters at the wall", dir, {"legend_context": "walk", "fps_avg": 60.0})
	t.eq(err, "", "write succeeds")
	for f in ["scenario.json", "scenario.cpstate", "replay.log", "replay.hashes", "replay_start.cpstate", "tuning.json", "meta.json", "log.txt"]:
		t.check(FileAccess.file_exists(dir.path_join(f)), "%s exists" % f)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("meta.json")))
	t.check(meta.note == "the creature jitters at the wall" and meta.tick == 1000 and meta.screenshot == null and meta.legend_context == "walk", "meta.json")
	t.check(int(meta.replay_from_tick) <= 400 and int(meta.replay_from_tick) % 100 == 0, "the replay starts >= 600 ticks back from a ring snapshot (tick %s)" % meta.replay_from_tick)
	var r: Dictionary = t.exec(t.build_path("world_cli"), ["--replay", dir.path_join("replay.log")])
	t.eq(r.rc, 0, "world_cli replays the bundle")
	var got: PackedStringArray = str(r.out).strip_edges().split("\n")
	var want: PackedStringArray = FileAccess.get_file_as_string(dir.path_join("replay.hashes")).strip_edges().split("\n")
	t.check(got == want and got.size() == 1000 - int(meta.replay_from_tick), "world_cli output equals replay.hashes (%d lines)" % got.size())
	var w = CporeWorld.new()
	t.eq(w.restore(FileAccess.get_file_as_bytes(dir.path_join("scenario.cpstate"))), 0, "scenario.cpstate restores")
	t.eq(w.state().hash, meta.hash, "and equals the hash in meta.json")
	t.check(FileAccess.get_file_as_string(dir.path_join("log.txt")).contains("feedback test marker"), "log.txt carries recent engine messages")
	t.check(Feedback.output_dir("x").ends_with("/x"), "output_dir ends with the stamp")
	# a short session (no ring snapshot old enough) replays from reset
	var sw2 = StageWorld.new()
	sw2.reset(setup)
	for i in 120:
		sw2.step_once()
	var dir2 := ProjectSettings.globalize_path("user://devtools-test/feedback/two")
	t.eq(Feedback.write(sw2, {}, "short", dir2), "", "short session writes")
	var r2: Dictionary = t.exec(t.build_path("world_cli"), ["--replay", dir2.path_join("replay.log")])
	t.check(r2.rc == 0 and str(r2.out).strip_edges().split("\n").size() == 120, "a short session replays from reset")
	for d in [dir, dir2]:
		var da := DirAccess.open(d)
		for f in da.get_files():
			da.remove(f)
		DirAccess.remove_absolute(d)
