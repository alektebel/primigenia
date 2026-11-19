class_name RenderTier
extends RefCounted
## Renderer quality tier. The project (and every test) runs the GL Compatibility renderer. Forward+ (Vulkan) is an
## OPT-IN high-quality tier chosen at launch with `--rendering-method forward_plus` (`make godot-play-hq`,
## `make godot-studio-hq`) or by the env var CPORE_RENDERER=forward_plus together with that flag. Nothing in the
## Compatibility path changes; these calls are no-ops there. See docs/godot/CREATURE-REALISM.md section 1.
##
## What the HQ tier turns on (Environment / light / viewport features that exist only in Forward+ and Mobile):
##   SSAO + SSIL  contact darkening and one bounce of colour under bodies, between legs, in skin folds
##   SDFGI        off by default (CPORE_HQ_SDFGI=1 to try; it needs a GPU and is costly on a big island)
##   soft shadows PSSM 4 splits, 8k atlas, light angular size (PCSS-like penumbra), blurred filter
##   volumetric fog  off by default (CPORE_HQ_FOG=1); thin morning haze, cheap with the low-res froxel grid below
##   TAA, FXAA    replace the 2x MSAA of the Compatibility project
##   subsurface   `skin.gdshader` writes SSS strength (a real screen-space scatter in Forward+ only); the Compatibility
##                tier uses the wrap-light approximation in the shader
## Not verified on a GPU here (the build machine has no software Vulkan); see the doc.

static func method() -> String:
	return RenderingServer.get_current_rendering_method()


static func is_hq() -> bool:
	return method() == "forward_plus"


static func _flag(name: String) -> bool:
	return OS.get_environment(name) == "1"


## Called by every Environment factory (game island, studio, previews).
static func apply_environment(env: Environment) -> void:
	if not is_hq():
		return
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.25
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	if _flag("CPORE_HQ_SDFGI"):
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.5
	if _flag("CPORE_HQ_FOG"):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.004
		env.volumetric_fog_albedo = Color(0.95, 0.85, 0.72)
		env.volumetric_fog_length = 80.0
		env.volumetric_fog_detail_spread = 2.0


static func apply_sun(sun: DirectionalLight3D) -> void:
	if not is_hq():
		return
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.5
	sun.shadow_blur = 1.5
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


static func apply_viewport(vp: Viewport) -> void:
	if not is_hq():
		return
	vp.use_taa = true
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.msaa_3d = Viewport.MSAA_DISABLED
