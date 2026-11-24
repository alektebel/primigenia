# Brief: flora addendum — the start valley plants + a strict skeptical review + bilingual names (lore council)

Worktree `/home/diego/Desarrollo/cpore-wt/flora-valley`, branch `lore/flora-valley` (from main `claude/v0.1-restore`). Work only here.
Commit per step (end messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); do not merge. Never touch the main
checkout, other worktrees, `.codex/`, `.kimi-code/`.

Read: `tools/lore/council/flora.py` (the flora pass: qwen personas + DeepSeek/GLM voices, referee, sol as chair via
`codex exec --skip-git-repo-check -m gpt-6.1-sol -s read-only "<prompt>" < /dev/null`), `tools/lore/council/council.py` (sol_chat,
QWEN_CONC=5 semaphore), `tools/lore/README.md`, `docs/lore/FLORA.md`, `lore/flora/*.json`, `lore/creatures/*.json` (world primigenia),
the game: P4 gifts (fruit and plants are gift items; herbivores eat plants), `docs/DESIGN.md` G65, A24.

Owner decisions (2026-11-19): (1) add 3–4 plants for the start valley (east meadow): **a fruiting shrub** (herbivore food + gift item),
**a visible flower or herb**, **a mid-size tree for the valley edges**, and **a red-veined poison plant** as an early hazard — designed
from first principles with the same rigour and care ("con cariño") as the 16; (2) a **strict, skeptical second review** of ALL the flora
(the first referee rated every chain "plausible": too lenient) by a different model family (sol via codex, or DeepSeek if available),
which must find real weaknesses, rate each chain plausible / needs-fix / implausible, and the chair applies the fixes; (3) names are
bilingual like the creatures: Spanish name in the Spanish game, English in the English one (e.g. Nieblón / Fogcomber) — make sure every
plant has both, natural-sounding.

Steps: write a `flora_addendum.py` (or a mode of flora.py) reusing the council machinery; run it (NAN_API_KEY is in the env; never run in
parallel with another council process — check `pgrep -af council` first); validate (`make lore-check`), render docs/lore/FLORA.md and the
plant pages; write `docs/lore/FLORA-REVIEW.md` with the strict review verdicts and what changed. Mark all DRAFT for the owner.
Report: the new plants (table), the review stats before/after, every name pair, failures of free models.
