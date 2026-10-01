# Cómo arrancar y usar el MCP de Godot (Godot MCP Pro)

Guía para un agente nuevo. Sigue los pasos **en orden**.

## Cómo funciona (30 segundos)

```
Agente (Claude Code)
   │  stdio (MCP)
   ▼
Servidor Node  (addons/godot_mcp/server/index.js)   ← lo lanza Claude Code solo, vía .mcp.json
   │  WebSocket en 127.0.0.1:6505-6514
   ▼
Plugin "Godot MCP Pro" dentro del editor de Godot 4.7  ← debe estar abierto con ESTE proyecto
```

Si Godot no está abierto con el plugin activo, **todas** las herramientas responden
`Godot editor is not connected`.

## Requisitos

| Qué | Versión / detalle |
|---|---|
| Godot | 4.7.x (el proyecto usa Forward+) |
| Node.js | v18+ (aquí v26.7.0). Comprobar: `node --version` |
| Proyecto | `C:\Users\miche\Documents\alien-cleaner` |
| Plugin | `addons/godot_mcp/` (ya está en el repo y activado en `project.godot`) |

## Paso a paso

### 1. Dependencias del servidor Node (solo la primera vez)

`addons/godot_mcp/server/node_modules` ya existe. Si faltara:

```bash
cd addons/godot_mcp/server
npm install
```

### 2. Abrir el proyecto en Godot

Abre Godot 4.7 → importa/abre `C:\Users\miche\Documents\alien-cleaner\project.godot`.
**Deja el editor abierto** mientras uses el MCP.

### 3. Comprobar que el plugin está activado

Proyecto → Configuración del proyecto → pestaña **Plugins** → **Godot MCP Pro** = ✅ *Enabled*.
(En `project.godot` ya aparece `enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")`.)

Si no estaba activo: actívalo y, si hace falta, reinicia el editor.

### 4. Verificar `.mcp.json` (en la raíz del proyecto)

Ya está configurado así (no tocar salvo que cambie la ruta del proyecto):

```json
{
  "mcpServers": {
    "godot-mcp-pro": {
      "command": "node",
      "args": ["C:/Users/miche/Documents/alien-cleaner/addons/godot_mcp/server/index.js"],
      "env": { "GODOT_MCP_PORT": "6505" }
    }
  }
}
```

> Si el proyecto se mueve de carpeta, hay que actualizar la ruta absoluta de `args`.

### 5. Abrir Claude Code en la carpeta del proyecto

```bash
cd C:\Users\miche\Documents\alien-cleaner
claude
```

La primera vez Claude Code pregunta si confías en el servidor `godot-mcp-pro` → **aprobar**.
Las herramientas aparecen como `mcp__godot-mcp-pro__<comando>`.

### 6. Probar la conexión

Pedir/ejecutar `get_project_info`. Si devuelve nombre y versión de Godot, todo funciona.

## Problemas típicos

### "Godot editor is not connected"
1. ¿Está Godot abierto **con este proyecto** y el plugin activo? (pasos 2-3)
2. Puede haber **procesos Node viejos de otros proyectos** ocupando los puertos 6505-6514.
   Ver quién los usa:
   ```powershell
   netstat -ano | findstr "6505 6506 6507 6508"
   Get-Process node | Select-Object Id, StartTime, Path
   ```
   Cerrar los `node ... godot_mcp/server/index.js` que pertenezcan a **otros** proyectos
   (`Stop-Process -Id <PID>`), luego reiniciar el editor de Godot (o desactivar/activar el plugin)
   y reiniciar Claude Code.
3. Tras cambios en el plugin: `reload_plugin` o reiniciar el editor.

### `validate_script` marca error con `Art`, `Sfx` o `Game`
Falso positivo: los autoloads nuevos no se reconocen hasta reiniciar el editor.
Verifica ejecutando el juego, o por consola:

```bash
godot --headless --path . res://scenes/game.tscn --quit-after 300
```

(`--script` headless **no** carga autoloads.)

### Cambios en `project.godot`
**No editarlo a mano con el editor abierto.** Usar `set_project_setting`, `set_input_action`,
`add_autoload`, `set_physics_layers`.

## Cómo trabajar con él (resumen)

1. Empezar siempre con `get_project_info` y `get_scene_tree`.
2. Escenas: `open_scene` → `add_node` / `update_property` / `add_resource` → `save_scene`.
   (`create_scene` NO cambia la escena abierta: llamar `open_scene` después.)
3. Scripts: `create_script` / `edit_script` (o editar el `.gd`) → `validate_script`;
   tras cambios grandes, `reload_project`.
4. Valores como string parseable: `"Vector2(100, 200)"`, `"Color(1,0,0,1)"`, `"#ff0000"`, `"true"`, `"42"`.
5. En `create_node/add_node` en Godot 4 usar `set_anchors_and_offsets_preset` (no `set_anchors_preset`) al crear Controls por código.

### Ciclo de prueba
1. `play_scene` (`mode: main` o `current`)
2. `get_game_screenshot` / `capture_frames`
3. `simulate_action` (preferido) o `simulate_key` con `duration` 0.3–0.5 s; `simulate_mouse_click` para UI
4. `get_game_node_properties`, `get_game_scene_tree`, `execute_game_script`
5. `get_editor_errors` / `get_output_log`
6. `stop_scene`, corregir, repetir

## Más documentación (en este repo)

- [docs/godot-mcp-commands.md](godot-mcp-commands.md) — lista de **todos** los comandos y parámetros.
- [docs/godot-mcp-skills.es.md](godot-mcp-skills.es.md) — flujos concretos (3D, animación, tilemap, audio, tests) y trampas.
- [CLAUDE.md](../CLAUDE.md) — arquitectura del juego y reglas del proyecto.

## Checklist rápido

- [ ] Node instalado (`node --version`)
- [ ] Godot 4.7 abierto con este proyecto
- [ ] Plugin Godot MCP Pro activado
- [ ] Sin procesos `node` de otros proyectos en los puertos 6505-6514
- [ ] Claude Code abierto en la carpeta del proyecto y servidor aprobado
- [ ] `get_project_info` responde
