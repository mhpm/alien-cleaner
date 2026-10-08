# Aliens Cleaner Arena Editor

Plugin en `addons/aliens_cleaner_arena_editor/` (Proyecto → Configuración → Plugins).
Dock **Arena** junto al Inspector. Arena de ejemplo: `scenes/arenas/arena_world_01_level_01.tscn`
("Quarantine Lab": ábrela para ver todos los componentes).

## Flujo

1. **New**: mundo, nivel, nombre, tamaño, suelo y estilo de muro → `scenes/arenas/arena_world_NN_level_NN.tscn`.
   **Size & Walls** (en cualquier arena ya creada): ancho/alto en baldosas, estilo de muro
   (ninguno = abierta, solo los límites te paran · tiras de muro · banda de agua u otro
   autotile sólido con su ancho), qué hacer con los muros viejos (quitar el marco / vaciar
   la capa Walls / dejarlos), rellenar el suelo vacío y borrar el terreno de fuera.
   Un solo Ctrl+Z lo deshace. Estilos nuevos: cualquier fuente de `terrain.json` con
   `border` (tiras) o un autotile `wang` con `solid` (banda) aparece sola en la lista.
2. **PAINT**: Floor / Environment / Details / Walls abren el pintor TileMap de Godot
   (las baldosas de Walls tienen colisión). ↻ = Sync TileSet.
3. **OBJECTS**: categoría → clic en un objeto → clic en la vista (arrastrar pinta con
   snap; Esc / clic derecho suelta). **Brush** (debajo de la paleta): *One (click)* = una copia por clic;
   *Area (random)* = arrastra un rectángulo en la vista y se llena de copias en posiciones
   al azar (Ctrl / Shift + clic en varios objetos de la paleta para mezclarlos). Opciones:
   *Copies*, *Min dist.* (0 = pueden encimarse), *Round area* (la elipse dentro del
   rectángulo), *Avoid objects* (respeta lo que ya hay), y lo que quieras aleatorio:
   *Random size* (entre dos %), *Random opacity* (entre dos %), *Tint* (un color entre dos;
   el mismo dos veces = todos con ese tinte), *Random flip*, *Random rotation* (± grados).
   Cada arrastre usa una semilla nueva salvo con *Lock seed*. Todo el relleno es una sola
   acción de Ctrl+Z; las opciones se recuerdan por proyecto. La transparencia al pasar
   detrás respeta la opacidad de cada pieza. Código: `dock/brush_panel.gd`,
   `editor/area_brush.gd` (prueba `tests/area_brush_test.tscn`). Categorías: Gameplay, Spawners, Triggers, Hazards,
   Pickups, Environment (props de `PropData`), Contamination (decals).
4. **MISSIONS**: tipo → Add Objective; clic en una fila = editarla en el Inspector y ver
   en la vista los objetos a los que apunta.
5. **WAVES**: línea de tiempo de las oleadas; Add Wave; **+ Spawner** coloca un spawner
   ya asignado a la oleada seleccionada.
6. **DECOR**: pintor de decoración aleatoria (densidad, distancia mínima, semilla,
   giro/rotación, arena entera o área dibujada). Misma semilla = mismo resultado.
   Nunca coloca objetos de juego. Remove Last quita el último reparto.
7. **Settings**: `ArenaData` (id, nombre, dificultad, entorno, música, jefe, recompensas).
8. **Validate** → pestaña VALIDATION (clic = seleccionar nodo). READY / NOT READY.
9. **Play Arena**: guarda y juega solo esta arena. **God** = invencible, **W n** = empezar
   en la oleada n. Las pruebas no guardan progreso. BACK TO EDITOR cierra la ventana.
10. **Duplicate**: copia a otro mundo/nivel con su propio `ArenaData`.

Todo es deshacible con Ctrl+Z (colocar, límites, misiones, oleadas, decoración, Repair).

## Enemigos, hordas y jefes

- OBJECTS > **Enemies**: un objeto por alien (con su dibujo). Colocarlo = un Enemy
  Spawner de ese alien; en el Inspector se ajusta cuántos (`spawn_count`), ritmo, radio,
  oleada (`wave_id`) y se mezclan más con **+ Add alien**.
- OBJECTS > **Bosses**: un objeto por jefe. Colocarlo = un Boss Trigger con ese jefe
  (entra cuando el astronauta pisa el área; valla, música, recompensa).
- **Listas de aliens en el Inspector** (Enemy Spawner y Alien Nest `enemies`, la
  `horde` de una oleada, `roaming` de la arena): una fila por alien con su dibujo, peso,
  porcentaje y cuántos saldrán aprox. (del total `spawn_count` / `enemy_count`),
  probabilidad de élite (★) y quitar; **+ Add alien** abre una rejilla con buscador.
- **Jefe en el Inspector** (Boss Trigger y oleadas `boss_id`): botón con el dibujo del
  jefe; clic = rejilla de jefes (en oleadas también "None").
- **Horda de una oleada**: WAVES > selecciona la oleada > `spawn_mode` AROUND_PLAYER (o
  BOTH), `horde` = qué aliens y en qué proporción, `enemy_count` = cuántos en total
  (0 = sin parar hasta que acabe), `horde_rate` = por segundo, `horde_alive` = máximo
  vivos a la vez, `elite_count` = élites (los últimos).

## Supervivientes (tripulantes a rescatar)

- OBJECTS > **Survivors**: un objeto por tripulante (los 15 de `SurvivorData.CREW`, con su
  cara y su regalo en el tooltip). Elige uno y colócalo.
- Para cambiar uno ya colocado: selecciónalo y en el Inspector, arriba, **Crew member**
  muestra las 15 caras; clic = ese tripulante (Ctrl+Z lo deshace). El Survivor genérico
  de Gameplay sigue disponible.

## Personajes jugables (Players)

Botón **Players** del dock (o **Edit Players…** en el Inspector de un Player Spawn).
Cada personaje es `assets/characters/<id>/<id>.tres` (`CharacterData`) + sus cuadros PNG.

- **New from sheet…**: elige una imagen (PNG/WebP/JPG; fondo transparente o liso, que se
  quita desde las esquinas). Se detecta cada dibujo; estrellas, gotas o fogonazos se
  unen al dibujo más cercano. Cada **fila** es una animación: elige idle, walk, walk_up,
  shoot, hurt, death o skip (filas con la misma animación se juntan). Todos los cuadros
  van en un lienzo común con los pies abajo al centro (centrado por la coronilla; los
  tumbados por su dibujo principal).
- **Edición**: nombre, altura en el juego (el astronauta mide 25.5), arma, *Still idle*
  (de pie = primer cuadro + respiración en código), *Hop* (botecito al andar), fps y
  loop por animación. Clic/arrastre en la vista previa coloca la **mano** (arma de la
  ARMORY que gira hacia el objetivo) o la **boca del cañón** (arma dibujada en el arte:
  se reproduce `shoot` mientras dispara y las balas salen de ahí). *Face left* para
  revisarlo mirando a la izquierda. **Save** guarda.
- **Arma en la mano + pose de disparo**: con *Weapon* = ARMORY weapon el arma es un
  sprite aparte que gira hacia donde disparas (cualquier arma de la ARMORY, mismo tamaño
  en el mundo para todos). *Shoot pose* = mientras dispara se reproduce `shoot` (el brazo
  estirado, sin arma dibujada) y el arma va en **SHOOT HAND**; andando o quieto va en
  **HAND**. Poses por dirección: apuntando más de 45° hacia abajo usa `shoot_down`
  (arma en **SHOOT-DOWN HAND**), hacia arriba `shoot_up` (**SHOOT-UP HAND**, el arma
  pasa detrás del cuerpo); si faltan, usa `shoot`. La vista previa dibuja el Pulse
  Blaster en la mano (apuntando como la pose) para colocarlo. *Walk aims*: los cuadros
  de caminar ya llevan el brazo estirado; el arma va en **WALK HAND** y al disparar de
  lado mientras camina sigue caminando (arriba/abajo usan sus poses).
- **Muzzle flash…**: imagen del fogonazo (apuntando a la derecha; su borde izquierdo va
  en la boca del arma) que sale en cada disparo; `flash` = largo en unidades. **No flash**
  lo quita.
- **Frames from images…**: añade o reemplaza los cuadros de la animación elegida con
  imágenes sueltas (un dibujo por imagen, fondo transparente o liso; uno negro se recorta
  con tolerancia baja para no comerse el contorno). Se redimensionan a la altura de los
  cuadros actuales y el lienzo crece si hace falta (los pies no se mueven) y se recorta
  a lo que se usa. *Split each picture* = una imagen con varios cuadros en rejilla
  (columnas × filas, de izquierda a derecha y de arriba abajo). La hoja de **New from
  sheet** también tiene *Grid columns/rows* + **Cut** para cuadros que se tocan.
- **Replace frames from a sheet…** cambia los sprites de un personaje existente.
  **Duplicate** / **Delete** (el astronauta no se borra).
- **Elegir quién juega**: OBJECTS > Gameplay lista un **"Player · <nombre>"** por
  personaje (el astronauta incluido). Colócalo en la vista: como solo hay un Player Spawn
  por arena, si ya existe se mueve ahí y cambia de personaje (Ctrl+Z lo deshace).
  También: **Use in this arena** en la ventana Players, o `character` en el Inspector
  del Player Spawn. Vacío = el astronauta.
- Animaciones que falten usan otra: walk_up → walk, shoot/hurt → idle, death → hurt.
  Al mutar (Modo Infectado), los personajes nuevos conservan su arte con un tinte magenta.

Ejemplo: `kid_astronaut` (hoja `tools/characters/kid_astronaut_ref.webp`, pose de disparo
`kid_shoot_pose_ref.webp`, fogonazo `kid_muzzle_flash.png` recortado de
`kid_muzzle_flash_ref.webp`, caminar apuntando `kid_walk_aim2_ref.png` (rejilla 2×2, *Walk aims*), poses apuntando abajo / arriba `kid_shoot_down_ref.png` / `kid_shoot_up_ref.png` (de
espaldas: el arma va detrás de la cabeza y solo asoma el cañón); lleva el
arma de la ARMORY con *Shoot pose*).

## Mundos abiertos (mapas grandes para explorar)

- **Tamaño**: New Arena admite hasta 256×256 baldosas (8.192 unidades); las asas de
  `Bounds` lo cambian después. La cámara sigue al astronauta y se detiene en los bordes.
- **Horda alrededor del jugador**: en una oleada, `spawn_mode` = AROUND_PLAYER (o BOTH
  con spawners) + lista `horde`, `horde_rate`, `horde_alive`. Llegan justo fuera de la
  pantalla, sobre todo por delante de hacia donde caminas.
- **Aliens que vagan**: `ArenaData` → Open World → `roaming` (lista ponderada),
  `roaming_alive`, `roaming_rate`: el mapa nunca está vacío.
- **Correa**: los aliens de la horda que se quedan muy atrás vuelven al borde de la
  pantalla; los de spawners y nidos se quedan en su zona.
- **Spawners que despiertan**: `activation_range` en `EnemySpawner` (solo funciona si
  estás cerca); los nidos ya tienen `wake_range`.
- **Minimapa** (arriba a la derecha) con niebla de exploración, colores del terreno y
  marcadores: tripulantes, nidos, núcleos, jefe, salida abierta y el objetivo actual.
- **Luz y fondo**: `ambient` (atardecer, noche) y `background` en `ArenaData`.
- **Decoración ligera** `ArenaScenery`: cientos de árboles, rocas o coches sin coste.
  Tienen viento por shader compartido (`sway`), se vuelven transparentes al pasar detrás
  (`fade_behind`), una huella de colisión opcional (`footprint`) y pueden ir planos sobre
  el suelo (`flat`).

Arena demo de mundo abierto: `scenes/arenas/arena_world_10_level_01.tscn` ("Harvest
Hollow", ver más abajo).

## Proteger la aldea (aldeanos y asaltos)

- **Aldeanos a rescatar**: un Survivor con `look` = su dibujo (cualquier aldeano de los
  kits, asustado y feliz es el mismo); vacío = el tripulante. Sigue dando el regalo de
  su `crew`. `character_name`, `dialogue` (lo que grita) y `thanks_line` le dan voz; los
  avisos de escolta usan su nombre ("PIP SAFE!").
- **Lo que hay que defender**: un Defend Core con `look` (pozo, granero, casa…) y
  `look_width`; vacío = el reactor. `core_name` sale al caer ("THE BARN DESTROYED!").
- **Asaltos** (`lure_range` > 0, círculo naranja en el editor): los aliens que entran en
  ese radio y no están peleando con el astronauta **marchan hacia el núcleo**
  (`Enemy.lure`) y lo desgastan; si el astronauta se les acerca (`Enemy.LURE_BREAK` 90)
  vuelven a ser suyos. Los jefes no se distraen. Spawners en los bordes del mapa +
  núcleos con atracción = oleadas que asaltan la aldea.

Mundo de ejemplo: `scenes/arenas/arena_world_10_level_01.tscn` ("Harvest Hollow", 80×80,
aldea de granja al atardecer), construido con `res://tools/build_harvest_hollow.tscn`:
defender el Viejo Pozo (y el granero) de 3 asaltos que salen de los maizales, el huerto
y el bosque, 6 aldeanos escondidos (Pip hay que llevarlo del estanque a la plaza), nidos
en el maíz, diálogo con el anciano, maizales en hileras y COMMANDER ZORP en el
círculo de las cosechas.

**Kit de construcciones de granja**: hoja `tools/farm_buildings_ref.webp` → `python
tools/import_decor_sheet.py tools/farm_buildings_ref.webp --kit farm --category Buildings --prefix bld
--solid --scale 0.75 --min-area 300` (las piezas que se tocan en la hoja se separaron después:
casa/silo, corrales/torre/molino, puesto/farol, pacas, cajas, barril/carreta = `bld_48..54`) →
`assets/decor/farm/buildings/bld_NN.png`, OBJECTS > Farm · Buildings · Houses / Barns / Animal
pens / Fences / Yard. Tamaño y colisión (huella en la base) por tipo en `kit.json`, sin sombra;
el arco con farol `bld_51` no bloquea (se pasa por debajo). Harvest Hollow los usa: casas,
granero (núcleo `bld_07`), pozo (núcleo `bld_40`), silo, torre de agua, molino, establos,
gallinero, corral de ovejas, puestos del mercado, pacas, cajas, barriles y carreta.

**Kit de hierba**: hoja `tools/grass_sheet_ref.webp` → `python tools/import_decor_sheet.py
tools/grass_sheet_ref.webp --kit farm --category Grass --prefix grass --sway --scale 0.3 --min-area 60`
→ `assets/decor/farm/grass/grass_NN.png` (98 piezas: matas, arbustos con flores y bayas, hojas
bajas) en OBJECTS y DECOR > Farm · Grass, con viento y sin sombra; las que llevan piedras o tocón
(73-75, 77, 78, 80, 81) van en Farm · Grass · Rocks sin viento y con colisión, y la piedrita 95 es plana.

**Kit de maíz**: hoja `tools/corn_sheet_ref.webp` → `python tools/import_decor_sheet.py
tools/corn_sheet_ref.webp --kit farm --category Corn --prefix corn --sway --scale 0.3 --min-area 150`
→ `assets/decor/farm/corn/corn_NN.png` (OBJECTS > Farm · Corn). Grupos que usa el constructor
(`YOUNG`, `MATURE`, `COBS`, `DRY`, `STUMPS`, `DEBRIS` (planos), `WEEDS`, `FLOWERS`):
`_cornfield` pone maíz joven y hierba en los bordes, maduro y con mazorcas dentro, seco
y tocones cerca de los nidos, y hojas caídas en los pasillos entre hileras (las mazorcas sueltas 08, 09 y 24 no se usan).

## Auto-import (una imagen de arte de suelo → listo para usar)

PAINT > **Auto-import…**: elige una imagen con baldosas, caminos, claros, plantas… (fondo
transparente o liso) y el editor lo ordena solo (`editor/sheet_auto_import.gd`):
- separa cada pieza, calcula el tamaño de baldosa (el cuadrado lleno más repetido) y
  clasifica: **Floor tiles** (cuadrados de una sola textura → baldosas de suelo sin
  costura y con brillo igualado, rellenan New Arena), **Detail tiles** (cuadrados con
  algo distinto en el centro → baldosas para pintar encima), **Pieces** (piezas grandes
  de bordes rectos), **Patches** (piezas grandes orgánicas), **Plants** (pequeñas y
  verdes, con viento) y **Spots** (pequeñas de otro color); todo plano en el suelo.
- La ventana muestra cada grupo con miniaturas: clic en una pieza = moverla a otro grupo
  o *Skip*. Campos: nombre (grupo de terreno), kit de decoración (`assets/decor/<kit>/`,
  uno existente o nuevo), sección (subcarpeta) y tamaño de baldosa en px (= 32 unidades,
  fija la escala).
- **Import**: crea las fuentes "<nombre> floor" / "<nombre> tiles" en la biblioteca y las
  piezas en OBJECTS > <Kit> · <Sección> · …. Reiniciar Godot para que el pintor de
  TileMap muestre el grupo nuevo. Reimportar con el mismo kit y sección reemplaza las
  piezas (las fuentes de baldosas se añaden de nuevo: borra las viejas en Tiles…).

## Terreno de granja

Hoja `tools/farm_tiles_ref.webp` → `python tools/import_farm_tiles.py`:
- Baldosas (biblioteca de terreno, grupo **Farm**): **Farm grass** (6, sin costura,
  rellenan el suelo de New Arena) y **Farm dirt patches** (12, hierba con un claro de
  tierra; se pintan encima del pasto). Se añadieron con PAINT > Tiles (los PNG de origen
  quedan en `tools/farm_tiles/`).
- Piezas sueltas en el kit `assets/decor/farm/terrain/` (OBJECTS > Farm · Ground · …,
  todas planas en el suelo): **Paths** (tiras, esquinas, cruces), **Patches** (claros y
  matas grandes), **Plants** (matas, arbustos y flores, con viento) y **Dirt** (manchas).
  Escala: una baldosa de la hoja (~107 px) = una baldosa de la arena (32 unidades).

## Kits de decoración (arte intercambiable)

Cada carpeta `assets/decor/<kit>/` es un kit: todos sus PNG/WebP (también en
subcarpetas) aparecen en OBJECTS y DECOR como "<Kit> · <Categoría>". `kit.json` es
opcional y ajusta cada archivo: `category`, `width` (unidades), `solid` ([ancho, alto]
de la huella o null), `sway`, `fade`, `flat`. Sin él: la subcarpeta da la categoría y el
tamaño de la imagen da el ancho.

Hojas de arte → kit: `python tools/import_decor_sheet.py <hoja> --kit earth --category Trees --prefix tree --sway --solid`
(corta cada figura separada, quita el fondo si no hay transparencia y actualiza kit.json).

### Biblioteca de tiles (dock > PAINT > **Tiles…**)

Todo el terreno se gestiona desde esta ventana (guarda `terrain.json` y actualiza el
TileSet solo):

- **Import Sheet**: elige una hoja (de cualquier carpeta), indica ancho/alto del tile,
  margen y separación (la vista previa dibuja la cuadrícula de corte), nombre y **grupo**.
  Cada tile se escala a 64 px; "Make seamless" quita las costuras; "Blocks" = colisión.
- **Import Images**: varias imágenes sueltas, una por tile.
- Fuente seleccionada: cambiar nombre, grupo, sólido, relleno de New Arena y terreno;
  **clic en un tile** para dejarlo fuera del pintor (tachado) y *Save Tile Choice*;
  **Remove Source** la borra (las celdas pintadas con ella quedan vacías).
- **Make Autotile**: elige un tile de fuera (p. ej. césped) y uno de dentro (p. ej. lava),
  el estilo del borde (plain, water, path, infested), el terreno nuevo (nombre y color) y
  si bloquea: crea las 48 baldosas de transición, el terreno de la pestaña Terrains y la
  colisión que sigue la orilla.
- **Terrains**: renombrar, recolorear y añadir tipos de terreno.

En el panel TileMap las fuentes aparecen como "Grupo · Nombre". Lo importado se copia a
`assets/arena/terrain/custom/`.

### Arte de la Tierra (tus hojas, mejoradas)

`python tools/make_earth_assets.py` lee `tools/earth_terrain_ref.webp` y
`tools/earth_decor_ref.webp` y genera:

- **Terreno sin costuras**: tus baldosas de césped, agua, tierra e infestado se
  convierten en texturas que repiten sin juntas (`tools/earth_autotile.py`).
- **Autotiles de esquinas** (terrenos de Godot): césped↔agua (arena, línea húmeda y
  espuma), césped↔sendero y césped↔infestado; 16 casos × 3 variantes cada uno, así las
  orillas largas no se repiten. En el editor: capa Floor → panel TileMap → pestaña
  **Terrains** → "Earth" → Water / Dirt path / Infested / Grass, y pinta: los bordes
  salen solos. El agua bloquea con la **forma real de la orilla**.
- **Puentes**: cualquier pieza con `bridge` hace transitable el agua bajo ella (y la
  validación lo sabe). El agua pintada alrededor de los puentes de la hoja se quita.
- **Decoración**: 132 piezas recortadas por objeto (aunque se toquen en la hoja) en
  `assets/decor/earth/<categoría>/` con viento, colisión y transparencia por tipo.

Las carreteras se usan tal como están pintadas (fuente "Earth - roads").

## Componentes (`scripts/arena/components/`)

| Componente | Qué hace | Evento |
| --- | --- | --- |
| `EnemySpawner` | lista ponderada, cantidad, intervalo, ráfaga, radio, retraso, máx. vivos, `wave_id`, auto / trigger | — |
| `AlienNest` | nido-enemigo real que pare aliens cuando te acercas | `nest_destroyed` |
| `ArenaSurvivor` | rescate (radio/tiempo propios, diálogo, regalo); con `escort_to` te sigue hasta una zona y puede morir | `survivor_rescued`, `escort_delivered`, `escort_lost` |
| `AndroidPart` | pieza oculta que se revela al acercarte; se guarda en `Game.android_parts` | `item_collected` (android) |
| `BossTrigger` | zona → valla, música, intro, jefe; al caer, recompensa | `boss_defeated` |
| `HazardArea` | ácido, radiación, slime, eléctrico (ciclo), fuego, vacío (atrae) | — |
| `ArenaTrigger` | REACH, MESSAGE (diálogo), START_WAVE, START_SPAWNERS, ACTIVATE_HAZARDS, OPEN_DOOR, ACTIVATE (consola) | `location_reached`, `activated` |
| `ArenaDoor` | barrera que se abre por trigger, oleada u objetivo | — |
| `ArenaExit` | portal: se abre al completar los MAIN | — |
| `DefendCore` | núcleo que los aliens desgastan | `core_destroyed` |
| `ArenaPickup`, `ArenaChest` | coleccionables y cofres del juego | `item_collected` |
| `ArenaScenery` | decoración ligera de kits (viento, transparencia, huella) | — |
| `ArenaProp`, `ArenaDecal`, `PlayerSpawn` | props reales, decals, inicio | — |

## Diálogos (Dialogue Trigger)

Doble clic en un Dialogue Trigger del mapa (o **Open Dialogue Editor** arriba en su
Inspector) abre el **Dialogue Editor** (`dock/dialogue_editor.gd`):

- **CAST**: personajes con cara (galería `dock/portrait_picker.gd`: tripulantes felices /
  asustados, astronauta, aldeanos de las carpetas `villagers`/`people`/`npc` de los kits,
  aliens, jefes, o cualquier PNG), nombre, color, lado del cuadro (dos que hablan se miran)
  y voz (tono de los pitidos al escribir).
- **SCRIPT**: la conversación como chat; por línea: quién, texto, tamaño S/M/L/XL (8/12/16/24;
  S, L y XL son los más nítidos), efecto (Normal, Shout!, Whisper…, Radio, Thought), segundos
  que se queda (0 = automático), cara propia de la línea. Botones "+ nombre" añaden la
  siguiente; **Ctrl+Enter** en una línea añade la respuesta del otro. Plantillas para empezar.
- **PREVIEW**: el cuadro real del juego (`DialogueBoxArt`, compartido con `ArenaDialogue`)
  escribiendo; "Play this line" / "Play all".
- **HOW IT PLAYS**: cinemático (pausa el juego y se avanza tocando), velocidad, arriba/abajo.

Se edita una copia; **Save dialogue** la aplica en una sola acción con deshacer. Los datos
son `DialogueData` (`cast` de `DialogueSpeaker`, `lines` de `DialogueLine`) en
`ArenaTrigger.dialogue`; sin él, el trigger sigue usando `speaker`/`message`/`portrait`.
En juego: `ArenaDirector.play_dialogue()` → `ArenaDialogue.play()`.

## Datos (`scripts/arena/data/`)

`ArenaData` (en la escena), `ObjectiveData`, `WaveData`, `SpawnEntry`, `RewardData`,
`DialogueData` / `DialogueSpeaker` / `DialogueLine`.
Un objetivo nuevo = un script que extiende `ObjectiveData` y sobrescribe
`progress_for` / `tick` / `fails_on` (tipo CUSTOM); nada más cambia.

## Runtime (`scripts/arena/runtime/`)

`scenes/arena_play.tscn` → `ArenaWorld` (hereda `GameWorld`, sin modificarlo) +
`ArenaDirector` (eventos, recompensas, flecha guía al objetivo más cercano),
`ArenaWaveManager`, `ArenaObjectives` + `ObjectivePanel` (HUD), `ArenaDialogue`.
Los aliens entran por `ArenaSpawnService`: para un pool, extender y sobrescribir `_create`.
`ArenaSession.arena_path` permite jugar una arena desde código (campaña futura).

## Contenido sin código

- Props: `PropData.PROPS`. Escenas preset: `scenes/arena/palette/<categoría>/`
  (regenerar con `godot --headless --path . res://tools/build_arena_palette.tscn`).
- Decals: `scenes/arena/palette/palette.json`. Terreno: `assets/arena/terrain/terrain.json`.
- Arte: `python tools/make_arena_terrain.py`, `python tools/make_android_parts.py`.

## Pruebas

```powershell
godot --headless --path . res://tests/arena_editor_test.tscn
```
Valida la arena de ejemplo y casos rotos, la juega entera y prueba el mundo abierto
(minimapa, horda, correa, transparencia): 41 comprobaciones. Las arenas guardadas con el
formato anterior (metadatos en la raíz) se migran solas a `ArenaData`.
Reconstruir la arena de ejemplo: `res://tools/build_test_arena.tscn`.
