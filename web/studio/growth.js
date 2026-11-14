/* Deterministic surface-growth recipes. Geometry only; no renderer or network. */
const CreatureGrowth = (() => {
  'use strict';
  const VERSION = 'cpore.growth/1';
  const families = ['horns', 'plates', 'tendrils'];
  const defaults = Object.freeze({family:'horns', seed:17, count:7, length:1,
    curve:0.45, branches:1});
  const ranges = {seed:[0,4294967295], count:[1,18], length:[0.2,2.4],
    curve:[-1,1], branches:[0,3]};

  function validate(recipe) {
    const r = {...defaults, ...recipe};
    if (!families.includes(r.family)) throw new Error('growth: unknown family');
    for (const [key, [min,max]] of Object.entries(ranges)) {
      if (!Number.isFinite(r[key]) || r[key]<min || r[key]>max)
        throw new Error(`growth.${key}: expected ${min}..${max}`);
    }
    for (const key of ['seed','count','branches'])
      if (!Number.isInteger(r[key])) throw new Error(`growth.${key}: expected integer`);
    return r;
  }

  function random(seed) {
    return () => {
      seed = (seed + 0x6D2B79F5) | 0;
      let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  const sub = (a,b) => a.map((v,i)=>v-b[i]);
  const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
  const unit = a => {const n=Math.hypot(...a)||1;return a.map(v=>v/n)};

  // Closed swept surfaces can add topology while retaining a stable recipe.
  function tube(out, center, radius, segments, sides, flatten=1) {
    const base=out.positions.length/3;
    for (let i=0;i<=segments;i++) {
      const t=i/segments, p=center(t);
      const tangent=unit(sub(center(Math.min(1,t+0.001)),center(Math.max(0,t-0.001))));
      const side=unit(cross(tangent,Math.abs(tangent[2])>.95?[1,0,0]:[0,0,1]));
      const up=unit(cross(side,tangent));
      const r=radius(t);
      for(let j=0;j<sides;j++) {
        const a=j/sides*Math.PI*2;
        for(let k=0;k<3;k++) out.positions.push(p[k]+r*(side[k]*Math.cos(a)+up[k]*Math.sin(a)*flatten));
      }
    }
    for(let i=0;i<segments;i++) for(let j=0;j<sides;j++) {
      const a=base+i*sides+j,b=base+i*sides+(j+1)%sides,c=a+sides,d=b+sides;
      out.indices.push(a,c,b,b,c,d);
    }
    for(const end of [0,1]) {
      const c=out.positions.length/3;
      out.positions.push(...center(end));
      for(let j=0;j<sides;j++) {
        const a=base+end*segments*sides+j,b=base+end*segments*sides+(j+1)%sides;
        out.indices.push(...(end?[c,b,a]:[c,a,b]));
      }
    }
  }

  function finish(out) {
    const positions=new Float32Array(out.positions),indices=new Uint32Array(out.indices);
    const normals=new Float32Array(positions.length);
    for(let i=0;i<indices.length;i+=3) {
      const a=indices[i]*3,b=indices[i+1]*3,c=indices[i+2]*3;
      const ab=[positions[b]-positions[a],positions[b+1]-positions[a+1],positions[b+2]-positions[a+2]];
      const ac=[positions[c]-positions[a],positions[c+1]-positions[a+1],positions[c+2]-positions[a+2]];
      const n=cross(ab,ac);
      for(const vertex of [a,b,c])for(let k=0;k<3;k++)normals[vertex+k]+=n[k];
    }
    for(let i=0;i<normals.length;i+=3) {
      const length=Math.hypot(normals[i],normals[i+1],normals[i+2])||1;
      normals[i]/=length;normals[i+1]/=length;normals[i+2]/=length;
    }
    return {positions,normals,indices};
  }

  function generate(input) {
    const recipe=validate(input),pieces=[];
    for(let i=0;i<recipe.count;i++) {
      // Each index has its own seed: adding density does not reroll earlier shapes.
      const rnd=random((recipe.seed^Math.imul(i+1,0x9E3779B1))>>>0);
      const out={positions:[],indices:[]};
      const length=recipe.length*(.82+rnd()*.36),lean=(rnd()-.5)*.32;
      const radius=length*(recipe.family==='plates'?.3:recipe.family==='tendrils'?.06:.12);
      if(recipe.family==='plates') {
        tube(out,t=>[lean*length*t*t,length*t,recipe.curve*length*t*t*.65],
          t=>radius*(.12+Math.sin(Math.PI*Math.pow(t,.72)))*(.99-t*.9),16,12,.18);
      } else {
        const tendril=recipe.family==='tendrils';
        const center=t=>tendril
          ? [lean*length*t+Math.sin(t*Math.PI*2)*recipe.curve*length*t*.25,
             length*(t-Math.abs(recipe.curve)*t*t*.3),
             recipe.curve*length*(1-Math.cos(t*Math.PI*1.5))*.36]
          : [lean*length*t*t,length*t,recipe.curve*length*t*t*.75];
        const profile=t=>Math.max(.003,radius*Math.pow(1-t,.85)*(1+.06*Math.sin(t*72)));
        tube(out,center,profile,tendril?28:16,10);
        for(let b=0;b<recipe.branches;b++) {
          const t=.3+b*.17,start=center(t),side=b%2?-1:1;
          const reach=length*(.25+rnd()*.22),bend=recipe.curve*.5;
          tube(out,u=>[start[0]+side*reach*u*.7,start[1]+reach*(u-u*u*.28),
            start[2]+reach*(bend*u*u+.12*u)],
            u=>Math.max(.003,profile(t)*.62*Math.pow(1-u,.8)),10,8);
        }
      }
      pieces.push({...finish(out),rootRadius:recipe.family==='plates'?radius*.12:radius,
        offset:recipe.count===1?0:i/(recipe.count-1)-.5});
    }
    return {version:VERSION,recipe,pieces};
  }
  return {VERSION,defaults,validate,generate};
})();
if(typeof module!=='undefined') module.exports=CreatureGrowth;
