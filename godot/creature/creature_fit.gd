class_name CreatureFit
extends RefCounted
## Part-fit measurement (docs/briefs/creature-fit.md): how well every attached part sits on the body.
## Visual only, rest pose, body space (the BodyRoot / Skeleton frame). Per part:
##   gap     smallest signed distance from any part vertex to the body surface (>0 floating, <0 sunk)
##   reach   largest signed distance (how far the part sticks out)
##   floating  gap above the tolerance (nothing of the part touches the skin)
## Teeth: base point inside the mouth volume (the skin ellipsoids of the mouth part), normalised radius <= 1.
## Eyes: how deep the eyeball centre sits under the skin, as a fraction of the eyeball radius.
## Limbs: how far the hip / shoulder mass sticks out of the body relative to the limb width.
## Horns and spikes: base radius and length relative to the head.

const EYE_SINK_MIN := 0.12   ## eyeball centre at least this fraction of its radius below the skin
const EYE_SINK_MAX := 0.75   ## ... and not so deep that the eye is a dimple
const HIP_BULGE_MAX := 1.6   ## thickest part of the upper limb over its knee-end thickness (the root flare is allowed, a ball is not)


## Signed distance (m) of a body-space point to the body skin (negative inside). Uses the rest ring positions.
static func body_sdf(c: Creature, ring_pos: PackedVector3Array, p: Vector3) -> float:
	var best := 1e9
	var bi := 0
	var bk := 0.0
	for i in Creature.NS - 1:
		var a: Vector3 = c.rest[i]
		var ab: Vector3 = c.rest[i + 1] - a
		var l2 := ab.length_squared()
		var k := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-12 else 0.0
		var d := p.distance_squared_to(a + ab * k)
		if d < best:
			best = d
			bi = i
			bk = k
	var cc: Vector3 = (c.rest[bi] as Vector3).lerp(c.rest[bi + 1], bk)
	var tdir: Vector3 = ((c.rest[bi + 1] as Vector3) - c.rest[bi]).normalized()
	var v := p - cc
	var vperp := v - tdir * v.dot(tdir)
	var d := vperp.length()
	var ring := bi + (1 if bk > .5 else 0)
	var rc: Vector3 = c.rest[ring]
	if d < 1e-5:
		var rmin := 1e9
		for j in Creature.RN:
			rmin = minf(rmin, (ring_pos[ring * Creature.RN + j] - rc).length())
		return -rmin
	var dir := vperp / d
	var r := 0.0
	var bestdot := -2.0
	for j in Creature.RN:
		var w: Vector3 = ring_pos[ring * Creature.RN + j] - rc
		w -= tdir * w.dot(tdir)
		var wl := w.length()
		if wl < 1e-6:
			continue
		var dt := w.dot(dir) / wl
		if dt > bestdot:
			bestdot = dt
			r = wl
	# Beyond the end caps the nearest point is on the cap, the radial test above is then slightly generous.
	return d - r


static func body_ring_positions(c: Creature) -> PackedVector3Array:
	var arr := c.body_mesh.mesh.surface_get_arrays(0)
	return arr[Mesh.ARRAY_VERTEX]


## Transform of `n` into body space (up to the Skeleton3D, or to the Creature for the limbs).
static func _body_xf(c: Creature, n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != c.skeleton and cur != c:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	if cur == c:
		xf = Transform3D(Basis(), Vector3(0, -c.ground_offset, 0)) * xf
	return xf


static func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and n.has_meta("geo"):
		out.append(n)
	for ch in n.get_children():
		_meshes(ch, out)


static func _verts(c: Creature, mi: MeshInstance3D) -> PackedVector3Array:
	var geo: CreatureGeo = mi.get_meta("geo")
	var xf := _body_xf(c, mi)
	var out := PackedVector3Array()
	out.resize(geo.pos.size())
	for i in geo.pos.size():
		out[i] = xf * geo.pos[i]
	return out


static func _vertex_stats(c: Creature, ring: PackedVector3Array, meshes: Array, only_skip_material: Array = []) -> Dictionary:
	var gap := 1e9
	var reach := -1e9
	var n := 0
	for mi in meshes:
		if mi.material_override in only_skip_material:
			continue
		var vs := _verts(c, mi)
		# Subsample big meshes: the extremes of a smooth part are found within a stride of 3.
		var step := 1 if vs.size() < 600 else 3
		var i := 0
		while i < vs.size():
			var s := body_sdf(c, ring, vs[i])
			gap = minf(gap, s)
			reach = maxf(reach, s)
			n += 1
			i += step
	return {"gap": gap, "reach": reach, "n": n}


## AABB ellipsoid test of a point against one mesh (its local frame). Returns the normalised radius.
static func _ellipsoid_r(c: Creature, mi: MeshInstance3D, p: Vector3) -> float:
	var geo: CreatureGeo = mi.get_meta("geo")
	var box := geo.aabb()
	var lp := _body_xf(c, mi).affine_inverse() * p
	var h := box.size * .5
	var q := lp - (box.position + h)
	return sqrt(pow(q.x / maxf(h.x, 1e-5), 2) + pow(q.y / maxf(h.y, 1e-5), 2) + pow(q.z / maxf(h.z, 1e-5), 2))


static func _tooth_base(c: Creature, mi: MeshInstance3D) -> Vector3:
	# Cone: apex at +Y of its frame, base at -Y. The base centre is the vertex centroid of the wider half.
	var geo: CreatureGeo = mi.get_meta("geo")
	var box := geo.aabb()
	var base := Vector3(box.position.x + box.size.x * .5, box.position.y, box.position.z + box.size.z * .5)
	return _body_xf(c, mi) * base


## Full measurement of one built creature. {parts:[...], eyes:[...], teeth:{...}, limbs:[...], horns:[...], summary:{...}}
static func measure(c: Creature) -> Dictionary:
	var ring := body_ring_positions(c)
	var mats := c.materials
	var head_r: float = float(c.genome["nodes"][-1]["r"])
	var out := {"parts": [], "eyes": [], "teeth": [], "limbs": [], "horns": [], "name": c.genome["name"]}
	for e in c.parts:
		var node: Node3D = e["node"]
		var meshes := []
		_meshes(node, meshes)
		if meshes.is_empty():
			continue
		var mr: float = float(e["mount_radius"])
		var st := _vertex_stats(c, ring, meshes)
		var tol := .02 + .03 * mr
		var rec := {"type": e["type"], "side": e["side"], "gap": st["gap"], "reach": st["reach"], "mount_r": mr,
			"floating": st["gap"] > tol, "buried": st["reach"] < .02 + .02 * mr, "tol": tol}
		out["parts"].append(rec)
		var cat: String = e["category"]
		# Teeth in the mouth volume.
		var skin_meshes := []
		var tooth_meshes := []
		for mi in meshes:
			if mi.material_override == mats.tooth:
				tooth_meshes.append(mi)
			elif mi.material_override == mats.skin or mi.material_override == mats.skin_body:
				skin_meshes.append(mi)
		for tm in tooth_meshes:
			var tb := _tooth_base(c, tm)
			var inside := 1e9
			for sm in skin_meshes:
				inside = minf(inside, _ellipsoid_r(c, sm, tb))
			out["teeth"].append({"type": e["type"], "r": inside, "ok": inside <= 1.0, "gap": body_sdf(c, ring, tb)})
		# Eyeball in its socket.
		for mi in meshes:
			if mi.material_override == mats.eye_white:
				var geo: CreatureGeo = mi.get_meta("geo")
				var box := geo.aabb()
				var er := box.size.x * .5
				var centre := _body_xf(c, mi) * (box.position + box.size * .5)
				var sink := -body_sdf(c, ring, centre) / maxf(er, 1e-5)
				var stalk := String(e["type"]) in ["tallo", "eye_triad", "eye_stalk"]
				out["eyes"].append({"type": e["type"], "sink": sink, "radius": er, "head_ratio": er / head_r, "stalk": stalk,
					"ok": stalk or (sink >= EYE_SINK_MIN and sink <= EYE_SINK_MAX)})
		# Horns, spines: base thickness and length vs the head.
		if String(e["type"]) in ["cuerno", "asta", "pua", "horn_crown"]:
			var box := AABB()
			var first := true
			for mi in meshes:
				var b := (_body_xf(c, mi) * (mi.get_meta("geo") as CreatureGeo).aabb())
				box = b if first else box.merge(b)
				first = false
			out["horns"].append({"type": e["type"], "t": e["t"], "length": box.get_longest_axis_size(), "head_r": head_r,
				"length_ratio": box.get_longest_axis_size() / head_r})
	# Limb roots: the thickest cross-section in the top 60% of the upper segment against the cross-section just above
	# the knee. A ball or thigh blob at the hip reads as a separate piece (ratio well above 1); a taper is near 1.
	for l in c.legs:
		var ms := []
		_meshes(l.upper, ms)
		var st := _vertex_stats(c, ring, ms)
		var bins := PackedFloat32Array()
		bins.resize(20)
		for mi in ms:
			for v in (mi.get_meta("geo") as CreatureGeo).pos:
				var u := clampf(-v.y / l.upper_length, 0.0, .999)
				var k := int(u * 20)
				bins[k] = maxf(bins[k], Vector2(v.x, v.z).length())
		var top := 0.0
		for k in 12:
			top = maxf(top, bins[k])
		var knee := bins[19]   # the lower ring of the tube sits exactly at the knee
		var bulge := top / maxf(knee, 1e-5)
		out["limbs"].append({"type": l.type, "side": l.side, "width": l.width, "gap": st["gap"],
			"emerge": bulge, "floating": st["gap"] > .02 + .1 * l.width,
			"ok": st["gap"] <= .02 + .1 * l.width and bulge <= HIP_BULGE_MAX})
	# Summary.
	var floating := 0
	for r in out["parts"]:
		if r["floating"]:
			floating += 1
	var bad_teeth := 0
	var worst_tooth := 0.0
	for t in out["teeth"]:
		if not t["ok"]:
			bad_teeth += 1
		worst_tooth = maxf(worst_tooth, t["r"])
	var bad_eyes := 0
	for e in out["eyes"]:
		if not e["ok"]:
			bad_eyes += 1
	var bad_limbs := 0
	var worst_emerge := 0.0
	for l in out["limbs"]:
		if not l["ok"]:
			bad_limbs += 1
		worst_emerge = maxf(worst_emerge, l["emerge"])
	var worst_horn := 0.0
	for h in out["horns"]:
		worst_horn = maxf(worst_horn, h["length_ratio"])
	out["summary"] = {"parts": out["parts"].size(), "floating": floating, "teeth": out["teeth"].size(), "teeth_out": bad_teeth,
		"worst_tooth_r": worst_tooth, "eyes": out["eyes"].size(), "eyes_bad": bad_eyes, "limbs": out["limbs"].size(),
		"limbs_bad": bad_limbs, "worst_emerge": worst_emerge, "worst_horn_ratio": worst_horn}
	return out


## Fixed-seed random valid genomes (not for the game: for the fit check and the look-dev of odd bodies).
static func random_genome(seed_: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var n := rng.randi_range(5, 8)
	var nodes := []
	var z := -rng.randf_range(1.5, 3.2)
	var y := rng.randf_range(.9, 2.2)
	var rmax := rng.randf_range(.35, .9)
	for i in n:
		var u := float(i) / (n - 1)
		var r := rmax * (.25 + .75 * sin(PI * clampf(u * .85 + .08, 0, 1))) * rng.randf_range(.85, 1.15)
		nodes.append({"y": y + rng.randf_range(-.1, .1) + (u - .6) * rng.randf_range(-.2, .9) * (1.0 if u > .6 else .0), "z": z, "r": clampf(r, .05, 1.2)})
		z += rng.randf_range(.5, .95) * (1.0 + rmax)
	nodes[-1]["r"] = clampf(float(nodes[-1]["r"]) * rng.randf_range(.8, 1.4), .15, 1.0)
	var parts := []
	var mouth: String = ["fauces", "romo", "pico", "trompa", "pinzas"][rng.randi() % 5]
	parts.append({"type": mouth, "t": 1, "ang": 0, "size": snappedf(rng.randf_range(.8, 1.3), .05)})
	for i in rng.randi_range(1, 2):
		parts.append({"type": ["ojo", "ojo", "tallo"][rng.randi() % 3], "t": snappedf(rng.randf_range(.82, .95), .01), "ang": snappedf(rng.randf_range(.6, 1.2), .05), "size": snappedf(rng.randf_range(.8, 1.4), .05), "len": snappedf(rng.randf_range(.5, .9), .05)})
	var extras := ["cuerno", "pua", "placa", "cresta", "antena", "oreja", "aguijon", "maza", "bulbo", "aleta", "asta", "frill_fan", "horn_crown", "shell_plate", "tail_spike", "tail_paddle", "arm_grasper", "wing_glider", "excavadora"]
	for i in rng.randi_range(2, 4):
		var ty: String = extras[rng.randi() % extras.size()]
		var p := {"type": ty, "t": snappedf(rng.randf_range(.15, .9), .01), "ang": snappedf(rng.randf_range(-1.5, 1.5), .05), "size": snappedf(rng.randf_range(.7, 1.3), .05)}
		if ty in ["cuerno", "asta", "pua", "antena"]:
			p["len"] = snappedf(rng.randf_range(.3, 1.1), .05)
		if ty == "cuerno":
			p["curve"] = snappedf(rng.randf_range(-.3, .8), .05)
		if ty in ["tail_spike", "tail_paddle", "excavadora"]:
			p["t"] = .08 if ty != "excavadora" else .6
			p["ang"] = 0
		if ty in ["wing_glider", "arm_grasper"]:
			p["t"] = snappedf(rng.randf_range(.5, .7), .01)
			p["ang"] = 1.3
		parts.append(p)
	var legs := rng.randi_range(1, 3)
	var lt: String = ["pata", "pata", "zanca", "pezuna"][rng.randi() % 4]
	for i in legs:
		var s := rng.randf_range(.7, 1.3)
		parts.append({"type": lt, "t": snappedf(.3 + .4 * (float(i) / maxf(legs - 1, 1)) + rng.randf_range(-.03, .03), .01), "ang": 2.1,
			"w": snappedf(rng.randf_range(.1, .3), .01), "k": [.28 * s, -.7 * s, .15], "f": [.38 * s, -1.4 * s, 0.0]})
	var skin := {"pat": rng.randi_range(0, 3), "cA": "#%02x%02x%02x" % [rng.randi_range(40, 220), rng.randi_range(40, 200), rng.randi_range(30, 180)],
		"cB": "#%02x%02x%02x" % [rng.randi_range(20, 120), rng.randi_range(20, 100), rng.randi_range(20, 100)],
		"cC": "#%02x%02x%02x" % [rng.randi_range(180, 250), rng.randi_range(170, 240), rng.randi_range(140, 220)],
		"wet": snappedf(rng.randf(), .05), "scale": rng.randi_range(4, 12)}
	return {"schema": "cpore.creature/4", "name": "Fit %d" % seed_, "nodes": nodes, "parts": parts, "skin": skin, "regions": []}
