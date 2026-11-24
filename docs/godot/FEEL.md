# Feel: faster creatures and turns that are not clunky (branch g-feel)

Implements steps S0-S8 of [PLAN-feel.md](PLAN-feel.md). S9 (per-creature morphology speeds) is deferred for the owner.
Numbers come from `make godot-feel-test` (`godot/game/tests/feel_test.gd`), which writes
`docs/evidence/godot/feel/measurements.json`. The base measurements are in `baseline-b90dbbc.json`, one file per step
(`after-S2.json` ... `after-S6.json`) shows the progress. Player: the default Merodeador (radius_cm 300), flat ground, 60 fps.

## What changed

- **C (`core/src/stage_world.c walk()`, `CP_STAGE_MOTION`, `CP_STAGE_VERSION` 2).** Jog is 1.3 x `profile.speed`
  (5.2 m/s), sprint 1.7 x jog (8.84 m/s), wild creatures 0.6 x jog. Speed eases toward the wanted speed with
  acceleration capped at 15 m/s2 and braking at 20. The yaw rate is `clamp(1.1 sqrt(9.81/r_body), 1.5, 4.5)` rad/s
  (Merodeador 2.0, Garfio 4.0) and at most `11.8/v` (1.2 g lateral), so a turn at speed is a curve; the wanted speed
  falls to 60 % for a 90 degree turn and to 0 behind the creature. A pivot (twice the turn rate, 3 to 7 rad/s) happens
  only below 0.3 x jog. `combat.c` is untouched: `make tourney` and the combat goldens are identical.
- **Input latch (`player_input.gd`).** WASD is relative to the camera as it was when the key combination changed. A held
  S or A runs in a straight line. Settings in `Game.settings` (saved in `user://settings.cfg`, section `game`):
  `controls/strafe_latch` (default true), `controls/tank` (default false; A/D turn the heading at 2.2 rad/s, W forward,
  S reverse; overrides the latch), `camera/kick` (default false; fov +5 and boom x1.06 near sprint). With
  `strafe_latch` false the old live-camera behaviour returns.
- **Hermite interpolation (`stage_world.gd sample()`).** C1 cubic Hermite through the 10 Hz ticks with one-sided
  tangents (no added latency); Fritsch-Carlson limited yaw; analytic velocity; teleports and fight start and end are
  linear. `speed` is now `|vel|`, the C speed is `speed_c`.
- **Locomotion (`loco_controller.gd`).** Per-plan bank (0.35 quadruped ... 0, limit 0.2 or 0.3 rad); the spine bends along the
  path (station yaw `kappa (z - com.z)`, clamped 0.35); a fast turn on the spot steps around on the lowest gait with
  at least half the legs down; walking gaits never lift a leg when fewer than half would remain; a gait needs 0.3 s
  between changes; the head and the front of the spine turn toward the key press at once (`set_intent`).
- **Camera (`chase_camera.gd`).** The look-at point leads the creature by its velocity (no steady lag), the yaw follow is
  capped at 100 deg/s and 6 rad/s2, engages only after the heading has been steady for a quarter of a second, and does not
  swing when the creature runs toward the camera, pivots, or while orbiting by hand.

## Before and after (measured)

| Measure | Before (b90dbbc) | After |
|---|---|---|
| Jog / sprint top speed | 4.0 / 6.8 m/s | 5.2 / 8.84 m/s |
| Time to 90 % speed, jog / sprint | 0.4 / 0.4 s | 0.4 / 0.6 s |
| Peak acceleration, jog / sprint | 18.0 / 30.7 m/s2 | 15.0 / 15.0 m/s2 |
| Tightest circle, jog / sprint | 1.05 / 1.79 m | 1.57 / 2.67 m |
| 90 degree turn at jog | 0.4 s, speed kept 4.0 | 0.7 s, slows to 3.7 m/s |
| Reversal at jog: facing back / 90 % speed back | 0.4 / 0.8 s (turret) | 1.0 / 1.1 s (brake and turn), overshoot 0.48 m |
| Stop from jog | 0.6 s, 0.23 m | 0.7 s, 0.53 m |
| S held: body yaw travel / camera yaw travel / camera max rate | 941 deg / 855 deg / 441 deg/s | 180 deg (the one reversal) / 3 deg / 29 deg/s |
| A held: body yaw travel / camera yaw travel | 718 deg / 648 deg | 90 deg / 90 deg |
| Max camera yaw rate (any scenario) | 441 deg/s | 99.7 deg/s, acceleration <= 6 rad/s2 |
| Max on-screen body yaw rate | 515 deg/s | 263 deg/s (reversal), 149 deg/s (curves) |
| Camera target lag, steady run | 0.97 m (jog) | 0.01 to 0.02 m, 0.013 at sprint |
| Max roll | 23.9 deg | 11.5-12.0 deg in curves, 9 deg in a reversal |
| Frames without a flat planted foot, reversal / click behind | 55 / 25 | 5 / 5 (a foot is always in contact) |
| Planted-sole slide in the rig | 1.1 mm (but see below) | 0.8-1.3 mm |
| Winnability (biter / guard / spitter) | 42 / 100 (out) / 76 % | 42 / 58 / 76 % |

## Deviations from the plan

- `turn_k` is 1.1, not 1.18: the plan assumed `radius_cm` 340, the default Merodeador has 300 and gave a 1.46 m circle.
- `wild_k` is 0.6, not 0.7: 0.7 sent the spitter winnability fixture to 12 %. At 0.6 Garfio chases at 4.3 m/s against the
  player's jog of 5.2 (ratio 0.83, the plan wanted 0.96). Combat is unchanged. The result is not monotonic in `wild_k`
  (0.55 and 0.5 break the spitter fixture too), it follows the approach timing.
- The speed factor for a target behind the creature is a continuous ramp (1 at 90 degrees down to 0 at 120) instead of a
  step at 90 degrees, which made the circle radius depend on rounding.
- A Hermite on a rate step peaks at 4/3 of the C rate in that tick (263 against 229 deg/s in a reversal), so the plan's 1.1
  bound is gated at 4/3 and at 1.0 (steady) in a circle.
- Frames without a *flat* planted foot are 5 in a reversal, not 0: they are re-acceleration frames of the amble with both
  planted feet at the heel-off limit. A foot is in contact in every frame (`frames_no_contact` is 0).
- The guarantee "half the legs down" applies to gaits with duty >= 0.5 (walk, tripod, pivot stepping). An amble or a trot
  has less than half its legs down by design.
- The plan's slide of 0.0 mm and its 29/10 "no planted foot" counts came from a scratch harness that did not let the
  engine update the rig's hip attachments between steps. `feel_test.gd` now awaits one frame per step as the game does, which
  showed that the spine bend needed no compensation in the controller (planted-sole slide stays under 6 mm) but made the
  baseline slide figure unreliable (it assumed straight hips).

## Not verified

- Software GL only: real GPU frame rates and the camera comfort at 60+ fps need the owner.
- The rig's bent spine against the controller's hips differ by up to 0.2 m (`hip_mismatch_mm` in the measurements): the legs
  absorb it, the sole stays planted, but a leg can look slightly stretched in a hard curve.
- Only the Merodeador was measured in the full pipeline (the loco test covers every plan for the pivot and the spine).
- Per-creature speeds (S9) and the tank steering feel are untested by a human.
- The web stage runs on the same C world and gets the faster rule (`make stage-test` was not run).

## Camera zoom, orbit and strategic map (CAMERA-ZOOM s1, s2, s4)

`chase_camera.gd` keeps the F1 follow (velocity lead, yaw 100 deg/s and 6 rad/s2 caps, no swing towards the camera, tap and
pivot guards); the zoom is a new parameter `z` on top.

| z | distance | pitch |
|---|---|---|
| 0 | 1.8h | 8 deg |
| 0.15 (default, was 6h / 0.24 rad) | 4h | 15 deg |
| 0.40 | 12h | 35 deg |
| 0.70 | 150 m | 55 deg |
| 1.0 | 0.85 x island size (about 3060 m) | 70 deg, fov -8 |

- Distance is interpolated in log space, pitch linearly; both strictly increase. z eases (tau 0.2 s, cap 1.4 z/s, a full
  zoom takes about 0.7 s); a wheel notch is 0.04 z, a flick (several notches within 0.25 s) up to 3.5x that. From z 0.75 the
  look-at point drifts to the island centre; near plane grows with distance (0.25 to 40 m) to keep the depth buffer precise.
- Orbit: right or middle drag only (a left drag past 6 px is ignored, creature-fixes 1). The orbit holds while the creature stands still;
  after 1 s of moving the yaw and pitch ease back behind with the F1 caps (also from the front, unlike plain follow).
  Setting `camera/free_orbit` disables the return. Home or middle click resets (default zoom, behind). A left press is
  a click at release (picks or walks), a hold of 0.2 s keeps steering, a drag orbits. Q/E rotation was skipped: they dodge.
- Strategic icons (`strategic_icons.gd`, CanvasLayer): alpha 0 up to z 0.7, solid by 0.88. Nest, creatures, you (arrow),
  `?` den until you come within 60 m. Hook for the sites registry (D2): set `island.pois_fn` before `build()` to a Callable
  returning `{id, kind: nest|den|site|shard, pos: Vector2(x, z), discovered, label}`; `discovered: false` draws a `?`.
  Clicking a creature icon sends `creature_clicked`; double-click zooms back to the chase band.
- Far zoom budget: above z 0.6 grass and sun shadows are off, above 0.85 creature models are hidden; terrain LOD is already
  distance based (about 3 km picks the coarsest LOD). Ground rays march with a growing step for the click at the map.
- Software GL, 1280x720, llvmpipe (`make godot-camera-evidence`, `docs/evidence/godot/camera/frame_times.json`):
  z 0: 762 ms, 0.25: 606, 0.5: 400, 0.75: 223, 1.0: 124 ms per frame. Far zoom is the cheapest view; real GPU rates are
  not measured. Camera CPU at z 1 is under 1 ms (checked in test_camera).

## Hold to follow, steering (branch c1/movement-feel)

Left button: a drag before 0.15 s is ignored (it no longer orbits); a release before 0.15 s is a click (walk there, or select a creature); staying 0.15 s
makes a **hold**: the creature follows the mouse while the button is down (target re-sent every 0.15 s, moves under 0.6 m
ignored so a still mouse does not replan) and moving the mouse steers it instead of orbiting. Releasing keeps going to the last
target. Turns are now size dependent and smooth: see LOCOMOTION.md section 8. Key legend: "Follow the mouse (hold, then move)".
