const { chromium } = require('playwright');
const fs = require('fs');

const port = 8889;
const output = process.argv.includes('--output') ? process.argv[process.argv.indexOf('--output') + 1] : '/tmp/food_final.png';
const count = process.argv.includes('--count') ? parseInt(process.argv[process.argv.indexOf('--count') + 1]) : 1;

const chromePath = require('path').join(process.env.HOME, '.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');

(async () => {
  for (let i = 0; i < count; i++) {
    const seed = 42 + i * 137;
    const out = output.replace(/\.png$/, `_iter${i+1}_s${seed}.png`);

    const browser = await chromium.launch({
      executablePath: chromePath,
      args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox', '--disable-gpu', '--window-size=1600,1200']
    });

    const page = await browser.newPage({ viewport: { width: 1600, height: 1200 } });
    await page.goto(`http://localhost:${port}/web/props/food.html?t=golden`, { waitUntil: 'networkidle', timeout: 15000 });

    // Wait and render until stable
    for (let attempt = 0; attempt < 10; attempt++) {
      await new Promise(r => setTimeout(r, 500));
      const stats = await page.evaluate(() => {
        if (typeof THREE === 'undefined') return { ok: false, reason: 'no THREE' };
        if (typeof renderer === 'undefined') return { ok: false, reason: 'no renderer' };
        if (typeof scene === 'undefined') return { ok: false, reason: 'no scene' };
        let totalChildren = 0;
        scene.traverse(() => totalChildren++);
        return {
          ok: true,
          drawCalls: renderer.info ? renderer.info.render.calls : 'N/A',
          children: totalChildren,
          geometries: renderer.info ? renderer.info.memory.geometries : 'N/A',
          textures: renderer.info ? renderer.info.memory.textures : 'N/A',
        };
      });

      if (stats.ok && stats.children > 10) {
        console.log(`Scene ready: ${JSON.stringify(stats)}`);
        break;
      }
      console.log(`Attempt ${attempt}: ${JSON.stringify(stats)}`);
    }

    // Force a render
    await page.evaluate(() => {
      if (typeof renderer !== 'undefined' && typeof scene !== 'undefined' && typeof camera !== 'undefined') {
        renderer.render(scene, camera);
      }
    });

    await new Promise(r => setTimeout(r, 500));
    const screenshot = await page.screenshot({ type: 'png', fullPage: false });
    fs.writeFileSync(out, screenshot);
    console.log(`Saved: ${out} (${screenshot.length} bytes)`);
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
