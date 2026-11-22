# Brief: move-style picker, round 2 (more bodies, turning, walk/canter/gallop)

Owner request (2026-11-22): "do the same exercise from these decisions with more body types and also turning, galloping, walking etc".

## Starting point
- Round 1: `web/gaitlab/styles.html`, `docs/evidence/loco/styles.md`.
- Owner picks for starter B (DESIGN A42): walk = diagonal walk / sprawl, stalk = slinky stalk, middle band = canter, full chase/flee = rotary gallop.
- Gait-lab rules in `docs/evidence/loco/gaitlab.md`: Froude, stride law, cadence = v/stride.
- Cadence target for the walk: longer strides, about 0.8–1.0 Hz at 2 m/s for starter B. Scale other bodies by the Froude number.

## Build `web/gaitlab/styles2.html`
Single file, file:// only, local three.js like round 1. Reuse round 1's code where possible.

**Grid: 4×4 per body.**
- **Rows are actions:**
  1. Walk: straight line at walk speed.
  2. Turn: walk around a circle or figure-8 of about 3 body lengths radius, plus one sharp 90–180° turn.
  3. Canter: middle band.
  4. Gallop: full speed.
  Each row runs at that body's own Froude-scaled speed.
- **Columns are four variants:**
  1. **A42 port:** the owner's picks, adapted to the body with the Froude rules.
  2. **Longer and lower:** stride +25%, body lower, cadence lower.
  3. **Bouncier:** more bob and flight, springier.
  4. **Froude default:** the gait lab's default, with no owner style.
- **Turn-row variants:**
  1. A42 port: lean into the turn, head leads, outside legs take longer steps.
  2. Wide arc: no stopping.
  3. Stop and pivot: steps around on the spot with real foot placement, no sliding.
  4. Froude default.
- Label each cell with Hz, stride, Froude number and duty factor, plus a footfall strip like round 1.

**Bodies (Space / Shift+Space cycles; about 14):**
- Starter B
- The hatchling
- Starters A, C and D
- Heavy quadruped (elephant-like, long legs, slow)
- Small fast quadruped (rodent-like)
- Short-legged sprawling lizard
- Long-necked, long-tailed quadruped
- Tall biped (bird-like)
- Hopping biped (kangaroo-like with tail)
- Hexapod (insect, tripod gait)
- Octopod (spider, metachronal gait)
- Many-legged centipede (≥ 12 legs, metachronal wave)
- Asymmetric or "impossible" body (e.g. 3 legs, one long), which must move clumsily but believably, never blocked (motion canon A34)

Use the game's starter JSON leg lengths where they exist (`godot/game/data/starters/`).

**Gait adaptation rules:**
- A canter or gallop for a hexapod, octopod or centipede means the faster version of its own gait: a fast tripod or a faster wave, not a mammal gallop.
- For bipeds it means a run or a hop.
- Write down the rule you use for each body type.

## Controls and output
- **Same as round 1:**
  - Click to star; one star per row per body is allowed.
  - "Copy choices", with a text fallback.
  - Choices persist in localStorage, wrapped in try/catch.
  - F to focus a cell, Esc to go back, P to pause, 0.25× / 0.5× / 1× playback.
- **Camera:** the turn row needs a camera that is top-down or high three-quarter, so the arc and the foot placement are readable. Optionally a T key toggles the camera for the turn row.
- **Copy text format:** `<body>: walk=<variant>; turn=<variant>; canter=<variant>; gallop=<variant>`.

## Checks
- A self-check exposed as `window.__stylesCheck`, covering every body × row × variant:
  - no foot slide while in stance (contact foot world-position drift < 2 cm)
  - no reversed knees
  - the body doesn't float: at least one foot down unless the gait has a flight phase
  - the turn path radius is reached
  - pivot turns have no foot slide
- `tools/gaitlab/styles2_capture.cjs` captures one JPG per body. Use SwiftShader only, never GPU flags. Write to `docs/evidence/loco/styles2/`.
- Document the presets and adaptation rules in `docs/evidence/loco/styles2.md`.

## Rules
- Do not touch Godot or C code.
- Do not commit; Claude commits.
- If Chromium is blocked in your sandbox, say so. Claude runs the capture.
