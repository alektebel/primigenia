#!/usr/bin/env node
/* Gait lab capture: web/gaitlab/index.html, SwiftShader software WebGL only (never GPU flags).
   NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules nice -n 10 node tools/gaitlab/capture.cjs [--video] [--noshots]
   Runs the in-page self-check (exit 1 if any assertion fails), writes docs/evidence/loco/gaitlab/*.jpg, docs/evidence/loco/gaitlab/table.json,
   and with --video a ~6 s real-time clip per preset into /home/diego/Desarrollo/cpore-wt/_agent/gaitlab-clips/ (outside the repo).
   three.js r128 is served from web/biome/three.min.js (same revision as the cdnjs build) so the run needs no network. */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(ROOT, 'docs/evidence/loco/gaitlab');
const CLIPS = '/home/diego/Desarrollo/cpore-wt/_agent/gaitlab-clips';
const VIDEO = process.argv.includes('--video'), SHOTS = !process.argv.includes('--noshots');
fs.mkdirSync(OUT, { recursive: true }); if (VIDEO) fs.mkdirSync(CLIPS, { recursive: true });
const CHROME = process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome';
const THREE = fs.readFileSync(path.join(ROOT, 'web/biome/three.min.js'));
const PRESETS = ['walk', 'trot', 'gallop', 'game', 'gamefix'];
const srv = http.createServer((req, res) => {
  const f = path.join(ROOT, 'web/gaitlab', decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, 'index.html'));
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': 'text/html' }); fs.createReadStream(f).pipe(res);
}).listen(0, '127.0.0.1', async () => {
  const port = srv.address().port;
  const browser = await chromium.launch({ executablePath: fs.existsSync(CHROME) ? CHROME : undefined, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  let failed = false;
  const mk = async (opts) => {
    const ctx = await browser.newContext(opts);
    await ctx.route('**/three.min.js', (r) => r.fulfill({ status: 200, contentType: 'application/javascript', body: THREE }));
    const page = await ctx.newPage();
    page.on('console', (m) => { if (m.type() === 'error' || /self-check/.test(m.text())) console.log('console:', m.text().slice(0, 600)); });
    page.on('pageerror', (e) => { console.log('page error:', String(e).slice(0, 400)); failed = true; });
    return [ctx, page];
  };
  // 1. self-check + screenshots
  const [ctx, page] = await mk({ viewport: { width: 1600, height: 1000 } });
  await page.goto(`http://127.0.0.1:${port}/index.html?test=1`);
  await page.waitForFunction('window.__ready && window.__gaitlabCheck', null, { timeout: 300000 });
  const res = await page.evaluate('window.__gaitlabCheck');
  fs.writeFileSync(path.join(OUT, 'table.json'), JSON.stringify(res.table, null, 1));
  console.log(res.pass ? 'SELF-CHECK PASS' : 'SELF-CHECK FAIL');
  for (const f of res.fails) console.log('  ' + f);
  if (!res.pass) failed = true;
  if (SHOTS) for (const k of PRESETS) {
    await page.evaluate(`(() => { GL.pause(true); GL.preset('${k}', true); GL.settle(60); GL.advance(0.37); GL.render(); })()`);
    await page.waitForTimeout(150);
    const f = path.join(OUT, `grid_${k}.jpg`);
    await page.screenshot({ path: f, type: 'jpeg', quality: 90 }); console.log('wrote', f);
  }
  await ctx.close();
  // 2. real-time clips
  if (VIDEO) for (const k of PRESETS) {
    const [c2, p2] = await mk({ viewport: { width: 1280, height: 800 }, recordVideo: { dir: CLIPS + '/tmp', size: { width: 1280, height: 800 } } });
    await p2.goto(`http://127.0.0.1:${port}/index.html?preset=${k}`);
    await p2.waitForFunction('window.__ready'); await p2.waitForTimeout(6500);
    const v = p2.video(); await c2.close(); await v.saveAs(path.join(CLIPS, `gaitlab_${k}.webm`)); console.log('wrote clip', k);
  }
  await browser.close(); srv.close(); process.exit(failed ? 1 : 0);
});
