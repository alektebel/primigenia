#!/usr/bin/env node
// Runs the actual inline solver/check in Node when Chromium is unavailable.
// Rendering and interaction still require styles_capture.cjs in a browser.
// Optional: --transitions tests abrupt slider changes; --quick tests 2 m/s only.
const fs = require('fs'), path = require('path'), vm = require('vm');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'web/gaitlab/styles.html'), 'utf8');
const js = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const model = js.slice(js.indexOf('/* GENOMES_BEGIN'), js.indexOf('let bodyIndex='));
const check = js.slice(js.indexOf('function runCheck('), js.indexOf('window.STYLELAB='));
const transitions = process.argv.includes('--transitions');
const quick = process.argv.includes('--quick');
const transitionCheck = `
const fails = []; let cases = 0, maxSlipMm = 0;
for (const b of BODIES) for (const s of STYLES) {
  const w = new Walker(b, s, false);
  for (let n = 0; n < 960; n++) {
    const speed = n < 240 ? 2 : n < 480 ? 6 : n < 720 ? 1 : 2;
    w.step(1 / 240, speed);
  }
  maxSlipMm = Math.max(maxSlipMm, w.m.slipMm);
  for (const key of ['kneeBad', 'below', 'cross', 'clampN'])
    if (w.m[key]) fails.push(b.name + '/' + s.name + ': ' + key + ' ' + w.m[key]);
  if (w.m.slipMm >= 1) fails.push(b.name + '/' + s.name + ': slip ' + w.m.slipMm);
  cases++;
}
result = { pass: !fails.length, cases, maxSlipMm, fails };`;
const context = { THREE: require(path.join(root, 'web/biome/three.min.js')), console };
vm.createContext(context);
vm.runInContext(model + '\n' + (transitions ? transitionCheck : check + '\nresult=runCheck(' + (quick ? '[2]' : '') + ');'), context, { timeout: 180000 });
const result = context.result;
const dest = path.join(root, 'docs/evidence/loco/styles');
fs.mkdirSync(dest, { recursive: true });
fs.writeFileSync(path.join(dest, transitions ? 'transitions.json' : quick ? 'quick.json' : 'table.json'), JSON.stringify(result, null, 2) + '\n');
console.log(`${result.pass ? 'PASS' : 'FAIL'}: ${transitions ? result.cases + ' slider-transition' : result.table.length + ' body/style/speed'} cases`);
for (const f of result.fails) console.log(f);
process.exitCode = result.pass ? 0 : 1;
