# Procedural action animation (G77, `godot/actions/`)

Every action (bite, charge, spit, tail strike, guard, dodge, hit, stagger, stun, death, the Befriend and Intimidate moves,
Observe, idle) is built at runtime from the creature's own bones and synced to the C combat phases. The design is
[PLAN-actions.md](PLAN-actions.md); this file says what was built, how it was measured and what still looks wrong.
The plan's section 0.6 lists the corrections found while implementing.

## Model

* `action_clock.gd`: pure time functions. `tau = (e - 1) + alpha` ticks, `e` from the C fighter state; the first state of a
  move has `e = 1`, the state that carries the HIT has `e = W + 1`, so a pose keyed at `tau = W` lands on the damage.
* `action_feed.gd`: `StageWorld` states and `combat.events` -> a signal per entity (move, phase, `tau`, events addressed to
  entity ids once per tick, `start`/`end`/`cancel` marks). Read only.
* `action_data.gd` + `data/*.json` (26 files, schema `cpore.action/1`): one file per action, tracks of keys over `w`, `a`,
  `r`, `s` (wind-up, active, recovery, settle) on a fixed channel vocabulary, variants per body capability.
* `action_body_map.gd`: the body as the solver sees it: bone chains beyond the leg anchors, limits per joint, mouth point,
  capabilities (`jaw`, `tail`, `long_neck`, `legless`, ...) and capacities.
* `action_solver.gd`: the retargeter. Root delta guarded so planted feet stay reachable, head posture, aim, CCD reach with
  the body lunge taking what the neck cannot, tail, ground clearance, a rate limit.
* `action_springs.gd`: springs per channel; an action-keyed channel is slaved (exact timing) and released with its velocity.
* `action_layer.gd`: per actor slots and priorities, weights and fades, cancel by C state, impulses for hits and blocks,
  idle (breathing, blink, look-around, fidgets), cosmetic triggers quantised to the tick, stances (observe, attend,
  combat-ready), events out (`impact`, `spit_release`, `cry`, `shake`).
* `action_rig.gd`: jaw, pincers, lids, sway, wings, arms, sacs and body inflate written to the rig's hook nodes every frame.
* `action_fx.gd`: the spit blob. Wiring: `game/actors/actor_driver.gd` (layer per creature), `game/island/island.gd`
  (feed, ctx, stage ticks first), `game/stage/stage_ui.gd` (abilities, dodge hint, mode).

## Channels

`root.lunge|side|lift|pitch|roll|yaw`, `body.inflate`, `head.pitch|yaw|roll`, `neck.coil`, `head.aim` (+ goal),
`head.reach` (+ goal), `jaw.open|tremble`, `tail.pitch|yaw|curl|stiff`, `display`, `arms`, `lids`, `sacs`, `still`.
Values are normalised to the body (a share of its range or capacity), so one file serves a 0.5 m and a 6 m creature.
Goals: `target_surface`, `target_head`, `target_ground`, `ground_front`, `forward`, `up`, `sky_target`, `away`, `item`.

## How to add an action

Copy a file in `data/`, change `id`, `class`, `driver` (`c_move` with `move`, `c_state`, `cosmetic`, `stance`, `idle`),
`ticks`, tracks, `variants`. Unknown keys and channels are errors at load. A cosmetic action is started with
`layer.trigger(id)`; a new C move needs its entry in `Clock.TICKS` and `MOVE_NAMES`. A new channel is code (solver or rig).

## Measurements

`make godot-actions-test`: 322 checks, 0 failures (clock, feed, data, body map on 4 real creatures, plumbing, bite end to
end, solver, springs, every combat action on Merodeador, Zancuda, Babosa and Garfio, idle, cosmetic, read-only).
`make godot-play-test`: 186 checks (was 178), 0 failures, real C world: every C HIT of the session (the player's charges,
the enemy's bite) is matched by a layer `impact` within 1 frame, the enemy wind-up weight is >= 0.99 after the first 4
frames, the session log replays to the same hashes, a cosmetic roar sends no verb to C. Also green: `godot-loco-test` 216,
`godot-creature-test` 1456, `godot-feel-test` 76, `godot-test` 326.

From `capture.gd` (60 fps, Merodeador / Zancuda / Babosa, flat ground, scripted feed; `docs/evidence/godot/actions/measurements.json`):

| action | body | max bone speed (rad/s) | max sole slide, plant actions (mm) | min guard k |
|---|---|--:|--:|--:|
| bite | Babosa | 20.7 | 0.0000 | 1.00 |
| bite | Merodeador | 15.4 | 0.0003 | 0.62 |
| bite | Zancuda | 22.6 | 0.0003 | 1.00 |
| charge | Babosa | 3.9 | 0.0000 | 1.00 |
| charge | Merodeador | 8.0 | 0.0000 | 1.00 |
| charge | Zancuda | 2.8 | 0.0000 | 1.00 |
| death | Babosa | 2.0 | 0.0000 | 1.00 |
| death | Merodeador | 3.4 | 0.0000 | 1.00 |
| death | Zancuda | 3.0 | 0.0000 | 1.00 |
| dodge | Babosa | 2.9 | 0.0000 | 1.00 |
| dodge | Merodeador | 3.4 | 0.0000 | 1.00 |
| dodge | Zancuda | 3.0 | 0.0000 | 0.27 |
| guard | Babosa | 16.0 | 0.0000 | 1.00 |
| guard | Merodeador | 13.9 | 0.0004 | 1.00 |
| guard | Zancuda | 13.7 | 0.0002 | 1.00 |
| roar | Babosa | 16.0 | 0.0000 | 1.00 |
| roar | Merodeador | 16.0 | 0.0003 | 1.00 |
| roar | Zancuda | 22.6 | 0.0002 | 1.00 |
| sing | Babosa | 6.1 | 0.0000 | 1.00 |
| sing | Merodeador | 2.5 | 0.0002 | 0.50 |
| sing | Zancuda | 3.9 | 0.0002 | 0.61 |
| spit | Babosa | 22.6 | 0.0000 | 1.00 |
| spit | Merodeador | 22.6 | 0.0002 | 1.00 |
| spit | Zancuda | 22.6 | 0.0002 | 1.00 |
| stagger | Babosa | 2.8 | 0.0000 | 1.00 |
| stagger | Merodeador | 3.0 | 0.0000 | 1.00 |
| stagger | Zancuda | 2.4 | 0.0000 | 1.00 |
| tail_strike | Babosa | 16.0 | 0.0000 | 1.00 |
| tail_strike | Merodeador | 10.3 | 0.0004 | 0.44 |
| tail_strike | Zancuda | 12.5 | 0.0002 | 1.00 |

Bone speeds stay under the 25 rad/s gate (the solver rate-limits at 16 rad/s per bone). Stance soles do not move in
`plant` actions (slide below 0.001 mm). `k < 1` is the reach guard cutting the lunge of a standing quadruped.

## Evidence (`docs/evidence/godot/actions/`)

`strip_<action>.png` for bite, charge, spit, tail_strike (seen from above), guard, dodge, stagger, death, roar, sing: three
rows (Merodeador, Zancuda, Babosa), eight columns: wind-up 0, 0.5, 0.85, active 0, 0.5, recovery 0, 0.5, settle. The bar
under a frame is the segment colour (amber wind-up, red active, grey recovery, green settle) and the label gives `tau`.
Looked at: bite (Merodeador shows the open-mouth tell, the strike lands on the target at `a:0`, the jaw shuts, the heron
Zancuda cocks up and stabs down, Babosa rears and drops), charge (crouch, head down, tail up), spit (inhale, strike,
recoil), tail strike (top view), death.

## Still unconvincing

* No contact response: the bite does not grip, the victim only flinches; a blocked hit does not stop on the guard.
* The charge dash is C's translation; in the strips (no world) the body only crouches. Legs lag a dash as before (loco).
* Tail strike: v1 hip swing (`root.yaw` and tail yaw), short tails do not reach the front cone; the planned hop-pivot
  (step 13) and the whip `lag` are not built. Guard, dodge and display have no leg action (`legs` is accepted, treated as `plant`).
* Quadruped trunks stay rigid between the leg stations; arms and wings are single hinges; eyes do not track.
* Observe stalking has no head stabilisation; `attend` and the cosmetic moves use a placeholder beat (`7 * id % 12`), not C's.
* Death is a posed collapse, the corpse does not conform to slopes.
* Only the four real creatures are tested; the capsule test bodies and the clips (`clip_*.mp4`) were not produced.
* Everything was judged under software GL and 60 fps headless; the feel in motion on a real GPU is for the owner.
