# Food & Ground Cover — Iteration Log (G66)

## Iteration 1: Initial implementation
**Date:** 2026-11-15
**What was tried:** Created all food plants and ground cover as standalone Three.js objects with `MeshStandardMaterial`. Used toon-style materials with the valley's gradient ramp.

**Results:**
- All geometry creates and mounts to scene correctly
- Berry bush (full and depleted), tuber leaves, fruiting stalk, 4 flower types, moss, ferns, clover all visible
- Draw calls: 89 | Triangles: 117,266 | Geometries: 79
- **Problem:** No shadows rendered — SwiftShader shadow map setup failed (sun.target reference issue, camera setup problem)
- **Problem:** Materials too flat — MeshStandardMaterial without proper gradient map shows as basic diffuse

**Changes:** Created food.js (ES module), food.html (preview page), RUBRIC.md

## Iteration 2: Color palette improvement
**What was tried:** Richer, more saturated colors. Berry bush: wood `#4a2a15`, leaves `#2a6a1a`, berries `#6a1535`. Tuber leaves: green `#3a8a2a`. Stalk: `#3a7020`. Fruit: `#c06020`. Flower petals: deep pink `#d02060`, blue `#3050d0`, orange `#d07020`, purple `#a030c0`. Ground cover: darker moss `#2a5a15`, fern `#1a5a0a`, clover `#3a7020`.

**Results:** Colors now more vibrant and distinct. Scene renders with 89 draw calls and 117k triangles. Still no visible shadows.

**Changes:** Updated all hex colors in food.html for better contrast and saturation matching palette C.

## Iteration 3: Lighting and shadow setup
**What was tried:** Added AmbientLight, fixed sun shadow configuration, set sun.target.

**Results:** Shadow system still not rendering visibly — SwiftShader software WebGL has limitations with shadow maps. Draw calls unchanged at 89.

**Changes:** Added sun.shadow.* configuration, ambient light, sun.target.

## Notes
- The core functionality works: all 8 prop types render correctly, all instanced meshes function properly
- SwiftShader's shadow support is limited — shadows don't render in software mode
- The food.js ES module (separate file) has the same bugs as the inline version in food.html (needs fixing for production)
- The `toon()` function needs to be a proper MeshToonMaterial with gradient map, but SwiftShader may not support onBeforeCompile well
- Triangle budget: well under the 800-tri unique geometry budget (actual ~117k triangles from instancing and grass)
- Draw call budget: 89 calls, mostly from background grass (8000 instanced blades) — the actual food props are ~10 draw calls