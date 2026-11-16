extends SceneTree
## Quick look: one seed, one view.
## godot --path godot --rendering-driver opengl3 --script res://creature/tools/render_quick.gd -- <seed> <yaw> <pitch> <dist> <out.png> [w h]

func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var seed_name := a[0] if a.size() > 0 else "Merodeador"
	var yaw := float(a[1]) if a.size() > 1 else .5
	var pitch := float(a[2]) if a.size() > 2 else .18
	var dist := float(a[3]) if a.size() > 3 else 8.0
	var out := a[4] if a.size() > 4 else "user://quick.png"
	var size := Vector2i(int(a[5]), int(a[6])) if a.size() > 6 else Vector2i(640, 400)
	var stage := CreaturePreview.new(self, size)
	var c := Creature.new()
	stage.world_root.add_child(c)
	var g
	if seed_name.ends_with(".json"):
		g = FileAccess.get_file_as_string(seed_name)
	else:
		g = Creature.seeds()[seed_name]
	var r := c.load_genome(g)
	if not r["ok"]:
		push_error("genome: " + r["error"])
		quit(1)
		return
	stage.orbit(CreaturePreview.mid_target(c), yaw, pitch, dist, 42)
	var img: Image = await stage.capture(self, 4)
	img.save_png(out)
	print("saved ", out)
	quit()
