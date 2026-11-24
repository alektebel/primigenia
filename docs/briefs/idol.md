# Task: photo-to-3D pipeline with Idol (G74)
The owner approved installing PyTorch and the Idol model weights and using the local GPU (RTX 5060 Laptop, 8 GB) for this task only. Work in this worktree; put the Python environment in /home/diego/Desarrollo/cpore-wt/_agent/idol-venv (not in the repo); model weights in /home/diego/Desarrollo/cpore-wt/_agent/models/ (not in the repo). Idol: https://speridlabs.com/research/idol , weights/code on Hugging Face (Apache 2.0; check the official repo/instructions).
1. Install and run Idol on 3 test images; record VRAM and time per image.
2. Pipeline tools/idol/: image → Idol Gaussian splat → mesh (marching cubes on an opacity/density field, or a documented splat-to-mesh method) → decimate (≤ 4k triangles for props, ≤ 3k for creature parts) → texture or vertex colours → glTF (.glb) in two styles: toon (palette C, matching tools/hero) for props, and physical for creature body parts (regions skin/keratin/eye/membrane like web/studio GLB parts).
3. Sources: only images the owner provides or CC0/public-domain photos (Wikimedia Commons CC0, Openverse CC0); record source URL, author and licence for every image in assets/idol/CREDITS.md. Start with: 4 rocks/boulders, 2 tree trunks or stumps, 2 fossils or bones, and 4 animal body parts (a beak, a claw, a horn, a shell/plate) as candidates for G48-style studio parts.
4. Evidence: docs/evidence/idol/sheet.png (input photo | splat render | final mesh in-game style) and README.md with the honest quality verdict per asset and the limits (single objects only).
Run renders with SwiftShader for evidence; Idol itself may use the GPU. Do not touch web/studio, web/stage or core in this task (integration is later and must be reviewed).
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
