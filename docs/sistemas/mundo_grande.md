# Mundo grande generado

[← Índice](../README.md) · Decidido con Fernando el 2026-10-09. Estado: **hecho** (2026-10-10). Código: `world/region/`, `world/world_builder.gd`, `world/navigation/`, `ui/map/`. Complementa [historia y mundo aleatorio](historia_y_mundo_aleatorio.md), [pueblos e interiores](pueblos_e_interiores.md), [clima y eventos](clima_y_eventos.md) y [montar y volar](montar_y_volar.md).

## Tamaño, semilla y carga por zonas
- **4 × 4 km** (unas 70 veces el mundo de 480 m). Cada partida nueva elige una **semilla** al azar (`GameState.world_seed`, se guarda); misma semilla, mismo mundo. Las pruebas usan la de `WorldConfig` (1).
- `RegionLayout` (`world/region/region_layout.gd`) decide todo con funciones puras de (x, z): clima (temperatura y humedad), altura, bioma, ríos, lagos, pueblos, caminos y lugares. Tarda ~15 ms.
- `WorldBuilder` construye **zonas de 128 m** alrededor del jugador:
  - **Cercanas** (5 × 5 zonas): malla de 2 m con colisión, árboles y rocas con colisión, decoración, hierba alta, charcas y corales. 
  - **Lejanas** (hasta 6 zonas según la calidad): malla de 8 m sin colisión y árboles de lejos.
  - Los datos de cada zona se calculan en **hilos** (WorkerThreadPool); en el hilo principal solo se crean los nodos (1 cercana y 4 lejanas por cuadro). Al teletransportarse (portal, interior, carga) se construye de golpe con `ensure_area`.
  - **Faldas** de 5 m en el borde de cada zona tapan las rendijas entre zonas de distinto detalle.
- El inicio es la **plaza del pueblo inicial**. Arranque del mundo: ~2.7 s.
- Interiores: desde `INTERIOR_X` (x ≥ 10 km) el mundo responde suelo plano en y = 0, sin agua y el hábitat del interior.

## Biomas (17)
Pradera, Bosque, Montaña, Costa, Desierto, Cañón, Sabana, Selva, Tundra, Volcán, Campo de flores, Bosque de hongos, Bosque oscuro, Pantano, Pantano tóxico, Mesetas y Mar.
- Temperatura más fría al norte y con la altura; la humedad y un ruido especial deciden la variante (oasis, flores, hongos, tóxico…).
- Cada bioma tiene **familia de suelo** (pasto, bosque, roca, arena, pantano), **tinte**, **hábitat de Pokémon** y **afinidad de tipos** (desierto: Tierra ×4 y Agua ×0.05; volcán: Fuego ×8…).
- Vegetación por bioma: árboles B2W2 y arte generado (`PropArt`): cactus, palmeras, acacias, hongos gigantes y **hongos luminosos que brillan de noche**, corales.
- Mar al sur con **islas** (archipiélago) y **arrecife**: corales en el fondo y nadadores propios (Corsola, Luvdisc, Relicanth…).
- **Mesetas** escalonadas y **cascadas** donde el río baja más de 1.2 m.
- **Lagos congelados** en la tundra (hielo plano que se pisa) y **oasis** en el desierto.
- Tierra adentro nunca queda bajo el nivel del mar.
- Nieve por altura (salvo en biomas cálidos) y en toda la tundra. Las **estaciones** tiñen el pasto y el follaje ([clima](clima_y_eventos.md)).

## Agua
- Mar: un plano a nivel −1.5 m bajo todo el mundo; el terreno baja al sur.
- 6 ríos que nacen en la montaña y bajan siguiendo la pendiente; si un río da vueltas en una hondonada, termina en un lago nuevo.
- 9–15 lagos en hondonadas, oasis y finales de río; charcas en las zonas de pantano.
- El borde del agua siempre queda bajo el terreno (prueba `test_world`, ~600 bordes).

## Borde del mundo
Cordillera exterior (norte, este y oeste) y mar abierto al sur, con colisión propia para la cámara; muros invisibles de 800 m en el borde; corriente que regresa a la costa.

## Navegación y mapa
- Navegación **horneada por zona** al construirse (terreno, árboles, edificios y lugares; el agua profunda se excluye), unida por los bordes; se libera con la zona. Los interiores tienen la suya.
- Mapa de la región a **8 m por píxel** (512 px) calculado en un hilo y guardado en `user://map_<semilla>_v2.png`. Niebla de exploración guardada en la partida. Pueblos (rojo = ciudad) y lugares descubiertos con nombre. Ver [mapa](mapa.md).

## Lugares de la región (por semilla)
13 asentamientos (ciudades, pueblos, aldeas y cabañas, **ahora el doble de grandes**, ver [pueblos e interiores](pueblos_e_interiores.md#pueblos-×2-con-identidad-2026-10-11)) unidos por caminos y más de 90 lugares: ruinas (5), cuevas por pares (8), santuarios (8 + la cumbre), torre con cementerio, mansión, central eléctrica, barcos hundidos (2), faros (2), laboratorio en ruinas, árbol milenario, Liga Pokémon con Calle Victoria, ruinas flotantes (2), portales (2), Zona Safari, guardería, aguas termales (4), territorios Alfa (8), fuentes (3), ranchos (3), huertos de bayas (3), minas (2, **ahora mazmorras de 3 pisos con guardián al fondo**), grutas de cristal (6), base secreta del equipo criminal, comerciantes en los caminos (4), oasis y volcanes (2), y los **eventos del campo** nuevos (2026-10-11): árbol caído (2), puesto de control del equipo villano (2), viajero con un problema (4), Pokémon gigante dormido (3) y pista de carreras (2). Qué hace cada uno: [pueblos e interiores](pueblos_e_interiores.md).
- **Puentes** (2026-10-11): donde un camino cruza un río aparece un puente de madera con barandales, alineado con el camino (antes el camino solo allanaba el terreno y el agua quedaba sin nada encima).

## Desfiladeros (2026-10-11, rama `tuneles`)
Atajos a cielo abierto que cortan una cresta de montaña, cañón o meseta cerca de un camino existente (decisión "Túneles" de `docs/plan_pulido_mundo.md`). Código: `world/region/region_layout.gd` (talle del terreno) y `world/rocks/mountain_passes.gd` (todo lo que no es terreno).
- **4–6 por región**, fijos por semilla (`RegionLayout.passes`). Se buscan primero las crestas de verdad (el punto medio de 40–80 m claramente más alto que las dos bocas) y luego se exige un camino no muy lejos (≤ 300 m): en un mapa de 4 × 4 km con unos 15 caminos, pedir que coincidan al azar un punto de cresta Y uno junto a un camino es muy poco probable si se exige lo segundo desde el principio del muestreo.
- **Talle del terreno** (`RegionLayout.height_at` / `_carve_pass`, se aplica después de ríos y lagos): corredor plano de ~5 m (`PASS_WIDTH`) a la altura interpolada entre las dos bocas, pared empinada de roca (`PASS_WALL_BAND`, se levanta `PASS_WALL_HEIGHT` = 16 m sobre el piso en todo el largo, no solo en la cresta, para que el bloqueo sea parejo) y de vuelta al terreno natural en un margen, todo continuo (sin huecos ni escalones). Al ser la propia malla del terreno, queda horneado en la colisión y en la navegación igual que cualquier zona.
- **Encima del terreno** (`MountainPasses`, nodo del mismo nivel que `BreakableRocks`): pasto (matas 3D a lo largo del piso), a veces un cofre 3D (mitad de los desfiladeros, fijo por id), 1–2 Pokémon de roca propios por día y, en la boca más baja, una **roca grande** (`BreakableRock`, id estable `"pass:<n>"`, igual que las cuevas chicas).
- **Bloqueo real**: mientras la roca no se rompe, un `StaticBody3D` invisible (capa `LAYER_OBSTACLES`) cierra todo el ancho del corredor desde el piso hasta bien arriba del techo de vuelo del jugador (`Player.FLY_CEILING` = 260 m): no se puede ni caminar ni volar por encima de la roca mientras tapa el paso. Las paredes de los lados ya bloquean por sí solas (son parte del terreno, con colisión). Al romperla, el bloqueo se libera para siempre (persistido en `world_flags["boulders"]`, como cualquier roca grande) y se vuelve a hornear la navegación de esa zona (`WorldNavigation._bake_chunk`, llamado directamente al construir y al romper, sin esperar al orden de señales).
- **Mapa y pistas**: se marcan igual que los demás lugares especiales, solo al descubrirlos (fog of war); el color y el texto cambian según si siguen tapados o ya están abiertos. El sueño del campamento que avisa de rocas grandes temblando ahora menciona "cueva o desfiladero".
- Pruebas: `tests/test_rocks.gd` (sección 7) comprueba la cuenta (4–6), el talle del piso y la pared, que la roca bloquee de verdad (rayo físico antes/después de romperla) y que siga abierta tras recargar la partida.

## Rendimiento
- Zona cercana: ~60 ms de cálculo en un hilo; instanciar ~3 ms. Caminar y volar no traban el cuadro.
- Calidad (Opciones): baja/media/alta cambia la escala de render, sombras, MSAA y la distancia de dibujo (4, 5 o 6 zonas).
- Desfiladeros: solo 4–6 por región y con pocos objetos cada uno (matas individuales, 1 roca, a veces 1 cofre); sin impacto medible en FPS.


## Kit por bioma (2026-10-10)
Fernando vio zonas vacías ("aquí dice Pantano y no veo nada de pantano").
- **Bug encontrado:** la decoración de todas las zonas nunca se guardaba (`(dic[k] as PackedVector3Array).append(...)` modifica una copia en GDScript). Ahora se reasigna: aparecieron todas las flores, matas y adornos que ya estaban planeados.
- **Kit de objetos por bioma** (`WorldBuilder.BIOME_KITS`, sprites en `PropArt`): pradera (flores rosas y blancas, rocas, cercas viejas, troncos), campo de flores, sabana (arbustos secos, huesos), bosque y selva (troncos con musgo, rocas con musgo, hongos), bosque oscuro y de hongos (hongos venenosos), montaña, mesetas y cañón, desierto, tundra (nieve, cristales de hielo), volcán (rocas de lava), costa (conchas, madera de deriva), **pantano** (juncos, espadañas, troncos, hongos) y **pantano tóxico** (hongos venenosos, espadañas, huesos).
- **Pantanos:** suelo propio de lodo con charquitos (`art/world/b2w2/swamp_ground.png`); verde oliva oscuro en el pantano y morado apagado en el tóxico; **nenúfares** (algunos con flor) en las charcas; charcas **moradas que burbujean** en el tóxico; **neblina baja** sobre las charcas. La decoración puede ir en la orilla y en agua muy baja.
- **Puntos de interés** (`world/poi/`, hecho el 2026-10-10, ampliado el 2026-10-11): fijos por semilla, marcados en el mapa al descubrirlos (a 25 m). Campamento abandonado (cofre diario), pozo de los deseos ($100: objeto o Pokémon de agua raro), ruinas pequeñas (lore y datos de un legendario), árbol grande (bayas diarias y voladores que caen), cueva chica (Pokémon raro dormido, a veces Alfa; solo en montaña, cañón, mesetas, bosque y tundra), mirador (revela 300 m del mapa y $300 por la foto del día), **caseta de descanso** (recupera vida poco a poco, como las aguas termales), **guarida** (2–4 de la misma especie, a veces con un líder más fuerte) y **lugar de entrenamiento** (combate amistoso de práctica, $300, una vez al día). Densidad subida de 0.35 a 0.42 (`CHANCE`) al agregar los 3 tipos nuevos; `tests/test_town.gd::_check_poi_density` mide el espaciado real sobre tierra (sin contar el mar).
- **Campo abierto (2026-10-10, tarde):** pasto menudo sin contorno (3,000 matas por zona en los biomas con pasto, sin pasto en la nieve), manchones de flores agrupadas (8–18 matas del mismo color) y flores rediseñadas como matas con hojas (antes se veían "cortadas").
