// render_sheet.js — create composite sheet.png with all variants
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const out = process.argv[2] || '/home/diego/Desarrollo/cpore-wt/art-remains/docs/evidence/props/remains/sheet.png';

  const browser = await chromium.launch({
    executablePath: '/home/diego/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox', '--disable-gpu'],
  });

  const context = await browser.newContext({ viewport: { width: 2560, height: 1440 } });
  const page = await context.newPage();

  var remainsSrc = fs.readFileSync(path.join(__dirname, 'remains.js'), 'utf8');
  remainsSrc = remainsSrc.replace(/export\s+function\s+/g, 'function ');

  const html = `
<!DOCTYPE html>
<html>
<head><style>body{margin:0;overflow:hidden;background:#1a1a20;font-family:system-ui}</style></head>
<body>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"><\/script>
<script>${remainsSrc}</script>
<script>
(function() {
  var T = THREE;

  // === Sheet layout ===
  var W = 2560, H = 1440;

  /* Each panel: {x,y,w,h, camera, label, buildFn} */
  var panels = [];

  /* 1. Wide shot: all props */
  panels.push({ x:0, y:0, w:W, h:H*0.55, camPos:[12,6,14], camTarget:[1.5,0.2,0.5], label:'ALL VARIANTS (close to far)' });

  /* 2-5. Close-ups of each variant */
  panels.push({ x:W*0.05, y:H*0.62, w:W*0.44, h:H*0.35, camPos:[-2,1.2,2.5], camTarget:[-2,0.3,0], label:'FRESH CARCASS (close)' });
  panels.push({ x:W*0.52, y:H*0.62, w:W*0.44, h:H*0.35, camPos:[1,1,3.5], camTarget:[1,0.3,0], label:'PICKED CARCASS (close)' });
  panels.push({ x:W*0.52, y:H*0.32, w:W*0.2, h:H*0.27, camPos:[-2,1,3], camTarget:[-2,0.2,3], label:'SKULL (meadow)' });
  panels.push({ x:W*0.74, y:H*0.32, w:W*0.2, h:H*0.27, camPos:[1,0.8,2.5], camTarget:[1,0.2,3], label:'RIBCAGE (alpine)' });
  panels.push({ x:W*0.05, y:H*0.32, w:W*0.2, h:H*0.27, camPos:[4,1,3], camTarget:[4,0.2,3], label:'SPINE (beach)' });

  // Create multiple renderers, one per panel
  var canvases = [];
  var renderers = [];
  var scenes = [];
  var cameras = [];

  function countT(obj) {
    var ct = 0;
    obj.traverse(function(c){if(c.isMesh&&c.geometry){var g=c.geometry;if(g.index)ct+=g.index.count/3;else ct+=g.attributes.position.count/3}});
    return ct;
  }

  panels.forEach(function(panel, pi) {
    var canvas = document.createElement('canvas');
    canvas.width = panel.w;
    canvas.height = panel.h;
    canvas.style.position = 'absolute';
    canvas.style.left = panel.x + 'px';
    canvas.style.top = panel.y + 'px';
    canvas.style.width = panel.w + 'px';
    canvas.style.height = panel.h + 'px';
    canvas.style.borderRadius = '8px';
    document.body.appendChild(canvas);
    canvases.push(canvas);

    var scene = new T.Scene();
    scene.background = new T.Color(0x87a5c0);
    scene.fog = new T.Fog(0xc0c8c0, 20, 80);
    scenes.push(scene);

    var camera = new T.PerspectiveCamera(panel.w > 400 ? 45 : 50, panel.w / panel.h, 0.3, 500);
    camera.position.set.apply(camera, panel.camPos);
    camera.lookAt.apply(camera, panel.camTarget);
    cameras.push(camera);

    var renderer = new T.WebGLRenderer({ canvas: canvas, antialias: true, alpha: false });
    renderer.setSize(panel.w, panel.h);
    renderer.outputEncoding = T.sRGBEncoding;
    renderer.shadowMap.enabled = false;  // no shadows in panel mode (too slow with SwiftShader)
    renderer.toneMapping = T.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.1;
    renderers.push(renderer);

    // Lighting (shared across scenes)
    scene.add(new T.AmbientLight(0xffffff, 0.6));
    var sun = new T.DirectionalLight(0xffd6a0, 3.5);
    sun.position.set(-8, 5, -6);
    scene.add(sun);
    scene.add(new T.HemisphereLight(0xa8ccf8, 0x6a6a5c, 0.5));

    // Ground
    var gt = new T.DataTexture(new Uint8Array([46,46,82,82,112,112]),6,1,T.LuminanceFormat);
    gt.minFilter = gt.magFilter = T.NearestFilter; gt.needsUpdate = true;
    var gm = new T.MeshToonMaterial({ gradientMap: gt, color: new T.Color(0.185,0.335,0.075) });
    var gg = new T.PlaneGeometry(80,80); gg.rotateX(-Math.PI/2);
    var gnd = new T.Mesh(gg, gm); gnd.position.y = -0.02; scene.add(gnd);

    // Rocks
    var rm = new T.MeshToonMaterial({ gradientMap: gt, color: new T.Color(0.28,0.215,0.14) });
    for(var i=0;i<10;i++){
      var s=0.06+Math.random()*0.2;
      var g2=new T.Mesh(new T.IcosahedronGeometry(s,0),rm);
      g2.position.set((Math.random()-0.5)*20,-s*0.2,(Math.random()-0.5)*20);
      scene.add(g2);
    }

    // Build carcasses
    var cg = buildAllCarcasses(T, 42);
    cg.position.set(-2, 0, 0);
    panels[1] && (cg.position.x = -2);
    scene.add(cg);

    // Build fossils
    var fg = buildAllFossils(T, 137);
    fg.children.forEach(function(bg,i){bg.position.set(2+i*2.5,0,0)});
    scene.add(fg);

    // Render
    renderer.render(scene, camera);
  });

  // Label overlay on panels
  panels.forEach(function(panel, i) {
    var ctx = canvases[i].getContext('2d');
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.font = 'bold 18px system-ui, sans-serif';
    ctx.fillText(panel.label, 16, 32);
  });

  // Composite to a single canvas
  var composite = document.createElement('canvas');
  composite.width = W;
  composite.height = H;
  var ctx = composite.getContext('2d');
  ctx.fillStyle = '#1a1a20';
  ctx.fillRect(0, 0, W, H);

  // Draw all panels
  panels.forEach(function(panel, i) {
    ctx.drawImage(canvases[i], panel.x, panel.y, panel.w, panel.h);
  });

  // Title bar at top
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  ctx.fillRect(0, 0, W, 60);
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 22px system-ui, sans-serif';
  ctx.fillText('Carcasses & Fossils — G3, G4', 20, 38);
  ctx.fillStyle = '#aaa';
  ctx.font = '14px system-ui, sans-serif';
  ctx.fillText('Primigenia (cpore) · Three.js r128 · SwiftShader · G63 palette C', 20, 55);

  // Save as PNG
  window.__sheet = composite.toDataURL('image/png');
})();
<\/script>
</body></html>
  `;

  await page.setContent(html);
  await new Promise(r => setTimeout(r, 6000));

  const sheetData = await page.evaluate(() => window.__sheet);
  if (sheetData) {
    const base64 = sheetData.replace(/^data:image\/png;base64,/, '');
    const buf = Buffer.from(base64, 'base64');
    fs.writeFileSync(out, buf);
    console.log('Sheet saved to', out);
  } else {
    console.error('No sheet data');
    await page.screenshot({ path: out, fullPage: true });
    console.log('Fallback saved to', out);
  }

  await browser.close();
  console.log('Done.');
})().catch(e => { console.error(e); process.exit(1); });