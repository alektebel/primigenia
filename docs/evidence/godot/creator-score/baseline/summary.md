# creator score baseline: 16/56 (29%)

groups: framing 8/21, hud 0/7, camera 7/7, stage 0/7, handles 0/3, timing 0/5, events 1/6
absent events: puff_spawned, cost_popup_shown, cost_popup_hidden, head_target_changed, handle_shown
gates: studio pass, ui pass, first_quest fail
frame ms (software GL, whole replay incl. capture passes): median 53.27, p95 83.86

| check | group | value | target | pass | note |
|---|---|---|---|---|---|
| start.height_frac | framing | 0.431 | 0.607 | NO |  |
| start.cx | framing | 0.533 | 0.589 | yes |  |
| start.cy | framing | 0.554 | 0.429 | NO |  |
| start.ui_coverage | hud | 0.415 | <=0.15 (ref 0.13) | NO |  |
| start.elev_deg | camera | 8.0 | 12 | yes |  |
| start.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| spine_hover.height_frac | framing | 0.431 | 0.607 | NO |  |
| spine_hover.cx | framing | 0.537 | 0.588 | yes |  |
| spine_hover.cy | framing | 0.554 | 0.419 | NO |  |
| spine_hover.ui_coverage | hud | 0.416 | <=0.15 (ref 0.13) | NO |  |
| spine_hover.elev_deg | camera | 8.0 | 12 | yes |  |
| spine_hover.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| spine_hover.spheres | handles | 0 | >=3 (ref 4) | NO | no creator_probe: spine arrows only |
| part_picked.height_frac | framing | 0.431 | 0.621 | NO |  |
| part_picked.cx | framing | 0.536 | 0.588 | yes |  |
| part_picked.cy | framing | 0.554 | 0.424 | NO |  |
| part_picked.ui_coverage | hud | 0.41 | <=0.15 (ref 0.13) | NO |  |
| part_picked.elev_deg | camera | 8.0 | 12 | yes |  |
| part_picked.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| part_dropped.height_frac | framing | 0.431 | 0.621 | NO |  |
| part_dropped.cx | framing | 0.536 | 0.588 | yes |  |
| part_dropped.cy | framing | 0.554 | 0.424 | NO |  |
| part_dropped.ui_coverage | hud | 0.417 | <=0.15 (ref 0.13) | NO |  |
| part_dropped.elev_deg | camera | 8.0 | 12 | yes |  |
| part_dropped.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| spine_drag.height_frac | framing | 0.458 | 0.607 | NO |  |
| spine_drag.cx | framing | 0.537 | 0.588 | yes |  |
| spine_drag.cy | framing | 0.544 | 0.415 | NO |  |
| spine_drag.ui_coverage | hud | 0.41 | <=0.15 (ref 0.13) | NO |  |
| spine_drag.elev_deg | camera | 8.0 | 12 | yes |  |
| spine_drag.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| spine_drag.spheres | handles | 0 | >=2 (ref 3) | NO | no creator_probe: spine arrows only |
| part_rotate.height_frac | framing | 0.493 | 0.616 | NO |  |
| part_rotate.cx | framing | 0.536 | 0.59 | yes |  |
| part_rotate.cy | framing | 0.528 | 0.43 | yes |  |
| part_rotate.ui_coverage | hud | 0.42 | <=0.15 (ref 0.13) | NO |  |
| part_rotate.elev_deg | camera | 8.0 | 15 | yes |  |
| part_rotate.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| part_rotate.part_ring | handles | False | True | NO | no creator_probe: rotation bead only |
| final.height_frac | framing | 0.493 | 0.497 | NO |  |
| final.cx | framing | 0.534 | 0.577 | yes |  |
| final.cy | framing | 0.528 | 0.367 | NO |  |
| final.ui_coverage | hud | 0.407 | <=0.15 (ref 0.13) | NO |  |
| final.elev_deg | camera | 8.0 | 13 | yes |  |
| final.clutter | stage | True | False | NO | grass/rocks between camera and creature |
| drop_to_puff_s | timing | None | 0.0 | NO | absent |
| cost_popup_delay_s | timing | None | 0.29 | NO | absent |
| cost_popup_life_s | timing | None | 0.455 | NO | absent |
| head_react_delay_s | timing | None | 0.33 | NO | absent |
| handle_fade_in_s | timing | None | 0.04 | NO | absent: no vertebra_sphere / part_ring handle event |
| event.part_placed | events | True | True | yes |  |
| event.puff_spawned | events | False | True | NO | absent |
| event.cost_popup_shown | events | False | True | NO | absent |
| event.cost_popup_hidden | events | False | True | NO | absent |
| event.head_target_changed | events | False | True | NO | absent |
| event.handle_shown | events | False | True | NO | absent |
| gate.studio | gates | pass | pass | yes | gate, not part of the score |
| gate.ui | gates | pass | pass | yes | gate, not part of the score |
| gate.first_quest | gates | fail | pass | NO | gate, not part of the score |
