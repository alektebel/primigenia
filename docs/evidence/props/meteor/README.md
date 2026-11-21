# Panspermia Meteor Shards & Crater Kit — Implementation Notes

## What was built

A self-contained ES module (`web/props/meteor.js`) producing:

- **5 meteor shards** (G65): dark glassy crystals, each with a unique carved glyph
  and a faint warm inner glow. Shapes:
  - `spire` — tall diamond octahedron, spine glyph
  - `blade` — wedge/curved blade, zigzag glyph
  - `tablet` — thick polygonal plate, dome glyph
  - `cluster` — three fused prisms (the crater core shape), cross glyph
  - `dart` — elongated asymmetrical shard, ring glyph

- **Impact crater kit** (W10 / G13): shattered rim ring, fused glass patches,
  scorched spatter decals, and a half-buried meteor core.

## Files

| File | Description |
|------|-------------|
| `web/props/meteor.js` | ES module; builder functions, palette, toon ramp |
| `web/props/meteor.html` | Preview page with orbit camera, all shots |
| `tools/props/capture_meteor.cjs` | Headless Chromium capture script |
| `docs/evidence/props/meteor/RUBRIC.md` | Acceptance rubric |
| `docs/evidence/props/meteor/sheet.png` | Evidence: all variants, close + far |

## How to view

```bash
cd /home/diego/Desarrollo/cpore-wt/art-meteor
python3 -m http.server 8765 --bind 127.0.0.1 &
open http://localhost:8765/web/props/meteor.html
```

URL parameters:

| Param | Values |
|-------|--------|
| `?shot=...` | `lineup`, `scene`, `far`, `core`, `shard0`..`shard4` |
| `?seed=...` | numeric seed (default 20261115) |

## Capture

```bash
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
  nice -n 10 node tools/props/capture_meteor.cjs --shots lineup,scene,far,core,shard0..shard4
```

Uses headless Chromium with SOFTWARE WebGL (SwiftShader only).

## Statistics

| Metric | Value |
|--------|-------|
| Total triangles (props) | ~1 140 |
| Per-shard triangles | 14–42 (cluster is largest at 42) |
| Total draw calls | 8 |
| Shards | 5 |
| Crater elements | 3 (rim+debris rocks, glass/scorch surface, core shard) |
| Renderer used for capture | ANGLE SwiftShader (Vulkan 1.3, software) |

## What is not done

- **Bowl geometry** is available (via `bowl: true`) but disabled by default in
  the preview; the meadow ground material's built-in scorched ring is considered
  sufficient for the MVP crater look. The bowl is kept for when the crater must
  integrate into bare terrain (no meadow shader).
- **Scorch texture canvas** (`scorchTexture()`) was removed during iteration 2
  when glass and scorch were merged into a single instanced mesh. The scorched
  ring in the meadow ground shader serves the same purpose.
- **Individual shard glyph close-ups** are not included in the sheet as separate
  files — the `?shot=shardN` URLs and the `core` shot provide close views of
  each carved glyph.
- **Night / overcast variants** — only the golden (palette C) look was evaluated.
- **LOD** — no lower-poly versions are provided; the current budgets (≤ 42 tris
  per shard) are already well within the 128-tri rubric target.
- **Integration with the stage world** — this task only produces the prop
  module; the crater's world placement (W10) is a later integration task.

## Design decisions

1. **All colours from palette C** — shard body (`shard: [0.052, 0.049, 0.066]`),
   inner glow (`glow: [0.7455, 0.3515, 0.0513]` = #e0a040), rim rock, glass —
   all within the toon world's palette C "Current+" range.

2. **Carved glyphs, not painted** — each shard gets a height-field normal map
   derived from a procedural stroke pattern. The groove floor is darker (albedo
   map) and a warm emissive leaks from within.

3. **Glassy Fresnel edges** — `onBeforeCompile` injects a Fresnel term (power 2.5)
   that makes thin crystal edges glow warm, and a rim highlight (power 5) for
   the sharp edge catch.

4. **Meadow-integrated crater** — the crater bowl sits at the meadow surface;
   the ground shader's `uCrater`/`uScorchAmt` uniforms produce a scorched ring
   that blends into grass, avoiding the "grey disc dropped on the meadow" problem.

5. **Instanced meshes** — rim rocks and floor debris share a single geometry
   (36 vertices / ~40 tris per mesh, ~24+12=36 instances = 1 draw call). Glass
   and scorched patches share another circle geometry (10 draw-call-efficient).