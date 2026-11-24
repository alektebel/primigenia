# Loop scorecard (bot)

| metric | target | seed1 | seed42 | seed7 | status |
|---|---|---|---|---|---|
| time to first input | <= 10 s | 1.4 | 1.4 | 1.4 | pass |
| time to first select | <= 120 s | 0.1 | 0.1 | 0.1 | pass |
| time to hunt | <= 360 s | 338 | 169 | 148 | pass |
| time to friend | <= 720 s | 741 ! | 646 | 553 | FAIL |
| time to dig | <= 840 s | 746 | 651 | 556 | pass |
| time to wings | <= 1080 s | 1016 | 921 | 753 | pass |
| time to fire | <= 1500 s | 1072 | - | 804 | pass |
| time to cousin seen | <= 1620 s | 1028 | 922 | 754 | pass |
| deaths before the first evolve | <= 0 | 1 ! | 0 | 0 | FAIL |
| fights per kill | <= 2 | 3 ! | 3 ! | 2 | FAIL |
| befriend tries before the first bond | <= 3 | 2 | 3 | 2 | pass |
| Garfio win rate | in 0.35..0.8 | - | 0 ! | - | FAIL |
| cold load | <= 15 s | 6.7 | 7.79 | 6.98 | n/a |
| re-entry load | <= 5 s | - | - | - | n/a |
| creatures phase | <= 2.5 s | 0.85 | 0.7 | 0.71 | n/a |
| stage_setup phase | <= 0.3 s | 1.15 | 1.43 | 0.34 | n/a |
| frame time p95 (low tier) | <= 33.3 ms | 16.67 | 16.67 | 16.67 | n/a |
| longest stretch without progress or stimulus | <= 90 s | 78.6 | 108 ! | 40.6 | FAIL |
| dead time share of the first 30 min | <= 0.1 | 0 | 0.1 ! | 0 | FAIL |
| DNA when the editor first opens | >= 30 | 106 | 108 | 105 | pass |
| longest gap between novelties | <= 15 min | 6.04 | 5.33 | 4.2 | pass |
| species seen in the first 10 min | >= 4 | 2 ! | 2 ! | 3 ! | FAIL |
| species seen by 30 min | >= 8 | 3 ! | 4 ! | 4 ! | FAIL |
| hunt task ticks (budget 15000) | <= 15000 ticks | 3384 | 1687 | 1475 | pass |
| friend task ticks (budget 12000) | <= 12000 ticks | 4024 | 4775 | 4059 | pass |
| dig task ticks (budget 2500) | <= 2500 ticks | 51 | 51 | 21 | pass |
| wings task ticks (budget 6000) | <= 6000 ticks | 2700 | 2697 | 1975 | pass |
| fire task ticks (budget 6000) | <= 6000 ticks | 563 | - | 515 | pass |
| chain ticks (budget 40000) | <= 40000 ticks | 10722 | - | 8045 | pass |

| info | seed1 | seed42 | seed7 |
|---|---|---|---|
| distance walked (m) | 1473 | 1371 | 1079 |
| run length (s) | 1072 | 1051 | 805 |
| kills | 1 | 2 | 1 |
| fights | 3 | 6 | 2 |
| bonds | 1 | 1 | 1 |
| deaths | 1 | 3 | 0 |
| DNA earned | 110 | 118 | 109 |
| evolves | 1 | 1 | 1 |
| species seen | 3 | 4 | 4 |
| first flight at (s) | - | - | - |
| editor first opened at (s) | 1017 | 922 | 754 |
| first part found at (s) | 1016 | 921 | 753 |
| nest visits | 3 | 3 | 2 |
| wall time to fire (s) | 61.04 | - | 50.7 |

Failing targets: time to friend, deaths before the first evolve, fights per kill, Garfio win rate, longest stretch without progress or stimulus, dead time share of the first 30 min, species seen in the first 10 min, species seen by 30 min
