# Pueblos, lugares e interiores

[← Índice](../README.md) · Estado: **hecho** (2026-10-10). Código: `world/region/structures.gd`, `town_services.gd`, `interiors.gd`, `ui/shop/shop_ui.gd`.

## Interacción
Cerca de una puerta, mostrador, persona o lugar, el HUD muestra la acción (`[E] Entrar: Centro Pokémon`) y **interact** (E / ✕) la hace. Algunos puntos se usan nadando (barco hundido). Al llegar a un pueblo o lugar, un cartel muestra su nombre.

## Edificios de los asentamientos
| Edificio | Dónde | Qué hace |
|---|---|---|
| Centro Pokémon | Pueblos, ciudades y aldeas | Cura a todo el equipo y al jugador, fija ahí la reaparición y autoguarda; PC con la Caja |
| Tienda | Pueblos y ciudades (8:00–21:00) | Compra ×1/×10 y vende a mitad de precio; más surtido con medallas y 4 MT distintas cada día |
| Gimnasio | Ciudades (7:00–22:00) | Líder de un tipo (fijo por semilla); reto de 3 Pokémon, más fuertes con cada medalla; medalla y dinero |
| Sala de Concursos | Ciudades | Puntaje por dominio de movimientos, variedad de tipos y vínculo; con 14+ gana la cinta (1 intento por día) |
| Laboratorio | Pueblo inicial | El profesor entrega premios de investigación, la **bicicleta**, las **licencias de montura y vuelo** y **revive fósiles** |
| Casas y cabañas | Todos | Vecino que da un consejo y un regalo al día; cama para dormir hasta la mañana |
| Carpas | Cabañas | Descansar hasta la mañana |
| Torre del reloj | Ciudades | Descubre el mapa a 600 m |
| Alcantarilla | Ciudades | Baja a las alcantarillas |

## Lugares especiales
- **Ruinas antiguas:** inscripción con una pista y **acertijo** de 3 piedras (sol, luna, estrella): en el orden de la inscripción dan premio y aparecen Unown. Unown aparecen alrededor.
- **Cuevas por pares:** cada cueva tiene salida al otro lado, en su pareja lejana. **Calle Victoria** sale frente a la Liga.
- **Grutas de cristal:** sin pantalla de carga (paredes y techo de roca, cristales que brillan) con Pokémon de cueva.
- **Minas abandonadas:** mazmorra con fósiles y minerales.
- **Torre espectral** (con cementerio), **mansión**, **central eléctrica**, **laboratorio en ruinas**, **base secreta** del equipo criminal (jefe al final: 4 Pokémon Siniestro/Veneno; al vencerlo se liberan las zonas tomadas y sube la reputación).
- **Barco hundido:** se explora nadando junto al casco.
- **Portales:** llevan a un **mundo de distorsión** (mazmorra con Pokémon raros) que sale por el otro portal.
- **Ruinas flotantes:** a 40 m de altura, solo volando; fragmento de cielo y descubrimiento.
- **Árbol milenario**, **faros**, **volcanes** (humo en el cráter), **fuentes** y **aguas termales** (curan poco a poco).
- **Zona Safari:** $500 por 30 Safari Balls (×1.5) que se devuelven al salir; Pokémon raros dentro.
- **Guardería:** deja un Pokémon (no el compañero) y gana 2 Puntos de Entrenamiento por día.
- **Ranchos** (Leche Mu-mu, Miltank, Mareep…), **huertos de bayas** (4 filas, cada una una vez al día), **comerciantes viajeros** en los caminos (5 objetos raros al día, precio ×1.5), **oasis** con palmeras.
- **Territorios Alfa** y **santuarios** de legendarios: ver [clima y eventos](clima_y_eventos.md) y [legendarios](legendarios.md).

## Interiores (con fundido)
- Se construyen al entrar en `x = 20 km` con suelo en y = 0 y se liberan al salir. Fondo oscuro sin cielo ni niebla, menos luz en mazmorras, cámara alta y lejana.
- **Salas:** Centro (enfermera + Chansey o Blissey de mascota), Tienda (dependiente + Kecleon de mascota), casas, laboratorio, gimnasio y Liga (arena), Sala de Concursos.
- **Mazmorras** en cuadrícula de celdas de 7 m: recorrido al azar de la entrada a la salida con ramas, luces y Pokémon propios (cueva, alcantarilla, torre, mansión, central, laboratorio, Calle Victoria, mina, base, distorsión, barco), y 2 tesoros que se recogen una vez por día.
- Muros bajos y sin choque con la cámara (estilo HD-2D) en las salas de piezas (sin modelo); el del lado de la entrada es más bajo.
- Navegación horneada para el interior. Al guardar adentro se guarda la puerta.

### Arreglo base de todos los interiores (2026-10-10, rama `interiores`)
Código: `world/region/interiors.gd` (`_model_room`, `_floor_rect`, `_ceiling_height`, `_ceiling_lamps`, `_pokemon_pet`), `world/day_night.gd`, `world/region/town_services.gd`.
- **La cámara se mete en el modelo (bug raíz):** las salas con modelo real de B2W2 (tienda y Centro, de dos pisos) tienen techo de verdad, a diferencia de las salas de piezas (sin techo, hechas a mano); con la cámara alta y lejana fija (zoom 11, 52°) de antes, la cámara quedaba fuera del edificio o dentro del piso de arriba y se veía un amasijo de triángulos en vez del cuarto. Ahora `_ceiling_height` mide la altura real del techo (agrupa los triángulos horizontales del modelo por altura y busca la losa ancha más baja por encima de la cabeza) y la cámara se ajusta para quedar siempre bajo ese techo y dentro del piso, con un zoom y un ángulo calculados por sala (`current["cam_zoom"/"cam_pitch"]`).
- **Piso mal detectado:** `_floor_rect` elegía la superficie horizontal con más área, y algunos modelos (p. ej. uno de los gimnasios de hielo) traen un plano de fondo decorativo (terreno, montañas) mucho más grande que el piso real, lejos de él en altura; el jugador terminaba en un cuarto vacío y oscuro, lejos de los muebles. Ahora se agrupan las alturas por cercanía (un salto de más de 10 m separa el fondo decorativo del resto) y, dentro del grupo principal, se toma la más cercana a 0 (el origen que usó quien hizo el modelo).
- **Luz propia cálida:** `_ceiling_lamps` pone lámparas de techo (repartidas según el tamaño de la sala) en todas las salas con modelo, que antes no tenían ninguna luz propia. Además, en `day_night.gd`, dentro de cualquier interior el sol y la luz ambiente nunca bajan de un mínimo cálido, aunque sea de noche (antes el "sol" seguía oscureciéndose igual que afuera y el interior se veía negro pasadas las 20:00).
- **Zonas negras:** las paredes del contorno (antes solo colisión invisible) ahora también tienen una caja visible con un color parecido al de las paredes del modelo (promedio de sus texturas no hay a mano), y un faldón oscuro bajo el borde del piso, para tapar los huecos que dejan los modelos de la DS. El muro del lado de la entrada es bajo (como en las salas de piezas) para no tapar la cámara ni la puerta.
- **Personal correcto:** la enfermera y el dependiente son humanos (`NpcLooks.for_role("enfermera"/"vendedor", rng)`) detrás del mostrador; el Chansey/Blissey y el Kecleon son su mascota junto a ellos, con `_pokemon_pet` (hoja de caminar de mundo, `DirectionalSprite`), nunca con su sprite de frente. `_npc` ya no acepta un Pokémon de frente (se quitó ese camino).
- **Caja de diálogo:** el profesor (tienda del laboratorio), el entrenador del gimnasio ya vencido, el juez de la Sala de Concursos y el tutor de movimientos hablan en `DialogBox` con su nombre y retrato; antes salían como avisos sueltos (`GameState.notice`).
- **Pendiente de verificar en el juego:** las dos escaleras de la tienda y del Centro (de dos pisos) — el arreglo del piso y del contorno ataja la causa descrita (el muro del contorno cortaba una escalera porque el piso detectado no llegaba hasta ahí), pero no se automatizó una prueba que suba por cada escalera de cada variante del modelo.
- **Prueba:** `tests/test_interiors.gd` entra al Centro, la Tienda, una casa, el laboratorio y un gimnasio, y revisa que haya luz propia, que la cámara quede dentro de la sala, que no haya ningún NPC con sprite de frente y (en el Centro y la Tienda) que el personal sea el correcto.

## Retos (gimnasio, Liga, base)
Sale un Pokémon del entrenador a la vez y ataca; al debilitarlo sale el siguiente. **No se pueden capturar** (la ball rebota). Si te desmayas, el reto termina. Liga: requiere las 8 medallas; Alto Mando y Campeón (11 Pokémon fuertes).

## Tienda y MT
- 18 MT, una por tipo (`tm-<tipo>`): enseñan a tu compañero el movimiento más potente de ese tipo de su lista oficial (MT/tutor, o de nivel) que aún no tenga.
- Fósiles: Hélix, Domo, Raíz, Garra, Cráneo, Coraza, Tapa y Pluma → el profesor los revive.


## Identidad de cada pueblo (2026-10-10)
Código: `world/region/town_identity.gd`. Acordado con Fernando: tema por bioma y tamaño.
| Tema | Dónde | Monumento | Objetos |
|---|---|---|---|
| Comercial | Ciudades | Fuente monumental con Pokéball y rocío | Faroles |
| Agrícola | Pradera, flores, sabana | Molino de B2W2 (a 0.6) | Surcos de cultivo, pacas de heno |
| Pesquero | Costa | Ancla gigante con boyas | Barcas volteadas, barriles |
| Minero | Montaña, cañón | Vagoneta con piedras brillantes sobre rieles | Rocas, cajas |
| Leñador | Bosques, selva, pantanos | Tótem de madera | Pilas de troncos |
| Oasis | Desierto, mesetas, volcán | Pozo con palmeras | Puestos con toldos de colores |
| Alpino | Tundra | Hoguera con humo y luz | Nieve, trineos |

- Plaza: monumento al centro (en el pueblo inicial, 13 m a un lado, porque ahí apareces) con un aro de **macetones de piedra** con arbustos de flores de B2W2 y bancas.
- Los objetos del tema van entre los edificios, sin tapar puertas ni caminos.
- El cartel del lugar dice el tema: "Pueblo Raíz · pueblo agrícola".
- **Reflejos de la DS:** algunos modelos (el molino) traen bajo el nivel 0 una copia reflejada para el agua; ahora se apoyan en y = 0 y el reflejo queda enterrado (antes el molino flotaba sobre su reflejo).

## Física del mobiliario y cámara (2026-10-10, noche)
Acordado con Fernando: "todo el mobiliario" (bancas, macetas, cercas, faroles, puestos, cajas) debe ser sólido para el jugador, la gente y los Pokémon, y al saltar encima debe quedar parado ahí (no atravesarlo). Código: `world/region/structures.gd` (helpers `_collider`, `_cylinder_collider`, `_furniture`), `world/region/town_identity.gd`, `world/npc/town_npcs.gd`.

- **Colisión a la medida:** los macetones de la plaza (cilindro), las bancas (caja ajustada al modelo de B2W2, hija del propio nodo así hereda su giro), la caja/cajón de las plazas mineras, el tronco bajo de las plazas alpinas, los puestos con toldo del oasis, los faroles sueltos y las cercas de las casas ya tenían o ahora tienen un `StaticBody3D` en `WorldBuilder.LAYER_OBSTACLES`. El salto del jugador llega a 1.4 m (`jump_velocity`/`gravity` de `world/player/player_config.tres`); todo este mobiliario mide menos de 1.1 m, así que al saltar encima el jugador queda parado arriba (es una `CharacterBody3D` normal con `move_and_slide()`, sin código especial: la física ya lo resuelve).
- **Pokémon y navegación:** `WorldNavigation` hornea la malla de navegación a partir de los colisionadores en `LAYER_TERRAIN`/`LAYER_OBSTACLES` dentro de los nodos "Buildings"/"Landmarks" (`world/navigation/world_navigation.gd`); como el mobiliario nuevo cuelga de esos mismos nodos, ya queda incluido sin tocar ese archivo.
- **Habitantes del pueblo (`TownNPCs`):** se mueven por posición directa, sin físicas. `Structures.furniture` (un `Array` por asentamiento, guardado en `settlement["furniture"]`) registra la posición y el radio de cada pieza; `TownNPCs._avoid_furniture()` empuja al habitante hacia afuera a media fuerza (como el espacio personal) si queda más cerca que ese radio. No se aplica en el último tramo (1.2 m) al punto actual de su ruta: si no, un habitante cuya casa o lugar en la plaza cae cerca de una pieza podía quedarse oscilando sin llegar nunca (pasó con una cerca cuyo radio de evasión, calculado mal con el largo de la pieza en vez de su grosor, llegaba a tapar la puerta de una casa; ya corregido). No cambia su ruta, solo el paso de ese cuadro, así que no se rompe la rutina (casa → plaza → trabajo); probado con `tests/test_town.gd` (sigue la rutina de 24 h y de noche todos quedan en casa).
- **Cámara pegada de golpe:** el `SpringArm3D` de la cámara (`world/camera/camera_rig.gd`) solo debe chocar con el terreno y con paredes grandes (`WorldBuilder.LAYER_CAMERA`), no con mobiliario chico. Antes, `Structures._collider()` ponía esa capa en todo lo que tocaba (edificios, pero también cercas, faroles y el buzón), así que la cámara se pegaba de golpe al personaje al pasar cerca. Ahora `_collider()` y `_cylinder_collider()` reciben un parámetro `block_camera` (por defecto `true` para edificios y monumentos, `false` para mobiliario) y todo el mobiliario nuevo o ya existente (cercas, faroles, buzón, macetones, bancas, puestos, cajas, troncos) lo pone en `false`.
- **Pruebas:** `tests/test_town.gd` ya cubre el pueblo inicial y sus habitantes; se agregó `_check_building_walls()` para la colisión de los edificios (ver [edificios B2W2](edificios_b2w2.md#puerta-visible-y-colisión-de-todo-el-contorno-2026-10-10-noche)) y `_check_furniture_physics()`, que camina al jugador contra el primer macetón de la plaza (no debe atravesarlo) y luego salta sobre él (debe quedar parado encima). Pendiente (no se alcanzó por tiempo): una prueba automática de que la cámara no se pega de golpe con una cerca o farol cerca (se verificó a mano revisando el código de capas, no con una prueba automatizada).
