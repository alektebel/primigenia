# Loop scorecard (bot)

| metric | target | seed42 | status |
|---|---|---|---|
| time to first input | <= 10 s | 1.4 | pass |
| time to first select | <= 120 s | 0.1 | pass |
| time to hunt | <= 360 s | 81.1 | pass |
| time to friend | <= 720 s | 220 | pass |
| time to dig | <= 840 s | 223 | pass |
| time to wings | <= 1080 s | - | n/a |
| time to fire | <= 1500 s | - | n/a |
| time to cousin seen | <= 1620 s | - | n/a |
| deaths before the first evolve | <= 0 | 1 ! | FAIL |
| fights per kill | <= 2 | 2 | pass |
| befriend tries before the first bond | <= 3 | 1 | pass |
| Garfio win rate | in 0.35..0.8 | 0 ! | FAIL |
| cold load | <= 15 s | 16.02 | n/a |
| re-entry load | <= 5 s | - | n/a |
| creatures phase | <= 2.5 s | 2.05 | n/a |
| stage_setup phase | <= 0.3 s | 3.04 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 49.9 | pass |
| dead time share of the first 30 min | <= 0.1 | 0 | pass |
| DNA when the editor first opens | >= 30 | 58 | pass |
| longest gap between novelties | <= 15 min | 1.51 | pass |
| species seen in the first 10 min | >= 4 | 3 ! | FAIL |
| species seen by 30 min | >= 8 | 3 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 811 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 1393 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 22 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | - | n/a |
| fire task ticks (budget 6000) | <= 6000 ticks | - | n/a |
| chain ticks (budget 40000) | <= 40000 ticks | - | n/a |

| info | seed42 |
|---|---|
| distance walked (m) | 530 |
| run length (s) | 365 |
| kills | 1 |
| fights | 2 |
| bonds | 1 |
| deaths | 1 |
| DNA earned | 58 |
| evolves | 0 |
| species seen | 3 |
| first flight at (s) | - |
| editor first opened at (s) | 365 |
| first part found at (s) | - |
| nest visits | 2 |
| wall time to fire (s) | - |

Failing targets: deaths before the first evolve, Garfio win rate, species seen in the first 10 min, species seen by 30 min
