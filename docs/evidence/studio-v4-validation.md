# P1 creator integration — 2026-11-14

The studio starts from a copy of `art/reference/creador-de-criaturas.html`.
Its renderer and editor now live in `web/studio/studio.js`; the original three
HTML references were SHA-256 checked before/after and remain byte-identical.

The implementation ships 46 palette entries (22 procedural, 24 GLB), nine
categories, Build/Paint/Test, direct vertical spine sculpting, mirrored part
placement, the reference procedural IK/gait, seeded growth regions, undo/redo,
JSON files/paste, Unicode share links and es/en. The source GLBs and manifest
are copied byte-for-byte; `catalog.blend` is excluded.

## Automated checks

All browser processes were launched with `nice -n 10`. The executable was
`~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome`; Chromium reported
`158.0.8127.18`. Explicit launch arguments were exactly:

```js
['--use-angle=swiftshader', '--enable-unsafe-swiftshader']
```

Desktop: 1280×800, DPR 1. Mobile: 390×844, DPR 1, mobile/touch emulation.
Browsers were closed in `finally`. These are software-WebGL functional checks,
not hardware performance measurements.

| Command | Result |
| --- | --- |
| `node tests/test_studio_genome.cjs` | Pass: strict `/4` validation; `/1`, `/2`, `/3` fixtures; original preservation and migration round trips; malformed, duplicate and missing growth fields; `/2` `none` handling |
| `nice -n 10 node tests/test_growth.cjs` | Pass: deterministic geometry, finite data, valid indices/normals, branching, seed stability and rejection contracts; CPU generation benchmark printed, not a frame-rate claim |
| `python3 tests/check_studio_glbs.py` | Pass: all 24 GLBs, 62,858 triangles; hashes, GLB headers/chunks, buffer/accessor bounds, finite values, triangle indices, material references and declared source axes |
| `nice -n 10 node tests/studio_interaction.cjs` | Pass: 469 browser contracts plus mouse/keyboard/UI interactions; see `studio-v4-results.json` |
| `nice -n 10 node tests/studio_touch.cjs` | Pass: seven mobile interaction/layout checks, no page errors; see `studio-v4-touch-results.json` |
| `node --check` on authored JS and CJS | Pass |
| Focused final browser check | Pass: JSON entity preservation, English ability labels after a rebuild, rotated GLB round trip and startup |
| `git diff --check` | Pass |
| Impeccable detector on changed interface | No findings |

The browser contracts hash exported JSON with SHA-256, import it and compare
hashes for all three reference presets and 20 seeded random creatures. They
also migrate the three fixture versions and reject invalid documents without
changing the creature. The interaction suite covers a Unicode name/share-link
reload, independent regions, duplicate/delete/variant history, cached geometry
on placement, pointer drag/Escape, keyboard placement, GLB palette dragging,
language, Paint and Test actions.

Every one of the 46 catalog entries is placed on every preset: **138
part/preset cases**. Root error is measured independently against the actual
body triangles using closest-point distance, including procedural leg hips and
mirrored copies. Maximum observed distance: **0.014990032920857215 studio
units**, below the 0.045-unit threshold. This proves attachment-point proximity,
not a tissue blend or absence of all mesh/body intersections.

No offline `gltf-validator` executable/module was found on PATH, the default
Node module path or the supplied Playwright dependencies. No validator was
downloaded. The structural script is deliberately smaller than a conformance
validator: **zero Khronos validation errors are not claimed**. Khronos Sample
Viewer comparison is unverified.

## Materials and orientation

The original manifest specifies Blender +Z-up, +X-forward and glTF +Y-up in
meters. The authoring script exports with `export_yup=True`: source `(x,y,z)`
becomes glTF `(x,z,-y)`. The loader bakes exported node transforms before a
−90° Y rotation into studio +Z-forward/+Y-up. It mounts radial parts along the
surface normal and body parts in the local spine frame, mirroring wings/limbs
across the spine plane. Automated bounds checks confirm forward jaws, downward
legs, outward wings, rearward tails and outward crowns through the actual
loaded exporter output.

The assets have descriptive material names, without explicit anatomical region
tags. The table maps these names to skin/keratin/membrane/eye, overrides beak
slots and the insect wing's lower sail, and supplies category fallback for
unnamed slots. No source palette is retained. Skin and membranes use the
creator's shared pattern/colour uniforms; membranes are translucent. Keratin
uses bone/beak, eyes use the reference iris/pupil materials.

The desktop screenshot was visually inspected: the wing spans outward on the
flank, the grasper sits at the front flank, and the lure rises from the head.
The mobile screenshot was inspected at 390px: scene, palette, DNA, inspector
and document controls remain readable without horizontal clipping. This is a
representative studio orientation check, not an inspection of all 24 assets
in the Khronos viewer.

- [Desktop, imported wing/arm/lure](studio-v4-desktop.png)
- [Mobile, imported insect wing and full workbench](studio-v4-mobile.png)

## Delivery limits

All designs and catalog entries are explicitly cosmetic until the C validator
is connected. Candidate C type names and illustrative abilities in the part
table grant nothing; studio DNA and capability meters are preview estimates.
No gameplay validation or C/WASM projection is claimed.

Legacy slider documents cannot reproduce identical geometry in a node-based
creator. Imports report approximations of body/head/slots, motion and levels;
old gameplay estimates stay only in `migration.source`, which preserves the
original. `/3` regional recipes retain stable IDs; `/2` becomes one torso
region; `/1` has none. No silent loss of the original document is required.

GLBs remain rigid, including imported legs, arms and wings. Only the original
procedural legs have IK. One original LOD per GLB ships; reduced LODs, root
footprints/deformation cages, unified root tissue, generalized rigs, branching,
asymmetry, AI generation and measured end-to-end latency budgets remain open.
Owner visual approval remains pending.

cdnjs does not distribute the r128 examples loader (its version API lists only
`three.js`, `three.min.js`, `three.module.js`, `three.module.min.js`; the requested
examples URL returns 404). The matching official r128 `GLTFLoader.js` is
vendored with the Three.js MIT license. Three.js itself stays on cdnjs;
fonts/Three.js still require network access.
