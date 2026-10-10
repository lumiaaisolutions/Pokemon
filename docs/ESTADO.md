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
| Mundo grande (+ 2.6 y 5.7) | Hecha | `57ee187`, `e81a792` | 4 × 4 km por zonas con semilla, 17 biomas, pueblos, ~80 lugares, interiores y mazmorras, clima y estaciones, eventos, bicicleta, montura y vuelo, opciones completas ([mundo grande](sistemas/mundo_grande.md)) |
| 2.7 | Hecha | `e81a792` | Habitantes con rutina por hora y clima, horarios de tiendas ([habitantes](sistemas/habitantes.md)); día/noche y clima ya estaban |
| Interfaz, edificios, música | Hecha | `903fed2` | Kit visual estilo Z-A, inicio, menú, Cajas, HUD ([interfaz](sistemas/interfaz.md)); modelos de B2W2 ([edificios](sistemas/edificios_b2w2.md)); música y efectos de BW/BW2 ([música](sistemas/musica_y_sonido.md)) |
| 3 | Hecha | `903fed2` | Combate en arena de 15 m en el lugar, cambio, objetos, recompensas, megaevolución ([combate](sistemas/combate.md)) |
| 4 | Hecha | `a554c0e` | Captura en la arena: carga de potencia, lanzamiento excelente, esquiva de Nate |
| 5.5 | Hecha | `b68fe8d` | Evolución sin niveles, Piedra Llave en las ruinas, misiones de megapiedras, fotografía con misiones ([progresión](sistemas/progresion.md)) |
| 5.6 | Hecha | `b68fe8d` | Entrenadores en los caminos con campo de visión, premio y revancha diaria ([entrenadores](sistemas/entrenadores.md)) |
| Pulido del mundo | Hecho (salvo regiones) | `c13a1a9` → `e3858d9` | Plan acordado tras la prueba de Fernando ([plan](plan_pulido_mundo.md)): bugs, interfaz Pokopia, mapa con zoom, tablero de misiones, NPC de BW2 con oficio y diálogo, héroes, profesor, rival, interiores B2W2, biomas, puntos de interés, pueblos con identidad |
| Regiones | Diseñada | — | 6 regiones generadas, líderes de Kanto a Teselia, Liga por región ([regiones](sistemas/regiones.md)) |
| 5.8 | Pendiente | — | Pesca, hordas y migraciones, rocas rompibles |
| 6 | Pendiente | — | Jefe y balance |
| 7 | Pendiente | — | Pulido y entrega |

## Por confirmar con Fernando
- Fase 5.8 (pesca, hordas y migraciones, rocas rompibles): detalles al empezarla.
- Fase 6: quién es el jefe del bioma y cómo se balancea la dificultad.

## Pendientes técnicos
- El mundo tarda ~2.7 s en construirse (antes 5–6.5 s): se puede agregar una pantalla de carga.
- Aviso de Godot "edge error" de navegación en las esquinas donde se juntan 4 zonas: inofensivo (las regiones sí se conectan).
- Medir FPS en el mundo grande en la Mac con calidad alta.
