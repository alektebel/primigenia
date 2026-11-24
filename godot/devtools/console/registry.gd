extends RefCounted
## Command registry of the dev console (D1). `execute(text)` is pure with respect to the UI: the console,
## the agent socket and the tests all call it, so a command behaves the same everywhere.
##
##   register(name, args_spec, help, fn, opts)   fn(args: PackedStringArray) -> {ok, out, error}
##   opts: dev (default true: hidden when Dev tools are off), sandbox (false), changes_sim (false),
##         complete: Callable(arg_index, prefix, tokens) -> Array of strings
## Commands that change the simulation build a debug op or an order; nothing writes C state otherwise.

const TestIsolation := preload("res://devtools/test_isolation.gd")
const HISTORY_MAX := 50

var commands := {}
var history: PackedStringArray = PackedStringArray()
var services := {}          # modules register themselves here: "sites", "scenarios", "tuning"
var flags := {}             # console-wide presentation switches (reveal, ...)
var stage_provider: Callable = Callable()   # () -> StageWorld or null
var dev_enabled := true

static func ok(out: String = "") -> Dictionary:
	return {"ok": true, "out": out, "error": ""}

static func fail(error: String) -> Dictionary:
	return {"ok": false, "out": "", "error": error}

func stage():
	return stage_provider.call() if stage_provider.is_valid() else null

func register(cmd: String, args_spec: String, help: String, fn: Callable, opts: Dictionary = {}) -> void:
	commands[cmd] = {"name": cmd, "args": args_spec, "help": help, "fn": fn, "dev": bool(opts.get("dev", true)),
		"sandbox": bool(opts.get("sandbox", false)), "changes_sim": bool(opts.get("changes_sim", false)),
		"complete": opts.get("complete", Callable())}

## Splits on whitespace; "double quotes" keep spaces inside one token.
static func tokenize(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var quoted := false
	var has := false
	for c in text:
		if c == "\"":
			quoted = not quoted
			has = true
		elif (c == " " or c == "\t") and not quoted:
			if has:
				out.append(cur)
			cur = ""
			has = false
		else:
			cur += c
			has = true
	if has:
		out.append(cur)
	return out

func execute(text: String) -> Dictionary:
	var line := text.strip_edges()
	if line == "":
		return ok("")
	var tok := tokenize(line)
	if tok.is_empty():
		return ok("")
	var name := tok[0].to_lower()
	var args := tok.slice(1)
	var res: Dictionary
	if not commands.has(name):
		res = fail("unknown command '%s' (try: help)" % name)
	else:
		var c: Dictionary = commands[name]
		if c.dev and not dev_enabled:
			res = fail("'%s' is a dev command and dev tools are off (--dev turns them on)" % name)
		else:
			var r = c.fn.call(args)
			res = r if r is Dictionary else ok(str(r) if r != null else "")
	_remember(line)
	return res

func _remember(line: String) -> void:
	if history.size() > 0 and history[history.size() - 1] == line:
		return
	history.append(line)
	while history.size() > HISTORY_MAX:
		history.remove_at(0)

## Candidates for the last token of `line` (command names first, then the command's argument completer).
func complete(line: String) -> Array:
	var tok := tokenize(line)
	var ends_space := line.ends_with(" ")
	if tok.is_empty() or (tok.size() == 1 and not ends_space):
		var prefix := tok[0].to_lower() if tok.size() == 1 else ""
		var out := []
		for n in commands:
			if n.begins_with(prefix) and (dev_enabled or not commands[n].dev):
				out.append(n)
		out.sort()
		return out
	var name := tok[0].to_lower()
	if not commands.has(name):
		return []
	var idx := tok.size() - 1 if not ends_space else tok.size()
	var prefix2 := tok[tok.size() - 1] if not ends_space else ""
	var comp: Callable = commands[name].complete
	if not comp.is_valid():
		return []
	var cands: Array = comp.call(idx - 1, prefix2, tok.slice(1))
	var out2 := []
	for c in cands:
		if str(c).to_lower().begins_with(prefix2.to_lower()):
			out2.append(str(c))
	return out2

func help_text(name: String = "") -> String:
	if name != "":
		if not commands.has(name):
			return "no command '%s'" % name
		var c: Dictionary = commands[name]
		return "%s %s\n  %s" % [name, c.args, c.help]
	var names := commands.keys()
	names.sort()
	var lines := PackedStringArray()
	for n in names:
		var c: Dictionary = commands[n]
		if c.dev and not dev_enabled:
			continue
		lines.append("  %-10s %-26s %s" % [n, c.args, c.help])
	return "\n".join(lines)

func load_history(path: String = "") -> void:
	if path == "":
		path = TestIsolation.user("console_history.txt")
	if not FileAccess.file_exists(path):
		return
	history = PackedStringArray()
	for l in FileAccess.get_file_as_string(path).split("\n", false):
		history.append(l)

func save_history(path: String = "") -> void:
	if path == "":
		path = TestIsolation.user("console_history.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(history) + "\n")
