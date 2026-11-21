# Primigenia — Valley Species

Procedural creature species built for the Primigenia game valley. Rendered with Three.js r128 using the same toon-shaded, physically-based material pipeline as the hero creature system.

## Quick Start

Open `web/props/species.html` in a browser and navigate to `file:///path/to/...` or serve with:

```bash
cd art-species
python3 -m http.server 8767
# then open http://localhost:8767/web/props/species.html
```

## Species

| Species | Type | Legs | Skin Pattern | Distinctive Features |
|---------|------|------|-------------|---------------------|
| **Rondo** | Round herbivore grazer | 4 (short) | Banding (3) | Dorsal plates, cranial horn, eye stalks |
| **Zanco** | Tall long-legged wader | 4 (stilt) | Worley noise (2) | Fan-fin, antenna with glow bulb, long beak |
| **Espinodo** | Spiny omnivore | 4 (medium) | Gradient (2) | Fang mouth, dorsal spikes, plates |
| **Espinodo Nocturno** | Dark nocturnal morph | 4 (medium) | Gradient + glow | Bioluminescent glow bulbs, dark skin |
| **Espinodo Albino** | Pale albino morph | 4 (medium) | Muted gradient | White/cream skin, reduced contrast |

## Genome Format

All species use the `cpore.creature/4` schema defined at `web/studio/genome.js`. Key fields:

- **nodes**: Spine skeleton — array of `{y, z, r}` defining the curved body centerline
- **parts**: Body attachments — array of `{type, t, ang, size, ...}` placed on the spine
- **skin**: Shader parameters — `{pat, cA, cB, cC, wet, scale}`
- **regions**: Optional growth/decoration regions (unused in current species)

## Renderer

`web/props/species.js` is a self-contained ES module that builds creatures from genomes:

```js
import { buildLineup } from './species.js';

const lineup = buildLineup(THREE, genomes, { size: 1 });
scene.add(lineup);
```

### Architecture Decisions
- **Shared skin material**: One toon shader instance shared by all creatures → minimum draw calls
- **Physical materials only**: MeshPhysicalMaterial / MeshStandardMaterial (no emissive for body, glow only for bulbo parts)
- **Deterministic**: Same seed → same output (no RNG in creature geometry)
- **Low draw-call budget**: <20 draws per creature with shared skin material

## Evidence

Render evidence is captured from `web/props/species.html` showing all species on valley ground under golden-hour lighting with an orbit camera.

### Evaluation Rubric

See `RUBRIC.md` for the full evaluation criteria covering anatomy, aesthetics, performance, schema compliance, and pipeline quality.

## File Structure

```
web/props/
├── species.js          # Renderer module (self-contained ES module)
├── species.html        # Preview page (golden-hour, orbit camera)
├── species/
│   ├── rondo.json      # Round herbivore grazer
│   ├── zanco.json      # Tall long-legged wader
│   ├── espinodo.json   # Spiny omnivore
│   ├── espinodo-nocturnal.json  # Dark nocturnal variant
│   └── espinodo-albino.json     # Pale albino variant
docs/evidence/props/species/
├── RUBRIC.md           # Evaluation rubric
├── ITERATIONS.md       # Iteration history
├── README.md           # This file
└── sheet.png           # Render evidence (to be captured)
```