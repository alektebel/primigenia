# Loop scorecard (bot)

| metric | target | seed1 | seed42 | seed7 | status |
|---|---|---|---|---|---|
| time to first input | <= 10 s | 1.4 | 1.4 | 1.5 | pass |
| time to first select | <= 120 s | 0.1 | 0.1 | 0.1 | pass |
| time to hunt | <= 360 s | 93.9 | 81.1 | 90.4 | pass |
| time to friend | <= 720 s | 453 | 589 | 490 | pass |
| time to dig | <= 840 s | 458 | 593 | 495 | pass |
| time to wings | <= 1080 s | 691 | - | 731 | pass |
| time to fire | <= 1500 s | 748 | - | 782 | pass |
| time to cousin seen | <= 1620 s | 700 | - | 731 | pass |
| deaths before the first evolve | <= 0 | 0 | 1 ! | 0 | FAIL |
| fights per kill | <= 2 | 2 | 2 | 2 | pass |
| befriend tries before the first bond | <= 3 | 2 | 2 | 1 | pass |
| Garfio win rate | in 0.35..0.8 | - | 0 ! | - | FAIL |
| cold load | <= 15 s | 6.33 | 7.57 | 6.21 | n/a |
| re-entry load | <= 5 s | - | - | - | n/a |
| creatures phase | <= 2.5 s | 0.81 | 0.81 | 0.74 | n/a |
| stage_setup phase | <= 0.3 s | 1.05 | 1.4 | 0.31 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | 16.67 | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 115 ! | 326 ! | 95.8 ! | FAIL |
| dead time share of the first 30 min | <= 0.1 | 0.15 ! | 0.32 ! | 0.12 ! | FAIL |
| DNA when the editor first opens | >= 30 | 96 | 68 | 99 | pass |
| longest gap between novelties | <= 15 min | 4.98 | 7.26 | 4.91 | pass |
| species seen in the first 10 min | >= 4 | 2 ! | 2 ! | 2 ! | FAIL |
| species seen by 30 min | >= 8 | 2 ! | 3 ! | 2 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 939 | 811 | 904 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 3589 | 5080 | 3995 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 51 | 36 | 51 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 2332 | - | 2356 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 567 | - | 513 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 7478 | - | 7819 | pass |

| info | seed1 | seed42 | seed7 |
|---|---|---|---|
| distance walked (m) | 950 | 1368 | 1093 |
| run length (s) | 748 | 1011 | 782 |
| kills | 1 | 1 | 1 |
| fights | 2 | 2 | 2 |
| bonds | 1 | 1 | 1 |
| deaths | 0 | 1 | 0 |
| DNA earned | 97 | 68 | 100 |
| evolves | 1 | 0 | 1 |
| species seen | 2 | 3 | 2 |
| first flight at (s) | - | - | - |
| editor first opened at (s) | 692 | 1011 | 731 |
| first part found at (s) | 691 | - | 731 |
| nest visits | 2 | 2 | 2 |
| wall time to fire (s) | 39.48 | - | 47.05 |

Failing targets: deaths before the first evolve, Garfio win rate, longest stretch without progress or stimulus, dead time share of the first 30 min, species seen in the first 10 min, species seen by 30 min
