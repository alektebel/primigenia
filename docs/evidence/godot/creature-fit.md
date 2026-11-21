# Creature part fit (branch art/creature-fit)

Check: `make godot-creature-fit` (also inside `make godot-creature-test`). Code: `godot/creature/creature_fit.gd`, `tests/test_fit.gd`.
4 pilots (hero, giant, spider, beetle) + 10 seeded random valid genomes (seeds 101..110). Visual only, no genome change.

| Issue | Metric | Before | After |
|---|---|---|---|
| Floating parts | parts whose nearest vertex is above skin tolerance | 0 | 0 (hero 8 parts, beetle 16, seeds 6..13) |
| Teeth outside the mouth | tooth base outside the mouth ellipsoids (hero, giant, spider, seeds 107, 109) | 4/24 per creature, worst normalised radius 1.11 | 0/24, worst 0.96 |
| Eye not socketed | eyeball centre depth under skin / radius, want 0.12..0.75 | -0.10..-0.26 (above the skin), every ojo | within range, all creatures |
| Limb root ball | thickest visible part of upper limb / knee-end thickness (limit 1.6) | 1.96 | 1.36 |
| Horn size | root radius / head radius | 0.36 (hero) | 0.22 |
| Horn length | length / head radius | 1.87 (hero) | 1.73 (unchanged: genome len .9) |

Not fixed here:
- Belly "flat white" and pattern scale body vs limbs: both live in `shaders/skin_common.gdshaderinc` (owned by art/skin-v1). The pattern wavelength is already the same in metres (body UV vs triplanar limbs use one `tur_tile`); the visual difference is stripes on the tube vs triplanar blotches on limbs. Belly countershading is a smoothstep gradient (cs 0.5 mixes 68 % towards cC); it reads white because cC is pale cream under midday sun. Proposal for skin-v1: limb UVs along the limb axis, and cap belly mix to 0.5.
- Horn position/length are genome values (hero: t .87, ang .4, len .9). Proposal needing a genome edit: starter horn t .92, ang .55, len .65 (brow, not skull back, ~1.25 head radii).

Crops: `creature-realism/<id>_<view>_fit.jpg` (eye, close, legs, side, chase), compare with `_after`.
