# Plan: make the island look natural and alive (world look, 2026-11-19)

Planner: Opus 5.5 (plan only, no code). Base: `claude/v0.1-restore` @ c98dbd2 (the repo's working main).
Implementers: **Sonnet** = Claude Sonnet 5.5 subagent in its own worktree (Godot/visual, takes xvfb screenshots);
**Codex** = `gpt-6.1-sol` sandboxed (headless C/C++, leaves work uncommitted, a Sonnet commits and captures afterwards).
Shared rules: `_agent/briefs/_rules-godot.md`. Sizes: S ≈ 1 day, M ≈ 2–4 days, L ≈ 1–2 weeks of agent time.

## 0. Diagnosis (from the current frames, docs and code)

Frames looked at: `docs/evidence/godot/flora/{valley_chase_z35,valley_east,vista_wide,riverbank,forest_floor,madre_spring}.jpg`,
`terrain-photo/after/{close_cliff,close_scree,cliff_lit,coast}.jpg`, `secrets/{cave_mouth,cave_passage}.jpg`, plus two new xvfb
captures in `_agent/world-look/captures/` (`rk_boulder_{close,wide}`: near-black faceted blobs on a photo-textured slope; `rk_scree_close`: a black lump cluster; `rk_meadow_*`: spike-shaped grass on a flat green sheet; no outcrop was placed on seed 1).

**The root cause behind "playground": two lighting worlds and two art styles.**
1. Terrain, grass, river and lake shaders are `render_mode unshaded` with their own toon sun (`terrain_body.gdshaderinc`,
   `grass.gdshader`, `water.gdshader`, `river.gdshader`). Flora and prop rocks are lit by Godot's sun. So the ground **never receives
   a shadow** (trees, rocks, creatures cast none on it; the creature gets a fake disc), SSAO/SSIL on the RTX tier do nothing to the
   ground, and every object floats on a flat sheet. This alone makes plants look "popped in".
2. Style split: rock/scree/sand are photographic (ambientCG, terrain/rock-textures), the meadow is a flat saturated toon green with
   no texture, grass blades are flat unshaded strips. Photo rock next to toon grass is the Garry's Mod read.

**Grass "weird"** (`grass.gd`, `grass.gdshader`): 3-triangle wedges 12–25 cm wide and up to 1.2 m tall, unshaded, one light value per
blade from the root normal (no gradient across the blade), clumps of 8 on a torus of side 88 m (the same pattern repeats every 88 m),
blade colour unrelated to the ground under it (dark green sheet, light green strips), hard edges where the mask stops (riverbanks).

**Plants "popped"** (`flora_placement.gd`): a jittered 20 m grid, one species per point, chosen uniformly from the zones that match,
patches of ≤ 5 within a fixed radius; random height inside the recipe range, no age classes, no seedlings or snags; no ecotones (forest
is "x < -110 m"); no ground change at trunk bases (no root flare, litter, moss, darker soil, grass exclusion); no understory tied to
trees; moisture/light are only binary zone tests; no shadows (point 1). 20 recipes exist and are good individually (FLORA-ART reports).

**Rivers**: pale opaque ribbons 2.6 m+ wide on every D8 stream (4,254 stream + 721 shallow + 343 deep cells on seed 1, so ~80 % of the
ribbons are the *stream* class that the sim treats as dry land), a dark grey "wet gravel" halo that reads as a concrete gutter, D8 zig-zag;
the lake is the generator's circular bowl (r 68 m) drawn with visible quad seams.

**Rocks**: (a) prop boulders (`island_props.gd` + `prop_rock.gdshader`): 4–6 ellipsoid lumps with 5–13 sides (faceted), raw photo
albedo with no palette normalisation, one 1.7 m triplanar tile, no normal map, `cull_disabled`, no per-instance variation, placed by a
32 % coin flip on rock cells; they render almost black against the palette-normalised terrain. (b) terrain rock: the photo layers are
fine up close but the tuff/mineral patches read as pasted decals and scree areas are blobs with hard outlines.

**Caves**: `cave_site.gd` sweeps one semicircular arch ring (12 segments, ±12 % wobble) for 14 m, then a half-ellipsoid dome; vertex
colours, flat floor: a pipe. The mouth is a dark arch shell sitting on the slope, not a hole in rock. The C rule
(`cp_stage_secrets_ground`: passage half-width 4 m, length 14 m, chamber r 10 m, floor flat at the entrance floor) is fine and stays.

**Cliffs: yes, they exist** (TERRAIN.md: `sea_cliffs`, `cliff_bands`, `hard_rock` strata, all default 1). They don't read as cliffs
because a 3.5 m heightfield cannot be vertical or overhang (bedrock angle 62°, scree at 38°), v5 bounds the visual field to the sim,
the photo rock is smeared on 50–60° faces, there is no cliff lip, ledge, overhang or scree cone, and the sea "cliff" is a 38 m shelf.

**Spring**: today it is the Madre de agua tree placed on the nearest river bank east of the nest. There is no water source.

**Predators**: 6 species, all roam inside 20–30 m of a home point (`CP_STAGE_SPECIES[].roam`, straight-line goals, no A*); max 24 wild.

## 1. Slices, ordered by impact on the first 10 minutes

Every Godot slice: before/after frames from the same cameras (`flora_evidence.gd` cameras + `valley_chase_z0/35/70`) at 1280x720
under xvfb, `make godot-test godot-ui-test godot-play-test` green with counts, llvmpipe bench ratio on chase/mid/far (relative only,
the RTX number is the owner's), and a `docs/godot/<TRACK>.md`. No C golden, terrain hash or route fixture changes unless stated.

### WL1 · One light for the whole world (Sonnet, M) — first, everything else builds on it
- **Goal**: ground, grass and water receive the sun shadow map and the environment's ambient/SSAO, like flora and creatures do.
- **Files**: `shaders/terrain_body.gdshaderinc`, `terrain_{low,medium,high}.gdshader`, `grass.gdshader`, `water.gdshader`,
  `river.gdshader`, `island/environment.gd`, `creature/render_tier.gd`, `island/look.gd` (+ `test_look.gd`).
- **Method**: drop `unshaded`; keep the existing toon/soft ramp but move it into a `light()` function (`DIFFUSE_LIGHT +=
  ramp(dot(N,L)) * ATTENUATION * LIGHT_COLOR`), albedo = current colour before the ramp, so the far palette is preserved. Grass: lit,
  normal bent from the ground normal toward the blade (fake round blade), receives shadows (near ring only), keeps `occ` push.
  Sun shadow distance 80 m → split 4 cascades to 200 m on high, 2 to 120 m on medium, off on low (low keeps baked `sun_visibility`
  and turns it on by default). Turn the remaining fake creature disc into contact AO only. Low tier stays unshaded (fallback define).
- **Acceptance**: tree, boulder and creature shadows visible on meadow and rock in `valley_chase_z35`, `madre_spring`, `forest_floor`;
  far view mean colour within 4/255 of before on the rock and meadow masks; llvmpipe medium ratio ≤ 1.3 on chase; play test green on
  all three tiers. Owner check on the RTX: same frames in Forward+ with SSAO.

### WL2 · Meadow ground and grass rework (Sonnet, M)
- **Goal**: the ground under the grass is soil-and-turf with variation; the grass is fine, varied and rooted in it.
- **Files**: `terrain_body.gdshaderinc` (meadow branch), `rock_photo.gdshaderinc` (atlas), `tools/bake_photo_textures.py`,
  `textures/photo/*` + `CREDITS.md`, `island/grass.gd`, `grass.gdshader`, `island/terrain_data.gd` (new ecology map, see WL3).
- **Method**: two CC0 ground layers (turf/soil, dry grass/litter) added to the photo atlas with the same palette normalisation,
  macro patches of lush/dry/clover/bare soil by moisture (wetness + flow), slope, convexity and a world noise; worn soil around the
  nest and on the graded trails. Grass: curved 5-vertex-pair blades 3–6 cm wide, 0.15–0.7 m, 12–20 per clump; height, density and
  hue from the ecology map (taller and greener near water, short and yellow on convex dry ground, none in deep shade or on trails);
  blade root colour = ground albedo at the root, tip lighter; per-world hash rotates and offsets each 88 m tile so the torus never
  repeats visibly; one coherent gust field (scrolling noise) drives grass, flora `bend` and later dust.
- **Acceptance**: no flat-colour meadow pixels in `valley_chase_*` (luminance std in a meadow crop ≥ 2× before); no repeated clump
  pattern in a 300 m top-down frame (autocorrelation peak at 88 m below 0.2); grass edge at riverbanks fades over ≥ 2 m;
  tier budget as WL1. Owner A/B frame pair.

### WL3 · Ecological placement v2 (Sonnet, L; Codex optional for a C++ port if GDScript is > 3 s)
- **Goal**: plants follow moisture, light, soil and disturbance; they cluster, age and blend into the ground.
- **Files**: `island/flora_placement.gd` (rewrite), `island/island_props.gd`, `data/flora.json` (new fields), new
  `island/ecology_maps.gd` (or `extension/ecology.cpp`), `tests/test_flora.gd`, `tests/flora_evidence.gd`, terrain cache version.
- **Method**:
  1. *Fields* per 3.5 m cell, cached with the terrain entry: moisture (river distance, flow, wetness, lake/sea), light (aspect × slope,
     later canopy), soil depth (sediment, deposition, minus exposure), disturbance (nest, trails, river floodplain), temperature (altitude).
  2. *Suitability* per recipe as a product of smooth response curves over those fields (new `niche` block in flora.json, replaces the
     binary zones but keeps `habitat` as a fallback), so species blend into each other across ecotones.
  3. *Clustered sampling*: Poisson-disk per layer (canopy trees, shrubs, herbs, ground cover) with radius ∝ 1/suitability; trees grow
     from seed parents with a dispersal kernel (clumps and gaps, denser downhill and along water); age classes (seedling, sapling,
     adult, old, snag, fallen log) with size from age × suitability, not uniform random; forest edge gets a shrub/sapling mantle.
  4. *Companions*: each adult tree spawns understory (ferns/pluma_de_sombra in its shade, pan_de_humus, litter) inside its crown
     radius; shrubs under-plant herbs; rocks get moss on the windward/north side and herbs in their lee.
  5. *Grounding*: root flare in `flora_mesh.gd` trunks (3–5 buttress roots sinking 0.3 m), a ground decal per tree/rock (darker
     soil, leaf litter, moss ring, AO) via the existing `ground_marks.gd` path, grass exclusion radius and shorter grass under crowns
     (the ecology map's canopy term feeds WL2), small random lean (≤ 4°) toward the downhill light for trees on slopes.
- **Acceptance**: same seed gives identical records (test); Ripley's K on trees shows clustering (L(r) > r at 10–40 m) where v1 was
  random; ≥ 90 % of trees have a companion within their crown; nearest-neighbour species mixes at the forest edge over ≥ 40 m;
  no plant on trails/river ribbons (existing masks); placement time ≤ 3 s at medium; frames `valley_east`, `forest_edge`,
  `forest_floor`, `riverbank`, `vista_wide` before/after. Owner verdict on "playground".

### WL4 · Rocks that belong (Sonnet, M)
- **Goal**: boulders and outcrops share the terrain's rock, vary, sit in the ground and gather where geology puts them.
- **Files**: `shaders/prop_rock.gdshader` (rewrite on `rock_photo.gdshaderinc`), `island/island_props.gd`, `flora_mesh.gd` or new
  `island/rock_mesh.gd`, `flora_placement.gd` (rock part), `tests/test_flora.gd`.
- **Method**: *Material*: include the terrain's photo functions: palette normalisation (divide by sheet mean × palette colour),
  stochastic two-shift taps + macro scale, the pack normal map, per-instance hue/value/scale jitter (`INSTANCE_CUSTOM`), layer chosen
  from the terrain material under the rock (andesite on rock, basalt on volcanic, tuff/strata where the cap-rock phase says), moss on
  up-facing and north faces by world noise and wetness, dirt/darkening near the ground line (height above `visual_ground`), cavity AO
  from the mesh. Back-face culling on. *Meshes*: procedural boulders from a subdivided icosphere (≥ 320 tris near) displaced by ridged
  noise and cut by 2–4 random planes (fracture faces), smooth normals with hard edges only on cuts; 8 variants per kind; sink 20–40 %
  into the ground. *Placement*: boulders where geology drops them: talus apron map below cliffs (cones of decreasing size downhill),
  river beds and banks (rounded, smaller), glacial erratics on meadows (rare, big, alone), outcrops poking out of convex ridges
  (exposure map), never a coin flip per cell.
- **Acceptance**: rock prop mean colour within 8/255 of the terrain rock under it at 30 m; no two neighbouring boulders share mesh
  and orientation; `rk_boulder_close/wide` frames (script in §3) show embedded, lit, mossy rocks; talus cones visible under the
  cliffs in `cliff_lit`. Also fix the terrain's decal-like tuff patches: soften the patch mask edge and drive it by the strata phase.

### WL5 · Water: rivers reduced and redone, a lake that is not a circle, the spring (Sonnet, M)
**Decision first (owner, §4 Q1).** What rivers give the design: the sim's water levels (fords = shallow, deep = blocked until C4
swimming), the waterfall that the first cave prefers (G65/W18), the C4 water secrets (sunken bones, waterfall cave, ink jet), a reason
to drink later, routes and certified trails (`ROUTES-REPORT`, 288/288 per seed with fords), and the hashes in `world-field-1` and the
route fixtures.

| Option | What | Cost | Risk |
|---|---|---|---|
| A. Improve only | new shader and banks, all ribbons stay | S, Sonnet | the spaghetti stays: 80 % of ribbons are dry-land streams |
| **B. Reduce visually + improve (recommended)** | draw ribbons only for shallow and deep classes, plus the one stream chain that starts at the spring; every other *stream* cell (dry and walkable in the sim already) becomes a dry gully: gravel, damp soil, reeds, no water | M, Sonnet; no C change, no golden or route change | streams on the map no longer look wet (consistent with the sim) |
| C. Reduce in the generator | raise the stream threshold or keep one trunk | M, Codex + re-certification; terrain hash, `world-field-1`, route fixtures, shard and cave placement all move | routes 288/288 to re-run on 3 seeds; waterfall cave may move |
| D. Remove (`rivers 0`) | no carved channels | M, Codex + same re-certification | loses fords, the waterfall cave, C4 water secrets; the valley reads dry |

- **Method (B)**: `rivers.gd` filters chains by class and by the spring chain; river shader: transparent with depth from the depth
  buffer (Forward+/mobile; GL compat keeps the current depth-from-ground), refraction offset, bed pebbles visible in the shallows,
  flow-aligned normal ripples, foam only on rapids, width from `width_for` × 0.7, edges that follow the bank contour (no straight
  ribbon edge), Catmull-Rom centreline (kills the D8 zig-zag). Banks: replace the grey wet-gravel halo with wet soil + pebbles +
  reeds (`trenza_de_ribera`), fading over 2–4 m. Lake: shoreline mask from the real pond level with noise-broken wet sand, reeds and
  rocks so the circle reads as an irregular shore; remove the quad seams (one continuous mesh with smooth shore alpha).
- **Spring (manantial)**: move the spring to the **head of the stream chain nearest the nest** (a river source cell, so the water
  starts there). Build: a rock seep (two or three WL4 boulders and a cleft), a small pool 3–5 m across (local water mesh at the source
  water level), bubbling sand particles and rings on the pool, a thin overflow trickle that becomes the visible stream, moss and ferns
  on the wet rocks, Madre de agua leaning over it, light god-rays at dawn on high tier, a loop of trickling water sound. Later hook: the
  C4/C3 "drink" action targets this pool.
- **Acceptance**: `vista_wide` shows the trunk, the lake inlets and one stream from the spring, not the web; ribbon pixels drop ≥ 60 %;
  `riverbank` and a new `spring_close`/`spring_wide` frame; routes untouched (`make routes-test` unchanged, no C diff).

### WL6 · Caves that are caves (Codex for the mesher, Sonnet for art and integration, M–L)
- **Goal**: irregular chambers and passages, a mouth carved into rock, with the C walkable rule unchanged.
- **Files**: new `godot/extension/cave_mesher.cpp` (+ binding `CporeTerrain.cave_mesh(params)`), `island/cave_site.gd`,
  new `shaders/cave_rock.gdshader`, `tests/test_secrets.gd` (+ a new cave mesh test).
- **Method**: describe the cave as a signed distance field: the walkable volume (passage box and chamber cylinder from the C rule,
  floor at `floor_h`) unioned with non-walkable volume above and beside it (ceilings 3–9 m, side alcoves, a higher dome with a
  collapse chimney), all displaced by 3D noise (0.5–3 m) **only outward and upward** from the walkable footprint + 0.6 m, so the
  floor is exactly where the sim walks and no wall intrudes. Mesh with marching cubes on a 0.4 m grid (deterministic C++,
  ~20–60k tris), smooth normals. Dressing: stalactites (instanced cones where the SDF normal points down, weighted by drip noise),
  stalagmites and collapse blocks only outside the walkable footprint, flowstone on walls; floor: wet patches, puddles with
  reflections on high tier, gravel. Light: a daylight shaft and falloff from the mouth (light energy by distance along `u`), darkness
  inside, the cold glow patches as irregular organic shapes. Mouth: the SDF opens through a WL4-style rock outcrop mesh that covers
  the terrain notch, so the opening is a hole in rock, with scree and ferns at the lip.
- **Acceptance**: GDScript test samples 500 points: floor height = `cave_site.adjust()` ± 2 cm inside the walkable footprint and no
  mesh triangle inside the walkable volume below 2.5 m clearance; secrets tests (35) and routes `cave-chamber` unchanged;
  frames `cave_mouth`, `cave_passage`, `cave_chamber` before/after; triangle and draw budget logged.

### WL7 · The false wall ("you should dig here") (Codex for C, Sonnet for the cue, M)
- **Goal**: a readable breakable wall with a reward behind it, before digging (C5) exists.
- **Recommended place**: the back of the existing chamber, opening into a small second room (r 4–5 m) with a fossil or a recipe
  clue. The certified route to the chamber stays as it is.
- **C (Codex)**: `stage_secrets.c`: a wall object (id 3010) on the chamber wall; while intact, `cp_stage_secrets_ground` keeps the
  side room unwalkable (step); a **charge** or any attack on the wall within 3 m adds damage, three hits (or one charge at full
  speed) crack it, the fourth opens it: room becomes walkable, event `wall_cracked {stage}` / `wall_broken`; hashed only when the
  secrets bit is on; snapshot field. Tests in `test_secrets.c`; routes add `cave-sideroom` reached after breaking (planner path in
  the test after a scripted break). Goldens unchanged with secrets off.
- **Cue (Sonnet)**: different stone (pale layered sediment against the dark cave rock) with a hairline crack network; dust motes and a
  leaf drifting toward the crack (the draft); a faint whistle that gets louder near it; grass/ferns bending toward the gap at the
  outdoor variant; `observe` on it gives a clue line ("air moves behind this stone"); crack decals grow per stage; break = debris
  burst, rubble left at the base (outside the walkable path).
- **Acceptance**: break sequence frames (intact, cracked, open) and the side-room frame; C tests; routes green.
- **Reuse**: the same object later marks soft ground for C5 digging (one component, two triggers).

### WL8 · Cliffs that read as cliffs (Sonnet, M)
- **Goal**: vertical faces, ledges and overhangs where the generator already has steep rock.
- **Method**: a cliff mask (visual slope > 52° and exposure) drives (a) *cliff kit meshes*: procedural slab and column pieces
  (WL4 mesher with strata-aligned cuts) instanced along the steep bands, leaning out by up to 2 m to make vertical/overhanging faces
  (they stand on unwalkable cells, so the sim is unaffected; feet never touch them), (b) a turf lip that overhangs the top edge,
  (c) talus cones and scree fans at the base from the apron map (shared with WL4), (d) shading: strata lines continuous across kit and
  terrain, vertical water streaks below seeps. Sea cliffs get the same treatment, plus wave foam at the toe.
- **Acceptance**: `cliff_lit`, `coast`, a new `cliff_from_valley` frame; mask coverage report; no kit piece on any cell the walk
  grid marks walkable (test against `nav_cell`).

### WL9 · Roaming predators (Codex for C behaviour, Sonnet for bodies and animation, L)
- **Fit**: ECOLOGY.md (branch `m-ecology`, not merged; merge it first as the roster source) lists apex/meso predators per biome.
  Proposed three, all readable at 80 m by silhouette and gait:
  1. **Garfio pack patrol** (exists, upgrade): 3 Garfios walk a 600–900 m loop around the valley rim by day, rest at a den at
     noon; howl before engaging; the player hears them before seeing them.
  2. **Acechador** (ECOLOGY #12, new): solitary stalker, low and long with three eyes; follows the player at 40–60 m in tall grass,
     circles, charges when you turn your back or are hurt; leaves if you face it (intimidate works).
  3. **Glacior** (ECOLOGY #18, new) or **Sombrío** (#7): a high-pass hunter on the col/alpine routes, so climbing has a threat.
     Sombrío overlaps the Acechalunas (night ambusher), so Glacior is the recommendation.
- **C (Codex)**: per-species `patrol` block (den, 4–8 waypoints picked at setup from the walk grid on the certified network,
  deterministic from the field hash), wild creatures follow waypoints with the existing A* (`plan_path` generalised to an entity,
  budget: one plan per waypoint change, cap 50k expansions, cached), states `patrol / rest / stalk / charge / leave`, stalking
  distance and break-off rules in fixed math; species count 6 → 8 (`CP_STAGE_SPECIES_COUNT`, `CP_SOC_SPECIES`, social tables,
  parts drops), hashed only when present; `CP_STAGE_MAX_WILD` 24 → 32 if needed (snapshot format bump). Tests: patrol loop
  determinism, replay, no path through deep water, stalk/leave rules, tourney unchanged.
- **Godot (Sonnet)**: species JSON bodies (like `babosa.json`), tracks/scent marks on the ground (`ground_marks.gd`), audio cue, map
  icon only after first sighting; evidence of each predator patrolling (frame strip) and the stalk.
- **Acceptance**: `make test`, routes 288/288 (+ new places), soak 10 min with no stuck predator (> 30 s without progress).

### WL10 · Polish that ties it together (Sonnet, S–M, after WL1–WL5)
- Wind coherence: one gust field for grass, leaves, river ripples and dust (WL2 field), visible gust fronts crossing the meadow.
- Atmosphere: height fog in valleys at dawn, aerial perspective already exists; volumetric fog on high tier by default (owner).
- Small life: insects over water, pollen, birds as specks circling cliffs; falling leaves in the forest.
- Litter: fallen logs, branches, bones near predator dens (feeds WL9 storytelling).

## 2. Order, parallelism and who

| Step | Slices | Who | Parallel? |
|---|---|---|---|
| 1 | WL1 light | Sonnet | alone (touches every shader) |
| 2 | WL2 ground+grass, WL4 rocks, WL6 mesher (C++ part) | Sonnet, Sonnet, Codex | yes, separate files; WL2/WL4 share `rock_photo.gdshaderinc` (WL4 only reads it) |
| 3 | WL3 ecology, WL5 water+spring, WL7 C part | Sonnet, Sonnet, Codex | yes |
| 4 | WL6 art, WL7 cue, WL8 cliffs | Sonnet ×2 | yes |
| 5 | WL9 predators (C first, then bodies) | Codex, Sonnet | C can start in step 2 |
| 6 | WL10 | Sonnet | — |

Owner play gates: after step 1+2 (light, grass, rocks), after step 3 (ecology, water, spring), after step 4 (caves, cliffs, wall).

## 3. Evidence tooling (shared)
- `godot/game/tests/world_look_evidence.gd` (new, WL1 adds it): extends `flora_evidence.gd` with rule-found cameras for boulders,
  outcrops, scree, cliffs, the spring, each cave mouth/passage/chamber and four player-height meadow views from the nest; `make
  godot-world-look OUT=dir` under xvfb software GL. A prototype used for this plan: `_agent/world-look/rocks_evidence.gd`.
- Each slice adds its frames and a before/after sheet; the owner judges on the RTX with the same script windowed (`--rendering-method
  forward_plus`, his machine).

## 4. Continent later: architecture note (no work now)

What would have to change to grow the creature stage to a continent (tens of km):
- **Generator**: stream power and priority-flood are global over one N² map (29 N² bytes, N ≤ 2048, no malloc). A continent needs
  hierarchical generation: a coarse continental pass (drainage basins, ranges, coast) at ~50–100 m cells, then per-tile detail
  conditioned on the coarse result with overlapping borders, so tiles are generated independently and deterministically.
- **C world**: one field, `bound = half - 2 cell`, a static 1024² walk grid (29 MB BSS, single signature slot), `MAX_WILD` 24 in one
  array, the hash over the whole field. Needs tiled fields with portals for the planner, an active simulation bubble around the
  player plus a coarse "off-screen" sim for far creatures, and hashing per active tile.
- **Fixed math**: float32 positions are fine to ~16 km (ulp ≈ 2 mm); beyond that use tile + local coordinates in the sim and
  camera-relative origin shifting in Godot (or a double-precision build).
- **Caches/streaming**: the terrain cache is one 38 MB file per island and the visual field one 4096² texture; a continent needs
  per-tile cache files, streaming of chunks and textures (virtual texture or clipmaps), and flora/ecology generated per tile on demand.
- **Avoid now** (cheap rules that keep the door open): read terrain only through `ground(x,z)`/`sample()` style functions, never by
  raw `[k]` index outside `terrain_data.gd`; no hard-coded ±1800 m or island size in game code; place secrets, dens, the spring and
  routes by rule relative to features (already the case), not by absolute coordinates; keep derived data (nav, ecology maps) as
  caches keyed by inputs; save positions with a world/tile id field (zero today); keep per-island arrays behind one accessor.

## 5. Owner decisions (each with a recommendation)

1. **Rivers**: A improve / B reduce visually + improve / C reduce in the generator / D remove. **Recommend B**: it removes the
   spaghetti, keeps fords, the waterfall cave and C4 secrets, and touches no C, golden or route.
2. **Art direction for the ground**: go naturalistic everywhere (photo-based ground and lit grass, matching A24 for creatures) or
   pull the rock back to stylised? **Recommend naturalistic**, palette-normalised as today, so far views keep the island's colours.
3. **Lighting**: terrain/grass/water become lit (receive shadows, SSAO) on medium and high, unshaded fallback on low. **Recommend yes**;
   it costs some GPU, you measure on the RTX and the 860M.
4. **False wall location**: back of the existing chamber with a side room (recommended), or a separate sealed cave entrance.
5. **Third predator**: Glacior (alpine pass, recommended) or Sombrío (forest, night; overlaps the Acechalunas).
6. **Merge ECOLOGY.md** (branch `m-ecology`) as the roster source for WL9. **Recommend yes**, after a quick review of names.
7. **Lake shape**: dress the circular bowl visually (recommended now) or make the generator's lake irregular later (changes hashes).
8. **Sea cliffs**: visual cliff kit only (recommended) or raise the generator's shelf height (hash and route re-certification).
9. **Caves**: allow the C++ marching-cubes mesher in the GDExtension (recommended; deterministic, headless-testable).
10. **Continent**: adopt the "avoid now" rules in §4 as a coding rule in `_rules-godot.md`. **Recommend yes**, no other work now.
