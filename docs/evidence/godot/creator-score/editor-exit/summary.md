# creator score editor-exit: 63/63 (100%)

groups: framing 21/21, hud 7/7, camera 14/14, stage 7/7, handles 3/3, timing 5/5, events 6/6
absent events: none
gates: studio pass, ui pass, first_quest skip
frame ms (software GL, whole replay incl. capture passes): median 44.94, p95 76.1

| check | group | value | target | pass | note |
|---|---|---|---|---|---|
| start.height_frac | framing | 0.596 | 0.607 | yes |  |
| start.cx | framing | 0.579 | 0.589 | yes |  |
| start.cy | framing | 0.449 | 0.429 | yes |  |
| start.ui_coverage | hud | 0.091 | <=0.15 (ref 0.13) | yes |  |
| start.elev_deg | camera | 12.0 | 12 | yes |  |
| start.facing_deg | camera | 133.8 | 130 | yes |  |
| start.clutter | stage | False | False | yes |  |
| spine_hover.height_frac | framing | 0.585 | 0.607 | yes |  |
| spine_hover.cx | framing | 0.583 | 0.588 | yes |  |
| spine_hover.cy | framing | 0.453 | 0.419 | yes |  |
| spine_hover.ui_coverage | hud | 0.092 | <=0.15 (ref 0.13) | yes |  |
| spine_hover.elev_deg | camera | 12.0 | 12 | yes |  |
| spine_hover.facing_deg | camera | 133.8 | 130 | yes |  |
| spine_hover.clutter | stage | False | False | yes |  |
| spine_hover.spheres | handles | 8 | >=3 (ref 4) | yes |  |
| part_picked.height_frac | framing | 0.585 | 0.621 | yes |  |
| part_picked.cx | framing | 0.58 | 0.588 | yes |  |
| part_picked.cy | framing | 0.453 | 0.424 | yes |  |
| part_picked.ui_coverage | hud | 0.093 | <=0.15 (ref 0.13) | yes |  |
| part_picked.elev_deg | camera | 12.0 | 12 | yes |  |
| part_picked.facing_deg | camera | 133.8 | 130 | yes |  |
| part_picked.clutter | stage | False | False | yes |  |
| part_dropped.height_frac | framing | 0.592 | 0.621 | yes |  |
| part_dropped.cx | framing | 0.579 | 0.588 | yes |  |
| part_dropped.cy | framing | 0.45 | 0.424 | yes |  |
| part_dropped.ui_coverage | hud | 0.094 | <=0.15 (ref 0.13) | yes |  |
| part_dropped.elev_deg | camera | 12.0 | 12 | yes |  |
| part_dropped.facing_deg | camera | 133.8 | 130 | yes |  |
| part_dropped.clutter | stage | False | False | yes |  |
| spine_drag.height_frac | framing | 0.592 | 0.607 | yes |  |
| spine_drag.cx | framing | 0.62 | 0.588 | yes |  |
| spine_drag.cy | framing | 0.446 | 0.415 | yes |  |
| spine_drag.ui_coverage | hud | 0.094 | <=0.15 (ref 0.13) | yes |  |
| spine_drag.elev_deg | camera | 12.0 | 12 | yes |  |
| spine_drag.facing_deg | camera | 133.8 | 130 | yes |  |
| spine_drag.clutter | stage | False | False | yes |  |
| spine_drag.spheres | handles | 8 | >=2 (ref 3) | yes |  |
| part_rotate.height_frac | framing | 0.588 | 0.616 | yes |  |
| part_rotate.cx | framing | 0.588 | 0.59 | yes |  |
| part_rotate.cy | framing | 0.442 | 0.43 | yes |  |
| part_rotate.ui_coverage | hud | 0.096 | <=0.15 (ref 0.13) | yes |  |
| part_rotate.elev_deg | camera | 12.0 | 15 | yes |  |
| part_rotate.facing_deg | camera | 133.8 | 130 | yes |  |
| part_rotate.clutter | stage | False | False | yes |  |
| part_rotate.part_ring | handles | True | True | yes |  |
| final.height_frac | framing | 0.565 | 0.497 | yes |  |
| final.cx | framing | 0.588 | 0.577 | yes |  |
| final.cy | framing | 0.452 | 0.367 | yes |  |
| final.ui_coverage | hud | 0.142 | <=0.15 (ref 0.13) | yes |  |
| final.elev_deg | camera | 12.0 | 13 | yes |  |
| final.facing_deg | camera | 133.8 | 140 | yes |  |
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
| gate.first_quest | gates | skip | pass | NO | gate, not part of the score |
