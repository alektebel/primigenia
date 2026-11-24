#!/usr/bin/env node
// node tools/gaitlab/social_duel_node_check.cjs : the pure-maths self-check of the social duel core (no browser).
const C=require('../../web/gaitlab/social_duel_core.js');const r=C.selfCheck();
console.log(JSON.stringify(r.R,null,1));console.log(r.pass?'SELF-CHECK PASS':'SELF-CHECK FAIL\n'+r.fails.join('\n'));process.exit(r.pass?0:1);
