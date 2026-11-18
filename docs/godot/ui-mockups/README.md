# UI mockups (diegetic redesign)

Static HTML/SVG pages for [../UI-DIEGETIC.md](../UI-DIEGETIC.md), one per state, drawn over a placeholder scene.
`kit.js` holds the palette, the glyphs and the drawing of every mark; each page is a few lines that call it.

- Open any `NN-*.html` in a browser (1280 x 720), or look at `render/*.jpg`.
- Render again: `NODE_PATH=<dir with playwright>/node_modules node render.js "$PWD" [name filter]` (software rendering, no GPU flags).
- Export the glyphs as SVG files: `node export-glyphs.js` (writes `glyphs/`).
- `fonts/`: Alegreya Sans and Alegreya Italic with their SIL Open Font Licences.
