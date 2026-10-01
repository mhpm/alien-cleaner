# Playground — pantalla especial de pruebas

## Mostrar u ocultar

En Godot: **Proyecto → Configuración del proyecto**, activar **Avanzado** y buscar
`playground`. Cambiar **Debug → Playground → Enabled**:

- Activado: aparece **PLAYGROUND** en la parte inferior del menú principal.
- Desactivado: desaparece el botón y se bloquea la entrada directa a las escenas.

Después del cambio, detener y volver a ejecutar el juego. Está activado ahora.
El ajuste completo es `debug/playground/enabled` (booleano).
Las exportaciones **Release** siempre ocultan el acceso, aunque el ajuste esté
activado; para probar en un dispositivo, exportar una compilación **Debug**.
No es necesario eliminar las escenas ni los scripts para publicar el juego.

## Preparar una prueba

1. Abrir **PLAYGROUND** desde el menú principal.
2. En **Enemigos**, usar **+ / −** para elegir las cantidades de cada tipo.
3. En **Jefes**, tocar **Elegir** en un jefe; volver a tocarlo para quitarlo.
4. Opcional: activar **Jugador invencible**, **Enemigos invencibles** o **Jefe invencible**.
5. Pulsar **PLAY**.

El catálogo lee todos los tipos de `EnemyData.TYPES` y muestra sus imágenes reales.
Incluye los enemigos pequeños que otros invocan. Al registrar enemigos nuevos,
aparecen automáticamente. Hay búsqueda por nombre o identificador.
El límite es 30 por tipo y 100 enemigos iniciales por prueba; las invocaciones
propias de cada enemigo siguen funcionando con sus límites habituales.

La pantalla usa el diseño azul y cian proporcionado: pestañas, buscador, tarjetas
con retrato y HP/ATQ, controles de cantidad y botón PLAY verde. Al abrirla muestra
primero UFO, UFO Gunship, UFO Scout y Zorp Drone; el resto está ordenado por nombre.
El catálogo se desplaza dentro de su panel; las opciones y PLAY quedan visibles.
El diseño completo se ajusta a la pantalla y a las zonas seguras del dispositivo.
Los cuatro retratos del ejemplo provienen de la hoja de elementos proporcionada;
los demás se obtienen de la animación de cada enemigo del juego.

Los tres interruptores son independientes y se conservan durante la sesión.
**Enemigos invencibles** impide que los enemigos normales pierdan vida, incluidas
las criaturas invocadas. **Jefe invencible** protege solamente al jefe. Conservan
su IA y ataques; las criaturas que se consumen al atacar o eclosionar mantienen
ese comportamiento. Con enemigos invencibles, la oleada no se completa por daño;
con un jefe invencible, la pelea continúa. Usar pausa → **ELEGIR ENEMIGOS** para
cambiar las opciones y volver a probar. Estos ajustes no afectan las partidas normales.

| Selección | Resultado |
| --- | --- |
| Enemigos y jefe | Una sola oleada con las cantidades exactas; al eliminarla por completo empieza el jefe elegido. |
| Solo jefe | Entrada directa a la pelea del jefe. |
| Solo enemigos | Una oleada; al limpiarla finaliza la prueba. |
| Nada | PLAY permanece desactivado. |

El jefe pelea en la arena de pruebas con su barra de vida y valla. Sus propias
invocaciones permanecen activas; no hay refuerzos ni oleadas adicionales del mundo.
Al comenzar la pelea se limpian los proyectiles y zonas peligrosas de la oleada.
La prueba usa el equipo actual, con el escalado inicial del mundo 1. Los jefes
con resistencia adaptada al DPS mantienen ese comportamiento.

Al completar la prueba, morir o pausar, se puede **REPETIR PRUEBA** o
**ELEGIR ENEMIGOS**. Las selecciones permanecen durante la sesión de la aplicación.
**Limpiar** quita todas las selecciones. La flecha superior vuelve al menú principal.

## Progreso y arquitectura

Esta modalidad no guarda monedas, XP, récords, partidas ni desbloqueos. Captura
el estado de `Game` antes de la prueba y lo restaura al salir. `Game.save()` y
`Game.end_run()` se bloquean mientras `playground_active` está activo. Las muertes
muestran el arte real y cargan el medidor de infección, pero no otorgan recompensas.

- `scenes/playground.tscn`: catálogo y selección.
- `scenes/playground_combat.tscn`: carga la escena de combate existente con los
  comportamientos específicos de pruebas; no modifica `scenes/game.tscn`.
- `scripts/playground/`: pantalla, sesión, flujo de combate y HUD de pruebas.
- `tests/playground_test.tscn`: prueba de regresión ejecutable mediante el MCP.

El arte reutilizable está en `assets/ui/playground/`. Para regenerarlo desde las
referencias conservadas en `tools/playground_ref.png` y
`tools/playground_elements_ref.png`:

```powershell
python -B tools/make_playground_assets.py
```

El extractor separa los controles y limpia los textos y contadores de ejemplo;
los nombres, cantidades, estadísticas y selección del jefe se dibujan en vivo.

Verificado en Godot 4.7.2: catálogo y botones, cantidades exactas, orden de las
fases, pruebas con solo jefe o solo oleada, resultados, desactivación del acceso
y conservación del archivo de guardado byte por byte.

```powershell
godot --headless --path . res://tests/playground_test.tscn --quit-after 600
```
