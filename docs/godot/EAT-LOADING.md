# Eating animation, island entry loading screen, nest scale

Branch `ui/eat-loading`. Three owner asks: "an animation for eating", "a loading screen when generating the world", and the nest that
is huge next to the 1.2 m hatchling.

## 1. Eating

C only has the eat verb on a **carcass** (`stage_social.c`: 4 bites, `CP_SOC_BITE_TICKS` = 10, the last bite ends the action). There is
no plant-eating verb and wild creatures have no eat state, so "plants" is a visual kind only (the evidence sheet shows a tuft eaten the
same way) and grazing is not wired.

* `actions/data/eat.json` is now a **meal**, not one bite: 3 + 20 + 3 ticks. The layer slaves `tau` to the C act tick (`ctx.eat.t`, from
  `island._eat_ctx()` reading `state.social.action`): act ticks 0..10 are the first bite, then ticks 10..20 loop. A C bite
  (`EV_EAT`) lands on tick 10, 20, 30, 40, which is the **tear** of the cycle: head down and reach to the food (`item` goal = the
  carcass point), jaw open, snap shut, the head pulls back shaking; after the bite the head lifts to chew and swallow (jaw tremble,
  throat sacs, a small inflate), then lowers again. The body crouches (`root.pitch`, `root.lift`) and sways.
* Variants by capability (`action_body_map._caps`: `beak` pico, `proboscis` trompa, `fauces`): the beak pecks (three short jaw taps and a
  head dip), the proboscis sucks (jaw shut, sacs pulsing, head held low, no tear), the fauces tear harder (bigger head and body shake).
* End: C ends the action, `slaved` is dropped and the 3-tick recovery plays out (swallow, head up) and fades. A C move (a fight) fades
  it in 0.08 s. A moving body does not start it (rooted action).
* Food: the carcass host eases to its next size (`island._carcass_scale`: a quarter of the meat per bite, a 7% pulse per bite, never a
  pop) and is hidden once it is eaten to the bone (it used to stay at 30%). Each bite: crumbs (`action_fx.crumbs`, CPU particles, more on
  the last bite) and a soft sound (`Audio.eat_bite`, the step sample pitched up, quiet). The DNA popup at the end is the existing `EV_DNA`.
* Radial bodies and any body without an action layer: `actor_driver.eat_pulse` (a quick dip and rebound of the body per bite).
* Tests (`make godot-actions-test`, 383 checks, 0 failures; 322 before the round-2 data, 61 new in `_t_eat` over the 4 real bodies): tau
  follows the C tick exactly (error 0), the head goes down, the mouth reaches the food, the 10-tick loop is seamless, `eat_bite` fires
  once, the end is clean (weight 0, head and jaw at rest), a fight cancels it, and `trigger("eat")` still plays one finite meal.
* Evidence: `docs/evidence/godot/eat-loading/eat_hatchling.png`, `eat_merodeador.png` (`make godot-eat-evidence`): rows carcass and
  plant, columns act ticks 1.2 .. 40 (ended). Looked at: the head lowers and tears back on the 10-tick beat, crumbs fly, the food
  shrinks per bite and is gone at the end.
* Weak still: the hatchling's neck is short, so the beak reaches the food's top but does not touch the ground; the legs stay planted
  (no crouch of the hips beyond `root.lift`).

## 2. Entry loading screen

`game/loading/entry_veil.gd`, owned by `Game` (a CanvasLayer under the root, so it survives the scene change).

* Every entry goes through `Game.enter_island(from)` (menu Criatura / Continuar / plain start, the cell bridge via `enter_island_new`,
  the studio via `enter_island_now`, `--play` and scenarios via `main.gd`) or `Game.goto_island` (dev console, zoo, tests). Terrain
  generation (cache miss) runs inside the same screen on a worker thread with the generator's real stage progress (30% of the bar);
  then the scene is loaded with `ResourceLoader.load_threaded_request` while the screen animates.
* The island build (`island.gd build`) yields a frame between phases when a screen is up (`_slice`), has `_building` guards on
  `_process`/input, pauses the stage meanwhile, and runs the **pure-data** work on worker threads (`_offload`): lake mesh data, river
  chains, flora placement records, the radial fauna plan and `nav_warm` (the 4.4 s one). Node creation stays on the main thread and
  yields between batches of flora meshes and between creatures. Without a screen nothing suspends, so every other test and tool that
  instantiates the island keeps its synchronous build.
* Progress is real: `Game.report_entry`'s phases call `veil.phase_done(name)`; the bar eases (exp, 5/s) to the weighted fraction of the
  finished phases (weights = measured ms) and may creep a share of the next phase, capped, and is clamped below 100% until
  `island_ready`. Monotonic by construction.
* Design: the menu's dark sky gradient, the Primigenia title, a thin gold line, a rotating tip every 4.5 s (6 tips, ES/EN, `Strings`), a
  small phase line. Hand-off: after the first island frames are drawn the bar completes and the screen fades out in 250 ms (ease-out).
* Fast path: `Game.entry_screen_wanted()` is false only when the kit is parked and the last kit entry took < 500 ms
  (`Game.last_kit_entry_ms`). Today a kit entry still takes 3 to 4 s (creatures, flora records, stage), so it shows the screen; the rule
  is there for when that gets cheaper.
* Timings (headless, `nice`, one machine, noisy). Before: menu entry **11 708 ms** with zero frames drawn (water 2118, rivers 375,
  props_flora 1574, nav_warm 4432, creatures 1282, ui_and_rest 731). After: the same build with the screen up, longest main-thread
  stall under the screen about **200 ms** (a creature host) instead of the whole entry; total 6.2 to 7.4 s when the machine was quiet,
  10 to 13 s when other suites ran at the same time. Second entry with the kit and a warm `nav_warm`: 2.9 to 4 s.
* Tests: `make godot-entry-test` (23 checks): progress monotonic and below 100% until ready, 100% and a freeing screen after the fade,
  menu / studio / cell bridge each show it, the kit path skips it when the last kit entry was < 500 ms and shows it at 900 ms, the
  menu's Continue / Criatura / plain share the one entry. Existing tests adapted to wait for the finished build (`_building`) and
  wall-clock budgets (`play_test`, `test_bridge`); the bridge whisper now starts at the hand-off.

## 3. Nest scale

`island_props.nest_scale_for(body_radius_cm)` = `clamp(sqrt(r / 300), 0.4, 1.0)` (300 cm is the Merodeador the nest was drawn for;
the hatchling's 50 cm gives 0.41, a 0.99 m nest instead of 2.42 m). `build_nest` scales radii, bank height, straw and twig lengths and
widths; scale 1.0 is bit-identical to before. `island.refit_nest()` rebuilds only the Nest node when the genome changes
(`load_scenario`, evolution) and at start through `props.nest_scale`. The C 12 m nest radius is untouched.
Tests: 4 checks in `test_flora.gd` (scale table, span against the full nest, single Nest node, growing back is the exact full nest).

## Counts

godot-test 1118, godot-ui-test 882, godot-actions-test 383, godot-menu-test 32 (+1 with `--play`), godot-bridge-test 42,
godot-play-test 237, godot-entry-test 23, all 0 failures. The `order`, `free RefCounted` and `%` script errors printed by godot-test and
godot-ui-test come from `test_input`, `test_flight` and a UI string format, not from this work.
