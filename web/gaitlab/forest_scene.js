'use strict';
/* forest_scene.js: renders the four forest versions (three.js r128) and computes the GPU-side judging measures of the plan's table.
 * Uses FOREST (forest_core.js: data, stand, ray measures) and FT (forest_trees.js: procedural trees). Public API: window.LAB. */
const LAB=(()=>{
const T=THREE,F=FOREST,{lerp,clamp,sstep,V3}=FT;
const S={renderer:null,canvas:null,ground:null,tile:null,views:{},ver:'A',slot:'OG7',cam:new T.PerspectiveCamera(65,16/9,.1,4000),yaw:0,pitch:0,compare:false,errs:[],ready:false,quality:1};
const TRI=(g)=>g?(g.index?g.index.count/3:g.attributes.position.count/3):0;
const col3=a=>new T.Color(a[0],a[1],a[2]);
const lin=h=>FT.srgb(h);

/* ---------------- one view = one version's scene ---------------- */
class View{
  constructor(id){
    this.id=id;this.V=F.VERSIONS[id];this.st=new F.Stand(id,S.ground);this.scene=new T.Scene();this.built=false;this.im={};this.proto={};this.lastInst=null;this.counts={};this.stats={};
    const L=this.V.light,FG=this.V.fog;
    this.U={uFogColor:{value:col3(FG.col)},uFogDen:{value:FG.den},uFogK:{value:FG.k},uFogBase:{value:FG.base},uFogFar:{value:FG.far||0},uSunDir:{value:new T.Vector3()},uSunCol:{value:col3(L.sunCol)},uMask:{value:0},uAO:{value:1},uAOk:{value:this.V.aoK||1.45}};
    const az=L.sunAz,el=L.sunEl;this.sunDir=new T.Vector3(Math.cos(el)*Math.cos(az),Math.sin(el),Math.cos(el)*Math.sin(az)).normalize();this.U.uSunDir.value.copy(this.sunDir);
  }
  async build(progress){
    const step=async(msg)=>{if(progress)progress(msg);await new Promise(r=>setTimeout(r,0));};
    const st=this.st,V=this.V;F.sharedTextures();
    await step('trail and clearings');st.makeClearings();st.makeGaps();st.buildTrail();
    await step('stand');st.buildTrees();
    await step('canopy light');st.buildSky();
    await step('materials');this.makeMaterials();
    await step('trees');this.buildProtos();
    await step('terrain');this.buildTerrain();
    await step('sky, lights, creature');this.buildSky();this.buildLights();this.buildCreature();this.buildBeams();this.buildLogsRocks();
    this.built=true;
  }
  makeMaterials(){
    const SH=F.SHARED,U=this.U,P=F.patchMat,m={};
    m.bark=P(new T.MeshStandardMaterial({map:SH.bark,bumpMap:SH.bark,bumpScale:1.6,vertexColors:true,roughness:.96,metalness:0}),U,{mask:[0,0,1]});
    m.leaf={};m.blob={};
    for(const k of['laurel','cloud','broad','small']){
      m.leaf[k]=P(new T.MeshStandardMaterial({map:SH.leaf[k],alphaTest:.4,side:T.DoubleSide,vertexColors:true,roughness:.9,metalness:0}),U,{mask:[0,0,1],faceFix:true});
      m.blob[k]=P(new T.MeshStandardMaterial({map:SH.blob[k],vertexColors:true,roughness:.85,metalness:0}),U,{mask:[0,0,1],faceFix:true});
    }
    m.shrub=P(new T.MeshStandardMaterial({map:SH.leaf.laurel,alphaTest:.4,side:T.DoubleSide,vertexColors:true,roughness:.9,metalness:0}),U,{mask:[0,0,1],faceFix:true});
    m.moss=P(new T.MeshStandardMaterial({map:SH.moss,alphaTest:.3,side:T.DoubleSide,vertexColors:true,roughness:1}),U,{mask:[0,0,1],faceFix:true});
    m.fern=P(new T.MeshStandardMaterial({map:SH.fern,alphaTest:.3,side:T.DoubleSide,vertexColors:true,roughness:.7}),U,{mask:[0,0,1],faceFix:true});
    m.fernB=P(new T.MeshStandardMaterial({map:SH.fernB,alphaTest:.3,side:T.DoubleSide,vertexColors:true,roughness:.7}),U,{mask:[0,0,1],faceFix:true});
    m.grass=P(new T.MeshStandardMaterial({map:SH.grass,alphaTest:.45,side:T.DoubleSide,vertexColors:true,roughness:.9}),U,{mask:[0,0,1],faceFix:true});
    m.plain=P(new T.MeshStandardMaterial({vertexColors:true,roughness:.6}),U,{mask:[0,0,1]});
    m.rock=P(new T.MeshStandardMaterial({vertexColors:true,roughness:.97,map:SH.bark,bumpMap:SH.bark,bumpScale:2}),U,{mask:[0,0,1]});
    m.creature=P(new T.MeshStandardMaterial({vertexColors:true,roughness:.78,metalness:0}),U,{mask:[0,1,0]});
    this.mats=m;
  }
  /* ---- prototypes: each class x variant x lod ---- */
  buildProtos(){
    const st=this.st,pp=st.protoParamsMap,out=this.proto;this.cap={};
    for(const t of st.trees)this.cap[t.key]=(this.cap[t.key]||0)+1;
    for(const key of Object.keys(pp)){
      const cls=key.slice(0,-1),vi=+key.slice(-1),P=pp[key],lods=[];
      const c0=st.l0Cache&&st.l0Cache[key];
      if(cls==='tfern'){for(let l=0;l<3;l++)lods.push(l===1&&c0?c0:FT.treeFernParts(vi*5+3,P,Math.min(l,1)));}
      else if(P.src)for(let l=0;l<3;l++)lods.push(l===0&&c0?c0:FT.skeletonParts(F.ASSETS.glb,P.m,P,l,vi*53+cls.charCodeAt(0)+this.id.charCodeAt(0)*7));
      else for(let l=0;l<3;l++)lods.push(l===0&&c0?c0:FT.treeParts(vi*53+cls.charCodeAt(0)+this.id.charCodeAt(0)*7,P,l));
      out[key]={cls,P,lods};
    }
    /* undergrowth prototypes, normalised to unit reach and unit height so an item scales by its own r and h */
    const norm=(g)=>{g.computeBoundingBox();const b=g.boundingBox;return{reach:Math.max(.2,Math.max(Math.abs(b.min.x),Math.abs(b.max.x),Math.abs(b.min.z),Math.abs(b.max.z))),height:Math.max(.2,b.max.y)};};
    this.ug={};
    const mk=(type,v,gen)=>{const lods=[0,1].map(l=>gen(l));lods.forEach(x=>{const g=x.g||x.leaf;x.n=norm(g);});this.ug[type+v]=lods;};
    for(let v=0;v<3;v++){
      mk('fern',v,l=>FT.fernParts(v*11+1,{n:12,len:1,el0:.5,el1:1.2,wr:.34,droop:.5,shade:1},l));
      mk('fernL',v,l=>FT.fernParts(v*11+41,{n:11,len:1,el0:.6,el1:1.25,wr:.3,droop:.4,shade:1},l));
      mk('shrub',v,l=>{const r=FT.shrubParts(v*7+2,{n:6,r:.5,h:1,cr:.42,cs:.5,tint:[.9,1,.85]},l);return r;});
    }
    this.grassP=[0,1].map(l=>FT.grassParts(5,l));this.grassP.forEach(x=>{x.n=norm(x.g);});
  }
  imesh(key,geo,mat,cap,opt){
    let m=this.im[key];if(m)return m;
    m=new T.InstancedMesh(geo,mat,Math.max(1,cap));m.count=0;m.frustumCulled=false;m.castShadow=!!(opt&&opt.cast);m.receiveShadow=!!(opt&&opt.recv);
    m.instanceColor=new T.InstancedBufferAttribute(new Float32Array(Math.max(1,cap)*3),3);m.instanceMatrix.setUsage(T.DynamicDrawUsage);
    m.userData.tris=TRI(geo);this.scene.add(m);this.im[key]=m;return m;
  }
  /* ---- terrain ---- */
  buildTerrain(){
    const g=S.ground,st=this.st,V=this.V,tmp=new T.Vector3();
    const mk=(half,step,hole)=>{
      const n=Math.round(half*2/step)+1,pos=[],nor=[],uv=[],aT=[],aM=[],aS=[],aMd=[],aR=[],idx=[];
      const col=(x,z)=>{
        const q=st.trailQ(x,z),w=st.trail.w*.5;let tr=1-sstep(w-.12,w+.38,q.d);tr=Math.max(tr,.16*(1-sstep(w+.1,w+1.3,q.d)));
        const M=this.softMask(x,z),sl=g.slopeDeg(x,z),rv=g.riverAt(x,z),sky=st.skyAt(x,z);
        let moss=V.mossGround*(.45+.9*FT.fbm(x/14,z/14,3,21))+(1-sky)*.18+(rv?.5:0)+.1*clamp((sl-30)/20,0,1);
        let mead=1-sstep(.08,.65,M);let clr=0;for(const c of st.clearings){const d=Math.hypot(x-c.x,z-c.z);clr=Math.max(clr,1-sstep(c.r*.6,c.r*1.0,d));}
        mead=Math.max(mead,clr*.72);
        return[tr,clamp(moss,0,1)*(1-mead),sky,mead,sstep(47,57,sl)*.9];};
      for(let j=0;j<n;j++)for(let i=0;i<n;i++){
        const x=-half+i*step,z=-half+j*step,y=g.at(x,z);g.normal(x,z,tmp);
        pos.push(x,y,z);nor.push(tmp.x,tmp.y,tmp.z);uv.push(x*.31,z*.31);const c=col(x,z);aT.push(c[0]);aM.push(c[1]);aS.push(c[2]);aMd.push(c[3]);aR.push(c[4]);
      }
      for(let j=0;j<n-1;j++)for(let i=0;i<n-1;i++){
        if(hole){const x0=-half+i*step,z0=-half+j*step;if(x0>=-hole-1e-3&&x0+step<=hole+1e-3&&z0>=-hole-1e-3&&z0+step<=hole+1e-3)continue;}
        const a=j*n+i,b=a+1,c=a+n,d=c+1;idx.push(a,c,b,b,c,d);
      }
      const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(pos,3));geo.setAttribute('normal',new T.Float32BufferAttribute(nor,3));geo.setAttribute('uv',new T.Float32BufferAttribute(uv,2));
      geo.setAttribute('aTrail',new T.Float32BufferAttribute(aT,1));geo.setAttribute('aMoss',new T.Float32BufferAttribute(aM,1));geo.setAttribute('aSky',new T.Float32BufferAttribute(aS,1));
      geo.setAttribute('aMead',new T.Float32BufferAttribute(aMd,1));geo.setAttribute('aRock',new T.Float32BufferAttribute(aR,1));geo.setIndex(idx);geo.computeBoundingSphere();return geo;
    };
    const mat=F.patchMat(new T.MeshStandardMaterial({color:0xffffff,roughness:.96,metalness:0,bumpMap:F.SHARED.floor.litter.height,bumpScale:.3}),this.U,{terrain:true,mask:[1,0,0],
      meadCol:new T.Color(...(this.id==='C'?[.13,.16,.05]:[.095,.12,.05])),mossK:1.0});
    const inner=new T.Mesh(mk(300,2,0),mat),outer=new T.Mesh(mk(F.EXT,6,300),mat);
    /* the trail: a soft-edged ribbon draped over the terrain (a 1.2 m trail cannot live in 2 m vertices) */
    {const tr=st.trail,pos=[],nor=[],aT=[],uv=[],aS=[],z0=[],idx=[],n=tr.pts.length,w=tr.w*.5+.32,nn=new T.Vector3();let k=0;
      for(let i=0;i<n;i++){const p=tr.pts[i],q=tr.pts[Math.min(i+1,n-1)],r=tr.pts[Math.max(i-1,0)];let tx=q.x-r.x,tz=q.z-r.z;const L=Math.hypot(tx,tz)||1;tx/=L;tz/=L;
        const wob=1+.22*Math.sin(i*.37)+.12*Math.sin(i*1.31);
        for(const sd of[-1,0,1]){const x=p.x-tz*sd*w*wob,zz=p.z+tx*sd*w*wob,y=g.at(x,zz)+.1+(sd===0?.02:0);g.normal(x,zz,nn);
          pos.push(x,y,zz);nor.push(nn.x,nn.y,nn.z);aT.push(sd===0?1:.0);uv.push(sd*.5+.5,p.s/3);aS.push(st.skyAt(x,zz));}
        if(i<n-1){const a=i*3;idx.push(a,a+3,a+1,a+1,a+3,a+4,a+1,a+4,a+2,a+2,a+4,a+5);}}
      const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(pos,3));geo.setAttribute('normal',new T.Float32BufferAttribute(nor,3));geo.setAttribute('uv',new T.Float32BufferAttribute(uv,2));
      const zero=new Array(n*3).fill(0);geo.setAttribute('aTrail',new T.Float32BufferAttribute(aT,1));geo.setAttribute('aMoss',new T.Float32BufferAttribute(zero,1));geo.setAttribute('aSky',new T.Float32BufferAttribute(aS,1));
      geo.setAttribute('aMead',new T.Float32BufferAttribute(zero,1));geo.setAttribute('aRock',new T.Float32BufferAttribute(zero,1));geo.setIndex(idx);
      const rm=F.patchMat(new T.MeshStandardMaterial({color:0xffffff,roughness:.97,metalness:0,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-3,polygonOffsetUnits:-3,bumpMap:F.SHARED.trail.height,bumpScale:.16}),this.U,{terrain:true,ribbon:true,mask:[1,1,0],meadCol:new T.Color(0,0,0),mossK:0});
      const rib=new T.Mesh(geo,rm);rib.receiveShadow=true;rib.renderOrder=2;this.scene.add(rib);this.ribbon=rib;this.terrTris+=idx.length/3;}
    inner.receiveShadow=true;outer.receiveShadow=true;this.scene.add(inner,outer);this.terrain=[inner,outer];this.terrTris=TRI(inner.geometry)+TRI(outer.geometry);
  }
  softMask(x,z){const st=this.st;let M=sstep(-4,48,F.axisS(x,z)+(FT.fbm(x/38,z/38,3,4)-.5)*34);for(const c of st.clearings){const d=Math.hypot(x-c.x,z-c.z)+(FT.fbm(x/7,z/7,2,3)-.5)*c.r*.35;M*=sstep(c.r*.78,c.r*1.12,d);}return M;}
  buildSky(){
    const L=this.V.light,FG=this.V.fog;
    const mat=new T.ShaderMaterial({side:T.BackSide,depthWrite:false,fog:false,uniforms:Object.assign({uTop:{value:col3(L.sky)},uHor:{value:col3(FG.col)},uSunDir:this.U.uSunDir,uSunCol:this.U.uSunCol,uMask:this.U.uMask},{}),
      vertexShader:'varying vec3 vD;void main(){vD=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',
      fragmentShader:`uniform vec3 uTop,uHor,uSunDir,uSunCol;uniform float uMask;varying vec3 vD;
        void main(){vec3 d=normalize(vD);float h=clamp(d.y,0.0,1.0);vec3 c=mix(uHor,uTop,pow(h,0.55));
        float s=max(dot(d,uSunDir),0.0);c+=uSunCol*(pow(s,12.0)*0.06+pow(s,200.0)*0.5);
        c=mix(c,uHor,smoothstep(0.0,0.02,-d.y)*0.7);
        if(uMask>0.5)c=vec3(0.0);
        gl_FragColor=vec4(c,1.0);
        #include <encodings_fragment>
        }`});
    mat.toneMapped=true;
    const dome=new T.Mesh(new T.SphereGeometry(3500,24,12),mat);dome.renderOrder=-10;dome.frustumCulled=false;this.dome=dome;this.scene.add(dome);
  }
  buildLights(){
    const L=this.V.light;
    this.sun=new T.DirectionalLight(col3(L.sunCol),L.sunI);this.sun.castShadow=true;this.sun.shadow.mapSize.set(4096,4096);this.sun.shadow.bias=-.0004;this.sun.shadow.normalBias=.35;
    const sc=this.sun.shadow.camera;sc.near=10;sc.far=1200;sc.left=-80;sc.right=80;sc.top=80;sc.bottom=-80;
    this.scene.add(this.sun,this.sun.target);
    this.hemi=new T.HemisphereLight(col3(L.hemiSky),col3(L.hemiGnd),L.hemiI);this.scene.add(this.hemi);
  }
  aimShadow(cam,extent){
    const f=new T.Vector3();cam.getWorldDirection(f);const c=cam.position.clone().addScaledVector(f,extent*.45);c.y=S.ground.at(c.x,c.z)+4;
    if(extent>150)c.copy(cam.position).addScaledVector(f,extent*.3),c.y=S.ground.at(c.x,c.z)+10;
    const q=this.sun.shadow.mapSize.x,tex=extent*2/q;c.x=Math.round(c.x/tex)*tex;c.z=Math.round(c.z/tex)*tex;
    this.sun.target.position.copy(c);this.sun.position.copy(c).addScaledVector(this.sunDir,500);this.sun.target.updateMatrixWorld();
    const sc=this.sun.shadow.camera;sc.left=-extent;sc.right=extent;sc.top=extent;sc.bottom=-extent;sc.updateProjectionMatrix();
  }
  /* ---- the creature ---- */
  buildCreature(){
    /* Pip, the lab's little herbivore (sig_rig.js), so the scale reads the same as in the attack labs */
    const grp=new T.Group(),pip=BB.sig.Pip(grp,0,{col:'#5c3417',belly:'#cdb07c'});pip.set(1.2,{});
    grp.traverse(o=>{if(o.isMesh&&o.material&&!o.material.isSpriteMaterial){o.material=o.material.clone();o.material.color.convertSRGBToLinear();F.patchMat(o.material,this.U,{mask:[0,1,0],nofog:true});o.castShadow=true;o.receiveShadow=true;}});
    const holder=new T.Group();holder.add(grp);grp.rotation.y=Math.PI;grp.scale.setScalar(1.25);this.creature=holder;this.pip=pip;this.scene.add(holder);this.creatureTris=2500;
  }
  placeCreature(x,z,tx,tz){
    const y=S.ground.at(x,z);this.creature.position.set(x,y+.0,z);
    const n=S.ground.normal(x,z,new T.Vector3());const q=new T.Quaternion().setFromUnitVectors(new T.Vector3(0,1,0),n.lerp(new T.Vector3(0,1,0),.5).normalize());
    const yawQ=new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),Math.atan2(-tz,tx));this.creature.quaternion.copy(q).multiply(yawQ);
  }
  /* ---- light shafts: cylindrical billboards along the sun direction at the gaps the canopy leaves ---- */
  buildBeams(){
    this.beams=new T.Group();this.scene.add(this.beams);this.beamsOn=this.V.shafts;
    const mat=new T.ShaderMaterial({transparent:true,depthWrite:false,blending:T.AdditiveBlending,side:T.DoubleSide,fog:false,
      uniforms:{uCol:{value:col3(this.V.light.sunCol)},uAxis:{value:this.sunDir},uTime:{value:0},uI:{value:this.V.shafts?1.6:0}},
      vertexShader:`uniform vec3 uAxis;varying vec2 vUv;varying float vH;void main(){vUv=uv;vec3 base=(modelMatrix*vec4(0.,0.,0.,1.)).xyz;float L=${'26.0'};
        float w=length((modelMatrix*vec4(1.,0.,0.,0.)).xyz);vec3 toCam=cameraPosition-base;vec3 side=normalize(cross(uAxis,toCam));
        vec3 p=base+uAxis*(position.y+0.5)*L+side*position.x*w;vH=position.y+0.5;gl_Position=projectionMatrix*viewMatrix*vec4(p,1.);}`,
      fragmentShader:`uniform vec3 uCol;uniform float uI;varying vec2 vUv;varying float vH;
        void main(){float across=1.0-abs(vUv.x*2.0-1.0);across=smoothstep(0.0,1.0,across);across*=across;
          float along=smoothstep(0.0,0.1,vH)*(1.0-smoothstep(0.25,0.95,vH));
          float n=0.75+0.25*sin(vUv.y*17.0+vUv.x*5.0);float a=across*along*n*uI*0.2;gl_FragColor=vec4(uCol,a);}`});
    this.beamMat=mat;this.beamsBuilt=false;
  }
  rebuildBeams(cam){
    if(!this.V.shafts){this.beams.visible=false;return;}
    const g=this.beams;while(g.children.length)g.remove(g.children[0]);
    const R=FT.rng32(99),pl=new T.PlaneGeometry(1,1),st=this.st,cn=st.canopy,sd=this.sunDir;let n=0;
    const px=cam.position.x,pz=cam.position.z,pts=[];
    for(let k=0;k<7000&&n<110;k++){
      const a=R()*6.283,d=4+Math.sqrt(R())*110,x=px+Math.cos(a)*d,z=pz+Math.sin(a)*d;if(Math.abs(x)>290||Math.abs(z)>290||F.axisS(x,z)<12)continue;   /* shafts only inside the stand and its clearings, never over the meadow */
      const y=S.ground.at(x,z)+3,tr=cn.trans(x,y,z,sd.x,sd.y,sd.z,90);if(tr<.28)continue;
      if(pts.some(q=>Math.hypot(q[0]-x,q[1]-z)<5.5))continue;pts.push([x,z]);
      const m=new T.Mesh(pl,this.beamMat);m.position.set(x,S.ground.at(x,z)+.2,z);m.scale.set(1.6+R()*3.6,1,1);m.frustumCulled=false;m.renderOrder=5;g.add(m);n++;
    }
    this.beamN=n;this.beams.visible=true;
  }
  buildLogsRocks(){
    const st=this.st,R=FT.rng32(555+this.id.charCodeAt(0)),V=this.V;this.logs=[];this.rocks=[];
    const ha=30;let n=Math.round(V.logs*ha),guard=0;
    while(this.logs.length<n&&guard++<n*40){const x=(R()-.5)*1100,z=(R()-.5)*1100;if(this.softMask(x,z)<.7||st.trailQ(x,z).d<2.2||S.ground.slopeDeg(x,z)>38)continue;
      this.logs.push({x,z,y:S.ground.at(x,z),yaw:R()*6.283,L:4+R()*6,r:.18+R()*.28,v:Math.floor(R()*3)});}
    n=Math.round(V.rocks*ha);guard=0;
    while(this.rocks.length<n&&guard++<n*40){const x=(R()-.5)*1100,z=(R()-.5)*1100;if(st.trailQ(x,z).d<1.8||S.ground.riverAt(x,z)>=2)continue;
      this.rocks.push({x,z,y:S.ground.at(x,z),yaw:R()*6.283,r:.35+Math.pow(R(),2)*1.3,v:Math.floor(R()*3)});}
    this.logP=[0,1,2].map(v=>[0,1].map(l=>FT.logParts(v+3,{L:1,r:1,moss:this.V.moss},l)));
    this.rockP=[0,1,2].map(v=>[0,1].map(l=>FT.rockParts(v+9,{r:1,moss:this.V.moss},l)));
    this.rockMoss=this.V.moss;
  }
  /* ---- instancing for a camera ---- */
  updateInstances(cam,opt){
    const px=cam.position.x,py=cam.position.y,pz=cam.position.z,st=this.st,M=this.mats,V=this.V;
    for(const k in this.im)this.im[k].count=0;
    const L0=opt.l0,L1=opt.l1,RM2=opt.rmax*opt.rmax;let nInst=0,tris=0;
    const put=(mesh,x,y,z,sx,sy,sz,yaw,tint)=>{const i=mesh.count++,a=mesh.instanceMatrix.array,c=Math.cos(yaw),s=Math.sin(yaw),o=i*16;
      a[o]=sx*c;a[o+1]=0;a[o+2]=-sx*s;a[o+3]=0;a[o+4]=0;a[o+5]=sy;a[o+6]=0;a[o+7]=0;a[o+8]=sz*s;a[o+9]=0;a[o+10]=sz*c;a[o+11]=0;a[o+12]=x;a[o+13]=y;a[o+14]=z;a[o+15]=1;
      const ic=mesh.instanceColor.array;ic[i*3]=tint[0];ic[i*3+1]=tint[1];ic[i*3+2]=tint[2];tris+=mesh.userData.tris;};
    for(const t of st.trees){
      const dx=t.x-px,dz=t.z-pz,d2=dx*dx+dz*dz;if(d2>RM2)continue;const d=Math.sqrt(d2);
      let lod=d<L0?0:d<L1?1:2;const pr=this.proto[t.key];if(pr.cls==='tfern'&&lod===2){if(d>L1*1.6)continue;lod=1;}
      const part=pr.lods[Math.min(lod,pr.lods.length-1)],key=t.key+'|'+lod;
      nInst++;
      if(pr.cls==='tfern'){
        const mb=this.imesh(key+'b',part.bark,M.bark,this.cap[t.key],{cast:true,recv:true}),ml=this.imesh(key+'l',part.leaf,M.fern,this.cap[t.key],{cast:true});
        const s=t.sc;put(mb,t.x,t.y,t.z,s,s,s,t.yaw,t.tint);put(ml,t.x,t.y,t.z,s,s,s,t.yaw,[t.tint[0]*.9,t.tint[1],t.tint[2]*.85]);continue;}
      const s=t.sc,tintLeaf=[t.tint[0],t.tint[1],t.tint[2]];
      if(part.bark){const m=this.imesh(key+'b',part.bark,M.bark,this.cap[t.key],{cast:true,recv:true});put(m,t.x,t.y,t.z,s,s,s,t.yaw,[1,1,1]);}
      if(part.leaf){const mat=lod===2?M.blob[pr.P.leaf]:M.leaf[pr.P.leaf];const m=this.imesh(key+'l',part.leaf,mat,this.cap[t.key],{cast:true,recv:lod<2});put(m,t.x,t.y,t.z,s,s,s,t.yaw,tintLeaf);}
      if(lod===0&&part.moss){const m=this.imesh(key+'m',part.moss,M.moss,this.cap[t.key],{});put(m,t.x,t.y,t.z,s,s,s,t.yaw,[1,1,1]);}
      if(lod===0&&part.vines){const m=this.imesh(key+'v',part.vines,M.plain,this.cap[t.key],{});put(m,t.x,t.y,t.z,s,s,s,t.yaw,[1,1,1]);}
      if(lod===0&&part.epi){const m=this.imesh(key+'e',part.epi,M.fernB,this.cap[t.key],{});put(m,t.x,t.y,t.z,s,s,s,t.yaw,[.85,.95,.8]);}
      if(lod===0&&part.fruit){const m=this.imesh(key+'f',part.fruit,M.plain,this.cap[t.key],{cast:true});put(m,t.x,t.y,t.z,s,s,s,t.yaw,[1,1,1]);}
    }
    /* logs and rocks */
    for(const lg of this.logs){const dx=lg.x-px,dz=lg.z-pz,d2=dx*dx+dz*dz;if(d2>200*200)continue;const lod=d2<40*40?0:1,p=this.logP[lg.v][lod];
      const mb=this.imesh('log'+lg.v+lod,p.bark,M.bark,this.logs.length,{cast:true,recv:true});put(mb,lg.x,lg.y+lg.r*.7,lg.z,lg.L,lg.r,lg.r,lg.yaw,[1,1,1]);nInst++;
      if(lod===0&&p.moss){const mm=this.imesh('logm'+lg.v,p.moss,M.moss,this.logs.length,{});put(mm,lg.x,lg.y+lg.r*.7,lg.z,lg.L,lg.r,lg.r,lg.yaw,[1,1,1]);}}
    for(const rk of this.rocks){const dx=rk.x-px,dz=rk.z-pz,d2=dx*dx+dz*dz;if(d2>250*250)continue;const lod=d2<50*50?0:1,p=this.rockP[rk.v][lod];
      const mb=this.imesh('rock'+rk.v+lod,p.g,M.rock,this.rocks.length,{cast:true,recv:true});put(mb,rk.x,rk.y,rk.z,rk.r,rk.r*.8,rk.r*(.8+.4*((rk.v+1)/3)),rk.yaw,[1,1,1]);nInst++;}
    /* undergrowth around the camera */
    if(opt.ug>0){
      const S16=16,ci=Math.floor(px/S16),cj=Math.floor(pz/S16),rc=Math.ceil(opt.ug/S16);
      for(let b=-rc;b<=rc;b++)for(let a=-rc;a<=rc;a++)for(const it of st.ugCell(ci+a,cj+b)){
        const dx=it.x-px,dz=it.z-pz,d2=dx*dx+dz*dz;if(d2>opt.ug*opt.ug)continue;const lod=d2<30*30?0:1,p=this.ug[it.type+it.v][lod],nrm=p.n;
        const sx=it.r/nrm.reach,sy=it.h/nrm.height,sh=.3+.7*Math.min(1,st.skyAt(it.x,it.z)*3.5),tint=[it.c*sh*.95,it.c*sh,it.c*sh*.8];
        if(it.type==='shrub'){const mb=p.bark&&this.imesh('shrubB'+it.v+lod,p.bark,M.bark,4000,{});if(mb)put(mb,it.x,it.y,it.z,sx,sy,sx,it.yaw,tint);
          const ml=this.imesh('shrubL'+it.v+lod,p.leaf,M.shrub,4000,{cast:false});put(ml,it.x,it.y,it.z,sx,sy,sx,it.yaw,tint);}
        else{const m=this.imesh(it.type+it.v+lod,p.g,(it.v&1)?M.fernB:M.fern,4000,{});put(m,it.x,it.y,it.z,sx,sy,sx,it.yaw,tint);}
        nInst++;}
      /* meadow grass tufts */
      if(opt.grass>0){const gs=4,gc=Math.floor(px/gs),gr=Math.ceil(opt.grass/gs),R2=opt.grass*opt.grass;
        for(let b=-gr;b<=gr;b++)for(let a=-gr;a<=gr;a++){const ix=gc+a,iz=Math.floor(pz/gs)+b,rr=FT.rng32(Math.imul(ix+9000,73856093)^Math.imul(iz+9000,19349663));
          const cx=(ix+.5)*gs,cz=(iz+.5)*gs;if((cx-px)**2+(cz-pz)**2>R2)continue;const M0=this.softMask(cx,cz);let w=(1-sstep(.15,.7,M0));for(const c of st.clearings){w=Math.max(w,.6*(1-sstep(c.r*.7,c.r,Math.hypot(cx-c.x,cz-c.z))));}
          if(w<.05||st.trailQ(cx,cz).d<.6)continue;const n=Math.round(w*22*(.6+.8*rr()));
          /* bracken patches and big ochre tussocks make the meadow uneven */
          const pc=FT.hash2(Math.floor(cx/9),Math.floor(cz/9),77);
          if(w>.4&&pc<.16&&st.trailQ(cx,cz).d>1.5){const nf=3+Math.floor(rr()*4);for(let q=0;q<nf;q++){const x=cx+(rr()-.5)*gs,z=cz+(rr()-.5)*gs,r=.7+rr()*.5,v=Math.floor(rr()*3),pr=this.ug['fernL'+v][0],m=this.imesh('fernL'+v+'0',pr.g,M.fern,4000,{});
            put(m,x,S.ground.at(x,z),z,r/pr.n.reach,(.9+rr()*.5)/pr.n.height,r/pr.n.reach,rr()*6.28,[.95,.95,.7]);nInst++;}}
          if(w>.3&&FT.hash2(Math.floor(cx/5),Math.floor(cz/5),91)<.22&&st.trailQ(cx,cz).d>1.2){const x=cx+(rr()-.5)*gs,z=cz+(rr()-.5)*gs,gp=this.grassP[0],m=this.imesh('grass',gp.g,M.grass,16000,{});
            for(let k=0;k<3;k++)if(m.count<16000){put(m,x+(rr()-.5)*.6,S.ground.at(x,z),z+(rr()-.5)*.6,1.7+rr()*.5,1.1/gp.n.height*(.8+rr()*.5),1.7+rr()*.5,rr()*6.28,[.95,.8,.45]);nInst++;}}
          for(let q=0;q<n;q++){const x=cx+(rr()-.5)*gs,z=cz+(rr()-.5)*gs;if(st.trailQ(x,z).d<st.trail.w*.5+.1)continue;const gp=this.grassP[0],h=.5+rr()*.6,sc=.8+rr()*.6;
            const m=this.imesh('grass',gp.g,M.grass,16000,{});if(m.count<16000){put(m,x,S.ground.at(x,z),z,sc,h/gp.n.height,sc,rr()*6.28,[.9+rr()*.2,.95+rr()*.1,.8]);nInst++;}}}}
    }
    for(const k in this.im){const m=this.im[k];m.visible=m.count>0;m.instanceMatrix.needsUpdate=true;m.instanceColor.needsUpdate=true;}
    this.stats={instances:nInst,tris:tris+this.terrTris+this.creatureTris,treeTris:tris,terrainTris:this.terrTris};
    this.lastInst={x:px,z:pz,opt:Object.assign({},opt)};
  }
  needsInstUpdate(cam,opt){const l=this.lastInst;if(!l)return true;if(Math.hypot(cam.position.x-l.x,cam.position.z-l.z)>(opt.l0*.35))return true;return JSON.stringify(opt)!==JSON.stringify(l.opt);}
}

/* ---------------- camera slots ---------------- */
function slotCamera(view,id){
  const g=S.ground,st=view.st;let p,look,fov=62,opt;
  if(id==='OG5'){const x=F.OG5_L[0],z=F.OG5_L[1],y=g.at(x,z)+150;p=V3(x,y,z);const d=F.AX;look=V3(x+d[0]*400,y-95,z+d[1]*400);fov=62;opt={l0:40,l1:90,rmax:700,ug:0,grass:0,shadow:240};}
  else if(id==='OG6'){const x=F.OG6_L[0],z=F.OG6_L[1],y=g.at(x,z)+4;p=V3(x,y,z);const tx=F.OG5_L[0],tz=F.OG5_L[1];look=V3(tx,g.at(tx,tz)+10,tz);fov=62;opt={l0:45,l1:110,rmax:700,ug:90,grass:42,shadow:90};}
  else if(id==='OG7'){const sOG7=st.trailSAt(F.OG7_L[0],F.OG7_L[1])+(S.sOff||0),q=st.trailAt(sOG7),x=q.x,z=q.z,y=g.at(x,z)+1.8;p=V3(x,y,z);const q2=st.trailAt(sOG7+22);look=V3(q2.x,g.at(q2.x,q2.z)+1.5,q2.z);fov=70;opt={l0:38,l1:100,rmax:700,ug:view.V.ugR||85,grass:0,shadow:80,creatureS:sOG7+4.2};}
  else{ /* clearing: stand on the trail 0.9 r before the clearing centre, look across it and up */
    const cl=st.clearings.slice().sort((a,b)=>b.r-a.r)[0],sc=st.trailSAt(cl.x,cl.z),sp=Math.max(10,sc-cl.r*.95-3),q=st.trailAt(sp),x=q.x,z=q.z,y=g.at(x,z)+1.7;p=V3(x,y,z);
    look=V3(cl.x+(cl.x-x)*.6,y+Math.max(2,cl.r*.28),cl.z+(cl.z-z)*.6);fov=68;opt={l0:40,l1:100,rmax:700,ug:view.V.ugR||85,grass:50,shadow:70,creatureS:sp+4.5};}
  return{pos:p,look,fov,opt};
}
function applySlot(view,id){
  const c=slotCamera(view,id),cam=S.cam;cam.position.copy(c.pos);cam.fov=c.fov;cam.updateProjectionMatrix();cam.lookAt(c.look);
  const e=new T.Euler().setFromQuaternion(cam.quaternion,'YXZ');S.yaw=e.y;S.pitch=e.x;S.curOpt=c.opt;S.slot=id;
  /* the creature stands on the trail ahead of the camera, inside the view cone */
  if(c.opt.creatureS!==undefined){let sc=c.opt.creatureS;if(id==='CLR'){const f=c.look.clone().sub(c.pos);f.y=0;f.normalize();let best=1e9;for(let ds=2;ds<=16;ds+=.5){const q=view.st.trailAt(c.opt.creatureS-4.5+ds),dx=q.x-c.pos.x,dz=q.z-c.pos.z,d=Math.hypot(dx,dz),ang=Math.acos(clamp((dx*f.x+dz*f.z)/d,-1,1)),score=ang*10+Math.abs(d-4.5);if(d>2.5&&score<best){best=score;sc=c.opt.creatureS-4.5+ds;}}}
    const q=view.st.trailAt(sc);view.placeCreature(q.x,q.z,q.tx,q.tz);view.creature.visible=true;}
  else if(id==='OG6'){const q=view.st.trailAt(view.st.trailSAt(F.E0[0],F.E0[1])-6);view.placeCreature(q.x,q.z,q.tx,q.tz);view.creature.visible=true;}
  else{ /* flyover: show it on the trail below the camera */
    const s0=view.st.trailSAt(c.pos.x,c.pos.z),q=view.st.trailAt(s0+40);view.placeCreature(q.x,q.z,q.tx,q.tz);view.creature.visible=true;}
}
function applyCam(){const e=new T.Euler(S.pitch,S.yaw,0,'YXZ');S.cam.quaternion.setFromEuler(e);}

/* ---------------- rendering ---------------- */
function lightsAndExposure(view){S.renderer.toneMappingExposure=view.V.light.exp;}
function renderView(view,cam,x,y,w,h){
  const r=S.renderer;if(!view.built)return;
  cam.aspect=w/h;cam.updateProjectionMatrix();
  const opt=S.curOpt||{l0:38,l1:100,rmax:700,ug:85,grass:0,shadow:80};
  if(view.needsInstUpdate(cam,opt)){view.updateInstances(cam,opt);}
  view.aimShadow(cam,opt.shadow);
  if(view.beamsOn&&view.beamsFor!==S.slot+'|'+Math.round(cam.position.x/20)+'|'+Math.round(cam.position.z/20)){view.rebuildBeams(cam);view.beamsFor=S.slot+'|'+Math.round(cam.position.x/20)+'|'+Math.round(cam.position.z/20);}
  r.toneMappingExposure=view.V.light.exp;
  r.setViewport(x,y,w,h);r.setScissor(x,y,w,h);r.render(view.scene,cam);
}
function fullRender(){
  const r=S.renderer,W=S.canvas.width,H=S.canvas.height;r.setScissorTest(true);r.setRenderTarget(null);
  if(!S.compare){const v=S.views[S.ver];if(v&&v.built)renderView(v,S.cam,0,0,W,H);}
  else{const w2=Math.floor(W/2),h2=Math.floor(H/2);F.VORDER.forEach((id,i)=>{const v=S.views[id];if(!v||!v.built)return;const cam=S.camCmp[id];renderView(v,cam,(i%2)*w2,(i<2?h2:0),w2,h2);});}
}

/* ---------------- GPU measures ---------------- */
function lumOf(buf,i){return(.2126*buf[i]+.7152*buf[i+1]+.0722*buf[i+2])/255;}
function dilate(mask,w,h,rad){ /* box dilation by rad px (separable max filter over the sorted hit lists) */
  const a=new Uint8Array(w*h),b=new Uint8Array(w*h);
  for(let y=0;y<h;y++){const o=y*w,idx=[];for(let x=0;x<w;x++)if(mask[o+x])idx.push(x);let p=0;
    for(let x=0;x<w;x++){while(p<idx.length&&idx[p]<x-rad)p++;a[o+x]=(p<idx.length&&idx[p]<=x+rad)?1:0;}}
  for(let x=0;x<w;x++){const idx=[];for(let y=0;y<h;y++)if(a[y*w+x])idx.push(y);let p=0;
    for(let y=0;y<h;y++){while(p<idx.length&&idx[p]<y-rad)p++;b[y*w+x]=(p<idx.length&&idx[p]<=y+rad)?1:0;}}
  return b;
}
function readCanvas(){const r=S.renderer,gl=r.getContext(),w=S.canvas.width,h=S.canvas.height,buf=new Uint8Array(w*h*4);gl.readPixels(0,0,w,h,gl.RGBA,gl.UNSIGNED_BYTE,buf);return buf;}
function renderRT(view,cam,mode){ /* mode: 'mask' | 'sun' | 'lin' ; returns RGBA bytes of an offscreen render at canvas size */
  const r=S.renderer,w=S.canvas.width,h=S.canvas.height;if(!S.rt||S.rt.width!==w||S.rt.height!==h){if(S.rt)S.rt.dispose();S.rt=new T.WebGLRenderTarget(w,h,{minFilter:T.NearestFilter,magFilter:T.NearestFilter,depthBuffer:true});}
  const U=view.U,tm=r.toneMapping,saved={far:U.uFogFar.value,den:U.uFogDen.value,sunI:view.sun.intensity,hemiI:view.hemi.intensity,beams:view.beams.visible};
  r.toneMapping=T.NoToneMapping;
  if(mode==='mask'){U.uMask.value=1;view.beams.visible=false;}
  else if(mode==='height'){U.uMask.value=3;view.beams.visible=false;}
  else if(mode==='sun'){view.beams.visible=false;U.uFogDen.value=0;U.uFogFar.value=0;view.sun.intensity=8;view.hemi.intensity=0;view.dome.visible=false;}
  else if(mode==='lin'){view.beams.visible=false;U.uFogDen.value=0;U.uFogFar.value=0;}
  r.setRenderTarget(S.rt);r.setScissorTest(false);r.setViewport(0,0,w,h);r.render(view.scene,cam);
  const buf=new Uint8Array(w*h*4);r.readRenderTargetPixels(S.rt,0,0,w,h,buf);
  r.setRenderTarget(null);r.toneMapping=tm;U.uMask.value=0;U.uFogDen.value=saved.den;U.uFogFar.value=saved.far;view.sun.intensity=saved.sunI;view.hemi.intensity=saved.hemiI;view.dome.visible=true;view.beams.visible=saved.beams;
  return buf;
}
function flipRows(buf,w,h){const o=new Uint8Array(buf.length);for(let y=0;y<h;y++)o.set(buf.subarray((h-1-y)*w*4,(h-y)*w*4),y*w*4);return o;}
/* measures at one slot; leaves the canvas showing the slot's normal frame */
function measureSlot(id){
  const view=S.views[S.ver],r=S.renderer,res={slot:id};
  setSlot(id);const w=S.canvas.width,h=S.canvas.height;
  fullRender();const disp=readCanvas();   /* bottom-up RGBA from the canvas */
  const maskRaw=renderRT(view,S.cam,'mask');
  fullRender();
  const px=w*h,mask=new Uint8Array(px),terr=new Uint8Array(px),trail=new Uint8Array(px),cre=new Uint8Array(px),veg=new Uint8Array(px);
  for(let i=0;i<px;i++){const R=maskRaw[i*4],G=maskRaw[i*4+1],B=maskRaw[i*4+2];
    if(R>200){terr[i]=1;if(G>128)trail[i]=1;}else if(G>200&&R<60&&B<60)cre[i]=1;else if(B>200)veg[i]=1;}
  const L=new Float32Array(px);for(let i=0;i<px;i++)L[i]=lumOf(disp,i*4);
  const mean=(m,arr)=>{let s=0,n=0;for(let i=0;i<px;i++)if(m[i]){s+=arr[i];n++;}return n?s/n:0;};
  /* trail contrast: trail pixels vs the ring around them */
  const nTr=trail.reduce((a,b)=>a+b,0);
  if(nTr>150){const d1=dilate(trail,w,h,2),d2=dilate(trail,w,h,14),ring=new Uint8Array(px);for(let i=0;i<px;i++)ring[i]=(d2[i]&&!d1[i])?1:0;
    const lt=mean(trail,L),lr=mean(ring,L);res.trailPx=nTr;res.trailL=lt;res.trailRingL=lr;res.trailContrast=Math.abs(lt-lr);}
  else{res.trailPx=nTr;res.trailContrast=null;}
  /* creature readability: score.py dist_contrast, ring = dilate 30 minus dilate 3 */
  const nC=cre.reduce((a,b)=>a+b,0);
  if(nC>=50){const d1=dilate(cre,w,h,3),d2=dilate(cre,w,h,30),ring=new Uint8Array(px);for(let i=0;i<px;i++)ring[i]=(d2[i]&&!d1[i])?1:0;
    const lc=mean(cre,L),lr=mean(ring,L);res.creaturePx=nC;res.distContrast=Math.abs(lc-lr);}else{res.creaturePx=nC;res.distContrast=null;}
  /* sun-lit fraction of the frame */
  const sunBuf=renderRT(view,S.cam,'sun');let lit=0,litAll=0;
  for(let i=0;i<px;i++){if(sunBuf[i*4]+sunBuf[i*4+1]+sunBuf[i*4+2]>10){litAll++;if(terr[i]||cre[i])lit++;}}
  res.sunFrac=lit/px;res.sunFracAll=litAll/px;   /* sunFrac: sunlit ground and creature pixels (the patches and shafts on the floor); sunFracAll adds every lit leaf and trunk in view */
  /* ground luminance with and without the canopy (linear, no fog, same pixels) */
  const tg=terr.reduce((a,b)=>a+b,0);
  if(tg>200){
    view.sun.castShadow=true;
    const withBuf=renderRT(view,S.cam,'lin');
    const vegVis=[];for(const k in view.im){if(view.im[k].visible){vegVis.push(view.im[k]);view.im[k].visible=false;}}
    const bv=view.beams.visible;
    renderer_shadowRefresh();
    view.U.uAO.value=0;const withoutBuf=renderRT(view,S.cam,'lin');view.U.uAO.value=1;
    for(const m of vegVis)m.visible=true;view.beams.visible=bv;renderer_shadowRefresh();
    let a=0,b=0;for(let i=0;i<px;i++)if(terr[i]){a+=(.2126*withBuf[i*4]+.7152*withBuf[i*4+1]+.0722*withBuf[i*4+2]);b+=(.2126*withoutBuf[i*4]+.7152*withoutBuf[i*4+1]+.0722*withoutBuf[i*4+2]);}
    res.groundPx=tg;res.lumRatio=b>0?a/b:null;
  }
  res.stats=Object.assign({},view.stats);
  fullRender();
  return res;
}
/* OG7 depends on where the trail happens to pass a gap, so the judged numbers are the mean of five frames 20 m apart along the trail (the plan's single OG7 frame is the middle one) */
function measureOG7(){
  const offs=[-40,-20,0,20,40],rs=[];for(const o of offs){S.sOff=o;rs.push(measureSlot('OG7'));}S.sOff=0;
  const keys=['trailContrast','distContrast','sunFrac','sunFracAll','lumRatio','trailPx','creaturePx'],res=Object.assign({},rs[2]);
  res.frames=rs.length;res.perFrame=rs.map(r=>({lumRatio:r.lumRatio,sunFrac:r.sunFrac,trailContrast:r.trailContrast,distContrast:r.distContrast}));
  for(const k of keys){const v=rs.map(r=>r[k]).filter(x=>x!=null&&isFinite(x));res[k]=v.length?v.reduce((a,b)=>a+b,0)/v.length:null;}
  res.stats=rs[2].stats;setSlot('OG7');fullRender();return res;
}
function renderer_shadowRefresh(){S.renderer.shadowMap.needsUpdate=true;}

/* ---------------- public ---------------- */
function setSlot(id){const v=S.views[S.ver];if(!v||!v.built)return;S.slot=id;S.free=false;applySlot(v,id);S.renderer.shadowMap.needsUpdate=true;v.lastInst=null;if(v.beamsOn)v.beamsFor=null;
  S.camCmp=S.camCmp||{};F.VORDER.forEach(k=>{const vv=S.views[k];if(!vv||!vv.built)return;const c=slotCamera(vv,id),cam=new T.PerspectiveCamera(c.fov,16/9,.1,4000);cam.position.copy(c.pos);cam.lookAt(c.look);S.camCmp[k]=cam;});}
async function ensure(id,progress){const v=S.views[id]||(S.views[id]=new View(id));if(!v.built&&!v.building){v.building=v.build(progress).then(()=>{v.building=null;});}await v.building;return v;}
async function setVersion(id,progress){S.ver=id;const v=await ensure(id,progress);S.renderer.shadowMap.needsUpdate=true;v.lastInst=null;setSlot(S.slot);return v;}
async function init(canvas,tileBuf,progress){
  S.canvas=canvas;const r=S.renderer=new T.WebGLRenderer({canvas,antialias:true,preserveDrawingBuffer:true,powerPreference:'low-power'});
  r.outputEncoding=T.sRGBEncoding;r.toneMapping=T.ACESFilmicToneMapping;r.shadowMap.enabled=true;r.shadowMap.type=T.PCFSoftShadowMap;r.setClearColor(0x000000);
  const [gb,jb]=await Promise.all([fetch('forest_assets/trees.glb').then(r=>r.arrayBuffer()),fetch('forest_assets/trees.json').then(r=>r.json())]);
  F.setAssets({glb:FT.parseGLB(gb),meta:jb,bytes:gb.byteLength});
  S.tile=F.parseTile(tileBuf);S.ground=new F.Ground(S.tile);S.ready=true;
  await setVersion(S.ver,progress);
}
function frameInfo(){const v=S.views[S.ver];return v&&v.built?Object.assign({ver:S.ver,slot:S.slot},v.stats,{trail:v.st.trail.pts.length}):{};}
function move(f,r,u,dt){const cam=S.cam,v=S.views[S.ver];const dir=new T.Vector3(0,0,-1).applyQuaternion(cam.quaternion);dir.y=0;dir.normalize();const side=new T.Vector3().crossVectors(dir,new T.Vector3(0,1,0));
  const sp=(S.slot==='OG5'||S.free==='fly'?30:2.4)*dt;cam.position.addScaledVector(dir,f*sp).addScaledVector(side,r*sp);
  if(S.slot==='OG5'){cam.position.y+=u*sp;}else{const gy=S.ground.at(cam.position.x,cam.position.z);cam.position.y=gy+1.7+Math.max(0,u*0);}
  cam.position.x=clamp(cam.position.x,-590,590);cam.position.z=clamp(cam.position.z,-590,590);S.free=true;}
function look(dx,dy){S.yaw-=dx;S.pitch=clamp(S.pitch-dy,-1.4,1.4);applyCam();S.free=true;}
return{S,F,init,setVersion,setSlot,ensure,fullRender,measureSlot,measureOG7,frameInfo,move,look,renderView,applyCam,
  setCompare(v){S.compare=!!v;S.renderer.shadowMap.needsUpdate=true;},
  setSize(w,h){S.renderer.setSize(w,h,false);S.cam.aspect=w/h;S.cam.updateProjectionMatrix();S.renderer.shadowMap.needsUpdate=true;},
  views:S.views};
})();
