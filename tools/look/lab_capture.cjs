#!/usr/bin/env node
/* Look-dev lab captures: web/lookdev/index.html at dawn, midday, dusk, night (SwiftShader software WebGL, never GPU flags).
   NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules nice -n 10 node tools/look/lab_capture.cjs [outdir] [variant] [quality] [cam]
   Writes <outdir>/lab_v<variant>_<quality>_<cam>_<tod>.jpg (default docs/evidence/look/lab). Serves the page from a throwaway localhost server. */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const out = path.resolve(process.argv[2] || path.join(ROOT, 'docs/evidence/look/lab'));
const variant = process.argv[3] || '0', quality = process.argv[4] || 'medium', cam = process.argv[5] || 'close';
fs.mkdirSync(out, { recursive: true });
const CHROME = process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome';
const srv = http.createServer((req, res) => {
  const f = path.join(ROOT, 'web/lookdev', decodeURIComponent(req.url.split('?')[0]).replace(/^\/+$/, 'index.html'));
  if (!f.startsWith(path.join(ROOT, 'web/lookdev')) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': f.endsWith('.html') ? 'text/html' : 'application/octet-stream' }); fs.createReadStream(f).pipe(res);
}).listen(0, '127.0.0.1', async () => {
  const port = srv.address().port;
  const browser = await chromium.launch({ executablePath: fs.existsSync(CHROME) ? CHROME : undefined, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', (m) => { if (m.type() === 'error') console.log('console error:', m.text().slice(0, 300)); });
  page.on('pageerror', (e) => console.log('page error:', String(e).slice(0, 300)));
  for (const t of ['dawn', 'midday', 'dusk', 'night']) {
    await page.goto(`http://127.0.0.1:${port}/index.html?still=1&t=${t}&q=${quality}&v=${variant}&cam=${cam}`);
    await page.waitForFunction('window.__ready && window.__rendered >= 1', null, { timeout: 120000 });
    await page.waitForTimeout(500);
    const f = path.join(out, `lab_v${variant}_${quality}_${cam}_${t}.jpg`);
    await page.screenshot({ path: f, type: 'jpeg', quality: 92 });
    console.log('wrote', f);
  }
  await browser.close(); srv.close();
});
