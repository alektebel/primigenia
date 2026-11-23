extends RefCounted
## Shared melee impact (A64): what EVERY melee hit does on screen, whatever the move. Presentation only: nothing here
## touches the C world, whose combat timing stays authoritative (the freeze is the layer holding its own pose).
##
##   hit-pause       60..90 ms visual freeze of BOTH creatures' action layers (the C ticks keep their time)
##   flinch + knock  the victim recoils along the hit direction (action_layer.react), scaled by the size ratio
##   dust / sparks   a puff and a few sand-coloured sparks at the contact point (never blood)
##   camera shake    subtle, scaled by damage and by the attacker's body size (island.melee_impact)
##   flash           the victim's body goes pale for a moment (apply_flash on the layer's flash value)
##   sound           audio.hit with the pitch and weight of the body (audio_manager.hit)
##
## Size scale s = size01(height): 0 = small and light (0.5 m), 1 = big and heavy (2 m and up).

## C moves that are melee (a body part meets the other body): bite, charge, tail_strike, claw_swipe, peck, pounce, stomp.
const MELEE := {0: true, 1: true, 4: true, 6: true, 7: true, 8: true, 11: true}

const PAUSE_MIN := 0.06
const PAUSE_MAX := 0.09

static func is_melee(move: int) -> bool:
	return MELEE.has(move)

## 0 (about 0.5 m tall) .. 1 (2 m and up).
static func size01(height: float) -> float:
	return clampf((height - 0.5) / 1.5, 0.0, 1.0)

## Seconds of visual freeze: small bodies 60 ms, big ones 90 ms (heavy things hit with more stop).
static func pause_seconds(height_a: float, height_b: float) -> float:
	return lerpf(PAUSE_MIN, PAUSE_MAX, size01(maxf(height_a, height_b)))

## Camera shake strength 0..1 for the island's land_impact (0.12 m at 1.0): the attacker's size sets the base,
## the damage adds up to a third more.
static func shake_strength(attacker_height: float, damage: float) -> float:
	return clampf(0.18 + 0.5 * size01(attacker_height) + 0.3 * clampf(damage / 20.0, 0.0, 1.0), 0.15, 1.0)

## Recoil scale of the victim: a heavy attacker on a light victim knocks it further, the other way round less.
static func knock_scale(attacker_height: float, victim_height: float) -> float:
	return clampf(attacker_height / maxf(victim_height, 0.2), 0.6, 1.6)

## How long the victim's flash lasts after the pause (seconds) and how bright it starts (0..1).
const FLASH_LIFE := 0.16

static func flash_strength(damage: float) -> float:
	return clampf(0.45 + damage / 30.0, 0.5, 0.9)

## --- particles ---------------------------------------------------------------------------------------------------

## A small ground-coloured puff at `at`, thrown mostly along `dir` (unit, horizontal) and up. `size` is the attacker's
## body height in metres. Frees itself.
static func dust_puff(parent: Node, at: Vector3, dir: Vector3, size: float, strength := 1.0) -> CPUParticles3D:
	var s := size01(size)
	var p := CPUParticles3D.new()
	p.amount = int(8 + 10 * s)
	p.lifetime = 0.45 + 0.25 * s
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = (dir + Vector3.UP * 0.7).normalized()
	p.spread = 50.0
	p.initial_velocity_min = (0.5 + 0.7 * s) * strength
	p.initial_velocity_max = (1.2 + 1.2 * s) * strength
	p.gravity = Vector3(0, -2.2, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (0.12 + 0.16 * s)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.66, 0.58, 0.44, 0.6), Color(0.66, 0.58, 0.44, 0.0)])
	p.color_ramp = g
	p.top_level = true
	p.emitting = false
	parent.add_child(p)
	p.global_position = at
	p.restart()
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(p.lifetime + 0.3)
	tw.tween_callback(p.queue_free)
	return p

## A few bright flecks (dust and chips catching the light, not blood) thrown along `dir`. Frees itself.
static func sparks(parent: Node, at: Vector3, dir: Vector3, size: float, strength := 1.0) -> CPUParticles3D:
	var s := size01(size)
	var p := CPUParticles3D.new()
	p.amount = int(5 + 5 * s)
	p.lifetime = 0.22 + 0.1 * s
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = (dir + Vector3.UP * 0.3).normalized()
	p.spread = 70.0
	p.initial_velocity_min = (1.5 + 1.0 * s) * strength
	p.initial_velocity_max = (3.0 + 2.0 * s) * strength
	p.gravity = Vector3(0, -6.0, 0)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (0.025 + 0.02 * s)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.93, 0.7)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.85, 0.5, 0.0)])
	p.color_ramp = g
	p.top_level = true
	p.emitting = false
	parent.add_child(p)
	p.global_position = at
	p.restart()
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(p.lifetime + 0.2)
	tw.tween_callback(p.queue_free)
	return p

## The whole contact effect at once (what the driver calls for a layer's `hit_fx` event). Returns the nodes.
static func contact(parent: Node, data: Dictionary) -> Array:
	var at: Vector3 = data.pos
	var dir: Vector3 = data.dir
	var size: float = float(data.size)
	var k := clampf(0.7 + float(data.get("amount", 8.0)) / 30.0, 0.7, 1.4)
	return [dust_puff(parent, at, dir, size, k), sparks(parent, at, dir, size, k)]

## --- flash ---------------------------------------------------------------------------------------------------------

const OVERLAY_META := "impact_overlay"

## Pale flash over every mesh of `body` (k 0..1; 0 clears). The overlay is one shared material kept on the body.
static func apply_flash(body: Node3D, k: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var mat: StandardMaterial3D = body.get_meta(OVERLAY_META) if body.has_meta(OVERLAY_META) else null
	if k <= 0.003:
		if mat != null and mat.albedo_color.a > 0.0:
			mat.albedo_color.a = 0.0
			for m in _meshes(body):
				m.material_overlay = null
		return
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.96, 0.88, 0.0)
		mat.no_depth_test = false
		body.set_meta(OVERLAY_META, mat)
	var was := mat.albedo_color.a
	mat.albedo_color.a = clampf(k, 0.0, 1.0) * 0.7
	if was <= 0.0:
		for m in _meshes(body):
			m.material_overlay = mat

static func _meshes(body: Node) -> Array:
	var out := []
	for n in body.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null and mi.visible and mi.mesh != null:
			out.append(mi)
	return out
