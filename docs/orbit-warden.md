# Orbit Warden — jefe y enemigo para futuros mundos

Implementado a partir de `tools/orbit_warden_ref.png` (hoja transparente original).
Los tres tipos están registrados en `EnemyData.TYPES`. No se han añadido a las
oleadas ni se ha sustituido el jefe de ningún mundo actual.

| Tipo | Uso | Comportamiento |
| --- | --- | --- |
| `orbit_warden` | Jefe final o minijefe | Salvas de plasma, rayos sobre el suelo, invocaciones y furia bajo el 50% de vida. |
| `orbit_raider` | Enemigo de horda | Un proyectil por ataque y un rayo pequeño cada tercer ataque. Sin invocaciones, furia ni protección de jefe. |
| `orbit_spawn` | Criatura invocada | Persigue y golpea por contacto. También se puede usar en un pool. |

## Ataques y límites

- **Plasma:** el jefe lanza dos salvas de cinco proyectiles. En furia, tres de siete.
  La dirección se fija al aparecer el aviso, permitiendo esquivar. El Raider lanza
  un único proyectil más lento y descansa entre 2.8 y 4 segundos.
- **Rayo de suelo:** objetivo fijo, aviso verde, erupción y un solo golpe. El jefe
  marca dos zonas (tres en furia), de radio 28 y con 1.1 segundos de aviso.
  El Raider marca una zona de radio 17, con 1.35 segundos de aviso y daño reducido.
  La velocidad de ataque del mundo no reduce este tiempo de aviso.
- **Invocación:** tres criaturas, cuatro en furia, con un límite de seis vivas
  por jefe. Su dureza sigue el escalado de Survival. El Raider nunca invoca.
- **Resistencia:** jefe con 2600 HP de base, escalado al daño del jugador como los
  otros jefes finales y límite del 2.5% de la vida por impacto. Raider con 58 HP
  de base, daño recibido normal, congelación, aturdimiento y variante élite estándar.
- **Muerte:** animación de cúpula rota y restos de goo. Se cancelan los rayos,
  proyectiles e invocaciones propios; no se borran ataques de otros enemigos.

## Añadirlo a un mundo

En la configuración `survival` del futuro mundo:

```gdscript
"boss": "orbit_warden",
"boss_help": {"pool": ["orbit_raider", "orbit_spawn"], "max": 6,
    "every": [16.0, 9.0], "squad": 2},
```

Para una oleada de horda, añadir `orbit_raider` al `pool` correspondiente:

```gdscript
{"pool": ["slime", "runner", "orbit_raider"], "alive": 24, "rate": 2.5},
```

Para un evento de minijefe:

```gdscript
{"at": 12.0, "event": "boss", "id": "orbit_warden", "label": "ORBIT WARDEN!"},
```

El perfil del jefe mantiene la resistencia de un jefe final: ajustar `hp` y el
tiempo de escalado en `boss_orbit_warden.gd` si se desea una pelea más corta.
El Raider cuenta como enemigo que dispara para el límite de tiradores de Survival.
Ambos flotan: el peligro está en sus ataques; las criaturas pequeñas sí hacen daño
por contacto. El ciclo habitual `_spawn_boss` / HUD / BossFence funciona con su ID.

## Archivos y reconstrucción

- `scripts/enemies/orbit_raider.gd`: comportamiento compartido y límites por perfil.
- `scripts/enemies/boss_orbit_warden.gd`: resistencia exclusiva del jefe.
- `scripts/fx/orbit_strike.gd`: aviso, impacto único y cancelación del rayo.
- `tools/make_orbit_warden_assets.py`: recortes de la hoja y reconstrucción selectiva.
- `tools/slice_sprites.py`: definición de animaciones y anclas.

```powershell
python tools/make_orbit_warden_assets.py
```

Conserva los demás sets del manifest. Después, reescanear el proyecto en Godot y
reiniciar el juego para recargar la caché de `Art`.

## Verificación

Godot 4.7.2, mediante el MCP: validación de los tres scripts, comprobación visual
en el juego y prueba automatizada con salida `ORBIT_WARDEN_TEST: PASS`.

```powershell
godot --headless --path . res://tests/orbit_warden_test.tscn --quit-after 300
```

La prueba comprueba texturas, perfiles, límite por golpe, reducción de las salvas,
límite de invocaciones, zonas fijas, esquiva, impacto único, furia y limpieza al
morir. Ejecuta una partida aislada con el procesamiento detenido, sin recoger
recompensas ni guardar progreso.
