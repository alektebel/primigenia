#!/usr/bin/env node
// Runs the SAME engine and assertions as web/gaitlab/flight.html in Node (no DOM, no WebGL).
// node tools/gaitlab/flight_check.cjs [body-id] [--table]  (exit 1 on any failure)
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'web/gaitlab/flight.html'),'utf8');
const core=html.slice(html.indexOf('/*CORE_BEGIN*/'),html.indexOf('/*CORE_END*/'));
const L=new Function(core+';return {runCheck,BODIES};')();
const only=process.argv[2]&&!process.argv[2].startsWith('--')?process.argv[2]:null;
const res=L.runCheck(only?b=>b.id===only:null);
console.log(`${res.pass?'PASS':'FAIL'}: ${res.passed}/${res.cases} body x row x variant cases`);
for(const f of res.fails)console.log(f);
if(process.argv.includes('--table'))for(const r of res.table)console.log([r.body,r.row,r.variant,r.outcome||'-','maxAlt '+r.maxAlt,'maxV '+r.maxV,'L/D '+(r.ld==null?'-':r.ld),'bank80 '+r.bank80+' deg','drift '+r.drift+' mm'].join(' | '));
process.exitCode=res.pass?0:1;
