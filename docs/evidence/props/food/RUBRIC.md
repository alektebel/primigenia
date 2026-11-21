# Food & Ground Cover — Visual Rubric (G66)

## 1. Silhouette readability

| # | Criterion | 5 m (close) | 30 m (far) |
|---|-----------|-------------|------------|
| S1 | **Berry bush** — round shrub form with distinct berry clusters that read as "edible" | Berries visible as small spheres at branch tips; bush volume clearly bigger than grass tufts | Single green blob with darker berry spots; no confusion with rocks/trees |
| S2 | **Tuber leaves** — broad low-lying leaf cluster (tuber is underground, invisible) | Leaf shape distinguishable from ferns; leaf veins suggested by shading | Green patch on ground, ~1–2 m across; reads as "ground plant" not grass |
| S3 | **Fruiting stalk** — tall single stalk with a fruit cluster near top | Stalk height readable vs creature (~1.5–2×); fruit distinct from leaves | Thin vertical line with a small bump at top; tall enough to spot from distance |
| S4 | **Flowers** — small 4–5 cm flower clusters (4 colour variants) | Individual petals and centres visible; stems thin but visible | Small coloured dots on green; no silhouette confusion with berries |
| S5 | **Moss patches** — low irregular ground cover | Texture variation visible (not flat colour) | Soft green/brown irregular patch; clearly different from grass |
| S6 | **Ferns** — frond shapes with leaflets | Frond arch visible; leaflets from distance | Dark green fan shape; taller than moss but shorter than tuber leaves |
| S7 | **Clover** — 3-leaf clusters close to ground | 3-leaf shape recognisable | Small green clusters at ground level; not confused with flowers (no petals) |

## 2. Fit with the valley's toon style

| # | Criterion | Details |
|---|-----------|---------|
| T1 | **Toon ramp** | All world props use the same 3-band toon ramp as the valley (ramp values from `__heroLight`: `[46,46,82,82,112,112]`). No un-toned materials on environment props. |
| T2 | **Palette C colours** | Greens, browns, and fruit colours match palette C (G63): `g0=[.09,.225,.04]`, `g1=[.185,.335,.075]` for base green; earth tones warm; fruit: berry `#7a2040`, tuber `#c8a060`, stalk fruit `#d08030`. |
| T3 | **ACES tone mapping** | Final render uses ACES Filmic (same as hero shot). No materials that look "flat" or "gamey" — all have toon ramp or leaf-card shading. |
| T4 | **Leaf-card canopy** | Any leafy surface uses the leafCard() pattern (translucent card, backlit glow) when it's a canopy-size element. Small ground plants use flat toon. |
| T5 | **No creature materials on world** | Environment props use toon materials only. Creature skin/keratin/membrane materials are reserved for creatures only (G2). |

## 3. Variety between variants

| # | Criterion | Target |
|---|-----------|--------|
| V1 | **3 food plants** | Each must look distinctly different: bush (low, wide), tuber (low, flat), stalk (tall, thin) |
| V2 | **4 flower types** | Each flower type must have a different colour, shape, or both |
| V3 | **4 ground cover types** | Moss, ferns, clover, and ground flowers — each must be visually distinct from each other |
| V4 | **Depleted state** | Each food plant must show both a "full" and a "depleted/eaten" variant that are clearly different |

## 4. No artefacts

| # | Criterion | Details |
|---|-----------|---------|
| A1 | **No z-fighting** | Ground cover must not flicker when camera moves. Proper depth offset or render order. |
| A2 | **No texture bleeding** | Canvas-based textures (leaf pattern, flower pattern) must not show seams or grid lines. |
| A3 | **No stretched geometry** | Instanced meshes must use uniform scale or pre-scaled geometry. |
| A4 | **Clean edges** | No jagged artifacts at silhouette edges (proper anti-aliasing from headless Chrome). |

## 5. Triangle budget

| # | Item | Target |
|---|------|--------|
| B1 | Berry bush (full) | ≤ 200 tris |
| B2 | Berry bush (depleted) | ≤ 150 tris |
| B3 | Tuber leaves | ≤ 80 tris |
| B4 | Fruiting stalk | ≤ 120 tris |
| B5 | Each flower type | ≤ 40 tris |
| B6 | Each ground cover type (moss, fern, clover, ground flowers) | ≤ 60 tris |
| B7 | **Total unique geometry** | ≤ 800 tris (all types combined, before instancing) |
| B8 | **Draw calls per type** | 1 (all instances share geometry + material) |
| B9 | **Total draw calls** | ≤ 12 (3 food plants × 2 states + 4 flowers + 4 ground cover) |

## 6. Technical constraints

| # | Criterion | Details |
|---|-----------|---------|
| C1 | **Deterministic** | Same seed produces identical geometry. No random() calls outside seeded RNG. |
| C2 | **Three.js r128** | Compatible with the hero shot's Three.js version. |
| C3 | **Self-contained ES module** | No external dependencies. Builder functions take (THREE instance, seed, params). |
| C4 | **InstancedMesh** | Ground cover (flowers, moss, ferns, clover) must use InstancedMesh for low draw-call count. |
| C5 | **No art/reference edits** | Byte-identical references stay untouched. |