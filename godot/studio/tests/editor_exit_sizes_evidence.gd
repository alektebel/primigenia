extends SceneTree
## A73 evidence: the default size of a freshly placed part, before (size 1.0 / the raw defaults) and after (scaled to the creature),
## one part per category on a starter, the hatchling and a big body. Software GL only:
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
##     --script res://studio/tests/editor_exit_sizes_evidence.gd -- <out_dir>
const IDS := ["fauces", "ojo", "pata", "arm_grasper", "cuerno", "wing_glider", "aleta", "excavadora", "cresta", "placa"]
var out := "/tmp"
var ui

func _init() -> void:
	call_deferred("run")

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _amount(p: Dictionary) -> float:
	if p.has("size"):
		return snappedf(float(p["size"]), .01)
	return snappedf(Vector3(p["f"][0], p["f"][1], p["f"][2]).length(), .01)     # a leg: its reach

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var Studio = load("res://studio/ui/studio.gd")
	ui = Studio.new()
	root.add_child(ui)
	await _frames(8)
	var rows: Array = []
	for seed_name in ["Starter B", "Hatchling", "Merodeador"]:
		for mode in ["before", "after"]:
			var m = ui.model
			m.new_from_seed(seed_name)
			m.doc["parts"] = []
			var slots := {"fauces": [1.0, 0.0], "ojo": [.9, .95], "pata": [.45, 2.1], "arm_grasper": [.62, 1.0], "cuerno": [.85, .5], "wing_glider": [.72, 1.3], "aleta": [.3, 0.0], "excavadora": [.5, 2.0], "cresta": [.6, 0.0], "placa": [.4, 0.0]}
			var sizes := {}
			for id in IDS:
				var t: float = slots[id][0]
				var ang: float = slots[id][1]
				if mode == "after":
					var i: int = m.add_part(id, t, ang)
					var p: Dictionary = m.doc["parts"][i]
					sizes[id] = _amount(p)
				else:
					var p2: Dictionary = ui.parts_db.defaults(id)       # what a fresh part was: the raw default, 1.0 whatever the body
					p2["t"] = t
					p2["ang"] = m._fit_ang(id, ang)
					m.doc["parts"].append(p2)
					sizes[id] = _amount(p2)
			m.select(-1)
			m.changed.emit(false)
			ui._apply_model()
			ui.frame_creature()
			await _frames(14)
			var path := out.path_join("sizes-%s-%s.jpg" % [seed_name.to_lower().replace(" ", "_"), mode])
			root.get_texture().get_image().save_jpg(path, 0.9)
			print(path, " ", sizes)
			rows.append({"body": seed_name, "mode": mode, "sizes": sizes})
	var f := FileAccess.open(out.path_join("sizes.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "  "))
	f.close()
	quit(0)
