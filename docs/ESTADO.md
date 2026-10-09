# Estado del proyecto

Motor: Godot 4.7.2 estable (estándar, GDScript), instalado con Homebrew.

## Tabla de estado

| Fase | Estado | Commit | Notas |
|---|---|---|---|
| 0 | Hecha | ver `git log` (Fase 0: proyecto base) | `--quit` y `tests/smoke_test.tscn` en headless sin errores |
| 1 | Hecha (aprobada por Fernando el 2026-10-09) | `89ba4cc` | Nate animado, cámara libre y Pradera HD-2D con texturas de B2W2; 0 fallos; 60 FPS |
| 2 | En curso | — | Roster aprobado; compañero inicial al azar entre los básicos |
| 3 | Pendiente | — | — |
| 4 | Pendiente | — | — |
| 5 | Pendiente | — | — |
| 5.5 | Pendiente | — | Misiones, Piedra Llave, megapiedras y desbloqueos |
| 5.6 | Pendiente | — | Entrenadores NPC (GDD 10b) |
| 6 | Pendiente | — | — |
| 7 | Pendiente | — | — |

## Decisiones

- 2026-10-09: proyecto personal y privado. Se usan Pokémon reales y los sprites del paquete local `sprites/` (Pokémon Showdown).
- 2026-10-09: `sprites/` es solo fuente (con `.gdignore` y fuera de git). A `res://art/` se copian solo los sprites del roster.
- 2026-10-09: sprites gen5: `gen5ani` animado cuando existe y, si no, `gen5` estático con animación procedural. Hay 71 megas completas en estático.
- 2026-10-09: el jugador es Nate (`sprites/trainers/nate.png`).
- 2026-10-09: megaevolución una vez por combate (jugador y jefe), con Piedra Llave y megapiedra. Animación estilo X/Y.
- 2026-10-09: sin niveles ni experiencia. La progresión es por desbloqueo de habilidades y movimientos. Piedra Llave en un lugar fijo; megapiedras por misiones, en mundo abierto y sin orden obligatorio.
- 2026-10-09: se usan los 18 tipos oficiales con la tabla de efectividad oficial.
- 2026-10-09: el repo es propio, en `Pokemon/`. El repo raíz de LUMIA ya ignora esta carpeta.

## Fase 0 (proyecto base): hecha

1. `git init` en `Pokemon/`. `.gitignore` con `.godot/`, `sprites/`, `*.import` de builds y `export/`.
2. `.gdignore` en `sprites/` y en `docs/` para que Godot no los importe.
3. `project.godot` (4.7, Forward+, 1920×1080, 60 FPS) en la raíz, con la estructura de `res://` de la sección 4 del GDD más `art/pokemon/`.
4. Autoloads vacíos y tipados: `GameState`, `SaveSystem`, `InputHints` y `AudioBus`, en `core/`.
5. Input Map dual (teclado + mouse y mando): mover, cámara, correr, interactuar, esquivar, fijar objetivo, 4 ataques, capturar, apuntar, lanzar y menú.
6. Preset de importación pixel art por defecto: filtro Nearest, sin mipmaps y compresión sin pérdida.
7. Escena `tests/smoke_test.tscn`, que comprueba que los autoloads y las acciones existen y luego sale con código 0.
8. Verificar con `godot --headless --quit` y con la escena de prueba. Luego commit `Fase 0: proyecto base`.

Resultado:
- Godot 4.7.2. `project.godot` se genera con `tools/setup_project.gd` (`godot --headless --path . -s tools/setup_project.gd`).
- 23 acciones en el Input Map, cada una con teclado o mouse y con mando (incluye `mega_evolve`: G o cruceta arriba).
- Escena principal temporal: `world/main.tscn` (vacía).
- Material 3D base pixel art: `art/materials/pixel_base.tres` (Nearest).
- Prueba: `godot --headless --path . tests/smoke_test.tscn` sale con 0. La prueba negativa (una acción inexistente) sale con 1.

## Plan de la Fase 1 (jugador y Pradera en greybox)
1. Jugador `CharacterBody3D` (`world/player/`): caminar y correr relativos a la cámara, gravedad y salto desactivado; los parámetros van en un Resource `PlayerConfig.tres`.
2. Visual: `sprites/trainers/nate.png` copiado a `art/trainers/` (con un script en `tools/`), como `Sprite3D` billboard en eje Y, filtro Nearest, rebote procedural al caminar y blob shadow.
3. Cámara en tercera persona: `SpringArm3D` con pitch limitado a 35–45°, órbita con mouse (captura del cursor) y stick derecho, zoom limitado con rueda o cruceta, y suavizado.
4. Pradera greybox (`world/biomes/pradera.tscn`): terreno de unos 200×200 m con desniveles suaves, rocas y árboles low-poly con `pixel_base`, colisiones estáticas y límites invisibles.
5. `world/main.tscn` instancia la Pradera y al jugador; luz direccional y `WorldEnvironment` simple.
6. Pruebas en headless: `tests/test_player_movement.tscn` simula input (caminar, correr y mando) y comprueba desplazamiento, velocidad y que no atraviesa el terreno. Smoke test actualizado.
7. Verificación manual: abres el juego y lo pruebas con teclado y con mando. Commit `Fase 1:`.

## Fase 1: resultado
- Jugador: `world/player/` (`PlayerConfig.tres`): caminar a 4.5 m/s y correr a 8 m/s relativos a la cámara, velocidad constante en pendientes y stick analógico proporcional.
- Nate: billboard en eje Y con frente y espalda (la espalda se genera con `tools/make_back_sprite.py`), rebote al caminar y blob shadow (`Decal`).
- Cámara: `world/camera/camera_rig.tscn`. Pitch 35–45°, órbita con mouse (clic captura el cursor, Esc lo libera), stick derecho o flechas, zoom 4–11 m con rueda o cruceta.
- Pradera greybox: `world/biomes/pradera.tscn` con `BiomeConfig`. 200×200 m de terreno low-poly por ruido, con colisión exacta (trimesh), 40 rocas, 70 árboles, muros invisibles y un centro libre de 18 m.
- Sprites: `python3 tools/copy_sprites.py` regenera `art/` desde `sprites/` según `tools/sprites_manifest.json`.
- Prueba: `tests/test_player_movement.tscn`, con 15 comprobaciones: suelo, caminar, correr, frenar, frente y espalda, stick completo y a la mitad, recorrido por colinas sin atravesar el terreno, choque con un árbol y con el muro.

## Retroalimentación de la prueba manual (2026-10-09)
- La espalda generada de Nate no se ve bien. Se reemplaza por su sprite sheet overworld de B2W2 (caminar y correr en 4 direcciones).
- No hay animación de caminar ni de lado. Se resuelve con el sprite sheet overworld.
- Los árboles se ven pixeleados. Hecho: MSAA 4x + SMAA. Los árboles se reemplazan por modelos con follaje.
- La cámara no subía y no se sentía 360°. Hecho: órbita libre y pitch de -20° a 80°.
- Al mundo le faltaba estructura y textura. Primero se eligió el estilo Leyendas Arceus, pero al ver a Nate animado Fernando pidió que el mundo tuviera su mismo pixel art. Decisión final: HD-2D con gráficos de B2W2 (descargas autorizadas).
- Nate animado (hoja overworld de B2W2 de The Spriters Resource, ripeada por Dazz, "No Credit Required"): aprobado.
- Pokémon en el mundo: sprites overworld de seguidores (4 direcciones). En combate siguen gen5 / gen5ani.

## Mundo HD-2D (2026-10-09)
- Fuente: The Models Resource, B2W2 Route 01 (asset 587527), descargado en Chrome. Godot no importa bien el `.dae` ("Multiple instance_* not supported"), así que solo se usan sus texturas.
- Suelo: `world/terrain/terrain_pixel.gdshader`. Coordenadas del mundo a 17.5 px/m (igual que Nate); pasto, pasto claro, caminos de arena y tierra en pendientes, con bordes por dither de píxel; luz en escalones.
- Pinos como billboards con colisión (30 % a escala 2x). Flores, arbustos y mechones con MultiMesh sin colisión. Sprites sin sombreado (colores exactos).
- Ambiente: tonemap lineal, niebla ligera, brillo suave y desenfoque a distancia (DOF) en la cámara.
- Capas de colisión: 1 = terreno (la cámara choca), 2 = árboles y muros (solo bloquean al jugador).
- Descargados después (Chrome, con descargas múltiples permitidas por Fernando y URL directa `/media/assets/584/<id>.zip`): Floccesy Ranch, Pinwheel Forest y Twist Mountain. De ahí salen las rocas cafés, el árbol redondo y la lavanda de la Pradera.
- Apoyo en el suelo (pedido de Fernando): los sprites del mundo se recortan para que el dibujo toque su borde inferior; cada árbol, roca o decoración se apoya en la altura más baja de su base (centro y 8 puntos) y se hunde un poco (0.15 m los obstáculos, 0.05 m la decoración). Árboles y rocas llevan una sombra de contacto (Decal) que solo se proyecta sobre el terreno (los sprites van en la capa visual 2). Lo verifica una prueba que falla si algo flota (prueba negativa: detecta los 155 obstáculos subidos 0.5 m).
- Pendiente: la extensión de Chrome no tiene permiso en www.spriters-resource.com (Pokémon overworld, Fase 2).

## Recursos sugeridos por Fernando (para el arte del mundo, más adelante)
- Kenney.nl (Nature Kit, Prototype Kit) y KayKit: CC0.
- ambientCG (texturas de pasto, tierra y roca): CC0.
- Poly Pizza y OpenGameArt: la licencia varía por asset; revisar cada uno.
- Sonniss GDC Audio: licencia propia libre de regalías (no es CC0).
- Cada asset se registra en `CREDITS.md` con su URL y licencia.

## Decisiones de Fernando (2026-10-09, Fase 2)
- Roster aprobado.
- Inicial: 5 al azar de cualquier básico (no legendario); selección con huevos que eclosionan y luego Nate les lanza una Pokéball (pantalla en Fase 5). En la Fase 2 el compañero es un básico al azar.
- Evolución por desbloqueos (Fase 5.5); la mega llega con la forma final.

## Roster aprobado (los 18 tipos cubiertos, mezcla con y sin mega)
| Grupo | Pokémon | Tipos | Mega |
|---|---|---|---|
| Mundo (antes iniciales) | Venusaur | Planta/Veneno | Sí |
| Mundo (antes iniciales) | Charizard | Fuego/Volador | Sí (X e Y) |
| Mundo (antes iniciales) | Blastoise | Agua | Sí |
| Pradera | Pidgeot | Normal/Volador | Sí |
| Pradera | Ampharos | Eléctrico | Sí |
| Pradera | Sawsbuck | Normal/Planta | No |
| Pradera (rara) | Absol | Siniestro | Sí |
| Bosque/humedal | Heracross | Bicho/Lucha | Sí |
| Bosque/humedal | Swampert | Agua/Tierra | Sí |
| Bosque/humedal | Leavanny | Bicho/Planta | No |
| Bosque/humedal (rara) | Gardevoir | Psíquico/Hada | Sí |
| Montaña | Aggron | Acero/Roca | Sí |
| Montaña | Aerodactyl | Roca/Volador | Sí |
| Montaña | Excadrill | Tierra/Acero | Sí |
| Montaña (rara) | Froslass | Hielo/Fantasma | Sí |
| Jefe (bioma 3) | Garchomp | Dragón/Tierra | Sí |

Sprites verificados para los 16: mapa (pokeemerald-expansion, GitHub), frente y espalda gen5 animados, y mega.

## Plan de la Fase 2 (hierba alta y Pokémon visibles)
1. `tools/`: descarga de GitHub las hojas overworld del roster (32×32, 6 frames: abajo, arriba, lado) y las convierte a hojas de 4 direcciones con fondo transparente en `art/pokemon/<especie>/`. Créditos en `CREDITS.md`.
2. Datos: `PokemonType` (18), `SpeciesData.tres` (nombre, tipos, temperamento, rareza, velocidad, hoja overworld) y `EncounterTable.tres` de la Pradera.
3. Componente compartido `DirectionalSprite` (animación por dirección relativa a la cámara), reutilizado por Nate y por los Pokémon.
4. Hierba alta: parches con `MultiMeshInstance3D` (briznas pixel art de B2W2) que se mecen con el viento y se apartan al paso del jugador y de los Pokémon (shader con posiciones).
5. Spawner: los Pokémon aparecen visibles dentro de la hierba según la tabla de encuentro (máximo de vivos, desaparecen lejos del jugador).
6. IA salvaje (máquina de estados): deambular, curioso (se acerca), tímido (huye) y agresivo (persigue), según el temperamento de la especie.
7. Compañero: un Pokémon básico al azar (hasta que exista la selección de la Fase 5) te sigue con `NavigationAgent3D` (navmesh horneado del terreno y obstáculos), esquiva árboles y rocas, tiene idle y mira a los salvajes cercanos.
8. Pruebas en headless (spawner, IA, seguimiento) y medición de FPS con la hierba; commit `Fase 2:`.

## Pendiente de definir
- Entrenadores NPC (GDD 10b), Fase 5.6: qué recompensa dan y si vuelven a retar.
- Detalle de misiones y desbloqueos (Fase 5.5).
