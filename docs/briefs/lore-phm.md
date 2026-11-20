# Task: Project Hail Mary lore file (data + doc only, no code)
Worktree /home/diego/Desarrollo/cpore-wt/lore-phm, branch lore-phm. Read docs/ARC-PLAN.md §5.3, §5.3b and §5.3c first, and use
lore/ + docs/LORE-ALLTOMORROWS.md (on main; see `git show claude/v0.1-restore:docs/LORE-ALLTOMORROWS.md`) as the format model.
Research Andy Weir's *Project Hail Mary* (2021 novel; the 2026 film only for naming differences). Write:
1. `lore/hailmary.en.json`: entries for Astrophage (biology, energy storage, breeding, the Petrova line, the star-dimming effect),
   Taumoeba (and the nitrogen-tolerant strain), Adrian, Erid, the Eridians (body, senses, language of chords, society, xenonite, the
   radiation blind spot, ammonia/pressure/temperature), the Hail Mary ship and the spin drive, the Blip-A, and anything else with a
   game hook. Fields: id, name, kind, description (2–4 lines, in your own words, no quotes longer than a few words), facts (numbers
   where the book gives them: gravity, pressure, temperatures, energy density), source, confidence (book|film|wiki), game_hook
   (ARC-PLAN §5.3c).
2. `docs/LORE-HAILMARY.md`: readable table + how Astrophage could work as a resource and a crisis with simple numbers (fuel per kg,
   dimming rate per year, how long the cure expedition takes) + a short legal note (living author, 2026 film: names only in the lore file,
   no film likeness). Commit both. Touch nothing else, no installs, no pushes.
