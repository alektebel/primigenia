# Move-style picker, round 3 (brief `docs/briefs/move-styles-3.md`)

Open [styles3.html](../../../web/gaitlab/styles3.html) directly with `file://` (local three.js r128, no network). Round 2 is [styles2.md](styles2.md). **Awaiting owner choice; nothing here is approved or ported.** All numbers are starting values for the owner comparison, not measured animal data.

## What it shows
11 bodies, cycled with Space / Shift+Space. Each body has a 4x4 grid: rows are **walk (slow crawl for limbless), turn, fast, rough ground**; the four columns are four movement patterns for that body, each explained in its cell subtitle. 176 cells in all. Keys and controls as round 2: star one cell per row, Copy choices (`<body>: walk=<variant>; turn=...; fast=...; rough=...`, `crawl` instead of `walk` for limbless), localStorage in try/catch, **F** focus, **Esc**, **P** pause, 0.25x / 0.5x / 1x. **T** toggles top-down vs side / three-quarter camera. Limbless bodies start top-down (inchworm starts side-on, because its loops cannot be seen from above). Teal line = path of the body centre. Gold dots = legged touchdown points; on limbless bodies the **anchored (static) parts are tinted gold**.

Labels: legged cells print Hz, stride, Froude number, duty; limbless cells print Hz, wavelength (serpentine, eel) or step length, body lengths per second.

### A. Legged, other symmetries
| Body | Columns |
|---|---|
| radial 5 (starfish) | leading arm (arm 0 points forward with a short stance, four push); rotating lead (heading fixed, lead arm = the one nearest the path direction, highlighted); tube-foot glide (duty .84, half speed, low); cartwheel (rolling pentagon) |
| radial 8 (octopus) | two-arm bipedal walk (rear arms 135/225 degrees walk, six curled; Huffard, Boneka and Full 2005); all-arm ring crawl; jet-scoot hop (all arms push together, trail behind in the air); rolling (eight-spoke wheel) |
| trilateral (3 legs at 120 degrees) | tripod rotation (legs 0, 1/3, 2/3); lead-leg switch (heading fixed); spin-walk (body spins 1.3 rad/s while it walks any direction); tumble (rolling triangle) |
| two-headed mirror (head at both ends, 6 legs) | reverse without turning (path goes forward then backward along itself, no 150 degree turn; turn row retraces its arcs backwards); push-me-pull-you shuffle (front and rear legs in antiphase, hips breathe in length); hinge fold (body arches, legs in pairs); caterpillar wave (legs and body wave rear to front) |
| chiral helix (8 limbs, quarter turn apart) | screw-roll (body rolls about its long axis, limbs plant in turn); wave rear to front; wave front to rear; double wave |

### B. Limbless
| Body | Columns |
|---|---|
| snake | serpentine (follows the head track, pegs at the bend apexes); sidewinding (body across its motion, static patches); concertina; rectilinear |
| earthworm | peristalsis with 1, 2, 3 waves; burrow-dive (2 waves, front dives into soil and returns; ground translucent, buried nodes shaded) |
| inchworm | loop-step; fast looper (shallow loops, quick cadence); pole-vault flip (head lifts to 60 degrees on the tail clasper, then falls forward); deep loop |
| slug | direct pedal waves; retrograde pedal waves; loping (arching); five short direct waves |
| eel on land | wide S-wave; narrow fast S; side-flop crawl; coil and jump (explicit ballistic hop, floating allowed) |
| snake with two legs | legs assist (plant at bend apexes); legs lead (small wave); legs tucked (control); legs braced high |

## Engine (one code block `CORE_BEGIN..CORE_END`, also run by Node)
- **Legged:** round 2's path-first planner, generalised: hips on a ring or chain, rest points anywhere, body yaw independent of travel direction (`yaw = c1 * heading + c2 * t + c0`: follows, fixed, or spinning), per-leg duty, curled legs (never in contact), swing-time blend toward a trailing or radial pose, hip displacement (breathing, hinge, vertical wave), screw roll about the body axis. Feet are planted in world space at the pose of mid-stance and never move; stride is capped by a reach test that is exact for follow-heading bodies and conservative otherwise.
- **Wheels (cartwheel, tumble, rolling):** a rolling polygon. The stance spoke tip is planted at the hub's ground point, hub height is `sqrt(L^2 - d^2)` so the stance spoke is exactly straight and the next spoke lands exactly when the hub has travelled one polygon side (`2 L sin(pi/n)`); other spokes are the stance spoke rotated by `2 pi m / n`. Tips never slide.
- **Limbless:** every node sits on the path centre line at arc length `a_j`, plus a lateral offset. Serpentine and eel: `a_j` is the head track, lateral offset `A sin(2 pi a / lambda)`, so each node follows its predecessor (no side slip; measured below). Everything else is a **stair** model: node phase `g_j = phi - lag * p_j`, plateau fraction `beta`; a node is anchored while `frac(g) < beta` and then moves forward by one stride `D` with a cosine ease, so anchored nodes are exactly static along the path line, also on curves, because their path position is constant. The stride is tied to the path (`D = stride`), so the average speed is exactly the requested speed. Spacing between nodes is kept at most the rest spacing (`cb = 1 - (stairMax - 1) * D * lag / L`); the concertina zig-zag and the peristalsis radius (`r ~ 1/sqrt(spacing)`, volume conserved) are derived from the spacing. Loopers use a circular-arc body of length L between two clasper points (head anchored while the tail comes forward, then the reverse).
- **Rough ground** is a smooth height field (amplitude 0.4 hip heights for legged bodies, 0.06 body lengths for limbless, slope under 12 degrees). Feet plant on it, bodies ride it, pegs sit on it.
- **Turn row:** radius 3 body lengths (nose to tail), arcs of 120 degrees with a straight in between and a 150 degree sharp turn at radius 1 body length (the "A42 lean" plan of round 2); the mirror reverse variant retraces its arcs backwards instead.

## Physics rules (what the page enforces, with the biology behind it)
1. **Serpentine needs lateral push points.** A snake with no pegs, rocks or ground roughness only slides forward (friction is anisotropic: low along the body, high across it). The body pushes on the outer sides of its bends, so every node must follow the track of the one in front. The page shows pegs at the apex of each bend and checks that the lateral slip of every node against the body tangent stays below 0.15 (measured 0.00 to 0.02). Gray 1946, J Exp Biol 23:101; Gray and Lissmann 1950, J Exp Biol 26:354.
2. **Sidewinding lifts body sections; only static contact patches touch the ground.** The body moves roughly across its own axis. Each node is anchored (static) while on the ground and lifted while it moves to its next patch. Jayne 1986, Copeia; Marvi et al. 2014, Science 346:224 (sidewinding with minimal slip).
3. **Concertina anchors and extends.** The rear anchors in tight bends while the front extends, then the front anchors and the rear is pulled up. The anchored bends are static; spacing in the bunched part is shorter than the rest spacing and its lateral amplitude follows from arc-length conservation. Gans 1962, Am Zool 2:167.
4. **Peristalsis needs anchors.** Short, fat segments are anchored by setae (static), long thin segments move; the contraction wave runs backward along the body while the body moves forward. Quillin 1999, J Exp Biol 202:661.
5. **Rectilinear locomotion** moves belly scales in anchored and lifted waves with a straight body (Lissmann 1950, J Exp Biol 26:368, from memory).
6. **Pedal waves (slug):** sole between waves adheres (static); direct waves run the same way as the animal, retrograde waves against it. Lai et al. 2010, J Exp Biol 213:3920.
7. **Looper:** two clasper contact points, one stays anchored while the other moves; they never move together (van Griethuijsen and Trimmer 2014, Biol Rev 89:656, from memory).
8. **Octopus bipedal walk:** two arms walk, the others are held curled (Huffard, Boneka and Full 2005, Science 307:1927).
9. **Starfish, trilateral and chiral bodies, jet-scoot and the eel flop/jump are design variations** with no animal measurement behind the numbers (the eel jump is loosely modelled on mudskipper tail-flips, Swanson and Gibb 2004). They are marked starting values.
10. **A static contact point must not slide.** Every foot, anchored node and wheel spoke tip is held at its planted position; the check measures it.
Citations are from memory and have not been re-read; check before quoting.

## Self-check (`window.__stylesCheck`, `?test=1`, or the header button)
Node runs the **same inline code**: `node tools/gaitlab/styles3_check.cjs [body] [--table]`. Every body x row x variant (11 x 4 x 4 = 176 cases): 2 s settling and 4 s measured for straight rows (240 Hz), up to 8 s settling and one full period for the turn row (120 Hz). Per case it asserts:
- static contact drift < 2 cm (legged feet vs plant, anchored nodes vs their start position, wheel spoke tips); measured 0.00 cm for limbless and legged bodies except concertina 0.06 cm;
- nothing below ground (feet, knees, nodes; burrow-dive nodes are allowed below the surface by exactly their dive depth);
- no floating: some foot or body part touches the ground in every frame unless the style has an explicit hop (jet-scoot, eel jump); measured air fraction equals the analytic value;
- no reversed knees, no IK clamps (legged and hybrid legs); no same-side feet crossing (mirror body);
- limbless: lateral slip along the track below 0.15 and no segment length error above 0.7 of its rest length (peristalsis and concertina compress on purpose, up to 0.63);
- turn row: radius of each 120 degree arc equals R within 3% (circumradius of the path), each sharp turn at least 145 degrees.

Run 2026-11-22: **PASS, 176/176 cases** (browser capture and Node). Evidence: `styles3/table.json` (per-case Hz, stride, drift, air, segment error, lateral slip, radii), one JPG per body `styles3/grid_<body>.jpg`, `top_radial5.jpg` (legged, top-down), `side_snake.jpg` (limbless, side view), `focus_cell.jpg`, `laptop.jpg`.

```sh
node tools/gaitlab/styles3_check.cjs
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/styles3_capture.cjs
```
Capture is SwiftShader only, `file://`, flags a network request as an error, and checks stars, one-per-row, persistence, copy, Space, Shift+Space, F/Esc, P, T and playback with real keys and clicks.

## Round-2 bug: "longer-lower" on the asymmetric three-legged body (fixed in styles2.html)
**Cause.** The lowering floor kept the hips above half the length of the *shortest* leg (`Math.min` over the legs). The three-legged oddity has legs of 0.47, 0.58 and 0.85 m, so the floor (about 0.47 of hip height) let the hips drop to 0.36 m, at which the 0.85 m leg was folded to 38% of its length (it is already at 48% in the plain A42 style because all hips share one height). The knee then popped about 10 cm above the hip, which reads as a bug. For symmetric bodies min and max are equal, so only asymmetric bodies were hit.
**Fix.** The floor now uses the *longest* leg (`Math.max`): `.5 * max(a+b) / (h * hs)`. On the three-legged body the lowered height is 0.85 instead of 0.72, minimum leg extension rises from 0.38 to 0.46 and the knee stays within 4 cm of the hip line. The stride gain for this body stays small (about 14%) because the reach cap is set by its shortest legs, the same cap described under known weak spots of round 2. `styles2_check.cjs` still passes 240/240.

## Known weak spots
- **Slug:** from above the pedal ripple is hidden under the dorsal body (made translucent); the ripple reads best in the footfall strip and the gold sole patches. Speeds are very low by design.
- **Eel flop crawl and jump:** from the top-down default the flop is a slightly curved bar and the jump is only a coil; both read better with T (side view). The flop is also the least biological variant.
- **Sidewinding** from above shows a long S-shaped bar rather than the lifted arches; the lift is only visible from the side (`side_snake.jpg`).
- **Starfish:** arms are two-link legs with a knee, so it reads as a spider from the side; top-down it reads as a starfish.
- **Octopus two-arm walk:** the six curled arms are held up like a crown; the two walking arms overlap in the side view.
- **Chiral wave variants:** the three wave columns look alike in a still image; the difference is the direction of the footfall wave (see the strips).
- **Hybrid snake with legs:** the legs are small crosses behind the head; the four columns differ mostly in body wave amplitude and stride.
- Several numbers sit at the edge of what the geometry allows (segment compression 0.63 in peristalsis, concertina 0.47).
