# Alien Cleanup Crew — Godot 4.7

Roguelite de habitaciones para móvil en vertical (360×640, stretch `canvas_items`/`expand`, filtro nearest). Godot 4.7.2 (Forward+). Escena principal: `res://scenes/main_menu.tscn` → `res://scenes/game.tscn`.

## Arquitectura
- **Personajes** (astronauta, aliens verde/rosa/azul, balas, impactos, polvo, splats): recortados de la hoja de referencia `tools/reference_sheet.webp` con `python tools/slice_sprites.py tools/reference_sheet.webp` → `assets/sprites/<set>/<anim>_<i>.png` + `manifest.json` (lienzo simétrico anclado en los pies; `flip_h` seguro). Para cambiar/añadir frames editar los rangos `(fila, x0, x1)` del script y volver a ejecutarlo. `Art.make_anim(set, escala)` crea el `AnimatedSprite2D` (filtro linear); `AnimFx.spawn` para efectos de un solo uso.
- **Menú principal**: arte `tools/main_menu_ref.webp` → `python tools/make_menu_assets.py` genera `assets/ui/menu_bg.webp` (sin monedas/récord, que se dibujan en vivo) y los botones recortados `assets/ui/btn_*.png`; sus rectángulos están duplicados en `BUTTONS` de `scripts/main_menu.gd`.
- **Pantalla CHARACTER** (`scenes/character.tscn`, `scripts/character_screen.gd`): arte `tools/character_ref.webp` → `python tools/make_character_assets.py` genera `assets/ui/character/` (fondo sin valores, íconos sin fondo, variantes recoloreadas de cada pieza). Datos del equipamiento en `scripts/data/gear_data.gd` (6 ranuras × 8 variantes, precios, stats por nivel, perks, bonus de set); estado/guardado y aplicación a la run en `Game` (`gear_owned`, `gear_equipped`, `_apply_gear`).
- **Trajes por partes**: `tools/suits_ref.webp` (8 trajes) → `python tools/make_suit_parts.py` corta cada traje en 6 capas (`backpack, legs, armor, arms, helmet, weapon`) sobre un lienzo común 300×380 → `assets/suits/<variante>_<ranura>.png`, y genera los íconos `assets/ui/character/item_<ranura>_<variante>.png`. `SuitRig` (`scripts/suit_rig.gd`) apila las capas según `Game.gear_equipped`; lo usan el `Player` (arma aparte para apuntar, pivote `GUN_PIVOT`/`GUN_TIP`) y la vista previa de CHARACTER. Orden de trajes en la hoja: standard, recon, heavy, exploration(Medic), hazard, stealth, titan(Crystal), final(Legend).
- **Entorno, UI y sonido se generan en código**: `Art` (tiles, cajas, barriles, corona, iconos pixel, paleta Sweetie‑16) y `Sfx` (sintetizador chiptune + loop de música).
- `Game` (autoload): stats de la run, mejoras, monedas, guardado (`user://save.cfg`) y mejoras permanentes.
- **Arma**: el bláster es un sprite separado (`Art` "blaster") que rota hacia el objetivo; las balas salen de su cañón en la misma dirección. Niveles del arma en `scripts/data/weapon_data.gd` (shot1…shot5 de la hoja); suben con la mejora "Blaster Upgrade" o el pickup Power Core (`Game.weapon_up()`).
- **Datos** (añadir contenido aquí sin tocar el núcleo): `scripts/data/enemy_data.gd` (aliens; jefes con `script` propio), `upgrade_data.gd` (mejoras: `roll` + `apply`), `world_data.gd` (Mundo → Rooms → Waves; layouts ASCII 9×15: `. v # T B t z`).
- `game.gd` (`GameWorld`): flujo intro → fight → gap → cleared → upgrade → exit; helpers de game feel (`shake`, `hitstop`, `burst`, `ring`, `popup_*`, `explosion`, `chain_lightning`).
- Entidades se construyen en código (`Player`, `Enemy`, `Bullet`, `EnemyShot`, `Pickup`, `Barrel`); `game.tscn` solo tiene Room/Decals/Entities(y‑sort)/Effects/Camera2D(zoom 2)/HUD.
- **Salas y HUD**: arte `tools/room_ref.webp` → `python tools/make_room_assets.py` genera `assets/room/room_bg.webp` (marco de paredes/puerta + suelo reconstruido), `prop_*.png` (cajas, barril, lata, cristales, rejillas, manchas de slime) y `hud_*.png` (paneles, pausa, joystick, botón BLAST). `Room` dibuja el marco con `ART_ORIGIN`/`ART_SCALE` y coloca los props según el layout.
- Unidades del mundo: 1 tile = 16, cámara zoom 2 centrada en el arte de la sala. Interior = `Rect2(0, 0, 160, 224)` (rejilla 10×14), puerta arriba en x 64–96.

## Trampas conocidas
- Tras `add_autoload`, el analizador del editor (y `validate_script`) no reconoce `Art`/`Sfx`/`Game` hasta reiniciar el editor; el juego sí funciona. Para comprobar errores reales: ejecutar el juego (o `--headless --path . res://scenes/game.tscn --quit-after 300`). `--script` headless no carga autoloads.
- En Godot 4 usar `set_anchors_and_offsets_preset` (no `set_anchors_preset`) al crear Controls por código.
- `create_scene` no cambia la escena editada: llamar `open_scene` antes de `add_node`/`attach_script`.

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
