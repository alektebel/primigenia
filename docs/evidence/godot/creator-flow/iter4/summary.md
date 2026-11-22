# creator score creator-flow-score-4: 56/56 (100%)

groups: framing 21/21, hud 7/7, camera 7/7, stage 7/7, handles 3/3, timing 5/5, events 6/6
absent events: none
gates: studio pass, ui pass, first_quest fail
frame ms (software GL, whole replay incl. capture passes): median 37.99, p95 65.54

| check | group | value | target | pass | note |
|---|---|---|---|---|---|
| start.height_frac | framing | 0.561 | 0.607 | yes |  |
| start.cx | framing | 0.552 | 0.589 | yes |  |
| start.cy | framing | 0.474 | 0.429 | yes |  |
| start.ui_coverage | hud | 0.084 | <=0.15 (ref 0.13) | yes |  |
| start.elev_deg | camera | 12.0 | 12 | yes |  |
| start.clutter | stage | False | False | yes |  |
| spine_hover.height_frac | framing | 0.554 | 0.607 | yes |  |
| spine_hover.cx | framing | 0.555 | 0.588 | yes |  |
| spine_hover.cy | framing | 0.477 | 0.419 | yes |  |
| spine_hover.ui_coverage | hud | 0.085 | <=0.15 (ref 0.13) | yes |  |
| spine_hover.elev_deg | camera | 12.0 | 12 | yes |  |
| spine_hover.clutter | stage | False | False | yes |  |
| spine_hover.spheres | handles | 8 | >=3 (ref 4) | yes |  |
| part_picked.height_frac | framing | 0.554 | 0.621 | yes |  |
| part_picked.cx | framing | 0.552 | 0.588 | yes |  |
| part_picked.cy | framing | 0.477 | 0.424 | yes |  |
| part_picked.ui_coverage | hud | 0.086 | <=0.15 (ref 0.13) | yes |  |
| part_picked.elev_deg | camera | 12.0 | 12 | yes |  |
| part_picked.clutter | stage | False | False | yes |  |
| part_dropped.height_frac | framing | 0.562 | 0.621 | yes |  |
| part_dropped.cx | framing | 0.552 | 0.588 | yes |  |
| part_dropped.cy | framing | 0.473 | 0.424 | yes |  |
| part_dropped.ui_coverage | hud | 0.086 | <=0.15 (ref 0.13) | yes |  |
| part_dropped.elev_deg | camera | 12.0 | 12 | yes |  |
| part_dropped.clutter | stage | False | False | yes |  |
| spine_drag.height_frac | framing | 0.594 | 0.607 | yes |  |
| spine_drag.cx | framing | 0.532 | 0.588 | yes |  |
| spine_drag.cy | framing | 0.46 | 0.415 | yes |  |
| spine_drag.ui_coverage | hud | 0.086 | <=0.15 (ref 0.13) | yes |  |
| spine_drag.elev_deg | camera | 12.0 | 12 | yes |  |
| spine_drag.clutter | stage | False | False | yes |  |
| spine_drag.spheres | handles | 8 | >=2 (ref 3) | yes |  |
| part_rotate.height_frac | framing | 0.61 | 0.616 | yes |  |
| part_rotate.cx | framing | 0.55 | 0.59 | yes |  |
| part_rotate.cy | framing | 0.455 | 0.43 | yes |  |
| part_rotate.ui_coverage | hud | 0.088 | <=0.15 (ref 0.13) | yes |  |
| part_rotate.elev_deg | camera | 12.0 | 15 | yes |  |
| part_rotate.clutter | stage | False | False | yes |  |
| part_rotate.part_ring | handles | True | True | yes |  |
| final.height_frac | framing | 0.592 | 0.497 | yes |  |
| final.cx | framing | 0.546 | 0.577 | yes |  |
| final.cy | framing | 0.464 | 0.367 | yes |  |
| final.ui_coverage | hud | 0.135 | <=0.15 (ref 0.13) | yes |  |
| final.elev_deg | camera | 12.0 | 13 | yes |  |
| final.clutter | stage | False | False | yes |  |
| drop_to_puff_s | timing | 0.0 | 0.0 | yes |  |
| cost_popup_delay_s | timing | 0.267 | 0.29 | yes |  |
| cost_popup_life_s | timing | 0.433 | 0.455 | yes |  |
| head_react_delay_s | timing | 0.3 | 0.33 | yes |  |
| handle_fade_in_s | timing | 0.12 | 0.04 | yes |  |
| event.part_placed | events | True | True | yes |  |
| event.puff_spawned | events | True | True | yes |  |
| event.cost_popup_shown | events | True | True | yes |  |
| event.cost_popup_hidden | events | True | True | yes |  |
| event.head_target_changed | events | True | True | yes |  |
| event.handle_shown | events | True | True | yes |  |
| gate.studio | gates | pass | pass | yes | gate, not part of the score |
| gate.ui | gates | pass | pass | yes | gate, not part of the score |
| gate.first_quest | gates | fail | pass | NO | gate, not part of the score |
