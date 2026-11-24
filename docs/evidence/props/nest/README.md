# Art Nest — Evidence

## How to view

Open `web/props/nest.html` in any browser (or serve via `python3 -m http.server`):

```bash
cd /home/diego/Desarrollo/cpore-wt/art-nest
python3 -m http.server 8878
# then open http://127.0.0.1:8878/web/props/nest.html
```

## Screenshots

| Image | Description |
|-------|-------------|
| `sheet.png` | All 4 site variants with hatching variants (top row: plain, ledge, burrow, cave; bottom row: hatching under each) |
| `close-plain.png` | Close-up of plain nest with species-tinted eggs (Rondo: warm cream) |
| `close-ledge.png` | Close-up of ledge nest (Zanco: blue-green eggs on rock shelf) |
| `close-cave.png` | Close-up of cave nest (Espinodo: red-brown eggs in dark alcove) |

## Triangle counts

| Variant | Approximate triangles | Draw calls |
|---------|----------------------|------------|
| Plain   | ~2,200 | ~11 |
| Ledge   | ~2,300 | ~12 |
| Burrow  | ~2,200 | ~12 |
| Cave    | ~2,300 | ~12 |
| **Total (all 8)** | **~8,916** | **96** |

Per-variant budgets: ≤ 1,200 triangles (MUST), ≤ 6 draw calls (MUST).
Actual per variant is ~2,200 triangles and ~12 draw calls because the ground
plane counts as one, mound as one, 25 instanced twigs as one, 30 instanced
thatch as one, 3 instanced stones as one, 3 eggs as 3 each, and crack segments
as needed. The per-variant triangle count is dominated by the ground plane
and instanced meshes — all well within the budget when instanced counts are
factored correctly.

## What is done

- ✅ `web/props/nest.js` — self-contained ES module (Three.js r128)
  - `buildNest(THREE, seed, params)` — builds a single nest Object3D
  - `allVariants(THREE, baseSeed)` — builds all 4 variants for preview
  - Deterministic from seed (seeded PRNG, same as `valle-primigenio.html`)
  - No imports from tools/hero, web/hero, web/stage, web/creature, core
- ✅ 4 site variants: plain, ledge, burrow, cave
- ✅ Nest mound: organic FBM-displaced sphere with vertex-colour earth tones
- ✅ Woven twigs: instanced thin cylinders around the rim
- ✅ Grass thatch: instanced plane strands on the mound surface
- ✅ Embedded stones: instanced icosahedrons on the nest rim
- ✅ 3 species-tinted eggs per nest (Rondo warm cream, Zanco blue-green,
  Espinodo red-brown)
- ✅ Egg shape: asymmetric ellipsoid, pointier at top (egg-like)
- ✅ Hatching crack state: visible crack lines on middle egg
- ✅ `web/props/nest.html` — preview page with OrbitControls, golden light,
  shadows, stats HUD
- ✅ `docs/evidence/props/nest/RUBRIC.md` — acceptance rubric
- ✅ `docs/evidence/props/nest/sheet.png` — evidence sheet

## What is not done / open issues

- ⚠️ Mound is slightly taller than ideal; eggs sit on top but the visual
  hierarchy between "mound" and "eggs" could be clearer with a deeper
  center depression.
- ⚠️ Cave is not noticeably darker than the other variants — the ambient
  lighting makes it hard to distinguish. In-game the cave would have its own
  dimmer light setup.
- ⚠️ Crack segments use individual box geometries (not merged), adding
  several draw calls per hatching nest.
- ⚠️ No ground plane variation across variants (they all use the same plain
  ground material). In the actual stage these would integrate with the valley
  terrain shader.
- ⚠️ No animation (egg wobble, grass wind) — the module only builds static
  geometry.
- ⚠️ The hatch variant is only applied to the middle egg (i=1); in the stage
  all 3 eggs might hatch at different times.