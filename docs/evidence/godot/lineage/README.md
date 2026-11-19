# Lineage evidence

The headless test creates three actual studio bodies and checks independent live
SubViewports, two cousin branch buttons, pause/menu entry, map pins, scenario
save/load and replay hashes. A second test exercises the real island console,
cousin actors and restoring an earlier generation. Run `make godot-lineage-test`.

`make godot-lineage-evidence` (xvfb, software GL) writes, from the real island test:
`cousin-in-valley.jpg` (a cousin of the founding body 7 m away with its card selected) and
`family-tree-island.jpg` (three generations, type badge and name, part diffs, cousin pins,
opened with T), plus `lineage.json`. Captured 2026-11-19 after merging the social loop.

The shared godot-cpp source was read-only here. For local verification it was
copied into ignored `build/deps/godot-cpp` and the build used:

```
make godot GODOT_CPP="$PWD/build/deps/godot-cpp"
```

Isolated test data used `XDG_DATA_HOME=/tmp/c2-godot-data` and
`XDG_CONFIG_HOME=/tmp/c2-godot-config`, leaving the owner's save slots untouched.
