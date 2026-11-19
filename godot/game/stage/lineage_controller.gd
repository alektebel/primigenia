extends Node
const TreeView := preload("res://game/stage/family_tree.gd")
var island
var screen: Control
var layer: CanvasLayer
var selected_pin: Dictionary = {}
var _was_paused := false
var _base_pois: Callable

func setup(owner_island) -> void:
	island = owner_island
	_base_pois = island.icons.pois_fn
	layer = CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	screen = TreeView.new()
	layer.add_child(screen)
	screen.hide()
	screen.closed.connect(close)
	screen.cousin_pin_requested.connect(_pin)
	island.stage_ui.ui.family_tree_requested.connect(open)

func open() -> void:
	_was_paused = island.stage_ui.ui.paused
	island.stage_ui.ui.set_paused(true)
	island.stage_ui.ui.menu.close_menu()
	screen.show_lineage(JSON.parse_string(island.stage.world.lineage()))
	screen.show()

func close() -> void:
	screen.hide()
	island.stage_ui.ui.set_paused(_was_paused)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("family_tree") and screen.visible:      # opening is the UI's (T or the menu item)
		close()
		get_viewport().set_input_as_handled()
	elif screen.visible and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()

func _pin(generation: Dictionary) -> void:
	selected_pin = generation
	_was_paused = false
	close()
	# Add a discovered den to the existing strategic icon source; never teleport.
	var previous: Callable = _base_pois
	var pos := Vector2(generation.home_cm[0] / 100.0, generation.home_cm[1] / 100.0)
	island.icons.pois_fn = func() -> Array:
		var out: Array = previous.call() if previous.is_valid() else []
		out.append({"id": 9000 + int(generation.generation), "kind": "den", "pos": pos, "discovered": true, "label": generation.name})
		return out
	island.chase.map_center = pos
	island.chase.z_target = 1.0
