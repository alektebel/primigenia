#!/usr/bin/env node
// Runs the SAME engine and assertions as web/gaitlab/styles4.html in Node (no DOM, no WebGL).
// node tools/gaitlab/styles4_check.cjs [body-name-substring] [--table]  (exit 1 on any failure)
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'web/gaitlab/styles4.html'),'utf8');
const core=html.slice(html.indexOf('/*CORE_BEGIN*/'),html.indexOf('/*CORE_END*/'));
const L=new Function(core+';return {buildBodies,runCheck};')();
const bodies=L.buildBodies(),only=process.argv[2]&&!process.argv[2].startsWith('--')?process.argv[2]:null;
const res=L.runCheck(bodies,only?b=>b.name.includes(only):null);
console.log(`${res.pass?'PASS':'FAIL'}: ${res.passed}/${res.cases} body x row x variant cases`);
for(const f of res.fails)console.log(f);
if(process.argv.includes('--table'))for(const r of res.table)console.log([r.body,r.row,r.variant,'Hz '+r.hz.toFixed(2),'drift '+r.driftCm.toFixed(2)+' cm','pen '+r.penMm.toFixed(1)+' mm','float '+r.float,'flight '+r.flightFrames,'forced '+r.forcedSwings,'yaw '+r.yawDeg.toFixed(0)].join(' | '));
process.exitCode=res.pass?0:1;
