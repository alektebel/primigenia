// render_sheet2.js — create composite sheet using multiple pages
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const out = process.argv[2] || '/home/diego/Desarrollo/cpore-wt/art-remains/docs/evidence/props/remains/sheet.png';

  const browser = await chromium.launch({
    executablePath: '/home/diego/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox', '--disable-gpu'],
  });

  var remainsSrc = fs.readFileSync(path.join(__dirname, 'remains.js'), 'utf8');
  remainsSrc = remainsSrc.replace(/export\s+function\s+/g, 'function ');

  /* Helper: render a single scene to a base64 PNG */
  async function renderScene(config) {
    const page = await browser.newPage({ viewport: { width: config.w || 2000, height: config.h || 1200 } });

    const html = `
<!DOCTYPE html>
<html>
<head><style>body{margin:0;overflow:hidden;background:#1a1a20}</style></head>
<body>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"><\/script>
<script>${remainsSrc}</script>
<script>
(function() {
  var T = THREE;
  var scene = new T.Scene();
  scene.background = new T.Color('${config.bg || '#87a5c0'}');
  scene.fog = new T.Fog('${config.bgColor || '#c0c8c0'}', ${config.fogNear || 20}, ${config.fogFar || 100});

  var camera = new T.PerspectiveCamera(${config.fov || 50}, ${config.w} / ${config.h}, 0.3, 500);
  camera.position.set(${config.camX || 5}, ${config.camY || 3}, ${config.camZ || 5});
  camera.lookAt(${config.targetX || 0}, ${config.targetY || 0.3}, ${config.targetZ || 0});

  var renderer = new T.WebGLRenderer({ antialias: true });
  renderer.setSize(${config.w}, ${config.h});
  renderer.outputEncoding = T.sRGBEncoding;
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = ${config.exposure || 1.1};
  document.body.appendChild(renderer.domElement);

  // Lights
  scene.add(new T.AmbientLight(0xffffff, ${config.ambient || 0.5}));
  var sun = new T.DirectionalLight(0xffd6a0, ${config.sunI || 3.5});
  sun.position.set(${config.sunX || -8}, ${config.sunY || 5}, ${config.sunZ || -6});
  scene.add(sun);
  scene.add(new T.HemisphereLight(0xa8ccf8, 0x6a6a5c, 0.5));

  // Ground
  var gt = new T.DataTexture(new Uint8Array([46,46,82,82,112,112]),6,1,T.LuminanceFormat);
  gt.minFilter = gt.magFilter = T.NearestFilter; gt.needsUpdate = true;
  var gm = new T.MeshToonMaterial({ gradientMap: gt, color: new T.Color(${config.groundColor || '0.185,0.335,0.075'}) });
  var gg = new T.PlaneGeometry(80,80); gg.rotateX(-Math.PI/2);
  var gnd = new T.Mesh(gg, gm); gnd.position.y = -0.02; scene.add(gnd);

  // Rocks
  var rm = new T.MeshToonMaterial({ gradientMap: gt, color: new T.Color(0.28,0.215,0.14) });
  for(var i=0;i<8;i++){
    var s=0.06+Math.random()*0.2;
    var g2=new T.Mesh(new T.IcosahedronGeometry(s,0),rm);
    g2.position.set((Math.random()-0.5)*15,-s*0.2,(Math.random()-0.5)*15);
    scene.add(g2);
  }

  // Build all props
  var cg = buildAllCarcasses(T, ${config.carcassSeed || 42});
  cg.position.set(${config.carcassX || -2}, ${config.carcassY || 0}, ${config.carcassZ || 0});
  scene.add(cg);

  var fg = buildAllFossils(T, ${config.fossilSeed || 137});
  fg.children.forEach(function(bg,i){bg.position.set(${config.fossilX || 2}+i*2.5, 0, ${config.fossilZ || 0})});
  scene.add(fg);

  renderer.render(scene, camera);
  window.__img = renderer.domElement.toDataURL('image/png');
})();
<\/script>
</body></html>
    `;

    await page.setContent(html);
    await new Promise(r => setTimeout(r, 4000));

    const img = await page.evaluate(() => window.__img);
    await page.close();
    return img;
  }

  // --- Render panels ---
  console.log('Rendering wide shot...');
  var wide = await renderScene({
    w: 2000, h: 1200,
    camX: 12, camY: 6, camZ: 14,
    targetX: 1.5, targetY: 0.2, targetZ: 0.5,
    fogNear: 30, fogFar: 100,
    carcassX: -2, carcassY: 0, carcassZ: 0,
    fossilX: 2, fossilZ: 0,
    carcassSeed: 42, fossilSeed: 137,
  });

  console.log('Rendering carcass close-up...');
  var carcassClose = await renderScene({
    w: 1000, h: 700,
    camX: -1, camY: 1.5, camZ: 3,
    targetX: -2, targetY: 0.3, targetZ: 0,
    carcassX: -2, carcassY: 0, carcassZ: 0,
    fossilX: 20, fossilZ: 0, // push fossils far away
    carcassSeed: 42, fossilSeed: 137,
  });

  console.log('Rendering picked carcass close-up...');
  var pickedClose = await renderScene({
    w: 1000, h: 700,
    camX: 1, camY: 1.5, camZ: 3,
    targetX: 1, targetY: 0.3, targetZ: 0,
    carcassX: 1, carcassY: 0, carcassZ: 0,
    fossilX: 20, fossilZ: 0,
    carcassSeed: 142, fossilSeed: 137,
  });

  console.log('Rendering skull close-up...');
  var skullClose = await renderScene({
    w: 600, h: 500,
    camX: -1.5, camY: 1, camZ: 2,
    targetX: -2, targetY: 0.2, targetZ: 3,
    carcassX: -10, carcassY: 0, carcassZ: 0,
    fossilX: -2, fossilZ: 3,
    carcassSeed: 42, fossilSeed: 137,
  });

  console.log('Rendering ribcage close-up...');
  var ribClose = await renderScene({
    w: 600, h: 500,
    camX: 1, camY: 0.8, camZ: 2.5,
    targetX: 1, targetY: 0.25, targetZ: 3,
    carcassX: -10, carcassY: 0, carcassZ: 0,
    fossilX: 1, fossilZ: 3,
    carcassSeed: 42, fossilSeed: 138,
  });

  console.log('Rendering spine close-up...');
  var spineClose = await renderScene({
    w: 600, h: 500,
    camX: 4, camY: 1, camZ: 2.5,
    targetX: 4, targetY: 0.2, targetZ: 3,
    carcassX: -10, carcassY: 0, carcassZ: 0,
    fossilX: 4, fossilZ: 3,
    carcassSeed: 42, fossilSeed: 139,
  });

  // Create composite HTML with all panels
  console.log('Creating composite...');
  const ctx = await browser.newContext({ viewport: { width: 2560, height: 1440 } });
  const cpage = await ctx.newPage();

  const compositeHtml = `
<!DOCTYPE html>
<html>
<head><style>
  body { margin: 0; padding: 20px; background: #0d0d12; font-family: system-ui, sans-serif; display: flex; flex-direction: column; align-items: center; }
  .title { color: #fff; font-size: 22px; font-weight: 600; margin-bottom: 6px; }
  .subtitle { color: #888; font-size: 13px; margin-bottom: 20px; }
  .row { display: flex; gap: 12px; }
  .panel { text-align: center; }
  .panel img { border-radius: 6px; border: 1px solid #333; }
  .panel .label { color: #ccc; font-size: 13px; margin-top: 6px; font-weight: 500; }
  .wide { width: 1280px; height: 768px; }
  .close { width: 620px; height: 435px; }
</style></head>
<body>
  <div class="title">Carcasses &amp; Fossils — G3, G4</div>
  <div class="subtitle">Primigenia (cpore) · Three.js r128 · SwiftShader · G63 palette C</div>
  <div class="panel" style="margin-bottom:20px">
    <img class="wide" src="${wide}">
    <div class="label">All variants — wide shot</div>
  </div>
  <div class="row">
    <div class="panel">
      <img class="close" src="${carcassClose}">
      <div class="label">Fresh carcass — close</div>
    </div>
    <div class="panel">
      <img class="close" src="${pickedClose}">
      <div class="label">Picked carcass — close</div>
    </div>
  </div>
  <div class="row" style="margin-top:12px">
    <div class="panel">
      <img class="close" src="${skullClose}" style="width:380px;height:300px">
      <div class="label">Skull fossil</div>
    </div>
    <div class="panel">
      <img class="close" src="${ribClose}" style="width:380px;height:300px">
      <div class="label">Ribcage fossil</div>
    </div>
    <div class="panel">
      <img class="close" src="${spineClose}" style="width:380px;height:300px">
      <div class="label">Spine fossil</div>
    </div>
  </div>
</body></html>
  `;

  await cpage.setContent(compositeHtml);
  await new Promise(r => setTimeout(r, 2000));
  await cpage.screenshot({ path: out, type: 'png' });
  console.log('Sheet saved to', out);

  await cpage.close();
  await browser.close();
  console.log('Done.');
})().catch(e => { console.error(e); process.exit(1); });