'use strict';
/* forest_trees.js: procedural stand-ins for the T0 trees (docs/plans/island-realism.md section 5, step L1).
 * Everything is generated in the browser: canvas textures (bark, leaf sprays, fern fronds, hanging moss, ground) and tree geometry with a real
 * trunk taper, buttress fins, limbs, crown clumps of leaf cards in layers, moss, epiphyte ferns and rope vines, at three levels of detail.
 * Each tree also returns the crown clumps (centre, radius, extinction k) that the lab's canopy measures integrate with Beer-Lambert,
 * so the numbers shown come from the same data as the picture. Units: metres, +y up. */
const FT=(()=>{
const T=THREE;
const lerp=(a,b,t)=>a+(b-a)*t,clamp=(x,a,b)=>x<a?a:x>b?b:x,sstep=(a,b,x)=>{const t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);};
function rng32(seed){let a=seed>>>0;return()=>{a=(a+0x6D2B79F5)>>>0;let t=a;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296;};}
function hash2(x,y,s){let h=(Math.imul(x,374761393)+Math.imul(y,668265263)+Math.imul(s,1274126177))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296;}
function vnoise(x,y,s){s=s||0;const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf);
  return lerp(lerp(hash2(xi,yi,s),hash2(xi+1,yi,s),u),lerp(hash2(xi,yi+1,s),hash2(xi+1,yi+1,s),u),v);}
function fbm(x,y,o,s){let a=.5,f=1,t=0,n=0;for(let i=0;i<(o||4);i++){t+=a*vnoise(x*f,y*f,(s||0)+i*17);n+=a;a*=.5;f*=2.03;}return t/n;}
/* periodic value noise (period P lattice cells) for tileable textures */
function pnoise(x,y,P,Q,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf);
  const m=(a,p)=>((a%p)+p)%p,h=(i,j)=>hash2(m(i,P),m(j,Q),s||0);return lerp(lerp(h(xi,yi),h(xi+1,yi),u),lerp(h(xi,yi+1),h(xi+1,yi+1),u),v);}
function pfbm(x,y,P,Q,o,s){let a=.5,f=1,t=0,n=0;for(let i=0;i<o;i++){t+=a*pnoise(x*f,y*f,P*f,Q*f,(s||0)+i*31);n+=a;a*=.5;f*=2;}return t/n;}
const srgb=h=>new T.Color(h).convertSRGBToLinear();

/* ---------------- canvas textures ---------------- */
function cvs(w,h){const c=document.createElement('canvas');c.width=w;c.height=h;return c;}
function tex(cv,opt){const t=new T.CanvasTexture(cv);t.encoding=T.sRGBEncoding;t.wrapS=t.wrapT=opt&&opt.clamp?T.ClampToEdgeWrapping:T.RepeatWrapping;t.anisotropy=4;t.minFilter=T.LinearMipmapLinearFilter;return t;}
function coverage(cv,thr){const d=cv.getContext('2d').getImageData(0,0,cv.width,cv.height).data;let n=0;for(let i=3;i<d.length;i+=4)if(d[i]>thr*255)n++;return n/(d.length/4);}

function barkTex(seed,lichen){
  const W=256,H=512,cv=cvs(W,H),g=cv.getContext('2d'),im=g.createImageData(W,H),D=im.data;
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const u=x/W,v=y/H;
    const ridge=pfbm(u*10,v*2.2,10,2,4,seed);            /* long vertical ridges */
    const fine=pfbm(u*38,v*14,38,14,3,seed+5);
    const fis=Math.abs(pnoise(u*7+ridge*1.4,v*1.4,7,1,seed+9)-.5)*2;   /* fissure lines */
    let L=.42+.5*ridge+.16*(fine-.5)-.34*(1-sstep(.0,.16,fis));
    const lic=pfbm(u*5,v*3,5,3,3,seed+21);
    const li=lichen*sstep(.55,.72,lic);
    let r=92*L,gg=82*L,b=70*L;
    r=lerp(r,150*L+10,li*.8);gg=lerp(gg,165*L+10,li*.8);b=lerp(b,128*L+8,li*.8);
    const i=(y*W+x)*4;D[i]=clamp(r*1.35,0,255);D[i+1]=clamp(gg*1.35,0,255);D[i+2]=clamp(b*1.3,0,255);D[i+3]=255;
  }
  g.putImageData(im,0,0);return tex(cv);
}
const LEAF_STYLES={
  laurel:{L:66,W:25,n:9,hue:[78,102],sat:[20,34],lig:[17,27],twigs:6,curve:.5,round:0},
  cloud:{L:50,W:24,n:11,hue:[76,100],sat:[18,32],lig:[17,28],twigs:7,curve:.4,round:.4},
  broad:{L:92,W:38,n:7,hue:[82,108],sat:[22,36],lig:[18,29],twigs:4,curve:.3,round:.2},
  small:{L:40,W:19,n:13,hue:[74,100],sat:[18,30],lig:[15,25],twigs:8,curve:.6,round:.2}
};
function leafTex(style,seed){
  const S=512,cv=cvs(S,S),g=cv.getContext('2d'),st=LEAF_STYLES[style],R=rng32(seed);
  g.lineCap='round';
  const leaf=(x,y,ang,L,W,hue,sat,lig,round)=>{
    g.save();g.translate(x,y);g.rotate(ang);
    const grd=g.createLinearGradient(0,-W/2,0,W/2);
    grd.addColorStop(0,`hsl(${hue},${sat}%,${lig+7}%)`);grd.addColorStop(.5,`hsl(${hue},${sat}%,${lig}%)`);grd.addColorStop(1,`hsl(${hue+4},${sat}%,${lig-5}%)`);
    g.fillStyle=grd;g.beginPath();g.moveTo(0,0);
    g.bezierCurveTo(L*.18,-W*(.62+round*.2),L*.62,-W*(.55+round*.3),L,0);g.bezierCurveTo(L*.62,W*(.55+round*.3),L*.18,W*(.62+round*.2),0,0);g.fill();
    g.strokeStyle=`hsla(${hue-8},${sat-6}%,${lig+14}%,.75)`;g.lineWidth=Math.max(1.2,W*.045);g.beginPath();g.moveTo(1,0);g.lineTo(L*.93,0);g.stroke();
    g.strokeStyle=`hsla(${hue},${sat}%,${lig-9}%,.55)`;g.lineWidth=1;g.beginPath();g.moveTo(0,0);
    g.bezierCurveTo(L*.18,-W*(.62+round*.2),L*.62,-W*(.55+round*.3),L,0);g.stroke();
    g.restore();};
  for(let k=0;k<st.twigs;k++){
    const bx=S*(.12+.76*(k+.5)/st.twigs)+(R()-.5)*30,by=S-4,tx=S*(.5+(bx/S-.5)*1.5)+(R()-.5)*40,ty=18+R()*150;
    const cx=bx+(R()-.5)*120*st.curve,cy=by-(by-ty)*.55;
    const pt=t=>{const a=1-t;return[a*a*bx+2*a*t*cx+t*t*tx,a*a*by+2*a*t*cy+t*t*ty];};
    g.strokeStyle='#4a3b28';g.lineWidth=5;g.beginPath();let p=pt(0);g.moveTo(p[0],p[1]);for(let t=.05;t<=1.001;t+=.05){p=pt(t);g.lineTo(p[0],p[1]);}g.stroke();
    for(let i=0;i<st.n*3;i++){
      const t=.1+.9*(i/(st.n*3-1)),q=pt(t),q2=pt(Math.min(1,t+.03)),tang=Math.atan2(q2[1]-q[1],q2[0]-q[0]);
      for(const side of[-1,1]){
        if(i%2===(side>0?0:1)&&t<.93)continue;
        const sc=lerp(1,.62,t)*(.85+R()*.3),ang=tang+side*(.75+R()*.55);
        const bright=R()<.13;leaf(q[0],q[1],ang,st.L*sc,st.W*sc,bright?lerp(62,76,R()):lerp(st.hue[0],st.hue[1],R()),lerp(st.sat[0],st.sat[1],R())+(bright?10:0),lerp(st.lig[0],st.lig[1],R())+(bright?13:0),st.round);
      }
    }
    leaf(tx,ty,Math.atan2(ty-cy,tx-cx),st.L*.55,st.W*.55,st.hue[1],st.sat[0],st.lig[1],st.round);
  }
  const t=tex(cv);t.userData={coverage:coverage(cv,.4)};return t;
}
function blobTexFrom(leafTexture,base){ /* opaque canopy surface: the leaf spray over a dark leaf-shade background, so distant crowns do not turn black */
  const src=leafTexture.image,cv=cvs(src.width,src.height),g=cv.getContext('2d');g.fillStyle=base||'#1f2e16';g.fillRect(0,0,cv.width,cv.height);
  for(let i=0;i<2;i++){g.globalAlpha=.55+.45*i;g.drawImage(src,0,0);}
  const t=tex(cv);t.repeat.set(3,3);return t;}
function fernTex(seed,lush){
  const W=256,H=512,cv=cvs(W,H),g=cv.getContext('2d'),R=rng32(seed);g.lineCap='round';
  g.strokeStyle='#2c3d1c';g.lineWidth=4;g.beginPath();g.moveTo(W/2,H-2);g.quadraticCurveTo(W/2+10,H*.5,W/2,12);g.stroke();
  const NP=22;
  for(let i=0;i<NP;i++){
    const t=i/(NP-1),y=H-14-(H-30)*t,len=(W*.5)*Math.pow(Math.sin(Math.PI*(.12+.88*(1-t))),.8)*(1-.5*t*t)+10;
    for(const side of[-1,1]){
      g.save();g.translate(W/2+Math.sin(t*3)*4,y);g.scale(side,1);g.rotate(-1.15+t*.35);
      const hue=lerp(88,108,R()),lig=lerp(17,27,R())+(lush?3:0);
      g.fillStyle=`hsl(${hue},${lerp(26,40,R())}%,${lig}%)`;g.beginPath();g.moveTo(0,0);
      g.bezierCurveTo(len*.2,-len*.3,len*.7,-len*.27,len,-len*.05);g.bezierCurveTo(len*.7,len*.2,len*.2,len*.2,0,5);g.fill();
      g.strokeStyle=`hsla(${hue},40%,${lig-9}%,.8)`;g.lineWidth=1.2;g.beginPath();g.moveTo(0,0);g.lineTo(len*.95,-len*.04);g.stroke();
      g.restore();
    }
  }
  const t=tex(cv,{clamp:true});t.userData={coverage:coverage(cv,.4)};return t;
}
function mossHangTex(seed){
  const W=256,H=512,cv=cvs(W,H),g=cv.getContext('2d'),R=rng32(seed);g.lineCap='round';
  for(let k=0;k<11;k++){
    const x0=24+R()*(W-48),len=H*(.4+.55*R()),w=2.5+R()*4;
    const hue=lerp(66,92,R()),lig=lerp(22,34,R());
    for(let s=0;s<2;s++){g.strokeStyle=`hsla(${hue},${lerp(24,38,R())}%,${lig+s*5}%,${.85-s*.25})`;g.lineWidth=w*(1-s*.4);g.beginPath();g.moveTo(x0,0);
      let x=x0;for(let y=0;y<=len;y+=20){x+=(R()-.5)*10;const yy=y,ww=1-y/len*.8;g.lineTo(x+Math.sin(y*.05+k)*4,yy);}g.stroke();}
    for(let j=0;j<7;j++){g.fillStyle=`hsla(${hue+10},30%,${lig+7}%,.7)`;g.beginPath();g.ellipse(x0+(R()-.5)*14,R()*len*.9,2+R()*3,4+R()*7,0,0,7);g.fill();}
  }
  const t=tex(cv,{clamp:true});t.userData={coverage:coverage(cv,.4)};return t;
}
function grassTex(seed){
  const W=256,H=256,cv=cvs(W,H),g=cv.getContext('2d'),R=rng32(seed);
  for(let k=0;k<22;k++){
    const x0=W*(.15+.7*R()),x1=x0+(R()-.5)*W*.9,top=10+R()*H*.55,hue=lerp(70,96,R()),lig=lerp(17,30,R());
    g.fillStyle=`hsl(${hue},${lerp(24,38,R())}%,${lig}%)`;g.beginPath();g.moveTo(x0-4,H);g.quadraticCurveTo(x0+(x1-x0)*.2,(H+top)/2,x1,top);g.quadraticCurveTo(x0+(x1-x0)*.5+5,(H+top)/2,x0+4,H);g.fill();
  }
  const t=tex(cv,{clamp:true});t.userData={coverage:coverage(cv,.4)};return t;
}
/* seamless forest-floor layers drawn from shapes with wrap-around: leaf litter, wet moss cushion, trodden soil with roots and gravel. Each returns map + height (bump). */
function floorTex(kind,seed){
  const N=512,R=rng32(seed),cv=cvs(N,N),g=cv.getContext('2d'),hc=cvs(N,N),hg=hc.getContext('2d');
  const wrap=(x,y,r,fn)=>{for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){const X=x+dx*N,Y=y+dy*N;if(X<-r||Y<-r||X>N+r||Y>N+r)continue;fn(X,Y);}};
  g.fillStyle=kind==='moss'?'#2d4420':kind==='litter'?'#2b2118':'#4a3a2c';g.fillRect(0,0,N,N);hg.fillStyle='#606060';hg.fillRect(0,0,N,N);
  /* low-frequency mottling */
  const im=g.getImageData(0,0,N,N),D=im.data;
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){const u=x/N,v=y/N,m=pfbm(u*6,v*6,6,6,4,seed)-.5,i=(y*N+x)*4,k=1+m*(kind==='moss'?.7:.9);D[i]*=k;D[i+1]*=k;D[i+2]*=k;}
  g.putImageData(im,0,0);
  const leaf=(x,y,ang,L,W,fill,hh)=>{wrap(x,y,L,(X,Y)=>{
    for(const[c,h]of[[g,fill],[hg,hh]]){c.save();c.translate(X,Y);c.rotate(ang);c.fillStyle=h;c.beginPath();c.moveTo(0,0);c.bezierCurveTo(L*.2,-W*.7,L*.7,-W*.6,L,0);c.bezierCurveTo(L*.7,W*.6,L*.2,W*.7,0,0);c.fill();c.restore();}});};
  const hg_=v=>`rgb(${v},${v},${v})`;
  if(kind==='litter'){
    for(let i=0;i<2200;i++){const x=R()*N,y=R()*N,L=9+R()*20,W=L*(.34+R()*.18),t=R(),
      col=t<.42?`hsl(${24+R()*14},${30+R()*20}%,${15+R()*13}%)`:t<.7?`hsl(${40+R()*14},${28+R()*18}%,${19+R()*14}%)`:t<.88?`hsl(${72+R()*22},${20+R()*14}%,${14+R()*11}%)`:`hsl(${8+R()*10},${30+R()*18}%,${14+R()*10}%)`;
      leaf(x,y,R()*6.28,L,W,col,hg_(Math.round(95+R()*110)));}
    g.lineCap='round';hg.lineCap='round';for(let i=0;i<150;i++){const x=R()*N,y=R()*N,a=R()*6.28,L=14+R()*44;wrap(x,y,L,(X,Y)=>{for(const[c,col,w]of[[g,'#3a2c1f',1.6],[hg,hg_(210),1.6]]){c.strokeStyle=col;c.lineWidth=w;c.beginPath();c.moveTo(X,Y);c.lineTo(X+Math.cos(a)*L,Y+Math.sin(a)*L);c.stroke();}});}
  }else if(kind==='moss'){
    for(let i=0;i<5200;i++){const x=R()*N,y=R()*N,r=2+R()*7,hh=Math.round(80+R()*110),c=`hsl(${78+R()*28},${34+R()*26}%,${17+R()*20}%)`;
      wrap(x,y,r,(X,Y)=>{g.fillStyle=c;g.beginPath();g.arc(X,Y,r,0,6.3);g.fill();hg.fillStyle=hg_(hh);hg.beginPath();hg.arc(X,Y,r,0,6.3);hg.fill();});}
    for(let i=0;i<260;i++){const x=R()*N,y=R()*N,L=8+R()*14;leaf(x,y,R()*6.28,L,L*.4,`hsl(${30+R()*12},26%,${14+R()*8}%)`,hg_(120));}
  }else{
    for(let i=0;i<3500;i++){const x=R()*N,y=R()*N,r=1+R()*3.2,c=`hsl(${22+R()*16},${14+R()*14}%,${22+R()*26}%)`,hh=Math.round(80+R()*130);
      wrap(x,y,r,(X,Y)=>{g.fillStyle=c;g.beginPath();g.arc(X,Y,r,0,6.3);g.fill();hg.fillStyle=hg_(hh);hg.beginPath();hg.arc(X,Y,r,0,6.3);hg.fill();});}
    g.lineCap='round';for(let i=0;i<70;i++){const x=R()*N,y=R()*N,a=R()*6.28,L=30+R()*90,bend=(R()-.5)*60;wrap(x,y,L,(X,Y)=>{for(const[c,col,w]of[[g,'#2a1f16',2+R()*3],[hg,hg_(185),3]]){c.strokeStyle=col;c.lineWidth=w;c.beginPath();c.moveTo(X,Y);c.quadraticCurveTo(X+Math.cos(a)*L*.5+bend,Y+Math.sin(a)*L*.5,X+Math.cos(a)*L,Y+Math.sin(a)*L);c.stroke();}});}
  }
  const m1=cvs(1,1),mg=m1.getContext('2d');mg.drawImage(cv,0,0,1,1);const md=mg.getImageData(0,0,1,1).data;
  const lin=v=>Math.pow(v/255,2.2);return{map:tex(cv),height:tex(hc),mean:[lin(md[0]),lin(md[1]),lin(md[2])]};
}

/* ---------------- geometry builder ---------------- */
class GB{
  constructor(){this.p=[];this.n=[];this.uv=[];this.c=[];this.i=[];}
  v(x,y,z,nx,ny,nz,u,v,r,g,b){this.p.push(x,y,z);this.n.push(nx,ny,nz);this.uv.push(u,v);this.c.push(r,g,b);return this.p.length/3-1;}
  tri(a,b,c){this.i.push(a,b,c);}
  get tris(){return this.i.length/3;}
  geo(){const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(this.p,3));g.setAttribute('normal',new T.Float32BufferAttribute(this.n,3));
    g.setAttribute('uv',new T.Float32BufferAttribute(this.uv,2));g.setAttribute('color',new T.Float32BufferAttribute(this.c,3));g.setIndex(this.i);g.computeBoundingSphere();g.computeBoundingBox();return g;}
}
const V3=(x,y,z)=>new T.Vector3(x,y,z);
/* tube along pts. rad(t,theta)->radius, col(t,theta,y)->[r,g,b]; ring vertices are shared across a seam so UVs wrap cleanly. */
function tube(gb,pts,rad,sides,o){
  o=o||{};const n=pts.length,col=o.col||(()=>[1,1,1]),uvs=o.uvScale||1,uvu=o.uvU||1;
  const tans=pts.map((p,i)=>pts[Math.min(i+1,n-1)].clone().sub(pts[Math.max(i-1,0)]).normalize());
  let ref=Math.abs(tans[0].y)<.9?V3(0,1,0):V3(1,0,0),u=ref.clone().sub(tans[0].clone().multiplyScalar(ref.dot(tans[0]))).normalize();
  const rings=[];let len=0;
  for(let i=0;i<n;i++){
    if(i>0){u=u.clone().sub(tans[i].clone().multiplyScalar(u.dot(tans[i]))).normalize();len+=pts[i].distanceTo(pts[i-1]);}
    const w=new T.Vector3().crossVectors(tans[i],u),t=n>1?i/(n-1):0,ring=[];
    for(let s=0;s<=sides;s++){const th=2*Math.PI*s/sides,dir=u.clone().multiplyScalar(Math.cos(th)).addScaledVector(w,Math.sin(th)),r=rad(t,th,pts[i].y);
      ring.push({p:pts[i].clone().addScaledVector(dir,r),d:dir,th,t,len,y:pts[i].y});}
    rings.push(ring);
  }
  const base=gb.p.length/3;
  for(let i=0;i<n;i++)for(let s=0;s<=sides;s++){
    const a=rings[i][s],pa=rings[Math.max(i-1,0)][s],pb=rings[Math.min(i+1,n-1)][s];
    const sa=rings[i][s===sides?1:s+1],sb=rings[i][s===0?sides-1:s-1];
    const dt=pb.p.clone().sub(pa.p),dth=sa.p.clone().sub(sb.p);let nn=new T.Vector3().crossVectors(dth,dt).normalize();if(nn.dot(a.d)<0)nn.negate();if(!isFinite(nn.x))nn=a.d.clone();
    const c=col(a.t,a.th,a.y);gb.v(a.p.x,a.p.y,a.p.z,nn.x,nn.y,nn.z,s/sides*uvu,a.len*uvs,c[0],c[1],c[2]);
  }
  for(let i=0;i<n-1;i++)for(let s=0;s<sides;s++){const a=base+i*(sides+1)+s,b=a+1,c=a+sides+1,d=c+1;gb.tri(a,c,b);gb.tri(b,c,d);}
  return len;
}
/* a quad card. nrm(vx,vy,vz)->[nx,ny,nz] gives per-vertex normals (leaf clumps use sphere normals). */
function card(gb,c,right,up,w,h,nrm,col,uv0,uv1,bend,anchorBottom){
  const hw=w/2,y0=anchorBottom?0:-h/2,y1=anchorBottom?h:h/2,b=bend||0;
  const corners=[[-hw,y0],[hw,y0],[hw,y1],[-hw,y1]],uvs=[[uv0[0],uv0[1]],[uv1[0],uv0[1]],[uv1[0],uv1[1]],[uv0[0],uv1[1]]];
  const ids=[];
  for(let k=0;k<4;k++){
    const [sx,sy]=corners[k];const bw=(sy-y0)/(y1-y0);
    const p=c.clone().addScaledVector(right,sx).addScaledVector(up,sy);
    if(b)p.y-=b*bw*bw*h*.5;
    const n=nrm(p.x,p.y,p.z);ids.push(gb.v(p.x,p.y,p.z,n[0],n[1],n[2],uvs[k][0],uvs[k][1],col[0],col[1],col[2]));
  }
  gb.tri(ids[0],ids[1],ids[2]);gb.tri(ids[0],ids[2],ids[3]);
}
function ico(gb,c,r,detail,col,rnd,sq){
  const g=new T.IcosahedronGeometry(1,detail),pos=g.attributes.position,idx=g.index;
  const vs=[];for(let i=0;i<pos.count;i++)vs.push(V3(pos.getX(i),pos.getY(i),pos.getZ(i)));
  const base=gb.p.length/3,sy=sq||1;
  for(let i=0;i<vs.length;i++){const d=vs[i],k=1+(rnd?(rnd()-.5)*.28:0),p=c.clone().add(V3(d.x*r*k,d.y*r*k*sy,d.z*r*k));
    const sh=.62+.38*sstep(-.6,.9,d.y),cc=col(d,sh);gb.v(p.x,p.y,p.z,d.x,d.y,d.z,.5+Math.atan2(d.z,d.x)/6.283,.5+Math.asin(d.y)/3.1416,cc[0],cc[1],cc[2]);}
  if(idx)for(let i=0;i<idx.count;i+=3)gb.tri(base+idx.getX(i),base+idx.getX(i+1),base+idx.getX(i+2));
  else for(let i=0;i<vs.length;i+=3)gb.tri(base+i,base+i+1,base+i+2);
  g.dispose();
}

/* ---------------- trees ----------------
 * P: H (m), dbh (m at 1.3 m), taper 0..1, buttA (fin height factor), buttN (fins), buttH (m), firstBr (m), crownR (m), nLimbs, clumpR (m),
 * nClump, layers, lean, moss 0..1, epi 0..1 (epiphyte ferns), hang 0..1 (hanging moss), vines (count), vineMoss, leaf style, tint [r,g,b], fruit 0..1
 * lod: 0 full, 1 reduced, 2 distant blobs. */
const BARK_BASE=[.34,.29,.24];
function treeParts(seed,P,lod){
  const R=rng32(seed*7919+13),bark=new GB(),leaf=new GB(),moss=new GB(),fruit=new GB(),epi=new GB();
  const H=P.H,Ht=H*.93,r0=P.dbh/2/(1-P.taper*Math.pow(1.3/Ht,1.1))*(1-0.0);
  const NS=[0,12,6,4][lod+1]||12,NR=[0,16,9,5][lod+1]||16,SIDES=NS,NRING=NR;
  const lx=(R()-.5)*2*P.lean,lz=(R()-.5)*2*P.lean,wobA=P.H*.03,wp=R()*10,wq=R()*10,fin0=R()*6.28;
  const trunkAt=y=>{const t=y/Ht;return V3(lx*Ht*t*t+wobA*(Math.sin(wp+t*5)+.45*Math.sin(wq+t*13))*Math.min(1,t*3),y,lz*Ht*t*t+wobA*(Math.cos(wp*1.3+t*4)+.45*Math.cos(wq*.7+t*11))*Math.min(1,t*3));};
  const radAt=(y,th)=>{const t=clamp(y/Ht,0,1);let r=r0*lerp(1,1-P.taper,Math.pow(t,1.1))*(1+.28*Math.exp(-y/.9));
    const fin=Math.pow(Math.max(0,Math.cos(P.buttN*(th+fin0))),2.4);r*=1+P.buttA*Math.exp(-y/Math.max(.3,P.buttH))*fin;
    return r*(1+.025*Math.sin(th*5+y*1.7+wp));};
  const barkCol=(y,th,wy)=>{ /* moss on the lower trunk and on fins, dirty at the root */
    const fin=Math.pow(Math.max(0,Math.cos(P.buttN*(th+fin0))),2.4);
    const m=clamp(P.moss*(.25+.9*(1-sstep(1,Ht*.75,y))*(.55+.6*vnoise(th*2+wp,y*.35,seed)))+P.moss*.4*fin*Math.exp(-y/4),0,1);
    const sh=lerp(.6,1,sstep(0,Ht*.55,y)),mc=[.17,.29,.08];
    return[lerp(BARK_BASE[0],mc[0],m)*sh*2,lerp(BARK_BASE[1],mc[1],m)*sh*2,lerp(BARK_BASE[2],mc[2],m)*sh*2];};
  /* trunk */
  const ys=[];for(let i=0;i<=NRING;i++)ys.push(Ht*Math.pow(i/NRING,lod===0?1.7:1.5));
  const pts=ys.map(trunkAt);
  tube(bark,pts,(t,th,y)=>radAt(y,th),SIDES,{uvScale:.4,uvU:2,col:(t,th,y)=>barkCol(t,th,y)});
  /* limbs and clumps */
  const clumps=[],limbPaths=[];
  const topY=Ht*.97,nL=P.nLimbs;let ga=R()*6.28;
  const crownH=Math.max(2,Ht*.96-P.firstBr);
  for(let k=0;k<nL;k++){
    const fl=Math.pow((k+.5)/nL,P.layers>1?.8:.7),yb=P.firstBr+crownH*(.04+.9*fl)*.88;
    ga+=2.399+(R()-.5)*.5;
    const prof=Math.sin(Math.PI*clamp(.18+.8*(yb-P.firstBr)/crownH,0,1)*.92+.2)*.85+.15;
    const L=P.crownR*clamp(prof,.35,1)*(.75+R()*.4),el=lerp(.35,.85,R())*(1-.35*fl);
    const dh=V3(Math.cos(ga),0,Math.sin(ga)),a=trunkAt(yb);
    const tip=a.clone().addScaledVector(dh,L).add(V3(0,L*Math.tan(el)*.55+.4,0));
    const mid=a.clone().addScaledVector(dh,L*.5).add(V3(0,L*.35*Math.sin(el)+.2,0));
    const wob=L*.16,path=[a,a.clone().lerp(mid,.55).add(V3((R()-.5)*wob,L*.08,(R()-.5)*wob)),mid.clone().add(V3((R()-.5)*wob*1.6,0,(R()-.5)*wob*1.6)),tip.clone().addScaledVector(dh,-L*.08).add(V3(0,-L*.06*R(),0))];path.push(tip);
    limbPaths.push(path);
    const rb=Math.max(.06,radAt(yb,0)*.5);
    if(lod<2)tube(bark,limbPaths[k],(t)=>Math.max(.035,rb*(1-.88*t)),lod===0?7:4,{uvScale:.4,uvU:1,col:(t)=>[.3*(1-.2*t),.27,.22]});
    const cr=P.clumpR*(.9+R()*.3);
    clumps.push({x:tip.x,y:tip.y,z:tip.z,r:cr,limb:k});
    if(nL>3||lod===0)clumps.push({x:mid.x+dh.x*L*.15,y:mid.y+cr*.25,z:mid.z+dh.z*L*.15,r:cr*.78,limb:k});
    if(L>3.2){const q=a.clone().lerp(mid,.55);clumps.push({x:q.x,y:q.y+cr*.2,z:q.z,r:cr*.6,limb:k});}
  }
  const topP=trunkAt(topY);clumps.push({x:topP.x,y:topP.y+P.clumpR*.15,z:topP.z,r:P.clumpR*1.05,limb:-1});
  /* a few extra clumps fill holes in the crown so it closes like a laurel crown */
  for(let k=clumps.length;k<P.nClump;k++){
    const th=R()*6.28,rr=Math.sqrt(R())*P.crownR*.8,yy=P.firstBr+crownH*(.3+.65*R());
    const c=trunkAt(Math.min(yy,Ht));clumps.push({x:c.x+Math.cos(th)*rr,y:yy,z:c.z+Math.sin(th)*rr,r:P.clumpR*(.7+R()*.35),limb:-1});
  }
  /* foliage */
  const tint=P.tint||[1,1,1];
  const cardArea=1.55*1.55,alpha=P.alpha||.5;
  for(const c of clumps){
    const csz=P.cardSize,nc0=Math.round(34*Math.pow(c.r/2.4,2)*Math.pow(1.5/csz,2)*(P.leafDensity||1));
    c.lai=nc0*csz*csz*alpha/(Math.PI*c.r*c.r);c.k=.5*c.lai/(4*c.r/3);
    const ctr=V3(c.x,c.y,c.z);
    if(lod===2)continue;
    const nc=lod===0?nc0:Math.max(8,Math.round(nc0*.26)),cs=P.cardSize*(lod===0?1:1.9);
    for(let j=0;j<nc;j++){
      let d=V3(R()-.5,(R()-.5)*.9+.12,R()-.5).normalize();
      const rd=.5+.5*Math.sqrt(R());const p=ctr.clone().addScaledVector(d,c.r*rd*(d.y<-.3?.65:1));
      const nrm0=d.clone();
      const ref=Math.abs(nrm0.y)>.9?V3(1,0,0):V3(0,1,0),rt=new T.Vector3().crossVectors(nrm0,ref).normalize(),upv=new T.Vector3().crossVectors(rt,nrm0).normalize();
      const roll=R()*6.28,cr=Math.cos(roll),sr=Math.sin(roll),rt2=rt.clone().multiplyScalar(cr).addScaledVector(upv,sr),up2=upv.clone().multiplyScalar(cr).addScaledVector(rt,-sr);
      const depth=rd,shade=(.5+.5*depth)*(.72+.38*sstep(-.5,.9,d.y))*(.9+.2*R());
      const col=[tint[0]*shade*1.2,tint[1]*shade*1.2,tint[2]*shade*1.2];
      const w=cs*(.8+R()*.45);
      card(leaf,p,rt2,up2,w,w,(x,y,z)=>{const q=V3(x-c.x,y-c.y,z-c.z).normalize();q.lerp(V3(0,1,0),.18).normalize();return[q.x,q.y,q.z];},col,[R()<.5?0:1,0],[R()<.5?1:0,1],0,false);
    }
    if(P.fruit&&lod===0&&R()<P.fruit){
      const nf=2+Math.floor(R()*4);for(let f=0;f<nf;f++){const d=V3(R()-.5,-.1-R()*.4,R()-.5).normalize(),p=ctr.clone().addScaledVector(d,c.r*.82);
        ico(fruit,p,.13+R()*.05,1,(dd,sh)=>[.9*sh+.12,.28*sh,.07],null,1);}
    }
  }
  if(lod===2){ /* distant tree: a flattened crown ellipsoid that bounds the real clumps, plus one cap bump */
    let cx=0,cy=0,cz=0,top=0;for(const c of clumps){cx+=c.x;cy+=c.y;cz+=c.z;top=Math.max(top,c.y+c.r);}cx/=clumps.length;cy/=clumps.length;cz/=clumps.length;
    let rh=0;for(const c of clumps)rh=Math.max(rh,Math.hypot(c.x-cx,c.z-cz)+c.r);const lo=Math.min(...clumps.map(c=>c.y-c.r*.8)),hh=(top-lo)*.5;
    const colf=(d,sh)=>[.16*tint[0]*sh*1.55,.25*tint[1]*sh*1.55,.1*tint[2]*sh*1.55];
    ico(leaf,V3(cx,(top+lo)*.5,cz),rh*.92,1,colf,R,Math.max(.3,hh/(rh*.92)));
    ico(leaf,V3(cx+(R()-.5)*rh*.3,top-rh*.28,cz+(R()-.5)*rh*.3),rh*.5,0,colf,R,.75);
  }
  /* moss shelves, hanging moss and epiphyte ferns on limbs (full detail only) */
  const mossStrips=[];
  if(lod===0){
    for(let k=0;k<limbPaths.length;k++){
      const lp=limbPaths[k];
      const nm=Math.round(P.hang*(3+R()*3));
      for(let j=0;j<nm;j++){const t=.2+.7*R(),a=lp[Math.min(3,Math.floor(t*4))],b=lp[Math.min(4,Math.floor(t*4)+1)],f=t*4-Math.floor(t*4),p=a.clone().lerp(b,f);
        const h=1.2+R()*2.6,w=.55+R()*.5;
        card(moss,p.clone().add(V3(0,-.1,0)),V3(Math.cos(R()*6.28),0,Math.sin(R()*6.28)),V3(0,1,0),w,h,()=>[0,1,0],[.62,.7,.5].map(v=>v*(.55+P.moss*.4)),[0,1],[1,0],.0,false);
        mossStrips.push(1);}
      const ne=Math.round(P.epi*(1+R()*2.5));
      for(let j=0;j<ne;j++){const t=.15+.6*R(),a=lp[Math.min(3,Math.floor(t*4))],b=lp[Math.min(4,Math.floor(t*4)+1)],f=t*4-Math.floor(t*4),p=a.clone().lerp(b,f).add(V3(0,.12,0));
        const nf=5+Math.floor(R()*3);for(let q=0;q<nf;q++){const ang=q/nf*6.28+R()*.4,e=.5+R()*.5,len=.7+R()*.7;
          const dir=V3(Math.cos(ang)*Math.cos(e*.9),Math.sin(e),Math.sin(ang)*Math.cos(e*.9)),side=new T.Vector3().crossVectors(dir,V3(0,1,0)).normalize();
          card(epi,p,side,dir,len*.5,len,()=>[0,1,0],[.8,.9,.7],[.0,.0],[1,1],.25,true);}
      }
    }
  }
  /* vines */
  let vineReach=99;
  if(lod===0&&P.vines>0){
    for(let v=0;v<P.vines;v++){
      const lp=limbPaths[Math.floor(R()*limbPaths.length)],t=.25+.6*R(),a=lp[Math.min(3,Math.floor(t*4))].clone().lerp(lp[Math.min(4,Math.floor(t*4)+1)],t*4-Math.floor(t*4));
      const down=Math.max(3,a.y-(R()<.55?R()*3:R()*(a.y*.6))),pp=[];const drift=V3((R()-.5)*1.6,0,(R()-.5)*1.6),n=7;
      for(let i=0;i<=n;i++){const s=i/n;pp.push(V3(a.x+drift.x*s+Math.sin(s*5+v)*.25,a.y-(a.y-(a.y-down))*s,a.z+drift.z*s+Math.cos(s*4+v)*.25));}
      const endY=pp[n].y;if(endY<vineReach)vineReach=endY;
      const th=.035+R()*.03*(1+P.vineMoss);tube(bark,pp,(s)=>th*(1+.5*(1-s))*(1+.0),4,{uvScale:1,col:()=>[.2*(1-P.vineMoss*.4)+.02,.2+.1*P.vineMoss,.1+.02]});
      if(P.vineMoss>.2){for(let i=1;i<n;i+=2)card(moss,pp[i],V3(1,0,0),V3(0,1,0),.5,.7,()=>[0,1,0],[.7,.9,.6],[0,.2],[.5,.8],0,false);}
    }
  }
  return{bark:bark.tris?bark.geo():null,leaf:leaf.tris?leaf.geo():null,moss:moss.tris?moss.geo():null,fruit:fruit.tris?fruit.geo():null,epi:epi.tris?epi.geo():null,
    meta:{H,dbh:P.dbh,firstBr:P.firstBr,clumps,vineReach,trunkR:r0,Ht,buttA:P.buttA,tris:bark.tris+leaf.tris+moss.tris,
          triParts:[bark.tris,leaf.tris,moss.tris],crownR:P.crownR,lean:[lx,lz]}};
}

/* ---------------- undergrowth ---------------- */
function fernParts(seed,o,lod){ /* rosette of arching fronds; o: n, len, w, up (elevation) */
  const R=rng32(seed*31+7),gb=new GB(),n=lod===0?o.n:Math.max(5,Math.round(o.n*.55)),seg=lod===0?3:2;
  for(let i=0;i<n;i++){
    const ang=i/n*6.28+(R()-.5)*.4,el=lerp(o.el0,o.el1,R()),L=o.len*(.7+R()*.5),w=L*(o.wr||.34);
    const dir=V3(Math.cos(ang),0,Math.sin(ang)),side=V3(-Math.sin(ang),0,Math.cos(ang));
    const base=V3(dir.x*.05,0,dir.z*.05),ids=[];
    for(let s=0;s<=seg;s++){const t=s/seg,hh=Math.sin(el)*L*t-L*.55*t*t*Math.cos(el)*(1+o.droop),rr=Math.cos(el)*L*t+.04;
      const c=base.clone().addScaledVector(dir,rr);c.y=hh+.02;const ww=w*Math.sin(Math.PI*(.18+.62*t))*.5*(t>.9?.5:1)+w*.05;
      const nn=V3(-dir.x*Math.sin(el)*.2,1,-dir.z*Math.sin(el)*.2).normalize();
      const sh=.55+.45*t*(o.shade||1);
      for(const sd of[-1,1]){const p=c.clone().addScaledVector(side,sd*ww);ids.push(gb.v(p.x,p.y,p.z,nn.x,nn.y,nn.z,sd<0?0:1,t,sh,sh,sh));}}
    for(let s=0;s<seg;s++){const a=ids[s*2],b=ids[s*2+1],c=ids[s*2+2],d=ids[s*2+3];gb.tri(a,b,c);gb.tri(b,d,c);}
  }
  return{g:gb.geo(),tris:gb.tris};
}
function shrubParts(seed,o,lod){
  const R=rng32(seed*17+3),stem=new GB(),leaf=new GB(),n=lod===0?o.n:Math.max(3,Math.round(o.n*.6));
  for(let i=0;i<n;i++){
    const a=R()*6.28,rr=Math.sqrt(R())*o.r,h=o.h*(.5+.5*R()),c=V3(Math.cos(a)*rr,h,Math.sin(a)*rr);
    if(lod===0)tube(stem,[V3(Math.cos(a)*rr*.15,0,Math.sin(a)*rr*.15),V3(Math.cos(a)*rr*.6,h*.55,Math.sin(a)*rr*.6),c],t=>.012*(1-.6*t),4,{col:()=>[.5,.4,.3]});
    const nc=lod===0?16:7;
    for(let j=0;j<nc;j++){const d=V3(R()-.5,R()*.7-.15,R()-.5).normalize(),p=c.clone().addScaledVector(d,o.cr*(.35+.65*R()));
      const ref=V3(0,1,0),rt=new T.Vector3().crossVectors(d,ref).normalize(),up=new T.Vector3().crossVectors(rt,d).normalize(),sh=.55+.55*R();
      const cs=o.cs*(.7+.5*R())*(lod===0?1:1.5);
      card(leaf,p,rt,up,cs,cs,(x,y,z)=>{const q=V3(x-c.x,y-c.y,z-c.z).normalize();q.y+=.35;q.normalize();return[q.x,q.y,q.z];},[sh*o.tint[0],sh*o.tint[1],sh*o.tint[2]],[0,0],[1,1],0,false);}
  }
  return{bark:stem.tris?stem.geo():null,leaf:leaf.geo(),tris:stem.tris+leaf.tris};
}
function grassParts(seed,lod){
  const R=rng32(seed*13+1),gb=new GB(),n=lod===0?7:4;
  for(let i=0;i<n;i++){const a=i/n*3.14+R()*.4,w=.5+R()*.5,h=.45+R()*.45,rt=V3(Math.cos(a),0,Math.sin(a)),c=V3((R()-.5)*.25,0,(R()-.5)*.25);
    card(gb,c,rt,V3(0,1,0),w,h,()=>[0,1,0],[.9,.95,.85],[0,0],[1,1],.35,true);}
  return{g:gb.geo(),tris:gb.tris};
}
function treeFernParts(seed,o,lod){
  const R=rng32(seed*23+9),bark=new GB(),leaf=new GB(),H=o.H;
  const pts=[];for(let i=0;i<=(lod===0?6:3);i++){const t=i/(lod===0?6:3);pts.push(V3(o.lean*t*t*H*.2,H*t,0));}
  tube(bark,pts,(t)=>o.r*(1-.35*t)*(1+.35*Math.exp(-t*12)),lod===0?7:5,{uvScale:.5,uvU:2,col:(t)=>[.6-.2*t,.5-.18*t,.38]});
  const top=pts[pts.length-1],nf=lod===0?13:8;
  for(let i=0;i<nf;i++){
    const ang=i/nf*6.28+R()*.3,el=lerp(.1,1.0,R()),L=o.fl*(.8+R()*.4),w=L*.3,dir=V3(Math.cos(ang),0,Math.sin(ang)),side=V3(-Math.sin(ang),0,Math.cos(ang));
    const ids=[],seg=3;
    for(let s=0;s<=seg;s++){const t=s/seg,c=top.clone().addScaledVector(dir,Math.cos(el)*L*t+.1);c.y+=Math.sin(el)*L*t-L*.7*t*t*(.6+.5*(1-el));
      const ww=w*Math.sin(Math.PI*(.2+.6*t))*.5+.03,sh=.55+.45*t;for(const sd of[-1,1]){const p=c.clone().addScaledVector(side,sd*ww);ids.push(leaf.v(p.x,p.y,p.z,0,1,0,sd<0?0:1,t,sh,sh,sh));}}
    for(let s=0;s<seg;s++){const a=ids[s*2],b=ids[s*2+1],c=ids[s*2+2],d=ids[s*2+3];leaf.tri(a,b,c);leaf.tri(b,d,c);}
  }
  return{bark:bark.geo(),leaf:leaf.geo(),tris:bark.tris+leaf.tris,meta:{H,r:o.r,crown:[top.x,top.y,top.z,o.fl*.7]}};
}
function logParts(seed,o,lod){
  const R=rng32(seed*29+5),gb=new GB(),moss=new GB(),L=o.L,n=lod===0?8:4,pts=[];
  for(let i=0;i<=n;i++)pts.push(V3((i/n-.5)*L,(vnoise(i*.7,seed,3)-.5)*.2,(vnoise(i*.9,seed,5)-.5)*.3));
  tube(gb,pts,(t,th)=>o.r*(1-.3*t)*(1+.06*Math.sin(th*3+t*9))+(t<.04?-.0:0),lod===0?8:5,{uvScale:.5,uvU:2,col:(t,th,y)=>{const top=Math.max(0,Math.sin(th)),m=clamp(o.moss*(.35+.65*top),0,1);return[lerp(.36,.1,m)*1.5,lerp(.3,.22,m)*1.5,lerp(.24,.07,m)*1.5];}});
  if(lod===0)for(let k=0;k<Math.round(o.moss*5);k++){const t=R(),i=Math.floor(t*(n-1)),p=pts[i].clone().lerp(pts[i+1],t*(n-1)-i).add(V3(0,o.r*.8,0));
    card(moss,p,V3(1,0,0),V3(0,0,1),.8,.8,()=>[0,1,0],[.9,1,.8],[.0,.0],[1,.15],0,false);}
  return{bark:gb.geo(),moss:moss.tris?moss.geo():null,tris:gb.tris+moss.tris,meta:{L,r:o.r}};
}
function rockParts(seed,o,lod){
  const R=rng32(seed*37+11),gb=new GB();
  ico(gb,V3(0,o.r*.35,0),o.r,lod===0?2:1,(d,sh)=>{const up=clamp(d.y,0,1),m=o.moss*sstep(.15,.75,up);const g=.34*sh;return[lerp(g*.95,.1,m)*1.5,lerp(g,.2,m)*1.5,lerp(g*.9,.07,m)*1.5];},()=>R(),.62);
  return{g:gb.geo(),tris:gb.tris,meta:{r:o.r}};
}

return{rng32,hash2,vnoise,fbm,pnoise,pfbm,lerp,clamp,sstep,srgb,GB,tube,card,ico,V3,blobTexFrom,
  barkTex,leafTex,fernTex,mossHangTex,grassTex,floorTex,
  treeParts,fernParts,shrubParts,grassParts,treeFernParts,logParts,rockParts};
})();
