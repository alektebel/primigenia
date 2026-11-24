# WL6 cave mesher handoff

The GDExtension exposes `CporeTerrain.cave_mesh(params)` as a static method. The existing SConstruct compiles the new source through `Glob("*.cpp")`.

## Integration

Pass a copy of `world.state().cave` and set `seed` to the desired unsigned 32-bit visual seed (default 1). The generator reads `x`, `z`, `fx`, `fz`, `floor`, `half`, `length` and `radius`. As in the C initializer, the chamber centre lies at `length + radius` along the inward axis. An empty dictionary requests the default cave at the origin facing +Z. A disabled cave or an invalid numeric parameter returns an empty dictionary.

| Optional parameter | Default | Meaning |
|---|---|---|
| `mouth_half` | `half + 1.2` m | Half-width at the entrance plane, at least `half + 0.6` m |
| `mouth_height` | 4.4 m | Height at the centre of the arch, range 3–9 m |

The mesh ends at the entrance plane `u = 0`. Boundary edges there each have one incident triangle. Use these edges to fit the outcrop around the actual lip. The passage opens inward along `(-fx, 0, -fz)`. All positions already include the site transform and floor elevation.

| Result key | Type | Use |
|---|---|---|
| `vertices`, `normals`, `indices` | PackedVector3Array, PackedVector3Array, PackedInt32Array | Supply to the corresponding ArrayMesh slots for one indexed triangle surface. Normals face the air and triangles wind clockwise from inside. |
| `stalactites`, `stalactite_normals` | PackedVector3Array each | Paired roof positions and downward surface normals, sampled with drip noise. |
| `wet_patches` | PackedVector3Array | Floor positions in world metres. |
| `flowstone`, `flowstone_normals` | PackedVector3Array each | Paired wall positions and inward surface normals. |

The signed field unions the buffered C passage and chamber with side alcoves, a raised dome and an offset collapse chimney. Two scales of integer-hashed 3D value noise expand the cavity by 0.5–3 m, tapering to zero at the mouth. The floor plane and the 9 m upper bound clip the displaced volume. Marching cubes samples at 0.4 m, shares intersections between adjacent cubes and resolves four-crossing faces using the face centre. Central differences of the field provide smooth normals.

## Verification

- Built with the repository build profile and Godot 4.7.2 on Linux x86-64. Used a workspace-local copy of the shared godot-cpp dependency and ran `make godot-cave-mesh-test GODOT_CPP="$PWD/build/godot-cpp"`. The target runs Godot headless under `nice -n 10` and a 120-second timeout.
- The rotated, translated seed-42 fixture produced **31,540 triangles and 15,815 vertices**. The SHA-256 of the packed vertices, normals and indices was `c59dc0ab45bb270621aefbe33cd7a10674ebfc8f6aa0f1311efa8e9da663f374`. Rebuilding the same site reproduced the mesh bytes and all anchors.
- All 500 floor rays in the fully overridden region matched `cave_site.adjust()` with a raised raw terrain height. Maximum measured difference was 0.000000 m. Another 96 rays checked the flat shell in the terrain blend band. The test also checked every triangle against the 2.5 m clearance volume, interior edge incidence and winding, the open mouth dimensions, unit normals and dressing outputs.
- Repeated the acceptance checks with visual seeds 0, 1, 7, 42, 987654321 and 4294967295. All passed within the triangle budget.
- `make -j4 test` passed. Seeds 1, 7 and 42 each certified 288/288 routes with identical replays, including the chamber routes. The existing Godot secrets test passed all 35 checks in a separate headless run.
- Godot reported an editor socket bind failure during import and resource leak diagnostics on project shutdown. Both headless test processes exited successfully. The same shutdown diagnostics appeared in the existing secrets test.

## Open integration questions

- The C rule and `cave_site.adjust()` blend raw terrain into the floor in the outer 0.8 m of the footprint. An exactly flat mesh can differ from that blend when the terrain is above the entrance floor. The test measures the interior and the transition band separately. How should the outcrop or terrain material cover this junction?
- The shell supplies attachment positions. The art pass determines stalactite lengths and how many dressing instances to draw while preserving clearance. Final draw calls and the visible mouth-to-outcrop join need verification in the integrated scene.

## Intended commits

1. `feat(godot): mesh deterministic cave interiors and expose dressing anchors`
2. `test(godot): verify cave floor, clearance, topology and repeatability`
