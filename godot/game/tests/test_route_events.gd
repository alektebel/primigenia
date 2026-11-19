extends SceneTree
# C1: native state exposes route outcomes to the UI exactly once, independently of observe acknowledgement.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL " + message)
func _initialize() -> void:
	var world := CporeWorld.new()
	check(world.reset({"terrain": 1, "wild": []}) == 0, "reset flat world")
	check(world.command("go 10 0") == 0, "GO accepted")
	var arrived := 0
	for i in 200:
		world.step({})
		var state: Dictionary = world.state()
		for event in state.route_events:
			if event.type == "arrived":
				arrived += 1
				check(absf(event.x - 10.0) < 0.3 and absf(event.z) < 0.3, "arrival coordinates")
	check(arrived == 1, "one arrival reaches the UI")
	check(world.state().route_events.is_empty(), "state does not repeat outcomes")
	check(world.command("go 999 0") < 0, "bad GO rejected")
	world.ack_events()
	var blocked: Array = world.state().route_events
	check(blocked.size() == 1 and blocked[0].type == "blocked" and blocked[0].reason != "", "blocked reason survives agent acknowledgement")
	check(world.state().route_events.is_empty(), "blocked event delivered once")
	print("route UI events: %d failures" % failures)
	quit(1 if failures else 0)
