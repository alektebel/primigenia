// capture.js — headless Chromium screenshot of remains.html
// Usage: node capture.js [url] [output.png]
const { chromium } = require('playwright');

(async () => {
  const url = process.argv[2] || 'http://localhost:8899/remains.html';
  const out = process.argv[3] || '/home/diego/Desarrollo/cpore-wt/art-remains/docs/evidence/props/remains/iteration04.png';

  console.log('Launching Chromium with SwiftShader...');
  const browser = await chromium.launch({
    executablePath: '/home/diego/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',
    args: [
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--no-sandbox',
      '--disable-gpu',
    ],
  });

  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
  });
  const page = await context.newPage();

  // Log JS errors
  page.on('console', msg => console.log('PAGE LOG:', msg.type(), msg.text()));
  page.on('pageerror', err => console.error('PAGE ERROR:', err.message));

  console.log('Navigating to', url);
  await page.goto(url, { waitUntil: 'load', timeout: 30000 });

  // Wait for scene to render
  await new Promise(r => setTimeout(r, 5000));

  // Check if canvas exists and has content
  const canvasInfo = await page.evaluate(() => {
    var canvas = document.querySelector('canvas');
    if (!canvas) return { error: 'no canvas' };
    var gl = canvas.getContext('webgl');
    return {
      width: canvas.width,
      height: canvas.height,
      gl: !!gl,
      debugInfo: gl ? gl.getParameter(gl.getContextAttributes() ? gl : gl).toString() : null,
    };
  });
  console.log('Canvas info:', JSON.stringify(canvasInfo));

  console.log('Taking screenshot...');
  await page.screenshot({ path: out, type: 'png', fullPage: false });
  console.log('Saved to', out);

  await browser.close();
  console.log('Done.');
})().catch(e => { console.error(e); process.exit(1); });