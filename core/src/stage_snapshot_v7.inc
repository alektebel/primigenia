/* Frozen v7 ABI (six species). Keep unchanged; guards reject other architectures/layouts. */
typedef struct {
    CpRng rng;                       /* the `social` stream: mood jitter, rival heckle, display contest */
    int32_t used;                    /* a social verb has been accepted: the block below is hashed */
    int32_t dna_total,dna_balance;   /* total only rises (Q-1); balance is spendable */
    int32_t items[CP_ITEM_COUNT];
    int32_t act_verb,act_target,act_arg,act_t,act_len,act_rhythm,act_mult; /* the action under way (verb 0 = none) */
    int32_t stagger,intimidate_cd;
    int32_t food,diet;               /* hunger meter 0..100 (no starvation effect yet) and the body's diet (CP_DIET_*, omnivore by default) */
    int32_t obs_target,obs_ticks,obs_need;    /* observe: creature watched and ticks on the current clue */
    int32_t obs_items[6]; /* clues revealed per species chain, 0..3 */
    uint32_t learned;                /* moves learned by observing (bit = 1 << move id) */
    int32_t kills[6],latched[6],resolution[6],first_met[6];
    uint64_t tested;                 /* preferences tried: bit s*8+k = species s skill k (k<4) or gift k-4, sign in `liked` */
    uint64_t liked;
    int32_t dna_by_source[CP_DNA_SOURCES];
    int32_t n_explored,explored[CP_SOC_EXPLORE_MAX];
    uint32_t species_seen;
    CpStageSocialCreature c[CP_STAGE_MAX_WILD];
} CpStageSocialV7;
typedef struct {
    CpRng loot,fossil;
    uint64_t discovered,owned,starter;
    uint8_t level[CP_STAGE_PART_COUNT],tier[CP_STAGE_PART_COUNT];
    uint32_t hits[CP_STAGE_PART_COUNT],wins[CP_STAGE_PART_COUNT],kills[CP_STAGE_PART_COUNT];
    uint32_t move_hits[CB_MOVE_COUNT],move_wins[CB_MOVE_COUNT];
    int dry[6],kill_paid[CP_STAGE_MAX_WILD],ally_paid[6];
    int used,eggs,lost,hatchling,n_nodes,inspect_id,inspect_ticks;
    int tiers_on,clues; /* A25: tier forms are built but off by default; fossil/bone clues (2 unlock a recipe) */
    float adult_hp;
    CpStagePartNode nodes[CP_STAGE_PART_NODES+1]; /* one extra slot: the cave chamber fossil, placed after the random nodes */
} CpStagePartsV7;
typedef struct {
    CpStageSetup setup;
    CpRng spawn_rng,roam_rng;
    uint8_t noise[512]; /* derived from terrain_seed; not hashed twice */
    uint32_t tick,clock;
    CpStageCreature player,wild[CP_STAGE_MAX_WILD];
    CpStageInput order;
    int32_t active,started,outcome,respawn_ticks,cooldown_ticks;
    float arena_x,arena_z;
    CpCombatWorld combat;
    CpStageBot bot;
    /* Derived last-tick outputs. Excluded from hash. */
    CpCombatAction combat_orders[2];
    int32_t accepted[2],last_error;
    uint64_t hash;
    /* DT0 additions (PLAN-devtools step 3). Part of the snapshot payload, except `field`, which MUST stay
     * the last member: the payload is offsetof(CpStageWorldV7,field) bytes. */
    CpStageMotion motion;            /* per-world copy of CP_STAGE_MOTION, changed by debug PARAM ops */
    int32_t debug_flags,reserved;    /* CP_STAGE_FLAG_* ; reserved keeps the layout explicit */
    uint64_t field_hash;             /* hash of the attached field, 0 outside FIELD mode */
    /* C1-nav: the GO / GO_NEST path (hashed while n_path>0) and derived observation outputs (not hashed). */
    float path[CP_STAGE_MAX_PATH][2];/* waypoints, the last is where the order ends */
    int32_t n_path,path_i,blocked_ticks,replans;
    float path_goal_x,path_goal_z;   /* the unsnapped target of the planned order */
    int32_t blocked_reason;          /* CP_STAGE_BLOCK_* of the last step, derived */
    float blocked_x,blocked_z;
    uint32_t ev_total,ev_acked;      /* events pushed / already shown to the agent; ring index = n % CP_STAGE_MAX_EVENTS */
    CpStageEvent events[CP_STAGE_MAX_EVENTS];
    CpCombatLoadout loadout;         /* the player's kit; copied into the fight at its start; hashed when custom */
    CpAncestry ancestry;
    CpLedger ledger;              /* L0: opt in via cp_ledger_init; snapshot owns it */
    CpStageSocialV7 social;            /* C2: trust, DNA, species progress, observe; hashed once `social.used` */
    CpStagePartsV7 parts;
    CpStageSecrets secrets;          /* derived at reset when setup.secrets; hashed only then */
    const CpStageField *field;       /* not owned, not in the snapshot, set by cp_stage_attach_field */
} CpStageWorldV7;
static uint64_t snapshot_v7_layout(void){
    uint64_t h=14695981039346656037ULL;
    lay(&h,sizeof(CpStageWorldV7));lay(&h,sizeof(CpStageSetup));lay(&h,sizeof(CpStageCreature));
    lay(&h,sizeof(CpCombatWorld));lay(&h,sizeof(CpCombatCreature));lay(&h,sizeof(CpStageBot));
    lay(&h,sizeof(CpStageMotion));lay(&h,sizeof(CpStageInput));lay(&h,sizeof(CpStageSpawn));
    lay(&h,sizeof(CpStageObstacle));lay(&h,sizeof(CpCombatProfile));lay(&h,sizeof(CpRng));
    lay(&h,sizeof(CpCombatHill));lay(&h,sizeof(CpCombatEvent));lay(&h,sizeof(CpCombatAction));
    LAY(CpStageWorldV7,setup);LAY(CpStageWorldV7,spawn_rng);LAY(CpStageWorldV7,roam_rng);LAY(CpStageWorldV7,noise);
    LAY(CpStageWorldV7,tick);LAY(CpStageWorldV7,clock);LAY(CpStageWorldV7,player);LAY(CpStageWorldV7,wild);
    LAY(CpStageWorldV7,order);LAY(CpStageWorldV7,active);LAY(CpStageWorldV7,started);LAY(CpStageWorldV7,outcome);
    LAY(CpStageWorldV7,respawn_ticks);LAY(CpStageWorldV7,cooldown_ticks);LAY(CpStageWorldV7,arena_x);
    LAY(CpStageWorldV7,arena_z);LAY(CpStageWorldV7,combat);LAY(CpStageWorldV7,bot);LAY(CpStageWorldV7,combat_orders);
    LAY(CpStageWorldV7,accepted);LAY(CpStageWorldV7,last_error);LAY(CpStageWorldV7,hash);LAY(CpStageWorldV7,motion);
    LAY(CpStageWorldV7,debug_flags);LAY(CpStageWorldV7,reserved);LAY(CpStageWorldV7,field_hash);LAY(CpStageWorldV7,path);LAY(CpStageWorldV7,n_path);LAY(CpStageWorldV7,path_i);
    LAY(CpStageWorldV7,blocked_ticks);LAY(CpStageWorldV7,replans);LAY(CpStageWorldV7,path_goal_x);LAY(CpStageWorldV7,path_goal_z);
    LAY(CpStageWorldV7,blocked_reason);LAY(CpStageWorldV7,blocked_x);LAY(CpStageWorldV7,blocked_z);LAY(CpStageWorldV7,ev_total);
    LAY(CpStageWorldV7,ev_acked);LAY(CpStageWorldV7,events);LAY(CpStageWorldV7,loadout);LAY(CpStageWorldV7,social);LAY(CpStageWorldV7,ledger);LAY(CpStageWorldV7,ancestry);LAY(CpStageWorldV7,parts);LAY(CpStageWorldV7,secrets);LAY(CpStageWorldV7,field);lay(&h,sizeof(CpStageSecrets));lay(&h,sizeof(CpStageCave));lay(&h,sizeof(CpStageSocialV7));lay(&h,sizeof(CpStageSocialCreature));lay(&h,sizeof(CpStageEvent));
    LAY(CpStageSetup,seed);LAY(CpStageSetup,terrain_seed);LAY(CpStageSetup,terrain);LAY(CpStageSetup,n);
    LAY(CpStageSetup,n_obstacles);LAY(CpStageSetup,nest_x);LAY(CpStageSetup,nest_z);LAY(CpStageSetup,flat_height);
    LAY(CpStageSetup,water_x);LAY(CpStageSetup,water_z);LAY(CpStageSetup,water_radius);LAY(CpStageSetup,player);LAY(CpStageSetup,player_legs);
    LAY(CpStageSetup,wild);LAY(CpStageSetup,obstacles);LAY(CpStageSetup,secrets);LAY(CpStageSetup,start_clock);LAY(CpStageSetup,cave);
    LAY(CpStageCreature,x);LAY(CpStageCreature,z);LAY(CpStageCreature,fx);LAY(CpStageCreature,fz);
    LAY(CpStageCreature,hp);LAY(CpStageCreature,stamina);LAY(CpStageCreature,speed);LAY(CpStageCreature,acceleration);
    LAY(CpStageCreature,turn_rate);LAY(CpStageCreature,home_x);LAY(CpStageCreature,home_z);LAY(CpStageCreature,goal_x);
    LAY(CpStageCreature,goal_z);LAY(CpStageCreature,species);LAY(CpStageCreature,dead);LAY(CpStageCreature,pivot);
    LAY(CpStageCreature,returning);LAY(CpStageCreature,roam_ticks);LAY(CpStageCreature,profile);LAY(CpStageCreature,omega);LAY(CpStageCreature,legs);LAY(CpStageCreature,sliding);
    LAY(CpCombatWorld,rng);LAY(CpCombatWorld,seed);LAY(CpCombatWorld,tick);LAY(CpCombatWorld,n);LAY(CpCombatWorld,hill);
    LAY(CpCombatWorld,n_hills);LAY(CpCombatWorld,c);LAY(CpCombatWorld,ev);LAY(CpCombatWorld,n_ev);LAY(CpCombatWorld,hash);
    LAY(CpCombatCreature,alive);LAY(CpCombatCreature,medium);LAY(CpCombatCreature,team);LAY(CpCombatCreature,prof);
    LAY(CpCombatCreature,x);LAY(CpCombatCreature,y);LAY(CpCombatCreature,fx);LAY(CpCombatCreature,fy);
    LAY(CpCombatCreature,hp);LAY(CpCombatCreature,stamina);LAY(CpCombatCreature,move);LAY(CpCombatCreature,phase);
    LAY(CpCombatCreature,ptick);LAY(CpCombatCreature,plen);LAY(CpCombatCreature,hit_mask);LAY(CpCombatCreature,dash_x);
    LAY(CpCombatCreature,dash_y);LAY(CpCombatCreature,stun_t);LAY(CpCombatCreature,bleed_t);LAY(CpCombatCreature,slow_t);
    LAY(CpCombatCreature,since_spend);LAY(CpCombatCreature,bleed_src);LAY(CpCombatCreature,verb);
    LAY(CpCombatCreature,verb_move);LAY(CpCombatCreature,verb_started);LAY(CpCombatCreature,verb_target);
    LAY(CpCombatCreature,verb_dir);LAY(CpCombatCreature,verb_ticks);LAY(CpCombatCreature,heading_x);
    LAY(CpCombatCreature,heading_y);LAY(CpCombatCreature,dmg_dealt);LAY(CpCombatCreature,dmg_taken);
    LAY(CpCombatCreature,stamina_spent);LAY(CpCombatCreature,hits);LAY(CpCombatCreature,hits_taken);
    LAY(CpCombatCreature,blocked);LAY(CpCombatCreature,dodged);LAY(CpCombatCreature,interrupted);
    LAY(CpCombatCreature,kills);LAY(CpCombatCreature,died_tick);LAY(CpCombatCreature,lo);LAY(CpCombatCreature,cd);
    LAY(CpCombatLoadout,slot);LAY(CpCombatLoadout,sig_slot);LAY(CpCombatLoadout,pad);LAY(CpCombatLoadout,known);
    LAY(CpStageBot,rng);LAY(CpStageBot,kind);LAY(CpStageBot,spam_move);LAY(CpStageBot,delay);
    LAY(CpStageBot,reaction);LAY(CpStageBot,ranged_commit);LAY(CpStageBot,timer);
    LAY(CpStageMotion,jog_k);LAY(CpStageMotion,sprint_k);LAY(CpStageMotion,wild_k);LAY(CpStageMotion,accel);
    LAY(CpStageMotion,brake);LAY(CpStageMotion,ease);LAY(CpStageMotion,turn_k);LAY(CpStageMotion,turn_min);
    LAY(CpStageMotion,turn_max);LAY(CpStageMotion,grip);LAY(CpStageMotion,pivot_k);LAY(CpStageMotion,pivot_mul);
    LAY(CpStageMotion,pivot_max);LAY(CpStageMotion,turn_slow);
    return h;
}
