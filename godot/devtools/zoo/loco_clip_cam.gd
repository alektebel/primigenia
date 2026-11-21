extends Node
## Runs after the zoo each frame (priority 100) and asks loco_clip.gd to place the side camera.
var owner_clip

func _process(_dt: float) -> void:
	owner_clip.place_camera()
