# M1 gait optimiser

This offline experiment fits fourteen gait parameters independently for each body and speed. The pilot takes ten Godot body descriptions through a free-root MuJoCo simulation, scores each CMA-ES candidate over four seconds, and replays each winner. [Pilot findings and acceptance gates](../../docs/GAITOPT-REPORT.md)

## Reproduce the pilot

From the worktree root, using the existing venv and a headless Godot import:

```bash
PY=/home/diego/Desarrollo/cpore-wt/_agent/gaitopt-venv/bin/python
mkdir -p godot/bin
test -e godot/bin/libcpore.linux.template_debug.x86_64.so || \
  ln -s /home/diego/Desarrollo/cpore/godot/bin/libcpore.linux.template_debug.x86_64.so godot/bin/
timeout 600 nice -n 19 godot --headless --path godot --import
timeout 600 nice -n 19 godot --headless --path godot --check-only \
  --script res://../tools/gaitopt/export_bodies.gd
timeout 600 nice -n 19 godot --headless --path godot \
  --script res://../tools/gaitopt/export_bodies.gd -- /tmp/gaitopt-bodies.json
nice -n 19 "$PY" tools/gaitopt/optimise.py /tmp/gaitopt-bodies.json --workers 4 --generations 60
```

The checked-in results use MuJoCo 4.0.1, cma 4.6.0, population 24, diagonal CMA-ES, fixed per-fit seeds, 60 generations and 500 steps of 8 ms per candidate. The commanded Fr grid is 0.30, 0.50, 0.70, 2.0 and 3.0. The first 24 generations search over all gait choices. The remaining 36 are divided equally among that plan’s footfall templates, each seeded from its best candidate in the mixed search. The lowest measured cost over both stages wins. The runner accepts one to six worker processes and one to 150 generations. It sets niceness 19 and single-threaded numerical kernels. Use `--out /tmp/gaitopt-repeat` for a separate run.

The exporter takes seven named locomotion fixtures (including the octopod) and uses the production rig adapter for Garfio, Merodeador and a 0.18-scale Merodeador hatchling. Each description includes the adapter geometry and the result of `Morph.analyse`. Its optional `--catalog` argument after the output filename also exports the seven devtools zoo rigs and 200 deterministically sampled genomes with 2/4/6/8 legs, nominal spine lengths 0.3–6 m and varied proportions. The optimiser always selects the ten pilot IDs.

## Proxy and search space

The model uses metres, kilograms and seconds with +X forward, +Y left and +Z up. Three slides and a ball joint give the root six free degrees of freedom. A bounded horizontal velocity actuator guides it toward the command. Axial capsule masses come from spine frusta and end caps. Limb masses use tapered cross-sections and the feet use the morphology foot sizes. Point-like part masses attach at their exported positions. MuJoCo scales the assembled mass to the Godot morphology total. The front girdle has pitch and yaw joints, with neck and tail pitch joints where the segments exist. Each two-bone leg has hip roll, hip pitch and knee pitch. An ankle pitch actuator levels the ellipsoid foot. The swinging pelvis shifts toward each supporting leg in the biped reference. Foot-floor contact is resolved by the solver. The proximal thigh sockets and axial capsule seams overlap by construction and are excluded from self-collision checks.

| Control | Interpretation |
|---|---|
| Duty factor | Commanded stance fraction in the selected footfall template. The reported measured duty uses load-bearing contacts. |
| Relative stride | Stride in characteristic hip heights. Dividing commanded speed by stride gives cycle frequency. |
| Swing height | Peak ankle lift in hip heights. |
| Bounce share | Blends vault and spring body-height targets over a stride. |
| Standing hip ratio | Body lowering relative to the morphology's characteristic hip height. |
| Pitch gain, lean gain | Oscillatory trunk pitch and speed-dependent forward lean, applied through leg targets. |
| Spine flexion | Girdle pitch amplitude in gallop, radians. |
| Girdle yaw | Peak girdle rotation per cycle, radians. |
| Neck spring, tail spring | Multipliers on the corresponding axial PD stiffness. Damping scales with the square root of the multiplier. |
| Sequence offset, lead lag | Fore/hind offset around the chosen quadruped pattern, and left/right lead separation during gallop. |
| Gait | Walk/run for bipeds, walk/trot/gallop for quadrupeds, alternating support groups or a ripple for multi-legged bodies. |

The reference solves two-bone IK on the exported segment lengths and rests. Swing returns the foot with a smooth fore-aft displacement. Each hinge tracks its angle and angular velocity through a force-limited PD actuator. Limits scale as mass to the power 0.67. The root guide is capped at 0.18 body weights. Rollouts begin at commanded forward velocity in the starting gait pose. Initial kinetic energy is excluded from actuator work. The proxy approximates the meanings of the procedural controls, including pitch, bounce and appendage compliance. The game controller also has terrain adaptation, feedback and discrete foot planting.

## Reading one result

Each JSON in [results/pilot](results/pilot/) contains the morphology hash, seed, best parameters, best objective sampled by gait, weighted cost terms and observations for all five commands. A lower score wins. The `infeasible` term marks any fall, out-of-reach target, monitored self-contact, or majority support by non-foot geometry. Failed winners are preserved for inspection. `command_fr` uses exported hip height. `achieved_fr` uses net forward displacement over the actual four seconds. Reverse or zero progress yields a null achieved Fr and transport comparison.

| Weighted term | Calculation |
|---|---|
| Transport | Sum of positive hinge power integrated over time, divided by mass × gravity × net forward distance. |
| Guide | Five times the integral of absolute guide power with the same denominator. The separate guide fraction divides guide work by guide plus positive joint work. |
| Slip | Three times integrated tangential relative speed at loaded foot contacts, averaged over feet and divided by distance. |
| Torque | 0.25 times mean squared applied torque as a fraction of each motor limit. The actuator enforces saturation. |
| Impact | 0.08 times squared excess of peak total vertical ground reaction force over two body weights. |
| Head jerk | 0.002 times RMS vertical jerk, scaled by √(hip height / gravity) / gravity. Heights are averaged in 40 ms bins before differencing. |
| Non-foot support | 30 times the squared fraction of vertical ground impulse carried by non-foot geometry. |
| Speed error | 15 times mean squared fractional forward-speed error to penalise stalling. |
| Hard penalties | 10,000 once per infeasible trial. A trunk, neck, girdle or tail touching the floor, root height below 40% of standing hip height, or a trunk tilt past 57 degrees counts as a fall. Additional terms penalise fall duration, self-contact duration and maximum unreachable distance. |

The objective floors its distance denominator at 1% of hip height. Reported CoT uses actual positive progress. `mechanical_cot_j_kg_m` and `taylor_j_kg_m` both have units J/(kg m). Taylor's 10.7 M⁻⁰·³¹⁶ is a metabolic reference. The mechanical/metabolic ratio is the brief's external comparison, without an assumed muscle efficiency. Neither Taylor nor the empirical Froude transition bands enter the objective.

Measured duty and slip include loaded intervals at the start and end of the rollout. Touchdown timestamps and median same-foot stride distances support footfall inspection. For each body the Fr 0.50 winner also has a 100-frame, 25 fps replay. The encoder runs serially after the worker pool closes. The evidence runner probes software OSMesa and EGL in fresh processes and checks the actual GL renderer. The pilot used EGL with llvmpipe. Where software rendering is unavailable the runner writes a compressed time-indexed joint-position trace.
