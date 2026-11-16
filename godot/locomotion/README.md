# godot/locomotion (G73)

Realistic locomotion from morphology: the creature rig supplies a body
description, the controller turns the C world's position, heading and speed
into a pose (root transform, foot positions, spine bend), the rig applies it.
Pure maths, no nodes, no `class_name`, no project settings needed.
Full description: `docs/godot/LOCOMOTION.md`.

## Use (three lines)

```gdscript
const Morph := preload("res://locomotion/loco_morphology.gd")
const Ctl := preload("res://locomotion/loco_controller.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")

var desc := Adapter.loco_describe(creature, UNIT)          # once; check desc.problems is empty
var loco := Ctl.new(Morph.analyse(desc), func(x, z): return terrain_height(x, z))
# every frame, with the interpolated world pose (yaw 0 faces +Z, yaw 90 deg faces +X):
loco.step(delta, world_pos, heading_yaw, world_velocity)   # velocity optional
Adapter.loco_apply(creature, loco.pose, desc)
```

`UNIT` is metres per rig unit (the game must choose it; hip height must come out
between 0.02 and 5 m). `loco.proposal` (in the morphology) holds the speed
proposal for the C profile. The adapter has not been run on the real rig yet.

Without the real rig, `test/capsule_rig.gd` implements the same two calls on
capsules (`loco_describe()`, `loco_apply(pose)`) and `test/stage.gd` drives it.

## Files

| File | Role |
| --- | --- |
| `loco_morphology.gd` | mass, centre, inertia, stations, plan, robustness, speed proposal |
| `loco_gait.gd` | Froude ladders, duty factor, stride, footfall offsets |
| `loco_controller.gd` | the controller (`step`, `reset`, `pose`, `spine_at`, signals) |
| `loco_ik.gd`, `loco_support.gd` | two-bone IK, support polygon |
| `loco_rig_adapter.gd` | `loco_describe` / `loco_apply` over the real rig's fields |
| `test/` | tests, fake and capsule rigs, evidence scripts, `movie.tscn` |

## Pose fields

`root` (rest space to world), `feet` (ankle targets), `contact`, `swing_u`,
`foot_pitch` (heel raised, rad), `contact_point` (ball of the foot, fixed in
stance), `foot_dir`, `hips` (world hips after the girdle yaw), `station_yaw`,
`spine_at(z)`, `neck`, `tail`, `wave` (legless), `com`, `gait`, `froude`,
`duty`, `cadence`, `stride`, `speed`, `pitch`, `roll`, `bounce`.

## Run

```
make godot-loco-test            # 192 checks, about 25 s, writes docs/evidence/godot/locomotion/measurements.json
cd godot && timeout 400 nice -n 10 xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 \
  godot --path . --rendering-driver opengl3 --script locomotion/test/capture.gd      # strips and footfall diagrams
cd godot && timeout 200 nice -n 10 xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 \
  godot --path . --rendering-driver opengl3 --resolution 640x360 --write-movie /tmp/x.avi \
  --fixed-fps 30 --quit-after 300 res://locomotion/test/movie.tscn -- plan=biped    # then ffmpeg -c:v libx264 -crf 28
```

Always wrap Godot in `timeout`: a script that fails to compile never exits.
Check scripts first with `godot --headless --check-only --script <file>`.
