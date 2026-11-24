# Loop scorecard (bot)

| metric | target | seed1 | seed42 | seed7 | status |
|---|---|---|---|---|---|
| time to first input | <= 10 s | 1.4 | 1.4 | 1.5 | pass |
| time to first select | <= 120 s | 0.1 | 0.1 | 0.1 | pass |
| time to hunt | <= 360 s | 93.9 | 81.1 | 90.4 | pass |
| time to friend | <= 720 s | 222 | 220 | 265 | pass |
| time to dig | <= 840 s | 224 | 223 | 267 | pass |
| time to wings | <= 1080 s | 484 | 447 | 446 | pass |
| time to fire | <= 1500 s | 540 | 499 | 497 | pass |
| time to cousin seen | <= 1620 s | 491 | 448 | 447 | pass |
| deaths before the first evolve | <= 0 | 0 | 1 ! | 0 | FAIL |
| fights per kill | <= 2 | 2 | 3 ! | 2 | FAIL |
| befriend tries before the first bond | <= 3 | 1 | 1 | 1 | pass |
| Garfio win rate | in 0.35..0.8 | - | 0 ! | - | FAIL |
| cold load | <= 15 s | 25.95 | 34.74 | 23.37 | n/a |
| re-entry load | <= 5 s | - | - | - | n/a |
| creatures phase | <= 2.5 s | 3.69 | 3.7 | 2.33 | n/a |
| stage_setup phase | <= 0.3 s | 4.22 | 6.9 | 1.01 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | 16.67 | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 41.3 | 42.7 | 41.9 | pass |
| dead time share of the first 30 min | <= 0.1 | 0 | 0 | 0 | pass |
| DNA when the editor first opens | >= 30 | 103 | 101 | 97 | pass |
| longest gap between novelties | <= 15 min | 1.64 | 2.22 | 1.75 | pass |
| species seen in the first 10 min | >= 4 | 4 | 5 | 4 | pass |
| species seen by 30 min | >= 8 | 4 ! | 5 ! | 4 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 939 | 811 | 904 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 1283 | 1393 | 1744 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 21 | 22 | 21 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 2599 | 2248 | 1794 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 563 | 519 | 508 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 5405 | 4993 | 4971 | pass |

| info | seed1 | seed42 | seed7 |
|---|---|---|---|
| distance walked (m) | 792 | 809 | 695 |
| run length (s) | 541 | 500 | 497 |
| kills | 1 | 1 | 1 |
| fights | 2 | 3 | 2 |
| bonds | 1 | 1 | 1 |
| deaths | 0 | 1 | 0 |
| DNA earned | 104 | 126 | 97 |
| evolves | 1 | 1 | 1 |
| species seen | 4 | 5 | 4 |
| first flight at (s) | - | - | - |
| editor first opened at (s) | 485 | 448 | 447 |
| first part found at (s) | 484 | 447 | 446 |
| nest visits | 2 | 3 | 2 |
| wall time to fire (s) | 84.59 | 92.87 | 102 |

Failing targets: deaths before the first evolve, fights per kill, Garfio win rate, species seen by 30 min
