// render_remains.js — build remains and screenshot via Playwright (standalone)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const out = process.argv[2] || '/home/diego/Desarrollo/cpore-wt/art-remains/docs/evidence/props/remains/iteration09.png';

  const browser = await chromium.launch({
    executablePath: '/home/diego/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args: [
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--no-sandbox',
      '--disable-gpu',
    ],
  });

  const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
  const page = await context.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      console.log('PAGE:', msg.type(), msg.text());
    }
  });
  page.on('pageerror', err => console.log('PAGEERR:', err.message));

  // Load remains.js and strip export keywords
  var remainsSrc = fs.readFileSync(path.join(__dirname, 'remains.js'), 'utf8');
  remainsSrc = remainsSrc.replace(/export\s+function\s+/g, 'function ');

  const html = `
<!DOCTYPE html>
<html>
<head><style>body{margin:0;overflow:hidden;background:#000}</style></head>
<body>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"><\/script>
<script>
${remainsSrc}
</script>
<script>
(function() {
  var T = THREE;
  var scene = new T.Scene();
  scene.background = new T.Color(0x87a5c0);
  scene.fog = new T.Fog(0xc0c8c0, 40, 120);

  var camera = new T.PerspectiveCamera(60, 1920/1080, 0.3, 500);
  camera.position.set(4, 2.5, 4);
  camera.lookAt(0.5, 0.3, 0);

  var renderer = new T.WebGLRenderer({ antialias: true });
  renderer.setSize(1920, 1080);
  renderer.outputEncoding = T.sRGBEncoding;
  renderer.shadowMap.enabled = true;
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  document.body.appendChild(renderer.domElement);

  // Sun
  var sun = new T.DirectionalLight(0xffd6a0, 3.2);
  sun.position.set(-10, 5, -8);
  sun.castShadow = true;
  sun.shadow.mapSize.set(512, 512);
  sun.shadow.camera.left = -8; sun.shadow.camera.right = 8;
  sun.shadow.camera.top = 8; sun.shadow.camera.bottom = -8;
  sun.shadow.camera.near = 0.5; sun.shadow.camera.far = 30;
  scene.add(sun); scene.add(sun.target);
  scene.add(new T.HemisphereLight(0xa8ccf8, 0x6a6a5c, 0.5));

  // shared toon gradient
  var gt = new T.DataTexture(new Uint8Array([46,46,82,82,112,112]),6,1,T.LuminanceFormat);
  gt.minFilter = gt.magFilter = T.NearestFilter; gt.needsUpdate = true;

  // ground
  var gm = new T.MeshToonMaterial({ gradientMap: gt, color: new T.Color(0.185,0.335,0.075) });
  var gg = new T.PlaneGeometry(80,80); gg.rotateX(-Math.PI/2);
  var gnd = new T.Mesh(gg, gm); gnd.receiveShadow = true; gnd.position.y = -0.02; scene.add(gnd);

  // rocks
  var rm = new T.MeshToonMaterial({ gradientMap: gt, color: new T.Color(0.28,0.215,0.14) });
  for(var i=0;i<15;i++){
    var s=0.08+Math.random()*0.25;
    var g2=new T.Mesh(new T.IcosahedronGeometry(s,0),rm);
    g2.position.set((Math.random()-0.5)*12,-s*0.2,(Math.random()-0.5)*12);
    g2.receiveShadow=true; scene.add(g2);
  }

  // Count triangles
  var ct = 0;
  function countT(obj){
    obj.traverse(function(c){
      if(c.isMesh && c.geometry){
        var g=c.geometry;
        if(g.index) ct += g.index.count/3;
        else ct += g.attributes.position.count/3;
      }
    });
  }

  // --- Build carcasses ---
  window.__carcassErr = null;
  try {
    window.__carcassErr = (typeof buildAllCarcasses !== 'function') ? 'buildAllCarcasses not defined' : null;
    var cg = buildAllCarcasses(T, 42);
    cg.position.set(-2, 0, 0);
    countT(cg);
    scene.add(cg);
  } catch(e) { window.__carcassErr = e.message; console.error('Carcass:', e.message); }

  // --- Build fossils ---
  window.__fossilErr = null;
  try {
    window.__fossilErr = (typeof buildAllFossils !== 'function') ? 'buildAllFossils not defined' : null;
    var fg = buildAllFossils(T, 137);
    fg.children.forEach(function(bg,i){
      bg.position.set(2 + i*2.5, 0, 0);
      countT(bg);
    });
    scene.add(fg);
  } catch(e) { window.__fossilErr = e.message; console.error('Fossil:', e.message); }

  console.log('=== Scene state ===');
  console.log('buildAllCarcasses:', typeof buildAllCarcasses);
  console.log('buildAllFossils:', typeof buildAllFossils);
  console.log('Carcass children:', window.__carcassErr || 'OK');
  console.log('Fossil children:', window.__fossilErr || 'OK');

  // Try rendering
  try {
    renderer.render(scene, camera);
    if (renderer.domElement && renderer.domElement.toDataURL) {
      window.__png = renderer.domElement.toDataURL('image/png');
    }
  } catch(e) {
    window.__renderErr = e.message;
    console.error('Render failed:', e.message);
    // Take screenshot anyway
    window.__png = null;
  }

  console.log('Done.');
})();
<\/script>
</body></html>
  `;

  await page.setContent(html);
  await new Promise(r => setTimeout(r, 5000));

  const carcassErr = await page.evaluate(() => window.__carcassErr);
  const fossilErr = await page.evaluate(() => window.__fossilErr);
  const renderErr = await page.evaluate(() => window.__renderErr);

  console.log('Carcass error:', carcassErr);
  console.log('Fossil error:', fossilErr);
  console.log('Render error:', renderErr);

  const pngData = await page.evaluate(() => window.__png);
  if (pngData) {
    const base64 = pngData.replace(/^data:image\/png;base64,/, '');
    const buf = Buffer.from(base64, 'base64');
    fs.writeFileSync(out, buf);
    console.log('Saved to', out);
  } else {
    await page.screenshot({ path: out, fullPage: false });
    console.log('Fallback saved to', out);
  }

  await browser.close();
  console.log('Done.');
})().catch(e => { console.error(e); process.exit(1); });