# WL1: one light for the whole world

Plan: `_agent/briefs/world-look-plan.md` section WL1. Branch `art/wl1-lighting`.

## Problem

Terrain, grass, rivers and water were `render_mode unshaded` with their own toon sun, while flora and creatures were lit by Godot's
sun. The ground therefore never received a shadow (trees, rocks and creatures cast none on it; a fake disc stood in for the creature),
SSAO on the Forward+ tier had nothing to work on, and every object floated on a flat sheet.

## What changed

* `shaders/world_light.gdshaderinc` (new): a `light()` function that adds `mix(SH_K * S_TINT, 1, ATTENUATION)` for the directional sun.
  The shaders keep computing exactly the colour they computed before, toon ramp included, and write it to `ALBEDO` as before (so the
  far palette is the same); the shadow map only multiplies it. `render_mode ambient_light_disabled, specular_disabled` replaces
  `unshaded`, so the environment's ambient does not add to the pre-lit colour. Unshadowed, the factor is 1.
* `terrain_medium`, `terrain_high`, `grass`, `water`, `river` are written lit (`#define WORLD_LIT`). `terrain_low` stays `unshaded`; the
  other three are turned into the same unshaded form for tier 1 by `island/world_light.gd` (`shader_for`), so there is one source.
* The fake creature disc (`occluder_shadow`, `land.gdshaderinc`) keeps 45 % of its strength when lit (`OCC_STRENGTH`): contact darkening
  under a body; the body casts the real shadow.
* Sun shadows per tier (`WorldLight.configure_sun`, applied by `island.gd` after the terrain tier is known): high 4 cascades to 200 m,
  medium 2 cascades to 120 m (split at 25 %), low none (it was 80 m, one cascade, on every tier). `_apply_zoom_budget` keeps the sun's
  shadow off on low and at far zoom (z >= 0.6) as before.
* `tests/test_look.gd`: shadow tint equals `SH_K * S_TINT`; every lit shader keeps its markers and low becomes unshaded; per-tier sun settings.
* Evidence: `tests/world_look_evidence.gd` (shared by every world-look slice; `make godot-world-look`), clouds pinned
  (`Clouds.frozen_time`, `FLORA_CLOUD_T`) so before and after compare pixel for pixel.

## Decisions

* The baked terrain sun visibility (PLAN-rock step 9) was **not** turned on by default for low, as the plan suggested: with a sun at 16
  degrees it darkens every bank and swell of the meadow (`evidence/godot/world-look/rejected/`). It stays opt-in (`sun_shadows`).
  Consequence: the low tier has no shadows at all on the ground.
* The grass blade normal was not bent. The grass keeps the colour from its root normal; the grass rework (WL2) owns the blade shape.

## Evidence

`docs/evidence/godot/world-look/{before,after}/<frame>[-low|-medium].jpg` (high has no suffix), sheets in `sheets/`. 1280x720, software GL,
seed 1, same cameras (`make godot-world-look WL_QUALITY=<tier>`), clouds pinned so cloud shadows do not move between runs.
`before` was taken from a copy of the tree at the base commit (only the evidence scripts newer).

* Shadows now fall on the meadow, the river and the lake in `valley_chase_z0`, `valley_chase_z35`, `sh_madre_de_agua`; the creature
  throws a real shadow on the water; small trees and the butterfly shadow the grass. `forest_floor` is in the shade of the canopy.
* Far view: mean colour difference after - before on `vista_wide` and `valley_east` (medium) is 0.0 to 0.1 per channel on the whole
  frame, 0.1/0.0/0.0 on the top 40 percent (rock and sky); `rk_boulder_close` 0.0. The brightest changes are where a shadow falls:
  `valley_chase_z0` bottom 40 percent -5.1/-5.7/-2.7. Near ground at the riverbank frame is up to +3.5/+5.9/+2.2 brighter in the bottom
  40 percent (contour-shaped, no shadow involved); not explained, flagged below.
* Low tier is the old look minus the shadows of flora and creatures on themselves; the grass pixels differ only by wind phase.
* The 4 and 2 cascade settings were checked in the same frames; the tall plant's shadow reaches 50 m (`sh_madre_de_agua`).
* `madre_spring` (the camera the plan names) stands with the sun behind the tree: its shadow falls to the lower left, outside the frame; the frame
  `sh_madre_de_agua` was added to show it.

## Forward+ (RTX tier)

Not rendered here: there is no software Vulkan driver on this machine (no lavapipe; only the NVIDIA and radeon ICDs, which would use the
GPU, forbidden). The lit shaders are the same under Forward+; the part that cannot be checked is whether SSAO darkens the ground through
a custom `light()` (it should darken the ambient, which these shaders disable, so it may do nothing; `AO_LIGHT_AFFECT` is the knob if the
owner wants contact AO). Owner check: the same frames with `--rendering-method forward_plus`.

## Perf (llvmpipe, relative only; the machine ran at load 20-40 from other agents' work)

`make godot-terrain-bench-sw` medium, chase / mid, mean frame ms, 3 interleaved runs each (30 frames): 

| view | before (3 runs) | after (3 runs) | mean ratio |
|---|---|---|---|
| chase | 3061, 4425, 3167 (mean 3551) | 4445, 3777, 3159 (mean 3794) | 1.07 |
| mid | 1705, 2193, 1975 (mean 1958) | 2778, 2020, 2012 (mean 2270) | 1.16 |

Under the limit (1.3 on chase), but the run-to-run spread (3.1 to 4.4 s for the same code) is larger than the difference. Per tier single runs (40 frames) were no
better. A quiet-machine rerun, or the owner's RTX number (`make godot-terrain-bench TIER=high`), is needed to decide the 1.3 limit.
Expected cost: the medium and high tiers add a shadow map pass for tall flora and creatures (2 or 4 cascades) and one shadow lookup per
terrain, grass, river and water fragment; the low tier loses the previous 80 m shadow pass.

## Open

* Riverbank near-ground brightening above (+3.5/+5.9/+2.2).
* Low tier now draws no sun shadows at all (the plan said off); trees and creatures lose self-shadowing there. Keep a 40 m single cascade?
* Terrain does not cast shadows (chunks `SHADOW_CASTING_SETTING_OFF`): mountains do not shade the valley. Turning it on needs a depth-only
  cheaper chunk mesh; not in WL1.
* Grass blade normal bent toward the blade is left to WL2.
