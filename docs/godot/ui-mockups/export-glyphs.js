// Writes every glyph of kit.js as a white-stroke SVG (24 x 24 box) into ./glyphs/, ready to copy to godot/ui/glyphs/.
// Run: node export-glyphs.js
const fs = require('fs'), path = require('path');
global.window = {}; global.document = {};
require('./kit.js');
const out = path.join(__dirname, 'glyphs'); fs.mkdirSync(out, { recursive: true });
for (const [name, body] of Object.entries(window.Kit.G)) {
  fs.writeFileSync(path.join(out, name + '.svg'),
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="96" height="96" fill="none" stroke="#fff" color="#fff" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${body}</svg>\n`);
}
console.log(Object.keys(window.Kit.G).length + ' glyphs');
