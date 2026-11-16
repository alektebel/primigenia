# Locomotion module (G73, `godot/locomotion/`)

Realistic locomotion computed from morphology. Input: position, heading and speed from the
C world (any rate, interpolated by the caller), a terrain height function and a body
description from the rig. Output: a pose (see `godot/locomotion/README.md`). Metres, seconds,
radians; +Y up; yaw 0 faces +Z; body-local +X is the creature's left. Plan of record:
`docs/godot/PLAN-locomotion.md`.

## 1. Model

- **Morphology** (`loco_morphology.gd`): mass from frusta and caps (checked against the closed
  form for a capsule), centre of mass, inertia about it, hip stations, per-station load share
  (`1/n + alpha (z - zbar)` so the load follows the centre of mass), plan (`legless`, `monopod`,
  `upright_biped`, `horizontal_biped`, `quadruped`, `multi`), `robustness = mass / (h/0.15)^(1/0.35)`
  (mammal allometry), `graviportal = quadruped and mass > 800 and robustness > 1.6`.
- **Gaits** (`loco_gait.gd`): Froude ladders (`Fr = v^2/(g h)`, hysteresis +-0.05): bipeds walk|run
  at 0.5; quadruped walk|trot at 0.5, trot|gallop at 2.5; graviportal walk|amble at 0.5; multi
  tripod; monopod hop; legless slither. Duty factor, stride `2.3 Fr^0.3 h` (gallop `1.9 Fr^0.4`),
  footfall offsets (quadruped walk LH, LF, RH, RF).
- **Controller** (`loco_controller.gd`), per substep (<= 1/90 s): filters, terrain slopes, gait
  and stride (reach block with toe-off allowance), clock, leg oscillators and footsteps
  (minimum-jerk swing, arc height from speed and obstacles, touchdown on the predicted home),
  load per leg, hip plane (weighted least squares at the feet's home positions) with a
  **per-hip pendulum cap**, implicit springs, balance shift, spring-mass bounce and pitch, lean and
  bank, **girdle yaw and spine bend**, reach guard with **heel-off**, neck and tail springs, legless
  undulation.
- **Rig adapter** (`loco_rig_adapter.gd`): `loco_describe` / `loco_apply` over the field names of the
  real `Creature` and `CreatureLegChain` (read from branch `g-creature`, not modified).

### What changed in this step (relative to the plan's section 1)

1. **Pendulum cap per hip (replaces W1, W3).** Each stance hip may not be higher than
   `foot_ground + sqrt(Lr^2 - d^2) - rest_h` (`Lr = 0.985 L`, `d` from the girdle-rotated hip with
   the balance shift). The walking target is lifted to that cap (weight `(1 - bounce) * erect`), then
   8 Gauss-Seidel passes with a softplus (`w = 0.01 h`) push the plane down at violating hips
   (`_cap_fix`). **Deviation from the plan:** the plan fitted the plane without any pendulum term
   and only enforced caps. That keeps the hip at rest height at mid-stance (knee flexion 39 degrees
   for the test biped) and cannot satisfy the knee target, so the walking target is lifted to the
   cap instead. **Second deviation:** swinging legs anticipate touchdown (their cap fades in over
   the late swing, `smoothstep(0.5, 1, u)`, using the hip position at touchdown); without it the
   spring lags and the reach guard still drops the body 5 cm at every footfall. A limiter applied
   after the springs was tried and rejected (vertical acceleration rose to 9-13 g).
   The touchdown clamp's `0.1 rest_h` guess is replaced by `vault_at_touchdown`.
2. **Toe-off.** The planted point is the ball of the foot (`contact_point`, fixed in the world);
   the heel-off angle `phi` (0 to 60 degrees) is solved by bisection in the reach guard, rises
   instantly and falls with tau 0.03 s. `pose.feet` is the ankle target, `foot_pitch` and
   `foot_dir` are for the rig. The crouch estimate uses `Lr + 0.6 toe`.
3. **Girdles.** The controller rotates each hip pair about the spine toward its leading foot
   (gain **0.085**, not the plan's 0.3, which gave 16-40 degrees peak to peak), bends the spine
   between stations and publishes `pose.hips` and `pose.spine_at(z)`; the rig, the guard and the
   tests use those hips.

## 2. Measurements (`docs/evidence/godot/locomotion/measurements.json`, `make godot-loco-test`: 192 checks, 0 failures)

Gates (all must hold at every commit):

| Gate | Threshold | Measured |
| --- | --- | --- |
| Foot slide per stance, 6 plans x 11 scenarios (IK-solved ball of the foot + IK residual) | < 20 mm | 0.00 mm everywhere (also on ridges, and for turning on the spot) |
| Centre of mass inside the support polygon, statically stable walks | > 95 % of frames | 100 % (light and heavy quadruped Fr 0.03 and 0.06, hexapod Fr 0.05, 0.25, 1.0, octopod); with point feet and no contact patch 93.75-94.03 % at Fr 0.06 (reported) |
| Gait change within +-0.15 of the target Froude number | 0.5 / 2.5 | +0.05 / -0.05 for every transition (0.55 / 0.45; 2.551 / 2.449) |

The slide is zero partly by construction (the planted target does not move); the test measures what
the IK reaches, so it fails when the leg cannot reach. Ankle travel during stance with heel-off:
biped 45 mm, horizontal biped 77 mm, wader 52 mm, light quadruped 36 mm (Fr 1.5), not counted as slide.
Bipeds are not statically stable (reported, not gated): CoM inside the polygon 60 % (biped Fr 0.05),
9 % (horizontal biped), 84 % (wader).

Quality metrics (plan step 2), before the changes -> after:

| Plan | max reach-guard drop (walk / slow walk), share of h | max vertical acceleration (walk / slow) | knee flexion at mid-stance (walk / slow) |
| --- | --- | --- | --- |
| biped | 2.8 % / 1.4 % -> 0 / 0 | 9.05 / 4.52 g -> 2.61 / 2.08 g | 40.7 / 38.8 -> 32.9 / 33.4 deg |
| horizontal biped | 6.1 % / 7.5 % -> 0 / 0 | 22.3 / 28.2 g -> 1.81 / 1.75 g | 37.6 / 33.3 -> 34.4 / 34.5 deg |
| light quadruped | 2.5 % / 5.8 % -> 0 / 0 | 3.50 / 9.99 g -> 1.59 / 2.38 g | 47.9 / 45.4 -> 42.5 / 38.6 deg |
| heavy quadruped | 10.9 % / 14.6 % -> 0 / 0 | 13.2 / 10.0 g -> 1.53 / 4.81 g | 47.4 / 43.8 -> 47.1 / 42.1 deg |
| hexapod (sprawled) | 0 / 0 -> 0 / 0 | 0.12 / 0.03 g -> 0.19 / 0.10 g | 105 -> 99.5 deg (by design) |
| wader | 4.5 % / 5.1 % -> 0 / 0 | 15.8 / 18.8 g -> 4.29 / 1.76 g | 29.6 / 27.5 -> 32.1 / 33.1 deg |

(Heavy slow walk had 4.0 % after step 3 alone; toe-off removed the rest.) Forced lifts: 0 in all
steady walks, before and after. Targets of the plan met: `max_drop < 3 %`, `forced_lifts == 0`,
quadruped pitch range at Fr 0.12 in 0.3-4 degrees (3.31 light, 2.61 heavy), pelvis yaw 3-12 degrees
(biped 9.7, horizontal biped 6.8, light 8.0, heavy 4.6, wader 11.4), the biped still vaults
(CoM 35.5 mm higher in single support). **Not met:** vertical acceleration below 1.5 g (best 1.5,
bipeds 1.8-2.6, wader walk 4.3, heavy slow walk 4.8 g) and stance knee below 20 degrees
(29-34 degrees for bipeds and the wader). The floor for the knee is 20 degrees at the cap
(`Lr = 0.985 L`); the rest is the softplus bias, the spring lag and the plane being shared between
legs.

Run crouch at Fr 1.5 (share of hip height), before -> after toe-off: biped 11.8 -> 7.9 % (target
below 7 % **not met**), horizontal biped 18.0 -> 15.5 %, wader 15.1 -> 10.4 %, light quadruped
(trot) 12.2 -> 9.1 %. Ball slide stayed 0.00 mm, so toe-off is kept.

## 3. Evidence (`docs/evidence/godot/locomotion/`)

Regenerated on this commit and looked at: `strip_<plan>.png` (6 plans, 8 frames per stride, one
row per gait), `strip_legless.png`, `strip_situations.png` (uphill, ridges, banked turn,
acceleration), `footfalls_<plan>.png` (bars measured from contact flags; walk lateral sequence,
flight gaps in run, trot and gallop), `clip_<plan>.mp4` (640x360, 30 fps, 10 s, 0.5-0.7 MB, made
with Godot's movie writer under xvfb software GL: stand, walk, fast gait, turn, stop, label with gait,
Fr, speed and duty), `measurements.json`. The legless body has no clip (no plan in the plan's list).

## 4. Still unconvincing

- Run crouch is reduced but not gone (biped 7.9 %, horizontal biped 15.5 %): a two-bone leg with a
  fixed-length foot cannot reach touchdown and lift-off from standing height.
- Straight-legged walking: stance knee flexion is 29-34 degrees for bipeds (not below 20) and
  hips rise 3-4 cm above rest height when walking starts; vertical acceleration is still 1.5-4.8 g
  in several walks (compass-gait cusps at touchdown). Heavy slow walk 4.8 g.
- No lead change or canter, no slow metachronal gait for hexapods, no pelvic list or lateral
  sway proper, heads do not bob like a wading bird's, the legless body has no
  clip.
- Spine bend yaw gain 0.085 is tuned to land in the 3-12 degree range, not measured on animals.
- The rig adapter's bone sign conventions (tail pitch, neck pitch) and the lateral spine offset are
  taken from the capsule rig and are **unverified on the real skeleton**; only a fake object with the
  same field names has been tested. Nothing has been tried on the real creature rig or the real
  island terrain. The part-mass table (`K_CATEGORY`, `K_TYPE` in the adapter, mass = density x k x size^3:
  horn 0.02, shell 0.08, wing 0.01, default 0.02) is provisional.
- Hex and tripod bodies look odd in the strips because of the test rig's knee pole, not the controller.
- The speed proposal constants below are game tuning.

## 5. Rig adapter contract (asserted in `test_adapter`, six points)

1. Units: `unit` (m per rig unit) comes from the game; `hip_height` must be 0.02-5 m, else a problem is reported.
2. Axes: head in front of the tail along +Z; `side = +1` leg has hip x > 0; a mirrored rig is reported (flip it in the adapter, not the controller).
3. Ankle versus sole: `foot_size = 0.6 width / FOOT.ankle` makes the controller's ankle height equal the rig's sole offset (0.6 x width); `foot_target = ankle - 0.6 width` (world up); rest sole must be on the ground (< 2 mm); planted soles stay within 2 mm of the ground in the fake-rig run.
4. Hanging legs (`hang > 0.001`) are left out of `legs` and not driven.
5. Part masses: provisional table above.
6. Foot names: `garra, dedos, pezuna, runner, sucker, spring, cloven, gecko` exist in the FOOT table; unknown names are reported.

`loco_apply` also sets `creature.global_transform = root` with the basis scaled by `unit`, `foot_pitch`
(heel raised in stance, `-0.5 sin(pi u)` in swing like rig.js), `foot_yaw`, bends tail, neck and
trunk bones and calls `solve_legs()`.

## 6. Speed proposal for the C profile (game tuning, `core/` untouched)

```
hirt   = 25.5 M^0.26 (1 - exp(-22 M^-0.6)) / 3.6            m/s, M in kg
v      = 0.55 * hirt * plan_k * limb * foot_k
plan_k = quadruped 1.0, horizontal biped 0.95, upright biped 0.7, multi 0.6, monopod 0.5, legless 0.22
limb   = clamp(robustness^-0.175, 0.6, 1.3)
foot_k = mean of the feet's speed factors (FOOT table)
cap    = sqrt(Fr_cap g h), Fr_cap = 25 / 20 / 10 / 8 / 6 (same order as plan_k), 3 for graviportal
max_speed  = clamp(min(v, cap), 0.5, 12)        (the C range)
roam_speed = max_speed / 1.7                    (C sprint multiplier)
max_accel  = clamp(0.6 grip g min(1, (M/10)^-0.2), 0.8, 8)
ease/tick  = 1 - exp(-0.1 * 2 max_accel / max_speed)
max_turn   = clamp(0.45 sqrt(M g lever / I_yaw), 0.8, 3.8) rad/s,  lever = max(track/2, body_length/4)
```

The Hirt et al. 2017 fit is data; **the factor 0.55, the plan factors `plan_k`, the Froude caps and the
acceleration and turn constants are game tuning, not measurements.** Outputs (m/s top speed, from
`measurements.json`): biped 6.4 (roam 3.8), horizontal biped 8.0, light quadruped 9.3, heavy
quadruped 2.9, hexapod 3.0, wader 10.0, legless 1.6. (The plan listed biped 7.6; the code gives 6.4
now.) Accelerations 1.6-4.6 m/s2, turn rates 1.5-3.8 rad/s.

## 7. References

Alexander 1984 (dynamic similarity, Froude number and gait change); Alexander & Jayes 1983 (duty
factor and stride as functions of Froude number); Hildebrand 1965 and 1989 (footfall patterns,
diagonal and lateral sequences); Hecker et al. 2008 (Spore creature locomotion); Raibert 1986
(legged robots, spring-mass bouncing); Hirt et al. 2017 (maximum speed versus body mass).
