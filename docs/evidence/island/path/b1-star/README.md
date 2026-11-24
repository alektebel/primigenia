# Island review path, `b1-star` (2026-11-25)

`make godot-island-path LABEL=b1-star` on the game's island after B1: the frozen Star massif desc, seed 1, medium tier, software GL, 4 times of day x OG0..OG9. The full frames (40 JPG) live outside the repo; this folder keeps the contact sheet (`sheet_medium.jpg`), the exact camera of every frame, the times, and the midday OG8 and OG9 frames.

- **OG9 is fixed.** The old baseline (`island-p0`) showed a flat sky-coloured band under the nest: the nest of the old setup stood in the 2.4 m deep lake that fills the nest valley, and the chase camera saw the water sheet. The nest is now on the dry shore (seed 1: (0, 115)) and OG9 shows the creature on grass with its herd.
- **OG8 moved to the nest** (it stood at (0, 40), inside the lake); it now looks over the lake from the shore to the north pass.
- Known weak points: a paler rectangle on the lake at the lower left of OG8 (a lake quad of the water mesh over a sloping bank, the old "pale slab" of INTEGRATION-QA bug 5); OG0 and OG1 are still stand-ins; the jungle (OG5 to OG7) waits for B2.
- Compare with the baseline: `python3 tools/look/compare.py island-p0 b1-star` (the baseline was the layout-1 lab island, the same terrain without the nest-valley placement changes).
