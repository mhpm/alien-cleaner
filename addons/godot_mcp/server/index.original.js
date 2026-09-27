#!/usr/bin/env node

/**
 * Godot MCP Pro Server Bridge
 * Connects AI assistants (Antigravity, Claude, Cursor) via MCP stdio to the Godot 4 Editor plugin (WebSocket).
 */

const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} = require("@modelcontextprotocol/sdk/types.js");
const { WebSocketServer } = require("ws");

const START_PORT = parseInt(process.env.GODOT_MCP_PORT || "6505", 10);
const MAX_PORT = 6514;

// State
let godotSocket = null;
let nextRequestId = 1;
const pendingRequests = new Map(); // id -> { resolve, reject, timeout }

// Start WebSocket Server for Godot with automatic port fallback (6505-6514)
function startWebSocketServer(port) {
  const wss = new WebSocketServer({ port, host: "127.0.0.1" });

  wss.on("error", (err) => {
    if (err.code === "EADDRINUSE" && port < MAX_PORT) {
      console.error(`[Godot-MCP] Port ${port} is in use, retrying on port ${port + 1}...`);
      startWebSocketServer(port + 1);
    } else {
      console.error(`[Godot-MCP] WebSocket error on port ${port}:`, err);
    }
  });

  wss.on("listening", () => {
    console.error(`[Godot-MCP] WebSocket server listening on ws://127.0.0.1:${port}`);
  });

  wss.on("connection", (ws) => {
    console.error(`[Godot-MCP] Godot Editor connected on port ${port}`);
    godotSocket = ws;

    ws.on("message", (raw) => {
      try {
        const msg = JSON.parse(raw.toString());
        
        // Heartbeat ping
        if (msg.method === "ping") {
          ws.send(JSON.stringify({ jsonrpc: "2.0", method: "pong", params: {} }));
          return;
        }
        if (msg.method === "pong") {
          return;
        }

        // Handle response to a pending request
        if (msg.id !== undefined && pendingRequests.has(msg.id)) {
          const { resolve, timer } = pendingRequests.get(msg.id);
          clearTimeout(timer);
          pendingRequests.delete(msg.id);
          resolve(msg);
        }
      } catch (err) {
        console.error("[Godot-MCP] Error parsing message from Godot:", err);
      }
    });

    ws.on("close", () => {
      console.error(`[Godot-MCP] Godot Editor disconnected from port ${port}`);
      if (godotSocket === ws) {
        godotSocket = null;
      }
    });

    ws.on("error", (err) => {
      console.error("[Godot-MCP] Client WebSocket error:", err);
    });
  });
}

startWebSocketServer(START_PORT);

/**
 * Send JSON-RPC request to Godot
 */
function sendToGodot(method, params = {}) {
  return new Promise((resolve, reject) => {
    if (!godotSocket || godotSocket.readyState !== 1) {
      return resolve({
        error: {
          code: -1,
          message: "Godot Editor is not connected. Make sure Godot is running with the Godot MCP Pro plugin enabled.",
        },
      });
    }

    const id = nextRequestId++;
    const timer = setTimeout(() => {
      if (pendingRequests.has(id)) {
        pendingRequests.delete(id);
        resolve({
          error: {
            code: -32000,
            message: `Command '${method}' timed out after 30 seconds`,
          },
        });
      }
    }, 30000);

    pendingRequests.set(id, { resolve, reject, timer });

    const payload = JSON.stringify({
      jsonrpc: "2.0",
      id,
      method,
      params,
    });

    godotSocket.send(payload);
  });
}

// Initialize MCP Server
const server = new Server(
  {
    name: "godot-mcp-pro",
    version: "1.16.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Define MCP Tools
const TOOLS = [
  {
    name: "godot_command",
    description: "Run any Godot MCP Pro command by name with arbitrary parameters. Check skills.es.md for all 178 commands.",
    inputSchema: {
      type: "object",
      properties: {
        command: {
          type: "string",
          description: "The name of the Godot MCP command (e.g. get_project_info, create_scene, add_node, simulate_key, etc.)",
        },
        params: {
          type: "object",
          description: "Parameters object for the command",
          additionalProperties: true,
        },
      },
      required: ["command"],
    },
  },
  {
    name: "get_project_info",
    description: "Get general project information: project name, Godot version, viewport size, renderer, autoloads.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "get_filesystem_tree",
    description: "Scan the project filesystem. Filter by file patterns (e.g. *.tscn, *.gd).",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Path to scan, e.g. 'res://'" },
        filter: { type: "string", description: "Filter pattern, e.g. '*.gd' or '*.tscn'" },
        max_depth: { type: "integer", description: "Maximum recursion depth (default: 10)" },
      },
    },
  },
  {
    name: "get_scene_tree",
    description: "Get the node hierarchy of the currently open scene in the Godot Editor.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "read_script",
    description: "Read the source code of any GDScript file in the project.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Script path, e.g. 'res://scenes/player.gd'" },
      },
      required: ["path"],
    },
  },
  {
    name: "create_script",
    description: "Create a new GDScript file in the project.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Script path, e.g. 'res://scenes/enemy.gd'" },
        content: { type: "string", description: "GDScript source code content" },
      },
      required: ["path", "content"],
    },
  },
  {
    name: "edit_script",
    description: "Modify an existing script with full content replacement or target replacements.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Script path, e.g. 'res://scenes/player.gd'" },
        content: { type: "string", description: "New complete content (optional)" },
        replacements: {
          type: "array",
          description: "Array of { search, replace } objects for targeted edits",
          items: {
            type: "object",
            properties: {
              search: { type: "string" },
              replace: { type: "string" },
            },
            required: ["search", "replace"],
          },
        },
      },
      required: ["path"],
    },
  },
  {
    name: "create_scene",
    description: "Create a new .tscn scene file with the specified root node type.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Path for the new scene, e.g. 'res://scenes/enemy.tscn'" },
        root_type: { type: "string", description: "Root node type, e.g. 'CharacterBody2D', 'Area2D', 'Node2D'" },
      },
      required: ["path", "root_type"],
    },
  },
  {
    name: "add_node",
    description: "Add a new node to the active scene in the Godot Editor.",
    inputSchema: {
      type: "object",
      properties: {
        scene_path: { type: "string", description: "Scene path (optional, defaults to current scene)" },
        parent_path: { type: "string", description: "Parent node path, e.g. '.' for root" },
        type: { type: "string", description: "Node type, e.g. 'Sprite2D', 'CollisionShape2D', 'AudioStreamPlayer'" },
        name: { type: "string", description: "Name for the new node" },
        properties: { type: "object", description: "Initial properties to set on the node", additionalProperties: true },
      },
      required: ["type", "name"],
    },
  },
  {
    name: "save_scene",
    description: "Save the current scene or specified scene to disk in Godot.",
    inputSchema: {
      type: "object",
      properties: {
        scene_path: { type: "string", description: "Scene path to save (optional, defaults to current scene)" },
      },
    },
  },
  {
    name: "play_scene",
    description: "Launch the game from the Godot editor for playtesting.",
    inputSchema: {
      type: "object",
      properties: {
        mode: { type: "string", description: "'main' (run project F5), 'current' (run current scene F6), or scene path" },
      },
    },
  },
  {
    name: "stop_scene",
    description: "Stop the running game session in Godot.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "get_game_screenshot",
    description: "Capture a screenshot of the running game window.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "simulate_key",
    description: "Simulate a keyboard key press in the running game (e.g. Left, Right, Space, W, A, S, D).",
    inputSchema: {
      type: "object",
      properties: {
        key: { type: "string", description: "Key name, e.g. 'Left', 'Right', 'Space', 'A', 'D'" },
        duration: { type: "number", description: "Duration in seconds (e.g. 0.3 to 0.5)" },
      },
      required: ["key"],
    },
  },
  {
    name: "simulate_action",
    description: "Simulate an InputMap action in the running game (e.g. ui_left, ui_right, move_left).",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", description: "Action name, e.g. 'ui_left', 'ui_right'" },
        duration: { type: "number", description: "Duration in seconds (e.g. 0.3 to 0.5)" },
      },
      required: ["action"],
    },
  },
  {
    name: "get_editor_errors",
    description: "Retrieve recent editor errors, script errors, and runtime exceptions from Godot.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
];

// Handle ListTools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

// Handle CallTool
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  let godotMethod = name;
  let godotParams = args || {};

  if (name === "godot_command") {
    godotMethod = args.command;
    godotParams = args.params || {};
  }

  const response = await sendToGodot(godotMethod, godotParams);

  if (response.error) {
    return {
      isError: true,
      content: [
        {
          type: "text",
          text: `Error from Godot [${response.error.code}]: ${response.error.message}`,
        },
      ],
    };
  }

  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(response.result !== undefined ? response.result : response, null, 2),
      },
    ],
  };
});

// Start MCP Server on stdio
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[Godot-MCP] MCP Server initialized on stdio");
}

main().catch((err) => {
  console.error("[Godot-MCP] Fatal error:", err);
  process.exit(1);
});
