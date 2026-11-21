# Resources inventory

Every tool, repo, skill and reference the owner has shared, with a verdict and how it fits Primigenia. Assessed 2026-11-20/21. The tracker (https://claude.ai/artifact/AVN2K7HLTX7c8fzZPgAvuR, "Tools inventory" tab) mirrors this table; ids match. **Verdicts:** use = adopt now; trial = small test first; later = when that work starts; skip = does not fit (reason given).

Project skills that turn the "use" and "trial" items into procedures: `.claude/skills/cpore-motion`, `.claude/skills/cpore-assets`, `.claude/skills/cpore-media`.

## Installed and in use
| Id | Resource | Status | Where |
|---|---|---|---|
| G1 | game-design skill (MCP Market, https://app.mcpmarket.com/dratencia/skills/game-design) | use; connected via the MCP Market connector (`mcp__claude_ai_MCP_Market_Hub__skill_game_design`). Adoption as the brief template = decision D-19 | 5-part filter: Clarity, Motivation, Response, Satisfaction, Fit; numbers must cite a source or be a starting value with a test |
| G2 | Godot / art skills: godot-shaders, godot-3d-essentials, game-feel, create-game-assets (gamedev-skills, Apache-2.0); godot-particles, godot-3d-lighting, godot-3d-materials (gd-agentic-skills, LGPL-3.0); godot (haxqer, MIT); texture-workflow, procedural-modeling (arjun988/blender-skills, MIT) | installed 2026-11-20 in `~/.claude/skills/` (user level; provenance in `~/.claude/skills/.game-skills-provenance.txt`). godot-agent-vision skipped: it captures the host screen | |
| V2 | FFmpeg (https://github.com/FFmpeg/FFmpeg) | use; installed (`/usr/bin/ffmpeg`) | frame sheets, side-by-side clips: `cpore-media` skill |
| — | Blender MCP bridge (in repo) | in use for assets | `tools/blender-mcp/`, `docs/BLENDER_MCP.md`, `make blender` |

## Design / UI repos (pasted list 1)
| Id | Repo | Verdict | Why |
|---|---|---|---|
| U1 | shadcn/ui https://github.com/shadcn-ui/ui · Tailwind CSS https://github.com/tailwindlabs/tailwindcss · Magic UI https://github.com/magicuidesign/magicui | skip | Our UI is Godot, not a web app |
| U2 | Lucide https://github.com/lucide-icons/lucide | use (not installed) | Consistent SVG glyphs for HUD, radial menu, creator; ISC licence. Import SVGs into Godot as textures |
| U3 | Adobe Leonardo https://github.com/adobe/leonardo | use (not installed) | Palettes from a target contrast ratio: fixes low-contrast cell tabs (phases 5–6), legible ES/EN text |
| U4 | ui-ux-pro-max https://github.com/nextlevelbuilder/ui-ux-pro-max-skill · theme-factory https://github.com/anthropics/skills/tree/main/skills/theme-factory · stitch-skills https://github.com/google-labs-code/stitch-skills · Astryx https://github.com/meta/astryx | skip | Web looks; Emil skills already set our motion rules |
| — | frontend-design https://github.com/anthropics/skills/tree/main/skills/frontend-design | already available as a user skill | For web pages (tracker, studio), not the Godot HUD |
| U5 | DESIGN.md spec https://github.com/google-labs-code/design.md | later | Becomes `docs/UI-STYLE.md` once the HUD style settles |
| U6 | Figma Context MCP https://github.com/GLips/Figma-Context-MCP · tldraw https://github.com/tldraw/tldraw | skip | No Figma in the workflow; whiteboards available as artifacts |
| U7 | Excalidraw https://github.com/excalidraw/excalidraw | later | Menu/HUD wireframes before building |
| U8 | rembg https://github.com/danielgatis/rembg | use (not installed; ask before `pip install rembg`) | Local background removal for concept/UI art cutouts |

## Video / audio repos (pasted list 2)
| Id | Repo | Verdict | Why |
|---|---|---|---|
| V1 | SAM 2 https://github.com/facebookresearch/sam2 | trial | Track real animals (and the reference clips) to measure gait timing and keypoints: research step R1. Needs a GPU model; run only with owner OK (GPU is the owner's) or CPU on short clips |
| V2 | FFmpeg | use | see above |
| V3 | Demucs https://github.com/adefossez/demucs · DeepFilterNet https://github.com/Rikorose/DeepFilterNet | later | Only if we record real sounds for the audio pass |
| V4 | Real-ESRGAN https://github.com/xinntao/Real-ESRGAN | later | Texture upscaling if needed |
| V5 | RobustVideoMatting https://github.com/PeterL1n/RobustVideoMatting · ProPainter https://github.com/sczhou/ProPainter · video-subtitle-remover https://github.com/YaoFANGUK/video-subtitle-remover · LatentSync https://github.com/bytedance/LatentSync · faster-whisper https://github.com/SYSTRAN/faster-whisper · WhisperX https://github.com/m-bain/whisperX · AutoSubs https://github.com/tmoroney/auto-subs · FunClip https://github.com/modelscope/FunClip · LosslessCut https://github.com/mifi/lossless-cut | skip (for now) | Trailer and devlog editing, not the game. LosslessCut is the pick for quick trims when trailers start |

## 3D / rig / motion repos (pasted list 3)
| Id | Repo | Verdict | Why |
|---|---|---|---|
| A1 | Agent-driven Blender: Blender MCP https://github.com/ahujasid/mcp-for-blender (we have our own bridge), the keno / Yokohara / rewind workflows (article, see below) | trial, props only (D-20) | Rocks, fossils, nest, cave dressing. Not creatures: ours are generated and rigged at runtime from the genome |
| A2 | texture-workflow, procedural-modeling skills | trial | Pair with A1 |
| A3 | AnyMachine https://github.com/apekshik/anymachine | skip | Machines rigged in Blender; our creatures are rigged at runtime. Worth reading for its script-driven rig ideas |
| A4 | UniRig https://github.com/VAST-AI-Research/UniRig · Puppeteer https://github.com/Seed3D/Puppeteer · Make-It-Animatable https://github.com/jasongzy/Make-It-Animatable · Mesh2Motion https://github.com/Mesh2Motion/mesh2motion-app | skip | Rig fixed meshes; ours are procedural |
| A5 | FreeMoCap https://github.com/freemocap/freemocap · MediaPipe https://github.com/google-ai-edge/mediapipe · Kalidokit https://github.com/yeemachine/kalidokit · GVHMR https://github.com/zju3dv/GVHMR · 4D-Humans https://github.com/shubham-goel/4D-Humans | skip | Human skeletons only. For animals use SAM 2 + SuperAnimal (DeepLabCut), see `docs/research/procedural-locomotion.md` |
| A6 | HY-Motion https://github.com/Tencent-Hunyuan/HY-Motion-1.0 · MDM https://github.com/GuyTevet/motion-diffusion-model · MoMask https://github.com/EricGuo5513/momask-codes | skip | Human (SMPL) text-to-motion, offline; no arbitrary bodies |
| A7 | three-vrm https://github.com/pixiv/three-vrm | skip | Web avatars, not our engine |

## Other
| Id | Resource | Verdict | Why |
|---|---|---|---|
| X1 | "Floating Island" three.js one-shot prompt | skip | A model-comparison benchmark, not a tool. Full text kept in `docs/research/floating-island-prompt.md` to compare agent models on a fixed task |
| X2 | "UI Moments" video, 36 loading animations | later | Pick one or two for the loading screen / creator "thinking" state; Emil rules. Local copy: `~/Desarrollo/cpore-refs/videos/ui-moments-loading-36.mp4` |
| X3 | Spore gorilla knuckle-walk video | use: main motion reference | Head level, shoulders above hips, knuckle-walk on long arms, torso rolls with each hand plant. Local copy: `~/Desarrollo/cpore-refs/videos/spore-gorilla-knucklewalk.mp4` (never commit) |
| X4 | Second twimg video from the Blender article (`lmv4sHs8MDBAgsS5.mp4`) | not downloaded | Download to `~/Desarrollo/cpore-refs/videos/` to assess |
| X5 | Andy Weir's world-building method (owner's research notes, 2026-11-21): Physics Today "Science inspires, but does not limit"; Scientific American podcast "The real science behind Project Hail Mary"; Huge Conversations (Cleo Abram) transcript; Film Threat; IFLScience; Planetary Radio Book Club | use: lore method | Derive forward from a few fixed constraints, biosphere before characters, auditable numbers in a spreadsheet, at most one physics violation, internal coherence over source data. Written as `lore/rules/derivation.md`. Medium confidence on the exact Erid figures (from summaries) |

## The agent-driven Blender article (summary)
Source: owner paste 2026-11-20 (keno "GPT Dot" builds itself and a Tesla Roadster scene in Blender; Hirokazu Yokohara's AI-only Blender test; rewind's Claude + Blender + Unreal + Meshy game pipeline, "every tool one job").
- Three routes: an agent operates Blender (editable scenes); a model is generated elsewhere (Meshy etc.) then refined; AI assists a person.
- Decide the deliverable first (still, video, game asset, print): it changes the brief. For us it is always **a game asset loaded in Godot**.
- Workflow with checkpoints: **brief → rough shapes → preview → correction → detail → final test → delivery.** Name failures precisely instead of "make it better"; keep approved camera/lighting while changing one part.
- **Five checks before an asset is usable:** turn it around; inspect the parts (separately selectable/renamable); test the actual output (load it in the game); reopen the delivered project from its files alone; estimate the final cost (render time / runtime cost).
- Procedure for us: `.claude/skills/cpore-assets`.
