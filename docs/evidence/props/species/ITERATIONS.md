# Primigenia — Valley Species: Iterations

## Overview
Procedural species built for the Primigenia game valley, rendered with Three.js r128 using the same toon-shaded aesthetic as the hero creature pipeline.

## Species Created

### 1. Rondo
- **Type:** Round herbivore grazer
- **Body:** Cylindrical torso on four short legs, crawling body shape
- **Distinctive features:** Dorsal bony plates, cranial horn, mouth + eye stalks, tail spike
- **Skin:** Warm tan with banding pattern (pat 3)
- **Genome nodes:** 7
- **Genome parts:** 11

### 2. Zanco
- **Type:** Tall long-legged wader
- **Body:** Slender torso on four extremely long stilt legs (zancas)
- **Distinctive features:** Fan-fin ornament, antenna with glow bulb, long beak, tail spike
- **Skin:** Sandy brown with Worley noise pattern (pat 2)
- **Genome nodes:** 9
- **Genome parts:** 11

### 3. Espinodo
- **Type:** Spiny omnivore
- **Body:** Medium build with four legs, many dorsal spikes (púas)
- **Distinctive features:** Fang mouth (fauces), paired eyes, dorsal plates, tail spike
- **Skin:** Olive green with gradient pattern (pat 2)
- **Genome nodes:** 7
- **Genome parts:** 15

### 4. Espinodo Nocturno (Nocturnal Variant)
- **Type:** Dark nocturnal morph
- **Body:** Same as base Espinodo
- **Distinctive features:** Bioluminescent glow bulbs, dark skin
- **Skin:** Dark grey/black with strong bioluminescent emissive glow
- **Genome nodes:** 7
- **Genome parts:** 17 (added glow bulbs)

### 5. Espinodo Albino (Albino Variant)
- **Type:** Pale albino morph
- **Body:** Same as base Espinodo
- **Distinctive features:** Very light skin tone, reduced pattern contrast
- **Skin:** White/cream with muted pattern
- **Genome nodes:** 7
- **Genome parts:** 15

## Technical Implementation

### Renderer Architecture (`web/props/species.js`)
- Self-contained ES module, no dependency on rig.js
- Three.js r128 API accessed via `T.` parameter (compatible with global THREE)
- Shared skin material across all creatures (single draw call for skin)
- Physical materials only (MeshPhysicalMaterial, MeshStandardMaterial)

### Key Functions
- `buildSkinMat(T, params)` — ACES-compatible toon shader with skin attribute
- `buildOne(T, genome, opts)` — single creature builder
- `buildLineup(T, genomes, opts)` — lineup builder with shared material
- `countTriangles(obj)` / `countDrawCalls(obj)` — metrics

### Anatomy Primitives
- Spine tube with skin attribute (4-component: position offset + material region)
- Body part placement on spine using tangent frame
- IK legs (upper/lower/shin joints)
- 15+ part types: romo, pico, fauces, ojo, tallo, antena, oreja, cuerno, asta, pua, placa, cresta, bulbo, aleta, tail_spike, tail_paddle, arm_grasper

### Toon Shader
- ACES filmic tone mapping
- Custom GLSL injected via `onBeforeCompile`
- Pattern modes: banding, Worley noise, gradient, furrow
- Furrow noise from `vSkin.w` coordinate
- Wetness parameter controls roughness

## Evidence Pipeline
1. Preview page at `web/props/species.html` (golden-hour lighting, orbit camera)
2. Render evidence with headless Chromium/SwiftShader (when available)
3. Capture sheet.png with all species on valley ground
4. Document triangle count and draw call budget

## Files
- `web/props/species.js` — Renderer module (self-contained ES module)
- `web/props/species.html` — Preview page (golden-hour, orbit camera)
- `web/props/species/*.json` — 5 genome files (cpore.creature/4 schema)
- `docs/evidence/props/species/RUBRIC.md` — Evaluation rubric
- `docs/evidence/props/species/ITERATIONS.md` — This file
- `docs/evidence/props/species/README.md` — Project overview