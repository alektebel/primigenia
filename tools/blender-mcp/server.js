import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import net from "node:net";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";

const HOST = "127.0.0.1";
const PORT = Number(process.env.CPORE_BLENDER_PORT || 9876);
const TIMEOUT_MS = Number(process.env.CPORE_BLENDER_TIMEOUT_MS || 170_000);
const ROOT = path.resolve(process.env.CPORE_PROJECT_ROOT || process.cwd());
const MAX_MESSAGE_BYTES = 64 * 1024 * 1024;
let queue = Promise.resolve();

if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
  throw new Error("CPORE_BLENDER_PORT must be an integer from 1 to 65535");
}

function sendRequest(command, params) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: HOST, port: PORT });
    const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    let buffer = Buffer.alloc(0);
    let settled = false;

    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      socket.destroy();
      if (error) reject(error);
      else resolve(result);
    };
    const timer = setTimeout(() => {
      finish(new Error(`Blender did not answer ${command} within ${TIMEOUT_MS} ms`));
    }, TIMEOUT_MS);

    socket.setEncoding("utf8");
    socket.on("connect", () => {
      socket.write(`${JSON.stringify({ id, command, params: { ...params, project_root: ROOT } })}\n`);
    });
    socket.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, Buffer.from(chunk)]);
      if (buffer.length > MAX_MESSAGE_BYTES) {
        finish(new Error("Blender response exceeds 64 MiB"));
        return;
      }
      const newline = buffer.indexOf(10);
      if (newline === -1) return;
      try {
        const response = JSON.parse(buffer.subarray(0, newline).toString("utf8"));
        if (response.id !== id) throw new Error("Blender response id does not match request");
        if (!response.ok) throw new Error(response.error || "Unknown Blender error");
        finish(null, response.result);
      } catch (error) {
        finish(error);
      }
    });
    socket.on("error", (error) => {
      if (error.code === "ECONNREFUSED") {
        finish(new Error("Blender bridge is offline. Run `make blender` and keep Blender open."));
      } else {
        finish(error);
      }
    });
    socket.on("end", () => {
      if (!settled) finish(new Error("Blender closed the connection before answering"));
    });
  });
}

function request(command, params = {}) {
  const task = queue.then(() => sendRequest(command, params));
  queue = task.catch(() => undefined);
  return task;
}

function textResult(value) {
  return { content: [{ type: "text", text: JSON.stringify(value, null, 2) }] };
}

async function call(command, params = {}) {
  try {
    return textResult(await request(command, params));
  } catch (error) {
    return {
      content: [{ type: "text", text: `Blender command failed: ${error.message}` }],
      isError: true,
    };
  }
}

async function imageResult(metadata) {
  const data = await readFile(metadata.path);
  return {
    content: [
      { type: "text", text: JSON.stringify(metadata, null, 2) },
      { type: "image", data: data.toString("base64"), mimeType: "image/png" },
    ],
  };
}

const renderOptions = {
  width: z.number().int().min(64).max(2048).default(1024),
  height: z.number().int().min(64).max(2048).default(1024),
  engine: z.enum(["WORKBENCH", "EEVEE", "CYCLES"]).default("WORKBENCH"),
  view: z.enum(["current", "three_quarter", "front", "side", "top"]).default("current"),
  camera: z.string().optional().describe("Existing camera name; defaults to the active scene camera"),
  transparent: z.boolean().default(false),
};

const server = new McpServer(
  { name: "cpore-blender", version: "1.0.0" },
  {
    instructions: [
      "Design iteratively in Blender: inspect the scene, execute focused bpy edits, render, visually critique, then revise.",
      "Use meters, +Z up, descriptive object/material names, and non-destructive modifiers where practical.",
      "For cpore assets, keep the main subject near the origin and export GLB for the Three.js client.",
      "Do not reset or overwrite the user's scene unless explicitly asked. Execute Python only in the trusted local Blender session.",
    ].join(" "),
  },
);

server.registerTool(
  "blender_status",
  {
    title: "Check Blender connection",
    description: "Check that the Cpore Blender add-on is running and return its version and current file.",
    inputSchema: {},
  },
  async () => call("ping"),
);

server.registerTool(
  "blender_get_scene",
  {
    title: "Inspect Blender scene",
    description: "Return structured scene state: objects, transforms, mesh counts, materials, modifiers, collections, camera, and units.",
    inputSchema: {
      object_limit: z.number().int().min(1).max(500).default(200),
    },
  },
  async (params) => call("get_scene", params),
);

server.registerTool(
  "blender_execute_python",
  {
    title: "Design with Blender Python",
    description: "Execute bpy Python in Blender's main thread. Variables persist between calls; assign JSON-serializable output to `result`. Use for modeling, materials, rigging, lighting, and revisions. Optionally render after the edit.",
    inputSchema: {
      code: z.string().min(1).max(200_000),
      undo_label: z.string().max(100).default("Cpore MCP edit"),
      render: z.boolean().default(false).describe("Render immediately after successful execution"),
      render_options: z.object(renderOptions).optional(),
    },
  },
  async (params) => {
    try {
      const result = await request("execute", params);
      if (!result.render) return textResult(result);
      const image = await imageResult(result.render);
      return {
        content: [
          { type: "text", text: JSON.stringify(result, null, 2) },
          image.content[1],
        ],
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Blender execution failed: ${error.message}` }],
        isError: true,
      };
    }
  },
);

server.registerTool(
  "blender_render",
  {
    title: "Render visual feedback",
    description: "Render the active scene to PNG and return the actual image for visual critique. WORKBENCH is fast; EEVEE shows scene lighting; CYCLES is path traced. Camera presets frame all visible geometry.",
    inputSchema: renderOptions,
  },
  async (params) => {
    try {
      return await imageResult(await request("render", params));
    } catch (error) {
      return { content: [{ type: "text", text: `Blender render failed: ${error.message}` }], isError: true };
    }
  },
);

server.registerTool(
  "blender_export_glb",
  {
    title: "Export game asset",
    description: "Export the scene or selected objects as binary glTF 2.0 for cpore's Three.js renderer. Relative paths resolve from the cpore project root.",
    inputSchema: {
      path: z.string().min(1).describe("Destination ending in .glb, for example art/generated/creature.glb"),
      selected_only: z.boolean().default(false),
      apply_modifiers: z.boolean().default(true),
      animations: z.boolean().default(true),
      overwrite: z.boolean().default(false),
    },
  },
  async (params) => call("export", params),
);

server.registerTool(
  "blender_save",
  {
    title: "Save Blender source",
    description: "Save the editable scene as a compressed .blend file. Existing files require overwrite=true. Relative paths resolve from the cpore project root.",
    inputSchema: {
      path: z.string().min(1).describe("Destination ending in .blend"),
      overwrite: z.boolean().default(false),
    },
  },
  async (params) => call("save", params),
);

server.registerPrompt(
  "design-cpore-asset",
  {
    title: "Iterative cpore asset design",
    description: "Guide a model through scene inspection, modeling, visual feedback, revision, and GLB export.",
    argsSchema: {
      brief: z.string().min(1).describe("Asset, style, gameplay role, and constraints"),
      feedback: z.string().optional().describe("Optional human critique of the current design"),
    },
  },
  ({ brief, feedback }) => ({
    messages: [
      {
        role: "user",
        content: {
          type: "text",
          text: `Design this cpore asset in Blender: ${brief}\n${feedback ? `Human feedback: ${feedback}\n` : ""}\nUse cpore's original Spore-like creature/prop language with a painterly BotW-inspired finish, without copying protected assets. Inspect before editing. Work in meters with +Z up, keep the subject near the origin, and name objects/materials clearly. Build an initial version with blender_execute_python, render a three_quarter view, inspect the image, and revise visible problems. Then render front and side views for proportion checks. Save the editable .blend and export a GLB under art/generated/. Explain design choices and report exact output paths.`,
        },
      },
    ],
  }),
);

await server.connect(new StdioServerTransport());
console.error(`Cpore Blender MCP ready; bridge=${HOST}:${PORT}; project=${ROOT}`);
