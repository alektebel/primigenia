extends RefCounted
## Test body plans, in the rest space the creature rig must provide
## (+Z forward, +Y up, +X left, ground y = 0, metres).

static func _spine(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append({"pos": Vector3(0.0, r[1], r[0]), "radius": r[2], "region": r[3]})
	return out

static func _pair(z: float, x: float, y: float, upper: float, lower: float, radius: float, foot: String, size: float, rest = null) -> Array:
	var out: Array = []
	for s in [1.0, -1.0]:
		var l := {"hip": Vector3(x * s, y, z), "upper": upper, "lower": lower, "radius": radius, "foot": foot, "foot_size": size}
		if rest != null:
			l["foot_rest"] = Vector3(rest.x * s, 0.0, rest.z)
		out.append(l)
	return out

static func names() -> Array:
	return ["biped", "horizontal_biped", "light_quadruped", "heavy_quadruped", "hexapod", "wader", "legless"]

static func get_body(name: String) -> Dictionary:
	match name:
		"biped":  # upright, human-like proportions
			return {"spine": _spine([[0.0, 0.92, 0.13, "trunk"], [0.01, 1.2, 0.15, "trunk"], [0.02, 1.45, 0.14, "trunk"],
					[0.03, 1.56, 0.06, "neck"], [0.05, 1.68, 0.1, "head"]]),
				"legs": _pair(0.0, 0.1, 0.9, 0.48, 0.46, 0.075, "paw", 0.08),
				"parts": [{"pos": Vector3(0.22, 1.2, 0.0), "mass": 4.0, "category": "arm"}, {"pos": Vector3(-0.22, 1.2, 0.0), "mass": 4.0, "category": "arm"}]}
		"horizontal_biped":  # theropod: horizontal trunk balanced by a long tail
			return {"spine": _spine([[-1.6, 0.9, 0.02, "tail"], [-0.8, 0.98, 0.1, "tail"], [-0.1, 1.02, 0.22, "trunk"],
					[0.45, 1.05, 0.24, "trunk"], [0.8, 1.15, 0.14, "neck"], [1.05, 1.4, 0.1, "neck"], [1.3, 1.45, 0.12, "head"]]),
				"legs": _pair(0.0, 0.2, 1.0, 0.55, 0.55, 0.1, "garra", 0.12), "parts": []}
		"light_quadruped":  # gazelle-sized cursor
			return {"spine": _spine([[-0.65, 0.5, 0.015, "tail"], [-0.35, 0.52, 0.07, "trunk"], [0.0, 0.53, 0.1, "trunk"],
					[0.3, 0.52, 0.1, "trunk"], [0.45, 0.62, 0.05, "neck"], [0.58, 0.72, 0.055, "head"]]),
				"legs": _pair(-0.3, 0.08, 0.48, 0.26, 0.27, 0.035, "pezuna", 0.05) + _pair(0.28, 0.08, 0.48, 0.26, 0.27, 0.035, "pezuna", 0.05),
				"parts": []}
		"heavy_quadruped":  # rhino-sized graviportal body
			return {"spine": _spine([[-1.9, 1.1, 0.03, "tail"], [-1.4, 1.25, 0.4, "trunk"], [-0.5, 1.3, 0.55, "trunk"],
					[0.4, 1.3, 0.55, "trunk"], [1.0, 1.25, 0.4, "trunk"], [1.4, 1.15, 0.3, "neck"], [1.9, 1.0, 0.22, "head"]]),
				"legs": _pair(-1.1, 0.4, 1.1, 0.58, 0.58, 0.16, "pad", 0.3) + _pair(0.7, 0.4, 1.1, 0.58, 0.58, 0.16, "pad", 0.3),
				"parts": [{"pos": Vector3(0.0, 1.2, 2.0), "mass": 25.0, "category": "horn"}]}
		"hexapod":  # sprawled beetle-like body, 0.7 m long
			return {"spine": _spine([[-0.35, 0.2, 0.08, "trunk"], [-0.1, 0.22, 0.12, "trunk"], [0.15, 0.22, 0.11, "trunk"], [0.32, 0.2, 0.07, "head"]]),
				"legs": _pair(-0.2, 0.1, 0.2, 0.2, 0.25, 0.02, "point", 0.03, Vector3(0.28, 0.0, -0.3))
					+ _pair(0.0, 0.1, 0.2, 0.2, 0.25, 0.02, "point", 0.03, Vector3(0.3, 0.0, 0.0))
					+ _pair(0.2, 0.1, 0.2, 0.2, 0.25, 0.02, "point", 0.03, Vector3(0.28, 0.0, 0.3)),
				"parts": []}
		"wader":  # tall, long-necked wading bird
			return {"spine": _spine([[-0.35, 1.0, 0.02, "tail"], [-0.15, 1.05, 0.1, "trunk"], [0.1, 1.1, 0.12, "trunk"],
					[0.25, 1.25, 0.035, "neck"], [0.3, 1.55, 0.03, "neck"], [0.4, 1.8, 0.03, "neck"], [0.52, 1.85, 0.045, "head"]]),
				"legs": _pair(0.0, 0.07, 1.0, 0.52, 0.56, 0.02, "dedos", 0.16), "parts": []}
		"legless":  # snake
			var rows: Array = []
			for i in range(9):
				var u := i / 8.0
				rows.append([-1.0 + 2.0 * u, 0.05, 0.05 * (0.4 + 0.6 * sin(PI * clamp(u * 0.9 + 0.1, 0.0, 1.0))), "tail" if u < 0.3 else ("head" if u > 0.95 else "trunk")])
			return {"spine": _spine(rows), "legs": [], "parts": []}
		"octopod":
			var legs: Array = []
			for k in range(4):
				var z := -0.3 + 0.2 * k
				legs += _pair(z, 0.1, 0.2, 0.22, 0.26, 0.02, "point", 0.03, Vector3(0.32, 0.0, z * 1.5))
			return {"spine": _spine([[-0.4, 0.2, 0.1, "trunk"], [0.0, 0.22, 0.14, "trunk"], [0.4, 0.2, 0.09, "head"]]), "legs": legs, "parts": []}
		"monopod":
			return {"spine": _spine([[0.0, 0.5, 0.12, "trunk"], [0.0, 0.8, 0.1, "head"]]),
				"legs": [{"hip": Vector3(0.0, 0.5, 0.0), "upper": 0.27, "lower": 0.27, "radius": 0.05, "foot": "spring", "foot_size": 0.1}], "parts": []}
		"tripod":
			return {"spine": _spine([[-0.3, 0.5, 0.1, "trunk"], [0.3, 0.5, 0.1, "head"]]),
				"legs": _pair(0.2, 0.1, 0.48, 0.27, 0.27, 0.04, "paw", 0.06) + [{"hip": Vector3(0.0, 0.48, -0.25), "upper": 0.27, "lower": 0.27, "radius": 0.04, "foot": "paw", "foot_size": 0.06}], "parts": []}
	return {}
