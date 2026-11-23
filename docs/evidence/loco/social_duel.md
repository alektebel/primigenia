# Social duel lab (A78, A79)

`web/gaitlab/social_duel.html` (+ `social_duel_core.js`, pure sim). One playable encounter: starter B vs a Zanco herd, 20 m apart, far to bonded.
Self-check: `?test=1` or `node tools/gaitlab/social_duel_node_check.cjs`. Capture: `tools/gaitlab/social_duel_capture.cjs` -> `docs/evidence/loco/social_duel/` (strip_brain1.jpg, strip_brain3.jpg with the map and arrows, raid, night, fear_run, tier3_brain1_ignored, summary_card, freeplay_a/b + check.json).

## How to play
W/S move, A/D turn (arrows too), Shift run, Space hold = sneak/lower posture. 1 sing(trill) 2 dance(bob-and-weave) 3 charm(preen) 4 pose(crest): press when the dial hand reaches the key's numbered tick, so the wind-up ends on the beat (green window = +-200 ms). R roar/bite, E pick up fruit, O observe (stand still). T tier, B brain, L easter egg, N night, P predator pass, G raid, Enter restart.

## Rules and starting values
- Beat 1.2 s, window +-0.2 s, read at the end of the wind-up (sing W.2 A.8 R.2 range 8; dance .2/1.0/.2 r5; charm .1/.6/.2 r4; pose .4/.8/.2 r10).
- Mood = point (x fear -1..trust +1, y calm -1..excited +1). Start x -0.6, y 0.3. States by x: wary < -0.2 <= curious < 0.2 <= trusting. Bonded = x >= bondX and y <= bondY held `hold` beats.
- Action push (hit, dx,dy): sing +.09,+.05; dance +.12,+.20; charm +.14,-.16 (calm); pose +.18,+.08. Multiplied by band, tier gain, favourite x1.4, combo (+15%/hit up to x1.6), off-beat factor (tier.off).
- Bands: far >10 m only sing (x0.3, sets "noticed"); approach 4-10: sing 1 (0.5 beyond 8 m), pose .8, dance .6 (<=5 m), charm 0; close <4: all 1.
- Passive: run within 14 m: x -0.28/s*fear (x2 under 4 m), y +.35/s; sneak-walk inside 10 m: +0.05/s (only while x < 0.2); still: +0.015/s; closer than 1.2 m: -0.15/s. Flee at x <= -0.85 for 7 s, then x -0.55, y 0.35. Roar: -0.45, +0.45 (alarm). Predator pass: -0.4,+0.5 when within 10 m of it. Alarm makes the herd look 2.2 s then move off 6 s.
- Preferred distance by x: wary 9.5 m (backs away), curious 6.5, trusting 3, bonded 1.8 (follows).
- Tiers: T1 gain 1, loss .6, fear .8, bond x .6 y .10, hold 1, chain 2; T2 .8/1.0/1.2, .7/0, hold 2, chain 3; T3 .65/1.4/1.5, .75/-.05, hold 3, chain 4, gate: cognitive level 3 (below: gains x0.1, x capped at 0.1, no chains, hint; bond refused).
- Chains: every `cd` beats at curious+, <=9 m, noticed: it calls n gestures (1 per beat, own animation), 1-beat gap, then the player answers in the same order, each read within +-0.2 s of its beat. Right = x1.2 on that hit, full chain +0.12*gain / y -0.08; wrong key or off-beat answer -wrong*loss (.08/.12/.18 x loss); missed answer half that.
- Brain 1 body language only; 2 emotion map; 3 predicted arrows (x2.2 length).
- Easter eggs (cap x below bonded unless met): night (cap .15 in daylight), fruit (cap .5; E near the bush, offer with charm under 4 m: +.45,-.25), raid (cap .5; G or egg start: roar within 7 m of each predator; all gone -> instant bond if egg=raid, else +.3 gratitude). Observing 3 times gives favourite gesture, reading/gate hint, egg hint.
- Body language: ears (flat back = fear, straight up = alert, low sideways = calm), neck height, body turned away -> toward B, tail tucked/wagging, steps back/closer, startle, mood glyph (! ? note heart).

## Checks (all PASS)
Windows +-190 hit, 210/600 miss; run -0.25 x per second at 8 m vs sneak +0.05; running at it bolts in ~1.1 s (all tiers); charm hits give strictly rising x, falling y, dance excites; good bot bonds T1 24 s, T2 30 s, T3 54 s (brain 3); T3 at brain 1 and 2 never bonds and shows the hint; off-beat bot reaches x 0.11 vs 0.84; right chain beats wrong chain; night/fruit/raid bond only under their condition; predator pass -0.32; free play (no ?test=1, 4.4 s, W/1/O/2/B key presses, 0 page errors, two differing screenshots).

## Porting to C
- Mood: two int16 fixed-point (x, y) per target, `state` derived from x with hysteresis-free thresholds; bond-hold counter in beats; cap = min of gate/egg caps applied inside `push`.
- Chain: struct {seq[4], n, b0 beat, idx, right, wrong, miss}; call beat = b0+k, answer beat = b0+n+1+k; accept reads within +-6 ticks of the expected beat, hit = key match and |err| <= 2 ticks.
- Cognitive gate: tier.gate vs brain organ level checked in `apply_action` (x0.1, cap) and in `bond()` (refuse); hints are events.
- All rates above are per second; with 10 ticks/s divide by 10. Not modelled: stamina, herd leader, tier-3 special charms (play, teaching, gifts).
