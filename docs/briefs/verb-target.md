# Brief: verb-first targeting (Spore-style), family at the nest, edit with found parts at the nest

Worktree `/home/diego/Desarrollo/cpore-wt/verb-target`, branch `ui/verb-target`. Owner, 2026-11-22, after playing:
- "the interacting UI is not good at all, it is very hard to do on moving targets. We should lock what we want to do exactly, and just select the creature we want to do that. If attack, red arrows signalling the creature; if befriend, green arrows, as in Spore."
- "At the nest there should be more creatures like me."
- "I should be able to change my creature with new parts I found around."

Read first:
- `AGENTS.md`
- `docs/plans/creature-loop.md` (beats 4–11)
- `docs/DESIGN.md` (combat/social rows, A25, A27, A31, A38)
- the current interaction code: radial ring in `godot/game/ui/stage_ui.gd`, `player_input.gd`, combat key 1, befriend keys 1–4 + G, `core/src/stage_social.c`, `core/src/combat.c` (read only unless the C part below)
- the studio editor entry (`STUDIO.md`, menu > Edit creature)
- the Emil UI skills (ease-out ≤ 250 ms, press 0.97, no animation on keyboard actions, never from scale 0)

## Part 1 — Verb first, then target
- **Pick the verb, then the creature.** The player picks the verb first: Attack, Befriend (and Eat for a carcass) from a small bar, keys Q/E (or 1/2), or right-click cycling. Then they click or hover a creature.
- **Lock-on:** once a verb is armed, hovering highlights the nearest valid creature under the cursor with a generous pick radius (screen-space, scaled by distance) so moving targets are easy. A click **locks** the target.
- **Marker:** the locked target gets a marker that follows it every frame: **red chevrons/arrows pointing down at it for Attack, green for Befriend** (Spore-like), on the ground ring plus over the head. No outlines (LOOK §5).
- **Auto-pursuit:** the player creature walks or runs to the target automatically and does the verb when in range (the existing GO-order and combat/social paths); the player can keep pressing the move keys to cancel.
- **During befriend:** the rhythm keys still apply but the card shows clearly what to press.
- **Cancel and switch:** Esc or a right-click cancels; switching verb keeps the target if valid.
- **Readability:** the target's name and relation (prey, hostile, friendly, neutral) show next to the marker.
- **Tests:** arm, hover, lock and cancel; the target-follows-a-moving-creature check; the pick radius on a fast creature; the e2e first quest still passes using the new flow (update the bot to the new API if needed).
- Remove or relegate the old radial ring only if the new flow covers all its actions; list any action it drops.

## Part 2 — Family at the nest
- At game start, 2–4 siblings of the player's species (same genome, small colour variation) live at the nest. They wander nearby, return, and react to the player (follow a bit, greet).
- If this needs wild slots in C, note the slot budget problem (24 slots, 23 used; plan finding 2). Prefer a visual-only family (GDScript actors that don't need C slots, like the radial ambient fauna) for now, and say what a real C version would need (task T9).
- Check: `make godot-play-test` plus a screenshot at the nest.

## Part 3 — Edit at the nest with found parts
- When the player is at the nest (within the nest radius), a prompt appears ("E: Edit creature"). It opens the studio editor in-game (the existing creature editor path, as the first quest does for the fire gland), showing **only parts the player has found or unlocked**, plus the basics, with their DNA costs.
- After a part is found (`part_found`), a short hint points back to the nest ("New part: wing vane — edit at the nest").
- Leaving the editor returns to the nest at the same time of day.
- Tests: the prompt shows only at the nest; found parts appear in the editor; DNA spend; return to the game.

## Rules
- Software GL only, `timeout`, `nice -n 10`, kill only your own pids.
- C changes only if unavoidable (Sonnet may; keep it deterministic, the next snapshot is 12 or whatever is free after speed-gait).
- Suites: `make godot-test`, `godot-ui-test`, `godot-play-test`, `godot-devtools-test`, the first-quest e2e.
- Evidence screenshots (software GL), in `docs/evidence/godot/verb-target/`:
  - red arrows on a hostile while it moves
  - green arrows on a friend
  - the family at the nest
  - the editor with found parts
- Commit after each part. Do not merge. Report: keys, flow, files, suites, screenshots, what the old ring did that the new flow doesn't.
