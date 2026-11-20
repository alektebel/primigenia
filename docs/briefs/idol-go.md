# Task: Idol photo-to-3D pipeline (G74) — the owner explicitly approved this task's installs and GPU use
Read /home/diego/Desarrollo/cpore-wt/_agent/briefs/idol.md (the full task). Override of the generic rules for THIS task only, approved by the owner: you MAY create a Python venv at /home/diego/Desarrollo/cpore-wt/_agent/idol-venv, pip-install PyTorch (CUDA build for the RTX 5060) and Idol's requirements into it, download the Idol weights into /home/diego/Desarrollo/cpore-wt/_agent/models/, and run Idol on the GPU. Still: nothing system-wide, nothing into the repo except code, glTF outputs, credits and evidence. The game is now Godot 4 desktop (docs/DESIGN.md G76): output .glb that Godot imports (props in toon style, creature parts with the material regions skin/keratin/eye/membrane), and add a small Godot import check if godot (~/.local/bin/godot) can load them headless.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Godot screenshots: xvfb-run -a with LIBGL_ALWAYS_SOFTWARE=1 and --rendering-driver opengl3 (software, no GPU, no windows on the desktop).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
