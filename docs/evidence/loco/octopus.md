# Octopus, underwater study (owner 2026-11-22, A53 follow-up)

Open [octopus.html](../../../web/gaitlab/octopus.html) directly with `file://` (local three.js r128, no network). Round 4 is [styles4.md](styles4.md); none of its 8 land octopus styles was liked, and the owner asked how octopuses really move with these arms. **Awaiting owner choice; nothing here is approved or ported.** All numbers are starting values (metres, seconds; mantle 20 cm, arms 55 cm, cirrate 42 cm), not measured animal data.

**Every biology claim and citation below is from memory and UNCHECKED. Verify before quoting.**

## What it shows
3 pages (Space / Shift+Space), each 4 rows x 4 columns = 48 cells. Rows: **cruise, fast / escape, turn and manoeuvre, terrain**. One star per row across all pages; **Copy choices** gives `octopus (underwater): cruise=<name>; fast=...; turn=...; terrain=...`. Keys: **F** focus, **Esc**, **P**, 0.25x / 0.5x / 1x, **T** (three-quarter, top-down, side). Underwater look: blue-green fog, vertex-lit caustics that move over a sand and rock heightfield, plankton specks that are pushed by the body and by the jet, ink, pale ghosts of the mantle 0.12 s apart on fast swimmers, teal line = path. Pale gold dots = suckers stuck to the ground. Every cell's subtitle names the animal that does it and says **Documented / Partly documented / Speculative**.

| Page | Columns |
|---|---|
| 1 core modes | benthic crawl / jet / web pulse / cirrate fins, per row (fast crawl, jet burst + ink, web snap, fast flap; crawl no yaw, siphon steering, asymmetric web, differential fins; clamber rocks, gap squeeze, slope, open-water climb) |
| 2 variations | tiptoe crawl, jet and glide, jet with loose arms, two-arm walk; tight jet, jet + arm flare, two-arm run, arm skitter; crawl with yaw (contrast), arm rudder, two-arm walk turning, web pivot; jet over rocks, web climb, cirrate over rocks, two-arm walk on a slope |
| 3 special | land excursion, cirrate hover, lazy umbrella, low belly crawl; land scuttle, parachute pounce, double pulse, jet then brake; slow circle, land turn, jet U-turn, crawl reversal; land over rocks, pounce among rocks, tight squeeze (7 cm gap), land slope |

## The seven real modes
| # | Mode | What the model does | Status and animals (UNCHECKED) |
|---|---|---|---|
| 1 | **Seafloor crawl** | Planted arms are fixed in the world (a short sucker patch lies on the ground). Arms in the direction of travel reach and land, arms behind elongate (up to 1.4 x) while the body moves away, then release; release times are random per arm, any arm can lead, at most 3 swing at once, at least 4 stay down. The mantle heading is fixed, so the path can turn in any direction with no yaw. | Documented. Levy, Flash and Hochner 2015, Curr Biol 25 (arm coordination in octopus crawling: arms push by elongating, no fixed rhythm, any arm leads, body moves in any direction without turning). |
| 2 | **Jet swimming** | Mantle cavity fills (58% of the cycle), squeezes fast (25%), rests; thrust is proportional to the expelled flow; the body travels mantle-first, arms trail as a bundle; the funnel bends to steer. Steady: 1.5 s pulses (0.7 m/s peak); burst: 0.75 s pulses with ink, up to 2.4 m/s. | Documented for octopuses generally (jet propulsion, mantle and funnel; ink as decoy). Numbers invented. |
| 3 | **Web pulse ("medusoid")** | Arms and web open as an umbrella, then snap shut; the pulse pushes the body apex-first. Web between all arms for 60-65% of their length. | Partly documented: incirrate octopuses use arm and web pulsing ("umbrella") in escapes and parachute moves; as steady cruising it is speculative. |
| 3b | **Fin flap (cirrate)** | Two ear-shaped fins beat as a travelling wave (1.2-2.3 Hz); arms webbed 72% as a soft bell. | Documented: Grimpoteuthis and Opisthoteuthis "dumbo" cirrates swim with the fins and the web (Vecchione and Young 1997 on cirrate functional morphology; ROV footage). The fast beat and differential-fin turn are guesses. |
| 4 | **Parachute pounce** | Approach, flare web, drop with arms spread, then arms close down over a crab on the seafloor and wrap. Scripted, 9.5 s loop; arms collide with the prey sphere. | Documented as web-over prey capture in common octopuses (e.g. Mather's field work); the timings are invented. |
| 5 | **Two-arm walk** | Two rear-lateral arms alternate as stilts, body held 31 cm high and rocking; six arms rolled into helical coils under the body (camouflage as drifting algae or coconut shell). | Documented: Amphioctopus (Octopus) marginatus, Huffard, Boneka and Full 2005, Science 307. |
| 6 | **Rock clambering and gap squeeze** | Arm anchors are refused when the target is on a tall rock or behind one (line-of-sight to the ground); arms are pushed up over rock surfaces; the body rides the ground under its footprint. In a gap narrower than the mantle (9 cm and 7 cm gaps) the mantle width drops to 40-60% and its length grows so the volume stays constant; width is measured ahead of and behind the body. | Documented in general (octopus squeezes through any hole larger than its beak); the arm and body shapes are speculative. |
| 7 | **Land excursion** | Same crawl, but with a sag factor from the shore: the body sinks, the mantle flattens (volume kept), the swing lift and reach shrink, speed falls to 10 cm/s (16 cm/s scuttle), the arms drag. Starts in a tide pool. | Documented: Abdopus aculeatus walks between tide pools (Huffard 2006, J Exp Biol 209); sagging is our rendering of "heavy without water". |

Arms are the round-4 soft tubes (24 stations along the arm, 9 sides, taper to a fine tip, radius scaled by sqrt(rest length / current length) so volume is roughly conserved, no joints, bend anywhere, stretch 0.6-1.6x), now with parallel-transport frames (no twisting), a mottled skin texture, suckers as small spheres on the belly side, a web mesh between arm pairs, and a soft squashing mantle (muscular hydrostat idea: Kier and Smith 1985; Kier and Stella 2007 on octopus arm muscles). Swimming arms are a damped follow-the-leader chain pulled toward a rest shape (bundle, bell, fan, rudder, flare) so they lag, whip and trail.

## Self-check (`window.__stylesCheck`, `?test=1`, header button, or `node tools/gaitlab/octopus_check.cjs [name] [--table]`)
48 cells, 7 modes. Run 2026-11-22: **48 / 48 pass** (Node and browser identical), 25 s in the browser. Results are in `octopus/table.json`.
1. Attached suckers do not slide: the planted tip node stays on its anchor and the nodes of the 6.6 cm sucker patch stay on the fixed patch line (measured in the rendered nodes; limit 2 cm; worst 0.00 cm). Note this is by construction for the tip; the check proves the post-processing (ground push, smoothing) does not move it.
2. Nothing goes through rock or seafloor: all arm nodes (radius included), 28 mantle and head sample points and the prey sphere, limit 4 mm (worst 0.0 mm).
3. Mantle volume: crawl cells keep width x height x length at 1.00 exactly (limit 3%), including the gap squeeze (minimum width 40% and 48%). Jet cells: the cavity cycle is present (fill and squeeze range 1.0 of full, outer mantle width ratio 1.41) and water intake equals water expelled per cycle (limit 0.03).
4. Arms do not interpenetrate badly: neighbour arms, distal 70% of their length, a centreline closer than 0.35 x the sum of the two radii counts as bad; at most 25% of frames (worst 22.9%, slow circle; most cells under 15%). Overlaps are shallow and short but not zero.
5. Crawl, bipedal, land: arm stretch 0.5-1.6x (worst 1.59), at least 3 arms attached (bipedal 1), the body travels, the gap cells get through (x above 2.8 m), the slope is climbed. Jets exceed 0.3 m/s.

```sh
node tools/gaitlab/octopus_check.cjs
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/octopus_capture.cjs
```
The capture is SwiftShader only, flags any network request or page error, writes `page1..3_*.jpg` at a moment that shows each cell's movement (squeeze phase for jets, open umbrella for web pulses, inside the gap, over the slope, out of the water), single-cell close-ups with `OCTO_FOCUS=id,id`, `focus_cell.jpg`, `laptop.jpg`, and checks stars, one per row, persistence, copy, Space, Shift+Space, F/Esc, P, T and playback with real keys. `OCTO_FAST=1` skips the check and interactions.

## Weak cells and caveats
- **Jet and web arms are still too straight at high speed**: the bundle behind a burst reads as a lance with a few splayed tips, not a floppy bunch. The jet U-turn and the siphon-steered cells show the bank and the funnel but the arms barely react.
- **Web pulse, asymmetric web, tight web pivot, differential fins** look the same as their straight versions in a still; the turn comes only from the heading controller, not from asymmetric beats (speculative anyway).
- **Cirrate fins** are small ellipses; the bell and the fins read, the wave in the fins does not in stills.
- **Gap squeeze and tight squeeze** read best in the top-down camera (T); the default camera is almost top-down for these cells because the walls hide the body from the side. The gap is a pair of 50 cm walls; there is no ceiling, so it is a lateral squeeze only.
- **Land cells**: the water is one flat translucent plane; the sag is visible mainly as a low flat mantle.
- **Parachute pounce**: the prey is a small crab under the umbrella and is mostly hidden from the three-quarter camera; the wrap is arms pushed out of the prey sphere, not a true envelopment.
- **Arm skitter, tiptoe, low belly crawl, slow circle, jet + arm flare, double pulse, jet then brake** are speculative variations, labelled as such.
- Plankton, ghosts, ink, caustics and the water tint are decoration; the plankton box is relative to the animal, so they show relative flow, not a real current.
