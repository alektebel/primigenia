# Brief: finish world light (A1), round 2

Same worktree and branch (`/home/diego/Desarrollo/cpore-wt/world-light`, `art/world-light`). Read `docs/briefs/world-light.md`, `docs/canon/LOOK.md` and `AGENTS.md` first.

## Where it stands (Claude's review, 2026-11-21)
- **Kept:** commits 1–3 (wl2). "No moon shadow map" (wl3) made night worse (day_cycle_night 6 → 8, crush unchanged) and was reverted (93dc26e).
- **Failing shots per check, baseline → wl2:**
  - improved: warmth 39 → 4, night 11 → 6, bloom 7 → 2, creature flat light 8 → 0, creature crushed 8 → 2, world noise 3 → 1, tier parity 8 → 6
  - regressed: saturation_over 8 → 10, saturation_p95 6 → 11, flat_light 0 → 8, world_crushed 7 → 10
- **Seen by eye** (baseline vs wl2 medium_night_riverbank and medium_dawn_valley_chase): the baseline "night" was not night at all (blue sky, green grass). The wl2 night is a real moonlit blue-grey night, which is correct per LOOK §3, but the near ground is too dark. Dawn wl2 has long shadows and is correct, but its grass chroma is high.

## Do
1. **Night-specific targets.** `flat_light` and `world_crushed` were set for day shots. In `docs/research/look-targets.json`, add night variants: contrast ≥ 0.15 and crush < 0.35 (starting values, with the reason written there: the baseline night passed only because it was not night). Keep the night readability checks: day_cycle_night, creature readability and creature_crushed. Do not loosen anything else. `tools/look/score.py` must apply the night variants only to night shots.
2. **Lift the near ground at night** a little: ambient and moon fill on the ground, staying blue-grey. Near-ground crush goes below 0.35, and night/day luminance stays ≤ 0.5.
3. **Dawn and dusk saturation:** lower the grass and ground chroma in the warm keys (keep the hue), so saturation_over and saturation_p95 are at baseline (8 / 6) or better.
4. **Forest floor noise:** medium_midday_forest_floor 7.2 → below 6 (detail fade by distance).
5. **Low-tier parity:** optional, only if it is cheap.
6. One scorecard, `wl4`, then `python3 tools/look/compare.py baseline wl4`. **Merge rule:** every check equal to or better than baseline (with the step 1 night targets). If a check is still worse, iterate once more (`wl5`).
7. Suites: `make godot-test`, `make godot-ui-test`, `make godot-play-test`, `make godot-studio-test`.
8. Evidence:
   - `docs/evidence/look/world-light.md`: compare table baseline → final, what was changed, what remains
   - the blind A/B sheet `python3 tools/look/compare.py baseline <final> --side docs/evidence/look/world-light-ab.jpg`, with its .key.json
   - force-add `docs/evidence/look/score/<final>/`
   Commit.

## Rules
- Software GL only, `timeout`, `nice -n 10`, kill only your own pids, never `pkill -f`.
- Commit on `art/world-light`; do not merge.

## How to wait for long runs (why the previous agent kept stopping)
A scorecard takes 10–25 minutes and a single shell call is limited to 10 minutes. Start it detached (`nohup make godot-look-score LOOK_LABEL=wl4 > /tmp/wl4.log 2>&1 &`). Then wait with repeated shell calls, each a loop up to 9 minutes long that checks for `docs/evidence/look/score/wl4/summary.md` (`for i in $(seq 1 50); do [ -f …/summary.md ] && break; sleep 10; done`). **Do not hand back while a run is going.** Hand back only when everything in "Do" is done, or if you hit a real blocker.
