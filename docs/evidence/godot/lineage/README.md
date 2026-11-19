# Lineage evidence

The headless test creates three actual studio bodies and checks independent live
SubViewports, two cousin branch buttons, pause/menu entry, map pins, scenario
save/load and replay hashes. A second test exercises the real island console,
cousin actors and restoring an earlier generation. Run `make godot-lineage-test`.

To capture the 1280×720 tree using xvfb and software GL, run
`make godot-lineage-evidence`. It writes `family-tree.png` and `lineage.json` here.
The capture was attempted in this session but X11/Wayland display creation failed
inside the sandbox. No screenshot is included yet.

The shared godot-cpp source was read-only here. For local verification it was
copied into ignored `build/deps/godot-cpp` and the build used:

```
make godot GODOT_CPP="$PWD/build/deps/godot-cpp"
```

Isolated test data used `XDG_DATA_HOME=/tmp/c2-godot-data` and
`XDG_CONFIG_HOME=/tmp/c2-godot-config`, leaving the owner's save slots untouched.
