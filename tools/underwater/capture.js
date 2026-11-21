/** capture.js — Full capture with error capture */
const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const PRESET = process.argv[2] || "shallow";
const OUTNAME = process.argv[3] || `${PRESET}-render.png`;
const PORT = parseInt(process.env.CAPTURE_PORT || Date.now().toString().slice(-4), 10);
const CHROME = path.join(process.env.HOME, ".cache/ms-playwright/chromium-1254/chrome-linux64/chrome");
const OUTPUT = path.join(ROOT, "docs", "evidence", "underwater", OUTNAME);

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
    
    // Collect ALL console messages
    const allMessages = [];
    page.on("console", (msg) => {
      const type = msg.type();
      const text = msg.text();
      allMessages.push("[" + type + "] " + text);
      if (["error", "warning"].includes(type) && !text.includes("ReadPixels") && !text.includes("GPU stall") && !text.includes("favicon")) {
        console.log("[" + type.toUpperCase() + "] " + text.substring(0, 300));
      }
    });
    page.on("pageerror", (err) => {
      console.log("JS ERROR: " + err.message.substring(0, 300));
      allMessages.push("PAGE ERROR: " + err.message);
    });

    const url = `http://127.0.0.1:${PORT}/web/biome/underwater.html`;
    console.log(`Preset: ${PRESET}`);

    await page.goto(url, { waitUntil: "load", timeout: 15000 });
    console.log("Page loaded, waiting for canvas...");

    // Wait for animation frames
    await new Promise((r) => setTimeout(r, 3000));

    // Apply preset
    console.log("Applying preset...");
    await page.evaluate(async (preset) => {
      const btn = document.querySelector(`[data-preset="${preset}"]`);
      if (btn) btn.click();
      await new Promise((r) => setTimeout(r, 2000));
      await new Promise((r) => setTimeout(r, 1000));
    }, PRESET);

    // Extra wait for caustics to settle
    await new Promise((r) => setTimeout(r, 2000));

    // Render one more frame and get info from the renderer
    // Capture one more frame to trigger compilation
    await page.evaluate(() => {
      if (window.__biome) window.__biome.update(performance.now() / 1000);
      window.__renderer && window.__renderer.render(window.__scene, window.__camera);
    });

    const info = await page.evaluate(() => {
      const result = {
        mats: window.__biome ? window.__biome._mats.length : 0,
        errors: [],
        isWebGL2: window.__isWebGL2,
        allGLProgramsTruthy: true,
        matDetails: [],
      };
      if (window.__biome && window.__biome._mats) {
        for (let i = 0; i < window.__biome._mats.length; i++) {
          const m = window.__biome._mats[i];
          const name = m._name || ("mat" + i);
          const hasProgram = m.glProgram != null;
          if (!hasProgram) result.allGLProgramsTruthy = false;
          const infoObj = m.info;
          const errCount = (infoObj && infoObj.errors && infoObj.errors.length) || 0;
          const warnCount = (infoObj && infoObj.warnings && infoObj.warnings.length) || 0;
          if (errCount > 0 || warnCount > 0 || !hasProgram) {
            result.matDetails.push({
              idx: i, name, hasProgram, errCount, warnCount,
              errors: infoObj && infoObj.errors ? infoObj.errors : [],
              warnings: infoObj && infoObj.warnings ? infoObj.warnings : [],
            });
          }
          if (errCount > 0) {
            result.errors.push({ mat: name, errors: m.info.errors });
          }
        }
      }
      return result;
    });
    console.log("\n=== RENDERER INFO ===");
    console.log(JSON.stringify(info, null, 2));

    console.log("\n=== ALL MESSAGES ===");
    allMessages.forEach(m => console.log(m));

    // Render the final frame
    await page.evaluate(() => {
      if (window.__biome) {
        window.__biome.update(performance.now() / 1000);
      }
    });
    
    // Take screenshot after rendering
    await page.screenshot({ path: OUTPUT, type: "png", omitBackground: false });
    console.log(`Saved: ${OUTPUT}`);
  } catch (err) {
    console.error("Render error:", err.message, err.stack?.substring(0, 500));
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})();