# Loop scorecard (bot)

| metric | target | seed1 | seed42 | seed7 | status |
|---|---|---|---|---|---|
| time to first input | <= 10 s | 1.4 | 1.5 | 1.5 | pass |
| time to first select | <= 120 s | 0.1 | 0.1 | 0.1 | pass |
| time to hunt | <= 360 s | 116 | 133 | 140 | pass |
| time to friend | <= 720 s | - ! | - ! | - ! | FAIL |
| time to dig | <= 840 s | - ! | - ! | - ! | FAIL |
| time to wings | <= 1080 s | - ! | - ! | - ! | FAIL |
| time to fire | <= 1500 s | - ! | - ! | - ! | FAIL |
| time to cousin seen | <= 1620 s | - ! | - ! | - ! | FAIL |
| deaths before the first evolve | <= 0 | 0 | 0 | 0 | pass |
| fights per kill | <= 2 | 1 | 1 | 1 | pass |
| befriend tries before the first bond | <= 3 | - | - | - | n/a |
| Garfio win rate | in 0.35..0.8 | - | - | - | n/a |
| cold load | <= 15 s | 10.4 | 9.59 | 8.86 | n/a |
| re-entry load | <= 5 s | - | - | - | n/a |
| creatures phase | <= 2.5 s | 2.01 | 1.05 | 1.39 | n/a |
| stage_setup phase | <= 0.3 s | 0.63 | 0.72 | 0.65 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | 16.67 | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 666 ! | 643 ! | 643 ! | FAIL |
| dead time share of the first 30 min | <= 0.1 | 0.34 ! | 0.25 ! | 0.25 ! | FAIL |
| DNA when the editor first opens | >= 30 | 23 ! | 24 ! | 24 ! | FAIL |
| longest gap between novelties | <= 15 min | 30.95 ! | 30.9 ! | 30.89 ! | FAIL |
| species seen in the first 10 min | >= 4 | 1 ! | 1 ! | 1 ! | FAIL |
| species seen by 30 min | >= 8 | 1 ! | 1 ! | 1 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 1164 | 1328 | 1402 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | - | - | - | n/a |
| dig task ticks (budget 2500) | <= 2500 ticks | - | - | - | n/a |
| wings task ticks (budget 6000) | <= 6000 ticks | - | - | - | n/a |
| fire task ticks (budget 6000) | <= 6000 ticks | - | - | - | n/a |
| chain ticks (budget 40000) | <= 40000 ticks | - | - | - | n/a |

| info | seed1 | seed42 | seed7 |
|---|---|---|---|
| distance walked (m) | 128 | 153 | 151 |
| run length (s) | 1974 | 1987 | 1993 |
| kills | 1 | 1 | 1 |
| fights | 1 | 1 | 1 |
| bonds | 0 | 0 | 0 |
| deaths | 0 | 0 | 0 |
| DNA earned | 23 | 24 | 24 |
| evolves | 0 | 0 | 0 |
| species seen | 1 | 1 | 1 |
| first flight at (s) | - | - | - |
| editor first opened at (s) | 1974 | 1987 | 1993 |
| first part found at (s) | - | - | - |
| nest visits | 1 | 1 | 1 |
| wall time to fire (s) | - | - | - |

Failing targets: time to friend, time to dig, time to wings, time to fire, time to cousin seen, longest stretch without progress or stimulus, dead time share of the first 30 min, DNA when the editor first opens, longest gap between novelties, species seen in the first 10 min, species seen by 30 min
