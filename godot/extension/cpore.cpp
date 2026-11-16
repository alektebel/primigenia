// Ownership and Variant conversion only. All generation, movement and combat
// remain in libcpore.a, compiled as C99 with its original determinism flags.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <vector>
extern "C" {
#include "cpore/terrain.h"
#include "cpore/world.h"
}
#include "terrain_fields.inc"

using namespace godot;

static String hash_text(uint64_t h) {
    char text[17];
    std::snprintf(text, sizeof text, "%016llx", (unsigned long long)h);
    return String(text);
}

class Cpore : public RefCounted {
    GDCLASS(Cpore, RefCounted)
    CpStageWorld world{};
    std::atomic<int> stage{0}, done{0}, total{1};
    static void notify(int s, int d, int t, void *user) {
        auto *self = static_cast<Cpore *>(user);
        self->done.store(d); self->total.store(t); self->stage.store(s);
    }
    static Dictionary entity(const CpStageCreature &c, int id) {
        Dictionary d;
        d["id"] = id; d["x"] = c.x; d["z"] = c.z;
        d["fx"] = c.fx; d["fz"] = c.fz;
        d["hp"] = c.hp; d["stamina"] = c.stamina; d["speed"] = c.speed;
        d["species"] = c.species; d["dead"] = c.dead;
        d["turn_rate"] = c.turn_rate;
        return d;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("terrain_defaults"), &Cpore::terrain_defaults);
        ClassDB::bind_method(D_METHOD("terrain_version"), &Cpore::terrain_version);
        ClassDB::bind_method(D_METHOD("generate", "params"), &Cpore::generate);
        ClassDB::bind_method(D_METHOD("progress"), &Cpore::progress);
        ClassDB::bind_method(D_METHOD("world_reset", "setup"), &Cpore::world_reset);
        ClassDB::bind_method(D_METHOD("world_step", "input"), &Cpore::world_step);
        ClassDB::bind_method(D_METHOD("world_state"), &Cpore::world_state);
        ClassDB::bind_method(D_METHOD("world_observe"), &Cpore::world_observe);
        ClassDB::bind_method(D_METHOD("world_command", "command"), &Cpore::world_command);
    }
public:
    Cpore() { world_reset(Dictionary()); }
    int terrain_version() const { return CP_TERRAIN_VERSION; }
    Dictionary terrain_defaults() const {
        CpTerrainParams p; cp_terrain_params_default(&p);
        Dictionary d;
#define FIELD(name) d[#name] = p.name;
        TERRAIN_FIELDS(FIELD)
#undef FIELD
        return d;
    }
    Dictionary progress() const {
        Dictionary d;
        d["stage"] = stage.load(); d["done"] = done.load(); d["total"] = total.load();
        return d;
    }
    Dictionary generate(const Dictionary &options) {
        CpTerrainParams p; cp_terrain_params_default(&p);
        Dictionary result, defaults = terrain_defaults();
        Array keys = options.keys();
        for (int i = 0; i < keys.size(); ++i) {
            const Variant v = options[keys[i]];
            if (!defaults.has(keys[i]) || (v.get_type() != Variant::INT && v.get_type() != Variant::FLOAT)
                || !std::isfinite(double(v))) {
                result["error"] = CP_TERR_ERR_RANGE; return result;
            }
            // Bound numeric conversion before narrowing to C integers/floats.
            if (std::abs(double(v)) > 4294967295.0) {
                result["error"] = CP_TERR_ERR_RANGE; return result;
            }
        }
#define FIELD(name) if (options.has(#name)) p.name = static_cast<decltype(p.name)>(double(options[#name]));
        TERRAIN_FIELDS(FIELD)
#undef FIELD
        int rc = cp_terrain_validate(&p);
        result["error"] = rc;
        if (rc) return result;
        const int count = p.n * p.n;
        PackedFloat32Array height, flow, sediment;
        PackedByteArray material;
        height.resize(count); flow.resize(count); sediment.resize(count); material.resize(count);
        std::vector<float> scratch(count);
        std::vector<int32_t> recv(count), ups(count), queue(count);
        CpTerrain t{};
        t.height = height.ptrw(); t.flow = flow.ptrw(); t.sediment = sediment.ptrw(); t.material = material.ptrw();
        CpTerrainWorkspace ws{scratch.data(), recv.data(), ups.data(), queue.data()};
        stage.store(0); done.store(0); total.store(1);
        rc = cp_terrain_generate(&p, &t, &ws, notify, this);
        result["error"] = rc;
        if (rc) return result;
        result["version"] = CP_TERRAIN_VERSION; result["seed"] = int64_t(p.seed);
        result["n"] = t.n; result["size_m"] = t.size_m;
        result["height"] = height; result["flow"] = flow; result["sediment"] = sediment;
        result["material"] = material; result["hash"] = hash_text(cp_terrain_hash(&t));
        Array caves;
        for (int i = 0; i < t.cave_count; ++i) {
            const auto &c = t.caves[i]; Dictionary cave;
            cave["position"] = Vector3(c.x_m, c.z_m, c.y_m);
            cave["facing"] = Vector3(c.facing_x, 0, c.facing_y);
            cave["size"] = Vector3(c.width_m, c.height_m, c.depth_m);
            cave["waterfall"] = bool(c.waterfall); caves.append(cave);
        }
        result["caves"] = caves;
        result["volcano"] = Vector4(t.volcano_x_m, t.volcano_y_m, t.volcano_radius_m, t.crater_radius_m);
        return result;
    }
    int world_reset(const Dictionary &options) {
        CpStageSetup s;
        cp_stage_setup_default(&s, uint32_t(int64_t(options.get("seed", 1))));
        s.terrain = int(options.get("terrain", CP_STAGE_FLAT));
        s.flat_height = float(options.get("flat_height", 42.0));
        s.water_radius = 0; // generated lake is rendered separately; see README.
        s.n = int(options.get("wild_count", s.n));
        return cp_stage_reset(&world, &s);
    }
    Dictionary world_step(const Dictionary &input) {
        CpStageInput i{};
        i.verb = int(input.get("verb", CP_STAGE_CONTINUE));
        i.target = int(input.get("target", 0)); i.move = int(input.get("move", 0));
        i.dir = int(input.get("dir", 0)); i.sprint = bool(input.get("sprint", false));
        i.hx = int16_t(CLAMP(int(input.get("hx", 0)), -32767, 32767));
        i.hz = int16_t(CLAMP(int(input.get("hz", 0)), -32767, 32767));
        i.x = float(input.get("x", 0.0)); i.z = float(input.get("z", 0.0));
        cp_stage_step(&world, &i);
        return world_state();
    }
    Dictionary world_state() const {
        Dictionary d;
        d["tick"] = int64_t(world.tick); d["clock"] = int64_t(world.clock);
        d["hash"] = hash_text(cp_stage_hash(&world)); d["player"] = entity(world.player, 0);
        d["active"] = world.active; d["outcome"] = world.outcome; d["error"] = world.last_error;
        Array wild, events, fighters;
        for (int i = 0; i < world.setup.n; ++i) wild.append(entity(world.wild[i], i + 1));
        for (int i = 0; i < world.combat.n_ev; ++i) {
            auto &e = world.combat.ev[i]; Dictionary ev;
            ev["type"] = e.type; ev["a"] = e.a; ev["b"] = e.b;
            ev["move"] = e.move; ev["amount"] = e.amount; events.append(ev);
        }
        for (int i = 0; i < world.combat.n; ++i) {
            auto &c = world.combat.c[i]; Dictionary f;
            f["move"] = c.move; f["phase"] = c.phase; f["phase_tick"] = c.ptick;
            f["phase_length"] = c.plen; f["hp"] = c.hp; fighters.append(f);
        }
        d["wild"] = wild; d["events"] = events; d["fighters"] = fighters;
        return d;
    }
    String world_observe() const {
        char buffer[65536];
        return cp_stage_observe(&world, buffer, sizeof buffer) >= 0 ? String(buffer) : String();
    }
    int world_command(const String &command) { return cp_stage_command(&world, command.utf8().get_data()); }
};

static void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(Cpore);
}
static void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT cpore_library_init(
    GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize); init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
