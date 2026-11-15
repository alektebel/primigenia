# Art Inventory and Gap List

Documentation only — no code changes. All facts sourced from the repository
(`web/`, `assets/`, `art/`, `core/`, `tools/hero/`, `docs/`) as of 2026-11-15.

---

## 1. Inventory: existing visual assets

Every visual asset type that exists today, where it is made, and its state.

### 1.1 Creature anatomy (rig.js)

`web/creature/rig.js` — shared anatomy/material/IK library (used by both
studio and stage). Procedural JS generation; physically lit skin material
with furrow/strain noise and clearcoat.

| Category | Parts (templates in `LIB` / `glbTemplates`) | Type | State |
|---|---|---|---|
| Mouths | `fauces` (jawed, animated), `romo` (blunt snout, jawed), `pico` (beak, animated) | Procedural JS | **Done** — IK jaw, teeth, teeth movement |
| Eyes | `ojo` (basic, blink lid), `tallo` (stalk eye, animated), `antena` (antenna with glow) | Procedural JS | **Done** — eyelid blink, stalk sway |
| Senses | `oreja` (not in rig.js LIB — placeholder?), `antena` (glow bulb) | Procedural JS | **Partial** — `oreja` absent from LIB; `antena` glow works |
| Legs | `pata` (clawed), `zanca` (stilt, not in LIB), `pezuna` (hoof), `leg_sprinter`, `leg_sucker`, `foot_spring`, `foot_hoof`, `foot_gecko` | Procedural JS + GLB templates | **Done** — IK leg, gait derived from parts; GLB variants loaded as rigid |
| Arms | `arm_grasper` (pincer, animated), `arm_smasher` (smash) | Procedural JS + GLB templates | **Done** — pincer animation, IK arms |
| Weapons | `cuerno` (horn, procedural growth), `pua` (spike), `asta` (antler, procedural growth), `maza` (club), `tail_spike`, `tail_hammer`, `sac_spitter`, `aguijón` (stinger, not in LIB) | Procedural JS + GLB templates | **Done** — growth.js procedural horns/plates/tendrils; GLB rigid parts |
| Wings | `wing_glider`, `wing_insect` | GLB templates | **Done** — loaded as rigid; mesh structure visible |
| Fins | `aleta`, `tail_paddle` | Procedural JS + GLB templates | **Done** — paddle shape |
| Digging claws | `excavadora` | Procedural JS | **Done** — shape |
| Details | `placa` (plate/guard), `cresta` (crest), `frill_fan`, `bulbo` (glow bulb, not in LIB), `lure_lantern` (GLB) | Procedural JS + GLB templates | **Partial** — `bulbo` not in LIB; `lure_lantern` loaded as GLB rigid |
| Skin | Physically lit skin material with pattern types (spots, stripes, mottle), clearcoat, wetness | Procedural GLSL | **Done** — multi-pattern, membrane subsurface, membrane backlight |
| Keratin/eye/glow | Separate materials for bone, teeth, beak, eye, iris, pupil, glow | Procedural GLSL | **Done** |

**Total unique part types defined in rig.js LIB**: ~30 procedural templates.
**GLB rigid imports**: 25 `.glb` files listed in `parts.json` under `"source": "glb"`.

### 1.2 Studio (web/studio/)

| Asset | Source | Type | State |
|---|---|---|---|
| Parts palette | `web/studio/parts.json` (50 entries), `web/studio/parts/*.glb` (25 files) | GLB + procedural | **Done** — manifest with SHA-256, LOD info, polygon budget 3,598 max |
| Spine sculpting | `web/studio/studio.js` — direct node drag, vertical bends, mirrored symmetry | Procedural JS | **Done** — P0 creator loop, Build/Paint/Test modes |
| Growth generation | `web/studio/growth.js` | Procedural JS (tube surfaces) | **Done** — 3 families (horns, plates, tendrils), deterministic |
| Creature rig preview | `web/studio/studio.js` — `createCreatureRig()` | Three.js | **Done** |
| Paint (skin regions) | `web/studio/studio.js` — seeded regions on torso/neck/tail | Procedural JS | **Done** — 3 regions exported as `cpore.creature/4` |
| Part drag-and-drop | 3D thumbnails, snap-to-body, IK legs | JS | **Done** |
| i18n | `web/studio/i18n.js` | JS | **Done** — es/en |

### 1.3 Stage / gameplay environment (web/stage/, web/creature/)

| Asset | Source | Type | State |
|---|---|---|---|
| Valley terrain (heightmap) | `core/include/cpore/world.h`, `core/src/stage_world.c` (`cp_stage_height`) — analytic value-noise, fBm, bowl flattening, lake depression, mountain mask | C procedural | **Done** — max error 0.004203 m against reference |
| Valley terrain (ground material) | `core/src/stage_world.c` (`cp_stage_ground`) — 256×256 triangular surface | C procedural | **Done** |
| Trees (scatter) | `web/studio/studio.js` (rock/3D-ring props) — placeholder rocks and 3D ring backdrop | Three.js | **Partial** — 3D ring backdrop, scattered rocks |
| Sky dome | `web/studio/studio.js` — shader sky (BotW-style gradient, sun disc, clouds) | GLSL | **Done** |
| Distant mountain ring | `web/studio/studio.js` — 3-layer procedural ridgeline backdrop | Three.js | **Done** (studio only) |
| Ground (studio) | `web/studio/studio.js` — flat ground with procedural dirt/grass patches | GLSL onBeforeCompile | **Done** |
| Grass (studio) | `web/studio/studio.js` — instanced blades, wind, no world anchoring | Three.js instanced | **Done** — ~120k blades, wind-swept |
| Species definitions | `web/stage/species/garfio.json` (schema `cpore.creature/4`), `web/stage/species/garfio-combat.json` | JSON data | **Partial** — only Garfio fully defined; other species (Rondo, Zanco, Espinodo) need species JSON files |
| Combat encounter arena | `web/engine/encounter.js` — 40×40 m flat arena overlay | Three.js | **Done** — flat arena with visual cone for attacks |
| Creature rendering (stage) | `web/creature/rig.js` + `web/studio/studio.js` creature placement | Three.js | **Done** — creature placed on terrain, shadow receives |
| Camera + controls | `web/stage/stage.js` — Spore-like pointer movement, WASD | JS | **Done** |
| Audio | `assets/audio/` — 15 CC0 files (2.1 MB total) | Ogg Vorbis | **Done** — footsteps, combat sounds, ambient wind + meadow, creature cries |

### 1.4 Hero shot / reference (web/hero/, art/reference/, tools/hero/)

| Asset | Source | Type | State |
|---|---|---|---|
| Valley reference | `art/reference/valle-primigenio.html` | Three.js (read-only reference) | **Done** — golden look reference, untouched |
| Creator reference | `art/reference/creador-de-criaturas.html` | Three.js (read-only reference) | **Done** — creature appearance reference, untouched |
| Studio reference | `art/reference/taller-de-criaturas.html` | HTML (read-only reference) | **Done** — creature appearance reference |
| Hero shot build | `tools/hero/build_hero.py` → `web/hero/index.html` | Python patcher | **Done** — merges valley + creature, 4 presets (golden, noon, overcast, night) |
| Hero grass v9 | 200k near + 52k far blades, world-anchored, shadowed, creature push, gust bands, meadow wave | GLSL + Three.js instanced | **Done** — shadowed by creature, pushed by creature body, tinted by land material |
| Hero ground (land material) | `tools/hero/build_hero.py` — `landMaterial()` with height-aware aerial perspective, meadow/rock/scree/snow shader, cavity marks, alpine turf | GLSL onBeforeCompile | **Done** — continuous meadow, alpine relief, shadow, push, backlight |
| Hero trees (V5) | 3 shapes: round broadleaf, tall poplar, gnarled — blob core + leaf card canopy, per-tree hue, backlit glow | Three.js instanced | **Done** — 3 procedural canopy types with leaf textures |
| Hero rocks & scree | `build_hero.py` — rock/shader integration with meadow ground | GLSL | **Done** — mineral/erosion stratification, scree on ledges, snow above 120 m |
| Hero sky/atmosphere | ACES tone mapping, 3-layer sky dome, 3 ring distant mountains, shared aerial haze, cloud atmosphere | GLSL + Three.js | **Done** — unified ACES pipeline |
| Mountain debug | `build_hero.py` — debug mode for mountain eligibility (rock face, snow, scree) | GLSL | **Done** — for W15 alpine style verification |
| Hero capture tool | `tools/hero/capture_grid.cjs`, `check_grass_anchor.cjs` | Node.js | **Done** — SwiftShader grid capture, grass anchor check |

### 1.5 Terrain lab (web/terrain-lab/)

| Asset | Source | Type | State |
|---|---|---|---|
| Terrain generator | `core/` C module (W11) — ridged domain-warped height, particle hydraulic erosion, thermal erosion | C procedural | **Done** — 3,000+ droplets, deterministic from seed |
| Terrain WASM binding | `web/terrain-lab/terrain.mjs`, `worker.mjs` | WASM + JS worker | **Done** — height, flow, sediment, level maps; hash; timing |
| Terrain browser lab | `web/terrain-lab/index.html`, `lab.mjs` | Three.js + WASM | **Done** — interactive parameter tweaking |

### 1.6 Audio (assets/audio/)

| Asset | Count | Type | State |
|---|---|---|---|
| Footsteps | 3 files (step-0/1/2.ogg) | CC0 sampled | **Done** — grass surface, randomised |
| Combat | 6 files (hit, block, dodge, spit, hurt, death.ogg) | CC0 sampled | **Done** |
| UI | 1 file (click.ogg) | CC0 sampled | **Done** |
| Ambience | 3 files (wind.ogg, meadow.ogg, grass-rustle.ogg, idle.ogg, aggro.ogg) | CC0 sampled | **Done** — wind loop, meadow ambient, grass rustle on movement, creature calls |
| Credits | `CREDITS.md` | Markdown | **Done** — full attribution table |

---

## 2. Gap list: visual assets needed for MVP and near tail

For each gap: what it is, where used, design reference, approach, size, dependencies.

### 2.1 MVP-critical gaps (P4, BACKLOG item 1)

| # | Asset | What | Where used | Decision ref | Approach | Size | Dependencies |
|---|---|---|---|---|---|---|---|
| G1 | **Nest structure** | Physical nest marker (mound, eggs visible, egg counter visual). MVP needs a marker (Q-6); P5 needs full nest (G24: 4 site types). | Stage, nest area | G24, Q-6, G35 | Procedural JS (mound mesh + egg instances) or small GLB. Must match valley ground material. | M | Requires nest position (world seed). P5 needs 4 variants (plain, ledge, burrow, cave). |
| G2 | **Procedural food plants** | Small fruit-bearing plants, grass tufts with fruit, herbaceous ground cover. | Scattered throughout valley | P4.md §2.3 (food store), G37 (carcass + fossil nodes) | Procedural JS: trunk + leaf cluster + fruit spheres, seed-based variation. Re-use growth.js tube primitive. | S–M | Fruit types: plant (herbivore), fruit (all), meat (from carcass). Needs 3 variants minimum. |
| G3 | **Carcass prop** | Dead creature remains on ground (skeleton/hide). Visual for P4 carcass discovery loop. | Scattered — spawn where wild creatures die | P4.md §2.3 (eating carcass → 3 DNA), §2.4 (carcass → bone drop) | Procedural JS (simplified creature silhouette) or small GLB. Needs to match creature palette. | S | Part of drop system (G37). |
| G4 | **Surface fossil node** | Partial fossil exposed in ground (bone fragments, skull fragment). | Placed at world creation, walkable | P4.md §2.4 (fossil discovery), G37 (fossils by biome/depth) | Procedural JS: rock-like base + bone-colored fragment protruding. Biome-colored. | S | Fossil placement algorithm in C world creation. |
| G5 | **Creature variants** | Visual variants of the 4 species (Rondo, Zanco, Espinodo) beyond Garfio. Each species needs distinctive body shape + palette. | Stage — spawn in world | DESIGN.md Q43 (4 species), P4.md §2.2 (species profiles) | Studio: each species = unique genome JSON. Already supported by creator (G42). | S | Creator (G42) must produce each species genome. Carries through tribe traits (G28). |
| G6 | **Epic creature (Coloso)** | Large distinctive epic creature, home to islet (W4). | P8 (islet biome) | W4, Q-9 (not in P4) | Procedural JS (large body, distinctive features) or GLB. Hero shot candidate. | L | Needs species design. P8. |
| G7 | **Water surface + shallow water** | Water plane with transparency, caustics, shoreline. Shallow water visual for swimming biome. | Shallow sea, rivers, lakes | W7 (shallow: fins, underwater caves), G17 (swim) | GLSL water shader (BotW-style caustics), transparent plane with edge foam. | M | P6. Requires swimming medium. |
| G8 | **Deep water / underwater visual** | Underwater volume fog, light shafts, reduced visibility, pressure effect. | Deep sea, underwater caves | W7 (deep: gills, reefs, trenches), G20 (scoped later) | GLSL volumetric fog, color tint (blue-green), light caustics from above. | M | G20. After P6. |
| G9 | **Underwater cave interior** | Dark cave chamber with entrance, bioluminescent parts useful inside. | Coast, cliff, underwater | W5 (cliff and underwater entrances), W7 (underwater caves) | Procedural JS: tunnel geometry + dark interior, optional glow elements. | M | P6 (swimming). Requires cave network data from C. |
| G10 | **Cliff / rock face detail** | Vertical cliff surfaces (climbable faces gated by climbing parts). | Mountains (W3) | W3 (climbable faces), W5 (cliff entrances), G24 (ledge nest sites) | Shader-based cliff material (strata, cracks), procedural cliff meshes in terrain. | M | Erosion generator output (cliff bands). Requires climbing parts. |
| G11 | **Offshore islet** | Small island(s) reachable by swim/glide, with endemic species and parts. | Sea perimeter | W4 (2–4 islets, one with epic creature) | Procedural island geometry (raised circle), beach + grass + rock. | S | W4. Part of full island (W1–W5). |
| G12 | **Flowers / ground cover variation** | Small flowers, moss patches, fern-like ground plants for meadow valley. | Start valley meadow | BACKLOG item 2 (grass anchored, soft shadows — partial) | Procedural JS: small flower/fern clusters, color variation by seed. | S | Complements G3 (food plants). BotW aesthetic. |
| G13 | **Landmark: panspermia meteor crater** | Large visible crater rim + depression at valley start. | Start valley | W10 (start valley landmark), P4.md §2.3 (10 DNA for landmark) | Procedural JS or C terrain modification (depression). Rim rock ring. | M | Tied to C terrain generator. Requires crater shape from W11. |

### 2.2 Near-tail gaps (P5–P8, BACKLOG §2)

| # | Asset | What | Where used | Decision ref | Approach | Size | Dependencies |
|---|---|---|---|---|---|---|---|
| G14 | **Burrow entrance / tunnel opening** | Hole in ground, dirt mound, thorn-wall entrance. | Nest area, territory | G24 (burrow site), G27 (digging tunnels), P5 | Procedural JS: hole mesh + scattered dirt particles + thorn walls. | S | P5 (nest system). |
| G15 | **Thorn wall / nest defence** | Interwoven branch walls with sharp thorns. | Nest periphery | G29 (defences), G35 (build defences) | Procedural JS: interlocking twig geometry, thorn spikes. | S | P5. |
| G16 | **Pack young / hatchlings** | Small creatures (reduced body scale, 60% HP from G23). | Nest (hatching) | G23 (dying costs egg, respawn hatchling), P5 | Same body as adult, scaled down. No new geometry. | S | P5 (hatching). |
| G17 | **Full biome roster** | Forest (dense canopy, shade), savanna/desert (sparse trees, dry grass), alpine (rock, snow, cirques). | W2 (5 biomes) | W2 (first island: 5 biomes) | Shader patches + scatter variation per biome type. Reuse existing grass/rock/tree templates. | L | W2. After MVP. Requires biome layer from C generator. |
| G18 | **Jungle / taiga / tundra** | Later biomes not in first island. | Full island (W2) | W2 (come later) | TBD. | L | Post-MVP. |
| G19 | **Volcano biome + fire visual** | Smoking volcano, lava flow, fire spread effect, burnt terrain. | P8 | G52 (fire changes world), G54 (fire breath P8) | GLSL fire shader, lava glow, particle smoke. Burnt grass/ground material. | L | P8. G52 fire sim in C. |
| G20 | **Skyline landmarks** | Rock spire, giant tree, smoking volcano (distant), sea arch. | Every biome, visible from far | W10 (landmarks visible from far) | Distant mesh or shader-based. Re-use distant-range pattern. | S | W10. Post-MVP. |
| G21 | **Natural cave system** | Cave network with chambers, tunnels, dark interior, own fauna. | Mountains, coast | W5 (natural caves), G27 (same tunnel network as burrows) | C-generated geometry + dark interior shader. Glow parts visible inside. | L | W5. Requires tunnel network from C. |

### 2.3 Missing parts / palette gaps

| # | Asset | What | Where used | Decision ref | Approach | Size | Dependencies |
|---|---|---|---|---|---|---|---|
| G22 | **Back spine part (`espinas_dorsales`, `CP4_BACKSPINE`)** | New part for bone spines recipe. Procedural. | P4 recipes | P4.md §2.6 (new part), Q-15, G48 (procedural, G49) | Procedural JS: dorsal spine row, matches creator style. | S | P4. New part type. |
| G23 | **Shell / sac procedural parts** | Sac spitter, lure lantern, frill — need procedural variants (G48 says GLBs that fit badly → rebuild as procedural). | Creator palette | G48 (rebuild as procedural in creator's style) | See `growth.js` family. Reuse tube/primitive shapes with skin material. | M | G48. After creator integration. |
| G24 | **Missing GLB→procedural migrations** | Several GLB parts need procedural rebuilds: wings, sacs, arms, tail paddle, frill, beak. | Creator palette | G48, G54 (tier system) | Procedural JS templates. Keep GLB as shape reference only. | M | G48. Iterative per part. |
| G25 | **Part tier visuals** | Tier 1 (hooked, serrated, reinforced) and Tier 2 variants visually distinct from base. | Shop / editor | G49 (tier = form variant), P4.md §2.5 | Procedural: add texture detail (barbs, serrations) to base part. | S | G49. Tier data from P4. |

### 2.4 Environment polish gaps

| # | Asset | What | Where used | Decision ref | Approach | Size | Dependencies |
|---|---|---|---|---|---|---|---|
| G26 | **Particle effects — hit flash, dust, blood** | Small VFX on combat events: hit flash, dust cloud on charge, blood on bleed. | Combat encounters | P2 (combat), P4 (combat counter matrix) | Canvas sprite or instanced geometry. Fast, small. | S | P2 combat. |
| G27 | **Social interaction visual feedback** | Rhythm ring pulse, trust ring fill, mood face change, bond toast bubble. | Stage UI | P4.md §2.1 (social interactions) | CSS/HTML overlay (already has some). Need mood face sprites, trust ring shader. | S | P4. |
| G28 | **Discovery toast / codex UI** | "New part" toast with 3D thumbnail, codex page with silhouettes. | Stage UI | P4.md §2.4 (codex, field journal), G38 | HTML overlay. Need silhouette rendering for undiscovered parts. | S | P4. |
| G29 | **DNA award toast** | Floating text toast showing DNA source and amount. | HUD | P4.md §2.3 (DNA awards) | HTML overlay. Simple. | S | P4. |
| G30 | **Caesium bar UI** | Calcium resource meter next to stamina bar. | HUD | P4.md §2.6 (bone spines meter) | HUD overlay (HTML/CSS). | S | P4. |
| G31 | **Recipe codex page** | Codex entry for recipes: hidden slots ("?"), clue list, mastery state. | Codex | P4.md §2.6 (recipe states) | HTML overlay with codex layout. | S | P4. |

---

## 3. Suggested build order

Ordered by MVP-criticality, then by dependency chain. Each group is a logical
batch that reuses the same techniques from step N.

### Batch A: MVP essentials (must ship with creature stage)

1. **G5 — Creature variants** (Rondo, Zanco, Espinodo genomes)
   Use existing creator (G42) to sculpt species-specific bodies. No new code.
   → *Enables species diversity, all downstream species content.*

2. **G22 — Back spine procedural part**
   New procedural template in rig.js/studio.js. Simple spine row.
   → *Required for bone spines recipe (P4).*

3. **G1 — Nest structure**
   Procedural mound mesh with egg instances (3 eggs visible). Simple geometry.
   → *Required for P4 nest marker (Q-6), P5 respawn.*

4. **G2 — Food plants (3 variants)**
   Procedural JS: trunk + leaf cluster + fruit. Seed-based color variation.
   → *Required for P4 food discovery (G37).*

5. **G3 — Carcass prop**
   Simplified dead creature silhouette in ground material colors.
   → *Required for P4 carcass eating loop.*

6. **G4 — Fossil node**
   Rock base + bone fragment. One procedural template with biome color.
   → *Required for P4 fossil discovery.*

7. **G12 — Flowers / ground cover**
   Small flower and moss clusters. Reuses growth.js primitives.
   → *Polish for start valley (BotW aesthetic).*

### Batch B: P6 swimming & expanded world

8. **G7 — Water surface**
   Transparent plane + BotW-style caustics shader + foam edge.
   → *Enables shallow water swimming.*

9. **G8 — Underwater visual**
   Volume fog shader + light shafts + blue-green tint.
   → *Enables deep water and underwater exploration.*

10. **G9 — Underwater cave interior**
    Tunnel geometry + dark shader + glow element placement.
    → *Enables underwater cave exploration (W7).*

11. **G10 — Cliff / rock face detail**
    Shader-based cliff material with strata lines and cracks.
    → *Enables climbing gameplay (W3).*

### Batch C: World expansion

12. **G13 — Meteor crater**
    Depression + rim rock ring at valley start. Tied to terrain generator.
    → *Landmark (W10), navigation point.*

13. **G11 — Offshore islets**
    Raised circular geometry with beach and grass. 2–4 instances.
    → *Epic creature home (W4).*

14. **G10 (cliff faces) + G21 (cave network)**
    Tied to C terrain generator output. Requires tunnel network data.
    → *Full world exploration.*

### Batch D: Procedural migration (G48)

15. **G23 — Sac / lure / frill procedural rebuilds**
    Rebuild GLB parts that fit badly (G48) as procedural JS.
    → *Creator consistency. Keep GLBs as shape reference only.*

16. **G24 — Remaining GLB→procedural migrations**
    Wings, arms, tail paddle, beak. One per PR.
    → *Full procedural palette.*

### Batch E: Near-tail (P5–P8)

17. **G6 — Epic creature (Coloso)**
    Large distinctive creature. Hero shot candidate.
    → *P8 islet boss.*

18. **G14 — Burrow entrance**
    Hole + dirt mound + thorn wall.
    → *P5 nest raid system.*

19. **G15 — Thorn wall**
    Interwoven branches with spikes.
    → *P5 defence system.*

20. **G17 — Full biome roster**
    Forest, savanna/desert, alpine. Shader patches + scatter.
    → *Full island (W2).*

21. **G19 — Volcano + fire**
    Lava flow, smoke particles, fire shader, burnt ground.
    → *P8. Requires G52 fire sim.*

### Batch F: Polish (ongoing)

22. **G25 — Part tier visuals**
    Small visual changes to existing parts (barbs, serrations).
    → *G49 tier system.*

23. **G26 — Particle effects**
    Hit flash, dust, blood. Fast to implement.
    → *P2/P4 combat polish.*

24. **G27–G31 — UI feedback elements**
    Social interaction visuals, discovery toasts, DNA toasts, calcium bar, recipe codex.
    → *P4 UX. All HTML/CSS overlays.*

---

## 4. Notes on uncertainty

- **Species JSON files**: Only `garfio.json` and `garfio-combat.json` exist in
  `web/stage/species/`. The other three species (Rondo, Zanco, Espinodo) from
  the prototype have no standalone species JSON. **Uncertain** whether these
  were intended to be inline in stage.js or are genuinely missing.

- **Procedural vs GLB split**: `parts.json` lists `"source": "procedural"` for
  many parts that also have a `.glb` file. The source says `"glb"` only for
  `eye_stalk`, `jaw_nipper`, `horn_crown`, `shell_plate`, `lure_lantern`,
  `mandible_shear`, `snout_trumpet`, `tongue_spring`. The rest with `"source":
  "procedural"` may have GLBs that are shape references only. **Verified** by
  checking `web/studio/parts/*.glb` directory listing (25 GLB files present).

- **Growth.js families**: Only 3 families (horns, plates, tendrils) with no
  explicit mapping to part categories. **Uncertain** if more families will be
  added or if other procedural parts (e.g. legs, tails) use different generation
  code.

- **`oreja` (ear)** and **`tallo` (stilt leg)**: `oreja` exists in parts.json but
  not in rig.js LIB. `tallo` exists in both. **Uncertain** if `oreja` is
  intentional omission or a gap.

- **Polygon budget**: `parts.json` states `max_source_polygons: 3598` (foot_gecko
  GLB). **No verification** was performed that all GLBs respect this or that
  LOD reduction is applied. This is a P1 acceptance criterion (G46/P1).

- **Creature materials on environment**: The hero shot (`web/hero/`) uses
  physically lit skin materials for the creature in the toon valley. The stage
  does not yet use physically lit creature skin in the environment — it uses
  the studio creator's skin. **Uncertain** if this is a deliberate difference
  or a gap.

---

## 5. What is NOT needed

- **Creature mesh generation from scratch** — rig.js already covers all part
  types and the creator already generates anatomy.
- **Creature skin/material system** — physically lit skin with patterns is
  implemented (rig.js).
- **BotW-style renderer** — hero shot has the full toon pipeline (ACES, sky,
  fog, grass, trees, distant mountains).
- **Creature audio** — CC0 audio files are present and wired in (audio.js).