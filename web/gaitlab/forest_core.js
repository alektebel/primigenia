'use strict';
/* forest_core.js: the jungle look-study lab (docs/plans/island-realism.md section 5, step L1; owner decisions A95, A97, A98, A99).
 * A 600 m tile of the Star massif forest vale (terrain_cli crop of the real C terrain, layout 1, seed 1, centre world (700, -900)), the T0 stand-in
 * trees from forest_trees.js, four stand versions (A Laurisilva, B Cloud forest, C Cathedral, D Tangle), four camera slots and the judging
 * measures of the plan's table, computed from the very data that is drawn. Local frame: x east, z south, y up, tile centre at the origin. */
const FOREST=(()=>{
const T=THREE,{rng32,hash2,vnoise,fbm,lerp,clamp,sstep,V3}=FT;
const TILE_CX=700,TILE_CZ=-900,EXT=780,GRID=2,N1=EXT*2/GRID+1,STAND_HALF=720;
const WORLD2LOCAL=(wx,wz)=>[wx-TILE_CX,wz-TILE_CZ];
const OG6_L=WORLD2LOCAL(520,-640),OG5_L=WORLD2LOCAL(874,-1076),OG7_L=WORLD2LOCAL(940,-1180);
const AXL=Math.hypot(OG5_L[0]-OG6_L[0],OG5_L[1]-OG6_L[1]),AX=[(OG5_L[0]-OG6_L[0])/AXL,(OG5_L[1]-OG6_L[1])/AXL];
const E0=[OG6_L[0]+AX[0]*34,OG6_L[1]+AX[1]*34];                 /* the forest edge crosses the axis 34 m in front of OG6 */
const axisS=(x,z)=>(x-E0[0])*AX[0]+(z-E0[1])*AX[1],axisL=(x,z)=>-(x-E0[0])*AX[1]+(z-E0[1])*AX[0];
const axisPt=(s,l)=>[E0[0]+AX[0]*s-AX[1]*l,E0[1]+AX[1]*s+AX[0]*l];

/* ---------------- terrain tile ---------------- */
function parseTile(buf){
  const dv=new DataView(buf),mg=String.fromCharCode(...new Uint8Array(buf,0,6));if(mg!=='CPCROP')throw new Error('bad crop file');
  const m=dv.getUint32(12,true),cell=dv.getFloat32(16,true),x0=dv.getFloat32(20,true),z0=dv.getFloat32(24,true),nn=m*m;
  const h=new Float32Array(buf.slice(28,28+4*nn)),flow=new Float32Array(buf.slice(28+4*nn,28+8*nn)),mat=new Uint8Array(buf,28+8*nn,nn),riv=new Uint8Array(buf,28+9*nn,nn);
  let mn=1e9;for(let i=0;i<nn;i++)mn=Math.min(mn,h[i]);
  return{m,cell,x0,z0,h,flow,mat,riv,ymin:mn};
}
const reflect=(i,m)=>{const p=2*(m-1);let k=((i%p)+p)%p;return k>m-1?p-k:k;};
const cr=(a,b,c,d,t)=>.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t);
class Ground{
  constructor(tile,sigmaCells){
    this.tile=tile;const{m,cell,x0,z0,ymin}=tile;this.hg=new Float32Array(N1*N1);
    /* the 5 m C terrain carries cliff-band stair steps (3-4 m risers) that read as 40-48 degree ground; a light Gaussian low-pass keeps the macro relief
       (the vale, ridges, streams) and removes the staircase. sigma in cells, 0 = raw. */
    const sg=sigmaCells==null?1.3:sigmaCells;let h=tile.h;
    if(sg>0){const r=Math.ceil(sg*3),k=[];let ks=0;for(let i=-r;i<=r;i++){const v=Math.exp(-i*i/(2*sg*sg));k.push(v);ks+=v;}
      const t1=new Float32Array(m*m),t2=new Float32Array(m*m);
      for(let j=0;j<m;j++)for(let i=0;i<m;i++){let a=0;for(let q=-r;q<=r;q++)a+=k[q+r]*tile.h[j*m+reflect(i+q,m)];t1[j*m+i]=a/ks;}
      for(let j=0;j<m;j++)for(let i=0;i<m;i++){let a=0;for(let q=-r;q<=r;q++)a+=k[q+r]*t1[reflect(j+q,m)*m+i];t2[j*m+i]=a/ks;}
      h=t2;}
    this.smooth=sg;
    for(let j=0;j<N1;j++)for(let i=0;i<N1;i++){
      const X=-EXT+i*GRID,Z=-EXT+j*GRID,fx=(X+TILE_CX-x0)/cell,fy=(Z+TILE_CZ-z0)/cell,ix=Math.floor(fx),iy=Math.floor(fy),tx=fx-ix,ty=fy-iy,col=[];
      for(let q=-1;q<=2;q++){const r=[];for(let p=-1;p<=2;p++)r.push(h[reflect(iy+q,m)*m+reflect(ix+p,m)]);col.push(cr(r[0],r[1],r[2],r[3],tx));}
      /* the 5 m cells of the C terrain are smooth; add the mounds, root humps and hollows a forest floor really has (0.4 m at 9 m, 0.12 m at 2.5 m) */
      this.hg[j*N1+i]=cr(col[0],col[1],col[2],col[3],ty)-ymin+(fbm(X/9,Z/9,3,5)-.5)*1.1+(vnoise(X/2.5,Z/2.5,9)-.5)*.3;
    }
  }
  at(X,Z){const u=clamp((X+EXT)/GRID,0,N1-1.001),v=clamp((Z+EXT)/GRID,0,N1-1.001),i=Math.floor(u),j=Math.floor(v),a=u-i,b=v-j,H=this.hg,k=j*N1+i;
    return lerp(lerp(H[k],H[k+1],a),lerp(H[k+N1],H[k+N1+1],a),b);}
  slopeDeg(X,Z){const e=1.5,dx=(this.at(X+e,Z)-this.at(X-e,Z))/(2*e),dz=(this.at(X,Z+e)-this.at(X,Z-e))/(2*e);return Math.atan(Math.hypot(dx,dz))*57.2958;}
  normal(X,Z,out){const e=1.2,dx=this.at(X+e,Z)-this.at(X-e,Z),dz=this.at(X,Z+e)-this.at(X,Z-e);out.set(-dx,2*e,-dz).normalize();return out;}
  riverAt(X,Z){const t=this.tile,fx=Math.round((X+TILE_CX-t.x0)/t.cell),fy=Math.round((Z+TILE_CZ-t.z0)/t.cell);
    if(fx<0||fy<0||fx>=t.m||fy>=t.m)return 0;return t.riv[fy*t.m+fx]&3;}
}

/* ---------------- versions ---------------- */
const LEAFTINT={A:[1,1,.9],B:[.92,.98,.95],C:[1.02,1,.86],D:[.86,.95,.8]};
const VERSIONS={
 A:{id:'A',name:'Laurisilva',org:'Tenerife Anaga / La Gomera Garajonay, Madeira Fanal',
  tag:'Closure about 85%. Two layers: a 15-22 m laurel canopy over a fern understory. Soft green diffuse light, no shafts. Narrow 1.2 m trails, few clearings.',
  classes:{
   canopy:{clumpScale:1.3,src:'laurel',dens:140,minD:.6,H:[15,22],dbh:[.42,1.15],firstBr:[3,6.5],crownR:[4.2,5.6],buttA:.3,buttN:5,buttH:1.6,limbs:6,clumpR:2.7,nClump:14,layers:2,lean:.1,moss:.55,epi:.5,hang:.35,vines:3,vineMoss:.25,leaf:'laurel',nv:5,cardSize:1.5,leafDensity:1.1},
   under:{src:'small',dens:95,minD:.7,H:[4.5,8],dbh:[.1,.22],firstBr:[2.3,3],crownR:[1.8,2.6],buttA:.1,buttN:4,buttH:.8,limbs:3,clumpR:1.5,nClump:5,layers:1,lean:.1,moss:.3,epi:.2,hang:.1,vines:0,vineMoss:0,leaf:'laurel',nv:3,cardSize:1.1,leafDensity:.9},
   sap:{src:'sap',dens:110,minD:.4,nv:3,leaf:'laurel',cardSize:.8,leafDensity:.8,moss:.4,epi:0,hang:0,vines:0,vineMoss:0,clumpScale:.7},
   tfern:{dens:22,minD:.9,H:[2.4,4.6],r:.12,fl:1.9}},
  ug:{fern:{lam:.6,r:[.5,.8],h:[.55,1.3]},fernL:{lam:.2,r:[.7,1.1],h:[1,1.5]},shrub:{lam:.05,r:[.7,1.1],h:[.8,1.6]},light:[.7,1.25]},
  gaps:1.4,logs:6,rocks:10,trail:{w:1.2,stream:false},clearings:[[250,20,9],[430,-16,10]],
  light:{sunAz:.9,sunEl:.78,sunI:.9,sunCol:[1,.93,.78],hemiI:1.55,hemiSky:[.62,.82,.58],hemiGnd:[.2,.17,.1],exp:.95,sky:[.52,.66,.78],hor:[.76,.84,.82]},
  fog:{den:.0042,k:.035,base:-5,far:.0016,col:[.62,.72,.69]},shafts:false,aoK:1.45,moss:.45,skyGamma:1,mossGround:.45},
 B:{id:'B',name:'Cloud forest',org:'Monteverde, Garajonay "Bosque Encantado", Fanal fog',
  tag:'Closure about 90%. Three layers with moss-draped limbs, epiphyte ferns, rope vines and tree ferns. Fog stands between the trunks, light is diffused and grey-green. Mossy logs; 1.5 m trails along streams, small spring clearings.',
  classes:{
   giant:{src:'giant',dens:6,minD:.8,H:[22,27],dbh:[1.0,1.6],firstBr:[4,8],crownR:[6,7.5],buttA:.75,buttN:5,buttH:2.6,limbs:6,clumpR:3.1,nClump:14,layers:2,lean:.1,moss:.9,epi:1.6,hang:1.2,vines:6,vineMoss:.8,leaf:'cloud',nv:2,cardSize:1.6,leafDensity:1.0},
   canopy:{clumpScale:1.3,src:'laurel',dens:140,minD:.6,H:[13,19],dbh:[.42,1.05],firstBr:[2.8,5.5],crownR:[3.8,5.2],buttA:.3,buttN:5,buttH:1.4,limbs:6,clumpR:2.6,nClump:15,layers:2,lean:.16,moss:.9,epi:1.2,hang:1.1,vines:5,vineMoss:.8,leaf:'cloud',nv:5,cardSize:1.45,leafDensity:1.05},
   under:{src:'small',dens:125,minD:.7,H:[4,7],dbh:[.08,.2],firstBr:[2.3,3],crownR:[1.8,2.6],buttA:.1,buttN:4,buttH:.8,limbs:3,clumpR:1.5,nClump:5,layers:1,lean:.14,moss:.8,epi:.5,hang:.4,vines:0,vineMoss:0,leaf:'cloud',nv:3,cardSize:1.05,leafDensity:.9},
   sap:{src:'sap',dens:150,minD:.4,nv:3,leaf:'cloud',cardSize:.8,leafDensity:.8,moss:.8,epi:0,hang:0,vines:0,vineMoss:0,clumpScale:.7},
   tfern:{dens:55,minD:.9,H:[2.4,5.2],r:.13,fl:2.1}},
  ug:{fern:{lam:.72,r:[.5,.85],h:[.55,1.3]},fernL:{lam:.22,r:[.7,1.1],h:[1,1.5]},shrub:{lam:.06,r:[.7,1.1],h:[.8,1.5]},light:[.8,1.2]},
  gaps:1.8,logs:26,rocks:26,trail:{w:1.5,stream:true},clearings:'springs',
  light:{sunAz:.9,sunEl:.74,sunI:1.15,sunCol:[1,.95,.85],hemiI:1.45,hemiSky:[.78,.86,.8],hemiGnd:[.2,.2,.16],exp:1.0,sky:[.86,.89,.89],hor:[.86,.89,.88]},
  fog:{den:.058,k:.028,base:-10,far:.0042,col:[.86,.89,.88]},shafts:false,aoK:2.0,moss:.95,skyGamma:1,mossGround:.8},
 C:{id:'C',name:'Cathedral',org:'tall emergent forest, Hoh and lowland rainforest light',
  tag:'Closure about 80% with buttressed emergents to 30 m over tall straight canopy trunks. Open understory except in gaps. Strong light shafts in 3-4 large clearings with fruit trees and a landmark giant; 2 m trails.',
  classes:{
   giant:{clumpScale:2.1,src:'giant',dens:20,minD:.9,H:[26,32],dbh:[1.4,2.3],firstBr:[13,18],crownR:[7.5,9.5],buttA:1.35,buttN:5,buttH:3.6,limbs:7,clumpR:3.6,nClump:15,layers:1,lean:.03,moss:.3,epi:.5,hang:.15,vines:3,vineMoss:.2,leaf:'broad',nv:2,cardSize:1.8,leafDensity:1.0},
   canopy:{clumpScale:2.1,src:'tall',dens:135,minD:.62,H:[19,25],dbh:[.5,1.0],firstBr:[9,14],crownR:[4.8,6],buttA:.55,buttN:5,buttH:2.2,limbs:6,clumpR:2.9,nClump:13,layers:1,lean:.03,moss:.25,epi:.2,hang:.1,vines:2,vineMoss:.2,leaf:'broad',nv:3,cardSize:1.6,leafDensity:.95},
   under:{src:'small',dens:28,minD:.8,H:[4,8],dbh:[.1,.2],firstBr:[2.4,3.2],crownR:[1.8,2.8],buttA:.1,buttN:4,buttH:.8,limbs:3,clumpR:1.6,nClump:5,layers:1,lean:.08,moss:.2,epi:.1,hang:0,vines:0,vineMoss:0,leaf:'broad',nv:3,cardSize:1.2,leafDensity:.9},
   sap:{src:'sap',dens:22,minD:.4,nv:3,leaf:'broad',cardSize:.8,leafDensity:.8,moss:.2,epi:0,hang:0,vines:0,vineMoss:0,clumpScale:.7},
   tfern:{dens:14,minD:.9,H:[2.5,4.5],r:.12,fl:2},
   fruit:{src:'small',dens:0,minD:.8,H:[5,8],dbh:[.2,.34],firstBr:[2.4,3],crownR:[2.6,3.4],buttA:.15,buttN:4,buttH:1,limbs:4,clumpR:1.8,nClump:7,layers:1,lean:.1,moss:.1,epi:0,hang:0,vines:0,vineMoss:0,leaf:'broad',nv:2,cardSize:1.2,leafDensity:.9,fruit:.9}},
  ug:{fern:{lam:.04,r:[.5,.8],h:[.55,1.2]},fernL:{lam:.02,r:[.7,1.1],h:[1,1.5]},shrub:{lam:.012,r:[.7,1.1],h:[.8,1.5]},light:[.45,7.5]},
  gaps:.8,logs:6,rocks:8,trail:{w:2.0,stream:false},clearings:[[130,16,21],[290,-22,24],[440,12,19],[560,-14,17]],
  light:{sunAz:.9,sunEl:.82,sunI:2.1,sunCol:[1,.9,.72],hemiI:1.5,hemiSky:[.62,.78,.6],hemiGnd:[.16,.15,.09],exp:.88,sky:[.34,.55,.82],hor:[.74,.82,.86]},
  fog:{den:.0024,k:.03,base:-5,far:.0012,col:[.62,.73,.78]},shafts:true,aoK:2.1,moss:.3,skyGamma:1,mossGround:.35},
 D:{id:'D',name:'Tangle',org:'dwarf cloud forest, Honduras Cusuco, Fanal scrub',
  tag:'Closure about 95%. Low 10-14 m crooked canopy hung with lianas. Darkest light, very dense undergrowth that slows you most; game trails are the only fast way.',
  classes:{
   canopy:{clumpScale:1.3,src:'crooked',dens:250,minD:.55,H:[9,14],dbh:[.3,.75],firstBr:[2.8,4.4],crownR:[3,4.2],buttA:.25,buttN:5,buttH:1,limbs:6,clumpR:2.2,nClump:13,layers:2,lean:.34,moss:.7,epi:.6,hang:.7,vines:9,vineMoss:.5,leaf:'small',nv:3,cardSize:1.2,leafDensity:.85},
   under:{src:'small',dens:110,minD:.55,H:[3,5.5],dbh:[.06,.16],firstBr:[2.2,3],crownR:[1.5,2.3],buttA:.08,buttN:4,buttH:.6,limbs:3,clumpR:1.35,nClump:5,layers:1,lean:.2,moss:.5,epi:.2,hang:.3,vines:2,vineMoss:.4,leaf:'small',nv:3,cardSize:.95,leafDensity:1.0},
   sap:{src:'sap',dens:190,minD:.4,nv:3,leaf:'small',cardSize:.8,leafDensity:.8,moss:.6,epi:0,hang:0,vines:0,vineMoss:0,clumpScale:.7},
   tfern:{dens:75,minD:.8,H:[2,4.2],r:.12,fl:1.9}},
  ug:{fern:{lam:1.1,r:[.55,.95],h:[.7,1.5]},fernL:{lam:.36,r:[.8,1.2],h:[1.2,1.8]},shrub:{lam:.3,r:[.8,1.3],h:[1,1.9]},light:[.9,1.1]},
  gaps:1.6,logs:14,rocks:14,ugR:42,trail:{w:1.0,stream:false},clearings:[[330,10,5]],
  light:{sunAz:.9,sunEl:.7,sunI:.95,sunCol:[1,.92,.8],hemiI:1.3,hemiSky:[.54,.74,.5],hemiGnd:[.13,.14,.08],exp:1.0,sky:[.55,.65,.7],hor:[.68,.76,.73]},
  fog:{den:.0075,k:.045,base:-6,far:.0022,col:[.52,.6,.56]},shafts:false,aoK:1.9,moss:.55,skyGamma:1,mossGround:.55}
};
const VORDER=['A','B','C','D'];
const SLOT_LIST=[
 {id:'OG5',label:'OG5 canopy flyover',help:'150 m above the vale, looking NE along it: closure from above, impostor range'},
 {id:'OG6',label:'OG6 forest edge',help:'4 m above the meadow, 35 m before the edge: edge structure and LOD transitions'},
 {id:'OG7',label:'OG7 under the canopy',help:'1.8 m on the game trail: light, undergrowth, trail readability, a climbable trunk'},
 {id:'CLR',label:'Clearing',help:'on the trail at the edge of a clearing: fruit, light shafts, the creature for scale'}];

/* ---------------- shared textures and materials ---------------- */
let SHARED=null,ASSETS=null;
function sharedTextures(){
  if(SHARED)return SHARED;
  const bark=FT.barkTex(3,.5),floor={litter:FT.floorTex('litter',11),moss:FT.floorTex('moss',23),dirt:FT.floorTex('dirt',31)};
  const leaf={};for(const s of['laurel','cloud','broad','small'])leaf[s]=FT.leafTex(s,s.length*13+5);
  const blob={};for(const s in leaf)blob[s]=FT.blobTexFrom(leaf[s]);
  SHARED={bark,floor,trail:FT.trailTex(41),leaf,blob,fern:FT.fernTex(5,false),fernB:FT.fernTex(9,true),moss:FT.mossHangTex(7),grass:FT.grassTex(3)};
  return SHARED;
}
const GLSL_HEAD='uniform vec3 uFogColor;uniform float uFogDen,uFogK,uFogBase,uFogFar;uniform vec3 uSunDir,uSunCol;uniform float uMask;uniform vec3 uMaskCol;varying vec3 vWP;\n';
const FOG_FRAG=`
{vec3 vd=vWP-cameraPosition;float dist=length(vd);float dy=vWP.y-cameraPosition.y;float kk=uFogK*dy;
 float avg=abs(kk)<1e-3?1.0:(1.0-exp(-kk))/kk;float tau=uFogDen*dist*exp(-uFogK*(cameraPosition.y-uFogBase))*avg+uFogFar*dist;
 float ff=1.0-exp(-clamp(tau,0.0,12.0));float sunk=pow(max(dot(normalize(vd),uSunDir),0.0),6.0);
 vec3 fc=uFogColor+uSunCol*sunk*0.28;gl_FragColor.rgb=mix(gl_FragColor.rgb,fc,ff);}
`;
function patchMat(mat,U,o){
  o=o||{};
  mat.onBeforeCompile=sh=>{
    for(const k of['uFogColor','uFogDen','uFogK','uFogBase','uFogFar','uSunDir','uSunCol','uMask'])sh.uniforms[k]=U[k];
    sh.uniforms.uMaskCol={value:new T.Vector3(...(o.mask||[0,0,1]))};
    sh.vertexShader=(o.bill?'attribute vec3 aCen;attribute vec2 aOff;\n':'')+'varying vec3 vWP;\n'+(o.terrain?'attribute float aTrail;attribute float aMoss;attribute float aSky;attribute float aMead;attribute float aRock;varying float vTrail;varying float vMoss;varying float vSky;varying float vMead;varying float vRock;\n':'')+sh.vertexShader
      .replace('#include <begin_vertex>',o.bill?`vec3 transformed=vec3(position);
        {mat4 BM=modelMatrix;
        #ifdef USE_INSTANCING
        BM=modelMatrix*instanceMatrix;
        #endif
        vec3 bc0=BM[0].xyz,bc1=BM[1].xyz,bc2=BM[2].xyz;
        vec3 vr=vec3(viewMatrix[0][0],viewMatrix[1][0],viewMatrix[2][0]),vu=vec3(viewMatrix[0][1],viewMatrix[1][1],viewMatrix[2][1]);
        vec3 lr=normalize(vec3(dot(bc0,vr),dot(bc1,vr),dot(bc2,vr))),lu=normalize(vec3(dot(bc0,vu),dot(bc1,vu),dot(bc2,vu)));
        transformed=mix(transformed,aCen+lr*aOff.x+lu*aOff.y,0.8);}`:'#include <begin_vertex>')
      .replace('#include <project_vertex>',`#include <project_vertex>
        {vec4 wp4=vec4(transformed,1.0);
        #ifdef USE_INSTANCING
        wp4=instanceMatrix*wp4;
        #endif
        vWP=(modelMatrix*wp4).xyz;}`+(o.terrain?'vTrail=aTrail;vMoss=aMoss;vSky=aSky;vMead=aMead;vRock=aRock;':''));
    let f=GLSL_HEAD+(o.terrain?'varying float vTrail;varying float vMoss;varying float vSky;varying float vMead;varying float vRock;uniform float uAO,uAOk;uniform sampler2D tLitter,tMoss,tDirt;uniform vec3 uMeadCol,uMeanL,uMeanM,uMeanD;uniform float uMossK;\n':'')+sh.fragmentShader;
    if(o.faceFix)f=f.replace('#include <normal_fragment_begin>',T.ShaderChunk.normal_fragment_begin.replace('float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;','float faceDirection = 1.0;'));
    f=f.replace('#include <fog_fragment>',o.nofog?'':FOG_FRAG);
    if(o.terrain){
      sh.uniforms.uAO=U.uAO;sh.uniforms.uAOk=U.uAOk;sh.uniforms.tLitter={value:SHARED.floor.litter.map};sh.uniforms.tMoss={value:SHARED.floor.moss.map};sh.uniforms.tDirt={value:o.ribbon?SHARED.trail.map:SHARED.floor.dirt.map};
      sh.uniforms.uMeadCol={value:o.meadCol};sh.uniforms.uMeanL={value:new T.Vector3(...SHARED.floor.litter.mean)};sh.uniforms.uMeanM={value:new T.Vector3(...SHARED.floor.moss.mean)};sh.uniforms.uMeanD={value:new T.Vector3(...SHARED.floor.dirt.mean)};sh.uniforms.uMossK={value:o.mossK};
      const RIB=o.ribbon?'gr=mix(mossC*1.2,pow(texture2D(tDirt,vUv).rgb,vec3(2.2))*1.2,smoothstep(.22,.6,vTrail));diffuseColor.a*=smoothstep(0.02,0.4,vTrail);':'';
      f=f.replace('#include <map_fragment>',`
        vec2 wuv=vWP.xz;
        vec3 l1=pow(texture2D(tLitter,wuv*0.31).rgb,vec3(2.2)),l2=pow(texture2D(tLitter,wuv*0.067+vec2(.37,.11)).rgb,vec3(2.2)),l3=pow(texture2D(tLitter,wuv*1.3+vec2(.5,.9)).rgb,vec3(2.2));
        vec3 m1=pow(texture2D(tMoss,wuv*0.27).rgb,vec3(2.2)),m2=pow(texture2D(tMoss,wuv*0.059+vec2(.2,.6)).rgb,vec3(2.2)),m3=pow(texture2D(tMoss,wuv*1.1).rgb,vec3(2.2));
        vec3 d1=pow(texture2D(tDirt,wuv*0.42).rgb,vec3(2.2)),d2=pow(texture2D(tDirt,wuv*0.09).rgb,vec3(2.2));
        float lm=dot(uMeanL,vec3(.2126,.7152,.0722)),mm=dot(uMeanM,vec3(.2126,.7152,.0722)),dm=dot(uMeanD,vec3(.2126,.7152,.0722));
        vec3 W3=vec3(.2126,.7152,.0722);
        vec3 litter=vec3(.098,.072,.046)*mix(vec3(dot(l1,W3)/lm),l1/uMeanL,.3)*pow(dot(l2,W3)/lm,.5)*pow(dot(l3,W3)/lm,.55);
        vec3 mossC=vec3(.085,.135,.045)*mix(vec3(dot(m1,W3)/mm),m1/uMeanM,.35)*pow(dot(m2,W3)/mm,.5)*pow(dot(m3,W3)/mm,.5);
        vec3 dirt=vec3(.45,.35,.26)*mix(1.0,dot(d1,W3)/dm,.1);
        vec3 rockC=mix(vec3(.13,.125,.115),mossC*.75,.5);
        vec3 gr=mix(litter,mossC,clamp(vMoss*uMossK,0.0,1.0));
        gr=mix(gr,rockC,vRock);
        float n1=dot(pow(texture2D(tMoss,wuv*0.019).rgb,vec3(2.2)),W3)/mm,n2=dot(pow(texture2D(tLitter,wuv*0.031+vec2(.3,.7)).rgb,vec3(2.2)),W3)/lm,nd=dot(m1,W3)/mm;
        vec3 mead=uMeadCol*(0.5+0.75*n1)*(0.8+0.4*nd);
        mead=mix(mead,vec3(.2,.155,.065)*(0.7+0.5*nd),smoothstep(0.95,1.5,n2)*0.75);
        mead=mix(mead,vec3(.19,.15,.1)*(0.8+0.4*nd),smoothstep(1.5,2.1,n1*n2));
        mead=mix(mead,vec3(.045,.07,.025)*(0.8+0.5*nd),smoothstep(1.0,0.5,n1)*0.5);
        gr=mix(gr,mead,vMead);
        gr=mix(gr,dirt,vTrail*0.97);
        
        ${RIB}
        diffuseColor.rgb*=gr;`);
      f=f.replace('#include <aomap_fragment>','#include <aomap_fragment>\nreflectedLight.indirectDiffuse*=mix(1.0,mix(0.07+0.93*pow(vSky,uAOk),0.4+0.6*pow(vSky,.8),vTrail*0.7),uAO);');
    }
    f=f.replace('#include <dithering_fragment>',`#include <dithering_fragment>
      if(uMask>2.5){gl_FragColor=vec4(clamp(vWP.y/48.0,0.0,1.0),0.0,0.0,1.0);}
      else if(uMask>0.5){gl_FragColor=vec4(${o.terrain?'1.0,vTrail,0.0':'uMaskCol'},1.0);}`);
    sh.fragmentShader=f;
  };
  mat.customProgramCacheKey=()=>'forest'+(o.bill?'B':'')+(o.nofog?'N':'')+(o.ribbon?'R':'')+(o.terrain?'T':'')+(o.faceFix?'F':'')+(o.mask||[]).join('');
  return mat;
}

/* ---------------- ray tools over the crown clumps and trunks (Beer-Lambert) ---------------- */
class Canopy{
  constructor(){this.cs=[];this.cell=8;this.half=760;this.nc=Math.ceil(this.half*2/this.cell);this.grid=new Array(this.nc*this.nc);this.stamp=0;this.seen=null;this.maxTop=0;}
  add(x,y,z,r,k){this.cs.push([x,y,z,r,k]);if(y+r>this.maxTop)this.maxTop=y+r;}
  addTrunk(x,z,rad,h){this.cs.push([x,0,z,rad,-h]);}
  build(){
    const nc=this.nc;for(let i=0;i<nc*nc;i++)this.grid[i]=null;this.seen=new Int32Array(this.cs.length);
    this.cs.forEach((c,id)=>{const r=c[3];const x0=Math.floor((c[0]-r+this.half)/this.cell),x1=Math.floor((c[0]+r+this.half)/this.cell),z0=Math.floor((c[2]-r+this.half)/this.cell),z1=Math.floor((c[2]+r+this.half)/this.cell);
      for(let j=z0;j<=z1;j++)for(let i=x0;i<=x1;i++){if(i<0||j<0||i>=nc||j>=nc)continue;(this.grid[j*nc+i]||(this.grid[j*nc+i]=[])).push(id);}});
  }
  /* transmittance of the ray o+td up to maxT. Clumps: exp(-k*chord); trunks (k<0): vertical cylinders, opaque. */
  trans(ox,oy,oz,dx,dy,dz,maxT){
    const nc=this.nc,half=this.half,cell=this.cell;let tr=1;this.stamp++;const st=this.stamp,seen=this.seen;
    const stepT=cell*.7;let lastC=-1;
    const tEnd=dy>1e-3?Math.min(maxT,(this.maxTop+1-oy)/dy):maxT;
    for(let t=0;t<=tEnd+stepT;t+=stepT){
      const tt=Math.min(t,tEnd),x=ox+dx*tt,z=oz+dz*tt;const ci=Math.floor((x+half)/cell),cj=Math.floor((z+half)/cell);
      for(let b=-1;b<=1;b++)for(let a=-1;a<=1;a++){const i=ci+a,j=cj+b;if(i<0||j<0||i>=nc||j>=nc)continue;const lst=this.grid[j*nc+i];if(!lst)continue;
        for(let q=0;q<lst.length;q++){const id=lst[q];if(seen[id]===st)continue;seen[id]=st;const c=this.cs[id];
          if(c[4]<0){ /* trunk */
            const ex=ox-c[0],ez=oz-c[2],A=dx*dx+dz*dz;if(A<1e-9)continue;const B=ex*dx+ez*dz,C=ex*ex+ez*ez-c[3]*c[3],D=B*B-A*C;if(D<=0)continue;
            const sq=Math.sqrt(D),t0=(-B-sq)/A;if(t0<0||t0>maxT)continue;const yy=oy+dy*t0;if(yy>=0&&yy<=-c[4])return 0;continue;}
          const ex=ox-c[0],ey=oy-c[1],ez=oz-c[2],b2=ex*dx+ey*dy+ez*dz,cc=ex*ex+ey*ey+ez*ez-c[3]*c[3],disc=b2*b2-cc;if(disc<=0)continue;
          const sq=Math.sqrt(disc),t0=Math.max(0,-b2-sq),t1=Math.min(maxT,-b2+sq);if(t1>t0)tr*=Math.exp(-c[4]*(t1-t0));}}
      if(tr<.002)return 0;if(tt>=tEnd)break;
    }
    return tr;
  }
}

/* ---------------- the stand of one version ---------------- */
class Stand{
  constructor(vid,ground){
    this.id=vid;this.V=VERSIONS[vid];this.g=ground;this.rnd=rng32(vid.charCodeAt(0)*1013+7);
    this.trail=null;this.clearings=[];this.trees=[];this.canopy=new Canopy();this.sky=null;this.logs=[];this.rocks=[];this.ugMemo=new Map();
    this.protoMeta={};this.gaps=new Map();
  }
  makeGaps(){const V=this.V,R=rng32(555+this.id.charCodeAt(0)),n=Math.round((V.gaps||0)*144);this.gaps.clear();
    for(let i=0;i<n;i++){const x=(R()-.5)*1180,z=(R()-.5)*1180,r=3+R()*3.5;if(axisS(x,z)<40)continue;const k=Math.floor(x/24)+','+Math.floor(z/24);let l=this.gaps.get(k);if(!l)this.gaps.set(k,l=[]);l.push([x,z,r]);}}
  gapAt(x,z){const ci=Math.floor(x/24),cj=Math.floor(z/24);let M=1;for(let b=-1;b<=1;b++)for(let a=-1;a<=1;a++){const l=this.gaps.get((ci+a)+','+(cj+b));if(l)for(const g of l){const d=Math.hypot(x-g[0],z-g[1]);if(d<g[2]*1.15)M*=sstep(g[2]*.7,g[2]*1.1,d);}}return M;}
  forestMask(x,z){
    const s=axisS(x,z)+(fbm(x/38,z/38,3,4)-.5)*34;let M=sstep(-4,48,s);
    M*=.84+.3*(fbm(x/75,z/75,3,8)-.5);
    for(const c of this.clearings){const d=Math.hypot(x-c.x,z-c.z)+(fbm(x/7,z/7,2,3)-.5)*c.r*.35;M*=sstep(c.r*.78,c.r*1.12,d);}
    M*=this.gapAt(x,z);const sl=this.g.slopeDeg(x,z);M*=1-sstep(58,72,sl);
    const rv=this.g.riverAt(x,z);if(rv>=2)M*=.1;
    return clamp(M,0,1);
  }
  buildTrail(){
    const g=this.g,V=this.V,step=4,half=300,n=half*2/step+1,idx=(i,j)=>j*n+i;
    const rcells=[];const t=g.tile;for(let j=0;j<t.m;j++)for(let i=0;i<t.m;i++)if((t.riv[j*t.m+i]&3)>=1){rcells.push([t.x0+i*t.cell-TILE_CX,t.z0+j*t.cell-TILE_CZ]);}
    const rd=new Float32Array(n*n),H=new Float32Array(n*n);
    for(let j=0;j<n;j++)for(let i=0;i<n;i++){const X=-half+i*step,Z=-half+j*step;H[idx(i,j)]=g.at(X,Z);let b=1e9;for(const c of rcells){const d=Math.hypot(c[0]-X,c[1]-Z);if(d<b)b=d;}rd[idx(i,j)]=b;}
    /* waypoints: the edge, the clearings on the way, OG5's ground, OG7 */
    const way=[[E0[0]+AX[0]*4,E0[1]+AX[1]*4]];
    const cl=this.clearings.slice().sort((a,b)=>axisS(a.x,a.z)-axisS(b.x,b.z));for(const c of cl)way.push([c.x,c.z]);
    way.push(OG5_L.slice());way.push(OG7_L.slice());
    way.sort((a,b)=>axisS(a[0],a[1])-axisS(b[0],b[1]));
    const toNode=p=>[clamp(Math.round((p[0]+half)/step),0,n-1),clamp(Math.round((p[1]+half)/step),0,n-1)];
    const path=[];
    for(let w=0;w<way.length-1;w++){
      const a=toNode(way[w]),b=toNode(way[w+1]);const dist=new Float32Array(n*n).fill(1e9),prev=new Int32Array(n*n).fill(-1),heap=[[0,idx(a[0],a[1])]];dist[idx(a[0],a[1])]=0;
      const push=e=>{heap.push(e);let i=heap.length-1;while(i>0){const p=(i-1)>>1;if(heap[p][0]<=heap[i][0])break;[heap[p],heap[i]]=[heap[i],heap[p]];i=p;}};
      const pop=()=>{const r=heap[0],l=heap.pop();if(heap.length){heap[0]=l;let i=0;for(;;){let m=i;const L=2*i+1,R=L+1;if(L<heap.length&&heap[L][0]<heap[m][0])m=L;if(R<heap.length&&heap[R][0]<heap[m][0])m=R;if(m===i)break;[heap[m],heap[i]]=[heap[i],heap[m]];i=m;}}return r;};
      const goal=idx(b[0],b[1]);
      while(heap.length){const[d,u]=pop();if(d>dist[u])continue;if(u===goal)break;const ui=u%n,uj=(u/n)|0;
        for(let dj=-1;dj<=1;dj++)for(let di=-1;di<=1;di++){if(!di&&!dj)continue;const vi=ui+di,vj=uj+dj;if(vi<0||vj<0||vi>=n||vj>=n)continue;const v=idx(vi,vj),len=Math.hypot(di,dj)*step;
          const sl=Math.atan(Math.abs(H[v]-H[u])/len)*57.3;let c=len*(1+Math.pow(sl/13,2));
          if(V.trail.stream){const r=rd[v];c*=r<12?.55:1.15;}
          const rv=g.riverAt(-half+vi*step,-half+vj*step);if(rv>=2)c+=len*3;else if(rv===1)c+=len*.4;
          if(d+c<dist[v]){dist[v]=d+c;prev[v]=u;push([d+c,v]);}}}
      const seg=[];for(let u=goal;u>=0;u=prev[u])seg.push([-half+(u%n)*step,-half+((u/n)|0)*step]);seg.reverse();
      if(path.length)seg.shift();path.push(...seg);
    }
    let pts=path;for(let it=0;it<3;it++){const q=[pts[0]];for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];q.push([.75*a[0]+.25*b[0],.75*a[1]+.25*b[1]],[.25*a[0]+.75*b[0],.25*a[1]+.75*b[1]]);}q.push(pts[pts.length-1]);pts=q;}
    /* extend past both ends so the trail does not stop inside the view */
    const d0=[pts[0][0]-pts[3][0],pts[0][1]-pts[3][1]],l0=Math.hypot(...d0),d1=[pts[pts.length-1][0]-pts[pts.length-4][0],pts[pts.length-1][1]-pts[pts.length-4][1]],l1=Math.hypot(...d1);
    const ext=[];for(let k=60;k>=1;k--)ext.push([pts[0][0]+d0[0]/l0*k*2,pts[0][1]+d0[1]/l0*k*2]);
    const ext2=[];for(let k=1;k<=75;k++)ext2.push([pts[pts.length-1][0]+d1[0]/l1*k*2,pts[pts.length-1][1]+d1[1]/l1*k*2]);
    const all=[...ext,...pts,...ext2];
    /* resample at 1.5 m */
    const res=[];let acc=0;res.push({x:all[0][0],z:all[0][1],s:0});let carry=0;
    for(let i=0;i<all.length-1;i++){const a=all[i],b=all[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]);let d=1.5-carry;while(d<=L){res.push({x:a[0]+(b[0]-a[0])*d/L,z:a[1]+(b[1]-a[1])*d/L,s:0});d+=1.5;}carry=L-(d-1.5);}
    res.forEach((p,i)=>{p.y=g.at(p.x,p.z);p.s=i*1.5;});
    this.trail={pts:res,w:V.trail.w,cell:10,map:new Map()};
    res.forEach((p,i)=>{const k=Math.floor(p.x/10)+','+Math.floor(p.z/10);let a=this.trail.map.get(k);if(!a)this.trail.map.set(k,a=[]);a.push(i);});
  }
  /* distance to the trail centre line, and the trail s (arc length) */
  trailQ(x,z){
    const tr=this.trail,ci=Math.floor(x/10),cj=Math.floor(z/10);let best=1e9,bi=-1;
    for(let b=-1;b<=1;b++)for(let a=-1;a<=1;a++){const l=tr.map.get((ci+a)+','+(cj+b));if(!l)continue;for(const i of l){const p=tr.pts[i],d=Math.hypot(p.x-x,p.z-z);if(d<best){best=d;bi=i;}}}
    if(bi<0)return{d:99,i:-1};
    const p=tr.pts[bi],q=tr.pts[Math.min(bi+1,tr.pts.length-1)],r=tr.pts[Math.max(bi-1,0)];
    for(const o of[q,r]){const ax=o.x-p.x,az=o.z-p.z,L2=ax*ax+az*az;if(L2<1e-6)continue;const t=clamp(((x-p.x)*ax+(z-p.z)*az)/L2,0,1),d=Math.hypot(p.x+ax*t-x,p.z+az*t-z);if(d<best)best=d;}
    return{d:best,i:bi};
  }
  trailAt(s){const tr=this.trail.pts,i=clamp(Math.round(s/1.5),0,tr.length-2),a=tr[i],b=tr[i+1];const tx=b.x-a.x,tz=b.z-a.z,L=Math.hypot(tx,tz);return{x:a.x,z:a.z,y:a.y,tx:tx/L,tz:tz/L};}
  trailSAt(x,z){const q=this.trailQ(x,z);return q.i<0?0:this.trail.pts[q.i].s;}
  makeClearings(){
    const V=this.V,g=this.g;this.clearings=[];
    if(V.clearings==='springs'){ /* spring clearings on the stream cells that are inside the forest and clear of the camera spots */
      const t=g.tile,cand=[];for(let j=0;j<t.m;j++)for(let i=0;i<t.m;i++)if((t.riv[j*t.m+i]&3)===1){const X=t.x0+i*t.cell-TILE_CX,Z=t.z0+j*t.cell-TILE_CZ,s=axisS(X,Z);
        if(Math.abs(X)<270&&Math.abs(Z)<270&&s>90&&Math.hypot(X-OG7_L[0],Z-OG7_L[1])>40&&Math.hypot(X-OG5_L[0],Z-OG5_L[1])>25)cand.push([X,Z,s]);}
      cand.sort((a,b)=>a[2]-b[2]);const rr=rng32(77);const picks=[];
      for(let k=0;k<cand.length&&picks.length<3;k++){const c=cand[Math.floor(rr()*cand.length)];if(picks.every(p=>Math.hypot(p[0]-c[0],p[1]-c[1])>110))picks.push(c);}
      if(picks.length<3)for(const s0 of[200,330,470]){const p=axisPt(s0,10);if(picks.every(q=>Math.hypot(q[0]-p[0],q[1]-p[1])>100))picks.push([p[0],p[1]]);if(picks.length>=3)break;}
      for(const p of picks)this.clearings.push({x:p[0],z:p[1],r:6.5+rr()*2,spring:true});
    }else for(const c of V.clearings){const p=axisPt(c[0],c[1]);this.clearings.push({x:p[0],z:p[1],r:c[2]});}
  }
  /* trees: dart-throwing on a jittered grid, mask-driven, with a hash grid so trunks do not overlap */
  buildTrees(){
    const V=this.V,g=this.g,rnd=this.rnd,out=this.trees=[],protoParams={};
    const hash=new Map(),hkey=(x,z)=>Math.floor(x/4)+','+Math.floor(z/4);
    const near=(x,z,r)=>{const ci=Math.floor(x/4),cj=Math.floor(z/4);for(let b=-2;b<=2;b++)for(let a=-2;a<=2;a++){const l=hash.get((ci+a)+','+(cj+b));if(l)for(const t of l){if(Math.hypot(t.x-x,t.z-z)<r+t.rad)return true;}}return false;};
    const place=(cls,x,z,dbhS,forceH)=>{
      const C=V.classes[cls];const nv=C.nv||1;
      const vi=Math.min(nv-1,Math.floor(rnd()*nv));
      const key=cls+vi;if(!protoParams[key])protoParams[key]=this.protoParams(cls,vi);
      const P=protoParams[key];
      const sc=(forceH?1:.9+rnd()*.22);
      const t={cls,vi,key,x,z,y:g.at(x,z),sc,yaw:rnd()*6.283,rad:P.dbh/2*sc*1.2,H:P.H*sc,dbh:P.dbh*sc,firstBr:P.firstBr*sc,tint:(()=>{const v=.82+rnd()*.38,y=rnd()<.18?1:0;return[v*(1+.12*y),v*(1+.05*y),v*(.92-.2*y)*(.9+rnd()*.2)];})()};
      out.push(t);let l=hash.get(hkey(x,z));if(!l)hash.set(hkey(x,z),l=[]);l.push(t);return t;
    };
    this.protoParamsMap=protoParams;
    const half=STAND_HALF;
    const cell=cls=>Math.sqrt(10000/V.classes[cls].dens);
    for(const cls of Object.keys(V.classes)){
      const C=V.classes[cls];if(!C.dens)continue;const c=cell(cls);
      for(let gz=-half;gz<half;gz+=c)for(let gx=-half;gx<half;gx+=c){
        const x=gx+rnd()*c,z=gz+rnd()*c,M=this.forestMask(x,z);
        if(rnd()>M*(cls==='under'||cls==='tfern'?1:1))continue;
        const tq=this.trailQ(x,z);if(tq.d<this.trail.w*.5+(cls==='tfern'||cls==='under'?.9:1.3))continue;
        if(near(x,z,C.minD*c*.5))continue;
        place(cls,x,z);
      }
    }
    /* edge scatter: a few single trees and shrubs on the meadow side so the edge is not a hard line */
    const c=cell('canopy')*1.6;
    for(let gz=-half;gz<half;gz+=c)for(let gx=-half;gx<half;gx+=c){const x=gx+rnd()*c,z=gz+rnd()*c,s=axisS(x,z);
      if(s<-70||s>=8)continue;if(rnd()>.28*sstep(-70,-10,s)*(1-sstep(-10,8,s)*.4))continue;if(this.trailQ(x,z).d<2.5||near(x,z,3))continue;
      place(rnd()<.55?'under':'canopy',x,z);}
    /* landmark giants and fruit trees in the big clearings (version C) */
    if(V.id==='C'){
      this.clearings.forEach((cl,k)=>{
        const a=.8+k*1.9,gx=cl.x+Math.cos(a)*cl.r*.55,gz=cl.z+Math.sin(a)*cl.r*.55;const gt=place('giant',gx,gz,1,true);gt.sc=1.18;gt.H*=1.18;gt.dbh*=1.18;gt.rad*=1.18;gt.landmark=true;
        for(let f=0;f<5;f++){const b=a+2.2+f*1.15,rr=cl.r*(.4+.3*((f*37)%5)/5),fx=cl.x+Math.cos(b)*rr,fz=cl.z+Math.sin(b)*rr;if(this.trailQ(fx,fz).d<2.5||near(fx,fz,2))continue;place('fruit',fx,fz);}
      });
    }
    /* canopy data for the ray measures */
    const cn=this.canopy;
    for(const t of out){
      const P=protoParams[t.key],meta=this.metaFor(t.key),c=Math.cos(t.yaw),s=Math.sin(t.yaw);
      if(meta.clumps)for(const k of meta.clumps)cn.add(t.x+(k.x*c+k.z*s)*t.sc,t.y+k.y*t.sc,t.z+(-k.x*s+k.z*c)*t.sc,k.r*t.sc,k.k);
      else if(meta.crown){const k=meta.crown;cn.add(t.x,t.y+k[1]*t.sc,t.z,k[3]*t.sc,.55);}
      cn.addTrunk(t.x,t.z,(meta.trunkR||.1)*t.sc*.78,(meta.Ht||meta.H||3)*t.sc*.9);
      t.climb=t.dbh>=.8&&(t.firstBr<=4||(meta.vineReach!==undefined&&meta.vineReach*t.sc<=4));
    }
    cn.build();
  }
  protoParams(cls,vi){
    const C=this.V.classes[cls],R=rng32(cls.charCodeAt(0)*977+vi*131+this.id.charCodeAt(0)),u=(vi+.5)/(C.nv||1),j=()=>.85+R()*.3;
    if(C.src){const nm=C.src+(vi%ASSETS.count[C.src]),m=ASSETS.meta[nm];m.name=nm;
      return{src:C.src,vi,name:nm,m,H:m.H,dbh:m.dbh,firstBr:m.firstBr,leaf:C.leaf,tint:LEAFTINT[this.id],fruit:C.fruit||0,cardSize:C.cardSize,leafDensity:C.leafDensity*(C.src==='sap'?1:1.0),moss:C.moss,epi:C.epi,hang:C.hang,
        vines:C.vines,vineMoss:C.vineMoss,clumpScale:C.clumpScale||1,newLeaf:this.V.newLeaf==null?.2:this.V.newLeaf,alpha:SHARED?SHARED.leaf[C.leaf].userData.coverage:.5};}
    if(cls==='tfern')return{H:lerp(C.H[0],C.H[1],u),r:C.r*j(),fl:C.fl*j(),lean:(R()-.5)*.8,dbh:C.r*2,firstBr:99};
    const H=lerp(C.H[0],C.H[1],u)*(.94+R()*.12),dbh=lerp(C.dbh[0],C.dbh[1],clamp(u+(R()-.5)*.4,0,1));
    return{H,dbh,taper:.62,buttA:C.buttA*(.8+R()*.4),buttN:C.buttN+(R()<.5?0:1)-0,buttH:C.buttH,firstBr:lerp(C.firstBr[0],C.firstBr[1],R()),crownR:lerp(C.crownR[0],C.crownR[1],R()),
      nLimbs:C.limbs,clumpR:C.clumpR*j(),nClump:C.nClump,layers:C.layers,lean:C.lean,moss:C.moss,epi:C.epi,hang:C.hang,vines:C.vines,vineMoss:C.vineMoss,leaf:C.leaf,
      tint:LEAFTINT[this.id],fruit:C.fruit||0,cardSize:C.cardSize,leafDensity:C.leafDensity,alpha:SHARED?SHARED.leaf[C.leaf].userData.coverage:.5};
  }
  /* the L0 metadata of a prototype (clumps, trunk, vine reach) without building its meshes twice */
  metaFor(key){
    if(this.protoMeta[key])return this.protoMeta[key];
    const P=this.protoParamsMap[key],cls=key.slice(0,key.length-1),vi=+key.slice(-1);let m;
    if(P.src){const r=FT.skeletonParts(ASSETS.glb,P.m,P,0,vi*53+cls.charCodeAt(0)+this.id.charCodeAt(0)*7);(this.l0Cache||(this.l0Cache={}))[key]=r;m=r.meta;}
    else if(cls==='tfern'){const r=FT.treeFernParts(vi*5+3,P,1);m={Ht:P.H,H:P.H,trunkR:P.r,crown:r.meta.crown};(this.l0Cache||(this.l0Cache={}))[key]=r;}
    else{const r=FT.treeParts(vi*53+cls.charCodeAt(0)+this.id.charCodeAt(0)*7,P,0);m=r.meta;(this.l0Cache||(this.l0Cache={}))[key]=r;}
    return this.protoMeta[key]=m;
  }
  /* sky view factor on a grid: cosine-weighted mean transmittance over the zenith cone, 12 rays (the same quantity the closure measure uses) */
  buildSky(){
    const step=6,half=STAND_HALF,n=half*2/step+1,s=new Float32Array(n*n),dirs=[];
    for(let k=0;k<12;k++){const u=(k+.5)/12,th=Math.acos(Math.sqrt(1-u*.75)),ph=k*2.39996;dirs.push([Math.sin(th)*Math.cos(ph),Math.cos(th),Math.sin(th)*Math.sin(ph)]);}
    for(let j=0;j<n;j++)for(let i=0;i<n;i++){const X=-half+i*step,Z=-half+j*step,Y=this.g.at(X,Z)+1.4;let a=0;for(const d of dirs)a+=this.canopy.trans(X,Y,Z,d[0],d[1],d[2],80);s[j*n+i]=a/dirs.length;}
    this.sky={step,half,n,s};
  }
  skyAt(x,z){const k=this.sky;if(!k)return 1;const u=clamp((x+k.half)/k.step,0,k.n-1.001),v=clamp((z+k.half)/k.step,0,k.n-1.001),i=Math.floor(u),j=Math.floor(v),a=u-i,b=v-j,S=k.s,o=j*k.n+i;
    return lerp(lerp(S[o],S[o+1],a),lerp(S[o+k.n],S[o+k.n+1],a),b);}
  /* undergrowth in 16 m cells, deterministic from the cell index, so the picture and the transect measure agree */
  ugCell(ix,iz){
    const key=ix+','+iz,m=this.ugMemo.get(key);if(m)return m;
    const V=this.V,U=V.ug,R=rng32(Math.imul(ix+4000,73856093)^Math.imul(iz+4000,19349663)^this.id.charCodeAt(0)),items=[],S=16;
    const defs=[['fern',U.fern],['fernL',U.fernL],['shrub',U.shrub]];
    for(const[type,D]of defs){
      const expect=D.lam*S*S;let cnt=Math.floor(expect)+(R()<expect%1?1:0);
      for(let q=0;q<cnt;q++){
        const x=(ix+R())*S,z=(iz+R())*S;const M=this.forestMask(x,z);if(M<.02)continue;
        const sky=this.skyAt(x,z),pm=lerp(U.light[0],U.light[1],sstep(.04,.45,sky))*(.35+.65*M);   /* light-driven density: ferns thrive in gaps */
        if(R()>pm)continue;
        const mk=(px,pz)=>{if(this.trailQ(px,pz).d<this.trail.w*.5+.25)return;if(this.g.slopeDeg(px,pz)>56||this.g.riverAt(px,pz)>=2)return;
          const r=lerp(D.r[0],D.r[1],R());items.push({type,x:px,z:pz,y:this.g.at(px,pz),r,h:lerp(D.h[0],D.h[1],R()),yaw:R()*6.283,v:Math.floor(R()*3),c:.85+R()*.3});};
        mk(x,z);
        for(let e=pm-1;e>0;e-=1)if(R()<Math.min(e,1))mk(x+(R()-.5)*4,z+(R()-.5)*4);
      }
    }
    this.ugMemo.set(key,items);return items;
  }
  ugCover(x,z,h0,h1){const S=16,ci=Math.floor(x/S),cj=Math.floor(z/S);
    for(let b=-1;b<=1;b++)for(let a=-1;a<=1;a++)for(const it of this.ugCell(ci+a,cj+b)){if(it.h<h0)continue;const dx=it.x-x,dz=it.z-z,rr=it.r*.9;if(dx*dx+dz*dz<rr*rr)return true;}
    /* small trees and tree ferns also count as cover at that height */
    return false;}
  /* ---- the plan's judging measures that need no GPU ---- */
  closureAt(x,z,rays){
    const y=this.g.at(x,z)+1.5;let a=0;rays=rays||64;
    for(let k=0;k<rays;k++){const u=(k+.5)/rays,cz=lerp(1,.5,u),sz=Math.sqrt(1-cz*cz),ph=k*2.39996;a+=this.canopy.trans(x,y,z,sz*Math.cos(ph),cz,sz*Math.sin(ph),90);}
    return 1-a/rays;
  }
  measureCPU(){
    const R=rng32(4242+this.id.charCodeAt(0)),belt=[],edge=[];let guard=0;
    while(belt.length<20&&guard++<4000){const x=(R()-.5)*520,z=(R()-.5)*520;if(axisS(x,z)<70)continue;if(this.trailQ(x,z).d<2)continue;if(this.g.slopeDeg(x,z)>52)continue;
      if(this.clearings.some(c=>Math.hypot(x-c.x,z-c.z)<c.r*1.3))continue;belt.push([x,z]);}
    guard=0;while(edge.length<20&&guard++<4000){const l=(R()-.5)*420,s=R()*40,p=axisPt(s,l);if(Math.abs(p[0])>290||Math.abs(p[1])>290)continue;edge.push(p);}
    const mean=a=>a.reduce((s,v)=>s+v,0)/Math.max(1,a.length);
    const cb=belt.map(p=>this.closureAt(p[0],p[1])),ce=edge.map(p=>this.closureAt(p[0],p[1]));
    /* undergrowth: 50 m transects, cover fraction of the 0.3-1.5 m layer, sampled every 0.25 m */
    const tr=(x0,z0,dx,dz)=>{let hit=0,n=0;for(let d=0;d<50;d+=.25){n++;if(this.ugCover(x0+dx*d,z0+dz*d,.3,1.5))hit++;}return hit/n;};
    const off=[];guard=0;while(off.length<8&&guard++<400){const x=(R()-.5)*400,z=(R()-.5)*400;if(axisS(x,z)<80)continue;const a=R()*6.283,dx=Math.cos(a),dz=Math.sin(a);
      if(Math.abs(x+dx*50)>295||Math.abs(z+dz*50)>295)continue;if(this.trailQ(x,z).d<4||this.trailQ(x+dx*50,z+dz*50).d<4)continue;if(this.clearings.some(c=>Math.hypot(x-c.x,z-c.z)<c.r*1.5))continue;off.push(tr(x,z,dx,dz));}
    const on=[];for(const s0 of[80,200,330,460,560]){const p=this.trailAt(s0);let hit=0,n=0;for(let d=0;d<50;d+=.25){const q=this.trailAt(s0+d);n++;if(this.ugCover(q.x,q.z,.3,1.5))hit++;}on.push(hit/n);}
    /* climbable trees per hectare in the belt (tile interior beyond the edge band, outside clearings) */
    let cl=0,area=0;const beltArea=(()=>{let a=0,c=0;for(let x=-295;x<295;x+=10)for(let z=-295;z<295;z+=10){if(axisS(x,z)>=60&&!this.clearings.some(q=>Math.hypot(x-q.x,z-q.z)<q.r))a+=100;}return a;})();
    for(const t of this.trees){if(Math.abs(t.x)>=300||Math.abs(t.z)>=300||axisS(t.x,t.z)<60)continue;if(this.clearings.some(c=>Math.hypot(t.x-c.x,t.z-c.z)<c.r))continue;if(t.climb)cl++;}
    const stemsBelt=this.trees.filter(t=>Math.abs(t.x)<300&&Math.abs(t.z)<300&&axisS(t.x,t.z)>=60).length;
    return{closureBelt:mean(cb),closureEdge:mean(ce),closureBeltMin:Math.min(...cb),closureBeltMax:Math.max(...cb),
      undergrowthOff:mean(off),undergrowthOffN:off.length,undergrowthTrail:mean(on),climbablePerHa:cl/(beltArea/10000),stemsPerHa:stemsBelt/(beltArea/10000),beltHa:beltArea/10000,nTrees:this.trees.length};
  }
}

function setAssets(a){a.count={};for(const k in a.meta){const kind=k.replace(/\d+$/,'');a.count[kind]=(a.count[kind]||0)+1;}ASSETS=a;}
return{setAssets,VERSIONS,VORDER,SLOT_LIST,Ground,parseTile,Stand,Canopy,patchMat,sharedTextures,axisS,axisPt,AX,E0,OG5_L,OG6_L,OG7_L,TILE_CX,TILE_CZ,STAND_HALF,EXT,
  get SHARED(){return SHARED;},get ASSETS(){return ASSETS;},WORLD2LOCAL};
})();
