# Lore format: one file per creature, one planet file, one bibliography

Status: **standard, 2026-11-18** (owner request). Applies to all creature-stage lore (A22) and, later, to every stage's worlds.

## 1. Files

| File | Format | What it holds |
|---|---|---|
| `lore/planet.json` | JSON, schema `lore/schema/planet.schema.json` | The planet canon: numbered facts `F1…Fn`, each with value, unit, justification and references |
| `lore/creatures/<id>.json` | JSON, schema `lore/schema/creature.schema.json` | **One file per creature**: niche, body, causal chains, skills, weaknesses, observe steps, journal, relations, plausibility review, provenance, changelog |
| `lore/references.json` | **CSL-JSON** (the citation standard used by Zotero, Pandoc, Crossref) | Every reference, cited by `id` from the files above. Each entry adds `x-status`: `verified` (DOI or ISBN checked against Crossref/OpenLibrary), `unverified` (from a model's memory) or `rejected` (does not exist / wrong) |
| `docs/creatures/<id>.md` | Markdown, **generated** | A readable page per creature, rendered from its JSON. Never edited by hand |
| `lore/alltomorrows.en.json`, `lore/hailmary.en.json` | existing | Third-party lore files (A19, A20). Their references move into `lore/references.json` later |

JSON is the single source of truth (the game reads it: Observe reveals chains, the journal prints `journal` lines). Markdown is only a view.

## 2. Identifiers

- Creatures: lowercase ascii ids (`rondo`, `garfio`, `ecolumbre`). Display names in `name.es` / `name.en`.
- Planet facts: `F1…Fn`, never renumbered; a retired fact keeps its id with `"status": "retired"`.
- Chains: `<creature>.c<N>` (`ecolumbre.c2`). Skills: `<creature>.<skill_slug>`.
- References: CSL `id` = `author_year_shortword` (`lloyd_1965_photuris`).

## 3. A causal chain (the unit of lore, A22)

`trait ← links… ← roots (F-ids) → skill + weakness`, plus what the player must observe to reveal it, and a plausibility review:

```json
{
  "id": "ecolumbre.c2",
  "trait": "talks with light",
  "links": ["vocal calls would mask its own and the flock's echolocation", "long echoes in lava tubes"],
  "roots": ["F4", "F11"],
  "skill": {"id": "ecolumbre.flash_code", "name": {"en": "Flash code", "es": "Código de luz"}, "role": "Social",
            "effect": "befriend by copying its light pattern; needs a glow part", "numbers": {"range_m": 25}},
  "weakness": "goes dark and freezes when a sight hunter is near; a fake lure at the cave mouth draws it out",
  "observe": ["see a flock flash in a deep tube", "hear the clicks stop when it flashes", "see it go dark under the moon"],
  "journal": {"en": "It sings with its skin.", "es": "Canta con la piel."},
  "plausibility": {"verdict": "fixable", "judge": "astrobio/composer-2.5", "date": "2026-11-18",
                   "summary": "only as a conditional, refuge-bound, ventral, brief signal",
                   "analogues": [{"organism": "Photinus / Photuris fireflies", "mechanism": "species-specific flash codes, femme-fatale mimicry",
                                  "refs": ["lloyd_1965_photuris", "lewis_2008_fireflies"]}],
                   "fixes": ["ventral photophores, sub-second bursts", "moon-phase and depth gating"]},
  "provenance": {"council_run": "got-2026-11-18", "by": ["senses/glm", "naturalist/qwen"], "edited_by": "opus"}
}
```

## 4. Rules

1. **No chain without roots.** Every chain cites at least one planet fact. Every fact cites a justification (and references where it is real physics).
2. **No reference without a status.** Model-provided citations enter as `unverified`; a tool checks them against Crossref / OpenLibrary and flips them to `verified` (with DOI/ISBN) or `rejected`. Docs show the status next to each citation.
3. **Never invent a reference.** A rejected reference is removed from the chain and the claim is re-reviewed.
4. **Provenance is kept**: which council voice/model proposed it, which judge reviewed it, who edited it, and a `changelog` per file.
5. **Status per creature**: `draft` (council output) → `reviewed` (judges passed) → `canon` (owner approved). Only `canon` ships.
6. **Validation in CI**: `make lore-check` validates every file against its schema, checks that every `roots` id exists in `planet.json`, every reference id exists in `references.json`, every relation points to an existing creature, and renders `docs/creatures/`.
