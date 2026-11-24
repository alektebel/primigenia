# Task: progress report of every running agent task (read-only, no code changes)
You are working in /home/diego/Desarrollo/cpore-wt/_agent (do not modify any worktree). For each task below:
- brief: /home/diego/Desarrollo/cpore-wt/_agent/briefs/<brief>.md (and any <brief>-r2/-cont/-fix variant)
- worktree: /home/diego/Desarrollo/cpore-wt/<task> (read `git -C <worktree> log --oneline claude/v0.1-restore..HEAD`, `git -C <worktree> status --short`, and the evidence files the brief asks for)
- agent log: /home/diego/Desarrollo/cpore-wt/_agent/{oc,cur,codex}-<task>*.log (last lines only)

Tasks: w11-alpine (brief w11-alpine), art-nest, art-food, art-remains, art-species, art-meteor, art-underwater (brief art-underwater-r2), m-e2e, m-ecology, m-garfio.

Method: list every acceptance item the brief asks for (each deliverable file, each check, each required number of iterations, each test). For each item decide DONE / PARTIAL / MISSING strictly from evidence in the worktree (a file that exists and matches what was asked, a commit, a test result written in the log). Completion % = (DONE + 0.5·PARTIAL) / total items. Never guess: if you cannot verify, count it MISSING.
Write /home/diego/Desarrollo/cpore-wt/_agent/STATUS.md: one table (task, model, % complete, items done/total, running or stopped, last commit time, the next missing item), then per task the item list with the evidence path for each DONE. Keep it factual and short.
