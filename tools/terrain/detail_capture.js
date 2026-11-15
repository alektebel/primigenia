/* Appended to lab.mjs only by the evidence runner's Playwright route.
 * Uses the existing height-field mesh; no invented cave/tunnel geometry. */
window.captureTerrainDetail = kind => {
  const {n,size,height:h} = terrain, cell=size/n;
  let x,z,y,fx,fz,range,caveIndex=-1;
  if(kind==='cave') {
    const v=terrain.entrances.find(v=>!v.waterfall)||terrain.entrances[0];
    caveIndex=terrain.entrances.indexOf(v);
    [x,z,y]=v.position;[fx,fz]=v.facing;range=18;
  } else {
    // A coastal face whose outward view is clear of the island interior.
    let best=-Infinity,chosen;
    for(let row=5;row<n-5;row++)for(let col=5;col<n-5;col++) {
      const i=row*n+col,wx=(col+.5)*cell-size/2,wz=(row+.5)*cell-size/2;
      if(h[i]<10||h[i]>32||Math.hypot(wx,wz)<1300)continue;
      const dx=(h[i+1]-h[i-1])/(2*cell),dz=(h[i+n]-h[i-n])/(2*cell),slope=Math.hypot(dx,dz);
      if(slope<1)continue;
      const ox=-dx/slope,oz=-dz/slope;
      if(groundAt(wx+ox*45,wz+oz*45)>1)continue;
      const score=slope+.3*(ox*SUN[0]+oz*SUN[2]);
      if(score>best){best=score;chosen=[wx,wz,h[i],ox,oz];}
    }
    if(!chosen)throw Error('No exposed sea cliff found');
    [x,z,y,fx,fz]=chosen;range=90;
  }
  // Full cell resolution resolves the small cave-floor notch for this view.
  query.set('mesh',String(n-1));buildMesh();caveMarkers.visible=false;
  if(caveIndex>=0) {
    caveMarkers.visible=true;
    caveMarkers.children.forEach((marker,i)=>{
      marker.visible=i===caveIndex;
      if(marker.visible){marker.position.set(x,y+4,z);marker.scale.set(2.5,2.5,1);}
    });
  }
  camera.near=.2;camera.fov=55;
  camera.position.set(x+fx*range,y+(kind==='cave'?18:range*.22),z+fz*range);
  camera.lookAt(x,y+2,z);camera.updateProjectionMatrix();renderer.render(scene,camera);
  return {kind,position_m:[x,z,y],eye_m:camera.position.toArray(),target_m:[x,y+2,z],
    note:kind==='cave'?'Generated entrance floor notch only; no tunnel or overhang mesh':'Generated coastal height-field face'};
};
