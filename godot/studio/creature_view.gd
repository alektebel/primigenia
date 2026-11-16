extends Node3D
## Interface the studio needs from a creature view (G48/M2). The real builder (godot/creature/) must
## provide a Node3D with these methods; placeholder/placeholder_view.gd is the stand-in used by the tests.
## Space: view-local, +Y up, +Z along the spine, X lateral; spine nodes lie in the x=0 plane.
## `genome` is the cpore.creature/4 Dictionary (nodes {y,z,r}, parts, skin).
## Parts with ang off the midline are rendered mirrored on both sides (as in the web studio).

signal genome_applied

func set_genome(_doc: Dictionary) -> void: push_error("set_genome not implemented")
func get_genome() -> Dictionary: return {}

## Append a part (type id from parts.json). params: size, len, curve, w, k, f, rot, tilt. Returns its index.
func attach_part(_type: String, _t: float, _ang: float, _params: Dictionary = {}) -> int: return -1
func remove_part(_index: int) -> void: pass
func update_part(_index: int, _fields: Dictionary) -> void: pass

## Spine node centres, view-local, one per genome node (x = 0).
func spine_node_positions() -> PackedVector3Array: return PackedVector3Array()

## Ray (view-local) against the body surface. Returns {} on miss, else {t: 0..1 along the spine,
## ang: signed radians around it (0 = up, +X side positive), point: Vector3}.
func hit_body(_origin: Vector3, _dir: Vector3) -> Dictionary: return {}
## Index of the part under the ray (either mirrored side), or -1.
func hit_part(_origin: Vector3, _dir: Vector3) -> int: return -1
## Index of the spine node under the ray, or -1.
func hit_node(_origin: Vector3, _dir: Vector3) -> int: return -1

## Where to draw handles for a part: {pos: Vector3, normal: Vector3, up: Vector3}. {} if unknown.
func part_anchor(_index: int) -> Dictionary: return {}

func set_selection(_index: int) -> void: pass
func set_spine_visible(_on: bool) -> void: pass
## Test mode hook: start/stop the creature's locomotion/animation.
func set_playing(_on: bool) -> void: pass
