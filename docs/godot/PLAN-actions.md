# Plan: procedural action animation (G77, `godot/actions/`)

Written by the planning agent (Fable 5.2) for the implementing agent (Sonnet 5.5). Branch
`g-actions`, worktree `/home/diego/Desarrollo/cpore-wt/g-actions`. Read
`_agent/briefs/common.md` and `_agent/briefs/godot-common.md` first, then `docs/DESIGN.md`
G73, G75, G77, `docs/COMBAT.md` (move data, tick contract), `docs/P4.md` 2.1 and its addendum,
`docs/godot/CREATURE.md`, `LOCOMOTION.md`, `WIRE.md`, `UI.md`.

State checked on commit `b90dbbc` by reading the code and by one headless probe of the real rig
(numbers in section 0.4). Nothing in `godot/` was changed by the planner. The GDExtension is
**not built** in this worktree: run `make godot` once before anything that needs `CporeWorld`
(steps 9 onward); steps 0 to 8 run without it.

Always wrap Godot in `timeout`, check new scripts with
`godot --headless --path godot --check-only --script <file>`, send output to a file, use
`nice -n 10`. Renders: `xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 ... --rendering-driver opengl3`.

You may create `godot/actions/` (all new code), `docs/godot/ACTIONS.md`,
`docs/evidence/godot/actions/`, two Makefile targets, and make the **small, listed** edits to
`godot/locomotion/loco_rig_adapter.gd`, `loco_controller.gd`, `locomotion/test/capsule_rig.gd`,
`godot/game/actors/actor_driver.gd`, `actor_host.gd`, `godot/game/island/island.gd`,
`godot/game/stage/stage_ui.gd`, `godot/game/tests/play_test.gd`. `core/` is not touched. The
one optional edit to `godot/extension/cpore_world.cpp` (step 10b) only exposes fields that
already exist in the C structs.

---

## 0. Facts the design rests on

### 0.1 What Godot gets from C (read only)

`StageWorld` (`game/stage/stage_world.gd`) steps the C world at 10 Hz and keeps `prev`, `cur`
and `alpha()` (0 just after a tick, near 1 just before the next). Per tick:

- `cur.entities[id]`: `x, z, fx, fz, hp, speed, dead, species, radius_cm ...` (id 0 = player).
- `cur.active` (index of the wild creature in the fight, or -1) and `cur.combat.fighters[k]`
  (only while a fight is active; k = 0 player, k = 1 the active wild creature, whose entity id
  is `cur.active + 1`): `world_id, move, phase, phase_tick, phase_length, hp, stamina`.
- `cur.combat.events[]`: `{type, a, b, move, amount}`; `a`, `b` are **fighter indices**, not
  entity ids. Types: 1 HIT (a damaged b), 2 BLOCKED, 3 GUARD_BROKEN, 4 DODGED, 5 INTERRUPTED
  (b's move cancelled by a), 6 STUNNED, 7 DEATH, 8 NO_STAMINA.
- Moves: 0 bite, 1 charge, 2 guard, 3 spit, 4 tail_strike, 5 dodge, -1 none.
  Phases: 0 idle, 1 wind-up, 2 active, 3 recovery.
- **A stagger** is `move == -1 and phase == 3` with `phase_length` = stagger ticks
  (`combat.c` `stagger()`).
- Stun, slow, bleed timers and the dash direction are **not** exposed (step 10b adds them).
- Befriend, Observe and Intimidate have **no C verbs yet** (`WIRE.md`); the UI only shows a
  message. Their animations are driven by a client-side cosmetic clock until the verbs exist
  (section 1.3).

### 0.2 Exact phase timing (from `combat.c` `begin_move`, `advance_phase`, step order)

A move launched in tick `L` with wind-up `W`, active `A`, recovery `R`:

- `begin_move` runs in step 2 of tick `L` with `ptick = 0`; step 5 of the same tick advances
  it. So the **first state Godot sees** (after tick `L`) has elapsed count `e = 1`.
- Define `e(state)`: wind-up `ptick`; active `W + ptick`; recovery `W + A + ptick`.
  State after tick `L + n` has `e = n + 1`.
- Hits are gathered in step 4 of tick `L + W` (first active tick). The HIT event is delivered
  with the state where `e = W + 1`.
- The last state that still reports the move has `e = W + A + R - 1`; the next state is idle
  (or already a new move with `e = 1`).
- Moves with `W = 1` (guard, dodge) are **never seen in wind-up**: their first state is
  already `phase = 2, ptick = 0`.

**Action time** (continuous, in ticks): `tau = (e_cur - 1) + alpha`.

- First sight: `tau = 0`. HIT event arrives at `tau = W + alpha_now`, and `alpha_now` is at most
  one frame's worth of a tick. So **a pose keyed at `tau = W` coincides with the event within
  one frame**, and the wind-up is on screen for the full `W` ticks.
- Segments: wind-up `tau in [0, W)`, active `[W, W + A)`, recovery `[W + A, W + A + R)`, then a
  client-only settle.
- Positions are drawn with the same `alpha` between `prev` and `cur`, so the body's dash
  (charge, dodge) is on screen during exactly the active segment.

Tick table (authority is C; mirrored in `action_clock.gd`, and the observed `phase_length`
wins if it differs, with one warning):

| move | W | A | R | seconds (tell / active / recovery) |
|---|--:|--:|--:|---|
| bite | 3 | 1 | 2 | 0.3 / 0.1 / 0.2 |
| charge | 10 | 5 | 2 | 1.0 / 0.5 (dash 5 m) / 0.2 |
| guard | 1 | 14 | 2 | 0.1 / up to 1.4 / 0.2 |
| spit | 6 | 1 | 4 | 0.6 / 0.1 / 0.4 |
| tail_strike | 3 | 2 | 4 | 0.3 / 0.2 / 0.4 |
| dodge | 1 | 3 | 2 | 0.1 / 0.3 (dash 2.2 m) / 0.2 |
| sing (P4) | 2 | 8 | 2 | cosmetic until C |
| dance (P4) | 2 | 10 | 2 | cosmetic until C |
| charm (P4) | 1 | 6 | 2 | cosmetic until C |
| pose (P4) | 4 | 8 | 2 | cosmetic until C |
| gift (P4) | 2 | 1 | 3 | cosmetic until C |
| roar (proposal) | 3 | 8 | 3 | cosmetic, not in P4 |
| display (proposal) | 4 | 10 | 2 | cosmetic, not in P4 |

P4 beat: period 12 ticks (1.2 s) per creature; "in rhythm" = the active frame within 2 ticks
of the beat.

### 0.3 How locomotion applies a pose today

`actor_driver.gd`: `controller.step(dt, pos, yaw, vel)` then
`adapter.loco_apply(body, controller.pose, desc)`. The adapter sets
`creature.global_transform = pose.root`, sets every leg's world `foot_target` from `pose.feet`,
bends the spine bones (`_bend_spine`) and calls `solve_legs()`.

Consequences used by this plan:

1. Foot targets are **world points**. If the action layer changes `pose.root` after the
   controller and before the adapter, the rig's IK re-solves the legs to the same world points:
   planted feet do not move, as long as each leg can still reach (section 1.5).
2. A standing controller does not start steps when only the root moves (`home_now` comes from
   the C position and yaw), so "legs plant" needs no controller change.
3. The capsule test rig reads `pose.hips`; whoever changes `pose.root` must recompute
   `pose.hips` and `pose.com`.
4. On the real rig the hips ride spine bones (`CreatureLegChain.hip_bone`). Bending a bone that
   carries a hip moves the hip. **The action layer never bends hip-carrying bones or bones
   between two leg stations** (v1); see the chains in section 1.4.

### 0.4 Rig numbers (probe on the real `Creature`, unit 1)

| creature | bones | tail / torso / neck bones | head (y, z) | tail len | "neck" len | legs | hooks |
|---|--:|---|---|--:|--:|--:|---|
| Merodeador | 19 | 7 / 6 / 3 | 2.72, 2.62 | 2.00 | 0.72 | 4 | jaw (fauces), lid x2 |
| Zancuda | 19 | 6 / 7 / 3 | 5.32, 1.94 | 1.48 | 0.61 | 2 | jaw (pico), lid x2, sway x4 (aleta, antena x2, cresta) |
| Babosa | 19 | 7 / 6 / 3 | 1.47, 2.06 | 1.58 | 0.42 | 0 | jaw (romo), lid x2 (tallo); maza at t = 0 has no hook |
| Garfio | 19 | 7 / 6 / 3 | 1.11, 0.49 | 0.52 | 0.14 | 4 | jaw, lid x2, sway (cresta), arm x2, tail (tail_spike) |

`neck_bones` is "t >= 0.68", not anatomy: Zancuda's real neck (3 m) is mostly `torso_bones`.
The retargeter therefore builds its own chains (section 1.4) and does not use `neck_bones`.

Bone signs, verified on the real skeleton in `WIRE.md`: a rotation of a spine bone about its
local +X by a positive angle lowers the nose (head side) and lifts the tail tip (tail side);
about local +Y a positive angle turns the head to +X (left) and swings the tail to -X.

### 0.5 Geometry mismatch to keep in mind

C treats a body as a circle (`radius_cm`, 40 to 400; Merodeador 300, Garfio 50) and measures
reach from the attacker's **centre** to the target's surface. The drawn Merodeador's mouth is
2.7 m ahead of its centre. So "bring the mouth to the target" cannot be taken literally: goals
are a **direction plus a clamped distance** (section 1.4.3), never an exact contact point.

---

## 1. Architecture

### 1.1 Pipeline per actor per frame

```
s    = stage.sample(id)
pose = controller.step(dt, s.pos, s.yaw, s.vel)          # G73, unchanged
layer.update(dt, ctx)        # clocks from the C state and events; pick, start, cancel, blend
layer.apply(pose)            # ADD to the pose: root delta (reach-guarded), pose.act
adapter.loco_apply(body, pose, desc)   # reads pose.act.bone_* in _bend_spine
rig.apply_parts(body, pose.act)        # jaw, lids, sway, wing, arm, sacs, inflate
```

Five kinds of object, all `RefCounted`, no `class_name`, found with `preload` (as in
`godot/locomotion`):

| file | role |
|---|---|
| `actions/action_clock.gd` | pure functions: `e`, `tau`, segment and `u`; cosmetic clock; beat phase |
| `actions/action_feed.gd` | turns `StageWorld` states and events into per-entity signals (`start`, `sync`, `end`, `cancel`, `react`); never writes |
| `actions/action_data.gd` | loads and validates `actions/data/*.json`, resolves variants per body |
| `actions/action_body_map.gd` | the body as the retargeter sees it: chains, limits, capabilities, capacities |
| `actions/action_layer.gd` | per actor: slots, priorities, track sampling, blending, springs, events out |
| `actions/action_solver.gd` | retargeter: channel values to root delta, bone deltas, leg overrides |
| `actions/action_springs.gd` | spring bank and follow-through |
| `actions/action_rig.gd` | writes `pose.act` part values into the real rig's hook nodes |
| `actions/action_fx.gd` | spit blob, gift item (cosmetic nodes) |
| `actions/data/*.json` | one file per action (section 3) |
| `actions/test/` | `run_tests.gd`, `scripted_feed.gd`, `capture.gd`, `movie.gd`, `movie.tscn` |

### 1.2 An action is semantic and body-independent

An action file holds **tracks**: one channel, keys over phase time. Channels are a fixed
vocabulary (the only place where code knows anatomy). Values are **normalised to the body's
capacity**, so the same numbers work for a 0.5 m Garfio and a 6 m Merodeador.

| channel | unit, 1.0 means | sign |
|---|---|---|
| `root.lunge` | `map.lunge_cap` metres along the heading | + forward |
| `root.side` | `map.side_cap` metres | + to the creature's left (`* side` when the track is signed) |
| `root.lift` | `map.height` metres | + up, negative crouches |
| `root.pitch`, `root.roll`, `root.yaw` | radians | pitch + nose up; roll + left side up; yaw + turns left |
| `body.inflate` | uniform body scale minus 1 (cap 0.08) | |
| `head.pitch`, `head.yaw`, `head.roll` | share of the head chain's range (`map.head_range`) | pitch + head up, yaw + left |
| `neck.coil` | share of each joint's limit, S-curve | + retracts the head, - straightens |
| `head.aim` | weight 0..1 of looking at the track's `goal` | |
| `head.reach` | 1 = mouth at the track's `goal` (clamped); negative = pulled back by that share of `map.reach_back` | |
| `jaw.open` | 0 closed .. 1 full gape of that mouth part | |
| `jaw.tremble` | amplitude in `jaw.open` units; with `hz` | |
| `tail.pitch`, `tail.yaw` | share of the tail chain's range (`map.tail_range`) | pitch + tip up, yaw + tip to the left |
| `tail.curl` | uniform curvature, share of limits | + curls to the left |
| `tail.stiff` | multiplies the tail springs' omega | |
| `display` | 0..1: wings spread, fins and crests erect, sacs full, antennae forward | |
| `arms` | -1 raised/back .. +1 extended forward (the `arm` hook) | |
| `lids` | 0 open, 1 closed, -0.3 wide | |
| `sacs` | 0 rest .. 1 full | |
| `legs.gesture` | named leg gesture with a 0..1 progress (step 13) | |
| `still` | 0..1: scales every oscillator and idle layer down (freeze) | |

A track may name a `goal` (for `head.aim`, `head.reach`): `target_surface`, `target_head`,
`target_ground` (ground point 40 % of the way to the target), `ground_front` (ground, half a
body height ahead), `forward`, `up`, `sky_target` (35 degrees above the target), `away`, `item`.

### 1.3 Drivers: where an action's time comes from

| driver | time source | used by |
|---|---|---|
| `c_move` | `tau` from the fighter's `move, phase, phase_tick` (0.2) | bite, charge, guard, spit, tail_strike, dodge |
| `c_state` | a condition on the C state that holds for a while | stagger, stun, death, combat-ready stance |
| `c_event` | an event in `combat.events` (impulse or short one-shot) | hit flinch, block recoil, guard broken |
| `cosmetic` | client tick counter started by the UI, quantised to the next C tick, with the table's W/A/R | sing, dance, charm, pose, gift, roar, display |
| `stance` | client condition (UI mode, speed, distance) | observe (crouch, stalk, freeze), attend |
| `idle` | always on; fidgets chosen with a client RNG | breathing, blink, look, fidgets |

When C gains `befriend`, `gift`, `observe`, `intimidate` (P4), the cosmetic and stance drivers
are replaced by `c_move`/`c_state` readers in `action_feed.gd`; the data files do not change.

### 1.4 The retargeter (Hecker et al. 2008, adapted)

Spore's scheme: animators author against a generic body in semantic frames (ground, body,
target), and each creature's capabilities decide how a goal is met (who provides the reach:
neck, spine, body, legs). Here the "animator" is the data file, and `ActionBodyMap` plus
`ActionSolver` do the specialisation.

#### 1.4.1 `ActionBodyMap` (built once per body; from the real rig or from a `desc`)

Built from a list of **joints** `{pos (rest space), frame (Basis: X left, Y dorsal, Z toward the
head), length to the next joint, radius}`:

- real rig: one joint per skeleton bone, `creature.bone_rest_global(b)`, radius
  `creature.rad[creature.bone_ring[b]]`; joint index = bone index.
- capsule rig or any `desc`: one joint per `desc.spine` point, frame from finite differences.

Fields:

- `plan`, `height` (hip height; legless: radius at the widest joint), `length`, `track`
  (from `LocoMorphology`), `com`.
- `front_anchor`, `hind_anchor`: the joint that carries the front-most / hind-most hip
  (real rig: `leg.hip_bone`; `desc`: nearest spine point to the station's z). Legless: both are
  the root joint (widest ring). No legs and no root information: the middle joint.
- `head_chain`: joints strictly ahead of `front_anchor`, ordered base to head. If fewer than 2,
  it is what it is (a rigid head): the body provides the reach instead.
- `tail_chain`: joints strictly behind `hind_anchor`, ordered base to tip.
- Per chain joint `j`: `limit_j = clamp(0.5 * length_j / max(radius_j, 0.02), 0.06, 0.55)`
  rad per axis (thin and long bends more); roll limit is half. `a_j` = arc fraction 0 (base)
  .. 1 (tip).
- `head_range = min(sum(limit_j), 1.4)`, `tail_range = min(sum(limit_j), 2.2)` rad.
- `mouth_local`: mouth tip in the head joint's frame. Real rig: the front-most point of the
  mouth part's meshes along the head tangent (part with category `mouths` and the largest
  `t`); fallback `anchor(1, 0).p + tangent * rad[last]`. `desc`: last spine point + tangent *
  radius.
- Capacities, measured once by running the solver on the rest pose: `reach_fwd`, `reach_up`,
  `reach_down`, `reach_back` (metres the mouth can travel in each direction using the head
  chain only).
- `lunge_cap`: quadruped and multi `0.35 * height`; bipeds `0.25 * height`; legless and monopod
  `0.12 * length`. `side_cap`: `0.4 * track`; legless `0.10 * length`.
- `belly_clear`: lowest `pos.y - radius` over the joints between the anchors (limit for
  crouching).
- `caps` (capability set of strings): `jaw` (a `jaw` hook), `pinch`, `mouth` (any part of
  category `mouths`), `tail` (`tail_chain` length > 0.15 * `length`), `tail_weapon` (a `tail`
  hook or a `weapons` part with t < 0.15), `arms` (an `arm` hook), `wings`, `fins`, `crest`
  (a `sway` hook on a `details` or `fins` part), `antennae` (a `sway` hook on a `senses`
  part), `lids`, `sacs`, `horns` (a `weapons` part with t > 0.6), `plates`, `long_neck`
  (`reach_fwd > 0.6 * height`), `legless`, `biped`, `upright`, `quadruped`, `multi`,
  `graviportal` (from the morphology), `legs2` (>= 2 driven legs), `legs4`.

#### 1.4.2 Root delta

With heading basis `B = Basis(UP, yaw_C)`, loco root `R0`, pivot `piv = (0, com.y, com.z)`
(the pivot loco uses):

```
Rot = Basis(UP, yaw) * Basis(RIGHT, -pitch_up) * Basis(BACK, roll)
R1  = R0 * T(piv) * Rot * T(-piv)
R1.origin += B * Vector3(side * side_cap, 0, lunge * lunge_cap) + UP * lift * height
```

`lift` is first clamped to `>= -(belly_clear - 0.03) / height`. Then the reach guard
(1.5) scales the whole delta by `k`. Then `pose.hips[i] = R1 * R0^-1 * hips[i]`,
`pose.com` likewise, `pose.root = R1`.

`body.inflate` (real rig only): `creature.body_root.scale = Vector3.ONE * (1 + s)` and
`body_root.position = Vector3(0, ground_offset, 0) + (-s) * Vector3(0, com.y, com.z)`; it must
be reset to 1 and `(0, ground_offset, 0)` when `s == 0`. The legs are not under `body_root`,
so they keep their thickness and re-solve to the same feet.

#### 1.4.3 Head chain: posture, aim, reach

Per frame, for the head chain joints (local deltas `dp_j` about the joint's X, `dy_j` about
its Y, `dr_j` about its Z; "head up" is a **negative** rotation about X, 0.4):

1. **Posture.** `g = min(1, 1.4 / sum(limit_j))`.
   `up_j = head.pitch * limit_j * g + neck.coil * 0.8 * limit_j * cos(PI * a_j)`;
   `dy_j = head.yaw * limit_j * g`; `dr_j = head.roll * 0.5 * limit_j` on the last two joints
   only. The cosine profile bends the base back and the tip forward, so the head retracts
   without changing where it points.
2. **Aim** (`head.aim` = weight `wa`, direction `d` to the goal in body space): forward-kinematic
   the chain, take the head joint's Z axis `f`; yaw error `ey = atan2(d.x, d.z) - atan2(f.x,
   f.z)`, pitch error `ep = asin(d.y) - asin(f.y)`; add `wa * ey * limit_j / S` and
   `wa * ep * limit_j / S` to the joints with `a_j >= 0.4` (`S` = sum of their limits); two
   passes.
3. **Reach** (`head.reach` = `v`, goal point `G` in world):
   - mouth rest point `M0` (after steps 1 and 2, before reach), direction `n = (G - M0)`
     normalised, distance `D = |G - M0|`.
   - `v >= 0`: wanted travel `t = v * clamp(D, min_lunge, reach_fwd + lunge_cap)` with
     `min_lunge = 0.15 * reach_fwd` (a bite always shows a lunge, even when the bodies overlap,
     0.5). Target point `P = M0 + n * t`.
   - `v < 0`: `P = M0 - n_h * |v| * reach_back + UP * 0.15 * |v| * reach_back` (`n_h` =
     horizontal part of `n`): pull back and slightly up.
   - **Who provides the reach**: the chain first, then the body. `t_chain = min(t, chain
     capacity along n)`; the rest goes to the root as an extra `root.lunge` (and `root.lift`
     when `n.y < -0.3`: a tall creature lowers its body to reach the ground), still subject
     to the reach guard. Bodies with `long_neck` use the chain for all of it; `graviportal`
     and rigid heads use mostly the body. This split is the retargeting.
   - Solve the chain with **weighted CCD**: 3 iterations per frame, tip to base; for joint `j`
     and each of its two axes (current global X and Y of the joint), the signed angle about
     that axis between `(mouth - joint_pos)` and `(P - joint_pos)` projected on the plane
     normal to the axis, times damping 0.6, times `limit_j / max(limit)`; add to a separate
     `reach_dp_j`, `reach_dy_j` and clamp so the total stays within `1.15 * limit_j`. Warm-start
     from the previous frame. When `|v|` falls, multiply the stored reach deltas by
     `exp(-dt / 0.06)` instead of solving.
4. **Ground clearance** (all chains, all bodies): two passes from base to tip; if a joint is
   lower than `ground + radius + 0.01`, add "up" rotation at the previous joint by
   `asin(deficit / length)`.

Goal point for `target_surface`: the nearest point to `M0` on the target's shape, taken from
`ActorHost.occluders()` (world spheres already built for the contact shadow: nearest sphere
surface). Without a host (tests): a sphere of `target_radius` at `target_pos`, height
`min(mouth height, target height)`.

#### 1.4.4 Tail chain

`dy_j = -(tail.yaw * limit_j * g_t + tail.curl * limit_j)` (sign because a positive bone yaw
swings the tail to -X), `up_j = tail.pitch * limit_j * g_t`, `g_t = min(1, 2.2 / sum(limit))`.
A track may carry `"lag": x`: joint `j` samples the track at `tau - x * a_j` ticks (the tip
arrives later: a travelling whip). The `tail` hook of a tail weapon gets
`rotation.y = 0.3 * tail_range * tail.yaw` on top.

No `tail` capability: tail channels are ignored; variants replace them (section 2.3).

#### 1.4.5 Parts (`action_rig.gd`, values from `web/creature/rig.js` lines 469 to 475)

| hook | value |
|---|---|
| `jaw` | `rotation.x = 0.06 + 0.75 * (jaw.open + tremble)`; gape per type may be overridden in `GAPE = {"pico": 0.7, "romo": 0.6}` |
| `pinch` (array) | `q.rotation.y = sx * (0.25 - 1.1 * (0.06 + 0.75 * jaw.open))`, `sx` as the port stores it (`creature_parts.gd` near line 432) |
| `lid` | `rotation.x = -0.3 + 1.5 * lids` |
| `sway` | `rotation.x = idle + spring + display_sign * 0.5 * display`; idle `0.12 * sin(2.2 t + 9 part.t)`; `display_sign` per part type, default -1, **check in the strips** |
| `wing` | `rotation.z = 0.12 + 0.8 * display + flap`, `rotation.y = lerp(0.32, 0.12, display)` |
| `arm` | `rotation.x = 1.0 * arms + spring` (each side; a track flagged `alternate` flips the sign by side) |
| `sacs` (array) | `scale = Vector3.ONE * (1 + 0.35 * sacs)` |

Every hook is written every frame from the current values (stateless), so a cancelled action
leaves nothing behind.

### 1.5 Blending with locomotion; no foot sliding

- **Root**: additive delta (1.4.2). Loco's bounce, lean and bank stay underneath.
- **Head and tail**: the action's bone deltas are added to the loco spine. A track may set
  `"mask": m` (0..1): the loco value for that region is multiplied by `1 - m * w` (`w` =
  the action's weight). Default: `head.*` 0.5, `tail.*` 1.0 for combat actions, 0 for idle.
  Implementation: `layer.apply` scales `pose.neck.*` / `pose.tail.*` before the adapter runs.
- **Legs**, by the action's `"legs"` field:
  - `free`: locomotion keeps full control (charge and dodge dashes, stalking, hit reactions
    while walking).
  - `plant`: nothing to do when standing (0.3 point 2). If the creature is walking, the
    action is upper-body only: root translations are multiplied by `1 - moving`
    (`moving = smoothstep(0.02, 0.15, froude)`), rotations and chains stay.
  - `gesture`, `hop`, `pivot`, `brace`: the scripted stepper of step 13.
- **Reach guard** (pose space, every frame, stance legs only): for `k` in [0, 1] the root is
  `R(k)` = delta scaled by `k` (translation linear, rotation slerp). Constraint per stance leg
  `i`: `|R(k) R0^-1 hips[i] - feet[i]| <= 0.985 * (upper + lower)` (the described lengths,
  which already carry the adapter's 4 cm margin). Take the largest `k` by 6 bisections,
  `k_out = min(k_found, k_prev + dt / 0.1)` (may fall at once, rises smoothly). With no stance
  legs (legless, all airborne) `k = 1`.
- **Result**: planted feet are world-fixed by construction and reachable by the guard. The
  test (step 6) measures the IK-solved sole, as the loco tests do, so a leg that cannot reach
  fails the test.

### 1.6 Secondary motion

One damped spring per chain joint axis, per part hook and per root channel
(`action_springs.gd`, the implicit integrator of `loco_controller._spring`):

```
omega_j = clamp(k_region * sqrt(G / l_distal_j), 6, 40)      l_distal = chain length beyond j
zeta    = head chain 0.8, tail chain 0.45, sway 0.25 (antennae), 0.4 (crests, fins), wings 0.5, arms 0.6, jaw 0.7, root 1.0
k_region = head 2.2, tail 1.6, parts 3.0
```

Follow-through (base acceleration drives the pendulum): with `a` = acceleration of the joint's
base in body space (second difference of the **action root delta plus loco root**, low-passed
at 0.05 s) and `l = max(l_distal, 0.05)`:

```
target_yaw   = goal_yaw   - c * a.x / (l * omega^2)
target_pitch = goal_pitch + c * a.y / (l * omega^2)      c = 0.6
```

clamped to the joint limit. Parts with `sway`, `wing`, `arm` hooks use the forward and vertical
acceleration the same way.

**Timing rule (springs must not delay a hit):** every track has a kinematic share `kin`
(default 1 for the channels an action keys, 0 for channels it does not). Output
`= lerp(spring.x, goal, kin * w)`. While `kin * w >= 0.99` the spring is slaved
(`x = goal`, `v = d goal / dt`), so when the action releases the channel the spring starts
from the keyed pose with its velocity: overshoot and settle come for free. Channels the
action does not key (the tail during a bite, crests, antennae) are fully spring-driven and
react to the lunge.

`tail.stiff` multiplies omega of the tail springs (stiff tail in a charge, limp in a stagger
with 0.3).

### 1.7 Slots, priorities, interruption

Per actor, four slots evaluated in this order and summed as channel values:

1. **base**: `idle_base` loop, always. Its oscillators are scaled by
   `(1 - still) * (1 - 0.7 * busy)` (`busy` = weight of the action slot).
2. **stance**: at most one held state; cross-fades over its `fade.in`.
3. **action**: one current instance plus up to two fading-out instances.
4. **reaction**: additive impulses and one short one-shot.

Priority (higher replaces lower in the same slot; equal priority: the newer one wins):
death 100, stun and stagger 80, C moves 60, cosmetic one-shots 40, stances 30 (guard hold is a
C move, 60), fidgets 10.

Rules:

- **C is the only authority for combat.** The layer never decides that a hit cancels a
  wind-up; it mirrors C. A move instance is **cancelled** when a new state shows: another
  move, `move == -1`, an INTERRUPTED/STUNNED/GUARD_BROKEN event with `b` = this fighter, or
  the fight ended, **before** the instance reached `e_last = W + A + R - 1`. It **ends
  normally** when the move disappears after `e_last` was seen; `tau` then runs on by
  extrapolation (`tau = e_last - 1 + ticks since + alpha`) through the last tick and the
  settle. Guard released early by C (a funded block) is a cancel that jumps to the action's
  recovery keys (`"on_cancel": "recover"`).
- Cancel: the instance's weight goes to 0 over `fade.cancel` (0.08 s); the reaction that
  caused it (stagger) starts at once. Because cancelled channels hand over to springs with
  their velocity, there is no pop.
- Start: weight rises over `fade.in`, at most 0.05 s for C moves (3 frames of a 0.3 s tell).
- A HIT on this creature while its own move continues (C did not cancel) is **additive**: the
  flinch impulse plays over the wind-up.
- Cosmetic and stance actions are cancelled by: any C move of this creature, a HIT/STUNNED on
  it, death, and (for actions with `"rooted": true`) its own speed above
  `0.03 * sqrt(G * height)`.
- Death holds its last pose until the entity is alive again or teleports (the controller's
  `reset`), then everything is cleared.

Events out (signal `action_event(name, data)` on the layer, cosmetic consumers only):
`impact`, `spit_release`, `foot_stomp`, `cry`, `shake`. The stage may connect audio to them;
C never hears them.

---

## 2. The actions

Notation: `w:0.45` = wind-up segment at `u = 0.45`; `a:` active; `r:` recovery; `s:` settle.
Values are in the channel units of 1.2. "Signed" tracks are multiplied by `side` (+1 left, -1
right), chosen as stated per action. All combat actions have `events: impact at a:0`.

### 2.1 Combat (driver `c_move`)

**bite** (3/1/2, legs `plant`, side = sign of the target's bearing)
- Tell: cock by `w:0.45`, hold to `w:0.7`: `head.reach` -0.5 (goal `target_surface`),
  `root.lunge` -0.3, `root.lift` -0.05, `root.pitch` +0.05, `jaw.open` 0.1 -> 1.0 by `w:0.35`
  (the open mouth is the tell), `lids` -0.3, `tail.pitch` +0.3.
- Strike `w:0.7 -> a:0` (ease `in`): `head.reach` -> 1.0, `root.lunge` -> 1.0, `root.pitch`
  -> -0.06. **Jaw shuts `a:0 -> a:0.25`** (1.0 -> 0.03, ease `snap`): the snap is the impact.
- `a:` hold; if a HIT event with `a` = self arrived: `head.yaw` oscillation 12 Hz, amplitude
  0.15, envelope `a:0.2 -> r:0.5` (track `"if": "hit"`).
- `r:` `head.reach`, `root.*` -> 0 (ease `inout`), `jaw.open` 0.1. Settle 0.25 s.
- Variants: `long_neck`: `neck.coil` +1.0 in the tell, `root.lunge` only 0.2 (a heron's
  strike). Rigid head or `graviportal`: `root.lunge` 1.0, `root.pitch` -0.12, `head.reach`
  0.5. `legless`: tell rears up (`head.pitch` +0.5), strike comes down and forward.
  `pinch` without `jaw`: same keys drive the pincers. Mouth without `jaw` or `pinch` (trompa,
  snout_trumpet, tongue_spring): a jab, `jaw.open` dropped, `head.reach` cock -0.7. No mouth
  at all (only in tests; C forbids it): head-butt, same as the jab.
- Note: the web stage opened the jaw widest during the active phase
  (`stage.js:113`); here it is widest in the tell and shut on the hit tick, which reads better
  and marks the tick.

**charge** (10/5/2, legs `free`)
- `w:0 -> 0.25`: `head.pitch` -0.7 (horns forward), `root.lift` -0.12, `root.lunge` -0.5,
  `tail.pitch` +0.6, `tail.stiff` 3, `display` 0.3, `lids` 0.4.
- `w:0.25 -> 0.85`: pawing. v1: `root.lift` dips -0.03 twice (period 3 ticks), `root.yaw`
  oscillation 4 Hz amplitude 0.04 from `w:0.5`, `jaw.open` pulses 0.2 (snorts). v2 (step 13):
  `legs.gesture: paw` x2 (quadruped: one fore leg; biped: alternate stomps; multi: front pair).
- `w:0.85 -> 1`: `root.lift` -0.2, `root.lunge` -0.7.
- `a:` (C dashes 1 m per tick): `root.lunge` 0, `root.pitch` -0.10, `root.lift` -0.08,
  `head.pitch` -0.5, `head.aim` 1 (`target_head`), `tail.pitch` 0, `tail.stiff` 3. If HIT with
  `a` = self: `head.pitch` -> +0.6 over 1 tick (toss).
- `r:` skid: `root.pitch` +0.12, `root.lift` -0.10 -> 0. Settle 0.35 s.
- Variants: no `horns`: `head.pitch` -0.4 and `head.yaw` 0.25 signed (shoulder first).
  `upright`: `root.pitch` -0.35 in the dash, `arms` -0.6. `legless` (C forbids water/ground
  cases; tests): coil in the tell (`tail.curl` 0.6, `neck.coil` 0.8), straighten in `a:`.

**spit** (6/1/4, legs `plant`)
- `w:0 -> 0.5` inhale: `head.pitch` +0.5, `head.reach` -0.4, `body.inflate` 0.06, `sacs` 1,
  `jaw.open` 0, `jaw.tremble` 0.03 at 9 Hz.
- `w:0.5 -> w_rel`: hold, `head.aim` 1 (`target_surface`).
- Release at `w_rel = 1 - T_f / (0.1 * W)` with flight time `T_f = clamp(dist / 28, 0.10,
  0.25)` s: `head.reach` +0.6 (ease `snap`), `jaw.open` 0.7, `sacs` -> 0, `body.inflate` ->
  -0.02; event `spit_release`. `action_fx.gd` flies a blob from the mouth to the target point
  so that it **arrives at `tau = W`**, when the C hit and its damage number appear. If the
  move is cancelled in flight the blob is freed; if no HIT event comes, it continues 3 m and
  lands.
- `a:` recoil: `head.reach` -0.2, `root.lunge` -0.15. `r:` jaw closes, two small gulps
  (`jaw.open` 0.15), return. Settle 0.2 s.
- Variants: no `sacs`: chest only. No `jaw`: nozzle mouth, `head.reach` snap only. `legless`:
  rears (`head.pitch` +0.7) to aim.

**tail_strike** (3/2/4, side = sign of the target's bearing, default left)
C hits inside the **facing** cone (1.6 rad), so the tail has to come round to the front.
- v1 (legs `plant`): tell: `root.yaw` +0.45 signed (the guard limits it), `tail.yaw` -1.0
  signed (pre-load away), `tail.curl` -0.4 signed, `root.lift` -0.10, `root.side` -0.3 signed,
  `head.aim` 1 (keeps looking at the target). Active: `root.yaw` -> -0.45 signed, `tail.yaw`
  -> +1.0 signed with `"lag": 0.7` (tip cracks late in the active window), `tail.stiff` 2.
  Recovery: tracks to 0 with `kin` 0 from `r:0.3` (springs carry the follow-through).
- v2 (step 13, legs `pivot`): hind-swing. The hind set hops sideways while the body yaws up to
  1.4 rad about the fore station (fore feet turn on the spot), bipeds hop-turn; the tail then
  crosses the front cone during the two active ticks; recovery hops back.
- `legless`: U-curl: `head.yaw` +0.8 signed and `tail.yaw` +1.0 signed, tip next to the head
  at `a:0.5`.
- No `tail` (tests; C forbids): rump swing: the `root.yaw` keys only, doubled `root.side`.

**guard** (1/14/2, legs `plant`, `on_cancel: recover`)
- First tick: snap in. Hold: `root.lift` -0.15, `root.lunge` -0.15, `root.pitch` -0.06,
  `head.pitch` -0.4, `neck.coil` +0.6, `tail.curl` 0.5, `arms` -0.9, `display` 0.3 (wings
  forward), `lids` 0.6, `jaw.open` 0; a 6 Hz tremor of 0.004 on `root.lift`.
- BLOCKED with `b` = self: reaction `block_recoil` (2.2). `r:` rise. Settle 0.2 s.
- Variants: `legless`: `neck.coil` +1, head low, no lift. `upright`: `root.yaw` 0.3 (shoulder
  first). v2: `legs: brace` (stance 15 % wider).

**dodge** (1/3/2; `side` and `fwd` from the dash: the player's key as a hint, otherwise the
sign of `s.vel` in the body frame during the active ticks, or `dash_x/dash_y` after step 10b)
- v1 (legs `free`): `a:0 -> a:0.4` `root.roll` 0.18 signed (lean into it), `root.lift` +0.06
  at `a:0.4`, `tail.yaw` -0.6 signed, `head.aim` 1 (`target_head`); `a:0.85 -> r:0.5` landing
  `root.lift` -0.14, roll overshoot -0.06 signed. Settle 0.2 s.
- v2 (legs `hop`): all feet leave at `a:0.05`, tuck 25 %, land at `a:0.85` under the body's
  new place; `root.lift` peak +0.12.
- Forward/back dodges: use `root.pitch` -+0.12 instead of roll.
- Variants: `legless`: no lift; `head.yaw` and `tail.yaw` +0.5 signed (a C-flick).
  `graviportal`, `multi`: no hop, roll 0.08, lift -0.05.

### 2.2 Reactions, stagger, stun, death

**hit** (`c_event` HIT with `b` = self; additive impulse, no keys). With `d` = unit vector
from the attacker to this creature in its body frame and `m = clamp(amount / 20, 0.3, 1.5)`,
add to spring **velocities** (the springs bring everything back in about 0.35 s):
`root.side += 2.5 m d.x`, `root.lunge += 2.5 m d.z` (normalised units per second),
`root.roll -= 1.5 m d.x`, `root.pitch -= 1.0 m d.z`, head chain yaw `-= 5 m d.x * limit_j`,
tail chain yaw `+= 4 m d.x * limit_j`; one-shot 0.12 s: `lids` 1, `jaw.open` 0.4.

**block_recoil** (BLOCKED with `b` = self): `root.lunge` velocity -3, `head.pitch` velocity -2.
**guard_broken**, **interrupted**, **stagger** (`c_state`: `move == -1 and phase == 3`, length
`phase_length` ticks): `root.lunge` -0.4 (ease `out`, first tick), `root.roll` 2 Hz oscillation
0.15 decaying to 0 over the length, `head.pitch` -0.5 with a 3 Hz wobble 0.1, `jaw.open` 0.3,
`lids` 0.5, `tail.stiff` 0.3, legs `free`. Then 0.2 s recovery.
**stun** (STUNNED with `b` = self; 6 ticks from the table, or the `stun` field after 10b):
`head.pitch`/`head.yaw` Lissajous 1.5 Hz amplitude 0.2, `lids` flutter 0.5 +- 0.4 at 6 Hz,
`root.side` +-0.1 at 0.8 Hz, `root.lift` -0.08.
**death** (`entity.dead`; priority 100; duration `t_c = clamp(0.45 * sqrt(height / 0.5), 0.35,
1.2)` s, bigger bodies fall slower): `root.lift` -> `-(belly_clear - 0.03) / height` (belly on
the ground, ease `in`), `root.roll` -> 1.2 signed (away from the last hit, default left) from
`0.3 t_c`, head and tail chains limp (`tail.stiff` 0.2, head chain omega x 0.3, goals: ground
clearance only), `jaw.open` 0.35, `lids` 1, `display` 0, `still` 1 afterwards. Legs: feet stay
planted while the body sinks (IK folds them); legs on the upper side after the roll go
`gesture: limp` in v2 (v1: they stay planted and stretch; the reach guard does **not** apply
to death, legs that cannot reach are allowed to lift: set their `contact` false and target =
hip + down * 0.8 length).
`legless`: roll 1.4 and chains limp only.

### 2.3 Social (driver `cosmetic`, then C), in rhythm with the P4 beat

Beat clock: `beat_u = fposmod(tick + alpha - beat_phase, 12) / 12`. Until C exposes
`beat_in`, `beat_phase = (7 * id + seed) % 12` (placeholder, documented). An action's accents
are placed on a grid of quarter beats (3 ticks) **shifted so that one accent falls on a beat
that lies inside the active window**; if the player was off the beat, no beat lies inside and
the grid starts at `a:0`. The target shows its own beat (stance `attend`, 2.5), so a
performance in rhythm visibly lands on the target's nod.

**sing** (2/8/2, legs `plant`, `rooted`)
- `w:` inhale: `head.pitch` +0.3, `body.inflate` 0.04.
- `a:` `head.pitch` +0.8, `head.aim` 0.5 (`sky_target`), `jaw.open` 0.55 + 0.3 sin at 2.2 Hz
  (rig.js `0.3 + 0.25 sin(14 t)`), `jaw.tremble` 0.05 at 9 Hz, `root.lift` 0.04 |sin| on the
  quarter-beat grid (rig.js bob `|sin(9 t)| * 0.18`, re-timed), `sacs` 0.5 + 0.5 sin on the
  grid, `display` 0.4, `tail.yaw` +-0.4 one side per half beat, `lids` 0.6. Envelope: swell
  `a:0 -> a:0.25`, peak (`jaw.open` 1, head highest) on the in-window beat or `a:0.5`, fade
  `a:0.8 -> r:0.5`.
- `r:` head down, `head.aim` 1 (`target_head`) for a glance.
- Variants: no `jaw` but `mouth` (trompa, trumpet): `head.pitch` +1.0 and `head.yaw` weave
  +-0.2 on the grid, no jaw keys. `pinch`: `jaw.open` square wave on the grid (clacking).
  `long_neck`: head chain yaw travelling wave, amplitude 0.25, one cycle per beat (`lag`).
  `legless`: rear up first. No mouth (tests; C forbids): hum = inflate and sacs pulses only.

**dance** (2/10/2, needs `legs2`, `rooted`, side alternates each accent)
- `w:` dip: `root.lift` -0.10, `head.aim` 1.
- `a:` three accents on the grid. Per accent: `root.lift` -0.06 on it, +0.05 between;
  `root.side` 0.25 signed; `root.yaw` 0.2 signed; `root.roll` 0.08 signed; `head.pitch`
  +-0.25 in counter-phase; `tail.yaw` 0.8 signed (springs lag it); `display` pulse 0.8;
  `arms` 0.6 `alternate`. v2: `legs.gesture: stomp` of alternating sets (biped L, R, L;
  quadruped diagonal pairs; multi the front pair raised and waving).
- `r:` flourish: `head.pitch` +0.6, `display` 1, then return.
- Variants: `legless` (tests; C forbids): `tail.curl` and `head.yaw` weave in opposition.
  `graviportal`: half amplitudes, no yaw.

**charm** (1/6/2, legs `plant`, side alternates per use)
- `a:` `head.roll` 0.35 signed (head tilt), `head.reach` 0.2 (`target_head`), `head.pitch`
  -0.15, `root.lift` -0.05, slow blinks (`lids` 1 for 1.5 ticks at `a:0.25` and `a:0.65`),
  antennae and stalks toward the target (`display` 0.3), `tail.yaw` +-0.25 at 5 Hz with
  `"lag": -0.5` weighting the tip.
- Variants: no `lids`: two nods (`head.pitch` -0.3) instead of blinks. No eyes (tests): the
  same with nods.

**pose** (4/8/2, legs `plant`, display of strength)
- `w:` rise: `root.lift` up to +0.06 (the guard caps it at straight legs), `root.pitch`
  +0.12, `head.pitch` +0.5, `neck.coil` 0.3, `body.inflate` 0.06.
- `a:` hold, onset accent on the in-window beat: `root.yaw` 0.3 signed (shows the flank),
  `head.yaw` -0.5 signed (one eye on the target), `display` 1, `sacs` 1, `tail.pitch` +0.7,
  `arms` -1.0, `still` 0.6 (a held pose reads as strength).
- `r:` exhale, return.
- Variants: `legless`: `head.pitch` +1.0 (rear to full height). `upright`: `arms` -1.0 wide.
  No display parts (tests): the same without `display`.

**gift** (2/1/3, legs `plant`)
- `w:` `head.reach` 1 (`ground_front`), `jaw.open` 0.4 -> 0.1 (picks the item; FX item
  parented to the mouth point).
- `a:` `head.reach` 1 (`target_ground`), `jaw.open` 0.6 at `a:0.5` (item dropped; FX frees
  it after 2 s).
- `r:` nudge (`head.reach` pulse 1.15), then `root.lunge` -0.3, `head.pitch` -0.3, `lids`
  blink, `tail.pitch` -0.3 (submissive).
- Variants: `arms`: `arms` +1.0 present the item, head level. No `jaw`: the item is pushed
  along the ground with the snout (never lifted). Tall bodies: the solver adds `root.lift`
  down to -0.35 to reach the ground.

### 2.4 Intimidate (driver `cosmetic`)

**roar** (3/8/3 proposal, legs `plant`)
- `w:` `head.pitch` +0.5, `head.reach` -0.4, `body.inflate` 0.08, `root.lunge` -0.3.
- `a:` `head.reach` 0.5 (`target_head`), `head.pitch` 0, `jaw.open` 1.0 with `jaw.tremble`
  0.06 at 18 Hz, `root.side` noise 18 Hz amplitude 0.02, `tail.yaw` +-0.7 at 2.5 Hz with
  `tail.stiff` 2, `display` 0.7, `lids` -0.3, events `cry` at `a:0`, `shake` at `a:0`.
  v2: `legs.gesture: stomp` of the most loaded front leg at `a:0` (event `foot_stomp`).
- `r:` jaw shuts (`snap`), `head.aim` 1 held (stare), deflate.
- Variants: no `jaw`: hiss, `sacs` 4 Hz pulses, body shake. `pinch`: spread wide and clack
  twice. `legless`: rear up, then the forward thrust. `wings`: `display` 1 at `a:0`.

**display** (4/10/2 proposal, legs `plant`; "makes the body bigger")
- `root.lift` to the guard's cap (straight legs), `body.inflate` 0.08, `root.yaw` 0.35 signed
  (broadside), `head.pitch` +0.6, `tail.pitch` +1.0, `display` 1 with a 1.2 Hz flap 0.15 on
  wings, `jaw.open` 0.35, `root.roll` +-0.05 at 1 Hz, `arms` -1.2.
- v2: tiptoe (`foot_pitch` up to 0.5 rad on all feet through the controller's `ankle_at`),
  two side steps; light quadrupeds (`robustness < 1.2`) **rear up**: `root.pitch` +0.6 about
  the hind station, fore legs `gesture: hold_up`, only if the centre of mass stays over the
  hind feet (`loco_support.gd`).
- Variants: `legless`: `head.pitch` +1.0, hood = `body.inflate` 0.08. No display parts: the
  posture alone.

### 2.5 Observe and attend (driver `stance`)

**observe** (player, UI mode Observe with a target selected; C verb later). Sub-states by the
creature's own speed `v` and time:
- **crouch** (enter, 0.3 s): `root.lift` -0.25 (limited by `belly_clear`), `head.reach` 0.4
  (`target_head`) with `head.pitch` -0.3, `tail.pitch` -0.3, `tail.stiff` 2, `display` -0.3
  (crests flat, wings tight), `lids` 0.4.
- **stalk** (`v` above the moving threshold): the same, plus head stabilisation (subtract
  `pose.bounce` and `pose.pitch` from the head chain: `head.pitch += pose.pitch / head_range`
  and a `root`-independent height hold through `head.reach` on a point fixed in the heading
  frame), `root.roll` +-0.03 on the gait clock, a `tail.yaw` tip twitch every 1 to 2 s.
- **freeze** (stationary for 0.3 s): `still` 1 within 0.1 s (breathing x 0.15, no blink, no
  sway), everything else held.
- Variants: `legless`: flatten (`body.inflate` -0.04), head low and straight. `long_neck`:
  `neck.coil` +0.8 while stalking.

**attend** (a wild creature that the player has selected in Befriend mode, within 12 m, not in
a fight): `head.aim` 0.8 (the player's head), and a **beat nod** on its own beat:
`head.pitch` -0.12 for 1.2 ticks, a `tail.yaw` flick 0.2, a `display` pulse 0.3. This is the
diegetic beat display that makes the rhythm learnable.

**combat_ready** (`c_state`: this creature is a fighter and its phase is idle): `root.lift`
-0.05, `head.aim` 1 (`target_head`), `tail.pitch` +0.2, `jaw.open` 0.1, a 1.5 Hz weight
shift `root.side` +-0.06.

### 2.6 Idle variety (driver `idle`)

`idle_base` (loop tracks): breathing `body.inflate` +-0.012 and `root.lift` +-0.004 at
`f = clamp(0.9 * mass^-0.26, 0.15, 1.2)` Hz (mammalian allometry); blink
`lids = max(0, sin(1.6 t))^60` (rig.js); `jaw.open` `0.05 sin(2.1 t)` (rig.js); part sway
(1.4.5); weight shift `root.side` +-0.08 every 6 to 12 s (ease 1.5 s); look-around: every 2 to
6 s a new `head.yaw` in +-0.5 and `head.pitch` in +-0.15, or `head.aim` 0.7 at the nearest
creature within 15 m. Scaled by `1 - moving` except breathing and blink.

Fidgets (one-shots, priority 10, when idle for 8 s, weights in the data): `shake` (body roll
oscillation 8 Hz for 0.6 s, springs do the rest), `sniff` (`head.reach` `ground_front` 0.8,
two small `jaw.open` pulses), `yawn` (`jaw.open` 1 over 1.2 s, `head.pitch` +0.4, `lids` 1),
`stretch` (`root.lunge` -0.6, `root.pitch` +0.15, then +0.5 / -0.1), `tail_swish`
(`tail.yaw` +-0.7 with lag), `scratch` (v2, `legs.gesture`).

The RNG is a `RandomNumberGenerator` seeded with the entity id; it is client-only.

### 2.7 What a body without the part does (summary)

| action | no jaw | no tail | no arms | legless |
|---|---|---|---|---|
| bite | pincers; else a jab with the snout or head | spring tail absent; nothing lost | n/a | rear up, strike down |
| charge | n/a (snorts dropped) | no counterweight pose | n/a | coil and release |
| spit | nozzle: head snap only | n/a | n/a | rear up to aim |
| tail_strike | n/a | rump swing (body yaw) | n/a | U-curl of the whole body |
| guard | n/a | no tail curl | no arm cover | coil back, head low |
| dodge | n/a | no counter-swing | n/a | C-flick, no lift |
| hit, stagger, stun | no cry gape | fewer springs | n/a | chains only |
| death | n/a | n/a | n/a | roll and go limp |
| sing | trumpet weave; pincer clack; else hum (inflate, sacs) | no tail sway | n/a | rear up and sway |
| dance | n/a | no swish | no waving | weave (tests only) |
| charm | n/a | no wag | n/a | same, no lift |
| pose | n/a | no raised tail | no flex | rear to full height |
| gift | push the item with the snout | n/a | mouth carries it | same with the head |
| roar | hiss: sacs and shake | no lashing | n/a | rear up and thrust |
| display | closed mouth | no raised tail | no spread | hood (inflate), rear |
| observe | n/a | n/a | n/a | flatten |

A missing capability never raises an error: unknown channels for a body are skipped by the
solver, and variants only make the fallback look intended.

---

## 3. Data format (`godot/actions/data/<id>.json`, schema `cpore.action/1`)

```json
{
  "schema": "cpore.action/1",
  "id": "bite",
  "class": "combat",
  "driver": {"kind": "c_move", "move": 0},
  "ticks": {"w": 3, "a": 1, "r": 2},
  "settle": 0.25,
  "priority": 60,
  "fade": {"in": 0.05, "out": 0.12, "cancel": 0.08},
  "legs": "plant",
  "rooted": false,
  "side": "target",
  "tracks": [
    {"ch": "head.reach", "goal": "target_surface",
     "keys": [["w", 0, 0], ["w", 0.45, -0.5, "out"], ["w", 0.7, -0.5], ["a", 0, 1.0, "in"],
              ["a", 1, 0.9], ["r", 1, 0, "inout"]]},
    {"ch": "jaw.open",
     "keys": [["w", 0, 0.1], ["w", 0.35, 1.0, "out"], ["a", 0, 1.0], ["a", 0.25, 0.03, "snap"], ["r", 1, 0.1]]},
    {"ch": "head.yaw", "if": "hit", "osc": {"clock": "time", "hz": 12, "amp": 0.15},
     "env": [["a", 0.2, 1], ["r", 0.5, 0]]}
  ],
  "events": [{"at": ["a", 0], "emit": "impact"}],
  "variants": [
    {"when": {"has": ["long_neck"]},
     "set": [{"ch": "neck.coil", "keys": [["w", 0, 0], ["w", 0.45, 1.0, "out"], ["w", 0.7, 1.0], ["a", 0, -0.3, "in"], ["r", 1, 0]]},
             {"ch": "root.lunge", "keys": [["w", 0, 0], ["a", 0, 0.2, "in"], ["r", 1, 0]]}]},
    {"when": {"lacks": ["jaw", "pinch"]}, "drop": ["jaw.open"]}
  ]
}
```

Rules (validated by `action_data.gd`, errors name the file and the path):

- `class`: `combat | reaction | social | intimidate | observe | idle`.
- `driver.kind`: `c_move` (`move`), `c_state` (`state`: `stagger | stun | dead | fighter_idle`),
  `c_event` (`event`), `cosmetic`, `stance` (`when`), `idle` (`weight`, `min_gap`).
- `ticks`: fallback and cosmetic durations. For `c_move` the observed `phase_length` wins.
- Key: `[segment, u, value, ease?]`. Segments `w`, `a`, `r`, `s` (settle, seconds = `settle`);
  for `stance`: `in`, `hold`, `out`; for loops: `loop` (with `"period"` seconds or
  `"clock"`). Keys must be in time order. Before the first key the value is the first key's;
  after the last, the last key's. Ease applies to the interval **ending** at the key: `lin`
  (default), `in` (`u^2`), `out` (`1 - (1 - u)^2`), `inout` (smoothstep), `snap` (reached
  within 0.02 s), `hold` (stays at the previous value, then jumps).
- A track has `keys`, or `osc` (+ optional `env` keys as amplitude envelope), or both
  (`keys + osc * env`). `osc`: `{"clock": "time" | "tick" | "beat" | "grid" | "gait", "hz" or
  "per" (cycles per clock unit), "amp", "shape": "sin" | "abs" | "square" | "noise",
  "phase"}`. `grid` is the quarter-beat grid of 2.3.
- Track options: `goal`, `kin` (default 1), `mask` (default per 1.5), `lag` (ticks, chains
  only), `signed` (multiply by the action's `side`), `alternate` (flip per side for part
  hooks), `if` (`hit`: only after a HIT event with `a` = self during this instance).
- `side`: `target` (sign of the target's bearing in the body frame, +1 if none), `dash`
  (from the dash direction), `alternate` (flips on every use), `away_hit`, or a number.
- `legs`: `free | plant | gesture | hop | pivot | brace`. A body or a build without the
  stepper (step 13) treats the last four as `plant` (or `free` when `legs_fallback` says so).
- `variants`: first match wins. `when`: `{"has": [...], "lacks": [...]}` over `map.caps`.
  `set` replaces or adds tracks by `ch` (and by `goal` when two tracks share a channel);
  `drop` removes channels; `ticks`, `legs`, `settle` may be overridden.
- Unknown keys are errors (typos must not pass silently); unknown channels are errors;
  a channel a body cannot express is skipped at run time without a warning.

New actions are new files. A new **channel** is code (solver + table).

---

## 4. Determinism

- The layer **reads** `StageWorld.prev/cur/alpha()`, `combat.events`, the controller's pose
  and the rig. It **never** calls `CporeWorld.step/order/reset`, never touches
  `stage.input_provider`, `log_inputs`, `player_input`, and never changes `host.position` /
  `host.basis` (the C pose) or anything the camera, clicks or UI read as game state.
- Cosmetic social, intimidate and observe actions start from UI signals but send **nothing**
  to C; `stage_ui` keeps showing the "not in this build" message until the verbs exist.
- Time is frame time; randomness is a private `RandomNumberGenerator` per actor. Two runs may
  animate differently in detail (frame rate) without any effect on the world.
- Test (step 9): the same scripted fight twice, once with the layer and once with
  `ActorDriver.actions_enabled = false`; `stage.hashes` and `stage.export_log()` must be
  byte-identical.

---

## 5. Steps for the implementer

Each step ends with its tests passing, `make godot-loco-test` (192) still passing, and a small
commit. Tests live in `godot/actions/test/run_tests.gd` (print `actions tests: N checks, F
failures`, exit code 1 on failure, an `OS.add_logger` hook that counts engine errors as
failures, as `play_test.gd` does).

### Step 0. Skeleton

Files: `godot/actions/` with empty modules, `test/run_tests.gd`, Makefile targets:

```
godot-actions-test:
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --import >/dev/null 2>&1 || true
	cd godot && nice -n 10 timeout 600 $(GODOT) --headless --path . --script actions/test/run_tests.gd
godot-actions-evidence:   (step 14)
```

Accept: the target prints `0 failures`.

### Step 1. `action_clock.gd` (pure)

```
const TICKS := {0: [3,1,2], 1: [10,5,2], 2: [1,14,2], 3: [6,1,4], 4: [3,2,4], 5: [1,3,2]}
static func elapsed(move, phase, ptick, w, a) -> int      # e of 0.2
static func tau(e: int, alpha: float) -> float            # (e - 1) + alpha
static func locate(tau, w, a, r, settle_ticks) -> {seg, u, done}
static func seg_time(seg, u, w, a, r, settle_ticks) -> float     # inverse, for keys and lag
static func beat_u(tick, alpha, phase, period := 12) -> float
static func grid_shift(start_tick, w, a, beat_phase, period := 12, step := 3) -> float
```

`locate`: `tau < w` -> (`w`, `tau / w`); `< w + a` -> (`a`, ...); `< w + a + r` -> (`r`, ...);
else (`s`, `(tau - w - a - r) / settle_ticks`), `done` when that exceeds 1. A zero-length
segment is skipped. `grid_shift`: the offset in ticks from `a:0` to the first accent, such
that an accent falls on a beat tick inside `[w, w + a)`; 0 when no beat lies inside.

Accept: table-driven checks for all six moves: `e` at each state of a simulated
`advance_phase` (re-implement the 10 lines of `combat.c` in the test), `tau = W` exactly when
the test's state reaches `e = W + 1` with `alpha = 0`; `W = 1` moves start in the active
segment; `locate` and `seg_time` are inverses to 1e-6.

### Step 2. `action_feed.gd` and `test/scripted_feed.gd`

`ActionFeed.read(prev_state, cur_state, alpha) -> {entity_id: signal}` where signal is
`{move, phase, e, plen, tau, fighter_index, events: [...], dead, target_id, in_fight}`;
events are re-addressed to entity ids (`fighter 0 -> 0`, `fighter k -> cur.active + 1`) and
are delivered **once** (keyed by `cur.tick`). It keeps, per entity, the instance bookkeeping
of 1.7: `start` (move appears, or `e` decreased), `sync`, `end` (vanished after `e_last`),
`cancel` (vanished or changed before), `stagger` (`move == -1 and phase == 3`).

`ScriptedFeed`: builds the same state dictionaries from a script
`[{tick, fighter, begin: move}, {tick, fighter, interrupt: n}, {tick, event: {...}}]` using
the phase automaton of step 1, so tests and evidence need no C extension.

Accept: scripted sequences give exactly the expected signal lists for: each move alone; bite
re-launched on the tick after it finishes (old `end`, new `start` in the same tick); spit
interrupted in wind-up (`cancel` + `stagger` 4); guard released at active tick 5 (`cancel`
with `on_cancel`); death mid-move; fight ending mid-move.

### Step 3. Data loader and the first file

`action_data.gd`: `load_all(dir) -> {id: action}`, `validate(dict) -> [errors]`,
`resolve(action, caps) -> action` (variants applied, tracks compiled into arrays sorted by
time), `sample(track, seg, u, clocks) -> float` (keys + ease + osc + env + `if`).
Write `data/bite.json` (section 3). Channel table in `action_data.gd` as
`CHANNELS := {"root.lunge": {...}, ...}` from 1.2.

Accept: bite validates; six deliberately broken copies (unknown key, unknown channel, keys
out of order, bad ease, bad segment, bad `when`) each give one error that names the path;
`sample` of the jaw track returns 1.0 at `w:0.35..a:0` and <= 0.03 from `a:0.25`; a `snap` key
reaches its value within 0.02 s; `resolve` with caps `[long_neck]` contains `neck.coil`.

### Step 4. `action_body_map.gd`

`static func from_rig(creature, desc) -> map`, `static func from_desc(desc) -> map` (1.4.1).

Accept (real rig: Merodeador, Zancuda, Babosa, Garfio; `desc`: the 7 bodies of
`locomotion/test/bodies.gd`):
- no head or tail chain joint carries a hip or lies between two stations;
- Zancuda's head chain is longer than 2.5 m and has `long_neck`; Babosa has `legless`, `jaw`,
  `plates`, no `arms`; Garfio has `arms`, `tail_weapon`, `crest`; Merodeador has `horns`,
  `jaw`; test biped has no `tail`;
- all limits within [0.06, 0.55]; capacities finite and positive (0 allowed for a rigid head);
- sign checks on the real skeleton (as `play_test._bone_signs`): applying a head "up" delta
  raises the head bone's global y; a head yaw + moves it to +X; tail pitch + raises the tip;
  tail yaw + moves the tip to +X (note: this is the **channel** sign of 1.2, the opposite of
  the raw bone yaw).

### Step 5. Pose plumbing (the only edits outside `godot/actions/` before step 9)

1. `loco_rig_adapter.gd`, `_bend_spine`, in the last loop, after `dy`, `dp`:
   ```
   var act: Dictionary = pose.get("act", {})
   if not act.is_empty():
       dy += act.bone_dy[b]; dp += act.bone_dp[b]
       q = rest_q * Quaternion(UP, dy) * Quaternion(RIGHT, dp) * Quaternion(BACK, act.bone_dr[b])
   ```
   (`bone_dy/dp/dr`: `PackedFloat32Array` of size bone count, local deltas, zeros when absent.)
   With no `pose.act` the result must be bit-identical to today.
2. `locomotion/test/capsule_rig.gd`, `loco_apply`: when `pose.act` has `joint_dp/dy`, rotate
   each spine point about its base joint cumulatively from the anchors outward (the same
   forward kinematics as the solver, call `ActionSolver.fk_points`), and draw the jaw as a
   small box at the head whose pitch is `jaw.open` (so strips of test bodies show the mouth).
3. `action_solver.gd`: `apply_root(pose, map, ch, dt)` (1.4.2 with the guard of 1.5),
   `fk_points(map, deltas) -> Array[Transform3D]`.
4. `action_rig.gd`: `apply_parts(creature, act)` (1.4.5) and `reset(creature)`.

Accept: with an empty `pose.act` and zero channels, the pose and every bone transform are
identical (max difference 0) to the loco-only run over 2 s of walking, for Merodeador and the
light quadruped; `godot-loco-test` 192, `godot-creature-test` 1456 still pass. With
`root.lunge = 1` standing: planted soles move < 0.5 mm, `k` reported, hips recomputed
(capsule rig legs still meet the hips). With `root.lift = +1`: the guard returns `k < 1` and
no leg is longer than `0.985 L`. `jaw.open = 1` sets the fauces jaw node's `rotation.x` to
0.81.

### Step 6. `action_layer.gd` core and bite end to end

```
func setup(map, actions, rig_kind)              # resolves every action for this body once
func update(dt: float, ctx: Dictionary) -> void # ctx: signal (step 2), tick, alpha, target, beat, mode, speed
func apply(pose: Dictionary) -> void
func trigger(id: String, args := {}) -> bool    # cosmetic start (quantised to the next tick)
signal action_event(name, data)
var debug := {}                                 # current ids, weights, tau, k (for tests and labels)
```

Slots, fades, priorities and cancel as in 1.7. Channel accumulation: per channel
`value = sum(w_i * v_i)`, `kin = max(w_i * kin_i)`, masks by max. Weights:
`w = smoothstep(0, fade.in, t_since_start) * (1 - smoothstep(0, fade.out, t_since_end))`.

Accept (ScriptedFeed, Merodeador on flat ground, 60 fps and again with frame times drawn
from [1/144, 1/45] with a fixed seed):
- **timing**: the frame at which `action_event("impact")` fires and the frame at which the
  feed delivered the state with `e = W + 1` differ by at most 1 frame, for 200 bites with
  random sub-tick offsets; the jaw is >= 0.9 open for every frame of `tau in [0.35 W, W)` and
  <= 0.1 open from `tau = W + 0.3`; the action weight is >= 0.99 within 4 frames of the first
  wind-up state;
- **no sliding**: sole displacement of every stance leg over the whole bite < 2 mm (measure
  the IK-solved sole like `locomotion/test/sim.gd`), IK residual < 2 mm;
- **return**: 1 s after the end, every bone and the root are within 1e-3 of the loco-only
  pose;
- **cancel**: an interrupt at `w:0.5` brings the weight to 0 within `fade.cancel` + 1 frame
  and no bone rotates faster than 25 rad/s in any frame.

### Step 7. Head chain solver

`action_solver.gd`: `solve_head(map, ch, goals, state, dt)`, `solve_tail(...)`,
`ground_clear(...)` (1.4.3, 1.4.4). Goal resolution `resolve_goal(kind, ctx, map) -> Vector3`.

Accept: for the 4 real creatures and 7 test bodies, a `head.reach = 1` goal placed at
`0.5 * reach_fwd` ahead of the mouth is met within 3 cm after 12 frames; at `3 * reach_fwd`
the chain is at its limits, the root lunges, and nothing is NaN; no joint exceeds
`1.15 * limit`; with the goal held still the mouth moves < 1 mm per frame after 0.5 s
(no CCD jitter); `head.aim` at a point 60 degrees to the left turns the head's Z axis to within
0.15 rad or the limits; Babosa with `head.pitch = -1`: no joint below `radius + 0.01`.

### Step 8. Springs

`action_springs.gd` (1.6) and its use in the layer (kinematic share, slaving, release).

Accept: a step in `tail.yaw` goal with `kin = 0` overshoots by 10 to 35 % and is within 5 %
after 1.5 s (zeta 0.45); with `kin = 1` the output equals the goal every frame; after a
bite's strike the Merodeador's tail (not keyed) moves by more than 0.02 rad and returns;
the impact timing test of step 6 still passes unchanged; frame-rate independence: tail angle
at t = 0.5 s after a kick differs by < 5 % between 30 and 144 fps.

### Step 9. Wire into the game

- `actor_driver.gd`: `var actions_enabled := true`, `var layer`, `var map`; in `_try_loco`
  after the controller: build `map = BodyMap.from_rig(body, desc)`, `layer.setup(...)`; in
  `update(dt, s, ctx := {})`: `controller.step` -> `layer.update(dt, ctx)` ->
  `layer.apply(controller.pose)` -> `adapter.loco_apply` -> `ActionRig.apply_parts`.
  Without loco (placeholder or rest-pose glide) there is no layer.
- `actor_host.gd`: `update(dt, s, ctx)` passes through; expose `layer` and `mouth_world()`.
- `island.gd`: one `ActionFeed`; in `_update_actors`: `var sig = feed.read(stage.prev,
  stage.cur, stage.alpha())`, then per host a `ctx` with its signal, `tick`, `alpha`, target
  (the other fighter's host: position, `occluders()`, radius), beat, UI mode. Set
  `stage.process_priority = -10` **so the world ticks before the actors read it** (today the
  island, as the parent, updates the actors first and they see each tick one frame late).
- `stage_ui.gd`: in `_on_ability` and `_on_mode`, for modes other than Attack, also call
  `island.hosts[0].driver.layer.trigger(ability.id, {target = selected_id})` (keep the
  message); on `dodge_pressed` store the direction hint for the player's host; set the
  observe stance while `ui.mode == OBSERVE` and a creature is selected.
- Actors farther than 40 m from the player: base layer only, no CCD; farther than 80 m:
  `layer.update` skipped (rest of the pipeline unchanged).

Accept (`game/tests/play_test.gd`, new section `_actions()`; needs `make godot`):
- real fight, player bites: the frame of the layer's `impact` and the frame in which
  `combat_events` delivered HIT with `a = 0` differ by <= 1 frame, over at least 5 hits; the
  enemy's bite or spit: the same for its `impact` against HIT with `b = 0` when the hit lands;
- during an enemy wind-up the enemy's action weight is >= 0.99 for all but the first 4 frames
  of the `W` ticks;
- determinism: section 4's test;
- no engine errors; `make godot-play-test` total grows from 178 and has 0 failures.

### Step 10. The remaining combat actions

Write the data for `spit`, `charge`, `tail_strike` (v1), `guard`, `dodge` (v1), `stagger`,
`stun`, `death`, `combat_ready`; the impulse reactions `hit`, `block_recoil` in
`action_layer.gd` (`react(kind, dir, magnitude)`, 2.2); `action_fx.gd` spit blob
(`SphereMesh` radius `0.08 * mouth size`, unshaded emissive green-yellow, linear flight with
a 0.15 * distance arc).

Accept, per action, ScriptedFeed on Merodeador, Zancuda, Babosa, Garfio and the 6 legged test
bodies plus `legless`:
- runs start to end without errors, all numbers finite, no joint over `1.15 * limit`, no
  joint under the ground, sole slide of stance legs < 2 mm for `plant` actions;
- timing: `impact` within 1 frame of `tau = W`; spit blob's arrival within 1 frame of
  `tau = W`; tail tip crosses the body's forward half-plane on the strike side during the
  active window for bodies with `tail` (v1: at least reaches its maximum signed yaw within
  the active window); guard holds a constant pose (bone speeds < 0.5 rad/s) from `a:1` to
  the end of the hold; dodge roll has the sign of the dash;
- interrupts: every action cancelled at 5 random times: weight 0 within `fade.cancel` + 1
  frame, max bone speed < 25 rad/s;
- death: belly within 5 cm of the ground at the end, the pose is still (speeds < 0.01) 1 s
  later, and a revive (`dead` false + teleport) restores the loco-only pose.

**10b (optional, 10 lines, only if `make godot` works):** in `cpore_world.cpp` fighters add
`f["stun"] = c.stun_t; f["slow"] = c.slow_t; f["bleed"] = c.bleed_t; f["dash"] =
Vector2(c.dash_x, c.dash_y); f["alive"] = c.alive;`. The feed uses them when present (stun
length, dodge direction during the first tick). No C change.

### Step 11. Idle

`idle_base.json`, fidget files, the look-at chooser and the fidget scheduler in the layer.

Accept: 60 s idle on each of the 4 creatures: no errors, blink count 12 to 18, at least one
fidget, root motion amplitude < 3 % of height, sole slide 0; while walking at Fr 0.25 the
loco foot-slide gate (< 20 mm, here expect 0) holds with the layer on.

### Step 12. Cosmetic driver, social, intimidate, observe

`trigger()` quantises the start to the next tick boundary and runs the W/A/R of `ticks`.
Data: `sing`, `dance` (v1), `charm`, `pose`, `gift`, `roar`, `display`, `observe`, `attend`;
the gift item FX; `beat` in `ctx` from the placeholder formula (2.3).

Accept: every action on the 4 creatures and the 7 bodies as in step 10; **rhythm**: for sing
and dance started so that a beat lies in the active window, one accent (the maximum of
`root.lift` for sing's bob, the minimum for dance's dip) is within 1 frame of the beat tick,
for all 12 beat phases; when no beat lies in the window the first accent is at `a:0`;
`attend` nods within 1 frame of each beat; observe: `still` reaches 1 within 0.4 s of
stopping and the maximum bone speed is then < 0.05 rad/s; triggering any of these sends
nothing to C (`stage.log_inputs` contains no new verbs; determinism test repeated with
cosmetic triggers in the script).

### Step 13. Scripted stepper (v2 legs)

`actions/action_legs.gd`: owns foot targets of legs that an action takes over.

- `legs.gesture` (`paw`, `stomp`, `hold_up`, `limp`): leg `i` leaves its planted point `F`
  along a local path and **returns to exactly `F`** (`paw`: lift `0.12 h`, back `0.25 h`,
  down, forward on the ground is forbidden: the return to `F` is in the air; `stomp`: lift
  `0.15 h`, down in `0.06 s`, event `foot_stomp`). While lifted, `pose.contact[i] = false`.
  A leg may be taken only if it is in stance and the centre of mass stays inside the support
  polygon of the other stance feet (`loco_support.gd`), after shifting `root.side` by up to
  `side_cap` toward that polygon; otherwise the gesture is skipped.
- `hop`: all legs go to hip-relative tucked targets (ease 0.05 s), body `root.lift` arc;
  landing targets = the controller's homes under the current C position.
- `pivot`: two alternating sets re-place their feet to the homes under the body rotated by
  the action's `root.yaw`, each swing >= 0.12 s, arc `0.1 h`; the stance set stays planted
  and the guard limits the yaw rate.
- `brace`: one corrective step per leg to homes scaled by 1.15 in x.
- Hand-back: new method in `loco_controller.gd`,
  `func adopt_feet(feet: PackedVector3Array, mask: Array) -> void`: for each masked leg set
  `l.swing = false`, `l.foot`, `l.g_to`, `l.dir`, `l.ball` (as `reset()` does for one leg),
  nothing else. And make `_ankle_at` reachable as `ankle_at(i, phi)`.
- Use it in `dodge` (hop), `tail_strike` (pivot / hop-turn), `charge` (paw), `roar` and
  `dance` (stomp), `guard` (brace), `display` (tiptoe, rear), `death` (limp).

Accept: for every stepper action on the 6 legged bodies and the 3 legged creatures: a foot
flagged `contact` never moves (< 2 mm) between its touchdown and its lift-off; every lifted
foot returns within 2 mm of where the stepper says it lands; after the action
`adopt_feet` leaves the controller with `forced_lifts` unchanged and no corrective step in
the next second when the body ended where it began; centre of mass inside the support
polygon for every frame of a `gesture` (not for `hop`); `godot-loco-test` still 192.

### Step 14. Evidence (`docs/evidence/godot/actions/`)

`actions/test/capture.gd` (SceneTree script; ScriptedFeed, no C extension): a plain stage like
`creature/tools/render_evidence.gd` (same light and ground), side-quarter orthographic camera
framed on `rest_aabb()` grown by 60 % toward the front, a grey target capsule of radius 0.6 m
standing at the C attack distance (`0.92 * reach + own radius`... use: own radius + 0.6 +
`0.92 * reach` between centres, capped so it stays in frame).

- **Strips**: one PNG per action, `strip_<action>.png`: 3 rows (Merodeador, Zancuda, Babosa)
  x 8 frames (240 x 200 each, 1920 x 600) at `tau` = `w:0, w:0.5, w:0.85, a:0, a:0.5, r:0,
  r:0.5, s:1` (stances and idle: 8 evenly spaced times). A thin bar under each frame shows
  the segment colour (wind-up amber, active red, recovery grey) and the frame's `tau`.
  Frame `a:0` is the hit frame: check by eye that it is the contact pose.
- **Test bodies**: `bodies_<class>.png` for combat, social, other: rows = the 6 bodies,
  columns = the actions of that class at their most characteristic time (`a:0` or `a:0.5`).
- **Clips** (movie writer, 640 x 360, 30 fps, as `locomotion/test/movie.tscn`):
  `clip_<creature>.mp4` for Merodeador, Zancuda, Babosa: every action in sequence with a
  label (`action  segment  tau`), about 40 s each; then
  `ffmpeg -c:v libx264 -crf 28`. One more, `clip_fight.mp4`, 15 s of a scripted fight
  (ScriptedFeed, Merodeador against Garfio, both animated: bite, guard and block, dodge,
  spit hit and flinch, death).
- `measurements.json`: per action and body: impact frame error, maximum sole slide, maximum
  joint share of limit, guard `k` minimum, maximum bone speed.

Command line arguments `-- out=<dir> actions=bite,spit creatures=Merodeador` so single strips
can be re-rendered without the whole set (fans). Whole set: 19 strips + 3 sheets + 4 clips.

Accept: files exist and were **looked at**; `ACTIONS.md` lists, per action, anything that
looks wrong.

### Step 15. Documents

`docs/godot/ACTIONS.md` in the form of `LOCOMOTION.md`: model, measurements table from
`measurements.json`, evidence list, "still unconvincing", the channel table, how to add an
action. Update `godot/README.md` (one paragraph) and `docs/godot/WIRE.md` connections table
(two rows). Optional: three buttons in the studio's Test mode (Bite, Sing, Roar, as the web
studio had Bite and Sing) calling `layer.trigger` on the view's creature.

---

## 6. Risks and what will still look unconvincing

**Risks**

1. **C geometry is not the drawn geometry** (0.5). The mouth will often close on air near the
   target or inside it. Mitigated by clamped goals; a real fix needs C radii or reach to
   follow the visible body (game design, not animation).
2. **Short tells on big bodies.** 0.3 s for a 6 m Merodeador's bite or tail strike is
   physically absurd; the pose changes are large and fast. The data keeps amplitudes
   moderate for `graviportal`; ticks are C's and are not scaled by mass.
3. **One-tick interpolation latency.** Positions are drawn one tick late while events are
   shown at once. For a charge the HIT appears when the drawn attacker is still up to one
   tick (1 m) short of contact. The layer does not hide this; delaying event-driven reactions
   by `1 - alpha` ticks for dash moves is a possible later tweak (it would also have to delay
   the damage number and sound to stay consistent).
4. **Process order.** Step 9 moves the world tick before the actor update. If something else
   relied on the old order (camera, UI), the play test will show it; the fallback is to keep
   the order and accept exactly one frame of lag (still inside the gate).
5. **Springs versus timing.** Any keyed channel accidentally left with `kin < 1` will lag the
   hit. The timing tests measure the event frame, not the pose; add a pose check per combat
   action (jaw closed, tail past centre) as in step 10.
6. **Skinning.** Strong bends pinch the tube at bone heads and open seams at part roots
   (`CREATURE.md` section 4). Limits of 0.55 rad per joint keep it tolerable; coiled long
   necks will show it first.
7. **`body.inflate` scales the whole body root**, parts included, and moves the hips a
   little; over 8 % it looks like a zoom. A chest-only swell needs a vertex shader term in
   the skin shader (not planned).
8. **CCD** can flip between two solutions when the goal passes near the chain's base (target
   under the chin). Warm start, damping and the clamp on distance reduce it; the jitter test
   in step 7 is the guard.
9. **The stepper (step 13) is the riskiest step.** It duplicates a little of the controller's
   job; `adopt_feet` must leave the controller consistent or it will take corrective steps
   after every action. Everything before step 13 is shippable without it (v1 variants).
10. **Dash gaits.** The controller low-passes speed (0.12 s) and its stride clock is slow for
    tall bodies, so in a 0.5 s charge or a 0.3 s dodge the legs lag the body; the existing
    reach guard may drop the body. v2 `hop` covers the dodge; the charge keeps this flaw.
11. **Social timings and the beat are placeholders** until the C verbs exist; the beat phase
    formula will not match C's. Only `action_feed.gd` and the `ctx.beat` source change then.
12. **Cost.** GDScript, about 19 bones, CCD 3 iterations, some 40 springs per actor. Expected
    well under 0.2 ms per actor; the distance cut-offs of step 9 bound it. Not measured yet.

**Will still look unconvincing**

- No contact response: a bite does not grip, the target's flesh does not give, a blocked hit
  does not stop on the guard; the victim only flinches.
- Quadruped trunks stay rigid between the leg stations (no arched back, no cat-like coil).
- Arms and wings are single hinges; "offer with the arms" is a hinge swinging forward.
- No face beyond jaw and eyelids; the eyes do not track.
- The tail strike has to reach the front cone: v1 is a hip swing that does not get there for
  short tails, v2 is a stylised hop-pivot.
- Death is a posed collapse, not a ragdoll; on slopes the corpse does not conform to the
  ground.
- Giant and tiny creatures act at the same speed (C ticks), so weight does not read from
  timing, only from amplitudes and spring frequencies.
- Dance is one second long (P4 active window): three accents, more a flourish than a dance.
- The spit is a sphere on an arc; no splash, no trail.
- Legless bodies cannot slide their belly contact during lunges (the root lunge is small by
  design), so their strikes are mostly neck.
