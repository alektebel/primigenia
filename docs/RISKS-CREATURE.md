# Creature stage risk register (C0–C9)

Pre-mortem for the creature stage only, 2026-11-17 → done in
`docs/CREATURE-ROADMAP.md` (C0–C9). Game-first (G1), one stage at a time (A17).
L/I = H/M/L. Owners: **owner** (gates), **Claude** (review), **agents** (code).
Roadmap sizes already say usage limits are the real clock.

---

## 1. Top 10

| ID | Risk | L | I | Bites | Owner |
|---|---|---|---|---|---|
| R01 | Core loop is not fun on a real GPU (C1 / G70 second-to-second) | H | H | C1 | owner |
| R02 | Full-arc ideas leak into the creature stage (A1–A18 vs A17) | H | H | C2–C5 | owner |
| R03 | C sim and island disagree (flat ±195 m world; F4 not done) | H | H | C0–C2 | agents |
| R04 | AI process: false “done”, usage-limit stalls, review bottleneck | H | H | all | Claude |
| R05 | Procedural action animation (G77) never reads as combat/social | H | H | C1 | agents |
| R06 | Saves, hashes and goldens break as P4+ rules land | M | H | C2+ | agents |
| R07 | Procedural art ceiling; weak-model art fails the toon/physical look | H | M | C1–C6 | Claude |
| R08 | One owner cannot playtest, decide and close G25 gates | H | H | all | owner |
| R09 | Game changes break the C benchmark (goldens, fairness, cost) | M | H | C2, C9 | Claude |
| R10 | Legal/store: “Primigenia”, Spore likeness, AI/asset licences | M | H | C8 | owner |

---

## 2. Register

### Fun / design

**R01 — The second-to-second loop never clicks.** G70/G72 put movement, camera
and fight readability first. F1 is merged (`2f5cf70`) with measured jog
5.2 m/s and a calmer camera (`docs/godot/FEEL.md`), but every Godot evidence
path is xvfb + llvmpipe (`godot/README.md`: “feel … on a real GPU are for the
owner”). WIRE.md: Garfio spit often wins, no flee key, grass in play-test is
3,000 blades vs 252,000 default. BACKLOG item 4 still says owner playtest
pending. C1 gate is “10 minutes of enjoying move and fight.”
*Watch:* “clunky / floaty / unreadable” after a GPU session.
*Prevent:* C0 tools (D4 A/B, D5 F8) before more systems; no P4 until C1 closes.
*If it happens:* one more feel pass (S9 speeds already deferred); cut systems, do not add them.
*Check:* F8 pack per session; move/fight 1–5; stop if <4 after three GPU sessions.

**R11 — Minute-to-minute loop is a combat treadmill.** G75’s four radial modes
are UI-only except Attack (`godot/README.md`, WIRE.md). P4.md is a large spec
(social, DNA, parts, recipes, Q43 ally 3 / dominate 3). Ally vs dominate must
both win the stage (roadmap done #2). Spore calibration (`CALIBRATION.md`)
says a first play is ~1–2 h; the target here is 6–10 h with G71’s 80/20
discovery mix. Easy failure: hunt is obvious, befriend is a minigame nobody
uses, Observe/Intimidate stay toasts.
*Watch:* every species resolved by killing; gifts/rhythm unused.
*Prevent:* thin Q43 slice (two species, two skills, DNA, one nest edit) before
the full P4 table; Intimidate is the non-kill dominate tool.
*If it happens:* latch ally/dominate earlier; buff befriend DNA/parts; cut rhythm.
*Check:* 45-minute C2 gate: ally and dominate both ≥1; unused radial modes.

**R12 — G71 pacing and 6–10 h of content.** Cheap secrets every 10–15 min,
deep secret every 45–60 min, 8 deep recipes (G71, roadmap catalogue). Spore
players often finish the stage in 1–2 h (or 11 min in a speedrun). Empty 3.2 km
island (W14) with one Garfio (`web/stage/species/` has only Garfio JSON;
`ECOLOGY.md` is cited in the roadmap and does not exist) will feel hollow.
*Watch:* ten minutes of walking with nothing; or secret spam before a nest exists.
*Prevent:* density on the start valley first (W12); cheap secrets in C2; deep
ones one per phase as the catalogue already does.
*If it happens:* shrink the island; drop C6 viewpoints before the four radial modes.
*Check:* timestamped “new thing” log in F8 notes; flag gaps >20 min.

**R13 — Stakes (eggs, nest, raids) feel punitive.** G23: dying costs an egg;
zero eggs loses the stage. P4.md Q-7 already applies this with a stub nest
before hatching exists. Easy to read as a lives counter, not a colony.
*Watch:* rage-quit after a raid, or never leaving the nest to protect eggs.
*Prevent:* C0 scenario “two eggs left”; sandbox (G38) for feel; retune at C2/C3 gates.
*If it happens:* more eggs, slower raids, or sandbox as the demo-hour default.
*Check:* deaths per 45-minute session; abandon rate after first egg loss.

### Scope creep

**R02 — Full-arc leakage.** Same day as A17 (“finish creature completely”),
the log records A1–A18, INDUSTRY.md, ship minds, rogue AIs, cell-as-automation
(`5e6eca5` … `9845216`). CAMERA-ZOOM.md already designs the Band command view.
C2 still takes L0 lineage and A13 cousins “because later stages need them.”
P4.md §1.2 and §5 already treat in-scope creep as a review finding.
*Watch:* PRs naming Band/Realm/Industry/Space, local 1B models, or RTS fog;
ARC-PLAN growing while C1 is unplayed.
*Prevent:* merge rule A17: L0 trait bits only; nothing else from ARC-PLAN §7.2.
Cell (A16) stays a proposal.
*If it happens:* revert; park the branch; do not “just add the ledger UI.”
*Check:* DESIGN.md §11 vs CREATURE-ROADMAP; a new A-number in C0–C1 is a stop.

**R14 — Media and the eight deep secrets arrive too early.** G17/G22: ground,
then swim+glide, then flight+dig. G72: feel → P4 → island → eggs. BACKLOG
still lists underwater art “now” (G64) and alpine W15 “in progress.” Parallel
worktrees (`art-underwater`, `art-meteor`, `g-rock`, `g-actions`) already run
ahead of C1.
*Watch:* water/air/dig PRs before C1; secret parts (`espinas_dorsales`, silk,
ink) without a discovery loop.
*Prevent:* C4/C5 closed until the C2 gate; G64 water may be scenery, not a verb.
*If it happens:* scenery-only water; disable the verb.
*Check:* roadmap phase of every merge; count of open media worktrees.

**R15 — Dual delivery docs.** README.md still teaches `make serve` and
`web/stage/` as “how to play.” G76 says the three.js pages are reference until
Godot is approved. BACKLOG §0–2 (2026-11-15) still has F1 “in progress”,
Electron P7, and “MVP includes the P4 loop,” all superseded by the 2026-11-17
roadmap. Agents will implement the wrong stack.
*Watch:* PRs to `web/stage` combat or Electron; agents citing BACKLOG §1 item 5c.
*Prevent:* one BACKLOG banner: “creature order is CREATURE-ROADMAP; this file is
item state.” (Do not edit README in this task.)
*If it happens:* close the web change; replay the Godot path.
*Check:* new commits under `web/stage` after G76.

### Technical

**R03 — Sim vs island (F4).** M0.md / `godot/README.md`: C world is flat at
42 m, clamped ±195 m (`core/src/stage_world.c`); the 3.2 km island is visual.
Creatures are drawn on `Game.ground` so feet can leave the sim. P4 nodes
(fossils, nest, dens) need W6 guarantees on real heights. PLAN-m0 §8.15 named
this as BACKLOG item 6, not M0.
*Watch:* walking into a mountain on air; nest in a pond; square clamp, no wall.
*Prevent:* F4 in C0, before props; generator heights = LOD0 `TerrainData.ground`;
wall + message until the whole island is live.
*If it happens:* freeze spawns to the valley floor; do not place P4 nodes.
*Check:* `Game.ground` vs `CporeWorld.height` grid error → centimetres, not visual-only.

**R16 — Determinism and GDExtension coupling.** Q24/G56: official bit-exact
path is x86-64 Linux native == WASM, `-fno-fast-math -ffp-contract=off`
(`Makefile`). PLAN-feel: `sinf`/`atan2f` in `walk()` breaks it; only `sqrtf`
and polynomials. PLAN-m0 §8.21: interpolation, camera, grass, loco are
presentation and must not feed back except player intent. Feel already bumped
`CP_STAGE_VERSION` to 2 and rejected v1 logs (`docs/WORLD.md`). Goldens were
re-recorded after combat (`d675356`). `atan2f` is allowed only for observation
bearings. Godot glue uses godot-cpp **master at 4.8-beta3** pinned to
`api_version=4.7` (`godot/README.md`); a casual `git pull` of godot-cpp is a
landmine (PLAN-m0 §8.2).
*Watch:* native ≠ WASM; Godot log ≠ `world_cli --replay`; `ClassDB.class_exists` false.
*Prevent:* keep C flags; `make test` / `make wasm-test`; no rules in GDScript;
pin godot-cpp; seed `extension_list.cfg`.
*If it happens:* revert the math; bump log version; never loosen hashes.
*Check:* three world goldens + 100 random native/WASM runs; one Godot log in `world_cli`.

**R17 — Performance (creatures, grass, terrain, 8 GB).** Default grass 252k
blades; evidence used 60k because software GL is seconds-per-frame
(PLAN-m0 §8.14). World cap `CP_STAGE_MAX_WILD` 24 and 1,024 obstacles
(`world.h`). C5 wants pack + Coloso + five biomes + fire. Compatibility
renderer is the AMD-iGPU path; Forward+ is forbidden in M0. Cache ~8.7 MB per
seed, no eviction (M0.md). Idol (G74) + Godot + a local critic model compete
for 8 GB.
*Watch:* <30 fps in the valley with default grass on the 5060; first gen >10 s (W13).
*Prevent:* quality tiers in C0 D4; imposters at A18 far zoom; shared pack materials;
no Idol while playtesting.
*If it happens:* drop grass, then shadows, then wild count; pull C6 tiers forward.
*Check:* overlay frame time; D12 soak p95 on the owner GPU.

**R05 — G77 action animation.** Locomotion (G73) is in and tested (192 checks,
0 mm slide by construction, deviations documented in `LOCOMOTION.md`). Combat
and social still have no body motion timed to C phases. Branch `g-actions` is
WIP (`f2a1197`) and PLAN-feel already warned it will collide with
`loco_controller.gd`. F3 is “plan only” in the roadmap. Bad tells will make
C1 fail even if the C combat is fair (P2 tourney currently passes,
`COMBAT.md`).
*Watch:* bite lands before the jaw moves; social T-pose; g-actions fights g-feel.
*Prevent:* G73: Opus/Codex only; merge feel → actions; semantic goals, C phase is the clock.
*If it happens:* canned poses for the four combat verbs; delay social motion.
*Check:* tell visible ≥200 ms before hit; `godot-loco-test` still 0 failures.

**R06 — Saves, scenarios, snapshots.** G61/G76: local files in
`~/.local/share/primigenia/`. DEVTOOLS.md: one scenario format for debug,
tests, benchmark starts and F8. Not built. Studio saves genomes only.
P4.md hashes a trailing stage block (DNA, eggs, recipes, four new RNG
streams). Genome `/5` (tiers/levels) is specified and `/4` must still load
(G55). Old scenarios that do not load must fail loudly (DEVTOOLS §3).
*Watch:* lost 45-minute session; F8 missing C state; `/4` creatures rejected after `/5`.
*Prevent:* C0 save/load of `seed + C blob + genome + camera` before C2; version + migrations.
*If it happens:* reset the scenario library; keep genome export working.
*Check:* save, kill, load, hash matches; load a `/4` Merodeador.

### Art and audio

**R07 — Procedural ceiling and weak models.** G66: parallel qwen3.6 agents,
SwiftShader, critic (`tools/art/critic.py` on Gemini Flash / Cohere trial /
NVIDIA). G48 audit rebuilt 16/24 GLBs that were buried, floating or dark
(`docs/evidence/g48.md`). CREATURE.md still lists pinch on spine bends, Babosa
shadow peter-panning, scale shimmer, no PMREM. ART_GAPS.md: no nest, carcass,
fossil, food plants, or Rondo/Zanco/Espinodo genomes. `art-underwater` has
round-2 WIP and GLSL ES precision fixes — the pattern of “looks done in
software, fails for real.” Audio is 15 CC0 files (`assets/audio/CREDITS.md`);
WIRE.md: cries and DNA toasts are placeholders; Q40 voices are C6.
*Watch:* critic ≥8 with an unreadable silhouette; G48 contact fails; “does not belong.”
*Prevent:* Claude reviews every art family (G66); G48 tests; palette C (G63) is the bar;
qwen does props, not loco/combat.
*If it happens:* hero trees/rocks; fewer species done well (G5), not more GLBs.
*Check:* side-by-side vs `docs/evidence/hero/palettes/C/`; G48 contact sheet.

**R18 — Look split: physical creatures in a toon world.** G2/G46: ACES one
pipeline. WIRE.md already retuned sun/ambient because creature preview used
exposure 1.4 vs world 0.926. Rock F2 is in flight (“baked sun shadows need
owner approval”). M0 rock “reads lighter and greyer” than the hero.
*Watch:* creatures look like another game; cliffs stretch (G77 owner note).
*Prevent:* judge at golden hour (G47) on GPU; do not raise world exposure for creatures.
*If it happens:* flatten creature clearcoat, not the sky.
*Check:* creature vs meadow luminance in one GPU shot (P0 method).

### Process (AI agents)

**R04 — False done, stalls, review pile-up.** Evidence already in-tree:
Codex M0 WIP `0170204` did not build (missing OS in the profile, `.so` name
wrong, Makefile stole the default goal) until `a4e7259`; PLAN-m0 is an
assessment of that WIP. Usage-limit rescue commits: `53d42e3`, `3f3dace`,
`05c7d5c`, `96e8354`, `1c88899` (“paused to save weekly Claude usage”).
CALIBRATION.md had to be rebuilt (`d629e22`) because the first pass invented
Spore numbers. P2 spent many combat commits before gates passed (`6c27aa1`).
Q53/BACKLOG §0: Claude reviews every merge. Parallel worktrees on this
machine include `g-actions`, `c0-devtools`, `c1-camera`, `g-rock`, `idol`,
and a stack of `art-*`. PLAN-m0 §8.5: hung Godot under xvfb burns the CPU
and other agents’ runs.
*Watch:* “N checks, 0 failures” with no GPU play; WIP commits; two agents on
`loco_controller.gd`; review waiting >24 h.
*Prevent:* G25 = tests + playable build + evidence + **owner session**. Critical
paths (G73/G77, `walk()`, hashes) = Opus/Codex. One folder owner (PLAN-m0).
Timeout every Godot. Claude does not implement the week it is the only reviewer.
*If it happens:* freeze worktrees; drain review; resume from last green `godot-play-test`.
*Check:* open worktrees; age of unreviewed PRs; WIP commits per week.

**R19 — Stale plans and lost work.** BACKLOG vs roadmap (R15). PLAN-feel S9
deferred; STUDIO-PARITY.md is named in BACKLOG and missing in this tree.
Laptop reboot loses uncommitted agent work unless someone writes a WIP commit
(the existing pattern). `user://` lives only on this disk.
*Watch:* agents treat PLAN-m0 leftovers as open; uncommitted Godot state in `/tmp`.
*Prevent:* C0 D5 F8 + a WIP commit at every usage-limit warning; scenarios in git.
*If it happens:* recover from the last WIP commit; do not reconstruct from chat.
*Check:* `git status` clean in every worktree before a reboot.

### Owner bandwidth

**R08 — Decision and playtest bottleneck.** Every phase gate is an owner
play session (roadmap, G25, G58). Open owner calls already listed: F2 rock
shadows, colours outside palette C, loading-screen copy, tank vs latch,
S9 speeds, CAMERA-ZOOM vs today’s chase, trademark, name on the store.
Feel work is iterative by nature; C2–C5 will multiply questions (P4.md still
has Q-1…Q-20 even though G55 approved the recommendations).
*Watch:* >5 unanswered design questions; play past usefulness; agents stuck on “ask.”
*Prevent:* C0 A/B answers in-game; one decision batch a day; default to P4.md if DESIGN.md is silent.
*If it happens:* freeze features, only tune; skip C4 media rather than skip gates.
*Check:* decision-backlog count; play sessions/week (target 3×30 min, not one 4 h grind).

### Benchmark coupling

**R09 — Goldens and fairness.** Same C core for game and board (G1, G56).
Feel already invalidated v1 world logs. P4 appends a hash block so combat
goldens stay byte-identical — until someone hashes the new fields into the
old path. Q-10 pity drops exist so seed variance does not wreck the board.
Q18 cap is 2,500 creature decisions; P4 Q-13 budgets 400 for “find the
recipe.” Q51 wants idle < random < scripted and one LLM over scripted.
`bindings/python/` and WASM faces must stay in lockstep. PLAN-feel warned
`stage_winnability` (guard 100 % at baseline, later 58 % with `wild_k` 0.6).
*Watch:* goldens fail after a feel tweak; agents rewrite `tests/golden/`; idle wins;
recipe search is brute force (Q-12).
*Prevent:* stage-block hash only when the layer is on; bump engine version on rules;
canaries in CI; tunables in data (D4), not `combat.c`, when possible.
*If it happens:* freeze the board at the last tagged core; game continues on a versioned ABI.
*Check:* `make test && make tourney && make wasm-test` on every core PR; canary wins = 0.

**R20 — LLM harness cost (C9).** Q12/Q54: one OpenAI-compatible client, NAN
for dev, paid frontier from v0.4. Creature cap 2,500 decisions × 3–5 seeds
× retries is real money if someone points a frontier model at every merge.
Local 1B ship-mind (A8) is **not** a creature-stage task.
*Watch:* NAN bills from playtest agents; C9 work during C1.
*Prevent:* C9 alongside C6–C8 only; scripted + PPO first; cap eval tokens.
*If it happens:* stop live LLM evals; use recorded replays.
*Check:* weekly token log; no frontier calls before C8 demo.

### Legal / release

**R10 — Name, likeness, licences.** G34/G62: public name Primigenia, informal
web search only; Argentine RPG *Pampa Primigenia* noted; formal EUIPO/TMview
+ USPTO still required before P7, now C8. README: independent fan tribute,
no Maxis/EA terms (Q4). Calibration is wiki/YouTube, game not bought
(Q14). Spore captures live **outside** the repo (`80e60f0`, CAMERA-ZOOM.md)
and must never be committed. Audio is CC0 with `CREDITS.md`. Art is CC BY
4.0; code MIT. G74 Idol is Apache 2.0; PyTorch/weights are a separate
licence surface. Stores (Steam especially) want an AI-content disclosure;
G66 procedural art and Idol meshes are in scope. A4’s Culture/Foundation
proper nouns are later stages but A12’s void-adapted shortcut is a creature
secret with a space payoff — keep names original here too.
*Watch:* store page using “Spore-like” as a mark; Idol weights bundled; missing CC0
credits; TM office hit on Primigenia.
*Prevent:* start the formal TM search in C0. Credits screen from day one. No Spore
assets in git. Disclose AI pipelines at C8. Do not ship Idol weights.
*If it happens:* rename (cpore is already the format prefix); strip the asset; delay C8.
*Check:* `git grep -i spore` in shipped paths; credits list; TM docket.

### Platform and release

**R21 — Desktop ports and GPUs.** G76/C8: Linux, Windows, macOS from Godot.
Only Linux `.so` is built; `cpore.gdextension` Windows/macOS lines are
placeholders (`godot/README.md`). First-import SIGSEGV without
`extension_list.cfg` (PLAN-m0). AMD iGPU owners will hit Compatibility +
low VRAM: quality tiers are C6. No crash reporter; D12 soak is the plan
(`make soak` not implemented). es/en is Q48 and studio `i18n.gd`; stage
strings are still mixed and C6 lists localisation. itch.io downloads
replace the Electron plan (G60 superseded).
*Watch:* white screen on AMD; unsigned Windows .dll; Spanish UI, English verbs;
silent exit on extension load.
*Prevent:* export templates in C8 not C1; one AMD/iGPU smoke before the demo;
F1 legend (A14) generated from the InputMap.
*If it happens:* Linux-only demo; Low preset default; English with es overlay.
*Check:* `make godot` on a clean Windows VM before C8; 8 h soak with D12.

### Hardware / single machine

**R22 — One laptop is the studio, CI and farm.** RTX 5060 8 GB, 30 GB RAM,
many worktrees under `/home/diego/Desarrollo/cpore-wt/`. Godot, Emscripten,
Playwright Chromium, Idol/PyTorch, and parallel agents fight that budget.
No remote backup is documented. `~/.local/share/primigenia/` (island cache,
studio saves, future F8) is not in git. Disk fill from terrain caches
(PLAN-m0 §8.20) and worktree `.godot/` imports.
*Watch:* OOM with two Godots and Idol; disk full; laptop loss.
*Prevent:* one GPU job at a time; `nice -n 10`; remote for this git; weekly copy of
`user://` and `_agent/`; park art worktrees after review.
*If it happens:* restore from remote + last WIP commits; regenerate the island cache.
*Check:* worktree count; disk free; last off-laptop backup date.

### Other (found in this tree)

**R23 — Camera conflict (A18 vs G72).** Feel just settled a chase camera
with a 100 deg/s cap. A18/`c1-camera` wants continuous zoom to a strategic
map. Easy to undo C1 feel while implementing the map.
*Watch:* camera yaw rate back above 100 deg/s; owner “whirl” notes after zoom lands.
*Prevent:* keep chase as default z=0.15 (CAMERA-ZOOM.md already says so); map zoom after C1.
*If it happens:* ship zoom as a debug overlay (D9) until feel_test is green.
*Check:* feel_test camera rates still ≤100 deg/s after zoom lands.

**R24 — Species and ecology data missing.** Roadmap C2 needs 6–8 species
(ECOLOGY.md). P4 tables name four; only Garfio is a file. World species ids
0–3 are hard-coded (`WORLD.md`).
*Watch:* social PRs invent species in code; four names, one genome.
*Prevent:* genomes + temperament tables as data before social verbs.
*If it happens:* ship two species only (Garfio + one herbivore) for the C2 gate.
*Check:* `ls web/stage/species` and Godot equivalents ≥4.

**R25 — Combat fairness ≠ fight readability.** P2 tourney passes; stage
winnability is scripted (42/58/76 %). Humans still lack tells, hit flash
(ART_GAPS G26), dodge feedback, flee. Guard was 100 % until `wild_k` was
cut — a reminder that motion changes break “balance” without touching
`combat.c`.
*Watch:* owner cannot tell bite from charge; `wild_k` retunes after every motion PR.
*Prevent:* C1 readability before new moves; G53 secret moves must re-run tourney.
*If it happens:* freeze new moves; add tells and a flee key only.
*Check:* owner can name the incoming move from the tell alone.

---

## 3. Kill criteria (stop, cut, or rescope)

1. **C1 fun:** after three GPU sessions with F8 notes, move or fight still <4/5.
   Do not start C2. Rescope to a combat toy or stop.
2. **Empty valley:** a 10-minute walk after C1 props yields no fight, creature,
   or find. Cut island size; do not add biomes.
3. **Ally path dead:** two C2 sessions with no deliberate befriend. Cut social
   to one skill + gifts, or drop “both paths win” for the demo.
4. **Stakes hate:** egg loss causes quit more than retry. Sandbox is the public
   demo; G23 stays for the long game only.
5. **Determinism red >7 days:** native ≠ WASM or replays diverge on trunk.
   Freeze features; only hash/math fixes.
6. **Owner saturation:** no gate closed for 14 days while worktrees pile up.
   Halt new agents; owner plays, then cuts C4/C5 first.
7. **Usage stall:** two weeks of only WIP-limit commits and no owner gate.
   One agent, C0 tools only.
8. **Art identity:** blind “does it belong?” fails vs palette C after two G66
   rounds on the same family. Stop qwen on that family; reuse hero props.
9. **Perf floor:** <30 fps in the valley on the 5060 at Low with 8 wilds.
   Cut grass/fire/pack; no Coloso.
10. **Legal stop:** EUIPO/USPTO hit on Primigenia, or store rejection on
    AI/Spore likeness. Rename or delay C8; work continues under cpore.
11. **Benchmark poison:** idle or random wins, or goldens rewritten with no
    engine-version bump. Revert the rule change.
12. **Scope inversion:** a merged PR’s main purpose is Band/Industry/Space
    or a local LLM. Revert; reread A17.

---

## 4. This week (ranked)

1. **Owner GPU play of `make godot && godot --path godot`.** Ten minutes,
   F8-style notes even if D5 is missing (screenshot + feel). Only this informs R01. (owner)
2. **C0 DT0, thinnest slice:** F1 legend, console, F5/F6 scenario, F4 A/B,
   F8 dump. The play loop is the bottleneck. (agents; Claude reviews)
3. **F4 spike:** C heightfield from the generator on the valley slice; wall
   + message at ±195 m until the island is live. Unblocks props and P4. (agents)
4. **A17 freeze:** no new ARC-PLAN / Industry / cell work; L0 bits only as
   a side effect. Park `c1-camera` map zoom until after the GPU session. (owner, Claude)
5. **Serialise `g-actions`.** Rebase onto feel and finish bite/charge tells,
   or pause so it cannot fight `loco_controller.gd`. (Claude)
6. **Start the formal Primigenia TM search** (EUIPO/TMview, USPTO). Due
   “before P7” since G62; C8 is the new P7. (owner)
7. **Off-laptop backup:** remote for this git; copy `~/.local/share/primigenia/`
   and `_agent/godot-cpp` pin notes. (owner)
8. **BACKLOG banner** pointing at CREATURE-ROADMAP (when other docs may
   change) so agents stop reading Electron/P7/web-first as current. (Claude)
9. **Species roster:** draft 6–8 names, diets, temperaments (the missing
   ECOLOGY.md) without art. Merodeador + Garfio are not a roster. (owner)
10. **Art farm hygiene:** one qwen worktree to merge-or-kill; no new Idol
    download while the 5060 is for play. Claude reviews G48 only. (Claude)

---

Sources: CREATURE-ROADMAP, DESIGN (Q/G/W/A), BACKLOG, P4 §5, DEVTOOLS, ART_GAPS,
CALIBRATION, README, Makefile, godot/{M0,CREATURE,LOCOMOTION,FEEL,WIRE,PLAN-m0,PLAN-feel,CAMERA-ZOOM,UI,STUDIO},
WORLD, COMBAT, ARC-PLAN, audio CREDITS, `world.h`, `git log --oneline -150`,
WIP/usage-limit commits, worktrees on this machine.
