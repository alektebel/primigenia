# Starter B shoulders, legs and feet (A54, owner note e165fe and loop-04 "Legs and feet")

Tool: `godot/devtools/zoo/loco_close.gd` (close-camera clip of a zoo body, with a per-frame numbers log). Before = commit 9f120dc.

| What | Cause | Fix | Before | After |
| --- | --- | --- | --- | --- |
| shoulders look detached | the upper limb was an open lathe ending on the skin at the hip; on a thin chest its rim stuck out as a flat sail | a dome behind the hip closes the root inside the torso (`_upper_limb`) | `shoulder_before_*.jpg` | `shoulder_after_*.jpg` (idle sprawl walk and bold gallop) |
| knee flips | a fixed pole vector: a trailing leg lining up with it flipped the knee | the knee bends about the rest hinge axis (`CreatureLegChain.hinge`) | 72 degrees in one frame with the leg extended (ext 0.95), gallop start | 23 degrees |
| toes through the ground | the foot took the body's pitch and roll, hung straight under the ankle, and the controller's ball was 0.4 w while the hoof mesh reaches 1.17 w | foot laid on the ground (world basis, ground slope tilt), pivots about the ankle on its own up axis, controller toe = mesh toe; the IK ankle sits above the sole along world up | starter B gallop 2.4 cm, sprawl walk 1.5 cm, giant 21.3 cm below the ground | 0.2 cm, 0.1 cm, 3.7 cm; planted-sole slide 0.0 mm |
| a foot whips at the start of a run | the leg held down while the body took off swung a metre in two frames | swing speed capped at 2 x body speed + 3.5 sqrt(g h) | 24.4 m/s foot, minimum leg extension 0.15 | 14.7 m/s, 0.40 |

Not touched: stance feet never slid (slip 0.00 m/s in every clip); the sprawl walk's folded hind legs (a style the owner picked, A42/A43).
Tests: `godot-creature-test` (bilateral mesh hash fixture re-recorded: limbs changed on purpose), `godot-loco-test` 305/0,
feel_test 76/0 (it caught the ankle/sole mismatch).
