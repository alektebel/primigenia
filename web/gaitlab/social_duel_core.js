'use strict';
// Primigenia social duel core (A78/A79): pure simulation, no DOM, no three.js. Used by social_duel.html and by the node self-check.
// Units: metres, seconds. World: x = east, z = south. A heading yaw means forward = (cos yaw, sin yaw) in (x, z); yaw grows clockwise seen from above.
// Beat = 1.2 s (CP_SOC_BEAT 12 ticks), rhythm window +-0.2 s (CP_SOC_WINDOW +-2 ticks), read at the END of the wind-up (befriend lab numbers).
// Mood is a point on a circumplex map (Russell 1980): mx fear(-1) <-> trust(+1), my calm(-1) <-> excited(+1). States come from mx:
// wary < -0.2 <= curious < 0.2 <= trusting; "bonded" = mx >= tier.bondX and my <= tier.bondY held for tier.hold beats.
(function(root){
const BEAT=1.2,WIN=0.2,STEP=1/60,KEYS=['sing','dance','charm','pose'];
const ACT={sing:{W:.2,A:.8,R:.2,range:8,eff:[.09,.05]},dance:{W:.2,A:1.0,R:.2,range:5,eff:[.12,.20]},charm:{W:.1,A:.6,R:.2,range:4,eff:[.14,-.16]},pose:{W:.4,A:.8,R:.2,range:10,eff:[.18,.08]}};
const TIERS={
 1:{name:'Zanco (easy herbivore)',gain:1.0,loss:.6,fear:.8,bondX:.6,bondY:.10,hold:1,chain:2,wrong:.08,off:.5,fav:'dance',gate:0,cd:5},
 2:{name:'Zanco (wary herd)',gain:.8,loss:1.0,fear:1.2,bondX:.7,bondY:0,hold:2,chain:3,wrong:.12,off:.3,fav:'pose',gate:0,cd:5},
 3:{name:'Zanco elder (smart species)',gain:.65,loss:1.4,fear:1.5,bondX:.75,bondY:-.05,hold:3,chain:4,wrong:.18,off:.15,fav:'sing',gate:3,cd:6}};
const RULES={run:{speed:5,fearPerS:.28,closeMult:2,radius:14},walk:2.0,sneak:.9,back:1.2,turnRate:2.2,passiveCap:.2,roar:{dx:-.45,dy:.45,range:14,cd:1.5,chase:7},
 observe:{secs:1.5,range:14},pred:{dx:-.4,dy:.5,near:10},predSpeed:3.2,chainBonus:{dx:.12,dy:-.08},fruit:{dx:.45,dy:-.25},eggCapFor:.5,nightCap:.15,gateCap:.1,gateMult:.1,favMult:1.4,
 flee:{x:-.85,secs:7,speed:4.2,resetX:-.55,resetY:.35},raidSecs:25,herdPanic:2.5};
const clamp=(x,a,b)=>x<a?a:x>b?b:x;
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
const angd=(a,b)=>{let d=(a-b)%(2*Math.PI);if(d>Math.PI)d-=2*Math.PI;if(d<-Math.PI)d+=2*Math.PI;return d;};

function create(o){o=o||{};
 const s={pin:!!o.pin,t:0,beatIdx:0,tier:o.tier||1,brain:o.brain||1,egg:o.egg||'none',night:!!o.night,predToggle:!!o.pred,predT:3,rng:mulberry(o.seed||7),
  B:{x:0,z:0,yaw:0,v:0,mode:'idle',act:null,fruit:false,streak:0,roarCd:0,pressed:0},
  T:{x:20,z:0,yaw:Math.PI,mx:-.6,my:.3,noticed:false,flee:0,bondHold:0,bonded:false,bondT:null,react:0,reactKind:null,startle:0,call:null,side:1,fruitGiven:false,defended:false,alarm:0,predSeen:false,moving:0},
  herd:[],pred:[],fruit:{x:9,z:6,taken:false},raid:null,chain:null,chainCd:3,obs:0,observeT:0,notes:[],log:[],events:[],trace:[],
  stats:{beats:0,combos:0,maxStreak:0,mistakes:0,hits:0,flees:0,chainsWon:0,chainsLost:0}};
 [[-1.8,2.2],[2.4,-2.0],[1.2,3.4]].slice(0,3).forEach((p,i)=>s.herd.push({x:s.T.x+p[0],z:s.T.z+p[1],yaw:Math.PI,home:p,mode:'graze',tm:0,speed:0,seed:i}));
 return s;}
const P_=s=>TIERS[s.tier];
const dist=s=>Math.hypot(s.T.x-s.B.x,s.T.z-s.B.z);
const band=d=>d>10?'far':d>4?'approach':'close';
function moodState(s){const T=s.T;return T.bonded?'bonded':T.flee>0?'fled':T.mx<-.2?'wary':T.mx<.2?'curious':'trusting';}
function msg(s,text,kind){s.log.push({t:s.t,text,kind:kind||''});s.events.push({t:s.t,type:'msg',text,kind});if(s.log.length>40)s.log.shift();}
function ev(s,type,x){s.events.push(Object.assign({t:s.t,type},x||{}));}
function capX(s){const P=P_(s),T=s.T;let c=1;
 if(P.gate&&s.brain<P.gate)c=Math.min(c,RULES.gateCap);
 if(s.egg==='night'&&!s.night)c=Math.min(c,RULES.nightCap);
 if(s.egg==='fruit'&&!T.fruitGiven)c=Math.min(c,RULES.eggCapFor);
 if(s.egg==='raid'&&!T.defended)c=Math.min(c,RULES.eggCapFor);
 return c;}
function push(s,dx,dy){const T=s.T;const before=T.mx;T.mx=clamp(T.mx+dx,-1,capX(s));T.my=clamp(T.my+dy,-1,1);
 if(dx<-.2*P_(s).fear||dx<-.25)alarm(s);if(dx<-.12)T.startle=.9;return T.mx-before;}
function alarm(s){if(s.T.alarm>0)return;s.T.alarm=2.5;s.herd.forEach(h=>{h.mode='alert';h.tm=2.2;});ev(s,'alarm');msg(s,'alarm call: the herd looks up and moves off','bad');}
function bandMult(k,d){const b=band(d);
 if(b==='far')return k==='sing'?.3:0;
 if(b==='approach'){if(k==='sing')return d<=8?1:.5;if(k==='pose')return .8;if(k==='dance')return d<=5?.6:0;return 0;}
 return 1;}
// ------------------------------------------------------------------ input
function press(s,k){const B=s.B;if(B.act||s.T.bonded||s.T.flee>0)return false;if(!ACT[k])return false;B.act={k,t0:s.t,read:false,hit:false,err:0,applied:false,tr:0};B.pressed++;ev(s,'act',{k});return true;}
function chainRead(s,a){const c=s.chain;if(!c)return;
 if(c.phase==='call'){a.suppress=true;msg(s,'listen first, answer after the calls','dim');return;}
 const exp=c.ans[c.idx];if(Math.abs(a.tr-exp)>BEAT/2)return;
 const P=P_(s),want=c.seq[c.idx];c.idx++;
 if(a.k===want&&a.hit){c.right++;a.chainRight=true;msg(s,'answered '+want+' ('+c.idx+'/'+c.n+')','good');}
 else{c.wrong++;a.chainWrong=true;stats(s).mistakes++;s.B.streak=0;msg(s,(a.k!==want?'wrong answer: wanted '+want:'right call, off the beat'),'bad');push(s,-P.wrong*P.loss,.05);}}
const stats=s=>s.stats;
function applyAction(s,a){const T=s.T,P=P_(s),A=ACT[a.k],d=dist(s),st=s.stats;
 if(a.suppress)return;
 if(a.chainWrong)return;
 if(a.k==='sing'&&d<=30&&!T.noticed){T.noticed=true;ev(s,'noticed');msg(s,'it noticed your call','good');}
 // fruit offer
 if(a.k==='charm'&&s.B.fruit&&d<=4){s.B.fruit=false;
  if(s.egg==='fruit'){T.fruitGiven=true;push(s,RULES.fruit.dx,RULES.fruit.dy);T.react=1.6;T.reactKind='fruit';ev(s,'fruit');msg(s,'it takes the special fruit: this is what it wanted','egg');return;}
  push(s,.08,-.05);msg(s,'it sniffs the fruit and eats it, politely','dim');return;}
 const m=bandMult(a.k,d);
 if(m<=0){msg(s,a.k+' out of range ('+d.toFixed(1)+' m, '+(a.k==='charm'?'needs under 4 m':band(d)==='far'?'only a call carries this far':'too far')+')','dim');return;}
 let timing=a.hit?1:P.off;
 if(a.hit){s.B.streak++;st.hits++;st.maxStreak=Math.max(st.maxStreak,s.B.streak);if(s.B.streak%3===0){st.combos++;msg(s,'combo x'+s.B.streak,'good');}}
 else{s.B.streak=0;st.mistakes++;msg(s,'off the beat ('+(a.err>=0?'+':'')+Math.round(a.err*1000)+' ms)','bad');}
 let k=m*timing*P.gain;
 if(a.k===P.fav)k*=RULES.favMult;
 if(a.hit&&s.B.streak>=2)k*=1+.15*(Math.min(s.B.streak,5)-1);
 if(a.chainRight)k*=1.2;
 if(P.gate&&s.brain<P.gate){k*=RULES.gateMult;if(!s.gateHinted){s.gateHinted=true;msg(s,'it ignores simple charms: it needs cognitive level '+P.gate+' (yours is '+s.brain+')','gate');}}
 push(s,A.eff[0]*k,A.eff[1]*k);T.react=1.4;T.reactKind=a.k;ev(s,'hit',{k:a.k,hit:a.hit,gain:A.eff[0]*k});}
// ------------------------------------------------------------------ world events
function roar(s){const B=s.B;if(B.roarCd>0)return false;B.roarCd=RULES.roar.cd;ev(s,'roar');
 let chased=0;for(const p of s.pred)if(p.mode!=='flee'&&Math.hypot(p.x-B.x,p.z-B.z)<=RULES.roar.chase){p.mode='flee';chased++;}
 if(chased){msg(s,'you roar: '+chased+' predator'+(chased>1?'s':'')+' run','good');return true;}
 if(dist(s)<=RULES.roar.range&&!s.T.bonded){s.stats.mistakes++;push(s,RULES.roar.dx*P_(s).fear,RULES.roar.dy);msg(s,'you roared at it: fear!','bad');}
 return true;}
function interact(s){const f=s.fruit,B=s.B;if(!f.taken&&Math.hypot(f.x-B.x,f.z-B.z)<=2.2){f.taken=true;B.fruit=true;ev(s,'pickup');msg(s,'you carry the special fruit: offer it with charm (3) up close','egg');return true;}return false;}
function observe(s){if(s.observeT>0)return false;const B=s.B;if(dist(s)>RULES.observe.range){msg(s,'too far to observe','dim');return false;}s.observeT=RULES.observe.secs;msg(s,'observing, keep still...','dim');return true;}
function revealHint(s){const P=P_(s),i=s.obs++;let h;
 if(i===0)h='Favourite gesture: '+P.fav+' (it brightens: x'+RULES.favMult+' trust).';
 else if(i===1)h=s.tier===3?'A sharp mind: simple charms bounce off. It wants a partner of cognitive level '+P.gate+'.':s.tier===2?'Wary herd: it forgives little, needs more trust, and holds the bond '+P.hold+' beats. Ears flat = fear, ears up = alert, ears low and sideways = calm.':'Easy herbivore. Charm calms it (down), dance and pose excite it (up). Ears up = alert, ears low and sideways = calm.';
 else if(i===2)h=({none:'Nothing odd about this one: no hidden condition.',night:'It keeps shying from the daylight; at dusk its eyes glow. Perhaps it only trusts in the dark.',fruit:'It keeps sniffing the air towards the thorn patch: a rare yellow fruit lies there. Perhaps a gift.',raid:'Its herd keeps staring at the treeline where predators prowl. It would trust whoever drives them off.'})[s.egg];
 else h='You have learned all you can by watching.';
 s.notes.push(h);msg(s,'field note: '+h,'note');ev(s,'note');}
function startRaid(s){if(s.raid)return false;s.raid={t0:s.t,done:false};
 for(let i=0;i<2;i++){const a=(i?1:-1)*.7;s.pred.push({x:s.T.x+Math.cos(a)*14,z:s.T.z+Math.sin(a)*14,mode:'attack',ang:Math.PI*(1+a),vx:0,vz:0,id:'raid'+i});}
 push(s,-.3,.5);s.T.my=Math.max(s.T.my,.8);alarm(s);msg(s,'predators attack the herd! chase them off with a roar (R)','bad');ev(s,'raid');return true;}
function startPass(s){s.pred.push({x:s.T.x-7,z:-16,mode:'pass',vx:0,vz:RULES.predSpeed,id:'pass'});msg(s,'a predator is passing near the herd','dim');ev(s,'pass');}
function bond(s,why){const T=s.T,P=P_(s);if(T.bonded)return;
 if(P.gate&&s.brain<P.gate){msg(s,'it likes you, but your mind is too simple to bond (cognitive level '+P.gate+' needed)','gate');return;}
 T.bonded=true;T.bondT=s.t;T.mx=Math.max(T.mx,P.bondX);T.my=Math.min(T.my,P.bondY);T.bondWhy=why;ev(s,'bonded',{why});msg(s,'BONDED ('+why+')','egg');}
// ------------------------------------------------------------------ per frame
function onBeat(s){s.beatIdx++;const T=s.T,P=P_(s),d=dist(s);
 if(d<=10&&!T.bonded)s.stats.beats++;
 s.trace.push([T.mx,T.my]);if(s.trace.length>14)s.trace.shift();
 const inRegion=T.mx>=P.bondX&&T.my<=P.bondY&&!T.flee&&!s.raid;
 if(inRegion){T.bondHold++;if(T.bondHold>=P.hold)bond(s,'trust');}else T.bondHold=0;
 if(s.chainCd>0)s.chainCd--;
 const c=s.chain;
 if(!c&&s.chainCd<=0&&T.mx>=-.2&&d<=9&&T.noticed&&!T.flee&&!s.raid&&!T.bonded&&!(P.gate&&s.brain<P.gate)){
  const n=P.chain,seq=[];for(let i=0;i<n;i++)seq.push(KEYS[Math.floor(s.rng()*4)]);
  const b0=s.beatIdx+1;s.chain={seq,n,b0,phase:'call',idx:0,right:0,wrong:0,miss:0,ans:seq.map((_,k)=>(b0+n+1+k)*BEAT),called:0};
  msg(s,'it calls a pattern ('+n+'): answer in kind','chain');ev(s,'chainStart');}
 const c2=s.chain;
 if(c2&&c2.phase==='call'&&s.beatIdx>=c2.b0&&c2.called<c2.n){T.call={k:c2.seq[c2.called],t0:s.t};ev(s,'call',{k:T.call.k,i:c2.called});c2.called++;}
 if(c2&&c2.phase==='answer'){}
}
function step(s,dt,inp){inp=inp||{};const B=s.B,T=s.T,P=P_(s);s.events.length=0;
 s.t+=dt;
 // beat
 if(Math.floor(s.t/BEAT+1e-9)>s.beatIdx)onBeat(s);
 // B movement
 const act=B.act;
 B.yaw+=clamp(inp.turn||0,-1,1)*RULES.turnRate*dt*(act?.4:1);
 let sp=0;B.mode='idle';
 if((inp.fwd||0)>0){sp=inp.run?RULES.run.speed:inp.sneak?RULES.sneak:RULES.walk;B.mode=inp.run?'run':inp.sneak?'sneak':'walk';}
 else if((inp.fwd||0)<0){sp=-RULES.back;B.mode=inp.sneak?'sneak':'walk';}
 else if(inp.sneak)B.mode='crouch';
 if(act)sp*=(act.k==='charm'?.5:.2);
 B.v=sp;B.x+=Math.cos(B.yaw)*sp*dt;B.z+=Math.sin(B.yaw)*sp*dt;
 B.roarCd=Math.max(0,B.roarCd-dt);
 // action pipeline
 if(act){const A=ACT[act.k],el=s.t-act.t0;
  if(!act.read&&el>=A.W-1e-9){act.read=true;act.tr=act.t0+A.W;act.err=act.tr-Math.round(act.tr/BEAT)*BEAT;act.hit=Math.abs(act.err)<=WIN+1e-9;ev(s,'read',{hit:act.hit,err:act.err});chainRead(s,act);}
  if(!act.applied&&el>=A.W+A.A-1e-9){act.applied=true;applyAction(s,act);}
  if(el>=A.W+A.A+A.R)B.act=null;}
 // observation
 if(s.observeT>0){if(B.mode==='run'||(B.v!==0&&Math.abs(B.v)>.3)||dist(s)>RULES.observe.range){s.observeT=0;msg(s,'observation broken: you moved','dim');}else{s.observeT-=dt;if(s.observeT<=0){s.observeT=0;revealHint(s);}}}
 passive(s,dt);
 chainStep(s);
 predators(s,dt);
 targetMove(s,dt);
 herdMove(s,dt);
 // decay timers
 T.react=Math.max(0,T.react-dt);T.startle=Math.max(0,T.startle-dt);T.alarm=Math.max(0,T.alarm-dt);
 if(T.call&&s.t-T.call.t0>1.1)T.call=null;
 // flee trigger
 if(!T.bonded&&T.flee<=0&&!s.raid&&T.mx<=RULES.flee.x){T.flee=RULES.flee.secs;s.stats.flees++;T.noticed=false;alarm(s);ev(s,'flee');msg(s,'it bolted! (fear too high)','bad');s.chain=null;}
 if(T.flee>0){T.flee-=dt;if(T.flee<=0){T.mx=RULES.flee.resetX;T.my=RULES.flee.resetY;T.bondHold=0;msg(s,'it calms down a little, still wary','dim');}}
 // night/pred toggles
 if(s.predToggle){s.predT-=dt;if(s.predT<=0){s.predT=30;startPass(s);}}
 if(s.raid&&!s.raid.done)raidStep(s);
}
function passive(s,dt){const T=s.T,B=s.B,P=P_(s),d=dist(s);if(T.flee>0||T.bonded||s.raid)return;
 const cap=capX(s);
 if(B.mode==='run'&&d<RULES.run.radius){const k=RULES.run.fearPerS*P.fear*dt*(d<4?RULES.run.closeMult:1);T.mx=Math.max(-1,T.mx-k);T.my=Math.min(1,T.my+.35*dt);T.startle=Math.max(T.startle,.3);if(!s.runWarned){s.runWarned=true;msg(s,'running scares it','bad');}if(d<4)alarm(s);}
 else if(d<10){
  const moving=Math.abs(B.v)>.1;
  if(d<1.2){T.mx-=.15*P.fear*dt;}
  else if((B.mode==='sneak')&&moving){if(T.mx<RULES.passiveCap)T.mx=Math.min(cap,T.mx+.05*P.gain*(d<4?1.3:1)*dt);T.my-=.03*dt;}
  else if(B.mode==='walk'&&moving){if(d<3)T.mx-=.05*P.fear*dt;}
  else if(!moving&&T.mx<RULES.passiveCap)T.mx=Math.min(cap,T.mx+.015*P.gain*dt);
 }
 T.my-=T.my*.12*dt;T.mx=clamp(T.mx,-1,cap);}
function chainStep(s){const c=s.chain;if(!c)return;
 if(c.phase==='call'&&s.t>=c.ans[0]-BEAT*.5){c.phase='answer';ev(s,'yourTurn');msg(s,'your turn: answer the pattern on the beat','chain');}
 const P=P_(s);
 while(c.idx<c.n&&s.t>c.ans[c.idx]+BEAT/2+1e-9){c.idx++;c.miss++;s.stats.mistakes++;s.B.streak=0;push(s,-P.wrong*P.loss*.5,0);msg(s,'missed an answer','bad');}
 if(c.idx>=c.n&&(!s.B.act||s.B.act.read)){
  if(c.right===c.n){s.stats.combos++;s.stats.chainsWon++;push(s,RULES.chainBonus.dx*P.gain,RULES.chainBonus.dy);s.T.react=1.6;s.T.reactKind='chain';msg(s,'PATTERN COMPLETE: combo bonus','good');ev(s,'chainWin');}
  else{s.stats.chainsLost++;msg(s,'pattern broken','bad');ev(s,'chainLose');}
  s.chain=null;s.chainCd=P.cd;}}
function predators(s,dt){const T=s.T;
 for(const p of s.pred){
  if(p.mode==='pass'){p.z+=p.vz*dt;if(!T.predSeen&&Math.hypot(p.x-T.x,p.z-T.z)<RULES.pred.near){T.predSeen=true;push(s,RULES.pred.dx*P_(s).fear,RULES.pred.dy);ev(s,'predNear');msg(s,'a predator passes: it is spooked','bad');}if(p.z>18){p.dead=true;T.predSeen=false;}}
  else if(p.mode==='attack'){const dx=T.x-p.x,dz=T.z-p.z,d=Math.hypot(dx,dz);if(d>3.2){p.x+=dx/d*3.5*dt;p.z+=dz/d*3.5*dt;}else{p.ang+=1.1*dt;p.x=T.x+Math.cos(p.ang)*3.2;p.z=T.z+Math.sin(p.ang)*3.2;}}
  else if(p.mode==='flee'){const dx=p.x-T.x,dz=p.z-T.z,d=Math.hypot(dx,dz)||1;p.x+=dx/d*6.5*dt;p.z+=dz/d*6.5*dt;if(d>34)p.dead=true;}}
 s.pred=s.pred.filter(p=>!p.dead);}
function raidStep(s){const r=s.raid,T=s.T;
 if(!T.bonded){T.my=Math.max(T.my,.7);}
 const attackers=s.pred.filter(p=>p.mode==='attack').length;
 if(attackers===0){r.done=true;T.defended=true;ev(s,'defended');
  if(s.egg==='raid'){msg(s,'you drove the predators off: it trusts you completely','egg');T.my=-.4;bond(s,'raid');}
  else{push(s,.3,-.4);msg(s,'you drove the predators off: it is grateful','good');}
  s.raid=null;return;}
 if(s.t-r.t0>RULES.raidSecs){r.done=true;push(s,-.3,.3);msg(s,'too slow: the predators scattered the herd','bad');for(const p of s.pred)p.mode='flee';s.raid=null;}}
function targetMove(s,dt){const T=s.T,B=s.B,P=P_(s),d=dist(s);if(s.pin&&T.flee<=0)return;
 const toB=Math.atan2(B.z-T.z,B.x-T.x);let spd=0,dir=0;
 if(T.flee>0){const away=Math.atan2(T.z-B.z,T.x-B.x);T.yaw+=clamp(angd(away,T.yaw),-5*dt,5*dt);spd=RULES.flee.speed;T.x+=Math.cos(T.yaw)*spd*dt;T.z+=Math.sin(T.yaw)*spd*dt;T.moving=spd;return;}
 const pref=T.bonded?1.9:T.mx<=-.2?9.5:T.mx<.2?6.5:T.mx<.6?3:1.8;
 if(s.raid){spd=0;}
 else if(d<pref-.5&&!T.bonded){dir=-1;spd=Math.min(1.6,.4+(pref-d)*.5);}
 else if((T.mx>-.2||T.bonded)&&d>pref+(T.bonded?.4:1)){dir=1;spd=T.bonded?Math.min(3.5,1+(d-pref)*.6):1.0;}
 // facing: turned away when afraid, toward when trusting; unaware targets face away
 let want;const away=T.noticed?Math.PI*.55*clamp((.25-T.mx)/.9,0,1):Math.PI*.7;
 want=toB+away*T.side;if(dir===-1&&T.mx<-.2)want=toB+Math.PI*T.side*.85;
 T.yaw+=clamp(angd(want,T.yaw),-1.6*dt,1.6*dt);
 if(spd>0){const mv=dir>0?toB:toB+Math.PI;const mvd=angd(mv,T.yaw);const sp=spd*(Math.abs(mvd)>1.6?.35:1);T.x+=Math.cos(mv)*sp*dt;T.z+=Math.sin(mv)*sp*dt;spd=sp;}
 T.moving=spd*dir;}
function herdMove(s,dt){const T=s.T;
 for(const h of s.herd){
  h.tm=Math.max(0,h.tm-dt);let tx=T.x+h.home[0],tz=T.z+h.home[1],sp=1.0;
  if(h.mode==='alert'){sp=0;if(h.tm<=0){h.mode='flee';h.tm=6;}}
  if(h.mode==='flee'){const ax=h.x-s.B.x,az=h.z-s.B.z,dd=Math.hypot(ax,az)||1;tx=h.x+ax/dd*5;tz=h.z+az/dd*5;sp=3.6;if(h.tm<=0)h.mode='graze';}
  const dx=tx-h.x,dz=tz-h.z,dd=Math.hypot(dx,dz);
  if(dd>.4){const k=Math.min(sp,dd*1.2);h.x+=dx/dd*k*dt;h.z+=dz/dd*k*dt;h.speed=k;h.yaw+=clamp(angd(Math.atan2(dz,dx),h.yaw),-3*dt,3*dt);}
  else{h.speed=0;const look=Math.atan2(s.B.z-h.z,s.B.x-h.x);h.yaw+=clamp(angd(look+(h.mode==='alert'?0:1.2*(h.seed-1)),h.yaw),-1*dt,1*dt);}
  if(h.mode==='alert'){const look=Math.atan2(s.B.z-h.z,s.B.x-h.x);h.yaw+=clamp(angd(look,h.yaw),-4*dt,4*dt);}
 }}
// ------------------------------------------------------------------ predictor (brain level 3): where would key k push the dot if hit on the beat now
function predict(s,k){const P=P_(s),d=dist(s),m=bandMult(k,d),A=ACT[k];let g=m*P.gain*(k===P.fav?RULES.favMult:1);if(P.gate&&s.brain<P.gate)g*=RULES.gateMult;
 if(s.B.streak>=2)g*=1+.15*(Math.min(s.B.streak+1,5)-1);return [A.eff[0]*g,A.eff[1]*g,m];}
// ------------------------------------------------------------------ scripted player (tests and the capture)
// opts: mode 'good' | 'run' | 'offbeat' | 'wrongchain'; jit seconds added to the press time; stand = stop at this many metres.
function bot(s,o){o=o||{};const B=s.B,T=s.T,P=P_(s),d=dist(s),inp={fwd:0,turn:0,run:false,sneak:false};
 const toT=Math.atan2(T.z-B.z,T.x-B.x),dyaw=angd(toT,B.yaw);inp.turn=clamp(dyaw*4,-1,1);
 const stand=o.stand||3.3;
 if(o.mode==='run'){inp.fwd=1;inp.run=true;return {inp};}
 if(d>stand&&Math.abs(dyaw)<1.2){inp.fwd=1;inp.sneak=true;}
 else if(d<stand-1.2&&d<2.2){inp.fwd=-.5;inp.sneak=true;}
 if(o.still)inp.fwd=0;
 let key=null,jit=o.jit||0;
 if(!B.act&&!T.bonded&&T.flee<=0&&!o.noact){
  const c=s.chain;
  if(c){if(c.phase==='answer'&&c.idx<c.n){let want=c.seq[c.idx];if(o.mode==='wrongchain')want=KEYS[(KEYS.indexOf(want)+1)%4];
    const A=ACT[want],tb=c.ans[c.idx];if(s.t>=tb-A.W+jit-1e-9&&s.t<tb+BEAT/2-A.W)key=want;}}
  else{
   let pick;
   if(d>10)pick=T.noticed?null:'sing';
   else if(d>4)pick=T.mx<.2||d>5?'pose':P.fav;
   else pick=T.my>.0?'charm':(T.mx<.45?P.fav:'charm');
   if(pick&&bandMult(pick,d)>0){const A=ACT[pick],tb=Math.ceil((s.t+A.W)/BEAT-1e-9)*BEAT;if(s.t>=tb-A.W+jit-1e-9&&s.t<tb-A.W+jit+.1)key=pick;}}}
 return {inp,key};}
function runBot(s,o,maxT){o=o||{};let n=0;const lim=Math.round((maxT||150)/STEP);
 while(s.t<lim*STEP&&n<lim){const b=bot(s,o);if(o.pre)o.pre(s,b);if(b.key)press(s,b.key);if(o.roarBot&&s.pred.some(p=>p.mode==='attack'&&Math.hypot(p.x-s.B.x,p.z-s.B.z)<6)&&s.B.roarCd<=0)roar(s);step(s,STEP,b.inp);n++;if(o.stop&&o.stop(s))break;if(s.T.bonded&&!o.go)break;}
 return s;}
// ------------------------------------------------------------------ self-check (pure maths; the page adds its UI checks)
function selfCheck(){const fails=[],R={};const ok=(c,m)=>{if(!c)fails.push(m);return c;};
 const close=(o)=>{const s=create(Object.assign({pin:true},o));s.B.x=s.T.x-3;s.B.z=0;s.B.yaw=0;s.T.noticed=true;s.t=BEAT*3-.0001;s.beatIdx=3;s.T.mx=-.5;s.T.my=0;s.chainCd=o&&o.chains?0:1e9;return s;};
 // 1 beat windows: read at wind-up end, hit iff |err|<=200 ms
 {const out=[];for(const [errMs,exp] of [[0,1],[190,1],[-190,1],[210,0],[-210,0],[600,0]]){const s=close({tier:1,brain:3});s.t=BEAT*4+errMs/1000-ACT.charm.W;s.beatIdx=Math.floor(s.t/BEAT);press(s,'charm');for(let i=0;i<30&&!s.B.act.read;i++)step(s,STEP,{});out.push([errMs,s.B.act.hit,Math.round(s.B.act.err*1000)]);ok(s.B.act.hit===!!exp,'window '+errMs+' ms expected hit='+exp+' got '+s.B.act.hit+' (err '+Math.round(s.B.act.err*1000)+')');}
  R.windows=out;}
 // 2 running near the target raises fear; sneaking lowers it; walking is neutral at range
 {const res={};for(const mode of ['run','walk','sneak']){const s=create({tier:1,brain:1});s.B.x=s.T.x-8;s.T.noticed=true;s.T.mx=-.4;const x0=s.T.mx;for(let i=0;i<60;i++)step(s,STEP,{fwd:1,run:mode==='run',sneak:mode==='sneak'});res[mode]=+(s.T.mx-x0).toFixed(3);}
  R.runFear=res;ok(res.run<-.1,'running at it must raise fear: '+res.run);ok(res.sneak>0,'sneaking must build trust: '+res.sneak);ok(res.run<res.walk&&res.walk<=res.sneak,'run < walk <= sneak');
  const s2=create({tier:1});s2.B.x=s2.T.x-9;for(let i=0;i<200&&s2.T.flee<=0;i++)step(s2,STEP,{fwd:1,run:true});ok(s2.T.flee>0&&s2.stats.flees===1,'running at it must make it bolt');R.runFlee=s2.t;}
 // 3 emotion map monotonic with scripted actions: charm hits move x up and y down every time, dance moves y up
 {const s=close({tier:1,brain:3});const xs=[],ys=[];for(let k=0;k<5;k++){const A=ACT.charm;let tb=Math.ceil((s.t+A.W)/BEAT-1e-9)*BEAT;while(s.t<tb-A.W-1e-9)step(s,STEP,{});press(s,'charm');for(let i=0;i<80&&s.B.act;i++)step(s,STEP,{});xs.push(s.T.mx);ys.push(s.T.my);}
  R.charmX=xs.map(x=>+x.toFixed(3));R.charmY=ys.map(x=>+x.toFixed(3));
  ok(xs.every((x,i)=>i===0||x>xs[i-1]),'charm hits: x must rise monotonically '+xs.join(','));ok(ys.every((y,i)=>i===0||y<ys[i-1]),'charm hits: y must fall monotonically');
  const s2=close({tier:1,brain:3});s2.T.my=-.3;let y0=s2.T.my;for(let k=0;k<3;k++){const A=ACT.dance;let tb=Math.ceil((s2.t+A.W)/BEAT-1e-9)*BEAT;while(s2.t<tb-A.W-1e-9)step(s2,STEP,{});press(s2,'dance');for(let i=0;i<90&&s2.B.act;i++)step(s2,STEP,{});ok(s2.T.my>y0,'dance must excite');y0=s2.T.my;}
  const p=predict(close({tier:1,brain:3}),'charm');ok(p[0]>0&&p[1]<0,'predicted arrow for charm goes right and down');R.arrow=p;}
 // 4 playthroughs per tier with the right inputs (brain 3) reach bonded; wrong inputs fail
 R.good={};
 for(const tier of [1,2,3]){const s=create({tier,brain:3,seed:11});runBot(s,{},180);R.good[tier]={bonded:s.T.bonded,t:+s.T.bondT?.toFixed?.(1),stats:s.stats,x:+s.T.mx.toFixed(2),y:+s.T.my.toFixed(2)};ok(s.T.bonded,'tier '+tier+' good playthrough must bond (x '+s.T.mx.toFixed(2)+' y '+s.T.my.toFixed(2)+' t '+s.t.toFixed(0)+')');}
 {const t=[1,2,3].map(k=>R.good[k].t);ok(t[0]<=t[1]&&t[1]<=t[2],'progressive difficulty: bond time must not shrink with tier '+t.join(' '));}
 {const s=create({tier:3,brain:1,seed:11});runBot(s,{go:true},150);R.gate1={bonded:s.T.bonded,x:+s.T.mx.toFixed(2),hint:!!s.gateHinted};ok(!s.T.bonded&&s.gateHinted&&s.T.mx<=.11,'tier 3 at brain 1 must never bond and must show the hint');
  const s2=create({tier:3,brain:2,seed:11});runBot(s2,{go:true},150);ok(!s2.T.bonded,'tier 3 at brain 2 must not bond');}
 for(const tier of [1,2,3]){const s=create({tier,brain:3,seed:11});runBot(s,{mode:'run'},60);R['run'+tier]={flees:s.stats.flees,bonded:s.T.bonded};ok(s.stats.flees>0&&!s.T.bonded,'tier '+tier+' running at it must flee, not bond');}
 {const g=create({tier:1,brain:3,seed:11,pin:true}),o=create({tier:1,brain:3,seed:11,pin:true});for(const q of [g,o]){q.B.x=17;q.T.noticed=true;q.T.mx=-.2;q.T.my=0;}runBot(g,{go:true},40);runBot(o,{jit:.45,go:true},40);R.timing={goodX:+g.T.mx.toFixed(2),offX:+o.T.mx.toFixed(2),offMistakes:o.stats.mistakes};ok(g.T.mx>o.T.mx+.15,'off-beat play must build trust much slower');ok(o.stats.mistakes>g.stats.mistakes,'off-beat counts mistakes');}
 // 5 call-and-answer: right answers give a bonus; wrong answers lose trust
 {const a=create({tier:1,brain:3,seed:5,pin:true}),b=create({tier:1,brain:3,seed:5,pin:true});for(const q of [a,b]){q.B.x=17;q.T.noticed=true;q.T.mx=0;q.T.my=0;q.chainCd=0;}runBot(a,{go:true,stop:s=>s.stats.chainsWon>=1},120);runBot(b,{go:true,mode:'wrongchain',stop:s=>s.stats.chainsLost>=1},120);
  R.chain={won:a.stats.chainsWon,lostWrong:b.stats.chainsLost,mistakesWrong:b.stats.mistakes};ok(a.stats.chainsWon>=1,'right answers must win a chain');ok(b.stats.chainsLost>=1&&b.stats.mistakes>a.stats.mistakes,'wrong answers must lose chains and count mistakes');
  // a controlled trust comparison
  const mk=wrong=>{const s=create({tier:1,brain:3,seed:5,pin:true});s.B.x=s.T.x-3;s.T.noticed=true;s.T.mx=0;s.T.my=0;s.chainCd=0;let guard=0;while(!s.chain&&guard++<4000)step(s,STEP,{});const x0=s.T.mx;
   while(s.chain&&s.t<200){const b=bot(s,wrong?{mode:'wrongchain',stand:3.3,still:true}:{stand:3.3,still:true});if(b.key)press(s,b.key);step(s,STEP,{});}return s.T.mx-x0;};
  const gr=mk(false),gw=mk(true);R.chainTrust={right:+gr.toFixed(3),wrong:+gw.toFixed(3)};ok(gr>0&&gw<gr-.05,'wrong answers must cost trust against right answers ('+gr+' vs '+gw+')');}
 // 6 easter eggs trigger only under their condition
 {R.eggs={};
  const night=(n)=>{const s=create({tier:1,brain:3,seed:11,egg:'night',night:n});runBot(s,{},150);return s.T.bonded;};R.eggs.nightDay=night(false);R.eggs.nightDark=night(true);ok(!R.eggs.nightDay,'night egg must NOT bond in daylight');ok(R.eggs.nightDark,'night egg must bond in the dark');
  const fruit=(give)=>{const s=create({tier:1,brain:3,seed:11,egg:'fruit'});if(give){s.B.x=s.fruit.x;s.B.z=s.fruit.z;interact(s);s.B.x=0;s.B.z=0;}
   const o={fruitGo:true};runBot(s,{pre:(ss,b)=>{if(give&&ss.B.fruit&&dist(ss)<=3.6&&!ss.B.act&&ss.T.mx>=-.1){b.key='charm';}}},170);return s.T.bonded;};
  R.eggs.fruitWithout=fruit(false);R.eggs.fruitWith=fruit(true);ok(!R.eggs.fruitWithout,'fruit egg must NOT bond without the fruit');ok(R.eggs.fruitWith,'fruit egg must bond after offering the fruit');
  const raid=(egg,defend)=>{const s=create({tier:1,brain:3,seed:11,egg});s.B.x=s.T.x-6;s.B.yaw=0;s.T.noticed=true;s.t=BEAT*2;s.beatIdx=2;startRaid(s);
   for(let i=0;i<60*12;i++){const b=bot(s,{noact:true,stand:5});if(defend&&s.pred.some(p=>p.mode==='attack')){const p=s.pred.find(p=>p.mode==='attack');const toP=Math.atan2(p.z-s.B.z,p.x-s.B.x);b.inp.turn=clamp(angd(toP,s.B.yaw)*4,-1,1);b.inp.fwd=Math.hypot(p.x-s.B.x,p.z-s.B.z)>4.5?1:0;b.inp.sneak=false;if(Math.hypot(p.x-s.B.x,p.z-s.B.z)<=5.5)roar(s);}else{b.inp.fwd=0;}step(s,STEP,b.inp);if(s.T.bonded)break;}return {bonded:s.T.bonded,defended:s.T.defended,why:s.T.bondWhy,x:+s.T.mx.toFixed(2),t:+s.t.toFixed(1)};};
  R.eggs.raidDefendEgg=raid('raid',true);R.eggs.raidIdleEgg=raid('raid',false);R.eggs.raidDefendNoEgg=raid('none',true);
  ok(R.eggs.raidDefendEgg.bonded&&R.eggs.raidDefendEgg.why==='raid','defending the herd must instantly bond with the raid egg ('+JSON.stringify(R.eggs.raidDefendEgg)+')');
  ok(!R.eggs.raidIdleEgg.bonded,'ignoring the raid must not bond');ok(!R.eggs.raidDefendNoEgg.bonded&&R.eggs.raidDefendNoEgg.defended,'defending without the raid egg gives gratitude, no instant bond');}
 // 7 predator pass spooks it; observe reveals three hints with the egg hint; sing is the only action that notices at far range
 {const s=create({tier:1});s.B.x=s.T.x-12;s.T.noticed=true;const x0=s.T.mx;startPass(s);for(let i=0;i<60*8;i++)step(s,STEP,{});R.pass={dx:+(s.T.mx-x0).toFixed(2)};ok(s.T.mx<x0-.15,'a passing predator must knock its trust back');
  const o=create({tier:1,egg:'fruit'});o.B.x=o.T.x-9;for(let k=0;k<3;k++){observe(o);for(let i=0;i<120;i++)step(o,STEP,{});}R.notes=o.notes;ok(o.notes.length===3&&/fruit/.test(o.notes[2])&&/dance/.test(o.notes[0]),'observing three times must reveal favourite, reading and the easter-egg hint');
  const f=create({tier:1});f.B.x=f.T.x-16;for(const k of ['dance','charm','pose']){f.t=BEAT*4-ACT[k].W;f.B.act=null;press(f,k);for(let i=0;i<120;i++)step(f,STEP,{});}ok(!f.T.noticed&&f.T.mx<=-.59,'at far range only a call registers (dance/charm/pose are ignored)');f.t=BEAT*8-ACT.sing.W;f.B.act=null;press(f,'sing');for(let i=0;i<120;i++)step(f,STEP,{});ok(f.T.noticed,'a sing at far range registers as noticed');}
 return {pass:fails.length===0,fails,R};}
const api={BEAT,WIN,STEP,KEYS,ACT,TIERS,RULES,create,step,press,roar,interact,observe,startRaid,startPass,dist,band,bandMult,moodState,capX,predict,bot,runBot,selfCheck,clamp,angd};
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.SDCORE=api;
})(typeof window!=='undefined'?window:globalThis);
