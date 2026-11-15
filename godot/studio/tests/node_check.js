// Cross-check against the web studio's own validator/migrator (web/studio/genome.js).
// usage: node godot/studio/tests/node_check.js   (after the godot tests wrote build/studio-godot/*.json)
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '../../..');
const Doc = require(path.join(root, 'web/studio/genome.js'));
const types = Object.fromEntries(JSON.parse(fs.readFileSync(path.join(root, 'web/studio/parts.json'))).parts.map(p => [p.id, p]));
const dir = path.join(root, 'build/studio-godot');
let fails = 0, checks = 0;
const close = (a, b, p) => {
  if (typeof a === 'number' && typeof b === 'number') return Math.abs(a - b) < 1e-6 || (console.error('num diff', p, a, b), false);
  if (Array.isArray(a) && Array.isArray(b)) return a.length === b.length && a.every((x, i) => close(x, b[i], p + '[' + i + ']')) || (console.error('arr diff', p), false);
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const ka = Object.keys(a).sort(), kb = Object.keys(b).sort();
    if (ka.join() !== kb.join()) { console.error('keys diff', p, ka.join(), kb.join()); return false; }
    return ka.every(k => close(a[k], b[k], p + '.' + k));
  }
  return a === b || (console.error('diff', p, a, b), false);
};
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.json')).sort()) {
  const text = fs.readFileSync(path.join(dir, f), 'utf8'); checks++;
  try {
    const mine = JSON.parse(text);
    const r = Doc.parse(text, types);          // the web validator must accept the Godot output unchanged
    if (f.startsWith('parsed-')) {             // Godot migration must equal the web migration of the same fixture
      const fx = path.join(root, 'tests/fixtures/studio', f.replace('parsed-', ''));
      const web = Doc.parse(fs.readFileSync(fx, 'utf8'), types).genome;
      if (!close(web, mine, f)) throw new Error('migration differs from web');
    }
    console.log('ok   ' + f);
  } catch (e) { fails++; console.error('FAIL ' + f + ': ' + e.message); }
}
console.log(`web validator cross-check: ${checks} files, ${fails} failures`);
process.exit(fails || !checks ? 1 : 0);
