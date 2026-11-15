#!/usr/bin/env python3
"""Layer P3 play mode over the authoritative hero valley patch sequence."""
import contextlib
import importlib.util
import io
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('primigenia_hero', ROOT / 'tools/hero/build_hero.py')
hero = importlib.util.module_from_spec(spec)
# Import executes the existing patch sequence and byte-identical hero regeneration.
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(hero)
h = hero.h
h = hero.patch(h, '<head>', '<head>\n<link rel="icon" href="data:,">')
patch = hero.patch
h = patch(h, '<title>Primigenia hero shot</title>', '<title>Primigenia · The valley</title>')
h = patch(h, hero.CREATURE_MODULE, '')
h = patch(h, '<script>\n(()=>{\nconst T=THREE', '''<link rel="stylesheet" href="stage.css">
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script src="../studio/growth.js"></script>
<script src="../studio/genome.js"></script>
<script>window.__heroBuild=env=>window.__stageEnvironment=env;</script>
<script type="module" src="stage.js"></script>
<script>
(()=>{
const T=THREE''')
h = patch(h, 'vistaTrees:[...broad,...conif]', 'vistaTrees:[...broad,...conif],obstacles:[...broad.map(o=>({...o,r:o.s*.75})),...conif.map(o=>({...o,r:o.s*.6})),...rocks.map(o=>({...o,r:o.s}))]')
# Preserve the landscape and terrain code, bypass the reference game's simulation,
# camera, keyboard handlers and HUD. Stage owns the display and input clocks.
h = patch(h, 'function render(frameDt){\n', 'function render(frameDt){\n  if(window.__stageEnvironment){window.Stage?.frame(frameDt||0);return}\n')
h = patch(h, 'function drawHUD(){', 'function drawHUD(){if(window.__stageEnvironment)return;')
h = patch(h, 'function frame(t){requestAnimationFrame(frame);const dt=Math.min(.1,(t-last)/1000||0);last=t;', '''function frame(t){requestAnimationFrame(frame);const dt=Math.max(0,(t-last)/1000||0);last=t;''')
h = patch(h, 'setMode(location.hash===\'#benchmark\');requestAnimationFrame(frame);', "setMode(false);requestAnimationFrame(frame);")
# Stop the inherited reference input at its registration sites, without a second
# DOM input layer acting on hidden controls.
for event in ['keydown', 'keyup', 'pointerdown', 'pointermove', 'pointerup', 'wheel']:
    h = h.replace("addEventListener('"+event+"',", "addEventListener('reference-"+event+"',")
h = patch(h, '</body>', '''<div id="play-ui">
 <header id="play-header"><div><b>Primigenia</b><span>THE FIRST VALLEY</span></div><nav><a href="../studio/">Studio ↗</a><button id="pause" aria-label="Pause game">Pause</button></nav></header>
 <div id="enemy-hud" class="vitals" hidden><div><b>Wild Merodeador</b><span id="enemy-phase">Watching</span></div><meter id="enemy-hp" min="0" max="100" value="100" aria-label="Enemy health"></meter><meter id="enemy-stamina" min="0" max="100" value="100" aria-label="Enemy stamina"></meter></div>
 <div id="status" role="status" aria-live="polite">Opening the valley…</div>
 <div id="player-hud" class="vitals"><div><b id="creature-name">Your creature</b><span id="player-health">100</span></div><meter id="player-hp" min="0" max="100" value="100" aria-label="Your health"></meter><meter id="player-stamina" min="0" max="100" value="100" aria-label="Your stamina"></meter></div>
 <div id="actions" role="group" aria-label="Combat actions"></div>
 <p id="controls">WASD / arrows · Shift sprint · Drag to orbit<br>1–4 moves · Space guard · Q / E dodge · Run to the edge to flee</p>
 <div id="stick" aria-label="Movement stick"><i></i></div><button id="sprint" class="touch-button">Sprint</button>
 <div id="damage" aria-hidden="true"></div>
 <div id="fade"></div>
 <div id="pause-panel" hidden role="dialog" aria-modal="true" aria-labelledby="pause-title"><h1 id="pause-title">The valley can wait.</h1><p>Explore as your studio creature. Watch the wild creature’s windup, then choose your move.</p><button id="resume">Return to the valley</button><a href="../studio/">Open Studio ↗</a></div>
</div>
</body>''')
output = ROOT / 'web/stage/index.html'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(h, encoding='utf-8')
print(f'wrote {output.relative_to(ROOT)} ({len(h)} bytes)')
