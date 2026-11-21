#!/usr/bin/env node
/* Turns docs/evidence/loco/gaitlab/table.json (written by capture.cjs) into Markdown tables on stdout. */
const t = require('../../docs/evidence/loco/gaitlab/table.json');
const names = { walk: 'Walk (Fr 0.3, Froude gait)', trot: 'Trot / Run (Fr 1.2)', gallop: 'Gallop (Fr 3.2)', gamefix: 'Game speed 5.1 m/s with Froude gait selection', game: 'Game speed 5.1 m/s, today (forced walk, asserted nothing)' };
for (const k of Object.keys(names)) {
  console.log(`\n### ${names[k]}\n`);
  console.log('| plan | size/legs | v m/s | Fr | gait | duty (set/meas) | stride m (set/meas) | cadence Hz | slip mm | air frac | hip y/h min-max | flags |');
  console.log('|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (const r of t[k]) {
    const fl = [r.capped ? 'stride capped by leg spacing' : '', r.kneeBad ? 'knee flip ' + r.kneeBad : '', r.drag ? 'drag ' + r.drag : ''].filter(Boolean).join(', ');
    console.log(`| ${r.plan} | ${r.col} (h ${r.h.toFixed(2)}) | ${r.v.toFixed(2)} | ${r.fr.toFixed(2)} | ${r.gait} | ${r.beta.toFixed(2)} / ${r.betaMeasured.toFixed(2)} | ${r.stride.toFixed(2)} / ${r.strideMeasured.toFixed(2)} | ${r.cadence.toFixed(2)} | ${r.slipMm.toFixed(3)} | ${r.flight.toFixed(2)} | ${r.hipMin.toFixed(2)}-${r.hipMax.toFixed(2)} | ${fl} |`);
  }
}
