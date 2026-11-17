# The meta-game: tools for playing, testing and debugging

Status: **draft, 2026-11-17.** Owner request: a meta layer to debug and to jump
to particular places, sites and situations, so that iterating on the feel of
each stage is fast instead of tedious. It's designed once for the creature stage
and grows with every stage.

## 1. The core idea: one scenario format for everything

Our sim is a deterministic C core (Q24). So a **situation** is fully described by
*seed + C state + lineage + genome + camera*. Saving that gives a
**scenario**. One file format is used by:

| Use | What it means |
|---|---|
| Debugging | Jump straight to the moment you want to test |
| Tests | Headless tests load the same scenarios and check the outcome |
| Benchmark | The fixed standard start states of Q7 are scenarios |
| Feedback | The owner's feedback key saves a scenario + replay |
| Sandbox (G38) | Players get a cleaned-up version of the same tools as creative mode |

So these tools are not throwaway: they're the game's sandbox, test harness and
benchmark starts.

## 2. Tools

| # | Tool | What it does | Key |
|---|---|---|---|
| D1 | **Console** | Type commands: `tp crater`, `tp 120 -40`, `spawn garfio 3`, `give dna 500`, `time 18:30`, `weather storm`, `timescale 0.2`, `ai off`, `god`, `reveal`, `kill radius 30`, `stage band`, `trait add aquatic`… Autocomplete, history, help | ` (backtick) |
| D2 | **Sites** | Every world seed publishes its points of interest from the generator: crater, volcano, waterfall cave, nest sites, species dens, Garfio's territory, viewpoints, meteor shards, fossils. A **site picker** (searchable list with thumbnails) teleports you there. You can add your own **bookmarks** with a key | F2 picker, Ctrl+B bookmark |
| D3 | **Scenarios** | Save / load the full situation. Library under `scenarios/<stage>/` (JSON + C state blob). Starts from the command line too: `godot --path godot -- --scenario creature/garfio_fight` | F5 save, F6 load |
| D4 | **Live tuning panel** | Every tunable (C params via GDExtension, GDScript params) registered in one registry: sliders, applied instantly, grouped (movement, camera, combat, AI, look). Save the changes as a tuning diff to `tuning/*.json`; **A/B slots** to switch between two versions with one key | F3 panel, F4 swap A/B |
| D5 | **Feedback key** | Saves a screenshot, the last 60 s of replay, the scenario at that point, the tuning diff, the build hash and a typed note to `feedback/<time>/`. Claude or an agent loads it and sees exactly what happened | F8 |
| D6 | **Replay scrubber** | A timeline over any replay: pause, rewind, step one tick, jump. **"Take control from here"** branches a new game from any moment (possible because the C sim is deterministic) | F9 |
| D7 | **Time control** | Pause, step a tick, slow motion, fast-forward ×10 / ×100 (seasons in Band, years in Realm and Space) | Pause, [ ] |
| D8 | **Overlays** | Toggle visual debug layers: navigation, AI intents and target lines, combat phases and hitboxes, locomotion (feet, support polygon, gait), C vs rendered positions, fog, trust between species, economic flows (later), performance | F10 cycles, console `overlay <name>` |
| D9 | **Free camera** | Detach the camera and fly anywhere; snap back | F7 |
| D10 | **Lineage editor** | Pick the traits you've earned (aquatic, void-adapted, silk…), then start any stage with them. That's how carry-forward between stages gets tested without playing the whole arc | console `lineage` |
| D11 | **Stage jump** | Start any stage from its standard start state (Q7), with any lineage | main menu (dev builds) |
| D13 | **Key legend** | An always-available legend of what every key and button does, **context-sensitive** (it changes with the mode: walking, fighting, radial menu, studio, RTS, console). Hold the key for the full sheet; a small corner hint shows the 3–4 keys that matter right now. Generated from Godot's input map, so it never goes out of date. Also in the player build (not dev-only) | F1 (hold) |
| D12 | **Autoplay** | The AI takes the avatar; overnight runs play a matrix of scenarios × tuning and write a report (win rates, durations, stuck units, errors, frame times) | console `autoplay`, `make soak` |

### What "A/B" means (D4)

Two versions of the same settings, A and B (e.g. turning speed 180°/s vs 240°/s,
or camera v1 vs v2), loaded at once in the same build. One key swaps between them
mid-game, so you compare by feel in seconds instead of restarting. The legend
and the corner of the screen say which one is active; the feedback key (D5)
records it, so your note says "B is better" and we know exactly what B was.

## 3. Rules

- **Dev builds only** by default. Sandbox mode exposes a reduced set (D2, D7, D9, a few D1 commands).
- **Everything that changes the sim goes through C** (the same validated way
  as player orders), so debug actions show up in the replay and replays stay bit-exact (Q24).
- **Scenarios are versioned** with the engine. An old scenario that won't load fails loudly,
  with a readable error (as genomes do, Q11).
- **Tunables live in data**, not code. A good tuning diff gets merged as the new default with
  a one-line reason.

## 4. The owner's loop

1. Pick a focused question ("is turning good?") and the scenario that tests it (D3).
2. Play 5–10 minutes. Tweak live (D4), compare A/B (D4), press F8 whenever something feels off (D5).
3. Overnight: agents read the feedback folders, fix and tune; autoplay (D12) checks balance.
4. Next day: the same scenario, with a new build.

## 5. Build order

| Step | Tools | Size |
|---|---|---|
| DT0 (now, creature stage) | D13 key legend, D1 console, D2 sites + bookmarks, D3 scenarios, D4 tuning + A/B, D5 feedback key, D7 time | M |
| DT1 | D6 replay scrubber + branching, D9 free camera, D8 overlays (combat, locomotion, AI) | M |
| DT2 | D10 lineage editor, D11 stage jump, D12 autoplay + soak report | M |
| With each new stage | more console commands, sites, overlays (RTS: orders, flow fields, fog; Industry: logistics flows) and standard scenarios | S each |
