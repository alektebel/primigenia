#!/usr/bin/env node
/* Capture the meteor props preview (web/props/meteor.html) with software WebGL.
 *
 *   NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
 *     nice -n 10 node tools/props/capture_meteor.cjs [options]
 *
 *   --out DIR        output dir (default docs/evidence/props/meteor/shots)
 *   --shots a,b,c    shot names (default: lineup,scene,far,core,shard0..shard4)
 *   --port N         http port for the preview server (default: free port)
 *   --seed N         world seed passed to the page
 *   --keep-server    leave the preview server running
 *
 * The page is served over http so the ES module + import map resolve the same
 * way they will in the game.  Chromium runs with SwiftShader only (no GPU).
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const net = require('net');

const ROOT = path.resolve(__dirname, '../..');
const arg = (k, d) => { const i = process.argv.indexOf(k); return i < 0 ? d : (process.argv[i + 1] ?? true); };
const OUT = path.resolve(arg('--out', path.join(ROOT, 'docs/evidence/props/meteor/shots')));
const SEED = arg('--seed', '20261115');
const ALL_SHOTS = ['lineup', 'scene', 'far', 'core', 'shard0', 'shard1', 'shard2', 'shard3', 'shard4'];
const SHOTS = String(arg('--shots', ALL_SHOTS.join(','))).split(',').filter(Boolean);
const CHROME = process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome';
const ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'];
const W = 1280, H = 800;

function freePort() {
  return new Promise((resolve) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => resolve(p)); });
  });
}

async function waitForServer(port) {
  const http = require('http');
  for (let i = 0; i < 60; i++) {
    const ok = await new Promise((resolve) => {
      const req = http.get({ host: '127.0.0.1', port, path: '/web/props/meteor.html' }, (res) => {
        res.resume(); resolve(res.statusCode === 200);
      });
      req.on('error', () => resolve(false));
      req.setTimeout(1500, () => { req.destroy(); resolve(false); });
    });
    if (ok) return true;
    await new Promise((r) => setTimeout(r, 250));
  }
  return false;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const port = arg('--port', null) ? +arg('--port') : await freePort();
  const server = cp.spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1', '--directory', ROOT],
    { stdio: 'ignore' });
  const stop = () => { if (!process.argv.includes('--keep-server')) server.kill('SIGTERM'); };
  process.on('exit', stop);

  if (!await waitForServer(port)) { server.kill('SIGTERM'); throw new Error('preview server did not start'); }

  const browser = await chromium.launch({ executablePath: CHROME, args: ARGS });
  const browserVersion = browser.version();
  const stats = [];
  let renderer = null;
  try {
    for (const shot of SHOTS) {
      const t0 = Date.now();
      const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
      const errors = [];
      page.on('pageerror', (e) => { errors.push(e.message); console.error(shot + ': ' + e.message); });
      page.on('console', (m) => { if (m.type() === 'error') { errors.push(m.text()); console.error(shot + ': ' + m.text().slice(0, 800)); } });
      await page.goto(`http://127.0.0.1:${port}/web/props/meteor.html?shot=${shot}&seed=${SEED}`,
        { waitUntil: 'load', timeout: 60000 });
      await page.waitForFunction(() => window.Meteor && window.Meteor.ready, null, { timeout: 120000 });
      await page.waitForTimeout(1200);   // a few frames for the grass and the shadow map
      if (!renderer) {
        renderer = await page.evaluate(() => {
          const gl = document.getElementById('gl').getContext('webgl2') || document.getElementById('gl').getContext('webgl');
          const e = gl && gl.getExtension('WEBGL_debug_renderer_info');
          return e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : (gl ? gl.getParameter(gl.RENDERER) : 'none');
        });
      }
      const file = path.join(OUT, shot + '.png');
      await page.screenshot({ path: file });
      const s = await page.evaluate(() => window.Meteor.stats());
      s.errors = errors;
      s.seconds = (Date.now() - t0) / 1000;
      stats.push(s);
      console.log(`${shot}: ${s.propTris} tris, ${s.propDrawCalls} draw calls, ${errors.length} errors, ${s.seconds.toFixed(1)}s -> ${path.relative(ROOT, file)}`);
      await page.close();
    }
  } finally {
    await browser.close();
    stop();
  }
  fs.writeFileSync(path.join(OUT, 'capture.json'), JSON.stringify({
    generated: new Date().toISOString(), seed: SEED, viewport: `${W}x${H}`,
    browser: 'Chromium ' + browserVersion, args: ARGS, renderer, shots: stats,
  }, null, 1));
  console.log('wrote ' + path.relative(ROOT, path.join(OUT, 'capture.json')));
})().catch((e) => { console.error(e); process.exit(1); });
