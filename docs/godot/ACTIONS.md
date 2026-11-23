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

## Round 2 (C1-anim2): hit reaction, roar, bite grip, charge run-up

Owner feedback from the evidence strips. Timings stay tied to the C phases (no C timing touched); everything below is
GDScript and data (`godot/actions/`).

* **Hit reaction.** `react("hit")` is stronger and scaled by damage: recoil away along the hit direction, head snap back,
  a 2-3 frame squash (spring dip of `root.lift`) and side/roll wobble; the `hit` one-shot adds a keyed squash and head
  snap. The `stagger` action was rewritten (recoil to -1.0 of the lunge range, rock back, head thrown up then dropping, a
  brief stumble from the free legs), and its instance amplitude follows the damage of the HIT that caused it (`amp`,
  0.6 to 1.6).
* **Roar.** The active phase no longer reaches at the target: head up and back (`head.pitch` held at 0.6), reach pulled
  back, a slight rear (`root.pitch` +, `root.lunge` -), jaw held wide, chest inflated, display raised. A pulse
  (`action_fx.roar_ring`: two expanding ground rings, cosmetic) is spawned by the `cry` event in `actor_driver.gd`.
* **Bite grip.** On a connecting bite (`hit` flag, set from C's HIT event) the jaw stays shut and the head stays on the
  target through the active tick and the first half of the recovery, the head tugs (9 Hz pitch and yaw), the body pulls
  back a little, then the jaw opens on release. The bitten creature is pulled toward the biter and shaken for 0.3 s
  (`_pull` in the layer, visual only: C owns positions).
* **Charge.** Run-up: crouch (wind-up), explosive stretch at the start of the active phase (`root.lunge` +0.5,
  `root.pitch` -0.22, head low at -0.85, tail streaming back), legs at the gallop the loco gives the C displacement
  (1 m per tick, which is what the strip harness feeds the body), then on C's HIT a new `strike` one-shot squashes and
  rebounds the attacker, the stretch is cancelled, and the target gets the stronger hit reaction (charge factor 1.5).
* **Harness fix.** `harness.gd` dropped the marks and events of a tick (the feed delivers them once, with the first read);
  existing tests ran without them. They now reach the layer, so the hit and bite tests exercise the real path.
* **Tests** (`_t_round2`, 19 new checks): recoil, squash and head snap values, damage scaling, roar (no forward reach, head
  held up, jaw held, inflated, ring visible), bite grip against a miss (jaw, head reach, tug), the victim's pull and its
  release, charge stretch and the strike squash. Counts: actions 341, play 197, devtools 714, M0 533.
* **Evidence.** `strip_bite.png`, `strip_stagger.png`, `strip_roar.png`, `strip_charge.png` are 6 frames at fixed action
  times (labels show `tau`), three bodies. The strip target is a capsule that stands in for the other creature's layer
  (it recoils, squashes, is pulled by the bite). Looked at on Merodeador, Zancuda and Babosa under software GL.

What still looks weak:

* Zancuda's bite grip: the long neck tucks and wobbles into a folded S during the tug rather than holding on, and its
  mouth does not reach the capsule at the strip's distance. The heron bite was never a bite on a surface.
* The roar rings are plain thin tori; dust or a distortion would read better. Merodeador's head held up at the end of the
  roar drops quickly in the recovery.
* Stagger on Merodeador rears more than the owner may want (head snap amplitude is one number for every body).
* The victim pull for the bite and the charge stagger of the target are only exercised in tests and with the capsule
  stand-in; a two-creature fight on screen was not captured. The `measurements.json` table above was not regenerated for
  these four actions (the bone-speed gate of 25 rad/s is still asserted by the all-actions test).
* The charge dash in the strip is 10 m/s fed by the harness, not the C world; in the game the same displacement arrives
  from the C positions.

## A64 bite port (combat/bite-port): the lunge+peck hybrid, the chain and the shared melee impact

Source: `web/gaitlab/bite2.html` version 3 (the bite) and 4 (the chain), `docs/evidence/loco/bite.md` round 2.

**C timing was NOT changed.** The lab contact is at 760 ms (310 coil + 310 hold + 140 strike); C's bite is 3/1/2 ticks (contact at 300 ms). Retiming the bite to about 7/1/6 failed 25 checks in `combat_test` (the counter-matrix reaction windows, the one-fast-move riposte, the telegraph budget), the stage goldens, `world_test` and `social_test`, and would collide with the four C branches in flight. So `bite.json` compresses the hybrid into C's 3 wind-up ticks: coil with the neck cocked in an S and the jaws opening (w 0..0.35), a locked-on hold (0.35..0.62), body drive (0.62..1, ease-in) and the head whip over the last 50 ms (0.83..1); beak contact = a:0 = the C hit tick. Post-contact numbers are the lab's: the 80 ms hit-pause sits in the active tick, hold-on through the recovery, the pull-out in a 0.5 s settle. The 760 ms pre-contact timing needs a C change for the owner to decide (see the report of this branch).

**Chain.** No C change. Pressing bite within 7 ticks (`CHAIN_TICKS`) of our own bite landing sends a PECK order (stage_ui.gd `chain_open`, needs the peck in the loadout; the standing attack returns to bite afterwards). The layer plays any peck that starts within 7 combat ticks of its own bite hit as `peck_chain` (`data/peck_chain.json`, starts from the hold-on pose), otherwise the plain `peck.json`. Peck's own numbers are the reduced damage (7 against 9, 1.6 stamina).

**Shared melee impact** (`actions/impact_fx.gd`, every melee move: bite, charge, tail strike, claw, peck, pounce, stomp):
hit-pause 60 ms (small) to 90 ms (big) freezing both layers (`action_layer.hit_pause`, C keeps ticking); victim flinch and knockback along the hit direction scaled by attacker/victim height; dust puff and sparks at the beak contact point (`hit_fx` event, never blood); camera shake `island.melee_impact` scaled by size and damage and by distance; victim flash (`layer.flash`, a material overlay); `audio.hit` pitched and weighted by body size.
Tests: `make godot-actions-test` (414 checks, new section `impact (A64)`); clip: `godot/game/tests/bite_clip.gd`.

### A65 on this branch: the peck is a galloping strike; click to eat

* **C (`core/src/combat.c`, goldens untouched: nothing in them uses the peck).** `peck` is now `CB_F_DASH | CB_F_NO_WATER`, role engage: wind-up 3 (gather), active 3 (4.5 m of run, ends on contact, the last metres home on the target so it does not run past), recovery 3, 8 stamina, 14 damage (was 9, a starting value), 6 s cooldown (60 ticks). Inside `CB_PECK_MIN_RUN` (2.5 m of gap) there is no run-up: the order becomes the standing bite (if the bite is equipped and ready). Right after a connected move (`hit_mask` set and `since_spend <= CB_CHAIN_TICKS`, 7) it is the A64 chain jab instead: no dash vector, reach 1.8 m, half damage, no cooldown spent. No new state, no snapshot or hash change. Tests: `combat_test` `galloping_peck` (gallop hits for 14 from 4.2 m and moves the attacker, cooldown starts, bite fallback at 1.6 m, the jab is in place at reduced damage with no cooldown).
* **Godot.** `peck.json` is the gallop (gather, run with the head reaching out, a short beak lunge on a hit), `peck_chain.json` the jab; the layer plays `peck_chain` when the peck starts within 7 ticks of its own bite hit. The loco gallops from the C displacement (burst start as merged on main). The A64 impact effects apply to it like to every melee move.
* **Click to eat.** `stage_ui._on_clicked`: no verb armed, not in a fight, and the body is edible (`_edible`: remains with meat and a diet that takes meat) sends the same `eat` order as R and walks or runs there; the hover shows the eat marker and a hand cursor. A living creature is still selected with its ring. Only carcasses are edible bodies in the C eat flow today; fruit and plants have no eat order yet.
* **Play tests:** `godot/game/tests/click_peck_test.gd` (xvfb, software GL): click a carcass and it is eaten; a living Rondo is only selected; the peck from 4 m gallops, closes the distance and hits for 14.5; at 1.6 m the order starts the bite.
