#include "atmosphere.h"
#include "cpore_terrain.h"
#include "cpore_world.h"
#include <godot_cpp/godot.hpp>

using namespace godot;

static void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(CporeTerrain);
    GDREGISTER_CLASS(CporeWorld);
    GDREGISTER_CLASS(CporeAtmosphere);
}
static void terminate(ModuleInitializationLevel) {}

extern "C" GDExtensionBool GDE_EXPORT cpore_library_init(
    GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
