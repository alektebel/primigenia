# tools/lore: from council to canon

Standard: `docs/LORE-FORMAT.md`. Data: `lore/worlds/<id>.json`, `lore/creatures/<id>.json`, `lore/references.json`. Python 3 stdlib + `jsonschema`.

## Pipeline

1. **Council on a world** (`council/council.py`): seven advisors draft and peer-review the world's physics.
   `export NAN_API_KEY=...; LORE_RUNS_DIR=/path/to/runs python3 tools/lore/council/council.py planet`
   Output goes to `$LORE_RUNS_DIR` (default `tools/lore/council/runs/`, gitignored). Resumable.
2. **World canon**: a human/Opus merges the drafts into `planet_canon.md` (in the runs dir, facts `F1..Fn`) and into `lore/worlds/<id>.json`.
3. **GoT creatures** (`council/got.py`): generate, aggregate, score, refine and crosslink causal chains per creature.
   `python3 tools/lore/council/got.py` writes `<runs>/got/graph.json` and `3_score_*` files. `got.py species "<concept>"` derives a new species.
4. **Import**: `python3 tools/lore/import_got.py <runs>/got/graph.json --world primigenia [--kind native] [--dry-run]`
   Creates drafts in `lore/creatures/`. Existing drafts are merged by chain trait (changelog line added); `reviewed` and `canon` files are never touched.
5. **Validate**: `python3 tools/lore/validate.py` (schemas, roots in the creature's world, references exist and are not rejected, unique ids, relation targets; unresolved relation targets are warnings while draft).
6. **Render**: `python3 tools/lore/render.py` writes `docs/creatures/`, `docs/lore/worlds/`, `docs/lore/REFERENCES.md` (generated, never edit).
7. **Refcheck**: `python3 tools/lore/refcheck.py [--dry-run] [--only ID]` checks `unverified` references against Crossref / OpenLibrary (cached in `tools/lore/.cache/`, 1 req/s) and sets `verified` (DOI/ISBN filled, title fixed), `rejected`, or leaves a note when ambiguous. Remove or re-review any chain that cites a rejected reference.
8. **Owner approval**: the owner sets `status` to `canon` (draft, reviewed, canon). Only canon ships.

## Make targets

- `make lore-check`: unit tests, validate, render, and fail if the rendered docs differ from what is committed.
- `make lore-refcheck`: run the reference checker and write `lore/references.json`.
- Tests alone: `python3 -m unittest discover tools/lore/tests` (fixture graph in `tests/fixtures/got/`).

## Autoloop (all worlds, unattended)

`python3 tools/lore/council/autoloop.py [--only WORLD] [--max-worlds N] [--no-commit]` walks `tools/lore/council/worlds_seed.json` (19 worlds) and, per world, runs: planet drafts + peer reviews + astrobio referee, the **chair** (DeepSeek, fallback qwen) writes the world canon as JSON, the referee checks it, the chair applies the fixes (`lore/worlds/<id>.json`, status draft), GoT creatures, species for empty niches, `import_got`, validate, render, refcheck, and commits `Lore: world <id> (N creatures)`.
Everything is resumable (state in `runs/<world>/state.json`, log in `runs/<world>/log.txt`); a failing step is retried, then marked failed without stopping the loop. Summary table and the judges' worst problems: `docs/lore/AUTOLOOP.md`.
World-parametric council: `LORE_CTX=<ctx.json>` makes `council.py` / `got.py` work on any world (creature list, notes, kind, voices, batch size); without it they behave as before for the island. `council.py chair` and `got.py species|profiles` are the new commands.
