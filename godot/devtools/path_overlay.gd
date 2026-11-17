extends Node3D
## Debug overlay (C1-nav): the player's GO path drawn on the ground as a thin line with a dot at every waypoint.
## Off by default; the console command `overlay path [on|off]` toggles it. Presentation only: it reads
## CporeWorld.path() and the ground height, it never writes to the simulation.

const LIFT := 0.6
const COLOR := Color(1.0, 0.85, 0.2)

var enabled := false
var _mesh := ImmediateMesh.new()
var _inst := MeshInstance3D.new()

func _ready() -> void:
	name = "PathOverlay"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR
	mat.no_depth_test = true
	mat.render_priority = 100
	_inst.mesh = _mesh
	_inst.material_override = mat
	_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inst.visible = false
	add_child(_inst)
	set_process(false)

func set_enabled(on: bool) -> void:
	enabled = on
	_inst.visible = on
	set_process(on)
	if not on:
		_mesh.clear_surfaces()

func _process(_dt: float) -> void:
	_mesh.clear_surfaces()
	var st = Game.stage
	if st == null:
		return
	var pts: PackedVector2Array = st.world.path()
	if pts.is_empty():
		return
	var me: Dictionary = st.cur.entities[0]
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_mesh.surface_add_vertex(_up(me.x, me.z))
	for p in pts:
		_mesh.surface_add_vertex(_up(p.x, p.y))
	_mesh.surface_end()
	# a small cross at every waypoint (lines, so the overlay stays two draw calls)
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for p in pts:
		for d in [Vector2(1.2, 0), Vector2(0, 1.2)]:
			_mesh.surface_add_vertex(_up(p.x - d.x, p.y - d.y))
			_mesh.surface_add_vertex(_up(p.x + d.x, p.y + d.y))
	_mesh.surface_end()

func _up(x: float, z: float) -> Vector3:
	return Vector3(x, Game.stage.world.ground(x, z) + LIFT, z)
