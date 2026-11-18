# Creature stage: independent second opinion

Reviewed 2026-11-18 at `9c4747f`, on branch `risk-sol`.
Perspective: an outside senior producer and technical director. Report only.
This is a document and history review. I did not build, run Godot, or play the game.
Reported test results below belong to the cited documents, not this review.

## Blind review: my top ten

This section was written to disk before opening `RISKS-CREATURE.md`.
C0–C9 below are risk IDs, ranked by delivery priority, not roadmap phase numbers.
Likelihood: H = likely without intervention; M = credible but unproven.
Impact: Critical = blocks a viable release; High = major rework or loss of players.
All thresholds below are proposed production decisions, not existing owner approvals.

The project has built far more infrastructure than it has proved player value.
That is the main danger. More agent output will not settle whether this is fun.
The owner and Claude are scarce resources. Parallel work does not multiply either.

The roadmap's status table is stale. `89a4bbb` merged dev tools and island heights;
`0e35914` merged actions; `9b1abb7` merged studio parity; `ea0e31e` merged rock work.
These reduce implementation risk. They do not establish interactive acceptance.
`docs/godot/DEVTOOLS.md`, `ACTIONS.md`, and `ROCK.md` explicitly retain unverified work.

### C0 — “Finish completely” can prevent any release

**Likelihood H · Impact Critical.** The definition of done requires 6–10 hours,
eight deep secrets, four media, raids, packs, three desktop platforms, and more.
`CREATURE-ROADMAP.md` C2 alone combines social, economy, evolution, cousins and secrets.
A17 stops other stages; it does not bound the creature stage. Commit `9845216`
fixes ordering, while `9c4747f` still adds another fossil to the catalogue.

**Early warning:** another week closes module plans but no player completes a new loop.
**Mitigation:** keep the full vision, but approve a separately releasable 30–45 minute
slice: one region, hunt and befriend, one evolution, one secret, save/load, a clear end.
Use this week's measured throughput to budget the next two weeks. Count accepted play,
not commits. Require a named substitution for every new mandatory feature.
**Kill/pivot:** if two weekly reviews miss the same playable gate, stop adding content;
ship or repair the smaller slice before committing to the eight-secret full release.

The full arc does endanger Creature. `ARC-PLAN.md` §7.3 authorises L1 now and gates
later work only on MVP + P9; §7.2 invites parallel Cell. A17 instead permits only L0
before Creature is complete. Follow A17. Record earned traits and their provenance;
do not build a universal pressure/gravity/radiation model or RTS framework now.
The Space shortcut explicitly waits for Space (§9b); it must not block this ending.

### C1 — Matching terrain is not navigable terrain

**Likelihood H · Impact Critical.** F4 closed the flat-world mismatch, not traversal.
`docs/godot/DEVTOOLS.md` says straight GO orders fail on about half of 20 far targets.
`PLAN-heights.md` leaves caves without interiors. Yet roadmap C2 requires a hidden cave,
and C3 requires autonomous foragers and raiders. `98cb49a` is progress, not a pathfinder.

**Early warning:** the owner teleports to content that a fresh creature cannot reach;
a forager or retreat order stalls against a cliff without explanation.
**Mitigation:** certify a small route graph for the curated region: nest, food, fight,
fossil and cave. Check both directions with the initial body and each unlocked medium.
Add arrival/blocked results to orders. Separate cave entrances from playable interiors.
**Kill/pivot:** any mandatory round trip needing teleport or an unavailable part blocks
C2 acceptance. Restrict the region and use authored paths/cave rooms before pack AI.

### C2 — Tests prove timing while players still cannot read the fight

**Likelihood H · Impact Critical.** `ACTIONS.md` reports C HIT/impact agreement within
one frame, but also no bite contact response, short tails missing the front cone,
and judgement under software GL. `WIRE.md` still documents social modes without C verbs.
`AGENTPLAY.md` reports missing outcomes and errors; it measures the Python interface,
so it cannot by itself establish the same defects in the Godot HUD.

**Early warning:** a player cannot explain why a hit landed, why an order failed,
or whether singing changed a relationship rather than merely played an animation.
**Mitigation:** review actual moving footage at normal speed. Test three unfamiliar
people for ten minutes now. Ask them to predict an enemy attack, dodge, retreat,
and distinguish a working verb from a cosmetic preview. Log the resulting C events.
**Kill/pivot:** if two of three cannot explain a loss or a mode's consequence after
one revision, freeze extra animation polish and repair tells, input and feedback first.

### C3 — The authored body can promise abilities the C creature does not have

**Likelihood H · Impact High.** G4 makes C authoritative; G73/G77 derive motion from
morphology. `CREATURE.md` exposes illustrative stats, `STUDIO-PARITY.md` still lacks
ability names, and `PLAN-actions.md` §6 warns that C geometry differs from drawn geometry.
`FEEL.md` defers per-creature speeds and measures the full pipeline on Merodeador only.

**Early warning:** longer legs do not change travel as expected; a visible jaw misses
while C deals damage; a purchased wing looks functional before gliding exists.
**Mitigation:** define one explicit studio-to-C projection for price, capabilities,
size, speed and reach. Show unsupported parts as cosmetic. Compare rendered contact
and actual hits on the three seeds plus deliberately extreme legal bodies.
**Kill/pivot:** an accepted body with an unavoidable reach or movement failure blocks
paid evolution. Bound legal body dimensions or abilities until the projection works.

### C4 — Debug snapshots are not yet a durable progression save contract

**Likelihood H · Impact Critical.** `5efb3bc` added game saves, so “add saves” is obsolete.
But `docs/godot/DEVTOOLS.md` describes raw POD snapshots with layout fingerprints,
recipes, and an unverified exported F5 write path. `PLAN-heights.md` says generator
changes invalidate old islands. A recipe can rebuild a test; it need not preserve
45 minutes of DNA, cousin identities, clue discovery and irreversible trait history.

**Early warning:** an ordinary core change rejects yesterday's playtest save;
loading restores the world hash but loses progression or changes the terrain.
**Mitigation:** specify which versions are supported; store stable progression fields,
genome, lineage, generator identity and tuning. Keep binary snapshots for exact repro.
Maintain a pre-update save fixture and check continuation, not just immediate hashing.
Require an atomic write and recovery from interruption before outside playtests.
**Kill/pivot:** any lost progression in the supported version blocks longer sessions.
Pin the demo engine/generator and label unsupported upgrades instead of promising migration.

### C5 — Review and owner acceptance are the actual production queue

**Likelihood H · Impact High.** Every phase needs owner closure (G25); Claude reviews
parallel agents. `1c88899` explicitly paused work to save weekly Claude usage;
`53d42e3` also records unfinished work saved at a usage limit.
Small, fast implementation steps still queue integration, evidence and design decisions.

**Early warning:** more than two playable changes wait for review, or feedback bundles
are produced faster than anyone resolves them. An agent starts another polish branch.
**Mitigation:** cap work at one shared-core change and one independent content task.
Reserve owner sessions and reviewer usage before starting implementation. Merge against
one known integration commit. Each handoff names interfaces, open defects and next check.
**Kill/pivot:** if review waits exceed two working days, stop starting branches and use
remaining capacity to reproduce, integrate and close the queue. Do not recruit more agents.

### C6 — Progression can reward grinding and punish the exploratory player

**Likelihood H · Impact High.** G49 requires usage to unlock tiers; G19 adds trust decay;
G23 makes eggs lives; G30 makes Cognition compete with parts. C2–C3 combine them before
there is evidence of a sustainable session. `AGENTPLAY.md` reports every scripted survivor
episode had a death; that is an early combat-world signal, not a measured egg-loss rate.

**Early warning:** repeated safe kills beat exploration for DNA; the player must babysit
trust or eggs; a body purchase prevents earning the means to recover.
**Mitigation:** model a 45-minute resource budget for hunter, befriender and explorer.
Check distinct costs and rewards, ally/dominate completion and no-cost farming canaries.
Test one bad purchase and one death. Explain losses before introducing permanent failure.
**Kill/pivot:** if a supported route cannot recover without repetitive farming or restarting,
flatten tier requirements or remove decay pressure before adding raids and more recipes.

### C7 — The laptop's development evidence is not a shipping performance budget

**Likelihood H · Impact Critical.** M0 documents 252,000 default grass blades versus
60,000 in evidence. `ROCK.md` still asks for hardware numbers and refers to a Radeon 860M;
the brief gives an RTX 5060 8 GB. Neither identifies the adapter used by a future player.
The Makefile's evidence targets force software GL. `make check` exercises the old browser
pipeline; separate Godot targets exist. M0 lists Linux-only builds and export asset filters
are required by `CREATURE.md`. A desktop release is more than the editor running.

**Early warning:** p95 frame time is unknown at actual defaults; exports omit raw assets
or the native extension; parallel renders make the owner's session unusable.
**Mitigation:** reserve the laptop for a recorded hardware run. Log adapter, build,
resolution, grass, tier, p95 and peak memory on a fixed route with several creatures.
Propose 1080p/60 fps on the RTX, with 30 fps low tier as a declared fallback.
Validate a clean Linux export early, then Windows/macOS smoke tests before announcing them.
**Kill/pivot:** if low tier cannot sustain 30 fps or memory fits only with development
work stopped, reduce population/grass/detail; release Linux first if other exports fail.

### C8 — Discovery density and cousins create recurring content costs

**Likelihood H · Impact High.** G71's 10–15 minute cadence implies roughly 24–60
new beats over 6–10 hours; eight moves do not fill that schedule. `ARC-PLAN.md` §9b
calls cousins low cost, but every evolution adds population, identity, trust, saves,
family-tree UI and possible reward farming. C2 needs these before its first long gate.

**Early warning:** routes offer repeated fossils without new decisions; cousin spawns
consume the species budget or let players repeatedly harvest their own lineage.
**Mitigation:** map the first 45 minutes by route and discovery time. Give each secret
a reachable clue, meaningful payoff and a recovery path. Bound active cousin populations,
keep old genomes in the journal, and separate cousins from progression rewards.
**Kill/pivot:** if outsiders need hints to find any secret, fix clues and placement before
adding recipes. If cousins displace designed encounters, retain the archive and defer wildlife.

### C9 — The benchmark can certify a different game and consume scarce usage

**Likelihood H · Impact High.** `AGENTPLAY.md` audits Python's ±195 world; FIELD mode
is deliberately absent there and in WASM in C0 (`docs/godot/DEVTOOLS.md`). The Godot
socket now exists (`92ab1ef`), but its existence does not move the reported audit onto it.
The audit spent 2,538,472 tokens and random won 38% of its eight combat episodes.
That “win” is not established as stage advancement; Q52's stage canary remains untested.

**Early warning:** green Python replays justify island acceptance; old analytic-world
bounds flag valid island movement; another LLM sweep runs before known feedback bugs close.
**Mitigation:** identify backend, terrain hash, schema, build and win definition on every
report. Exercise the curated island through the socket with scripted routes first.
Bring FIELD support and parity to official benchmark backends before C9 scoring.
Use paid/limited model calls only for a question deterministic policies cannot answer.
**Kill/pivot:** any backend mismatch or stage win without legitimate progress invalidates
that result. Pause the leaderboard and broad LLM runs; retain cheap regression playtests.

## Where I disagree with the first review

The first review (`1c1d54a`, merged by `ff2b99f`) gets the owner/reviewer bottleneck
and game-first priority right. Several differences below reflect subsequent merges,
not mistakes the reviewer could have foreseen. Its weekly queue must be refreshed.

| First review | My judgement and replacement |
|---|---|
| R03: flat island is a top-three risk; build F4 this week | Outdated after `89a4bbb`. Heights now agree. Promote navigation, reachability and cave interiors instead (C1). Comparing height grids cannot prove a round trip works. |
| R05: actions have no timed body motion | Outdated after `0e35914`. `ACTIONS.md` documents real timing tests. Lower the implementation risk; keep readability high because contact, short tails and real GPU judgement remain open (C2–C3). |
| R06: saves not built, M likelihood | Saves exist; durable progression remains H (C4). Resetting the scenario library is acceptable for fixtures, not player progress. An immediate hash round trip cannot prove upgrade survival or exported writes. |
| R19: studio parity document missing | It is present; `9b1abb7` merged parity. Remaining gaps are named in `STUDIO-PARITY.md`. Do not restart completed work from stale status prose. |
| R15: a BACKLOG banner fixes dual delivery docs | `1bc6a58` already added it. README and `make check` still lead to the browser. A banner alone cannot tell an agent which command actually certifies the shipped Godot game. |
| R02: new A-number or later-stage PR means stop/revert | Too blunt. An isolated design note is cheap; committed implementation and review obligations are expensive. A17 is the boundary. Resolve L1 and parallel Cell wording explicitly; keep L0 small. |
| R01: three owner ratings below 4/5 imply combat toy or stop | Too little evidence for that pivot. Identify the failed behaviour and try a bounded fix. Test strangers early; owner taste alone cannot establish onboarding or readable combat. |
| R11: Intimidate is the non-kill dominate tool | G75 says drive off without kill DNA or relationship damage. It does not establish species-resolution credit. Define that rule before counting intimidations as domination. |
| R09/R20: M benchmark coupling; defer C9 and replay instead | Coupling is already H: Python/WASM lack the island field. Recorded replays cannot exercise a changed implementation. Keep cheap scripted island tests now; defer expensive leaderboard comparisons (C9). |
| R21: export templates in C8, not C1 | Too late for native-library and raw-asset discovery. Smoke a clean Linux export now. Announce Windows/macOS only after their exports work. This need not become a porting project this week. |
| R07/R18: more art review, canned poses if procedural actions fail | Art matters, but another critic score or pose set cannot fix sim/drawn reach disagreement. Prioritise reliable body capabilities and normal-speed readability. Do not replace G77's morphology contract silently. |

The first review lists pacing (R12), stakes (R13), species (R24), performance (R17)
and fairness (R25). Those are not omissions. I promote them because full C2–C5
scope can fail even if cross-stage leakage stops. “One stage at a time” is insufficient.

Its material omissions are the current split between island and benchmark worlds;
explicit traversal contracts before autonomous pack jobs; the difference between
repro snapshots and durable progression; and the lifecycle cost of cousin species.
Its top ten also hides content/economy risk below visual and legal risks.
R10 remains a release dependency, but I would not rank it above those this week.
A19 (`9c4747f`) adds exact borrowed species names for later stages. The creature
skull is a generic fossil; ensure any shipped lore strings receive the planned
release review. A swappable lore file does not itself establish permission to ship.

## Merged top five for this week

Keep the first review's GPU play, A17 boundary and review discipline. Replace its
already-merged DT0/F4/actions tasks with acceptance work. Execute this as one queue.

| Rank | Action and accountable person | Reviewable exit evidence |
|---|---|---|
| 1 | **Owner:** play the current integrated build for ten minutes; compare A/B and capture F8. **Claude:** triage only the three biggest failures. | Build hash, actual adapter, defaults, frame times and clips. Player can recognise a tell, dodge and retreat. Name the one repair needed to close C1. |
| 2 | **One agent, Claude reviewing:** certify the curated route through nest, food, encounter, fossil and cave entrance; test blocked orders and return home. | Route matrix on the real FIELD world through the Godot socket. Mandatory routes pass without teleport. Cave entrance and interior are explicitly distinguished. |
| 3 | **Owner + Claude:** freeze the small C2 slice and its roster, resource budget and completion rules. Resolve A17 versus L1/Cell wording in the next authorised planning change. | One-page acceptance checklist: hunt, befriend, spend, evolve, discover, save, end. State what Intimidate earns. Schedule three unfamiliar ten-minute testers before adding more systems. |
| 4 | **One agent, Claude reviewing:** validate the existing save and a clean Linux export. | Save in the exported build, exit, reload and continue. Check genome, progression, terrain and lineage. Interrupt a write; recover or fail clearly. Record the supported-version policy. |
| 5 | **Claude + owner:** cap active work, reserve review/play time, refresh the acceptance queue. | At most two active implementation tasks; named reviewer and session for each. Mark merged work as awaiting acceptance where appropriate. Run scripted island checks before spending more LLM usage. |

If the week ends with more polished modules but no accepted player loop, the plan
has failed for that week. Narrow the next slice. Do not respond by opening more worktrees.
