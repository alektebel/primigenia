extends RefCounted
## Writes the action layer's part values into the real rig's hook nodes (docs/godot/PLAN-actions.md 1.4.5,
## constants from web/creature/rig.js lines 469-475). Stateless: every hook is written every frame.

const GAPE := {"pico": 0.7, "romo": 0.6}

## act: {parts: {jaw, tremble, lids, sacs, display, arms, inflate, time}, ...}
static func apply_parts(c, act: Dictionary) -> void:
	var p: Dictionary = act.parts
	var t: float = p.time
	var jaw_a: float = 0.06 + 0.75 * (float(p.jaw) + float(p.tremble))
	for e in c.parts:
		var h: Dictionary = e.hooks
		if h.is_empty():
			continue
		var side := float(e.side)
		if h.has("jaw") and h.jaw is Node3D:
			var gape: float = GAPE.get(str(e.type), 1.0)
			h.jaw.rotation.x = 0.06 + (jaw_a - 0.06) * gape
		if h.has("pinch"):
			for q in h.pinch:
				q.rotation.y = float(q.get_meta("sx", 1.0)) * (0.25 - jaw_a * 1.1)
		if h.has("lid"):
			h.lid.rotation.x = -0.3 + 1.5 * float(p.lids)
		if h.has("sway") and h.sway is Node3D and h.sway != h.get("jaw"):
			var disp := -1.0
			h.sway.rotation.x = sin(t * 2.2 + float(e.t) * 9.0) * 0.12 * (1.0 - float(p.still)) + disp * 0.5 * float(p.display)
		if h.has("wing"):
			var d: float = p.display
			h.wing.rotation.z = 0.12 + 0.8 * d
			h.wing.rotation.y = lerpf(0.32, 0.12, d)
		if h.has("sacs"):
			for sac in h.sacs:
				sac.scale = Vector3.ONE * (1.0 + 0.35 * float(p.sacs))
		if h.has("arm"):
			h.arm.rotation.x = 1.0 * float(p.arms)
	var s: float = p.inflate
	c.body_root.scale = Vector3.ONE * (1.0 + s)
	var com: Vector3 = act.get("com", Vector3.ZERO)
	c.body_root.position = Vector3(0, c.ground_offset, 0) - s * Vector3(0, com.y, com.z)

static func reset(c) -> void:
	apply_parts(c, {"parts": {"jaw": 0.0, "tremble": 0.0, "lids": 0.0, "sacs": 0.0, "display": 0.0, "arms": 0.0, "inflate": 0.0, "time": 0.0, "still": 1.0}})
