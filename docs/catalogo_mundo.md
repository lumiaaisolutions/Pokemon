# Catálogo del mundo (aprobado por Fernando, 2026-10-09)

[← Índice](README.md)

Orden por capas: primero el mundo exterior, luego la vida (NPC, día y noche, clima), después el combate y la captura, y al final los interiores y las actividades.

| Capa | Contenido |
|---|---|
| 2.5 y 2.8 ✅ | Tres biomas con río, lago, pantano y costa; aparición por hábitat, rareza, manadas, shiny, tamaños; persecución, peleas, emboscadas, captura en el mundo, legendarios en santuarios; vida del jugador; mapa |
| 2.6 Asentamientos y lugares icónicos ✅ (con el [mundo grande](sistemas/mundo_grande.md); los edificios son volúmenes de colores, no modelos de B2W2; parque de atracciones, muelle y casas en árboles no se hicieron) | **Pradera:** pueblo inicial (laboratorio del profesor con la selección de huevo, casas, Centro Pokémon, tienda) y rancho (granero y corrales). **Bosque:** aldea de cabañas, casas en los árboles, campamento con fogata, puentes sobre el río y el pantano, bosque ancestral con árbol sagrado y santuario. **Montaña:** pueblo minero, refugio, mirador, volcán con lava, aguas termales y ruinas, torre antigua, cumbre nevada. **Costa:** ciudad portuaria con calles pavimentadas, edificios, gimnasio, muelle, faro en acantilado, naufragio, mercado de pescadores y parque de atracciones con noria. **Zonas nuevas:** isla y archipiélago (con Surf), desierto o cantera, pueblo fantasma en el pantano. Rutas con distinto pavimento (tierra, adoquín, baldosa o asfalto, madera). Edificios con modelos de B2W2; si no se importan, se reconstruyen con volúmenes y sus texturas |
| 2.7 Vida del mundo ✅ ([habitantes](sistemas/habitantes.md), [clima](sistemas/clima_y_eventos.md); entrenadores que retan quedan para la 5.6) | NPC con rutinas según la hora; viajeros entre pueblos que acampan; entrenadores caminando; cada NPC con su Pokémon; ciclo día/noche; clima (lluvia, niebla, nieve) que cambia las apariciones (Fantasma y Siniestro de noche; Agua y Eléctrico con lluvia; Hielo con nieve) |
| 3 y 4 | Combate en tiempo real y captura en combate |
| 5 | UI, inventario y guardado; inicial con huevos; Pokédex con hábitats (dónde y a qué hora vive cada Pokémon) |
| 5.5 | Misiones, evolución, megapiedras, reputación de pueblos, fotografía |
| 5.6 | Entrenadores NPC: reto y combate |
| 5.7 Interiores ✅ en su mayoría ([pueblos e interiores](sistemas/pueblos_e_interiores.md); faltan museo, torre de batalla, estación de tren y ferry) | Casas y edificios, cuevas, gruta de cristal, mina abandonada (fósiles), alcantarillas, templo sumergido, museo, guardería, torre de batalla y estadio, estación de tren y ferry |
| 5.8 Actividades | Pesca con minijuego, Surf y monturas, hordas y migraciones, equipo villano con bases, objetos en el suelo, bayas, rocas rompibles |

## Ideas propuestas por Claude (Zona Safari, concursos, bazar nómada, estaciones y vuelo: aprobadas y hechas el 2026-10-09/10)
- Zona Safari con reglas propias de captura.
- Concursos Pokémon y salón de belleza.
- Bazar nómada que cambia de lugar cada día.
- Estaciones del año que cambian el color del mundo y las apariciones.
- Puntos de vuelo con Pokémon volador.
- Base de guardabosques con misiones de rescate.
- Jardín botánico con plantas raras.

## Fase 5.8 — decisiones (Fernando, 2026-10-10)
- **Pesca:** hecha con el campamento (ver [jugador](sistemas/jugador.md)).
- **Hordas de 5 que te rodean** (como Rubí Omega): 5 de la misma especie pelean contra tu compañero a la vez, dan más premios y más probabilidad de shiny. **Hecho** (ver [Pokémon salvajes](sistemas/pokemon_salvajes.md#hordas-fase-58-decidido-por-fernando-el-2026-10-10--hecho)).
- **Migraciones, las dos (hechas, ver [Pokémon salvajes](sistemas/pokemon_salvajes.md)):** bandadas visibles que cruzan el mapa a ciertas horas y estaciones (Wingull al atardecer, Swablu en primavera, Butterfree en verano…), aterrizan en un lugar y se quedan un día (el Rotom avisa), **y** especies de temporada (solo en ciertas estaciones).
- **Rocas rompibles, ambas:** rocas agrietadas en montañas, cuevas y caminos que tu compañero rompe con un ataque (o Golpe Roca) y sueltan minerales, fósiles, piedras evolutivas o un Pokémon escondido; **y además** tapan entradas de cuevas y atajos que se abren al romperlas.
- **Detalles (Fernando, 2026-10-10):**
  - Hordas **más raras y fuertes: 2 % de las apariciones, en cualquier lugar**; el **1 %** de las hordas trae un **líder** evolucionado.
  - Especies de temporada **por tipo y estación**: invierno más Hielo y menos Bicho/Planta; verano más Bicho, Planta y Fuego; otoño más Fantasma y Siniestro; primavera más Hada, Normal y Volador; algunas especies solo salen en su estación (Deerling, Cherubi, Snover…).
  - Rocas: las **pequeñas agrietadas las rompe cualquier compañero**; las **grandes que bloquean** cuevas y atajos necesitan un compañero de tipo **Lucha, Roca, Tierra o Acero** (o que sepa Golpe Roca).
  - Bandadas: en el cielo solo se ven; **al aterrizar se quedan un día** en ese lugar como salvajes normales (más probabilidad de shiny) y luego se van.
  - Bandadas (2.ª ronda): **pueden traer especies de fuera de la Pokédex regional** (vienen de otra región; solo se atrapan ese día); pasa **1 cada 2–3 días**; aterriza **lejos, hay que buscarla**: el Rotom solo dice la zona.
  - Bandada en pantalla: como la cámara normal casi no ve el cielo, **la cámara mira arriba unos segundos** al pasar (cancelable moviéndola) y sus sombras cruzan el suelo.
  - Rocas pequeñas (2.ª ronda): se rompen **atacándolas con tu compañero** (como objetivo de sus ataques, sin menú); **reaparecen a los 3 días**; premios **mezcla equilibrada**: minerales 55 %, Pokémon escondido 15 % (Geodude, Roggenrola, Dwebble, Nosepass…), piedra evolutiva 10 %, fósil 5 %, Pepita/Perla 5 %, nada 10 %.
  - Rocas grandes (2.ª ronda): tapan **una boca de cada par de cuevas** (abierta = atajo), **la mitad de las cuevas chicas** (mejor premio dentro la primera vez) **y túneles cortos** que atraviesan crestas de montaña o cañones junto a un camino (4–6 por región). **Bloqueo real**: no se saltan ni se rodean por las paredes (tampoco volando). Rotas, quedan abiertas para siempre en esa región.
  - Desfiladeros (túneles): **hecho** (2026-10-11, rama `tuneles`) como atajo a cielo abierto (sin pantalla de carga): corredor tallado en el propio terreno, con pasto, a veces un cofre y Pokémon de roca propios; la roca que tapa la boca más baja bloquea de verdad (paredes del terreno + un bloqueo invisible hasta el techo de vuelo). Ver [mundo grande](sistemas/mundo_grande.md#desfiladeros-2026-10-11-rama-tuneles).
  - Aspecto: **3D de pocas caras con textura pixel y grietas marcadas** (como la tienda de campaña), distintas de las rocas decorativas.
  - Avisos del Rotom (brotes, bandadas, lluvia de estrellas): tarjeta propia **"ROTOM"** con su ícono y color, separada de las misiones.
