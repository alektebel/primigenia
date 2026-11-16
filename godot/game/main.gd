extends Node
# Boot: settings -> terrain cache or loading screen -> island.

func _ready() -> void:
	Game.goto_island.call_deferred()
