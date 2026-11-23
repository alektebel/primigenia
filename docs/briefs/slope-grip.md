# Brief: slope grip by adaptations (A59), Codex

Owner (2026-11-23): "If my creature is not adapted (and the rest) it should fall on too much slope. Certain adaptations can allow my creature to not fall off."

Today every creature shares one grade ceiling of 51.6°. Above it, a creature never rests and slides or refuses steep cells (fix/slope-ceiling, commit 3c237f3: `git show 3c237f3`). The steering slope code is `cp_steer_slope` with the limit near core/src/stage_world.c:954, plus the nav costs.

## Build
1. **Per-creature grip limit, deterministic, in C.** Base it on the body plan and parts already in the profile/genome. The numbers are starting values; document them.
   - Base ~35° for a plain creature.
   - Bonuses: digging claws / claw feet (+10°), grasping arms that reach the ground (+8°), suckers / sticky pads / tentacles (+20°, can cling to near-vertical), many legs (≥6: +8°), sprawling low body (+5°), prehensile tail (+5°).
   - Penalties: heavy body (−), hooves on rock (−), and wings or flippers count for nothing.
   - Cap it below 90°, except clingers can rest up to ~80°.
2. **Above the limit:**
   - the creature slides down the fall line with friction
   - if it slides fast or drops it becomes a real fall, using the A31 fall damage, 10 HP per metre of equivalent drop with the existing cap
   - it can't walk up the slope
   - nav and AI avoid cells steeper than the creature's own limit; nav cost uses that creature's limit
   - the player gets feedback: a slipping state the animation can read (feet scrabbling) and a short message the first time ("Too steep for your feet — claws or suckers would help")
3. **Expose the number to Godot.** Expose the limit, e.g. a `grip_deg` field in the profile/state, and show it in the studio abilities panel ("Grip: 47°"), so the editor tells the player when a part improves it.
4. **Determinism and versions.** Keep the existing 51.6° results where a creature's computed limit equals the old behaviour, if possible. If snapshot or layout versions change, follow the repo's conventions and regenerate goldens once. Update the tests: test_world.c, test_run_fall.c, test_nav.c, steer tests, the routes fixtures if affected, and the Godot play test.
5. **Tests to add.**
   - A plain creature slides off a 50° slope.
   - The same creature with claws holds a 50° slope.
   - A sucker creature clings at 75°.
   - A slide over a cliff edge causes fall damage.
   - The AI never plans through cells above its own limit.
6. **Run make test.** The routes tests are slow on this loaded machine, so give them a long timeout. You cannot commit: leave the work uncommitted and write `docs/evidence/sim/slope-grip.md` with the table of limits per starter and part and the test results. If Xvfb is blocked, say so.

Another agent is changing player motion in parallel: a jump on Space in branch feat/jump. Keep your changes focused on slope and grip so the merge stays small.
