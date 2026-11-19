class_name CreatureRadial
extends RefCounted
## Radial body plan (A24, docs/godot/CREATURE-RADIAL.md): the mesh, skeleton and parts of a creature whose genome has
## plan.sym == "radial". `Creature.build()` branches here once; the bilateral path is untouched.
##
## Frame: +Y up, bearing `ang` is measured from +Z towards +X: dir(ang) = (sin ang, 0, cos ang). Arm 0 points to +Z.
## The body is a lathe of the axial profile (genome nodes, oral pole first) with `fold * 12` vertices per ring, lobed
## towards the arms, plus `fold` swept arms, all in ONE skinned surface (material skin_body). Skeleton: `disc` root,
## `axis_0..2` (oral, middle, aboral) and `arm{k}_0..5` chained from the root.

const NSP := Creature.NSP
const NC := Creature.NC
const NS := Creature.NS
const ARM_RINGS := 18
const ARM_CAP := 3
const ARM_RN := 12
const ARM_BONES := 6
const Y := Vector3(0, 1, 0)

var c: Creature
var plan: Dictionary
var arm: Dictionary
var fold := 5
var star := 0.3
var gel := 0.0
var rn := 60
var max_r := .3
var i_max := NC
var y_floor := 0.0           ## lowest point of the oral surface (body space, before ground_offset)
var arm_len := 0.0           ## metres of one arm beyond the disc margin
var arm_base_r := 0.0
var disc_half := .1          ## half thickness of the disc at the arm roots
var tip_radius := 0.0

var disc_bone := 0
var axis_bones := PackedInt32Array()
var arm_bones: Array = []    ## Array of PackedInt32Array, 6 bones per arm, base first
var arm_geo_range: Array = []


static func dir_of(ang: float) -> Vector3:
	return Vector3(sin(ang), 0, cos(ang))


func _init(creature: Creature) -> void:
	c = creature


# ================================================================ build

func build(p: Dictionary) -> void:
	plan = p
	arm = p["arm"]
	fold = int(p["fold"])
	star = float(p["star"])
	gel = float(p["gel"])
	rn = fold * 12
	_profile()
	c.bio = CreatureBio.derive(c.genome, c.maker.is_leg, c.maker.lib["entries"])
	_adjust_bio()
	if gel > 0.0:
		c.materials.use_gel(gel)
	c.materials.configure(c.bio, c.genome["skin"])
	var body := CreatureGeo.new()
	_disc(body)
	var weights := _disc_weights()
	var arm_data: Array = []
	for k in fold:
		arm_data.append(_arm_geo(k, body))
	c.ground_offset = .02 - y_floor
	c.stride_hint = maxf(.25, arm_len * .8)
	c.body_root = Node3D.new()
	c.body_root.name = "BodyRoot"
	c.body_root.position.y = c.ground_offset
	c.add_child(c.body_root)
	c.limbs = Node3D.new()
	c.limbs.name = "Limbs"
	c.add_child(c.limbs)
	_skeleton(body, weights)
	_parts()
	_eyespots()
	c._compute_stats()
	_stats()
	CreatureParts.finalize(c)


## Radial bodies are boneless/hydrostatic skeletons whose arms are the limbs (A24). The body shader stays calm unless
## the body is a gel (a bell pulses); plan.arm.act overrides the derived arm actuation.
func _adjust_bio() -> void:
	var act: String = arm["act"]
	if act == "":
		act = "hydrostat" if float(arm["droop"]) >= .5 else ("cilia" if float(arm["frill"]) >= .5 and arm["tip"] == "frill" and float(arm["len"]) < 1.5 else "tubefeet")
	c.bio["arm"] = {"count": fold, "act": act, "mode": CreatureBio.ACT_MODE[act]}
	c.bio["arms"] = fold
	c.bio["legs"] = 0
	c.bio["actuation"] = "hydrostatic" if (gel > 0.0 or act in ["cilia", "hydrostat"]) else "muscle"
	c.bio["body_r"] = max_r
	c.materials.tube_feet = act == "tubefeet"


# ================================================================ profile

func _profile() -> void:
	var nodes: Array = c.genome["nodes"]
	var cpts := []
	for n in nodes:
		cpts.append(Vector3(n["r"], n["y"], 0))
	c.rest = []
	c.rest.resize(NS)
	c.rad = PackedFloat32Array()
	c.rad.resize(NS)
	for i in Creature.NSP:
		var p := CreatureGeo.catmull_point(cpts, float(i) / (NSP - 1), false, "catmullrom", .5)
		c.rad[NC + i] = maxf(.03, p.x)
		c.rest[NC + i] = Vector3(0, p.y, 0)
	# Caps: the oral face is nearly flat (concave for a bell), the aboral one a dome.
	var oral_h := -.55 if gel > 0.0 else .14
	for ad in [[NC, -1, oral_h], [NC + NSP - 1, 1, 1.0]]:
		var a: int = ad[0]
		var d: int = ad[1]
		var r0: float = c.rad[a]
		for k in range(1, NC + 1):
			var ph := float(k) / NC * PI / 2
			var h := r0 * float(ad[2])
			c.rest[a + d * k] = c.rest[a] + Y * (float(d) * h * sin(ph) if d > 0 else -h * sin(ph))
			c.rad[a + d * k] = maxf(.004, r0 * cos(ph))
	max_r = 0.0
	i_max = NC
	for i in NS:
		if c.rad[i] > max_r:
			max_r = c.rad[i]
			i_max = i
	y_floor = 1e9
	for i in NS:
		y_floor = minf(y_floor, c.rest[i].y)
	c.frames = []
	c.frames.resize(NS)
	for i in NS:
		var a2: Vector3 = c.rest[maxi(i - 1, 0)]
		var b2: Vector3 = c.rest[mini(i + 1, NS - 1)]
		var dist := a2.distance_to(b2)
		var dr := clampf((float(c.rad[mini(i + 1, NS - 1)]) - float(c.rad[maxi(i - 1, 0)])) / (dist if dist > 0.0 else 1.0), -4, 4)
		c.frames[i] = {"s": Vector3(1, 0, 0), "u": Vector3(0, 0, 1), "t": Y, "dr": dr}
	var y_top := y_floor
	for i in range(i_max, NS):
		if c.rad[i] >= .75 * max_r:
			y_top = maxf(y_top, c.rest[i].y)
	disc_half = maxf(.02, (y_top - y_floor) * .5)
	arm_len = float(arm["len"]) * max_r
	arm_base_r = float(arm["w"]) * max_r


## Lobing factor at ring radius r and bearing ang: 1 on the axis, up to 1 + star at the arm bearings of the margin.
func lobe(r: float, ang: float) -> float:
	if star <= 0.0:
		return 1.0
	var w := pow(clampf(r / max_r, 0.0, 1.0), 4.0)
	var q := (1.0 + cos(fold * ang)) * .5
	return 1.0 + star * w * q * q * q


## Same contract as Creature.anchor(): {p, n, t, u} in body space; `u` is the horizontal outward direction.
func anchor(t: float, ang: float) -> Dictionary:
	var f := clampf(t, 0, 1) * (NS - 1)
	var i: int = mini(int(f), NS - 2)
	var k := f - i
	var d := dir_of(ang)
	if t <= .04 or t >= .96:
		var pole := 0 if t <= .04 else NS - 1
		var pn := -Y if t <= .04 else Y
		return {"p": c.rest[pole], "n": pn, "t": Y, "u": d}
	var r := lerpf(c.rad[i], c.rad[i + 1], k)
	r *= lerpf(lobe(c.rad[i], ang), lobe(c.rad[i + 1], ang), k)
	var fr: Dictionary = c.frames[int(round(f))]
	var p: Vector3 = (c.rest[i] as Vector3).lerp(c.rest[i + 1], k) + d * r
	var n := (d - Y * float(fr["dr"])).normalized()
	return {"p": p, "n": n, "t": Y, "u": d}


# ================================================================ disc mesh

func _disc(g: CreatureGeo) -> void:
	g.pos.resize(NS * rn)
	g.nrm.resize(NS * rn)
	g.uv.resize(NS * rn)
	g.uv2.resize(NS * rn)
	var arc := 0.0
	var sector := TAU / fold
	for i in NS:
		if i > 0:
			arc += (c.rest[i] as Vector3).distance_to(c.rest[i - 1])
		for j in rn:
			var ang := float(j) / rn * TAU
			var r: float = c.rad[i] * lobe(c.rad[i], ang)
			var k := i * rn + j
			g.pos[k] = c.rest[i] + dir_of(ang) * r
			var phi := absf(fposmod(ang + sector * .5, sector) - sector * .5)   # D_fold mirror: pattern symmetric
			g.uv[k] = Vector2(arc, phi * c.rad[i])
			g.uv2[k] = Vector2(c.rad[i], float(i) / (NS - 1))
	for i in NS - 1:
		for j in rn:
			var a := i * rn + j
			var b := i * rn + (j + 1) % rn
			var cc := a + rn
			var d := b + rn
			g.idx.append_array([a, b, cc, b, d, cc])
	g.compute_vertex_normals()


## Bone weights of every disc vertex: [axis a, axis b, arm k base, none].
func _disc_weights() -> Array:
	var out := []
	var sector := TAU / fold
	for i in NS:
		var f := float(i) / (NS - 1) * 2.0
		var a := 0 if f < 1.0 else 1
		var t := f - a if f < 1.0 else f - 1.0
		var wr := pow(clampf(float(c.rad[i]) / max_r, 0.0, 1.0), 4.0)
		for j in rn:
			var ang := float(j) / rn * TAU
			var k := int(round(ang / sector)) % fold
			var q := (1.0 + cos(fold * ang)) * .5
			var wa := .35 * wr * q * q * q
			out.append({"axis": a, "t": t, "arm": k, "wa": wa})
	return out


# ================================================================ arms

## Vertical half-height of an arm at u: as thick as the disc at its base, tapering slower than the width (a starfish
## arm is a tall ridge at the disc, a round tube at the tip); round tubes for hanging oral arms.
func _rv(u: float) -> float:
	var w := _arm_w(u)
	if float(arm["droop"]) > .5:
		return w * .85
	var w0 := maxf(_arm_w(0.0), .001)
	return minf(disc_half * pow(w / w0, .6), w * .85)


## Half-width of arm `k` at u (0 base .. 1 tip) and its vertical half-height.
func _arm_w(u: float) -> float:
	var w := arm_base_r * pow(maxf(1.0 - float(arm["taper"]) * u, .02), .85)
	if arm["tip"] == "bulb":
		w *= 1.0 + .45 * smoothstep(.72, .95, u)
	return maxf(w, .006)


func _arm_point(k: int, u: float) -> Vector3:
	var ang := TAU * k / fold
	var d := dir_of(ang)
	var droop := float(arm["droop"])
	var r_in := max_r * (.75 - .5 * droop)
	var horiz := u * arm_len * (1.0 - .8 * droop)
	var rv := _rv(u)
	var lift := float(arm["curl"]) * .25 * arm_len * u * u - droop * arm_len * u
	var y := y_floor + rv + lift
	var p := d * (r_in + horiz) + Y * y
	if droop > .5:          # oral arms of a bell wave a little in the current, each at its own phase
		p += Vector3(d.z, 0, -d.x) * sin(u * 4.2 + float(k) * 1.9) * .07 * arm_len * u * droop
	return p


## Appends the swept tube of arm k to `g` (skinned weights are returned in the parallel arrays `arm_skin`).
func _arm_geo(k: int, g: CreatureGeo) -> Dictionary:
	var base := g.pos.size()
	var rings := ARM_RINGS + ARM_CAP
	var frill := float(arm["frill"])
	var ripple_phase := float(k) * .7
	var arc := 0.0
	var prev := Vector3.ZERO
	var info := {"first": base, "count": rings * ARM_RN}
	for ri in rings:
		var u := minf(float(ri) / (ARM_RINGS - 1), 1.0)
		var p := _arm_point(k, u)
		var tg := (_arm_point(k, minf(u + .02, 1.0)) - _arm_point(k, maxf(u - .02, 0.0))).normalized()
		var w := _arm_w(u)
		var cap := 1.0
		if ri >= ARM_RINGS:
			var ph := float(ri - ARM_RINGS + 1) / ARM_CAP * PI / 2
			p += tg * w * .9 * sin(ph)
			cap = cos(ph)
			u = 1.0
		if ri > 0:
			arc += p.distance_to(prev)
		prev = p
		var side := Y.cross(tg).normalized()
		var up := tg.cross(side).normalized()
		var rv := _rv(u)
		for j in ARM_RN:
			var psi := float(j) / ARM_RN * TAU
			var cs := sin(psi)            # side component (0 at the dorsal midline)
			var cu := cos(psi)            # up component
			var rip := 1.0
			if frill > 0.0:
				var fa := frill * (.12 if arm["tip"] != "frill" else .12 + .3 * smoothstep(.55, 1.0, u))
				rip = 1.0 + fa * sin(u * 15.0 + ripple_phase + psi * 2.0) * (cs * cs)
			var wy := 1.0 if cu >= 0.0 else .85                         # flat underside, round back
			var pos := p + side * cs * w * cap * rip + up * cu * rv * cap * wy
			g.pos.append(pos)
			g.nrm.append(Vector3.UP)
			var sym := acos(clampf(cu, -1.0, 1.0))
			g.uv.append(Vector2(arc + 10.0, sym * w))   # x > 5 marks an arm vertex for the shader (tube-feet rows)
			g.uv2.append(Vector2(w, u))
	# rings are ordered base -> tip with j counter-clockwise around the arm; indices as for the disc
	for ri in rings - 1:
		for j in ARM_RN:
			var a := base + ri * ARM_RN + j
			var b := base + ri * ARM_RN + (j + 1) % ARM_RN
			var cc := a + ARM_RN
			var d := b + ARM_RN
			g.idx.append_array([a, cc, b, b, cc, d])
	return info


# ================================================================ skeleton

func _bone_basis(k: int) -> Basis:
	var d := dir_of(TAU * k / fold)
	var side := Y.cross(d).normalized()
	return Basis(side, Y, d)


func _skeleton(g: CreatureGeo, dw: Array) -> void:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	c.body_root.add_child(sk)
	c.skeleton = sk
	var y_mid: float = (c.rest[i_max] as Vector3).y
	var globals: Array = []
	var parents: Array = []
	var names: Array = []
	var rings: Array = []
	# 0 disc
	names.append("disc"); parents.append(-1); globals.append(Transform3D(Basis(), Vector3(0, y_mid, 0))); rings.append(-1000)
	for a in 3:
		var ring: int = [0, (NS - 1) / 2, NS - 1][a]
		names.append("axis_%d" % a); parents.append(0); globals.append(Transform3D(Basis(), c.rest[ring])); rings.append(ring)
		axis_bones.append(names.size() - 1)
	arm_bones = []
	for k in fold:
		var chain := PackedInt32Array()
		var bs := _bone_basis(k)
		for b in ARM_BONES:
			var u := float(b) / (ARM_BONES - 1)
			chain.append(names.size())
			names.append("arm%d_%d" % [k, b])
			parents.append(0 if b == 0 else names.size() - 2)
			globals.append(Transform3D(bs, _arm_point(k, u)))
			rings.append(-1000)
		arm_bones.append(chain)
	for i in names.size():
		sk.add_bone(names[i])
		c.bone_ring.append(rings[i])
	for i in names.size():
		var par: int = parents[i]
		sk.set_bone_parent(i, par)
		var local: Transform3D = globals[i] if par < 0 else (globals[par] as Transform3D).affine_inverse() * globals[i]
		sk.set_bone_rest(i, local)
		sk.set_bone_pose(i, local)
	disc_bone = 0
	c.root_bone = 0
	c.head_bone = arm_bones[0][ARM_BONES - 1] if fold > 0 else 0
	c.spine_bones = PackedInt32Array(axis_bones)
	c.torso_bones = PackedInt32Array(axis_bones)
	# Skin: disc vertices (axis blend + a lift of the arm sector), arm rings between consecutive arm bones.
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for k in NS * rn:
		var d: Dictionary = dw[k]
		var a: int = d["axis"]
		var t: float = d["t"]
		var wa: float = d["wa"]
		var ab: int = arm_bones[d["arm"]][0]
		bones.append_array([axis_bones[a], axis_bones[a + 1], ab, 0])
		weights.append_array([(1.0 - t) * (1.0 - wa), t * (1.0 - wa), wa, 0.0])
	var rings_per := ARM_RINGS + ARM_CAP
	for k in fold:
		for ri in rings_per:
			var u := minf(float(ri) / (ARM_RINGS - 1), 1.0)
			var f := u * (ARM_BONES - 1)
			var b0 := mini(int(f), ARM_BONES - 2)
			var t := f - b0
			for j in ARM_RN:
				bones.append_array([arm_bones[k][b0], arm_bones[k][b0 + 1], 0, 0])
				weights.append_array([1.0 - t, t, 0.0, 0.0])
	# Per-vertex skin data for the shader: pattern coordinate = position, w = oral (-1) .. aboral (+1).
	g.compute_vertex_normals()
	g.skin.resize(g.pos.size() * 4)
	for i in g.pos.size():
		g.skin[i * 4] = g.pos[i].x
		g.skin[i * 4 + 1] = g.pos[i].y
		g.skin[i * 4 + 2] = g.pos[i].z
		g.skin[i * 4 + 3] = clampf(g.nrm[i].y * 1.25, -1.0, 1.0)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g.to_arrays(bones, weights), [], {}, CreatureGeo.SURFACE_FLAGS)
	c.body_mesh = MeshInstance3D.new()
	c.body_mesh.name = "Body"
	c.body_mesh.mesh = mesh
	c.body_mesh.material_override = c.materials.skin_body
	sk.add_child(c.body_mesh)
	c.body_mesh.skeleton = NodePath("..")
	c.body_mesh.skin = sk.create_skin_from_rest_transforms()
	c.body_mesh.set_meta("material_region", "skin")


# ================================================================ parts

func _parts() -> void:
	var nodes: Array = c.genome["nodes"]
	var plist: Array = c.genome["parts"]
	for pi in plist.size():
		var p: Dictionary = plist[pi]
		var m: Dictionary = c.maker.meta(p["type"])
		var t := float(p["t"])
		var axial := t <= .04 or t >= .96
		var copies := 1 if (axial or int(p.get("single", 0)) != 0) else fold
		for k in copies:
			var ang := float(p["ang"]) + TAU * k / fold
			var A := anchor(t, ang)
			var ctx := {"head": float(nodes[-1]["r"]), "body": max_r, "height": (A["p"] as Vector3).y + c.ground_offset,
				"mouthHeight": float(nodes[-1]["y"]) + c.ground_offset}
			var g := c.maker.make(p, A["p"], c.mount_radius(t), ctx)
			g.name = "%s_%d_r%d" % [p["type"], pi, k]
			var sink := .015
			var xf := c.orient(A, sink, float(p.get("rot", 0.0)), float(p.get("tilt", 0.0)))
			g.transform = xf
			var bone := c._attach(g, t)
			c.parts.append({"index": pi, "type": p["type"], "category": m.get("category", ""), "side": 1, "replica": k, "node": g,
				"t": t, "ang": ang, "size": float(p.get("size", 1.0)), "bone": bone, "mount": "radial",
				"mount_radius": c.mount_radius(t), "hooks": c._hooks(g)})


## Optic cushions (plan.arm.eye): a small tinted bulge with a dark pupil on top of each arm tip.
func _eyespots() -> void:
	if int(arm["eye"]) != 1:
		return
	var mat := CreatureMaterials.phys("#c47a2c", .45, .4)
	var dark := CreatureMaterials.phys("#120c08", .2, 1.0)
	for k in fold:
		var u := 1.0
		var tip := _arm_point(k, u)
		var w := _arm_w(u)
		var root := Node3D.new()
		root.name = "eyespot_%d" % k
		var cushion := MeshInstance3D.new()
		cushion.mesh = CreatureGeo.sphere(w * .7, 12, 8).to_mesh()
		cushion.material_override = mat
		cushion.scale = Vector3(1, .6, 1)
		root.add_child(cushion)
		var pupil := MeshInstance3D.new()
		pupil.mesh = CreatureGeo.sphere(w * .22, 8, 6).to_mesh()
		pupil.material_override = dark
		pupil.position = Vector3(0, w * .28, w * .2)
		root.add_child(pupil)
		root.transform = Transform3D(Basis(), tip + Y * _rv(u) * .55 - dir_of(TAU * k / fold) * w * .8)
		var bone: int = arm_bones[k][ARM_BONES - 1]
		var att := c._attachment(bone)
		root.transform = c.skeleton.get_bone_global_rest(bone).affine_inverse() * root.transform
		att.add_child(root)


func _stats() -> void:
	var warn: Array = c.stats["warn"].duplicate()
	warn.erase("Sin patas se arrastra")
	if float(arm["len"]) < .5:
		warn.append("Sin brazos se arrastra")
	c.stats["warn"] = warn
	c.stats["speed"] = 1.0 + float(arm["len"]) * .2


## Volume of the arms as frusta (S2 mass data).
func arm_data() -> Array:
	var out := []
	for k in fold:
		var tip := _arm_point(k, 1.0)
		out.append({"base": _arm_point(k, 0.0), "dir": dir_of(TAU * k / fold), "length": (tip - _arm_point(k, 0.0)).length(),
			"radius": arm_base_r})
	return out


func arm_volume() -> float:
	var v := 0.0
	for k in fold:
		var prev := _arm_point(k, 0.0)
		for s in range(1, 9):
			var u := float(s) / 8.0
			var p := _arm_point(k, u)
			var w := _arm_w(u)
			v += w * _rv(u) * prev.distance_to(p) * 3.14
			prev = p
	return v
