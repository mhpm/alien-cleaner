---
name: new-enemy
description: Implementa un enemigo nuevo o un jefe (mini jefe / jefe final) de Alien Cleanup Crew a partir de una hoja de sprites que manda el usuario. Cubre el recorte de la hoja, los sets de sprites, los datos, el script de IA con ataques creativos, su colocación en un mundo, la prueba en el juego y la documentación. Úsalo cuando el usuario pase una imagen con un alien/jefe nuevo o pida "implementa este enemigo/jefe".
---

# Nuevo enemigo / jefe

Flujo completo, en este orden. Cada paso tiene su verificación; no pases al siguiente sin ella.
Referencias vivas (léelas antes de escribir, copian el estilo exacto del proyecto):
- Jefe: `scripts/enemies/boss_angler.gd` (el más completo), `boss_magma.gd`.
- Enemigo normal: `scripts/enemies/nova_puffer.gd` (simple), `goo_lantern.gd`, `plasma_pupil.gd` (con mecánica).
- Datos: `scripts/data/enemy_data.gd`, `scripts/combat/enemy_shot.gd` (`STYLES`), `scripts/data/world_data.gd`.
- Reglas generales de diseño: `CLAUDE.md` (secciones de cada enemigo) y la memoria `new-enemy-guidelines`.

## Reglas de diseño (las pide el usuario)
1. **Tamaño**: igual o mayor que el astronauta (~25 unidades de alto; objetivo 26-31 para enemigos, ~45-60 para jefes). Ajusta `scale` = altura deseada / `body_h` del manifest.
2. **Ataque creativo e inteligente**, cada enemigo con su rol propio (predice tu camino, se esconde tras otros, reacciona a que le disparen, atrae, deja rastro...). No sirve "dispara en línea recta". Si el arte trae poses/proyectiles, deja que inspiren los ataques (una pose de guiño → "ven aquí", anillos de ondas → buceo con géiseres, minas girando → lanzarlas).
3. **Contrajuego claro**: todo ataque avisa (`Telegraph` círculo/línea, anillo, pose) y se puede esquivar. Los jefes tienen una ventana de daño tras sus ataques fuertes (agotado/mareado con `armor` > 1).
4. Explica al usuario el contrajuego de cada ataque al terminar.
5. Prefiere las hojas separadas del usuario; corta con `tools/cut_sheet_enemies.py` (NO uses `scripts/split_items.py`).

## 1. Guardar y analizar la hoja
1. Copia la imagen a `tools/<nombre>_ref.webp` (la ruta temporal viene en el mensaje). Comprueba con PIL que tiene alfa.
2. Genera una cuadrícula ampliada ×2 con líneas cada 50 px y etiquetas (guarda en el scratchpad) y míra recortes con `Read`. Anota por fila: `y0,y1` y las `x` entre fotogramas (recuerda dividir entre 2 las coordenadas de la imagen ampliada).
3. Identifica qué es cada fila/pieza: idle/miradas, enfadado, furia (aura), mareado, herido, ataques, proyectiles (crecen/revientan), minas, ondas/anillos, muerte.

## 2. Recorte (`tools/cut_sheet_enemies.py`)
- Añade una hoja en `SHEETS`: `"<hoja>.webp": {"<id>": [("fila", y0, y1, x0, x1, cuts), ...]}`.
  - `cuts` = x aproximadas entre fotogramas (se ajustan solas a la columna más vacía, `SNAP` 12). `[]` = un solo fotograma. `None` = piezas sueltas por componentes conectados.
  - Filas que se pisan en vertical: parte la fila en dos rangos con distinto `y0/y1` (p. ej. `die` y `die2`) para no arrastrar goteos de la fila vecina.
  - `MAIN_ONLY = {"fila": n}` deja solo la pieza mayor de los primeros n fotogramas (quita goteos).
- Ejecuta `python tools/cut_sheet_enemies.py <id>` (borra `assets/sprites/enemies/<id>/` antes si cambias filas).
- **Verifica visualmente**: monta una hoja de contacto de todos los recortes (PIL, fondo gris) y míra con `Read`. Busca fotogramas cortados, trozos de vecinos y tamaños raros; ajusta rangos y repite.

## 3. Sets de sprites (`tools/slice_sprites.py`)
- Define una constante de ruta (`TA = "enemies/<id>/%s/image_%02d.png"`) o usa `W4`.
- `SETS["<id>"] = {"anchor": "bbox"|"center"|"feet"|"bottom", "anims": {nombre: ([rutas], fps, loop)}, "body": "walk"}`.
  - Anim obligada `walk` (la usa el cuerpo). Nombres comunes: `walk`, `angry`, `fury`, `hurt`, `stun`, `attack`/`charge`, `death` (una vez, no loop).
  - Sets de proyectiles/efectos aparte: `anchor: "center"`, anim `fly` (proyectil) o `pop` (efecto de un solo uso).
  - Todos los fotogramas de un set comparten lienzo (el mayor): no mezcles efectos enormes en el set del cuerpo si no hace falta.
- Regenera solo lo nuevo: `python tools/slice_sprites.py tools/reference_sheet.webp --only <set1>,<set2>`.

## 4. Datos
- `enemy_data.gd`: entrada en `TYPES` con `name`, `hp`, `speed`, `damage`, `coins`, `radius`, `art`, `scale`, `ai`, `color`, `kb`, `script`. Enemigo que dispara: `"shoots": true` (cuenta como tirador, máx 15 vivos). Jefe: `"boss": true, "kb": 0.0, "cost": 0`.
- Proyectiles: `EnemyShot.STYLES` en `enemy_shot.gd`: `art`, `scale`, `pop`/`pop_s`, `tint`, `color`, `hit` (radio de golpe) y opcionales `home` (giro hacia el jugador), `drag`/`min` (frenado), `split`/`split_tex` (revienta en anillo), `grow` (los fotogramas se reparten por su vida), `rot` (si el arte no apunta a +x). El `life` se fija tras `spawn_enemy_shot`; la velocidad real ya lleva el multiplicador del mundo (usa `s.vel.length()`).
- Charcos tóxicos/ácidos: `GooPuddle` (`style` red/hive/lava, `acid`, `radius`, `life`, `damage`).

## 5. Script de IA
- Enemigo normal: `extends Enemy`, `_init_ai()` y `_ai(delta) -> Vector2` (devuelve la velocidad), `_anim_name()`, `_on_death()`. Estados con `state`/`state_t`. `speed` ya incluye el multiplicador del mundo.
- Jefe: `extends BossBase` (`class_name BossXxx`): `_size_to_player(FIGHT_SECS)` en `_init_ai` (mini jefe 45 s), ciclo `CALM`/`FURY` de movimientos, `_enrage()` bajo 50 % (banner, `tint_flash`, borra `enemy_shots` con `.pop()`, empuja), `_desperate()` bajo 20 %, `armor` (fases y ventanas de daño), `_drift` para orbitar, `_after(rest)` para volver al reposo, `_next()` elige el siguiente movimiento.
- Utilidades: `Game.world.telegraph_circle/telegraph_line`, `ring`, `burst`, `shake`, `popup_text`, `spawn_enemy_shot`, `decals`/`effects`, `AnimFx.spawn`, `_ring(n, off, spd, dmg_k, tex)`, `_in_fence`, `Player.knock`, `Sfx.play("roar"|"spit"|"charge"|"dash"|"explode"|"slash"|"freeze"|"alert"|"pop", pitch, vol_db)`.
- Daño de área: los círculos se dibujan aplastados (y×0.75): comprueba `Vector2(off.x, off.y / 0.75).length() < r`.
- Atracción: `p.knock = dir * PULL_SPEED` cada frame (la velocidad base del astronauta es 80; la atracción debe ser menor para poder resistir). `+=` no sirve: el knock decae a 700/s.
- Invulnerable mientras está bajo tierra/en el aire: sobrescribe `take_damage` y `_contact`, pon `collision_layer = 0` y `targetable = false`; restáuralos (`4`) al volver.
- Trampas de GDScript: no redeclares miembros de `Enemy` (`trail_t`, `air`, `face`, `squash`, `phase`...); evita parámetros llamados `set_name`/`name` (sombrean `Node`); las lambdas con varias líneas no admiten argumentos después, usa una `static func` auxiliar y una lambda de una línea; las lambdas diferidas (tweens/timers) no deben usar `self` del jefe (puede liberarse): llama a funciones `static`.
- Los efectos temporales que crean nodos (minas, tweens) añádelos a un grupo y libéralos en `_on_death`.

## 6. Colocación
- `world_data.gd`: normales → añádelos a los pools del mundo (`ALL`, `HIVE`, `VOID`, `SPACE`... y `*_SHOOTERS` si disparan) y/o a un evento; mini jefe → `{"at": s, "event": "boss", "id": "<id>", "label": "NOMBRE!"}` dentro de `events` de una oleada (o `"event": "boss"` de la oleada); jefe final → `"boss": "<id>"` del `survival` del mundo (+ `boss_help`).
- Elige mundo/oleada acorde al tema del arte y deja hueco entre jefes (no dos mini jefes seguidos).

## 7. Probar en el juego (Godot MCP)
1. `reload_project`, `validate_script` del script nuevo, `get_editor_errors` (si falla por un autoload nuevo, ejecuta el juego).
2. `play_scene` `res://scenes/game.tscn`; `execute_game_script`: `Game.new_run(<mundo-1>)` + `get_tree().change_scene_to_file("res://scenes/game.tscn")`.
3. Aísla la prueba: `w.survival.set_physics_process(false)`, `w.player.invuln = 9999.0`, libera los demás `enemies` y `w._spawn_boss("<id>", w.player.global_position + Vector2(100,-40), 1.0, 0.3)` (o `w.spawn_enemy`).
4. Fuerza cada ataque (`b.pattern_i = n; b.state = "drift"; b.state_t = 0.0`) y captura con `capture_frames` (resolución completa). Fuerza fases con `b.hp = b.max_hp * 0.45` / `0.15`; prueba la muerte (`b.take_damage(999999.0)`).
5. Revisa: sprites bien recortados y con el tamaño correcto, telegraphs visibles, daño solo dentro de las zonas, invulnerabilidad real, que no queden nodos huérfanos, y `get_editor_errors` sin errores nuevos. `stop_scene` al acabar.

## 8. Documentar y cerrar
- Añade un párrafo en `CLAUDE.md` (junto al resto de jefes/enemigos): arte y comandos de recorte, sets, script, ataques con sus constantes clave y fases.
- Informa al usuario: dónde se colocó, cada ataque con su contrajuego, qué se probó y qué no (equilibrio de dificultad, partida completa).
- No hagas commit salvo que lo pida.
