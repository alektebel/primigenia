# Blender design bridge for LLMs

`tools/blender-mcp/` connects Kimi Code or another MCP client to a live Blender
scene. The model can inspect structured scene state, run Blender Python, receive
rendered PNGs as vision input, revise the same geometry, and export a GLB for
cpore's Three.js renderer.

This is an asset-design tool, not a replacement for cpore's deterministic
`cpore.creature/1` genome. Exported GLBs are visual assets; simulation genomes
still need the shared genome contract in `docs/CREATURE_VISUAL_PLAN.md`.

## Start

Requirements: Blender 4.2+ (tested with 5.3) and Node.js 18+.

```sh
npm ci --prefix tools/blender-mcp
make blender
```

`make blender` opens Blender with the bridge running on `127.0.0.1:9876`. Keep
that Blender process open. The 3D View sidebar also has a **Cpore** panel with
start/stop controls. The server starts automatically when launched this way;
no add-on installation is required.

The repository includes `.kimi-code/mcp.json`. Start a **new** Kimi session in
the repository root, trust the project when prompted, then use `/mcp` to check
`cpore-blender`. Existing Kimi sessions do not pick up newly added MCP servers.

For another MCP client, register the same stdio server:

```json
{
  "mcpServers": {
    "cpore-blender": {
      "command": "node",
      "args": ["tools/blender-mcp/server.js"],
      "cwd": "/absolute/path/to/cpore",
      "env": {
        "CPORE_PROJECT_ROOT": "/absolute/path/to/cpore",
        "CPORE_BLENDER_PORT": "9876"
      }
    }
  }
}
```

Run the MCP server and Blender on the same machine. Set `CPORE_BLENDER_PORT` on
both if 9876 is occupied. `CPORE_BLENDER_TIMEOUT_MS` controls the MCP-side
request timeout (default 170000).

## Tools

| MCP tool | Purpose |
|---|---|
| `blender_status` | Verify the live connection and Blender version. |
| `blender_get_scene` | Read objects, transforms, mesh counts, materials, modifiers, camera, and units. |
| `blender_execute_python` | Run arbitrary `bpy` code; variables persist between calls. Assign output to `result`. Can render after the edit. |
| `blender_render` | Return an actual PNG plus its path. Supports Workbench, EEVEE, Cycles, and current/three-quarter/front/side/top cameras. |
| `blender_export_glb` | Export all or selected objects as binary glTF 2.0, with optional animations and modifier application. |
| `blender_save` | Save a compressed, editable `.blend`. |

Renders default to `art/generated/renders/`. Relative export/save paths resolve
from the cpore root. Existing `.glb` and `.blend` files are not overwritten
unless `overwrite: true` is explicit. Rendering creates a preview camera if the
scene has none; a named camera preset repositions the active camera to frame
visible geometry.

Workbench is the fast modeling-feedback default and displays material viewport
colors. Use EEVEE or Cycles when lighting, emission, transparency, or final
materials matter.

## Prompts

The MCP prompt `design-cpore-asset` accepts a brief and optional human feedback.
If the client does not expose MCP prompts, paste this into a new session:

> Use cpore-blender to design a six-legged tidal scavenger with expressive
> eyes, dorsal armor, and readable proportions at gameplay distance. Inspect
> the current scene before editing. Build it with Blender Python, render a
> three-quarter view, inspect the image, then revise weak shapes or colors.
> Check front and side views. Save art/generated/tidal-scavenger.blend and
> export art/generated/tidal-scavenger.glb. Do not overwrite existing files.

For a visual iteration, follow with:

> Render the current creature. Its silhouette is too round and the head is hard
> to read. Elongate the body 15%, raise the head, enlarge the eyes slightly,
> and shift the skin toward tidal teal. Render the revised three-quarter view
> and compare it with the previous version before exporting.

## Sample creature parts

```sh
make blender-sample-parts
```

This isolated background Blender run generates 24 reusable visual parts under
`art/generated/parts/`. The foundation set contains stalk and triad eyes,
nipping jaw, horn crown, shell plate, sprinter and sucker legs, grasper arm,
paddle and spike tails, glider wing, and display frill. The researched set adds
crushing beak, shearing mandibles, trumpet snout, spring tongue, spit sacs,
smasher arm, spring and hoof feet, gecko foot, lantern lure, insect wing, and
hammer tail. Each part is a self-contained GLB with materials and anatomical
attachment origin. The directory also contains `manifest.json`, an editable
`catalog.blend`, and a labeled `catalog.png` preview.

The researched set follows Spore-like modularity and ability archetypes using
original geometry. Online design and biological references are recorded in
[PART_INSPIRATION.md](PART_INSPIRATION.md); no game meshes or textures are used.

In source Blender space, +Z is up, +X is forward, and the origin is the
attachment point. Legs extend down, tails backward, and horns upward. GLB uses
its standard +Y-up conversion and meter units. Mirror `wing_glider` across XZ
for the opposite wing. Suggested abilities in the manifest are illustrative;
these meshes are not simulation genomes.

## Verification

```sh
make blender-mcp-smoke
```

The smoke command starts an isolated background Blender and a real MCP stdio
client. It discovers tools and prompts, creates a creature, checks scene state,
returns and compares two different rendered PNGs after a visual revision,
validates the GLB header/version, and saves a `.blend`. Temporary artifacts are
removed unless `CPORE_SMOKE_KEEP=1` is set.

## Security and failure modes

- The bridge binds only to loopback; do not expose the port to a network.
- `blender_execute_python` has the permissions of the Blender process. It can
  read/write files and run subprocesses. Use trusted models and review prompts
  from untrusted sources. Do not auto-approve every MCP tool blindly.
- Model code runs on Blender's main thread. An infinite loop or a very heavy
  mesh operation can freeze Blender; the MCP timeout does not interrupt Python.
  Save important work before autonomous modeling.
- Each code call requests an undo checkpoint, but arbitrary Python and render
  operations are not guaranteed to be one-step undoable. Keep `.blend` saves.
- The stdio server writes protocol messages to stdout and diagnostics to stderr.
  Do not launch it in a normal terminal and type into it; connect an MCP client.
