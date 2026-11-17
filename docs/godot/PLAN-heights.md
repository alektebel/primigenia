# PLAN-heights: F4, the C world walks on the generated island

Status: **plan, 2026-11-17.** Roadmap C0 item F4; BACKLOG item 6; the gap documented in
`docs/godot/M0.md` "C world gap". Planner: Opus. Implementer: Sonnet; steps marked **[CORE]** touch
`core/` or `apps/` and may go to Codex (`make test` green, goldens untouched unless stated).
Shared core sequencing with `PLAN-devtools.md` §6.

## 1. Today

* Godot runs the C world with `terrain = CP_STAGE_FLAT`, `flat_height = 42` (valley floor) and one
  water circle (`game/stage/stage_setup.gd`). C clamps everything to ±195 m (`cp_stage_can_walk`,
  `cp_stage_reset`, `cp_stage_order` GO, all in `core/src/stage_world.c`).
* The island (seed 1, `CporeTerrain.generate`, defaults: n = 1024, size 3600 m, cell 3.516 m) is
  drawn and creatures are *drawn* at `Game.ground(x, z)` = `TerrainData.ground()` (exact LOD0 surface),
  but C moves them on a plane: slopes do not slow them, cliffs and sea do not stop them, and the world
  ends at ±195 m. `stage_ui.gd` uses `FLAT_HEIGHT` for ambience.
* Combat (`combat.c`) runs on its own flat 40×40 m arena (`s.flat = 1`), mapped back to stage x/z.

## 2. Decisions

### 2.1 The C sim reads the generator's own height array (no second source)

The heights already come from C (`cp_terrain_generate`), are hashed (`cp_terrain_hash`) and cached on
disk by Godot with a hash check on load (`terrain_cache.gd`). So the sim does not regenerate or
resample anything: **Godot hands C a pointer to the same float32 arrays the renderer uses.**

```c
/* world.h */
struct CpStageField {
    int32_t n; float size_m, cell, half;      /* cell = size_m/n, half = size_m/2 */
    const float *height;                      /* n*n metres, row-major j*n+i (z rows, x columns) */
    const float *water_level;                 /* n*n, depression-filled level (pond test), may be NULL */
    uint64_t hash;                            /* cp_terrain_hash of the generated terrain */
};
int cp_stage_attach_field(CpStageWorld *w, const CpStageField *f);  /* before reset; NULL detaches */
```

* New terrain mode `CP_STAGE_FIELD = 2` in the existing `setup.terrain` int (**no `CpStageSetup`
  layout change**, so the Python binding and WASM API keep their sizes).
* `cp_stage_reset` with `terrain == FIELD` requires an attached field (else -1); it stores
  `w->field_hash = field->hash` (the field pointer survives reset's memset, PLAN-devtools step 3).
  The field hash is folded into `cp_stage_hash` only in FIELD mode, so analytic/flat hashes and the
  three golden world logs are unchanged.
* The pointer is not owned by C. In the extension, `CporeWorld` keeps `PackedFloat32Array` members
  (copy-on-write refcounted: holding a reference keeps the buffer alive and its address stable while
  nobody writes to it; TerrainData never writes after load).
* Identity: the replay/scenario carries the terrain seed, n and the hash; `world_cli` regenerates the
  terrain from those (3.6 s at n = 1024, < 0.5 s at 256) and refuses to replay on a hash mismatch.

### 2.2 One ground formula, written twice, tested equal

`cp_stage_ground` in FIELD mode is a line-by-line port of `TerrainData.ground()` (cell-centred
samples, two triangles per quad with the (i+1, j)–(i, j+1) diagonal, clamped at the edge):

```c
float u=(x+f->half)/f->cell-.5f, v=(z+f->half)/f->cell-.5f;
int i=clampi(floor_int(u),0,f->n-2), j=clampi(floor_int(v),0,f->n-2);
float fu=clamp(u-i,0,1), fv=clamp(v-j,0,1); const float *h=f->height+j*f->n+i;
return fu>=fv ? h[0]+fu*(h[1]-h[0])+fv*(h[f->n+1]-h[1])
              : h[0]+fv*(h[f->n]-h[0])+fu*(h[f->n+1]-h[f->n]);
```

Only `+ - * /` and the existing `floor_int`, so it is deterministic under the project flags
(`-fno-fast-math -ffp-contract=off`). GDScript evaluates the same formula in float64 over the same
float32 samples; the difference is ~1e-5 m. Agreement gate: **≤ 1 mm** at every sampled point.
(Why not call C from GDScript's `Game.ground`? `ground()` is called thousands of times per frame by
grass, pointer and camera; keeping it in GDScript avoids a world dependency for the renderer and the
test proves both agree.) `cp_stage_height` returns the same value in FIELD mode.

### 2.3 Water and bounds

* `float cp_stage_water_depth(const CpStageWorld *w, float x, float z)`: FIELD mode, nearest cell `k`:
  sea `max(0, -height[k])`; pond (`water_level[k] - height[k] > 0.5 && height[k] > 0`, the same test as
  `TerrainData.is_pond`) `water_level[k] - height[k]`; else 0. FLAT keeps its circle, ANALYTIC 0.
* `float cp_stage_bound(const CpStageWorld *w)`: 195 for ANALYTIC/FLAT (unchanged numbers), FIELD
  `half - 2*cell` (≈ 1793 m). Every literal `195` in `stage_world.c` (reset checks of nest/wild, GO
  order, `can_walk`) becomes `cp_stage_bound(w)`. Reset validates against the bound of the mode it is
  resetting into (attached field known before reset).
* `cp_stage_can_walk` in FIELD mode: the existing slope rule (`|Δh| per 0.25 m sub-step > 1.2×run +
  0.04` blocks, i.e. ≈ 50°), plus **blocked where `water_depth > 0.7 m`** (replaces `height < -0.7`,
  which also works for the sea: wading in the shallows is allowed, swimming is C4). Obstacles as today.
* `walk()` is unchanged: its slope slow-down (`step / (1 + slope*0.65)`) and axis-separated sliding
  now act on real terrain.

### 2.4 Combat on terrain

`combat.c` stays flat and untouched (combat goldens and `make tourney` identical). In FIELD mode,
after `cp_combat_step` maps positions back (in `fight()`), each fighter's move from its previous stage
position is checked with `cp_stage_can_walk`; a rejected move keeps the old stage x/z **and writes it
back into `w->combat.c[i].x/y`** (arena coordinates), so both views stay consistent and deterministic.
The fight start (`start()`) is unchanged. Effect: a charge into a cliff or a dash into the lake stops at
the edge. Only FIELD mode does this, so flat/analytic runs and their hashes are unchanged.

### 2.5 WASM / Python parity

The web stage is reference-only since G76; the official determinism target that matters is native
x86-64. FIELD mode is **not exposed** to the WASM world API (`apps/world_wasm_api.c` unchanged; `make
world-test` must still pass where emcc exists) nor to the Python binding in this phase (the agent
harness keeps flat/analytic worlds; a follow-up can add `attach_field` to `bindings/python`).
The code itself is portable (no transcendental functions), so parity is a later, cheap addition.

### 2.6 Performance

No copies: 2 × 4 MB arrays referenced. Per tick per creature: `walk` does 2 ground samples + up to 3
`can_walk` calls of ⌈d/0.25⌉ + 1 samples (≈ 5 at sprint) → < 40 samples, each a handful of flops.
Budget: `cp_stage_step` with 1 player + 24 wild < 50 µs (measured in H6; today's flat step is the
baseline).

## 3. Steps

### H1 · [CORE] Field mode in the stage world
Files: `core/include/cpore/world.h`, `core/src/stage_world.c`, `tests/test_world.c`.
Do §2.1–2.3: `CpStageField`, `CP_STAGE_FIELD`, `cp_stage_attach_field`, FIELD branches in
`cp_stage_height/ground`, `cp_stage_water_depth`, `cp_stage_bound`, `can_walk`, reset validation,
hash rule. Prerequisite: PLAN-devtools step 3 (the `field` pointer slot at the end of the struct).
Tests (`make test`): the three golden world logs and combat goldens unchanged; a synthetic 64×64 field
(plane tilted 10°, a 60° wall band, a sea strip, a pond): ground equals the formula at 1000 points
(exact float compare against a reference implementation in the test), on a plane it is exact; walking
up the 10° plane is slower than flat by the `walk` factor; the wall and the pond block; the sea blocks
deeper than 0.7 m and allows wading; reset without a field in FIELD mode returns -1; two identical runs
give identical hashes; a different field hash gives a different state hash.

### H2 · [CORE] Combat clamp on terrain
Files: `core/src/stage_world.c`, `tests/test_world.c`.
Do §2.4. Tests: a fight forced next to the synthetic wall (player at the wall, Garfio charging into it)
never puts either fighter where `can_walk` from its previous position fails; combat state and stage
state agree (`|stage - (arena + combat - 20)| < 1e-4`) every tick; flat-mode fight hashes unchanged
(`make tourney`, golden 42).

### H3 · [CORE] Replays with a field: world_cli and a field golden
Files: `apps/world_cli.c`, `tests/golden/world-field-1.log` + `.hashes` (new), `Makefile`
(`world-test` replays it).
* Log v3 (PLAN-devtools step 4) gets an optional line after the header:
  `field <terrain_seed> <n> <size_m> <hash16>`. `world_cli --replay` on such a log runs
  `cp_terrain_params_default`, sets seed/n/size, `cp_terrain_generate`, compares `cp_terrain_hash` with
  the line (error "terrain hash mismatch: log made with generator v3 hash X, this build gives Y"),
  attaches the field and replays.
* `world_cli --field <seed> <n>` recording mode: the existing scripted 300-tick run but on that field
  (nest = nearest walkable cell to the valley centre, Garfio 60 m away on a walkable gentle straight
  path, same rule as `stage_setup.find_home`), writes the v3 log. Record `world-field-1` once at
  **n = 256** (fast in tests). Justification: a new mode needs its own golden; no existing golden is
  re-recorded.
Tests: replay reproduces the committed hashes; a log whose `field` hash is edited fails with the
sentence.

### H4 · Extension: attach the island
Files: `godot/extension/cpore_world.{h,cpp}`, `godot/game/tests/test_world.gd`.
* `CporeWorld.set_field(entry: Dictionary) -> int`: takes the TerrainData entry (`n`, `size_m`,
  `height`, `water_level`, `hash` hex text), validates sizes (`n*n`), keeps the two
  `PackedFloat32Array`s as members, fills a `CpStageField` member, calls `cp_stage_attach_field`.
  `clear_field()`. `water_depth(x, z)`, `bound()`. `reset()` with `terrain: 2` and no field returns -1
  and `last_error()` says "terrain 2 needs set_field() first".
* `get_setup()`/log: `StageWorld.export_log()` writes the `field` line from the attached entry
  (`world_log.gd` v3).
Tests: the seed-1 cached island attaches; `CporeWorld.ground == TerrainData.ground` at 10 000 points
(5 000 uniform over the whole island, 2 000 along chunk edges `k*64*cell`, 2 000 on rock cells
(`material == ROCK`) where slopes are steep, 1 000 within 2 cells of the map edge): max |Δ| ≤ 1 mm;
`water_depth > 0` exactly on `is_sea`/`is_pond` cells; a Godot session on the field replays in
`world_cli` (extends `test_session.gd`).

### H5 · The game uses the field
Files: `godot/game/stage/stage_setup.gd`, `godot/game/island/island.gd`, `godot/game/stage/stage_ui.gd`,
`godot/game/tests/{play_test,test_session}.gd`, `docs/godot/M0.md` (gap section), `godot/README.md`.
* `StageSetup.build`: `terrain = 2`, no `flat_height`, `water = Vector3.ZERO` (ponds come from the
  field), `BOUND` replaced by `world.bound()` (or `data.half - 2*data.cell`); `find_nest`/`find_home`
  keep their rules but also require `CporeWorld.can_walk` along the path; `water_circle()` stays only
  for the feel test's flat setups (or is deleted if unused).
* `island._build_stage`: `stage.world.set_field(Game.terrain)` before `reset`.
* `stage_ui.gd`: ambience height = `pos.y - valley_floor_m` (terrain params) instead of
  `FLAT_HEIGHT`; delete the constant.
* `feel_test.gd` already builds its own flat setup (`terrain = 1`, flat 0): it must stay flat (it
  measures motion on flat ground), so `make godot-feel-test` numbers are unchanged; check it.
Tests: `make godot-play-test` green with the field (the encounter still happens: Garfio's home is 60 m
away on a gentle path); `test_session` replays; a 3000-tick scripted walk (random headings, fixed seed,
sprints) on the island never puts an entity where `water_depth > 0.7` or outside the bound, and the
rendered actor y equals `CporeWorld.ground` at the C position (≤ 1 mm, interpolation aside: compare
at tick boundaries, alpha 0).

### H6 · Agreement, stuck and performance checks
Files: `godot/game/tests/test_heights.gd`, Makefile `godot-heights-test`
(`nice -n 10 timeout 600 $(GODOT) --headless --path godot --script res://game/tests/test_heights.gd`).
* Walk the player by GO orders to 20 points spread over the island (nearest walkable to a 5×4 grid):
  each run either arrives or is reported as blocked with the blocking reason (slope / water / bound);
  print a table; fail if > 4 of 20 are unreachable from the nest or any run oscillates in place for
  > 50 ticks with a GO order active ("stuck": position change < 0.05 m/tick while the target is > 2 m).
* Garfio chase from 10 random homes on slopes: no fighter ends a tick in water or on a > 50° slope.
* Timing: 10 000 `cp_stage_step` with 24 wild on the field vs flat; record both in
  `docs/evidence/godot/heights/timings.json`; gate field < 2× flat and < 50 µs/step.
Evidence: **one** software screenshot `docs/evidence/godot/heights/far-slope.png` (player ~600 m from
the nest on a slope, feet on the ground), via a small `heights_evidence.gd` under xvfb.

## 4. Goldens

Unchanged and asserted unchanged: `tests/golden/world-{1,42,987654321}`, all combat goldens,
`make tourney`, the feel measurements. New: `world-field-1` (H3), `world-debug-42` (PLAN-devtools
step 4). Nothing is re-recorded.

## 5. Risks

* **Caves:** the heightfield has notches at cave entrances but no interior; C cannot enter a cave
  until a cave graph exists (C4/C5). Sites list cave entrances; `tp` into a cave mouth lands on the
  notch floor. Document; no fix in C0.
* **Unreachable or stuck spots:** the 50° rule plus coarse 3.5 m cells can create narrow ledges where
  the axis-separated slide jitters. H6 measures it; if it shows up, the fix is in `walk()` (FIELD mode
  only) and is a separate decision.
* **Encounter balance:** the playable area grows from 390 m to ~3.6 km; wild density and Garfio
  aggression were tuned for the valley. Gameplay content is C1/C2; only the existing encounter is gated.
* **Fight clamp** changes fight outcomes near walls in FIELD mode (winnability fixtures are flat and
  unaffected). Owner may prefer refusing fights next to cliffs instead; ask.
* **Python/WASM** do not get FIELD mode in C0; agents that play through `bindings/python` still play the
  flat world. The Godot agent socket (PLAN-devtools step 12) plays the real field.
* **Cache vs generator version:** a `CP_TERRAIN_VERSION` bump changes the field hash, so saved
  scenarios on the old island fail loudly (PLAN-devtools §1.4 rule 2) and replays need the old build.
  Expected and documented.
