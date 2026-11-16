# PLAN — finishing M1a (Godot creature builder)

Branch `g-creature`, worktree `/home/diego/Desarrollo/cpore-wt/g-creature`.
Allowed paths: `godot/creature/`, `docs/godot/CREATURE.md`, `docs/godot/PLAN-creature.md`,
`docs/evidence/godot/creature/`, plus the existing `godot-creature-*` targets at the end of
the root `Makefile` and the minimal `godot/project.godot` (M0 will replace it).
Read `/home/diego/Desarrollo/cpore-wt/_agent/briefs/common.md` and `godot-common.md` first.
Sign commits `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or your own model line
if the coordinator says so). Never use a GPU, always `nice -n 10`.

Source of truth: `web/creature/rig.js` (cited below as `rig:LINE`), `web/studio/genome.js`,
`web/studio/growth.js`, `web/studio/parts.json`, `docs/evidence/studio-v4-materials.md`,
`docs/evidence/g48.md`.

---

## 1. Current state (verified 2026-11-16)

`make godot-creature-test` → `creature tests: 1317 checks, 0 failures (~2.8 s)`.
Commits: `255f329` core port, `3ae968d` tests + make target, `3f3dace` WIP (evidence script,
preview tweaks, five evidence PNGs; made by the coordinator, content is final and correct).

| File | State |
|---|---|
| `godot/project.godot` | Minimal, GL Compatibility, no main scene. Done. |
| `godot/creature/creature_genome.gd` (`CreatureGenome`) | **Done.** `parse(input, types)` → `{ok, genome, warnings, error}`; `error` is the exact path string genome.js throws. Validation + /1 /2 /3 migration ported line by line. Parity-tested against genome.js (34 error cases, 3 migrations, the /4 GLB fixture). |
| `creature_growth.gd` (`CreatureGrowth`) | **Done.** mulberry32 with 32-bit `imul` emulation; same tubes; vertex parity with growth.js < 1e-4 on 4 recipes. |
| `creature_geo.gd` (`CreatureGeo`) | **Done.** Replicas of three.js `SphereGeometry`, `CylinderGeometry`/`ConeGeometry`, `OctahedronGeometry`, `CatmullRomCurve3.getPoint` (centripetal + catmullrom, open/closed), rig `allocTube/fillTube/curveTube/sweep/ell/skinify`. Indices are stored in three.js CCW order and flipped in `to_arrays()` (Godot front faces are clockwise). `skin` vec4 goes to `ARRAY_CUSTOM0` (RGBA float). |
| `creature_materials.gd` (`CreatureMaterials`) | **Done.** Per-creature materials: skin, skin2 (double), membrane/glider/insect/sac (shaders), bone/tooth/beak/eye_white/iris/pupil/dark/glow (StandardMaterial3D, values from rig:34-36, rig:56). `set_skin()` = rig `load()` (rig:555), `set_sun_direction()`. |
| `shaders/skin_common.gdshaderinc` + 6 `.gdshader` | **Done.** Port of `SKIN_GLSL` + the `onBeforeCompile` replacements (rig:11-31): 4 patterns, belly/back weight, Worley scales, derivative bump `pN`, rim emission, wet roughness, clearcoat; membrane variants with backlight (`#define MEMBRANE`, `MEMBRANE_STYLE 0..3`). Compiles and renders in GL Compatibility on llvmpipe. |
| `creature_parts.gd` (`CreatureParts`) | **Done.** Static `library()` loads `assets/parts.json`, checks the manifest coordinate convention (rig:268-269), loads the 8 GLB parts at runtime with `GLTFDocument.append_from_buffer` (no editor import) and applies rig:303-305 transforms and `slotRegion`/`regionMaterial` (rig:272-297). Instance `make()` builds every procedural part: classic LIB (rig:58-96), creator G48 parts (rig:119-261) with `creatorPart` scaling (rig:126-131), legs `make_leg()` (rig:351-359) and `_creator_foot()` (rig:322-342). |
| `creature_leg_chain.gd` (`CreatureLegChain`) | **Done.** Two-bone IK from rig:482-491 (`solve()`, `solve_local()`), rest pose (rig:479), stretch option (rig:486-487), `_arc` = `Quaternion.setFromUnitVectors`. |
| `creature.gd` (`Creature`, Node3D) | **Done, API not yet documented.** `load_genome()`, `build()`, `seeds()`, spine sampling (rig:388-390), `anchor()` (rig:392-394), `mount_radius()` (rig:396), `orient()` (rig:455), body/upright mounts (rig:470), mirrored pairs (rig:398, 403), `fittedPose` (rig:343-349), `layout` (rig:408-415), growth (rig:498-525), stats (rig:434-441), `default_part()` (rig:361-365), Skeleton3D spine with BoneAttachment3D parts, `mass_data()`, `animation_hooks()`. |
| `assets/` | Copies of `web/studio/parts.json`, `parts/*.glb`, `parts/manifest.json`; tests check SHA-256 against parts.json and byte equality with web/studio. |
| `tests/test_creature.gd` | Done but has 2 weak checks (see step 1). |
| `tests/parity/gen_parity.cjs` + `expected.json` | Done. Regenerate with `node godot/creature/tests/parity/gen_parity.cjs` from the repo root. |
| `tools/creature_preview.gd`, `render_quick.gd`, `render_evidence.gd` | Done. Evidence-only stage (sun = rig SUN, ACES, exposure 1.4 matched by eye, see pitfalls). |
| `docs/evidence/godot/creature/*.png` | 5 images present and current (see §4). No growth image yet. |
| `docs/godot/CREATURE.md` | **Missing.** Required by the task (public interface + honest list of visual differences). |

What is explicitly **not** in scope (do not write it): gait, stepping, body bob, spine sway
timing, part animation timing (rig `update()` rig:456-496), studio handles/selection rings/vertebra
gizmos (rig:387, rig:416-430, rig:494-495). The rig only exposes the nodes those need.

---

## 2. Remaining steps (in order, each small, commit after each)

### Step 1 — tighten two weak tests
File `godot/creature/tests/test_creature.gd`.
1. `_test_seeds_and_fixtures()`: replace the Babosa line
   `check(abs(c.ground_offset - (.03 - (.5 - .15 * 0 - 0))) < 2 or c.ground_offset > 0, ...)` with the
   exact rule of rig:401: compute `bottom = min_i(c.rest[i].y - c.rad[i])` over all `Creature.NS`
   rings and check `abs(c.ground_offset - (.03 - bottom)) < 1e-6` (Babosa has no legs). For a
   legged seed check `ground_offset == max(0, .03 - bottom)`.
2. Add seed DNA checks (rig:437; costs from parts.json, +5 per node beyond 6):
   Merodeador 129 (already), Zancuda `20+5+25+12+10+10 + 2*5 = 92`, Babosa `15+10+20+10+10 = 65`.
3. `_test_rig()`: the check `IK reaches the rest target` has an `or` escape. Split it: if
   `rest_ankle.distance_to(l.hip) <= l.total_length() - .011` require `< .02`, else require
   `l.hip.distance_to(l.ankle) <= l.total_length()`. Count how many legs took each branch and
   print it.

Acceptance: `make godot-creature-test` still prints `0 failures`, with more checks than 1317.

### Step 2 — growth evidence + growth placement test
Growth placement is ported (`Creature._build_growth`, from rig:502-525) but has no image.
1. In `tools/render_evidence.gd` `_comparisons()`, add a shot of `tests/fixtures/studio/v3.json`
   (9 horns, mirrored, torso) plus one /4 doc built from Zancuda with three regions
   `{family: plates, surface: torso}`, `{family: tendrils, surface: neck}`,
   `{family: horns, surface: tail}` (all keys from `regionDefaults` rig:500 plus a unique `id`).
   Save `growth.png` (2 or 3 cells, 420×300, yaw .9, pitch .2, distance 8, fov 50).
2. Test (`test_creature.gd`): for each growth root, its body-space origin
   (`skeleton.get_bone_global_rest(e.bone) * e.node.position`) must equal
   `anchor(t, angle*side).p - n*.01` within 1e-4 (rig:520 `orient(root,A1,.01,...)`), and
   mirrored roots exist only when `mirror && |angle| > .04` (rig:519).

Placement math to keep (rig:518-523): `range = tail [.08,.35] | neck [.75,.96] | torso [.35,.75]`;
`along = (1-coverage)*position + coverage*(offset+.5)`; `t = lerp(range, along)`;
`A = anchor(t, angle*side)`; `basis = orient(A,.01,0,0).basis * rotX(π/2) * scale(side,1,1)`;
skin attribute = `vertex + A.p`, w = `cos(angle)`; material: tendrils → skin, else bone (rig:511).

Acceptance: `growth.png` shows horns on both flanks of the v3 creature, plates/tendrils/horns on the
named surfaces; tests pass.

### Step 3 — write `docs/godot/CREATURE.md`
Contents (keep it a reference, not a story):
1. **Setup**: files, no project settings needed beyond GL Compatibility; `make godot-creature-test`,
   `make godot-creature-evidence`; for exported builds add an export filter including
   `creature/assets/*` (GLBs and parts.json are read raw with `FileAccess`, not as imported scenes);
   `.godot/` and `*.import` are not committed.
2. **Frames**: Creature local +Z = forward, +Y = up (same as rig.js, opposite to Godot's −Z
   convention); origin on the ground; `BodyRoot.position.y = ground_offset`; skeleton/body space =
   rig.js creature-local space.
3. **API** (copy signatures from the code):
   - `Creature.parse_genome(input) -> {ok, genome, warnings, error}`; `load_genome(input)`;
     `build(genome)`; `Creature.seeds()`; `default_part(type)`; `set_skin(skin)`;
     `set_sun_direction(dir)`; signal `built`.
   - Nodes: `body_root`, `skeleton`, `body_mesh`, `limbs`.
   - Spine: `rest`, `rad`, `frames`, `anchor(t, ang)`, `orient(A, sink, rot, tilt)`,
     `mount_radius(t)`, `bone_for_t(t)`, `bone_ring`, `spine_bones`, `tail_bones`, `torso_bones`,
     `neck_bones`, `head_bone`, `root_bone`, `reset_spine_pose()`. Bone convention: every bone's
     local basis is (X = frame s (left/right), Y = frame u (dorsal), Z = spine tangent toward the
     head); root = bone nearest the widest ring; chains run outward from the root to both tips.
     A lateral bend is a rotation about local Y (`set_bone_pose_rotation(b, rest_q * Quaternion(UP, a))`).
   - Legs: `legs: Array[CreatureLegChain]` with fields (`hip_marker, upper, lower, foot,
     upper_length, lower_length, width, side, pole, home, hang, rest_knee, rest_foot, pair_index,
     front, foot_target (GLOBAL sole point), foot_yaw, foot_pitch, allow_stretch`) and
     `solve()`, `solve_local()`, `pose_rest()`, `hip_global()`; `Creature.solve_legs()`,
     `pose_legs_rest()`. State what locomotion must do each frame: move `Creature`, optionally move
     `body_root` (bob) and spine bones, set `foot_target`/`foot_yaw`/`foot_pitch`, call `solve_legs()`.
   - Data: `parts` entries `{index, type, category, side, node, t, ang, size, bone, mount,
     mount_radius, hooks}`, `growth` entries, `mass_data()`, `stats` (`dna, vel, bite, sing, hp,
     warn, speed`), `stride_hint`, `body_volume()`, `rest_aabb()`, `animation_hooks()` (hook names
     and what rig.js does with each: jaw `rotation.x`, lid `rotation.x`, sway `rotation.x`, pinch
     `rotation.y`, wing `rotation.z/.y`, arm `rotation.x`, tail `rotation.y`, sacs `scale` — rig:469-475).
   - Library: `CreatureParts.library()` (`entries`, `types`, `templates`, `material_slots`).
   - Material region names and their materials (table from studio-v4-materials.md).
4. **Visual differences that remain** (honest list; check each against the evidence images):
   - Tonemapping: Godot ACES ≠ three r128 ACESFilmic (three divides exposure by 0.6); the preview uses
     exposure 1.4 instead of 1.05, matched by eye. The stage must pick its own value.
   - No PMREM environment map; reflections/ambient come from the Godot sky. Membranes and clearcoat
     look flatter.
   - Scale crevices (Worley + derivative bump) read darker/more contrasted than in three.js.
   - Glow has no bloom (three studio had none either; the hero stage may).
   - Body is a skinned mesh (linear blend between two spine bones per ring); rig.js rebuilt the tube
     on the CPU every frame. Bending the spine strongly can pinch at bone heads; parts ride rigid
     BoneAttachment3D nodes, so the seam between a part root and the skin can open when bent.
   - Membranes use alpha blending with `render_priority`; overlapping transparent sails may sort
     differently from three.js.
   - Shadows: Godot directional shadow with bias; small peter-panning under low creatures (Babosa).
   - Ellipsoid normals are analytic (three recomputed face normals; seam at u=0 differs slightly).
   - Not ported (studio-only): spine vertebra gizmos, selection rings, rotation handle, thumbnails.
5. **Test results** line and the evidence image list.

Acceptance: every public symbol named in CREATURE.md exists (grep), and the doc names the 5 (6 with
growth) evidence files.

### Step 4 — build-time and robustness checks
1. In `test_creature.gd` add timing: build each seed 5 times, print median ms (no hard threshold;
   record the number in CREATURE.md). Do not fabricate numbers.
2. Rebuild safety: call `build()` twice on the same Creature and check child count is stable
   (`_clear()` frees everything) and `legs.size()` unchanged.
3. Bad input: `load_genome("{")` returns `ok=false` and leaves the previous creature intact
   (same `parts.size()`).

Acceptance: tests pass; timing printed.

### Step 5 — final evidence run and commit
Run `make godot-creature-evidence` (see §4), view every PNG, update CREATURE.md if anything
changed, commit images + docs. Report: files, API summary, test line, remaining differences.

---

## 3. Pitfalls (already hit, or likely)

1. **Script errors hang Godot.** A `--script` SceneTree script that fails to compile never calls
   `quit()`; under xvfb it then renders an empty window at ~900 % CPU until killed. Always run
   with `timeout`, and syntax-check first:
   `godot --headless --path godot --check-only --script res://creature/tools/<x>.gd`.
2. **Type inference**: `var x := max(a, b)` / `min` / loop vars from untyped arrays are Variant and
   fail to parse (`Cannot infer the type`). Use `maxf/minf/maxi/mini/clampf`, `var x: float = ...`,
   `for u: float in [...]`.
3. **class_name cache**: new `class_name` scripts are not visible until
   `godot --headless --path godot --import` refreshes `.godot/global_script_class_cache.cfg`
   (the make targets do it). That import can take ~1-2 min; give it a long timeout.
4. **Not inside tree in `_initialize()`**: `global_transform` errors. Tests `await process_frame`
   first (`_run()`), and use `c.transform` for the creature placed at the origin.
5. **Winding**: three.js front faces are CCW, Godot's are CW. All `CreatureGeo` indices stay in
   three.js order; only `to_arrays()` flips. GLB surfaces read from Godot are flipped *back* to
   three.js order on load (`_collect_meshes`). Mirrored parts use negative `scale.x`; Godot handles
   the determinant, so do not flip indices for mirroring.
6. **Euler order**: three's default Euler is XYZ (matrix Rx·Ry·Rz); Godot `rotation` is YXZ.
   Use `CreatureParts.set_euler()` (it builds the basis explicitly); foot yaw/pitch uses YXZ (rig:491).
7. **Basis from columns**: `makeBasis(a,b,n)` = `Basis(a, b, n)` (columns). Orthonormalize before
   `get_rotation_quaternion()`.
8. **JS rounding/truncation**: `Math.round` → `round()` (positive inputs only here); `x|0` → `int(x)`.
9. **JSON numbers** are floats in Godot; integer checks compare `float(x) == floor(float(x))`;
   `from` in migration may be `1.0`.
10. **Growth RNG**: keep everything as uint32 with `& 0xFFFFFFFF`; `imul` must split `b` into 16-bit
    halves to avoid 64-bit overflow.
11. **Shared scratchpad**: other agents write into the same session scratchpad; keep temp files in a
    subfolder (e.g. `scratchpad/cr/`).
12. **CPU**: llvmpipe uses all cores. Pass `--max-fps 15`, `nice -n 10`, keep image sizes ≤ 600 px per
    cell, and batch shots in one process (`render_evidence.gd` does ~70 shots in one run).
13. **Lighting values**: three r128 legacy lights ≠ Godot energies; the preview values (sun 2.2,
    ambient .75, exposure 1.4) were tuned by eye only for evidence. Do not present them as a match.
14. **Exports**: raw GLBs/JSON are read by path; without an export include filter the exported game
    will not find them.
15. `trompa` has jaw/sway hooks in rig.js that are never attached (rig:79); the port exposes none. Keep.

---

## 4. Evidence (software GL only)

Command (also `make godot-creature-evidence`):
```
cd godot && LIBGL_ALWAYS_SOFTWARE=1 timeout 1200 nice -n 10 xvfb-run -a \
  godot --rendering-driver opengl3 --max-fps 15 --path . \
  --script res://creature/tools/render_evidence.gd
```
`CREATURE_EVIDENCE_ONLY=parts` renders only the contact sheet; `CREATURE_EXPOSURE=<x>` overrides
the preview exposure. Single views: `tools/render_quick.gd -- <Seed|file.json> <yaw> <pitch> <dist> <out.png> [w h]`.

Files in `docs/evidence/godot/creature/` (current = present now):
| File | Content | State |
|---|---|---|
| `merodeador_vs_threejs.png` | crop of `docs/evidence/hero/grid/golden-mid.png` (360,220,560×360) beside Godot Merodeador | current |
| `g48_tail_hammer_compare.png` | top: `g48-after3.png` tail_hammer row (cells at x=180+420c, y=1860, 420×300); bottom: Godot, same studio cameras (yaw .5/1.57/2.6, dist 7/8/8, pitch .18, fov 50) | current; silhouettes and mounts match |
| `zancuda_vs_threejs.png` | g48 Zancuda side cell, Godot Zancuda eyes+legs, Godot full seed | current |
| `seeds.png` | Merodeador, Zancuda, Babosa | current |
| `parts_contact_sheet.png` | all 46 parts at `default_part()` on Merodeador (eyes+legs) | current |
| `growth.png` | step 2 | to do |

Look at every image after rendering (Read tool) and describe real differences in CREATURE.md.
