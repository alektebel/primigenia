# Meteor Shards & Crater — Acceptance Rubric

## 1. Silhouette readability

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | At 5 m the shard is instantly read as a shard: pointed / faceted crystal, not a rock or a sphere. | Each shard has a distinct silhouette. No two look the same. |
| 5 | At 30 m the crater rim is visible as a ring depression in the meadow, not lost in terrain. | Rim ring spans > 60° arc from center camera; at least one shard in core visible as dark glint. |

## 2. Fit with the valley's toon style + palette C

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | Materials use the same `toon()` ramp and the same `onBeforeCompile` land-shader technique (shared light/shade / ramp / aerial fog). | No standard/physical materials except where physically lit skin is the intended contrast for creature-like things. |
| 5 | Colours come from palette C "Current+" (warm light / cool shade): dark body (`#1a1720` → `#2a2230` range), warm inner glow (`#e0a040`), scorched earth in the `g0`/`g1` meadow range. | No neon or out-of-palette colours. |
| 3 | The crater blends into the meadow: same grass base with scorched patches, not an isolated grey disc. | Scorched patches use the meadow patch system (`patchY` / `patchB` style). |

## 3. Variety between variants

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | All 5 shards are visually distinct: shape (octahedron, elongated needle, wedge, plate, irregular), scale, glyph carving style, and glow intensity differ. | No two share the same silhouette or glow. |
| 4 | Crater kit has ≥ 3 sub-variants that can be mixed: rim segment, glass pool, scorched decal, half-buried core. | At least 3 distinct sub-assets. |

## 4. No artefacts

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | No Z-fighting between shard faces or between glass and shard body. | Alpha-test on glass material. |
| 4 | No UV seams visible in the glow (no texture needed — procedural). | Glow via emissive / onBeforeCompile term. |
| 3 | No over-brightness / blooming under golden light. | Tone mapping handles glow intensity. |

## 5. Triangle budget

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | Each shard ≤ 128 tris (8–12 verts, indexed). 5 shards < 640 tris total. | Achieved via simple indexed buffers or parametric geometries. |
| 5 | Crater rim kit ≤ 512 tris (rim ring + glass + core). | One instanced ring + single core mesh. |
| 4 | Total draw calls ≤ 8 (5 shards + crater ring + glass + core + decals). | Group where possible with `InstancedMesh`. |

## 6. Determinism

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | Same seed → identical output every run. No `Math.random()`. | All variation via seeded PRNG only. |

## 7. Story / lore fit

| Score | Criterion | Target |
|-------|-----------|--------|
| 5 | Each shard has a carved glyph (simple line groove) suggesting an alien/ancient writing system. | Glyphs are carved/sunken into the surface, not just painted on. |
| 4 | Inner glow is faint and warm — "something alive inside the stone." | Glow intensity ≤ 0.4 emissive equivalent. |

---

**Accept threshold**: ≥ 48 / 52 total. No single category below 3.