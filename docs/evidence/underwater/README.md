# Underwater Biome (G64)

## What this module does

`web/biome/underwater.js` is a self-contained Three.js r128 ES module that adds an underwater look visible when the camera is below the water surface:

- **Animated caustics** on the sea floor (multi-layered flow pattern with warm-light blend)
- **Underwater fog** with depth-based blue-green absorption
- **Light shafts** from the surface (volumetric-style additive rendering)
- **Wavy surface** with Fresnel reflection and total internal reflection (TIR) from below
- **Kelp forests** (instanced, swaying via vertex shader)
- **Coral clusters** (instanced, multiple color varieties)
- **Rock clusters** (instanced, irregular blob geometry)
- **Sea grass** (instanced blades, swaying)
- **Fish schools** (boid-like wandering, instanced, tail-wag animation)
- **Floating particles** (plankton / detritus, drifting)
- **Shipwreck landmark** on the sea floor
- **Rippled sand** floor with caustic overlay

## Design decisions

- Stylised to match the valley's BotW-style toon world + physical creatures (G64)
- Uses palette C "Current+" extended for underwater (cool deep blues, warm light shafts)
- ACES Filmic tone mapping compatible
- Instanced geometry throughout for performance
- All shaders are custom GLSL (no post-processing overhead)
- Three.js r128 (same version as the hero shot)

## How to view

### Standalone preview
Open `web/biome/underwater.html` in a browser. Controls:

| Key | Action |
|-----|--------|
| WASD | Swim direction (relative to camera) |
| Q/E | Descend / Ascend |
| Shift | Fast swim |
| 1/2/3 | Preset: shallow / deep / surface from below |
| R | Reset camera |
| F | Capture PNG |

### Three presets
1. **Shallow (3 m)** — Golden-hour light, bright caustics, warm shafts, wreck visible, surface ripples above
2. **Deep (15 m)** — Dark blue atmosphere, reduced light, minimal caustics, particles, kelp silhouettes
3. **Surface from below (2.5 m)** — Camera looking up at wavy surface with TIR effect, light filtering through

### Headless capture
```bash
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules
node tools/underwater/capture.js [shallow|deep|surface]
```

Requires: Playwright, headless Chromium with SwiftShader (--use-angle=swiftshader).

## Files

| File | Purpose |
|------|---------|
| `web/biome/underwater.js` | Core underwater biome module (ES6 module) |
| `web/biome/underwater.html` | Standalone preview with swim camera + controls |
| `web/biome/three.min.js` | Three.js r128 vendored copy |
| `tools/underwater/capture.js` | Headless capture script |
| `docs/evidence/underwater/RUBRIC.md` | 9-criteria evaluation rubric |
| `docs/evidence/underwater/ITERATIONS.md` | Iteration log with rubric scores |
| `docs/evidence/underwater/shallow-render.png` | Shallow preset evidence |
| `docs/evidence/underwater/deep-render.png` | Deep preset evidence |
| `docs/evidence/underwater/surface-render.png` | Surface-from-below evidence |

## Not done (future)

- No above-water view of the surface (surface shader only visible from below)
- Fish schools use simple wandering noise — no actual boid steering behaviors
- Coral and rock geometry is simple procedural — no detailed modeling
- No animated creature interaction (fish fleeing, predator behavior)
- No underwater cave interiors or trench features
- No sound
- Not yet integrated into the hero shot or main game loop
- No integration with the actual terrain heightmap (uses placeholder heightmap function)