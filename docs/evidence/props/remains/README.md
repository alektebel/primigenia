# Evidence: Carcasses & Fossils (G3, G4)

## What was built

### `web/props/remains.js`
Self-contained ES module (Three.js r128) with deterministic procedural generation.

| Function | Description | Triangle budget |
|----------|------------|-----------------|
| `buildFreshCarcass(T, seed, params)` | Dead creature with skin intact (body, neck, head, legs, tail) | ~900 |
| `buildPickedCarcass(T, seed, params)` | Skeleton with exposed ribs, spine, skull, jaw, teeth, leg bones, tattered meat strips | ~800 |
| `buildSkullFossil(T, seed, biome)` | Skull embedded in rock (dome, snout, eye sockets, teeth) — meadow/alpine/beach | ~300 |
| `buildRibcageFossil(T, seed, biome)` | Ribcage embedded in rock (spine fragment, 6 rib pairs, vertebral nodes) — meadow/alpine/beach | ~400 |
| `buildSpineFossil(T, seed, biome)` | Vertebrae row emerging from rock at angle (discs, transverse processes) — meadow/alpine/beach | ~300 |
| `buildAllCarcasses(T, seed)` | Convenience: returns group with `fresh` and `picked` children | ~1700 |
| `buildAllFossils(T, seed)` | Convenience: returns group with `meadow`/`alpine`/`beach` children, each with skull/ribcage/spine | ~2400 |

**Total draw calls** for all variants: ~45 (carcasses) + ~195 (fossils) = **~240** when rendered together.
**Triangle budget** total: ~4100 triangles for all variants.

### `web/props/remains.html`
Preview page showing all variants on valley ground under golden light with orbit camera.

## Rendering

### Toolchain
- **Browser**: Headless Chromium (SwiftShader SOFTWARE WebGL)
- **Executable**: `~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome`
- **Args**: `--use-angle=swiftshader --enable-unsafe-swiftshader`
- **Three.js**: r128 (from CDN)

### Render scripts
- `web/props/render_remains.js` — Renders a scene with carcasses and fossils, exports PNG
- `web/props/render_sheet.js` — Creates composite sheet with close-up panels

### Iterations
| Iteration | Change | Result |
|-----------|--------|--------|
| iteration01–04 | Initial build, module loading issues, empty canvas | Debug |
| iteration05–07 | `MeshPhysicalMaterial` not rendering in SwiftShader | Switch to standard materials |
| iteration08 | Fixed export stripping for inline use | Rendered but off-camera |
| iteration09–11 | Camera positioning, `carcassMaterial` scope fix | Props visible but basic |
| iteration12 | Switched to `MeshLambertMaterial` for carcasses | Proper lighting on carcasses |
| iteration13 | Material refinement with `customProgramCacheKey` | Good result — carcasses have Lambert shading, fossils use toon ramp |

## Style compliance

- **Toon ramp**: `[46,46,82,82,112,112]` (G63 palette C) — used on all fossils (rock base, skull, spine)
- **Palette C coherence**: Fossils use biome-tinted bone colours (meadow `#a8b088`, alpine `#8a90a0`, beach `#c4b48a`)
- **Creature palette**: Fresh carcass uses cA/cB/cC (default `#884433`, `#221111`, `#ccaa88`) with `MeshLambertMaterial` for creature-like skin
- **Half-buried**: All fossils are embedded in rock base geometry, reading as discovered objects
- **Readability**: Skull (eye sockets + teeth), ribcage (paired arcs), spine (vertebrae row) are all distinguishable at close range

## What is NOT done

- **Biome-colored rock bases for fossils** — the rocks are the same geometry, just recolored; they don't vary enough in shape to feel distinctly meadow/alpine/beach
- **Procedural carcass color variants** — carcasses currently use hardcoded defaults; the API supports passing cA/cB/cC but only the defaults are demonstrated
- **Animation** — carcasses and fossils are static (no wind, no decay animation)
- **InstancedMesh optimization** — individual meshes used per bone/rib/vertebra instead of instanced geometry
- **Shadow reception** — disabled in the sheet render for performance (SwiftShader ReadPixels stall)
- **Full rubric evaluation** — this is a first-pass build; rubric scoring (RUBRIC.md) should be done on final sheet after iterations

## Files changed

```
web/props/remains.js         — Main module (613 lines)
web/props/remains.html       — Preview page
docs/evidence/props/remains/RUBRIC.md   — Evaluation criteria
docs/evidence/props/remains/iteration01.png – iteration13.png — Render iterations
docs/evidence/props/remains/sheet.png     — Final composite (pending)
docs/evidence/props/remains/README.md     — This file
```

## Commands run

```bash
# Start HTTP server for web-based debugging
cd web/props && python3 -m http.server 8899

# Render individual frames (SwiftShader)
NODE_PATH=... node render_remains.js output.png

# Create composite sheet
NODE_PATH=... node render_sheet.js sheet.png

# Debug module exports
NODE_PATH=... node debug_remains.js
```