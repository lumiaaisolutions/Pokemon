# Progresión: inicial, evolución, megapiedras y fotografía (Fases 5 y 5.5, hechas)

[← Índice](../README.md)

## Sin niveles
- Las estadísticas son fijas por especie. Se progresa con victorias, vínculo, investigación, dominio de movimientos y Puntos de Entrenamiento.

## Inicial (Fase 5)
- Al empezar, **5 huevos al azar** de cualquier básico (`basic_pool.tres`: 423, sin legendarios, singulares, Ultraentes ni paradojas), sin repetir. Cada huevo lleva el patrón de color de su Pokémon.
- **Hecho (2026-10-09), decidido así por Fernando:** los 5 eclosionan a la vez frente al jugador y eliges lanzándole una Pokéball al que quieras (captura segura); los demás se van y no se vuelven a ver. Detalle en [historia y mundo](historia_y_mundo_aleatorio.md).
- Cuando exista el pueblo inicial (capa 2.6), la ceremonia pasará al laboratorio del profesor.
- Mientras tanto, el compañero es un básico al azar.

## Evolución sin niveles (Fase 5.5)
Código: `core/evolution.gd`, `world/effects/evolution_scene.gd`; datos en `creatures/data/evolutions.json` (484 caminos de PokeAPI, `tools/build_evolutions.py`).

| Método oficial | En este juego |
|---|---|
| Subir de nivel (nivel N) | **Victorias en combate** con ese Pokémon: N / 5, mínimo 2 (Bulbasaur 16 → 4) |
| Piedra u objeto | Usarlo desde la **Mochila** en tu compañero (se gasta) |
| Amistad | Vínculo 5 |
| Intercambio | Vínculo 7 |
| Otros (lugar, movimiento, clima…) | Vínculo 4 y 6 victorias |
| De día o de noche | Igual, con el reloj del juego (día de 6:00 a 18:00) |

- **Nunca evoluciona solo:** al cumplirse, al ganar sale el aviso "¡X puede evolucionar! (Menú → Pokémon)" y su ficha muestra **"✦ Evolucionar en Y"**. La ficha también muestra cada evolución posible con lo que le falta.
- Animación estilo BW: silueta blanca que alterna con la nueva forma cada vez más rápido, `bw1_evolution` y al final la fanfarria `me_evolved`.
- Conserva sus movimientos (suma los iniciales de la nueva especie), se cura y queda registrado en la Pokédex. Si es tu acompañante, se vuelve a crear en el mismo lugar (`main.refresh_companion`).

## Piedra Llave y megapiedras (Fase 5.5)
Decidido por Fernando: Piedra Llave en un lugar fijo y megapiedras por misiones de especie, avisadas en el Rotom.
- **Piedra Llave:** la da el **primer acertijo de Ruinas Antiguas** que resuelvas (tres piedras en orden). El Rotom da la pista.
- **Misiones de megapiedra** (`core/mega_missions.gd`): cuando en tu equipo hay un Pokémon que puede llegar a megaevolucionar (él o su línea evolutiva), se abre su misión, sale en el Rotom (sección Megapiedras y noticias) y en un aviso. Tres tipos, fijos por especie:
  - **Capturar** 2 más de esa especie.
  - **Completar su investigación** (100 puntos).
  - **Vencer en combate a su Alfa o dominante.**
- Al cumplirla: la megapiedra (`stone-<mega>`), la fanfarria `me_mission_clear` y el logro de megapiedras.

## Fotografía (Fase 5.5)
Código: `world/photo/photo_mode.gd`.
- **P** (o el botón Compartir del mando) saca una foto: se oculta la interfaz, se guarda en `user://fotos/` y hay un destello.
- Cuentan los Pokémon en el 70 % central del cuadro, a menos de 35 m y sin nada que los tape: suman a la tarea de investigación **"Fotografiarlo"**.
- **Misión del día** en el Rotom: retratar a una especie que anda cerca; da $800 y un objeto. Logro con 25 fotos.

## Investigación
Tareas por especie: encuentros, capturas, por la espalda, verlo pelear, verlo debilitado, **vencerlo en combate** y **fotografiarlo**. Completa con 100 puntos.

## Entrenadores (Fase 5.6)
Ver [entrenadores](entrenadores.md).
