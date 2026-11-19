# Run gait (track loco-run-gait)

Animation side of running, driven only by speed (so wild creatures use it too). The C sim's `set_run` is a separate task.

## What changed (`godot/locomotion/`)
- Gait ladders (Froude, Alexander): bipeds walk -> run (0.5); light quadrupeds walk -> trot (0.5) -> gallop (2.5);
  heavy (graviportal) quadrupeds walk -> amble (0.5) -> heavy trot (1.8, duty floor 0.5: no flight, so the Merodeador
  never leaves the ground; `make godot-feel-test` guards that); multi-leg bodies with 4 or more stations (centipede,
  octopod) use a metachronal `ripple` (stations land 0.75/n of a stride apart, sides in antiphase), 3 stations keep the tripod.
- stride x cadence = speed holds by construction at every gait (tested at run Froude numbers).
- Posture: forward lean in `run` (upright 0.16 rad, horizontal 0.07 at Fr >= 3), spine arch in a gallop
  (`Gait.spine_flex`, up to 0.11 rad, constant curvature about the centre of mass, hips follow the arch, `pose.spine_pitch(z)`
  and `pose.flex`, applied to the bones by the adapter), bob drive modulated +-7 % so strides are not identical.
  Head stabilisation and tail counterbalance were already in the controller.
- Not done: arm swing for bipeds (the rigs have no locomotion arm bones; open question), slope and turn-in-place rework
  (the existing slide tests at 20 % slopes, rough ground, slalom and pivots stay under 20 mm; nothing visibly wrong found).

## Testing before the sim runs
- Console `runvis [factor|off]` (dev builds): the player is shown moving `factor` (default 2.5) times faster than C moves it
  (`StageWorld.vis_speed`, presentation only, off drops the offset). Hold Sprint for the highest speed.
- Zoo: `zoo [morphs] [course] [run|factor]`, or `--run=2.5` standalone; orders carry sprint and the shown speed is multiplied.
- Evidence on the real rig: `locomotion/test/gait_real.gd` (`mode=sheet|measure`, `morph=hero|mite|giant|hexapod|centipede|trotter`);
  sheets in `docs/evidence/godot/run-gait/sheet_<morph>.png`, one row per gait, 8 frames over a stride.

## Tests
`make godot-loco-test` 299 checks (254 + 45 new in `test_run_gaits`); `make godot-devtools-test` 832 (827 + 5, run mode).
