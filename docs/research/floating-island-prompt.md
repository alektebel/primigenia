# "Floating Island" one-shot benchmark prompt

Shared by the owner 2026-11-20 (used online to compare models; "same prompt for all 3, no edits"). Kept to compare agent models on a fixed task if needed (tracker X1).

```text
Build a single-file interactive 3D web app: "Floating Island" — a stylized low-poly island floating in the sky.

Tech: one file, index.html. Use three.js r170 only, loaded with this exact importmap:
{"imports":{"three":"https://unpkg.com/three@0.170.0/build/three.module.js","three/addons/":"https://unpkg.com/three@0.170.0/examples/jsm/"}}
No other libraries, no external assets: every model, texture and sound is generated in code.
The island:
- Low-poly floating island with grass top, layered rock underside and hanging roots
- A waterfall that pours off the edge and dissolves into mist below
- A small cottage with a smoking chimney, a spinning windmill, trees that sway in the wind
- Clouds drifting past at different depths, birds circling
Controls (bottom bar, clearly labeled buttons):
- "Day / Night": smooth 3-second transition; at night windows glow, stars appear, fireflies come out
- "Weather": cycles Clear → Rain → Snow, with particles and matching sky color
- "Grow": plants a new tree at a random spot with a growing animation
- "Explode": the island splits into floating layers with labels, press again to reassemble
Keyboard shortcuts: D, W, G, E for the same four buttons.
Mouse: drag to orbit, scroll to zoom, gentle auto-rotate when idle.

Quality bar: soft shadows, fog, tone mapping, smooth 60fps, polished UI with a title card in the top-left. It should look like a finished indie game menu screen, not a demo.
Finish in one go. Do not ask me questions. When done, tell me the file is ready.
```
