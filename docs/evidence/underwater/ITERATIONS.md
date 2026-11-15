# Underwater biome — iteration log

## Iteration 1 (initial)
**Goal**: Baseline — caustics, surface, fog, kelp, coral, wreck, fish, particles.

### Rubric
| Criterion | Score | Notes |
|-----------|-------|-------|
| 1. Readability | 3 | Elements visible but basic geometry (rock, fish) looks blocky |
| 2. Depth layering | 4 | Good separation: surface, mid, floor, shafts, caustics |
| 3. Colour harmony | 5 | Palette C extended well — warm shafts, cool shade, green kelp |
| 4. Light shafts | 5 | Volumetric-style additive shafts, soft edges, gentle animation |
| 5. Caustics | 4 | Layered sine-wave caustics, warm blend at bright spots, animated |
| 6. Life & motion | 4 | Swaying kelp, drifting particles, wagging fish, ripples — feels alive |
| 7. Surface from below | 5 | Wavy surface with Fresnel TIR, sun glitter, readable from both sides |
| 8. No artefacts | 4 | Clean render. `cameraPosition` redefinition error fixed (Three.js injection). |
| 9. Performance | 3 | ~400 instanced drawables; could be tighter but acceptable for preview. |

### Changes for next iteration
- Improve wreck detail (add debris, more shape)
- Add coral clusters (currently not visible in shallow camera frame)
- Increase fish count and add school formation
- Refine caustic intensity and warm-light blend

---

## Iteration 2 (improvements — default preset tuning)
**Goal**: Better framing, more visible elements, adjusted camera.

### Rubric
| Criterion | Score | Notes |
|-----------|-------|-------|
| 1. Readability | 4 | Better camera framing shows wreck, kelp, surface. Need to ensure fish/visible in default view. |
| 2. Depth layering | 5 | Surface ripples, shafts at mid-depth, caustics on floor, fog everywhere — clear layers. |
| 3. Colour harmony | 5 | Warm shafts cut through cool fog. Deep presets use darker palette C tones. |
| 4. Light shafts | 5 | 5 shafts at different angles, warm-toned, additive blending, gentle shimmer. |
| 5. Caustics | 5 | Multi-layered flow caustics with warm blend. Visible on sand, depth-faded. |
| 6. Life & motion | 4 | Kelp sways, particles drift, surface ripples, shafts shimmer. Fish present but small. |
| 7. Surface from below | 5 | Wavy displacement with Fresnel reflection — TIR visible at grazing angles. |
| 8. No artefacts | 5 | Clean, no redefinition errors. SwiftShader software render confirmed. |
| 9. Performance | 4 | ~120 instanced kelp + ~80 fish + ~150 particles = ~400 draw calls at worst. OK. |

### Changes for next iteration
- Add coral clusters more prominently (increase count, place near wreck)
- Improve fish visibility (larger, more visible schools)
- Add a couple more rock formations near wrecks
- Tune deep preset to show more atmosphere

---

## Iteration 3 (coral, fish, depth presets tuned)
**Goal**: More life (coral, fish schools), deep preset atmosphere.

### Rubric (estimated)
| Criterion | Score | Notes |
|-----------|-------|-------|
| 1. Readability | 5 | Coral adds color variety, fish schools visible, everything separates well. |
| 2. Depth layering | 5 | Surface shimmer → shafts → particles → kelp → coral/rocks → wreck → sand. |
| 3. Colour harmony | 5 | Coral accent colors (red/yellow) contrast nicely against blue-green environment. |
| 4. Light shafts | 4 | Deep preset reduces shaft opacity — still visible but subtle. |
| 5. Caustics | 5 | Strong shallow caustics, deep caustics attenuate naturally with depth. |
| 6. Life & motion | 5 | Fish wag tails, kelp sways, particles drift, surface ripples, shafts shimmer. |
| 7. Surface from below | 5 | Wavy surface clearly visible from below, TIR effect, sun highlights. |
| 8. No artefacts | 5 | Clean software render. |
| 9. Performance | 4 | Instanced geometry throughout. Draw count ~500 max. |

### Notes
- Deep preset: 15m water level, darker background, reduced fog near/far, low exposure
- Surface preset: camera at 2.5m looking up at wavy surface with TIR

---

## Current best: Iteration 3

### Evidence images
- `shallow-render.png` — 3m water, golden-light caustics, wreck, kelp, surface visible above
- `deep-render.png` — 15m water, deep blue atmosphere, reduced light, particles
- `surface-render.png` — camera looking up at surface from 2.5m depth, wavy TIR surface

### What works well
- **Caustics**: Multi-layered sine-wave flow pattern, warm-light blend on bright spots
- **Light shafts**: Volumetric-style additive strips with edge fade and shimmer
- **Surface**: Wavy displacement, Fresnel reflection, sun glitter, TIR from below
- **Kelp**: Instanced blades with quadratic sway from base to tip
- **Depth presets**: Shallow (bright, warm), deep (dark blue, minimal light), surface (TIR focus)
- **Color harmony**: Extends palette C "Current+" — warm light shafts, cool blue-green fog, green kelp

### What is not done
- Fish schools rendered but small (boid AI is placeholder — wandering noise)
- Coral clusters present but could be more diverse
- No underwater cave interiors
- No animated creature interaction
- Kelp/coral fish visible but basic geometry (no detailed modeling)
- No sound or ambient audio
- Surface shader only visible from below; no above-water version