# Studio parity: web studio / original demo vs Godot studio

Status key: P present, ~ partial, M missing. "Before" is the Godot studio at commit b90dbbc; "After" is filled in at the end.
Sources: `web/studio/studio.js`, `web/creature/rig.js`, `art/reference/creador-de-criaturas.html`.
Evidence: `docs/evidence/godot/studio-parity/` (web-*.png from the web studio, godot-*.png from this studio).

| # | Item | Before | After |
|---|------|--------|-------|
| **Environment** | | | |
| 1 | Sky gradient with warm horizon and sun glow | M (flat blue) | |
| 2 | Ground with dirt circular path and noise | M | |
| 3 | Wind-animated grass blades | M | |
| 4 | Distant mountain rings, rocks | M | |
| 5 | Warm sun light, soft shadows, aerial fog | ~ (plain light, no shadows) | |
| 6 | Orbit camera (drag), zoom limits 3..60 | P | |
| 7 | Camera smooth follow, floor clamp, default angle | ~ | |
| 8 | Idle auto-rotate (not in web; requested by owner) | M | |
| 9 | Test mode: creature walks the path, camera follows | ~ (small circle, fixed camera) | |
| **Palette** | | | |
| 10 | Real 3D part thumbnails | M (procedural orbs) | |
| 11 | Thumbnail spins on hover | M | |
| 12 | Hover enlarge and amber border | M | |
| 13 | Category tab icons (round, part render) | M (text tabs) | |
| 14 | DNA cost badge per part, tooltip with abilities | M | |
| 15 | Category title | P | |
| **Dragging a part** | | | |
| 16 | Ghost thumbnail follows cursor outside the body | ~ (text label) | |
| 17 | Real 3D part follows cursor over the body, snapping, real orientation | M (only a ring) | |
| 18 | Mirrored preview of paired parts | M | |
| 19 | Valid / invalid indication (hint, cursor, tint) | ~ (hint only) | |
| 20 | Drop animation | M | |
| 21 | Click palette then click body to place | P | |
| 22 | Drag an existing part, off body removes it | P | |
| 23 | Escape cancels a drag | P | |
| **Hover and selection** | | | |
| 24 | Pointer cursor on parts and vertebrae | P | |
| 25 | Hover highlight on a part | M | |
| 26 | Vertebra hover scale | M | |
| 27 | Spine shown only when hovering body, fades in | ~ (always visible balls) | |
| 28 | Vertebra shape (disc, spines) and cord | M (amber balls) | |
| 29 | Selection rings on both sides | M (2D circle) | |
| 30 | Green rotation bead on the surface, drag to rotate | ~ (2D overlay) | |
| 31 | Knee and foot handles on legs, drag | M | |
| **Spine** | | | |
| 32 | Drag vertebra to sculpt, auto add/remove at ends | P | |
| 33 | Wheel on vertebra changes girth, feedback ring | ~ | |
| 34 | Wheel on selected part resizes it | P | |
| **Panels** | | | |
| 35 | Capabilities pips (speed, bite, sing, health) | M | |
| 36 | DNA meter with budget, flashes red when over | M | |
| 37 | Seeds, random creature, copy genome | ~ (seeds only) | |
| 38 | Part sliders, delete | P | |
| 39 | Growth regions panel (horns, plates, tendrils) | M | |
| 40 | Undo / redo, name, save/load/import/export, language | P | |
| **Modes** | | | |
| 41 | Paint: pattern, 3 colours, scale, gloss, palettes | P | |
| 42 | Test: walk animation | P | |
| 43 | Test: bite and sing buttons, walk/run toggle | M | |
| 44 | Mode dims the palette outside Build | ~ | |
| **Polish** | | | |
| 45 | Sounds (web has none; click sound added) | M | |
| 46 | Tooltips | ~ | |
| 47 | Hint line per state | P | |
