# Brief: flora pass 3 — botanical branching, snow rosettes, the nest

Worktree `/home/diego/Desarrollo/cpore-wt/art-flora3`, branch `art/flora-pass3` (from main). Work only here. **No commits, no screenshots**
(sandbox): leave work uncommitted, write `docs/FLORA-ART3-REPORT.md` (intended commits, changes, per-tier triangle/batch numbers,
capture checklist for Sonnet). Never touch `.codex/`, `.kimi-code/`, other worktrees, the main checkout, `core/` or C goldens.

Read `docs/FLORA-ART2-REPORT.md` ("still weak") and the evidence JPGs in `docs/evidence/godot/flora/` (incl. compare_*.jpg), `lore/flora/*.json`.
Fix the remaining weaknesses: (1) branches are straight rods with hard forks → curved, tapering limbs (bezier/space-colonisation, branch
collars, gravitropic droop per species, smooth joins), still deterministic and within the low-tier budget; (2) Snowshield (rodela_de_nieve)
snow rosettes are flat pastel and faceted → a giant rosette with a woody stem column, dense leaf skirt of dead leaves, a silver-hairy living
rosette (lore: UV 1.4×, frost), smooth shading; (3) the nest is a smooth brown blob with sparse straw → a woven bowl of Paja dulce straw,
twigs and down, with visible strand structure and a scraped hollow, a landmark at chase distance; (4) crusts/moss get subtle relief (normal
detail/parallax-lite in the ground-cover shader). Keep gl_compatibility working; update flora tests for new parameters; run `--check-only`
and `godot-test`, `godot-ui-test`.
