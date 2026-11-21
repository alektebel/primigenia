extends RefCounted
## Creature zoo (docs/godot/DEVTOOLS.md "Locomotion zoo"): the morphologies the zoo can run, as cpore.creature/4 genomes
## built from the bundled Merodeador (scaled, with another number of legs or a long neck). Nothing here is saved or
## shipped: they exist to see how bodies of very different size, leg count and proportions move.

const Profile := preload("res://game/stage/profile.gd")
const BASE := "res://game/data/merodeador.json"

# id -> {label, speed (profile.speed, m/s), note}
const INFO := {
	"mite": {"label": "mite (small biped)", "speed": 4.6},
	"trotter": {"label": "trotter (quadruped)", "speed": 4.4},
	"hero": {"label": "hero (Merodeador, 4 legs)", "speed": 4.0},
	"giant": {"label": "giant (heavy quadruped)", "speed": 3.4},
	"longneck": {"label": "longneck (long neck)", "speed": 4.0},
	"centipede": {"label": "centipede (8 legs)", "speed": 3.6},
	"hexapod": {"label": "hexapod (6 legs)", "speed": 3.8},
	# starter candidates (docs/evidence/godot/starter): files in game/data/starters, speed 4.0 = Game's profile.speed
	"start0": {"label": "start0 (today's hatchling)", "speed": 4.0, "file": "res://game/data/hatchling.json"},
	"startA": {"label": "startA (grazer-hunter)", "speed": 4.0, "file": "res://game/data/starters/a_grazer.json"},
	"startB": {"label": "startB (lean runner)", "speed": 4.0, "file": "res://game/data/starters/b_runner.json"},
	"startC": {"label": "startC (armoured sprawler)", "speed": 4.0, "file": "res://game/data/starters/c_sprawler.json"},
	"startD": {"label": "startD (knuckle-walker)", "speed": 4.0, "file": "res://game/data/starters/d_knuckle.json"},
}
const STARTER_SET := ["start0", "startA", "startB", "startC", "startD"]
const DEFAULT_SET := ["mite", "trotter", "giant", "longneck", "centipede", "hero"]

static func ids() -> Array:
	return INFO.keys()

static func has(id: String) -> bool:
	return INFO.has(id)

static func _is_leg(p: Dictionary) -> bool:
	return str(p.get("type", "")) in ["pata", "zanca", "pezuna"]

# Uniform scale of a genome (nodes and every part dimension), clamped to the genome limits.
static func scaled(g: Dictionary, s: float) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	for n in out.nodes:
		n.y = float(n.y) * s
		n.z = float(n.z) * s
		n.r = clampf(float(n.r) * s, 0.03, 3.0)
	for p in out.parts:
		if _is_leg(p):
			p.w = clampf(float(p.w) * s, 0.05, 0.8)
			for k in ["k", "f"]:
				p[k] = [float(p[k][0]) * s, float(p[k][1]) * s, float(p[k][2]) * s]
		else:
			p.size = clampf(float(p.get("size", 1.0)) * s, 0.1, 4.0)
			if p.has("len"):
				p.len = clampf(float(p.len) * s, 0.1, 5.0)
	return out

static func _legs(g: Dictionary) -> Array:
	return g.parts.filter(func(p): return _is_leg(p))

static func _others(g: Dictionary) -> Array:
	return g.parts.filter(func(p): return not _is_leg(p))

# Genome with `pairs` leg pairs spread along the body from t0 to t1 (each pata part is a mirrored pair).
static func _with_legs(g: Dictionary, pairs: int, t0: float, t1: float, leg_len: float = 1.0) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	var proto: Dictionary = _legs(g)[0].duplicate(true)
	var parts: Array = _others(g)
	for i in pairs:
		var p: Dictionary = proto.duplicate(true)
		p.t = t0 if pairs == 1 else lerpf(t0, t1, float(i) / float(pairs - 1))
		for k in ["k", "f"]:
			p[k] = [float(p[k][0]), float(p[k][1]) * leg_len, float(p[k][2])]
		parts.append(p)
	out.parts = parts
	return out

static func genome(id: String) -> Dictionary:
	if INFO.has(id) and INFO[id].has("file"):
		var gs: Dictionary = Profile.load_json(INFO[id].file)
		gs.name = INFO[id].label
		return gs
	var base: Dictionary = Profile.load_json(BASE)
	var g: Dictionary
	match id:
		"hero":
			g = base
		"giant":
			g = scaled(base, 1.33)
		"trotter":
			g = scaled(base, 0.5)
		"mite":
			g = _with_legs(scaled(base, 0.2), 1, 0.5, 0.5)
		"hexapod":
			g = _with_legs(scaled(base, 0.42), 3, 0.3, 0.7, 0.9)
		"centipede":
			g = _with_legs(scaled(base, 0.45), 4, 0.25, 0.72, 0.65)
		"longneck":
			g = scaled(base, 0.6)
			var keep: Array = g.nodes.slice(0, 5)
			keep.append_array([{"y": 1.6, "z": 0.7, "r": 0.3}, {"y": 2.2, "z": 1.0, "r": 0.22}, {"y": 2.9, "z": 1.2, "r": 0.2},
				{"y": 3.6, "z": 1.35, "r": 0.18}, {"y": 3.9, "z": 1.7, "r": 0.2}])
			g.nodes = keep
			g = _with_legs(g, 2, 0.3, 0.55, 1.25)
		_:
			return {}
	g.name = INFO[id].label
	return g

# The combat profile (levels, radius_cm) and leg count a zoo creature gets in the C world.
static func profile(id: String, manifest: Dictionary) -> Dictionary:
	var g := genome(id)
	var pr := Profile.from_studio(g, manifest)
	var p: Dictionary = pr.profile if pr.ok else {}
	p["speed"] = float(INFO[id].speed)
	return p

static func leg_count(g: Dictionary) -> int:
	return clampi(_legs(g).size() * 2, 1, 8)
