---
name: map-objective
description: Añade a un mapa EXPLORE de Alien Cleanup Crew un objeto de mapa con arte del usuario - un objetivo del mundo (cosas que romper, recoger, activar, defender) o elementos repartidos por el mapa (huevos, nidos, trampas, decoración que reacciona). Cubre recorte de la hoja de cuadros, sprite, colocación con ForgeMap, contador en el HUD, recompensa, sombra, limpieza en el ring del jefe y prueba. Úsalo con "agrega estos X en varios lugares", "el objetivo del mundo será...", "usa este sprite para la cápsula/huevo...".
---

# Objeto u objetivo en el mapa

Ejemplos vivos (cópialos según el tipo):
| Tipo | Ejemplo | Archivo |
|---|---|---|
| Se rompe disparando, suelta aliens | cápsula `SpecimenVat` (mundo 6) | `scripts/enemies/specimen_vat.gd` |
| Repartido, reacciona al acercarte | huevos `EggCluster` (mundo 6) | `scripts/enemies/egg_cluster.gd` |
| Se activa quedándote encima | `ReactorCore` (mundo 5) | `scripts/combat/reactor_core.gd` |
| Se recoge al pisarlo | `WarpCell` (mundo 7) | `scripts/combat/warp_cell.gd` |
Colocación y contador: `scripts/explore.gd` (`_place_vat`, `_place_eggs`, `_place_warp_cells`,
`_refresh_counter`, `vault_purged`, `gate_charged`).

## 1. Arte (hoja de N cuadros en fila)
- Copia a `tools/<nombre>_ref.webp`. Las hojas del usuario traen a veces un fondo casi
  invisible (alfa 1-30): pon `a[a[..., 3] < 40] = 0` antes de recortar.
- Corta por columnas vacías (`columns()` de `tools/make_gene_vault_assets.py`, que reúne
  estos objetos; añade ahí la función del nuevo) → `assets/sprites/enemies/<id>/<anim>/`.
  Si un cuadro trae dos cosas (nido + cría), sepáralas por componentes conectados.
- Set en `tools/slice_sprites.py` con `anchor: "bottom"` (apoyado en el suelo) y regenera
  con `--only <id>`. Tamaño: un objetivo debe leerse bien (cápsula ~70 de alto, huevos ~35).

## 2. ¿Enemy o Node2D?
- Se le dispara (tiene vida): `extends Enemy` con `anchored = true` en `_init_ai`, y en
  `_ai` pon `_sep` y `knock` a cero. `anchored` hace que la correa, el barrido de la horda y
  el ring del jefe lo traten bien. Dato en `EnemyData` con `"internal": true`, `speed` 0,
  `kb` 0. Vida según tu daño si debe durar (`BossBase._player_dps()`, ver `SpecimenVat`).
- Sin vida (se pisa, se activa): `Node2D` en `world.entities` + `world.room.spawned`;
  comprueba la distancia al jugador cada ~0.08 s (no cada frame) y `DarkLights.glow(self)`.
- Aliens que suelta: siempre con los multiplicadores de la oleada
  (`survival._hp_mult()`, `_dmg_mult()`), aviso con `telegraph_circle` antes, y un tope de
  vivos propios (`MAX_OWN`). Precarga sus sprites con `Art.warm(Art.sets_for([...]))`.

## 3. Colocación (`Explore`)
- Objetivos en áreas amplias: suma su número a `_pick_cores` (como `vats`) y usa
  `forge.core_leaves`. Repartidos: celdas `forge.walkable` sin maquinaria, lejos del inicio
  y entre sí, `room.is_open(p, margen)`. Lejanos: `forge.distances(start_cell)`.
- Si es sólido, añade su rect a `walls` y a `props` (para que `clear_ring` lo quite).
- Clave nueva en `"explore"` del mundo (`"eggs": 14`, `"warp_cells": 5`…).

## 4. Contador y recompensa
- `_refresh_counter`: "<NOMBRE> n/m". Banner al avanzar y al completar, monedas, y un efecto
  en la pelea final (jefe con menos vida en `BossBase._size_to_player`, sin refuerzos en
  `Survival._boss_help`, sin un ataque en el `_next_move` del jefe…).

## 5. Detalles que el usuario ya pidió
- Sombra: la redonda de los aliens hace que lo que está en el suelo parezca flotar. Para
  objetos apoyados usa una propia pequeña y oscura (`EggCluster.SHADOW_*`).
- Colisión: solo la base de lo dibujado, nunca la caja entera (si no, "algo invisible
  bloquea").
- Al morir/romperse, que quede algo en el suelo (`add_splat` con la anim `splat`, o un
  `Sprite2D` en `world.decals`).
- Arrays tipados: `arr.assign(arr.filter(func(e: Variant) -> bool: ...))`; asignar el
  resultado de `filter()` directo a `Array[Enemy]` da error en juego.

## 6. Prueba
- En la prueba del mundo: que se coloquen N, que funcione al acercarte/romper/pisar, el
  contador, la recompensa, capturas antes/después; `tests/boss_ring_test.tscn` y
  `perf_lint`. Explica al usuario cómo se juega y dónde se ajusta la cantidad.
