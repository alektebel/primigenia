class_name CreatureGrowth
extends RefCounted
## Deterministic surface-growth recipes (horns, plates, tendrils).
## Port of web/studio/growth.js: same mulberry32 stream, same tubes, so a
## recipe produces the same vertices (to float precision) as the web builder.
## Geometry is returned in three.js winding (counter-clockwise front faces);
## CreatureGeo converts it when it builds a Godot mesh.

const VERSION := "cpore.growth/1"
const FAMILIES := ["horns", "plates", "tendrils"]
const DEFAULTS := {"family": "horns", "seed": 17, "count": 7, "length": 1.0, "curve": 0.45, "branches": 1}
const RANGES := {"seed": [0, 4294967295], "count": [1, 18], "length": [0.2, 2.4], "curve": [-1, 1], "branches": [0, 3]}
const M32 := 0xFFFFFFFF


## Returns {ok, recipe, error}. Missing keys take DEFAULTS like growth.js.
static func validate(recipe: Dictionary) -> Dictionary:
	var r := DEFAULTS.duplicate()
	r.merge(recipe, true)
	if not (r["family"] in FAMILIES):
		return {"ok": false, "error": "growth: unknown family"}
	for key in RANGES:
		var v = r[key]
		if not ((typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))) or float(v) < RANGES[key][0] or float(v) > RANGES[key][1]:
			return {"ok": false, "error": "growth.%s: expected %s..%s" % [key, RANGES[key][0], RANGES[key][1]]}
	for key in ["seed", "count", "branches"]:
		if float(r[key]) != floor(float(r[key])):
			return {"ok": false, "error": "growth.%s: expected integer" % key}
	return {"ok": true, "recipe": r, "error": ""}


## Math.imul on unsigned 32-bit values, without overflowing 64-bit ints.
static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := (a * (b & 0xFFFF)) & M32
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & M32


## mulberry32 as in growth.js; state is a one-element Array so the caller's
## Callable can advance it.
static func _rand(state: Array) -> float:
	state[0] = (state[0] + 0x6D2B79F5) & M32
	var s: int = state[0]
	var t := imul(s ^ (s >> 15), 1 | s)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & M32) ^ t
	return float((t ^ (t >> 14)) & M32) / 4294967296.0


static func _tube(out: Dictionary, center: Callable, radius: Callable, segments: int, sides: int, flatten := 1.0) -> void:
	var pos: PackedVector3Array = out["positions"]
	var idx: PackedInt32Array = out["indices"]
	var base := pos.size()
	for i in segments + 1:
		var t := float(i) / segments
		var p: Vector3 = center.call(t)
		var tangent: Vector3 = _unit(center.call(min(1.0, t + 0.001)) - center.call(max(0.0, t - 0.001)))
		var side := _unit(tangent.cross(Vector3(1, 0, 0) if abs(tangent.z) > .95 else Vector3(0, 0, 1)))
		var up := _unit(side.cross(tangent))
		var r: float = radius.call(t)
		for j in sides:
			var a := float(j) / sides * PI * 2
			pos.append(p + r * (side * cos(a) + up * sin(a) * flatten))
	for i in segments:
		for j in sides:
			var a := base + i * sides + j
			var b := base + i * sides + (j + 1) % sides
			var c := a + sides
			var d := b + sides
			idx.append_array([a, c, b, b, c, d])
	for end in [0, 1]:
		var c := pos.size()
		pos.append(center.call(float(end)))
		for j in sides:
			var a: int = base + end * segments * sides + j
			var b: int = base + end * segments * sides + (j + 1) % sides
			if end:
				idx.append_array([c, b, a])
			else:
				idx.append_array([c, a, b])
	out["positions"] = pos
	out["indices"] = idx


static func _unit(a: Vector3) -> Vector3:
	var n := a.length()
	if n == 0.0:
		n = 1.0
	return a / n


static func _finish(out: Dictionary) -> Dictionary:
	var pos: PackedVector3Array = out["positions"]
	var idx: PackedInt32Array = out["indices"]
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var n := (pos[b] - pos[a]).cross(pos[c] - pos[a])
		nrm[a] += n
		nrm[b] += n
		nrm[c] += n
	for i in nrm.size():
		nrm[i] = _unit(nrm[i])
	return {"positions": pos, "normals": nrm, "indices": idx}


## {ok, version, recipe, pieces:[{positions, normals, indices, rootRadius, offset}]}
static func generate(input: Dictionary) -> Dictionary:
	var v := validate(input)
	if not v["ok"]:
		return {"ok": false, "error": v["error"]}
	var recipe: Dictionary = v["recipe"]
	var count := int(recipe["count"])
	var length_r := float(recipe["length"])
	var curve := float(recipe["curve"])
	var family: String = recipe["family"]
	var pieces: Array = []
	for i in count:
		# Each index has its own seed: adding density does not reroll earlier shapes.
		var state := [(int(recipe["seed"]) ^ imul(i + 1, 0x9E3779B1)) & M32]
		var out := {"positions": PackedVector3Array(), "indices": PackedInt32Array()}
		var length := length_r * (.82 + _rand(state) * .36)
		var lean := (_rand(state) - .5) * .32
		var radius := length * (.3 if family == "plates" else (.06 if family == "tendrils" else .12))
		if family == "plates":
			_tube(out, func(t): return Vector3(lean * length * t * t, length * t, curve * length * t * t * .65),
				func(t): return radius * (.12 + sin(PI * pow(t, .72))) * (.99 - t * .9), 16, 12, .18)
		else:
			var tendril := family == "tendrils"
			var center: Callable
			if tendril:
				center = func(t): return Vector3(lean * length * t + sin(t * PI * 2) * curve * length * t * .25,
					length * (t - abs(curve) * t * t * .3),
					curve * length * (1 - cos(t * PI * 1.5)) * .36)
			else:
				center = func(t): return Vector3(lean * length * t * t, length * t, curve * length * t * t * .75)
			var profile := func(t): return max(.003, radius * pow(1 - t, .85) * (1 + .06 * sin(t * 72)))
			_tube(out, center, profile, 28 if tendril else 16, 10)
			for b in int(recipe["branches"]):
				var t := .3 + b * .17
				var start: Vector3 = center.call(t)
				var side := -1.0 if b % 2 else 1.0
				var reach := length * (.25 + _rand(state) * .22)
				var bend := curve * .5
				var pt: float = profile.call(t)
				_tube(out, func(u): return Vector3(start.x + side * reach * u * .7, start.y + reach * (u - u * u * .28), start.z + reach * (bend * u * u + .12 * u)),
					func(u): return max(.003, pt * .62 * pow(1 - u, .8)), 10, 8)
		var piece := _finish(out)
		piece["rootRadius"] = radius * .12 if family == "plates" else radius
		piece["offset"] = 0.0 if count == 1 else float(i) / (count - 1) - .5
		pieces.append(piece)
	return {"ok": true, "version": VERSION, "recipe": recipe, "pieces": pieces}
