# S0 baseline (commit 80b45db, motion rules of b90dbbc)

Gates: make test PASS, make tourney PASS (worst field mean 62.3 %, worst pair 72.2 %), wasm world test PASS
(encounters 2 / 3 / 2), make godot-test 301 checks 0 failures, godot-play-test 178 checks 0 failures,
godot-loco-test 192 checks 0 failures.

node tests/stage_winnability.mjs: biter 42 % OK, guard 100 % OUT OF RANGE (already failing), spitter 76 % OK.

Feel measurements (godot/game/tests/feel_test.gd): baseline-b90dbbc.json. The C part and the scenarios W, S, A,
click, figure eight reproduce PLAN-feel section 1.2 within 5 % (speed, t90, turn radius, yaw travel, camera rate,
roll). The count of frames without a planted flat foot differs from the plan's scratch number (S 55 against 29,
A 50 against 10, figure eight 124 against 3): the test counts every frame after the first second in which no leg
has contact with foot_pitch < 0.01. D tap and figure eight lengths differ from the scratch scenarios.
