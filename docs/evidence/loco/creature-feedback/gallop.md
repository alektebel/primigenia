# Gallop (A54): faster and punchier

Run Froude number `sprint_k` 1.5 -> 2.2 (v = sqrt(Fr g h), h = 0.56 r): starter B (r 0.85 m) runs 2.65 -> 3.2 m/s (the zoo body, r 0.64 m:
2.30 -> 2.78 m/s); the hero (r 3.4 m) 5.3 -> 6.4 m/s. Walk is unchanged (Fr 0.24). Wild fleeing and hunting creatures keep their speeds (a fixed
run Froude number 1.5, `CP_STAGE_WILD_RUN_FR`): had they followed sprint_k, a timid creature would flee faster than the player can walk
up to it and the first-quest befriend task could not finish (e2e). The player's run advantage over prey is 47% larger. F10 `run speed`: 1.5 / **2.2 (default)** / 3.0.

Animation (bold gallop, starter B, `gallop_*` jpg: before = Fr 1.5 run, after = Fr 2.2; side camera every 8th frame and a
close camera `*_close.jpg` every 18th frame):
- the style moves from the canter-like trot into a true gallop at the run (gait `gallop`, 2.78 m/s, in the zoo), with a long flight phase;
- longer bound (stride k x1.3, was x1.2), stronger push-off (bob x2.0, was x1.6), shoulders and hips rock x2.6 (was x2.0), swing lift x1.35;
- spine gather and extension 3.0 (was 2.2) with a sharper stroke (second harmonic): peak flex up to 0.14 rad;
- forward lean: +0.10 rad nose-down at Fr >= 2.4 on top of the lab's run lean; body pitch range at steady gallop -7 .. +19 degrees;
- camera speed cues on by default: +4 degrees of field of view, +5% boom and 0.07 s extra follow lag near the run speed
  (`chase.top_speed` now follows the player's run speed; it was a fixed 8.84 m/s so the cue never fired);
- feet stay pinned: planted slip 0.00 m/s over the clip; the first steps of a run no longer whip a foot at 24 m/s (a swing is capped at
  2 x body speed + 3.5 sqrt(g h) m/s: foot peak 14.7 m/s, knee swing with the leg extended 24 degrees, minimum leg extension 0.40 (was 0.15)).
