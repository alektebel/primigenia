extends Node
# Boot: settings -> terrain cache hit goes straight to the island; a miss shows the loading screen.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const LoadingScene := preload("res://game/loading/loading_screen.tscn")

func _ready() -> void:
	var params := {"seed": int(Game.settings.seed)}
	var t0 := Time.get_ticks_msec()
	var entry := TerrainCache.load_entry(params)
	if not entry.is_empty():
		print("terrain cache: hit (%d ms)" % (Time.get_ticks_msec() - t0))
		Game.set_island(entry)
		Game.goto_island.call_deferred()
		return
	print("terrain cache: miss")
	var screen := LoadingScene.instantiate()
	add_child(screen)
	screen.finished.connect(_on_generated.bind(t0))
	screen.start(params)

func _on_generated(entry: Dictionary, t0: int) -> void:
	if entry.get("error", -1) != 0:
		push_error("terrain generation failed: %s" % [entry.get("error")])
		get_tree().quit(1)
		return
	print("terrain cache: generated and stored (%d ms)" % (Time.get_ticks_msec() - t0))
	Game.set_island(entry)
	Game.goto_island()
