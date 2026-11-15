const tells=[
 {name:'Bite',color:'#ffb44f',pitch:-.26,crouch:.12},
 {name:'Charge',color:'#ff6458',pitch:.28,crouch:.22},
 {name:'Guard',color:'#74cfff',pitch:0,crouch:.12},
 {name:'Spit',color:'#c99aff',pitch:-.32,crouch:.06},
 {name:'Tail sweep',color:'#61e0c0',pitch:.12,crouch:.16},
 {name:'Dodge',color:'#e8f4ff',pitch:0,crouch:.15}
];
export const moveTell=move=>tells[move]||tells[0];
export class FightFeedback {
 constructor(){this.time=0;this.stopUntil=0;this.shakeUntil=0;this.flashes=[];this.labels=[]}
 tick(sim){
  for(const event of sim.events){
   const kind=event.type===1?'hit':event.type===2?'guard':event.type===4?'dodge':null;
   if(!kind)continue;
   this.flashes[event.b]={kind,until:this.time+.28};
   if(kind==='hit'){this.stopUntil=this.time+.045;this.shakeUntil=this.time+.18}
   else this.labels.push({id:event.b,kind,text:kind==='guard'?'GUARDED':'DODGED',until:this.time+.8});
  }
 }
 update(dt){this.time+=dt;this.labels=this.labels.filter(l=>l.until>this.time)}
 get frozen(){return this.time<this.stopUntil}
 get shake(){return Math.max(0,(this.shakeUntil-this.time)/.18)}
 flash(id){const f=this.flashes[id];return {kind:f?.kind,strength:Math.max(0,((f?.until||0)-this.time)/.28)}}
}
