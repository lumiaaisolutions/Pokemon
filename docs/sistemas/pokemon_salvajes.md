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
- **Shiny:** 1 % (antes 2 %, bajado a pedido de Fernando), con la paleta variocolor y un destello de estrellas cada 2.5 s.
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
