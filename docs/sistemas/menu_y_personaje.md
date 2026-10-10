# Personaje, menú y sistemas del menú (Fase 2.9, plan)

[← Índice](../README.md) · Decidido con Fernando el 2026-10-09. Estado: **bloque 1 hecho** (personaje, nombre y dificultad); el resto es plan y se construye por bloques (ver abajo).

## Inicio de partida
- Eliges **Hombre o Mujer** y uno de **5 personajes** de cada uno; los 10 tienen la misma funcionalidad (caminar, correr, saltar, nadar, bucear, desmayo, lanzar).
  - Hombres: Red, Ethan, Lucas, Brendan, Calem.
  - Mujeres: Leaf, Lyra, Dawn, May, Serena.
- Sprites (el mejor oficial por personaje): Red, Ethan y Lyra de HGSS; Lucas y Dawn de Platino. No hay oficiales a ese tamaño de Leaf, Brendan, May, Calem y Serena, así que se usan versiones fan de estilo DS: Brendan de hyo-oppa (estilo DPPt/HGSS), May, Serena (pelo corto) y Leaf de Zender1752 (estilo Gen 5) y Calem de TOBALCR (estilo BW). Red, Calem, Leaf, May y Serena no traen correr: corren con su caminar acelerado.
- Escribes tu **nombre** (los textos lo usan en vez de "Nate") y eliges la **dificultad**: daño de los salvajes (×0.6 / ×1 / ×1.4), dinero perdido al desmayarte (5 / 10 / 20 %) y tiempo de recuperación del desmayo (×0.75 / ×1 / ×1.25).
- Vista previa: el personaje gira en 4 direcciones antes de confirmar.

## Menú (Esc / Options)
- Pantalla con **pestañas** estilo Leyendas Arceus, con ventanas de borde pixel B2W2. El juego se pausa; cambias de pestaña con L1/R1 o Q/E.
- Al abrirlo se ve primero el **equipo** (hasta 6) en una tira visual: sprite animado, nombre, vida, tipos y quién es el acompañante. Es el acceso rápido a la ficha de cada uno.
- Pestañas:
  - **Equipo:** ficha completa con estadísticas, tipos, temperamento, habilidades y movimientos desbloqueados, mega, dónde se capturó y si es shiny. Desde aquí lo **eliges como acompañante**.
  - **Mochila:** objetos por bolsillo (ver abajo).
  - **Pokédex:** los 1,025 con estado (no visto, visto, capturado, shiny), con su ficha. La ficha trae sprite animado Gen 5, tipos, estadísticas, hábitat y bioma, rareza, temperamento, cadena evolutiva con desbloqueos, megas y dónde lo viste. Hay filtros por tipo y bioma, y **tareas de investigación** por especie estilo Leyendas Arceus (capturar N, verlo pelear, capturarlo sin que te vea…) que suben su nivel de investigación.
  - **Caja (PC):** capturados fuera del equipo. Puedes ordenarlos, marcar favoritos, liberarlos y cambiarlos con el equipo.
  - **Mapa:** el mapa completo actual.
  - **Diario y misiones:** misiones activas (como las de megapiedras), su progreso y el marcador en el mapa.
  - **Ficha del entrenador:** personaje, nombre, tiempo jugado, dinero, Pokédex, capturas, shinies, legendarios e insignias.
  - **Logros y estadísticas:** medallas por hitos y estadísticas de partida (km recorridos, peleas ganadas, desmayos…).
  - **Dinero:** dinero, últimas compras y ventas, y precios de referencia para las tiendas de la capa 2.6.
  - **Controles:** dibujo pixel art del **teclado de Mac** y del **control de PlayStation**. Al elegir una acción, su botón parpadea y una mini animación muestra a tu personaje haciéndola.
  - **Opciones:** ver abajo.
  - **Guardar:** ver abajo.
- **Guía inicial:** la primera vez que haces cada cosa salen avisos cortos.

## Cambio rápido de acompañante
- **Tocar** Q / △ guarda o saca al acompañante (ya hecho).
- **Mantener** Q / △ abre una rueda con el equipo: eliges con el stick o el mouse y sueltas. El tiempo pasa más lento mientras eliges.

## Mochila (bolsillos)
| Bolsillo | Contenido |
|---|---|
| Pokéballs | Poké, Super, Ultra y especiales (factor de ball en `CaptureRules`) |
| Curación | Pociones para tu Pokémon; comida y bayas para los corazones del jugador |
| Clave | Mega Aro, objetos de misión |
| Megapiedras | Las de cada mega |
| Evolución | Piedras evolutivas y objetos de intercambio usados como desbloqueos |
| Recolección | Bayas, minerales y plantas que se recogen en el mundo (brillos que indican dónde) |
| Fabricación | Recetas: Pokéballs, pociones y señuelos con lo recolectado |
| Señuelos y repelentes | Comida que atrae, bolas de humo, repelente, bolas de barro que aturden |
| Exploración | Linterna, caña de pescar, tanque de aire (más tiempo buceando), botas de nieve |
| Equipables | Objetos que lleva tu Pokémon (Restos, Cinta Elección, bayas de combate), para la Fase 3 |
| Potenciadores | Comida o caramelos temporales: velocidad, más shiny, sigilo, defensa del acompañante |
| Tesoros | Pepitas, perlas y fragmentos para vender |
| Coleccionables | Notas de investigación, cartas e insignias (sección aparte) |

## Opciones
Hecho; lo implementado está en [mochila y Pokédex](mochila_y_pokedex.md). Del plan quedaron fuera, por decisión, el inglés (el juego está escrito en español), la vibración, el límite de FPS y el tamaño del texto.
- **Cámara y control:** sensibilidad de mouse y stick, invertir Y, vibración y reasignar botones.
- **Video:** pantalla completa o ventana, resolución, calidad (sombras, distancia de pasto, desenfoque), límite de FPS y mostrar FPS.
- **Audio:** volumen general, de música, de efectos y de gritos.
- **Juego e interfaz:** velocidad del texto, ayudas de botones, minimapa, barras de vida de salvajes, dificultad e idioma (español o inglés).
- **Accesibilidad:** tamaño del texto, filtro para daltonismo, reducir temblor de cámara y destellos, y mantener o alternar para apuntar y correr.

## Guardado
- **3 ranuras** desde el menú. Cada una muestra personaje, nombre, tiempo jugado y Pokédex.
- **Autoguardado** cada 5 minutos y al entrar a un Centro Pokémon.
- Se guarda: personaje, nombre y dificultad; posición; vida; dinero; equipo, caja y mochila; Pokédex e investigación; legendarios; niebla del mapa; misiones; logros; estadísticas y opciones. Las opciones se guardan aparte, en `user://`.

## Bloques de construcción
1. ✅ Selección de personaje, nombre y dificultad (descarga y conversión de las 10 hojas). Código: `ui/character_select/`, `core/player_characters.gd`, `GameState.character_id/player_name/gender/difficulty`.
2. ✅ Marco del menú con pestañas y tira del equipo; pestañas Equipo, Ficha y Controles; rueda de cambio rápido.
3. ✅ Datos de objetos y Mochila (todos los bolsillos), fabricación y recolección en el mundo.
4. ✅ Pokédex con investigación y Caja.
5. ✅ Guardado (3 ranuras y autoguardado) y Opciones.
Detalle de lo hecho en [mochila y Pokédex](mochila_y_pokedex.md).
6. Diario, logros, estadísticas, dinero y guía inicial.
