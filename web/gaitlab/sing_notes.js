'use strict';
// Primigenia sing notes (A80): music notes that float up from a singer's mouth, one per trill / throat pulse.
// Our own glyphs, drawn on a canvas (eighth note, beamed pair, quarter note) plus a cracked set for a wrong song. No outside art.
// Stateless: every call is given the note's age in ms, so scrubbing, looping and live play all work the same way.
//   const pool=SingNotes.Pool(THREE,scene);  per frame: pool.begin(); pool.add({pos,age,seed,color,size,rise,kind,wrong}); pool.end();
(function(root){
const GLYPH_PX=128;
// shape: 0 eighth (one head, stem, flag)  1 beamed pair  2 quarter
function drawGlyph(shape,cracked){
  const c=document.createElement('canvas');c.width=c.height=GLYPH_PX;const g=c.getContext('2d');
  const head=(x,y)=>{g.beginPath();g.ellipse(x,y,15,11,-.42,0,Math.PI*2);g.fill();};
  const body=()=>{
    if(shape===0){head(46,98);g.fillRect(58,24,7,72);g.beginPath();g.moveTo(63,24);g.bezierCurveTo(70,50,104,52,96,86);g.bezierCurveTo(94,66,78,62,65,56);g.closePath();g.fill();}
    else if(shape===1){head(30,100);head(84,88);g.fillRect(42,30,7,72);g.fillRect(96,18,7,72);g.beginPath();g.moveTo(42,30);g.lineTo(103,17);g.lineTo(103,36);g.lineTo(42,49);g.closePath();g.fill();}
    else{head(48,96);g.fillRect(60,20,7,78);}
  };
  // soft dark outline first (stroked), then the white glyph on top, so a pale tint still reads against grass and sky
  const stroke=()=>{g.save();g.lineWidth=9;g.strokeStyle='rgba(0,0,0,.55)';g.lineJoin='round';
    const eh=(x,y)=>{g.beginPath();g.ellipse(x,y,15,11,-.42,0,Math.PI*2);g.stroke();};
    if(shape===0){eh(46,98);g.strokeRect(58,24,7,72);g.beginPath();g.moveTo(63,24);g.bezierCurveTo(70,50,104,52,96,86);g.bezierCurveTo(94,66,78,62,65,56);g.closePath();g.stroke();}
    else if(shape===1){eh(30,100);eh(84,88);g.strokeRect(42,30,7,72);g.strokeRect(96,18,7,72);g.beginPath();g.moveTo(42,30);g.lineTo(103,17);g.lineTo(103,36);g.lineTo(42,49);g.closePath();g.stroke();}
    else{eh(48,96);g.strokeRect(60,20,7,78);}
    g.restore();};
  stroke();g.fillStyle='#fff';body();
  if(cracked){ // jagged gaps cut through the head and the stem, so the note looks split
    g.globalCompositeOperation='destination-out';g.strokeStyle='#000';g.lineWidth=6;g.lineCap='round';g.lineJoin='miter';
    const zig=(pts)=>{g.beginPath();g.moveTo(pts[0][0],pts[0][1]);for(let i=1;i<pts.length;i++)g.lineTo(pts[i][0],pts[i][1]);g.stroke();};
    if(shape===0)zig([[26,84],[44,96],[38,104],[60,114]]);
    else if(shape===1)zig([[14,88],[32,98],[26,106],[46,116]]);
    else zig([[28,82],[46,95],[40,103],[62,112]]);
    zig([[52,50],[66,56],[58,63],[72,70]]);
    g.globalCompositeOperation='source-over';
  }
  return c;
}
const cache=new WeakMap();
function textures(THREE){
  let t=cache.get(THREE);if(t)return t;t={};
  for(const w of [0,1])for(const s of [0,1,2]){const tx=new THREE.CanvasTexture(drawGlyph(s,!!w));tx.anisotropy=2;t[w+':'+s]=tx;}
  cache.set(THREE,t);return t;
}
const easeOut=u=>1-Math.pow(1-Math.min(1,Math.max(0,u)),3);
const hash=n=>{let s=Math.sin(n*127.1+311.7)*43758.5453;return s-Math.floor(s);};
function Pool(THREE,scene,max){
  max=max||24;const tex=textures(THREE),sprites=[],col=new THREE.Color(),grey=new THREE.Color('#8b9096');let used=0;
  for(let i=0;i<max;i++){const m=new THREE.SpriteMaterial({map:tex['0:0'],transparent:true,depthTest:false,depthWrite:false,fog:false,opacity:0});const sp=new THREE.Sprite(m);sp.visible=false;sp.renderOrder=20;scene.add(sp);sprites.push(sp);}
  return {
    sprites,
    begin(){used=0;},
    // o: pos (Vector3, mouth), age (ms since the pulse), life (ms, default 1100), seed, color, size (glyph height, m), rise (m, ~1.2 body heights),
    //    kind (0 eighth, 1 beamed, 2 quarter), wrong (dull, cracked, tumbling), side (Vector3 the note sways along; default +z)
    add(o){
      const life=o.life||1100,u=o.age/life;if(!(u>0&&u<1)||used>=max)return;
      const sp=sprites[used++],r1=hash(o.seed||0),r2=hash((o.seed||0)+7.3),r3=hash((o.seed||0)+19.9),wrong=!!o.wrong;
      sp.visible=true;sp.material.map=tex[(wrong?1:0)+':'+((o.kind|0)%3)];
      // ease-out rise; a wrong note climbs less, then sags and tumbles
      const rise=(o.rise||1)*(wrong?.62:1)*easeOut(u),sag=wrong?(o.size||.2)*2.4*u*u*u:0;
      const side=o.side||{x:0,y:0,z:1},sw=(o.size||.2)*(wrong?.5:.9)*Math.sin(u*Math.PI*2*1.1+r1*6.283)*Math.min(1,u*3);
      sp.position.set(o.pos.x+side.x*sw+(r2-.5)*.04,o.pos.y+rise-sag,o.pos.z+side.z*sw);
      // scale-in from 0.6 (never 0), settled by 12 % of the life
      const sc=(o.size||.2)*(.6+.4*easeOut(u/.12));sp.scale.set(sc,sc,1);
      // slight random tilt that sways with the song; the wrong note tips over and spins as it drops
      const tilt=(r3-.5)*.5+.12*Math.sin(u*Math.PI*2*1.1+r2*6.283)+(wrong?(r1<.5?-1:1)*u*u*3.4:0);sp.material.rotation=tilt;
      // opacity: up quickly, hold, then ease out to nothing across the rest of the life
      const fade=u<.25?1:1-Math.pow((u-.25)/.75,1.6);sp.material.opacity=Math.min(1,u/.07)*Math.max(0,fade)*(wrong?.78:.95);
      if(wrong)col.copy(grey);else col.set(o.color||'#ffffff').lerp(new THREE.Color('#ffffff'),.22);
      sp.material.color.copy(col);
    },
    end(){for(let i=used;i<max;i++)sprites[i].visible=false;}
  };
}
root.SingNotes={Pool,textures,drawGlyph,easeOut,GLYPH_PX};
})(typeof window!=='undefined'?window:globalThis);
