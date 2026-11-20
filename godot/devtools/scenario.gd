extends RefCounted
## D3 scenarios and game saves (PLAN-devtools §1.4). One scenario = <name>.json + <name>.cpstate (raw world
## snapshot) + optional <name>.log (the recipe: the session's v3 log from reset, so a state can be rebuilt
## after an engine change). Game saves are scenarios with kind "save".
##
##   build(stage, ctx, kind, name, note) -> {json, state, recipe}      pure: no files
##   save(stage, ctx, path, kind, note) -> String                       "" or one readable sentence
##   read(path) -> {ok, dict, state, recipe, error}
##   validate(dict, label) -> String                                    format / shape errors
##   load_into(parsed, stage, ctx) -> {ok, error, rebuilt, note}        restores into a running StageWorld
## ctx: {genome, camera, tuning, island ({seed, terrain_version, terrain_hash} or {}), time, build}

const WorldLog := preload("res://game/stage/world_log.gd")

const FORMAT := "primigenia.scenario/1"
const FORMAT_READS := 1
const DEV_DIR := "res://scenarios"
const USER_DIR := "user://scenarios"
## Where game saves go; tests point it elsewhere so they never touch the owner's slot.
static var save_dir := "user://saves"
const SAVE_SLOT := "slot1"
## Species with a body, by entity id, recorded so a load can dress restored entities.
const BODY_PATHS := {3: "res://game/data/garfio.json"}

static func build_text() -> String:
	var path := "res://devtools/build.txt"
	if FileAccess.file_exists(path):
		var t := FileAccess.get_file_as_string(path).strip_edges()
		if t != "":
			return t
	return "unknown"

static func iso_now() -> String:
	return Time.get_datetime_string_from_system(false)

static func build(stage, ctx: Dictionary, kind: String, scenario_name: String, note: String, with_recipe: bool = true) -> Dictionary:
	var w = stage.world
	var st: Dictionary = w.state()
	var bytes: PackedByteArray = w.snapshot()
	var d := {
		"format": FORMAT,
		"name": scenario_name, "stage": "creature", "kind": kind, "note": note, "created": iso_now(),
		"engine": {"stage_version": CporeWorld.version(), "snapshot_version": 3, "layout": w.layout(), "build": ctx.get("build", build_text())},
		"island": ctx.get("island", {}),
		"setup": _jsonable(w.get_setup()),
		"state": scenario_name.get_file() + ".cpstate", "tick": int(st.tick), "hash": st.hash,
		"genome": ctx.get("genome", {}),
		"legacy": ctx.get("legacy", {}),
		"wild_bodies": _bodies(st),
		"lineage": JSON.parse_string(w.lineage()),
		"camera": ctx.get("camera", {}),
		"plants": ctx.get("plants", []),
		"tuning": ctx.get("tuning", {}),
		"time": ctx.get("time", {"timescale": stage.timescale, "paused": stage.paused}),
	}
	var recipe := ""
	if with_recipe and kind != "save" and stage.start_snapshot.size() == 0:
		recipe = stage.export_log()
		d["recipe"] = scenario_name.get_file() + ".log"
	return {"json": d, "state": bytes, "recipe": recipe}

static func _bodies(st: Dictionary) -> Dictionary:
	var out := {}
	for e in st.entities.slice(1):
		if BODY_PATHS.has(int(e.species)):
			out[str(int(e.id))] = BODY_PATHS[int(e.species)]
	return out

# JSON cannot hold Vector2/Vector3: setup dictionaries are stored with arrays and restored on load.
static func _jsonable(setup: Dictionary) -> Dictionary:
	var s := setup.duplicate(true)
	if s.has("nest") and s.nest is Vector2:
		s.nest = [s.nest.x, s.nest.y]
	if s.has("water") and s.water is Vector3:
		s.water = [s.water.x, s.water.y, s.water.z]
	return s

static func resolve(name_or_path: String, extension: String = ".json") -> String:
	var n := name_or_path
	if n.begins_with("/") or n.begins_with("user://") or n.begins_with("res://"):
		return n if n.ends_with(extension) else n + extension
	for base in [DEV_DIR, USER_DIR, save_dir]:
		var p: String = "%s/%s%s" % [base, n, extension]
		if FileAccess.file_exists(p):
			return p
	return "%s/%s%s" % [DEV_DIR, n, extension]

## Names of every scenario under res://scenarios and user://scenarios ("creature/garfio_close").
static func list_names() -> PackedStringArray:
	var out := PackedStringArray()
	for base in [DEV_DIR, USER_DIR]:
		_scan(base, "", out)
	out.sort()
	return out

static func _scan(base: String, rel: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(base if rel == "" else base + "/" + rel)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(base, sub if rel == "" else rel + "/" + sub, out)
	for f in dir.get_files():
		if f.ends_with(".json"):
			var n: String = (rel + "/" if rel != "" else "") + f.get_basename()
			if not out.has(n):
				out.append(n)

static func save(stage, ctx: Dictionary, path: String, kind: String, note: String) -> String:
	var base := path.trim_suffix(".json")
	var built := build(stage, ctx, kind, base.get_file(), note)
	var dir := base.get_base_dir()
	var real := ProjectSettings.globalize_path(dir) if dir.begins_with("res://") or dir.begins_with("user://") else dir
	if DirAccess.make_dir_recursive_absolute(real) != OK and not DirAccess.dir_exists_absolute(real):
		return "cannot create %s" % dir
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	if f == null:
		return "cannot write %s.json (error %d)" % [base, FileAccess.get_open_error()]
	f.store_string(JSON.stringify(built.json, "\t"))
	f.close()
	var s := FileAccess.open(base + ".cpstate", FileAccess.WRITE)
	if s == null:
		return "cannot write %s.cpstate" % base
	s.store_buffer(built.state)
	s.close()
	if built.recipe != "":
		var r := FileAccess.open(base + ".log", FileAccess.WRITE)
		if r == null:
			return "cannot write %s.log" % base
		r.store_string(built.recipe)
		r.close()
	return ""

static func read(path: String) -> Dictionary:
	var jp := resolve(path)
	if not FileAccess.file_exists(jp):
		return {"ok": false, "error": "scenario %s: no such file (looked for %s)" % [path, jp]}
	var v = JSON.parse_string(FileAccess.get_file_as_string(jp))
	if typeof(v) != TYPE_DICTIONARY:
		return {"ok": false, "error": "scenario %s: not a JSON object" % jp.get_file()}
	var err := validate(v, jp.get_file())
	if err != "":
		return {"ok": false, "error": err}
	var base := jp.get_base_dir()
	var sp: String = base.path_join(str(v.state))
	if not FileAccess.file_exists(sp):
		return {"ok": false, "error": "scenario %s: its state file %s is missing; re-save the scenario or restore the file" % [jp.get_file(), str(v.state)]}
	var recipe := ""
	if v.has("recipe") and FileAccess.file_exists(base.path_join(str(v.recipe))):
		recipe = FileAccess.get_file_as_string(base.path_join(str(v.recipe)))
	return {"ok": true, "dict": v, "state": FileAccess.get_file_as_bytes(sp), "recipe": recipe, "path": jp, "error": ""}

static func validate(d: Dictionary, label: String = "scenario") -> String:
	var fmt := str(d.get("format", ""))
	if not fmt.begins_with("primigenia.scenario/"):
		return "scenario %s: not a Primigenia scenario (format '%s')" % [label, fmt]
	var ver := fmt.get_slice("/", 1).to_int()
	if ver > FORMAT_READS:
		return "scenario %s: format %s is newer than this build (reads /%d)" % [label, fmt, FORMAT_READS]
	for k in ["name", "stage", "kind", "state", "tick", "hash", "setup"]:
		if not d.has(k):
			return "scenario %s: the field '%s' is missing" % [label, k]
	if str(d.stage) != "creature":
		return "scenario %s: made for the '%s' stage; this build only has the creature stage" % [label, d.stage]
	return ""

## Restores `parsed` (read()) into the running StageWorld. The island must already be the right one
## (see island_error). On an engine/layout mismatch with a recipe the state is rebuilt from the recipe.
static func load_into(parsed: Dictionary, stage, ctx: Dictionary = {}) -> Dictionary:
	var d: Dictionary = parsed.dict
	var label: String = str(parsed.get("path", d.get("name", "scenario"))).get_file()
	var ge := genome_error(d.get("genome", {}))
	if ge != "":
		return {"ok": false, "error": "scenario %s: the embedded genome was rejected: %s" % [label, ge], "rebuilt": false}
	var ie := island_error(d, stage, label)
	if ie != "":
		return {"ok": false, "error": ie, "rebuilt": false}
	var rc: int = stage.restore_from(parsed.state)
	if rc == 0:
		if stage.world.state().hash != str(d.hash):
			return {"ok": false, "error": "scenario %s: its .json and .cpstate disagree (hash %s vs %s); re-save it" % [label, d.hash, stage.world.state().hash], "rebuilt": false}
		_apply_time(d, stage)
		return {"ok": true, "error": "", "rebuilt": false, "note": ""}
	var msg: String = CporeWorld.snapshot_error(rc)
	if (rc == -3 or rc == -4) and parsed.get("recipe", "") != "":
		var rec: Dictionary = WorldLog.parse(parsed.recipe)
		if not rec.ok:
			return {"ok": false, "error": "scenario %s: %s, and its recipe does not parse (%s)" % [label, msg, rec.error], "rebuilt": false}
		var rrc: int = stage.replay_recipe(rec)
		if rrc != 0:
			return {"ok": false, "error": "scenario %s: %s, and its recipe was rejected by this engine (%d)" % [label, msg, rrc], "rebuilt": false}
		_apply_time(d, stage)
		return {"ok": true, "error": "", "rebuilt": true,
			"note": "state rebuilt from the recipe under engine v%d; check it still shows what it should, then F5 to re-save" % CporeWorld.version()}
	return {"ok": false, "error": "scenario %s: %s" % [label, msg], "rebuilt": false}

static func _apply_time(d: Dictionary, stage) -> void:
	var tm: Dictionary = d.get("time", {})
	stage.timescale = float(tm.get("timescale", 1.0))
	stage.paused = bool(tm.get("paused", false))

## "" when the genome is empty (the island keeps the current creature) or the creature module accepts it.
static func genome_error(genome: Dictionary) -> String:
	if genome.is_empty():
		return ""
	var path := "res://creature/creature.gd"
	if not ResourceLoader.exists(path):
		return ""
	var script = load(path)
	if script == null or not script.has_method("parse_genome"):
		return ""
	var r = script.parse_genome(JSON.stringify(genome))
	if typeof(r) == TYPE_DICTIONARY and r.get("ok", false):
		return ""
	return str(r.get("error", "not a valid creature genome")) if typeof(r) == TYPE_DICTIONARY else "not a valid creature genome"

## "" when the running island is the one the scenario was made on (or it names none).
static func island_error(d: Dictionary, stage, label: String) -> String:
	var isl: Dictionary = d.get("island", {})
	if isl.is_empty():
		var terrain := int(d.get("setup", {}).get("terrain", 0))
		if terrain == 2:
			return "scenario %s: it needs an island (terrain 2) but records none" % label
		return ""
	var cur: Dictionary = stage.world.field_info() if stage.world.has_field() else {}
	if cur.is_empty():
		return "scenario %s: made on island seed %s, but this session has no island field attached" % [label, isl.get("seed", "?")]
	if str(cur.hash) != str(isl.terrain_hash):
		return "scenario %s: made on island version %s (hash %s), this build generates %s" % [label, isl.get("terrain_version", "?"), isl.terrain_hash, cur.hash]
	return ""
