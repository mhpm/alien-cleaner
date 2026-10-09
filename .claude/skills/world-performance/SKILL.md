---
name: world-performance
description: Estándar de rendimiento obligatorio de Alien Cleanup Crew para hordas grandes. Úsalo SIEMPRE que crees o cambies un mundo, un mapa/arena, un enemigo, un jefe, un proyectil o un efecto (dibujo, colisiones, luces, generación de mapas), y antes de dar el trabajo por terminado. Incluye las técnicas que hay que aplicar, lo que está prohibido y las pruebas/mediciones que hay que pasar.
---

# Rendimiento con hordas (obligatorio en cada mundo)

El objetivo del usuario: muchísimos aliens en pantalla en móvil sin tirones. Todo lo nuevo
debe rendir igual o mejor que lo que ya hay. Sigue las 3 partes: **técnicas** al escribir,
**prohibido**, y **verificación** antes de terminar (con números en la respuesta).

## 1. Técnicas que hay que usar

### Dibujo
- Lo que se redibuja cada frame: **`FastDraw`** (`scripts/fx/fast_draw.gd`: `disc`, `ring`,
  `arc`, `polyline`). En Godot 4.7 `draw_circle`/`draw_arc`/`draw_polyline` cuestan
  40-70 µs por llamada; `draw_rect`/`draw_line`/`draw_texture_rect` ~2 µs.
- Escenario estático (suelo, muros, decoración pintada): dibujarlo **una vez** en `_draw`
  (sin `queue_redraw` por frame) y **partido en trozos** (`Node2D` por bloque del mapa,
  p. ej. `ForgeMap.CHUNK` 6×5 celdas) para que Godot descarte lo que está fuera de pantalla.
  Capas en orden: suelo → brillos → muros → decoración alta; un elemento que sobresale al
  trozo vecino va en una capa posterior, no en el trozo del suelo.
- **Un atlas por kit** (`draw_texture_rect_region` del mismo `Texture2D`) = lotes. Al cargar:
  `get_image()` → `decompress()` → `generate_mipmaps()` → `ImageTexture` (ver
  `ForgeMap._mip`, `RoomKit.tex`); filtro `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. En el atlas,
  piezas con borde extruido (`PAD`) para que los mipmaps no sangren.
- Brillos/luces de ambiente: un solo nodo con `CanvasItemMaterial` aditivo y texturas de
  degradado (`ForgeMap.Glows`), **no** `PointLight2D` por cada brillo.
- `PointLight2D`: pocas (≤ ~18 por mapa). Si el mapa tiene muchas áreas, una por área como
  mucho (`DarkLights.alarms_only`).
- Material de destello solo mientras parpadea (los sprites sin material se agrupan).
- `HazardArea` y zonas animadas: limita detalles (`MAX_DETAILS`) y redibuja solo cerca de la
  cámara. Flechas fuera de pantalla: `MAX_ARROWS`.

### Física y consultas
- Aliens cercanos: **`Game.world.enemies_near(pos, r)`** (rejilla espacial) y comprobar la
  distancia exacta; o `enemy_cache`. Nunca `get_nodes_in_group("enemies")` en
  `_process`/`_physics_process`/`_draw`.
- Colisiones del mapa: **rectángulos fusionados** (tramos de muro seguidos = un rect;
  celdas sólidas fusionadas por filas; ver `ForgeMap.solids()`, ~80 rects para un mapa
  18×14). Un solo `StaticBody2D` con sus `CollisionShape2D`. Los mismos rects van a
  `Room.blockers` (lo recorre `is_open` en cada aparición: pocos y grandes).
- Bordes del mapa que no se pisan (márgenes, vacíos, fosas) también en `blockers`, o los
  aliens aparecen ahí y se quedan atrapados.
- Movimiento de aliens: deja que `Enemy` lo haga (LOD, `crowd_every`, `_glide`, camino
  rápido sin `move_and_slide` lejos de muros = `GameWorld.near_solid`). Los enemigos normales
  no llaman `move_and_slide` por su cuenta.
- Mapas con muros/laberintos: los aliens deben poder **rodearlos** sin pathfinding por
  alien: campo de flujo por celdas (BFS desde la celda del jugador, se recalcula solo al
  cambiar de celda: `Explore.flow_dir`, `ForgeMap.flow`) + `Enemy._detour` (solo tras chocar
  con un muro). Si haces otro tipo de mapa con muros, dale su `flow_dir` o reutiliza este.
- Topes: invocaciones, proyectiles persistentes y minas con máximo (`MAX_*`), aliens vivos
  bajo `ArenaValidator.ALIVE_WARN` 300 en el peor momento; `MAX_SHOOTERS`.
- Generación procedural: en `setup`, una vez (objetivo < 200 ms), sin bucles por frame.

### Carga sin tirones
- La primera vez que sale un tipo de alien se cargan sus PNG: tirón de 100-600 ms. Por eso
  `Survival.setup` llama `Art.warm(Art.sets_for(alien_ids()))` (carga en hilos todos los
  sets del mundo: arte del alien y sus sets `<art>_*`). Un alien nuevo cuyos sprites se
  llamen distinto (proyectiles con otro prefijo) debe añadirse a `Art.sets_for` o se carga
  en caliente. Lo mismo para arenas/modos que no pasen por `Survival`: llama `Art.warm`.
- Texturas grandes generadas en código (atlas, mipmaps): en `setup`, nunca a mitad de pelea.

### Posiciones de aparición
- Toda posición donde se crea o teletransporta un alien pasa por `room.open_near` /
  `room.is_open` (también los respaldos "si no encontré sitio": antes `_edge_pos` devolvía una
  posición sin comprobar y los aliens acababan dentro del muro exterior).

## 2. Prohibido
- `draw_circle` / `draw_arc` / `draw_polyline` en código de juego que se redibuja (fuera de
  menús y del editor). `perf_lint` lo detecta.
- `get_nodes_in_group("enemies")` en bucles por frame.
- Recorrer todos los aliens desde cada bala/efecto.
- Un nodo/sprite por baldosa del suelo, o `TileMapLayer` gigantes redibujados a mano.
- Cientos de rects de colisión diminutos (fusiona).
- `set_physics_process(false)` antes de `add_child` (entrar al árbol lo reactiva).
- `await RenderingServer.frame_post_draw` en pruebas headless (se cuelga: las capturas solo
  en ventana).

## 3. Verificación antes de terminar (pon los números en la respuesta)
Godot: `C:/Users/miche/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`
(o `mcp__godot-mcp-pro__get_godot_executable`). Tras añadir PNG nuevos: `--headless --path . --import`.

1. `--headless --path . res://tests/perf_lint.tscn` → `PERF_LINT: PASS`.
2. `--headless --path . res://tests/arenas_check.tscn` → `ARENAS_CHECK: PASS` (arenas del editor).
3. Banco de hordas en ventana, comparando con un mundo de referencia en la misma ejecución
   (los números bailan con la carga del equipo):
   - `--path . res://tests/forge_perf_bench.tscn -- --world=<nuevo>,<referencia>`
     (0/150/300/500 aliens; `--slimes` aísla el coste del mapa).
   - `... -- --world=<nuevo>,<referencia> --real` = última oleada real: el mundo nuevo no debe
     ir claramente peor que la referencia (hoy ~9-11 ms/frame sin límite de fps).
   - Mapa vacío (n=0) ≈ 3-4 ms; si es mucho más, el escenario dibuja demasiado.
   - Arenas del editor: `res://tests/arena_perf_bench.tscn`.
4. Prueba del mundo (p. ej. `tests/forge_test.tscn`) con: todo alcanzable desde el inicio,
   el jugador empieza en suelo libre, **ningún alien dentro de un muro** tras una horda
   (`room.is_open(pos, -4)`), capturas en ventana (`user://*.png`) miradas con `Read`.
5. En el banco `--real` mira las líneas `BENCH spike`: un pico al aparecer un tipo nuevo =
   falta precarga; picos repetidos con los mismos vivos = algo caro por frame (mide).
6. Si algo empeora: mide aislando (`--slimes`, `--nodetour`, quitar un tipo de alien) antes
   de tocar nada, y explica la causa al usuario.

Al terminar, documenta en `CLAUDE.md` (sección del mundo y "Rendimiento") lo nuevo que afecte
al rendimiento.
