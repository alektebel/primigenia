#!/usr/bin/env node
// Runs the SAME solver and assertions as web/gaitlab/styles3.html in Node (no DOM, no WebGL).
// node tools/gaitlab/styles3_check.cjs [body-name-substring] [--table]  (exit 1 on any failure)
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const THREE=require(path.join(root,'web/biome/three.min.js'));
const html=fs.readFileSync(path.join(root,'web/gaitlab/styles3.html'),'utf8');
const core=html.slice(html.indexOf('/*CORE_BEGIN*/'),html.indexOf('/*CORE_END*/'));
const L=new Function('THREE',core+';return {buildBodies,runCheck};')(THREE);
const bodies=L.buildBodies(),only=process.argv[2]&&!process.argv[2].startsWith('--')?process.argv[2]:null;
const res=L.runCheck(bodies,only?b=>b.name.includes(only):null);
console.log(`${res.pass?'PASS':'FAIL'}: ${res.passed}/${res.cases} body x row x variant cases`);
for(const f of res.fails)console.log(f);
if(process.argv.includes('--table'))for(const r of res.table)console.log([r.body,r.row,r.variant,r.gait,'Hz '+r.hz.toFixed(2),'slip '+r.slipCm.toFixed(3)+' cm','air '+r.flightMeasured.toFixed(2),'seg '+r.seg.toFixed(2),'side '+r.side.toFixed(2)].join(' | '));
process.exitCode=res.pass?0:1;
