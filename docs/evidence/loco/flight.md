# Flight-style picker (owner 2026-11-22: "I want to debug flying movement patterns. Let's make the same exercise")

Open [flight.html](../../../web/gaitlab/flight.html) directly with `file://` (local three.js r128, no network). Same shell as the move-style rounds ([styles4.md](styles4.md)): **Space / Shift+Space** next / previous body, **G** other page of the same body, click a cell to star it (one star per row), **Copy choices** gives `<body>: <row>=<variant>; ...`, **F** focus the hovered cell, **Esc**, **P** pause, 0.25x / 0.5x / 1x, **T** cycles the camera (close three-quarter = default, close chase, close side, wide), each cell has a side-profile mini-map of the whole path. Choices persist in `localStorage` (read and written inside try/catch). **Awaiting owner choice; nothing here is approved or ported.** All numbers are lab starting values, not measured animal data.

Evidence: `docs/evidence/loco/flight/` (one JPG per page, `table.json` with every cell's outcome, `focus_cell.jpg`, `laptop.jpg`). Tools: `tools/gaitlab/flight_capture.cjs` (SwiftShader only), `tools/gaitlab/flight_check.cjs` (the same engine and assertions in Node, `--table` prints every cell).

## What each cell shows
Every cell runs one scripted pilot over a point-mass flight model that copies `godot/game/player/flight_test.gd`: lift `L = 1/2 rho V^2 S CL`, drag `CD = CD0 + k CL^2` with `k = 1/(pi e AR)` and `CD0` from the best L/D (so the polar's best glide ratio is exact), `CL_MAX`, a banked lift vector (`tan(bank) = v w / g` falls out of the dynamics, it is not scripted), a stall that cuts the lift, flap thrust `T = eta P / V` limited by an actuator-disk static thrust, a burst power of 2x with a stamina drain, and the dive fold to 40 % of the area. What the lab adds: a ground model (run, leap, touchdown, skid, tumble), ground effect, wind, thermals, ridge lift, gusts, a perch capture and a carried load. Whatever the physics gives is what is shown: a body that cannot do a variant fails in a believable way (stall, hop, tumble, blown back) and is never blocked.

Each cell prints: beat rate (Hz, and "(slowed)" for insects), wing loading N/m2, wing area, speed against stall speed, stroke amplitude in degrees, the measured glide ratio when the wings are not beating (against the spec value), state (AIR, HOVER, STALL, GROUND, TUMBLE, PERCHED), altitude and flap power. Teal dotted line = path of the body, gold line = wingtip of the right wing (ghost trail, about 2 s), dark disc = shadow on the ground (its size and darkness read altitude). Grid squares are `grid` metres (1 m for the bird, 2 m for starter B, 2 cm for the fly), the trees are a size reference (9 m for starter B, 6 m bird, 0.5 m fly).

Mechanics shown, all in the shared pose code (`wingGrid`, `legPose`, `updateRig`):
- Downstroke is 58 % of the beat (the game's `DOWNSTROKE`), upstroke recovery flexes the wrist, shortens the span and, for feathers, opens the vane (the wing turns more transparent and the shafts show). Bats flex deepest (1.35 rad of wrist sweep, 22 % camber, membrane between four finger rays). Insect wings are rigid with a supination twist at the stroke reversals and ghost copies for blur.
- Spanwise phase lag (tip follows the root), so the wing is a travelling wave, not a rigid board.
- Body bob opposite the wingbeat (body rises as the wings go down), head counter-rotates the body (gaze stabilisation, 85 % of the roll cancelled), legs tucked in cruise and extended and swung forward in the flare, tail fan spreads in the flare and yaws as a rudder.
- Stance feet are phase-locked to the ground speed, so a planted foot does not slide (run, run-out); after a stop both groups end in stance.
- Hover tilts the stroke plane towards horizontal (insects start at 45-70 % horizontal and go figure-8).

## Bodies, rows and variants
10 bodies x 2 pages x 4 rows x 4 variants = 320 cells. Page 1 = takeoff, cruise, turn, landing. Page 2 = hover, glide / soar, dive, rough air / load.

| Body | Mass | Span | Wing area | Loading | Stall | Beat (m^-1/3) | L/D | Hover power |
|---|---|---|---|---|---|---|---|---|
| starter B + wing_vane | 36 kg | 5.3 m | 2.7 m2 | 131 N/m2 | 11.9 m/s | 1.5 Hz (game m^-1/6: 2.5) | 11 | no |
| hatchling + wing_vane | 30 kg | 4.3 m | 2.05 m2 | 144 N/m2 | 12.5 m/s | 1.5 Hz (game: 2.6) | 11 | no |
| bird-like (kestrel) | 0.3 kg | 0.72 m | 0.075 m2 | 39 N/m2 | 6.0 m/s | 7.2 Hz | 10 | burst only |
| bat-like (fruit bat) | 0.12 kg | 0.55 m | 0.045 m2 | 26 N/m2 | 4.6 m/s | 8.7 Hz | 7 | burst only |
| insect 2 wings (fly) | 12 mg | 14.5 mm | 28 mm2 | 4.2 N/m2 | 2.1 m/s | 210 Hz (drawn at 16) | 2.5 | sustained |
| insect 4 wings (dragonfly) | 0.8 g | 9 cm | 16 cm2 | 4.9 N/m2 | 2.2 m/s | 24 Hz (drawn at 12) | 6 | sustained |
| beetle | 1.2 g | 5 cm | 6 cm2 | 20 N/m2 | 4.8 m/s | 38 Hz (drawn at 12) | 3.5 | burst only |
| pterosaur-like | 25 kg | 5.6 m | 3.9 m2 | 63 N/m2 | 8.0 m/s | 1.4 Hz | 14 | no |
| membrane glider | 0.13 kg | 0.3 m | 0.04 m2 | 32 N/m2 | 6.1 m/s | no beat | 2.6 | no |
| heavy, small wings | 30 kg | 3.0 m | 1.2 m2 | 245 N/m2 | 16.9 m/s | 1.3 Hz | 6 | no |

Variants (the same four for every body except where noted; a variant the body cannot do shows the failure):

| Row | Variants |
|---|---|
| Takeoff | running takeoff; standing leap + downstroke; vertical hover-takeoff; cliff drop. Bat: quad vault replaces the leap. Pterosaur: quad vault replaces the leap, order run / vault / cliff / vertical. Glider: run, leap, tree-trunk leap, cliff (branch). |
| Cruise | continuous flapping; flap-glide; flap-bound (wings folded between bursts); soaring with rare flaps. Glider: best glide, slow min-sink glide, fast steep glide, "flap" (limbs flail, no thrust). |
| Turn | banked coordinated turn (40 deg); flat yaw turn (tail and feet, no roll); wingover; tight pivot with asymmetric beats. |
| Landing | flare + stall touchdown; running landing; perch grab; crash-tumble. |
| Hover | true hover; wind hover (headwind equal to the stall speed, capped at 12 m/s); ground-effect flutter hop; slow down and stall. |
| Glide / soar | thermal circling; straight best glide; min-sink circling in still air; ridge soaring. |
| Dive | stoop (folded to 12 %); shallow glide dive (45 % fold, 25 deg); powered dive; fold, drop, open late. |
| Rough / load | light gusts (0.18 vs); strong gusts (0.42 vs); carry prey 30 % of the mass; carry prey 100 %. |

## Self-check (`window.__stylesCheck`, `?test=1`, `Run self-check`, and in Node)
Result 2026-11-22: **PASS, 320/320 cases** (3 s in Node). Per cell it asserts:
- no wing vertex inside the torso ellipsoid after collision resolution, and the resolution itself stays small (the body pushes a wing out by at most 60 % of its half width, the ground lifts one by at most 80 % of its length); no wing vertex below the ground in air, run and stand states;
- takeoff: the body leaves the ground in every takeoff cell (a hop counts, flying away is reported separately in the outcome line); landing: it touches down, the feet never go below the ground (2 mm), and after it comes to rest it drifts less than 2 cm (measured 0.0 mm, planted feet);
- banked turns (turn / bank, thermal circling, min-sink circling): 80th percentile of |displayed bank - atan(v w / (g + a_y))| below 10 deg, with w measured from the real heading change over 0.25 s (steady roll only);
- hover: the body whose actuator-disk power allows it (`B.hoverBurst`) holds altitude (mean |vy| under 0.6 m/s, drop under 30 %); a body that cannot must sink, stall or lose more than 40 % of the height in the hold window;
- glide ratio: best-glide cells within -22 / +10 % of the polar at the best-glide speed, and no cell ever beats the polar by more than 15 %;
- head stabilisation (residual under 20 % of the body roll), no NaN, speed under 3.5 x max(vne, cruise).

## Scaling rules
- Wingbeat `f = c m^(-1/3)` with c = 4.8 for feathered wings and bats (4.3), 4.0 for the pterosaur and heavy body, 2.2 for the dragonfly, 4.0 for the beetle. Geometric similarity gives -1/3; Pennycuick 1996 (Bird Flight Performance) fits `f ~ m^(3/8) b^(-23/24) S^(-1/3)` for birds. **Unchecked, from memory.** Both the housefly (about 200 Hz at 12 mg) and a pigeon (6-7 Hz at 0.4 kg) land close with c = 4.8; the dragonfly and beetle needed their own c. The game's `LocoWing.beat_hz` uses `4.5 m^-1/6` (2.5 Hz at 36 kg); the lab shows both for the starters.
- Hover power: induced power of an actuator disk `P = fp T^1.5 / sqrt(2 rho A_d)` with `fp` = 2.0 for vertebrates and 1.5 for insects (profile and losses), `A_d` = swept area of the stroke. Available power = `muscle * m * 150 W` as in `flight_test.gd`, x2 for burst (game: stamina drains about 12 s). Reality check: the kestrel and the fruit bat hover on burst only, the fly and dragonfly sustain it, the 25 kg pterosaur and both starters cannot, which matches what such animals do.
- Visual beat rate: above 9 Hz the drawn rate is `9 + 1.5 log2(f / 9)` so a 60 Hz screen does not alias, and insects get four ghost wings per wing. The physics uses the true average thrust, not the beat.
- Camera: the close views frame 2.5 body spans of height centred on the body (creature about 40 % of the cell width); the wide view keeps the old 2.2-4.4 span framing with the ground in shot.

## Documented biology vs speculative
Documented (qualitatively): upstroke wrist flexion and feather opening in birds; deep flexible bat stroke with an inflated membrane on the downstroke; figure-8 insect stroke with supination at reversals and hover with a near-horizontal stroke plane; dragonfly fore / hind wings beating out of phase (0.5 in forward flight, about 0.25 in hover); beetle elytra opening before the hindwings unfold; intermittent flap-glide and flap-bound flight (Rayner 1977 and later); wind or kestrel hover; flare with legs forward, tail spread and a stalled touchdown; perch landings that trade speed for height below the perch; flying squirrels launching from trunks and gliding at L/D about 2 to 3; thermal and ridge soaring; wingover; the g limit on a stoop pull-up; ground effect near the wing span height. Pterosaur quadrupedal vault launch (Habib 2008, from memory).
Speculative or simplified: every number (masses, spans, areas, muscle shares, L/D, clmax, run speeds, leap speeds, g limits, tolerated sink rates at touchdown); the pterosaur's soaring and its 25 kg size; the heavy creature's wing area; flies and beetles in steady-lift terms (their lift is mostly unsteady, the lab uses an actuator disk with a `clmax x 2` boost while flapping); crash and tumble outcome thresholds; carrying and dropping prey; the exact 40 degree bank of the banked turn; the 12 m/s wind cap; wings as a sheared planform parallel to the body axis (a rendering simplification, the trailing edge stays outboard).

## What the lab says about the player case (starter B with wing_vane)
Assumed wing: `wing_vane` family (L/D 11, e 0.8, stroke 70-110 deg, muscle 0.18 as in `flyer.json`), span 2.4 m a side, breadth 0.3, area = span x chord x 0.78, mass 36 kg. These are assumptions: the real `wing_info` comes from the mesh at runtime; put the real `area`, `span`, mass into `BODY_DEFS` to re-run. With them (`table.json`):
- running takeoff: flies. About 2.3 s of burst flapping and 20 m of run, lift-off at 8.5 m/s (flap thrust carries part of the weight), a skimming phase of 3 s over the ground while it picks up speed to 12-13 m/s, then a climb; the game's `takeoff()` instead teleports into the flight state at 1.15 x stall speed. The lab cost is the honest number to compare against.
- standing leap and vertical takeoff: hops 0.4-2.4 m and lands; vertical thrust is 81 % of the weight even at burst, so it cannot hover or lift off straight up. It does not hover (power 970 W against 2.7 kW); wind hover works only in a 12 m/s wind.
- cliff drop: pulls out and flies on; the lab sizes the cliff to 20 m (2.1 x the speed-gain height plus body lengths); a lower cliff ends in a crash.
- landing at 12-16 m/s runs out 9-13 m on legs (brake 0.5 g); crash variant tumbles.
- soaring: wing loading 131 N/m2 and L/D 11 give 1.2-1.5 m/s sink at the circling speed; in the 2.4 m/s thermal the pilot circles at the 35 deg bank radius (about 27 m) and roughly holds height instead of a clear climb, because its centring is crude (a better thermalling controller or a wider thermal is needed to show the climb).
The hatchling (30 kg, area 2.05 m2) is about the same: run takeoff works but needs a longer run, a 12 m/s wind is below its stall speed so wind hover shows "blown back".

## Weakest cells (known, flagged for the owner)
- Perch grab on bats and the heavy body, carry prey on bats, glider carry rows (no talons: the prey is "dropped"), and the glider hover row: the physics runs but the scripted pilot does not recover, the outcome line says what happened. These look like failures because they are.
- Insect landing and perch approaches use a slow vertical-speed controller; they take 5-8 s and look drifty. Their dive row mostly shows a drop and recovery.
- Wing flexion is a two-segment lever with spanwise lag and camber, not a real finger skeleton; bat and pterosaur wings have rays and a thicker leading edge, birds have shafts, the glider patagium only curls. Wing sections are flat.
- Beetle elytra are two plain shells; the hindwing fold (the Z-fold under the shells) is just a shortened span.
- Ground-contact wing clamping (the ground pushes a wing up) is a projection, so a drooping wing on the ground bends instead of resting; checked to stay under 80 % of the wing length.
- The flap thrust is an average: there is no within-beat force, so the bob and the pitch oscillation are drawn from the wing phase and are not simulated.
- Dive row stills show small animals because the dive starts high (8 spans plus the fall height) so the pull-up has room.

## Notes for porting to the game's `flight_mode.gd`
- The lab model is `flight_test.gd` with three additions that need decisions before porting: (1) a thrust vector that rotates from vertical (hover, `mixUp = 1`) to along the velocity (`mixUp` = 1.05 - V / (0.95 vs)) so flapping near zero speed lifts instead of pushing along a velocity of zero; (2) `T = 1 / (1/T_static + (1 - mixUp) V / (eta P))` with `T_static = (P / fp)^(2/3) (2 rho A_d)^(1/3)`: the game has no static thrust, so it can neither hover nor take off from rest; (3) a ground phase (run speed cap from the legs, wing-thrust-assisted run, lift-off when `L + T mixUp > m g`) instead of `takeoff()`. All three use only + - * / sqrt and `pow` (two-thirds), so they port to C with a fixed-point cube root.
- Beat rate: the game's `4.5 m^-1/6` gives 2.5 Hz at 36 kg where `m^-1/3` gives 1.5 Hz (1.7x faster), and about 3.7 Hz against 6.5 Hz for a 0.4 kg bird; the lab uses `-1/3` as requested. Decide, then use one law in `LocoWing`.
- The wing pose (`wingGrid`) uses the game's constants (downstroke 0.58, stroke 70-110 deg, retract 0.25, dive sweep 1.15, glide dihedral 0.20, flare cup 0.45) and the same eased channels (`ampE`, `foldE`, `diveE`, `flareE`, `hovE`) the game's `LocoWing` has. Porting means replacing its hinge-only sails by the spanwise chain, and adding the wrist flexion and the lag.
- The self-check inputs map onto `flight_mode.gd`'s keys: Space tap = one beat, hold = flap, Ctrl = dive, S / W = pitch, A / D = roll. The lab's pilot variants are the proposed automatic behaviours for the AI and for flight assistance (flap-glide when fast enough, auto flare near the ground, perch capture, thermal circling).
- Bank is derived, not stored: keep `phi = atan(v w / g)` as the displayed roll and let the lift tilt do the turn, as the game already does (`ROLL_RATE_T`, `ROLL_TAU`).
- The takeoff takes seconds and tens of metres for starter B: either keep the game's teleport takeoff for the starter (and use the lab for wild fliers) or add a short run-up to `flight_mode`.

## Ported (branch anim/flight-port, 2026-11-23, A56 / A57)
The owner's picks are in the game's flight (`godot/game/player/flight_test.gd`, `flight_mode.gd`, `locomotion/loco_wing.gd`, `actors/actor_driver.gd`); all Godot-side, no C change, takeoff untouched (Space on the ground).
- **Cruise = flap-glide** (default): hold Space; the wings burst while the body is under 1.07 x cruise speed and rest above it, hysteresis down to 0.93 x (cruise = 1.3 stall speeds; lab 1.34). While gated the flight-path damping is stiffer (CL 0.12 per m/s of climb), so a burst turns into speed, not a climb, and the body holds its height hands-off. Starter B-like body: bursts of about 1.2 s every 3 s (duty 0.4), stamina lasts about 30 s against 12 s of continuous flapping. A tap is one beat, the climb-out after takeoff and the last 1.5 body lengths are never gated. Console `fly cruise continuous` restores hold = flap.
- **Turn = wingover**: double-tap A or D (within 0.35 s) with at least 1.2 x stall speed and 12 m of height (0.085 x vs^2 + 2 body lengths). Phases: dive in at -17 degrees flapping until 1.85 x stall, zoom pull-up at 0.92 CL_MAX until 1.45 x stall or 54 degrees, roll to 85 degrees (angular rate 2.2 rad/s through a lag, no overshoot) until 150 degrees of heading change, roll out, dive away and pull out at cruise speed. Ctrl or the opposite key cuts it short and rolls out. Starter-B-like numbers: peak 7-8 m above the start, slowest 7 m/s (0.6 vs) over the top, ends about 25 degrees off the reverse heading, loses about 25 m. Console: `fly wingover [l|r]`.
- **Landing**: the auto flare picks its style by body (`LANDING_BY_BODY`, genome name; `fly landing flare|run|auto`). Flare + stall touchdown (starter B, default): cupped wings add CD 0.25 (the brake), nose up 0.3 rad, legs extended and swung forward; touches down at 0.9 vs and runs out 4 m. Running landing (hatchling): comes in at 1.15 vs flat (nose up 0.08), legs extended and reaching 0.4 forward, touches down at 13.7 m/s and runs out 15 m on its legs (6 m/s2).
- **Animation**: downstroke at full reach (+4 % span) and 58 % of the beat, upstroke flexes the wrist (sweep 0.30) and retracts the span; the body bobs 2 % of the span against the beat (rises on the downstroke); legs tuck in cruise (tuck 1.0) and extend in the flare (0.0, forward 1.0 for flare, 0.4 for run), eased over 0.14 s; head counter-rolls 92 % of the body roll (already there); the body roll is `atan(bank_t)` from the lift tilt, so the bank is coordinated by the dynamics.
- **Wingbeat scaling** is an F10 option (Creature group, "wingbeat"): `game m^-1/6` (default, 4.5 m^-1/6) or `lab m^-1/3` (4.8 m^-1/3). B (36 kg): 2.5 Hz / 1.5 Hz; hatchling (30 kg): 2.6 Hz / 1.5 Hz; 0.4 kg bird: 3.6 / 6.5 Hz. It applies to the wings at once; `fly report` prints the live rate and the style choices.
- Tests: `test_flight.gd` (flap-glide duty and speed band, wingover both ways, too low / too slow refused, cut short, both landings, both beat laws), `flight_evidence.gd`. Clips: `/home/diego/Desarrollo/cpore-wt/_agent/loco-clips/flight_*.mp4`, recorded by `godot/devtools/zoo/flight_clip.gd`.

## Choices
Not made yet. After the owner picks, copy `<body>: takeoff=...; cruise=...; ...` into the tracker and DESIGN.md (A31 keeps `lift_mul` dev-only; A34 is the motion canon this follows; A38 defines the wing parts).
