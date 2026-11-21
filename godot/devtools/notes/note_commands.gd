extends RefCounted
## Console commands for in-game notes: `notes`, `note show|done|add <...>`, `flag [on|off]`. The agent socket calls the same
## functions (agent_server.gd "notes", "note_done", "note_add").

const Store := preload("res://devtools/notes/note_store.gd")

static func list_text(flag, all := false) -> String:
	var ns := Store.list(flag.store_dir(), not all)
	if ns.is_empty():
		return "no %snotes" % ("" if all else "open ")
	var lines := PackedStringArray()
	for n in ns:
		lines.append("  " + Store.line(n) + ("  [done: %s]" % n.fix if n.status == "done" else ""))
	return "\n".join(lines)

## A note on the player's creature without the mouse (console and agents). Returns {ok, id|error}.
static func add(flag, text: String, tags: Array = [], sev := 2) -> Dictionary:
	var st = Game.stage
	if st == null:
		return {"ok": false, "error": "the island is not running yet"}
	var p: Dictionary = st.cur.entities[0]
	var tg := {"kind": "creature", "id": 0, "species": "player", "part": "", "name": "player #0",
		"pos": Vector3(float(p.x), float(Game.visual_ground(float(p.x), float(p.z))), float(p.z))}
	var err: String = flag.save_note(text, tags, sev, tg)
	return {"ok": err == "", "error": err, "id": flag.last_saved}

static func register(r, flag) -> void:
	r.services["notes"] = flag
	r.register("notes", "[all]", "list the open notes, newest first (all: with the done ones)", func(a):
		return r.ok(list_text(flag, a.size() > 0 and a[0] == "all")))
	r.register("note", "show <id> | done <id> [fix commit] | add <text>", "read, close or add an in-game note", func(a):
		if a.size() >= 2 and a[0] == "show":
			var n := Store.find(flag.store_dir(), a[1])
			return r.ok(JSON.stringify(n, "  ")) if not n.is_empty() else r.fail("no note '%s'" % a[1])
		if a.size() >= 2 and a[0] == "done":
			var err := Store.mark_done(flag.store_dir(), a[1], " ".join(a.slice(2)))
			flag.reload()
			return r.ok("note %s done" % a[1]) if err == "" else r.fail(err)
		if a.size() >= 2 and a[0] == "add":
			var res := add(flag, " ".join(a.slice(1)))
			return r.ok("note #%s saved" % res.id) if res.ok else r.fail(res.error)
		return r.fail("usage: note show <id> | done <id> [fix commit] | add <text>"),
		{"complete": func(i, p, t): return ["show", "done", "add"] if i == 0 else []})
	r.register("flag", "[on|off]", "flag mode (Shift+F8): click a thing in the world to leave a note on it", func(a):
		var on: bool = not flag.active
		if a.size() > 0:
			on = a[0] == "on"
		if on:
			flag.enter()
		else:
			flag.exit()
		return r.ok("flag mode " + ("on" if flag.active else "off")))
