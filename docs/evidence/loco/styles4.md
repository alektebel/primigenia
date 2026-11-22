# Move-style picker, round 4 (radial picks on terrain, trilateral A46, mirror A47, octopus redo)

Open [styles4.html](../../../web/gaitlab/styles4.html) directly with `file://` (local three.js r128, no network). Round 3 is [styles3.md](styles3.md). **Awaiting owner choice; nothing here is approved or ported.** All numbers are starting values for the owner comparison, not measured animal data.

## What it shows
16 pages, cycled with Space / Shift+Space (**G** jumps to the other page of the same body). Four columns per row. One star per row, **Copy choices** gives `<body>: <row>=<variant>; ...`. Keys: **F** focus a cell, **Esc**, **P** pause, 0.25x / 0.5x / 1x, **T** cycles three-quarter (default), top-down, side camera. Teal line = path of the body centre. Gold dot = a touchdown point; gold tip = an arm that is planted. Each cell prints Hz, stride, speed, Froude number and how many feet are down; the strip is the footfall record.

| Page | Body | Rows |
|---|---|---|
| 1-2 | radial 5 (starfish) | p1: flat walk, fast / bound, rocks and bumps, stop and reverse. p2: slope up 25 deg, slope down 25 deg, step / ledge, turn on rocks |
| 3-4 | radial 5 brittle star (long thin arms, small disc) | same 8 rows |
| 5-6 | radial 5, heavy short arms | same 8 rows |
| 7-8 | radial 6 | same 8 rows |
| 9-10 | radial 4 | same 8 rows |
| 11-12 | trilateral (A46) | flat, fast, rocks, reverse / slope then ledge, turn on rocks |
| 13-14 | two-headed mirror (A47) | flat, fast, rocks, reverse / slope then ledge, turn on rocks |
| 15-16 | octopus, 8 new candidates | flat, rocks, slope then ledge, fast; page 15 = candidates 1-4, page 16 = 5-8 |

## The four radial variants (starfish, brittle star, heavy, radial 6, radial 4)
| # | Variant | Rule |
|---|---|---|
| 1 | **leading arm** (A45 baseline) | Arm 0 is always the lead. It probes first (shorter stance, 8% reach bias). Body yaw follows the path (max 2.5 rad/s), so a reversal is a pivot in place. |
| 2 | **rotating lead** (A45 baseline) | Body yaw is fixed. The lead is the arm whose direction is nearest the path; the rest of the gait is arranged relative to it. A reversal only changes the lead. |
| 3 | **lead hand-over** (hybrid) | Leading arm, but the body yaws only 45% of the path's turn rate. Whenever the lead is more than 60 degrees off the path, the lead is handed to the nearest arm. Fewer lead changes than variant 2, less body turning than variant 1. On a straight reversal there is no path curvature, so the yaw stays at 0 and only the lead changes (the cell shows no body turn). |
| 4 | **rotating lead + bounding rhythm** (hybrid) | Variant 2, but the base rhythm is 2-beat: arms in front of the body land together, arms behind push together (a lope with 70% duty on the ground, a real bound with flight when fast). |

Rhythm per row: flat, rocks, slopes, step, turn, reverse use the pentagram walk for variants 1-3 (n=5, duty 0.62; n=6 alternating tripods; n=4 ring wave) and the lope for variant 4. The **fast** row: variant 1 and 3 and 4 use a **2-beat bound** (rear arms stance 0 to 0.30, front arms 0.50 to 0.80, duty 0.30 / 0.27, flight 0.2 cycle twice); variant 2 uses a **3-beat gallop** (rear, flanks, lead; one flight of 0.27 cycle). Front/rear is decided by the cosine between the arm and the path (front above 0.2, with hysteresis so an arm does not flip every tick).

### How bounding works for a radial body
There is no front leg pair, so groups come from the path direction: arms ahead of the body form the landing group, arms behind form the push group. Each group has a stance window and between the windows no arm touches the ground (flight). During flight the body follows a ballistic arc (apex = g t^2 / 8 for the real flight time at the current cadence, 1.1 cm for the starfish at Fr 1); during stance it squats by 14% of the hip height. Body pitch follows the cycle: nose up as the rear arms leave, nose down as the front arms land (up to 8.6 deg, 12 deg for variant 4). Cadence is tied to speed so a stance sweep never exceeds 0.42 arm lengths. With the rotating lead the groups follow the path, so the bound still works going backwards. A cartwheel sprint was considered for the hybrids and not built: it needs a rolling-polygon engine that this page's terrain solver does not have.

**Real animals.** Brittle stars (Ophiuroidea) move by rowing with a lead arm and two flanking arms pushing, and they change which arm leads instead of turning the body (Astley 2012, J Exp Biol 215:1923, on *Ophiocoma echinata*; Watanabe et al. 2012 on lead-arm coordination, citations from memory, check before quoting). Asteroid starfish also pick a lead arm and use tube feet, not bounds. **Speculative:** any flight phase for a radial body (real brittle stars do bound-like "jumping" only in escape swimming in a few species, and starfish do not), the 3-beat gallop, and the hand-over rule's 45% and 60 degree numbers.

## Trilateral, A46 (three legs at 120 degrees, no front)
Columns: **lead-leg switch** (baseline: heading fixed, nearest leg leads, 20 degree hysteresis); **faster switch** (no hysteresis, 1.3x cadence); **bouncier switch** (the same walk with a large bob and pitch, a 2-beat bound in the fast row with a bigger squat); **switch + tripod spin** (body spins with the path in tripod steps when path curvature exceeds 0.3 per arm length, otherwise switches lead). Fast row for all four is a 2-beat bound (lead leg after the rear pair). Round 3 had a lope here; the failed lope on three legs (support gaps when the lead flips) was replaced by a bobbing tripod walk. This is flagged as a **compromise**, not a design choice.

## Mirror body, A47 (head at each end, 6 legs)
Columns: **caterpillar wave** (baseline: body wave rear to front, wavelength 0.9 body, amplitude 3.5 cm, leg pairs lag 0.18 cycle, duty 0.72); **shorter wave** (14 thin segments, wavelength 0.45, amplitude 2.2 cm, lag 0.3); **hump** (one wave of 5 cm, wavelength 1.6, inchworm-like arch, duty 0.55); **wave + trough stepping** (baseline wave, each pair lifts when its part of the body is in a trough, derived from the wave phase). Reverse: the other head becomes the front, the wave and the leg order flip, the body never yaws (checked). Fast row: duty cut by 0.1 (min 0.5). The two-headed arrangement and the wave rows are design variations with no animal behind the numbers; the caterpillar-like wave is loosely modelled on caterpillar and millipede locomotion (speculative).

## Octopus: eight new candidates (round 3 was rejected)
Arms are now **continuous tapering tubes** (16 stations along a Bezier whose bulge is set by the arm's length), not jointed segments: the length changes with the task (stretch up to 1.5x, shorten to 0.55x), the arm bends smoothly anywhere, traveling curvature waves ride on free arms, and a web skirt billows in the pounce. Contact tips are static while planted. Arms are not bones; the engine treats them as hydrostats whose chord and length are independent (length conserved only loosely; **speculative**, no volume conservation).

| # | Candidate | What it does | Status |
|---|---|---|---|
| 1 | reach, anchor, pull | 3 front arms alternate: stretch to 1.4x ahead, anchor, contract to 0.55x while dragging the body; five arms trail | Real: octopuses crawl by reaching with arms, attaching suckers and pulling (documented, e.g. Mather 1998 and Huffard 2005, from memory); the exact 3-arm alternation is a design choice |
| 2 | sucker conveyor | 8 arms lie flat, the planted parts pass backwards in a wave, tiny steps | Speculative. Slug-like pedal waves are real in gastropods, not in octopus |
| 3 | tiptoe stilts | mantle high on 6 tips, 2 arms curled; slow rotating sequence | Partly real: octopuses can raise the body on arm tips ("stilt walking", Huffard et al. 2005 on bipedal walking and arm-tip locomotion, from memory); 6-tip rotation speculative |
| 4 | streaming slither | mantle low, 6 arms trail and ripple, 2 tips flick down alternately | Speculative; arm trailing in a current is real for swimming |
| 5 | umbrella pounce | all arms spread, web billows, snap in; flight 0.55 cycle | Speculative (escape jetting is real, but is water jet, not ground hop) |
| 6 | pole vault | two long arms plant ahead like poles; the body arcs over; next pair reaches | Speculative, good for ledges |
| 7 | arm rowing | lead arm probes, pairs of arms row on each side; soft version of the A45 pick | Inspired by brittle stars; speculative on octopus |
| 8 | wave roll | arms plant one after another around the ring and flip over the top, body tilt rolls | Speculative (rolling is not documented) |

Octopus rows use a slope 25 degrees then a ledge. In this solver the rotation of the arm planting around the ring is a ring wave with high swing arcs, not a true wheel: tips stay static.

## Engine (one code block `CORE_BEGIN..CORE_END`, also run by Node)
- **Heightfields:** flat; rocks (seeded, deterministic: one candidate Gaussian bump per 0.55 arm-length cell, up to 0.26 arm lengths high, slope up to about 40 degrees where bumps overlap; smaller for the mirror body and the trilateral); 25 degree ramps up and down (smooth fillets); a ledge of 0.45 body heights (hip height); ramp then 0.4 body-height ledge. One function per row, used for the picture and for the checks.
- **Path first:** the body centre follows a path with a speed profile; feet are scheduled on a cycle clock `Phi` (cadence set so no stance sweeps more than 0.42 arm lengths, 0.34 for the mirror). The touchdown point of each foot is the **rest point at the pose of mid-stance**, predicted along the path, then moved to the best of 17 candidate footholds on the real terrain (cost: offset, slope above 0.45, reach). The target is re-predicted twice during the swing and tracked in the last 30%. Feet land on the surface height of the field at their position; swing paths rise to clear the highest ground along the chord.
- **Body:** height and tilt follow the plane fitted to six samples of the heightfield under the disc, offset by the hip height along the plane normal (so slopes keep the same geometry as flat), smoothed; a clearance floor from rim samples keeps the disc above the ground. Dynamic pitch / bounce / wave are added on top.
- **Arms:** rigid two-link IK (starfish, trilateral, mirror) or soft arms (octopus); a post-step lift of the elbow keeps arm samples above the terrain.
- **Guards:** an arm is not lifted if that would leave fewer than 2 (walk, 4+ arms) or 1 (other) feet down, unless it is beyond reach; stopping completes swings in 0.3 s and restarts with a gait phase aligned to the lead; a lead change in a linear walk shifts the cycle clock so no arm changes its schedule (the "rephase" trick).

## Physics rules checked
1. A planted tip does not move (drift under 2 cm; measured worst 0.9 cm over the passing cases).
2. No arm sample, tip or disc rim goes through the ground (more than 3 mm).
3. No floating: some foot is down in every frame, except inside a declared flight window (bound, gallop, pounce).
4. Arm stretch at most 1.5x its rest length.
5. Terrain rows: the body reaches the end of the ramp or ledge and ends at the right height (slope down: at the bottom).
6. Reverse row: the rotating-lead and hand-over variants and every 3-fold / mirror variant must not yaw the body more than 2 degrees (hand-over: under 52 degrees), and the lead (or the head) must change; the leading arm must turn at least 150 degrees (it does, 180).

## Self-check (`window.__stylesCheck`, `?test=1`, header button, or `node tools/gaitlab/styles4_check.cjs [body] [--table]`)
Cases: 5 radial bodies x 8 rows x 4 variants = 160, trilateral 6 x 4 = 24, mirror 6 x 4 = 24, octopus 4 x 8 = 32: **240 cases**. Run 2026-11-22: **239 / 240 pass** (Node and browser identical). The failure: **trilateral, turn on rocks, lead-leg switch: 6 frames (0.04 s) with no foot down** (the first touchdown of a three-legged lead lands out of reach, and the retry leaves the body without a foot for a few frames). The numbers are in `styles4/table.json`.

```sh
node tools/gaitlab/styles4_check.cjs
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/styles4_capture.cjs
```
Capture: SwiftShader only, `file://`, flags a network request or page error, writes one JPG per page (`styles4/page01_...jpg` to `page16_...jpg`), `focus_cell.jpg`, `laptop.jpg`, and checks stars, one per row, persistence, copy, Space, Shift+Space, G, F/Esc, P, T and playback with real keys and clicks.

## Known weak cells and caveats
- **Trilateral turn on rocks, lead-leg switch:** the one failing check above.
- **Lead hand-over** is nearly the same as the leading arm on straight rows and in the fast row (same 2-beat bound); it differs only on turns (body yaws 45% of the turn, lead hands over) and on reversal.
- **Rotating lead + bounding (lope)** on 4-arm and 6-arm bodies on rocks and slopes has the thinnest support: only two groups, 70% duty; floating is avoided by a guard that delays lifts, which makes the lope less regular there.
- **Octopus** candidates 2 (conveyor) and 8 (wave roll) read as a generic ring-wave crawl in still frames; the difference is arm lying flat vs high flip arcs. The pounce web is barely visible. Candidate 5 (pounce) is the only one with a ballistic phase; 6 (vault) arc is a prescribed body hump, not computed dynamics.
- **Mirror body hump** is the weakest on rocks and turns (amplitude 5 cm against 28 cm hip height and 40 cm legs); rocks for the mirror are scaled down to 0.6.
- **Brittle star** arms are rigid two-link with a smooth outline, so they look like thin wires, not the segmented arms of real brittle stars.
- **Stops:** when a cell is standing (reverse row, 1.6 s pauses) the body is static and all arms planted; leading arm pivots at 2.5 rad/s during the pause.
- Cells restart when the path or terrain ends (about every 10 to 30 s); the restart is a cut.
- Camera: terrain rows start in three-quarter view, which shows slopes less clearly than the side view (T).
