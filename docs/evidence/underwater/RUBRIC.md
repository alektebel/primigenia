# Underwater biome — evaluation rubric

Scored 1–5 per criterion (5 = outstanding, 1 = broken).
Used after each render iteration to track improvement.

## 1. Readability (composition & clarity)
- **5** — Every element is clearly visible: floor, caustics, shafts, kelp, coral, fish. No visual mush.
- **3** — Some elements compete; depth layering could be tighter.
- **1** — Flat wash of blue-green; nothing distinct.

## 2. Depth layering
- **5** — Clear foreground/midground/background: surface shimmer, mid-water particles, floor caustics, distant fog. Each layer separable.
- **3** — Depth implied but layers blend together.
- **1** — No depth cue beyond fog.

## 3. Colour harmony with palette C (Current+)
- **5** — Underwater tones extend the warm-light/cool-shade palette: deep blues-teals below, warm shafts cutting through. Matches valley land colours.
- **3** — Colour works but feels disconnected from the palette.
- **1** — Clash with land palette or oversaturated neon.

## 4. Light shafts (volumetric god rays)
- **5** — Distinct, soft-edged shafts from surface to floor. Density/length varies. Animated gently.
- **3** — Shafts visible but uniform or flickery.
- **1** — No shafts or artefact-heavy.

## 5. Caustics
- **5** — Natural, shifting caustic patterns on the floor. Bright enough to read, not overpowering. Visible on creatures too.
- **3** — Caustics present but static or too subtle.
- **1** — Noise pattern that looks like compression artefacts.

## 6. Life & motion
- **5** — Kelp sways, fish school naturally, particles drift, surface ripples — motion reads as living ecosystem.
- **3** — Some elements move, others static. Fish schools present but stiff.
- **1** — Static scene or floating artefacts.

## 7. Surface from below
- **5** — Wavy caustic-like surface reflection with TIR effect. Readable from below without looking like a ceiling.
- **3** — Surface visible but flat or unrealistic.
- **1** — Missing or clearly wrong (flat mirror, wrong normal).

## 8. No artefacts
- **5** — Clean render. No z-fighting, banding, TAA shimmer, or geometry seams.
- **3** — Minor banding or shimmer at edges.
- **1** — Visible artefacts dominate the image.

## 9. Performance
- **5** — Instanced geometry, efficient shaders. Would run at 60 fps on mid-range laptop.
- **3** — Some overdraw or redundant draw calls.
- **1** — Would choke a browser (thousands of unique meshes, unbounded loops).