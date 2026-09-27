#!/usr/bin/env node

/**
 * Godot MCP Pro Server Bridge
 * Connects MCP clients (Claude Code, etc.) via stdio to the Godot 4 editor plugin (WebSocket).
 *
 * Tool schemas are generated at startup by parsing ../commands/*_commands.gd, so every
 * command the plugin registers is exposed with its real parameter names, types and defaults.
 * The previous hand-written bridge is kept as index.original.js.
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} = require("@modelcontextprotocol/sdk/types.js");
const { WebSocketServer } = require("ws");

const START_PORT = parseInt(process.env.GODOT_MCP_PORT || "6505", 10);
const MAX_PORT = 6514; // the plugin connects to every port in 6505-6514
const DEFAULT_TIMEOUT_MS = 60000;
const LONG_TIMEOUT_MS = 300000;
const LONG_COMMANDS = new Set([
  "run_test_scenario", "run_stress_test", "run_headless_scene", "run_headless_script",
  "export_project", "deploy_to_android", "bake_navigation_mesh", "capture_frames",
  "replay_recording", "monitor_properties", "watch_signals", "wait_for_node",
  "navigate_to", "move_to", "reload_project", "find_unused_resources",
  "detect_circular_dependencies", "cross_scene_set_property",
]);

const ADDON_DIR = path.resolve(__dirname, "..");
const COMMANDS_DIR = path.join(ADDON_DIR, "commands");
const PROJECT_DIR = path.resolve(ADDON_DIR, "..", "..");

const log = (...a) => console.error("[Godot-MCP]", ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------
// Schema generation from GDScript command sources
// ---------------------------------------------------------------------------

const TYPE_MAP = { string: "string", bool: "boolean", int: "integer", float: "number" };

// Short hints for the most used commands. Everything else gets a generated description.
const HINTS = {
  get_project_info: "Project name, Godot version, viewport size, renderer, autoloads.",
  get_filesystem_tree: "Directory tree of the project. filter e.g. '*.gd' or '*.tscn'.",
  get_scene_tree: "Node hierarchy of the scene currently open in the editor.",
  create_scene: "Create a .tscn with the given root type and open it in the editor.",
  open_scene: "Open a scene in the editor (makes it the target for add_node etc.).",
  save_scene: "Save the open scene (path optional = current scene).",
  add_node: "Add a node to the currently open scene. parent_path '.' = root. properties values are strings parsed by Godot, e.g. \"Vector2(10, 20)\", \"#ff0000\".",
  update_property: "Set a property on a node in the open scene. value is parsed: \"Vector2(1,2)\", \"Color(1,0,0,1)\", \"true\", \"42\".",
  add_resource: "Create and assign a resource (e.g. RectangleShape2D, CircleShape2D) to a node property.",
  create_script: "Create a new .gd file. Prefer full `content`.",
  edit_script: "Edit a script: `replacements` [{search, replace}], or full `content`, or `insert_at_line` + `text`, or `start_line`/`end_line` + `text`.",
  attach_script: "Attach a script to a node in the open scene.",
  validate_script: "Check a script for parse errors without running it.",
  play_scene: "Run the game. mode: 'main' (F5), 'current' (F6) or a res:// scene path.",
  stop_scene: "Stop the running game.",
  get_game_screenshot: "Screenshot of the running game (returned as an image).",
  get_editor_screenshot: "Screenshot of the editor (returned as an image).",
  capture_frames: "Capture several frames of the running game (returned as images).",
  simulate_key: "Send a key event to the running game. keycode e.g. 'W', 'SPACE', 'LEFT'. Bridge extra: duration (s) = press, hold, release.",
  simulate_action: "Send an InputMap action to the running game. Bridge extra: duration (s) = press, hold, release.",
  simulate_mouse_click: "Click at viewport coords x,y in the running game (auto_release true by default).",
  simulate_sequence: "Send a list of input events with frame_delay between them.",
  set_input_action: "Define/replace an InputMap action and its events.",
  set_project_setting: "Change a project setting (never edit project.godot by hand while the editor is open).",
  get_editor_errors: "Recent editor/script errors and runtime exceptions.",
  get_output_log: "Recent Output panel lines (print() output, warnings).",
  execute_game_script: "Run GDScript inside the running game. No nested funcs; use .get('prop').",
  execute_editor_script: "Run GDScript inside the editor.",
  reload_project: "Rescan filesystem / reload scripts after big changes.",
};

function splitFuncs(src) {
  const funcs = {};
  for (const part of src.split(/^(?=(?:static )?func )/m)) {
    const m = part.match(/^(?:static )?func (\w+)/);
    if (m) funcs[m[1]] = part;
  }
  return funcs;
}

function parseDefault(raw, type) {
  if (raw === undefined) return undefined;
  const v = raw.trim();
  if (type === "boolean") return v === "true" ? true : v === "false" ? false : undefined;
  if (type === "integer" || type === "number") {
    const n = Number(v);
    return Number.isFinite(n) ? n : undefined;
  }
  if (type === "string") {
    const m = v.match(/^"(.*)"$/);
    return m ? m[1] : undefined;
  }
  return undefined;
}

function buildTools() {
  const tools = [];
  let files = [];
  try {
    files = fs.readdirSync(COMMANDS_DIR).filter((f) => f.endsWith("_commands.gd")).sort();
  } catch (e) {
    log("Could not read commands dir:", e.message);
  }

  for (const file of files) {
    const category = file.replace("_commands.gd", "");
    const funcs = splitFuncs(fs.readFileSync(path.join(COMMANDS_DIR, file), "utf8"));
    const getCommands = funcs.get_commands;
    if (!getCommands) continue;

    for (const [, name, handler] of getCommands.matchAll(/"(\w+)"\s*:\s*(\w+)/g)) {
      let body = funcs[handler] || "";
      for (const c of body.matchAll(/\b(_\w+)\(params\b/g)) {
        if (funcs[c[1]] && c[1] !== handler) body += funcs[c[1]];
      }

      const properties = {};
      const required = [];
      for (const x of body.matchAll(/require_(\w+)\(params,\s*"(\w+)"/g)) {
        const [, kind, key] = x;
        if (properties[key]) continue;
        properties[key] = kind === "string" ? { type: "string" } : kind === "dictionary_array" ? { type: "array", items: { type: "object" } } : {};
        required.push(key);
      }
      for (const x of body.matchAll(/optional_(\w+)\(params,\s*"(\w+)"(?:,\s*([^)]+))?\)/g)) {
        const [, kind, key, def] = x;
        if (properties[key]) continue;
        const type = TYPE_MAP[kind];
        const prop = type ? { type } : {};
        const d = parseDefault(def, type);
        if (d !== undefined) prop.default = d;
        properties[key] = prop;
      }
      for (const x of body.matchAll(/params(?:\.get\(|\.has\(|\[)"(\w+)"/g)) {
        if (!properties[x[1]]) properties[x[1]] = {};
      }

      if (name === "simulate_key" || name === "simulate_action") {
        properties.duration = { type: "number", description: "Bridge extra: hold for N seconds then release (0.3-0.5 recommended)." };
      }

      const hint = HINTS[name] ? ` ${HINTS[name]}` : "";
      tools.push({
        name,
        description: `[Godot ${category}] ${name}.${hint}`,
        inputSchema: { type: "object", properties, ...(required.length ? { required } : {}), additionalProperties: true },
      });
    }
  }

  tools.push({
    name: "godot_command",
    description: "Escape hatch: run any Godot MCP Pro command by name with arbitrary params (use when a command is not listed as its own tool).",
    inputSchema: {
      type: "object",
      properties: {
        command: { type: "string", description: "Command name, e.g. get_project_info" },
        params: { type: "object", additionalProperties: true },
      },
      required: ["command"],
    },
  });
  return tools;
}

const TOOLS = buildTools();
log(`Generated ${TOOLS.length} tools from ${COMMANDS_DIR}`);

// ---------------------------------------------------------------------------
// WebSocket link to the editor plugin (the plugin connects to us as a client)
// ---------------------------------------------------------------------------

let godotSocket = null;
let nextRequestId = 1;
const pendingRequests = new Map();

function readAuthToken() {
  try {
    const cfg = fs.readFileSync(path.join(PROJECT_DIR, "project.godot"), "utf8");
    const name = (cfg.match(/config\/name="([^"]*)"/) || [])[1];
    const base = process.platform === "win32"
      ? path.join(process.env.APPDATA || "", "Godot", "app_userdata")
      : process.platform === "darwin"
        ? path.join(os.homedir(), "Library", "Application Support", "Godot", "app_userdata")
        : path.join(os.homedir(), ".local", "share", "godot", "app_userdata");
    return fs.readFileSync(path.join(base, name, "mcp_auth_token"), "utf8").trim();
  } catch {
    return null;
  }
}

function startWebSocketServer(port) {
  const wss = new WebSocketServer({ port, host: "127.0.0.1", maxPayload: 64 * 1024 * 1024 });

  wss.on("error", (err) => {
    if (err.code === "EADDRINUSE" && port < MAX_PORT) {
      log(`Port ${port} in use, trying ${port + 1}`);
      startWebSocketServer(port + 1);
    } else {
      log(`WebSocket error on port ${port}:`, err.message);
    }
  });

  wss.on("listening", () => log(`Listening for Godot on ws://127.0.0.1:${port}`));

  wss.on("connection", (ws) => {
    log(`Godot editor connected on port ${port}`);
    godotSocket = ws;

    const keepAlive = setInterval(() => {
      if (ws.readyState === 1) ws.send(JSON.stringify({ jsonrpc: "2.0", method: "ping", params: {} }));
    }, 10000);

    ws.on("message", (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch (err) {
        return log("Bad message from Godot:", err.message);
      }
      if (msg.method === "ping") {
        ws.send(JSON.stringify({ jsonrpc: "2.0", method: "pong", params: {} }));
        return;
      }
      if (msg.method === "pong") return;
      if (msg.method === "auth_required") {
        const token = readAuthToken();
        if (!token) return log("Godot requires a connection token but mcp_auth_token was not found.");
        ws.send(JSON.stringify({ jsonrpc: "2.0", id: `auth-${Date.now()}`, method: "auth", params: { token } }));
        return;
      }
      if (msg.id !== undefined && pendingRequests.has(msg.id)) {
        const { resolve, timer } = pendingRequests.get(msg.id);
        clearTimeout(timer);
        pendingRequests.delete(msg.id);
        resolve(msg);
      }
    });

    ws.on("close", () => {
      clearInterval(keepAlive);
      log(`Godot editor disconnected from port ${port}`);
      if (godotSocket === ws) godotSocket = null;
    });

    ws.on("error", (err) => log("Client socket error:", err.message));
  });
}

startWebSocketServer(START_PORT);

async function waitForGodot(ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (godotSocket && godotSocket.readyState === 1) return true;
    await sleep(250);
  }
  return !!(godotSocket && godotSocket.readyState === 1);
}

async function sendToGodot(method, params = {}) {
  // The plugin retries every 3s, so give it a moment right after startup.
  if (!(await waitForGodot(4000))) {
    return {
      error: {
        code: -1,
        message: "Godot editor is not connected. Open the project in Godot with the 'Godot MCP Pro' plugin enabled (Project > Project Settings > Plugins).",
      },
    };
  }

  const timeoutMs = LONG_COMMANDS.has(method) ? LONG_TIMEOUT_MS : DEFAULT_TIMEOUT_MS;
  return new Promise((resolve) => {
    const id = nextRequestId++;
    const timer = setTimeout(() => {
      if (pendingRequests.delete(id)) {
        resolve({ error: { code: -32000, message: `Command '${method}' timed out after ${timeoutMs / 1000}s` } });
      }
    }, timeoutMs);
    pendingRequests.set(id, { resolve, timer });
    godotSocket.send(JSON.stringify({ jsonrpc: "2.0", id, method, params }));
  });
}

// ---------------------------------------------------------------------------
// Bridge-side conveniences
// ---------------------------------------------------------------------------

async function runCommand(method, params) {
  params = { ...(params || {}) };

  // Accept the aliases used in the plugin docs.
  if (method === "simulate_key" && params.keycode === undefined && params.key !== undefined) {
    params.keycode = params.key;
    delete params.key;
  }
  if (method === "save_scene" && params.path === undefined && params.scene_path !== undefined) {
    params.path = params.scene_path;
    delete params.scene_path;
  }

  if ((method === "simulate_key" || method === "simulate_action") && Number(params.duration) > 0) {
    const duration = Number(params.duration);
    delete params.duration;
    const down = await sendToGodot(method, { ...params, pressed: true });
    if (down.error) return down;
    await sleep(duration * 1000);
    const up = await sendToGodot(method, { ...params, pressed: false });
    if (up.error) return up;
    return { result: { ...(down.result || {}), held_seconds: duration, released: true } };
  }

  delete params.duration;
  return sendToGodot(method, params);
}

function toContent(result) {
  const content = [];
  const images = [];
  const strip = (obj) => {
    if (Array.isArray(obj)) return obj.map(strip);
    if (!obj || typeof obj !== "object") return obj;
    const copy = {};
    for (const [k, v] of Object.entries(obj)) {
      if ((k === "image_base64" || k === "diff_image_base64") && typeof v === "string") {
        images.push(v);
        copy[k] = `<image ${images.length} attached>`;
      } else if (k === "frames" && Array.isArray(v) && v.every((f) => typeof f === "string")) {
        v.forEach((f) => images.push(f));
        copy[k] = `<${v.length} frames attached as images>`;
      } else {
        copy[k] = strip(v);
      }
    }
    return copy;
  };
  const clean = strip(result);
  content.push({ type: "text", text: JSON.stringify(clean, null, 2) });
  for (const data of images) content.push({ type: "image", data, mimeType: "image/png" });
  return content;
}

// ---------------------------------------------------------------------------
// MCP server
// ---------------------------------------------------------------------------

const server = new Server(
  { name: "godot-mcp-pro", version: "1.16.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  let method = name;
  let params = args || {};
  if (name === "godot_command") {
    method = params.command;
    params = params.params || {};
  }

  const response = await runCommand(method, params);
  if (response.error) {
    const data = response.error.data ? `\n${JSON.stringify(response.error.data)}` : "";
    return {
      isError: true,
      content: [{ type: "text", text: `Error from Godot [${response.error.code}]: ${response.error.message}${data}` }],
    };
  }
  return { content: toContent(response.result !== undefined ? response.result : response) };
});

async function main() {
  await server.connect(new StdioServerTransport());
  log("MCP server ready on stdio");
}

main().catch((err) => {
  log("Fatal error:", err);
  process.exit(1);
});
