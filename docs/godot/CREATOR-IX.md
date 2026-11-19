# Creator direct manipulation (studio/creator-ix)

All four interactions live in `godot/studio/ui/studio.gd` (input), `studio/model.gd` (edits, undoable) and
`studio/ui/actuator_ring.gd` (the ring). Click vs drag: 4 px / 200 ms (`CLICK_PX`, `CLICK_MS`).

1. **Wheel over a part** scales it (`Model.scale_part`): parts by `size` (0.5..2.2), legs by reach and thickness together
   (reach 0.5..6, `w` 0.1..0.45). A mirrored pair is one genome entry, so both sides follow. Wheel over empty space still
   zooms. Hover highlight is the existing overlay; a readout "Tamano 1.34 (limite)" follows the cursor for 1.2 s.
   Consecutive wheel ticks are one undo step (400 ms window).
2. **Joints are always draggable**: hovering any leg builds its knee and foot handles (`view.set_hover_leg`); LMB-drag on a
   handle moves it with the existing `leg_drag` limits. Vertebrae were already draggable. No mode switch.
3. **Spine arrows**: hovering the body shows an arrow beyond the neck/head end (last node) and the tail end (node 0).
   Dragging calls `Model.bend_end`: the end follows with the usual spacing rules (adds or removes end vertebrae, 4..14),
   and the two vertebrae behind it lean with the sideways part of the move (50 %, 25 %), so the neck or tail bends.
4. **Actuator ring**: a click on a limb opens a ring of muscle, hydraulic, exoskeleton, hydrostat around it (scale
   0.96 -> 1 and fade, 160 ms, ease-out, pivot on the limb). Current one marked. Esc or a click outside closes. The side-panel
   dropdowns for limb and body skeleton were removed; the read-only readout stays.
   Mapping (`Model.RING`): muscle = act muscle on an endoskeleton; exoskeleton = act muscle on an exoskeleton; hydraulic =
   act hydraulic (exoskeleton); hydrostat = act hydrostat (endo or hydro). A choice that needs another body skeleton sets
   `skin.sk` in the same undo step, only if the body can take it (`skel_cands`); otherwise it is dimmed and refused.

Tests: `make godot-studio-test` (887 checks), `make godot-studio-ix-test` (85 checks, real view, real input path).
Evidence: `make godot-studio-ix-evidence` -> `docs/evidence/godot/creator-ix/` (wheel, joint, spine, ring sequences).

Known limits: on the default framing the tail arrow can sit under the right panel (not grabbable there); the ring picks
change the whole body skeleton when needed, which re-derives the other limbs.
