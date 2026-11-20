# Drag polish (cell stage + creator top bar)

## Cell stage: drag from the Crear grid
- Press a tool card and move 6 px: the card becomes a drag (a still press stays a tap; tap-then-tap unchanged).
  `cell/drag_ghost.gd` draws the piece under the pointer, written straight from the event (1:1, no tween).
- The cell lights where it can go: membrane pieces light the ring and snap-preview on it, enzymes light the cytoplasm
  (`cell_canvas._draw_drop_hint`). A refused spot turns the ghost red with the reason ("Solo en la membrana",
  "Solo dentro de la célula", "No hay ATP al lado", "Tiene que tocar la colonia", "Ocupado", "Fase bloqueada").
- Drop = `place()` (same rules, via `can_place()`). Dropping outside the play area, or Esc, eases the ghost back to its
  card (200 ms, quint ease-out). The release of a drag is never read as a tap on the card.
- A placed piece can be moved (press and drag; `move_piece`) and dragged out of the cell to remove it (red ring and
  "Suelta para quitar"; same as Quitar, no refund exists). Esc puts it back.
- Cursors: open hand over cards and placed pieces, grabbing hand while dragging, forbidden on a refused drop.
  Press feedback 0.97 on the cards was already there; Esc and keys do not animate except the ghost's ease-back.

## Colony board (phase 6)
Same for blocks: palette card onto a hex, drag a placed block to another free hex (`ColonySim.move_block`, free of
charge, the founder stays), drag it off the board to remove it. `ColonySim.can_place/can_move` give the reasons.

## Creator top bar
One row of three clusters: file (Menú, name, Archivo), modes (centred), play (green primary "Jugar con esta criatura"
plus ES/EN). Outer clusters share free width equally; below 1240 px "Jugar con esta criatura" shortens to "Jugar",
below 1160 px undo/redo become arrows. Nothing overlaps at 1024x600, 1280x720, 1920x1080 (test_interaction.gd t_topbar).

Evidence: docs/evidence/godot/drag-polish/ (cell: `make`-less, run `cell/tests/drag_evidence.gd`; bar: `studio/tests/topbar_evidence.gd`).
