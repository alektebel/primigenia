# Task lore-run: the multi-world lore autoloop (build it, then run it unattended)

Worktree /home/diego/Desarrollo/cpore-wt/lore-run, branch lore-run (from main ca4b9e7). Read first: docs/LORE-FORMAT.md,
docs/LORE-WORLDS.md (A23), docs/DESIGN.md rows A19–A23, tools/lore/README.md, tools/lore/council/{council.py,got.py,canon.md},
tools/lore/{validate,render,refcheck,import_got}.py, lore/ (schemas, worlds/primigenia.json, creatures/ecolumbre.json, references.json,
alltomorrows.en.json; hailmary.en.json may arrive later from another branch — handle its absence), and
tools/lore/council/primigenia_canon.md (the APPROVED island canon, 27 facts F1–F27, written by Opus; uncommitted, commit it).
Models: council.py already routes voices to qwen3.6 (NAN API, $NAN_API_KEY, max 5 concurrent shared with other jobs: keep the
semaphores at 2), opencode free models (DeepSeek skeptic, GLM senses) and Cursor composer-2.5 (astrobio referee). Never change which
model plays which voice; you may add new voices only with existing models.

## Step 1 — convert the island canon
Convert primigenia_canon.md into lore/worlds/primigenia.json (status reviewed; keep the ids F1–F27 and their meaning; groups per
schema; justification + consequences). ecolumbre.json's roots must still be correct (F4 dense air, F5 oxygen, F6 moon, F8 fog,
F9 lava tubes) — check, fix if needed. `make lore-check` green.

## Step 2 — generalise the council to any world
Make council.py/got.py world-parametric (world id, a canon text, the creature list, kind, seed notes) without breaking the current
CLI. Add an "chair" step: after the planet drafts + peer reviews + the astrobio referee review, a chair (DeepSeek skeptic via opencode,
fallback qwen) writes the merged world canon as JSON for lore/worlds/<id>.json (status draft, numbered facts), then the referee checks
it once more and the chair applies the fixes. For kind "real" every fact needs refs (CSL ids added to lore/references.json as
unverified, then refcheck). For kind "third_party", facts come from the lore file (cite it in provenance) and the council only fills gaps.

## Step 3 — the world list (tools/lore/council/worlds_seed.json), in this order
1. primigenia (canon exists: skip planet; run GoT for the island creatures + `species` for empty niches: 4 new species, at least one
   bizarre). Island creatures: Rondo, Zanco, Espinodo, Garfio, Coloso, Merodeador, Zancuda, Babosa, the player's lineage and cousins,
   the nocturnal creature (give it an id and aliases), albinos, Ecolumbre (merge, never overwrite reviewed chains).
   NOTE: Opus is already running got.py for the island in /home/diego/Desarrollo/cpore-wt/_agent/lore-council/got/ — when its
   got/graph.json exists, import it instead of re-running (copy the run into the runs dir).
2. earth (kind real; Sol, Orion Arm ~8.2 kpc): humans with real-biology chains and real references; 3 real animals as reference points.
3. erid (40 Eridani A, ~16.3 ly) and adrian (Tau Ceti, ~11.9 ly): third_party (Project Hail Mary, A20): Eridians, Taumoeba; Astrophage
   filed on a star world (see 6).
4. a gas giant — "the deep sky": life in a Jupiter-like atmosphere from first principles: **sinkers, floaters, hunters** (Sagan &
   Salpeter 1976, ApJS — real, add the reference), **air whales** (giant hydrogen-buoyed floaters), **jet hunters** (fast predators that
   propel themselves), grazers of the cloud plankton, and the honour-bound tentacled species (A4, third_party Banks: name only via a
   lore file entry, our own description).
5. silicon life — two worlds, because silicon biochemistry only works in some conditions (the referee must say which and why, citing
   e.g. the silicon-vs-carbon literature such as Bains 2004 Astrobiology, Petkowski/Bains/Seager 2020 Life): a HOT world (silicone/
   silicate chemistry in a sulfuric or very hot regime) and a CRYOGENIC world (silanes in liquid nitrogen/methane). Creatures derived
   from that chemistry: slow metabolisms, crystal growth, glassy shells, whatever the physics forces.
6. life on and in stars — "the star world" files Astrophage (A20) plus original speculative life: plasma/magnetic-flux-tube organisms in
   a stellar photosphere or corona, and a neutron-star crust ecology (nuclear-chemistry life, very fast time). The referee must grade
   these honestly (speculative; cite the speculative literature it knows, e.g. Tsytovich et al. 2007 on plasma helical structures, and
   say "highly speculative" where true). Keep them original (no names from novels).
7. All Tomorrows (A19): one world per group the lore file implies (Earth/Mars, the Qu-shaped worlds, Gravital space, etc.); all 45
   species as kind easter_egg with lore_ref, 1–3 chains each explaining the book's design from first principles (our own words).
8. bizarre-but-plausible worlds: a tidally locked red-dwarf world, an ice-moon subsurface ocean, a high-pressure super-Earth, a rogue
   planet warmed from inside, a gas giant's ring-moon. 3–5 species each, at least one strange enough to surprise.

## Step 4 — the loop
`tools/lore/council/autoloop.py [--only WORLD] [--max-worlds N]`: for each world, unattended and resumable: planet stage → chair
canon → GoT creatures (generate, aggregate, 4 judges incl. astrobio, refine, crosslink) → species for empty niches → import_got →
validate → render → refcheck. Log per world to runs/<world>/log.txt and a summary table (creatures, chains, verdict counts, refs
verified/rejected, failures) to docs/lore/AUTOLOOP.md. A failing world must not stop the loop. Commit after each world
("Lore: world <id> (N creatures)"). Run it to the end. If a model is down (429 storms, opencode errors), retry with backoff; after 40
failed tries, mark that step failed and move on.

Rules: no installs, no pushes, no edits outside tools/lore, lore/, docs/creatures, docs/lore, docs/LORE-*.md, Makefile (lore targets).
Third-party names only where the A4/A19/A20 rule allows (our own files reference third-party lore by id). Commits end with
`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. When finished, reply with the summary table, the worst problems the
judges found, and anything that failed.
