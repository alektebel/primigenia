# Task: risk register for the Primigenia creature stage (report only, no code)

You are a senior game producer + technical director doing a pre-mortem. Write ONE file:
`docs/RISKS-CREATURE.md` in this worktree, commit it, nothing else. Do NOT modify any other file, do not
run builds or Godot, do not install anything, do not push.

Scope: ONLY the creature stage, from today to "done" as defined in `docs/CREATURE-ROADMAP.md` (phases C0–C9).
Read first: docs/CREATURE-ROADMAP.md, docs/DESIGN.md (all G/W/A decisions; skim), docs/BACKLOG.md,
docs/P4.md (headings), docs/DEVTOOLS.md, docs/godot/*.md (skim: M0, CREATURE, LOCOMOTION, FEEL, PLAN-* risks
sections), docs/ART_GAPS.md, docs/CALIBRATION.md (skim), README.md, the Makefile targets, and `git log --oneline -150`
to see what actually happened (rework, reverts, stalled agents, merges that failed review).

Context on how the project is built: one owner (game design, playtests) + Claude as orchestrator/reviewer + AI
coding agents (Claude Opus/Sonnet subagents, Codex, Cursor models, free models like qwen3.6 for audits/art) working in
parallel git worktrees; usage limits on each subscription; one laptop (RTX 5060 8 GB, 30 GB RAM); Godot 4.7 + a
deterministic C core via GDExtension; procedural art; the C sim also serves an LLM/RL benchmark.

Cover at least these categories, and find others yourself:
- Fun / design (the core loop may not be fun; depth vs readability; discovery pacing G71; ally vs dominate balance; 6–10 h of content)
- Scope creep (the full-arc ideas leaking into the creature stage; 8 deep secrets; media: water, air, digging)
- Technical (determinism across features; GDExtension/C coupling; performance with many creatures, grass, terrain; procedural animation G73/G77 quality; saves/snapshots breaking; Godot version upgrades)
- Art & audio quality (procedural art ceiling, weak-model art failures already seen, consistency with the toon/physical look)
- Process with AI agents (parallel branches conflicting, review bottleneck on Claude, agents reporting success falsely, usage limits stalling work, lost work on reboot, plans going stale, weak models touching critical code)
- Owner bandwidth (playtest fatigue, decision backlog, feedback loop latency)
- Benchmark coupling (game changes breaking benchmark goldens/fairness; LLM harness cost)
- Legal / release (trademark "Primigenia", Spore similarity, third-party assets/licences CC0, AI-generated content policies on stores, model weights licences e.g. Idol)
- Platform & release (desktop exports on Windows/macOS, GPU variety incl. AMD iGPU default, crash reporting, localisation es/en)
- Hardware / single point of failure (one laptop, no remote backup?, worktree sprawl)

Format:
1. A short summary: the top 10 risks in one table (ID, risk, likelihood H/M/L, impact H/M/L, phase where it bites, owner of the mitigation: owner / Claude / agents).
2. The full register grouped by category: for each risk — description, concrete evidence from this repo/git history if any, early warning signs, mitigation (preventive), contingency (if it happens), and a cheap check/metric to watch it.
3. "Kill criteria": signals that should make the owner stop, cut or rescope (e.g. MVP not fun after N iterations).
4. Ten concrete actions to take this week, ranked.
Be specific to THIS project (cite files, decisions, commits), not generic. Plain English, tables welcome, ≤ 450 lines.
End your run with a ≤10-line summary printed to stdout.
