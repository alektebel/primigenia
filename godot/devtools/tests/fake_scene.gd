extends Node
# Stand-in for the island in note tests: just what the notes read (scenario_ctx, camera_state).
func camera_state() -> Dictionary:
	return {"yaw": 1.5, "pitch": 0.2, "distance": 6.0}

func scenario_ctx() -> Dictionary:
	return {"genome": {"name": "Test body", "parts": [{"type": "pico"}]}, "island": {}, "camera": camera_state(), "plants": [], "quest": {}}
