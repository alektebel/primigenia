extends RefCounted
# Step 6: time control on the StageWorld bridge (no island needed).

const StageWorld := preload("res://game/stage/stage_world.gd")
const TimeControl := preload("res://devtools/time_control.gd")

func _world() -> Node:
	var sw = StageWorld.new()
	sw.reset(CporeWorld.default_setup(42))
	sw.input_provider = func() -> Dictionary:
		var k: int = sw.log_inputs.size()   # driven by the tick index, not by time
		return {"verb": 3, "hx": (k % 50) * 600 - 15000, "hz": 20000, "sprint": 1 if k % 70 < 20 else 0}
	return sw

func run(t) -> void:
	var sw = _world()
	sw.timescale = 0.5
	var steps := 0
	for i in 8:
		steps += sw.advance(0.25)
	t.eq(steps, 10, "2 s of frames at x0.5 are 10 ticks")
	sw = _world()
	sw.paused = true
	t.eq(sw.advance(0.25), 0, "paused advances nothing")
	sw.step_ticks(3)
	t.eq(sw.hashes.size(), 3, "paused + 3 steps = 3 ticks")
	sw = _world()
	sw.timescale = 100.0
	t.eq(sw.advance(0.25), 60, "x100 is capped at 60 ticks per frame")
	t.check(sw.achieved_scale < 100.0 and sw.achieved_scale > 20.0, "achieved rate is reported (x%.0f)" % sw.achieved_scale)
	t.check(sw.acc < sw.DT, "the backlog beyond the cap is dropped")
	var tc = TimeControl.new()
	tc.bind(sw)
	t.check(tc.text().begins_with("x100 (x"), "chip shows the achieved rate: '%s'" % tc.text())
	sw.timescale = 0.25
	t.eq(tc.text(), "x0.25", "chip at x0.25")
	sw.paused = true
	t.check(tc.text().begins_with("PAUSED · tick"), "chip when paused")
	sw.paused = false
	tc.set_timescale(1.0)
	t.eq(tc.text(), "", "no chip at x1")
	tc.faster()
	t.eq(sw.timescale, 2.0, "] moves up the ladder")
	tc.slower()
	tc.slower()
	t.eq(sw.timescale, 0.5, "[ moves down")
	tc.free()
	# Same inputs by tick index give the same hashes at any timescale.
	var a = _world()
	var b = _world()
	b.timescale = 5.0
	while a.hashes.size() < 300:
		a.advance(0.1)
	while b.hashes.size() < 300:
		b.advance(0.1)
		if b.hashes.size() > 300:
			break
	var same := true
	for i in 300:
		same = same and a.hashes[i] == b.hashes[i]
	t.check(same, "300 ticks at x5 hash exactly like the x1 run")
