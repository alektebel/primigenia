# Palette variants (golden hour)

Owner feedback: "colour and palette doesn't feel right". Three art-directed alternatives, selectable with the URL
parameter `pal=A|B|C` on `web/hero/index.html` (e.g. `?t=golden&cam=vista&pal=A`). Without `pal` the page is the
current golden look, pixel-identical to before (checked on golden-mid). Geometry, terrain shape and the creature's
own colours are untouched; trees and water keep their reference colours (they pick up the new light, fog and sky).

Comparison sheet: `palettes.png` (rows: current / A / B / C; columns: golden mid / golden vista). Individual frames and
metrics: `palettes/<current|A|B|C>/golden-{mid,vista}.png`, `metrics.json`. Generated with
`node tools/hero/capture_grid.cjs --out docs/evidence/hero/palettes/<name> --only golden:mid,golden:vista [--pal <name>]`.

## Intent

- **current**: today's golden preset, for reference.
- **A "BotW"**: deeper, cooler, more saturated greens with dark roots and light tips; yellow-green and blue-green hue
  patches across the meadow; blue-violet in shadows and warm gold on lit surfaces; cool grey-blue rock warming on the
  lit faces, crisp white snow; blue aerial perspective so the red creature pops against green/blue.
- **B "Spore"**: bright, saturated, toy-like candy colours; vivid emerald meadow, warm terracotta/ochre rock with pink strata,
  strong blue sky, high contrast and cleaner shading (lower aerial density).
- **C "Current+"**: conservative; same hues, stronger value contrast (darker roots, brighter tips and lit side), less lime
  saturation in the grass, clearer warm-light / cool-shadow split, slightly deeper sky.

## Values

Linear shader colours are shown as the sRGB hex of the linear value. "x r, g, b" entries are multipliers applied in
linear light. `@n` is the mix amount. Shadow tint on toon objects (trees, props) comes from the hemisphere ground
colour and the ramp; the meadow, blades and rock have explicit shade/shadow tints.

### Light and atmosphere (display-space sRGB, as stored; linear values converted for the hex)

| item | current | A BotW | B Spore | C Current+ |
|---|---|---|---|---|
| sun colour | `#ffd2a0` | `#ffd9a2` | `#fff0cc` | `#ffd6a0` |
| hemisphere sky / ground | `#bfe0ff` / `#6f8a4a` | `#9ec2ff` / `#4c4a7a` | `#a6d8ff` / `#c9a272` | `#a8ccf8` / `#6a6a5c` |
| sky horizon | `#f2d6b3` | `#f5d1ad` | `#c7ebff` | `#f2d6b3` |
| sky mid | `#8cb8eb` | `#6ba8f2` | `#4799ff` | `#85b3ed` |
| sky top | `#296bd1` | `#1754cc` | `#0847f2` | `#2163d6` |
| sun glow | `#ff9e4d` | `#ffa857` | `#ffcc80` | `#ff9e4d` |
| aerial cool (shadow side) | `#5c96db` | `#4d85eb` | `#66adff` | `#5794e0` |
| aerial warm (sunward) | `#f5ba70` | `#fac285` | `#ffd199` | `#f5bd75` |
| aerial density | 0.00052 | 0.0006 | 0.00044 | 0.00052 |
| fog colour | `#dbe0e0` | `#9ebde6` | `#b3dbff` | `#dbe0e0` |
| global grass/rock multiplier (RGB) | 1.04, 0.95, 0.8 | 1, 0.97, 0.9 | 1, 1, 0.92 | 1.03, 0.96, 0.86 |
| toon ramp (6 texels) | 54, 54, 83, 83, 108, 108 | 44, 44, 82, 82, 112, 112 | 38, 38, 86, 86, 120, 120 | 46, 46, 82, 82, 112, 112 |

### Meadow and terrain (hex = sRGB of the linear shader value, before lighting and tone mapping)

| item | current | A BotW | B Spore | C Current+ |
|---|---|---|---|---|
| blade height multiplier low / high | 0.7 / 1.42 | 0.5 / 1.22 | 0.62 / 1.22 | 0.52 / 1.28 |
| g0: meadow base, shaded | `#5f8d36` | `#2f6937` | `#19804b` | `#558238` |
| g1: meadow base, lit | `#85a84d` | `#50893f` | `#38a45d` | `#779d4d` |
| patchY: yellow-green patch (colour, mix) | - | `#9ead3f` @0.7 | `#95c550` @0.35 | - |
| patchB: blue-green patch (colour, mix) | - | `#2c8e6f` @0.55 | `#27b595` @0.3 | - |
| tuft0: blade tint low (multiplier) | x 0.85, 0.92, 0.74 | x 0.80, 0.95, 0.80 | x 0.85, 1.00, 0.85 | x 0.82, 0.90, 0.78 |
| tuft1: blade tint high (multiplier) | x 1.10, 1.04, 0.96 | x 1.08, 1.02, 0.92 | x 1.10, 1.08, 0.92 | x 1.04, 1.02, 0.98 |
| tip: blade tip tint | - | x 1.160, 1.100, 0.840 | x 1.100, 1.160, 0.900 | - |
| lit: lit tint (multiplier) | - | x 1.140, 1.040, 0.860 | x 1.100, 1.050, 0.900 | x 1.100, 1.030, 0.900 |
| shade: shade tint (multiplier) | - | x 0.760, 0.860, 1.200 | x 0.800, 0.900, 1.160 | x 0.860, 0.920, 1.100 |
| sTint: cast-shadow tint (multiplier) | - | x 0.740, 0.800, 1.340 | x 0.760, 0.860, 1.200 | x 0.800, 0.860, 1.140 |
| r0: rock base A | `#737679` | `#6c7786` | `#a27c65` | `#6c7179` |
| r1: rock base B | `#958265` | `#898280` | `#bc995d` | `#908069` |
| r2: rock strata/erosion | `#796752` | `#736965` | `#a26186` | `#796752` |
| scree: scree | `#8e846f` | `#89857e` | `#b59e79` | `#8e846f` |
| snow: snow | `#deecf5` | `#fcfdff` | `#ffffff` | `#e5f1f9` |
| rockShade: rock shade tint | x 0.780, 0.880, 1.120 | x 0.600, 0.780, 1.280 | x 0.720, 0.700, 1.180 | x 0.680, 0.840, 1.200 |
| rockLit: rock lit tint | x 1.220, 1.080, 0.860 | x 1.380, 1.120, 0.780 | x 1.300, 1.120, 0.820 | x 1.300, 1.100, 0.840 |
| sand: sand/shore tint | - | x 1.000, 0.950, 0.900 | x 1.100, 1.000, 0.800 | - |


