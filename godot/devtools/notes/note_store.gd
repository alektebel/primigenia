extends RefCounted
const TestIsolation := preload("res://devtools/test_isolation.gd")
## In-game notes on flagged things (DT-NOTE, docs/briefs/dev-options.md phase 2). One folder per note under
## <repo>/feedback/notes/ (git-ignored) or user://feedback/notes/: note.json (primigenia.note/1), screenshot.jpg, crop.jpg, the scenario
## of that moment (scenario.json/.cpstate/.log), and one line per note in index.jsonl next to the folders.
## Pure file functions: no scene needed, tools/feedback/notes.py reads the same files.

const FORMAT := "primigenia.note/1"
const TAGS := ["bug", "look", "motion", "idea", "lore"]          # the Shift+F8 box cycles these
const QUICK_TAGS := ["bug", "movement", "look", "ui", "idea", "balance"]   # the N card toggles these (Ctrl+1..6)
const ALL_TAGS := ["bug", "look", "motion", "idea", "lore", "movement", "ui", "balance"]
const KINDS := ["creature", "plant", "prop", "terrain", "water", "state"]

## Folder holding all notes: --notes-dir=<path>, else <repo>/feedback/notes when writable, else user://feedback/notes.
static func notes_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--notes-dir="):
			return a.substr(12)
	if TestIsolation.active():
		return TestIsolation.dir_for("notes")
	var repo := ProjectSettings.globalize_path("res://").path_join("../feedback/notes").simplify_path()
	if OS.is_debug_build() and not OS.has_feature("template"):
		if DirAccess.make_dir_recursive_absolute(repo) == OK and FileAccess.open(repo.path_join(".w"), FileAccess.WRITE) != null:
			DirAccess.remove_absolute(repo.path_join(".w"))
			return repo
	return ProjectSettings.globalize_path("user://feedback/notes")

static func new_id() -> String:
	return "%06x" % (randi() & 0xFFFFFF)

static func stamp_now() -> String:
	return Time.get_datetime_string_from_system(false).replace("-", "").replace(":", "").replace("T", "-")

## A note dictionary. `target`: {kind, id, species, part, name}; `pos`: world Vector3.
static func make(text: String, tags: Array, severity: int, target: Dictionary, pos: Vector3, ctx: Dictionary) -> Dictionary:
	var id := str(ctx.get("id", new_id()))
	var note := {
		"format": FORMAT, "id": id, "created": Time.get_datetime_string_from_system(false), "stamp": str(ctx.get("stamp", stamp_now())),
		"text": text, "tags": tags.filter(func(t): return ALL_TAGS.has(t)), "severity": clampi(severity, 1, 3),
		"target": {"kind": str(target.get("kind", "terrain")), "id": target.get("id", -1), "species": str(target.get("species", "")),
			"part": str(target.get("part", "")), "name": str(target.get("name", ""))},
		"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
		"tick": int(ctx.get("tick", 0)), "hour": snappedf(float(ctx.get("hour", 0.0)), 0.01),
		"camera": ctx.get("camera", {}), "options": ctx.get("options", {}), "build": str(ctx.get("build", "unknown")),
		"status": "open", "fix": "", "unix_ms": int(ctx.get("unix_ms", Time.get_unix_time_from_system() * 1000.0)),
	}
	# primigenia.note/1 stays: "meta" (devtools/notes/note_meta.gd) and "origin" (n, quick, flag) are additive, old readers ignore them.
	if ctx.has("meta") and not ctx.meta.is_empty():
		note["meta"] = ctx.meta
	if ctx.has("origin"):
		note["origin"] = str(ctx.origin)
	return note

static func folder_name(note: Dictionary) -> String:
	return "%s-%s" % [note.stamp, note.id]

## Writes note.json and the index line into `base`/<stamp>-<id>/. Returns the folder, or "" when it could not be written.
static func write(base: String, note: Dictionary) -> String:
	var dir := base.path_join(folder_name(note))
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	if not _store(dir.path_join("note.json"), JSON.stringify(note, "\t")):
		return ""
	var line := JSON.stringify(index_row(note))
	var idx := base.path_join("index.jsonl")
	var old := FileAccess.get_file_as_string(idx) if FileAccess.file_exists(idx) else ""
	return dir if _store(idx, old + line + "\n") else ""

static func index_row(note: Dictionary) -> Dictionary:
	return {"id": note.id, "stamp": note.stamp, "text": note.text, "tags": note.tags, "severity": note.severity, "kind": note.target.kind,
		"target": note.target.name, "status": note.status}

static func _store(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true

## Newest-first order: the stamp (seconds), then the millisecond clock when the note has one (rapid Ctrl+N), then the id.
static func _key(n: Dictionary) -> String:
	return "%s-%015d-%s" % [n.stamp, int(n.get("unix_ms", 0)), n.id]

## All notes (full note.json), newest first. open_only: only status "open".
static func list(base: String, open_only := false) -> Array:
	var out: Array = []
	var dir := DirAccess.open(base)
	if dir == null:
		return out
	for sub in dir.get_directories():
		var p := base.path_join(sub).path_join("note.json")
		if FileAccess.file_exists(p):
			var v = JSON.parse_string(FileAccess.get_file_as_string(p))
			if typeof(v) == TYPE_DICTIONARY and v.get("format") == FORMAT and (not open_only or v.get("status") == "open"):
				out.append(v)
	out.sort_custom(func(a, b): return _key(a) > _key(b))
	return out

static func find(base: String, id: String) -> Dictionary:
	for n in list(base):
		if str(n.id) == id or str(n.id).begins_with(id) and id.length() >= 3:
			return n
	return {}

## Rewrites note.json (and the index) after an edit. Returns "" or an error sentence.
static func save_edit(base: String, note: Dictionary) -> String:
	var dir := base.path_join(folder_name(note))
	if not _store(dir.path_join("note.json"), JSON.stringify(note, "\t")):
		return "could not write " + dir
	var rows := PackedStringArray()
	for n in list(base):
		rows.append(JSON.stringify(index_row(n)))
	rows.reverse()
	return "" if _store(base.path_join("index.jsonl"), "\n".join(rows) + "\n") else "could not write the index"

static func mark_done(base: String, id: String, fix := "") -> String:
	var n := find(base, id)
	if n.is_empty():
		return "no note '%s'" % id
	n.status = "done"
	n.fix = fix
	return save_edit(base, n)

## One line for the console / HUD: "#a1b2c3 [bug 2] text (creature Garfio #1)".
static func line(n: Dictionary) -> String:
	if str(n.text) == "":
		n = n.duplicate()
		n.text = "(no text)"
	return "#%s [%s %d] %s (%s %s)" % [n.id, ",".join(PackedStringArray(n.tags)) if not n.tags.is_empty() else "-", int(n.severity), n.text, n.target.kind, n.target.name]
