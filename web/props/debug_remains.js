// debug_remains.js — test remains module in browser, output to stdout
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch({
    executablePath: '/home/diego/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args: ['--no-sandbox', '--disable-gpu'],
  });
  const context = await browser.newContext({ viewport: { width: 1280, height: 1024 } });
  const page = await context.newPage();

  var remainsSrc = fs.readFileSync(path.join(__dirname, 'remains.js'), 'utf8');
  remainsSrc = remainsSrc.replace(/export\s+function\s+/g, 'function ');

  const html = `
<!DOCTYPE html>
<html><head><style>body{background:#fff;font-family:monospace;padding:20px}</style></head>
<body>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"><\/script>
<script>${remainsSrc}</script>
<script>
(function() {
  var T = THREE;

  window.__debugResults = [];
  function log(s) { window.__debugResults.push(s); }

  try {
    log('=== Test buildAllCarcasses ===');
    var cg = buildAllCarcasses(T, 42);
    log('Group name: ' + cg.name);
    log('Children: ' + cg.children.length);

    cg.traverse(function(c) {
      if (c.isMesh) {
        log('  Mesh: name=' + c.name + ' hasGeo=' + !!c.geometry + ' hasMat=' + !!c.material +
            ' pos=(' + c.position.x.toFixed(2) + ',' + c.position.y.toFixed(2) + ',' + c.position.z.toFixed(2) + ')');
      }
      if (c.isGroup) {
        log('  Group: name=' + c.name);
      }
    });

    var meshCount = 0;
    cg.traverse(c => { if (c.isMesh) meshCount++; });
    log('Total carcass meshes: ' + meshCount);

    log('');
    log('=== Test buildAllFossils ===');
    var fg = buildAllFossils(T, 137);
    log('Group name: ' + fg.name);
    log('Children: ' + fg.children.length);

    fg.children.forEach(function(bg, i) {
      log('Biome ' + i + ': ' + bg.name);
      var bm = 0;
      bg.traverse(c => { if (c.isMesh) bm++; });
      log('  Meshes: ' + bm);
      bg.traverse(function(c) {
        if (c.isMesh) {
          log('    Mesh: name=' + c.name + ' hasGeo=' + !!c.geometry + ' hasMat=' + !!c.material);
        }
      });
    });

    var totalMeshes = 0;
    fg.traverse(c => { if (c.isMesh) totalMeshes++; });
    log('Total fossil meshes: ' + totalMeshes);

    log('');
    log('=== Material test ===');
    var m = new T.MeshPhysicalMaterial({ color: 0xff0000 });
    log('MeshPhysicalMaterial: OK, color=' + m.color.getHexString());

    var m2 = new T.MeshToonMaterial({ color: 0xff0000 });
    log('MeshToonMaterial: OK');

    var gt = new T.DataTexture(new Uint8Array([46,46,82,82,112,112]),6,1,T.LuminanceFormat);
    gt.minFilter = gt.magFilter = T.NearestFilter;
    gt.needsUpdate = true;
    log('DataTexture: OK');

  } catch(e) {
    log('ERROR: ' + e.message);
    log(e.stack);
  }
})();
<\/script>
</body></html>
  `;

  await page.setContent(html);
  await new Promise(r => setTimeout(r, 3000));

  var results = await page.evaluate(() => window.__debugResults || ['no results']);
  results.forEach(r => console.log(r));

  await browser.close();
})();