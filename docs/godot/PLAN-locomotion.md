# Plan to finish G73 locomotion (godot/locomotion)

Written by the planning agent for the implementing agent. Branch `g-loco`,
worktree `/home/diego/Desarrollo/cpore-wt/g-loco`. Read
`_agent/briefs/common.md` and `_agent/briefs/godot-common.md` first. You may
edit only `godot/locomotion/`, `docs/godot/LOCOMOTION.md`,
`docs/evidence/godot/locomotion/`, `godot/project.godot` (minimal, already
there) and one new target in the top-level `Makefile`.

State checked on commit `53d42e3` by reading the code and running the tests:

```
cd godot && godot --headless --path . --script locomotion/test/run_tests.gd
-> 156 checks, 0 failures, 13.6 s
```

`make godot-loco-test` does **not exist yet** (step 1).

Always run Godot with `timeout` and send output to a file. A script with a
parse error does not exit: the process hangs and a pipe into `head` shows
nothing.

## 0. Conventions already fixed (do not change)

- Metres, seconds, radians. `G = 9.81`.
- World: +Y up. Yaw 0 faces +Z, yaw 90° faces +X (the C world's bearing).
  Forward = `(sin yaw, 0, cos yaw)`, left = `(cos yaw, 0, -sin yaw)`.
  `Basis(Vector3.UP, yaw)` maps body-local to world.
- Body-local "rest space": +Z forward, +Y up, **+X is the creature's left**,
  ground at y = 0.
- Slopes are stored as height per metre: `b` = fore-aft (+ = nose up),
  `c` = lateral (+ = left side up). Rotations: `pitch = -atan(b)` about +X,
  `roll = atan(c)` about +Z. Positive `pitch` therefore means nose **down**.
- `neck.yaw`, `tail.yaw` are rotations about body +Y of the whole chain;
  `neck.pitch` + = nose up; `tail.pitch` + = tip up.
- No `class_name` in this folder. Scripts find each other with
  `preload("...")`, so tests run with `--script` and no import step.
- Leg phase: leg `i` touches down when `phase - offset[i]` crosses an integer.
  So a larger offset means a **later** touchdown.

## 1. Current state, file by file

### `godot/locomotion/loco_morphology.gd` — works

`analyse(desc) -> object` with `mass`, `com`, `inertia` (x pitch, y yaw,
z roll, about the centre of mass), `legs[]`, `stations[]`, `plan`,
`graviportal`, `hip_height`, `body_length`, `track_width`, `trunk_incline`,
`robustness`, `neck`, `tail`, `spine_u`, `spine_regions`, `proposal`.

- Mass: spine as frustums `V = π l (r0² + r0 r1 + r1²)/3`, half-sphere caps at
  both ends, legs as two frustums plus a foot blob, parts as point masses.
  Verified against the closed form for a capsule.
- Stations: hips clustered by z with tolerance `0.12 hip_height`, rear first.
- Load share per station: `s_k = 1/n + α (z_k − z̄)`,
  `α = (com.z − z̄)/Σ(z_k − z̄)²`, clamped to ≥ `0.08/n`, renormalised; split
  evenly among the station's legs.
- Plan: 0 legs `legless`; 1 `monopod`; 2 `upright_biped` if the trunk axis is
  more than 45° from horizontal, else `horizontal_biped`; ≤ 4 legs on exactly
  2 stations `quadruped`; anything else `multi`.
- Bipeds: `home.z` is moved under the centre of mass (clamped to ±0.45 leg).
- `robustness = mass / (hip_height/0.15)^(1/0.35)` (mammal allometry).
  `graviportal = quadruped and mass > 800 and robustness > 1.6`.
- `proposal`: see step 8. Values are plausible but **not reviewed against the
  C core's coefficients**.

Partial: part masses must be given by the caller (`mass`); there is no
catalogue of masses per part category yet (step 7).

### `godot/locomotion/loco_gait.gd` — works

- Ladders: bipeds `walk|run @0.5`; quadruped `walk|trot @0.5`,
  `trot|gallop @2.5`; graviportal quadruped `walk|amble @0.5`; `multi` always
  `tripod`; `monopod` `hop`; `legless` `slither`. Hysteresis ±0.05.
- Duty factor `β(Fr)`: walk `clamp(0.47 Fr^-0.18, 0.53, 0.88)`; tripod same
  with `[0.5, 0.85]`; amble `clamp(0.45 Fr^-0.2, 0.3, 0.52)`; run/trot/hop
  `clamp(0.40 Fr^-0.2, 0.2, 0.48)`; gallop `clamp(0.36 Fr^-0.25, 0.15, 0.32)`.
- Stride: `λ = max(2.3 Fr^0.3, 0.3)·h`; gallop `1.9 Fr^0.4`.
- `bounce`: walk 0, tripod 0.25, amble 0.6, others 1.
- Offsets (touchdown phase): quadruped walk LH 0, LF 0.25, RH 0.5, RF 0.75;
  amble LH 0, LF 0.2, RH 0.5, RF 0.7; trot LH = RF = 0, RH = LF = 0.5;
  gallop (left lead) RH 0, LH 0.10, RF 0.30, LF 0.42; multi
  `0.5·((station + (side<0)) mod 2)`; biped 0 and 0.5.

Partial: no metachronal wave for slow hexapods; no lead change in gallop; a
3-legged body is classed `quadruped` and only smoke-tested.

### `godot/locomotion/loco_controller.gd` — works, with known weak spots

`step(dt, pos, yaw, vel=null)` substeps at ≤ 1/90 s and fills `pose`
(`root`, `feet`, `contact`, `swing_u`, `station_yaw`, `neck`, `tail`, `wave`,
`com`, `gait`, `froude`, `duty`, `cadence`, `stride`, `speed`, `pitch`,
`roll`, `bounce`). Signals `footfall`, `liftoff`, `gait_changed`.

What it does per substep, in order (numbers match the code comments):

1. Filters: speed τ 0.12 s, acceleration τ 0.18 s, yaw rate τ 0.1 s.
   `Fr = v²/(g h)`; `moving` if `v > 0.03 √(g h)`.
2. Terrain slopes by central differences over
   `ℓ = max(0.35 body_length, 0.5 h)`, τ 0.15 s.
3. Gait, duty, stride. Stride × `clamp(robustness^0.06, 0.9, 1.15)`; uphill
   × `1/(1 + 1.6 grade)`, downhill × `1/(1 + 0.6 |grade|)`. Reach block: leg
   angle limit `√(0.36 Lr² − off_x²) − off_z` with `Lr = 0.985 L`; crouch
   `= bounce·(1 − (√(Lr² − d_req²) − y_amp)/rest_h)`, max 0.18. Duty, bounce,
   crouch blend with τ `0.35/max(cadence, f_nat)`,
   `f_nat = 0.25 √(g/h)`; stride τ 0.15 s.
4. Clock: `f = v/λ` when moving; `max(f_nat, f)` while any foot is in the air
   or more than `0.12 h` from home; else 0.
5. Leg oscillators: `θ_i' = f·clamp(1 + 3·wrap(Φ − off_i − θ_i), 0.5, 1.8)`.
6. Footsteps. Stance → swing when `frac(θ) ∈ [β, β + 0.4(1−β))` and (moving
   or the foot is out of place) or when forced. Swing progress
   `u = (θ − θ0)/(θ1 − θ0)`, `θ1 = floor(θ0) + 1`. Target = home in the body
   pose predicted at `t_td + 0.5 β/f` (linear in velocity, yaw advance
   clamped to ±0.9 rad), clamped to a reach circle round the predicted hip.
   Path: minimum-jerk `10u³ − 15u⁴ + 6u⁵` horizontally; height
   `lerp(y_from, y_to) + H sin(πu)`, never under the ground. `H` = max of
   `(0.05 + 0.09 min(1, Fr/1.5))·rest_h·lift·clamp(dist/(0.25 rest_h))` and
   what five ground samples along the path need (+ `0.02 rest_h`).
   Touchdown plants the foot exactly on the target.
7. Load per stance leg: `smoothstep(0,0.2,s)·(1 − smoothstep(0.8,1,s))`,
   `s = frac(θ)/β`; all 1 at rest.
8. Hip plane: weighted least squares for `(a, b, c)` in
   `e_i ≈ a + b z_i + c x_i` at the feet's **home** coordinates, weights
   `0.12 + share_i·load_i·n`, ridge terms `0.02 Σw·body_length²` toward the
   terrain pitch `k_p·slope_f` (`k_p` 0.25 upright biped, 0.5 horizontal
   biped, 1 others) and `0.6 Σw·track²` toward `slope_l·(0.35 | 0.15)`.
   `e_i` = ground under the foot, moved back to home along the terrain slope,
   plus the pendulum vault
   `(1 − bounce)·vault_gain·erect·(√(Lr² − d²) − √(Lr² − d0²))`,
   `erect = 1 − clamp(|sprawl|/(0.5 Lr), 0, 1)`.
9. Springs on `a, b, c`: implicit, `ω = 12 √(g/h)·robustness^-0.15`,
   `ζ = clamp(0.7 + 0.15 log10(mass/10), 0.6, 1.3)` (roll at 0.7 ω).
10. Balance shift toward the load-weighted support centroid, gain
    `0.9/(1 + (Fr/0.12)²)` (bipeds: lateral only, `0.55/(1 + Fr/0.15)`),
    clamped to `0.45 track` and `0.15 body_length`.
11. Spring-mass: `ÿ = bounce·moving·g·(F − F̄) − 2ζ_c ω_c ẏ − ω_c² y`,
    `F = Σ_stance share_i·(π/(2β))·sin(π s_i)`, `F̄` its running mean
    (τ = one stride), `ω_c = 0.45·2π·max(f, f_nat)`. Pitch likewise with
    torque `Σ F_i (z_i − com.z)` × `leg_axis_torque (0.25)·m g / I_pitch`.
12. Lean: bipeds `b = −k a/g` (k 0.8 upright, 0.5 horizontal); others
    `b = +0.6 a·com.y/(g·wheelbase)`; clamp ±0.25. Bank
    `−atan(v ω/g)·0.7` (×0.4 for multi and legless), clamp ±0.4.
13. Root = translate · yaw · (pitch, roll about `(0, com.y, com.z)`).
14. Reach guard: if a planted foot is further than `0.995 L` from its hip the
    body is lowered at once by what is needed (release τ 0.12 s); the foot is
    forced to lift when the need exceeds `0.3 h` or the horizontal distance
    exceeds `0.9·0.995 L`.
15. Girdle yaw `−0.3 atan2(zL − zR, 2 track)`; tail and neck springs.
16. Legless wave: `A = 0.09 L·clamp(v/(0.25 √(g L)))`, 1.5 waves, amplitude
    `×(0.4 + 0.6(1−u))`.

Weak or wrong:

- **W1. The reach guard is doing the inverted pendulum's job for quadrupeds.**
  The least-squares plane averages the legs' vault arcs, so a hip is often
  higher than its own straight leg allows; step 14 then lowers the whole body
  uniformly. Feet stay planted (0 mm slide) but the body gets a sawtooth
  height and no pitch from it. Fix in step 3.
- **W2. Runs are crouched** ("Groucho" running, about 10 % of hip height),
  because a two-bone leg with no foot segment cannot reach touchdown and
  lift-off from standing height. Fix in step 4 (toe-off).
- **W3.** `hh -= (1 − bounce)·0.1·rest_h` in the touchdown reach clamp (step
  6) is a guess added in the last edit to allow for the vault. It is covered
  by tests but has no derivation. Replace it in step 3.
- **W4.** `station_yaw` is computed but no rig applies it; the test rig's
  spine is rigid. Step 5.
- **W5.** Hexapod body pitch wobbles at high cadence (seen as ±0.08 slope at
  Fr 4 before the `erect` factor; not re-measured after it).
- **W6.** Stability is only gated at Fr ≤ 0.06 for quadrupeds. With point
  feet the earlier figures at Fr 0.06 were 92–94 %; the 95 % gate uses a
  contact patch of `foot_radius`. This is stated in the test output; keep it
  stated.
- **W7.** The evidence PNGs in `docs/evidence/godot/locomotion/` were rendered
  **before** the straight-leg change and the body edits. They are stale.
  `measurements.json` is current.
- Bipeds are not statically stable at any speed (reported, not gated): correct
  for bipeds, do not try to force it.

### `godot/locomotion/loco_ik.gd`, `loco_support.gd` — work

Two-bone IK returning `{knee, foot, stretch}`; convex hull, signed margin,
support polygon with optional 8-point contact patch.

### `godot/locomotion/test/`

- `bodies.gd` — seven plans plus `octopod`, `monopod`, `tripod`. Works.
- `sim.gd` — driver and measurements (slide on the IK-solved foot, stability
  margin, footfall phase/duty from contact flags, clearance). Works.
- `run_tests.gd` — 156 checks; writes `measurements.json`. Works.
- `capsule_rig.gd`, `stage.gd` — visual test rig and stage. Work.
- `capture.gd`, `footfall_diagram.gd` — strips and diagrams under xvfb. Work.
- `probe.gd` — scratch debugging script. **Delete it.**

Missing: `godot/locomotion/README.md`, `docs/godot/LOCOMOTION.md`, the
Makefile target, movie clips, the adapter for the real rig.

## 2. Remaining work, in order

Run the tests after every step. Commit after every step. The three hard gates
must hold at every commit:

| Gate | Threshold | Where measured |
| --- | --- | --- |
| Foot slide per stance | < 20 mm (now 0.00 mm) | `test_foot_slide`, 6 plans × 11 scenarios |
| Centre of mass inside support polygon | > 95 % of frames | `test_stability` |
| Gait change | within ±0.15 of 0.5 / 2.5 | `test_transitions` |

### Step 1 — housekeeping

- Delete `test/probe.gd`.
- Append to `Makefile`:
  ```
  .PHONY: godot-loco-test
  godot-loco-test:
  	cd godot && timeout 300 nice -n 10 godot --headless --path . --script locomotion/test/run_tests.gd
  ```
  (`run_tests.gd` already exits 1 on failure.)
- Acceptance: `make godot-loco-test` prints `0 failures`, exit code 0.

### Step 2 — add the quality metrics that are missing

In `sim.gd::_measure` record, and in `run_tests.gd` report (new function
`test_quality`, written to `measurements.json` under `"quality"`):

- `max_drop`: largest `ctl._drop / hip_height`.
- `max_vert_acc`: largest `|ÿ|` of `pose.root.origin.y` by second difference
  at 60 Hz, in units of g.
- `stance_knee_deg`: for bipeds in walk at Fr 0.25, the knee flexion at
  mid-stance (`s` between 0.4 and 0.6): `180° − interior angle`, interior from
  the cosine rule on `upper`, `lower` and the hip–ankle distance.
- `forced_lifts`: count of lift-offs caused by `l.force` (add a counter
  `forced_lifts` in the controller, incremented where `l.force` is consumed).

Gate only what already passes, with margin; print the rest. Targets to reach
by the end of step 4: `max_drop < 0.03` in steady gaits, `max_vert_acc < 1.5 g`
in walks, `stance_knee_deg < 20°` for the biped and the wader,
`forced_lifts == 0` in steady straight-line gaits.

### Step 3 — proper pendulum constraint per hip (replaces W1 and W3)

File `loco_controller.gd`, steps 8 and 14 of `_sub`.

For each stance leg `i` compute the highest its hip may be:

```
Lr   = STRAIGHT * length_i                (STRAIGHT = 0.985)
d_i  = horizontal distance hip_i -> ankle_i, hip taken at the nominal body
       pose (p + basis * (hip.x, 0, hip.z)), clamped to 0.95 Lr
cap_i = foot_y_i + sqrt(Lr² - d_i²) - hip_rest_y_i     (an offset, like e_i)
```

Do the least-squares fit **without** the vault term (terrain only), giving
`(a0, b0, c0)`. Then enforce the caps with a smooth minimum, per leg:

```
viol_i = (a0 + b0 z_i + c0 x_i) - cap_i          (> 0 means too high)
```

Solve the smallest change `(Δa, Δb, Δc)` that removes the violations, by two
or three Gauss–Seidel passes over the stance legs: for a violated leg move
the plane down at that hip only,

```
k    = viol_i / (1 + z_i²/Sz + x_i²/Sx)      Sz = body_length²/4, Sx = track²
Δa  -= k ;  Δb -= k z_i / Sz ;  Δc -= k x_i / Sx
```

(for bipeds `z_i` are equal, so only `a` moves: the compass gait). Feed
`a0+Δa, b0+Δb, c0+Δc` to the existing springs. To avoid the cusp at
step-to-step change, replace the hard `max(0, viol)` by
`softplus(viol, w) = w·log(1 + exp(viol/w))` with `w = 0.01 h`.

Scale the correction by `(1 − bounce)·erect_i + bounce` — that is, keep it
always on: in bouncing gaits it replaces the crouch estimate for the moment
of touchdown.

The spring lags the constraint, so keep step 14 as a last resort, unchanged.
Remove the `- (1 - bounce) * 0.1 * m.rest_h` hack in step 6 and compute the
reach circle from the cap instead: `d_max = sqrt((0.97 L)² − hh²)` with
`hh = max(rest_h·(1 − crouch) − vault_at_touchdown, 0.5 rest_h)`,
`vault_at_touchdown = Lr − sqrt(Lr² − (0.5 β λ)²)` × `(1 − bounce)`.

Acceptance: all gates; `max_drop < 0.03` for all six plans in "walk" and
"slow walk"; biped walk still vaults
(`com_single_minus_double_mm > 0.2 % of h`, the existing check); quadruped
walk shows pitch from the constraint (pitch range at Fr 0.12 between 0.3° and
4°; add this check).

### Step 4 — toe-off, so runs need less crouch (W2)

Add a foot segment to the *contact model*, not to the IK:

- New per-leg data in `loco_morphology.gd`: `toe = 0.8·foot_radius` (distance
  from the ankle's ground projection forward to the ball of the foot).
- The planted point is the **ball**: `ball = ankle_ground + dir·toe`, fixed in
  the world for the whole stance. `dir` = body forward at touchdown.
- Heel-off angle `φ ∈ [0, 60°]`: the smallest angle for which
  `|hip − ankle(φ)| ≤ Lr`, where
  `ankle(φ) = ball + R_pitch(φ)·(−dir·toe + up·ankle_h)`. Solve by bisection
  (8 iterations) each substep; `φ = 0` whenever the flat foot already reaches.
  Low-pass φ with τ 0.03 s on the way down only.
- `pose.feet[i]` stays the ankle target (so the rig's IK is unchanged);
  add `pose.foot_pitch[i] = φ` and `pose.contact_point[i] = ball`.
- `sim.gd`: measure slide on `contact_point` **plus** the IK residual
  `|IK foot − feet[i]|`. Both must stay under 20 mm. Keep the old ankle-slide
  number in the JSON as `ankle_travel_mm` for honesty.
- With toe-off, reduce the crouch: in step 3 of `_sub` use
  `Lr_eff = Lr + 0.6·toe` in `need`.

Acceptance: gates; `stance_knee_deg < 20°` for biped and wader in walk; crouch
in biped run at Fr 1.5 below 0.07 (report before and after).

If this step threatens the slide gate and cannot be made to pass in a
reasonable time, stop, revert it, and record it in LOCOMOTION.md as open.

### Step 5 — girdles and spine in the test rig (W4)

`capsule_rig.gd::loco_apply`: rotate hips of station `s` about the body +Y
axis through the station's spine point by `pose.station_yaw[s]`, and bend the
trunk spine nodes by interpolating that yaw between stations. The controller
must use the same rotated hips, so move the rotation into the controller:
add `pose.hips` (world hip positions actually assumed) and have rigs read
those. Re-run the slide tests: the IK in `sim.gd` must take `pose.hips[i]`.

Acceptance: gates; in a lateral-sequence walk the pelvis yaw range is
between 3° and 12° (new check).

### Step 6 — evidence

Run (software GL only, `nice`, few renders):

```
cd godot && timeout 400 nice -n 10 xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 \
  godot --path . --rendering-driver opengl3 --script locomotion/test/capture.gd
```

- Regenerates `strip_<plan>.png` (8 frames across one stride, one row per
  gait), `strip_legless.png`, `strip_situations.png` and
  `footfalls_<plan>.png`. **Open every image and look at it** before
  committing: legs straight in walking stance, no foot under the ground, the
  lateral sequence visible in the diagram (LH, LF, RH, RF), a gap with no bar
  in run and gallop.
- Clips: add `test/movie.gd` (a `Node3D` scene root built in code, saved as
  `test/movie.tscn`) that uses `stage.gd`, reads `plan=` from
  `OS.get_cmdline_user_args()`, ramps speed 0 → walk → fast gait → turn →
  stop over 10 s with a label showing gait, Fr, speed and duty. Record with
  ```
  xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --path . --rendering-driver opengl3 \
    --resolution 640x360 --write-movie /tmp/x.avi --fixed-fps 30 --quit-after 300 \
    res://locomotion/test/movie.tscn -- plan=biped
  ffmpeg -y -i /tmp/x.avi -c:v libx264 -crf 28 -pix_fmt yuv420p clip_biped.mp4
  ```
  One clip per plan, each under 1 MB. If the movie writer fails under xvfb,
  say so in LOCOMOTION.md and capture a 40-frame PNG sequence with
  `capture.gd` and encode that with ffmpeg instead.
- `measurements.json` is rewritten by the tests; commit it.

### Step 7 — adapter for the real creature rig

New file `godot/locomotion/loco_rig_adapter.gd` (pure functions, no
dependency on `class_name Creature`; it takes the node as `Variant`). See
section 3 for the contract. Add a test that feeds it a fake object with the
same fields. Integration with the real rig is a later task; do not import
files from `godot/creature/`.

### Step 8 — documents

`godot/locomotion/README.md`: how to use (three lines of code), the project
settings needed (none), how to run tests and capture.

`docs/godot/LOCOMOTION.md`: the model (section 1 above, corrected for what
you changed), references (Alexander 1984; Alexander & Jayes 1983; Hildebrand
1965/1989; Hecker et al. 2008; Raibert 1986; Hirt et al. 2017), the
measurements table from `measurements.json`, the evidence list, what is still
unconvincing, and the **speed proposal for the C profile** (do not touch
`core/`):

```
hirt   = 25.5 M^0.26 (1 − exp(−22 M^−0.6)) / 3.6            m/s, M in kg
v      = 0.55 · hirt · plan_k · limb · foot_k
plan_k = quadruped 1.0, horizontal biped 0.95, upright biped 0.7,
         multi 0.6, monopod 0.5, legless 0.22
limb   = clamp(robustness^−0.175, 0.6, 1.3)
foot_k = mean of the feet's speed factors (FOOT table)
cap    = sqrt(Fr_cap g h), Fr_cap = 25 / 20 / 10 / 8 / 6 (same order),
         3 for graviportal
max_speed  = clamp(min(v, cap), 0.5, 12)        (the C range)
roam_speed = max_speed / 1.7                    (C sprint multiplier)
max_accel  = clamp(0.6 · grip · g · min(1, (M/10)^−0.2), 0.8, 8)
ease/tick  = 1 − exp(−0.1 · 2 max_accel / max_speed)
max_turn   = clamp(0.45 sqrt(M g lever / I_yaw), 0.8, 3.8) rad/s,
             lever = max(track/2, body_length/4)
```

Current outputs (m/s top speed): biped 7.6, horizontal biped 8.0, light
quadruped 9.3, heavy quadruped 2.9, hexapod 3.0, wader 10.0, legless 1.6 —
re-read them from `measurements.json` after the body edits. State plainly
that `0.55` and the plan factors are game tuning, not measurements.

## 3. Interface the creature rig must provide

`docs/godot/CREATURE.md` is not on branch `g-creature` yet. From reading
`godot/creature/creature.gd` and `creature_leg_chain.gd` there (read only):

The rig already has: `rest` (72 ring centres, tail → head, body space),
`rad`, `ground_offset` (body-root height above ground), `tail_bones`
(t < 0.35), `torso_bones`, `neck_bones` (t ≥ 0.68), `head_bone`,
`skeleton`, `mass_data()`, and per leg (`CreatureLegChain`):
`hip_local()`, `upper_length`, `lower_length`, `width`, `side`, `home`
(rest sole point, creature space, y = 0), `hang`, `pole`, and the inputs
`foot_target` (**global point under the sole**, not the ankle), `foot_yaw`,
`foot_pitch`; `solve_legs()`.

What locomotion needs, as two calls the adapter implements over that:

```
loco_describe(creature) -> Dictionary
  spine:  [{pos: Vector3, radius: float, region: "tail"|"trunk"|"neck"|"head"}]
          tail tip -> head, rest space (+Z forward, +X left, ground y = 0):
          pos = (rest[i] + (0, ground_offset, 0)) * unit, every 4th ring is
          enough; region from t: < 0.35 tail, >= 0.68 neck, last node head.
  legs:   [{hip: Vector3, upper, lower, radius, foot: String, foot_size,
            foot_rest: Vector3}]   hip = hip_local()*unit at rest,
            radius = width/2, foot_rest = home*unit.
  parts:  [{pos: Vector3, mass: float, category: String}]
  density: 1000

loco_apply(creature, pose) -> void
  creature.global_transform = pose.root (rest space origin on the ground)
  for each leg i: foot_target = pose.feet[i] − (0, ankle_i, 0)  (sole);
                  foot_pitch from pose.foot_pitch[i] (step 4) and swing_u;
                  foot_yaw = heading
  spine bones: distribute tail.pitch/yaw over tail_bones, neck.pitch/yaw/roll
               over neck_bones, station_yaw at the bones carrying hips,
               wave_offset(u) for legless bodies
  then creature.solve_legs()
```

Open questions the adapter must settle with the creature agent, and must
**assert** rather than assume:

1. **Units.** The web rig is in rig units (legs about 1.4 long). Locomotion
   is in metres because Froude needs g. `unit` (metres per rig unit) must be
   given by the game; assert `0.02 < hip_height < 5`.
2. **Axes.** Check that the rig's forward is +Z and that `side = +1` is +X.
   If the mesh is mirrored, flip in the adapter, not in the controller.
3. **Ankle vs sole.** The controller's `feet` are ankle centres at
   `ankle = FOOT[kind].ankle · foot_size` above the ground; the rig wants the
   sole. Either pass `foot_size` so that ankle height equals `0.6·width`, or
   subtract as above. Assert the planted sole is within 2 mm of the ground.
4. **Hanging legs** (`hang > 0`) must be left out of `legs`.
5. **Part masses.** Until the catalogue has masses, use
   `mass = density·k_cat·size³` with `k_cat` per category in one table in the
   adapter (e.g. horn 0.02, shell 0.08, wing 0.01); list it in LOCOMOTION.md
   as provisional.
6. **Foot names.** Map `garra, dedos, pezuna, runner, sucker, spring, cloven,
   gecko` to the `FOOT` table keys (already present).

The world must provide `ground(x, z) -> float` in metres (a `Callable`), and
each frame the interpolated position, heading and, if available, velocity.
If velocity is omitted it is derived from positions; with 10 Hz ticks
interpolated linearly this is already tested ("10 Hz world ticks").

## 4. Pitfalls already hit

1. **Phase sign.** `Φ + offset` gives the reverse footfall order: the walk
   became a diagonal sequence and still passed a naive test. Offsets are
   subtracted. The test now measures phases from contact flags; keep it.
2. **Explicit springs explode** at high cadence (`ω h > 1`); all springs are
   implicit: `v = (v + h ω² (x* − x))/(1 + 2ζωh + ω²h²)`.
3. **Force bias.** Integrating `F − 1` drifts whenever timing is not steady
   (a stop left the body 17 cm up, which showed as 22 mm of slide). Use
   `F − F̄`.
4. **Plane regressors.** Fitting at hip positions over-pitched sprawled
   bodies on slopes (15.4° on an 11.3° slope); fitting at live foot positions
   gives bipeds a false pitch. Fit at **home** positions and move each height
   back along the terrain slope.
5. **Leg straightness is very sensitive.** A rest hip height of 0.92 leg
   lengths is already 46° of knee flexion. Test bodies now stand at
   0.94–0.97. Any uniform crouch shows.
6. **Sprawled legs are not pendulums**; without `erect` the hexapod bobbed
   7 cm on a 19 cm hip height.
7. **Capping the reach guard's drop** left residual stretch (slide). Drop
   what is needed; force a lift only when hopeless.
8. **GDScript:** `max()`, `min()`, `clamp()` and dictionary reads return
   Variant; `var x := max(...)` is a parse error under this project's
   warnings-as-errors. Write `var x: float = ...`. A member named `_init`
   clashes with the constructor.
9. **Hanging Godot:** see the note at the top; always `timeout`.
10. **Unrealistic test inputs** (0 → top speed in under a second) are useful
    for robustness but should not drive tuning.
11. Another agent runs Godot on the same machine. Kill only your own PIDs.

## 5. Evidence to produce (in `docs/evidence/godot/locomotion/`)

- `measurements.json` (from the tests).
- `strip_<plan>.png` for biped, horizontal_biped, light_quadruped,
  heavy_quadruped, hexapod, wader; `strip_legless.png`;
  `strip_situations.png` (uphill, ridges, banked turn, acceleration).
- `footfalls_<plan>.png` for the six plans.
- `clip_<plan>.mp4` for the six plans, or the stated fallback.
- In LOCOMOTION.md: the table of gates with measured values, and a section
  "Still unconvincing" that is honest. Carry over at least: bipeds' running
  crouch if step 4 did not remove it; no lead change or canter; no slow
  metachronal gait for hexapods; no pelvic list; heads do not bob like a
  wading bird's; the proposal's tuning constants; nothing has been tried on
  the real creature rig or the real island terrain.
