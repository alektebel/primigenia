# Task: All Tomorrows lore catalogue (data + doc only, no code)

Worktree /home/diego/Desarrollo/cpore-wt/lore-at, branch lore-at. Read docs/ARC-PLAN.md §5.3 and §5.3b first.
The owner wants the species of C. M. Kosemen's *All Tomorrows* (2006, writing as Nemo Ramjet) in the game as the very
species (decision A19). Research the book (web search: the book's own text if freely available online, Wikipedia,
reviews, the author's interviews; fan wikis only to cross-check, and mark facts that only fan wikis give as
"unverified").

Write:
1. `lore/alltomorrows.en.json`: an array, chronological, one entry per species/group: id, name (exact), era/time
   (as given), origin (who made them / descended from), body plan (2–3 lines), environment, temperament/culture,
   fate, source(s), confidence (book|wiki|fan-unverified), and `game_hook` (one line, using ARC-PLAN §5.3b: which
   stage and mechanic could host it: creature egg, Band/Realm cousin, Industry, Space civilisation, Qu event,
   void-adapted mirror, rogue AI...). Include every named species you can verify (aim for all of them, 30+ if the
   book has them), the Qu, and the Amphicephali.
2. `docs/LORE-ALLTOMORROWS.md`: a readable table of the same plus 5 proposals for how the strongest species become
   gameplay (not just cameos), and a short legal note (copyrighted, living author; names and descriptions only in the
   lore file; no art copied).
Commit both. Do not modify any other file, do not install, do not push.
