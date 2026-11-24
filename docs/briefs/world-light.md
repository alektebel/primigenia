# Brief: world light follows the day cycle (art lane A1, D-25)

Worktree `/home/diego/Desarrollo/cpore-wt/world-light`, branch `art/world-light` (from main). Work only here.
Tracker test: A1 / D-25 (look canon §3: "marked dawn and dusk, warm with long shadows; neutral midday; readable night").
Read first:
- `AGENTS.md`
- `docs/canon/LOOK.md` (§3, §6, §7)
- `docs/DESIGN.md` A27, A35, A36
- skills `godot-3d-lighting`, `godot-shaders`, `.claude/skills/cpore-media`
- `docs/evidence/look/score/baseline/summary.md`
- the skin v1 evidence in `docs/evidence/look/` (how `moon_k` and day_night work today)

## Problem (visual scorecard baseline)
- **Flat day cycle:** 39 of 44 world shots fail flat light, because the sun is baked into the terrain and sky shaders. The time of day barely changes the world, only the creatures (`godot/game/island/day_night.gd`, global `moon_k`).
- **Night:** too bright and green.
- **Bloom:** too strong at the spring (madre_spring).
- **Forest floor:** noisy and oversaturated.
- **Tiers:** low and medium differ more than "the same game, less detail" allows.

## Steps
1. **Find where the light is baked:** sun direction and colour constants in the terrain, water, vegetation and sky shaders. Drive them from one source, the day/night node: shader globals `sun_dir`, `sun_color`, `sky_zenith`, `sky_horizon`, `ambient_color`, `fog_color`, plus `moon_k`, already present. Add each global to project.godot with today's value as the default, so that nothing changes at midday.
2. **Day curve:** a keyed palette over the 20-minute day (A27) for dawn, midday, dusk and night:
   - low sun with long shadows and warm light at dawn and dusk
   - a slight off-Earth sky tint (LOOK §2)
   - a blue-grey moonlit night, not green, readable but dark

   Each key is a starting value, with a reference photo noted (Galápagos or Hawai'i on Wikimedia Commons, D-24). Prototype the palette in the three.js lab first if useful (`web/lookdev`, A35).
3. **Bloom and exposure:** tame the bloom at the spring through the glow threshold and HDR clamp. No blur.
4. **Forest floor:** reduce saturation and high-frequency noise at game distance, using mip bias or detail fade by distance in the ground shader.
5. **Low tier:** same palette and composition with simpler shading. Keep fps (record frame time per tier).

## Measure
- After each step: `make godot-look-score LOOK_LABEL=<step>`, then `python3 tools/look/compare.py baseline <step>`.
- Keep a step only if its metric improves and nothing in §7 regresses.
- Commit each step separately, with its compare table in the message.
- Final evidence: the scorecard under `docs/evidence/look/score/<final>/` (force-add it; only baseline is tracked by default), `docs/evidence/look/world-light.md` (what improved, what still fails and why), and a blind A/B sheet (`compare.py --side`) of baseline against final at all 4 times of day, with its `.key.json`.

## Rules
- Software GL only: `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a … --rendering-driver opengl3`, `timeout`, `nice -n 10`, `--check-only` first. Never the GPU.
- Do not change `core/`, gameplay, creature skin shaders (skin v1 is done), or event and snapshot ids.
- Suites green: `make godot-test`, `make godot-ui-test`, `make godot-play-test`, `make godot-studio-test`.
- Commit on `art/world-light`; do not merge. Before stopping for any reason, commit WIP.
- Report: compare table baseline → final, the A/B sheet path, frame time per tier, and what remains.
