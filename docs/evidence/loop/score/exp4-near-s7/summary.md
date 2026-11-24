# Loop scorecard (bot)

| metric | target | seed7 | status |
|---|---|---|---|
| time to first input | <= 10 s | 1.5 | pass |
| time to first select | <= 120 s | 0.1 | pass |
| time to hunt | <= 360 s | 73.3 | pass |
| time to friend | <= 720 s | 202 | pass |
| time to dig | <= 840 s | 204 | pass |
| time to wings | <= 1080 s | 299 | pass |
| time to fire | <= 1500 s | 350 | pass |
| time to cousin seen | <= 1620 s | 300 | pass |
| deaths before the first evolve | <= 0 | 1 ! | FAIL |
| fights per kill | <= 2 | 3 ! | FAIL |
| befriend tries before the first bond | <= 3 | 2 | pass |
| Garfio win rate | in 0.35..0.8 | 0 ! | FAIL |
| cold load | <= 15 s | 25.54 | n/a |
| re-entry load | <= 5 s | - | n/a |
| creatures phase | <= 2.5 s | 3.17 | n/a |
| stage_setup phase | <= 0.3 s | 1.36 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 42 | pass |
| dead time share of the first 30 min | <= 0.1 | 0 | pass |
| DNA when the editor first opens | >= 30 | 91 | pass |
| longest gap between novelties | <= 15 min | 1.58 | pass |
| species seen in the first 10 min | >= 4 | 3 ! | FAIL |
| species seen by 30 min | >= 8 | 3 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 733 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 1289 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 21 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 948 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 508 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 3499 | pass |

| info | seed7 |
|---|---|
| distance walked (m) | 523 |
| run length (s) | 350 |
| kills | 1 |
| fights | 3 |
| bonds | 1 |
| deaths | 1 |
| DNA earned | 117 |
| evolves | 1 |
| species seen | 3 |
| first flight at (s) | - |
| editor first opened at (s) | 300 |
| first part found at (s) | 299 |
| nest visits | 3 |
| wall time to fire (s) | 63.51 |

Failing targets: deaths before the first evolve, fights per kill, Garfio win rate, species seen in the first 10 min, species seen by 30 min
