# Loop scorecard (bot)

| metric | target | seed1 | seed42 | seed7 | status |
|---|---|---|---|---|---|
| time to first input | <= 10 s | 1.3 | 1.3 | 1.4 | pass |
| time to first select | <= 120 s | 0.1 | 0.1 | 0.1 | pass |
| time to hunt | <= 360 s | 126 | 353 | 172 | pass |
| time to friend | <= 720 s | 1178 ! | - ! | 988 ! | FAIL |
| time to dig | <= 840 s | 1189 ! | - ! | 1078 ! | FAIL |
| time to wings | <= 1080 s | 1325 ! | - ! | 1272 ! | FAIL |
| time to fire | <= 1500 s | 1427 | - ! | 1375 | FAIL |
| time to cousin seen | <= 1620 s | - ! | - ! | - ! | FAIL |
| deaths before the first evolve | <= 0 | 0 | 2 ! | 1 ! | FAIL |
| fights per kill | <= 2 | 2 | 3 ! | 3 ! | FAIL |
| befriend tries before the first bond | <= 3 | 2 | - | 1 | pass |
| Garfio win rate | in 0.35..0.8 | - | 0 ! | 0 ! | FAIL |
| cold load | <= 15 s | 14.68 | 15.78 | 14.49 | n/a |
| re-entry load | <= 5 s | - | - | - | n/a |
| creatures phase | <= 2.5 s | 1.4 | 1.17 | 1.8 | n/a |
| stage_setup phase | <= 0.3 s | 2.36 | 2.93 | 1.5 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | 16.67 | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 90.7 ! | 180 ! | 58.7 | FAIL |
| dead time share of the first 30 min | <= 0.1 | 0.13 ! | 0.16 ! | 0 | FAIL |
| DNA when the editor first opens | >= 30 | 110 | 65 | 114 | pass |
| longest gap between novelties | <= 15 min | 15.08 ! | 23.45 ! | 8.12 | FAIL |
| species seen in the first 10 min | >= 4 | 2 ! | 2 ! | 3 ! | FAIL |
| species seen by 30 min | >= 8 | 3 ! | 2 ! | 3 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 1255 | 3526 | 1715 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 10522 | - | 8168 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 110 | - | 892 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 1360 | - | 1950 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 1024 | - | 1029 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 14271 | - | 13754 | pass |

| info | seed1 | seed42 | seed7 |
|---|---|---|---|
| distance walked (m) | 1393 | 1921 | 1333 |
| run length (s) | 1427 | 1902 | 1376 |
| kills | 1 | 1 | 1 |
| fights | 2 | 3 | 3 |
| bonds | 1 | 0 | 1 |
| deaths | 0 | 2 | 1 |
| DNA earned | 115 | 65 | 114 |
| evolves | 1 | 0 | 1 |
| species seen | 3 | 3 | 3 |
| first flight at (s) | - | - | - |
| editor first opened at (s) | 1325 | 1902 | 1273 |
| first part found at (s) | 1325 | - | 1272 |
| nest visits | 2 | 4 | 3 |
| wall time to fire (s) | 151 | - | 146 |

Failing targets: time to friend, time to dig, time to wings, time to fire, time to cousin seen, deaths before the first evolve, fights per kill, Garfio win rate, longest stretch without progress or stimulus, dead time share of the first 30 min, longest gap between novelties, species seen in the first 10 min, species seen by 30 min
