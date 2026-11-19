// Primigenia diegetic UI mockup kit. Static drawing only: every page calls Kit.page({...}) once.
// Canvas is 1280 x 720 design units (the game's reference resolution; see docs/godot/UI-DIEGETIC.md).
// The scene (sky, hills, creatures) is a neutral placeholder; only the marks are the design.
(function () {
  const C = {
    bone: '#F4EDE0', fog: '#C9D3D4', ink: '#0E1715',
    lichen: '#86D9B0', ember: '#F0704A', ochre: '#EBCB7A', dusk: '#CDBDF2', copper: '#E09A5F', mist: '#9CC4DD',
  };
  const P = (cx, cy, rx, ry, a) => { const t = a * Math.PI / 180; return [cx + rx * Math.sin(t), cy - ry * Math.cos(t)]; };
  const f = n => n.toFixed(1);

  // Arc on an ellipse, angles in degrees clockwise from north. style: line | teeth | dots | double
  function arc(cx, cy, rx, ry, a0, a1, o = {}) {
    const col = o.color || C.bone, w = o.w || 2, op = o.op == null ? 1 : o.op, style = o.style || 'line';
    const step = 3; let pts = [];
    for (let a = a0; a <= a1 + 0.01; a += step) pts.push(P(cx, cy, rx, ry, Math.min(a, a1)));
    const line = pp => 'M' + pp.map(p => f(p[0]) + ' ' + f(p[1])).join('L');
    let out = '';
    if (style === 'dots') {
      const gap = o.gap || 9;
      for (let a = a0; a <= a1 + 0.01; a += gap) { const p = P(cx, cy, rx, ry, a); out += `<circle cx="${f(p[0])}" cy="${f(p[1])}" r="${w * 0.75}" fill="${col}" opacity="${op}"/>`; }
      return out;
    }
    out += `<path d="${line(pts)}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="${style === 'teeth' ? 'butt' : 'round'}" opacity="${op}"/>`;
    if (style === 'double') {
      const k = 1 + (o.sep || 6) / rx; let p2 = [];
      for (let a = a0 + 4; a <= a1 - 4 + 0.01; a += step) p2.push(P(cx, cy, rx * k, ry * k, a));
      out += `<path d="${line(p2)}" fill="none" stroke="${col}" stroke-width="${w * 0.7}" stroke-linecap="round" opacity="${op * 0.8}"/>`;
    }
    if (style === 'teeth') {
      const n = o.teeth || Math.max(3, Math.round((a1 - a0) / 18)), h = o.h || 7, hw = o.hw || 3.2;
      for (let i = 0; i < n; i++) {
        const a = a0 + (a1 - a0) * (i + 0.5) / n, k = 1 + h / rx;
        const p0 = P(cx, cy, rx, ry, a - hw), p1 = P(cx, cy, rx * k, ry * k, a), p2 = P(cx, cy, rx, ry, a + hw);
        out += `<path d="M${f(p0[0])} ${f(p0[1])}L${f(p1[0])} ${f(p1[1])}L${f(p2[0])} ${f(p2[1])}Z" fill="${col}" opacity="${op}"/>`;
      }
    }
    return out;
  }

  // Glyphs: 24 x 24 box, stroke only unless noted. One weight, round caps: the game's own vector language.
  const G = {
    befriend: '<circle cx="9" cy="12" r="5.6"/><circle cx="15" cy="12" r="5.6"/>',
    attack: '<path d="M6.5 4.5H17.5Q15.5 13 12 20.5Q8.5 13 6.5 4.5Z" fill="currentColor" fill-opacity=".3"/>',
    observe: '<path d="M3 12Q12 4.5 21 12Q12 19.5 3 12Z"/><circle cx="12" cy="12" r="2.3" fill="currentColor" stroke="none"/>',
    intimidate: '<path d="M5 18Q12 13.5 19 18M12 13.5V4M8.2 14.6L5 7.5M15.8 14.6L19 7.5"/>',
    eat: '<path d="M15.5 6.6A7 7 0 1 0 17.9 13.2A4 4 0 0 1 15.5 6.6Z"/>',
    dna: '<path d="M8 3C8 8 16 7 16 12C16 17 8 16 8 21M16 3C16 8 8 7 8 12C8 17 16 16 16 21M9.2 5.6H14.8M9.2 18.4H14.8"/>',
    nest: '<path d="M4 10Q12 23 20 10"/><circle cx="12" cy="9.5" r="2.4"/>',
    bite: '<path d="M4 8Q12 3 20 8M4 16Q12 21 20 16M8 7.2L9.5 11L11 6.6M13 6.6L14.5 11L16 7.2M9 16.8L10.5 13.2L12 17.3L13.5 13.2L15 16.8"/>',
    charge: '<path d="M4 6L11 12L4 18M12 6L19 12L12 18"/>',
    spit: '<path d="M16 6C19.5 10 20 15 16 17.5C12 15 12.5 10 16 6Z"/><circle cx="8.5" cy="9" r="1.1" fill="currentColor" stroke="none"/><circle cx="5" cy="6.5" r="0.9" fill="currentColor" stroke="none"/>',
    tail: '<path d="M4 18C10 19 19 16 19 10C19 6 14 5 13 8.5C12.3 11 15 12 16 10.5"/>',
    sing: '<circle cx="6" cy="12" r="1.6" fill="currentColor" stroke="none"/><path d="M10 8.5Q12.6 12 10 15.5M14 6Q18 12 14 18M18 3.8Q23 12 18 20.2"/>',
    dance: '<path d="M4 17L9 9L14 17L19 7"/><circle cx="19" cy="7" r="1.3" fill="currentColor" stroke="none"/>',
    charm: '<path d="M12 12C12 10.5 14 10.5 14 12.3C14 14.5 10 14.8 9.6 12C9.2 8.6 15.6 7.6 16.6 12C17.6 17 9 18.6 7 13C5.4 8 10 4.4 14 5"/>',
    pose: '<path d="M12 20V8M7.5 20H16.5M6 8.5Q12 2 18 8.5"/>',
    roar: '<path d="M4 12L9 7V17Z"/><path d="M12.5 9L16 7M12.5 12H18M12.5 15L16 17"/>',
    display: '<path d="M12 20V11M12 11L5 5M12 11L19 5M12 11L8 4M12 11L16 4M12 11V3.5"/>',
    guard: '<path d="M4 9Q12 3 20 9M6 13Q12 8.6 18 13"/>',
    dodgeL: '<path d="M17 6Q7 7 7 16M3.5 12.5L7 16.5L10.5 12.5"/>',
    dodgeR: '<path d="M7 6Q17 7 17 16M13.5 12.5L17 16.5L20.5 12.5"/>',
    fruit: '<circle cx="12" cy="14" r="6.2"/><path d="M12 7.8Q12.6 4.6 16 3.6"/>',
    leaf: '<path d="M4.5 19.5Q4 6 20 4Q20 18.5 4.5 19.5ZM4.5 19.5L13 11"/>',
    pounce: '<path d="M3 18Q9 3 20 10M20 10L15 9.3M20 10L18 14.6"/>',
    quill: '<path d="M5 19L19 5M19 5L13 6.5M19 5L17.5 11M8 16L5.5 13M11 13L8.5 10"/>',
    stomp: '<path d="M9 4V12Q9 14.5 12 14.5H16.5M3.5 19Q7 16.5 10.5 19M13.5 19Q17 16.5 20.5 19"/>',
    seed: '<path d="M18.8 5.9A9.2 9.2 0 1 0 20.6 8.7"/><circle cx="12" cy="12" r="2.4" fill="currentColor" stroke="none"/>',
    health: '<circle cx="12" cy="12" r="6" fill="currentColor" stroke="none"/>',
    hunger: '<path d="M16.6 5.6A8 8 0 1 0 19.4 12.4A4.6 4.6 0 0 1 16.6 5.6Z"/>',
    stamina: '<path d="M12 5V19M5 12H19"/>',
    journal: '<path d="M4 6.5Q8 4.5 12 7Q16 4.5 20 6.5V18Q16 16 12 18.5Q8 16 4 18ZM12 7V18.5"/>',
    tree: '<path d="M12 21V13M12 13Q12 8.5 6 6.5M12 13Q12 8.5 18 6.5M12 13V4.5"/><circle cx="6" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="18" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="12" cy="4" r="1.4" fill="currentColor" stroke="none"/>',
    fang: '<path d="M6.5 4.5H17.5Q15.5 13 12 20.5Q8.5 13 6.5 4.5Z"/>',
    bone: '<path d="M8.6 15.4L15.4 8.6"/><circle cx="6.3" cy="15" r="1.9"/><circle cx="9" cy="17.7" r="1.9"/><circle cx="15" cy="6.3" r="1.9"/><circle cx="17.7" cy="9" r="1.9"/>',
  };
  function glyph(name, x, y, size = 24, color = C.bone, op = 1, sw = 1.7) {
    const s = size / 24;
    return `<g transform="translate(${f(x - size / 2)} ${f(y - size / 2)}) scale(${s})" fill="none" stroke="${color}" color="${color}" stroke-width="${sw / Math.sqrt(s)}" stroke-linecap="round" stroke-linejoin="round" opacity="${op}">${G[name]}</g>`;
  }
  function text(x, y, s, o = {}) {
    const fam = o.serif ? "'Alegreya', serif" : "'Alegreya Sans', sans-serif";
    return `<text x="${x}" y="${y}" font-family="${fam}" font-size="${o.size || 15}" ${o.serif ? 'font-style="italic"' : ''} font-weight="${o.weight || 400}" fill="${o.color || C.bone}" opacity="${o.op == null ? 1 : o.op}" text-anchor="${o.anchor || 'start'}" letter-spacing="${o.ls || 0}">${s}</text>`;
  }

  // ---------- placeholder scene ----------
  const SKY = {
    midday: ['#3F7CC4', '#8FB9E0', '#DCE8EE'], dawn: ['#8FA6B8', '#C6CFD2', '#E7E4DA'], evening: ['#35508F', '#B77F78', '#F1B77C'],
  };
  const LAND = {
    midday: ['#5E8F3F', '#3E7030', '#2C5A27'], dawn: ['#7E9777', '#56775A', '#3F6048'], evening: ['#5C6B38', '#3D4F2C', '#293B24'],
  };
  function rnd(seed) { let s = seed; return () => (s = (s * 16807) % 2147483647) / 2147483647; }
  function scene(time) {
    const sk = SKY[time], ld = LAND[time], r = rnd(7);
    let o = `<defs>
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${sk[0]}"/><stop offset=".7" stop-color="${sk[1]}"/><stop offset="1" stop-color="${sk[2]}"/></linearGradient>
      <linearGradient id="land" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${ld[0]}"/><stop offset=".45" stop-color="${ld[1]}"/><stop offset="1" stop-color="${ld[2]}"/></linearGradient>
      <linearGradient id="haze" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${sk[2]}" stop-opacity="0"/><stop offset="1" stop-color="${sk[2]}" stop-opacity="${time === 'dawn' ? 0.95 : 0.6}"/></linearGradient>
      <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="14"/></filter>
      <filter id="halo" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur in="SourceAlpha" stdDeviation="2.6" result="b"/><feFlood flood-color="${C.ink}" flood-opacity=".7"/><feComposite in2="b" operator="in" result="s"/><feMerge><feMergeNode in="s"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
      <filter id="blur3"><feGaussianBlur stdDeviation="3"/></filter>
    </defs>
    <rect width="1280" height="720" fill="url(#sky)"/>`;
    const rock = time === 'evening' ? ['#6E6480', '#8A7A86'] : time === 'dawn' ? ['#A9B4B8', '#BCC5C6'] : ['#7F8FA3', '#9AA7B5'];
    o += `<path d="M0 300L90 248L170 268L260 190L330 236L420 150L500 230L600 206L690 262L790 176L880 242L960 214L1060 150L1150 232L1230 196L1280 226V340H0Z" fill="${rock[1]}"/>`;
    o += `<path d="M420 150L446 190L420 182L398 196ZM1060 150L1090 196L1060 184L1034 198ZM790 176L812 210L790 202L770 212Z" fill="#F3F1EC" opacity=".8"/>`;
    o += `<path d="M0 330L140 284L250 304L380 262L520 300L640 276L800 306L930 270L1080 300L1200 274L1280 292V360H0Z" fill="${rock[0]}"/>`;
    o += `<rect y="230" width="1280" height="120" fill="url(#haze)"/>`;
    o += `<path d="M0 338Q320 312 640 330T1280 324V720H0Z" fill="url(#land)"/>`;
    o += `<path d="M0 470Q260 420 520 452T1280 430V720H0Z" fill="${ld[2]}" opacity=".35"/>`;
    if (time === 'dawn') o += `<rect x="-40" y="300" width="1360" height="90" fill="#E9E7DE" opacity=".75" filter="url(#soft)"/><rect x="200" y="400" width="900" height="50" fill="#E9E7DE" opacity=".3" filter="url(#soft)"/>`;
    if (time === 'evening') o += `<ellipse cx="930" cy="318" rx="320" ry="60" fill="#FFC98A" opacity=".5" filter="url(#soft)"/>`;
    for (let i = 0; i < 90; i++) {
      const y = 380 + r() * 330, x = r() * 1280, h = 4 + (y - 360) / 34;
      o += `<path d="M${f(x)} ${f(y)}l${f(-h * 0.3)} ${f(-h)}M${f(x + 2)} ${f(y)}l${f(h * 0.2)} ${f(-h * 1.2)}M${f(x + 4)} ${f(y)}l${f(h * 0.5)} ${f(-h * 0.8)}" stroke="${ld[0]}" stroke-width="1.3" opacity=".55" fill="none"/>`;
    }
    return o;
  }
  // Side-view placeholder creature; (x, y) is the ground point under its centre.
  function creature(x, y, s, o = {}) {
    const col = o.color || '#B4583E', dark = o.dark || '#7E3A2A', flip = o.flip ? -1 : 1;
    let b = `<ellipse cx="${x}" cy="${y}" rx="${f(62 * s)}" ry="${f(15 * s)}" fill="#0b1410" opacity=".32"/>`;
    b += `<g transform="translate(${x} ${f(y - 48 * s)}) scale(${f(s * flip)} ${f(s)}) rotate(${o.tilt || 0})">`;
    if (o.carcass) {
      b += `<path d="M-52 40Q-30 18 20 22Q50 24 62 40Z" fill="${col}"/><path d="M40 30Q64 22 82 34Q84 44 62 44Z" fill="${col}"/><rect x="-20" y="4" width="9" height="24" rx="4" fill="${dark}" transform="rotate(-18 -16 26)"/><rect x="10" y="2" width="9" height="24" rx="4" fill="${dark}" transform="rotate(14 14 26)"/><path d="M-50 40Q-80 36 -90 46Q-70 46 -50 46Z" fill="${dark}"/>`;
    } else {
      b += `<rect x="-30" y="8" width="10" height="38" rx="5" fill="${dark}"/><rect x="18" y="8" width="10" height="38" rx="5" fill="${dark}"/>
      <path d="M-40 -8Q-78 -16 -94 4Q-70 0 -42 8Z" fill="${col}"/><ellipse cx="0" cy="0" rx="46" ry="24" fill="${col}"/>
      <path d="M28 -14Q50 -42 70 -46Q90 -48 94 -35Q92 -26 73 -24Q56 -16 46 6Z" fill="${col}"/><circle cx="80" cy="-38" r="2.4" fill="#1a1a1a"/>
      <rect x="-20" y="10" width="11" height="38" rx="5.5" fill="${col}"/><rect x="28" y="10" width="11" height="38" rx="5.5" fill="${col}"/>`;
      if (o.stripes) b += `<path d="M-18 -22L-10 20M0 -24L6 22M18 -21L22 18" stroke="${dark}" stroke-width="5" opacity=".6"/>`;
    }
    return b + '</g>';
  }

  // ---------- marks ----------
  // Ground rings are drawn as ellipses (ry = 0.32 rx: the chase camera's pitch).
  const K = 0.32;
  function groundRing(x, y, rx, o = {}) {
    const ry = rx * K, col = o.color || C.bone; let s = '';
    const frac = o.frac == null ? 1 : o.frac;
    if (frac < 1) s += arc(x, y, rx, ry, 0, 360, { color: C.bone, w: 1.3, op: 0.28 });
    if (o.segments) {
      const n = o.segments, left = o.left;
      for (let i = 0; i < n; i++) s += arc(x, y, rx, ry, i * 360 / n + 7, (i + 1) * 360 / n - 7, { color: col, w: i < left ? 2.6 : 1.3, op: i < left ? 0.95 : 0.25 });
      return s;
    }
    s += arc(x, y, rx, ry, 0, 360 * frac, { color: col, w: o.w || 2.4, op: o.op == null ? 0.95 : o.op, style: o.style, teeth: o.teeth, gap: o.gap, sep: 5, h: 6 });
    return s;
  }
  function moveMarker(x, y, rx, o = {}) {
    const ry = rx * K;
    if (o.follow) return arc(x, y, rx, ry, 0, 360, { style: 'dots', gap: 30, w: 2.2, op: 0.6 });
    return `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${f(ry)}" fill="${C.bone}" opacity=".10"/>` + arc(x, y, rx, ry, 0, 360, { w: 2.4, op: 0.92 }) +
      `<ellipse cx="${x}" cy="${y}" rx="${f(rx * 0.14)}" ry="${f(ry * 0.14)}" fill="${C.bone}" opacity=".9"/>`;
  }
  // The mode ring (screen space, around the selected creature).
  function radial(cx, cy, R, o = {}) {
    const hov = o.hover, dim = m => (hov && hov !== m ? 0.7 : 1), wd = m => (hov === m ? 4 : 2.6);
    let s = `<circle cx="${cx}" cy="${cy}" r="${R}" fill="none" stroke="${C.bone}" stroke-width="1" opacity=".16"/>`;
    const lab = (m, a, name, key) => {
      const [gx, gy] = P(cx, cy, R + 30, R + 30, a);
      let t = glyph(m, gx, gy, hov === m ? 32 : 28, COL[m], dim(m), 1.9);
      if (hov === m || o.labels) {
        const right = a < 180 && a > 0, mid = a === 0 || a === 180;
        const tx = mid ? gx + 26 : right ? gx + 26 : gx - 26, ty = gy + 3;
        t += text(tx, ty, name, { size: 17, weight: 500, anchor: (mid || right) ? 'start' : 'end' });
        t += text(tx, ty + 17, key, { size: 12.5, color: C.fog, op: 0.85, anchor: (mid || right) ? 'start' : 'end', ls: 0.6 });
      }
      return t;
    };
    if (o.carcass) {
      s += arc(cx, cy, R, R, 35, 145, { color: C.ochre, w: wd('eat'), op: dim('eat') });
      s += arc(cx, cy, R, R, -25, 25, { color: C.ochre, w: wd('observe'), style: 'dots', gap: 10, op: dim('observe') });
      s += lab('eat', 90, o.es ? 'Comer' : 'Eat', 'D'); s += lab('observe', 0, o.es ? 'Observar' : 'Observe', 'W');
      return s;
    }
    s += arc(cx, cy, R, R, 215, 325, { color: C.lichen, w: wd('befriend'), op: dim('befriend') });
    s += arc(cx, cy, R, R, 35, 145, { color: C.ember, w: wd('attack'), style: 'teeth', teeth: 6, op: dim('attack') });
    s += arc(cx, cy, R, R, -25, 25, { color: C.ochre, w: wd('observe'), style: 'dots', gap: 10, op: dim('observe') });
    s += arc(cx, cy, R, R, 155, 205, { color: C.dusk, w: wd('intimidate'), style: 'double', op: dim('intimidate') });
    s += lab('befriend', 270, o.es ? 'Amistad' : 'Befriend', 'A') + lab('attack', 90, o.es ? 'Atacar' : 'Attack', 'D') + lab('observe', 0, o.es ? 'Observar' : 'Observe', 'W') + lab('intimidate', 180, o.es ? 'Intimidar' : 'Intimidate', 'S');
    return s;
  }
  const COL = { befriend: C.lichen, attack: C.ember, observe: C.ochre, intimidate: C.dusk, eat: C.ochre };
  // Ability petals on an arc above the target. list: [{g, key, cd?, off?, liked?, disliked?, active?}]
  function petals(cx, cy, R, list, o = {}) {
    const n = list.length, span = o.span || 28, a0 = -span * (n - 1) / 2; let s = '';
    list.forEach((it, i) => {
      const [x, y] = P(cx, cy, R, R, a0 + i * span), r = o.r || 20, col = it.color || C.bone;
      const op = it.off ? 0.38 : 1;
      s += `<circle cx="${f(x)}" cy="${f(y)}" r="${r}" fill="${C.ink}" opacity="${it.active ? 0.42 : 0.24}"/>`;
      if (it.cd != null) {
        s += `<circle cx="${f(x)}" cy="${f(y)}" r="${r}" fill="none" stroke="${C.bone}" stroke-width="1.2" opacity=".25"/>`;
        s += arc(x, y, r, r, 0, 360 * (1 - it.cd), { w: 2.2, color: col, op: 0.95 });
      } else if (it.shape === 'none') {
      } else s += `<circle cx="${f(x)}" cy="${f(y)}" r="${r}" fill="none" stroke="${col}" stroke-width="${it.active ? 2.6 : 1.4}" opacity="${it.off ? 0.35 : it.active ? 1 : 0.8}" ${it.off ? 'stroke-dasharray="2.5 4"' : ''}/>`;
      s += glyph(it.g, x, y, r * 1.22, C.bone, it.cd != null ? 0.45 : op);
      if (it.key) s += text(f(x), f(y + r + 15), it.key, { size: 14.5, anchor: 'middle', color: C.bone, op: it.off ? 0.45 : 0.95, weight: 500 });
      if (it.liked) s += `<circle cx="${f(x)}" cy="${f(y - r - 7)}" r="3.4" fill="${C.lichen}"/>`;
      if (it.disliked) s += `<path d="M${f(x - 4)} ${f(y - r - 7)}h8" stroke="${C.bone}" stroke-width="2.4" stroke-linecap="round"/>`;
    });
    return s;
  }
  // Field note: the species name and one row of signs. No box.
  function fieldNote(x, y, name, o = {}) {
    let s = text(x, y, name, { serif: true, size: 23 });
    let gx = x + 9;
    if (o.diet) { s += glyph(o.diet, gx, y + 19, 16, C.fog, 0.95, 1.5); gx += 24; }
    if (o.rel != null) for (let i = 0; i < 4; i++) s += `<rect x="${gx + i * 12 - 3}" y="${y + 17.5}" width="8" height="2.6" rx="1.3" fill="${i < o.rel ? C.lichen : C.bone}" opacity="${i < o.rel ? 1 : 0.35}"/>`;
    if (o.sub) s += text(x, y + 20, o.sub, { size: 13.5, color: C.fog, op: 0.9 });
    return s;
  }
  function hud(o = {}) {
    const q = o.quiet == null ? 0.74 : o.quiet; let s = '';
    // menu seed, bottom-left
    s += `<g opacity="${o.menu ? 1 : q}">${arc(40, 680, 12, 12, 38, 350, { w: 2 })}<circle cx="40" cy="680" r="3.2" fill="${C.bone}"/></g>`;
    // vitals
    const hp = o.hp == null ? 1 : o.hp, food = o.food == null ? 0.69 : o.food, low = hp < 0.3;
    const bar = (y, v, col, op, w) => `<path d="M80 ${y}h124" stroke="${C.bone}" stroke-width="1.2" opacity=".24" stroke-linecap="round"/><path d="M80 ${y}h${f(124 * v)}" stroke="${col}" stroke-width="${w || 2.4}" opacity="${op}" stroke-linecap="round"/><path d="M204 ${y - 3}v6" stroke="${C.bone}" stroke-width="1.2" opacity=".3"/>`;
    if (low) s += `<path d="M80 674h${f(124 * hp)}" stroke="${C.ember}" stroke-width="9" opacity=".35" stroke-linecap="round" filter="url(#blur3)"/>`;
    s += `<g opacity="${low || o.hpHot ? 1 : q + 0.15}"><circle cx="68" cy="674" r="3" fill="${low ? C.ember : C.bone}"/>${bar(674, hp, low ? C.ember : C.bone, 1, low ? 3.4 : 2.4)}</g>`;
    s += `<g opacity="${o.foodHot ? 1 : q + 0.15}"><path d="M70.4 683.5A3.2 3.2 0 1 0 71.2 687.6A2 2 0 0 1 70.4 683.5Z" fill="none" stroke="${C.ochre}" stroke-width="1.4"/>${bar(686, food, C.ochre, 0.95)}</g>`;
    if (o.foodGain) s += `<path d="M${f(80 + 124 * (food - o.foodGain))} 686h${f(124 * o.foodGain)}" stroke="#FFF6D8" stroke-width="4" stroke-linecap="round"/>`;
    if (o.stamina != null) s += `<g opacity=".95"><path d="M65.5 662h5M68 659.5v5" stroke="${C.mist}" stroke-width="1.4" stroke-linecap="round"/>${bar(662, o.stamina, C.mist, 0.95)}</g>`;
    // DNA and species pips, top-left
    const dq = o.dnaHot ? 1 : q;
    s += `<g opacity="${dq}">${glyph('dna', 40, 38, 24, C.copper, 1, 1.7)}${text(56, 44, o.dna == null ? '4' : o.dna, { size: 19, weight: 500 })}`;
    const px = 56 + String(o.dna == null ? '4' : o.dna).length * 10 + 16, res = o.resolved || 0;
    for (let i = 0; i < 4; i++) s += `<circle cx="${px + i * 13}" cy="38" r="3.6" fill="${i < res ? C.copper : 'none'}" stroke="${i < res ? C.copper : C.bone}" stroke-width="1.3" opacity="${i < res ? 1 : 0.8}"/>`;
    s += '</g>';
    if (o.dnaGain) s += text(px + 4 * 13 + 4, 44, '+' + o.dnaGain, { size: 16, color: C.copper, weight: 500 });
    // compass, top centre
    s += `<g opacity="${o.compassHot ? 0.95 : q}"><defs><linearGradient id="cf" x1="0" x2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".2" stop-color="#fff"/><stop offset=".8" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient><mask id="cm"><rect x="500" y="10" width="280" height="50" fill="url(#cf)"/></mask></defs><g mask="url(#cm)">`;
    s += `<path d="M500 34H780" stroke="${C.bone}" stroke-width="1.1" opacity=".55"/>`;
    const off = o.north == null ? -38 : o.north;
    for (let i = -12; i <= 12; i++) { const x = 640 + off + i * 20; const big = ((i % 3) + 3) % 3 === 0; s += `<path d="M${x} 34v${big ? 7 : 4}" stroke="${C.bone}" stroke-width="1.1" opacity="${big ? 0.8 : 0.5}"/>`; }
    s += text(640 + off, 27, 'N', { size: 13.5, anchor: 'middle', weight: 500, ls: 0.5 });
    s += glyph('nest', 640 + (o.nest == null ? 74 : o.nest), 23, 13, C.bone, 0.95, 1.5);
    if (o.targetBearing != null) s += `<path d="M${640 + o.targetBearing} 17l4 5l-4 5l-4 -5Z" fill="${o.targetColor || C.bone}"/>`;
    s += `</g><path d="M640 38l-3.5 6h7Z" fill="${C.bone}" opacity=".9"/></g>`;
    return s;
  }
  // Guard and dodge live at the player's own feet (fight only): Q left, E right, Space in front.
  function defence(x, gy, rx) {
    const ry = rx * K, m = (g, px, py, key) => `<circle cx="${f(px)}" cy="${f(py)}" r="13" fill="${C.ink}" opacity=".3"/><circle cx="${f(px)}" cy="${f(py)}" r="13" fill="none" stroke="${C.mist}" stroke-width="1.3" opacity=".85"/>` + glyph(g, px, py, 17, C.bone) + text(f(px), f(py + 28), key, { size: 13.5, anchor: 'middle', weight: 500, op: 0.8 });
    return arc(x, gy, rx, ry, 0, 360, { w: 1.2, op: 0.3 }) + m('dodgeL', x - rx - 6, gy, 'Q') + m('dodgeR', x + rx + 6, gy, 'E') + m('guard', x, gy + ry + 12, 'Space');
  }
  function whisper(x, y, s, o = {}) { return text(x, y, s, { size: o.size || 16, color: C.bone, op: o.op == null ? 0.92 : o.op, anchor: o.anchor }); }
  function keycap(x, y, k, w) {
    w = w || Math.max(22, 12 + k.length * 8);
    return `<rect x="${x}" y="${y - 15}" width="${w}" height="21" rx="4" fill="none" stroke="${C.bone}" stroke-width="1.1" opacity=".75"/>` + text(x + w / 2, y, k, { size: 13.5, anchor: 'middle', weight: 500 });
  }

  function page(o) {
    document.title = o.title;
    const css = `@font-face{font-family:'Alegreya Sans';src:url(fonts/AlegreyaSans-Regular.ttf);font-weight:400}
      @font-face{font-family:'Alegreya Sans';src:url(fonts/AlegreyaSans-Medium.ttf);font-weight:500}
      @font-face{font-family:'Alegreya';src:url(fonts/Alegreya-Italic.ttf);font-style:italic;font-weight:400 700}
      html,body{margin:0;background:#101614}svg{display:block;width:1280px;height:720px}`;
    const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
    document.body.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720" width="1280" height="720">${scene(o.time || 'midday')}${o.world ? `<g>${o.world}</g>` : ''}${o.veil || ''}<g filter="url(#halo)">${o.marks || ''}</g>${o.over || ''}</svg>`;
  }
  window.Kit = { G, COL, defence, C, arc, glyph, text, scene, creature, groundRing, moveMarker, radial, petals, fieldNote, hud, whisper, keycap, page, P, K };
})();
