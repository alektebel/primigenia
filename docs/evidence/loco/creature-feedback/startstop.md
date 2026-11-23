# Starting and stopping (A54, owner's number one)

C numbers, measured with a flat world, starter B body (r 0.85 m, walk 1.06 m/s, run 2.65 m/s at sprint_k 1.5) and the hero body
(r 3.4 m): ticks of 0.1 s, speed against the held top speed. Harness: a heading order held 40 ticks, then WAIT.

Before (accel 15, brake 20, ease 0.6):

```
r=85 walk top 1.06 m/s | start: first tick 0.64, 50% at 0.1 s, 90% at 0.3 s | stop: first tick 0.42, at rest after 0.5 s, distance 0.07 m
r=85 run  top 2.65 m/s | start: first tick 1.49, 50% at 0.1 s, 90% at 0.3 s | stop: first tick 1.06, at rest after 0.6 s, distance 0.17 m
r=340 walk top 2.12 m/s | start: first tick 1.27, 50% at 0.1 s, 90% at 0.3 s | stop: first tick 0.85, at rest after 0.6 s, distance 0.14 m
r=340 run  top 5.29 m/s | start: first tick 1.38, 50% at 0.2 s, 90% at 0.4 s | stop: first tick 3.45, at rest after 0.8 s, distance 0.61 m
```

After (accel 7, brake 7, ease 0.45; pivot_mul 2.0 -> 1.2; the wall detector counts a creep of 0.1 m/s as pushing):

```
r=85 walk top 1.06 m/s | start: first tick 0.48, 50% at 0.2 s, 90% at 0.4 s | stop: first tick 0.58, at rest after 0.8 s, distance 0.13 m
r=85 run  top 2.65 m/s | start: first tick 0.69, 50% at 0.2 s, 90% at 0.5 s | stop: first tick 1.95, at rest after 1.0 s, distance 0.47 m
r=340 walk top 2.12 m/s | start: first tick 0.65, 50% at 0.2 s, 90% at 0.5 s | stop: first tick 1.47, at rest after 0.9 s, distance 0.33 m
r=340 run  top 5.29 m/s | start: first tick 0.65, 50% at 0.5 s, 90% at 0.8 s | stop: first tick 4.65, at rest after 1.4 s, distance 1.99 m
```

Reading: B reaches 90% of walking speed in 0.4 s (was 0.3), 90% of its run in 0.5 s (was 0.3); the first tick no longer jumps to
60-100% of the speed (0.48 against 0.64 walking, 0.69 against 1.49 running). A walking stop takes 0.13 m (was 0.07), a running stop
0.47 m (was 0.17). The turn round from rest (pivot) takes 0.8 s for 180 degrees at 3.7 rad/s (was about 0.3 s at 6.1 rad/s).

Animation (devtools/zoo/loco_close.gd, startB, side camera, 30 fps; `startstop_before_*.jpg` against `startstop_after_*.jpg`, every
4th frame from the order): the quadruped leans into the launch (body pitch +11.8 degrees nose down at the first steps, it used to
pitch up to -6.2 degrees as if rearing), the stride law follows a rising target in 0.04 s instead of 0.15 s (the first steps no
longer shuffle at 2.6 strides/s while the speed ramps), the lean spring is underdamped (stop: nose dips 13 degrees and rocks back
once). Stance feet never slide (slip 0.00 m/s over the clip; the earlier clip showed up to 1.05 m/s and a 4.2 cm floating stance foot).
