import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import net from "node:net";
import path from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, "../..");
const output = await mkdtemp(path.join(tmpdir(), "cpore-blender-smoke-"));
const port = 20_000 + (process.pid % 20_000);
const env = {
  ...process.env,
  CPORE_BLENDER_PORT: String(port),
  CPORE_PROJECT_ROOT: output,
  CPORE_BLENDER_TIMEOUT_MS: "120000",
};
const blender = spawn(process.env.BLENDER_BIN || "blender", [
  "--background",
  "--factory-startup",
  "--python",
  path.join(directory, "addon.py"),
], { cwd: root, env, stdio: ["ignore", "pipe", "pipe"] });
let blenderLog = "";
blender.stdout.on("data", (chunk) => { blenderLog += chunk; });
blender.stderr.on("data", (chunk) => { blenderLog += chunk; });
blender.on("exit", (code) => {
  if (code && code !== 0) console.error(`Blender exited early (${code}):\n${blenderLog}`);
});

async function waitForBridge() {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    if (blender.exitCode !== null) throw new Error(`Blender exited before startup:\n${blenderLog}`);
    const connected = await new Promise((resolve) => {
      const socket = net.createConnection({ host: "127.0.0.1", port });
      socket.once("connect", () => { socket.end(); resolve(true); });
      socket.once("error", () => resolve(false));
      setTimeout(() => { socket.destroy(); resolve(false); }, 500).unref();
    });
    if (connected) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Blender bridge startup timed out:\n${blenderLog}`);
}

function payload(result) {
  assert.notEqual(result.isError, true, result.content?.[0]?.text);
  return JSON.parse(result.content.find((item) => item.type === "text").text);
}

let client;
try {
  await waitForBridge();
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [path.join(directory, "server.js")],
    cwd: root,
    env,
    stderr: "pipe",
  });
  client = new Client({ name: "cpore-blender-smoke", version: "1.0.0" });
  await client.connect(transport);

  const tools = await client.listTools();
  const names = tools.tools.map((tool) => tool.name);
  for (const expected of [
    "blender_status",
    "blender_get_scene",
    "blender_execute_python",
    "blender_render",
    "blender_export_glb",
    "blender_save",
  ]) assert(names.includes(expected), `Missing MCP tool: ${expected}`);

  const status = payload(await client.callTool({ name: "blender_status", arguments: {} }));
  assert.equal(status.status, "ready");

  const creation = await client.callTool({
    name: "blender_execute_python",
    arguments: {
      code: `
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'

def material(name, color):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1)
    value.use_nodes = True
    value.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*color, 1)
    return value

skin = material('Grazer / ochre skin', (0.52, 0.19, 0.055))
belly = material('Grazer / warm belly', (0.82, 0.55, 0.20))
dark = material('Grazer / dark keratin', (0.055, 0.025, 0.03))
eye = material('Grazer / eyes', (0.008, 0.012, 0.016))

def ellipsoid(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj

ellipsoid('Body', (0, 0, 1.25), (1.35, 0.62, 0.72), skin)
ellipsoid('Belly', (0, -0.03, 1.02), (1.10, 0.57, 0.45), belly)
ellipsoid('Head', (1.25, 0, 1.60), (0.65, 0.50, 0.52), skin)
ellipsoid('Muzzle', (1.75, 0, 1.43), (0.42, 0.38, 0.28), belly)
for index, x in enumerate((-0.78, 0.75)):
    for side in (-1, 1):
        ellipsoid(f'Leg {index} {side}', (x, side * 0.43, 0.58), (0.22, 0.22, 0.64), skin)
        ellipsoid(f'Foot {index} {side}', (x + 0.10, side * 0.44, 0.12), (0.34, 0.25, 0.15), dark)
for side in (-1, 1):
    ellipsoid(f'Eye {side}', (1.51, side * 0.43, 1.77), (0.10, 0.065, 0.11), eye)
for index, x in enumerate((-0.75, -0.15, 0.45)):
    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.32, radius2=0, depth=0.85, location=(x, 0, 2.03))
    plate = bpy.context.object
    plate.name = f'Dorsal plate {index + 1}'
    plate.data.materials.append(dark)
ellipsoid('Tail base', (-1.35, 0, 1.30), (0.65, 0.24, 0.25), skin)
ellipsoid('Tail tip', (-1.85, 0.08, 1.48), (0.45, 0.15, 0.16), dark)
result = {'asset': 'Spineback Grazer', 'objects': len(bpy.context.scene.objects)}
`,
      render: true,
      render_options: { width: 480, height: 360, view: "three_quarter", engine: "WORKBENCH" },
    },
  });
  const created = payload(creation);
  assert.equal(created.result.asset, "Spineback Grazer");
  const firstImage = creation.content.find((item) => item.type === "image");
  assert(firstImage?.data, "Creation did not return an image");
  assert.equal(Buffer.from(firstImage.data, "base64").subarray(1, 4).toString(), "PNG");

  const scene = payload(await client.callTool({ name: "blender_get_scene", arguments: {} }));
  assert(scene.object_count >= 20);
  assert(scene.objects.some((object) => object.name === "Body"));

  const revision = await client.callTool({
    name: "blender_execute_python",
    arguments: {
      code: `
skin.diffuse_color = (0.035, 0.48, 0.42, 1)
skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (0.035, 0.48, 0.42, 1)
for index in range(5):
    spot = ellipsoid(f'Bioluminescent spot {index + 1}', (-0.8 + index * 0.4, -0.58, 1.40), (0.10, 0.035, 0.10), belly)
result = {'feedback': 'Changed ochre skin to tidal teal and added five visible flank spots'}
`,
    },
  });
  assert(payload(revision).result.feedback.includes("tidal teal"));

  const rendered = await client.callTool({
    name: "blender_render",
    arguments: { width: 480, height: 360, view: "three_quarter", engine: "WORKBENCH" },
  });
  const render = payload(rendered);
  const secondImage = rendered.content.find((item) => item.type === "image");
  assert(secondImage?.data, "Revision did not return an image");
  assert.notEqual(firstImage.data, secondImage.data, "Visual revision did not change the render");

  const exported = payload(await client.callTool({
    name: "blender_export_glb",
    arguments: { path: "spineback-grazer.glb", animations: false },
  }));
  const glb = await readFile(exported.path);
  assert.equal(glb.subarray(0, 4).toString(), "glTF");
  assert.equal(glb.readUInt32LE(4), 2);

  const saved = payload(await client.callTool({
    name: "blender_save",
    arguments: { path: "spineback-grazer.blend" },
  }));
  assert((await readFile(saved.path)).length > 1000);

  const failure = await client.callTool({
    name: "blender_execute_python",
    arguments: { code: "raise ValueError('smoke expected failure')" },
  });
  assert.equal(failure.isError, true);
  assert(failure.content[0].text.includes("smoke expected failure"));

  const prompts = await client.listPrompts();
  assert(prompts.prompts.some((prompt) => prompt.name === "design-cpore-asset"));
  const prompt = await client.getPrompt({
    name: "design-cpore-asset",
    arguments: { brief: "A tidal scavenger", feedback: "Make the head readable" },
  });
  assert(prompt.messages[0].content.text.includes("Make the head readable"));

  console.log(JSON.stringify({
    ok: true,
    blender: status.blender_version,
    tools: names,
    objects: scene.object_count,
    render: render.path,
    glb: exported.path,
    blend: saved.path,
    output,
  }, null, 2));
} finally {
  if (client) await client.close();
  if (blender.exitCode === null) {
    blender.kill("SIGTERM");
    await Promise.race([once(blender, "exit"), new Promise((resolve) => setTimeout(resolve, 5000))]);
  }
  if (process.env.CPORE_SMOKE_KEEP !== "1") await rm(output, { recursive: true, force: true });
  else console.log(`Kept smoke artifacts in ${output}`);
}
