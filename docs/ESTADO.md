# Estado del proyecto

Motor: Godot 4.7.2 estable (estándar, GDScript), instalado con Homebrew.

## Tabla de estado

| Fase | Estado | Commit | Notas |
|---|---|---|---|
| 0 | Hecha | ver `git log` (Fase 0: proyecto base) | `--quit` y `tests/smoke_test.tscn` en headless sin errores |
| 1 | En curso: mundo HD-2D | `362778e` (greybox) | Nate animado con su hoja de B2W2, aprobado por Fernando. Falta: mundo en pixel art de B2W2 |
| 2 | Pendiente | — | Antes de empezar: aprobar el roster de 15 Pokémon (con y sin mega) |
| 3 | Pendiente | — | — |
| 4 | Pendiente | — | — |
| 5 | Pendiente | — | — |
| 5.5 | Pendiente | — | Misiones, Piedra Llave, megapiedras y desbloqueos |
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

## Recursos sugeridos por Fernando (para el arte del mundo, más adelante)
- Kenney.nl (Nature Kit, Prototype Kit) y KayKit: CC0.
- ambientCG (texturas de pasto, tierra y roca): CC0.
- Poly Pizza y OpenGameArt: la licencia varía por asset; revisar cada uno.
- Sonniss GDC Audio: licencia propia libre de regalías (no es CC0).
- Cada asset se registra en `CREDITS.md` con su URL y licencia.

## Pendiente de definir
- Detalle de misiones y desbloqueos (Fase 5.5).
