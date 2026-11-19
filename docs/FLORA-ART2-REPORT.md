# Island flora quality pass 2

The revised generator gives the near trees continuous, flared trunks and rounded clusters of leaves. On the default seed-1 island, low uses 28.5% fewer near triangles than the incoming generator with the same placements, instance slots and batches. The images in `docs/evidence/godot/flora/` are now re-captured from this revision (high tier, software GL, 1280x720) and `compare_*.jpg` set v1 against v2.

## Intended commits

| Commit | Contents |
| --- | --- |
| `feat(godot): round tree roots and light clustered foliage by tier` | Tree and berry geometry, vine path, flora shader, tier-aware mesh cache and mesh tests. |
| `feat(godot): blend lava crusts and moss into the ground` | Small terrain-aligned colony meshes, ground-cover shader and UID, sulfur pigment, footprint scaling and colony tests. |
| `fix(godot): follow the nest rim with shorter woven fibres` | Rounded earth profile and tapered straw and twigs in the nest builder. |
| `test(godot): frame alpine plants and record flora geometry budgets` | Evidence cameras, benchmark JSON and this report. |

Committed on `art/flora-quality` (five slices, then `claude/v0.1-restore` merged in).

## Art changes

- The trunk widens into five curved root lobes in the same mesh. The shoulder rolls into a tapered shaft with interpolated surface normals. A cylindrical procedural shader adds winding vertical fissures, normal relief and grey-green lichen. Fissure contrast decreases as the grooves become subpixel.
- Each near terminal spray has 6, 10 or 16 arched compound cards on low, medium or high. The corresponding trunks have 16, 24 or 36 radial segments. The distant tree uses four cards per spray and ten trunk segments. Leaf normals spread outward and upward around the spray. Inner segments receive baked colour darkening, and the two-sided shader supplies backlight and position-seeded hue variation. Derivative-filtered cutouts use alpha scissor and alpha-to-coverage for MSAA. The project requests 4× MSAA.
- Perlilla carries wax-white pendant bunches outside the dark stems. Near bunches have four to six larger berries with rounded shading and darker tips. Three berries carry the cluster into the far mesh. Berry size is exaggerated for legibility.
- Sulfur crust, ember crust and beacon moss use a translucent, 12-triangle patch oriented to the placement facet. An irregular opacity mask reveals soil or rock between colonies and at their edges. Beacon moss has finer grain, more relief from its recipe height and a subtle glow. Sulfur pigment shifted from ochre to grey buff. Pan de humus keeps its separate fungal cushions.
- The nest’s former shell had four large triangles per angular sector connecting the inner and outer slopes to a sharp ridge. That broad surface was exposed under the stems in the reference. The new earth bed follows a rounded profile with six radial intervals. Its 320 bent fibres use the same terrain and ridge profile at both ends and the bend. The chord length and taper limit the exposed size of each twig.
- The vine now winds outside the host’s flared base. Its evidence camera looks inward at a lower coil from the exposed side. The snow camera looks across the rosette group from about 12 m away. Both shots sample terrain along the sightline to clear intervening ridges. A new `tier_crown` shot frames the first fork of the seed-stable spring landmark across all three tiers.

## The meadow ellipses

The two bright ovals on the right of `valley_east.jpg` are surface-find markers from `godot/game/stage/part_nodes.gd`. Projecting the seed-1 stage records through the original camera gives horizontal pixel 920 for fossil 3006 and 1128 for bones 3005, matching the two ovals in the 1280-pixel reference. Each marker is a pale sphere flattened to 1.30 m across and 0.45 m high. The stage hides it after inspection. Their appearance belongs to the surface-find interaction.

## Performance

Godot 4.7.2 headless, seed 1, normal wild reservations, default terrain and density per tier. The baseline uses the incoming worktree revision’s generator and batching code against the same stage setup. Near and far columns sum indexed triangles times instance count over the resident batches. They include rock props. The separate nest is excluded. Each pair reads **v1 → pass 2**.

| Tier | Placed props | Resident instance slots | Resident batches | Near triangles | Far triangles |
| --- | ---: | ---: | ---: | ---: | ---: |
| Low | 5,081 | 6,001 | 2,528 | 1,805,585 → 1,290,786 | 138,417 → 132,626 |
| Medium | 8,421 | 10,084 | 2,848 | 3,151,523 → 2,969,564 | 252,035 → 240,288 |
| High | 12,802 | 15,416 | 2,501 | 4,912,016 → 6,234,530 | 395,318 → 377,816 |

Placements, slots and batches match v1 in each row. Slots include both LODs of tall objects. The renderer culls by range and spatial batch, so the totals describe the island’s geometry budget, not the triangles drawn in a frame. Near triangle count drops 5.8% on medium and rises 26.9% on high. The low-tier savings come largely from fewer spray cards, cheaper berry geometry and replacing 70 crust or moss lumps with one patch. Procedural bark, antialiased coverage and translucent colonies add fragment work. GPU frame time and alpha overdraw remain unmeasured. The terrain benchmark now writes these counts into its JSON under `flora`.

## Verification

- `--check-only` passed for the flora generator, island props, flora tests, evidence script and terrain benchmark.
- `make godot-test` passed 812 checks. `make godot-ui-test` passed 732. The flora suite also passed all 177 checks in isolation. Coverage includes tier-dependent near geometry, cached distant geometry, varying normals on bark and leaf triangles, colony topology and material parameters, seed determinism and placement rules.
- The integrated headless terrain benchmark built each tier and emitted the counts above. Headless runs used the dummy display backend. Live GL shader compilation, lighting, transparency and silhouette quality require a display run. The suites also emitted existing sandbox socket, negative-test and engine cleanup diagnostics.

## Integration pass (Sonnet/Opus review)

Changes made after rendering Astra's work under xvfb software GL:

- **Colour pipeline.** The `sqrt()` albedo in `flora.gdshader` over-brightened the compat renderer: bark came out cream/grey and crowns pale mint. It is now `pow(pigment, 0.64)` for trees, with the bark base moved to warm brown `6f5642`. The crust and moss shader used the same `sqrt()` and rendered ember crust pink and moss mint; it is now `pow(0.9)`.
- **Berries.** The perlilla berries were bipyramids (white diamonds). They are now 10-sided, 4-band ellipsoids with sphere normals (5 sides and 2 bands in the far mesh).
- **Nest bed.** The earth was flat-shaded rings (visible facets). It now has smooth vertex normals from neighbouring ring samples and a lighter soil colour.
- **Surface finds (the white meadow ellipses).** `part_nodes.gd` builds a seeded weathered marker: a low mound of dark earth with clods, plus either 3 to 4 cream bone shafts with knobbed ends and a skull-like lump (bones), or a tilted stone slab with three raised ribbed rings (fossil). It stays pale against grass and keeps the `E` label and the hide-on-inspect behaviour.
- Evidence set re-captured into `docs/evidence/godot/flora/` (base and volcano, high). New: `tier_crown.jpg`, `compare_forest_floor.jpg`, `compare_madre_spring.jpg`, `compare_nest_ground.jpg`, `compare_lava_crust.jpg`.

## Tests

`--check-only` clean on every touched script. After the merge of `claude/v0.1-restore`: `godot-test` 812 checks, 0 failures (includes the flora suite); `godot-ui-test` 732, 0 failures; `godot-play-test` 217, 0 failures (the first run before the merge had 6 failures, all fixed by the play-test commits already on `claude/v0.1-restore`).

## Visual assessment (honest)

Better: trees now read as trees. Crowns are lit, layered and backlit instead of near-black, trunks flare into roots with bark relief and a believable brown, berries are round, the nest is one rounded earth bed, crusts and moss sit in the ground rather than as lumps, and the surface finds look like bone or fossil in earth.

Still weak:
- Branches are still straight rods with hard bifurcations, so close-ups (`forest_floor`, `forest_edge`) read as stylised, not botanical. A bend or taper per segment would fix it.
- Leaf cards show a dither pattern in these captures because llvmpipe does not give real MSAA for alpha-to-coverage; on a GPU it should resolve. Verify on hardware.
- `snow_rosettes` is still flat-coloured and faceted pastel; it was not reworked.
- The nest looks like a smooth brown blob with sparse straw; more fibres on the slope would help.
- Surface-find markers are small bright specks at chase distance (readable by the `E` label only).
- Crusts and moss are matte flat patches with no relief.
- GPU frame cost is still unmeasured.

## Hardware checks still pending

1. Compare `tier_crown` at low, medium and high on a GPU. Inspect root continuity in `madre_base`, bark highlights in `forest_edge` and backlit sprays in `forest_floor`. Orbit during the LOD transition and check upper and lower leaf faces.
2. Capture `plant_perlilla` and walk back to ordinary chase distance. Check berry bunches against the branches and meadow. In `plant_soga_de_dosel`, verify that the lower coil is visible ahead of its host. In `snow_slope`, verify that a whole rosette and neighbouring terrain fit in frame.
3. In volcano mode capture `plant_costra_de_azufre`, `lava_crust` and `plant_musgo_faro`. Compare hue against the adjacent rock at noon and inspect from grazing angles for floating edges, z-fighting or visible sorting seams.
4. Capture `nest_ground`, `nest_high` and `valley_chase_z0` with the player for scale. Inspect the far and near lip for a broad plank silhouette and check straw contact on the outer slope. Compare the separate meadow markers in `valley_east`.
5. Run the same chase, mid, far and grove views on the Radeon with GL Compatibility and on the RTX with Forward+. Record resolution, MSAA, adapter, draw calls, GPU ms, mean/p95 frame time and shader diagnostics against v1. Repeat the leaf-edge inspection with MSAA off to check the scissor fallback.
