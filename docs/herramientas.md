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
| `build_evolutions.py` | Genera `creatures/data/evolutions.json` (métodos de evolución de PokeAPI) |
| `run_tests.sh` | Corre todas las pruebas con límite de tiempo por prueba |
| `protagonist_sheets.py` | Las 10 hojas de personajes jugables al formato de Nate (`--debug` guarda hojas numeradas) |
| `build_dex_info.py` | Datos de la Pokédex (categoría, descripción, altura, peso, sexo), sprites de frente Gen 5 y gritos de PokeAPI |
| `copy_item_icons.py` | Íconos de los objetos del catálogo (`creatures/data/items.json`) |
| `build_moves.py` | Movimientos (nombre en español, tipo, potencia, clase, efecto) y la lista oficial de cada especie |
| `build_megas.py` | Catálogo de las 97 megas (`creatures/data/megas/`, `all_megas.tres`) y sus sprites de combate Gen 5 |
| `snapshot.tscn` | Captura de pantalla con el render real. Opciones: `desmayo`, `arriba`, `borde`, `cima`, `ayuda`, `surf`, `barra`, `menu:N`, `hora:H`, `pueblo`, `vuelo`, `interior:<tipo>` (center, mart, cave, sewer…), `clima:N` y `lugar:<tipo>` (ranch, league, grotto…) |

## Pruebas (`tests/`, en headless)
`tools/run_tests.sh` corre todas (unos 8 min). Un error de script cuenta como fallo y no deja a Godot trabado. Solo se hace commit si todas pasan.

| Prueba | Qué comprueba |
|---|---|
| `smoke_test` | Autoloads, Input Map dual completo, 10 personajes (5 y 5) con su hoja, escena inicial, dificultad Normal por defecto y catálogo de megas con Mega Greninja |
| `test_world` | Mundo grande: el borde de ríos y lagos queda bajo el terreno, tierra adentro nunca bajo el mar, familias de suelo y 17 biomas, pueblos, caminos, ríos, lagos, cuevas por pares y lugares; la misma semilla repite el mundo y otra lo cambia; 5 × 5 zonas con colisión; interiores con suelo plano |
| `test_player_movement` | Caminar, correr, frenar, mando analógico, direcciones del sprite, colisiones con terreno, árboles y muros, que nada flote, stamina, salto, caída, nadar, bucear y ahogarse, desmayo y reaparición |
| `test_creatures` | Navegación, compañero, aparición por hábitat, tamaños y shiny, los 5 temperamentos, área de persecución, territorio, cupo por zona, manadas, esconderse, legendarios (santuarios, "?", escape corriendo y volando, sin combate) |
| `test_fights` | Tabla de tipos, enemigos clásicos hasta el aturdido y el humo, agresivo contra débil, tímido pacífico, daño al jugador, defensa y guardia del compañero (máx. 2), control del compañero con el jugador desmayado (cámara, ataque especial, esquivar), desmayo definitivo, emboscadas (Bicho que cae y ave tímida que se va) |
| `test_starter` | Ceremonia del inicial: 5 básicos distintos, quietos, sin salvajes; la Pokéball siempre captura, el elegido es el compañero y entra al equipo, los demás se van |
| `test_menu` | Movimientos (inicio, dominio, desbloqueo, estilos, curación al entrenador), Rotom Móvil (actividades, premios, plazos vencidos), recolección, día y noche, mochila y balls (cambio, multiplicadores, aviso sin balls), objetos, fabricación, Pokédex e investigación, premios, áreas propias, guardar y cargar, pestañas del menú y cambio de acompañante |
| `test_battle` | Combate en arena: inicio, mundo en pausa, huida, victoria con racha, investigación y vínculo, cambio con espera, megaevolución con Piedra Llave, captura con carga y lanzamiento excelente, esquiva, evolución (victorias, piedra y animación), misiones de megapiedra, foto y entrenadores de camino |
| `test_town` | Nombre del lugar en el HUD, Centro Pokémon (entrar, curar, salir a la puerta), tienda y MT, cueva por pares, gimnasio con medalla, guardería, lugar que cura, habitantes y su rutina, tienda cerrada de noche, acertijo de las ruinas, comerciante, huerto, profesor (bicicleta, licencia y fósil), mina, clima y estaciones, brote masivo, bicicleta, montura y vuelo, reasignar botones, daltonismo y el mapa de la región |
| `test_capture` | Fórmula, apuntar (cámara y arco), lanzar con física, captura exitosa y fallida, legendario marcado, mapa (exploración y pausa) |

## Medición de rendimiento
Las mediciones de FPS y tirones se hacen con scripts temporales en `tests/_tmp/` (no se versionan) a 1920×1080 en el M1.
