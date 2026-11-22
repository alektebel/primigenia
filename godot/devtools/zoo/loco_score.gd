extends SceneTree
## L0 locomotion scorecard runner. godot --headless --fixed-fps 30 --path godot --script res://devtools/zoo/loco_score.gd -- <out dir> [bodies] [scenarios] [ticks]
## Writes <out dir>/<body>_<scenario>.json for every body x scenario (bodies: zoo ids, comma separated; default all 7).
## Verdicts (PASS/FAIL against docs/research/loco-reference.json) are made by tools/loco/summary.py from these files.

# loaded at run time: zoo.gd names the Game autoload, which a --script run registers only after this file is compiled

const BODIES := ["mite", "trotter", "hero", "giant", "longneck", "centipede", "hexapod"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Core = load("res://devtools/zoo/loco_score_core.gd")
	if OS.get_environment("LOCO_GAIT") == "today":     # A/B: the pre-port gait rules (F10 option gait: today)
		load("res://locomotion/loco_gait.gd").froude_mode = false
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/loco-score"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bodies: Array = Array(args[1].split(",", false)) if args.size() > 1 and args[1] != "" else BODIES
	var scens: Array = Array(args[2].split(",", false)) if args.size() > 2 and args[2] != "" else Core.SCENARIOS
	var ticks := int(args[3]) if args.size() > 3 else 0
	for b in bodies:
		for sc in scens:
			var t0 := Time.get_ticks_msec()
			var res: Dictionary = Core.run_case(root, str(b), str(sc), ticks)
			var f := FileAccess.open(out_dir.path_join("%s_%s.json" % [b, sc]), FileAccess.WRITE)
			f.store_string(JSON.stringify(res, "  ", true))
			f.close()
			print("loco_score %s %s: %d frames in %.1f s" % [b, sc, res.frames, float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
