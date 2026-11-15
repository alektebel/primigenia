# Species — rendering rubric

## 1. Silhouette readability at 5 m (close)

| Criterion | Pass condition |
|---|---|
| Shape instant | In < 0.5 s the viewer identifies body plan (round, tall, spiny) from the creature outline alone — no need to read the name. |
| Part distinction | Every placed part is individually identifiable: mouth, eyes, legs, tail, horns/spikes. No two parts merge into one blob. |
| Spine clarity | The spine nodes read as a coherent curve; head, torso, and tail regions are clearly separated by node spacing and radius. |
| Grounding | Feet contact the ground plane. No floating or sunken legs. The body sits on the terrain. |
| Animation | Walk cycle is smooth. No leg snapping, no vertical bouncing beyond a small stride bob. |

## 2. Silhouette readability at 30 m (far)

| Criterion | Pass condition |
|---|---|
| Outline at distance | The silhouette is readable through fog and at reduced resolution. Distinctive features (round body, tall legs, spines) remain visible. |
| Color contrast | Palette provides at least one value contrast edge (e.g. dark body against lighter ground or sky). |
| No artefacts | No z-fighting, no flickering edges, no holes in the mesh visible through fog. |

## 3. Fit with the valley's toon / palette-C style

| Criterion | Pass condition |
|---|---|
| Palette C harmony | Skin colours (cA, cB, cC) are drawn from warm earth tones with cool shadows, matching the valley's palette C (see `tools/hero/build_hero.py` PAL.C). No neon or out-of-saturation colours. |
| Toon material | Physically lit skin material is compatible with ACES tone mapping. Luminance sits within the environment's measured range (golden: ~0.3–0.7 in sRGB). |
| Rim / edge | Rim light and clearcoat are present but not over-powering. The creature reads as organic flesh, not plastic or metal. |
| Pattern coherence | The skin pattern (spots / stripes / mottle) matches the body plan and species identity. |

## 4. Variety between variants

| Criterion | Pass condition |
|---|---|
| Five silhouettes | Rondo, Zanco, Espinodo, nocturnal Espinodo, albino — each has a clearly different silhouette at a glance. No two share the same body-plan shape. |
| Palette diversity | At least four distinct palettes across the five variants. No palette is a simple dark/light swap of another without a hue shift. |
| Part diversity | Not every species uses the same set of parts. Variation in mouth type, leg style, head appendages, and tail treatment. |

## 5. No artefacts

| Criterion | Pass condition |
|---|---|
| Zero rendering errors | No JS errors in the console, no WebGL errors, no missing textures or shaders. |
| Clean geometry | No inverted normals, no non-manifold edges visible, no overlapping faces. |
| Shadow correctness | Creatures cast proper shadows on the ground. No shadow artifacts (striping, banding). |

## 6. Triangle budget

| Criterion | Pass condition |
|---|---|
| Per-creature count | Each species stays under 4 000 triangles (excluding the shared skin base geometry). |
| Draw calls | A lineup of all five species uses ≤ 15 draw calls (one per creature for the skin base + up to 10 part draw calls spread across species). |