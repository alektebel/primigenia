extends RefCounted
## Console commands of the owner questions: `questions [all]` lists the pending ones (all: with the answered), `ask <id>` shows one now. The agent socket has the same as
## {"cmd":"questions"}, {"cmd":"ask","id":..}.

const Store := preload("res://devtools/questions/question_store.gd")

static func list_text(card, all := false) -> String:
	card.reload()
	var lines := PackedStringArray()
	for q in card.pending():
		lines.append("  " + Store.line(q))
	if all:
		for a in Store.load_answers(card.store_dir()):
			lines.append("  answered #%s: %s" % [a.id, a.label if str(a.label) != "" else str(a.text)])
	return "\n".join(lines) if not lines.is_empty() else "no pending questions"

static func register(r, card) -> void:
	r.services["questions"] = card
	r.register("questions", "[all]", "list the pending owner questions (all: with the answered ones)", func(a):
		return r.ok(list_text(card, a.size() > 0 and a[0] == "all")))
	r.register("ask", "<id>", "show an owner question card now (1-4 answer, T text, Tab shows it, L later, Esc dismisses)", func(a):
		if a.size() < 1:
			return r.fail("usage: ask <id>")
		var err: String = card.ask(a[0])
		return r.ok("asking #%s" % card.current.id) if err == "" else r.fail(err),
		{"complete": func(i, p, t): return card.pending().map(func(q): return q.id) if i == 0 else []})
