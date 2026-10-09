# Prompt maestro — Demo de juego de criaturas en mundo abierto (Godot 4, macOS)

> Uso: guarda este archivo en la raíz del repo como `docs/GDD.md`.
> Primera instrucción a Claude Code: "Lee docs/GDD.md completo y ejecuta la Fase 0. No avances de fase sin mi confirmación."

---

## 1. Rol y forma de trabajo

Eres un desarrollador senior de videojuegos en Godot 4 (GDScript tipado). Construyes un **demo personal** (fan game de uso privado, no se publica) para macOS (Apple Silicon, M1 o superior).

Reglas de trabajo:
- Trabaja **una fase a la vez**, en el orden de la sección 11. No adelantes sistemas de fases futuras.
- Antes de cada fase, escribe un plan breve (máx. 10 líneas) en `docs/ESTADO.md` y espera mi confirmación.
- Al cerrar cada fase: corre el proyecto en headless (`godot --headless --quit` + escenas de prueba) sin errores, actualiza la tabla de estado en `docs/ESTADO.md` y haz commit con el prefijo `Fase N:`.
- Verifica la versión de Godot instalada (`godot --version`) y usa la última 4.x estable. No asumas APIs: si dudas, consulta la documentación de esa versión.
- Si una decisión no está en este documento, pregúntame. No inventes alcance.

## 2. Visión

Juego de exploración y colección de criaturas en mundo abierto, en tercera persona. Las criaturas salvajes se ven deambulando por la hierba alta. El combate es **en tiempo real y a campo abierto**, en el mismo lugar donde ocurre el encuentro. La captura es **en primera persona**: apuntas, lanzas la esfera con física real y esquivas los ataques de la criatura.

**Ciclo principal (debe funcionar completo antes de expandir contenido):**
Explorar → ver criatura en la hierba → contacto → combate en tiempo real controlando a tu criatura → debilitarla → cambiar a primera persona → lanzar esfera y esquivar → captura → se une al equipo y te sigue por el mundo.

## 3. Dirección de arte (HD-2D con gráficos de Negro 2/Blanco 2)

- **Mundo (decisión final 2026-10-09): HD-2D con gráficos de Pokémon Negro 2/Blanco 2.** El mundo usa el mismo pixel art que Nate: texturas y tiles de B2W2 en el suelo 3D (pasto, hierba alta, caminos, agua), árboles, rocas y props como sprites billboard o modelos con texturas de B2W2, filtro `Nearest`, luz suave, profundidad de campo y niebla ligera. Se descarta el estilo naturalista de Leyendas Arceus.
- **Sprites (personajes y Pokémon):** preset pixel art: filtro `Nearest`, sin mipmaps, sin compresión con pérdida.
- **Criaturas y NPCs:** sprites 2D animados como billboards (billboard solo en eje Y) dentro del mundo 3D, con sombra proyectada simple (blob shadow).
- **Cámara de exploración:** tercera persona con órbita libre de 360° en horizontal y pitch de -20° (mirar al cielo) a 80° (casi cenital), con zoom limitado.
- **Decisión (2026-10-09):** proyecto personal y privado. Se usan Pokémon reales (nombres y sprites) tomados del paquete local `sprites/` (dump de Pokémon Showdown). El juego y sus assets no se publican ni se distribuyen.
- **Fuente de sprites:** `sprites/` es solo fuente: lleva `.gdignore` (Godot no la importa) y está fuera de git. Un script copia a `res://art/` únicamente los sprites del roster, y eso sí se versiona.
- Otros assets de terceros (modelos, texturas, audio) solo con licencia **CC0**, registrados en `CREDITS.md` con URL y licencia.

### Formato de sprites
| Uso | Fuente | Presentación |
|---|---|---|
| Criatura en mundo | Sprites *overworld* de seguidores (paquete de la comunidad, 4 direcciones con caminar) | Billboard en eje Y; la dirección mostrada (frente, espalda, izquierda, derecha) depende del movimiento respecto a la cámara |
| Criatura en combate | La misma regla (animado con respaldo estático) | Frente y espalda; estados (ataque, daño, debilitado) por animación procedural (escala, tinte, sacudida) |
| Variocolor | `gen5-shiny`, `gen5-back-shiny`, `gen5ani-shiny`, `gen5ani-back-shiny` | Igual que la forma normal |
| Megaevoluciones | 71 megas completas (frente y espalda) en `gen5`/`gen5-back`; animadas solo 26 de frente y 11 de espalda | Animado con respaldo estático |
| Íconos (menús) | `gen5icons` (no hay de megas; no hacen falta porque la mega se revierte al terminar el combate) | — |
| Jugador | Sprite sheet *overworld* de Nate de Negro 2/Blanco 2 (caminar y correr en 4 direcciones) | Billboard en eje Y con animación por dirección relativa a la cámara |

Godot no importa GIF: un script convierte cada GIF animado a sprite sheet PNG y normaliza la escala.

Cambiar el sprite de una criatura debe requerir solo reemplazar las texturas en su Resource.

## 4. Requisitos técnicos

- Godot 4.x, GDScript con tipos estáticos, escenas `.tscn` y datos en Resources `.tres`.
- **Data-driven:** criaturas, movimientos, tipos, tablas de encuentro y objetos viven en Resources, nunca hardcodeados.
- **Input:** teclado + mouse y mando (Xbox/PlayStation) funcionando a la vez desde el Input Map. La UI cambia los íconos de botones según el último dispositivo usado.
- **Rendimiento objetivo:** 60 FPS estables a 1080p en M1. La hierba usa `MultiMeshInstance3D`.
- **Estructura:**
```
res://
  core/        (autoloads: GameState, SaveSystem, InputHints, AudioBus)
  world/       (biomas, terreno, hierba, spawners)
  creatures/   (data/*.tres, scenes, ai)
  combat/      (arena, hitboxes, proyectiles, fórmulas)
  capture/     (modo primera persona, esferas, probabilidad)
  ui/
  art/placeholders/
  tests/
docs/  (GDD.md, ESTADO.md)
```

## 5. Sistemas de datos

**Tipos (18):** los oficiales de Pokémon (Normal, Fuego, Agua, Planta, Eléctrico, Hielo, Lucha, Veneno, Tierra, Volador, Psíquico, Bicho, Roca, Fantasma, Dragón, Siniestro, Acero, Hada). Tabla de efectividad oficial en un Resource (×2, ×1, ×0.5, ×0), con doble tipo.

**Stats por criatura:** PS, Ataque, Defensa, At. Especial, Def. Especial, Velocidad, Stamina. **Sin niveles ni experiencia:** las stats son fijas por especie (todo parejo). La progresión es por desbloqueo de habilidades y movimientos (ver sección 10).

**Movimientos:** cada criatura equipa 4.
- **Físico:** hitbox cuerpo a cuerpo o embestida, corto alcance.
- **Especial:** proyectil, cono o área en el suelo con indicador visible.
- Campos: tipo, categoría, poder, coste de stamina, cooldown, alcance, tiempo de preparación (telegraph).

**Roster del demo (15):** Pokémon reales; la lista se propone y aprueba antes de la Fase 2.
- Iniciales (decisión 2026-10-09): **no son fijos**. Al empezar una partida se ofrecen **5 Pokémon al azar** de cualquier especie en fase básica (no legendarios ni singulares), sin repetir. Selección con **huevos que eclosionan**: 5 huevos con el patrón de color de cada Pokémon; el seleccionado se mece y, al confirmar, se agrieta y eclosiona con partículas. Luego Nate **le lanza una Pokéball** para hacerlo su inicial (animación de lanzamiento y captura). Pantalla de selección: Fase 5 (UI).
- Venusaur, Charizard y Blastoise quedan en el roster como Pokémon del mundo.
- Bioma 1: 4 criaturas (1 rara).
- Bioma 2: 4 criaturas (1 rara).
- Bioma 3: 4 criaturas (1 rara).

## 6. Mundo abierto

- **3 biomas conectados sin pantallas de carga:** Pradera (inicio), Bosque/humedal y Zona rocosa/montaña. Usa carga por zonas (streaming) si hace falta.
- **Hierba alta:** reacciona al paso del jugador y de las criaturas. Las criaturas aparecen **visibles** en la hierba según la tabla de encuentro del bioma.
- **IA de criaturas salvajes** (máquina de estados): deambular, curiosa (se acerca), tímida (huye), agresiva (persigue). Cada especie tiene su temperamento.
- **Compañero:** tu criatura líder te sigue con NavigationAgent3D, esquiva obstáculos, tiene animaciones idle y reacciona a criaturas salvajes cercanas.

## 7. Combate en tiempo real

- **Inicio:** al contacto, se genera una arena circular (~15 m de radio) en ese mismo punto, con un borde visual. El mundo alrededor se pausa y la cámara pasa detrás de tu criatura.
- **Control directo de tu criatura:** moverse, esquiva con dash (frames de invulnerabilidad y coste de stamina), fijar objetivo (lock-on) y 4 movimientos asignados a botones.
- **IA salvaje:** telegrafía sus ataques con un indicador en el suelo y tiempo de preparación. Su agresividad depende del temperamento de la especie y de su rareza (no hay niveles).
- **Daño:** fórmula basada en stats, poder, efectividad de tipo, STAB (×1.5) y variación aleatoria (0.85–1.0).
- **Salidas:** huir (saliendo del borde con cooldown), victoria (sin experiencia; recompensa por definir, ver sección 10) o pasar a captura.
- **Captura:** botón disponible en cualquier momento del combate; se recomienda cuando la salvaje tiene <25% de PS.

## 8. Captura en primera persona

- La cámara cambia a primera persona del entrenador dentro de la misma arena, y tu criatura queda en espera.
- **Lanzamiento:** retícula, carga de potencia (mantener y soltar) y esfera como `RigidBody3D` con trayectoria parabólica. Solo cuenta si golpea la hitbox de la criatura.
- La criatura **sigue moviéndose y atacando al entrenador**: el jugador puede desplazarse lateralmente y esquivar. El entrenador tiene una barra de aguante y si llega a cero vuelve al combate normal.
- **Probabilidad de captura:** según % de PS restante, rareza y tipo de esfera. Animación de 3 sacudidas.
- **Fallo:** la criatura escapa y se reanuda el combate o la captura.
- **Éxito:** entra al equipo (máx. 6) y puede ser tu compañero en el mundo.

## 9. Megaevolución

- **Quién:** el Pokémon del jugador y el jefe del bioma 3. Los salvajes normales no megaevolucionan.
- **Frecuencia:** una vez por combate. Al terminar el combate (victoria, huida o captura) el Pokémon vuelve a su forma normal.
- **Roster mixto:** hay Pokémon con mega y sin mega; con los que no tienen, la acción de megaevolucionar está desactivada.
- **Requisitos:** el jugador tiene la **Piedra Llave** y el Pokémon lleva equipada **su megapiedra**.
- **Animación estilo X/Y (2.5–3 s, el combate se pausa):** rayo de la Piedra Llave a la megapiedra, esfera de luz arcoíris que envuelve al Pokémon, destello blanco y aparición de la mega con su símbolo. Se hace con partículas y shaders (no viene en el paquete de sprites).

## 10. Progresión y misiones (mundo abierto, sin orden obligatorio)

- **Piedra Llave:** se consigue en un lugar específico del mundo.
- **Megapiedras:** una por especie, repartidas en distintos lugares; se obtienen con misiones. No hay un orden obligatorio: todo es mundo abierto.
- **Sin niveles:** se desbloquean habilidades y movimientos: de esquiva (para evadir ataques) y de ataque (lanzar o golpear).
- **Evolución por desbloqueos (decisión 2026-10-09):** los Pokémon evolucionan al completar misiones o desbloqueos, no por nivel. Al llegar a su forma final pueden megaevolucionar si tienen megapiedra.
- Entra en la **Fase 5.5** (ver sección 11). Detalles por definir con Fernando: qué desbloquea cada habilidad, cómo se gana y tipos de misión.

## 10b. Entrenadores NPC (pedido de Fernando, 2026-10-09)

- Hay entrenadores en el mundo, cada uno con su equipo de Pokémon acorde al área o zona y a su contexto (por ejemplo, un Montañero con Pokémon de roca en la montaña). Como no hay niveles, la dificultad sube por zona: mejores especies, más Pokémon, IA más agresiva y megaevolución en entrenadores de élite.
- **Combate al pasar frente a ellos:** cada entrenador tiene un campo de visión. Si el jugador entra en él, el entrenador lo ve (exclamación), se acerca y empieza el combate en tiempo real en ese lugar, usando la misma arena del combate salvaje.
- **Caminan como NPC con su propia aventura:** no están fijos. Recorren rutas entre puntos de interés del mundo abierto, descansan, combaten Pokémon salvajes y avanzan por su cuenta. Usan sprites overworld de B2W2.
- Al derrotarlos no vuelven a retar (o vuelven tras un tiempo, por definir). La recompensa no es experiencia, porque no hay niveles: por definir con Fernando (dinero, objetos o progreso de desbloqueos).
- **Fase 5.6** (decidida por Claude a pedido de Fernando): necesita el combate (Fase 3), la captura (Fase 4) y el equipo con guardado (Fase 5), y conviene antes de la Fase 6 para que los biomas 2 y 3 se poblen con entrenadores desde el inicio. Recompensa y si vuelven a retar: por definir con Fernando al planear la fase.

## 11. Fases y criterios de "hecho"

| Fase | Entregable | Hecho cuando… |
|---|---|---|
| 0 | Proyecto base | Estructura de carpetas, autoloads vacíos, Input Map dual, import preset pixel art, `ESTADO.md` creado, repo con commit inicial |
| 1 | Jugador y bioma 1 en greybox | El jugador camina y corre con teclado y con mando, la cámara de 3ª persona funciona, y el terreno de la Pradera tiene colisiones |
| 2 | Hierba y criaturas visibles | Hierba con MultiMesh a 60 FPS, 4 criaturas placeholder con IA deambulando y el inicial siguiéndote |
| 3 | Combate en tiempo real | Arena en el lugar del encuentro; se pueden usar ataques físicos y especiales, esquivar y hay efectividad de tipos; ganar y huir funcionan |
| 4 | Captura en 1ª persona | Lanzamiento con física, esquiva, probabilidad, éxito y fallo; la criatura capturada aparece en el equipo |
| 5 | Equipo, inventario, UI y guardado | Menú de equipo, cambio de compañero, inventario de esferas y curación, bitácora de criaturas vistas/capturadas, guardar y cargar |
| 5.5 | Misiones y progresión | Piedra Llave en su lugar fijo, megapiedras por misiones en cualquier orden y desbloqueo de habilidades y movimientos (esquiva y ataque). Antes de esta fase, la mega se prueba con los objetos equipados en modo debug |
| 5.6 | Entrenadores NPC | Entrenadores con equipo según su zona, campo de visión que inicia el combate, rutas propias por el mundo abierto (su "aventura") y estado de derrotado guardado |
| 6 | Biomas 2–3 y roster completo | 3 biomas conectados, 15 criaturas con sus movimientos, 1 criatura jefe al final del bioma 3 |
| 7 | Pulido y entrega | Audio, partículas, transiciones, export macOS (arm64), build firmada ad-hoc para uso personal |

**Regla:** al terminar la Fase 4 el ciclo principal debe poder jugarse de punta a punta. Si algo de las Fases 5–7 lo pone en riesgo, se recorta contenido, no el ciclo.
