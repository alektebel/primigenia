class_name CreatureParts
extends RefCounted
## The part library: every id in parts.json, built as in web/creature/rig.js.
## Procedural parts are rebuilt here with the same primitives and numbers;
## GLB parts are loaded at runtime with GLTFDocument (no editor import step)
## and given the same material regions and axis fix-ups as the web loader.
##
## The static side (`library()`) holds metadata, parts.json and GLB templates,
## loaded once. An instance is a maker bound to one creature's materials:
##   var maker := CreatureParts.new(materials)
##   var node := maker.make(part_dict, skin_offset, mount_radius, context)
## Leg parts are built by make_leg() instead (they are IK chains).

const DEFAULT_ASSET_DIR := "res://creature/assets/"
const WingData := preload("res://creature/creature_wing.gd")
const X0 := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const ZA := Vector3(0, 0, 1)

## rig.js LIB metadata. cat/name/cost are replaced by parts.json entries.
const META := {
	"espinas_dorsales": {"p": ["size"]},
	"fauces": {"bite": 3, "sing": 1, "p": ["size"]},
	"romo": {"bite": 1, "sing": 3, "p": ["size"]},
	"pico": {"bite": 2, "sing": 2, "p": ["size"]},
	"ojo": {"p": ["size"]},
	"tallo": {"sing": 1, "p": ["size", "len"], "len": .7},
	"antena": {"sing": 1, "p": ["size", "len"], "len": 1.1},
	"trompa": {"bite": 0, "sing": 3, "p": ["size"]},
	"pinzas": {"bite": 4, "sing": 0, "p": ["size"]},
	"oreja": {"sing": 1, "p": ["size"]},
	"pata": {"leg": true, "foot": "garra", "p": ["w"], "w": .2, "k": [.28, -.72, .12], "f": [.38, -1.4, -.02]},
	"zanca": {"leg": true, "foot": "dedos", "p": ["w"], "w": .13, "k": [.1, -1.1, -.3], "f": [.18, -2.35, .05]},
	"pezuna": {"leg": true, "foot": "pezuna", "p": ["w"], "w": .3, "k": [.08, -.62, .1], "f": [.1, -1.2, 0]},
	"asta": {"bite": 1, "p": ["size", "len"], "len": 1.2},
	"aguijon": {"bite": 2, "p": ["size"]},
	"cuerno": {"bite": 1, "p": ["size", "len", "curve"], "len": .9},
	"pua": {"hp": .34, "p": ["size", "len"], "len": .55},
	"maza": {"bite": 1, "hp": 1, "p": ["size"]},
	"placa": {"hp": .5, "p": ["size"]},
	"cresta": {"sing": 1, "p": ["size"]},
	"bulbo": {"sing": 1, "p": ["size"]},
	"aleta": {"sing": 1, "p": ["size"]},
	"excavadora": {"p": ["size"]},
	"beak_crusher": {"bite": 3, "sing": 2, "mount": "body", "responsive": true},
	"eye_triad": {"responsive": true},
	"wing_glider": {"mount": "upright", "body_minimum": .8, "responsive": true},
	"wing_insect": {"mount": "upright", "body_minimum": .8, "responsive": true},
	"wing_vane": {"mount": "upright", "body_minimum": .8, "responsive": true},
	"wing_flap": {"mount": "upright", "body_minimum": .8, "responsive": true},
	"frill_fan": {"responsive": true},
	"sac_spitter": {"mount": "body", "responsive": true},
	"arm_grasper": {"mount": "upright", "body_minimum": .65, "responsive": true},
	"arm_smasher": {"mount": "upright", "body_minimum": .65, "responsive": true},
	"tail_paddle": {"mount": "body", "body_minimum": 1, "responsive": true},
	"tail_spike": {"mount": "body", "body_minimum": 1, "responsive": true},
	"tail_hammer": {"mount": "body", "body_minimum": 1, "responsive": true},
	"leg_sprinter": {"fitted_leg": true, "foot": "runner", "responsive": true},
	"leg_sucker": {"fitted_leg": true, "foot": "sucker", "responsive": true},
	"foot_spring": {"fitted_leg": true, "foot": "spring", "responsive": true},
	"foot_hoof": {"fitted_leg": true, "foot": "cloven", "responsive": true},
	"foot_gecko": {"fitted_leg": true, "foot": "gecko", "responsive": true},
}

static var _lib: Dictionary = {}


# ================================================================ library

## Loads parts.json and every GLB once. Returns the library dictionary:
## {ok, table, types, entries:{id: meta}, templates:{id: [ {geo, region, material, mesh} ]},
##  material_slots:[...], failures:[ids], asset_dir}
static func library(asset_dir := DEFAULT_ASSET_DIR) -> Dictionary:
	if not _lib.is_empty() and _lib["asset_dir"] == asset_dir:
		return _lib
	var lib := {"ok": false, "asset_dir": asset_dir, "table": {}, "types": {}, "entries": {}, "templates": {},
		"material_slots": [], "failures": [], "error": ""}
	var text := FileAccess.get_file_as_string(asset_dir + "parts.json")
	var table = JSON.parse_string(text)
	if typeof(table) != TYPE_DICTIONARY:
		lib["error"] = "cannot read " + asset_dir + "parts.json"
		return lib
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(asset_dir + "parts/manifest.json"))
	if typeof(manifest) == TYPE_DICTIONARY:
		var cv: Dictionary = manifest["coordinate_convention"]
		if cv["blender"]["up"] != "+Z" or cv["blender"]["forward"] != "+X" or cv["gltf"]["up"] != "+Y" or cv["gltf"]["units"] != "meters":
			lib["error"] = "Unsupported part coordinate convention"
			return lib
	lib["table"] = table
	lib["types"] = CreatureGenome.types_from_table(table)
	for entry in table["parts"]:
		var id: String = entry["id"]
		var meta: Dictionary = META.get(id, {}).duplicate(true)
		meta["id"] = id
		meta["category"] = entry["category"]
		meta["name"] = entry["name"]["es"]
		meta["name_en"] = entry["name"].get("en", entry["name"]["es"])
		meta["cost"] = entry["dna_cost"]
		meta["source"] = entry["source"]
		if entry["source"] == "glb":
			meta["glb"] = true
			meta["mount"] = entry.get("mount", "radial")
			meta["p"] = ["size"]
			var tpl := _load_glb(entry, table, asset_dir, lib["material_slots"])
			if tpl.is_empty():
				lib["failures"].append(id)
			lib["templates"][id] = tpl
		elif not META.has(id):
			lib["failures"].append(id)
		if not meta.has("p"):
			meta["p"] = ["size"]
		lib["entries"][id] = meta
	lib["ok"] = lib["failures"].is_empty()
	_lib = lib
	return lib


static func _slot_region(entry: Dictionary, table: Dictionary, mesh_name: String, mat_name: String, mat: Material) -> String:
	var glowing := false
	if mat is BaseMaterial3D and mat.emission_enabled:
		var e: Color = mat.emission
		glowing = e.r + e.g + e.b > .25 and mat.emission_energy_multiplier >= 1
	if glowing or _re("(?i)lantern|chartreuse|\\bglow\\b").search(mat_name):
		return "glow"
	if entry["id"] == "beak_crusher":
		return "keratin"
	if (entry["category"] == "wings" or _re("(?i)wing|membrane|fan").search(mesh_name)) and mat_name == "Warm sand underside":
		return "membrane"
	var listed = table["material_regions"].get(mat_name)
	if typeof(listed) == TYPE_STRING and mat_name != "method":
		return listed
	if _re("(?i)membrane").search(mat_name):
		return "membrane"
	if _re("(?i)iris|obsidian|\\beye").search(mat_name):
		return "eye"
	if _re("(?i)keratin|ivory|chitin").search(mat_name):
		return "keratin"
	if _re("(?i)skin|underside").search(mat_name):
		return "skin"
	if _re("(?i)dark").search(mat_name):
		return "dark"
	if entry["category"] in ["wings", "fins"]:
		return "membrane"
	if entry["category"] in ["weapons", "digging_claws"]:
		return "keratin"
	if entry["category"] == "senses":
		return "eye"
	return "skin"


static var _re_cache := {}


static func _re(p: String) -> RegEx:
	if not _re_cache.has(p):
		var r := RegEx.new()
		r.compile(p)
		_re_cache[p] = r
	return _re_cache[p]


## rig.js regionMaterial(): material name on a CreatureMaterials instance.
static func region_material_name(entry_id: String, mat_name: String, region: String) -> String:
	match region:
		"skin": return "skin"
		"membrane": return "membrane"
		"glow": return "glow"
		"eye": return "iris" if mat_name.contains("iris") else "pupil"
		"dark": return "dark"
	return "beak" if entry_id.contains("beak") and not mat_name.contains("Ivory") else "bone"


static func _load_glb(entry: Dictionary, table: Dictionary, asset_dir: String, slots: Array) -> Array:
	var path: String = asset_dir + "parts/" + entry["file"]
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return []
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_buffer(bytes, path.get_base_dir(), state) != OK:
		return []
	var root := doc.generate_scene(state)
	if root == null:
		return []
	var out: Array = []
	_collect_meshes(root, Transform3D.IDENTITY, entry, table, out, slots, true)
	root.free()
	return out


static func _collect_meshes(node: Node, parent_xf: Transform3D, entry: Dictionary, table: Dictionary, out: Array, slots: Array, is_root: bool) -> void:
	var xf := parent_xf
	if node is Node3D and not is_root:
		xf = parent_xf * (node as Node3D).transform
	var mesh: Mesh = null
	if node is MeshInstance3D:
		mesh = node.mesh
	elif node is ImporterMeshInstance3D and node.mesh:
		mesh = node.mesh.get_mesh()
	if mesh:
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var geo := CreatureGeo.new()
			geo.pos = arrays[Mesh.ARRAY_VERTEX]
			geo.nrm = arrays[Mesh.ARRAY_NORMAL]
			if arrays[Mesh.ARRAY_INDEX] != null:
				geo.idx = arrays[Mesh.ARRAY_INDEX]
			else:
				for i in geo.pos.size():
					geo.idx.append(i)
			geo.flip_winding()  # Godot (clockwise) -> three.js convention
			var mat := mesh.surface_get_material(s)
			if mat == null and node is MeshInstance3D:
				mat = node.get_surface_override_material(s)
			var mat_name := mat.resource_name if mat else ""
			var mesh_name := String(node.name)
			if mesh.resource_name != "":
				mesh_name = mesh.resource_name
			mesh_name = _re("_\\d+$").sub(mesh_name, "")
			# Node transforms retained, then glTF -> studio: rotate Y by -pi/2;
			# radial mounts rotate X by pi/2 except mouths (and the old sac).
			geo.apply_transform(xf)
			geo.rotate_y(-PI / 2)
			if entry.get("mount") == "radial" and entry["category"] != "mouths" and entry["id"] != "sac_spitter":
				geo.rotate_x(PI / 2)
			var region := _slot_region(entry, table, mesh_name, mat_name, mat)
			out.append({"geo": geo, "region": region, "material": region_material_name(entry["id"], mat_name, region), "mesh": mesh_name, "material_name": mat_name})
			slots.append({"part": entry["id"], "category": entry["category"], "mesh": mesh_name, "material": mat_name if mat_name != "" else "(unnamed)", "region": region})
	for c in node.get_children():
		_collect_meshes(c, xf, entry, table, out, slots, false)


# ================================================================ maker

var mats: CreatureMaterials
var lib: Dictionary


func _init(materials: CreatureMaterials, asset_dir := DEFAULT_ASSET_DIR) -> void:
	mats = materials
	lib = library(asset_dir)


func meta(type: String) -> Dictionary:
	return lib["entries"].get(type, {})


func is_leg(type: String) -> bool:
	var m := meta(type)
	return m.get("leg", false) or m.get("fitted_leg", false)


func _mesh(geo: CreatureGeo, mat, parent: Node3D, region := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.set_meta("geo", geo)
	m.material_override = mats.by_name(mat) if mat is String else mat
	if region != "":
		m.set_meta("material_region", region)
	if parent:
		parent.add_child(m)
	return m


func _group(parent: Node3D, name := "") -> Node3D:
	var n := Node3D.new()
	if name != "":
		n.name = name
	if parent:
		parent.add_child(n)
	return n


func _tissue(geo: CreatureGeo, region: String, parent: Node3D, mat := "") -> MeshInstance3D:
	var m := _mesh(geo, mats.for_region(region) if mat == "" else mats.by_name(mat), parent, region)
	if region == "glow":
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func set_euler(n: Node3D, x: float, y: float, z: float, order := "XYZ") -> void:
	var rx := Basis(X0, x)
	var ry := Basis(Y, y)
	var rz := Basis(ZA, z)
	var b := rx * ry * rz
	if order == "YXZ":
		b = ry * rx * rz
	n.transform.basis = b * Basis.from_scale(n.scale)


static func v3(a) -> Vector3:
	return a if a is Vector3 else Vector3(a[0], a[1], a[2])


## Builds the meshes of a part tree (call once the geometry is final).
static func finalize(root: Node) -> void:
	if root is MeshInstance3D and root.has_meta("geo"):
		var geo: CreatureGeo = root.get_meta("geo")
		var mat = root.material_override
		if mat is ShaderMaterial and mat.shader.resource_path.ends_with("keratin.gdshader"):
			geo.compute_along()
		elif mat is ShaderMaterial and mat.shader.resource_path.ends_with("eye_iris.gdshader"):
			geo.compute_disc()
		root.mesh = geo.to_mesh()
	for c in root.get_children():
		finalize(c)


## rig.js LIB[type].make(p, off, r, context). Returns the part root.
## context: {head, body, height, mouthHeight}.
func make(p: Dictionary, off: Vector3, r := .6, context := {}) -> Node3D:
	var type: String = p["type"]
	var m := meta(type)
	if context.is_empty():
		context = {"head": .6, "body": .6, "height": 2.0, "mouthHeight": 2.2}
	if m.get("glb", false):
		return _make_glb(type, p, off)
	if m.get("responsive", false):
		return _make_creator(type, p, off, r, context)
	var g := _make_classic(type, p, off)
	if m.get("category") == "mouths":
		# Older procedural mouths sit .3*size behind the mount.
		var inner := _group(null, "inner")
		inner.position.z = -.3 * p.get("size", 1.0)
		for c in g.get_children():
			g.remove_child(c)
			inner.add_child(c)
		g.add_child(inner)
	return g


func _make_glb(type: String, p: Dictionary, off: Vector3) -> Node3D:
	var g := Node3D.new()
	var s: float = p.get("size", 1.0)
	for src in lib["templates"].get(type, []):
		var geo: CreatureGeo = src["geo"].clone()
		geo.scale_all(s)
		geo.skinify(off, .42 if src["region"] == "membrane" else null)
		var mi := _mesh(geo, src["material"], g, src["region"])
		if src["region"] == "glow":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


# ---------------------------------------------------------------- classic

func _mouth(kind: String, p: Dictionary, off: Vector3) -> Node3D:
	var g := Node3D.new()
	var hr: float = .55 * p["size"]
	var jaw := _group(g, "jaw")
	g.set_meta("jaw", jaw)
	var teeth := func(par: Node3D, zs: Array, xw: float, y: float, up: bool):
		for sx in [-1.0, 1.0]:
			for i in zs.size():
				var t := _mesh(CreatureGeo.cone(hr * .055, hr * (.2 + .06 * (i % 2)), 8).translate(0, hr * .1, 0), "tooth", par)
				t.position = Vector3(sx * xw * (1 - i * .07), y, zs[i])
				set_euler(t, 0.0 if up else PI, 0, sx * (-.12 if up else .12))
	if kind == "fauces":
		_mesh(CreatureGeo.ell(hr * .62, hr * .44, hr * 1.3, 0, hr * .1, hr * .55).skinify(off, .3), "skin", g)
		jaw.position = Vector3(0, -hr * .2, -hr * .3)
		_mesh(CreatureGeo.ell(hr * .52, hr * .2, hr * 1.15, 0, 0, hr * .75).skinify(off, -.7), "skin", jaw)
		var zs := []
		for z in [.35, .65, .95, 1.25, 1.5, 1.7]:
			zs.append(z * hr)
		teeth.call(g, zs, hr * .47, -hr * .12, false)
		var zj := []
		for z in zs:
			zj.append(z + hr * .1)
		teeth.call(jaw, zj, hr * .4, hr * .1, true)
		for sx in [-1, 1]:
			_mesh(CreatureGeo.ell(hr * .05, hr * .035, hr * .07, sx * hr * .17, hr * .3, hr * 1.68), "dark", g)
	elif kind == "romo":
		_mesh(CreatureGeo.ell(hr * .8, hr * .52, hr * .8, 0, hr * .08, hr * .25).skinify(off, .3), "skin", g)
		jaw.position = Vector3(0, -hr * .22, -hr * .25)
		_mesh(CreatureGeo.ell(hr * .7, hr * .24, hr * .75, 0, 0, hr * .5).skinify(off, -.7), "skin", jaw)
		for sx in [-1, 1]:
			_mesh(CreatureGeo.ell(hr * .07, hr * .045, hr * .05, sx * hr * .24, hr * .3, hr * .98), "dark", g)
	else:
		_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, hr * .05 - hr * .6 * u * u, hr * (-.2 + 1.7 * u)), hr * .58, 12, 14, Y).scale(.8, 1, 1), "beak", g)
		jaw.position = Vector3(0, -hr * .25, -hr * .2)
		_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, hr * .1 * u, hr * (1.3 * u)), hr * .38, 10, 12, Y).scale(.85, .6, 1), "beak", jaw)
	return g


func _eye(p: Dictionary, off: Vector3, stalk: bool) -> Node3D:
	var g := Node3D.new()
	var er: float = .2 * p["size"]
	var e := _group(g, "eye")
	if stalk:
		var L: float = p["len"]
		_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, L * .35 * u * u, L * u), .09 * p["size"], 10, 10, X0).skinify(off, .3), "skin", g)
		e.position = Vector3(0, L * .35, L)
	else:
		e.position.z = er * .3
	g.set_meta("lid", _eyeball(e, er, off, str(p.get("pupil", "auto"))))
	return g


## One eye: sclera, a wet cornea bulge over a radial iris whose pupil shape follows the creature (or the creator's
## override: round, slit, bar), and two eyelids of skin. Returns the upper lid (the blink hook).
func _eyeball(e: Node3D, er: float, off: Vector3, pupil := "auto") -> MeshInstance3D:
	var kind := pupil if pupil != "auto" else str(mats.bio.get("pupil", "round"))
	_mesh(CreatureGeo.sphere(er, 24, 16), "eye_white", e)
	_mesh(CreatureGeo.ell(er * .66, er * .66, er * .3, 0, 0, er * .72), mats.iris_for(kind), e)
	var cor := _mesh(CreatureGeo.ell(er * .74, er * .74, er * .5, 0, 0, er * .62), mats.cornea, e)
	cor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lid := _mesh(CreatureGeo.sphere(er * 1.13, 18, 10, 0, 6.2832, 0, 1.25).skinify(off, .6), "skin", e)
	lid.name = "lid"
	set_euler(lid, -.3, 0, 0)
	var low := _mesh(CreatureGeo.sphere(er * 1.1, 18, 8, 0, 6.2832, 2.4, PI - 2.4).skinify(off, .3), "skin", e)
	low.name = "lid_low"
	set_euler(low, .12, 0, 0)
	return lid


static func _cone_z(r: float, h: float, z: float) -> CreatureGeo:
	return CreatureGeo.cone(r, h, 10).rotate_x(PI / 2).translate(0, 0, z)


func _make_classic(type: String, p: Dictionary, o: Vector3) -> Node3D:
	var s: float = p.get("size", 1.0)
	match type:
		"fauces", "romo", "pico":
			return _mouth(type, p, o)
		"ojo":
			return _eye(p, o, false)
		"tallo":
			return _eye(p, o, true)
		"antena":
			var g := Node3D.new()
			var L: float = p["len"]
			var sw := _group(g, "sway")
			g.set_meta("sway", sw)
			_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, L * .45 * u * u, L * u - .05), .045 * s, 12, 8, X0), "dark", sw)
			var b := _mesh(CreatureGeo.ell(.09 * s, .09 * s, .09 * s), "glow", sw)
			b.position = Vector3(0, L * .45, L - .05)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return g
		"trompa":
			var g := Node3D.new()
			_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, -.55 * s * u * u, (-.2 + 1.35 * u) * s), .3 * s, 16, 14, X0).skinify(o, .3), "skin", g)
			_mesh(CreatureGeo.ell(.07 * s, .07 * s, .05 * s, 0, -.5 * s, 1.1 * s), "dark", g)
			return g
		"pinzas":
			var g := Node3D.new()
			_mesh(CreatureGeo.ell(.46 * s, .3 * s, .34 * s).skinify(o, .3), "skin", g)
			var pinch := []
			for sx in [-1.0, 1.0]:
				var q := _group(g, "pincer")
				q.position.x = sx * .2 * s
				_mesh(CreatureGeo.curve_tube(func(u): return Vector3(sx * .42 * sin(u * 2.7) * s, 0, (.05 + .95 * u) * s), .13 * s, 14, 10, Y), "dark", q)
				q.set_meta("sx", sx)
				pinch.append(q)
			g.set_meta("pinch", pinch)
			return g
		"oreja":
			var g := Node3D.new()
			var sw := _group(g, "sway")
			g.set_meta("sway", sw)
			_mesh(CreatureGeo.ell(.07 * s, .3 * s, .55 * s, 0, .08 * s, .42 * s).skinify(o, .35), "skin", sw)
			_mesh(CreatureGeo.ell(.05 * s, .2 * s, .4 * s, .04 * s, .08 * s, .42 * s), "beak", sw)
			return g
		"asta":
			var g := Node3D.new()
			var L: float = p["len"]
			var r := .11 * s
			var m := func(u): return Vector3(0, -.25 * L * u * u, L * u - .06)
			_mesh(CreatureGeo.curve_tube(m, r, 14, 10, X0), "bone", g)
			for ad in [[.4, .5], [.68, .36]]:
				var b: Vector3 = m.call(ad[0])
				var d: float = ad[1]
				_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, b.y + d * L * u, b.z + d * L * .35 * u * u), r * .7, 8, 8, X0), "bone", g)
			return g
		"aguijon":
			var g := Node3D.new()
			var sw := _group(g, "sway")
			g.set_meta("sway", sw)
			for ur in [[.2, .24], [.5, .2], [.78, .16]]:
				var u: float = ur[0]
				var r: float = ur[1]
				_mesh(CreatureGeo.ell(r * s, r * s, r * s * 1.15, 0, .75 * s * u * u, .95 * s * u), "dark", sw)
			var c := _mesh(CreatureGeo.cone(.09 * s, .5 * s, 10).translate(0, .25 * s, 0), "beak", sw)
			c.position = Vector3(0, .5 * s, .82 * s)
			set_euler(c, .5, 0, 0)
			return g
		"cuerno":
			var g := Node3D.new()
			var L: float = p["len"]
			var c: float = p["curve"]
			_mesh(CreatureGeo.curve_tube(func(u): return Vector3(0, -c * L * .7 * u * u, L * u * (1 - .2 * c * u) - .06), .2 * s, 14, 12, X0), "bone", g)
			return g
		"espinas_dorsales":
			var g := Node3D.new()
			for k in 3:
				var spike := _mesh(_cone_z(.12 * s, .6 * s, .25 * s), "bone", g)
				spike.position.x = (k - 1) * .22 * s
			return g
		"pua":
			var g := Node3D.new()
			var L: float = p["len"]
			_mesh(_cone_z(.16 * s, L, L / 2 - .06), "bone", g)
			return g
		"maza":
			var g := Node3D.new()
			_mesh(CreatureGeo.ell(.42 * s, .36 * s, .44 * s, 0, 0, .3 * s), "bone", g)
			for k in 6:
				var a := k * 1.047
				var c := _mesh(CreatureGeo.cone(.1 * s, .4 * s, 8).translate(0, .2 * s, 0), "bone", g)
				c.position = Vector3(cos(a) * .34 * s, sin(a) * .28 * s, .3 * s)
				set_euler(c, 0, 0, a - PI / 2)
			return g
		"placa":
			var g := Node3D.new()
			var ge := CreatureGeo.octahedron().scale(.06 * s, .34 * s, .52 * s).translate(0, 0, .36 * s)
			ge.flat_normals()
			_mesh(ge, "bone", g)
			return g
		"cresta":
			var g := Node3D.new()
			var sw := _group(g, "sway")
			g.set_meta("sway", sw)
			for k in range(-2, 3):
				var f := _mesh(CreatureGeo.cone(.075 * s, (.95 - abs(k) * .12) * s, 6).translate(0, (.48 - abs(k) * .06) * s, 0).scale(.45, 1, 1), "iris" if k % 2 != 0 else "beak", sw)
				set_euler(f, PI / 2 - k * .33, 0, 0)
			return g
		"bulbo":
			var g := Node3D.new()
			_mesh(CreatureGeo.cylinder(.07 * s, .12 * s, .3 * s, 10).rotate_x(PI / 2).translate(0, 0, .12 * s).skinify(o, .3), "skin", g)
			var b := _mesh(CreatureGeo.ell(.22 * s, .22 * s, .24 * s, 0, 0, .42 * s), "glow", g)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return g
		"aleta":
			var g := Node3D.new()
			var sw := _group(g, "sway")
			g.set_meta("sway", sw)
			var n := 14
			var ge := CreatureGeo.new()
			for k in n:
				var y := (float(k) / (n - 1) * 2 - 1) * .8 * s
				var h := s * 1.15 * pow(maxf(0.0, 1 - pow(y / (.8 * s), 2)), .55) * (1 + .08 * sin(k * 2.4))
				ge.pos.append(Vector3(0, y, -.05))
				ge.pos.append(Vector3(0, y - h * .25, h))
				ge.skin.append_array([o.x, o.y, o.z + y, .9, o.x, o.y + h, o.z + y, .2])
				if k < n - 1:
					var q := k * 2
					ge.idx.append_array([q, q + 1, q + 2, q + 2, q + 1, q + 3])
			ge.compute_vertex_normals()
			_mesh(ge, "skin2", sw)
			return g
		"excavadora":
			var g := Node3D.new()
			_mesh(CreatureGeo.ell(.26 * s, .2 * s, .34 * s).skinify(Vector3.ZERO, .2), "skin", g)
			for x in [-.2, 0.0, .2]:
				_mesh(_cone_z(.08 * s, .8 * s, .35 * s).translate(x * s, 0, 0), "bone", g)
			return g
	return Node3D.new()


# ---------------------------------------------------------------- creator (G48)

func _sail(outline: Array, parent: Node3D, mat := "membrane") -> MeshInstance3D:
	# Curved fan with a raised centre: both faces receive the membrane backlight.
	var pts := []
	var c := Vector3.ZERO
	for p in outline:
		pts.append(v3(p))
		c += v3(p)
	c = c / outline.size() + Vector3(0, .045, 0)
	var ge := CreatureGeo.new()
	ge.pos.append(c)
	var n := 48
	for i in n:
		ge.pos.append(CreatureGeo.catmull_point(pts, float(i) / n, true, "catmullrom", .25))
	for i in n:
		ge.idx.append_array([0, i + 1, (i + 1) % n + 1])
	ge.compute_vertex_normals()
	return _tissue(ge, "membrane", parent, mat)


func _make_creator(type: String, p: Dictionary, off: Vector3, r: float, context: Dictionary) -> Node3D:
	var m := meta(type)
	var radius := r
	if m.has("body_minimum"):
		radius = max(r, float(context["body"]) * m["body_minimum"])
	var s: float = p.get("size", 1.0) * radius / .6
	if WingData.is_wing(type):
		var wp: Dictionary = WingData.params(type, p)
		if float(wp.span) > 0.0:
			s = float(p.get("size", 1.0)) * float(wp.span) / float(WingData.family(type).base_tip)   # the genome states the span in metres
	var g := _creator_shape(type, p, r, s, context)
	_scale_tree(g, s, off, true)
	if WingData.is_wing(type) and g.has_meta("wing_base"):
		g.set_meta("wing_info", WingData.info(type, p, float(g.get_meta("wing_base").area), s, 1.0))
	g.set_meta("mount_radius", r)
	g.set_meta("part_scale", s)
	return g


func _scale_tree(n: Node, s: float, off: Vector3, is_root: bool) -> void:
	if not is_root and n is Node3D:
		n.position *= s
	if n is MeshInstance3D and n.has_meta("geo"):
		var geo: CreatureGeo = n.get_meta("geo")
		geo.scale_all(s)
		geo.skinify(off, .42 if n.get_meta("material_region", "") == "membrane" else null)
	for c in n.get_children():
		_scale_tree(c, s, off, false)


# ---- wings (creature_wing.gd for the families and the optional `wing` block) -----------------------------------------

## The unit-size outlines of a wing family, the chord factor `zk` applied to z. {polys: [[Vector3]], ...}
func _wing_layout(type: String, w: Dictionary, zk: float) -> Dictionary:
	var Z := func(v: Vector3) -> Vector3: return Vector3(v.x, v.y, v.z * zk)
	var out := {"polys": [], "fingers": [], "vanes": [], "ribs": []}
	match type:
		"wing_glider":
			var fingers := [Vector3(.5, .5, .35), Vector3(1.35, .85, .15), Vector3(2.25, .9, -.5), Vector3(1.85, .6, -1.3), Vector3(.9, .25, -1.65)]
			var tail := [Vector3(.35, .06, -1.2), Vector3(0, -.12, -.8)]
			if w.anchor == "hind":
				tail = [Vector3(.4, .02, -1.65), Vector3(0, -.12, -1.25)]
			elif w.anchor == "none":
				tail = [Vector3(.3, .06, -.95), Vector3(0, -.1, -.5)]
			var outline := [Vector3(0, 0, .08), fingers[0], fingers[1], fingers[2], Vector3(1.75, .65, -.75), fingers[3], Vector3(1.25, .34, -1.15), fingers[4]] + tail
			out.polys.append(outline.map(Z))
			var n := clampi(int(w.spars), 1, 5)
			for i in n:
				out.fingers.append(Z.call(fingers[int(roundf(float(i) * 4.0 / float(maxi(n - 1, 1)))) if n > 1 else 2]))
		"wing_insect":
			var fore := [Vector3(0, 0, 0), Vector3(.7, .6, .6), Vector3(1.65, .92, .7), Vector3(2.25, 1, .35), Vector3(1.55, .65, .15), Vector3(.45, .2, -.05)]
			var hind := [Vector3(0, -.04, -.12), Vector3(.5, .1, -.45), Vector3(1.3, .4, -.75), Vector3(1.7, .48, -1.2), Vector3(1.1, .2, -1.35), Vector3(.3, -.05, -.65)]
			out.polys.append(fore.map(Z))
			out.polys.append(hind.map(Z))
			for q in [fore[2], fore[3], fore[4], hind[2], hind[3]]:
				out.fingers.append(Z.call(q))
		"wing_vane":
			# An arm panel to a wrist, then a fan of stiff vanes (each a leaf on its own hinge so the fan can close).
			out.polys.append([Vector3(0, 0, .2), Vector3(.5, .22, .28), Vector3(.95, .3, .2), Vector3(.95, .22, -.75), Vector3(.5, .1, -.8), Vector3(0, -.05, -.55)].map(Z))
			var n := clampi(int(w.spars), 1, 5)
			for i in n:
				var u := 0.5 if n == 1 else float(i) / float(n - 1)
				var psi := deg_to_rad(lerpf(10.0, -55.0, u))
				var vlen := 1.05 - 0.2 * absf(u - 0.35)
				var wd := 0.26 * zk
				out.vanes.append({"pivot": Z.call(Vector3(.95, .28, .1)), "angle": -psi, "len": vlen, "width": wd,
					"poly": [Vector3(0, 0, -wd * .5), Vector3(vlen * .5, .03, -wd * .55), Vector3(vlen, 0, 0), Vector3(vlen * .5, .03, wd * .55), Vector3(0, 0, wd * .5)]})
		"wing_flap":
			# Skin stretched on a fan of ribs from the shoulder, scalloped between the rib tips.
			var n := clampi(int(w.spars), 1, 5)
			var tips := []
			for i in n:
				var u := 0.5 if n == 1 else float(i) / float(n - 1)
				var psi := deg_to_rad(lerpf(25.0, -105.0, u))
				tips.append(Z.call(Vector3(1.6 * cos(psi), .12, 1.6 * sin(psi) + .1)))
			var outline := [Z.call(Vector3(0, 0, .1))]
			for i in n:
				outline.append(tips[i])
				if i < n - 1:
					var mid: Vector3 = ((tips[i] as Vector3) + (tips[i + 1] as Vector3)) * .5
					outline.append(Vector3(mid.x * .82, .06, (mid.z - .1 * zk) * .82 + .1 * zk))
			out.polys.append(outline)
			out.ribs = tips
	return out


func _wing_area(layout: Dictionary) -> float:
	var a := 0.0
	for poly in layout.polys:
		a += WingData.polygon_area(poly)
	for v in layout.vanes:
		a += WingData.polygon_area(v.poly)
	return a


func _wing_shape(type: String, p: Dictionary, g: Node3D) -> void:
	var w: Dictionary = WingData.params(type, p)
	var wing := _group(g, "wing")
	g.set_meta("wing", wing)
	_tissue(CreatureGeo.ell(.16, .18, .22), "skin", g)
	var zk := 1.0
	if float(w.breadth) > 0.0:
		var fam: Dictionary = WingData.family(type)
		var a0 := _wing_area(_wing_layout(type, w, 1.0))
		zk = float(w.breadth) / maxf(a0 / (float(fam.base_tip) * float(fam.base_tip)), 1e-4)
	var layout := _wing_layout(type, w, zk)
	g.set_meta("wing_base", {"area": _wing_area(layout), "zk": zk})
	match type:
		"wing_glider":
			_sail(layout.polys[0], wing, "glider")
			for f in layout.fingers:
				_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(f.x * .48, f.y * .65 + .08, f.z * .48), f], [.045, .032, .009]), "keratin", wing)
		"wing_insect":
			_sail(layout.polys[0], wing, "insect")
			_sail(layout.polys[1], wing, "insect")
			for q in layout.fingers:
				_tissue(CreatureGeo.sweep([Vector3.ZERO, q * .5, q], [.023, .016, .005]), "keratin", wing)
				_tissue(CreatureGeo.sweep([q * .45, Vector3(q.x * .72, q.y * .7, q.z * .72 + .1), Vector3(q.x * .85, q.y * .85, q.z * .85 + .14)], [.009, .007, .003]), "keratin", wing)
		"wing_vane":
			_sail(layout.polys[0], wing, "membrane")
			_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(.45, .2, .1 * zk), Vector3(.95, .28, .1 * zk)], [.05, .04, .03]), "keratin", wing)
			var nodes := []
			for v in layout.vanes:
				var vg := _group(wing, "vane")
				vg.position = v.pivot
				vg.rotation.y = v.angle
				vg.set_meta("rest_angle", v.angle)
				_sail(v.poly, vg, "membrane")
				_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(v.len * .5, .02, 0), Vector3(v.len, 0, 0)], [.02, .015, .005]), "keratin", vg)
				nodes.append(vg)
			wing.set_meta("vanes", nodes)
		"wing_flap":
			_sail(layout.polys[0], wing, "membrane")
			for t in layout.ribs:
				_tissue(CreatureGeo.sweep([Vector3(0, 0, .1 * zk), Vector3(t.x * .5, .08, (t.z - .1 * zk) * .5 + .1 * zk), t], [.04, .03, .008]), "keratin", wing)


func _creator_shape(type: String, p: Dictionary, r: float, s: float, context: Dictionary) -> Node3D:
	var g := Node3D.new()
	var size: float = p.get("size", 1.0)
	match type:
		"beak_crusher":
			var jaw := _group(g, "jaw")
			g.set_meta("jaw", jaw)
			# Start at the snout end, with a narrow skin seam and a forward hooked wedge.
			var width := .57 / maxf(1.0, size)
			var length := .6 * clampf(.8 + .2 * size, .8, 1.2) / size
			_tissue(CreatureGeo.ell(width, .36 / maxf(1.0, size), .025), "skin", g)
			for lower in [false, true]:
				var parent: Node3D = jaw if lower else g
				var ge := CreatureGeo.new()
				var rings := 21
				var sides := 24
				var L := length * (.74 if lower else 1.0)
				var edges := [[], []]
				for i in rings:
					var u := float(i) / (rings - 1)
					var z := L * u
					var w := width * pow(1 - u, .8)
					var seam := (-.075 + .035 * u) if lower else (.025 + .06 * sin(PI * u) - .18 * pow(u, 5))
					var h := (.23 if lower else .36) * (1 - u) * (.9 + .5 * sin(PI * u)) / maxf(1.0, size)
					for j in sides + 1:
						var a := float(j) / sides * PI
						ge.pos.append(Vector3(w * cos(a), seam + (-1 if lower else 1) * h * sin(a), z))
					edges[0].append(Vector3(-w, seam, z))
					edges[1].append(Vector3(w, seam, z))
				for i in rings - 1:
					for j in sides:
						var k := i * (sides + 1) + j
						ge.idx.append_array([k, k + 1, k + sides + 1, k + 1, k + sides + 2, k + sides + 1])
				if lower:
					ge.flip_winding()
				ge.compute_vertex_normals()
				var sm := _tissue(ge, "keratin", parent, "bone" if lower else "tooth")
				sm.name = "lower mandible" if lower else "upper mandible"
				for edge in edges:
					var rim := _tissue(CreatureGeo.sweep(edge, [.012, .012, .005]), "keratin", parent, "beak")
					rim.name = "cutting edge"
				if not lower:
					var tip := _tissue(ge.with_index_subset(16 * sides * 6), "keratin", parent, "beak")
					tip.name = "hook tip"
			for u: float in [.2, .4, .6]:
				var w := width * (1 - u) * .8
				_tissue(CreatureGeo.sweep([Vector3(-w, -.065, length * u), Vector3(0, -.045, length * u), Vector3(w, -.065, length * u)], [.012, .022, .012]), "keratin", jaw)
		"eye_triad":
			_tissue(CreatureGeo.ell(.48, .18, .15, 0, 0, .025), "skin", g)
			for x in [-.3, 0.0, .3]:
				var e := _group(g, "eye")
				e.position = Vector3(x, 0, .23 if x == 0.0 else .16)
				_eyeball(e, .17, Vector3.ZERO, str(p.get("pupil", "auto")))
		"wing_glider", "wing_insect", "wing_vane", "wing_flap":
			_wing_shape(type, p, g)
		"frill_fan":
			var fan := _group(g, "fan")
			g.set_meta("sway", fan)
			_tissue(CreatureGeo.ell(.2, .16, .15), "skin", g)
			var edge := []
			for i in 25:
				var a := (-110.0 + 220.0 * i / 24) * PI / 180
				edge.append(Vector3(.93 * sin(a), -.1, .18 + .93 * cos(a)))
			_sail([Vector3.ZERO] + edge, fan)
			for i in [0, 6, 12, 18, 24]:
				_tissue(CreatureGeo.sweep([Vector3.ZERO, edge[i] * .5, edge[i]], [.035, .027, .008]), "keratin", fan)
		"sac_spitter":
			_tissue(CreatureGeo.ell(.24, .18, .16, 0, -.12, -.06), "skin", g)
			var sacs := []
			for side in [-1.0, 1.0]:
				var sac := _group(g, "sac")
				sac.position = Vector3(side * .5, -.18, -.32)
				sacs.append(sac)
				_tissue(CreatureGeo.sweep([Vector3(0, -.12, -.06), Vector3(side * .3, -.16, -.25), Vector3(side * .5, -.18, -.32)], [.14, .12, .1]), "skin", g)
				_tissue(CreatureGeo.ell(.36, .37, .39), "membrane", sac, "sac")
				for z in [-.1, .15]:
					_tissue(CreatureGeo.ell(.07, .065, .07, side * .3, .09, z), "glow", sac)
			g.set_meta("sacs", sacs)
			_tissue(CreatureGeo.sweep([Vector3(0, -.13, -.04), Vector3(0, -.12, .25), Vector3(0, -.08, .55)], [.15, .1, .045]), "keratin", g)
			_tissue(CreatureGeo.ell(.046, .046, .018, 0, -.08, .55), "glow", g)
		"arm_grasper", "arm_smasher":
			var arm := _group(g, "arm")
			g.set_meta("arm", arm)
			var head: float = context["head"]
			var body: float = context["body"]
			var height: float = context["height"]
			var mouth_h: float = context["mouthHeight"]
			if type == "arm_smasher":
				_tissue(CreatureGeo.ell(.24, .25, .24), "skin", g)
				# Bent elbow carries the club up in front of the chest, clear of the knees.
				var club: float = min(body * .34 * size, head * .72) / s
				var y: float = -min(body * .12 * size, height * .1) / s
				var z := .85
				_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(.32, -.24, .08), Vector3(.55, -.38, .25)], [.2, .17, .14]), "skin", arm).name = "upper arm"
				_tissue(CreatureGeo.ell(.17, .17, .17, .55, -.38, .25), "skin", arm)
				_tissue(CreatureGeo.sweep([Vector3(.55, -.38, .25), Vector3(.65, y - .1, .55), Vector3(.6, y, z)], [.14, .13, .12]), "skin", arm).name = "forearm"
				_tissue(CreatureGeo.ell(club, club * .9, club * 1.2, .6, y, z + club * .65), "keratin", arm).name = "club head"
				for dz in [-.5, .1, .7]:
					_tissue(CreatureGeo.sweep([Vector3(.6 - club * .8, y + club * .55, z + club * (.65 + dz)), Vector3(.6, y + club * 1.05, z + club * (.65 + dz)), Vector3(.6 + club * .8, y + club * .55, z + club * (.65 + dz))], [.025, .035, .025]), "keratin", arm)
			elif mouth_h - height < head * 1.2:
				# Low bodies need an exposed shoulder below/outside the wide jaw.
				_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(.15, -.15, 0), Vector3(.3, -.3, 0)], [.2, .2, .19]), "skin", g)
				_tissue(CreatureGeo.ell(.23, .22, .23, .3, -.3, 0), "skin", g).name = "shoulder"
				arm.position = Vector3(.3, -.3, 0)
				_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(.35, -.05, .2), Vector3(.65, -.15, .45)], [.2, .17, .14]), "skin", arm).name = "upper arm"
				_tissue(CreatureGeo.ell(.17, .17, .17, .65, -.15, .45), "skin", arm)
				_tissue(CreatureGeo.sweep([Vector3(.65, -.15, .45), Vector3(.8, -.4, .8), Vector3(.7, -.65, 1.15)], [.14, .13, .11]), "skin", arm).name = "forearm"
				_tissue(CreatureGeo.ell(.21, .15, .2, .7, -.65, 1.2), "skin", arm).name = "palm"
				for side in [-1, 1]:
					_tissue(CreatureGeo.sweep([Vector3(.7 + side * .12, -.65, 1.25), Vector3(.7 + side * .29, -.61, 1.48), Vector3(.7 + side * .06, -.61, 1.69)], [.085, .06, .004]), "keratin", arm)
			else:
				_tissue(CreatureGeo.ell(.24, .25, .24), "skin", g)
				var hand := clampf((mouth_h - height - head * .4) / s, -.26, 1.6)
				var elbow := hand * .45 - .35
				_tissue(CreatureGeo.sweep([Vector3.ZERO, Vector3(.32, elbow * .6, .12), Vector3(.65, elbow, .35)], [.2, .17, .14]), "skin", arm)
				_tissue(CreatureGeo.ell(.17, .17, .17, .65, elbow, .35), "skin", arm)
				_tissue(CreatureGeo.sweep([Vector3(.65, elbow, .35), Vector3(.75, lerpf(elbow, hand, .5), .67), Vector3(.38, hand, .98)], [.14, .13, .11]), "skin", arm)
				_tissue(CreatureGeo.ell(.21, .15, .2, .38, hand, 1.03), "skin", arm)
				for side in [-1, 1]:
					_tissue(CreatureGeo.sweep([Vector3(.38 + side * .12, hand, 1.08), Vector3(.38 + side * .29, hand + .04, 1.31), Vector3(.38 + side * .06, hand + .04, 1.52)], [.085, .06, .004]), "keratin", arm)
		"tail_paddle", "tail_spike", "tail_hammer":
			var tail := _group(g, "tail")
			g.set_meta("tail", tail)
			# A tail-radius root merges with the rear 15%; the terminal organ scales
			# from max spine radius, so a slender tail never reduces it to a dot.
			_tissue(CreatureGeo.sweep([Vector3(0, 0, .025), Vector3(0, 0, -.18), Vector3(0, .02, -.45), Vector3(0, .03, -.72)], [r * .75 / s, .09, .085, .06]), "skin", tail)
			if type == "tail_paddle":
				_sail([Vector3(0, .03, -.35), Vector3(0, .48, -.67), Vector3(0, .52, -1.14), Vector3(0, .03, -1.42), Vector3(0, -.48, -1.14), Vector3(0, -.42, -.67)], tail, "glider").name = "vertical paddle"
				for side in [-1, 1]:
					_tissue(CreatureGeo.sweep([Vector3(0, .03, -.4), Vector3(0, side * .32, -.76), Vector3(0, side * .45, -1.13)], [.035, .025, .008]), "keratin", tail)
			elif type == "tail_spike":
				_tissue(CreatureGeo.ell(.19, .16, .25, 0, .03, -.77), "keratin", tail)
				for x in [-.15, 0.0, .15]:
					_tissue(CreatureGeo.sweep([Vector3(x, .07, -.85), Vector3(x * 1.4, .22, -1.15), Vector3(x * 1.7, .4, -1.48)], [.065, .045, .003]), "keratin", tail).name = "tail barb"
			else:
				_tissue(CreatureGeo.ell(.29, .23, .28, 0, .03, -.88), "keratin", tail)
				for side in [-1, 1]:
					_tissue(CreatureGeo.ell(.23, .21, .23, side * .25, .03, -.92), "keratin", tail)
					_tissue(CreatureGeo.sweep([Vector3(side * .36, .07, -.93), Vector3(side * .56, .15, -.96)], [.065, .003]), "keratin", tail)
				for x in [-.26, 0.0, .26]:
					_tissue(CreatureGeo.sweep([Vector3(x, .2, -.78), Vector3(x, .29, -.93), Vector3(x, .19, -1.1)], [.035, .045, .015]), "keratin", tail)
		_:
			if meta(type).get("fitted_leg", false):
				# Thumbnail-only shape (the creature builds fitted legs as IK chains).
				var pose := p.duplicate()
				pose["w"] = .16
				var lm := make_leg(type, pose, Vector3.ZERO, .7, .8)
				lm["lo"].position.y = -.7
				lm["ft"].position.y = -1.5
				for k in ["up", "lo", "ft"]:
					g.add_child(lm[k])
	return g


# ---------------------------------------------------------------- legs

## rig.js legMeshes(): returns {up, lo, ft} Node3D groups. `up` hangs from the
## hip along local -Y for length a, `lo` from the knee for b, `ft` sits at the sole.
func make_leg(type: String, p: Dictionary, o: Vector3, a: float, b: float) -> Dictionary:
	var w: float = p["w"]
	var kind: String = meta(type).get("foot", "garra")
	var up := Node3D.new()
	up.name = "upper"
	var lo := Node3D.new()
	lo.name = "lower"
	var ft := Node3D.new()
	ft.name = "foot"
	_mesh(CreatureGeo.cylinder(w * 1.5, w * 1.02, a, 14, 4).translate(0, -a / 2, 0).skinify(o, .15), "skin", up)
	_mesh(CreatureGeo.ell(w * 1.75, a * .42, w * 2, 0, -a * .24, 0).skinify(o, .3), "skin", up)
	_mesh(CreatureGeo.cylinder(w, w * .6, b, 14, 4).translate(0, -b / 2, 0).skinify(o, .05), "skin", lo)
	_mesh(CreatureGeo.ell(w * 1.08, w * 1.08, w * 1.08).skinify(o, .1), "skin", lo)
	if kind in ["runner", "sucker", "spring", "cloven", "gecko"]:
		_creator_foot(kind, w, o, lo, ft, b)
	elif kind == "pezuna":
		_mesh(CreatureGeo.cylinder(w * .72, w * 1.05, w * 1.1, 14).translate(0, w * .55, w * .12), "dark", ft)
		_mesh(CreatureGeo.ell(w * .75, w * .55, w * .75, 0, w * 1.1, 0).skinify(o, .05), "skin", ft)
	elif kind == "dedos":
		_mesh(CreatureGeo.ell(w * .8, w * .7, w * .8, 0, w * .6, 0).skinify(o, .05), "skin", ft)
		for cx in [-1, 0, 1, 2]:
			var c := _mesh(CreatureGeo.cone(w * .34, w * (1.8 if cx == 2 else 3.4), 8).rotate_x(PI / 2).translate(0, 0, w * (.9 if cx == 2 else 1.7)), "beak", ft)
			c.position.y = w * .3
			set_euler(c, 0, PI if cx == 2 else -cx * .6, 0)
	else:
		_mesh(CreatureGeo.ell(w * 1.2, w * .62, w * 1.8, 0, w * .5, w * .75).skinify(o, .05), "skin", ft)
		_mesh(CreatureGeo.ell(w * .7, w * .7, w * .7, 0, w * .6, 0).skinify(o, .05), "skin", ft)
		for cx in [-.75, 0.0, .75]:
			var c := _mesh(CreatureGeo.cone(w * .27, w * .95, 8).translate(0, w * .45, 0), "bone", ft)
			c.position = Vector3(cx * w, w * .3, w * (2.25 - abs(cx) * .4))
			set_euler(c, 1.85, 0, -cx * .35)
	return {"up": up, "lo": lo, "ft": ft}


func _creator_foot(kind: String, w: float, o: Vector3, lo: Node3D, ft: Node3D, b: float) -> void:
	var add := func(geo: CreatureGeo, region: String, par: Node3D = ft):
		geo.skinify(o, -.3 if region == "skin" else null)
		return _tissue(geo, region, par)
	if kind == "cloven":
		for side in [-1, 1]:
			add.call(CreatureGeo.ell(w * .68, w * .65, w * 1.15, side * w * .7, w * .65, w * .65), "keratin")
			add.call(CreatureGeo.sweep([Vector3(side * w * .7, w * 1.4, -w * .2), Vector3(side * w * .9, w * .8, -w * .85)], [w * .22, .003]), "keratin")
		add.call(CreatureGeo.ell(w, w * .7, w * .8, 0, w * 1.4, 0), "skin")
		return
	add.call(CreatureGeo.ell(w * 1.25, w * .6, w * 1.4, 0, w * .6, w * .8), "skin")
	if kind == "spring":
		add.call(CreatureGeo.sweep([Vector3(w * .6, 0, 0), Vector3(w * .65, -b * .5, -w * .3), Vector3(w * .4, -b, w * .1)], [w * .22, w * .18, w * .13]), "keratin", lo)
	var count := 5 if kind == "gecko" else (4 if kind == "sucker" else (2 if kind == "spring" else 3))
	for i in count:
		var a := (i - (count - 1) / 2.0) * (.48 if kind == "gecko" else .42)
		var L := w * (3.9 if kind == "runner" else 3.3)
		var x := sin(a) * L
		var z := w * .9 + cos(a) * L
		add.call(CreatureGeo.sweep([Vector3(0, w * .55, w * .8), Vector3(x * .65, w * .4, z * .7), Vector3(x, w * .3, z)], [w * .32, w * .24, w * .15]), "skin")
		if kind == "gecko" or kind == "sucker":
			add.call(CreatureGeo.ell(w * .6, w * .27, w * .78, x, w * .28, z), "skin")
			for dz in [-.35, 0.0, .35]:
				add.call(CreatureGeo.sweep([Vector3(x - w * .43, w * .49, z + dz * w), Vector3(x + w * .43, w * .49, z + dz * w)], [w * .055, w * .055]), "keratin")
		else:
			add.call(CreatureGeo.sweep([Vector3(x, w * .3, z), Vector3(x * 1.06, w * .18, z + w * .85)], [w * .22, .003]), "keratin")
