extends RefCounted
# Owner questions: queue load, the timing rules, answer write, input suspension, `when` triggers, the opts preview, console, and the
# tools/feedback/questions.py round trip.

const Store := preload("res://devtools/questions/question_store.gd")
const Cmds := preload("res://devtools/questions/question_commands.gd")
const CmdReg := preload("res://devtools/console/registry.gd")
const NotesTest := preload("res://devtools/tests/test_options.gd")
const DIR := "user://devtools-test/questions"

static func q(id: String, when := "", extra := {}) -> Dictionary:
	var d := {"id": id, "text": "Question %s?" % id, "context": "ctx", "when": when, "allow_free_text": true,
		"options": [{"label": "Yes", "desc": "go", "recommended": true}, {"label": "No", "desc": ""}]}
	d.merge(extra, true)
	return d

func run(t) -> void:
	var base := ProjectSettings.globalize_path(DIR)
	_wipe(base)
	# --- normalize and load
	t.eq(Store.normalize({"id": "a", "text": "t", "options": [{"label": "x"}]}), {}, "one option and no free text is unusable")
	t.check(not Store.normalize({"id": "a", "text": "t", "options": [], "allow_free_text": true}).is_empty(), "free text alone is a question")
	t.eq(Store.normalize(q("a", "", {"options": ["1", "2", "3", "4", "5"]})).options.size(), 4, "at most four options")
	t.eq(Store.load_pending(base), [], "no file, no queue")
	t.check(Store.save_pending(base, [q("a"), q("b", "now"), {"id": "bad"}]), "the queue is written")
	t.eq(Store.load_pending(base).size(), 2, "load drops the unusable item")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Store.pending_path(base)))
	t.eq(raw.schema, "primigenia.questions/1", "the wrapper is {schema, questions}")
	# --- when parsing and the timing rules
	t.eq(Store.parse_when("on_event:quest_done:hunt"), {"kind": "event", "arg": "quest_done:hunt"}, "on_event keeps the colon in the name")
	t.eq(Store.parse_when("after_minutes:5").kind, "minutes", "after_minutes")
	t.eq(Store.parse_when("").kind, "any", "empty when is any")
	var open := [Store.normalize(q("a")), Store.normalize(q("b", "after_minutes:10")), Store.normalize(q("c", "on_event:first_evolve")), Store.normalize(q("n", "now"))]
	var ctx := {"now": 100.0, "last_shown": -1.0, "showing": false, "dismissed": {}, "session_sec": 100.0, "events": {}}
	t.eq(Store.pick_next(open, ctx).id, "n", "a `now` question goes first")
	t.eq(Store.pick_next(open, ctx.merged({"showing": true}, true)), {}, "one card at a time")
	t.eq(Store.pick_next(open, ctx.merged({"dismissed": {"n": true}}, true)).id, "a", "a plain question when nothing else is due")
	t.eq(Store.pick_next(open, ctx.merged({"last_shown": 10.0, "dismissed": {"n": true}}, true)), {}, "within 3 minutes of the last card nothing pops")
	t.eq(Store.pick_next(open, ctx.merged({"last_shown": 10.0}, true)).id, "n", "but `now` ignores the gap")
	t.eq(Store.pick_next(open, ctx.merged({"last_shown": 10.0, "now": 191.0, "dismissed": {"n": true}}, true)).id, "a", "after 3 minutes the next one shows")
	var late := [open[1]]
	t.eq(Store.pick_next(late, ctx), {}, "after_minutes waits")
	t.eq(Store.pick_next(late, ctx.merged({"session_sec": 601.0}, true)).id, "b", "and shows once the minutes passed")
	var ev := [open[2]]
	t.eq(Store.pick_next(ev, ctx), {}, "an event question waits for the event")
	t.eq(Store.pick_next(ev, ctx.merged({"events": {"first_evolve": true}}, true)).id, "c", "and shows when it fires")
	# --- the card: answers, suspension, events through the shared signal
	var card = Dev.questions
	var old_base: String = card.base_dir
	card.base_dir = base
	card.open = []
	card.current = {}
	card.dismissed = {}
	card.events = {}
	card.last_shown = -1.0
	card.session_sec = 0.0
	Store.save_pending(base, [q("a"), q("b", "on_event:quest_done:hunt"), q("f", "now", {"where": {"opts": {"light": "dusk"}}})])
	card.reload()
	t.eq(card.pending_count(), 3, "three pending")
	card.tick(1.0)
	t.eq(card.current.get("id", ""), "f", "the `now` card pops first")
	t.check(not Game.options_open, "a card does not suspend the game")
	t.eq(NotesTest.key(KEY_9).keycode, KEY_9, "helper")
	t.check(card.handle_key(NotesTest.key(KEY_3)) and not card.current.is_empty(), "a key beyond the options is eaten and ignored")
	# preview of the opts
	var applied := []
	var old_tn = Dev.tuning
	var tn = NotesTest.new()._registry(null, applied)
	tn.add_choice("light", "light", ["live", "dawn", "dusk"], "live", Callable(), func(v): applied.append(v))
	Dev.tuning = tn
	t.eq(card.preview(), "", "Tab loads the opts preset")
	t.check(card.previewing and tn.choice_value("light") == "dusk", "light is dusk while previewing")
	card.preview()
	t.check(not card.previewing and tn.choice_value("light") == "live", "Tab again puts it back")
	# free text suspends the game
	card.handle_key(NotesTest.key(KEY_T))
	t.check(card.typing and Game.options_open and Game.movement_blocked(), "typing suspends the game input")
	t.check(not card.handle_key(NotesTest.key(KEY_X)), "other keys go to the text field while typing")
	card._edit.text = "make it quieter"
	t.eq(await card.submit_text(), "", "Enter writes the free text")
	t.check(not card.typing and not Game.options_open, "the game is free again after the answer")
	var ans := Store.load_answers(base)
	t.check(ans.size() == 1 and ans[0].id == "f" and ans[0].option == 0 and ans[0].text == "make it quieter" and ans[0].tick == 0, "free text answer line: %s" % str(ans))
	t.check(ans[0].has("options") and ans[0].has("screenshot") and ans[0].has("answered"), "the line carries options, screenshot, timestamp")
	t.eq(card.pending_count(), 2, "an answered question leaves the queue")
	# Esc while typing only backs out
	card.tick(200.0)
	t.eq(card.current.get("id", ""), "a", "the next plain card pops after the gap")
	card.handle_key(NotesTest.key(KEY_T))
	card.handle_key(NotesTest.key(KEY_ESCAPE))
	t.check(not card.typing and not Game.options_open and not card.current.is_empty(), "Esc while typing backs out, the card stays")
	# digits answer, dismiss, later
	card.handle_key(NotesTest.key(KEY_L))
	t.check(card.current.is_empty() and card.pending_count() == 2, "L: answer later keeps it pending")
	card.tick(1.0)
	t.check(card.current.is_empty(), "and nothing pops inside the gap")
	t.eq(card.ask("a"), "", "ask shows it at once")
	card.handle_key(NotesTest.key(KEY_ESCAPE))
	t.check(card.current.is_empty() and card.dismissed.has("a"), "Esc dismisses for the session")
	card.tick(500.0)
	t.check(card.current.is_empty(), "a dismissed card does not come back by itself")
	t.eq(card.ask("a"), "", "ask works on a dismissed one")
	await card.answer_option(2)
	t.eq(Store.load_answers(base)[1].label, "No", "key 2 answers with the option label")
	# event trigger through the shared Game signal
	card.tick(500.0)
	t.check(card.current.is_empty(), "the event question waits")
	Game.loop_event.emit("quest_done:hunt", {})
	card.tick(1.0)
	t.eq(card.current.get("id", ""), "b", "quest_done:hunt through Game.loop_event pops the question")
	# console and list
	var cr = CmdReg.new()
	Cmds.register(cr, card)
	t.check(cr.execute("questions").out.contains("#b"), "console questions lists the pending one")
	t.check(cr.execute("questions all").out.contains("answered #f"), "questions all adds the answered")
	t.check(not cr.execute("ask nope").ok, "ask with an unknown id fails")
	card.hide_card()
	card.open_list()
	t.check(card.list_mode and card.is_active(), "the pause list opens")
	card.handle_key(NotesTest.key(KEY_1))
	t.eq(card.current.get("id", ""), "b", "a number in the list opens that question")
	card.handle_key(NotesTest.key(KEY_ESCAPE))
	t.check(card.current.is_empty() and card.list_mode, "Esc on a card from the list goes back to it")
	card.handle_key(NotesTest.key(KEY_ESCAPE))
	t.check(not card.list_mode and not card.is_active(), "Esc closes the list")
	# --- questions.py round trip
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/feedback/questions.py").simplify_path()
	var pb := base + "/py"
	var out: Dictionary = t.exec("python3", ["-I", script, "--dir", pb, "add", "--id", "z1", "--text", "Keep the glow?", "--option", "Keep|as is",
		"--option", "Drop|remove it", "--recommend", "1", "--free-text", "--when", "after_minutes:2", "--opts", "light=dusk"])
	t.check(out.rc == 0 and out.out.contains("z1"), "questions.py add by flags: %s" % out.out)
	var gd := Store.load_pending(pb)
	t.check(gd.size() == 1 and gd[0].id == "z1" and gd[0].options[0].recommended and gd[0].where.opts.light == "dusk" and gd[0].when == "after_minutes:2", "the game reads what python wrote")
	var tracker := base + "/tracker.json"
	var tf := FileAccess.open(tracker, FileAccess.WRITE)
	tf.store_string(JSON.stringify({"tests": [{"id": "T9", "title": "Walk looks right", "status": "Open"}, {"id": "T1", "title": "done one", "status": "Passed"}],
		"decisions": [{"id": "D3", "title": "Which sky?", "status": "Open", "options": [{"label": "Bright"}, {"label": "Dusky", "recommended": true}]}]}))
	tf.close()
	out = t.exec("python3", ["-I", script, "--dir", pb, "seed-from-tracker", tracker])
	var seeded := Store.load_pending(pb)
	t.check(out.rc == 0 and seeded.size() == 3, "seed-from-tracker adds the open test and decision (%d)" % seeded.size())
	var tq := Store.find(seeded, "q-T9")
	t.check(tq.options.size() == 3 and tq.options[0].label == "Yes" and tq.options[2].label == "Partly" and tq.allow_free_text, "an open test becomes yes / no / partly + note")
	Store.append_answer(pb, Store.make_answer(Store.find(seeded, "z1"), 1, "", {"tick": 77, "options": {"light": "dusk"}, "note": "abc123"}))
	out = t.exec("python3", ["-I", script, "--dir", pb, "pull-answers"])
	t.check(out.out.contains("z1") and out.out.contains("Keep") and out.out.contains("tick 77") and out.out.contains("note abc123"), "pull-answers prints it: %s" % out.out.left(100))
	t.check(t.exec("python3", ["-I", script, "--dir", pb, "list"]).out.contains("q-D3") and not t.exec("python3", ["-I", script, "--dir", pb, "list"]).out.contains("#z1"), "list hides the answered")
	t.check(t.exec("python3", ["-I", script, "--dir", pb, "export-md", "--all"]).out.contains("| z1 |"), "export-md")
	Dev.tuning = old_tn
	card.base_dir = old_base
	card.open = []
	card.current = {}
	card.list_mode = false
	card.from_list = false
	_wipe(base)

func _wipe(base: String) -> void:
	var d := DirAccess.open(base)
	if d == null:
		return
	for sub in d.get_directories():
		_wipe(base.path_join(sub))
		DirAccess.remove_absolute(base.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(base.path_join(f))
