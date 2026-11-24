# Island review path, baseline `island-p0` (2026-11-24)

`make godot-island-path` (docs/plans/island-realism.md section 2), Star massif lab island (layout 1), medium tier, software GL, 4 times of day x OG0..OG9. The full frames (40 JPG) live outside the repo; this folder keeps the contact sheet and the exact camera of every frame.

- Run time: about 14 min for the 40 frames (medium, llvmpipe, `nice -n 10`).
- Determinism: OG3, OG6 and OG9 at midday run twice give identical JPG bytes.
- OG0 and OG1 are stand-ins until the orbit sky (O1).
- Known weak points of the baseline (what later steps fix): OG7 shows bare desert ground where the forest vale should be; OG9 (chase camera) shows a flat sky-coloured gap below the nest on this island.
