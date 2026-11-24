// Island analysis: a JS port of what `terrain_cli maps` and `terrain_cli stats` compute (apps/terrain_cli.c) and of the region and route
// statistics of tools/island/maps.py. Used by the editor's validation panel (in a Worker) and by tools/island/editor_check.cjs, which
// holds it to maps.py within 1%. Float32 arithmetic follows the C (Math.fround at every step) so the slope classes agree cell for cell.
const F = Math.fround;
export const TAN30 = F(0.57735), TAN45 = F(1), TAN516 = F(1.2608), TAN75 = F(3.7321), TAN10 = F(0.17632698);
export const RIVER_NONE = 0, RIVER_STREAM = 1, RIVER_SHALLOW = 2, RIVER_DEEP = 3;
export const MAT_ROCK = 1, MAT_SCREE = 2;

// cp_terrain_slope: central differences, one-sided at the border; the tangent of the slope angle.
export function slopeMap(h, n, size) {
  const cell = F(size / n), inv = F(1 / cell), inv2 = F(1 / F(2 * cell)), out = new Float32Array(n * n);
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const k = y * n + x;
    let dx, dy;
    if (x === 0) dx = F(F(h[k + 1] - h[k]) * inv); else if (x === n - 1) dx = F(F(h[k] - h[k - 1]) * inv); else dx = F(F(h[k + 1] - h[k - 1]) * inv2);
    if (y === 0) dy = F(F(h[k + n] - h[k]) * inv); else if (y === n - 1) dy = F(F(h[k] - h[k - n]) * inv); else dy = F(F(h[k + n] - h[k - n]) * inv2);
    out[k] = F(Math.sqrt(F(F(dx * dx) + F(dy * dy))));
  }
  return out;
}

// Classes as the C: 0 sea or deep river, 1 <30 deg, 2 30..45, 3 45..51.6, 4 steeper, 5 shallow river.
export function classify(h, river, slope, n) {
  const cls = new Uint8Array(n * n);
  let land = 0;
  for (let k = 0; k < n * n; k++) {
    if (h[k] <= 0) continue;
    land++;
    const s = slope[k], rc = river ? river[k] & 3 : 0;
    let c = s < TAN30 ? 1 : s < TAN45 ? 2 : s < TAN516 ? 3 : 4;
    if (rc === RIVER_DEEP) c = 0; else if (rc === RIVER_SHALLOW) c = 5;
    cls[k] = c;
  }
  return { cls, land };
}

const OX = [1, 1, 0, -1, -1, -1, 0, 1], OY = [0, 1, 1, 1, 0, -1, -1, -1];
// The C's flood: 8-connected from the centre cell, never into class 0, never over the tangent limit.
export function flood(cls, slope, n, limit) {
  const mark = new Uint8Array(n * n), q = new Int32Array(n * n);
  let qh = 0, qt = 0, count = 0;
  const start = (n >> 1) * n + (n >> 1);
  q[qt++] = start; mark[start] = 1;
  while (qh < qt) {
    const c = q[qh++], x = c % n, y = (c / n) | 0;
    count++;
    for (let d = 0; d < 8; d++) {
      const nx = x + OX[d], ny = y + OY[d];
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
      const ni = ny * n + nx;
      if (mark[ni] || cls[ni] === 0 || slope[ni] > limit) continue;
      mark[ni] = 1; q[qt++] = ni;
    }
  }
  return { mark, count };
}

// The shaded relief of `maps`: RGBA ready for ImageData, plus the 0..255 shade.
export function relief(h, river, material, n, size) {
  const rgba = new Uint8ClampedArray(n * n * 4), shade = new Uint8Array(n * n), cell = F(size / n);
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) {
    const k = j * n + i, i0 = i ? i - 1 : i, i1 = i < n - 1 ? i + 1 : i, j0 = j ? j - 1 : j, j1 = j < n - 1 ? j + 1 : j, hh = h[k];
    const gx = (h[j * n + i1] - h[j * n + i0]) / ((i1 - i0) * cell), gy = (h[j1 * n + i] - h[j0 * n + i]) / ((j1 - j0) * cell);
    const nz = 1 / Math.sqrt(1 + 1.96 * (gx * gx + gy * gy)), nx = -1.4 * gx * nz, ny = -1.4 * gy * nz;
    let lit = nx * -0.45 + ny * -0.55 + nz * 0.70; lit = lit < 0 ? 0 : lit > 1 ? 1 : lit;
    let sh = 0.25 + 0.85 * lit, r, g, b;
    const rc = river ? river[k] & 3 : 0;
    shade[k] = 255 * (sh > 1 ? 1 : sh);
    if (hh <= 0) {
      const dp = hh < -24 ? 1 : -hh / 24;
      r = 40 - 18 * dp; g = 90 - 30 * dp; b = 130 - 25 * dp; sh = 0.85 + 0.15 * lit;
      if (hh > -12) { const a = (hh + 12) / 12; r = 40 + 40 * a; g = 140 + 70 * a; b = 175 + 20 * a; }
      else if (hh < -60) { const a = hh < -140 ? 1 : (-60 - hh) / 80; r = 24 - 14 * a; g = 70 - 40 * a; b = 112 - 50 * a; }
    } else {
      let u = hh / 420; u = u > 1 ? 1 : u;
      if (hh < 7) { r = 205; g = 190; b = 140; }
      else if (u < 0.12) { r = 96 + 40 * u / 0.12; g = 140 - 10 * u / 0.12; b = 74; }
      else if (u < 0.45) { const a = (u - 0.12) / 0.33; r = 136 + 30 * a; g = 130 + 5 * a; b = 74 + 40 * a; }
      else if (u < 0.85) { const a = (u - 0.45) / 0.40; r = 166 + 10 * a; g = 135 + 25 * a; b = 114 + 50 * a; }
      else { r = 235; g = 238; b = 242; }
      if (material && (material[k] === MAT_ROCK || material[k] === MAT_SCREE)) { r = r * 0.55 + 78; g = g * 0.55 + 70; b = b * 0.55 + 64; }
      if (rc === RIVER_DEEP) { r = 40; g = 98; b = 150; sh = 0.9; }
      else if (rc === RIVER_SHALLOW || rc === RIVER_STREAM) { r = 80; g = 150; b = 190; sh = 0.95; }
    }
    rgba[k * 4] = r * sh; rgba[k * 4 + 1] = g * sh; rgba[k * 4 + 2] = b * sh; rgba[k * 4 + 3] = 255;
  }
  return { rgba, shade };
}

// maps.py region_mask: the union of a thick polyline and a disc at each vertex, in metres; `rr` is the radius.
// PIL draws on a W x W pixel image with the terrain's size mapped onto it; here W is the grid size n (maps.py --px n).
export function regionMask(pts, rr, n, size) {
  // PIL: a disc spans its bounding box inclusive (radius + half a pixel), and a thick line is `int(2 r)` pixels wide
  const m = new Uint8Array(n * n), s = n / size, r = rr * s, rd = r + 0.5, rl = Math.trunc(r * 2) / 2 + 0.5, rd2 = rd * rd, rl2 = rl * rl;
  const P = pts.map(([x, y]) => [(x + size / 2) * s, (y + size / 2) * s]);
  let x0 = n, y0 = n, x1 = 0, y1 = 0;
  for (const [x, y] of P) { x0 = Math.min(x0, x - rd); x1 = Math.max(x1, x + rd); y0 = Math.min(y0, y - rd); y1 = Math.max(y1, y + rd); }
  x0 = Math.max(0, Math.floor(x0) - 1); y0 = Math.max(0, Math.floor(y0) - 1); x1 = Math.min(n - 1, Math.ceil(x1) + 1); y1 = Math.min(n - 1, Math.ceil(y1) + 1);
  for (let j = y0; j <= y1; j++) for (let i = x0; i <= x1; i++) {
    const px = i + 0.5, py = j + 0.5;
    let hit = false;
    for (let a = 0; a < P.length && !hit; a++) {
      const [ax, ay] = P[a];
      if ((px - ax) ** 2 + (py - ay) ** 2 <= rd2) { hit = true; break; }
      if (a + 1 < P.length) {
        const [bx, by] = P[a + 1], sx = bx - ax, sy = by - ay, l2 = sx * sx + sy * sy;
        const u = l2 ? Math.min(1, Math.max(0, ((px - ax) * sx + (py - ay) * sy) / l2)) : 0;
        if ((px - ax - u * sx) ** 2 + (py - ay - u * sy) ** 2 <= rl2) hit = true;
      }
    }
    if (hit) m[j * n + i] = 1;
  }
  for (const [x, y] of P) { const i = Math.floor(x), j = Math.floor(y); if (i >= 0 && j >= 0 && i < n && j < n) m[j * n + i] = 1; }   // a vertex always paints its own pixel
  return m;
}

const WALK = [0, 1.0, 1.5, 3.0, 0, 1.6];
// maps.py grid_paths: cheapest walk over the class map resampled (nearest) to 256 x 256, through each route's waypoints.
export function gridPaths(cls, n, routes, size) {
  const G = 256, cost = new Float32Array(G * G);
  for (let j = 0; j < G; j++) for (let i = 0; i < G; i++) cost[j * G + i] = WALK[cls[Math.min(n - 1, Math.floor((j + 0.5) * n / G)) * n + Math.min(n - 1, Math.floor((i + 0.5) * n / G))]];
  const snap = (x, y) => {
    let gx = Math.trunc((x + size / 2) / size * G), gy = Math.trunc((y + size / 2) / size * G);
    gx = Math.min(Math.max(gx, 0), G - 1); gy = Math.min(Math.max(gy, 0), G - 1);
    for (let r = 0; r <= 30; r++) for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue;
      const x2 = gx + dx, y2 = gy + dy;
      if (x2 >= 0 && x2 < G && y2 >= 0 && y2 < G && cost[y2 * G + x2] > 0) return [x2, y2];
    }
    return null;
  };
  const dist = new Float64Array(G * G), prev = new Int32Array(G * G);
  const walk = (a, b) => {   // binary heap Dijkstra, 8-connected, diagonal x 1.4142
    dist.fill(Infinity); prev.fill(-1);
    const heap = [[0, a[1] * G + a[0]]]; dist[a[1] * G + a[0]] = 0;
    const goal = b[1] * G + b[0];
    const push = (e) => { heap.push(e); let i = heap.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; i = p; } };
    const pop = () => { const top = heap[0], last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0; for (;;) { let l = 2 * i + 1, r = l + 1, m = i; if (l < heap.length && heap[l][0] < heap[m][0]) m = l; if (r < heap.length && heap[r][0] < heap[m][0]) m = r; if (m === i) break; [heap[m], heap[i]] = [heap[i], heap[m]]; i = m; } } return top; };
    while (heap.length) {
      const [dd, u] = pop();
      if (u === goal) { const out = []; let c = u; while (c >= 0) { out.push([c % G, (c / G) | 0]); c = prev[c]; } return out.reverse(); }
      if (dd > dist[u]) continue;
      const ux = u % G, uy = (u / G) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const vx = ux + dx, vy = uy + dy;
        if (vx < 0 || vy < 0 || vx >= G || vy >= G) continue;
        const c = cost[vy * G + vx]; if (c <= 0) continue;
        const nd = dd + c * (dx && dy ? 1.4142 : 1.0), v = vy * G + vx;
        if (nd < dist[v]) { dist[v] = nd; prev[v] = u; push([nd, v]); }
      }
    }
    return null;
  };
  return routes.map((rt) => {
    const pts = rt.pts.map(([x, y]) => snap(x, y));
    if (!pts.every(Boolean)) return null;
    const chain = [];
    for (let i = 0; i + 1 < pts.length; i++) { const seg = walk(pts[i], pts[i + 1]); if (!seg) return null; for (const c of seg) chain.push(c); }
    return chain.length ? chain.map(([x, y]) => [((x + 0.5) / G) * size - size / 2, ((y + 0.5) / G) * size - size / 2]) : null;
  });
}

// Everything the validation panel and tools/island/maps.py agree on. meta = {nest_r, regions[{name,kind,gate,w,pts}], routes[{name,kind,pts}]}
// in world metres (as `cp_island_meta_json` writes them). canopy(x, y) -> 0..255 is optional (forest area under the canopy mask).
export function analyse({ height, river, material, n, size, meta, canopy = null, wantImages = true }) {
  const slope = slopeMap(height, n, size), { cls, land } = classify(height, river, slope, n);
  const plain = flood(cls, slope, n, TAN516), climb = flood(cls, slope, n, TAN75);
  const reach = new Uint8Array(n * n);
  for (let k = 0; k < n * n; k++) reach[k] = plain.mark[k] ? 1 : climb.mark[k] ? 2 : 0;
  const cell = size / n, cell2 = cell * cell;
  // valley_flat, as `terrain_cli stats`: cells within 90 m of the nest centre with a slope under 10 degrees
  let flatN = 0, flatOk = 0;
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) {
    const x = F(F(F(F(i + 0.5) * F(size / n)) - F(size * 0.5))), y = F(F(F(F(j + 0.5) * F(size / n)) - F(size * 0.5)));
    if (F(F(x * x) + F(y * y)) <= 8100) { flatN++; if (slope[j * n + i] < TAN10) flatOk++; }
  }
  const regions = meta.regions.map((r) => {
    const m = regionMask(r.pts, r.w || meta.nest_r, n, size), core = regionMask(r.pts, Math.max(r.w * 0.5, 8) || meta.nest_r, n, size);
    let area = 0, landPx = 0, plainPx = 0, climbPx = 0, canopyPx = 0, cArea = 0, cPlain = 0, cClimb = 0;
    for (let k = 0; k < n * n; k++) {
      if (m[k]) {
        area++;
        if (cls[k] !== 0) { landPx++; if (canopy && canopy(((k % n) + 0.5) * cell - size / 2, (((k / n) | 0) + 0.5) * cell - size / 2) >= 128) canopyPx++; }
        if (reach[k] === 1) plainPx++; else if (reach[k] === 2) climbPx++;
      }
      if (core[k]) { cArea++; if (reach[k] === 1) cPlain++; else if (reach[k] === 2) cClimb++; }
    }
    const pct = (a, b) => Math.round(1000 * a / Math.max(1, b)) / 10;
    return { name: r.name, kind: r.kind, gate: r.gate, land_px: landPx, plain_pct: pct(plainPx, landPx), climb_only_pct: pct(climbPx, landPx),
      core_plain_pct: pct(cPlain, Math.max(1, cArea)), core_climb_only_pct: pct(cClimb, Math.max(1, cArea)), land_km2: landPx * cell2 / 1e6, canopy_km2: canopyPx * cell2 / 1e6 };
  });
  const paths = gridPaths(cls, n, meta.routes, size);
  const stats = {
    land_cells: land, land_km2: Math.round(land * cell2 / 1e4) / 100, land_km2_exact: land * cell2 / 1e6,
    plain_reach_pct: Math.round(1000 * plain.count / Math.max(1, land)) / 10, climb_reach_pct: Math.round(1000 * climb.count / Math.max(1, land)) / 10,
    valley_flat: flatN ? flatOk / flatN : 0, valley_flat_n: flatN, regions, routes: meta.routes.map((rt, i) => ({ name: rt.name, kind: rt.kind, walkable: !!paths[i] })), route_paths: paths,
  };
  const out = { cls, reach, stats };
  if (wantImages) { const r = relief(height, river, material, n, size); out.rgba = r.rgba; out.shade = r.shade; }
  return out;
}

// The A83/A95 guarantees (docs/plans/island-realism.md 3.4) as red/green rules.
export const RULES = { valleyFlat: 0.85, mesaClimbOnly: 80, forestKm2: 1.5, landMin: 16, landMax: 18 };
export function validate(stats) {
  const R = stats.regions, rules = [];
  const byKind = (k) => R.find((r) => r.kind === k);
  const nest = byKind('nest'), mesa = R.find((r) => r.gate === 1), islet = R.find((r) => r.gate === 2), forest = byKind('forest');
  rules.push({ id: 'nest-flat', label: 'Nest floor flat', ok: stats.valley_flat >= RULES.valleyFlat, value: `${(stats.valley_flat * 100).toFixed(1)}%`, target: `at least ${RULES.valleyFlat * 100}% of the 90 m disc under 10 deg` });
  const exits = stats.routes.filter((r) => r.kind === 'exit');
  rules.push({ id: 'exits', label: '4 exits walkable', ok: exits.length >= 4 && exits.every((r) => r.walkable), value: `${exits.filter((r) => r.walkable).length} of ${exits.length}`, target: '4 of 4 reach their end on walkable ground' });
  rules.push({ id: 'mesa', label: 'Mesa reachable only by climbing', ok: !!mesa && mesa.core_climb_only_pct >= RULES.mesaClimbOnly, value: mesa ? `${mesa.core_climb_only_pct.toFixed(1)}% climb-only` : 'no gate-1 region', target: `core at least ${RULES.mesaClimbOnly}% climb-only` });
  rules.push({ id: 'islet', label: 'Islet gated', ok: !!islet && islet.core_plain_pct === 0 && islet.core_climb_only_pct === 0, value: islet ? `${islet.core_plain_pct.toFixed(1)}% walk, ${islet.core_climb_only_pct.toFixed(1)}% climb` : 'no gate-2 region', target: 'core reachable by neither' });
  rules.push({ id: 'forest', label: 'Forest vale land under canopy', ok: !!forest && forest.canopy_km2 >= RULES.forestKm2, value: forest ? `${forest.canopy_km2.toFixed(2)} km2` : 'no forest region', target: `at least ${RULES.forestKm2} km2` });
  rules.push({ id: 'land', label: 'Land area', ok: stats.land_km2 >= RULES.landMin && stats.land_km2 <= RULES.landMax, value: `${stats.land_km2.toFixed(2)} km2`, target: `${RULES.landMin} to ${RULES.landMax} km2` });
  return rules;
}
