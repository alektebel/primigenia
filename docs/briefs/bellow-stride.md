# Bellow in stride (A75 roar far, set B)

Owner pick A75 (docs/DESIGN.md): roar from far in attack set B = **bellow in stride**: the creature runs in and bellows without planting/stopping (set A = A74 "run in, plant, rear up", C plants at 3.2 m).
Today `moving_ctx()` in `core/src/combat.c` (~line 673) keeps legs going for CB_ROAR only in CB_CTX_WALK/GALLOP. Find how set A/B ("variant", snapshot 15, F10 "attack set A/B") reaches C.

Do:
1. When the variant is B, CB_ROAR in CB_CTX_FAR is layered: no plant, the run carries on (same wide turn and overshoot rules as the gallop bellow), fear still applies at the normal roar range when it fires. Set A unchanged, bit-for-bit (goldens must not move).
2. Godot: action file `godot/actions/roar_move_far_b.json` (or the existing generator `tools/actions/gen_context_actions.py`, preferred) mirroring `roar_move_gallop` with a slightly bigger chest swell; wire it to variant B far.
3. Tests in the C suite (`tests/`) for both variants; run `make test` (log to /home/diego/Desarrollo/cpore-wt/_agent/bellow-stride-tests.log). If a Godot test exists for context actions, run it headless with `timeout` + `nice -n 10`.
No snapshot bump unless a new persisted field is truly needed (main = 16; if needed use 17). Never pkill/killall; kill only pids you recorded. Do not commit (Claude commits). Report files, tests, golden status.
