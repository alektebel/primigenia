---
name: cpore-assets
description: Making art assets for Primigenia (cpore) — props via agent-driven Blender with checkpoints and the five checks, icons (Lucide), palettes (Leonardo), cutouts (rembg), licence records. Use when creating or importing props, textures, icons, palettes or concept-art cutouts. Not for creatures (they are generated from the genome at runtime).
---

# Art assets (cpore)

## What this covers and what it does not
- Props and set dressing: rocks, fossils, nest pieces, cave dressing, meteor shards. Decision D-20 (trial) in the tracker.
- **Not creatures.** Creature bodies are generated and rigged at runtime from the genome; never replace them with Blender models.
- Pair with user skills: `create-game-assets` (style guide, QA, licence records), `procedural-modeling`, `texture-workflow`, `godot-3d-materials`, `godot-3d-lighting`.

## Agent-driven Blender (props)
Bridge already in the repo: `tools/blender-mcp/`, `docs/BLENDER_MCP.md`, `make blender` (scene state, Python, rendered previews, GLB export). Headless Blender Python also works for batch work. Software rendering only; never the owner's GPU.

Workflow with visible checkpoints (from the keno / Yokohara / rewind article, `docs/RESOURCES.md`):
**brief → rough shapes + camera → preview → correction → detail → final test in Godot → delivery.**
- Brief states the deliverable (a Godot game asset), size in metres, which parts stay separate, poly/texture budget per quality tier, and references.
- Show rough proportions first; only then materials and detail.
- Corrections name the failure ("base 30% too wide; keep camera and light"), never "make it better".

Five checks before an asset counts as usable (write the result for each in the evidence note):
1. **Turn it around** — silhouette and surfaces from 4+ angles, including below if visible in game.
2. **Inspect the parts** — named, separately selectable/movable/recolourable pieces where the brief asked.
3. **Test the real output** — import the GLB into Godot, view it in the island at game camera distance and on low/medium/high tiers.
4. **Reopen from files alone** — the .blend/GLB opens with only the committed textures and instructions.
5. **Estimate the cost** — triangle count, texture memory, draw calls; fits the tier budget.

## Small tools
- **Lucide** icons (ISC): download SVGs from https://github.com/lucide-icons/lucide, import into Godot as textures; keep one stroke width across the HUD.
- **Adobe Leonardo** palettes: generate colours from a target contrast ratio (≥4.5:1 for text, ≥3:1 for UI glyphs); use for low-contrast tabs and ES/EN text.
- **rembg** background removal (not installed; ask the owner before `pip install rembg`): `rembg i in.png out.png` for concept-art and UI cutouts. Check for fake transparency afterwards.

## Rules
- Record source and licence of every external asset (create-game-assets licence record).
- Never edit `art/reference/` (owner's originals). Never commit Spore captures or other copyrighted references.
- Evidence as JPG in `docs/evidence/<area>/`.
