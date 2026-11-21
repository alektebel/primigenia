# Rubric: carcasses & fossils (G3, G4)

## Criteria

| # | Criterion | What to check | Pass threshold |
|---|-----------|---------------|----------------|
| 1 | **Silhouette at 5 m** | Close-up: a carcass reads as a dead creature; a fossil reads as bone embedded in rock. No ambiguity. | Every variant scores 4+ |
| 2 | **Silhouette at 30 m** | Far-down: carcass = dark lump on ground, fossil = pale protrusion. The landmark fossils (skull, spine) must be distinguishable from rocks at distance. | Every variant scores 3+ |
| 3 | **Fits toon style** | World props use the same 3-band toon ramp (`[46,46,82,82,112,112]` = G63) and Palette C colours as existing valley props. No physically-lit materials on world props. Creature-like parts (flesh, keratin) use physical materials only. | No violations |
| 4 | **Palette C coherence** | Carcasses carry the creature's colour identity (cA / cB / cC). Fossils are biome-tinted but sit within the same warm-cool palette family. | Visual match by eye |
| 5 | **Variety between variants** | Fresh vs picked-over carcass: clearly different states. Meadow / alpine / beach fossils: colour-shifted, not just recolored. | 4+ per carcass type, 4+ per fossil type |
| 6 | **No artefacts** | No z-fighting, no bleeding, no inverted normals, no floating meshes, no stretched textures. Shadow reception on ground consistent. | Zero artefacts |
| 7 | **Triangle budget** | Each carcass < 2 500 tris. Each fossil < 2 000 tris. Preview page draw calls < 30. | Checked in stats panel |

## Scoring guide

- **5** — Excellent: silhouette is instant, style is seamless, colour is on-brand.
- **4** — Good: readable with minor hesitation; style close but one element wobbles.
- **3** — Acceptable: readable after 1–2 s, needs tweaking but game-ready.
- **2** — Problematic: ambiguous at one distance, style mismatch, colour off.
- **1** — Fail: unreadable, artefacts, wrong material type.