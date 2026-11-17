# PLAN-feel: faster creatures and turns that are not clunky

Branch `g-feel`. Planner: Opus. Implementer: Sonnet 5.5. Owner feedback (G77, 2026-11-16): "make the game a bit
more dynamic (faster creature?)" and "the animation for changing directions is a bit clunky still".
This plan changes no code. Every number marked *measured* was produced on this branch (commit `b90dbbc`) with
the scratch harnesses described in section 1.3. Those harnesses live outside the repository. Step S1 turns them
into committed tests.

---

## 1. Where speed, acceleration, turning and camera response come from today

### 1.1 Sources

| Quantity | Source | Value |
|---|---|---|
| Top speed (roam, heading/go) | `core/src/stage_world.c` `cp_stage_step()`: `speed = player.profile.speed * (sprint ? 1.7 : 1)` | `profile.speed` = 4 m/s for every player: it is fixed in `web/engine/profile.js` and in its port `godot/game/stage/profile.gd` (`"speed": 4.0`) |
| Sprint | same, plus stamina: -1.4 per tick while sprinting, +1 per tick otherwise, needs stamina > 2 | 6.8 m/s |
| Wild roam and chase speed | `wild_tick()`: `espeed = e->profile.speed * .7` | Garfio `speed` 5.5 (`garfio-combat.json`), so it chases at 3.85 m/s |
| Acceleration and braking | `walk()`: `v = old + (wanted-old) * (.45118836 up / .63212055 down)` per 0.1 s tick, an exponential ease (tau 0.167 s up, 0.1 s down) | no acceleration cap |
| Turn rate | `walk()`: at most 0.38 rad per tick (3.8 rad/s), using polynomial sin/cos. It does not depend on speed or body size | 218 deg/s |
| Pivot | `walk()`: `dot < -0.5` (more than 120 deg) at **any speed** sets `pivot`: the creature turns 0.9 rad per tick (516 deg/s) with `wanted = 0`, and the pivot ends at `dot > .98` | turret spin |
| Arrival braking | `stop = sqrt((remaining-.08)*12)` (6 m/s2) | |
| Slope | `step = v*.1/(1+slope*.65)` | |
| Combat arena movement | `core/src/combat.c` `turn_toward()` 0.8 rad per tick, `walk_speed()` = `prof.speed` (instant, no ease), `CB_SPRINT_SPEED` 1.25 on flee | **not touched by this plan** |
| Tick | `CP_STAGE_DT .1`, `godot/game/stage/stage_world.gd` accumulator | 10 Hz |
| Interpolation | `stage_world.gd sample()`: `lerpf` on position, `lerp_angle` on yaw between `prev` and `cur`; `vel = (cur-prev)/DT` (a step function at 10 Hz) | piecewise linear |
| Input | `godot/game/player/player_input.gd sample()`, once per tick: WASD relative to the camera through `view_yaw`, which `island.gd _update_camera()` copies from `chase.view_yaw` **every frame** | |
| Locomotion | `godot/locomotion/loco_controller.gd`: root yaw = the interpolated C yaw; `_yawrate` low-pass tau 0.1 s; bank `-atan(v*yawrate/g)*0.7`, clamped to 0.4 rad; girdle yaw toward the leading foot (gain 0.085); footstep prediction rotates the home by `clamp(_yawrate*t_mid, ±0.9)` | |
| Camera | `godot/game/player/chase_camera.gd update()`: yaw follows `player.yaw+PI` with tau 0.4 s whenever speed > 0.4, **no rate cap**; target position eased with tau 0.25 s (first order, lags v*0.25); boom tau 0.3 s | G72 port of `web/stage/camera.js` |

### 1.2 Measured current values (player = Merodeador, the default genome)

C world, flat, from `build/libcpore.a` (scratch `measure.c`):

| Measure | Walk (4 m/s) | Sprint (6.8 m/s) |
|---|---|---|
| Time to 50 / 90 / 99 % of top speed | 0.2 / 0.4 / 0.8 s | 0.2 / 0.4 / 0.8 s |
| Peak acceleration (first tick) | 18 m/s2 | 30.7 m/s2 |
| Turn radius at full speed (no slowdown in turns) | 1.05 m (lateral 15.2 m/s2, 1.55 g) | 1.79 m (25.8 m/s2, 2.6 g) |
| 90 deg turn | 0.4 s, speed kept | 0.4 s, speed kept |
| Reversal: facing reversed / 90 % speed back | 0.4 s / 0.8 s, spinning 516 deg/s at 0.07 m/s | 0.4 s / 0.8 s |
| Stop | 0.6 s, 0.23 m (peak braking 25 m/s2) | |
| Sprint duration from full stamina | | 7.2 s |

Real Godot pipeline (`StageWorld` + `PlayerInput` + `ActorHost`/`LocoController`/rig adapter on the real Merodeador
rig + `ChaseCamera`, 60 fps, flat ground; scratch `feel_measure.gd`):

| Scenario (W held 2 s, then...) | Max body yaw rate on screen | Body yaw travel | Camera yaw travel / max rate | Camera target lag | Frames with no flat planted foot | Max roll |
|---|---|---|---|---|---|---|
| W only | 0 | 0 | 0 | 0.97 m | 0 | 1.9 deg |
| **S held 4 s** | 515 deg/s | **944 deg** | **859 deg / 441 deg/s** | 0.97 m | 29 | 23.8 deg |
| **A held 4 s** | 218 deg/s | **721 deg** | **651 deg / 178 deg/s** | 0.97 m | 10 | 23.9 deg |
| D tapped 0.3 s | 218 deg/s | 85 deg | 24 deg / 89 deg/s | 0.97 m | 3 | 16.5 deg |
| click 20 m behind | 515 deg/s | 181 deg | 180 deg / 392 deg/s | 0.97 m | 23 | 18.2 deg |
| figure eight (world headings) | 218 deg/s | 632 deg | 555 deg / 155 deg/s | 0.95 m | 3 | 23.8 deg |

Planted-sole slide (rig IK, flat-footed stance) was 0.0 mm in every scenario. Foot sliding is **not** the
problem today, and the existing 20 mm gate must keep it that way.

Morphology (from `loco_morphology.gd`, scratch `c2.gd`):

| Creature | Plan | Mass | Hip h | Length | Proposal v_max / turn | Fr at 4 / 6.8 m/s |
|---|---|---|---|---|---|---|
| Merodeador | quadruped (graviportal) | 6247 kg | 1.69 m | 6.79 m | 3.02 m/s / 1.44 rad/s | 0.96 / 2.79 |
| Zancuda | horizontal biped | 3379 kg | 2.49 m | 5.87 m | 4.42 / 1.95 | 0.66 / 1.89 |
| Babosa | legless | 4870 kg | (0.73) | 4.96 m | 0.98 / 1.49 | n/a |
| Garfio | quadruped | 194 kg | 0.43 m | 1.50 m | 6.25 / 2.98 | 3.80 / 10.98 |

Baseline gates on this branch: `make test` PASS, `make tourney` PASS (worst field mean 62.3 %, worst pair 72.2 %),
`node tests/test_wasm_world.mjs` PASS. **`node tests/stage_winnability.mjs` already FAILS on b90dbbc**: biter 42 %,
spitter 76 % (both OK), **guard 100 % (window is 35-80 %)**, exit code 1. This failure exists before any
change in this plan. The rule for this plan is "no fixture moves out of the window that was not already out,
and guard does not get further from it". Fixing guard is a balance task, not part of this plan.

### 1.3 Diagnosis

1. **The direction-change "clunk" is mostly an input and camera feedback loop, not the animation.** WASD is
   camera-relative, the camera's yaw chases the creature's heading every frame, and `view_yaw` is re-read on
   every tick. Holding **S** (or A or D) therefore keeps the requested heading at a constant angle from the
   camera, and the camera keeps rotating. The creature spins in a circle of about 1 m radius forever (944 deg
   of body rotation in 4 s) while the camera whips round at up to 441 deg/s.
2. **Turret pivot.** Any turn above 120 deg, even at full speed, stops the creature dead and rotates it
   at 516 deg/s. The 10 Hz linear yaw interpolation shows this as 52 deg steps with kinks, the feet cannot
   follow, and for 0.5 s no foot is flat on the ground.
3. **Turns at speed are physically impossible for the body.** The rate is 3.8 rad/s whatever the speed or
   size, which is a 1.05 m radius for a 6.8 m-long animal (the body swings like a door). Lateral acceleration
   reaches 1.5 to 2.6 g, so the bank hits its 23 deg clamp on a 6-tonne quadruped.
4. **10 Hz polylines.** Position and yaw are linear between ticks: there is a 22 deg corner every 0.1 s
   while turning, and the velocity handed to the locomotion steps at 10 Hz (lean and gait jitter).
5. **"Slow" is mostly a matter of scale.** The default creature is 6.8 m long with a 3.9 m tall bounding box,
   so the camera sits 23.5 m away (6 h). 4 m/s is 0.6 body lengths per second at Froude 0.96, a trot that
   barely leaves a walk. Sprint (Fr 2.8) barely enters a gallop (2.5 ± 0.05).
6. Acceleration is already fast (t90 0.4 s) but harsh: an 18-30 m/s2 first-tick spike, no cap.
7. Camera position lag is v x 0.25 s (1 m at walk, 1.7 m at sprint, 2.2 m at the new sprint).

---

## 2. Targets: dynamic but readable

Spore's creature stage is used as a **qualitative** reference only. No Spore numbers were measured. Spore has
an immediate start, a brisk default jog, a clearly faster sprint, snappy turns that lean, and quick about-faces
that are animated rather than spun. Gaits are kept readable with Froude numbers: **jog = trot (Fr 1.2-2.0),
sprint = gallop (Fr > 3)**, both well clear of the 0.5 and 2.5 hysteresis bands.

On the morphology proposal (LOCOMOTION.md section 6): the Hirt mass law makes the 6.2 t Merodeador **slower**
(3.0 m/s), which is the opposite of what the owner asked for. So:

- **Turning uses the proposal, scaled.** The proposal's turn law `0.45 sqrt(M g lever / I_yaw)` behaves like
  `sqrt(g / L)`. The C rule below uses `turn0 = 1.18 sqrt(g / r_body)` (with `r_body` = the profile's
  `radius_cm`, which already exists and is already hashed). It reproduces the proposal's ratio between
  Merodeador and Garfio (2.13 against 2.07) at 1.4 times its absolute value, which is the "scaled" part.
- **Speed stays a game number,** one multiplier on `profile.speed` for everybody, checked against Froude.
  Per-creature morphology speeds are evaluated in step S9 (deferred): with the proposal's shape factors and
  a Froude anchor they would give Merodeador 4.4, Zancuda 5.9, Babosa 2.5 and **Garfio 2.5 m/s**. The
  predator would become slower than every player, which is a stage-balance change that needs the owner.

| Target (Merodeador, default player) | Now | Target | Acceptance |
|---|---|---|---|
| Jog (default) | 4.0 m/s, Fr 0.96 | **5.2 m/s** (= 1.3 x profile.speed), Fr 1.63, trot | ±0.05 |
| Sprint (Shift) | 6.8 m/s, Fr 2.79 | **8.84 m/s** (1.7 x jog), Fr 4.7, gallop | ±0.05 |
| Garfio chase | 3.85 | 5.0 (0.7 x 1.3 x 5.5): still just below the player's jog, as now | ratio chase/jog 0.96 ±0.02 |
| Time to 90 % jog / sprint from rest | 0.4 / 0.4 s | **≤ 0.4 / ≤ 0.6 s** | prototype: 0.4 / 0.6 |
| Peak acceleration | 18-31 m/s2 | **≤ 15 m/s2** (capped), braking ≤ 20 m/s2 | |
| Stop from jog | 0.6 s, 0.23 m | ≤ 0.8 s, ≤ 0.6 m (a visible plant) | prototype 0.7 s, 0.53 m |
| Max yaw rate at low speed, `turn0` | 3.8 rad/s for all | `clamp(1.18 sqrt(9.81 / r_body), 1.5, 4.5)`: Merodeador 2.0, Garfio (r 0.75) 4.3, default body 0.6 m 4.5 | |
| Yaw rate at speed | 3.8 | `min(turn0, 11.8 / v)` (lateral 1.2 g) | |
| 90 deg turn at jog | 0.4 s, 1.05 m radius, full speed | **≤ 0.8 s**, slows to ~3.7 m/s, curved | prototype 0.8 s (Merodeador), 0.6 s (small) |
| Tightest circle at jog / sprint | 1.05 / 1.79 m | ≥ 1.5 / ≥ 2.5 m for Merodeador | prototype 1.56 / 2.66 m |
| Pivot | above 120 deg at any speed, 9 rad/s | above 120 deg **only below 0.3 x jog**, `pivot_turn = clamp(2 turn0, 3, 7)` (Merodeador 4 rad/s) | |
| Reversal at jog: facing back / 90 % speed back | 0.4 / 0.8 s, turret | Merodeador ≤ 1.0 / **≤ 1.2 s**; small body ≤ 0.6 / ≤ 0.9 s; overshoot ≤ 0.6 m | prototype 1.0 / 1.1 s and 0.6 / 0.8 s, overshoot 0.47 m |
| Holding S / A for 4 s | 944 / 721 deg of spinning | straight line; body yaw travel ≤ 200 deg / ≤ 100 deg | |
| On-screen body yaw rate | 515 deg/s | ≤ 260 deg/s for Merodeador (≤ 1.1 x pivot_turn) | |
| Frames with no planted foot during a pivot (walking gaits) | 29 | **0** | |
| Max roll | 23.9 deg | ≤ 12 deg quadruped, ≤ 18 deg biped | |
| Planted-sole slide in turns (rig IK) | 0.0 mm | < 20 mm (keep the LOCOMOTION gate), target < 5 mm | |
| Camera yaw rate | up to 441 deg/s | **≤ 100 deg/s**, angular acceleration ≤ 6 rad/s2 | |
| Camera target lag, steady run | v x 0.25 s (2.2 m at new sprint) | ≤ 0.5 m at sprint; transient ≤ 1.0 m | |
| Input to first visible reaction | 0-200 ms (tick + interpolation) | head and spine start turning within 1 frame; body within 1 tick | |

The prototype numbers come from `proto2.c`, a scratch re-implementation of the rule in section 3 (flat ground,
no collisions). The implementer must re-measure them on the real `walk()`.

---

## 3. C changes (step S2)

**Scope:** only `core/src/stage_world.c` `walk()` and its two callers, plus `core/include/cpore/world.h`.
`core/src/combat.c` is **not** touched, so `make tourney`, `tests/golden/combat-*` and the combat parts of the
winnability fights are unchanged by construction. The `CpStageInput`, `CpStageSetup` and `CpCombatProfile`
layouts do not change, so the WASM `_cw_*`/`_cb_*` ABI, `cpworld.js`, the GDExtension and the log format stay as
they are.

### 3.1 Data

In `world.h`:

```c
typedef struct {
    float jog_k, sprint_k, wild_k;   /* jog = profile.speed*jog_k; sprint = jog*sprint_k; wild = speed*wild_k*jog_k */
    float accel, brake;              /* m/s2 caps on the per-tick ease                              */
    float ease;                      /* share of the remaining speed error closed per tick          */
    float turn_k, turn_min, turn_max;/* turn0 = clamp(turn_k*sqrt(9.81/r_body), turn_min, turn_max)   */
    float grip;                      /* lateral limit, m/s2: yaw rate <= grip/v                     */
    float pivot_k, pivot_mul, pivot_max; /* pivot below pivot_k*jog; pivot rate clamp(pivot_mul*turn0, 3, pivot_max) */
    float turn_slow;                 /* wanted *= (1-turn_slow) + turn_slow*max(dot,0)             */
} CpStageMotion;
extern const CpStageMotion CP_STAGE_MOTION;
```

In `stage_world.c` (literal float constants, written once):

```c
const CpStageMotion CP_STAGE_MOTION={1.3f,1.7f,.7f, 15.f,20.f,.6f, 1.18f,1.5f,4.5f, 11.8f, .3f,2.f,7.f, .4f};
```

`CP_STAGE_VERSION` goes from 1 to **2**. It is hashed, so no hash from the old rules can be mistaken for a new
one, and a replay of an old session log fails loudly instead of diverging silently. `species.speed` in
`CP_STAGE_SPECIES` is still unused (as today). Leave it alone.

### 3.2 `walk()` (replaces lines 252-296)

Signature unchanged: `walk(w, c, dx, dz, wanted_speed)`. The callers pass the jog or sprint speed (3.3).
Let `r = cp_combat_body_radius(&c->profile)` (already computed), `M = CP_STAGE_MOTION`, `jog` = the creature's
jog speed (3.3), `v = c->speed` (measured last tick, as now), and `n = |d|`.

```
if n > 1e-5: d /= n; dot = f·d; cross = f.z*d.x - f.x*d.z      (as now)
turn0     = clamp(M.turn_k * sqrtf(9.81f / r), M.turn_min, M.turn_max)
pivot_v   = M.pivot_k * jog
-- pivot state
if n > 1e-5 && !pivot && dot < -.5f && v <= pivot_v : pivot = 1      (only at low speed)
if pivot && (dot > .5f || n <= 1e-5) : pivot = 0                    (leave at 60 deg: accelerate out on a curve)
-- target speed
wt = wanted_speed * clamp(n, 0, 1)
if pivot                 : wt = 0
else if n > 1e-5 && dot < 0 : wt = 0                                 (target behind at speed: plant and brake, keep turning)
else if n > 1e-5        : wt *= (1 - M.turn_slow) + M.turn_slow * dot
-- speed: ease with caps (deterministic: only * + - and compares)
dv = (wt - v) * M.ease;  dv = clamp(dv, -M.brake*.1f, M.accel*.1f);  v += dv
if v < .015f && wt < .015f : v = 0
-- yaw: limited by size, by grip at speed, and by the pivot
rate = pivot ? clamp(M.pivot_mul*turn0, 3, M.pivot_max) : min(turn0, v > 1e-3f ? M.grip / v : turn0)
limit = rate * .1f                                                   (<= .7 rad)
rotate f toward d by at most `limit`, with the existing polynomial co/si (keep the 4th and 5th order
terms; at .7 rad the cos error is 1.6e-4 before renormalising, the same method as today)
-- move: the existing slope factor, can_walk and axis-slide code, unchanged, with step = v*.1f/(1+slope*.65f)
c->speed = measured as now; c->acceleration as now
c->turn_rate = (applied angle) * 10, with the sign; the snap branch keeps `cross` as today
```

The order matters and matches the prototype: the speed update comes first, then the yaw limit uses the new
`v`. Braking therefore buys turn rate inside the same tick, which is what makes a U-turn at speed a tight
skid-arc and not a wide loop.

Determinism: only `+ - * /`, `sqrtf` (correctly rounded in IEEE and in WASM), compares and the existing
polynomials. No `expf`, `atan2f`, `sinf` or `cosf` in the step. `-ffp-contract=off` is already forced by the
Makefile. Native == WASM is checked by `tests/test_wasm_world.mjs` (3 goldens plus 100 random 3000-tick runs
native against WASM) and `make wasm-parity`.

### 3.3 Callers

- Player, in `cp_stage_step()`: `float jog = profile.speed*M.jog_k, speed = sprint ? jog*M.sprint_k : jog;`
  (replaces `profile.speed*(sprint?1.7f:1)`). The arrival clamp `stop = sqrtf(clamp(remaining-.08f,0,1e4)*12)`
  stays. `walk(w, &w->player, dx, dz, speed)` is called with `jog` known: pass it as a new 6th argument
  `float jog` (a static function, no ABI impact).
- Wild, in `wild_tick()`: `espeed = e->profile.speed*M.wild_k*M.jog_k`, and `jog` = the same value.
- Stamina rules unchanged (sprint still lasts about 7 s).

### 3.4 Tests in C (same commit)

`tests/test_world.c`: add `motion_law()`, which drives the player on FLAT with `HEADING` orders and asserts:
t90 for jog ≤ 4 ticks and for sprint ≤ 6 ticks; per-tick Δv ≤ 1.5 + 1e-4; no pivot when reversing at full jog
(the `pivot` flag stays 0 while v > pivot_v); a pivot from v = 0.5 reverses within ceil(π/(pivot rate x 0.1))+1
ticks; the radius of a held 90 deg-off heading at jog is ≥ 1.4 m for `radius_cm` 340; per-tick |Δyaw| ≤ 0.7.
Keep `tests/test_stage_sim.mjs` unchanged: its asserts (first-tick speed < profile.speed, braking has a curve,
|Δyaw| < .7 per tick, arrival within .25 m in 6 s) hold under the new rule. Verify that they do, and do not
loosen them.

### 3.5 Golden logs: deliberate re-recording

Files: `tests/golden/world-1.hashes`, `world-42.hashes`, `world-987654321.hashes`, and the matching `.log` files
only if their bytes change. The inputs come from an LCG, independent of state; the setup line may change only
through exported defaults. **Not** `tests/golden/combat-*` (a `git diff --stat tests/golden/combat-*` must be
empty), and not the terrain goldens.

```
source ~/emsdk/emsdk_env.sh
make build/world_cli wasm
node tests/test_wasm_world.mjs --update-goldens        # writes tests/golden/world-*.{log,hashes}
node tests/test_wasm_world.mjs                          # must PASS without the flag (native == WASM, 100 random runs)
make test                                               # world_test, combat goldens unchanged
make godot && make godot-test                           # game/tests/test_world.gd replays the new goldens through CporeWorld;
                                                        # test_session.gd replays a Godot log in world_cli
```

In the same commit, write in its message the encounter counts printed by `test_wasm_world.mjs`
(baseline: 2 / 3 / 2) and why the hashes changed (CP_STAGE_VERSION 2, motion rule).

### 3.6 Balance gates

- `make tourney`: must print `tourney checks passed` with the same matrix as the baseline
  (combat.c is untouched). Any difference means something leaked into combat: stop.
- `node tests/stage_winnability.mjs` (after `make wasm`): record biter, guard and spitter. Baseline: 42 / 100 / 76 %.
  Accept if biter and spitter stay within 35-80 % and guard does not rise further (it cannot: 100 %).
  If biter or spitter leaves the window, the likely cause is approach timing (the encounter starts at 5.5 m
  and Garfio now arrives faster). Tune `wild_k` first, in 0.05 steps, never combat.
- `make stage-test` (browser) is optional for this branch. The web stage still runs on the same C world and
  only gets faster.

---

## 4. Godot changes

### 4.1 Input that does not circle (step S3), `godot/game/player/player_input.gd`, `godot/game/island/island.gd`

Root cause 1.3.1. New rule: **latch the input frame.**

- `player_input.gd`: add `var frame_yaw = null` and `var _last_keys := 0` (a bitmask of forward/back/left/right).
  In `sample()`, compute `mask`. If `mask != 0 and (frame_yaw == null or mask != _last_keys)`, set
  `frame_yaw = view_yaw`. If `mask == 0`, set `frame_yaw = null`. Use `frame_yaw` (not `view_yaw`) in
  `camera_relative()`. Store `_last_keys = mask`.
  Effect: holding S runs straight toward where the camera was when S was pressed. W then S re-latches,
  so S means "back toward the camera", a reversal. A held means "to screen-left at press time", a
  straight run.
- Manual orbit (`chase.orbit`) re-latches immediately: `island.gd _unhandled_input` sets
  `player_input.frame_yaw = chase.view_yaw` after `chase.orbit(...)` while keys are held, so steering with the
  mouse still works.
- Add `func intent_yaw() -> Variant` (the world yaw of the current keys, or of the destination, or null).
  It is pure, reads the keys without side effects, and `island.gd` calls it every frame for 4.4.
- `test_input.gd`: add "holding back for 40 ticks with a rotating view_yaw gives a constant heading", and
  "W -> S re-latches".

Alternative (owner decision, not the default): Spore-style tank steering (A/D rotate, W/S forward/back relative
to the creature). The latch is the default because click-to-walk and the fight camera already assume
camera-relative movement.

### 4.2 Heading and position interpolation (step S4), `godot/game/stage/stage_world.gd`

Replace linear `sample()` with a **C1 Hermite with one-sided tangents (no added latency)**:

- Keep `pprev` (the state before `prev`). In `step_once()`: `pprev = prev; prev = cur; cur = world.state()`.
  In `reset()`: `pprev = prev = cur`.
- For entity `id`, with `a` = alpha and the basis `h00=2a³-3a²+1, h10=a³-2a²+a, h01=-2a³+3a², h11=a³-a²`:
  - Position: `P0 = prev, P1 = cur, m1 = P1-P0` (this tick's chord), `m0 = P0-PP` (last tick's chord). This is C1
    at tick boundaries, because the end tangent of tick k equals the start tangent of tick k+1. Overshoot guard:
    `if m0.length() > 3*m1.length(): m0 *= 3*m1.length()/m0.length()` (stops and collisions).
    `pos = h00 P0 + h10 m0 + h01 P1 + h11 m1`. It passes through the C points exactly.
  - Velocity: the analytic derivative / DT, with `h00'=6a²-6a, h10'=3a²-4a+1, h01'=-6a²+6a, h11'=3a²-2a`.
    This replaces the 10 Hz step `(c-p)/DT`, so the controller's `_acc`, lean and gait see a continuous signal.
  - Yaw: unwrap `y0 = yaw(prev)`, `y1 = y0 + wrapf(yaw(cur)-y0, -PI, PI)`, `m1 = y1-y0`,
    `m0 = wrapf(yaw(prev)-yaw(pprev), -PI, PI)`; **monotone limiter** (Fritsch-Carlson): if `m0*m1 <= 0` then
    `m0 = 0`, else `m0 = sign(m1)*min(|m0|, 3|m1|)`. Same Hermite. This removes the wobble when C snaps to the
    target heading after a limited turn.
  - **Discontinuity guard:** if `|P1-P0| > 2.5 m` (respawn, fight start or end, or arena placement; the fastest
    legal tick is 0.9 m), or `pprev` is a different `active` fight state, use `PP = P0` and `m0 = m1`
    (linear for that tick).
  - `speed` = `vel.length()` (continuous) instead of `c.speed`. Keep `c.speed` as `"speed_c"` for the UI and
    audio thresholds.
- Tests (`test_world.gd` or a new `test_interp.gd` in `run_m0_tests.gd`): `sample(id, 0)` == prev position and
  `sample(id, 1)` == cur position (to 1e-6); the velocity is continuous across a tick boundary (|Δv| < 0.05 m/s
  on a 90 deg turn at jog); the yaw is monotone within a constant-direction turn; the respawn jump has no
  overshoot.

### 4.3 Locomotion turning (step S5), `godot/locomotion/loco_controller.gd`

All in `_sub()`, numbered by its existing sections:

1. **Bank (section 12).** Replace `bank_gain := 0.7` and the 0.4 clamp with per-plan values:
   `bank_k` = quadruped 0.35, horizontal_biped 0.5, upright_biped 0.6, multi 0.2, legless 0.0, monopod 0.4, and
   `bank_max` = 0.20 rad for quadruped and multi, 0.30 for bipeds and monopod.
   `bank_t = clamp(-atan(_speed_f*_yawrate/G)*bank_k, -bank_max, bank_max)`. Spring unchanged.
2. **Spine follows the path (section 14a).** After `yw` is computed per station:
   `kappa = _yawrate / max(_speed_f, 0.5)` (path curvature, 1/m), and
   `yw += clamp(kappa * (zs - morph.com.z), -0.35, 0.35)`. Front stations yaw into the turn and hind stations
   yaw out, so a 6.8 m body bends along a 1.5-3 m arc instead of swinging like a door. Keep the existing
   `_lp(0.04)` filter. `spine_at()` and `pose.hips` pick it up unchanged.
3. **Plant and pivot (section 3 / 4).** `pivoting = absf(_yawrate) > 1.2 and _speed_f < 0.25*sqrt(G*_ref_h)`.
   `r_feet` = the mean horizontal distance of the leg homes from the centre of mass (computed once in `setup`).
   `v_rot = absf(_yawrate)*r_feet`. While pivoting:
   - gait = the lowest rung of `Gait.ladder(morph)` (walk or tripod), so support is diagonal or lateral;
   - `cadence = max(_speed_f, v_rot) / max(stride, 1e-4)`, with `stride_t` computed from
     `Gait.stride_length(gait, Gait.froude(v_rot, _ref_h), _ref_h)`;
   - `moving = true` (legs step around), `crouch_t += 0.05` (a slight plant);
   - for quadrupeds, hind legs get `_off` from the walk ladder, so the body visibly turns on its feet and
     not on its centre.
   The footstep yaw prediction clamp `clamp(_yawrate*t_mid, -0.9, 0.9)` (section 5/6) becomes ±1.2.
4. **Support guarantee (section 5/6).** Before a leg starts a swing (`in_window and want`), count the stance legs.
   If `stance_after < max(1, ceil(n_legs/2))` and the leg is not `force`d, defer it (keep it planted; it will
   lift next substep). At most one `force`d lift per 0.05 s. This removes the 29 frames with nothing planted
   during a pivot.
5. **Gait dwell.** `Gait.select` result is only adopted if `time - _gait_t >= 0.3`; set `_gait_t = time` on each
   change. This stops walk-trot-walk flicker through a U-turn's brake and re-acceleration. Phase continuity: `phase`
   and `l.theta` are never reset on a gait change or a pivot (they are not today); the new offsets blend in
   through the existing `rate = f_eff*clamp(1+3*wrap(...), 0.5, 1.8)` phase coupling.
6. **Intent anticipation** (new `var intent_yaw = null`, `func set_intent(y)`, called by the actor driver):
   `d = wrapf(intent_yaw - yaw, -PI, PI)`. Neck yaw target `+= clamp(0.6*d, -0.6, 0.6)`. Front stations
   (`zs > com.z`) add `clamp(0.25*d, -0.3, 0.3) * (zs-com.z)/(0.5*body_length)` to `yw`. The head and shoulders
   start the turn within one frame of the key press, and the body follows on the next tick.

Wiring: `godot/game/actors/actor_driver.gd update()` accepts an optional `s.intent` and calls
`controller.set_intent(s.intent)`. `island.gd _update_actors()` adds `intent = player_input.intent_yaw()` to the
player's sample only.

Tests: `make godot-loco-test` stays at 192 checks with 0 failures (foot slide < 20 mm, CoM, gait transition
within ±0.15). Add to `locomotion/test/run_tests.gd`: a pivot scenario per plan (feed yaw at 4 rad/s, speed 0):
zero frames without a planted foot for walking gaits, planted-ball slide 0.00 mm, roll ≤ bank_max. A curved-run
scenario: spine end-to-end yaw sign matches the turn.

### 4.4 Camera (step S6), `godot/game/player/chase_camera.gd`

- **Position:** `goal = player + vel_s * lead`. `vel_s` is the Hermite velocity, low-passed with tau 0.15 s.
  `lead = 0.12`, `target = target.lerp(goal, 1 - exp(-dt/0.12))`. The steady lag is zero, transients last
  about 0.12 s, and the 10 Hz jitter is gone because the velocity is continuous (4.2). Keep the ridge safety
  clamp unsmoothed. The `update()` player dict gains `vx, vz` (the island passes `p.vel`).
- **Yaw follow:** desired `yaw_goal = player.yaw + PI`, error `e = wrapf(yaw_goal - yaw, -PI, PI)`.
  - Auto-follow only if `speed > 0.4`, `manual == 0`, the creature is not pivoting (`absf(yaw rate) < 2.5`),
    and `absf(e) < deg_to_rad(110)` (it is running away from or across the camera, not toward it). Running toward
    the camera does not swing it; the latched input (4.1) keeps that stable.
  - Rate: `w_goal = clamp(e/0.5, -1.75, 1.75)` rad/s (tau 0.5 s, cap 100 deg/s). Then
    `w = move_toward(w, w_goal, 6*dt)` (angular acceleration ≤ 6 rad/s2), then `yaw += w*dt`.
  - Engage delay: the heading must have been within ±20 deg of its value 0.25 s ago (keep a 0.25 s ring of yaws)
    before auto-follow ramps in. A tap of D does not swing the camera.
- **Speed cues (optional, owner check):** FOV +5 deg (eased with tau 0.3 s) above 0.8 x sprint, boom x1.06.
  Off by default behind `Game.settings.camera_kick`.
- `test_camera.gd`: keep the zoom, orbit-grace and fight-framing checks. Change the auto-follow check to the
  new rule, and add: max |Δyaw|/dt ≤ 1.75 rad/s + ε in a scripted reversal, steady target lag < 0.05 m at
  8.8 m/s.

Not touched: fight framing (`fight_blend`, separation boom), pitch from zoom, and occlusion pull-in.

---

## 5. Ordered steps (one commit or more each; every step ends green)

Common gate for every step, unless the step says otherwise: `make test`, `make tourney`, `make godot-test`,
`make godot-play-test`, `make godot-loco-test` all pass. Run every Godot command under `timeout` and with
`--check-only` first for new scripts.

**S0. Baseline record.** Run the five targets plus `node tests/stage_winnability.mjs`, and write the numbers
into the step-S1 evidence file. Expected: the measurements of section 1.2, with winnability guard 100 %.

**S1. Feel measurement as a committed test** (no behaviour change).
`godot/game/tests/feel_test.gd` plus `make godot-feel-test` (headless, `--fixed-fps 60`, timeout 600).
It ports the scratch harness: `StageWorld` (FLAT, flat_height 0, no wild, no obstacles) + `PlayerInput`
with `keys_override` + `ActorHost` with `Creature.seeds().Merodeador` + `ChaseCamera`, `view_yaw` fed back every
frame as in `island.gd`. Scenarios: W; W then S; W then A; W then a 0.3 s tap of D; a click 20 m behind; a
figure eight (heading `(cos 1.2t, cos 2.4t)`, 10 s). It also runs a C-only part over `CporeWorld.step()`:
t50/t90/t99 for jog and sprint, peak acceleration, 90 deg time and minimum speed, tightest circle radius,
reversal (facing back and 90 % speed back, overshoot), stop time and distance.
Per scenario it reports: max on-screen yaw rate, body and camera yaw travel, max camera yaw rate, camera target
lag, max planted flat-sole slide (rig IK `leg.foot.global_position` while `pose.contact` and
`foot_pitch < 0.01`), frames without a planted foot, and max roll.
It writes `docs/evidence/godot/feel/measurements.json` and, in this step, gates nothing but finiteness.
It must reproduce section 1.2 within ±5 %.

**S2. C motion rule** (section 3). Acceptance: `feel_test` C part, Merodeador (`radius_cm` from its profile; the
Godot setup supplies it):
t90 jog ≤ 0.4 s, sprint ≤ 0.6 s; peak acceleration ≤ 15 m/s2; 90 deg at jog ≤ 0.8 s; circle ≥ 1.5 m at jog
and ≥ 2.5 m at sprint; reversal 90 % speed back ≤ 1.2 s with overshoot ≤ 0.6 m; stop ≤ 0.8 s.
Goldens re-recorded per 3.5; tourney identical; winnability per 3.6. **Run `make godot` before `godot-test`.**
LOCOMOTION.md section 6 gets a line: "C now uses jog = 1.3 x profile.speed and turn0 = 1.18 sqrt(g/r_body); the
mass law is not used for speed (see PLAN-feel)."

**S3. Input latch** (4.1). Acceptance: `feel_test` S held 4 s gives body yaw travel ≤ 200 deg and a straight
path (lateral deviation after the reversal < 0.5 m); A held 4 s gives travel ≤ 100 deg. `test_input.gd` new
checks pass.

**S4. Hermite interpolation** (4.2). Acceptance: the 4.2 tests; in `feel_test`, the yaw-rate signal has no
discontinuity bigger than 0.5 rad/s between consecutive frames in a steady curve (now it jumps at each tick);
the on-screen yaw rate stays ≤ 1.1 x the C rate.

**S5. Locomotion turning** (4.3), in this order with a commit each: bank, spine-follows-path, support guarantee,
pivot stepping, gait dwell, intent. Acceptance after all of them: frames without a planted foot during the
reversal and click-behind scenarios = 0; max roll ≤ 12 deg (Merodeador); planted-sole slide < 20 mm in every
scenario (target < 5 mm); gait changes during the figure eight ≤ 2 per lobe; `godot-loco-test` 0 failures.

**S6. Camera** (4.4). Acceptance: camera yaw rate ≤ 100 deg/s in every scenario; camera yaw travel in the
"S held" scenario ≤ 200 deg; steady target lag ≤ 0.5 m at sprint; `test_camera.gd` passes.

**S7. Frame strip of a figure eight.** `godot/game/tests/feel_evidence.gd` plus
`make godot-feel-evidence`:
`LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot --script res://game/tests/feel_evidence.gd -- $(CURDIR)/docs/evidence/godot/feel`.
It loads the island (`grass` 3000 blades, as in the play test), drives the figure eight with `--fixed-fps 30`
time stepping, and captures 16 frames over one loop from a fixed high camera (top three-quarter view) plus 16
from the chase camera. It writes `fig8_top.png` and `fig8_chase.png` (4x4 contact sheets) and `fig8_path.png`
(the C path in white, the Hermite path in orange, footfalls as dots). The owner looks at the sheets.
Also a reversal strip `reverse_chase.png` (8 frames).

**S8. Docs.** `docs/godot/FEEL.md` (what changed, the measured before/after table from `measurements.json`,
what is not verified); README "How it feels" numbers; WIRE.md note about the input latch.

**S9 (deferred, owner decision).** Per-creature motion from morphology: a `CpStageMotion` override in
`CpStageSetup`/`CpStageSpawn` (zero = derived), log format `CPORE_WORLD_LOG 2`, `world_log.gd`, `world_cli`,
`cpworld.js` and the GDExtension `reset()`. It is not done now because the measured morphology speeds put Garfio
(2.5 m/s) far below every player, which changes stage balance (section 2).

---

## 6. Risks

- **Stage balance.** The faster approach and chase change when encounters start. Combat itself is untouched, but
  `stage_winnability` is already out of its window for guard (100 %) on the base commit. Do not mistake that for a
  regression, and do not "fix" it by tuning motion. If biter or spitter moves out, tune `wild_k` only.
- **Old logs.** CP_STAGE_VERSION 2 invalidates every saved session log and the LLM benchmark's recorded runs.
  This is intended and must be stated in the S2 commit and in docs/WORLD.md.
- **The determinism trap.** A `sinf`, `cosf`, `expf` or `atan2f` in `walk()` would break native == WASM. Only
  `sqrtf` and the polynomials are allowed. The 100 random native/WASM runs in `test_wasm_world.mjs` are the gate.
- **The pivot rate at 0.7 rad per tick** sits at the edge of the 4th-order cos. It still behaves the same way
  (renormalised, deterministic), but the snap test `dot >= co` becomes slightly loose. Keep `pivot_max ≤ 7`.
- **Hermite and fight arena teleports:** the discontinuity guard must catch fight start and finish (the
  creatures are moved into the arena frame). Test it in `play_test` (an encounter happens there).
- **Camera latch and click-to-walk interplay:** clicking while keys are held must still clear the latch (the
  destination path ignores `frame_yaw`).
- **The input latch changes how controls feel** (A runs left in a straight line instead of circling). It is
  the owner's call; the tank alternative is noted in 4.1.
- **Support guarantee and very fast pivots:** deferring lifts can stretch a leg to its reach limit; `force`
  remains the escape hatch (one per 0.05 s). Check the hexapod and the biped in `godot-loco-test`.
- **Software GL only:** frame rates and camera comfort on a real GPU are not verified; the owner must play.
- **Parallel branch `g-actions` (G77 action animation)** probably edits `loco_controller.gd` and
  `actor_driver.gd`. Keep the S5 edits in separate small hunks and merge g-feel after g-actions (or rebase S5).
- **Scale is the real "slowness"**: Merodeador is 6.8 m long. If 5.2 / 8.8 m/s still reads as slow, the next
  levers are the camera distance (6 h -> 5 h, G72 number, owner) or S9, not a higher `jog_k` (Fr > 2.5 at jog
  would make the default gait a gallop).

## 7. Measurement harness (scratch, not committed)

Kept outside the repository: `measure.c` (current C rule), `proto.c` and `proto2.c` (the proposed rule),
`feel_measure.gd` (the real Godot pipeline) and `c2.gd` (morphology table). Step S1 reimplements them as
`feel_test.gd`. The Godot harness printed engine `!is_inside_tree()` errors from creatures built before they
entered the tree in `_initialize`. They do not affect the numbers, and `feel_test.gd` must add nodes to the tree
before use (the play test's "no engine errors" hook will catch it).
