# One camera, from the creature's eyes to the whole island

Status: **spec, 2026-11-17** (A18). The Spore captures live outside the repo in `~/Desarrollo/cpore-refs/spore-captures/` (never commit them). The owner wants Spore's mouse camera plus
Planetary Annihilation's continuous zoom: scroll to go near and far, drag to
orbit around the creature. Mechanics reference only (Q4): no assets or UI copied.

## 1. Controls

| Input | Effect |
|---|---|
| **Scroll** | Continuous zoom along one curve: over-the-shoulder → chase → high → **strategic map**. Smooth (eased), with a fast flick going farther |
| **Left drag** (moved more than ~6 px) | Nothing. The left button never moves the camera (creature-fixes 1, CREATURE-FIXES.md); a plain left **click** moves the creature (G57) and the drag threshold only stops a drag from counting as a click |
| **Right / middle drag** | Orbit too (already bound to `camera_orbit`) |
| **Middle click / Home** | Reset behind the creature at the default distance |
| **Q / E** (optional) | Rotate in steps without the mouse |

After you orbit, the camera **stays where you put it while you stand still**.
When you start moving, it eases back behind the creature after a short delay
(the default; a setting can turn this off for "free orbit").

## 2. The zoom curve

One parameter `z` from 0 (closest) to 1 (farthest) sets distance, pitch, field
of view and what gets drawn:

| z | Band | Distance | Pitch | What you see |
|---|---|---|---|---|
| 0.00 | **close (default, A54)** | 1.8 × body height | ~8° (almost level) | the gameplay view since the owner picked "Close" (2026-11-22); face and parts up close, befriending |
| 0.15 | chase | ~4 h | ~15° | the earlier default, horizon visible |
| 0.40 | high | ~12 h | ~35° | fights with several creatures, the pack later |
| 0.70 | tactical | ~150 m | ~55° | the area around you: dens, nests, paths; creature icons begin to fade in |
| 1.00 | **strategic** | whole island (~3 km) | ~70° | the island as a map: icons for your nest, species dens, `?` for undiscovered places, meteor shards found, your position. Terrain shown cheaply (LOD/imposters), grass and small props off |

- Terrain collision: the camera never goes underground or inside cliffs; it slides
  up along the slope.
- At high zoom, **icons replace models** (PA-style strategic zoom). Clicking an
  icon selects it (the G75 card); a double click does nothing extra (the left button never moves the camera).
- Time keeps running at every zoom (pause is separate, D7).
- The same camera becomes the **Band command view** later (ARC-PLAN §2): scroll out
  to command, scroll in to act.

## 3. HUD lessons from Spore screenshots (owner's captures, 2026-11-16)

What works there and is worth our own version (layout and ideas, not art):

| Element | Spore | Ours |
|---|---|---|
| Objective cards (top left) | "Eat", "Collect a part", "Hunt 3 Scorpo — 20 DNA" with relationship faces | A short goal stack: current species goal (ally/dominate progress 0/3, reward), diet hint, next discovery hint |
| Target card (top right) | species, abilities with levels, mood face, health bar over the target | the G75 card already does this; add ability levels and a health bar above the target |
| Minimap (bottom left) | coastline, `?` nests, home icon, zoom +/- | merges into the zoom curve: a small corner map, and z = 1 is the big one |
| Ability bar (bottom centre) | social / attack mode switch, moves on keys 1–4, movement abilities | the G75 radial stays; add a compact hotbar with keys 1–4 for the current mode's moves, with cooldowns |
| Own status (bottom right) | health, hunger, portrait | health, stamina, food, portrait of your creature |
| Evolution bar (bottom) | brain segments filling toward the next stage | progress to the next stage (species resolved, Cognition), DNA balance |
| Creator part tooltip | name, DNA cost, abilities with levels | the studio should show the same on hover (studio parity) |
| Creator ability summary (right) | totals per ability group, diet | the studio needs a totals panel: attack, social, movement, health |
| **History screen** | generations on a timeline, "gained dance / lost spit", consequence cards per stage | our **family tree / lineage view** (A13 ancestors, L0 ledger): every evolution step, gained and lost abilities, the traits earned, where each cousin lives now |

## 4. Tests

Zoom curve monotonic (distance, pitch); never below the terrain at 200 random
points; click vs drag threshold (click moves, drag orbits); orbit holds while still
and returns while moving; strategic icons appear above z ≈ 0.7; frame time at
z = 1 within budget. Evidence: a 5-frame strip from z = 0 to z = 1 on the real island.

## 5. Looking at the sky

Orbit pitch (`orbit_pitch`) goes from +0.5 to -1.6 rad (drag up). Below the level where the camera still looks at the creature
(elevation 0.04 rad) the camera stops rising above its floor, sinks towards the ground (never under it: 0.65 m clear) and its
aim tilts past the horizon up to -60 degrees (`look_pitch`, `aim` in the update result; the island does `camera.look_at(r.aim)`).
The zoom curve is unchanged; Home or middle click resets to behind the creature at the default pitch.
