# Move-style picker — M1 / D-26 owner comparison

Open [styles.html](../../../web/gaitlab/styles.html) directly with `file://`. Local three.js r128 is `web/biome/three.min.js`; no network, server, build, or install. This extends the M1 gait-lab comparison with the owner's 2026-11-22 request: one body, sixteen styles, 2 m/s default. **Awaiting owner choice; no style is approved or ported.**

Space / Shift+Space cycles starter B → hatchling → A → C → D → generic quadruped → generic biped. All sixteen cells use the same genome and world speed, adjustable from 1–6 m/s. Click to star; the side panel and Copy choices retain selections by creature. F fullscreens the hovered or focused cell (viewport fallback if the browser denies fullscreen); Esc restores the grid. P pauses. Playback buttons change simulation time, not stride or speed. Narrow screens preserve four columns in a horizontally scrollable grid.

## Provenance and proportions

`node tools/gaitlab/styles_extract.cjs --write` reproduces the inline `BODIES` table; `--check` checks for drift. It reads all four `godot/game/data/starters/*.json` plus `godot/game/data/hatchling.json`. No Godot files are modified. The extraction uses uniform Catmull–Rom tension 0.5 through `[z,y,r]` nodes, approximates the radial mount at each leg's `t, ang`, and maps genome forward Z to lab forward X. The leg segment lengths are `|k|` and `|f−k|`, with mirror partners; all five authored bodies have four walking legs. Node positions/radii carry body, neck, head, and tail proportions; genome skin colors, beak/blunt muzzle, D's extra graspers and C's plates aid recognition. Neck and tail are linked primitive segments, not a replacement genome.

The surface anchor is a continuous approximation to `Creature.anchor`, without its capped-spine sample/frame quantisation. Raw authored limb lengths are used, not Godot's runtime foot-height refitting. Generic controls use explicit starting dimensions in the extraction script. The page is a visual lab, not a claim of mesh or animation parity with Godot.

## Presets

Order of offsets is **LH, RH, LF, RF**, in stride cycles. `k` multiplies the shared stride law; `bob`, `height`, and `lift` are fractions of mean authored hip height `h`. `roll`, static `pitch`, rocking pitch, spine amplitude, and head yaw are radians, except that lateral spine displacement is `h × spine`. `phase` shifts bob in cycles. Body X rotation is roll, Z rotation is pitch.

**All numeric preset values are starting values for the M1 owner comparison**, including stylised animal analogies. They are not measured animal data. Footfall vocabulary and the underlying solver come from the existing [gait lab](gaitlab.md), which cites Hildebrand (1965/1977) for sequences, Alexander & Jayes (1983) for stride scaling, and Cavagna et al. (1977) for stance-linked bob. The knuckle-walk reference is the project's [motion procedure](../../../.claude/skills/cpore-motion/SKILL.md): shoulder-up posture and roll near hand support, estimated ~7° roll. That video has not been numerically tracked here.

| Style | Offsets | Duty | k | Bob / phase | Roll | Pitch / rock | Height | Spine | Head | Lift | Flight | Source |
|---|---|---:|---:|---|---:|---|---:|---:|---:|---:|---|---|
| lateral-sequence walk | 0, 0.5, 0.25, 0.75 | 0.66 | 1 | 0.025 / 0 | 0.04 | 0 / 0.015 | 0.9 | 0.015 | 0.025 | 0.12 | no | M1 starting values; gait-lab mechanics |
| diagonal walk / sprawl | 0, 0.5, 0.75, 0.25 | 0.7 | 0.95 | 0.025 / 0 | 0.06 | 0 / 0.02 | 0.64 | 0.16 | 0.025 | 0.12 | no | M1 starting values; gait-lab mechanics |
| amble / rack | 0, 0.5, 0.18, 0.68 | 0.56 | 1.15 | 0.012 / 0 | 0.025 | 0 / 0.01 | 0.9 | 0.02 | 0.015 | 0.13 | no | M1 starting values; gait-lab mechanics |
| knuckle-walk | 0, 0.5, 0.3, 0.8 | 0.7 | 1.05 | 0.025 / 0 | 0.122 | 0.09 / 0.025 | 0.9 | 0.025 | 0.02 | 0.1 | no | cpore-motion reference; starting values |
| trot | 0, 0.5, 0.5, 0 | 0.4 | 1.3 | 0.085 / 0.5 | 0.025 | -0.025 / 0.02 | 0.88 | 0.025 | 0.025 | 0.2 | yes | M1 starting values; gait-lab mechanics |
| pace | 0, 0.5, 0, 0.5 | 0.42 | 1.25 | 0.05 / 0.5 | 0.1 | -0.02 / 0.025 | 0.88 | 0.04 | 0.03 | 0.18 | yes | M1 starting values; gait-lab mechanics |
| canter | 0, 0.32, 0.32, 0.66 | 0.29 | 1.35 | 0.07 / 0.5 | 0.035 | -0.02 / 0.095 | 0.86 | 0.045 | 0.03 | 0.22 | yes | M1 starting values; gait-lab mechanics |
| rotary gallop | 0, 0.12, 0.62, 0.5 | 0.25 | 1.55 | 0.1 / 0.5 | 0.035 | -0.04 / 0.07 | 0.86 | 0.08 | 0.035 | 0.24 | yes | M1 starting values; gait-lab mechanics |
| heavy | 0, 0.5, 0.35, 0.85 | 0.65 | 1.22 | 0.012 / 0 | 0.055 | 0.015 / 0.015 | 0.87 | 0.02 | 0.015 | 0.07 | no | M1 starting values; gait-lab mechanics |
| nervous small | 0, 0.5, 0.25, 0.75 | 0.6 | 0.5 | 0.04 / 0 | 0.045 | -0.02 / 0.025 | 0.88 | 0.025 | 0.15 | 0.16 | no | M1 starting values; gait-lab mechanics |
| slinky stalk | 0, 0.5, 0.26, 0.76 | 0.74 | 1.2 | 0.012 / 0 | 0.025 | -0.015 / 0.015 | 0.6 | 0.075 | 0.025 | 0.07 | no | M1 starting values; gait-lab mechanics |
| springy | 0, 0.5, 0.5, 0 | 0.39 | 1.25 | 0.15 / 0.5 | 0.025 | 0.015 / 0.055 | 0.82 | 0.035 | 0.035 | 0.32 | yes | M1 starting values; gait-lab mechanics |
| biped run | 0, 0.5, 0.5, 0 | 0.38 | 1.4 | 0.09 / 0.5 | 0.045 | 0.22 / 0.04 | 0.84 | 0.035 | 0.025 | 0.23 | yes | M1 starting values; gait-lab mechanics |
| bound / hop | 0, 0, 0, 0 | 0.4 | 1.35 | 0.14 / 0.5 | 0.015 | -0.015 / 0.1 | 0.8 | 0.06 | 0.035 | 0.27 | yes | M1 starting values; gait-lab mechanics |
| salamander wiggle | 0, 0.5, 0.75, 0.25 | 0.72 | 1.1 | 0.02 / 0 | 0.045 | 0 / 0.025 | 0.61 | 0.28 | 0.035 | 0.12 | no | M1 starting values; gait-lab mechanics |
| crouch-creep | 0, 0.5, 0.3, 0.8 | 0.7 | 1.1 | 0.012 / 0 | 0.025 | -0.02 / 0.012 | 0.54 | 0.055 | 0.025 | 0.055 | no | M1 starting values; gait-lab mechanics |

Stride is `2.3 × min(Fr, .65)^.3 × h × k`, `Fr = v²/(9.81h)`, and cadence is exactly `v / stride`. The `.65` style-speed ceiling is a starting value: retain each style's reach and character as speed rises rather than silently select a different gait. The nominal stride is capped by `1.22 × shortest active limb reach / duty` and, only where adjacent same-side stance windows overlap in a potentially reversing order, `.96 × station spacing / adverse phase difference`. These starting-value caps leave bending reserve and prevent grounded same-side crossing. Body height is lowered for reach, never by dragging a foot. Default 2 m/s follows owner feedback; 1–6 m/s is the requested comparison range.

The caps mean short, closely spaced limbs can still need a high cadence at 6 m/s. They also limit how slowly the hatchling can step at 2 m/s while keeping its feet pinned. The page shows actual Hz and stride metres; heavy does not invent longer limbs or reduce root speed. Nervous small deliberately halves nominal reach. Crouch-creep means slow, careful *foot placement*, at the shared world speed; use 1 m/s for the slowest comparison.

The original lab's two-bone IK and fixed pole (outward/raised for low crouches), stance pinning, cosine swing, support-weight bob, tracking side camera (slightly raised and oblique so roll and lateral wiggle remain visible), ground ticks, touchdown marks, and two-stride contact strips are reused/adapted. World touchdown X is evaluated at the exact phase boundary, then held until lift-off. Bob in flight styles uses `height + bob × (1 − strongest support weight)`; grounded styles use `height + bob × sin(2π(phase + bobPhase))`. Roll uses right-minus-left support weights. Pitch rocks once per stride. A travelling lateral spine wave also moves hip anchors, not just the skin; the head counters torso pitch/roll and nervous head checks use a sharp, deterministic yaw. Tail nodes counter torso pitch.

### Body adaptations

- With two legs, grounded styles use alternating contacts and duty at least .56; flight styles alternate running contacts, except hop with simultaneous contacts. Labels identify the two-leg adaptation. Four-beat / three-beat sequences cannot be preserved on two feet.
- Biped run on a four-leg body uses rear-up posture about the hind hips, only rear feet supporting, and folded forelimbs visibly held clear. It retains four limbs and genome segment lengths. Labels identify the rear-up variant.
- Knuckle-walk uses the existing forelegs as struts; it never lengthens them. Its label says this explicitly. Starter D's additional graspers remain decorative, not extra support feet. Exact gorilla shoulder/hip ratio is not asserted on incompatible genomes.
- Flight is allowed only for trot, pace, canter, rotary gallop, springy, biped run, and bound/hop. Grounded alternatives stay grounded at every slider speed.

## Verification and capture

Run:

```sh
node tools/gaitlab/styles_extract.cjs --check
nice -n 10 node tools/gaitlab/styles_check.cjs
nice -n 10 node tools/gaitlab/styles_check.cjs --transitions
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules nice -n 10 node tools/gaitlab/styles_capture.cjs
```

`?test=1` exposes `window.__stylesCheck`; Node runs the **same inline solver and assertions** without DOM/WebGL. All seven bodies × sixteen styles × speeds 1, 2, 6 = 336 cases, three settling plus four measured strides each, sampled at 360 frames per stride. Measures actual IK endpoint slip (<1 mm), stance duty (±.02), measured touchdown stride (±3%), support/flight versus analytic coverage (±.02), correct pole-side knees, grounded same-side order, knees and feet above ground, no IK clamps or drags, and exact cadence × stride = speed. Running styles require flight >.02; grounded styles require zero. JSON evidence is `styles/table.json`. These are kinematic checks, not a dynamics or taste score.

Numerical run 2026-11-22: **PASS, 336/336 cases**. Maximum IK stance slip <0.000001 mm; no knee flips, grounded crossings, below-ground joints, clamps, or drags. Measured duty error ≤0.0017, touchdown-stride relative error <0.000001, and analytic-flight error ≤0.0034. Starter B at 2 m/s: walk 1.65 Hz, heavy 1.62 Hz, nervous small 3.20 Hz. The separate `--transitions` check runs abrupt 2 → 6 → 1 → 2 m/s changes on all 112 body/style pairs and writes `styles/transitions.json`, verifying that speed changes keep planted feet pinned and retain reach, knee, ground, and crossing invariants.

Capture uses only `--use-angle=swiftshader --enable-unsafe-swiftshader` and `file://` with local assets. It takes one JPEG grid per creature, writes measured JSON, then exercises stars, persisted choices, copy, Space / Shift+Space, F / Esc, P, playback, and laptop/narrow viewport captures. **Capture attempted 2026-11-22: Chromium launch blocked by sandbox (`crashpad ... setsockopt: Operation not permitted`, SIGTRAP). No screenshots or browser-interaction PASS are claimed.** Run the command above in an environment that permits Chromium to produce the JPGs. No GPU, installs, network, Godot, or C core changes were used.

## Port to `godot/locomotion/loco_gait.gd`

After the owner stars styles and confirms the M1/D-26 tracker comparison, add each approved name as an optional visual style alongside the existing gait selection. Store the corresponding row as a named parameter record, separating morphological adaptations from the shared style. `offsets()` maps by station/side rather than list index, `duty()` returns beta with the two-leg support rule, and `stride_length()` multiplies the current Alexander law by k and applies the reach/spacing caps. Cadence remains authoritative speed divided by stride; the C sim retains root position and speed.

Pass bob/phase, roll, pitch/rock, height, spine, head, and lift to the locomotion pose/foot planner. The stride planner owns planted world targets, the existing IK solves to them, the body reach pass lowers hips, and the visual spine/head/tail layer consumes the remaining parameters. Rear-up needs an explicit active-support mask, a hind-root pivot, and a clear-ground forelimb target. Never silently remove genome limbs. Integrate style transitions with the existing contact planner to avoid phase resets or moving a planted foot. Keep this archived lab independent (A35).

Run the Godot locomotion suite and L0 scorecard for each adopted style: slip, knee flips, foot penetration, airborne fraction, torso bob/roll, head pitch and extension. Compare the named style with the reference clips and owner's vote before merge. The present sandbox run does not replace those Godot or owner gates.
