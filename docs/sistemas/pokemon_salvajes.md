# Pokémon salvajes: datos, aparición e IA

[← Índice](../README.md) · Código: `creatures/data/`, `world/actors/pokemon_actor.gd`, `world/actors/wild_spawner.gd`, `world/actors/ambush_manager.gd`

## Datos (`tools/build_species.py` → `creatures/data/species/*.tres`)
- Las **1,025 especies**, con nombre en español, tipos, estadísticas base, etapa evolutiva (los bebés no cuentan), línea evolutiva, ratio de captura oficial, altura, legendario o singular, y hojas overworld normal y shiny.
- **Hábitat por tipo:** pradera, bosque, montaña, agua dulce, mar o pantano. Los de tipo Agua solo aparecen en el agua (los peces, serpientes y tentáculos nadan) o en la orilla. Los pseudolegendarios solo en la montaña.
- **Rareza:** peso = etapa × poder. Básico ×1, 2.ª etapa ×0.35 y 3.ª etapa ×0.1, menos probable a más estadísticas totales (más de 500, ×0.3). Pseudolegendarios ×0.1 y su etapa final ×0.01. Los legendarios no aparecen al azar ([santuarios](legendarios.md)).
- **Roster** (destacados de su bioma, ×20): Pidgeot, Ampharos, Sawsbuck, Absol (raro) en la Pradera; Heracross, Swampert, Leavanny, Gardevoir (rara) en el Bosque; Aggron, Aerodactyl, Excadrill, Froslass (rara) en la Montaña; Garchomp (jefe); Venusaur, Charizard, Blastoise en el mundo.
- **Tamaño** por altura oficial en escalones de píxel: ×1, ×1.5, ×2 y ×3 (Joltik ×1, Wailord ×3).
- **Temperamento:** el del roster es de diseño; para el resto se calcula por estadísticas (deambula, curioso, tímido, agresivo o territorial).
- `basic_pool.tres`: 423 básicos para elegir inicial (sin legendarios, singulares, Ultraentes ni paradojas).

## Aparición (`WildSpawner`)
- En **cualquier lugar transitable** (ajustado a la navegación: nunca dentro de árboles, rocas ni agua), en la orilla o dentro del agua, entre 15 y 70 m del jugador; se retiran a más de 100 m.
- **Zonas de 40 × 40 m** con cupo de grupos según el hábitat (pradera 3, bosque 4, montaña 2, agua dulce 2, mar 2, pantano 3) y 2 especies características por zona (35 % de las apariciones de esa zona).
- **Shiny:** 1 % (antes 2 %, bajado a pedido de Fernando), con la paleta variocolor y estrellitas que brillan alrededor siempre (sin destello del cuerpo, ver abajo).
- **Manadas (30 %):** de 3 a 6 de una línea evolutiva, solo con especies que viven en ese hábitat. Casi todos básicos; en el 25 % de las manadas hay un líder evolucionado. Siguen al líder en formación y huyen, persiguen o se esconden juntos. Están separadas 60 m, salvo un 5 % de manadas rivales a 15 m.

- **Clima** (`WildSpawner.climate_ok`): cerca o arriba de la línea de nieve no aparecen Pokémon de tipo Fuego, Planta ni Bicho (salvo que también sean de Hielo), y los de Hielo solo aparecen en la nieve o el mar. Se reintenta la especie hasta 8 veces. Corrige, por ejemplo, un Torchic junto a la nieve.

- **Áreas propias** (estilo Escarlata y Púrpura, 2026-10-10): con la semilla, cada especie tiene de 1 a 3 áreas (28 a 50 m de radio) en lugares de su hábitat y clima; dentro pesa ×12 y fuera ×0.12, así casi siempre sale en sus zonas pero a veces se ve suelta. El 8 % son **nómadas**: cambian de área cada día del juego. La Pokédex muestra las áreas según la investigación.
- **Densidad:** la mitad que antes (máx. 12 vivos; 7 / 12 / 18 según Opciones), manadas del 20 % de 2 a 4. Los caminos y los pueblos también tienen Pokémon (estilo Leyendas Z-A).
- **Mundo grande (2026-10-10):** el hábitat sale del bioma de la región y cada bioma suma su **afinidad de tipos** (desierto: Tierra ×4; volcán: Fuego ×8; tundra: Hielo ×8…). El **clima** del momento cambia los pesos ([clima](clima_y_eventos.md)). Lugares con Pokémon propios: Unown en ruinas, ranchos (Miltank, Mareep…), huertos, grutas, oasis, torre y central; Zona Safari con raros; **arrecife** en el mar del sur (40 % de los nadadores). Brotes masivos y lluvia de estrellas. En los interiores solo salen los del interior.
- **Pokédex regional:** las líneas evolutivas numeradas por qué tan cerca del pueblo inicial viven (cambia con la semilla).
- Clima frío también en toda la tundra; nada de Hielo en desierto, volcán ni playa.
- **Sexo** según la especie (♂ / ♀ en su recuadro) y **talla** individual de 0.75 a 1.3 (se ve en su sprite y en los récords de la Pokédex).

## IA (`PokemonActor`, rol salvaje)
| Temperamento | Comportamiento |
|---|---|
| Deambula | Pasea; te ignora |
| Curioso | Se acerca, se queda mirándote y pierde el interés |
| Tímido | Huye; no inicia peleas |
| Agresivo | Te persigue en cuanto te ve y te ataca |
| Territorial | Te persigue y ataca solo si entras a su zona (7 m) |

- **Mentalidad propia:** pasean hasta 14 m y cada 4 paseos se mudan unos 25 m.
- **Persecución:** área de 12–35 m según velocidad y poder, con anillo rojo en el suelo; si sales del área se rinden y regresan.
- **Esconderse:** tras 60–180 s sin interacción buscan hierba alta cercana y desaparecen con una nube según el lugar (hojas, polvo, roca, salpicadura, arena).
- **Emboscadas** (`AmbushManager`): hasta 3 en árboles a 18–40 m del jugador. Los Bicho cuelgan de un hilo y las aves se posan en la copa, y la copa se sacude como pista. Los agresivos y territoriales muestran "¡!" y caen o se lanzan en picada a los 0.5 s; los tímidos se van si te acercas y los curiosos observan.
- **Peleas** entre ellos y con el jugador: ver [peleas.md](peleas.md).

## Compañero (rol compañero)
- Un básico al azar te sigue con navegación (hasta que exista la selección con huevos, Fase 5): corre si te alejas, reaparece si se queda a más de 30 m, mira al salvaje más cercano y te espera en la orilla si nadas.
- Te defiende y hace guardia si te desmayas (ver [peleas.md](peleas.md)).

## Comunes y raros (pedido de Fernando, 2026-10-10 · hecho)
Fernando notó que la misma especie solo se repite en las manadas: los sueltos salen todos distintos y al azar.
- **Decisión:** cada zona tiene **3–5 especies comunes** que se ven varias veces sueltas, algunas poco comunes y **raras que cuesta encontrar** (muchos Pidgey, pocos Eevee).
- **Rareza por la especie** (igual en todas las regiones): básicos comunes salen mucho; evolucionados, pseudolegendarios y especies raras (Eevee, Dratini, Larvitar) salen poco.
- Las especies de cada región siguen siendo al azar por partida (Pokédex regional, ver [regiones](regiones.md)); no hay especies fijas por región.
- **Causa:** casi todo el mapa queda fuera de las áreas propias de las especies (×0.12 para todas), así que cada aparición salía de una especie distinta.
- **Implementación (`wild_spawner.gd`):** `rarity(species)` = (ratio de captura / 255)^1.2 entre 0.05 y 1 (Pidgey 1, Eevee 0.13); cada **parcela de 160 m** sortea con la semilla de 3 a 5 **comunes** (rareza ≥ 0.45, hasta 2.ª etapa) que pesan ×30. Medido en 4 lugares con 40 apariciones: los comunes salen 6–12 veces cada uno y el resto queda como poco común o raro (p. ej. Weedle ×12, Deerling ×10, Bellsprout ×9).

## Hordas (fase 5.8, decidido por Fernando el 2026-10-10 · hecho)
- **Qué es:** 5 salvajes de la misma especie que te rodean y pelean **a la vez** contra tu compañero (como Rubí Omega). Más raras y fuertes: **2 % de las apariciones, en cualquier lugar**; el **1 %** de las hordas trae un **líder** evolucionado. Shiny ×3 en cada miembro.
- **Aparición (`WildSpawner.spawn_horde`):** antes de la manada, `spawn_one` saca una horda con `HORDE_CHANCE` (no en agua). Los 5 quedan en círculo (2.6 m), con `meta "horde"` = id, en el grupo `hordes` y con el mismo `group_id`. Solo cuenta para el tope de la zona del primero. `horde_members(id)` devuelve los que siguen vivos.
- **Combate (`BattleManager`):** fuera de combate, cada 0.5 s, si un miembro está a menos de **12 m** del jugador y se puede pelear, la horda **se lanza** y empieza el combate ("¡Una horda de 5 X te rodea!"). Todos entran al círculo alrededor de tu compañero y lo atacan; no se congelan con el resto del mundo. Al debilitar al rival, el siguiente miembro pasa a ser el rival ("Quedan N"). Al vencer a todos: premio normal más **$150 por miembro y un Caramelo Raro**. Huir saliendo del círculo funciona igual.
- **Prueba:** `test_battle` sección 3b (5 miembros, se lanza al acercarte, los 5 en la arena, siguen uno tras otro, premio y limpieza).

## Especies de temporada (fase 5.8, decidido por Fernando el 2026-10-10 · hecho)
- **Estaciones** de 7 días (`Weather.season`, 0 Primavera, 1 Verano, 2 Otoño, 3 Invierno).
- **Por tipo** (`WildSpawner.SEASON_TYPES`, peso multiplicado por cada tipo): primavera Hada ×2.2, Normal ×1.5, Volador ×1.6; verano Bicho ×2, Planta ×1.6, Fuego ×1.8; otoño Fantasma ×2.5, Siniestro ×2; invierno Hielo ×3, Bicho ×0.3, Planta ×0.4.
- **Solo en su estación** (`SEASON_ONLY`): Cherubi, Combee (primavera); Volbeat, Illumise, Surskit (verano); Deerling, Phantump, Pumpkaboo (otoño); Snover, Delibird, Cubchoo, Vanillite, Spheal (invierno), con sus evoluciones. `pick_species` nunca las da fuera de su estación.
- **Prueba:** `test_creatures` (invierno/verano, Snover nunca sale en verano).

## Migraciones (fase 5.8, decidido por Fernando el 2026-10-10 · hecho)
- **Cada 2–3 días** (`Migrations`, `world/events/migrations.gd`): a las 6:00 el Rotom avisa: "Hoy hacia las HH:00 pasará una bandada de X y aterrizará por <zona>". La especie sale de la lista de la estación (`POOL`: Swablu, Pidove, Hoppip, Cottonee en primavera; Butterfree, Beautifly, Vivillon, Wingull en verano; Starly, Ducklett, Murkrow, Wingull en otoño; Delibird, Pidove, Starly en invierno), cada una con su hora (Wingull 18:00, Murkrow 19:00…).
- **Puede ser de fuera de la Pokédex regional** (viene de otra región; solo se atrapa ese día).
- **En el cielo:** a su hora, una V de 9 pasa a 12 m por delante de la cámara rumbo al aterrizaje y **la cámara mira al cielo unos 4 s** sola (`CameraRig.look_at_sky`; mover la cámara lo cancela). Si estás en combate, en un edificio o en un diálogo, espera a que salgas. Las aves proyectan sombra.
- **Aterrizaje lejos (hay que buscarla):** a 450 m o más del jugador, en tierra y fuera de los pueblos; el Rotom solo dice la zona. Desde su hora y hasta que termina el día, en 70 m salen de esa especie el 75 % de las veces, con **shiny ×3**, sin filtro de clima.
- Estado en `world_flags["events"]["migration"]` y `migration_next` (se guarda).
- **Prueba:** `test_town` (aviso, siguiente en 2–3 días, aterriza a su hora, V de 9, cámara al cielo, especie de fuera, apariciones, se va al día siguiente).

## Pendientes pedidos por Fernando (2026-10-10)
- **Emboscadas en árboles — tamaño:** algunos voladores y Bicho se ven del tamaño del árbol (o más grandes). Causa: el árbol se elegía sin mirar el tamaño del Pokémon. **Decisión:** primero el Pokémon y luego un árbol que mida **al menos 2.5× su altura**; si no hay, no se posa. **Hecho** (`AmbushManager.spawn_one`, `TREE_RATIO`).
- **Bicho también en el suelo:** ya salían caminando con los salvajes normales, pero pocos. **Decisión:** de las emboscadas de Bicho, **40 % al pie del árbol** (entre las raíces) y 60 % colgados. **Hecho** (`place_at_foot`, `GROUND_BUG_SHARE`).
- **Desfase con la cámara desde arriba:** el árbol se inclina desde su base al subir la cámara (shader `sprite_billboard`) y el Pokémon posado quedaba fijo en el aire. **Decisión:** que el Pokémon **se incline con la copa** en cada cuadro. **Hecho** (`PokemonActor._in_front_of_canopy` repite la fórmula del shader: a la altura h, `base + arriba·h·cos(t) − atrás·h·sin(t)`; el hilo del Bicho también se inclina). Verificado de lado, desde arriba, girando y casi cenital (`~/Desktop/Pokemon_posado_angulos.png`).
- **Destello de los shiny:** **hecho (2026-10-10).** El destello del cuerpo (blanco cada 2.5 s) casi no se veía y de noche se volvía blanco; Fernando decidió **solo estrellitas, siempre**: el shiny se ve con sus colores y 8 estrellas pixel brillan alrededor de día y de noche (sin luz propia del cuerpo). Se quitó el degradado de color de las partículas, que pintaba estrellas negras. El shader de sprites ganó `instance uniform flash` (para destellos de golpe en los ataques).
