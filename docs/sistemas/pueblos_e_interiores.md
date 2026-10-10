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
- **Salas:** Centro (Chansey o Audino), Tienda (Kecleon), casas, laboratorio, gimnasio y Liga (arena), Sala de Concursos.
- **Mazmorras** en cuadrícula de celdas de 7 m: recorrido al azar de la entrada a la salida con ramas, luces y Pokémon propios (cueva, alcantarilla, torre, mansión, central, laboratorio, Calle Victoria, mina, base, distorsión, barco), y 2 tesoros que se recogen una vez por día.
- Muros bajos y sin choque con la cámara (estilo HD-2D); el del lado de la entrada es más bajo.
- Navegación horneada para el interior. Al guardar adentro se guarda la puerta.

## Retos (gimnasio, Liga, base)
Sale un Pokémon del entrenador a la vez y ataca; al debilitarlo sale el siguiente. **No se pueden capturar** (la ball rebota). Si te desmayas, el reto termina. Liga: requiere las 8 medallas; Alto Mando y Campeón (11 Pokémon fuertes).

## Tienda y MT
- 18 MT, una por tipo (`tm-<tipo>`): enseñan a tu compañero el movimiento más potente de ese tipo de su lista oficial (MT/tutor, o de nivel) que aún no tenga.
- Fósiles: Hélix, Domo, Raíz, Garra, Cráneo, Coraza, Tapa y Pluma → el profesor los revive.
