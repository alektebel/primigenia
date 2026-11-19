# Creature module (M1a, `godot/creature/`)

Port of the creature builder of the web implementation (`web/creature/rig.js`,
`web/studio/genome.js`, `web/studio/growth.js`, `web/studio/parts.json`) to Godot 4.7.
It builds a rigged, skinned creature node from a `cpore.creature/4` genome. It does **not**
include gait, stepping, body bob or part animation timing (rig `update()`); it only exposes the
nodes and hooks those need.

## 1. Setup

- Files: `godot/creature/*.gd` (classes `Creature`, `CreatureGenome`, `CreatureGrowth`, `CreatureGeo`,
  `CreatureMaterials`, `CreatureParts`, `CreatureLegChain`), `shaders/` (skin and membrane
  shaders), `assets/` (copy of `web/studio/parts.json` and `parts/*.glb`; tests check SHA-256 and byte
  equality with `web/studio`), `tests/`, `tools/` (preview and evidence renders).
- Project settings: none beyond the GL Compatibility renderer. `godot/project.godot` is a minimal
  stand-in; the M0 project replaces it.
- `make godot-creature-test` (headless tests), `make godot-creature-evidence` (software-GL renders,
  needs `xvfb-run`). Run the import step (`godot --headless --path godot --import`, done by the
  make targets) once so new `class_name` scripts are registered.
- Exported builds: `parts.json` and the GLBs are read raw with `FileAccess` and
  `GLTFDocument.append_from_buffer` (not as imported scenes). Add an export include filter
  `creature/assets/*`, otherwise the exported game will not find them. `.godot/` and `*.import`
  are not committed.

## 2. Frames

- Creature local **+Z = forward, +Y = up** (same as rig.js; this is the opposite of Godot's -Z
  convention, so a locomotion node rotates the `Creature` accordingly). The origin is on the ground.
- `BodyRoot.position.y = ground_offset` (rig `off`: `max(0, .03 - lowest ring bottom)` for legged
  creatures, `.03 - bottom` for legless ones). Skeleton and body space equal rig.js creature-local space.
- Node layout: `Creature > BodyRoot > Skeleton3D > {Body, Bone_<name> BoneAttachment3D (parts, growth, hips)}`
  and `Creature > Limbs` (leg segments).
- Bone convention: every spine bone has local X = frame s (left/right), Y = frame u (dorsal),
  Z = spine tangent toward the head. `root_bone` is the bone nearest the widest ring; chains run
  outward from it to both tips. A lateral bend is a rotation about local Y:
  `skeleton.set_bone_pose_rotation(b, rest_q * Quaternion(Vector3.UP, a))`.
- Winding: three.js CCW indices are kept internally and flipped once in `CreatureGeo.to_arrays()`.

## 3. Public interface

`Creature` (extends `Node3D`, `@export asset_dir`, signal `built`):

| Symbol | Meaning |
|---|---|
| `static parse_genome(input, asset_dir) -> {ok, genome, warnings, error}` | Validate and migrate /1 /2 /3 to /4. `input` is a JSON string or Dictionary. `error` is the path string genome.js throws. |
| `load_genome(input) -> Dictionary` | `parse_genome` then `build`. On failure returns `ok=false` and leaves the current creature untouched. Sets `warnings`. |
| `build(genome: Dictionary)` | Rebuild from a parsed genome (frees all previous children). |
| `static seeds() -> Dictionary` | `Merodeador`, `Zancuda`, `Babosa` (rig.js SEEDS). |
| `default_part(type) -> Dictionary` | Default genome part entry for a part id (rig:361). |
| `set_skin(skin)`, `set_sun_direction(dir)` | Live palette change; sun direction for the membrane backlight. |
| `body_root`, `skeleton`, `body_mesh`, `limbs`, `materials`, `maker`, `genome`, `warnings` | Nodes and state. |
| `rest`, `rad`, `frames`, `NS` (72 rings) | Spine ring centres, radii, frames `{s,u,t,dr}`. |
| `anchor(t, ang) -> {p, n, t, u}` | Surface point (t spine parameter 0..1 tail to head, ang 0 dorsal, +pi/2 +X flank, pi belly). |
| `orient(A, sink, rot, tilt) -> Transform3D` | Surface frame, +Z out of the skin. |
| `mount_radius(t)`, `bone_for_t(t)`, `bone_rest_global(bone)` | Helpers. |
| `bone_ring`, `spine_bones` (tail tip to head tip), `tail_bones`, `torso_bones`, `neck_bones`, `head_bone`, `root_bone` | Skeleton groups. |
| `reset_spine_pose()` | All bones to rest. |
| `legs: Array[CreatureLegChain]`, `pose_legs_rest()`, `solve_legs()` | Legs, see below. |
| `parts` | Entries `{index, type, category, side, node, t, ang, size, bone, mount, mount_radius, hooks}`. |
| `growth` | Entries `{region_id, family, side, node, t, bone}`; roots sit at `anchor(t, angle*side).p - n*.01` (tested). |
| `stats` | `{dna, vel, bite, sing, hp, warn, speed}` (rig computeStats). |
| `stride_hint`, `body_volume()`, `rest_aabb()`, `mesh_instances()`, `mass_data()` | `mass_data` = `{segments, volume, length, parts, legs}` in body space. |
| `animation_hooks() -> [{index, type, side, hooks}]` | Hook names and what rig.js does with each: `jaw` rotation.x, `lid` rotation.x, `sway` rotation.x, `pinch` rotation.y, `wing` rotation.z/.y, `arm` rotation.x, `tail` rotation.y, `sacs` scale (rig:469-475). Hook values are node metadata on the part group. The `trompa` jaw/sway hooks are never attached in rig.js (rig:79), so none are exposed. |

`CreatureLegChain` fields: `hip_marker, upper, lower, foot, upper_length, lower_length, width, side,
pole, home, hang, rest_knee, rest_foot, pair_index, front, foot_target` (GLOBAL sole point),
`foot_yaw, foot_pitch, allow_stretch`; methods `solve()`, `solve_local(sole, yaw, pitch)`,
`pose_rest()`, `hip_global()`, `total_length()`. Per frame, locomotion moves the `Creature`,
optionally moves `body_root` (bob) and spine bones, sets `foot_target`/`foot_yaw`/`foot_pitch`
per leg and calls `solve_legs()`.

Library: `CreatureParts.library() -> {entries, types, templates, material_slots, table, failures}`
(static, cached). `CreatureGenome.parse(input, types)`, `CreatureGrowth.generate(recipe)`.

Material regions (from `docs/evidence/studio-v4-materials.md`): `skin` -> creature skin; `membrane` ->
double-sided skin colours, alpha .82, backlight; `keratin` -> bone (beak non-ivory slots use the
beak material); `eye` -> pupil, or iris when the material name contains "iris"; `glow` -> cyan
emissive, no shadows; `dark` -> unused by the GLBs. Selected by `CreatureMaterials.for_region()`.
Growth: tendrils use skin, horns and plates use bone.

## 4. Visual differences that remain

Checked against the evidence images below.

- **Tonemapping**: Godot ACES differs from three r128 ACESFilmic (three divides exposure by .6). The
  preview uses exposure 1.4 instead of 1.05, matched by eye, with sun 2.2 and ambient .75. The stage
  must pick its own values; these are evidence-only.
- **No PMREM environment map**: reflections and ambient come from the Godot sky; membranes and
  clearcoat look flatter than in `merodeador_vs_threejs.png`.
- **Scale crevices** (Worley + derivative bump) read darker and more contrasted, and at distance
  (`seeds.png`, Zancuda) the fine scales shimmer into noise.
- **No bloom** on glow (three studio had none either; the hero stage may).
- **Skinned body**: linear blend between two spine bones per ring; rig.js rebuilt the tube on the CPU
  each frame. Strong spine bends can pinch at bone heads, and parts ride rigid `BoneAttachment3D`
  nodes, so a seam between a part root and the skin can open when bent (not covered by an image).
- **Membranes** use alpha blending with `render_priority`; overlapping transparent sails (Zancuda fin) may
  sort differently from three.js.
- **Shadows**: Godot directional shadow with bias; in `seeds.png` the Babosa body floats slightly above
  its shadow (peter-panning on low creatures).
- **Ellipsoid normals** are analytic; three recomputed face normals, so the seam at u=0 differs slightly.
- **Lighting of the ground** in the evidence images is the preview stage, not the game terrain.
- **Not ported** (studio-only): vertebra gizmos, selection rings, rotation handle, thumbnails.

## 5. Tests and evidence

`make godot-creature-test` -> `creature tests: 1456 checks, 0 failures` (about 3 s): asset hashes,
genome parity with genome.js (34 error cases, 3 migrations, /4 GLB fixture), growth vertex parity with
growth.js (< 1e-4), all 46 parts build, seed stats (DNA 129 / 92 / 65), ground-offset rule, IK
(Merodeador: 4 of 4 legs reach the rest target exactly, 0 clamped), growth placement (max error ~1e-6), rebuild
stability, bad-input handling. Parity data: `tests/parity/expected.json`, regenerate with
`node godot/creature/tests/parity/gen_parity.cjs` from the repo root.

Build time (headless software run, median of 5 builds after the library is cached, one machine):
Merodeador 14.1 ms, Zancuda 8.6 ms, Babosa 6.7 ms.

Evidence, `docs/evidence/godot/creature/`: `merodeador_vs_threejs.png`, `g48_tail_hammer_compare.png`,
`zancuda_vs_threejs.png`, `seeds.png`, `parts_contact_sheet.png`, `growth.png`.

Realism pilot (skin detail, keratin, Turing patterns, actuation, Forward+ tier): `CREATURE-REALISM.md`.
