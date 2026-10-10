# Estado del proyecto

[← Índice](README.md) · Motor: Godot 4.7.2 estable (GDScript), macOS M1. Actualizado: 2026-10-10.

## Fases
| Fase | Estado | Commit | Notas |
|---|---|---|---|
| 0 | Hecha | `1f40246` | Proyecto base |
| 1 | Hecha (aprobada) | `89ba4cc` | Nate animado, cámara libre, Pradera HD-2D |
| 2 | Hecha (aprobada) | `33a8792` | Hierba alta, salvajes con IA, compañero al azar |
| 2.5 | Hecha (probada) | `cadf095` | 3 biomas con agua, aparición por hábitat, shiny, persecución con stamina |
| 2.8 / 2.8+ / 2.8++ | Hechas | ver `git log` | Mundo vivo, peleas, emboscadas, captura, mapa; correcciones de las pruebas de Fernando |
| 2.9 | Hecha | `bbd3553` y anteriores | Personaje (10), nombre y dificultad; menú, mochila, Pokédex, caja, guardado, opciones; inicial con huevos; Rotom; día y noche; movimientos sin niveles |
| Mundo grande (+ 2.6 y 5.7) | Hecha | `57ee187` y el siguiente | 4 × 4 km por zonas con semilla, 17 biomas, pueblos, ~80 lugares, interiores y mazmorras, clima y estaciones, eventos, bicicleta, montura y vuelo, opciones completas ([mundo grande](sistemas/mundo_grande.md)) |
| 2.7 | Hecha | el siguiente | Habitantes con rutina por hora y clima, horarios de tiendas ([habitantes](sistemas/habitantes.md)); día/noche y clima ya estaban |
| 3 | Pendiente | — | Combate en tiempo real (el combate en el mundo ya existe; falta el modo de combate formal y la megaevolución) |
| 4 | Pendiente | — | Captura en combate |
| 5.5 | Pendiente | — | Misiones, Piedra Llave, megapiedras, desbloqueos |
| 5.6 | Pendiente | — | Entrenadores NPC que retan en los caminos |
| 5.8 | Pendiente | — | Pesca, hordas y migraciones, rocas rompibles |
| 6 | Pendiente | — | Jefe y balance |
| 7 | Pendiente | — | Pulido y entrega |

## Por confirmar con Fernando
- Entrenadores NPC (5.6): recompensa y si vuelven a retar.
- Misiones y desbloqueos (5.5): qué desbloquea cada habilidad, cómo se gana y tipos de misión.
- Combate formal (3): si se mantiene el combate en el mundo como único o se agrega un modo de combate aparte.

## Pendientes técnicos
- El mundo tarda ~2.7 s en construirse (antes 5–6.5 s): se puede agregar una pantalla de carga.
- Aviso de Godot "edge error" de navegación en las esquinas donde se juntan 4 zonas: inofensivo (las regiones sí se conectan).
- Medir FPS en el mundo grande en la Mac con calidad alta.
