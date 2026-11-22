# Brief: move-style picker, a 4×4 grid of how *this* creature could move (three.js lab)

Worktree `/home/diego/Desarrollo/cpore-wt/move-styles`, branch `anim/move-styles`. Owner, 2026-11-22: "generate a 4x4 grid testing different move types in order to assess how we want this creature to move exactly; with Space we can iterate between creatures." Earlier owner feedback: "the legs move too fast"; "2 m/s seems the sweet spot".
Read first:
- `AGENTS.md`
- `docs/canon/MOTION.md`
- `docs/evidence/loco/gaitlab.md`
- `web/gaitlab/index.html`: reuse its IK, stance pinning, footfall and bob code
- `godot/game/data/starters/*.json` and the hatchling genome: body proportions

You cannot commit: leave the changes uncommitted.

## Page `web/gaitlab/styles.html` (single file, three.js r128, local copy as in the gait lab, no build, works from file://)
- **One creature, 16 cells.** All 16 cells show the **same creature** walking in a straight line at the same speed (default 2 m/s; a speed slider from 1 to 6 m/s keeps each style's character). Side camera per cell tracks it, with ground ticks for slip. A big label per cell: the style name plus one plain line ("long slow steps, heavy").
- **Space switches the creature** for all 16 cells at once: starter B (default), hatchling, A, C, D, plus a generic quadruped and a biped.
  - Proportions (hip height, leg segment lengths, body length, neck and head, tail) come from the starter genomes. Extract them with a small script into an inline JS table (record the script in `tools/gaitlab/`).
  - Primitive geometry is fine, but recognisable: body, neck, head, tail, the right leg count.
  - Shift+Space goes back. The creature name shows top-left.
- **The 16 styles** (each a parameter preset: footfall offsets, duty, stride/cadence ratio, bob amplitude and phase, roll, pitch, body height, spine undulation, head motion, foot lift; values cited or marked starting value):
  - Row 1, walks: **lateral-sequence walk** (horse or dog), **diagonal walk / sprawl** (lizard, low body, spine wave), **amble / rack** (smooth, four-beat, fast), **knuckle-walk** (gorilla: front limbs as struts, body rolls with each hand plant, as in the reference video).
  - Row 2, runs: **trot** (diagonal pairs), **pace** (same-side pairs, camel), **canter** (three-beat, rocking), **rotary gallop** (with a flight phase).
  - Row 3, character at walk speed: **heavy** (elephant: long slow strides, low bob, never airborne), **nervous small** (quick short steps, sudden head moves), **slinky stalk** (cat: low body, smooth, long reach, quiet feet), **springy** (deer: high foot lift, bouncy).
  - Row 4, other locomotion: **biped run** (raptor, tail as counterweight, if the body has 2 legs; otherwise a bipedal "rear-up" variant), **bound / hop** (all feet together, rabbit or kangaroo style), **salamander wiggle** (strong spine undulation driving the legs), **crouch-creep** (low, slow, careful, a predator stalking).
  - For bodies whose leg count doesn't fit a style (e.g. a biped), use the closest sensible adaptation and say so on the label.
- **Interaction:**
  - Click a cell to star it (★ in the corner; click again to unstar). A side panel lists starred styles per creature.
  - A **"Copy choices"** button copies a short text such as `starter B: ★ knuckle-walk, heavy; hatchling: ★ trot`, for the owner to paste into chat.
  - Keys: `F` fullscreens the hovered cell; `0.25×/0.5×/1×` playback; `P` pause. No animation on keyboard actions (Emil rules).
- **Correctness:**
  - stance feet pinned (zero slip), no knee flips, no crossing
  - cadence from stride, never fast tiny steps unless the style says "nervous small"
  - flight phase only where the style has one
  - a `?test=1` self-check per style per creature, the same as the gait lab
- **Capture:** `tools/gaitlab/styles_capture.cjs` (SwiftShader only, never GPU flags, `NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules`) takes one grid screenshot per creature into `docs/evidence/loco/styles/`. If the sandbox blocks the browser, say so.
- **Docs:** `docs/evidence/loco/styles.md` with the 16 presets as a table (parameters plus source) and how each would port to `godot/locomotion/loco_gait.gd` as a named style.
- Don't touch `godot/`, `core/` or other web pages.
