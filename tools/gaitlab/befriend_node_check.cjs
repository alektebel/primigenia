// node tools/gaitlab/befriend_node_check.cjs [rows] : runs BEFRIENDCORE.check() headless (three.min.js evaluated in a shared context)
const vm=require('vm'),fs=require('fs'),path=require('path');const w=path.resolve(__dirname,'../../web');
const ctx={console};ctx.window=ctx;vm.createContext(ctx);
for(const f of ['biome/three.min.js','gaitlab/bite2_core.js','gaitlab/befriend_core.js'])vm.runInContext(fs.readFileSync(path.join(w,f),'utf8'),ctx,{filename:f});
const r=ctx.BEFRIENDCORE.check();console.log(r.pass?'PASS':'FAIL');console.log(r.fails.join('\n'));
if(process.argv[2])console.log(JSON.stringify(r.rows,null,1));
