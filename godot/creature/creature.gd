class_name Creature
extends Node3D
## A creature built from a cpore.creature/4 genome (port of the anatomy in
## web/creature/rig.js). This node is the WORLD PLACEMENT: put its origin on
## the ground; the creature faces local +Z, +Y is up (same frame as rig.js).
##
## Node layout after build():
##   Creature (this)            world placement, origin on the ground
##   ├ BodyRoot                 y = ground_offset; bob/lean the body here
##   │  └ Skeleton3D            spine bones (tail -> head), skinned body tube
##   │     ├ Body               skinned MeshInstance3D
##   │     └ Bone_<name>        BoneAttachment3D carrying parts, growth, hips
##   └ Limbs                    leg segments (upper/lower/foot) per CreatureLegChain
##
## Public API: see docs/godot/CREATURE.md.

signal built

const NSP := 60          ## spine samples between the first and last node
const NC := 6            ## rounded end-cap rings at each end
const NS := NSP + 2 * NC ## rings along the body (72)
const RN := 22           ## vertices per ring
const BONE_STRIDE := 4   ## rings per spine bone
const X0 := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const ZA := Vector3(0, 0, 1)

@export var asset_dir := CreatureParts.DEFAULT_ASSET_DIR

var genome: Dictionary = {}
var warnings: Array = []
var bio: Dictionary = {}              ## CreatureBio.derive: actuation, toxic, diet, seed, graded palette
var materials: CreatureMaterials
var maker: CreatureParts

var body_root: Node3D
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var limbs: Node3D

## Spine rest data (body space = BodyRoot/Skeleton space).
var rest: Array = []                   ## NS Vector3 ring centres
var rad := PackedFloat32Array()        ## NS ring radii
var frames: Array = []                 ## NS {s, u, t, dr} ring frames
var ground_offset := 0.0               ## rig.js `off`: BodyRoot height above the ground
var stride_hint := 1.0                 ## rig.js `stride`: suggested step length

## Rig.
var bone_ring := PackedInt32Array()    ## ring index of each bone head
var spine_bones := PackedInt32Array()  ## all spine bones, tail tip -> head tip
var tail_bones := PackedInt32Array()   ## t < .35, tail tip first
var torso_bones := PackedInt32Array()
var neck_bones := PackedInt32Array()   ## .68 <= t, below the head bone
var head_bone := -1
var root_bone := -1                    ## bone at the widest ring (chain root)
var legs: Array = []                   ## CreatureLegChain
var parts: Array = []                  ## see part_entries in CREATURE.md
var growth: Array = []                 ## {region_id, side, node}
var stats: Dictionary = {}

var _attachments := {}


func _init(dir := CreatureParts.DEFAULT_ASSET_DIR) -> void:
	asset_dir = dir


## Parse + validate (+ migrate /1 /2 /3) a genome. Same contract as genome.js.
static func parse_genome(input, asset_dir_ := CreatureParts.DEFAULT_ASSET_DIR) -> Dictionary:
	var lib := CreatureParts.library(asset_dir_)
	return CreatureGenome.parse(input, lib["types"])


## Seed creatures from rig.js SEEDS.
static func seeds() -> Dictionary:
	var s := {
		"Merodeador": {"name": "Merodeador", "nodes": [{"y": 1.6, "z": -3.3, "r": .06}, {"y": 1.7, "z": -2.4, "r": .2}, {"y": 1.85, "z": -1.5, "r": .4}, {"y": 2.0, "z": -.6, "r": .7}, {"y": 2.05, "z": .4, "r": .78}, {"y": 2.15, "z": 1.3, "r": .62}, {"y": 2.5, "z": 2, "r": .46}, {"y": 2.75, "z": 2.7, "r": .56}],
			"parts": [{"type": "fauces", "t": 1, "ang": 0, "size": 1.15}, {"type": "ojo", "t": .9, "ang": .95, "size": 1}, {"type": "cuerno", "t": .87, "ang": .4, "size": 1, "len": .9, "curve": .6}, {"type": "pata", "t": .44, "ang": 2.1, "w": .23, "k": [.3, -.55, .4], "f": [.4, -1.35, -.05]}, {"type": "pata", "t": .7, "ang": 2.1, "w": .2, "k": [.25, -.7, -.3], "f": [.35, -1.45, .05]}, {"type": "pua", "t": .5, "ang": 0, "size": 1, "len": .5}, {"type": "pua", "t": .58, "ang": 0, "size": 1, "len": .6}, {"type": "pua", "t": .66, "ang": 0, "size": 1, "len": .5}],
			"skin": {"pat": 1, "cA": "#9a3b28", "cB": "#2a1414", "cC": "#e6cfa0", "wet": .3, "scale": 7}},
		"Zancuda": {"name": "Zancuda", "nodes": [{"y": 2.8, "z": -1.9, "r": .08}, {"y": 2.9, "z": -1.1, "r": .35}, {"y": 2.9, "z": -.2, "r": .72}, {"y": 3.0, "z": .6, "r": .6}, {"y": 3.6, "z": 1.1, "r": .3}, {"y": 4.4, "z": 1.25, "r": .24}, {"y": 5.1, "z": 1.5, "r": .26}, {"y": 5.35, "z": 2, "r": .36}],
			"parts": [{"type": "pico", "t": 1, "ang": 0, "size": 1}, {"type": "ojo", "t": .92, "ang": 1.1, "size": 1.25}, {"type": "zanca", "t": .4, "ang": 2.2, "w": .14, "k": [.1, -1.05, .45], "f": [.18, -2.2, .05]}, {"type": "aleta", "t": .42, "ang": 0, "size": 1.3}, {"type": "antena", "t": .9, "ang": .35, "size": 1, "len": .9}, {"type": "cresta", "t": .93, "ang": 0, "size": .9}],
			"skin": {"pat": 3, "cA": "#3d5fa8", "cB": "#8a4fb0", "cC": "#f0e6c8", "wet": .45, "scale": 9}},
		"Babosa": {"name": "Babosa", "nodes": [{"y": .5, "z": -2, "r": .15}, {"y": .6, "z": -1.1, "r": .5}, {"y": .7, "z": -.1, "r": .72}, {"y": .8, "z": .9, "r": .66}, {"y": 1.2, "z": 1.6, "r": .5}, {"y": 1.5, "z": 2.1, "r": .5}],
			"parts": [{"type": "romo", "t": 1, "ang": 0, "size": 1.2}, {"type": "tallo", "t": .88, "ang": .5, "size": 1.2, "len": .8}, {"type": "maza", "t": 0, "ang": 0, "size": .9}, {"type": "placa", "t": .4, "ang": 0, "size": 1}, {"type": "placa", "t": .55, "ang": 0, "size": 1.1}],
			"skin": {"pat": 2, "cA": "#5d8a3a", "cB": "#203818", "cC": "#e9e2a8", "wet": .7, "scale": 11}}}
	for k in s:
		s[k]["schema"] = CreatureGenome.SCHEMA
		s[k]["regions"] = []
	return s


## Parse and build in one call. Returns the parse result; on failure the
## creature is left unchanged.
func load_genome(input) -> Dictionary:
	var res := parse_genome(input, asset_dir)
	if res["ok"]:
		build(res["genome"])
		warnings = res["warnings"]
	return res


## Build from an already validated /4 genome (use load_genome for raw input).
func build(g: Dictionary) -> void:
	genome = g.duplicate(true)
	_clear()
	if materials == null:
		materials = CreatureMaterials.new()
	maker = CreatureParts.new(materials, asset_dir)
	_sample_spine()
	bio = CreatureBio.derive(genome, maker.is_leg, maker.lib["entries"])
	materials.configure(bio, genome["skin"])
	var body_geo := CreatureGeo.alloc_tube(NS, RN)
	frames = []
	frames.resize(NS)
	body_geo.fill_tube(rest, Array(rad), RN, null, true, frames)
	body_geo.skin.resize(NS * RN * 4)
	for i in NS:
		for j in RN:
			var k := i * RN + j
			var p := body_geo.pos[k]
			body_geo.skin[k * 4] = p.x
			body_geo.skin[k * 4 + 1] = p.y
			body_geo.skin[k * 4 + 2] = p.z
			body_geo.skin[k * 4 + 3] = cos(float(j) / RN * 6.28318)
	# Tube UVs for the Turing pattern, in metres: arc along the spine, arc from the dorsal midline (mirrored, so the
	# pattern is bilaterally symmetric). UV2: ring radius and spine parameter, read by the thickness and actuation code.
	body_geo.uv.resize(NS * RN)
	body_geo.uv2.resize(NS * RN)
	var arc := 0.0
	for i in NS:
		if i > 0:
			arc += rest[i].distance_to(rest[i - 1])
		for j in RN:
			var sym := acos(clampf(cos(float(j) / RN * 6.28318), -1.0, 1.0))
			body_geo.uv[i * RN + j] = Vector2(arc, sym * rad[i])
			body_geo.uv2[i * RN + j] = Vector2(rad[i], float(i) / (NS - 1))
	var has_leg := false
	for p in genome["parts"]:
		if maker.is_leg(p["type"]):
			has_leg = true
	var bottom := 1e9
	for i in NS:
		bottom = min(bottom, rest[i].y - rad[i])
	# With legs the spine sets the body height and each leg reaches the floor;
	# without legs the body rests on the ground.
	ground_offset = max(0.0, .03 - bottom) if has_leg else .03 - bottom

	body_root = Node3D.new()
	body_root.name = "BodyRoot"
	body_root.position.y = ground_offset
	add_child(body_root)
	limbs = Node3D.new()
	limbs.name = "Limbs"
	add_child(limbs)
	_build_skeleton(body_geo)
	_build_parts()
	_layout_legs()
	_build_growth()
	_compute_stats()
	_setup_actuation()
	CreatureParts.finalize(self)
	built.emit()


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	legs = []
	parts = []
	growth = []
	_attachments = {}
	bone_ring = PackedInt32Array()
	spine_bones = PackedInt32Array()
	tail_bones = PackedInt32Array()
	torso_bones = PackedInt32Array()
	neck_bones = PackedInt32Array()


# ================================================================ spine

func _sample_spine() -> void:
	var nodes: Array = genome["nodes"]
	var cpts := []
	for n in nodes:
		cpts.append(Vector3(n["r"], n["y"], n["z"]))
	rest = []
	rest.resize(NS)
	rad = PackedFloat32Array()
	rad.resize(NS)
	for i in NSP:
		var p := CreatureGeo.catmull_point(cpts, float(i) / (NSP - 1), false, "catmullrom", .5)
		rad[NC + i] = max(.03, p.x)
		rest[NC + i] = Vector3(0, p.y, p.z)
	for ad in [[NC, -1], [NC + NSP - 1, 1]]:
		var a: int = ad[0]
		var d: int = ad[1]
		var out: Vector3 = (rest[a] - rest[a - d]).normalized()
		var r0 := rad[a]
		for k in range(1, NC + 1):
			var ph := float(k) / NC * PI / 2
			rest[a + d * k] = rest[a] + out * r0 * sin(ph)
			rad[a + d * k] = max(.004, r0 * cos(ph))


## rig.js anchor(): point on the body surface at spine parameter t and angle
## ang around the spine (0 = dorsal, +pi/2 = +X flank, pi = belly).
## Returns {p, n, t, u} in body space.
func anchor(t: float, ang: float, pts = null) -> Dictionary:
	var arr: Array = rest if pts == null else pts
	var f := clampf(t, 0, 1) * (NS - 1)
	var i: int = min(int(f), NS - 2)
	var k := f - i
	var fr: Dictionary = frames[int(round(f))]
	var r := lerpf(rad[i], rad[i + 1], k)
	var sa := sin(ang)
	var ca := cos(ang)
	var wy := .9 if ca < 0 else 1.06
	var p: Vector3 = arr[i].lerp(arr[i + 1], k) + fr["s"] * sa * r + fr["u"] * ca * wy * r
	var n: Vector3 = (fr["s"] * sa + fr["u"] * ca - fr["t"] * fr["dr"]).normalized()
	return {"p": p, "n": n, "t": fr["t"], "u": fr["u"]}


## Radius of the anatomical spine at t (end caps excluded).
func mount_radius(t: float) -> float:
	var f := clampf(t * (NS - 1), NC, NC + NSP - 1)
	var i: int = min(int(f), NC + NSP - 2)
	return lerpf(rad[i], rad[i + 1], f - i)


## rig.js orient(): surface frame for a radial mount (+Z out of the skin).
func orient(A: Dictionary, sink: float, rot: float, tilt: float) -> Transform3D:
	var n: Vector3 = A["n"]
	var u: Vector3 = A["u"]
	var b: Vector3 = u - n * n.dot(u) + A["t"] * n.dot(u)
	b -= n * b.dot(n)
	if b.length_squared() < 1e-4:
		b = A["t"]
	b = b.normalized()
	var a := b.cross(n)
	var q := Basis(a, b, n).orthonormalized().get_rotation_quaternion()
	if rot != 0.0:
		q = q * Quaternion(ZA, rot)
	if tilt != 0.0:
		q = q * Quaternion(X0, tilt)
	return Transform3D(Basis(q), A["p"] - n * sink)


func _shoulder_t(a := .2) -> float:
	var nodes: Array = genome["nodes"]
	var i := 1
	for j in range(2, nodes.size() - 2):
		if nodes[j]["r"] > nodes[i]["r"]:
			i = j
	return clampf((NC + float(i) / (nodes.size() - 1) * (NSP - 1)) / (NS - 1) + a, .3, .8)


## rig.js defaults(type): placement for a newly added part (studio use).
func default_part(type: String) -> Dictionary:
	var m: Dictionary = maker.meta(type) if maker else CreatureParts.library(asset_dir)["entries"].get(type, {})
	var leg: bool = m.get("leg", false) or m.get("fitted_leg", false)
	var t := .62
	if m.get("category") == "mouths": t = 1
	elif type.begins_with("tail_"): t = .12
	elif type == "eye_triad": t = .92
	elif type == "sac_spitter": t = 1
	elif type.begins_with("arm_"): t = _shoulder_t()
	elif type in ["wing_glider", "wing_insect"]: t = _shoulder_t(.14)
	elif leg: t = .5
	var ang := 0.0
	if m.get("category") == "mouths" or type == "eye_triad": ang = 0
	elif leg: ang = 2.1
	elif m.get("category") == "wings": ang = 1.3
	elif type.begins_with("arm_"): ang = .95
	var p := {"type": type, "t": t, "ang": ang}
	if m.get("leg", false):
		p["w"] = m["w"]
		p["k"] = m["k"].duplicate()
		p["f"] = m["f"].duplicate()
	else:
		p["size"] = 1
	if m.has("len"):
		p["len"] = m["len"]
	if type == "cuerno":
		p["curve"] = .5
	return p


# ================================================================ skeleton

func _build_skeleton(body_geo: CreatureGeo) -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	body_root.add_child(skeleton)
	var rings: Array = []
	for i in range(0, NS - 1, BONE_STRIDE):
		rings.append(i)
	if rings[-1] != NS - 1:
		rings.append(NS - 1)
	# Root = bone head nearest the widest anatomical ring.
	var widest := NC
	for i in range(NC, NC + NSP):
		if rad[i] > rad[widest]:
			widest = i
	var root_k := 0
	for k in rings.size():
		if abs(rings[k] - widest) < abs(rings[root_k] - widest):
			root_k = k
	var globals: Array = []
	for k in rings.size():
		var fr: Dictionary = frames[rings[k]]
		globals.append(Transform3D(Basis(fr["s"], fr["u"], fr["t"]).orthonormalized(), rest[rings[k]]))
	var head_ring := NC + NSP - 1
	var head_k := 0
	for k in rings.size():
		skeleton.add_bone("spine_%02d" % k)
		bone_ring.append(rings[k])
		if abs(rings[k] - head_ring) < abs(rings[head_k] - head_ring):
			head_k = k
	for k in rings.size():
		var parent := -1
		if k > root_k:
			parent = k - 1
		elif k < root_k:
			parent = k + 1
		skeleton.set_bone_parent(k, parent)
		var local: Transform3D = globals[k] if parent < 0 else (globals[parent] as Transform3D).affine_inverse() * globals[k]
		skeleton.set_bone_rest(k, local)
		skeleton.set_bone_pose(k, local)
	root_bone = root_k
	head_bone = head_k
	for k in rings.size():
		spine_bones.append(k)
		var t := float(rings[k]) / (NS - 1)
		if k == head_k:
			pass
		elif t < .35 and k < root_k:
			tail_bones.append(k)
		elif t >= .68 and k < head_k:
			neck_bones.append(k)
		elif k < head_k:
			torso_bones.append(k)
	# Body skin weights: linear blend between the two bone heads around a ring.
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for i in NS:
		var k := 0
		while k < rings.size() - 2 and rings[k + 1] <= i:
			k += 1
		var f := float(i - rings[k]) / float(rings[k + 1] - rings[k])
		for j in RN:
			bones.append_array([k, k + 1, 0, 0])
			weights.append_array([1.0 - f, f, 0.0, 0.0])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body_geo.to_arrays(bones, weights), [], {}, CreatureGeo.SURFACE_FLAGS)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "Body"
	body_mesh.mesh = mesh
	body_mesh.material_override = materials.skin_body
	skeleton.add_child(body_mesh)
	body_mesh.skeleton = NodePath("..")
	body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	body_mesh.set_meta("material_region", "skin")


## Bone whose head ring is nearest spine parameter t.
func bone_for_t(t: float) -> int:
	var ring := int(round(clampf(t, 0, 1) * (NS - 1)))
	var best := 0
	for k in bone_ring.size():
		if abs(bone_ring[k] - ring) < abs(bone_ring[best] - ring):
			best = k
	return best


func bone_rest_global(bone: int) -> Transform3D:
	return skeleton.get_bone_global_rest(bone)


func _attachment(bone: int) -> BoneAttachment3D:
	if _attachments.has(bone):
		return _attachments[bone]
	var att := BoneAttachment3D.new()
	att.name = "Bone_" + skeleton.get_bone_name(bone)
	att.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(att)
	att.bone_idx = bone
	att.transform = skeleton.get_bone_global_rest(bone)
	_attachments[bone] = att
	return att


## Parents `node` (whose transform is in body space) to the bone nearest t.
func _attach(node: Node3D, t: float) -> int:
	var bone := bone_for_t(t)
	var att := _attachment(bone)
	node.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * node.transform
	att.add_child(node)
	return bone


# ================================================================ parts

func _centered(p: Dictionary) -> bool:
	return not maker.is_leg(p["type"]) and abs(sin(float(p["ang"]))) < .14


func _build_parts() -> void:
	var nodes: Array = genome["nodes"]
	var max_r := 0.0
	for n in nodes:
		max_r = max(max_r, float(n["r"]))
	var plist: Array = genome["parts"]
	for pi in plist.size():
		var p: Dictionary = plist[pi]
		var m: Dictionary = maker.meta(p["type"])
		var sides := [1] if _centered(p) else [1, -1]
		if int(p.get("single", 0)) != 0 and not maker.is_leg(p["type"]) and not _centered(p):
			sides = [int(p["single"])]    # one giant claw, one eye: the creator made this part single (A24)
		for sg in sides:
			var A := anchor(p["t"], sg * p["ang"])
			var o: Vector3 = A["p"]
			if maker.is_leg(p["type"]):
				_make_leg(pi, p, sg, A)
				continue
			var ctx := {"head": float(nodes[-1]["r"]), "body": max_r, "height": o.y + ground_offset, "mouthHeight": float(nodes[-1]["y"]) + ground_offset}
			var g := maker.make(p, o, mount_radius(p["t"]), ctx)
			g.name = "%s_%d%s" % [p["type"], pi, "" if sg > 0 else "_mirror"]
			var sink := 0.0 if String(p["type"]).begins_with("tail_") else .015
			var rot := float(p.get("rot", 0.0))
			var tilt := float(p.get("tilt", 0.0))
			var xf := orient(A, sink, rot * sg, tilt)
			var mount: String = m.get("mount", "")
			if mount in ["body", "upright"]:
				var upright := mount == "upright"
				var fr: Dictionary = frames[int(round(float(p["t"]) * (NS - 1)))]
				var q := Basis(X0 if upright else fr["s"], Y if upright else A["u"], ZA if upright else A["t"]).orthonormalized().get_rotation_quaternion()
				if rot != 0.0:
					q = q * Quaternion(ZA, rot * sg)
				if tilt != 0.0:
					q = q * Quaternion(X0, tilt)
				xf.basis = Basis(q) * Basis.from_scale(Vector3(sg, 1, 1))
			g.transform = xf
			var bone := _attach(g, p["t"])
			parts.append({"index": pi, "type": p["type"], "category": m.get("category", ""), "side": sg, "node": g,
				"t": float(p["t"]), "ang": float(p["ang"]), "size": float(p.get("size", 1.0)), "bone": bone,
				"mount": mount if mount != "" else "radial", "mount_radius": mount_radius(p["t"]), "hooks": _hooks(g)})


func _hooks(g: Node3D) -> Dictionary:
	var h := {}
	for k in ["jaw", "lid", "sway", "pinch", "wing", "arm", "tail", "sacs"]:
		if g.has_meta(k):
			h[k] = g.get_meta(k)
	return h


## rig.js fittedPose(): IK pose for G48 fitted legs (never written to genomes).
func _fitted_pose(p: Dictionary, height: float, r: float) -> Dictionary:
	var s: float = p.get("size", 1.0) * r / .6
	var w := .16 * s
	var rot := float(p.get("rot", 0.0))
	var tilt := float(p.get("tilt", 0.0))
	var k := Vector3(.32 * s, -height * .48, .34 * s + tilt * .3 * s).rotated(Y, rot)
	var f := Vector3(.35 * s, -height + w * .6, .12 * s).rotated(Y, rot)
	var out := p.duplicate(true)
	out["w"] = w
	out["k"] = [k.x, k.y, k.z]
	out["f"] = [f.x, f.y, f.z]
	return out


func _make_leg(pi: int, p: Dictionary, sg: int, A: Dictionary) -> void:
	var m := maker.meta(p["type"])
	var fitted: bool = m.get("fitted_leg", false)
	var pose: Dictionary
	if fitted:
		pose = _fitted_pose(p, A["p"].y + ground_offset, mount_radius(p["t"]))
	else:
		pose = p.duplicate(true)
	pose["f"] = pose["f"].duplicate()
	pose["k"] = pose["k"].duplicate()
	pose["f"][1] = -(A["p"].y + ground_offset) + float(pose["w"]) * .6
	pose["k"][1] = max(float(pose["k"][1]), float(pose["f"][1]) + .12)
	var kv := Vector3(pose["k"][0], pose["k"][1], pose["k"][2])
	var fv := Vector3(pose["f"][0], pose["f"][1], pose["f"][2])
	var a: float = max(.12, kv.length())
	var b: float = max(.12, (fv - kv).length())
	var segs := maker.make_leg(p["type"], pose, A["p"], a, b)
	var leg := CreatureLegChain.new()
	var mode := float(bio["limbs"][pi]["mode"]) if bio.get("limbs", {}).has(pi) else 1.0
	leg.upper_mat = _limb_skin(segs["up"], 1, a, mode)
	leg.lower_mat = _limb_skin(segs["lo"], 2, b, mode)
	leg.creature = self
	leg.part = p
	leg.part_index = pi
	leg.type = p["type"]
	leg.side = sg
	leg.upper = segs["up"]
	leg.lower = segs["lo"]
	leg.foot = segs["ft"]
	leg.upper_length = a
	leg.lower_length = b
	leg.width = pose["w"]
	leg.mirrored_mesh = fitted
	var tag := "%s_%d%s" % [p["type"], pi, "" if sg > 0 else "_mirror"]
	leg.upper.name = tag + "_upper"
	leg.lower.name = tag + "_lower"
	leg.foot.name = tag + "_foot"
	for n in [leg.upper, leg.lower, leg.foot]:
		limbs.add_child(n)
	var hip := Node3D.new()
	hip.name = tag + "_hip"
	hip.transform = Transform3D(Basis(), A["p"])
	leg.hip_bone = _attach(hip, p["t"])
	leg.hip_marker = hip
	leg.rest_knee = Vector3(kv.x * sg, kv.y, kv.z)
	leg.rest_foot = Vector3(fv.x * sg, fv.y, fv.z)
	legs.append(leg)


## Gives the skin meshes of one limb segment their own copy of the skin material (the flex uniform is per segment).
func _limb_skin(seg: Node3D, part: int, seg_len: float, mode: float) -> ShaderMaterial:
	var m := materials.limb_material(part, seg_len, mode)
	for c in seg.get_children():
		if c is MeshInstance3D and c.material_override == materials.skin:
			c.material_override = m
	return m


## Muscle masses at the hips and shoulders, and the wet radius around the snout (body rest space), for the body shader.
func _setup_actuation() -> void:
	var mounts: Array = []
	for l in legs:
		var A := anchor(l.part["t"], l.side * l.part["ang"])
		var pos: Vector3 = A["p"]
		var r := mount_radius(l.part["t"]) * .8
		var dup := false
		for m in mounts:
			if Vector3(m.x, m.y, m.z).distance_to(pos) < .05:
				dup = true
		if not dup and mounts.size() < 6:
			mounts.append(Vector4(pos.x, pos.y, pos.z, r))
	var packed: Array = []
	for i in 6:
		packed.append(mounts[i] if i < mounts.size() else Vector4())
	var head: Vector3 = rest[NS - 1]
	var head_r: float = rad[NS - 1]
	for m in materials.skin_materials():
		m.set_shader_parameter("mounts", packed)
		m.set_shader_parameter("n_mounts", mounts.size())
		m.set_shader_parameter("snout", Vector4(head.x, head.y, head.z, maxf(head_r * 2.2, .25)))


## rig.js layout(): rest knee/foot, pole, home, hang, stride and leg groups.
func _layout_legs() -> void:
	var st := 1e9
	for l in legs:
		var A := anchor(l.part["t"], l.side * l.part["ang"])
		var hp: Vector3 = A["p"]
		var sole: float = hp.y + l.rest_foot.y - l.width * .6
		var fd: Vector3 = l.rest_foot.normalized()
		var pole: Vector3 = l.rest_knee - fd * l.rest_knee.dot(fd)
		if pole.length() < .03:
			pole = Vector3(0, 0, 1)
		l.pole = pole.normalized()
		l.home = Vector3(hp.x + l.rest_foot.x, 0, hp.z + l.rest_foot.z)
		l.hang = max(0.0, sole + ground_offset)
		var L: float = l.total_length()
		var hh: float = hp.y + ground_offset - l.width * .6 - l.hang
		var mh := sqrt(maxf(L * L - hh * hh, 0.0))
		if l.hang < .08:
			st = min(st, min(1.25 * L, 2.9 * mh))
	stride_hint = max(.25, st) if st < 1e8 else 1.0
	var ts := []
	for l in legs:
		if not (float(l.part["t"]) in ts):
			ts.append(float(l.part["t"]))
	ts.sort()
	for l in legs:
		var k := ts.find(float(l.part["t"]))
		l.pair_index = k
		l.front = ts.size() > 1 and k >= ts.size() / 2.0
		l.pose_rest()


## Puts every leg back in its rest pose (knee/ankle at authored offsets).
func pose_legs_rest() -> void:
	for l in legs:
		l.pose_rest()


## Solves every leg towards its foot_target (see CreatureLegChain).
func solve_legs() -> void:
	for l in legs:
		l.solve()


# ================================================================ growth

static func region_range(surface: String) -> Vector2:
	if surface == "tail":
		return Vector2(.08, .35)
	if surface == "neck":
		return Vector2(.75, .96)
	return Vector2(.35, .75)


func _build_growth() -> void:
	for r in genome["regions"]:
		var gen := CreatureGrowth.generate(r)
		if not gen["ok"]:
			continue
		var rr := region_range(r["surface"])
		for piece in gen["pieces"]:
			for side in [1, -1]:
				if not (side == 1 or (r["mirror"] and abs(float(r["angle"])) > .04)):
					continue
				var along: float = (1 - r["coverage"]) * r["position"] + r["coverage"] * (piece["offset"] + .5)
				var t := lerpf(rr.x, rr.y, along)
				var A := anchor(t, float(r["angle"]) * side)
				var geo := CreatureGeo.new()
				geo.pos = piece["positions"]
				geo.nrm = piece["normals"]
				geo.idx = piece["indices"]
				# Stable body-relative skin coordinates.
				geo.skinify(A["p"], cos(float(r["angle"])))
				var root := Node3D.new()
				root.name = "growth_%s_%d" % [r["id"], growth.size()]
				var xf := orient(A, .01, 0, 0)
				xf.basis = xf.basis * Basis(X0, PI / 2) * Basis.from_scale(Vector3(side, 1, 1))
				root.transform = xf
				var mi := MeshInstance3D.new()
				mi.set_meta("geo", geo)
				mi.set_meta("material_region", "skin" if r["family"] == "tendrils" else "keratin")
				mi.material_override = materials.skin if r["family"] == "tendrils" else materials.bone
				root.add_child(mi)
				var bone := _attach(root, t)
				growth.append({"region_id": r["id"], "family": r["family"], "side": side, "node": root, "t": t, "bone": bone})


# ================================================================ data

## rig.js computeStats(): dna, vel, bite, sing, hp (1..5) and warnings.
func _compute_stats() -> void:
	var P: Array = genome["parts"]
	var lib: Dictionary = maker.lib["entries"]
	var mouths := P.filter(func(p): return lib[p["type"]].get("category") == "mouths")
	var lg := P.filter(func(p): return maker.is_leg(p["type"]))
	var vol := body_volume()
	var avg := 0.0
	if not legs.is_empty():
		for l in legs:
			avg += l.total_length()
		avg = avg / legs.size() * .95
	var sum := func(k: String) -> float:
		var s := 0.0
		for p in P:
			if lib[p["type"]].get("category") != "mouths":
				s += float(lib[p["type"]].get(k, 0))
		return s
	var mx := func(k: String) -> float:
		var s := 0.0
		for p in mouths:
			s = max(s, float(lib[p["type"]].get(k, 0)))
		return s
	var dna := 0
	for p in P:
		dna += int(lib[p["type"]]["cost"])
	dna += max(0, genome["nodes"].size() - 6) * 5
	var has := func(t: String) -> bool: return P.any(func(p): return p["type"] == t)
	var warn := []
	if mouths.is_empty(): warn.append("Sin boca no puede comer ni cantar")
	if not has.call("ojo") and not has.call("tallo"): warn.append("Sin ojos va a ciegas")
	if lg.is_empty(): warn.append("Sin patas se arrastra")
	var vel := 1
	if not lg.is_empty():
		vel = clampi(roundi(1.4 + avg * .95 + (.5 if lg.size() == 1 else 0.0) - max(0.0, vol - 7) * .12), 1, 5)
	stats = {"dna": dna, "vel": vel,
		"bite": clampi(roundi(mx.call("bite") + sum.call("bite")), 0, 5),
		"sing": clampi(roundi(mx.call("sing") + sum.call("sing")), 0, 5),
		"hp": clampi(roundi(1 + vol * .3 + sum.call("hp")), 1, 5),
		"warn": warn,
		"speed": 1 + vel * .55 if not lg.is_empty() else .7}


## rig.js body volume proxy (sum of r^2 * segment length * 3.14).
func body_volume() -> float:
	var vol := 0.0
	for i in range(NC, NC + NSP - 1):
		vol += rad[i] * rad[i] * rest[i].distance_to(rest[i + 1]) * 3.14
	return vol


## Mass-relevant data for physics/locomotion. Everything in body space
## (add ground_offset in y for Creature space).
## {segments:[{t, center, radius, length}], volume, length,
##  parts:[{type, category, side, size, t, cost}], legs:[{upper, lower, width, side, t}]}
func mass_data() -> Dictionary:
	var segs := []
	for i in NS - 1:
		segs.append({"t": (i + .5) / (NS - 1), "center": (rest[i] + rest[i + 1]) * .5,
			"radius": (rad[i] + rad[i + 1]) * .5, "length": rest[i].distance_to(rest[i + 1])})
	var plist := []
	for e in parts:
		plist.append({"type": e["type"], "category": e["category"], "side": e["side"], "size": e["size"], "t": e["t"],
			"cost": maker.meta(e["type"]).get("cost", 0)})
	var llist := []
	for l in legs:
		plist.append({"type": l.type, "category": "legs", "side": l.side, "size": l.part.get("size", l.width), "t": float(l.part["t"]),
			"cost": maker.meta(l.type).get("cost", 0)})
		llist.append({"upper": l.upper_length, "lower": l.lower_length, "width": l.width, "side": l.side, "t": float(l.part["t"])})
	return {"segments": segs, "volume": body_volume(), "length": rest[NS - 1].distance_to(rest[0]),
		"parts": plist, "legs": llist}


## Animation hooks of the attached parts: [{index, type, side, hooks:{jaw, lid,
## sway, pinch, wing, arm, tail, sacs}}] (only parts that have hooks).
func animation_hooks() -> Array:
	var out := []
	for e in parts:
		if not e["hooks"].is_empty():
			out.append({"index": e["index"], "type": e["type"], "side": e["side"], "hooks": e["hooks"]})
	return out


## Live skin palette change without rebuilding geometry.
func set_skin(skin: Dictionary) -> void:
	genome["skin"] = skin.duplicate()
	materials.set_skin(skin)


func set_sun_direction(dir: Vector3) -> void:
	materials.set_sun_direction(dir)


## Resets every spine bone to its rest pose.
func reset_spine_pose() -> void:
	for b in skeleton.get_bone_count():
		skeleton.set_bone_pose(b, skeleton.get_bone_rest(b))


## Body-space AABB of all meshes (rest pose), for framing and tests.
func rest_aabb() -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(self):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n and n != self:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func mesh_instances() -> Array:
	return _meshes(self)
