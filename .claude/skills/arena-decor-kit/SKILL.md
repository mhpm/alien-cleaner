---
name: arena-decor-kit
description: Recorta las hojas de arte que manda el usuario (muros modulares, objetos, plantas, máquinas, suelo) en un kit de la paleta del Arena Editor de Alien Cleanup Crew - assets/decor/<mundo>/<carpeta>/*.png + kit.json con tamaño y colisión correctos en vista 3/4 - y el suelo como terreno. Úsalo cuando el usuario mande hojas de muros/props para un nivel ("implementa estos assets", "usa estas paredes"), pida su carpeta para añadir más, o diga que la colisión no coincide con la imagen.
---

# Kit de decoración desde las hojas del usuario

Plantilla: `tools/make_biodome_kit.py` (mundo 8) sobre `tools/kit_cut.py` (funciones
comunes). Copia el script como `tools/make_<mundo>_kit.py` y cambia solo sus tablas.

## 1. Guardar y mirar las hojas
- Las imágenes pegadas en el chat a veces NO están en disco: búscalas en
  `%TEMP%/claude/.../images/` (la ruta sale junto a la imagen); si no aparecen, pídele al
  usuario que las guarde (`tools/w<N>_walls_ref.webp`, `tools/w<N>_props_ref.webp`).
- Comprueba alfa (fondo transparente). `python tools/kit_cut.py index <hoja> <out.png>`
  numera cada pieza e imprime su caja: míralo con `Read` y escribe la tabla
  `nombre: (carpeta, (x, y) arriba-izquierda)`. Las motas < `SPECK` 300 px dentro de la caja
  de una pieza se le pegan solas (`owner`).
- Carpetas por papel (la paleta las muestra como `<Kit> › <Carpeta>`): `walls`,
  `junctions`, `tanks`, `planters`, `plants`, `machines`, `storage`, `pipes`,
  `furniture`, `floor` (planas). Nombres descriptivos (`console_a`, `pot_fern`...).

## 2. Muros modulares (lo más delicado)
Mide la hoja: cada TRAMO horizontal trae un poste en cada extremo (`POST` px de ancho);
una COLUMNA va de la tapa del poste de arriba a la base del de abajo. Escala
`WALL_K` = unidades por px tal que los centros de los postes caen en los nodos de la
rejilla: `mod_w = (largo_tramo - POST) * WALL_K`, y la columna da `mod_h = largo_columna *
WALL_K - alto_tramo * WALL_K` (en el 8: 96 × 64 = 3×2 baldosas; ajusta para múltiplos de
32 = baldosa del suelo). Comprueba en una captura que tramos y columnas se unen.
- Largos distintos en la hoja: `stretch_run(img, POST, RUN_W)` reescala solo el centro unos
  px. **Nunca alargues mucho** (repetir franjas/estirar se vio mal y el usuario lo rechazó):
  para pasillos más anchos se repiten módulos en el constructor (`mods_x`/`mods_y`).
- Colisión 3/4 (`kit_cut`): `Kit.run_entry` = sólido el `RUN_SOLID` 80% de abajo del dibujo
  (por debajo te quedas delante de la cara, por arriba tras su borde); `Kit.column_entry` =
  `SIDE_PAD` 12 más ancho que el dibujo (el jugador choca con un círculo de 5.5 en los pies
  pero mide ~22: sin margen se mete medio cuerpo). Columnas y piezas altas con `fade`.
- Cruces y esquinas en L: a `junctions/`, para colocar a mano.

## 3. Objetos
`PROP_K` (~0.3 unidades/px) para que el astronauta (33 de alto) quede a escala: un tanque
~70 de alto, una maceta ~35. `Kit.prop_entry(cat, w, h, kind)`: `solid` (pie 80% de ancho,
6-22 de fondo; `fade` si mide más de `TALL` 45), `flat` (rejillas, manchas: sin colisión,
capa Decorations), `walk_under` (arcos), `post` (farolas: pie mínimo).

## 4. Suelo como terreno
`floor_atlas(png, px_baldosa, cols, rows, "<mundo>_floor.png", id, "<Mundo> floor", "<Grupo>")`
→ atlas de 64 px en `assets/arena/terrain/` + fuente en `terrain.json` (id libre:
`free_terrain_id()`; la baldosa 0 = la lisa). Los ids no se cambian nunca (las escenas los
guardan). Luego cualquier build del Arena Editor sincroniza el TileSet
(`TerrainTilesetBuilder.sync()`) y hay que reiniciar el editor.

## 5. Cerrar el kit
- `Kit.save(img, carpeta, nombre, entry)` guarda PNG de paleta 256 colores (~1/3 del
  tamaño; el proyecto vigila el peso del APK). `kit.finish(README)` escribe `kit.json`
  conservando las entradas de PNG que el usuario añadió a mano, y `README.txt` (cómo añadir
  más: soltar PNG en una carpeta + ↻; "Apply to all copies" guarda sus valores).
- `python tools/kit_cut.py contact <kit> <out.png>` → hoja con todas las piezas: mírala.
- Piezas viejas que el kit nuevo reemplaza: bórralas con su `.import` y su caché en
  `.godot/imported/` (`<archivo>-<md5("res://ruta")>.ctex` y `.md5`), y comprueba con grep
  que ninguna escena las usa.
- `Godot --headless --path . --import`.

## Atlas ForgeMap (mundos 5-7 sin kit nuevo)
Sus muros están en `assets/rooms/<set>/build/atlas.png` + `build.json` (regiones `post_n`,
`cap_n`, `feat_n`, `filler`, `shaft_n`, `corner_x<n>`; `K` 0.45). Para piezas del editor:
tramo = `filler` repetido a lo largo del hueco entre postes (`CW - post_w*K`) + `feat_n`
centrado encima; poste = `post_n` (con pata) o `cap_n` (si baja una columna); columna =
`shaft_n` repetido (es su forma de dibujo, no estira nada); esquinas `corner_x<n>` con pie =
mitad de abajo. Colocación como `ForgeMap.draw_walls`: tramo con los pies en
`nodo.y - hp.y + alto`, columna con los pies en `nodo.y + CH - hp.y + 2`, postes al final.
(La primera versión del mundo 8 se hizo así; el usuario luego mandó muros modulares.)

## Si la colisión no coincide con la imagen
Mide: dibujo de la pieza vs `solid` de `kit.json` vs radio del jugador (5.5) y su ancho
dibujado (~22). Corrige en el script del kit, regenera, y aplica a la escena ya hecha con
`python tools/apply_kit_solids.py scenes/arenas/<escena>.tscn <kit> [carpeta/]` (solo
reescribe líneas `footprint`, respeta lo hecho a mano y los UID). Pide al usuario que
recargue la escena sin guardar si la tenía abierta.
