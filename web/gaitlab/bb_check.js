'use strict';
// Self-check for the befriend-bodies lab (pure maths, runs in the page and in the capture script):
//  1. planted feet / anchored arm tips / coil contact points do not slide (< 2 cm inside any planted run, 60 fps sampling)
//  2. nothing goes through the ground (centre y - radius >= -1 cm)
//  3. beat alignment: the gesture's observable lands within +-60 ms of the beat tick (game: window +-200 ms, read at the end of the wind-up)
//  4. the target reacts on the success frame (flag flips in one frame, ears rise by > 0.3, nothing before)
(function(){
const BB=window.BB;
function check(){
  const fails=[],rows=[],STEP=1000/60;
  for(const rig of Object.values(BB.rigs))for(const act of BB.ACTS){
    const G=BB.GAME[act],W=G.W,ts=G.W+G.A,TD=rig.TD,row={body:rig.id,act};
    const runs={};let slide=0,ground=9,legErr=0,nan=false;
    const obsS=[];const gEnd=ts+BB.TAIL;
    for(let g=-BB.PRE;g<=gEnd;g+=STEP){
      const S=rig.pose(act,g);
      for(const a of S.anchors){let r=runs[a.id];
        if(a.on){if(!r)r=runs[a.id]={p:a.p.clone()};else slide=Math.max(slide,a.p.distanceTo(r.p));}else delete runs[a.id];}
      for(const n of S.nodes){const y=n.p.y-n.r;if(!isFinite(y))nan=true;ground=Math.min(ground,y);}
      legErr=Math.max(legErr,S.legErr||0);
      const T=BB.tSkel(act,g,TD,ts,rig.tbow);for(let i=0;i<4;i++)ground=Math.min(ground,T.feet[i].y-.02);
    }
    row.slide=slide;row.ground=ground;row.legErr=legErr;
    if(slide>.02)fails.push(`${rig.id}/${act}: anchor slides ${(slide*100).toFixed(1)} cm`);
    if(ground<-.01)fails.push(`${rig.id}/${act}: through the ground by ${(-ground*100).toFixed(1)} cm`);
    if(nan)fails.push(`${rig.id}/${act}: NaN in pose`);
    if(legErr>.02)fails.push(`${rig.id}/${act}: limb out of reach by ${(legErr*100).toFixed(1)} cm`);
    // beat alignment
    const mode=rig.acts[act].mode,o=g=>rig.pose(act,g).obs;let tm=null;
    if(mode==='max'){let best=-1e9;for(let g=W-250;g<=W+250;g+=2){const v=o(g);if(v>best){best=v;tm=g;}}}
    else if(mode==='land'){let seen=false;for(let g=W-320;g<=W+160;g+=2){const v=o(g);if(v>.02)seen=true;if(seen&&v<=.004){tm=g;break;}}}
    else{const ref=o(ts);for(let g=W-600;g<=W+600;g+=2)if(o(g)>=.97*ref){tm=g;break;}}
    row.beatErr=tm===null?null:tm-W;
    if(tm===null||Math.abs(tm-W)>60)fails.push(`${rig.id}/${act}: beat off by ${tm===null?'n/a':tm-W} ms (limit 60)`);
    // target reaction
    const pa=g=>BB.tSkel(act,g,TD,ts,rig.tbow).P;
    const before=pa(ts-1000/60),after=pa(ts),late=pa(ts+300),early=pa(ts-400);
    const ok=before.react===0&&after.react===1&&(late.earL-before.earL)>.3&&Math.abs(before.earL-early.earL)<.12;
    row.reacts=ok;if(!ok)fails.push(`${rig.id}/${act}: target reaction not on the success frame`);
    rows.push(row);
  }
  return {pass:fails.length===0,fails,rows};
}
BB.check=check;
})();
