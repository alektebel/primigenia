#!/usr/bin/env node
// Runs the same engine and assertions as web/gaitlab/octopus.html in Node.  node tools/gaitlab/octopus_check.cjs [name-substring] [--table]
const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'web/gaitlab/octopus.html'),'utf8');
const core=html.slice(html.indexOf('/*CORE_BEGIN*/'),html.indexOf('/*CORE_END*/'));
const L=new Function(core+';return {CELLS,Octo,runCheck,checkCase};')();
const only=process.argv[2]&&!process.argv[2].startsWith('--')?process.argv[2]:null;
const res=L.runCheck(L.CELLS,only?s=>(s.row+' '+s.name).includes(only):null);
console.log(`${res.pass?'PASS':'FAIL'}: ${res.passed}/${res.cases} cells`);for(const f of res.fails)console.log(f);
if(process.argv.includes('--table'))for(const r of res.table)console.log(JSON.stringify(r));
process.exitCode=res.pass?0:1;
