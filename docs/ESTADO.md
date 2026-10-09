# Estado del proyecto

Motor: Godot 4.7.2 estable (estándar, GDScript), instalado con Homebrew.

## Tabla de estado

| Fase | Estado | Commit | Notas |
|---|---|---|---|
| 0 | Hecha | ver `git log` (Fase 0: proyecto base) | `--quit` y `tests/smoke_test.tscn` en headless sin errores |
| 1 | Pendiente | — | — |
| 2 | Pendiente | — | Antes de empezar: aprobar el roster de 15 Pokémon (con y sin mega) |
| 3 | Pendiente | — | — |
| 4 | Pendiente | — | — |
| 5 | Pendiente | — | — |
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

## Pendiente de definir antes de la Fase 1
- Plan de la Fase 1 (requiere tu confirmación).
- En qué fase entran la Piedra Llave, las megapiedras, las misiones y los desbloqueos de habilidades (sección 10 del GDD).
