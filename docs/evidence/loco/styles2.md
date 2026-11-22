# Move-style picker, round 2 (brief `docs/briefs/move-styles-2.md`)

Open [styles2.html](../../../web/gaitlab/styles2.html) directly with `file://` (local three.js r128, no network). Round 1 is [styles.md](styles.md); the gait-lab rules are [gaitlab.md](gaitlab.md). **Awaiting owner choice; nothing here is approved or ported.** All numbers are starting values for the owner comparison, not measured animal data.

## What it shows
15 bodies, cycled with Space / Shift+Space. Each body gets a 4x4 grid: rows are **walk, turn, canter, gallop**, columns are four variants. Every cell is labelled with live Hz, stride, Froude number and duty factor, the gait name, the adaptation rule, and a footfall strip (two strides, one row per foot, black = down). Gold dots are touchdowns. Click a cell to star it (one star per row per body; click again to clear). "Copy choices" copies one line per body, `<body>: walk=<variant>; turn=<variant>; canter=<variant>; gallop=<variant>` (unstarred rows print `-`), with a selected-textarea fallback. Choices persist in `localStorage` (every access in try/catch). Keys: **F** focus the hovered cell, **Esc** back, **P** pause, **T** turn-row camera (3/4 or straight down), 0.25x / 0.5x / 1x playback.

Bodies: starter B, hatchling, starters A, C, D (leg lengths and node profile from `godot/game/data/`, as round 1), heavy quadruped, small fast quadruped, sprawling lizard, long-necked quadruped, tall biped, hopping biped, hexapod, octopod, centipede (14 legs), three-legged oddity (one long leg).

Camera: side orthographic for walk/canter/gallop (higher elevation for sprawlers and many-legged bodies so the leg splay shows). The turn row uses a high 3/4 view by default (T for top-down); a teal trail shows the last ten seconds of path, so the arc and the foot placement read together.

## Engine (shared with the check, one code block `CORE_BEGIN..CORE_END`)
- **Speeds are Froude scaled:** `v = sqrt(Fr g h)`, `h` = mean hip height. Default `Fr = 0.66 / 1.6 / 3.2` for walk / canter / gallop (starter B: 2.0 / 3.1 / 4.4 m/s, so B's walk is the owner's 2 m/s). Per-body overrides: heavy 0.30 / 0.6 / 1.0, lizard 0.45 / 1.0 / 1.8, long-necked 0.55 / 1.2 / 2.2, hexapod 0.5 / 1.2 / 2.4, octopod 0.4 / 0.9 / 1.6, centipede 0.4 / 0.8 / 1.4, three-legged 0.4 / 0.8 / 1.3.
- **Path first, feet second.** Each cell has a deterministic path (straight line, or the turn plan below). The foot planner, per leg and per cycle, plants the foot at the leg's body-frame rest point evaluated at the pose of mid-stance (found from the gait phase by an exact inverse), then pins it. Swing goes from the old plant to the next plant with a cosine ease and a sine lift. Stance feet never move; outer legs on an arc take longer steps and pivots step around on the spot without any special case.
- **Cadence = effective speed / stride**, where effective speed is the fastest foot rest point's speed (so pivots keep a cadence), floored at 15% of the row speed so the gait phase never stalls.
- **Stride law:** A42-derived columns use round 1's law `2.3 min(Fr,.65)^.3 h k`; the Froude default column uses the gait-lab rules (`2.3 Fr^.3 h` walk/trot with Fr clamped at .5 for walk, `1.9 Fr^.4 h` gallop, Fr capped at 6). Strides are capped by leg reach (stance travel at most 1.85 x the leg's half-span at the standing height) and by same-side neighbour crossing.
- Body: hips are lowered (never a planted foot moved) until every foot is in reach; roll toward loaded side, pitch rock, spine wave, tail counter-rotation, head counter-rotation; bob follows stance support in flight gaits, a sine otherwise.

## A42 port presets (column 1)
Offsets are in stride cycles; quads list LH, RH, LF, RF. `k` multiplies the stride law.

| Body plan | Walk | Canter | Gallop |
|---|---|---|---|
| quad | diagonal sprawl walk: `0,.5,.75,.25`, duty .70, k .95, height .64, spine .16, wide feet | canter: `0,.32,.32,.66`, duty .29, k 1.35, bob .07 | rotary gallop: `0,.12,.62,.5`, duty .25, k 1.55, bob .10 |
| biped | bird walk: alternate, duty .62, head pump | bird run, duty .40, flight | fast run, duty .30, lean .2 rad |
| hop | gather-hop shuffle: feet .06 apart, duty .56 | hop, feet .03 apart, duty .46 | long hop, feet together, duty .36 |
| hexapod | low tripod, duty .66, height .8 | fast tripod, duty .54 | sprint tripod, duty .50 |
| octopod | metachronal wave, lag .12, duty .68 | quick wave, lag .10, duty .60 | fast wave, lag .085, duty .56 |
| centipede | body wave, lag .075, duty .70, spine wave .12 | lag .06, duty .62 | lag .05, duty .56 |
| three-legged | lurching tripod: `0,.37,.72`, duty .62, roll .08, head .08 | scramble, duty .50 | hurried hobble, duty .42 |

## Variant columns
- **A42 port:** the table above after the body rules below.
- **Longer and lower:** `k x 1.25`, height `x .80` (never below half the shortest leg's length), bob `x .8`, lift `x .9`. Cadence falls because stride grows at the same speed. When the reach cap binds (starter B walk) the stride gain is smaller than 25%.
- **Bouncier:** bob `x 1.9 + .01`, lift `x 1.5`, duty `-.07` (never below .5 for walkers that must stay grounded), rock `x 1.5`, pitch `x 1.3`, roll `x 1.2`. In the gaits that already have flight this lengthens the air phase.
- **Froude default:** the gait-lab ladder for that row's Fr, no owner style: quad walk = lateral sequence `RH 0, RF .25, LH .5, LF .75`, duty `.78 - .46 min(Fr,.5)`; trot `0,.5,.5,0`, duty `.48 (Fr/.5)^-.25`; gallop `0,.1,.5,.6`, duty `.32 (Fr/2.5)^-.3`; biped walk/run with duty `.48 (Fr/.5)^-.3`; hexapod tripod duty `.62 - .05 Fr`; octopod and centipede metachronal wave, duty `.7 - .08 log10(Fr/.05)`, lag `.22 (Fr/.05)^-.23` (min .08). Row mapping: walk row = walk, canter row = trot, gallop row = gallop.

## Turn row
Radius is **3 body lengths** (nose to tail root, `bodyLen`), speed is the walk speed. The path repeats: left arc 120 degrees at R, 0.8 BL straight, a **150 degree sharp turn** to the right, right arc 120 degrees, 0.8 BL straight, sharp turn to the left.

| Variant | Gait | Sharp turn | Body language |
|---|---|---|---|
| A42 lean | A42 walk | arc R = 1 BL, slowing to .6 v | banks into the turn (`atan`-like, `0.8 v w / g`), spine bends along the curve, head yaws ahead of the body; outside legs take longer steps because rest points sit further out |
| wide arc | A42 walk | arc R = 2 BL at full speed, never stops | none |
| stop-and-pivot | A42 walk | decelerate 0.9 s, pivot in place at `w = .28 sqrt(g/h)` (clamped .6 to 3 rad/s) with half-second ramps, accelerate | feet step around the body with real placement (no sliding) |
| Froude default | gait-lab walk | arc R = 1.2 BL, slowing to .75 v | none |

## Per-body gait adaptation rules
1. **Quadrupeds** use the quad table. **Columnar-legged bodies** (heavy, long-necked, tall biped) do not sprawl: the A42 walk becomes a diagonal walk at height .92, spine .03, feet not widened.
2. **Heavy quadruped:** no flight anywhere (duty floor .5). Canter = heavy amble (`0,.5,.18,.68`, duty .62), gallop = heavy fast rack (duty .54). Froude default stays a walk-law gait.
3. **Small fast quadruped:** gallop is a bound (`0,.06,.5,.56`, duty .28) with 1.7x spine flex; every row has 1.7x spine amplitude.
4. **Sprawling lizard:** no flight. Walk = salamander wiggle (spine .28), canter = scurry (duty .6, spine .3), gallop = fast scurry (duty .52). Pole is outward and up.
5. **Long-necked:** quad table; head sway x3 so the neck reads; hips and legs stay upright.
6. **Biped (bird):** canter and gallop mean a run: alternating legs, duty below .5, flight, forward lean up to .2 rad. Head pumps at twice the stride frequency.
7. **Hopping biped:** never alternates. All rows are hops (feet 0 to .06 cycle apart); faster = longer hop, lower duty, more bob and rock. The Froude default column does alternate (the lab's biped), which shows what the style changes.
8. **Hexapod:** canter and gallop mean a **faster tripod** (duty .54, .50), not a mammal gallop; duty never below .5, so no flight even when bouncier.
9. **Octopod:** a **faster metachronal wave** (lag .12, .10, .085; duty .68, .60, .56).
10. **Centipede (14 legs):** a **faster wave** (lag .075, .06, .05); the body's spine wave uses the same phase gradient as the legs, so crests travel with the stepping wave.
11. **Three-legged:** gait is a clumsy tripod with offsets `0,.37,.72` (never a gap of more than a third of a cycle), extra roll, head sway and an irregular bob (`lurch`). Faster means a quicker scramble and hobble, never a stop. Always at least one foot down.
12. Many-legged bodies get the same crossing cap as the gait lab: stance travel is limited so grounded neighbours never swap order; this is why their relative stride sits below the Alexander law.

## Self-check (`window.__stylesCheck`, `?test=1`, or the header button)
Node runs the **same inline code**: `node tools/gaitlab/styles2_check.cjs [body] [--table]`. Every body x row x variant (15 x 4 x 4 = 240 cases): 2 s of settling and 4 s measured for straight rows, one settled period plus one full period for the turn row, at 240 Hz. Per case it asserts:

- stance foot drift (distance of the IK foot from its plant, and frame to frame) **< 2 cm** (measured 0.00 cm everywhere: planted feet are pinned in world space and no IK clamp occurs);
- no reversed knees (knee on the pole side every frame), no joint below ground, zero IK reach clamps;
- no floating: some foot down in every frame unless the gait has flight; measured air fraction equals the analytic value from offsets and duty (+-.03);
- no same-side feet crossing (straight rows);
- turn row: the radius of each 120 degree arc, from the path (circumradius of three points), equals R within 3%; each sharp turn turns at least 145 degrees (measured about 150); stop-and-pivot drifts under 0.15 body lengths in place.

Run 2026-11-22: **PASS, 240/240 cases**; also checked in the browser capture. Evidence: `styles2/table.json` (per-case duty, air fraction, slip, radii, sharp-turn angles), one JPG per body `styles2/grid_<body>.jpg`, `turn_topdown_starter_B.jpg`, `focus_cell.jpg`, `laptop.jpg`.

```sh
node tools/gaitlab/styles2_check.cjs
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/styles2_capture.cjs .
```
Capture is SwiftShader only (`--use-angle=swiftshader --enable-unsafe-swiftshader`), `file://`, flags a network request as an error, and checks stars, one-per-row, persistence, copy, Space, Shift+Space, F/Esc, P, T and playback with real keys and clicks.

## Known weak spots
- **Starter B walk cadence is 1.5 to 1.7 Hz at 2 m/s, not the briefed 0.8 to 1.0 Hz.** B's leg is 0.67 m, so the largest stance travel its reach allows (about 0.85 m at the sprawl height) gives a stride of roughly 1.2 to 1.35 m at duty .70. A 2 to 2.5 m stride would need a leg about twice as long, a duty near .35, or a speed near 1 m/s. Not hidden: the cell shows the real Hz. "Longer and lower" gains only about 10% there for the same reason; for longer-legged bodies (heavy 0.8 Hz, tall biped 1.3 Hz) the gain is the full 25%.
- Sprawling lizard and centipede: the splay is nearly invisible from the side (higher elevation helps; the turn row reads best). Lizard legs are very short next to the body.
- Hopping biped: the flight-heavy hop in the 3/4 turn view is cluttered, and in the pivot cell a hopper "pivots" while in the air between landings.
- Three-legged oddity: reads as a blob on stilts; the long leg is deeply folded (it is the least believable limb), though it always steps and is never blocked.
- Starter bodies keep round 1's balls-on-a-string profile; no cosmetic change was attempted.
