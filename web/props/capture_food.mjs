/* capture_food.mjs — Headless Chromium capture (SwiftShader, software WebGL).
 * Usage: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
 *   nice -n 10 node capture_food.mjs [--port PORT] [--output PATH] [--count N]
 * Requires: python3 -m http.server running on PORT.
 */
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const port = process.argv.includes('--port') ? parseInt(process.argv[process.argv.indexOf('--port') + 1]) : 8888;
const output = process.argv.includes('--output') ? process.argv[process.argv.indexOf('--output') + 1] : 'docs/evidence/props/food/iter0.png';
const count = process.argv.includes('--count') ? parseInt(process.argv[process.argv.indexOf('--count') + 1]) : 1;

const chromePath = path.join(process.env.HOME, '.cache/ms-playwright/chromium-1254/chrome-linux64/chrome');

async function capture(iteration, seed, view) {
  const browser = await chromium.launch({
    executablePath: chromePath,
    args: [
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--no-sandbox',
      '--disable-gpu',
      '--disable-software-rasterizer',
      '--window-size=1600,1200',
    ],
  });

  const page = await browser.newPage({ viewport: { width: 1600, height: 1200 } });

  // Inject custom CSS and JS to force ACES pipeline and proper materials
  await page.addStyleTag({ content: `
    * { margin: 0; padding: 0; }
    body { background: #2a3a20; }
    canvas { display: block; width: 100%; height: 100vh; }
  `});

  const url = `http://localhost:${port}/web/props/food.html?t=golden`;
  await page.goto(url, { waitUntil: 'networkidle', timeout: 15000 });

  // Wait for Three.js to initialize
  await page.waitForFunction(() => typeof THREE !== 'undefined', { timeout: 10000 });
  await new Promise(r => setTimeout(r, 2000));

  // Set seed via URL
  if (seed !== undefined) {
    await page.evaluate((s) => { window.location.href = window.location.pathname + '?seed=' + s + '&t=golden'; }, seed);
    await new Promise(r => setTimeout(r, 2000));
  }

  // Capture
  const screenshot = await page.screenshot({ type: 'png', fullPage: false });
  await browser.close();

  fs.writeFileSync(output, screenshot);
  console.log(`Saved: ${output}`);
  return screenshot;
}

async function main() {
  for (let i = 0; i < count; i++) {
    const seed = 42 + i * 137;
    const out = output.replace(/\.png$/, `_iter${i+1}_s${seed}.png`);
    console.log(`[${i+1}/${count}] Capturing seed=${seed} → ${out}`);
    await capture(i, seed, 'all');
  }
}

main().catch(e => { console.error(e); process.exit(1); });