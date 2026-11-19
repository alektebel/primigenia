# Flora art pass 3

The seed-1 island uses 1,216,048 near triangles on low, 74,738 below the pass-2 report’s budget. The pass retains the same placements and batch counts at all three tiers. The nest adds one mesh with 9,376 triangles.

## Intended commits

| Proposed commit | Changes |
| --- | --- |
| `feat(godot): grow curved limbs from tapered branch collars` | Near trees and shrubs follow cubic Bézier paths. Each child starts inside its parent, follows the parent tangent through a swollen collar and tapers towards the fork. Adjacent spans share ring normals. Recipe droop ranges from 0.18 for Caramillo to 0.46 for the arched Trenza de ribera. Low uses five primary limbs, five cards per terminal spray and cheaper rounded berries. Far limbs retain a single span. |
| `feat(godot): model the insulated Snowshield rosette` | A bark column occupies 39% of the plant’s height, about 0.59–0.98 m at the recipe’s 1.5–2.5 m scale. Two spirals carry 34 hanging buff leaves and 30 living blades. The living blades cup around a keel and rise more steeply towards the bud. Interpolated normals, fine lengthwise silver hairs and a grazing-angle sheen distinguish the hairy tissue from the narrow red-purple UV-screening margins. The retained skirt represents frost insulation. |
| `feat(godot): weave the nest rim and model colony relief` | Dry Paja dulce straw wraps around 32 crossing twig ribs in 15 staggered courses. Alternating strand heights expose crossings down both slopes of the 45 cm bank. Down collects inside the rim around a scraped earth floor. All materials share one nest surface. The colony shader uses derivatives of its existing grain to perturb the lighting normal, with 0.65 mm relief for sulfur crust, 1.1 mm for ember crust and 2.8 mm for beacon moss. Relief fades at transparent edges and with distance. |
| `test(godot): cover limb droop, alpine foliage and colony relief` | Flora checks exercise mesh determinism, the droop response, Snowshield column height, dead skirt, cupped normals and margin colour, per-colony relief, and the nest lining and floor. |

## Geometry budget

Godot 4.7.2, seed 1, default density and normal stage reservations. The headless terrain benchmark counts indexed triangles times instance count over resident MultiMesh batches, including rocks. Near and far have separate visibility ranges. The nest is a separate MeshInstance3D at every tier.

| Tier | Placed props | Instance slots | MultiMesh batches | Near triangles | Far triangles | Nest triangles / surfaces |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Low | 5,081 | 6,001 | 2,528 | 1,216,048 | 131,506 | 9,376 / 1 |
| Medium | 8,421 | 10,084 | 2,848 | 4,199,096 | 238,014 | 9,376 / 1 |
| High | 12,802 | 15,416 | 2,501 | 8,630,930 | 374,432 | 9,376 / 1 |

The incoming worktree measured 1,400,610 near and 133,946 far triangles on low before this pass. The earlier pass-2 report recorded 1,290,786 near and 132,626 far before its integration edits. Medium and high keep eight primary limbs and spend more geometry on branch curvature. GPU cost and chase-distance readability need a display run.

## Verification

`make godot-test` passed 832 checks and `make godot-ui-test` passed 732, both with zero failures. All three changed GDScripts passed Godot’s headless `--check-only`. The headless engine loaded both shader resources and returned their uniform lists. The terrain benchmark built all three tiers. The test suites also emit sandbox socket diagnostics, intentional invalid-input errors and engine cleanup warnings.

## Capture checklist for Sonnet

Use the seed-stable cameras in `godot/game/tests/flora_evidence.gd` at 1280×720 and match the pass-2 JPG framing. Its arguments are the output directory, tier, terrain mode and comma-separated shot prefixes. Capture the base island first, then switch to volcano mode for the colonies.

- [ ] Compare `forest_floor`, `forest_edge`, `madre_spring` and `tier_crown` against the existing close-ups. Inspect where bark leaves the parent at a fork, especially backlit limbs. Repeat `tier_crown` at low, medium and high and orbit through the near/far transition.
- [ ] Capture `snow_rosettes`, `snow_slope` and `plant_rodela_de_nieve`. Look for a visible stem between hanging leaves, a silver outer crown and a greener upright bud. Inspect purple margins and fine hair at close range and check for shimmer while backing away.
- [ ] Capture `nest_ground`, `nest_high` and `valley_chase_z0` with the player for scale. Check straw crossing the twig ribs on the near slope, pale down inside the lip, the bare scrape in the centre and the rim silhouette at chase distance.
- [ ] In volcano mode capture `lava_crust`, `plant_costra_de_azufre` and `plant_musgo_faro`. Compare the colony centre and feathered edge at noon and under grazing light. Orbit for reversed relief, shimmer and apparent lift off the rock.
- [ ] Run GL Compatibility on hardware and repeat on Forward+. Record adapter, resolution, MSAA, shader diagnostics and matched-view GPU and p95 frame times. Pay particular attention to medium/high grove cost and alpha-to-coverage on the low crown.

## Integration review (Claude)

- Budget re-measured with `make godot-terrain-bench-sw TIER=low` (xvfb, llvmpipe): flora on 5,081 placements, 2,528 batches, 1,216,048 near and 131,506 far triangles; flora off 1,530 near. Low is 74,738 near triangles (5.8%) below pass 2 (1,290,786) and 32.7% below v1 (1,805,585), so no further low-tier reduction was needed. llvmpipe frame times were flora on 2,102 ms vs off 2,114 ms at chase and 1,521 vs 1,487 ms at mid; this is software rendering and says nothing about an AMD iGPU.
- Suites after integration: godot-test 832 checks, godot-ui-test 732, godot-play-test 217, all 0 failures.
- Evidence re-captured at high tier, 1280x720, software GL. `compare3_forest_floor`, `compare3_snow_rosettes`, `compare3_nest_ground` and `compare3_lava_crust` set pass 2 (left) against pass 3 (right). Tree close-ups: `plant_madre_de_agua`, `plant_trenza_de_ribera`, `plant_caramillo`.
- Fixes from review: the nest bed showed near-black gaps between ribs, so soil went from 594738 to 7b6548; the snow-rosette skirt read as saturated orange, so `dead` went from 80613d to 76603f.

### Honest assessment

Improved: limbs curve and flare out of forks instead of meeting as straight rods; crowns are darker and denser in the backlit forest floor view; the snow rosette is a recognisable plant with a skirt of dead leaves rather than a flower of purple petals; the nest reads as woven twigs on an earth bed.
Still weak: alpha-to-coverage under SwiftShader shows heavy dither moire on close leaf cards (a software GL artefact, unverified on a GPU); the forest canopy at floor level is quite dark and uniform; the snow skirt is still warmer than natural; the lava crust patch is visually unchanged at the evidence distance; the nest lattice is regular. No hardware GPU timing was done.
