extends SceneTree
## Regenerates godot/audio/default_bus_layout.tres:
## godot --headless --path godot --script res://tests/gen_bus_layout.gd
func _initialize() -> void:
	var AM := preload("res://audio/audio_manager.gd")
	AM.ensure_buses()
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://audio/default_bus_layout.tres")
	print("saved: ", err)
	quit()
