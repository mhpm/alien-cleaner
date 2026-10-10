---
name: new-world
description: Crea un MUNDO completo de Alien Cleanup Crew cuando el usuario manda el paquete de un mundo nuevo (kit de muros/suelo/esquinas, icono, enemigos y/o jefe). Orquesta en orden el mapa (kit-world-map), los enemigos y el jefe (new-enemy), el objetivo propio del mundo (map-objective), los datos de oleadas, el icono, la prueba y el rendimiento (world-performance). Úsalo con frases como "crea el mundo N", "aquí tienes los assets del nivel N".
---

# Mundo nuevo (de principio a fin)

Mundos hechos así y que sirven de plantilla: 5 THE FORGE, 6 GENE VAULT, 7 WARP NEXUS
(`scripts/data/world_data.gd`, `tests/warp_nexus_test.gd` es la prueba más completa).
Carga las skills que se citan en cada paso cuando llegues a él.

## 0. Inventario (antes de tocar nada)
- Guarda cada imagen en `tools/`: `w<N>_build_kit_ref.webp`, `w<N>_corners_ref.webp`,
  `world<N>_ref.webp` (icono), `enemies_w<N>_ref.webp`, `boss_<nombre>_ref.webp`.
- Mira qué aliens y jefes NO usa ningún mundo (script de una línea: ids de
  `EnemyData.TYPES` que no aparecen en `world_data.gd`). Reglas del usuario (memoria
  `world-design-rules`): ~3 aliens nuevos por mundo, quitar ~3 de los más repetidos del
  mundo anterior, jefes no usados, y un objetivo que no sea solo matar.
- Si faltan piezas (sin enemigos nuevos, sin jefe), dilo al terminar; no lo ocultes.
- Avisa al usuario de vez en cuando en qué paso vas: el trabajo es largo.

## 1. Mapa → skill `kit-world-map`
- Kit con la misma estructura que w5/w6/w7: solo una entrada en `SETS` de
  `tools/make_forge_walls.py` + `ForgeMap.LOOKS[set]`. Suelo: por defecto `floor_from` "w5"
  (baldosas lisas de un color; el usuario lo prefirió en el mundo 7) salvo que pida las suyas.

## 2. Enemigos y jefe → skill `new-enemy`
- Una sola hoja con varios enemigos: una entrada por enemigo en `cut_sheet_enemies.py`.
  Mide con una cuadrícula ampliada con etiquetas en px REALES (cuidado al recortar
  cuadrantes: x real = x0 del recorte + x/2). Hoja de contacto siempre.
- Proyectiles con nombre distinto del alien: `"sets": [...]` en su entrada de `EnemyData`
  (si no, `Art.warm` no los precarga y hay tirones).
- Jefe final: `extends BossBase`, `_size_to_player()` (sin argumento = pelea final 85 s),
  `_next()` → `_next_move(step)` para poder forzar cada movimiento desde la prueba.

## 3. Objetivo del mundo → skill `map-objective`
- Uno distinto por mundo (núcleos que enfriar, cápsulas que romper, celdas que recoger…),
  con contador en el HUD y una recompensa que cambie la pelea final.

## 4. Datos (`world_data.gd`)
- Pools `<TEMA>_START / _MID / <TEMA> / _SHOOTERS` arriba del archivo (copia los del mundo 7).
- Entrada en `WORLDS` copiando la del mundo anterior: `enemy_mult` +0.1, `t_offset` +30,
  `chest` +300, `pic`, `explore` con `build: kit`, `set`, `cells`, objetivo; 15 oleadas,
  invasiones en 5/10/15, mini jefes en 6 y 11, eventos con `label` propios del tema;
  `boss_help` con aliens del mundo.
- Música: `"music": "<archivo>"` en la entrada del mundo, eligiendo de `assets/music/levels/` (el usuario va añadiendo pistas; analiza duración/energía con ffmpeg + numpy si hace falta y no repitas la del mundo anterior).
- Icono: `WORLD_PICS` de `tools/make_world_select_assets.py` y ejecútalo.
- En builds debug todos los mundos ya salen desbloqueados (`Game.world_unlocked`).

## 5. Prueba `tests/<mundo>_test.tscn` (copia `warp_nexus_test.gd`)
- Mapa del kit correcto, inicio libre, objetivo colocado y funcionando, cada enemigo nuevo
  atacando (dales `max_hp = 1e6`: el autodisparo los mata antes de verlos), cada movimiento
  del jefe forzado con `_next_move`, fases (`hp` al 45% y 15%), muerte.
- Capturas en ventana (`--resolution 900x1600`, `-- --overview`); haz tiras con PIL y míralas
  con `Read`. Ejecuta también `tests/boss_ring_test.tscn` (recorre todos los mundos).
- Godot: `C:/Users/miche/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`;
  tras PNG nuevos `--headless --path . --import`.

## 6. Rendimiento → skill `world-performance`
- `perf_lint`, `arenas_check`, `forge_perf_bench -- --world=<N>,<N-1>` normal, `--real` y
  `--slimes` (dos pasadas: el ruido es grande). Pon los números en la respuesta.

## 7. Cerrar
- Párrafo del mundo en `CLAUDE.md` (junto a los otros mundos): arte y comandos, objetivo,
  aliens con su mecánica y constantes clave, jefe con sus ataques y fases, prueba.
- Respuesta al usuario: mapa, objetivo, cada enemigo y cada ataque del jefe con su
  contrajuego, números de rendimiento, qué no se probó (equilibrio, partida completa).
  Sin commit salvo que lo pida.
