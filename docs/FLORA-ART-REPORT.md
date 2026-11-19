# Island flora, rocks and nest

All five slices are in the island scene on `art/flora-generators`. Placement reads the terrain and stage setup. Props have no physics bodies, collision shapes, simulation entities or per-frame GDScript update. The nest follows a restored scenario's setup, including its grass clearing.

## Intended commits

| Slice | Intended commit | Contents |
|---|---|---|
| S1 | `feat(godot): generate plants from flora recipes` | The 16 lore-derived rows in `game/data/flora.json`, `flora_mesh.gd` and the flora shader. Tapered branching, buttress plates, cutout sprays, arching fronds, blades, forked ribbons, climbing stems, cushions and crust plates. |
| S2 | `feat(godot): populate island habitats in seeded patches` | `flora_placement.gd`, plant batches in `island_props.gd`, island setup and scenario restore hooks. Heights use the rendered triangle. A seed and lattice cell select a shared mesh variant, yaw, height and patch. Vines share a tree root and derive their reach from that host. |
| S3 | `feat(godot): scatter photographic volcanic rock props` | Rock placement, irregular boulder, scree and outcrop meshes, and the triplanar shader sampling the existing andesite, basalt, strata and scree photo layers in world metres. |
| S4 | `feat(godot): weave the start nest into the meadow` | Terrain-following scraped earth, a continuous straw rim, 540 crossing straw stems and twigs, and the elliptical clearance in the existing grass shader. |
| S5 | `test(godot): verify flora recipes, habitat rules and tier budgets` | Persisted settings, tests registered in M0, benchmark scene registration and population output, and this report. |

The Godot paths above are relative to `godot/`. The placement and prop files contain hunks for several slices.

## Extending the flora

Add a row with the lore ID, growth form, height and altitude ranges in metres, habitat, chance, base sRGB colour, spread, branching angle, levels and leaf size in centimetres. The generator accepts optional `fruit`, `flower`, `veins`, `margin`, `tips`, `caudex`, `glow` and `sheltered_colour` fields. `patch_count` and `patch_radius` control neighbours. For the forthcoming valley species use the existing `meadow` habitat. The fruit option decorates woody crowns, the flower adds a petalled stalk, and the herb/rosette recipe accepts warning veins. The council's pending species have no speculative lore IDs in the table.

Two shape variants per species and detail level share mesh memory across instances. The generator checks the actual mesh height before scaling each specimen. Foliage uses two-sided cutouts, a backlight term and position-phased wind with the 1.6 multiplier. Trees, shrubs, vines and larger rocks switch to lower-detail geometry. Small plants and scree drop out at the near limit. Spatial batches use terrain-chunk width capped by near visibility distance.

## Verification

- Godot 4.7.2 headless. `make godot-test` passed 703 checks and `make godot-ui-test` passed 538. The original M0 suite passed 593 checks before the changes. The suites also emit existing diagnostics for negative test cases and resource cleanup.
- Standalone `--check-only` passed for the generator, placement, prop renderer, flora test and terrain benchmark scripts. Directly checking `island.gd` as a standalone main script cannot resolve the project autoload `Game`. The two benchmark runs instantiated that script in the full project and exercised stage setup, prop creation and the nest.
- Tests check both directions of the lore ID mapping, growth forms and height ranges, same-seed mesh arrays and ordered instance-list hashes, a different layout seed, water and spawn clearances, ground contact, grade, rock presence and the single spring tree. A controlled volcanic-material test covers the moisture-dependent crust, tussock, rosette and mineral-seep habitats.
- On seed 1 with the cone enabled, a separate high-density pass found all 16 species and all three rock types. The no-wild probe produced 16,600 records in 695 ms. The same probe on the default island produced 13,068 in 647 ms. A second Godot process reproduced both ordered-list hashes, 2672209765 for default terrain and 1254500107 with the cone. The integrated island also excludes its wild spawn locations. The low placement test took about 0.30 s. These are one-time CPU placement timings.
- Work stayed uncommitted. The C sources and goldens have no edits. The native extension was built with a worktree-local copy of the shared Godot C++ dependency.

## Tier budgets and benchmark

| Flora tier | Cell sampling probability | Near detail / small-prop limit | Distant silhouette limit | Seed 1 integrated instances | Resident MultiMesh batches |
|---|---:|---:|---:|---:|---:|
| Low | 0.34 | 90 m | 460 m | 5,176 | 2,410 |
| Medium | 0.57 | 135 m | 720 m | — | — |
| High | 0.87 | 190 m | 1,050 m | 13,057 | 2,283 |

Auto uses the low flora budget on adapters classified as integrated/software by the existing terrain resolver and high on discrete adapters. The explicit quality setting selects each row. Low uses smaller spatial batches. Resident counts include both LODs across the island. In `settings.cfg` under `[game]`, `flora_density=-1.0` selects the tier default, and a value from 0 through 1 overrides sampling. `flora_lod_scale=1.0` multiplies both distances, with supported values from 0.25 through 3. The nest and spring landmark remain available at zero scatter density.

`make godot-terrain-bench` ran with `GODOT='godot --headless'`, seed 1, 252,000 existing grass blades, 120 warmup frames and 600 timed frames per view. The benchmark registered the island as the current scene before its ready signal so devtools could bind it normally.

| Scene-loop frame time, mean / p95 | Chase | Mid | Far |
|---|---:|---:|---:|
| Low | 8.09 / 13.22 ms | 7.28 / 9.07 ms | 6.98 / 7.85 ms |
| High | 7.38 / 13.42 ms | 6.90 / 7.49 ms | 6.90 / 7.06 ms |

The headless viewport reported an empty adapter and 0 ms GPU time. These samples include engine scheduling and scene updates. GPU cost, draw calls, alpha overdraw, shadow cost and rendered frame budgets require a graphics run.

## Open art and geography questions

- Terrain v5 exports freshwater, caves and volcanic material. It has no named spring/dyke, impact deposit, lava age or vent-temperature field. The provisional spring is the nearest eligible eastern freshwater margin. Hierroflor uses a seeded lowland depression and a bent deposit trace independent of the volcano. Wet volcanic pockets and patch noise stand in for suitable mineral seeps and lava succession. Replace these proxies when the site registry supplies authoritative locations.
- The rendered snow belt is around 365 m. Rodela uses the terrain snow material and locally sheltered relief there. Its recipe retains the canon altitude range of 1,750–2,050 m for future terrain at lore scale. Colonies on cave mouths are exterior placements. Interior tube geometry and seasonal simulation are outside this visual layer.
- The route data exposes no corridor mask here. A root must satisfy grade ≤1.26 on both its actual visual facet and the smoothed sim surface, across the island. The exclusion also covers ponds, padded river ribbons, a 10 m radius around nest/spawns, and deep tidal water. Only tidal algae enter the shallow sea fringe.
- Sonnet should judge whether two crown variants provide enough variation, whether blade cutouts shimmer on the Radeon, whether the nest rim reads at chase and mid zoom, and whether chunk LOD transitions need tuning. The seed and Godot build are part of the determinism check. Cross-engine and cross-architecture identity have not been measured.

## Capture and integration checklist for Sonnet

1. Commit the slices and run the two headless suites. Use seed 1 with normal wild spawns. Capture the starting nest at ground, chase and mid zoom with the player for scale. Check the grass edge, scraped floor and woven rim. Move to a saved setup with a different nest and confirm the model and clearing follow.
2. On high, inspect the Madre near world X/Z **(27, 13)**. Frame its buttresses, bank clearance and whole crown. Inspect a Nieblón and vine around **(-262, -331)**. Approach and recede through the tier LOD boundary while watching the silhouette and ground contact.
3. Capture the river thicket near **(36, 6)**, coast near **(1198, 241)**, shallow ribbons near **(-1123, 715)**, snow rosettes near **(200, 790)** and the meteor plant near **(464, 774)**. These high-tier probe coordinates are approximate. Stage reservations can suppress individual plants.
4. Enable terrain parameter `volcano=1` on seed 1. Inspect red crust around **(124, -292)**, ash tussocks **(163, -266)**, lava tongues **(140, -339)** and mineral film **(452, -288)**. Examine atlas scale on the scree field and outcrop near **(164, -268)**. Include a close shot and a grazing view.
5. Capture GL compatibility under xvfb and Forward+ on the RTX. Compare the same low and high camera positions, shadows, cutout edges, pigment and photo colour to nearby terrain. Record any shader compiler diagnostics.
6. Run `make godot-terrain-bench TIER=low` on the AMD iGPU and `DRI_PRIME=1 make godot-terrain-bench TIER=high` on the RTX. Keep the same seed, resolution, grass count and views on the parent for the comparison. Record adapter, renderer, mean, p95, GPU ms and draw calls for chase, mid, far and cliff views, plus a grove close-up. Use `make godot-terrain-bench-sw` for the xvfb software comparison. Record separate results for loading time and peak memory.


## Integration pass (Claude, after the lore flora addendum)

### Commits

The three Codex slices were committed as `feat(godot): generate plants from flora recipes`, `feat(godot): populate island habitats, rocks and nest weave` and `test(godot): flora recipes, habitat rules, tier budgets`, then `claude/v0.1-restore` was merged in (it brought the four start-valley plants and the renamed English names). Two further commits add the four species and the visual fixes, and the evidence script, bench switch and tests.

### Four new start-valley plants

All four are rows in `game/data/flora.json` with a bilingual `name` taken from lore. The test now compares each name and height range with `lore/flora/*.json`; heights of Sweet Straw (0.08-1.2 m) and Snowshield (1.5-2.5 m) were also re-synced.

| Plant | Form and recipe | Placement (new habitat zone) |
|---|---|---|
| Perlilla / Wellberry | upright multistem shrub, small ovate leaf cards along the stems, wax-white pendant berry clusters on lower twigs (`fruit`) | `wet_fringe`: soil within bank reach of fresh water, east of x = -110, 15-350 m |
| Velilla / Dawnlamp | corm herb, narrow basal leaves, one scape with eight cream petals and a charcoal centre (`flower`, `flower_centre`) | `hollow`: gentle meadow ground with positive pocket noise, 15-400 m |
| Caramillo / Whistlewood | tree, 3 levels, 55 degrees, matt green, fluted 12-sided trunk | `valley_edge`: moderately sloping soil above the floor, pocket noise > 0.18, 30-550 m, > 60 m from the nest |
| Vetirroja / Redvein | soft stem with opposite serrated leaf pairs, red-purple veins (`arrangement: opposite`, `veins`) | `disturbed`: 10-80 m around the nest and the wild spawn points (stand-in for dung and feeding remains), 15-450 m |

Seed 1 low tier now places about 58 perlilla, 136 velilla, 10 caramillo and 14-19 vetirroja. The alula carrier named in the strict review does not exist in the valley, so the hooked capsules are not modelled; the plant is a visual warning only.

### Visual fixes made after looking at the frames

- Rock props rendered nearly white: `prop_rock` sampled the sRGB atlas with `source_color`, while the terrain decodes it by hand. It now decodes the same way and the boulders read as dark andesite or basalt. Boulders and outcrops are four overlapping 13-sided lumps instead of a single octahedron.
- Foliage: grazing Fresnel made flat blades and leaf cards read white, and the backlight term washed leaves pale. `SPECULAR` is 0.12, backlight 0.1.
- Crowns were nearly black from above. Colours for Springmother, Fogcomber, Whistlewood, Wellberry and Canopy Rope were raised, and the bark colour lifted. Bark rods get a per-facet shade so trunks no longer read as one flat colour. Springmother buttress fins are smaller.
- Snowshield: the caudex was a black flowerpot. It is now a thin buff stem with a hanging dead-leaf skirt, and the red-purple margin is limited to the blade tips.
- Beacon Moss was a few blue-black boulders. It is now about 70 small flat green cushions. Crusts are flat and darker. The Saltweeper spread was reduced to 0.7 and its crown turned into a compact shrub.
- Nest: the earth skirt is lighter, the straw rim keeps its thin stems, and twigs are thinner.
- `island_props.records` exposes the placed instances for the evidence script.

### Verification

`--check-only` passes for the generator, placement, props, island, tests and evidence script. After the merge: `make godot-ui-test`, `make godot-play-test` and `make godot-creature-test` passed before the last mesh tweaks (shrub foliage, rocks); `make godot-test` was rerun after them: `make godot-test` 751 checks, 0 failures (flora test included); `make godot-ui-test` 702, 0 failures; `make godot-play-test` 217, 0 failures; `make godot-creature-test` 1471 and 64 realism checks, 0 failures. The headless suites log a GLES shader compile warning from creature materials under the software context; it is not from flora.

### Frame times with flora on and off

`make godot-terrain-bench-sw TIER=low|medium` under xvfb and llvmpipe, 40 frames, 10 warmup, 60000 grass, 1280x720, `BENCH_FLORA=0` disabling scatter (the nest and spring tree stay). The machine was heavily loaded by other jobs, so absolute values are 1-3 orders above a GPU and run-to-run noise is large; only the ratios are of use. Mean ms per frame:

| Tier | Flora | chase | mid | far | cliff_lit |
|---|---|---:|---:|---:|---:|
| low | on (first run, loaded) | 3238 | 2169 | 1849 | 1774 |
| low | on (rerun) | 2190 | 1229 | 1413 | - |
| low | off | 1850 | 809 | 845 | 903 |
| medium | on | 1364 | 827 | 829 | 1210 |
| medium | off | 1271 | 803 | 837 | 1147 |

Medium is within about 3-7 percent in the near views and equal in the far view. Low swings widely with background load (reruns of the on case differ by 40 percent), so the +18 percent in the chase view is the safest reading. This does not predict GPU cost: real draw calls (about 2,500 batches at low), alpha overdraw of cutouts and shadow passes still need the RTX and the AMD iGPU run listed in the checklist above. `make godot-terrain-bench` itself (windowed, GPU) was not run; the sw variant was the only one possible under xvfb.

### Evidence (`docs/evidence/godot/flora/`)

JPG, 1280x720, llvmpipe, 60000 grass blades. Suffix `-volcano` frames come from seed 1 with `volcano=1` (the shipped seed-1 terrain has no cone, so the lava species only exist there). `-low`/`-medium` are the same camera on those tiers. Close-ups: `plant_<id>.jpg` for every species (the base island has 16 of 20; the other four are in the `-volcano` frames). Scenes: `valley_chase_z0/z35/z70`, `nest_ground`, `nest_high`, `valley_east/west`, `vista_wide`, `vista_island`, `forest_edge`, `forest_floor`, `madre_spring`, `madre_base`, `snow_rosettes`, `snow_slope`, `riverbank`, `coast_spray`, `coast_tide`, `lava_tussock/crust/tongue/wide`, `meteor_plants`, `tier_valley`, `tier_forest`.

Honest visual assessment: the forest, the meadow trees, the vista and the snow rosettes read well and are plausible in height and colour. Everything is still low-poly and flat-lit rather than photographic: crowns are stacked cutout cards, trunks have visible facets, and the fog forest is dark. The Springmother next to the start river is large enough to be a landmark, and the valley frames show correct scale against the creature. Weak spots that remain: sulfur and ember crusts are still faceted flakes (sulfur is too saturated yellow), the moss is blocky, Wellberry berries are small and hard to see at any distance, `snow_slope` and some `soga_de_dosel` close-ups are poorly framed (camera inside terrain or canopy), and the low and high tier frames look the same at the valley camera because the difference is in scatter density, not near detail. The white ellipses in the meadow in the start frames are not flora (they remain with scatter off).

### Open questions

- The Springmother sits about 40 m from the nest in the river bend; is that the intended spring site (the dyke is still a proxy)?
- Should tier differences be shown with a denser meadow camera and no grass, or is the instance count table enough?
- GPU numbers, shader compile diagnostics on the Radeon and the Forward+ look are still open.
- The hooked-capsule and alula link of Redvein is not drawn; the alula is not a valley animal.
