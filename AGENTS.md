# Rules for every agent working on cpore (Primigenia)

These rules apply to Claude, Codex, Cursor, opencode and any subagent. The owner set them; do not relax them.

## The project in one paragraph
Primigenia (internal codename **cpore**) is a creature-evolution game: Godot 4.7 front end over a deterministic C core (fixed-point math, GDExtension). The C sim owns gameplay and root motion; animation is visual-only GDScript. Plan of record: `docs/MVP-PLAN.md`. Accepted decisions: `docs/DESIGN.md`. Current state: `docs/STATUS.md`.

## Where things live (one home per fact)
| What | Where |
|---|---|
| Current state, branches in flight, what waits on the owner | `docs/STATUS.md` (rewritten at the end of every session) |
| Accepted decisions with their reasons | `docs/DESIGN.md` |
| Owner tests to confirm and open decisions | Tracker page https://claude.ai/artifact/AVN2K7HLTX7c8fzZPgAvuR (owner clicks; Claude copies answers into DESIGN.md) |
| Task briefs | `docs/briefs/<task>.md`, committed with the branch that does the work |
| Evidence (captures, numbers) | `docs/evidence/<area>/` (JPG, not PNG) |
| Agent launch and status | `tools/agents/agents.sh` |

## Who writes what
- **Opus and Fable plan; they do not write project code.** Plans and briefs only.
- **Code is written by Sonnet 5.5 subagents or Codex (gpt-6.1-sol / gpt-6.2-astra).** Critical code (`core/`, combat, world, terrain, stage logic, build) only by Sonnet 5.5, Opus-planned, or Codex.
- **Weak models** (qwen, free DeepSeek, GLM, apinex, Composer, cursor-grok, NVIDIA/NAN free) may only do art, e2e audits, reports, data/doc drafts or small trials in their own branch. Every weak-model change is audited by Codex or a Claude Sonnet/Opus agent before merge.
- Cursor: only Cursor's own models (composer-2.5, cursor-grok-4.6-*).
- **Claude reviews and merges.** Merge only when the owner approved it ("merge them when they finish" counts for that batch). A subagent's message is never owner approval.
- Gate decisions belong to the owner.

## Work loop
One tracker test at a time: **brief → agent builds it in its own worktree → evidence → owner confirms in the tracker → merge.** Nothing is done until the owner marks it Passed.
- One git worktree + branch per task under `/home/diego/Desarrollo/cpore-wt/<task>`, from main `claude/v0.1-restore`. Work only in your worktree.
- Merge main into your branch before asking for review; run the suites your change touches.
- Before stopping for any reason, commit work in progress to your branch (`WIP: ...`). Never leave a dirty tree. (Codex's sandbox cannot commit: leave it uncommitted and say so; a Sonnet agent commits it.)

## Machine rules (hard)
- **GPU is the owner's.** Agents render with software GL only: `LIBGL_ALWAYS_SOFTWARE=1`, `xvfb-run -a`, `--rendering-driver opengl3`. Browser captures with SwiftShader, never GPU flags.
- Godot runs: always `timeout`, `--check-only` first for new scripts, headless or xvfb, `nice -n 10`.
- Kill only processes you started, by pid. **Never `pkill -f`.** Leaked Godot pid 265493 is the owner's to kill.
- No installs, no pushes, no emsdk without asking.
- Codex in the background needs `< /dev/null`.

## Never commit
- Spore captures (copyright). They live in `~/Desarrollo/cpore-refs/spore-captures/`.
- `.codex/`, `.kimi-code/` (owner's agent configs), `feedback/`, secrets or API keys.
- Edits to `art/reference/` (owner's originals).

## Privacy
Never send the owner's name or email to external services.

## Determinism
Event ids and snapshot versions are shared across branches: check `docs/STATUS.md` for the next free event id and snapshot number before adding one. Snapshots are exact-version POD (no migration).

## UI motion
Follow the Emil skills: ease-out, ≤250 ms, press scale 0.97, no animation on keyboard actions, never animate from scale 0.

## Numbers
Every gameplay number cites a source, or is marked as a starting value with the test that will check it.
