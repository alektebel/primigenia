# Loop tuning proposal 1 (measuring pass, 2026-11-24)

Branch `sim/loop-tune-1`, from main `eb20d60` (roster v9, slope grip, context attacks, starter B kit, jump). No gameplay change is committed: the experiments are in `docs/evidence/loop/score/experiments.patch` (the last stacked state: leash + seen radius 45 + nearer herds) and were reverted.

Evidence: `docs/evidence/loop/score/2026-11-24/` (seeds 1, 7, 42; `compare-vs-baseline.md`), `exp1-leash-*`, `exp2-regen-s42`, `exp3-seen60-*`, `exp4-near-*`, and the idle roster probe `godot/game/tests/roster_probe.gd` (output in `2026-11-24/probe/`). Telemetry times are `tick / 10` (the C world runs at 10 Hz). Seed 42 never finishes (section 4); its run was stopped by killing my own recorded pid, so its late metrics are partial.

## Where main stands

| metric (target) | baseline s1 / s7 / s42 | main s1 / s7 / s42 | status |
|---|---|---|---|
| time to friend (<= 720 s) | 1178 / 988 / - | 453 / 490 / 589 | pass |
| time to fire (<= 1500 s) | 1427 / 1375 / - | 748 / 782 / hung | pass on s1, s7 |
| cousin seen (<= 1620 s) | - / - / - | 700 / 731 / - | pass |
| fights per kill (<= 2) | 2 / 3 / 3 | 2 / 2 / 2 | pass |
| deaths before first evolve (0) | 0 / 1 / 2 | 0 / 0 / 1 | fails on s42 only |
| longest dead stretch (<= 90 s) | 90.7 / 58.7 / 180 | 115 / 95.8 / 326 | FAIL, worse |
| dead share of first 30 min (<= 0.10) | 0.13 / 0 / 0.16 | 0.15 / 0.12 / 0.32 | FAIL, worse |
| species in first 10 min (>= 4) | 2 / 3 / 2 | 2 / 2 / 2 | FAIL |
| species by 30 min (>= 8) | 3 / 3 / 2 | 2 / 2 / 3 | FAIL |
| Garfio win rate (0.35..0.8) | 0 / 0 | n/a / n/a / 0 (1 sample) | not measured |

Most baseline failures are gone: befriend, fire and cousin now pass, load is 6-8 s. The "dead time" got worse only because everything else got faster: the one long stretch left is the chase in 1. The scorecard stops when the bot finishes (6 to 12 min of play), so "species by 30 min" is capped by the run length.

## Proposals, in order of impact

### 1. Timid creatures flee without limit: a 270-330 s chase (dead time, befriend time)

- Current: dead stretch 115 / 96 / 326 s; befriend 453-589 s. Target: stretch <= 90 s.
- Cause. The bot locks a Zanco 142 m away (verbose `friend pursuit` log, seed 1, tick 942) and trails it for ~330 s at d = 9.0 m, speed 1.0-1.6 m/s, until the Zanco is 394 m from its home (trust only starts at tick 4227). In C a timid creature flees whenever the player is within `sight*0.5` (12 m for Zanco), toward a point one step further from the player, at `CP_STAGE_WILD_RUN_FR 1.5` (`core/src/stage_world.c:1433-1436`, `:1442`, `:852`). Nothing limits how far from home it runs or ever stops it. The player's sprint lasts only run_stamina 1000 / 10 per tick = 10 s (`stage_world.c:1602`, `:725`); after that his jog cannot close the 9 m. Rondo and Babosa (also timid) behave the same for a human player.
- Smallest change: a leash. A timid creature flees only while it is within 40 m of its home (`length(e->x-e->home_x, e->z-e->home_z) < 40`); beyond that it holds and roams. About 4 lines in `wild_tick` (exp1 in the patch). No snapshot change: the rule is stateless.
- Measured (exp1-leash, 3 seeds): friend 222 / 265 s (from 453 / 490), fire 352 / 402 s (from 748 / 782), cousin seen 303 / 351 s, longest stretch 34.5 / 43.6 s, dead share 0 / 0, deaths 0, all passing. Seed 42 still hangs (4).
- Risk: befriending becomes 3-4 min of a 25-30 min goal; if the owner wants it harder, raise the trust threshold, not the chase. Goldens that cover a chase change (`make test`, combat suites). Alternative with the same effect but larger blast radius: `CP_STAGE_WILD_RUN_FR` 1.5 -> about 1.0, which also makes Rondo fights easier.

### 2. Species seen (2 / 2 / 3 against >= 4 in 10 min, >= 8 in 30)

- Cause. (a) Placement is one cluster per species at a fixed distance from the nest (`godot/game/stage/stage_setup.gd:57-59,138`): Garfio 60 m, Rondo 85, Zanco 110, Babosa 125, Espinodo 140, spread in different directions. The idle probe confirms it (`2026-11-24/probe/probe1.txt`: Garfio (23,55), Rondo (79,31), Zanco (60,-92), Espinodo (-118,-75), Babosa (-58,110)) and that they stay home for 10 min. Acechalunas are 615 m away at the cave, Brujula 1300 m and Corona 1600 m: out of reach in 10 min. So 5 species are reachable in 10 min, and the game cannot hit >= 8 by 30 min without the T10/T11 food-web species. (b) "Seen" needs the player within 30 m (`core/src/stage_social.c:539`). The bot walks at its task goals and never goes near Garfio, Espinodo or Babosa.
- Experiments (on top of exp1): radius 60 gives Garfio at tick 0 and 3 species (s1, s7); radius 45 with `HERD_DISTANCE [70, 85, 100]` and `SLUG_DISTANCE 90` also gives 3. Neither reaches 4, because Espinodo (west) and Babosa (north-west) are off the bot route. The fastest chain also shortens the window: the bot is done at 6 min.
- Recommendation: do not tune distances yet. (1) Add an explore loop to the bot (a 150 m ring before the hunt), which is also what the first-minute cue (T7) should push a player to do. (2) Raise "seen" to 45 m: closer to "can see it" than 30 m, and a one-number change. (3) If the owner's log still shows < 4, bring Espinodo and Babosa to <= 100 m. Judge on the owner's session log first.
- Risk: closer herds put territorial Espinodo near the nest; a larger radius gives the `CP_DNA_SEEN` award earlier (a small DNA gain, no snapshot change).

### 3. Garfio wins every fight: measure first

- Current: 0 of 1 (seed 42); no Garfio fight on s1 / s7. Target 0.35..0.8.
- Cause of the data: the bot fights Garfio only by accident, at 22 hp, because nothing in `stage_world.c` regenerates hp outside a fight (hp returns only on respawn `:1471` and at the nest). I tested a regen of 0.1% of max hp per tick (exp2-regen-s42): the same fight then starts at 100 hp and still ends in death in 8 s (`fight_end hp 0, ticks 80`). So Garfio (hp 90, mouth 2, tail 2, spit 2, speed 5.5, `godot/game/data/garfio-combat.json`) beats a full-hp bite-spamming starter; the 35-80% fixtures in `docs/briefs/m-garfio-cont.md` use a smarter policy than the e2e bot's bite and spit.
- Smallest change: no game number. First add a deliberate Garfio duel to the bot (full hp, context attacks, 5 per seed) so the scorecard records a real rate; only then retune Garfio hp (90) or speed (5.5) in 10% steps.
- Risk: regen alone is not a fix (no change in seed 42's outcome) and weakens the nest. Not recommended.

### 4. Seed 42: a death before evolve, then the bot hangs in the editor

- Current: 1 death (target 0); the run never finishes (main, exp1, exp2 all stop at `editor_open` with sim scale 0 and a frozen tick).
- Cause: after the dig step the bot walks back through Garfio's home (60 m from the nest) at 22 hp and dies; it respawns, digs at the nest (`dig {bed:-1, find:0}` at (0, 5)), the wings task never completes, it opens the editor and waits forever. Bot logic (`godot/game/tests/first_quest_e2e.gd` `_dig` / `_wings`), not balance.
- Smallest change, bot only: after a death redo the wing walk; route around Garfio's 30 m aggro or heal at the nest when hp < 50%; add a wall-clock guard so a scale-0 hang fails in 120 s, not 900 s.
- Risk: none for the game.

### 5. Cousin: passes

`cousin_seen` at 700 / 731 s on main (303 / 351 s with the leash). The event's `dist` of 50-60 m is the sighting distance, not the spawn distance; add the spawn distance to the event if T13 must be verified.

## Order of work

1. Leash (1): about 4 lines of C, clears the dead-time metrics and cuts befriend / fire time by half (2 seeds).
2. Bot fixes (4) and a Garfio duel step (3): measurement only.
3. Explore loop and seen radius 45 (2), then judge placement from the owner's log.

Not covered: owner sessions, GPU load time (the RTX log stays the reference), and anything past 12 min of play.

## Implementation result (A33, same branch)

Implemented: the 40 m home leash (`CP_STAGE_FLEE_LEASH`, `core/src/stage_world.c`, derived from the existing home position, no new state, no snapshot bump); bot changes in `godot/game/tests/first_quest_e2e.gd` (wall-clock guard, fight handling inside `walk_to`, explore step for Espinodo and Babosa, `duel` mode, stop after a failed wings step); `make godot-loop-duel` (Makefile). Garfio's numbers untouched.

Loop score, 3 seeds (`docs/evidence/loop/score/2026-11-24-tune1/`, with `compare-vs-baseline.md` and `compare-vs-2026-11-24.md`): friend 220-265 s, wings 446-484 s, fire 497-540 s, cousin seen 447-491 s, longest stretch 41-43 s, dead share 0, novelty gap <= 2.2 min, species in 10 min 4 / 5 / 4 (all pass). Seed 42 no longer hangs. Still failing: species by 30 min (the bot finishes at 8-9 min with 4-5 species; the target needs the T10/T11 species), and on seed 42 one death before evolve and 3 fights per kill. The seed 42 death is real world layout: its wing bed is at (17, 47), 8 m from Garfio's home at (23, 55), and the bot arrives with 22 hp. The "regressions" listed by compare.py against the first run are load times measured under a machine load of 25-40 (cold load 23-35 s against 6-8 s before) and distance walked, not game changes.

Garfio duel (`make godot-loop-duel`, `docs/evidence/loop/score/duel-tune1/`): the starter wins 8 of 8 duels at full hp (100 hp, ends with 34-48 hp left, 64 ticks) when it presses the first equipped usable move that reaches. That is 100%, above the 35-80% band, and overturns my earlier reading in section 3: Garfio is beatable at full hp; the earlier deaths were an old bite-spam policy and low hp (22 hp after the Rondo fight; there is no out-of-combat regen). The number to look at is therefore Garfio at partial hp, not his stats. Not changed here, per the instruction. Candidate for the next pass: Garfio hp 90 -> 110-120, or a smaller change such as his move cooldowns, measured with the duel target at 100% / 60% hp.

Suites (log `/home/diego/Desarrollo/cpore-wt/_agent/loop-tune-tests.log`): `make test` exit 0 (goldens unchanged: the leash is not in the golden scenarios), godot-test, godot-play-test, godot-devtools-test, godot-camera-test exit 0, first-quest e2e seed 1: 31 checks, 0 failures. No golden or scenario regenerated.
