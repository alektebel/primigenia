# Brief: move-style picker, round 3 (other symmetries + limbless movement)

Owner (2026-11-22): "try also other types of symmetries or worm/snake movement patterns".
- Builds on round 2: `web/gaitlab/styles2.html`, `docs/evidence/loco/styles2.md`, and owner picks A42/A43 in `docs/DESIGN.md`.
- Fix while you are in there: "longer-lower" looked buggy on the asymmetric three-legged body in styles2.html. Find the cause and fix it in styles2.html as well.

## Build `web/gaitlab/styles3.html`
Same shell as round 2:
- file://, local three.js
- Space / Shift+Space cycle bodies
- 4×4 grid per body, star one cell per row, Copy choices, localStorage in try/catch
- F, Esc, P, playback 0.25×, 0.5× and 1×
- T toggles a top-down camera, which is the default for limbless bodies
- teal path trail
- labels show Hz, wavelength or stride, speed, and Froude number where it applies

### A. Other symmetries (legged)
Each body gets rows walk / turn / fast / rough-or-slow (pick what fits) and 4 variants. Explain each variant in the cell subtitle.
- **Radial 5 (starfish-like):** 5 arms.
  - Variants:
    - (1) leading arm: one arm points forward, the others push
    - (2) rotating lead: the lead arm changes when turning, so the body doesn't need to rotate
    - (3) tube-foot glide: slow ripple
    - (4) cartwheel / tumble
- **Radial 6 or 8 (octopus-like):** arms walking on the ground.
  - Variants:
    - (1) two-arm bipedal walk, the octopus trick
    - (2) all-arm crawl
    - (3) jet-scoot hop
    - (4) rolling
- **Trilateral (3-fold symmetry, 3 or 6 legs at 120°):** no front.
  - Variants: tripod rotation, lead-leg switch, spin-walk, and a tumble.
- **Front/back mirror (two heads, or a head at both ends):** variants are reverse-without-turning, a push-me-pull-you shuffle, a fold, and a caterpillar-style wave.
- **Chiral / spiral body:** limbs arranged in a helix. Variants: a screw-roll and wave variants.

### B. Limbless (worm / snake)
Each body gets rows: slow crawl / turn / fast / rough-or-loose ground (e.g. sand or slope).
- **Snake:** lateral undulation (serpentine), sidewinding, concertina, rectilinear.
- **Earthworm:** peristalsis. Contraction waves travel backwards and segments anchor with setae. Variants: wave count 1, 2 or 3, and burrow-dive.
- **Inchworm / looper:** loop-step, with a fast-looper and a pole-vault-flip variant.
- **Slug / gastropod:** a pedal ripple glide on a slime trail. Variants: direct vs retrograde waves, loping (arching).
- **Eel-like on land:** a wide S-wave, with a flop/jump variant.
- **Hybrid body (snake body with 2 small legs):** legs-assisted serpentine.

### Physics rules
Write these in `docs/evidence/loco/styles3.md`, with sources where they are real biology:
- serpentine needs lateral push points
- sidewinding lifts body sections, and only static contact patches touch the ground
- concertina anchors and extends
- peristalsis needs anchors
- a static contact point must not slide

## Checks
- `window.__stylesCheck` with `?test=1`:
  - Static contact points (feet, anchored segments, sidewinding patches) drift < 2 cm.
  - Nothing goes through the ground.
  - Turn paths reach their radius.
  - The body doesn't float, except during explicit hops or tumbles.
- Capture with `tools/gaitlab/styles3_capture.cjs`, modelled on styles2_capture.cjs. Use SwiftShader only:
  ```
  NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/styles3_capture.cjs
  ```
  Write the output to `docs/evidence/loco/styles3/`. Look at the JPGs yourself and fix anything that looks broken.

## Rules
- Do not touch godot/ or C code.
- Commit on the branch. Do not merge.
- End the commit message with: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
