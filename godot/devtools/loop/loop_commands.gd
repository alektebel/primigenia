extends RefCounted
## `loop` console command (and {"cmd":"loop"} on the agent socket): `loop` summarises the session, `loop dump [n]` prints the last
## n events (default 30) as JSONL, `loop path` prints the session file. Analysis proper: tools/loop/score.py <file>.

static func run(rec, args: Array) -> String:
	if rec == null or not rec.enabled:
		return "loop recorder is off (CPORE_LOOP=0)"
	if args.size() > 0 and args[0] == "dump":
		return rec.dump(int(args[1]) if args.size() > 1 else 30)
	if args.size() > 0 and args[0] == "path":
		return rec.path if rec.path != "" else "(no events yet)"
	return rec.summary()

static func register(r, rec) -> void:
	r.register("loop", "[dump [n] | path]", "creature-loop telemetry: summary of this session, the last n events, or the JSONL path", func(a):
		return r.ok(run(rec, Array(a))), {"complete": func(i, p, t): return ["dump", "path"] if i == 0 else []})
