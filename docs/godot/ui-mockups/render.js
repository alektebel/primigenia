// Renders every mockup page to render/*.jpg. Software rendering only (no GPU flags).
// Run: NODE_PATH=<dir with playwright>/node_modules node render.js "$PWD" [name filter]
const { chromium } = require('playwright');
const path = require('path'), fs = require('fs');
(async () => {
  const dir = process.argv[2];
  const b = await chromium.launch({ executablePath: process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.html')).sort()) {
    if (process.argv[3] && !f.includes(process.argv[3])) continue;
    await p.goto('file://' + path.join(dir, f));
    await p.evaluate(() => document.fonts.ready);
    await p.waitForTimeout(150);
    await p.screenshot({ path: path.join(dir, 'render', f.replace('.html', '.jpg')), type: 'jpeg', quality: 88 });
    console.log(f);
  }
  await b.close();
})();
