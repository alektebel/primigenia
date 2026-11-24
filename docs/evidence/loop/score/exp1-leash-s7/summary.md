# Loop scorecard (bot)

| metric | target | seed7 | status |
|---|---|---|---|
| time to first input | <= 10 s | 1.5 | pass |
| time to first select | <= 120 s | 0.1 | pass |
| time to hunt | <= 360 s | 90.4 | pass |
| time to friend | <= 720 s | 265 | pass |
| time to dig | <= 840 s | 267 | pass |
| time to wings | <= 1080 s | 351 | pass |
| time to fire | <= 1500 s | 402 | pass |
| time to cousin seen | <= 1620 s | 351 | pass |
| deaths before the first evolve | <= 0 | 0 | pass |
| fights per kill | <= 2 | 2 | pass |
| befriend tries before the first bond | <= 3 | 1 | pass |
| Garfio win rate | in 0.35..0.8 | - | n/a |
| cold load | <= 15 s | 8.52 | n/a |
| re-entry load | <= 5 s | - | n/a |
| creatures phase | <= 2.5 s | 1.09 | n/a |
| stage_setup phase | <= 0.3 s | 0.39 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 43.6 | pass |
| dead time share of the first 30 min | <= 0.1 | 0 | pass |
| DNA when the editor first opens | >= 30 | 86 | pass |
| longest gap between novelties | <= 15 min | 1.75 | pass |
| species seen in the first 10 min | >= 4 | 2 ! | FAIL |
| species seen by 30 min | >= 8 | 2 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 904 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 1744 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 21 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 837 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 511 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 4017 | pass |

| info | seed7 |
|---|---|
| distance walked (m) | 528 |
| run length (s) | 402 |
| kills | 1 |
| fights | 2 |
| bonds | 1 |
| deaths | 0 |
| DNA earned | 87 |
| evolves | 1 |
| species seen | 2 |
| first flight at (s) | - |
| editor first opened at (s) | 351 |
| first part found at (s) | 351 |
| nest visits | 2 |
| wall time to fire (s) | 37.5 |

Failing targets: species seen in the first 10 min, species seen by 30 min
