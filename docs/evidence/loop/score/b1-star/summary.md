# Loop scorecard (bot)

| metric | target | seed1 | seed42 | seed7 | status |
|---|---|---|---|---|---|
| time to first input | <= 10 s | 1.5 | 1.5 | 1.4 | pass |
| time to first select | <= 120 s | 0.1 | 0.1 | 0.1 | pass |
| time to hunt | <= 360 s | 91.8 | 82.1 | 90.9 | pass |
| time to friend | <= 720 s | 245 | 242 | 227 | pass |
| time to dig | <= 840 s | 249 | 245 | 231 | pass |
| time to wings | <= 1080 s | 486 | 450 | 460 | pass |
| time to fire | <= 1500 s | 545 | 472 | 512 | pass |
| time to cousin seen | <= 1620 s | 501 | 450 | 461 | pass |
| deaths before the first evolve | <= 0 | 0 | 0 | 0 | pass |
| fights per kill | <= 2 | 2 | 3 ! | 2 | FAIL |
| befriend tries before the first bond | <= 3 | 1 | 1 | 1 | pass |
| Garfio win rate | in 0.35..0.8 | - | 0 ! | - | FAIL |
| cold load | <= 15 s | 13.24 | 10.6 | 10.9 | n/a |
| re-entry load | <= 5 s | - | - | - | n/a |
| creatures phase | <= 2.5 s | 0.77 | 0.69 | 0.7 | n/a |
| stage_setup phase | <= 0.3 s | 2.57 | 0.56 | 0.88 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | 16.67 | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 68.6 | 44 | 86.8 | pass |
| dead time share of the first 30 min | <= 0.1 | 0 | 0 | 0 | pass |
| DNA when the editor first opens | >= 30 | 100 | 100 | 98 | pass |
| longest gap between novelties | <= 15 min | 1.9 | 2.12 | 2.14 | pass |
| species seen in the first 10 min | >= 4 | 5 | 5 | 4 | pass |
| species seen by 30 min | >= 8 | 5 ! | 5 ! | 4 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 918 | 821 | 909 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 1534 | 1595 | 1361 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 37 | 36 | 36 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 2374 | 2043 | 2293 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 584 | 225 | 519 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 5447 | 4720 | 5118 | pass |

| info | seed1 | seed42 | seed7 |
|---|---|---|---|
| distance walked (m) | 754 | 720 | 750 |
| run length (s) | 545 | 473 | 512 |
| kills | 1 | 1 | 1 |
| fights | 2 | 3 | 2 |
| bonds | 1 | 1 | 1 |
| deaths | 0 | 1 | 0 |
| DNA earned | 100 | 100 | 98 |
| evolves | 1 | 1 | 1 |
| species seen | 5 | 5 | 4 |
| first flight at (s) | - | - | - |
| editor first opened at (s) | 487 | 450 | 461 |
| first part found at (s) | 486 | 450 | 460 |
| nest visits | 2 | 3 | 2 |
| wall time to fire (s) | 32.52 | 29.95 | 28.46 |

Failing targets: fights per kill, Garfio win rate, species seen by 30 min
