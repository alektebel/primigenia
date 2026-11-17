# Studio parity: web studio / original demo vs Godot studio

Status key: P present, ~ partial, M missing. "Before" is the Godot studio at commit b90dbbc; "After" is filled in at the end.
Sources: `web/studio/studio.js`, `web/creature/rig.js`, `art/reference/creador-de-criaturas.html`.
Evidence: `docs/evidence/godot/studio-parity/` (web-*.png from the web studio, godot-*.png from this studio).

| # | Item | Before | After |
|---|------|--------|-------|
| **Environment** | | | |
| 1 | Sky gradient with warm horizon and sun glow | M (flat blue) | P |
| 2 | Ground with dirt circular path and noise | M | P |
| 3 | Wind-animated grass blades | M | P |
| 4 | Distant mountain rings, rocks | M | P |
| 5 | Warm sun light, soft shadows, aerial fog | ~ (plain light, no shadows) | P |
| 6 | Orbit camera (drag), zoom limits 3..60 | P | P |
| 7 | Camera smooth follow, floor clamp, default angle | ~ | P |
| 8 | Idle auto-rotate (not in web; requested by owner) | M | P (idle auto-rotate) |
| 9 | Test mode: creature walks the path, camera follows | ~ (small circle, fixed camera) | P (walks the path, camera follows) |
| **Palette** | | | |
| 10 | Real 3D part thumbnails | M (procedural orbs) | P (baked 3D renders) |
| 11 | Thumbnail spins on hover | M | P (live spin 2.4 rad/s) |
| 12 | Hover enlarge and amber border | M | P |
| 13 | Category tab icons (round, part render) | M (text tabs) | P (part render in round tabs) |
| 14 | DNA cost badge per part, tooltip with abilities | M | ~ (cost badge + tooltip; ability list not shown) |
| 15 | Category title | P | P |
| **Dragging a part** | | | |
| 16 | Ghost thumbnail follows cursor outside the body | ~ (text label) | P |
| 17 | Real 3D part follows cursor over the body, snapping, real orientation | M (only a ring) | P (live 3D part, snapping, orientation) |
| 18 | Mirrored preview of paired parts | M | P |
| 19 | Valid / invalid indication (hint, cursor, tint) | ~ (hint only) | P (tint + hint) |
| 20 | Drop animation | M | P (pulse) |
| 21 | Click palette then click body to place | P | P |
| 22 | Drag an existing part, off body removes it | P | P |
| 23 | Escape cancels a drag | P | P |
| **Hover and selection** | | | |
| 24 | Pointer cursor on parts and vertebrae | P | P |
| 25 | Hover highlight on a part | M | P |
| 26 | Vertebra hover scale | M | P |
| 27 | Spine shown only when hovering body, fades in | ~ (always visible balls) | P |
| 28 | Vertebra shape (disc, spines) and cord | M (amber balls) | P |
| 29 | Selection rings on both sides | M (2D circle) | P |
| 30 | Green rotation bead on the surface, drag to rotate | ~ (2D overlay) | P (3D bead on the surface) |
| 31 | Knee and foot handles on legs, drag | M | P |
| **Spine** | | | |
| 32 | Drag vertebra to sculpt, auto add/remove at ends | P | P |
| 33 | Wheel on vertebra changes girth, feedback ring | ~ | P |
| 34 | Wheel on selected part resizes it | P | P |
| **Panels** | | | |
| 35 | Capabilities pips (speed, bite, sing, health) | M | P |
| 36 | DNA meter with budget, flashes red when over | M | P (flashes red over 320) |
| 37 | Seeds, random creature, copy genome | ~ (seeds only) | P (seeds, random, copy genome) |
| 38 | Part sliders, delete | P | P |
| 39 | Growth regions panel (horns, plates, tendrils) | M | P (add/duplicate/delete, shape, surface, 7 sliders, mirror, seed, variant) |
| 40 | Undo / redo, name, save/load/import/export, language | P | P |
| **Modes** | | | |
| 41 | Paint: pattern, 3 colours, scale, gloss, palettes | P | P |
| 42 | Test: walk animation | P | P |
| 43 | Test: bite and sing buttons, walk/run toggle | M | P (bite, sing, walk/run) |
| 44 | Mode dims the palette outside Build | ~ | P (palette dims to 40% and ignores input) |
| **Polish** | | | |
| 45 | Sounds (web has none; click sound added) | M | ~ (click sound only) |
| 46 | Tooltips | ~ | ~ (part tooltips) |
| 47 | Hint line per state | P | P |

## Status after the parity pass

Done: everything in the table except the "~" rows. Remaining gaps, honestly:
- 14: the tooltip lists the cosmetic note, not the per-part ability names (web `illustrative_abilities`).
- 45/46: only the click sound and part tooltips exist.
- "Place on body" region tool (web `editTool=growth`: click the body to position a region) is not ported; regions are edited with the sliders.
- Not verified on the GPU (software GL only); thumbnails bake about one per two frames under llvmpipe, so the first palette view fills in progressively.
- Web side-by-side has a few visual differences that are not behaviour: Godot panels use the Godot theme, the sky is slightly less warm, camera framing differs a little.

Fixed in this pass: the WIP thumbnail baker rendered empty images because part meshes were never built (`maker.finalize` is now called before baking).

Tests: `make godot-studio-test` (824 checks, 0 failures, plus the 8-file web validator cross-check) and `make godot-play-test` stay green.
Evidence: `docs/evidence/godot/studio-parity/` (web-*.png vs godot-*.png: idle, hover, drag, selected, paint, test), regenerated with `godot/studio/tests/parity_shots.gd -- <absolute out dir>`.
