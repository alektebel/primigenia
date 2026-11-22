# Brief: creature editor flow like the owner's reference video

Owner request (2026-11-22): "can we make the creature stage flow edition more similar to the demonstration of this video?"
- Reference: `~/Desarrollo/cpore-refs/videos/creator-flow-2026-11-22.mp4`, 77 s, portrait phone capture of someone remaking a creature in a 2008-era creature editor. Never commit the video.
- Frames: the scratchpad contact sheet. Extract your own with ffmpeg.

## What the video does (the target feel)
1. **The creature is the stage.**
   - It stands large and centred on a round pedestal, filling about 50–60% of the frame height.
   - The camera is close, at a slight low angle, and orbits the pedestal.
   - Behind it is a calm, uncluttered scenic backdrop.
   - No grass or rocks sit between the camera and the creature.
2. **A minimal HUD.**
   - Top left: a small row of mode icons.
   - Top right: a compact budget counter ("53/255").
   - Everything else hides until it's needed.
   - No big side panels covering the creature.
3. **Direct manipulation on the body.**
   - Hovering the spine shows **blue sphere handles** on each vertebra. Drag one to move or stretch the spine; the mouse wheel over a vertebra fattens or thins it.
   - Hovering a part shows a **green ring** around it. Drag the ring to rotate; the wheel scales the part.
   - Parts are dragged straight onto the body surface and snap there, mirrored automatically.
   - Placed parts can be dragged around freely to rearrange them.
   - Alt-drag duplicates a part, with a "copy for N" tooltip.
4. **Feedback for every action.**
   - A small puff and pop when a part lands.
   - A floating "+cost" number near the part.
   - The budget counter ticks up.
5. **The creature stays alive.**
   - It idles and breathes, and shifts its weight.
   - It looks at the part it was just given or at the cursor, and poses (flexes, roars) after a change.
   - Legs re-stand at once when the body changes.
6. **The finish.** The paint step gives the final textured look, then the creature walks off.

## What we have (Godot `godot/studio/`, `docs/evidence/godot/first-quest/08_task5_editor_gland.png`)
- The creature is small, in the middle of a grass field with grass blades in front of the camera.
- Two big side panels: the parts list on the left; level, abilities and actuation text on the right.
- Spine arrows plus a tiny joint dot; wheel scaling exists.
- A bottom hint line carries the instructions.

## Changes (in priority order; each one is its own commit with before/after captures)
- **C1 Stage:**
  - A pedestal scene: a round plinth, calm backdrop (sky, distant hills, a few trees), soft key and rim light.
  - No near grass.
  - The camera frames the creature at 50–60% of the frame height, orbits with right-drag, zooms with the wheel on empty space, and auto-frames when the size changes.
- **C2 HUD diet:**
  - Collapse the right panel into a compact budget counter (top right) and a slide-out "details" drawer, closed by default.
  - The left parts palette becomes a slim icon strip that expands on hover or click.
  - Keep Build / Paint / Test / Undo / Redo as icons with tooltips.
  - Follow the Emil rules: ease-out, ≤ 250 ms, press scale 0.97, no animation on keyboard actions, nothing appearing from scale 0.
- **C3 Handles:**
  - Blue vertebra spheres on spine hover: drag to move or stretch, wheel to fatten.
  - A green ring on part hover: drag to rotate, wheel to scale.
  - Handles keep a constant screen size and fade in about 120 ms.
  - Keep the existing model and undo transactions (`model.begin()` / `model.end()`).
- **C4 Feedback:**
  - A puff particle and pop sound when a part lands.
  - A floating "+N" cost that rises and fades in 600 ms.
  - The counter tick.
  - A short shake and red flash when a part won't fit, with the reason in a tooltip.
- **C5 Alive creature:**
  - An idle and breathing loop in build mode.
  - The head turns toward the last placed part or the cursor, clamped.
  - A one-shot pose after each change, at most once every 3 s.
  - Use the existing locomotion and pose code; this is visual only.
- **C6 Rearrange and duplicate:** drag placed parts across the surface with live mirroring; alt-drag duplicates.

## Out of scope
- New parts, painting tech and C code.
- The nest-edit entry is owned by `ui/verb-target`. Start from main after it merges, and keep its entry point working.

## Acceptance
- Side-by-side captures, ours against the video frames, at the same 4 moments: start, adding a part, stretching the spine, final.
- The creature fills ≥ 50% of the frame height.
- With the drawer closed, ≤ 15% of the screen is covered by UI.
- Studio suite, ui suite and first-quest e2e (which opens the editor) all pass.
- Frame time in the studio is no worse than today.
- Owner vote on the captures.
