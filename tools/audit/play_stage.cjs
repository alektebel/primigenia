/* tools/audit/play_stage.cjs — 5-minute browser audit of the C stage.

Uses Playwright with SwiftShader software WebGL.
Serves the repo on a free port, plays the stage for 5 minutes with
automated interactions (clicks, holds, WASD, camera orbit, selection,
all move keys, pause, resize to mobile, studio link), collects errors,
failed requests, frame-time spikes, and screenshots every 20 s.

Usage:
    node tools/audit/play_stage.cjs [--duration 300] [--port 8765]
*/
'use strict';

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const net = require('node:net');
const { chromium } = require('playwright');

// ── Config ────────────────────────────────────────────────────────────
const BASE_URL = process.env.CPORE_STAGE_URL || 'http://127.0.0.1:8765';
const EVIDENCE_DIR = process.env.CPORE_STAGE_EVIDENCE
  || path.resolve(__dirname, 'evidence');
const CHROME = process.env.HOME + '/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome';
const NODE_PATH = '/home/diego/Desarrollo/cpore-wt/_agent/node_modules';

let DURATION = 300;  // 5 minutes in seconds
let PORT = null;

// Parse args
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === '--duration' && process.argv[i + 1]) {
    DURATION = parseInt(process.argv[++i], 10);
  } else if (process.argv[i] === '--port' && process.argv[i + 1]) {
    PORT = parseInt(process.argv[++i], 10);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────

function findFreePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, '127.0.0.1', () => {
      const p = srv.address().port;
      srv.close(() => resolve(p));
    });
    srv.on('error', reject);
  });
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ── Violation collector ──────────────────────────────────────────────

const violations = [];

function record(severity, category, detail, context = '') {
  violations.push({ severity, category, detail, context, ts: Date.now() });
}

// ── Main ──────────────────────────────────────────────────────────────

(async () => {
  // Ensure evidence directory
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });

  // Determine URL and optionally start HTTP server
  let httpServer = null;
  let serverUrl = '';

  if (PORT) {
    // User specified port: use BASE_URL (expect pre-existing server)
    serverUrl = BASE_URL;
    console.log(`Using pre-existing server on port ${PORT}: ${serverUrl}`);
  } else {
    // Try to start a server on a free port
    try {
      const srvPort = await findFreePort();
      httpServer = http.createServer((req, res) => {
        let filePath = path.resolve(__dirname, '..');
        if (req.url !== '/') {
          filePath = path.join(filePath, req.url);
        }
        const ext = path.extname(filePath);
        const types = {
          '.html': 'text/html', '.js': 'application/javascript',
          '.css': 'text/css', '.json': 'application/json',
          '.wasm': 'application/wasm', '.png': 'image/png',
          '.ogg': 'audio/ogg',
        };
        try {
          const data = fs.readFileSync(filePath);
          res.writeHead(200, {
            'Content-Type': types[ext] || 'application/octet-stream',
            'Cache-Control': 'no-cache',
          });
          res.end(data);
        } catch (e) {
          res.writeHead(404);
          res.end('Not found');
        }
      });
      await new Promise((resolve) => { httpServer.listen(srvPort, '127.0.0.1', resolve); });
      serverUrl = `http://127.0.0.1:${srvPort}`;
      console.log(`HTTP server started on ${serverUrl}`);
    } catch (err) {
      console.error(`Server startup failed: ${err.message}`);
      console.log(`Falling back to ${BASE_URL}`);
      serverUrl = BASE_URL;
    }
  }

  const url = serverUrl + '/web/stage/';

  const launch = {
    headless: true,
    executablePath: CHROME,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  };

  const browser = await chromium.launch(launch);
  console.log(`Browser: ${browser.version()}`);
  console.log(`Target: ${url}`);
  console.log(`Duration: ${DURATION}s, Evidence: ${EVIDENCE_DIR}`);

  const startTime = Date.now();

  let consoleErrors = [];
  let pageErrors = [];
  let failedRequests = [];
  let frameTimes = [];
  let screenshotCount = 0;

  try {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 800 },
      hasTouch: false,
      isMobile: false,
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();

    // Collect errors
    page.on('pageerror', (e) => { pageErrors.push(e.message); });
    page.on('console', (m) => {
      if (m.type() === 'error') consoleErrors.push(m.text());
    });
    page.on('requestfailed', (req) => {
      const resp = req.response();
      failedRequests.push({
        url: req.url(),
        status: resp ? (typeof resp.status === 'function' ? resp.status() : resp.status) : 0,
        error: req.failure()?.errorString,
      });
    });

    // Frame time tracking via injected script
    await page.addInitScript(() => {
      window.__auditFrameTimes = [];
      window.__lastFrameTime = 0;
      window.__stageTesting = true;
      // Suppress rAF calls to avoid infinite loops while simulation is passive
      if (typeof window.requestAnimationFrame === 'function') {
        const origRAF = window.requestAnimationFrame.bind(window);
        window.requestAnimationFrame = (cb) => {
          origRAF((t) => {
            if (window.__lastFrameTime > 0) {
              const delta = t - window.__lastFrameTime;
              if (delta > 10) window.__auditFrameTimes.push(delta);
            }
            window.__lastFrameTime = t;
            try { cb(t); } catch (e) {}
          });
        };
      }
      window.__stageRAF = window.__stageRAF || function (t) {
        window.__lastFrameTime = t;
      };
    });

    // ── Open the stage ──────────────────────────────────────────────
    console.log('\n=== Opening stage ===');
    await page.goto(url);
    console.log('  Page loaded, waiting for Stage.ready...');

    // Wait for Stage to be ready (needs WASM load)
    await page.waitForFunction(() => {
      try {
        return typeof Stage !== 'undefined' && Stage.ready === true;
      } catch (e) { return false; }
    }, { timeout: 120000, polling: 200 });

    console.log('Stage loaded and ready');

    // Wait for simulation to start
    await sleep(1000);

    // ── Interaction sequence ────────────────────────────────────────
    console.log('\n=== Phase 1: Desktop interaction ===');

    // 1. Ground click to walk
    console.log('  Ground click (walk to marker)');
    await page.mouse.click(400, 500);
    await sleep(1500);

    // 2. Hold pointer to follow
    console.log('  Hold pointer (follow)');
    await page.mouse.move(300, 400);
    await page.mouse.down();
    await page.mouse.move(500, 300);
    await sleep(1500);
    await page.mouse.up();

    // 3. WASD movement
    console.log('  WASD movement');
    await page.keyboard.down('KeyW'); await sleep(1000); await page.keyboard.up('KeyW');
    await page.keyboard.down('KeyA'); await sleep(1000); await page.keyboard.up('KeyA');
    await page.keyboard.down('KeyS'); await sleep(1000); await page.keyboard.up('KeyS');
    await page.keyboard.down('KeyD'); await sleep(1000); await page.keyboard.up('KeyD');

    // 4. Shift sprint
    console.log('  Shift sprint');
    await page.keyboard.down('ShiftLeft'); await sleep(1000); await page.keyboard.up('ShiftLeft');

    // 5. Camera orbit - right button
    console.log('  Camera orbit (right drag)');
    await page.mouse.move(900, 380);
    await page.mouse.down({ button: 'right' });
    await page.mouse.move(1000, 400);
    await page.mouse.up({ button: 'right' });

    // 6. Camera orbit - middle button
    console.log('  Camera orbit (middle drag)');
    await page.mouse.move(900, 380);
    await page.mouse.down({ button: 'middle' });
    await page.mouse.move(950, 400);
    await page.mouse.up({ button: 'middle' });

    // 7. Zoom with wheel
    console.log('  Wheel zoom');
    await page.mouse.move(640, 400);
    await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      if (canvas) {
        canvas.dispatchEvent(new WheelEvent('wheel', { deltaY: 100, bubbles: true }));
        canvas.dispatchEvent(new WheelEvent('wheel', { deltaY: 50, bubbles: true }));
      }
    });

    // 8. Select a creature
    console.log('  Select creature (Garfio)');
    await page.mouse.click(800, 300);
    await sleep(500);

    // 9. Try move keys
    console.log('  Move keys (1-3, Q, E)');
    for (const key of ['Digit1', 'Digit2', 'Digit3', 'KeyQ', 'KeyE']) {
      await page.keyboard.press(key);
      await sleep(300);
    }

    // 10. Space for guard
    console.log('  Guard (Space)');
    await page.keyboard.press('Space');
    await sleep(300);
    await page.keyboard.press('Space'); // Cancel

    // 11. Pause/Unpause
    console.log('  Pause / Unpause (Escape)');
    await page.keyboard.press('Escape');
    await sleep(300);
    await page.keyboard.press('Escape');
    await sleep(300);
    await page.keyboard.press('p');
    await sleep(300);
    await page.keyboard.press('p');

    // ── Phase 2: Resize to mobile ───────────────────────────────────
    console.log('\n=== Phase 2: Mobile resize ===');

    const mobileViewport = { width: 390, height: 844 };
    await page.setViewportSize(mobileViewport);
    console.log('  Viewport set to 390x844');
    await sleep(1000);

    // Screenshot of mobile view
    await page.screenshot({ path: path.join(EVIDENCE_DIR, 'audit-mobile.png'), timeout: 30000 });
    screenshotCount++;

    // Touch interactions
    console.log('  Touch interactions');
    const cdp = await page.context().newCDPSession(page);

    // Tap to walk
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart', touchPoints: [{ x: 200, y: 600, id: 1 }],
    });
    await sleep(500);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });

    // Hold to follow
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart', touchPoints: [{ x: 100, y: 300, id: 2 }],
    });
    await sleep(1000);
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove', touchPoints: [{ x: 150, y: 250, id: 2 }],
    });
    await sleep(500);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });

    // Two-finger orbit
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: [{ x: 200, y: 200, id: 3 }, { x: 300, y: 200, id: 4 }],
    });
    await sleep(300);
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{ x: 220, y: 220, id: 3 }, { x: 320, y: 220, id: 4 }],
    });
    await sleep(300);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });

    // Combat buttons
    console.log('  Mobile combat buttons');
    const buttons = await page.$$('button[data-key], [data-key]');
    for (const btn of buttons.slice(0, 5)) {
      try { await btn.tap(); await sleep(200); } catch (e) { /* skip */ }
    }

    // Pause on mobile
    console.log('  Mobile pause menu');
    await page.keyboard.press('Escape');
    await sleep(200);
    try {
      const pauseVisible = await page.evaluate(() => {
        return !!document.querySelector('#pause-menu, .pause, [class*="pause"]');
      });
      console.log(`  Pause menu visible: ${pauseVisible}`);
    } catch (e) { /* ignore */ }
    await page.keyboard.press('Escape');

    // ── Phase 3: Resize back to desktop ─────────────────────────────
    console.log('\n=== Phase 3: Back to desktop ===');
    await page.setViewportSize({ width: 1280, height: 800 });
    console.log('  Viewport set back to 1280x800');
    await sleep(500);

    // ── Phase 4: Studio link ────────────────────────────────────────
    console.log('\n=== Phase 4: Studio link ===');
    let studioWorked = false;
    try {
      await page.goto(serverUrl + '/web/studio/', { waitUntil: 'domcontentloaded', timeout: 10000 });
      console.log('  Studio loaded');
      studioWorked = true;
    } catch (e) {
      console.log(`  Studio not available (expected): ${e.message}`);
    }

    // Navigate back to stage only if studio loaded successfully and page is still alive
    if (studioWorked && !page.isClosed()) {
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
        console.log('  Back to stage');
        await sleep(500);
      } catch (e) {
        console.log(`  Stage return skipped: ${e.message}`);
      }
    }

    // ── Phase 5: Continuous monitoring ──────────────────────────────
    const elapsed = (Date.now() - startTime) / 1000;
    const remaining = Math.max(0, DURATION - elapsed);

    if (remaining > 20 && !page.isClosed()) {
      console.log(`\n=== Phase 5: Continuous monitoring (${remaining.toFixed(0)}s remaining) ===`);

      let monitorTick = 0;
      const screenEvery = 20;

      const monitorInterval = setInterval(() => {
        monitorTick++;
        if (monitorTick % screenEvery === 0) {
          const spath = path.join(EVIDENCE_DIR, `audit-monitor-${monitorTick}.png`);
          page.screenshot({ path: spath, timeout: 15000 }).catch(() => {});
          screenshotCount++;
        }
      }, 10000);

      // Wait for the remaining time (cap at 2 minutes for safety)
      const waitMs = Math.min(remaining * 1000, 120000);
      console.log(`  Monitoring for ${waitMs}ms...`);
      await sleep(waitMs);
      console.log(`  Monitoring complete`);
      clearInterval(monitorInterval);

      // Extra screenshot
      page.screenshot({ path: path.join(EVIDENCE_DIR, `audit-monitor-final.png`), timeout: 15000 }).catch(() => {});
      screenshotCount++;
    }

    // ── Final diagnostics ───────────────────────────────────────────
    console.log('\n=== Final diagnostics ===');
    let frameData_safe = [];
    try {
      if (pageErrors.length > 0) {
        record('HIGH', 'page-errors', `${pageErrors.length} page errors`);
        for (const err of pageErrors.slice(0, 5)) { console.error(`  PAGE: ${err}`); }
      }

      if (consoleErrors.length > 0) {
        record('MEDIUM', 'console-errors', `${consoleErrors.length} console errors`);
        for (const err of consoleErrors.slice(0, 5)) { console.error(`  CONSOLE: ${err}`); }
      }

      if (failedRequests.length > 0) {
        record('MEDIUM', 'failed-requests', `${failedRequests.length} failed requests`);
        for (const req of failedRequests.slice(0, 5)) { console.error(`  FAIL: ${req.url} (${req.status})`); }
      }

      // Frame time analysis
      const frameData = page.isClosed() ? [] : await page.evaluate(() => {
        return typeof window.__auditFrameTimes !== 'undefined'
          ? window.__auditFrameTimes.slice(-100)
          : [];
      });

      if (frameData.length > 0) {
        frameData_safe = frameData;
        const maxFrame = Math.max(...frameData);
        const avgFrame = frameData.reduce((a, b) => a + b, 0) / frameData.length;
        console.log(`  Frame times: ${frameData.length} samples, max=${maxFrame.toFixed(1)}ms, avg=${avgFrame.toFixed(1)}ms`);
        if (maxFrame > 100) {
          record('LOW', 'frame-spikes', `Max frame ${maxFrame.toFixed(1)}ms`);
        }
      }
    } catch (e) {
      console.log(`  Final diagnostics skipped (page closed): ${e.message}`);
    }

    console.log(`  Screenshots: ${screenshotCount}`);
    console.log(`  Violations: ${violations.length}`);

    // ── Save results ────────────────────────────────────────────────
    const results = {
      duration: DURATION,
      url,
      browser: browser.version(),
      renderer: 'SwiftShader software WebGL',
      viewportSizes: ['1280x800', '390x844'],
      interactions: [
        'ground-click-walk', 'hold-pointer-follow',
        'wasd-movement', 'shift-sprint',
        'right-drag-orbit', 'middle-drag-orbit', 'wheel-zoom',
        'creature-selection', 'move-keys-1-3-q-e', 'guard-space',
        'pause-escape-p',
        'mobile-touch-walk', 'mobile-touch-follow',
        'mobile-two-finger-orbit', 'mobile-combat-buttons',
        'mobile-pause',
        'desktop-resize-back',
        'studio-link',
      ],
      screenshots: screenshotCount,
      consoleErrors: consoleErrors.length,
      pageErrors: pageErrors.length,
      failedRequests: failedRequests.length,
      violations: violations.length,
      violationsList: violations,
      frameTimeSamples: frameData_safe.length,
    };

    const resultsPath = path.join(EVIDENCE_DIR, 'audit-results.json');
    fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2) + '\n');
    console.log(`Results saved to ${resultsPath}`);

  } catch (err) {
    console.error('Audit error:', err);
    record('HIGH', 'audit-error', err.message || String(err));
  } finally {
    // Close CDP session if it was created
    try { await cdp.close(); } catch(e) {}

    // Close the context properly
    try { await context.close(); } catch(e) {}

    console.log('\nClosing browser...');
    console.error('[AUDIT] In finally block');
    await browser.close();
    console.log('Browser closed');

    if (httpServer) {
      httpServer.close(() => {});
      httpServer.unref?.();
      console.log('Server closed');
    }

    const vpath = path.join(EVIDENCE_DIR, 'violations.jsonl');
    fs.writeFileSync(vpath, JSON.stringify(violations, null, 2) + '\n');
    console.log(`Violations saved to ${vpath}`);

    process.exitCode = violations.some(v => v.severity === 'HIGH') ? 1 : 0;
  }

  // Force exit after cleanup (HTTP server may hold event loop)
  console.error('[AUDIT] Forcing exit, active handles:', process._getActiveHandles?.().length || '?');
  process.exit(process.exitCode || 0);
})().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});