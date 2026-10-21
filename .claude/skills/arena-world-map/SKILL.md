---
name: arena-world-map
description: Convierte el mapa de un mundo de Alien Cleanup Crew (1-15) en una escena del Arena Editor que el usuario edita a mano en Godot, y la conecta al mundo (WorldData "explore" - {"map" - ...}), como se hizo con el mundo 8 BIODOME. Úsalo cuando el usuario diga "convierte/pasa el nivel N al editor de arenas", "haz el escenario del mundo N con el arena builder", "ahora sigue el mundo N", o mande un kit de muros/objetos para el mapa de un mundo. Regla del usuario desde el 2026-10-20 - TODO escenario se hace así, nunca generado en código al jugar.
---

# Mapa de un mundo como escena del Arena Editor

Plantilla viva (cópiala): mundo 8 BIODOME =
`tools/make_biodome_kit.py` (kit) + `tools/build_biodome_arena.gd/.tscn` (constructor, subclase
de `tools/arena_map_builder.gd`) → `scenes/arenas/arena_world_08_level_01.tscn`, jugado por
`Explore._setup_map` (`"explore": {"map": ...}` en `world_data.gd`), prueba
`tests/biodome_test.gd`. Carga también `arena-decor-kit` (cortar el arte) y
`world-performance` (verificación). Avisa al usuario de vez en cuando en qué paso vas.

## Reglas del usuario (no negociables)
- La escena es SUYA en cuanto existe: el constructor se niega a sobrescribirla (`-- --force`
  solo si NO la ha guardado desde el editor: compara la hora del `.tscn` con tu última
  construcción y `git status`). Después, solo cambios dirigidos: edita líneas del `.tscn`
  con Python (p. ej. `tools/apply_kit_solids.py`); nunca la vuelvas a guardar con
  `PackedScene.pack` (pierde los UID que puso el editor). Copia de seguridad antes.
- **Pasillos amplios pero que siga siendo laberinto**, no cuartos grandes (memoria
  `wide-corridors`): ~75-105 unidades libres entre colisiones. Se ensancha repitiendo
  MÓDULOS de muro (`mods_x`/`mods_y`), nunca con menos celdas ni estirando el arte.
- **No estirar ni rebanar el arte** del usuario: se ve mal. A lo sumo reescalar el centro
  de un tramo unos px para igualar largos (`stretch_run`).
- Usar todas las piezas que mande; las viejas que ya no se usan se borran (y su caché
  `.godot/imported/<archivo>-<md5 de la ruta res://>.ctex/.md5`, o la paleta las sigue
  mostrando hasta reiniciar).
- Todo editable (memoria `arena-editor-everything-editable`): objetivos, cofres,
  supervivientes, inicio, bloqueos = objetos del editor, no código.
- Carpeta del nivel con su nombre en `assets/decor/<mundo>/` y un `README.txt`: el usuario
  añade PNG ahí y salen solos en la paleta.

## 0. Inventario del mundo
Mira su entrada en `scripts/data/world_data.gd` (`"explore"` / `"art"`) y `CLAUDE.md`:
| mundos | mapa actual | cómo pasarlo |
|---|---|---|
| 1-3 | salas pintadas por piezas (`LabRoomData`, sets lab/w2/w3, ZONE ZERO, `RoomKit` w3) | cada sala = `ArenaScenery` planas (`flat`) con su base y sus 4 esquinas de `assets/rooms/<set>/` + `ArenaBlocker` por cada rect sólido de `lab.json`/`pieces.json`; mejor si el usuario manda kit modular → como el 8 |
| 4 | arena pintada `space` (un solo dibujo + `SpaceBackdrop`) | el dibujo como `ArenaScenery` plana grande + `ArenaBlocker` en los bordes de la plataforma (o kit nuevo) |
| 5-6 | `ForgeMap` con kit de atlas (`assets/rooms/w5..w7/build/`: postes, tapas, tramos con adorno, fustes, esquinas) | constructor como el 8; si no hay kit nuevo, corta el atlas a piezas (ver `arena-decor-kit` § atlas ForgeMap) |
| 7 | hecho (`build_warp_arena.gd`, kit `warp_nexus`) | — |
| 8 | hecho (`build_biodome_arena.gd`, kit `biodome`) | — |
| 9-15 | sin construir (`WorldData.UPCOMING`) | skill `new-world` + este flujo para el mapa |
Objetivo propio del mundo y su objeto del editor:
| mundo | objetivo | componente (paleta Gameplay) |
|---|---|---|
| 5 | núcleos que enfriar | `ArenaReactorCore` (`reactor_core.tscn`) |
| 6 | cápsulas que romper + huevos | `ArenaAnchoredAlien` kind SPECIMEN_VAT / EGG_CLUSTER |
| 7 | celdas warp | `ArenaWarpCell` (lejos del inicio, en callejones) |
| 8 | tanques que defender | `ArenaSeedTank` |
| 1-4 | cofres + supervivientes (+ ZONE ZERO en el 1) | `ArenaChest` (`random_kind`), `ArenaSurvivor` |
Objetivo nuevo: componente `scripts/arena/components/arena_<x>.gd` que en `activate` crea el
objeto de juego, su pie sólido con `ArenaObjectiveBody.make(foot)` y llama a
`w.explore.add_<x>(obj)` (añádelo en `explore.gd` junto a `add_tank`: lista + `props` si el
ring del jefe debe quitarlo/ocultarlo + `_refresh_counter`), escena en
`scenes/arena/palette/gameplay/`, y amplía `tests/map_objectives_test.gd`.
Luces: `"dark"`/`"alarms"` de `DarkLights` necesitan `Explore.rooms`; en modo mapa no hay
salas: si el mundo las tenía, añade luces como objetos o díselo al usuario.

## 1. Kit → skill `arena-decor-kit`
`python tools/make_<mundo>_kit.py` → `assets/decor/<mundo>/<carpeta>/*.png` + `kit.json` +
suelo como terreno (`terrain.json`, id libre = `kit_cut.free_terrain_id()`).
Tras PNG nuevos: `Godot --headless --path . --import` (registra también clases nuevas).

## 2. Constructor `tools/build_<mundo>_arena.gd` (copia `build_biodome_arena.gd`)
`extends "res://tools/arena_map_builder.gd"`; solo:
- `_configure()`: `path` = `res://scenes/arenas/arena_world_NN_level_01.tscn`, `tag`,
  `kit_dir`, `layout` (config de `ForgeMap.generate`: `set` = el del mundo para sus
  esquinas/`LOOKS`, `maze`, `mazes`, número de objetivos con la clave que suma
  `_pick_cores`: `cores`/`vats`/`tanks`), `cells` (18×14 = densidad de laberinto buena),
  `seed_value`, `mod_w`/`mod_h` (lo que mide UN módulo del arte: tramo entre postes /
  columna), `mods_x`/`mods_y` (módulos por lado de celda: el 8 usa 1×2), `floor_*`, y las
  listas por papel: `runs`/`columns` (+ pesos), `corner_big`, `along_wall`, `pots`,
  `centrepieces`, `islands`, `floor_bits`, `lamps` (vacía = no se pone).
- `_data()`: `super._data()` + id `wNN_a01`, nombre, `world_id`, entorno. `waves_enabled`
  false y `boss_id` "" (el jefe y las oleadas siguen en WorldData; si no, el validador da
  error).
- `_objective(n, at)`: el componente del objetivo para el área n (o null); `_extra()` para
  lo que no encaje (huevos repartidos, celdas en callejones: usa `fm.distances`).
`tools/build_<mundo>_arena.tscn` = Node con el script. Ejecutar:
`Godot --headless --path . res://tools/build_<mundo>_arena.tscn` (`-- --out=user://x.tscn`
para probar sin tocar la escena; `-- --seed=N` para otro trazado; es determinista).

## 3. Conectar el mundo
En `world_data.gd`: `"explore": {"map": "res://scenes/arenas/arena_world_NN_level_01.tscn"}`
(las demás claves de explore sobran: cofres/supervivientes/objetivos salen de la escena).
Comentario del mundo actualizado. Nada más: `Explore._setup_map` hace el resto (límites,
`PlayerSpawn`, `ArenaDirector.start_map()`, contadores, `WalkMask` con camino de flujo,
`_clear_map_ring` en la pelea final).

## 4. Prueba (adapta la del mundo; plantilla `tests/biodome_test.gd`)
- `ex.arena != null and ex.forge == null`, nº de objetivos/cofres/supervivientes, más de N
  `ArenaScenery`, `w.room.walk_mask.reachable` grande, inicio libre, cada objetivo y cofre
  sobre suelo alcanzable, `_flows_home` (un alien lejos llega rodeando muros).
- Fija `Game.gun = "pulse"` antes de `new_run`: el guardado del usuario puede tener TESLA
  (aturde y "atasca" a los aliens en la prueba).
- Coloca aliens de prueba con vista despejada (`_in_sight`: `is_open(q, 14)` + rayo sin
  sólidos) y en la sala de inicio: con muros cerca las comprobaciones de ataque fallan al
  azar. Repite la prueba 2-3 veces: si falla una de tres, es la prueba.
- En ventana con `-- --overview`: mira `user://<mundo>_test_map.png` y `_start.png` con
  `Read` (rutas en `%APPDATA%/Godot/app_userdata/Alien Cleanup Crew/`; comprueba la hora:
  las capturas viejas se quedan).
- También: `tests/arenas_check.tscn`, `perf_lint.tscn`, `boss_ring_test.tscn` (todos los
  mundos), `walk_mask_test.tscn`, `map_objectives_test.tscn`, `arena_editor_test.tscn`
  (inestable aquí: si falla, repítela dos veces).

## 5. Cerrar
- `CLAUDE.md`: párrafo del mundo (escena, constructor, kit y carpetas, rejilla y pasillos,
  objetivo) — junto a "Mapas de mundos hechos con el Arena Editor".
- Al usuario: qué hay en la escena, dónde están las piezas en la paleta, cómo añadir más
  (soltar PNG en la carpeta + ↻), que reinicie el editor (terreno y clases nuevas) y que si
  tenía la escena abierta la recargue sin guardar.

## Dos estilos de muro modular (mira la hoja antes de medir)
- **Poste compartido** (mundo 8): los tramos de dos celdas vecinas se solapan en el poste
  del nodo → `mod_w = (largo - POST) * K`, dos columnas apiladas por celda (`mods_y` 2).
- **Poste con poste** (mundo 7): cada tramo trae su poste en cada extremo y se pegan uno
  junto a otro (en la hoja, las piezas "dobles" son dos tramos pegados: `split_at_gap`)
  → `mod_w = largo * K` = un lado de celda; columna de nodo a nodo (`stretch_column` si
  hay que igualar unos px).
- Elige como módulo el largo que más se repite; los demás largos no se deforman: van a
  `barriers/` como cobertura suelta en las salas grandes (`islands`).
- Decoración extra: `along_side` (junto a los muros laterales), `_extra()` para lo propio
  del mundo (rocas en `fm.pit`, una pieza central única como la puerta warp en la sala
  más grande, que se reserva en `busy` antes de `super._corners()`).
- Objetivos que no van en el centro de un área (celdas warp): colócalos en `_gameplay()`
  tras `super._gameplay()`, ANTES de decorar, para que la decoración los respete.
- Prueba del jefe: espera a que acabe un movimiento (p. ej. `not b.warping`) en vez de un
  número fijo de fotogramas: con salas más grandes los saltos duran más.

## Trampas que ya costaron horas
- Colisión 3/4: el jugador choca con un círculo de 5.5 en los pies pero se dibuja ~22 de
  ancho → columnas `SIDE_PAD` 12 más anchas que su dibujo, tramos sólidos el 80% de abajo
  (`kit_cut.RUN_SOLID`). Si cambias la colisión de un kit ya colocado:
  `python tools/apply_kit_solids.py <escena> <kit> [carpeta/]`.
- `WalkMask` va por celdas de 32: un punto de una celda libre puede caer dentro de una
  columna → `Room.is_open` ya pregunta a la física en mapas con máscara.
- Piezas altas con `fade` que el ring del jefe borra: `ArenaSceneryFader` ya lo aguanta;
  cualquier lista que guarde nodos del mapa debe recorrerse sin tipo e `is_instance_valid`.
- Clases nuevas (`class_name`) no existen en headless hasta `--import`.
- `Array.shuffle()` usa el azar global: el constructor llama `seed(seed_value)`.
- El constructor añade los muros como hijos de `Obstacles` (y-sort): columnas primero y
  tramos después, para que los tramos tapen los extremos de columna con el mismo pie.
