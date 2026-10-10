# Herramientas y pruebas

[← Índice](README.md)

## Scripts (`tools/`)
| Script | Para qué |
|---|---|
| `setup_project.gd` | Regenera `project.godot`: autoloads, Input Map dual (26 acciones), ventana, importación pixel art, AA, sombras, navegación (`godot --headless --path . -s tools/setup_project.gd`) |
| `copy_sprites.py` + `sprites_manifest.json` | Copia y recorta los sprites del mundo y de Nate desde `sprites/` |
| `overworld_sheet.py` | Hojas overworld de B2W2 a hojas limpias |
| `build_species.py` | Las 1,025 especies (`.tres`), sus hojas normal y shiny, el grupo de iniciales y la lista completa (descarga con caché y reintentos) |
| `derived_sprites.py` | Sprites derivados (árbol muerto) |
| `make_back_sprite.py` | Espalda generada de entrenadores (ya no se usa en Nate) |
| `run_tests.sh` | Corre todas las pruebas con límite de tiempo por prueba |

## Pruebas (`tests/`, en headless)
`tools/run_tests.sh` corre todas (unos 4 min). Un error de script cuenta como fallo y no deja a Godot trabado. Solo se hace commit si todas pasan.

| Prueba | Qué comprueba |
|---|---|
| `smoke_test` | Autoloads e Input Map dual completo |
| `test_world` | El borde del agua queda bajo el terreno (nunca flota), la costa no inunda tierra adentro y existen los 4 biomas |
| `test_player_movement` | Caminar, correr, frenar, mando analógico, direcciones del sprite, colisiones con terreno, árboles y muros, que nada flote, stamina, salto, caída, nadar, bucear y ahogarse, desmayo y reaparición |
| `test_creatures` | Navegación, compañero, aparición por hábitat, tamaños y shiny, los 5 temperamentos, área de persecución, territorio, cupo por zona, manadas, esconderse, legendarios (santuarios, "?", escape corriendo y volando, sin combate) |
| `test_fights` | Tabla de tipos, enemigos clásicos hasta el aturdido y el humo, agresivo contra débil, tímido pacífico, daño al jugador, defensa y guardia del compañero (máx. 2), desmayo definitivo, emboscadas (Bicho que cae y ave tímida que se va) |
| `test_capture` | Fórmula, apuntar (cámara y arco), lanzar con física, captura exitosa y fallida, legendario marcado, mapa (exploración y pausa) |

## Medición de rendimiento
Las mediciones de FPS y tirones se hacen con scripts temporales en `tests/_tmp/` (no se versionan) a 1920×1080 en el M1.
