extends RefCounted
const TestIsolation := preload("res://devtools/test_isolation.gd")
## Owner questions inside the game (docs/briefs/owner-questions.md). The queue is <repo>/feedback/questions/pending.json
## (git-ignored; falls back to user://feedback/questions; `--questions-dir=<path>` overrides) as {"schema": "primigenia.questions/1", "questions": [...]} ("format" is read too);
## the answers are appended to answers.jsonl next to it. Pure file and rule functions: no scene needed, tools/feedback/questions.py
## reads and writes the same files (keep them in sync).
##
## A question: {id, text, context, options: [{label, desc, recommended?}] (2 to 4), allow_free_text,
##   where?: {scenario?: name, opts?: {key: value}, pos?: [x, z]}, when?: "now" | "on_event:<name>" | "after_minutes:N"}.

const FORMAT := "primigenia.questions/1"
const MAX_OPTIONS := 4
## Between two cards (unless `when` is "now"): 3 minutes, a starting value the owner can change (tests: test_questions.gd).
const MIN_GAP_SEC := 180.0

static func questions_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--questions-dir="):
			return a.substr(16)
	if TestIsolation.active():
		return TestIsolation.dir_for("questions")
	var repo := ProjectSettings.globalize_path("res://").path_join("../feedback/questions").simplify_path()
	if OS.is_debug_build() and not OS.has_feature("template"):
		if DirAccess.make_dir_recursive_absolute(repo) == OK and FileAccess.open(repo.path_join(".w"), FileAccess.WRITE) != null:
			DirAccess.remove_absolute(repo.path_join(".w"))
			return repo
	return ProjectSettings.globalize_path("user://feedback/questions")

static func pending_path(base: String) -> String:
	return base.path_join("pending.json")

static func answers_path(base: String) -> String:
	return base.path_join("answers.jsonl")

## A question cleaned up to the format, or {} when it is unusable (no id, no text, fewer than 2 or more than 4 options without free text).
static func normalize(q) -> Dictionary:
	if typeof(q) != TYPE_DICTIONARY or str(q.get("id", "")) == "" or str(q.get("text", "")) == "":
		return {}
	var opts: Array = []
	for o in q.get("options", []):
		if typeof(o) == TYPE_DICTIONARY and str(o.get("label", "")) != "":
			opts.append({"label": str(o.label), "desc": str(o.get("desc", o.get("description", ""))), "recommended": bool(o.get("recommended", false))})
		elif typeof(o) == TYPE_STRING and str(o) != "":
			opts.append({"label": str(o), "desc": "", "recommended": false})
	opts = opts.slice(0, MAX_OPTIONS)
	var free := bool(q.get("allow_free_text", false))
	if opts.size() < 2 and not free:
		return {}
	var out := {"id": str(q.id), "text": str(q.text), "context": str(q.get("context", "")), "options": opts, "allow_free_text": free,
		"when": str(q.get("when", "")), "where": q.get("where", {}) if typeof(q.get("where", {})) == TYPE_DICTIONARY else {}}
	return out

static func load_pending(base: String) -> Array:
	var p := pending_path(base)
	if not FileAccess.file_exists(p):
		return []
	var v = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(v) != TYPE_DICTIONARY or v.get("schema", v.get("format")) != FORMAT:
		return []
	var out: Array = []
	for q in v.get("questions", []):
		var n := normalize(q)
		if not n.is_empty():
			out.append(n)
	return out

static func save_pending(base: String, qs: Array) -> bool:
	if DirAccess.make_dir_recursive_absolute(base) != OK:
		return false
	var f := FileAccess.open(pending_path(base), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"schema": FORMAT, "questions": qs}, "\t") + "\n")
	f.close()
	return true

static func load_answers(base: String) -> Array:
	var out: Array = []
	var p := answers_path(base)
	if not FileAccess.file_exists(p):
		return out
	for ln in FileAccess.get_file_as_string(p).split("\n", false):
		var v = JSON.parse_string(ln)
		if typeof(v) == TYPE_DICTIONARY and str(v.get("id", "")) != "":
			out.append(v)
	return out

static func answered_ids(base: String) -> Dictionary:
	var d := {}
	for a in load_answers(base):
		d[str(a.id)] = true
	return d

## Pending questions that have no answer yet, in file order.
static func open_questions(base: String) -> Array:
	var done := answered_ids(base)
	return load_pending(base).filter(func(q): return not done.has(q.id))

## One answer line. `option` is 1-based (0 for a free-text answer); `ctx`: {tick, options (the active F10 choices), screenshot, note}.
static func make_answer(q: Dictionary, option: int, text: String, ctx: Dictionary) -> Dictionary:
	var label := ""
	if option >= 1 and option <= q.options.size():
		label = str(q.options[option - 1].label)
	return {"id": q.id, "option": option, "label": label, "text": text, "answered": Time.get_datetime_string_from_system(false),
		"tick": int(ctx.get("tick", 0)), "options": ctx.get("options", {}), "screenshot": str(ctx.get("screenshot", "")),
		"note": str(ctx.get("note", ""))}

static func append_answer(base: String, ans: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(base) != OK:
		return false
	var p := answers_path(base)
	var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
	if f == null:
		return false
	f.seek_end()
	f.store_string(JSON.stringify(ans) + "\n")
	f.close()
	return true

# --- timing rules ---------------------------------------------------------------------------------------------

## "now" / "on_event:<name>" / "after_minutes:N" -> {kind, arg}. An empty or unknown `when` is a plain question ("any").
static func parse_when(w: String) -> Dictionary:
	if w == "now":
		return {"kind": "now", "arg": ""}
	if w.begins_with("on_event:") and w.length() > 9:
		return {"kind": "event", "arg": w.substr(9)}
	if w.begins_with("after_minutes:") and w.substr(14).is_valid_float():
		return {"kind": "minutes", "arg": w.substr(14).to_float()}
	return {"kind": "any", "arg": ""}

## Is the question's own condition met? ctx: {session_sec, events: {name: true}}.
static func condition_met(q: Dictionary, ctx: Dictionary) -> bool:
	var w := parse_when(str(q.get("when", "")))
	match w.kind:
		"event":
			return ctx.get("events", {}).has(w.arg)
		"minutes":
			return float(ctx.get("session_sec", 0.0)) >= float(w.arg) * 60.0
	return true

## The next card to show, or {}. ctx: {now, last_shown (seconds, -1 never), showing, dismissed: {id: true}, session_sec, events}.
## One card at a time; a `now` question ignores the 3-minute gap and goes first.
static func pick_next(open: Array, ctx: Dictionary) -> Dictionary:
	if bool(ctx.get("showing", false)):
		return {}
	var dismissed: Dictionary = ctx.get("dismissed", {})
	var last := float(ctx.get("last_shown", -1.0))
	var gap_ok := last < 0.0 or float(ctx.get("now", 0.0)) - last >= MIN_GAP_SEC
	var later := {}
	for q in open:
		if dismissed.has(q.id) or not condition_met(q, ctx):
			continue
		if parse_when(str(q.get("when", ""))).kind == "now":
			return q
		if later.is_empty() and gap_ok:
			later = q
	return later

static func find(qs: Array, id: String) -> Dictionary:
	for q in qs:
		if q.id == id or (id.length() >= 3 and str(q.id).begins_with(id)):
			return q
	return {}

## One line for the console and the pause list: "#id  text  (when)".
static func line(q: Dictionary) -> String:
	var w := str(q.get("when", ""))
	return "#%s  %s%s" % [q.id, q.text, ("  [%s]" % w) if w != "" else ""]
