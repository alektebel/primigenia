#!/usr/bin/env node
/** capture.js — Full capture: HTTP server + headless Chromium render.
 *
 * Usage: node capture.js [shallow|deep|surface]
 * NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules
 */

const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const PRESET = process.argv[2] || "shallow";
const PORT = parseInt(process.env.CAPTURE_PORT || Date.now().toString().slice(-4), 10);
const CHROME = path.join(process.env.HOME, ".cache/ms-playwright/chromium-1254/chrome-linux64/chrome");
const OUTPUT = path.join(ROOT, "docs", "evidence", "underwater", `${PRESET}-render.png`);

const MIME_TYPES = {
  ".html": "text/html", ".js": "application/javascript", ".css": "text/css",
  ".png": "image/png", ".svg": "image/svg+xml", ".json": "application/json",
};

// HTTP server
const server = http.createServer((req, res) => {
  let urlPath = req.url.split("?")[0];
  if (urlPath === "/") urlPath = "/web/biome/underwater.html";
  const filePath = path.join(ROOT, urlPath);
  const ext = path.extname(filePath).toLowerCase();
  
  if (!fs.existsSync(filePath)) {
    console.log(`404: ${req.url} -> ${filePath}`);
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not found: " + req.url);
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(500); res.end("Error"); return; }
    res.writeHead(200, { "Content-Type": MIME_TYPES[ext] || "application/octet-stream" });
    res.end(data);
  });
});

(async () => {
  server.listen(PORT, "127.0.0.1", () => {
    console.log(`HTTP server on port ${PORT}`);
  });

  let browser;
  try {
    await new Promise((r) => setTimeout(r, 500));

    browser = await chromium.launch({
      executablePath: CHROME,
      args: [
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
        "--no-sandbox",
        "--disable-gpu",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
      ],
      headless: true,
    });

    const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = await ctx.newPage();
    page.on("console", (msg) => {
      if (["error", "warning"].includes(msg.type())) {
        const t = msg.text();
        if (!t.includes("ReadPixels") && !t.includes("GPU stall")) {
          console.log("[" + msg.type() + "]", t.substring(0, 150));
        }
      }
    });
    page.on("pageerror", (err) => console.log("JS ERROR:", err.message));

    const url = `http://127.0.0.1:${PORT}/web/biome/underwater.html`;
    console.log(`Preset: ${PRESET}`);

    await page.goto(url, { waitUntil: "load", timeout: 15000 });
    console.log("Page loaded, waiting for canvas...");

    // Verify THREE.js loaded
    const threeOk = await page.evaluate(() => typeof THREE !== "undefined");
    console.log("THREE.js:", threeOk ? "loaded" : "MISSING");
    if (!threeOk) throw new Error("Three.js not loaded");

    // Check canvas
    const canvasInfo = await page.evaluate(() => {
      const c = document.querySelector("canvas");
      return {
        exists: !!c,
        width: c ? c.width : 0,
        height: c ? c.height : 0,
        threeLoaded: typeof THREE !== "undefined",
        biomeLoaded: typeof UnderwaterBiome !== "undefined",
        hasError: document.getElementById("loading") ? "loading" : "loaded"
      };
    });
    console.log("Canvas:", JSON.stringify(canvasInfo));

    // Wait for rendering
    console.log("Waiting for animation frames...");
    await new Promise((r) => setTimeout(r, 2500));

    // Apply preset
    console.log("Applying preset...");
    await page.evaluate(async (preset) => {
      const btn = document.querySelector(`[data-preset="${preset}"]`);
      if (btn) btn.click();
      await new Promise((r) => setTimeout(r, 1500));
      await new Promise((r) => setTimeout(r, 1000));
    }, PRESET);

    // Extra wait for caustics to settle
    await new Promise((r) => setTimeout(r, 1500));

    console.log("Capturing screenshot...");
    await page.screenshot({ path: OUTPUT, type: "png", omitBackground: false });
    console.log(`Saved: ${OUTPUT}`);
  } catch (err) {
    console.error("Render error:", err.message, err.stack?.substring(0, 500));
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})();