---
name: kit-world-map
description: Construye el mapa de un mundo de Alien Cleanup Crew a partir de un KIT de piezas que manda el usuario (suelo, tramos de muro, columnas, esquinas de maquinaria, decoración), como el mundo 5 THE FORGE (ForgeMap). Úsalo cuando el usuario pase una hoja de elementos de escenario para armar un mundo, pida corregir/mejorar muros o salas, pida pasillos/laberintos, o mande más piezas (esquinas, muros) para un mundo existente.
---

# Mapa de mundo armado con un kit

Referencia viva: `tools/make_forge_walls.py` (recorte, una entrada por kit en `SETS`) +
`scripts/data/forge_map.gd` (trazado y dibujo, `LOOKS[set]`) + `Explore._setup_forge` +
`tests/forge_test.gd` / `tests/gene_vault_test.gd`. Mundos hechos así: 5 (w5) y 6 (w6).
**Si el kit nuevo tiene la misma estructura** (suelo en baldosas, 10 tramos con postes,
columnas, 4 esquinas + hoja de esquinas extra): NO escribas otra herramienta ni otra clase;
añade su entrada en `SETS` (coordenadas medidas) y en `ForgeMap.LOOKS`, y en `WorldData`
`"explore": {"build": "kit", "set": "<set>", ...}`. Solo si la estructura es distinta,
amplía la herramienta.
**Carga también la skill `world-performance`** y cumple su verificación.

## Reglas del usuario
- Nada de muros estirados ni pinturas repetidas: muros compuestos pieza a pieza.
- No solo cámaras cuadradas: salas grandes, **pasillos**, **laberintos**, salas con columnas,
  salas partidas, en L, fosas/bloques que rodear. Cada partida distinta (aleatorio).
- Todo alcanzable, puertas de ≥ ~70 unidades, pasillos para pelear con hordas.
- Las piezas que mande el usuario se usan todas, combinadas e intercambiadas (barajadas sin
  repetir, espejadas cuando la perspectiva lo permite).

## 1. Analizar el kit
1. Copia la imagen a `tools/<mundo>_<algo>_ref.webp`. Comprueba alfa con PIL.
2. Componentes conectados (`scipy.ndimage.label` sobre alfa > 40, con `binary_closing` si
   hay piezas con huecos) → cajas `(x, y, w, h)`. Amplía recortes ×3-5 sobre magenta y
   míralos con `Read` para entender cada pieza (perspectiva 3/4: tapa arriba, cara frontal
   abajo).
3. Mide en px del kit: ancho/alto de los postes (fila superior con alfa = columnas del poste),
   fila donde empieza la losa, alto total del muro, ancho de las columnas, rejilla de
   baldosas del suelo (mínimos de brillo por columna/fila).

## 2. Recorte (`python tools/make_forge_walls.py <set>`)
Salida en `assets/rooms/<set>/build/`:
- `floor.png`: baldosas regularizadas a un tamaño fijo. Si el suelo trae brillos/manchas que
  cruzan baldosas, **quítalos** (parche desde una baldosa limpia con máscara suave) y añádelos
  en el juego como brillos sueltos; si no, al barajar baldosas salen cortados.
- `atlas.png` (ancho 2048 si hace falta) con borde extruido `PAD`: `post_n`, `cap_n` (poste
  sin pata cuando el muro sigue hacia abajo), `feat_n` (interiores de los tramos),
  `filler` (losa + cara lisa repetible), `shaft_n` (columnas repetibles), esquinas
  `corner_tl/tr/bl/br` y extras `corner_x<n>`.
- `build.json`: regiones y conteos (`posts`, `feats`, `shafts`, `extra_corners`, `floor`).
- Descarta piezas cortadas (p. ej. postes con la pata incompleta). Revisa el atlas con `Read`.
- Suelos muy teñidos (brillos/baba en casi todas las baldosas): mide la cobertura por baldosa
  y ajusta `glow` (color que se limpia) y `drop` (baldosas que se quitan); mira `floor.png`.
- Esquinas extra: `extra_side` "auto" detecta si cada una es de arriba-izquierda o
  arriba-derecha por el muro que muestra; compruébalo mirando la hoja.

## 2b. Objetivo propio del mundo
Cada mundo trae un objetivo distinto de "matar" (regla del usuario): mundo 5 núcleos que
enfriar (`ReactorCore`), mundo 6 tanques que romper (`SpecimenVat`, `Enemy.anchored`). Van en
las áreas que elige `ForgeMap._pick_cores` (`cores` + `vats` + lo nuevo), con contador en el
HUD (`Explore._refresh_counter`) y una recompensa que cambie la pelea final.

## 3. Trazado (clase tipo `ForgeMap`)
- Rejilla de celdas `CW`×`CH` (~100×112 unidades), muros en las aristas: poste en cada nodo,
  tramo horizontal entre postes, columna entre postes verticales. Escala `K` = unidades/px
  del kit: el muro horizontal ~40 unidades de alto, el astronauta ~25.
- BSP en áreas; a veces un pasillo de 1 celda entre mitades. Tipos: `hall`, `pillars`,
  `ring` (fosa/bloque central), `split`, `lshape`, `maze` (DFS + bucles), `solid`,
  `corridor`. Mínimo de laberintos (`mazes`). Inicio en un área amplia abajo al centro;
  objetivos del mundo (núcleos, etc.) en áreas amplias y separadas.
- Puertas: 1-2 entre mitades, bucles extra con `maze`, y `_repair` (BFS desde el inicio
  abriendo hacia lo alcanzable) para garantizar que todo se alcanza.
- Esquinas de maquinaria: solo en esquinas cuyos dos lados exteriores son muro, sin cortar el
  mapa (comprueba con BFS). Reparte las piezas con un mazo barajado por esquina; las de
  arriba se pueden espejar entre izquierda y derecha; las de abajo solo con piezas de abajo
  (espejar en vertical rompe la perspectiva 3/4).
- Muebles (`RoomKit`) en salas amplias, nunca tapando puertas.
- Dibujo: suelo por trozos, sombras de contacto bajo muros, brillos aditivos, muros por
  filas (columnas que bajan → tramos → postes), esquinas en una capa final. Muros solo donde
  hay suelo a algún lado (no entre dos vacíos).
- `solids()` fusionados + márgenes; `spots(area)` libres para cofres y supervivientes;
  `flow(celda)` para que los aliens rodeen los muros.
- En `WorldData`: `"explore": {"build": "<id>", "cells": [w, h], ...}` y la rama en
  `Explore.setup` (como `_setup_forge`).

## 4. Prueba y entrega
- Prueba del mundo en ventana con `-- --overview`: captura del mapa entero y primeros planos;
  míralas con `Read` y corrige lo que se vea mal (desalineados, piezas cortadas, huecos).
- Comprueba: todo alcanzable, inicio libre, ningún alien dentro de muros, `explore_test` sigue
  pasando (otros mundos intactos).
- Verificación de `world-performance` con el banco comparando con otro mundo.
- Documenta en `CLAUDE.md` (sección del mundo) y explica al usuario qué tipos de sala salen.
