# Nest — Acceptance Rubric (G1 / G24 / Q-6 / Q-7)

Every render is checked against the following criteria. Failing any
"Must" item blocks the iteration; a "Should" shortfall is acceptable
only when all Must items pass and the deviation is documented.

## 1. Silhouette readability

| # | Criteria | Target |
|---|----------|--------|
| S1 | **Nest mound** readable at 5 m as a low organic mound (not a pile of sticks or a perfect hemisphere). | Must — profile must show a raised centre with gentle shoulders and a slight depression in the middle where the eggs sit. |
| S2 | **Eggs** readable at 30 m as egg-shaped highlights on the mound. | Must — minimum 3 eggs visible; they must form a tight cluster that reads as "eggs" even when small. |
| S3 | **Branch / twigs** read as woven texture from 5 m. | Should — individual sticks not required at distance, but directionality of the weave (criss-cross lines) must be visible. |
| S4 | **Stone inclusions** read as irregular bumps along the nest rim. | Should — 2–3 darker stones embedded in the outer ring for a "woven on rocks" look. |

## 2. Fit with the valley's toon style (palette C)

| # | Criteria | Target |
|---|----------|--------|
| T1 | Nest uses the **same 6-band toon ramp** ([54,54,83,83,108,108] for palette C) as all other world props. | Must — no custom ramp. |
| T2 | Base colours are pulled from **PAL.C land** values: earthy browns for twigs (`r0`-range), muted greens for grass thatch, warm greys for stones. | Must — colours must not clash with the meadow ground or the green leaf-canopy trees. |
| T3 | Grass thatch on the nest uses the same grass material approach as the meadow blades (toon material, same height-based colour bands). | Should — reusing the grass palette keeps the visual language consistent. |
| T4 | No physically-lit materials on world props. Creature-like things (eggs as living objects) may use `MeshPhysicalMaterial`, but the nest mound must stay toon. | Must — the nest is an environmental prop; the toon pipeline is the environment pipeline. |
| T5 | Rim-light pass is identical to the valley's (the standard onBeforeCompile rim addition). | Should — visible rim highlight on the mound edges during golden light. |

## 3. Variety between the 4 site variants

| # | Criteria | Target |
|---|----------|--------|
| V1 | **Open plain:** a loose woven mound on flat ground, 3 eggs exposed. | Must — closest to the default nest. |
| V2 | **Mountain ledge:** nest built into a small rock shelf, twigs woven around embedded boulders. | Must — ledge material must read as rock (darker, higher contrast tones). |
| V3 | **Burrow mouth:** nest at the entrance of a dug-in hole, partial covering over the hole. | Must — visible tunnel opening with earth walls. |
| V4 | **Cave:** nest inside a darkened alcove, dimmer overall, eggs glow faintly. | Must — the cave interior must be noticeably darker than the plain. |
| V5 | Each variant is instantly distinguishable from the others in a single glance. | Must — no two look alike. |

## 4. Egg design

| # | Criteria | Target |
|---|----------|--------|
| E1 | Eggs are **species-tinted**: 3 distinct shell colours drawn from palette C land / skin palette range. | Must — Rondo (warm cream), Zanco (cool blue-green), Espinodo (red-brown) at minimum. |
| E2 | Eggs have an **egg-shaped** geometry (not spheres), pointier at one end. | Must — at least a 1:1.3 aspect ratio, asymmetric. |
| E3 | A **hatch crack** state exists (visible fine line or break in the shell). | Must — the hatching variant must show a crack and a slightly-opened shell. |
| E4 | Egg material can be **physical** (subsurface-like) or toon — but must not look like plastic. | Should — slight matte sheen, not glossy. |

## 5. No artefacts

| # | Criteria | Target |
|---|----------|--------|
| A1 | No z-fighting between nest elements. | Must — proper depth offsets or merged geometry. |
| A2 | No overdraw artefacts from transparent leaf-card passes. | Must — alpha-test on all leaf/blade geometry (≥ 0.5). |
| A3 | Shadow map artefacts are absent (no banding, no acne). | Should — shadow bias properly set. |
| A4 | No UV seams visible on the mound surface at the viewing distance used for screenshots (3 m and 20 m). | Must — vertex-coloured or procedurally shaded surfaces preferred over texture-mapped. |

## 6. Triangle budget

| # | Criteria | Target |
|---|----------|--------|
| B1 | Default nest variant ≤ 1,200 triangles (including eggs). | Must — measured in the preview page stats. |
| B2 | Each variant ≤ 1,500 triangles. | Must — cave variant with darker geo may use slightly more. |
| B3 | All four variants combined ≤ 5,000 triangles. | Must — total budget. |
| B4 | Draw calls per variant ≤ 6. | Must — use InstancedMesh where possible to batch. |
| B5 | Draw calls all variants ≤ 20. | Must — the nest system should not spike GPU draw calls. |

## 7. Code quality

| # | Criteria | Target |
|---|----------|--------|
| C1 | Self-contained ES module; no external imports besides `three`. | Must — `import { createNest } from './nest.js' {type:'module'}` style works. |
| C2 | Deterministic output: same seed + parameters → same geometry. | Must — uses a seeded PRNG, never `Math.random()`. |
| C3 | Export: builder function(s) that take `(THREE, seed, params)` and return `Object3D` or `InstancedMesh`. | Must — matches the spec. |
| C4 | No dependencies on `tools/hero`, `web/hero`, `web/stage`, `web/creature`, or `core`. | Must — isolation per the brief. |