@AGENTS.md

# Claude-specific

## Start of every session
1. Read `docs/STATUS.md`.
2. Read the tracker: `ArtifactData list` on collections `tests` and `decisions` of https://claude.ai/artifact/AVN2K7HLTX7c8fzZPgAvuR. Copy every newly decided row into `docs/DESIGN.md` (with date and tracker id) and set its `recorded_in`. A test marked Failed reopens its task.
3. Run `tools/agents/agents.sh status` and restart jobs the shutdown killed (`tools/agents/agents.sh restart <job>`), only the ones STATUS.md lists as running.
4. Tell the owner in a few lines: what changed since last session, what waits on them.

## End of every session ("wrap up")
1. Every running agent commits WIP to its branch.
2. Rewrite `docs/STATUS.md` (keep it one page: done, in flight, next, waiting on owner, next free ids).
3. Add new tests and decisions to the tracker.
4. Memory holds pointers only; history lives in git.

## Delegation
- Implementation: Agent tool with model `sonnet` (give it its worktree path), or Codex: `codex exec -m gpt-6.1-sol -s workspace-write --add-dir /home/diego/Desarrollo/cpore/.git "<brief>" < /dev/null` from the worktree.
- Hard planning: Agent model `opus`; Fable only when Opus is stuck.
- Keep at most 3 Claude implementation agents at once.
