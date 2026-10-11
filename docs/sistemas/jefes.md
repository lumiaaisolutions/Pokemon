# Jefes y dificultad adaptable (Fase 6)

[← Índice](README.md) · Decisión de Fernando (ver [plan_pulido_mundo.md](../plan_pulido_mundo.md#últimas-decisiones-antes-de-la-noche-fernando-2026-10-10)): guardianes por bioma, el líder del equipo villano al final, y dificultad que se adapta sola a cómo vas jugando. Hecho el 2026-10-11.

## Guardianes de bioma
`core/bosses.gd` (`Bosses`, datos y reglas puras) + `world/bosses/boss_manager.gd` (`BossManager`, el nodo que los crea y los vigila en el mundo).

- **Uno por bioma presente en la región** (de los 16; el mar no tiene guardián, ver "Decisiones" abajo), en el punto de ese bioma más alejado de cualquier pueblo (su "zona más difícil"): al llegar la región escanea una rejilla de 160 m sobre los 4 × 4 km y guarda, por bioma, el punto más lejano de un asentamiento.
- **Especie:** un Pokémon evolucionado del tipo de ese bioma (`Bosses.GUARDIAN_TYPE`, sin repetir tipo entre biomas), al azar por la semilla de la región entre los 5 más fuertes de su tipo (evolución final si existe alguna); puede ser de fuera de la Pokédex regional si no hay uno fuerte dentro de ella.
- **Enorme y fuerte:** escala ×2 a ×3 según la región (`Bosses.size_scale`) y de 2,4 a casi 4 veces la vida normal (`Bosses.hp_scale`); reaparece más grande y con más vida en cada región siguiente. Aura de su tipo (luz de color) y marcado con `set_meta("guardian", true)`.
- **Aparece** cuando te acercas a 90 m de su guarida (como los Territorios Alfa); vive ahí hasta que lo vences. Al aparecer, noticia del Rotom y aviso en pantalla.
- **Fases:** al bajar de 66 % y 33 % de vida invoca 1 y 2 ayudantes salvajes del mismo bioma (se suman a la horda del combate, pelean a la vez contra tu compañero) y ataca más seguido (el intervalo entre ataques en área baja de fase en fase, `Bosses.phase_interval`).
- **Ataques en área telegrafiados:** un círculo (o, en la fase 3, a veces una línea) rojo que se encoge en el suelo donde estaba tu compañero al lanzarse (`PokemonActor.telegraph_zone` / `telegraph_line`, la misma idea que el aviso de un golpe normal, `_telegraph`, pero más grande). Si te quedas ahí cuando se cumple, recibe daño; si sales de la zona antes, 0 de daño (`Bosses.circle_hit` / `segment_hit`). Esto es aparte de sus ataques normales de combate.
- **Premio único al vencerlo:** su insignia de recuerdo (una por bioma, objeto clave registrado en `Items` al cargar, `Bosses.crest_item_id`) y una piedra evolutiva de su tipo si existe una (si no, un Caramelo Raro), además de dinero (`Bosses.reward_money`). Queda **registrado por región** (`Bosses._flags`, dentro de `GameState.world_flags`, que ya se guarda por región al cambiar de región) para que no vuelva a aparecer ahí, aunque sí en la región siguiente.
- **Brújula del Rotom:** la categoría "Guardián de bioma" (antes usaba los Territorios Alfa como aproximación, ver `decisiones_sin_preguntar.md`) marca cada guarida de la región con su estado (vencido o no).

## Líder del equipo villano (jefe final de la región)
`world/region/town_services.gd` (`villain_confront`, `_villain_battle`, `_win_villain`, `_region_epilogue`), reemplaza al antiguo `villain_challenge` (un combate de reto simple sin IA ni mega).

- La base secreta (una por región, `world/region/structures.gd` y `region_layout.gd`) solo se puede retar de verdad **tras avanzar bastante por los caminos de la región**: con menos de `VILLAIN_BADGE_GATE` (4 de 8) medallas, un guardia rechaza el reto.
- Con medallas suficientes, el líder habla antes del combate (caja de diálogo, igual que un líder de gimnasio) y, si aceptas, el combate es un **combate de entrenador de verdad** (`TownServices._challenge`, el mismo camino que gimnasio y Liga: IA lista que esquiva y se cura, megaevolución si su equipo tiene una del tipo Siniestro o Veneno y la región ya la permite).
- Al vencerlo: la reputación sube, las zonas tomadas por el equipo se liberan, el emblema único del equipo villano (`villain-emblem`) y dinero (parte del combate normal), y un **epílogo corto de la región** (caja de diálogo con el cierre de la amenaza y un resumen de medallas/Campeón; no hay cinemática nueva, ver "Decisiones").

## Dificultad adaptable
`core/difficulty.gd` (`AdaptiveDifficulty`), encima de la dificultad que ya elige Fernando en Opciones (`GameState.difficulty` / `DIFFICULTIES`, que no cambia).

- Un valor continuo `GameState.performance` (-1 floja a +1 arrolladora, guardado con la partida) sube con una victoria con vida alta y racha (`BattleManager._win`) y con capturas fáciles (sigilo o casi sin pelear, `PokeballProjectile.start_capture`); baja con un desmayo (`main.gd`, `_on_blacked_out`).
- A rendimiento 0 no cambia nada (por eso `GameState.difficulty_value()` sigue dando exactamente el valor de la dificultad elegida por defecto). Si vas arrollando: más daño recibido, los rivales listos esquivan más seguido y se curan más veces, y sueltan algo menos; si vas flojo, lo contrario (te ayuda a remontar).
- Se explica en Opciones (fila "Se adapta a tu nivel", pestaña Dificultad) y en la Ficha de entrenador (chip de dificultad).

## Decisiones tomadas sin preguntar (ver `decisiones_sin_preguntar.md` para el detalle completo)
- El mar no tiene guardián (una arena de combate en pleno mar complica mucho la navegación sin aportar tanto).
- Las fases no reescriben las estadísticas del guardián (eso exigiría duplicar su especie como hace la megaevolución): "más rápido y nuevos ataques" se nota en que el intervalo entre ataques en área baja y aparecen ayudantes, no en sus estadísticas base.
- El "epílogo de la región" es una caja de diálogo con un resumen, no una cinemática nueva (coherente con el resto del juego, que no tiene más cinemáticas que la de inicio).
- Medallas mínimas para el líder del equipo villano: 4 de 8 (la mitad del camino de gimnasios de esa región).
