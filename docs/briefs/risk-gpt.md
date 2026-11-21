# Task: second-opinion risk review of the Primigenia creature stage (report only, no code)

You are a senior game producer + technical director from a different team, asked for an INDEPENDENT second
opinion. Write ONE file, `docs/RISKS-CREATURE-GPT.md`, in this worktree, commit it, nothing else. Do not modify any
other file, do not run builds or Godot, do not install anything, do not push.

Step 1 (blind): read docs/CREATURE-ROADMAP.md, docs/DESIGN.md (skim G/W/A decisions), docs/BACKLOG.md, docs/DEVTOOLS.md,
docs/audit/AGENTPLAY.md, docs/godot/*.md (skim), docs/ARC-PLAN.md (skim; check whether the full-arc plan endangers the
creature stage), README.md, the Makefile, and `git log --oneline -200`. Write your OWN top-10 risks for the creature
stage (C0–C9) BEFORE opening docs/RISKS-CREATURE.md: for each one give likelihood, impact, an early warning sign, a
mitigation, and a kill/pivot criterion.

Step 2 (compare): now read docs/RISKS-CREATURE.md (the first review, by another model). Add a section
"Where I disagree with the first review": risks it over- or under-rates, mitigations that won't work and why, risks it
missed entirely, and a merged top-5 for "this week".

Context: one owner (design + playtests), Claude as orchestrator/reviewer, AI coding agents in parallel git worktrees
under usage limits, one laptop (RTX 5060 8 GB), Godot 4.7 + a deterministic C core via GDExtension, procedural art,
the C sim also serves an LLM benchmark. Be concrete and blunt; cite files and commits. Plain English, short sentences,
tables where they help. Max ~250 lines.
