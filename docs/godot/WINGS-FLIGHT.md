# Wings and the flight test mode (slices W2 + F1)

Plan: `_agent/briefs/motion-flight-plan.md` section 3 and 4. Branch `loco-wings-flight`. Dev builds only (`Dev.enabled`);
the C world is untouched (flight moves to C in slice F2, after run-fall merges).

## Try it

```
make godot-fly        # the light winged test creature "Planeador" on a cliff plateau (GPU, you playing)
```

or, with your own creature: put a wing in the creator (`Ala` section appears when a wing part is selected), then play. In dev
builds the starter filter keeps `wing_*` parts. In the console: `fly report` (numbers of your wings), `fly off`, `fly land`.
F3 tuning, group `flight`: `lift_mul` (global lift gain, default 1), `power_mul`, `cd0_mul`, `enabled`.

Controls (decision D6): **Space** on the ground takes off (a run helps; the HUD says why a body cannot), in the air Space tap = one
beat, hold = flap, release = glide. **Ctrl** dive (wings fold to 40 % of the span). **S / W** pitch (slower and floatier / faster).
**A / D** roll left / right and the **mouse** (sideways = bank, up / down = pitch) do the same. Turning is bird-like (see
"How the bird turns" below). Landing is an automatic flare below 1.5 body lengths of altitude.

Merodeador (6 t) cannot fly by physics (stall about 120 m/s): the HUD and `fly report` say so. Raise `flight/lift_mul` to about 60
to try it anyway (D4: a global fun knob, never per creature). Dev builds only (A31): `FlightMode.lift_gain()` is 1 whenever `Dev.enabled` is false, so in normal play physics alone decides who flies.

## Genome: the `wing` block

Optional keys on a wing part (`wing_glider`, `wing_insect`, new `wing_vane`, `wing_flap`); schema stays `cpore.creature/5`:
`span` (m per side at size 1, 0.3 to 6), `breadth` (chord / span, 0.12 to 1.2), `spars` (1 to 5), `anchor` (`flank`, `hind`, `none`),
`mode` (`forelimb`, `extra`), `fold` (`flank`, `back`, `spread`), `muscle` (flight muscle share of mass, 0.08 to 0.25).
Absent keys keep today's look (legacy sizing from the body). Validation is in `creature/creature_genome.gd`, defaults and the four
families (best L/D 8, 11, 5, 2.5) in `creature/creature_wing.gd`. The built wing group carries meta `wing_info`
(span, area, chord, muscle, family constants), which the flight model reads.

## Model (`game/player/flight_test.gd`)

Point mass, lift `1/2 rho V^2 S CL lift_mul`, drag `1/2 rho V^2 S (CD0 + k CL^2)`, `k = 1/(pi e AR)`, `CD0` from the family's best
L/D, bank `t = tan(phi)`, dive area x0.4 with CL 0.2, flare commands the lift for a 0.3 to 1.5 m/s sink, flap thrust
`eta P / max(V, 3)` with `P = muscle m 150 W` (x2 burst while stamina lasts, drains in 12 s), landing damage from the equivalent
drop `vy^2 / 2g` minus 2 m (placeholders until run-fall's curve lands). + - * / and sqrt only in the physics.

While flying, the island sends the C world a WAIT order and a debug teleport (op 1) to the flyer's ground point every tick; the
teleports are logged, the session replays (checked by `make godot-flight-test`). A fight starting ends the flight.

## Kinematics (`locomotion/loco_wing.gd`)

Eased channels (flap, sweep, incidence, span, vane spread) driven by the flight state: ground pose = the action layer's
display-0 pose (no pop on hand-off), glide dihedral, beat `f = 4.5 m^(-1/6)` Hz, 58 % downstroke, 25 % span retraction on the
upstroke for membranes and vanes, pitch reversal for sails, dive fold, flare cup. Hinge only (rigid sails flap as a unit); the
vane wing's fan opens and closes. The legs are tucked while airborne (`actor_driver.gd` `_update_flight`).

## Tests and evidence

`game/tests/test_flight.gd` (in `make godot-test`): genome block, four families, kinematics, physics. `make godot-flight-test`: the
scripted flight on the real island. `make godot-flight-evidence`: contact sheets in `docs/evidence/godot/wings-flight/`.

## Numbers (this branch)

Plan's 30 kg vane flyer (S 3.7 m2, AR 7): stall 9.3 m/s, settled glide 10.9:1 against the polar's 11. The test creature Planeador
(game/data/flyer.json, 1.1 m, 48 kg, wings 2.4 m per side, breadth 0.3): S 3.46 m2, AR 6.7, loading 135 N/m2, stall 12.1 m/s,
L/D 11, 1290 W available against 635 W needed: it flaps, takes off from a standstill with the burst, and cannot run to 11 m/s.
Suites: godot-test 1004 checks (105 in test_flight.gd), ui 784, creature 1554 + realism 64 + radial 278, studio 881, devtools 833,
loco 254, play 217, flight scenario 22, all with 0 failures.

## Known limits

Hinge-only wings (W1 brings jointed membranes); the legs tuck but the spine keeps its last ground bend; roll of the camera is not
followed; pointer steering is not wired in the air (A/D only); landing damage is reported (HUD, console) but not applied to hp
until run-fall's curve exists; the mass of wings and flight muscle does not yet feed `loco_rig_adapter.gd`.


## How the bird turns

Roll leads, yaw follows. A / D (or sideways mouse) command a roll *rate* (d tan(bank)/dt = 1.1, lagged 0.2 s): a tap banks gently
(about 20 degrees), holding 0.6 s gives 30 degrees, 1.7 s the sharpest 60 degrees (`BANK_MAX_T = tan 60`). There is no direct yaw:
the heading changes only through the horizontal part of the tilted lift, rate = g tan(phi) / v. Releasing the key rolls back
to level (proportional, at most 1.3 tan/s). In a bank the bird pulls up, CL x 1/cos(phi) up to CL_MAX, to hold altitude, so it
bleeds speed (induced drag); past CL_MAX (too steep or too slow) it sinks and the HUD says "BANK TOO STEEP: sinking".
Presentation: the inner wing is flexed (shorter, swept back) and held higher, the outer wing extended (`loco_wing.gd`, `bank`
channel); the neck rolls back against the body so the head keeps within 8 % of the bank of the horizon (`HEAD_STAB`), the
tail twists into the turn and fans (`actor_driver.gd`). The camera follows the flight path with a 0.7 s yaw lag and rolls 30 %
of the bank, eased over 0.35 s. Evidence: `docs/evidence/godot/bird-turn/` (behind and side sequences, `turn.csv`).
