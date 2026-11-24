# M1 gait optimiser pilot

**Experiment.** Ten morphologies competed at five independently commanded Froude numbers (0.30, 0.50, 0.70, 2.0 and 3.0). Each candidate had four seconds to move under its own joint torques with a bounded, measured forward guide. The final search budget was 60 generations of 24 candidates per body and speed. At each speed, 24 generations searched all fourteen parameters together and 36 refined the available gait families with equal budgets. The empirical transition and Taylor reference only enter the evaluation. [Method and reproduction commands](../tools/gaitopt/README.md)

## Interpreting the evidence

The hatchling on this branch is an experimental 0.18-scale Merodeador run through the real rig and morphology adapter. Garfio and adult Merodeador use the bundled game genomes. The remaining bodies come from the locomotion test fixtures. Each JSON includes commanded and achieved speed, measured and target duty, the work calculation, weighted objective terms, per-foot touchdown times, and the best cost sampled for each gait family. Each clip shows the Fr 0.50 winner for four seconds, including any fall. [Per-body data and clips](../tools/gaitopt/results/pilot/)

During the first search, some hexapod and octopod candidates travelled with little foot contact. Replay exposed limb-ground contact carrying load outside the measured feet. The final proxy bends sprawling knees outward, actuates ankle pitch, tracks target joint velocity and shifts the biped pelvis toward the supporting leg. The final objective uses total vertical ground reaction for impact and penalises the fraction of ground impulse carried by other geometry. Majority non-foot support counts as infeasible. These implementation choices and the speed-error penalty are additional to the brief's named cost terms.

## Intended commits

1. `feat(gaitopt): export legged morphologies and optimise a torque-limited MuJoCo gait proxy`
2. `docs(gaitopt): record ten-body pilot fits, software replays and realism gates`
