extends RefCounted
## One light for the whole world (WL1, docs/godot/WORLD-LIT.md). Tiers: 1 low = `unshaded` fallback (baked sun visibility, no shadow map),
## 2 medium and 3 high = the ground shaders also receive the sun's shadow map (shaders/world_light.gdshaderinc).

## Shadow reach and cascades per tier (metres, split count). Low draws no sun shadows at all.
const SHADOW_MAX_DISTANCE := {1: 0.0, 2: 120.0, 3: 200.0}

static func lit(tier: int) -> bool:
	return tier >= 2


## The shader for a tier: tiers >= 2 return `base` (written lit), tier 1 a copy with the lit parts replaced by `unshaded`.
static func shader_for(base: Shader, tier: int) -> Shader:
	if lit(tier):
		return base
	var s := Shader.new()
	s.code = base.code.replace("ambient_light_disabled, specular_disabled,", "unshaded,").replace("#define WORLD_LIT", "")
	return s


## Sun shadow reach for the tier. The HQ (Forward+) path keeps its 4 splits and soft filter (RenderTier.apply_sun) and takes the distance.
static func configure_sun(sun: DirectionalLight3D, tier: int) -> void:
	sun.directional_shadow_max_distance = maxf(SHADOW_MAX_DISTANCE[clampi(tier, 1, 3)], 1.0)
	match tier:
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_split_1 = 0.25
			sun.directional_shadow_blend_splits = true
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_split_1 = 0.08
			sun.directional_shadow_split_2 = 0.22
			sun.directional_shadow_split_3 = 0.5
			sun.directional_shadow_blend_splits = true
