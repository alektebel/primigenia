extends RefCounted
## What the game knew at one moment (N notes, the F11 metadata overlay, the Shift+N browser). One dictionary, `primigenia.note.meta/1`,
## stored as the "meta" object of note.json (additive to primigenia.note/1) and shown live by the overlay.
##   collect(scene) is read-only: it never touches the sim. Every field is optional; a missing system (no stage in the cell, no
##   quest in the studio) leaves its section empty instead of failing.
## Pure helpers (p95, nearby, heading, mode_of, lines) take plain data so tests need no scene.

const Scenario := preload("res://devtools/scenario.gd")

const SCHEMA := "primigenia.note.meta/1"
const TEMPERAMENTS := ["timid", "territorial", "aggressive"]
const NEARBY_MAX := 8
const NEARBY_RANGE := 60.0
const RING := 240                          # frame times kept for fps and p95 (4 s at 60 fps)
const GIT_TTL := 60000                     # ms the dirty flag is trusted before git is asked again

static var _ring := PackedFloat32Array()
static var _ring_i := 0
static var _git := {}
static var _git_at := -1000000

# --- frame times -----------------------------------------------------------------------------------------

static func sample(dt: float) -> void:
	if _ring.size() < RING:
		_ring.append(dt)
	else:
		_ring[_ring_i] = dt
		_ring_i = (_ring_i + 1) % RING

static func reset_samples() -> void:
	_ring = PackedFloat32Array()
	_ring_i = 0

## 95th percentile of `times` (seconds), in milliseconds. Nearest-rank.
static func p95_ms(times: PackedFloat32Array) -> float:
	if times.is_empty():
		return 0.0
	var s := times.duplicate()
	s.sort()
	var rank := clampi(ceili(0.95 * s.size()) - 1, 0, s.size() - 1)
	return snappedf(s[rank] * 1000.0, 0.01)

static func perf() -> Dictionary:
	var avg := 0.0
	for v in _ring:
		avg += v
	avg = avg / maxf(_ring.size(), 1.0)
	return {"fps": snappedf(1.0 / avg, 0.1) if avg > 0.0 else 0.0, "frame_ms_avg": snappedf(avg * 1000.0, 0.01), "frame_ms_p95": p95_ms(_ring),
		"samples": _ring.size()}

# --- git -------------------------------------------------------------------------------------------------

static func _git_run(args: Array) -> String:
	var out: Array = []
	var repo := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	if OS.execute("git", PackedStringArray(["-C", repo] + args), out, false) != 0 or out.is_empty():
		return ""
	return str(out[0]).strip_edges()

## {commit, dirty, text}. Cached: the commit never changes in a session, the dirty flag is refreshed at most once a minute.
static func git_info(force := false) -> Dictionary:
	var now := Time.get_ticks_msec()
	if _git.is_empty() or force or now - _git_at > GIT_TTL:
		var commit := _git_run(["rev-parse", "--short", "HEAD"])
		var dirty := false
		if commit != "":
			dirty = _git_run(["status", "--porcelain", "-uno"]) != ""
		_git = {"commit": commit if commit != "" else "unknown", "dirty": dirty, "text": Scenario.build_text()}
		_git_at = now
	return _git

# --- pure helpers ----------------------------------------------------------------------------------------

## Heading in degrees clockwise from +Z (north), 0..360, from the facing vector (fx, fz).
static func heading_deg(fx: float, fz: float) -> float:
	return snappedf(fposmod(rad_to_deg(atan2(fx, fz)), 360.0), 0.1)

static func creature_state(e: Dictionary) -> String:
	if bool(e.get("dead", false)):
		return "dead"
	if bool(e.get("hostile", false)):
		return "hostile"
	if bool(e.get("hunkered", false)):
		return "hunkered"
	if bool(e.get("sliding", false)):
		return "sliding"
	if bool(e.get("returning", false)):
		return "returning"
	if float(e.get("speed", 0.0)) > 0.4:
		return "moving"
	return "idle"

## The creatures closest to (px, pz), nearest first: {id, species, dist, state, temperament, hp, hp_max}. `names`: species id -> name.
static func nearby(entities: Array, names: Dictionary, px: float, pz: float, limit := NEARBY_MAX, max_dist := NEARBY_RANGE) -> Array:
	var rows: Array = []
	for e in entities:
		if int(e.get("id", -1)) == 0:
			continue
		var d := Vector2(float(e.x) - px, float(e.z) - pz).length()
		if d > max_dist:
			continue
		var sp := int(e.get("species", -1))
		var t := int(e.get("temperament", -1))
		rows.append({"id": int(e.id), "species": str(names.get(sp, "species %d" % sp)), "dist": snappedf(d, 0.1), "state": creature_state(e),
			"temperament": TEMPERAMENTS[t] if t >= 0 and t < TEMPERAMENTS.size() else "", "hp": snappedf(float(e.get("hp", 0.0)), 0.1),
			"hp_max": snappedf(float(e.get("hp_max", 0.0)), 0.1)})
	rows.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return rows.slice(0, limit)

## island | nest | studio | cell | flight | combat | zoo | menu, from the scene file and what the island reports.
static func mode_of(scene_path: String, fighting: bool, flying: bool, at_nest: bool) -> String:
	if scene_path.contains("/studio/"):
		return "studio"
	if scene_path.contains("cell_stage"):
		return "cell"
	if scene_path.contains("zoo"):
		return "zoo"
	if scene_path.contains("island"):
		if fighting:
			return "combat"
		if flying:
			return "flight"
		return "nest" if at_nest else "island"
	if scene_path.contains("main") or scene_path.contains("menu"):
		return "menu"
	return "island" if fighting or flying or at_nest else "other"

static func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]

static var _names := {}

static func species_names() -> Dictionary:
	if _names.is_empty() and ClassDB.class_exists("CporeWorld"):
		for s in CporeWorld.species():
			_names[int(s.id)] = str(s.name)
	return _names

static func _choice(dev, short: String) -> String:
	if dev == null or dev.tuning == null:
		return ""
	for k in dev.tuning.choice_order:
		if str(k).get_slice("/", str(k).get_slice_count("/") - 1) == short:
			return str(dev.tuning.choice_value(k))
	return ""

# --- the collector ---------------------------------------------------------------------------------------

## Everything at once. `tree` gives the scene and the Dev autoload; a null tree returns the parts that need none.
static func collect(tree: SceneTree, with_git := true) -> Dictionary:
	var scene: Node = tree.current_scene if tree != null else null
	var dev = tree.root.get_node_or_null("Dev") if tree != null else null
	var st = Game.stage
	var out := {"schema": SCHEMA, "time": Time.get_datetime_string_from_system(false), "perf": perf(),
		"render": {"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"gpu": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor()},
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]}
	out["build"] = git_info() if with_git else (_git if not _git.is_empty() else {"commit": "unknown", "dirty": false, "text": Scenario.build_text()})
	var path := scene.scene_file_path if scene != null else ""
	var fighting := false
	var flying := false
	var at_nest := false
	var ents: Array = []
	var p: Dictionary = {}
	if st != null and st.cur is Dictionary and not st.cur.is_empty():
		ents = st.cur.get("entities", [])
		fighting = int(st.cur.get("active", -1)) >= 0
		out["tick"] = int(st.cur.tick)
		out["hour"] = snappedf(fposmod(float(st.cur.tick), 12000.0) / 500.0, 0.01)
		out["paused"] = bool(st.paused)
		out["timescale"] = st.timescale
		if not ents.is_empty():
			p = ents[0]
	var flight = scene.get("flight") if scene != null else null
	if flight != null and flight.get("model") != null:
		flying = str(flight.model.mode) != "ground"
	var nest = scene.get("_nest") if scene != null else null
	if nest is Vector2 and not p.is_empty():
		var radius := float(st.cur.get("loadout", {}).get("nest_radius", 12.0))
		at_nest = (nest as Vector2).distance_to(Vector2(float(p.x), float(p.z))) <= radius
	out["mode"] = mode_of(path, fighting, flying, at_nest)
	out["scene"] = path
	if st != null and st.world != null and st.world.has_field():
		out["seed"] = int(st.world.field_info().seed)
	elif Game.settings.has("seed"):
		out["seed"] = int(Game.settings.seed)
	if not p.is_empty():
		var host = scene.hosts.get(0) if scene != null and scene.get("hosts") != null else null
		var ctl = host.driver.controller if host != null and host.get("driver") != null and host.driver != null else null
		var pl: Dictionary = st.cur.get("player", {})
		out["player"] = {"pos": [snappedf(float(p.x), 0.01), snappedf(Game.visual_ground(float(p.x), float(p.z)), 0.01), snappedf(float(p.z), 0.01)],
			"heading_deg": heading_deg(float(p.fx), float(p.fz)), "speed": snappedf(float(p.speed), 0.01),
			"gait": str(ctl.gait) if ctl != null and ctl.get("gait") != null else "", "style": _choice(dev, "style"),
			"hp": snappedf(float(p.hp), 0.1), "hp_max": snappedf(float(p.hp_max), 0.1),
			"stamina": snappedf(float(p.stamina), 0.1), "stamina_max": snappedf(float(p.stamina_max), 0.1),
			"running": bool(pl.get("running", false)), "falling": bool(pl.get("falling", false))}
		out["nearby"] = nearby(ents, species_names(), float(p.x), float(p.z))
		var social: Dictionary = st.cur.get("social", {})
		var genome: Dictionary = scene.get("_genome") if scene != null and scene.get("_genome") is Dictionary else {}
		var parts: Array = []
		for part in genome.get("parts", []):
			parts.append(str(part.get("type", "?")))
		out["creature"] = {"name": str(genome.get("name", "")), "parts": parts, "nodes": genome.get("nodes", []).size() if genome.has("nodes") else 0,
			"dna": {"total": social.get("dna_total", 0), "balance": social.get("dna_balance", 0)}, "diet": social.get("diet", -1),
			"food": social.get("food", 0), "genome": genome}
	var fq = scene.get("first_quest") if scene != null else null
	if fq != null and fq.get("quest") != null:
		var q = fq.quest
		var cur: Dictionary = q.current()
		out["quest"] = {"chain": str(q.chain.get("id", "")), "step": int(q.step), "total": q.steps().size(), "finished": q.finished(),
			"task": str(cur.get("id", "")) if not cur.is_empty() else ""}
	var cam: Camera3D = tree.root.get_viewport().get_camera_3d() if tree != null else null
	var cs := {}
	if scene != null and scene.has_method("camera_state"):
		cs = scene.camera_state().duplicate()
	if cam != null:
		cs["pos"] = _v3(cam.global_position)
		cs["angle_deg"] = [snappedf(rad_to_deg(cam.global_rotation.x), 0.1), snappedf(rad_to_deg(cam.global_rotation.y), 0.1)]
		cs["fov"] = cam.fov
	out["camera"] = cs
	out["options"] = dev.tuning.current_choices() if dev != null and dev.tuning != null else {}
	return out

# --- text ------------------------------------------------------------------------------------------------

static func _f(v, digits := 1) -> String:
	return String.num(float(v), digits)

## Whole numbers as integers: JSON gives back floats ("tick 218.0") for what was an int.
static func _i(v) -> String:
	return str(int(v)) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else str(v)

## Compact lines for the overlay, the browser and `notes.py show`. Empty sections are skipped.
static func lines(m: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if m.is_empty():
		return out
	var b: Dictionary = m.get("build", {})
	out.append("%s  tick %s  seed %s  %s" % [str(m.get("mode", "?")), _i(m.get("tick", "-")), _i(m.get("seed", "-")),
		("%s%s" % [b.get("commit", "?"), "+dirty" if bool(b.get("dirty", false)) else ""]) if not b.is_empty() else ""])
	var p: Dictionary = m.get("player", {})
	if not p.is_empty():
		var pos: Array = p.pos
		out.append("pos %s, %s, %s  head %s deg  %s m/s" % [_f(pos[0]), _f(pos[1]), _f(pos[2]), _f(p.heading_deg, 0), _f(p.speed, 2)])
		out.append("gait %s  style %s  %s" % [p.gait if p.gait != "" else "-", p.style if p.style != "" else "-", "running" if bool(p.running) else "walking"])
		out.append("hp %s/%s  stamina %s/%s" % [_f(p.hp, 0), _f(p.hp_max, 0), _f(p.stamina, 0), _f(p.stamina_max, 0)])
	var c: Dictionary = m.get("creature", {})
	if not c.is_empty():
		out.append("%s  %d parts  DNA %s (balance %s)" % [c.name, c.parts.size(), _i(c.dna.total), _i(c.dna.balance)])
	var q: Dictionary = m.get("quest", {})
	if not q.is_empty():
		out.append("quest %s  step %d/%d" % [q.task if q.task != "" else ("done" if bool(q.finished) else "-"), int(q.step) + 1, int(q.total)])
	var cam: Dictionary = m.get("camera", {})
	if cam.has("pos"):
		out.append("cam %s, %s, %s  pitch %s yaw %s" % [_f(cam.pos[0]), _f(cam.pos[1]), _f(cam.pos[2]), _f(cam.angle_deg[0], 0), _f(cam.angle_deg[1], 0)])
	var pf: Dictionary = m.get("perf", {})
	if not pf.is_empty():
		out.append("%s fps  p95 %s ms" % [_f(pf.fps, 0), _f(pf.frame_ms_p95, 1)])
	var r: Dictionary = m.get("render", {})
	if not r.is_empty():
		var w: Array = m.get("window", [0, 0])
		out.append("%s  %s  %dx%d" % [r.get("renderer", "?"), str(r.get("gpu", "?")).left(34), int(w[0]), int(w[1])])
	var o: Dictionary = m.get("options", {})
	if not o.is_empty():
		var kv := PackedStringArray()
		for k in o:
			kv.append("%s %s" % [str(k).get_slice("/", str(k).get_slice_count("/") - 1), str(o[k])])
		out.append("F10: " + " · ".join(kv))
	var nb: Array = m.get("nearby", [])
	if not nb.is_empty():
		out.append("nearby %d:" % nb.size())
		for e in nb:
			out.append("  %s #%d  %s m  %s  %s  hp %s" % [e.species, int(e.id), _f(e.dist), e.state, e.temperament, _f(e.hp, 0)])
	return out
