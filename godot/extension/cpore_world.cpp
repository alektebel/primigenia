// Stage world glue: Variant <-> C structs only. The simulation is cp_stage_*.
#include "cpore_world.h"
extern "C" {
#include "cpore/steer.h"
}
#include "convert.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cstring>
#include <cstdlib>
#include <godot_cpp/classes/json.hpp>

using namespace godot;

namespace {

const char *const PROFILE_INTS[] = {"mouth", "charge", "spit", "tail", "guard", "fire"};

Dictionary profile_to_dict(const CpCombatProfile &p) {
    Dictionary d;
    d["mouth"] = int(p.mouth); d["charge"] = int(p.charge); d["spit"] = int(p.spit);
    d["tail"] = int(p.tail); d["guard"] = int(p.guard); d["fire"] = int(p.fire);
    d["hp"] = double(p.hp); d["stamina"] = double(p.stamina); d["speed"] = double(p.speed);
    d["radius_cm"] = int(p.radius_cm);
    d["grip_traits"] = int(p.grip_traits); d["grip_legs"] = int(p.grip_legs);
    d["grip_deg"] = double(cp_stage_grip_deg(&p,4));
    Array extra;for(int k=0;k<8;k++)extra.append(int(p.extra[k]));d["extra"]=extra;d["carnivore"]=int(p.carnivore);
    return d;
}

// Missing keys keep the value already in `p`. Wrong types or ranges fail.
bool profile_from_dict(const Variant &v, CpCombatProfile &p) {
    if (v.get_type() != Variant::DICTIONARY) return false;
    const Dictionary d = v;
    uint8_t *levels[] = {&p.mouth, &p.charge, &p.spit, &p.tail, &p.guard, &p.fire};
    for (int i = 0; i < 6; ++i) {
        if (!d.has(PROFILE_INTS[i])) continue;
        int64_t n;
        if (!cpore::to_int(d[PROFILE_INTS[i]], 0, 255, n)) return false;  // range (<= 5) is checked by cp_stage_reset
        *levels[i] = uint8_t(n);
    }
    if(d.has("extra")){
        if(d["extra"].get_type()!=Variant::ARRAY)return false;
        Array extra=d["extra"];if(extra.size()!=8)return false;
        for(int k=0;k<8;k++){int64_t n;if(!cpore::to_int(extra[k],0,5,n))return false;p.extra[k]=uint8_t(n);}
    }
    if(d.has("carnivore")){int64_t n;if(!cpore::to_int(d["carnivore"],0,1,n))return false;p.carnivore=uint8_t(n);}
    if (d.has("hp") && !cpore::to_float(d["hp"], p.hp)) return false;
    if (d.has("stamina") && !cpore::to_float(d["stamina"], p.stamina)) return false;
    if (d.has("speed") && !cpore::to_float(d["speed"], p.speed)) return false;
    if (d.has("radius_cm")) {
        int64_t n;
        if (!cpore::to_int(d["radius_cm"], 0, 65535, n)) return false;
        p.radius_cm = uint16_t(n);
    }
    if(d.has("grip_traits")){int64_t n;if(!cpore::to_int(d["grip_traits"],0,63,n))return false;p.grip_traits=uint16_t(n);}
    if(d.has("grip_legs")){int64_t n;if(!cpore::to_int(d["grip_legs"],0,255,n))return false;p.grip_legs=uint8_t(n);}
    return true;
}

Dictionary setup_to_dict(const CpStageSetup &s) {
    Dictionary d;
    d["seed"] = int64_t(s.seed); d["terrain_seed"] = int64_t(s.terrain_seed);
    d["terrain"] = int(s.terrain);
    d["nest"] = Vector2(s.nest_x, s.nest_z);
    d["flat_height"] = double(s.flat_height);
    d["water"] = Vector3(s.water_x, s.water_z, s.water_radius);
    d["player"] = profile_to_dict(s.player);
    d["player_legs"] = int(s.player_legs);
    Array wild;
    for (int i = 0; i < s.n; ++i) {
        const CpStageSpawn &c = s.wild[i];
        Dictionary w;
        w["x"] = double(c.x); w["z"] = double(c.z);
        w["home_x"] = double(c.home_x); w["home_z"] = double(c.home_z);
        w["species"] = int(c.species); w["bot"] = int(c.bot);
        w["profile"] = profile_to_dict(c.profile);
        w["legs"] = int(c.legs);
        wild.append(w);
    }
    d["wild"] = wild;
    Array obstacles;
    for (int i = 0; i < s.n_obstacles; ++i) {
        const CpStageObstacle &o = s.obstacles[i];
        Dictionary od;
        od["x"] = double(o.x); od["z"] = double(o.z); od["r"] = double(o.r); od["type"] = int(o.type);
        obstacles.append(od);
    }
    d["obstacles"] = obstacles;
    d["secrets"] = int(s.secrets); d["start_clock"] = int(s.start_clock);
    if (s.cave.on) {
        Dictionary c;
        c["x"] = double(s.cave.x); c["z"] = double(s.cave.z); c["fx"] = double(s.cave.fx); c["fz"] = double(s.cave.fz);
        c["half"] = double(s.cave.half); c["length"] = double(s.cave.length); c["radius"] = double(s.cave.radius);
        d["cave"] = c;
    }
    return d;
}

bool vec2_from(const Variant &v, float &x, float &z) {
    if (v.get_type() != Variant::VECTOR2) return false;
    const Vector2 p = v;
    x = p.x; z = p.y;
    return std::isfinite(x) && std::isfinite(z);
}

// Fills `s` from the dictionary over `defaults`. Returns false on any type/shape error.
bool setup_from_dict(const Dictionary &d, CpStageSetup &s) {
    static const char *const known[] = {"seed", "terrain_seed", "terrain", "nest", "flat_height",
                                        "water", "player", "player_legs", "wild", "obstacles",
                                        "secrets", "start_clock", "cave"};
    const Array keys = d.keys();
    for (int i = 0; i < keys.size(); ++i) {
        bool ok = false;
        if (keys[i].get_type() == Variant::STRING || keys[i].get_type() == Variant::STRING_NAME) {
            const String k = keys[i];
            for (const char *name : known) if (k == name) ok = true;
        }
        if (!ok) return false;
    }
    int64_t n;
    if (d.has("seed")) { if (!cpore::to_int(d["seed"], 0, 4294967295LL, n)) return false; s.seed = uint32_t(n); }
    if (d.has("terrain_seed")) { if (!cpore::to_int(d["terrain_seed"], 0, 4294967295LL, n)) return false; s.terrain_seed = uint32_t(n); }
    if (d.has("terrain")) { if (!cpore::to_int(d["terrain"], -2147483648LL, 2147483647LL, n)) return false; s.terrain = int(n); }
    if (d.has("nest") && !vec2_from(d["nest"], s.nest_x, s.nest_z)) return false;
    if (d.has("flat_height") && !cpore::to_float(d["flat_height"], s.flat_height)) return false;
    if (d.has("water")) {
        if (d["water"].get_type() != Variant::VECTOR3) return false;
        const Vector3 w = d["water"];
        s.water_x = w.x; s.water_z = w.y; s.water_radius = w.z;
    }
    if (d.has("player") && !profile_from_dict(d["player"], s.player)) return false;
    if (d.has("player_legs")) { if (!cpore::to_int(d["player_legs"], 0, 8, n)) return false; s.player_legs = int(n); }
    if (d.has("wild")) {
        if (d["wild"].get_type() != Variant::ARRAY) return false;
        const Array wild = d["wild"];
        if (wild.size() > CP_STAGE_MAX_WILD) return false;
        s.n = wild.size();
        for (int i = 0; i < s.n; ++i) {
            if (wild[i].get_type() != Variant::DICTIONARY) return false;
            const Dictionary w = wild[i];
            CpStageSpawn c;
            std::memset(&c, 0, sizeof c);
            c.bot = -1;
            c.profile = s.player;
            if (w.has("x") && !cpore::to_float(w["x"], c.x)) return false;
            if (w.has("z") && !cpore::to_float(w["z"], c.z)) return false;
            c.home_x = c.x; c.home_z = c.z;
            if (w.has("home_x") && !cpore::to_float(w["home_x"], c.home_x)) return false;
            if (w.has("home_z") && !cpore::to_float(w["home_z"], c.home_z)) return false;
            if (w.has("species")) { if (!cpore::to_int(w["species"], -2147483648LL, 2147483647LL, n)) return false; c.species = int(n); }
            if (w.has("legs")) { if (!cpore::to_int(w["legs"], 0, 8, n)) return false; c.legs = int(n); }
            if (w.has("bot")) { if (!cpore::to_int(w["bot"], -2147483648LL, 2147483647LL, n)) return false; c.bot = int(n); }
            if (c.species >= 0 && c.species < CP_STAGE_SPECIES_DEFINED) c.profile = CP_STAGE_SPECIES[c.species].profile;
            if (w.has("profile") && !profile_from_dict(w["profile"], c.profile)) return false;
            s.wild[i] = c;
        }
    }
    if (d.has("obstacles")) {
        if (d["obstacles"].get_type() != Variant::ARRAY) return false;
        const Array obs = d["obstacles"];
        if (obs.size() > CP_STAGE_MAX_OBSTACLES) return false;
        s.n_obstacles = obs.size();
        for (int i = 0; i < s.n_obstacles; ++i) {
            if (obs[i].get_type() != Variant::DICTIONARY) return false;
            const Dictionary o = obs[i];
            CpStageObstacle c{};
            if (o.has("x") && !cpore::to_float(o["x"], c.x)) return false;
            if (o.has("z") && !cpore::to_float(o["z"], c.z)) return false;
            if (o.has("r") && !cpore::to_float(o["r"], c.r)) return false;
            if (o.has("type")) { if (!cpore::to_int(o["type"], -2147483648LL, 2147483647LL, n)) return false; c.type = int(n); }
            s.obstacles[i] = c;
        }
    }
    if (d.has("secrets")) { if (!cpore::to_int(d["secrets"], 0, 3, n)) return false; s.secrets = int(n); }
    if (d.has("start_clock")) { if (!cpore::to_int(d["start_clock"], 0, CP_STAGE_DAY_TICKS - 1, n)) return false; s.start_clock = int(n); }
    if (d.has("cave")) {
        // {x, z, fx, fz} of the terrain cave record (map metres and the outward unit vector); half/length/radius optional (m)
        if (d["cave"].get_type() != Variant::DICTIONARY) return false;
        const Dictionary c = d["cave"];
        CpStageCave cv{};
        cv.on = 1;
        if (!c.has("x") || !cpore::to_float(c["x"], cv.x)) return false;
        if (!c.has("z") || !cpore::to_float(c["z"], cv.z)) return false;
        if (!c.has("fx") || !cpore::to_float(c["fx"], cv.fx)) return false;
        if (!c.has("fz") || !cpore::to_float(c["fz"], cv.fz)) return false;
        if (c.has("half") && !cpore::to_float(c["half"], cv.half)) return false;
        if (c.has("length") && !cpore::to_float(c["length"], cv.length)) return false;
        if (c.has("radius") && !cpore::to_float(c["radius"], cv.radius)) return false;
        s.cave = cv;
    }
    return true;
}

Dictionary order_to_dict(const CpStageInput &i) {
    Dictionary d;
    d["verb"] = int(i.verb); d["target"] = int(i.target); d["move"] = int(i.move);
    d["dir"] = int(i.dir); d["sprint"] = int(i.sprint);
    d["hx"] = int(i.hx); d["hz"] = int(i.hz);
    d["x"] = double(i.x); d["z"] = double(i.z);
    return d;
}

// Returns false if a field has the wrong type or a value that does not fit.
bool input_from_dict(const Dictionary &d, CpStageInput &in) {
    std::memset(&in, 0, sizeof in);
    int64_t n;
    struct IntField { const char *key; int32_t *out; };
    const IntField fields[] = {{"verb", &in.verb}, {"target", &in.target}, {"move", &in.move}, {"dir", &in.dir}};
    for (const IntField &f : fields) {
        if (!d.has(f.key)) continue;
        if (!cpore::to_int(d[f.key], -2147483648LL, 2147483647LL, n)) return false;
        *f.out = int32_t(n);
    }
    if (d.has("sprint")) {
        int b;
        if (d["sprint"].get_type() == Variant::BOOL) b = bool(d["sprint"]) ? 1 : 0;
        else if (!cpore::to_int(d["sprint"], -2147483648LL, 2147483647LL, n)) return false;
        else b = int(n);
        in.sprint = b;
    }
    if (d.has("hx")) { if (!cpore::to_int(d["hx"], -32768, 32767, n)) return false; in.hx = int16_t(n); }
    if (d.has("hz")) { if (!cpore::to_int(d["hz"], -32768, 32767, n)) return false; in.hz = int16_t(n); }
    if (d.has("x") && !cpore::to_float(d["x"], in.x)) return false;
    if (d.has("z") && !cpore::to_float(d["z"], in.z)) return false;
    return true;
}

Dictionary entity(const CpStageCreature &c, int id) {
    Dictionary d;
    d["id"] = id;
    d["falling"] = c.slip_air != 0; d["y"] = c.slip_y * .001;
    d["x"] = double(c.x); d["z"] = double(c.z); d["fx"] = double(c.fx); d["fz"] = double(c.fz);
    d["hp"] = double(c.hp); d["stamina"] = double(c.stamina);
    d["speed"] = double(c.speed); d["acceleration"] = double(c.acceleration); d["turn_rate"] = double(c.turn_rate);
    d["home_x"] = double(c.home_x); d["home_z"] = double(c.home_z);
    d["goal_x"] = double(c.goal_x); d["goal_z"] = double(c.goal_z);
    d["species"] = int(c.species); d["dead"] = bool(c.dead); d["pivot"] = int(c.pivot);
    d["omega"] = double(c.omega); d["grade"] = double(c.grade); d["legs"] = int(c.legs); d["sliding"] = bool(c.sliding);
    d["returning"] = bool(c.returning); d["roam_ticks"] = int(c.roam_ticks);
    d["hp_max"] = double(c.profile.hp); d["stamina_max"] = double(c.profile.stamina);
    d["radius_cm"] = int(c.profile.radius_cm);
    d["grip_deg"] = double(cp_stage_grip_deg(&c.profile,c.legs));
    return d;
}

// The C2 social layer as plain data (docs/P4.md section 2): per-creature fields go into the entity dictionaries,
// the player's side (DNA, species progress, food, observe chains, the action under way) into `social`.
void add_social_entity(Dictionary &d, const CpStageWorld &w, int i) {
    const CpStageSocialCreature &c = w.social.c[i];
    d["trust"] = int(c.trust); d["mood"] = int(c.mood); d["bonded"] = bool(c.bonded);
    d["relationship"] = cp_stage_social_relationship(&w, i);
    d["beat_in"] = cp_stage_social_beat_in(&w, i);
    d["hostile"] = cp_stage_social_hostile(&w, i) != 0;
    d["calm"] = c.calm_ticks > 0; d["leaving"] = c.leave_ticks > 0;
    d["meat"] = cp_stage_social_carcass_meat(&w, i);
    const int sp = w.wild[i].species;
    d["temperament"] = int(CP_STAGE_SPECIES[sp].temperament);
    Array likes, dislikes;
    for (int k = 0; k < 8; ++k) {
        const uint64_t bit = 1ULL << (sp * 8 + k);
        if (!(w.social.tested & bit)) continue;
        const String name = k < 4 ? String(CP_STAGE_SKILLS[k].name) : String(CP_STAGE_ITEM_NAMES[k - 4]);
        if (w.social.liked & bit) likes.append(name); else dislikes.append(name);
    }
    d["likes"] = likes; d["dislikes"] = dislikes;
}

Dictionary social_to_dict(const CpStageWorld &w) {
    const CpStageSocial &s = w.social;
    Dictionary d;
    d["used"] = s.used != 0;
    d["dna_total"] = s.dna_total; d["dna_balance"] = s.dna_balance;
    d["food"] = s.food; d["food_max"] = CP_SOC_FOOD_MAX; d["diet"] = s.diet;
    Array items;
    for (int k = 0; k < CP_ITEM_COUNT; ++k) items.append(s.items[k]);
    d["items"] = items;
    d["resolved"] = cp_stage_social_species_resolved(&w); d["resolved_total"] = cp_stage_social_species_present(&w);
    Array sp;
    for (int k = 0; k < CP_STAGE_SPECIES_DEFINED; ++k) {
        Dictionary e;
        e["bonded"] = s.latched[k]; e["kills"] = s.kills[k]; e["resolution"] = s.resolution[k];
        e["observed"] = s.obs_items[k]; e["seen"] = (s.species_seen & (1u << k)) != 0;
        sp.append(e);
    }
    d["species"] = sp;
    d["observe_target"] = s.obs_target; d["observe_ticks"] = s.obs_ticks; d["observe_ticks_max"] = CP_SOC_OBSERVE_TICKS;
    d["learned"] = int64_t(s.learned);
    d["stagger"] = s.stagger; d["intimidate_cooldown"] = s.intimidate_cd;
    Dictionary act;
    act["verb"] = s.act_verb; act["target"] = s.act_target; act["arg"] = s.act_arg; act["t"] = s.act_t; act["len"] = s.act_len;
    act["windup"] = s.act_mult;
    d["action"] = act;
    return d;
}

}  // namespace

CporeWorld::CporeWorld() {
    world.reset(new CpStageWorld());
    observe_buffer.resize(256 * 1024);
    CpStageSetup s;
    cp_stage_setup_default(&s, 42);
    cp_stage_reset(world.get(), &s);
}

void CporeWorld::_bind_methods() {
    ClassDB::bind_static_method("CporeWorld", D_METHOD("grip_profile", "genome"), &CporeWorld::grip_profile);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("version"), &CporeWorld::version);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("default_setup", "seed"), &CporeWorld::default_setup);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("default_profile"), &CporeWorld::default_profile);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("species"), &CporeWorld::species);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("moves"), &CporeWorld::moves);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("chains"), &CporeWorld::chains);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("order_error", "code"), &CporeWorld::order_error);
    ClassDB::bind_method(D_METHOD("reset", "setup"), &CporeWorld::reset);
    ClassDB::bind_method(D_METHOD("get_setup"), &CporeWorld::get_setup);
    ClassDB::bind_method(D_METHOD("step", "input"), &CporeWorld::step);
    ClassDB::bind_method(D_METHOD("command", "text"), &CporeWorld::command);
    ClassDB::bind_method(D_METHOD("apply_legacy", "diet", "part"), &CporeWorld::apply_legacy);
    ClassDB::bind_method(D_METHOD("command_input", "text"), &CporeWorld::command_input);
    ClassDB::bind_method(D_METHOD("order", "input"), &CporeWorld::order);
    ClassDB::bind_method(D_METHOD("state"), &CporeWorld::state);
    ClassDB::bind_method(D_METHOD("observe"), &CporeWorld::observe);
    ClassDB::bind_method(D_METHOD("nest_edit", "body"), &CporeWorld::nest_edit);
    ClassDB::bind_method(D_METHOD("nest_apply", "body"), &CporeWorld::nest_apply);
    ClassDB::bind_method(D_METHOD("set_run", "on"), &CporeWorld::set_run);
    ClassDB::bind_method(D_METHOD("jump"), &CporeWorld::jump);
    ClassDB::bind_method(D_METHOD("jump_height"), &CporeWorld::jump_height);
    ClassDB::bind_method(D_METHOD("quest_award", "step", "dna"), &CporeWorld::quest_award);
    ClassDB::bind_method(D_METHOD("set_tiers", "on"), &CporeWorld::set_tiers);
    ClassDB::bind_method(D_METHOD("set_edit_anywhere", "on"), &CporeWorld::set_edit_anywhere);
    ClassDB::bind_method(D_METHOD("lineage"), &CporeWorld::lineage);
    ClassDB::bind_method(D_METHOD("lineage_form", "body", "profile", "parts", "name", "evolve"), &CporeWorld::lineage_form);
    ClassDB::bind_method(D_METHOD("lineage_perk", "kind", "serial", "amount"), &CporeWorld::lineage_perk);
    ClassDB::bind_method(D_METHOD("lineage_begin"), &CporeWorld::lineage_begin);
    ClassDB::bind_method(D_METHOD("lineage_award", "deed", "amount", "cause"), &CporeWorld::lineage_award);
    ClassDB::bind_method(D_METHOD("hash"), &CporeWorld::hash);
    ClassDB::bind_method(D_METHOD("height", "x", "z"), &CporeWorld::height);
    ClassDB::bind_method(D_METHOD("ground", "x", "z"), &CporeWorld::ground);
    ClassDB::bind_method(D_METHOD("can_walk", "x", "z", "nx", "nz", "radius"), &CporeWorld::can_walk);
    ClassDB::bind_method(D_METHOD("snapshot"), &CporeWorld::snapshot);
    ClassDB::bind_method(D_METHOD("restore", "bytes"), &CporeWorld::restore);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("snapshot_error", "code"), &CporeWorld::snapshot_error);
    ClassDB::bind_method(D_METHOD("debug", "op"), &CporeWorld::debug);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("debug_error", "code"), &CporeWorld::debug_error);
    ClassDB::bind_static_method("CporeWorld", D_METHOD("params"), &CporeWorld::params);
    ClassDB::bind_method(D_METHOD("param", "index"), &CporeWorld::param);
    ClassDB::bind_method(D_METHOD("layout"), &CporeWorld::layout);
    ClassDB::bind_method(D_METHOD("set_field", "entry"), &CporeWorld::set_field);
    ClassDB::bind_method(D_METHOD("clear_field"), &CporeWorld::clear_field);
    ClassDB::bind_method(D_METHOD("has_field"), &CporeWorld::has_field);
    ClassDB::bind_method(D_METHOD("field_info"), &CporeWorld::field_info);
    ClassDB::bind_method(D_METHOD("water_depth", "x", "z"), &CporeWorld::water_depth);
    ClassDB::bind_method(D_METHOD("bound"), &CporeWorld::bound);
    ClassDB::bind_method(D_METHOD("path"), &CporeWorld::path);
    ClassDB::bind_method(D_METHOD("nav_warm"), &CporeWorld::nav_warm);
    ClassDB::bind_method(D_METHOD("nav_cell"), &CporeWorld::nav_cell);
    ClassDB::bind_method(D_METHOD("ack_events"), &CporeWorld::ack_events);
    ClassDB::bind_method(D_METHOD("last_error"), &CporeWorld::last_error);
}

int CporeWorld::version() { return CP_STAGE_VERSION; }

Dictionary CporeWorld::default_setup(int64_t seed) {
    CpStageSetup s;
    cp_stage_setup_default(&s, uint32_t(seed));
    return setup_to_dict(s);
}

Dictionary CporeWorld::default_profile() {
    CpCombatProfile p;
    cp_combat_profile_default(&p);
    return profile_to_dict(p);
}

Array CporeWorld::species() {
    Array a;
    static const char *const ACT[] = {"diurnal", "nocturnal", "crepuscular"};
    for (int i = 0; i < CP_STAGE_SPECIES_DEFINED; ++i) {
        const CpStageSpecies &s = CP_STAGE_SPECIES[i];
        Dictionary d;
        d["id"] = i; d["name"] = String(s.name);
        d["activity"] = int(s.activity); d["activity_name"] = String(ACT[s.activity]);
        d["nocturnal"] = s.activity == CP_ACT_NOCTURNAL;
        d["diet"] = i == 0 || i == 1 || i == 5 ? "herbivore" : i == 4 || i == 6 ? "omnivore" : "carnivore";
        d["chain"] = String(CP_STAGE_CHAINS[i].id);
        d["speed"] = double(s.speed); d["sight"] = double(s.sight); d["roam"] = double(s.roam);
        d["hostile"] = double(s.hostile); d["temperament"] = int(s.temperament);
        d["profile"] = profile_to_dict(s.profile);
        a.append(d);
    }
    return a;
}

Array CporeWorld::chains() {
    Array a;
    for (int i = 0; i < CP_STAGE_SPECIES_DEFINED; ++i) {
        const CpStageChain &c = CP_STAGE_CHAINS[i];
        Dictionary d;
        d["species"] = i; d["id"] = String(c.id); d["trait"] = String(c.trait); d["move"] = c.move;
        Array clues;
        for (int k = 0; k < CP_SOC_CHAIN_ITEMS; ++k) clues.append(String(c.observe[k]));
        d["observe"] = clues;
        a.append(d);
    }
    return a;
}

// The move table (A21): id, name, role (index and name), cooldown in ticks, level-1 stamina, reach, whether it can sit in a slot.
Array CporeWorld::moves() {
    Array a;
    for (int i = 0; i < CB_MOVE_COUNT; ++i) {
        const CpCombatMove &m = CP_COMBAT_MOVES[i];
        Dictionary d;
        d["id"] = i; d["name"] = String(m.name);
        d["role"] = int(m.role); d["role_name"] = String(cp_combat_role_name(m.role));
        d["cooldown"] = int(m.cooldown); d["stamina"] = double(m.stamina); d["reach"] = double(m.reach);
        d["windup"] = int(m.windup); d["active"] = int(m.active); d["recovery"] = int(m.recovery);
        d["slottable"] = !(m.flags & CB_F_SELF);
        d["arc"] = double(m.arc); d["damage"] = double(m.damage); d["status"] = int(m.status); d["status_ticks"] = int(m.status_ticks);
        a.append(d);
    }
    return a;
}

int CporeWorld::reset(const Dictionary &setup) {
    int64_t seed = 42;
    if (setup.has("seed") && !cpore::to_int(setup["seed"], 0, 4294967295LL, seed)) return -1;
    CpStageSetup s;
    cp_stage_setup_default(&s, uint32_t(seed));
    if (!setup_from_dict(setup, s)) return -1;
    error_text = "";
    if (s.terrain == CP_STAGE_FIELD && !field_attached) {
        error_text = "terrain 2 needs set_field() first";
        return -1;
    }
    // cp_stage_reset validates before it touches the world, so a failure keeps the old state.
    const int rc = cp_stage_reset(world.get(), &s);
    if (rc == 0) social_events_seen = 0;
    if (rc) error_text = "the stage setup was rejected (a value is out of range or outside the playable bound)";
    return rc;
}

Dictionary CporeWorld::get_setup() const { return setup_to_dict(world->setup); }

String CporeWorld::step(const Dictionary &input) {
    CpStageInput in;
    if (!input_from_dict(input, in)) return String();
    return cpore::hash_text(cp_stage_step(world.get(), &in));
}

int CporeWorld::apply_legacy(int diet, const String &part) {
    int id = -1;
    if (!part.is_empty()) {
        id = cp_stage_part_id(part.utf8().get_data());
        if (id < 0) return -1;
    }
    return cp_stage_legacy_apply(world.get(), diet, id);
}

int CporeWorld::command(const String &text) { return cp_stage_command(world.get(), text.utf8().get_data()); }

Dictionary CporeWorld::command_input(const String &text) const {
    std::unique_ptr<CpStageWorld> scratch(new CpStageWorld(*world));
    scratch->order = CpStageInput{};
    const int rc = cp_stage_command(scratch.get(), text.utf8().get_data());
    Dictionary d;
    d["rc"] = rc;
    CpStageInput parsed;
    std::memset(&parsed, 0, sizeof parsed);
    if (cp_stage_parse(text.utf8().get_data(), &parsed) == 0) d["input"] = order_to_dict(parsed);
    else d["input"] = order_to_dict(scratch->order);
    return d;
}

int CporeWorld::order(const Dictionary &input) {
    CpStageInput in;
    if (!input_from_dict(input, in)) return -1;
    return cp_stage_order(world.get(), &in);
}

String CporeWorld::order_error(int code) { return String(cp_stage_order_error(code)); }

void CporeWorld::set_run(bool on) { cp_stage_set_run(world.get(), on); }
int CporeWorld::jump() { return cp_stage_jump(world.get()); }
double CporeWorld::jump_height() const { return cp_stage_jump_height(world.get()); }
int CporeWorld::quest_award(int step, int dna) { return cp_stage_quest_award(world.get(), step, dna); }

Dictionary CporeWorld::state() const {
    const CpStageWorld &w = *world;
    Dictionary d;
    d["tick"] = int64_t(w.tick); d["clock"] = int64_t(w.clock);
    d["hash"] = cpore::hash_text(cp_stage_hash(&w));
    d["active"] = int(w.active); d["started"] = int(w.started); d["outcome"] = int(w.outcome);
    d["respawn_ticks"] = int(w.respawn_ticks); d["cooldown_ticks"] = int(w.cooldown_ticks);
    d["error"] = int(w.last_error);
    d["arena"] = Vector2(w.arena_x, w.arena_z);
    Dictionary player;
    player["running"] = w.running != 0; player["stamina"] = int(w.run_stamina);
    player["falling"] = w.falling != 0;
    player["jumping"] = w.jumping != 0; player["jump_cd"] = int(w.jump_cd);
    player["sliding"] = w.player.sliding != 0;
    player["grip_deg"] = double(cp_stage_grip_deg(&w.player.profile,w.player.legs));
    player["y"] = w.falling ? w.fall_y_mm * .001 : cp_stage_ground(&w, w.player.x, w.player.z);
    player["vertical_velocity"] = w.fall_v_mm_s * .001;
    d["player"] = player;
    d["order"] = order_to_dict(w.order);
    d["flags"] = int(w.debug_flags);
    {
        // The player's kit (A21): slot move ids (-1 = empty), the signature slot (-1 = none), the known-moves
        // bitmask (1 << move id) and whether a loadout order would be accepted now (at the nest, no fight).
        Dictionary lo;
        Array slots;
        for (int i = 0; i < CB_LOADOUT_SLOTS; ++i) slots.append(int(w.loadout.slot[i]));
        lo["slots"] = slots;
        Array cooldowns;for(int k=0;k<CB_MOVE_COUNT;k++)cooldowns.append(int(w.recipes.cd[k]));lo["cooldowns"]=cooldowns;
        lo["signature_slot"] = int(w.loadout.sig_slot);
        lo["known"] = int(cp_stage_known_moves(&w));
        const double dx = double(w.player.x) - double(w.setup.nest_x), dz = double(w.player.z) - double(w.setup.nest_z);
        lo["can_edit"] = w.active < 0 && dx * dx + dz * dz <= double(CP_STAGE_NEST_RADIUS) * double(CP_STAGE_NEST_RADIUS);
        lo["nest_radius"] = double(CP_STAGE_NEST_RADIUS);
        d["loadout"] = lo;
    }
    Array accepted;
    accepted.append(int(w.accepted[0])); accepted.append(int(w.accepted[1]));
    d["accepted"] = accepted;
    Array entities;
    entities.append(entity(w.player, 0));
    for (int i = 0; i < w.setup.n; ++i) {
        Dictionary e = entity(w.wild[i], i + 1);
        add_social_entity(e, w, i);
        const int generation=cp_stage_cousin_generation(&w,i+1);
        e["cousin_generation"]=generation;
        e["counts_progress"]=generation==0;
        if(generation){e["lineage_species_id"]=4+generation;e["trust_bonus"]=20;}
        e["hidden"] = cp_stage_creature_hidden(&w, i) != 0;       // a nocturnal creature asleep by day: draw nothing
        e["hunkered"] = cp_stage_creature_hunkered(&w, i) != 0;   // a crepuscular creature curled up in the noon light
        e["activity"] = int(CP_STAGE_SPECIES[w.wild[i].species].activity);
        entities.append(e);
    }
    d["entities"] = entities;
    d["social"] = social_to_dict(w);
    {char buf[4096];if(cp_stage_recipes_json(&w,buf,sizeof buf)>=0)d["recipes"]=JSON::parse_string(String::utf8(buf));}
    {char buf[16384];if(cp_stage_parts_json(&w,buf,sizeof buf)>=0)d["parts"]=JSON::parse_string(String::utf8(buf));}
    {char buf[8192];if(cp_stage_dig_json(&w,buf,sizeof buf)>=0)d["dig"]=JSON::parse_string(String::utf8(buf));}   // first-quest: beds, holes, the dig in progress
    {
        // C2 secrets: state().shards {total, found, mask, items[{id,index,name,found,x,z,(line,line_es once found)}], toward_crater},
        // state().cave {enabled, entered, chamber_entered, inside, x, z, fx, fz, floor, half, length, radius, chamber_x, chamber_z},
        // state().day {light 0..1000, phase dawn|day|dusk|night, night, hour}, state().species [per species, see species()].
        char buf[8192];
        if (cp_stage_secrets_json(&w, buf, sizeof buf) >= 0) {
            const Dictionary sec = JSON::parse_string(String::utf8(buf));
            d["secrets"] = sec;
            d["shards"] = sec["shards"]; d["cave"] = sec["cave"]; d["day"] = sec["day"];
        }
        static const char *const RES[] = {"open", "ally", "hunted"};
        Array roster;
        for (int k = 0; k < CP_STAGE_SPECIES_DEFINED; ++k) {
            Dictionary e;
            const CpStageSpecies &sp = CP_STAGE_SPECIES[k];
            e["id"] = k; e["name"] = String(sp.name); e["activity"] = int(sp.activity);
            e["temperament"] = int(sp.temperament);
            e["seen"] = (w.social.species_seen & (1u << k)) != 0;
            e["resolution"] = String(RES[w.social.resolution[k]]);
            e["bonded"] = w.social.latched[k]; e["kills"] = w.social.kills[k]; e["observed"] = w.social.obs_items[k];
            int present = 0, hidden = 0;
            for (int i = 0; i < w.setup.n; ++i) if (w.wild[i].species == k) { ++present; hidden += cp_stage_creature_hidden(&w, i); }
            e["present"] = present; e["hidden_now"] = hidden;
            roster.append(e);
        }
        d["species"] = roster;
    }
    {
        // Social events since the last state(): [{type, target, move, value, x, z, tick}]; see stage_social.c for the fields.
        Array evs, routes;
        uint32_t first = social_events_seen;
        if (first > w.ev_total || w.ev_total - first > CP_STAGE_MAX_EVENTS) first = w.ev_total > CP_STAGE_MAX_EVENTS ? w.ev_total - CP_STAGE_MAX_EVENTS : 0;
        for (uint32_t k = first; k < w.ev_total; ++k) {
            const CpStageEvent &e = w.events[k % CP_STAGE_MAX_EVENTS];
            if (e.type == CP_STAGE_EV_ARRIVED || e.type == CP_STAGE_EV_PATH_FAILED || e.type == CP_STAGE_EV_ORDER_REJECTED) {
                Dictionary route;
                route["type"] = e.type == CP_STAGE_EV_ARRIVED ? "arrived" : "blocked";
                route["tick"] = int64_t(e.tick); route["x"] = double(e.x); route["z"] = double(e.z);
                route["reason"] = e.type == CP_STAGE_EV_ARRIVED ? "" : cp_stage_order_error(e.type == CP_STAGE_EV_PATH_FAILED ? -4 : int(e.value));
                routes.append(route);
            }
            if (e.type < CP_STAGE_EV_SKILL) continue;
            Dictionary ev;
            ev["type"] = int(e.type); ev["by"] = int(e.by); ev["tick"] = int64_t(e.tick); ev["target"] = int(e.target); ev["move"] = int(e.move);
            ev["value"] = double(e.value); ev["x"] = double(e.x); ev["z"] = double(e.z);
            evs.append(ev);
        }
        social_events_seen = w.ev_total;
        d["social_events"] = evs;
        d["route_events"] = routes;
    }
    Dictionary combat;
    combat["tick"] = int(w.combat.tick);
    Array fighters;
    if (w.active >= 0) {
        for (int i = 0; i < w.combat.n; ++i) {
            const CpCombatCreature &c = w.combat.c[i];
            Dictionary f;
            f["world_id"] = i == 0 ? 0 : w.active + 1;
            f["x"] = double(w.arena_x + c.x - 20); f["z"] = double(w.arena_z + c.y - 20);
            f["fx"] = double(c.fx); f["fz"] = double(c.fy);
            f["hp"] = double(c.hp); f["stamina"] = double(c.stamina);
            f["move"] = int(c.move); f["phase"] = int(c.phase);
            f["fear"] = int(c.fear_t); f["burn"] = int(c.burn_t); f["bleed"] = int(c.bleed_t); f["slow"] = int(c.slow_t); f["stun"] = int(c.stun_t);
            f["phase_tick"] = int(c.ptick); f["phase_length"] = int(c.plen);
            f["ctx"] = int(c.mctx); f["hold"] = int(c.mhold); f["over"] = int(c.over_t); f["spd"] = double(c.spd); f["mspd"] = double(c.mspd);
            f["kbx"] = double(c.kbx); f["kbz"] = double(c.kby);
            Array cd;
            for (int k = 0; k < CB_MOVE_COUNT; ++k) cd.append(int(c.cd[k]));
            f["cooldowns"] = cd;
            fighters.append(f);
        }
    }
    combat["fighters"] = fighters;
    Array projectiles;                      // A69: spit shots in flight (aim point in world metres, ticks left)
    if (w.active >= 0) for (int i = 0; i < CB_MAX_PROJ; ++i) {
        const CpCombatProj &p = w.combat.proj[i];
        if (!p.alive) continue;
        Dictionary q;
        q["owner"] = int(p.owner); q["kind"] = int(p.kind); q["ticks"] = int(p.t_left);
        q["x"] = double(w.arena_x + p.x - 20); q["z"] = double(w.arena_z + p.y - 20);
        projectiles.append(q);
    }
    combat["projectiles"] = projectiles;
    Array events;
    for (int i = 0; i < w.combat.n_ev; ++i) {
        const CpCombatEvent &e = w.combat.ev[i];
        Dictionary ev;
        ev["type"] = int(e.type); ev["a"] = int(e.a); ev["b"] = int(e.b);
        ev["move"] = int(e.move); ev["amount"] = double(e.amount);
        events.append(ev);
    }
    combat["events"] = events;
    d["combat"] = combat;
    return d;
}

String CporeWorld::observe() {
    const int n = cp_stage_observe(world.get(), observe_buffer.data(), observe_buffer.size());
    if (n < 0) return String();
    return String::utf8(observe_buffer.data(), n);
}

String CporeWorld::hash() const { return cpore::hash_text(cp_stage_hash(world.get())); }
double CporeWorld::height(double x, double z) const { return cp_stage_height(world.get(), float(x), float(z)); }
double CporeWorld::ground(double x, double z) const { return cp_stage_ground(world.get(), float(x), float(z)); }
bool CporeWorld::can_walk(double x, double z, double nx, double nz, double radius) const {
    return cp_stage_can_walk(world.get(), float(x), float(z), float(nx), float(nz), float(radius)) != 0;
}

// --- snapshot / restore, debug ops, parameters (PLAN-devtools step 5) ---------------------------------

PackedByteArray CporeWorld::snapshot() const {
    PackedByteArray out;
    out.resize(int64_t(cp_stage_snapshot_size()));
    const int n = cp_stage_snapshot(world.get(), out.ptrw(), size_t(out.size()));
    if (n < 0) out.clear();
    return out;
}

int CporeWorld::restore(const PackedByteArray &bytes) {
    const int rc = cp_stage_restore(world.get(), bytes.ptr(), size_t(bytes.size()), field_attached ? &field : nullptr);
    error_text = rc ? String(cp_stage_snapshot_error(rc)) : String();
    if (rc == 0) social_events_seen = world->ev_total;
    return rc;
}

String CporeWorld::snapshot_error(int code) { return String(cp_stage_snapshot_error(code)); }

int CporeWorld::debug(const Dictionary &op) {
    CpStageDebug d{};
    int64_t n;
    struct IntField { const char *key; int32_t *out; };
    const IntField fields[] = {{"op", &d.op}, {"id", &d.id}, {"a", &d.a}};
    for (const IntField &f : fields) {
        if (!op.has(f.key)) continue;
        if (!cpore::to_int(op[f.key], -2147483648LL, 2147483647LL, n)) return -1;
        *f.out = int32_t(n);
    }
    if (op.has("x") && !cpore::to_float(op["x"], d.x)) return -1;
    if (op.has("z") && !cpore::to_float(op["z"], d.z)) return -1;
    if (op.has("v") && !cpore::to_float(op["v"], d.v)) return -1;
    return cp_stage_debug(world.get(), &d);
}

String CporeWorld::debug_error(int code) { return String(cp_stage_debug_error(code)); }

Array CporeWorld::params() {
    Array a;
    for (int i = 0; i < CP_STAGE_PARAM_COUNT; ++i) {
        const CpStageParam &p = CP_STAGE_PARAMS[i];
        Dictionary d;
        d["index"] = i; d["name"] = String(p.name); d["group"] = String(p.group);
        d["min"] = double(p.min); d["max"] = double(p.max);
        d["default"] = double(*reinterpret_cast<const float *>(reinterpret_cast<const char *>(&CP_STAGE_MOTION) + p.offset));
        a.append(d);
    }
    return a;
}

double CporeWorld::param(int index) const {
    if (index < 0 || index >= CP_STAGE_PARAM_COUNT) return 0.0;
    return double(*reinterpret_cast<const float *>(reinterpret_cast<const char *>(&world->motion) + CP_STAGE_PARAMS[index].offset));
}

String CporeWorld::layout() const { return cpore::hash_text(cp_stage_layout()); }

// --- the island field (PLAN-heights H4) -------------------------------------------------------------

int CporeWorld::set_field(const Dictionary &entry) {
    error_text = "";
    int64_t n;
    float size_m;
    if (!entry.has("n") || !cpore::to_int(entry["n"], 2, 4096, n) || !entry.has("size_m") || !cpore::to_float(entry["size_m"], size_m) ||
        !(size_m > 0.0f) || !entry.has("height") || entry["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
        !entry.has("hash") || entry["hash"].get_type() != Variant::STRING) {
        error_text = "set_field: the terrain entry needs n, size_m, height (PackedFloat32Array) and hash";
        return -1;
    }
    const PackedFloat32Array height = entry["height"];
    PackedFloat32Array level;
    if (entry.has("water_level") && entry["water_level"].get_type() == Variant::PACKED_FLOAT32_ARRAY) level = entry["water_level"];
    const int64_t count = n * n;
    if (height.size() != count || (level.size() != 0 && level.size() != count)) {
        error_text = "set_field: height and water_level need n*n floats";
        return -1;
    }
    const String hash_hex = entry["hash"];
    const CharString hash_utf8 = hash_hex.utf8();
    field_height = height;   // reference-counted copies: the buffers stay put while we hold them
    field_level = level;
    field.n = int32_t(n);
    field.size_m = size_m;
    field.cell = size_m / float(n);
    field.half = size_m * 0.5f;
    field.height = field_height.ptr();
    field.water_level = field_level.size() ? field_level.ptr() : nullptr;
    field.hash = std::strtoull(hash_utf8.get_data(), nullptr, 16);
    if (cp_stage_attach_field(world.get(), &field)) {
        error_text = "set_field: the field was rejected";
        field_attached = false;
        return -1;
    }
    field_attached = true;
    field_meta = Dictionary();
    field_meta["n"] = int64_t(n);
    field_meta["size_m"] = double(size_m);
    field_meta["hash"] = hash_hex;
    field_meta["seed"] = entry.has("seed") ? int64_t(entry["seed"]) : int64_t(0);
    return 0;
}

void CporeWorld::clear_field() {
    cp_stage_attach_field(world.get(), nullptr);
    field_attached = false;
    field_height = PackedFloat32Array();
    field_level = PackedFloat32Array();
    field_meta = Dictionary();
}

Dictionary CporeWorld::field_info() const { return field_meta; }
double CporeWorld::water_depth(double x, double z) const { return cp_stage_water_depth(world.get(), float(x), float(z)); }
double CporeWorld::bound() const { return cp_stage_bound(world.get()); }
PackedVector2Array CporeWorld::path() const {
    PackedVector2Array out;
    float xz[2 * CP_STAGE_MAX_PATH];
    const int n = cp_stage_path(world.get(), xz, CP_STAGE_MAX_PATH);
    for (int i = 0; i < n; ++i) out.push_back(Vector2(xz[2 * i], xz[2 * i + 1]));
    return out;
}
int CporeWorld::nav_warm() const { return cp_stage_nav_warm(world.get()); }
double CporeWorld::nav_cell() const { return cp_stage_nav_cell(world.get()); }
void CporeWorld::ack_events() { cp_stage_ack_events(world.get()); }

String CporeWorld::lineage() const {
    std::vector<char> buf(1000000);
    int n=cp_stage_lineage_export(world.get(),buf.data(),buf.size());
    return n<0?String():String::utf8(buf.data(),n);
}
int CporeWorld::lineage_begin(){return cp_stage_lineage_begin(world.get());}
int CporeWorld::lineage_award(int deed,int amount,int cause){
    if(amount<=0||cause<0)return -1;
    return cp_stage_lineage_award(world.get(),deed,uint32_t(amount),uint32_t(cause));
}

int CporeWorld::lineage_form(const String &body,const Dictionary &profile,const Array &parts,const String &name,bool evolve){
    CpLineageForm form={};
    const CharString text=body.utf8(), label=name.utf8();
    if(text.length()>=CP_LINEAGE_BODY_CAP||label.length()>=80||parts.size()!=CP_LINEAGE_PARTS)return -1;
    memcpy(form.body,text.get_data(),text.length());memcpy(form.name,label.get_data(),label.length());
    if(!profile_from_dict(profile,form.profile))return -1;
    CpLineageForm projected={};
    if(!cp_stage_genome_form(text.get_data(),&projected)){memcpy(form.profile.extra,projected.profile.extra,8);form.profile.carnivore=projected.profile.carnivore;form.profile.grip_traits=projected.profile.grip_traits;form.profile.grip_legs=projected.profile.grip_legs;}
    for(int i=0;i<CP_LINEAGE_PARTS;i++){int64_t n;if(!cpore::to_int(parts[i],0,65535,n))return -1;form.parts[i]=uint16_t(n);}
    return cp_stage_lineage_form(world.get(),&form,evolve?1:0);
}

int CporeWorld::lineage_perk(int kind,int serial,int amount){if(serial<=0)return -1;return cp_stage_lineage_perk(world.get(),kind,uint32_t(serial),amount);}

int CporeWorld::nest_edit(const String &body){CharString text=body.utf8();return cp_stage_edit(world.get(),text.get_data());}
int CporeWorld::nest_apply(const String &body){CharString text=body.utf8();return cp_stage_apply(world.get(),text.get_data());}
void CporeWorld::set_tiers(bool on){cp_stage_set_tiers(world.get(),on?1:0);}
void CporeWorld::set_edit_anywhere(bool on){cp_stage_set_edit_anywhere(world.get(),on?1:0);}

Dictionary CporeWorld::grip_profile(const String &genome){
    CpCombatProfile p={};CpLineageForm form={};CharString text=genome.utf8();
    if(!cp_stage_genome_form(text.get_data(),&form))p=form.profile;
    else if(cp_stage_grip_project(text.get_data(),&p))return Dictionary();
    Dictionary d;d["grip_traits"]=int(p.grip_traits);d["grip_legs"]=int(p.grip_legs);
    d["grip_deg"]=double(cp_stage_grip_deg(&p,4));return d;
}
