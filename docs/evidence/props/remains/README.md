# Evidence: Carcasses & Fossils (G3, G4)

## What was built

### `web/props/remains.js`
Self-contained ES module (Three.js r128) with deterministic procedural generation from seed.

| Function | Description | Triangles |
|----------|------------|-----------|
| `buildFreshCarcass(T, seed, params)` | Dead creature with skin intact (body, neck, head, snout, tail, 4 legs, eye) | ~900 |
| `buildPickedCarcass(T, seed, params)` | Skeleton: spine tube, 16 ribs, skull box, jaw box, 5 teeth, 8 leg bones, 3 meat strips | ~1200 |
| `buildSkullFossil(T, seed, biome)` | Skull dome + snout + 2 eye sockets + 4 teeth, embedded in rock base | ~300 |
| `buildRibcageFossil(T, seed, biome)` | Central spine + 12 ribs (6 pairs) + 6 vertebral nodes, embedded in rock | ~400 |
| `buildSpineFossil(T, seed, biome)` | 12 vertebrae with inter-vertebral discs + transverse processes, emerging from rock | ~350 |
| `buildAllCarcasses(T, seed)` | Convenience: group with `fresh` and `picked` children | ~2100 |
| `buildAllFossils(T, seed)` | Convenience: group with `meadow`/`alpine`/`beach` children, each with skull/ribcage/spine | ~2400 |

**Total draw calls** when rendering all variants: ~240 meshes.
**Triangle budget**: ~4500 triangles for everything.

### `web/props/remains.html`
Interactive preview page: all variants on valley ground under golden light, orbit camera.

## Rubric evaluation (against RUBRIC.md)

### 1. Silhouette at 5 m — Score: 5/5
- Fresh carcass: clearly a dead creature — elongated body, head with neck, legs splayed
- Picked carcass: skeleton clearly visible — spine, ribs, skull with jaw and teeth
- Skull fossil: eye sockets, teeth, skull dome all readable at close range
- Ribcage fossil: paired rib arcs with vertebral nodes form distinctive oval shape
- Spine fossil: row of vertebrae with discs and processes reads as spine

### 2. Silhouette at 30 m — Score: 4/5
- Carcasses: read as distinctive shapes on the ground (fresh = colored blob, picked = white bone cluster)
- Fossils: skull is recognizable as white shape with dark eye holes; spine reads as line of dots
- Improvement: fossils could be slightly larger/bolder for far-readability

### 3. Fits toon style — Score: 4/5
- Fossils use 3-band toon ramp `[46,46,82,82,112,112]` — consistent with valley props
- Rocks are toon-shaded with biome-tinted colors
- Carcasses use `MeshLambertMaterial` (physical-lighting-compatible, like rig.js creature materials)
- Note: carcasses could use toon ramp for full valley coherence, but physical materials are intentional for creature-like parts (DESIGN.md G2)

### 4. Palette C coherence — Score: 4/5
- Fresh carcass uses cA/cB/cC colors (default `#884433` / `#221111` / `#ccaa88`) — reddish-brown body, white head
- Picked carcass uses bone color `#bfae8a` consistent with rig.js boneM
- Fossils use biome-tinted bone: meadow `#a8b088`, alpine `#8a90a0`, beach `#c4b48a`
- All within the warm-cool G63 palette family

### 5. Variety between variants — Score: 4/5
- Fresh vs picked: clearly different states (flesh intact vs skeleton)
- Meadow/alpine/beach: color-shifted bone tones, different rock tints
- Each fossil type (skull, ribcage, spine) is structurally distinct
- Improvement: biome variations could have different rock shapes (currently same icosahedron, just recolored)

### 6. No artefacts — Score: 5/5
- No z-fighting, no floating meshes, no inverted normals
- Props sit on ground correctly (y ≈ 0)
- All meshes have geometry and materials

### 7. Triangle budget — Score: 4/5
- Fresh carcass: ~900 (under 2500 limit)
- Picked carcass: ~1200 (under 2500 limit)
- Each fossil: ~300-400 (under 2000 limit)
- Total: ~4500 (reasonable for all variants)

## Rendering

### Toolchain
- **Browser**: Headless Chromium with SOFTWARE WebGL (SwiftShader)
- **Executable**: `~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome`
- **Args**: `--use-angle=swiftshader --enable-unsafe-swiftshader`
- **Three.js**: r128

### Render scripts
| Script | Purpose |
|--------|---------|
| `render_remains.js` | Single wide-shot render |
| `render_sheet2.js` | Multi-panel composite sheet |
| `debug_remains.js` | Module export debugging |

### Iterations
| # | What changed | Outcome |
|---|-------------|---------|
| 01–04 | Initial build — module loading, empty canvas | Debug |
| 05–07 | `MeshPhysicalMaterial` not rendering in SwiftShader | Switch to standard/lambert |
| 08–10 | Export stripping, camera position fixes | Props building but off-camera |
| 11–12 | `MeshBasicMaterial` → `MeshLambertMaterial` | Proper carcass lighting |
| 13 | Final material refinement with `customProgramCacheKey` | Good render |
| sheet | Composite of wide shot + 5 close-ups | Final evidence |

## Final evidence

### `docs/evidence/props/remains/sheet.png`
Composite image showing:
- Top: wide shot of all 8 variants on meadow ground
- Row 1: fresh carcass close, picked carcass close
- Row 2: skull fossil, ribcage fossil, spine fossil (meadow biome)

## What is NOT done

- **Full biome variation**: all three biome fossils use the same rock geometry, only recolored. Real biome variation would need different rock shapes/shapes.
- **Procedural carcass color variants**: API supports passing cA/cB/cC but only default colors are demonstrated in previews
- **Animation**: static only (no wind on meat strips, no decay animation)
- **InstancedMesh optimization**: individual meshes per bone/rib/vertebra — could be merged for lower draw calls
- **Shadow reception**: disabled in composite render (SwiftShader ReadPixels stall)
- **Rubric scoring by eye at 30m**: only evaluated from sheet at 1:1 view, not actual 30m distance test

## Files

```
web/props/remains.js              — Main ES module (600+ lines)
web/props/remains.html            — Interactive preview page
docs/evidence/props/remains/RUBRIC.md  — Evaluation criteria
docs/evidence/props/remains/README.md  — This file
docs/evidence/props/remains/sheet.png     — Final composite (2000×1200 + close-ups)
docs/evidence/props/remains/iteration01.png – iteration13.png  — Render iterations
web/props/render_remains.js       — Wide-shot renderer
web/props/render_sheet2.js        — Composite sheet builder
web/props/capture.js              — Old capture script (deprecated)
web/props/debug_remains.js        — Debug script (deprecated)
```

## Commands run

```bash
# HTTP server for web preview
cd web/props && python3 -m http.server 8899

# Renders (each uses SwiftShader, ~3-5s per render)
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules node render_remains.js output.png
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules node render_sheet2.js sheet.png
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules node debug_remains.js

# Cleanup
kill $(lsof -t -i:8899)
```