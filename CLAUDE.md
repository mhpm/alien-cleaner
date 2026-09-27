# Alien Cleaner — Godot 4.7

Juego en Godot 4.7.2 (Forward+, Jolt Physics, stretch `canvas_items`/`expand`). Escena principal actual: `res://scenes/main.tscn` (Node2D vacío). Carpetas: `scenes/`, `scripts/`, `assets/`.

## Cómo trabajar: Godot MCP Pro

El editor se controla con el servidor MCP `godot-mcp-pro` (`.mcp.json` → `addons/godot_mcp/server/index.js`). Cada comando del plugin es una herramienta `mcp__godot-mcp-pro__<comando>` con los parámetros reales generados del código del plugin.

- Referencia exacta de comandos y parámetros: @docs/godot-mcp-commands.md
- Guía de flujos, formatos y trampas: `docs/godot-mcp-skills.es.md` (leer cuando se necesite un flujo concreto: 3D, animación, tilemap, audio, tests).

Requisitos: Godot abierto con este proyecto y el plugin **Godot MCP Pro** activado (Proyecto → Configuración → Plugins). Si una herramienta responde "Godot editor is not connected", revisar que no haya procesos `node ...godot_mcp/server/index.js` de otros proyectos ocupando los puertos 6505‑6514.

### Reglas
- Empezar con `get_project_info` / `get_scene_tree` antes de cambiar nada.
- **No editar `project.godot` a mano** mientras el editor está abierto: usar `set_project_setting`, `set_input_action`, `add_autoload`, `set_physics_layers`.
- Escenas: preferir herramientas MCP (`create_scene`, `open_scene`, `add_node`, `add_resource`, `update_property`, `save_scene`) en vez de escribir `.tscn` a mano. `add_node` actúa sobre la escena **abierta**; usar `open_scene` primero.
- Scripts: `create_script` / `edit_script` (o Write/Edit de archivos `.gd`), luego `validate_script`; tras cambios grandes, `reload_project`.
- Valores de propiedades como strings parseables: `"Vector2(100, 200)"`, `"Color(1,0,0,1)"`, `"#ff0000"`, `"true"`, `"42"`; enums como enteros.
- GDScript tipado estático (`:=`, tipos explícitos); en `for` sobre arrays sin tipo, indexar y tipar el elemento.
- Guardar con `save_scene` después de cada cambio significativo.

### Ciclo de prueba
1. `play_scene` (mode `main` o `current`)
2. `get_game_screenshot` / `capture_frames` (devuelven imágenes)
3. `simulate_action` (preferido) o `simulate_key` con `duration` 0.3–0.5 s; `simulate_mouse_click` para UI
4. `get_game_node_properties`, `get_game_scene_tree`, `execute_game_script` para inspeccionar
5. `get_editor_errors` / `get_output_log`
6. `stop_scene`, corregir y repetir

### Convenciones del proyecto
- Escenas en `res://scenes/`, scripts en `res://scripts/` (mismo nombre que la escena en snake_case), assets en `res://assets/`.
- Definir acciones de entrada (`move_left`, `move_right`, `move_up`, `move_down`, `shoot`, …) con `set_input_action` antes de escribir la lógica del jugador.
- Nombrar capas de física con `set_physics_layers` (player, enemy, world, pickup…).
