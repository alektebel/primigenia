# Creator validation — 2026-11-13

## Environment and scope

Linux x86-64; AMD Ryzen AI 7 350; Chromium 158.0.8127.18 through Playwright.
Browser captures use **SwiftShader software WebGL**, not the machine's hardware
GPU. Desktop is 1280×800; mobile is 390×844. The supplied reference was captured
at 1440×900. All screenshots are browser output from this repository, not
generated concept images. The reference HTML matches the supplied latest
`taller-de-criaturas(1).html` byte for byte.

Initial November 12 captures: [Taller reference](taller-reference-desktop.png),
[generated Coralino](creator-coralback-desktop.png),
[generated Abisal](creator-abyssal-desktop.png),
[Abisal on mobile](creator-abyssal-mobile.png).

## Verified behavior

- Seeded horn, plate, and tendril generation produces repeatable finite mesh
  buffers, valid indices, and normalized normals. Branch count adds topology;
  changing density preserves the shape seeds of existing indices.
- Browser checks verified direct pointer placement on the torso, one undo for
  a complete drag, exact redo, and Escape cancellation.
- Slider placement reuses generated geometry and preserves camera distance.
  Keyboard placement and leaving the placement tool were verified.
- Eight successive variations retained the same renderer geometry-allocation
  count. This is a bounded allocation check, not proof of zero memory leaks.
- All six presets, twenty random genomes, and all three growth families round
  trip. Invalid recipes are rejected without changing the accepted creature.
  The initial build migrated `cpore.creature/1` documents to `/2`; that version
  required a growth recipe so it could not be silently lost.
- Desktop and mobile rendering were visually inspected. Mobile has no horizontal
  document overflow and retains the creature viewport while controls scroll.

Commands: `node tests/test_growth.cjs`, the browser page
`/web/studio/test.html`, and `tests/studio_interaction.cjs` with Playwright.
The README documents the local server and optional browser test dependency.
The November 12 reusable browser runner completed with exit status 0; its
[machine-readable report](creator-browser-results.json) records every assertion
and the genome regression output.

## Performance evidence

The geometry-only Node benchmark generated 18 tendrils with three branches
each. After 20 warmups, 100 samples measured p50 **1.33 ms**, p95 **2.50 ms** in
the November 12 run. An earlier run measured p50 2.58 ms and p95 4.08 ms.
A November 13 run measured p50 2.99 ms and p95 4.06 ms.
These numbers cover recipe generation and normals only. They exclude GPU
upload, the scene, browser scheduling, and display latency. End-to-end latency,
hardware GPU frame rate, and real phone performance remain unverified.

## Capture failure and recovery

A browser run passed the interaction and mobile layout assertions, then exited
while taking the mobile screenshot after resizing a desktop context. The
reported error was `Target page, context or browser has been closed`.
There were no preceding application/shader errors and no observed system memory
exhaustion. The exact cause was not established.

A fresh mobile context successfully captured the scene and completed the full
genome regression page with no runtime errors. The reusable runner now starts
mobile in an independent context, which also exercises mobile startup. The
failure should not be described as an application defect or a confirmed driver
bug without additional evidence.

## Independent-region update

The November 13 studio adds independently editable torso, neck and tail regions.
The final reusable runner completed with exit status 0 and no runtime or shader
errors. Its [report](creator-regions-browser-results.json) records interaction
assertions and the complete genome regression output.

Visually inspected captures: [desktop regions](creator-regions-desktop.png) and
[mobile regions](creator-regions-mobile.png). Mobile startup loads the same
version 3 document through a share link; all recipes survive exactly.

Interaction checks cover:

- Editing the second region leaves the first recipe unchanged.
- Selecting a region does not mutate the saved document.
- Changing a seed rebuilds exactly one region; changing position and angle
  rebuilds none of the generated meshes.
- Duplication preserves the recipe under a distinct stable ID.
- Duplicate/delete undo and redo restore the exact document, including IDs.
- Symmetry and keyboard placement operate on the selected region only.
- Multiple regions survive an exact save/reload cycle.
- Version 1 and 2 documents migrate to version 3. Empty region lists and
  mixed torso/neck/tail recipes round trip. Duplicate/unsafe IDs, unknown
  surfaces, nonboolean symmetry, nonfinite positions, malformed parts and
  documents over the current 64-region resource limit are rejected.
- The mobile document has no horizontal overflow and the creature remains
  visible while the inspector scrolls.

A supplementary [touch report](creator-regions-touch-results.json) verifies
selection by tapping visible neck plates, no document change on selection,
touch dragging of only that region, and one-step undo. This uses actual browser
touch events at a 1280×800 viewport; it is not a physical phone latency test.
The reproducible runner is `tests/studio_touch.cjs`.

The first interaction run exposed a test setup error: it toggled an already
active placement tool off before sending arrow keys. The runner now explicitly
ensures that tool is active. A separate exploratory capture exceeded its
30-second screenshot timeout with software WebGL; the final runner captures
fresh desktop/mobile contexts with a 120-second capture timeout. Capture time
is not a measurement of interaction latency.

## Remaining product gaps

The prototype has three procedural families, independent regional placement,
seeded variations, and skin collars. It does not yet implement fused attachment
tissue, freely placed limbs, regional masks/locks, generalized rigs, editable GLB
import, AI-generated recipes/assets, or the C/WASM game connection. The Blender
asset library is available separately. Those remain explicit gates in the
functional design.
