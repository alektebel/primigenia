# Brief: creature skin v1 (first look change, prototyped in the lab, shipped in Godot)

Worktree `/home/diego/Desarrollo/cpore-wt/skin-v1`, branch `art/skin-v1` (from main at 0c9b70d). Work only here.
Read first: `AGENTS.md`, `docs/canon/LOOK.md` (§4 skin, §5 readability, §7 failures), `docs/DESIGN.md` A24 (player's hues never shift), A35, A36, `docs/godot/CREATURE-REALISM.md`, skills `godot-shaders`, `godot-3d-materials`.

## Goal
Fix the creature failures the visual scorecard found (baseline `docs/evidence/look/score/baseline/summary.md`), without touching hues, gameplay or the world shaders:
1. **Plastic shine**: midday glint fraction up to 0.023 (target ≤ 0.01). Matte by default; wet only on wet zones/aquatic genomes; gloss only where the player chose it.
2. **Night readability**: creatures 59–84% crushed at night, contrast 0.12, creature-vs-ground 0.07 (target ≥ 0.10). Add subtle moonlight response / rim (canon §5), never a glow or outline.
3. **Warmth at dawn/dusk**: creatures read cooler than midday (R/B 0.89–0.95). Check first whether it is the skin (e.g. subsurface/ambient tint) or the capture light; fix only what is the skin's.

## Method (A35)
1. Prototype in the lab `web/lookdev/index.html`: add variant 2 from variant 0, iterate, capture with `tools/look/lab_capture.cjs` (SwiftShader only, `NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules`).
2. Port the approved changes to `godot/creature/shaders/` (skin_common.gdshaderinc, skin*.gdshader). Must still compile and look the same in Compatibility; keep Forward+-only code under `#ifdef RENDERER_FORWARD_PLUS`.
3. Measure: `make godot-look-score LOOK_LABEL=skin1` then `python3 tools/look/compare.py baseline skin1 --side /home/diego/Desarrollo/cpore-wt/_agent/look-ab/skin1.jpg` (blind A/B sheet outside the repo). Iterate until the three targets pass or you can explain why not with numbers. No regression in other checks beyond noise.
4. Before/after creature shots: `make godot-creature-realism-shots TAG=skin1` (compare with the existing `before`/`after`).

## Rules
- Player hues never shift (A24); `CPORE_REALISM=0` still gives the old look.
- Visual only; no C, no gameplay, no world shaders.
- Evidence: force-add only the final label (`git add -f docs/evidence/look/score/skin1`); lab captures in `docs/evidence/look/lab/`.

## Acceptance
- Three targets reached (or explained); compare table in `docs/evidence/look/skin-v1.md`.
- Suites green: `make godot-test`, `make godot-studio-test`, `make godot-creature-test` (if present), `make godot-ui-test`, `make godot-play-test`.
- Commit on `art/skin-v1`; do not merge.
