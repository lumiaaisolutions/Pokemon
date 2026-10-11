# Plan de pulido del mundo (acordado con Fernando, 2026-10-10)

[← Índice](README.md) · Surgió de su prueba de las fases 3 a 5.6. **Regla nueva:** no asumir nada; toda decisión de diseño se pregunta con opciones y recomendación.

Orden elegido: **bugs → NPC → interiores → biomas** (el mapa entra con los NPC, porque muestra al profesor y a los héroes).

## 1. Bugs
**Hechos todos (2026-10-10).**
- La cámara entra en los edificios (modelos B2W2): revisar todos los modelos, cercas y lugares.
- Se atraviesan las cercas.
- El compañero dentro de un interior queda pegado al borde "como si quisiera pelear" sin nadie: limpiar su objetivo al entrar o salir.
- La fogata sigue de día y no se recoge (se rehace en el punto 2).
- Centro Pokémon y edificios blancos brillan de noche → **se oscurecen como el resto; ventanas, letreros y puerta con luz cálida**.
- Nombres de NPC que no corresponden al género.
- Los NPC cruzan el agua caminando → **nadan con animación** (medio cuerpo y ondas); los nadadores nadan por gusto.
- Rayo al sacar o guardar al Pokémon → **rojo con centro blanco, en zigzag como relámpago, de la mano de Nate hacia donde sale**; al sacarlo la ball se abre con destello; al guardarlo el Pokémon se vuelve rojo y el rayo lo absorbe.

## 2. NPC y personajes
**Hecho (2026-10-10):** clases de BW2 (39 aspectos, `art/npcs/`, `core/npc_looks.gd`, `tools/build_npc_sheets.py`); menos habitantes con lugar propio y espacio personal; conversación con caja de diálogo y opciones (Retar); ganas de pelear por oficio y día; retos al verte (viajeros y peleoneros); campamentos en pixel art con animación de armar y recoger; NPC que nadan; nombres por género.
**Acordado, por hacer:** profesor con sprite según su nombre, en el laboratorio de 8 a 19 h (de noche en su casa) y 1–2 días por semana de viaje a investigar a un lugar del mapa (si lo encuentras allá te da una misión o premio); **asistente** que dice dónde está (marcado en el mapa), recibe tus registros y entrega los premios de investigación; líderes con sprites de BW2 que entrenan fuera del gimnasio (reto amistoso); rival (Hugh) que te busca. Ver también [regiones](sistemas/regiones.md).

- **Aspecto:** sprites de las clases de BW2 según su oficio (Joven, Chica, Montañero, Pescador, Enfermera, Vendedor, Científico, Abuela…), no los héroes. Nombre según su género.
- **Menos y con oficio:** cada uno con rol y lugar (vendedor en su puesto, jardinero, pescador en el muelle, niño en el parque, guardia), rutina por hora y espacio personal (no se amontonan). Fuera del pueblo, solo viajeros y entrenadores.
- **Conversación:** se detiene y te mira; caja de diálogo abajo con retrato y nombre; E avanza. Al final, opciones según quién sea (Retar, Comprar/Vender, Misión, Adiós). Si te da algo: ícono del objeto y fanfarria. Luego sigue su rutina.
- **Ganas de pelear (cambia cada día, se mantiene ese día):** Karatekas, Entrenadores Guay y jóvenes 80 %; viajeros y pescadores 40 %; vendedores, abuelas y niños 10 %. Si hoy no quiere, solo habla; si lo vuelves a ver ese día, tiene las mismas opciones.
- **Quién reta al verte:** fuera del pueblo casi todos los que tienen Pokémon; en el pueblo solo los peleoneros; el resto habla si te acercas.
- **Premio de NPC del pueblo:** igual que los de camino (dinero y objeto, revancha diaria; equipo según su oficio).
- **Campamentos:** carpa y fogata con el estilo del mundo, solo fuera de pueblos; la arma al anochecer con animación y la recoge al amanecer (animación) y sigue su camino.
- **Profesor y personajes importantes (líderes, rival):** rutina (laboratorio de día, casa de noche) y viajes a lugares del mapa. Una **asistente/secretaria** en el laboratorio dice dónde está y se marca en el mapa. Los líderes entrenan fuera del gimnasio; el rival te busca para retarte.
- **Héroes no elegidos** (los otros 9 de los 10): existen como entrenadores **únicos, fuertes y competitivos**. Viajan por la región con su propia ruta y rutina; el Rotom avisa rumores de dónde se vieron. Equipo **fijo e icónico** (Red con Pikachu y Charizard…), 6 evolucionados, uno con mega, **IA lista** (cambia por tipo, esquiva, se cura) y **crecen progresivamente contigo** (según medallas y avance).
- **Entrenadores fuertes** además de los héroes: con buenos Pokémon y estrategia.
- **Avisos:** lo que dice un NPC en la caja de diálogo; el resto en **tarjetas con ícono y color por categoría** (objeto, captura, misión, clima, logro) que entran por la derecha y se apilan.

## 3. Mapa
**Hecho (2026-10-10):** zoom, arrastre, detalle por acercamiento, tarjeta al pasar el cursor y destino en el minimapa como brújula.
- **Ilustrado con zoom:** rueda o gatillos para acercar (región completa a calles), arrastrar para moverse; terreno por bioma, caminos y ríos; íconos grandes por tipo (pueblos, Centro, tienda, gimnasio, cuevas, ruinas, lugares, profesor y héroes vistos, misiones). Tarjeta al pasar el cursor. La niebla de lo no explorado se mantiene.
- **Marcar destino:** marca en la brújula y el minimapa, **sin línea de guía en el camino**.

## 4. Interiores
- **Modelos originales de B2W2** (The Models Resource): Centro con mostrador y enfermera, tienda con estantes, casas con muebles, laboratorio con máquinas, gimnasios. Todo lugar donde se entre debe tener diseño.
- Descargas: se pide permiso **una vez por lote** con la lista y el tamaño aproximado.

## 5. Biomas
- **Kit por bioma + puntos de interés.** Ejemplos: pantano (charcos, juncos, nenúfares, árboles muertos, troncos, neblina baja); pantano tóxico (charcos morados que burbujean, hongos venenosos, árboles secos, gas); pradera (flores en grupos, rocas, arbustos, cercas viejas, letreros). Puntos de interés cada cierta distancia: campamento abandonado, pozo, ruinas pequeñas, árbol grande con bayas, cueva chica, mirador.

## 6. Interfaz estilo Pokopia (pedido 2026-10-10, sus imágenes solo como referencia)
**Hecho (2026-10-10):** menú con panel rojo e íconos vectoriales, secciones con marco rojo, Pokédex en cuadrícula, estilo claro en HUD, combate, inicio, diálogo y avisos en tarjetas; pestaña para la leyenda (toque de H).
- **Menú:** el juego sigue visible a la izquierda (con minimapa); a la derecha un **panel rojo redondeado** con bolitas de color arriba. Dentro, tarjeta clara con **cuadrícula de íconos grandes y coloridos** (Pokémon, Mochila, Pokédex, Cajas, Rotom, Foto, Mapa, Logros, Opciones, Guardar). Al elegir, la sección se abre en pantalla completa con el mismo marco rojo.
- **Íconos dibujados estilo Pokopia** (pixel art de alta resolución, redondeados), con rebote y halo amarillo al enfocarlos.
- **Pokédex:** cuadrícula de 8 por fila; capturados con sprite a color, vistos en silueta gris; **los no vistos no aparecen** (hueco con su número). Al enfocar, burbuja con el nombre y círculo amarillo. Abajo: filtro, orden y contador. Al abrir uno, su ficha.
- **Un solo estilo en todo el juego** (HUD, combate, inicio, diálogos): paneles claros redondeados, acentos rojos, botones tipo píldora con el glifo del botón. Reemplaza el azul marino.

## 7. Pueblos con identidad (acordado 2026-10-10)
- **Tema por pueblo** según bioma y tamaño (pesquero, minero, agrícola, turístico, científico, histórico, deportivo…). El tema decide: estilo de casas, un **monumento o edificio icónico** (faro, molino, estatua, fuente, mercado, puerto, torre), plaza con decoración propia, puestos, colores y NPC de oficios acordes.

## Bugs extra reportados
- Fruto visible distinto al objeto recogido (árbol de bonguri). **Hecho.**
- Agua de charcas que flota en pendiente. **Hecho** (nivel por la orilla más baja).
- Faltan caras traseras en modelos de B2W2. **Hecho** (núcleo sólido).

## 8. Tablero de misiones (acordado 2026-10-10)
- **A la izquierda**, bajo las instrucciones de bienvenida: 3 tarjetas pequeñas con ícono, nombre y barra de avance (en curso o con más avance).
- **J** (o mantener cruceta ↓) abre el **tablero completo**: todas las misiones por categoría (Rotom, megapiedras, foto, entrenadores, investigación, regiones) con objetivos y premios.

## 9. Viaje por regiones (acordado 2026-10-10)
Ver [regiones](sistemas/regiones.md): 6 regiones generadas al desbloquearse, 8 líderes al azar de Kanto a Teselia por región, Liga por región, completar con 8 medallas + Liga + 50 % de misiones, viaje en barco o avión, dificultad que sube, Pokédex regional y legendarios repartidos, profesor por región.

## Orden de trabajo actual
1. ~~Profesor, asistente y rival~~ (**hecho**, ver [personajes](sistemas/personajes_importantes.md); los líderes por tipo van con las regiones) → 2. ~~Héroes no elegidos~~ (**hecho**, ver [héroes](sistemas/heroes.md)) → 3. ~~Tablero de misiones~~ (**hecho**) → 4. ~~Interiores~~ (**hecho**, ver [edificios](sistemas/edificios_b2w2.md)) → 5. ~~Biomas~~ (**hecho**: kit, pasto, flores y puntos de interés) → 6. ~~Pueblos con identidad~~ (**hecho**) → 7. ~~Regiones~~ (**hecho**, ver [regiones](sistemas/regiones.md); pendiente: sprites definitivos de Cilan y Volkner).

### Nota sobre los líderes (2026-10-10)
En la hoja de BW2 reconozco con certeza a Brock, Misty, Lt. Surge, Whitney, Brawly, Roark, Crasher Wake, Clair, Flint, Steven y a los de BW2 (Clay, Skyla, Marlon, Iris, Elesa, Lenora, Cheren). El resto se nombrará con un **catálogo que Fernando confirme** antes de las regiones.

## Pedidos nuevos tras las regiones (2026-10-10, en este orden)
1. ~~Destello de los shiny~~ (**hecho**) → [salvajes](sistemas/pokemon_salvajes.md).
2. ~~Salvajes comunes que se repiten y raros escasos~~ (**hecho**) → [salvajes](sistemas/pokemon_salvajes.md).
3. ~~Voladores y Bicho en árboles: tamaño, Bicho en el suelo, desfase desde arriba~~ (**hecho**) → [salvajes](sistemas/pokemon_salvajes.md).
4. ~~Viaje entre regiones en 3D estilo BW2~~ (**hecho**) → [regiones](sistemas/regiones.md).
5. ~~Animaciones de ataques (25 familias)~~ (**hecho**) → [animaciones de ataques](sistemas/animaciones_ataques.md).
6. ~~Campamento, comida y hambre~~ (**hecho**, con propuestas por confirmar) → [jugador](sistemas/jugador.md).

## Pedidos tras probar el juego (2026-10-10, noche)
Reportados por Fernando con capturas mientras avanzaba la fase 5.8.
1. **Calem con huecos blancos** en su sprite: la herramienta borraba el contorno negro y el blanco de los ojos como fondo. **Hecho** (`tools/protagonist_sheets.py`, `alpha_only`).
2. **Avisos del Rotom con etiqueta "MISIÓN"**: tarjeta propia "ROTOM" para brotes, bandadas, lluvia de estrellas…; las misiones siguen como "MISIÓN". **Hecho** (`NoticeCards.rotom_category`).
3. **Inicio y elección del inicial: Hecho** (`world/starter/intro_cinematic.gd`, `world/starter/starter_ceremony.gd`) → [inicio](sistemas/inicio.md).
   - Mucha gente se atraviesa en medio de la zona del inicial. **Hecho:** `TownNPCs.set_exclusion_zone`/`clear_exclusion_zone`, pared de exclusión que empuja a los vecinos fuera de la plaza mientras no eliges.
   - No debe dejarte salir de la zona hasta elegir inicial. **Hecho:** pared invisible de `StarterCeremony` (16 m alrededor de la plaza) que regresa al jugador y, cada pocos segundos, el profesor lo detiene en la caja de diálogo.
   - Instrucciones claras de qué hacer (lanzar la Poké Ball a tu inicial). **Hecho:** tarjeta de tutorial ("Mantén para apuntar") y la tarjeta general de lanzar (ya existente) se encadenan paso a paso con `InputHints` reales (teclado/mouse o mando).
   - Cinemática en 3D del profesor viajando y conociendo a los Pokémon; luego el profesor queda a tu lado y te ayuda a elegir, y después sigue su vida. **Hecho:** `IntroCinematic` (4 lugares reales del mundo generado, un candidato por lugar) + `StarterCeremony` (llegada a la plaza, comentarios al acercarte, elección y despedida).
4. **Mensajes flotantes de la gente** según el contexto: lo que platican entre ellos, lo que hacen al pelear, comentarios de sucesos (p. ej. "está eligiendo su inicial"). **Hecho** (`world/npc/speech_bubbles.gd`, ver [habitantes](sistemas/habitantes.md#burbujas-contexto-y-charlas-2026-10-10)).
5. **Física de los objetos:** al saltar sobre bancas, macetas, etc. se debe quedar encima, no atravesarlas. **Hecho** (`Structures._collider`/`_cylinder_collider`, `Structures.furniture`, `TownNPCs._avoid_furniture`) → [pueblos e interiores](sistemas/pueblos_e_interiores.md#física-del-mobiliario-y-cámara-2026-10-10-noche).
6. **IA de los salvajes en combate:** no pegarse siempre al jugador; esquivar, tomar distancia y lanzar ataques con estrategia. **Hecho** (`world/actors/pokemon_actor.gd`, `_think_wild_fight`) → [combate](sistemas/combate.md).
7. **Poké Ball al sacar o guardar al compañero:** aparece en la cabeza del personaje; debe salir de su mano. **Hecho** (`world/main.gd`, `_hand_position`) → [jugador](sistemas/jugador.md).
8. **Tienda Pokémon sin puerta y con una pared negra** (la caja interior que tapa caras faltantes se ve): mejor diseño, que parezca real y tenga su puerta. **Hecho** (`BuildingModels.instance`, núcleo trasero en vez de centrado; colisión de todo el contorno) → [edificios B2W2](sistemas/edificios_b2w2.md#puerta-visible-y-colisión-de-todo-el-contorno-2026-10-10-noche).
9. **Prueba intermitente (resuelta):** la del viajero fallaba cuando el jugador caía en el agua o el viajero ya había pasado; la de la horda y la de huir esperaban cuadros de física y bajo carga (con el juego abierto) varios caben en uno. Ahora esperan cuadros reales.

### Decisiones de Fernando (2026-10-10, noche)
- **Cinemática:** viaje y reunión: el profesor recorre 3–4 lugares (pradera, bosque, costa, montaña), conoce en cada uno a un candidato, vuelven al pueblo y la cámara termina en la plaza donde te espera. **30–45 s, se puede saltar** (Esc / Start); se ve una vez por partida nueva.
- **Zona del inicial:** **pared invisible** alrededor de la plaza con aviso (sin corral); la gente se aparta y no se atraviesa en medio.
- **Guía:** **tutorial paso a paso**: el profesor habla en la caja de diálogo, comenta a cada candidato al acercarte (tipo y carácter) e indica en pantalla cada paso ("Mantén clic derecho para apuntar" → "Lanza con R"); al elegir te felicita, te da Poké Balls y se va a su rutina.
- **Burbujas:** **contexto y charlas**: charla breve entre vecinos que se cruzan, frases al pelear ("¡Usa Placaje!", "¡Esquiva!"), reacciones a sucesos cercanos ("¡Está eligiendo su inicial!", "¡Un shiny!", "¡Una horda!") y por hora o clima; solo cerca de ti, máximo 3 a la vez.
- **IA salvaje:** **según su carácter**: rápidos o de poca defensa esquivan y atacan a distancia; fuertes cuerpo a cuerpo embisten y se retiran; todos rodean, toman distancia, esquivan ataques que ven venir y usan movimientos de estado cuando conviene.
- **Física:** **todo el mobiliario** (bancas, macetas, cercas, faroles, mesas, puestos, cajas) sólido para jugador, gente y Pokémon; al saltar te quedas encima de los bajos.
- **Edificios:** **completar el modelo**: cubrir las caras faltantes de los modelos B2W2 con paredes que imiten su textura en vez de la caja negra, y verificar que la puerta quede al frente, hacia la calle, donde está el punto de "Entrar".

### Tienda Pokémon por dentro (pedido y decisiones de Fernando, 2026-10-10 noche)
**Problemas reportados (bugs):**
- Interior vacío y oscuro; zonas negras (huecos sin pared, se ve el vacío); un área "sin diseño" y un florero flotando (no debe pasar en ningún interior). **Hecho (2026-10-10, rama `interiores`):** la causa raíz era la cámara (ver [interiores](sistemas/pueblos_e_interiores.md#arreglo-base-de-todos-los-interiores-2026-10-10-rama-interiores)); ya se ve el cuarto completo, con luz propia y sin huecos.
- El Kecleon "vendedor" no está en el mostrador, no debería vender y usa un sprite de frente que no es del estilo del mundo. **Hecho:** el dependiente (humano) atiende el mostrador; el Kecleon es su mascota, con su hoja de caminar de mundo.
- Una de las dos escaleras al segundo piso tiene una pared invisible (la otra sí deja subir); algo encimado bajo la escalera. **Atajada la causa descrita** (el piso detectado no llegaba hasta la escalera y el muro del contorno la cortaba), **pero sin prueba automática que suba por cada escalera**: pendiente de confirmar en el juego.

**Decisiones:**
- **Luz:** propia y cálida dentro de todos los edificios (lámparas de techo y luz ambiente clara), sin depender de la hora; por las ventanas se ve si es de día o de noche. **Hecho (base, 2026-10-10).**
- **Pokémon en el mundo:** solo sprites de mundo (hojas de caminar estilo B2W2); nada de sprites de frente en el mundo. Un Pokémon de interior, solo como mascota de alguien (p. ej. el Kecleon acompaña al dependiente). **Hecho.**
- **Gente:** dependientes humanos en el mostrador (uno de objetos generales y otro de lo de la ciudad: MT, Balls especiales, comida); clientes con rutina (entran, miran estantes, compran, se van, con burbujas); personal con funciones (consejos de objetos, oferta del día rotativa, un niño que intercambia o regala algo una vez al día); segundo piso útil (mostrador propio: medicinas y MT arriba, Balls y comida abajo; zona de descanso). **Por hacer** (solo el dependiente base quedó, el resto son las funciones nuevas grandes de este apartado).
- **Extras elegidos:** estantes con objetos reales (íconos de lo que venden; al acercarte dice qué es y su precio y lo compras ahí); tarjeta de puntos (Premier Ball por cada 10 Balls, premios mayores después); tablón de anuncios (rumores, brotes, ofertas y peticiones de vecinos que se vuelven misiones cortas); horario 9:00–21:00, cerrada de noche con aviso, fila en la mañana; tu compañero reacciona a los estantes y a veces "pide" algo (comprarlo sube el vínculo); pedidos por encargo (llegan en 1–2 días, aviso del Rotom); existencias limitadas por día (los clientes también compran; se reabastece cada mañana); música de tienda de BW2, sonido de puerta, ruido de gente y jingle de compra; vender lo recolectado con precio del día (sube y baja, en el tablón); mostrador de regalos (regalar a vecinos, líderes o profesor según sus gustos, favores y amistad); eventos de temporada (decoración y rebajas avisadas por el Rotom); ladrón ocasional del equipo villano (si lo alcanzas y le ganas, recompensa); máquina de bebidas (llenan hambre, suben un poco el vínculo, a veces suelta dos) y cabina de fotos con tu compañero (queda en tu Ficha); ruleta diaria de premios con cualquier compra; "empleado del mes": tras muchas compras te saludan por tu nombre, rumores exclusivos y aviso antes de las rebajas.

### Noche (reportado 2026-10-10)
- Los faroles alumbran poco y muchas zonas se ven muy oscuras de noche: más luz de faroles (alcance y fuerza) y un mínimo de luz ambiente para que nunca se vea negro.
- El molino (y cualquier modelo que no se oscurece) se ve de otro color de noche: debe seguir la luz del día y la noche como lo demás.
- **Hecho (2026-10-10 noche):** el molino brillaba porque sus texturas `c7wind*` se tomaban como ventanas (contienen "win"); ahora solo `mado` o `win` seguido de número (`BuildingModels.is_window_texture`). Faroles: energía 0.75 → 2.4 y alcance 5 → 11 m (`DayNight.LAMP_ENERGY`); luna 0.2 → 0.3 y luz ambiente de noche 0.42 → 0.5.

### Casas y otros interiores (reportado 2026-10-10 noche)
- Por dentro: sin iluminación, paredes oscuras, cosas desfasadas o incompletas (se ve como agua en el piso de una casa). Revisar que no pase en ningún interior ni estructura (misma decisión de luz propia cálida). **Hecho (base, 2026-10-10, rama `interiores`):** mismo arreglo de cámara, techo, luz y contorno que la tienda y el Centro; revisado por capturas de día y de noche en casa, laboratorio y gimnasio.
- Por fuera: la puerta de la casa no se ve (caja oscura en la fachada) y la cámara hace mucho zoom al estar cerca (choca con cercas y arbustos). Asignado al arreglo de edificios (rama fisica-edificios). **Sigue pendiente** (es por fuera, no es la rama `interiores`).
- Casa por dentro: objetos fuera del cuarto flotando en el vacío (ventana, cubeta) y zonas negras por donde se puede caminar (piso fuera de las paredes). Va con el arreglo de interiores. **Hecho:** no se vio ninguno de estos casos en las capturas; el contorno ahora tapa los huecos del modelo.
- Por fuera se atraviesa la puerta/fachada; el laboratorio por fuera es una caja azul con techo (no parece laboratorio). Asignado a la rama fisica-edificios. **Sigue pendiente** (por fuera).
- Al hablar con un líder solo sale un aviso ("El líder del gimnasio de … usa Pokémon de un solo tipo") en vez de una conversación con él. Esto ya usaba `DialogBox` al revisar el código (`talk_leader`, `ask_leader`); con el arreglo de interiores también pasan a `DialogBox` el profesor, el entrenador del gimnasio ya vencido, el juez de la Sala de Concursos y el tutor de movimientos, que seguían con avisos sueltos.

### Centro Pokémon (pedido y decisiones de Fernando, 2026-10-10 noche)
**Problemas (bugs):** por fuera sin puerta y con caja oscura (como la tienda); por dentro un Chansey en el mostrador en vez de la enfermera, zonas negras y poca luz.
**Hecho (base, 2026-10-10, rama `interiores`):** por dentro ya no hay zonas negras ni poca luz (ver [interiores](sistemas/pueblos_e_interiores.md#arreglo-base-de-todos-los-interiores-2026-10-10-rama-interiores)); la enfermera (humana) atiende y un Chansey o Blissey la acompaña de mascota, con su hoja de caminar de mundo. Lo de "por fuera" sigue en la rama fisica-edificios.
**Decisiones (resto, por hacer):**
- **Curación clásica animada:** entregas tu equipo, las Balls se colocan en la máquina y se encienden una a una con el jingle de BW2 (~3 s), te las devuelve ("¡Tus Pokémon están en plena forma!"). Abierto 24 h; también cura al jugador y llena un poco el hambre con un té.
- **Servicios:** PC de las Cajas; recordador de movimientos (Escama Corazón o dinero); café y zona de descanso (bebidas que llenan hambre y suben un poco el vínculo; entrenadores descansando para platicar o pelear amistosamente); mostrador de intercambios del día (Pokémon de otra región por uno tuyo de cierta especie); revisión de vínculo y salud con la enfermera (ánimo, cansancio, hambre, consejos); guardería y huevos (tus Pokémon de la Caja ganan experiencia y a veces aparece un huevo); sala de entrenamiento con muñecos de práctica (sube el dominio de movimientos); taquilla de excursiones (tours guiados: ver una bandada, visitar una cueva tapada); fotógrafo y álbum en el Rotom.
- **Ambiente:** gente con rutina (entran a curar, esperan sentados, se van, con burbujas); segundo piso con club de combate (retos amistosos y tabla de récords de racha); tablón de la región (brotes, bandadas, dónde anda cada líder hoy, peticiones); música del Centro de BW2, luz cálida propia y sonido de puerta automática; visitas de líderes, héroes o tu rival curando a su equipo (platicar o retarlos amistosamente).

### Gimnasios (reportado 2026-10-10 noche)
- Mismo problema que la tienda y el centro: cosas incompletas, zonas negras y poca luz. Entra en el arreglo general de interiores (luz propia cálida, paredes y piso completos, nada flotando, nada fuera del cuarto). **Hecho (base, 2026-10-10, rama `interiores`):** mismo arreglo; además, uno de los gimnasios (hielo) tenía el piso mal detectado (confundía un plano de fondo decorativo con el piso real) y quedaba vacío y oscuro — ya corregido, revisado con los 6 modelos de gimnasio.
- **Se atraviesan las paredes de los edificios** por fuera (el jugador queda dentro del modelo). Prioridad alta en la rama fisica-edificios, con prueba que camine contra las 4 caras de cada edificio. **Sigue pendiente** (por fuera, no es la rama `interiores`).

### Todo en 3D estilo B2W2 (decisión de Fernando, 2026-10-10 noche)
- Árboles, rocas y piedras, arbustos, flores, cactus **y la hierba alta** pasan a 3D, con **modelos reales de B2W2** (models.spriters-resource.com; permiso por cada descarga, Fernando pasa el Cloudflare si aparece).
- Fernando preguntó qué más está en 2D: se revisa y se le presenta la lista.
- Todas estas correcciones son reglas permanentes: [reglas_calidad.md](reglas_calidad.md).
- **Entrenadores que te ven (corregido 2026-10-10):** te podías ir caminando y saltarte el combate. Ahora al verte quedas quieto mirándolo hasta que llega (sale tu compañero si estaba guardado) y en combates contra entrenadores no se puede huir: tu Pokémon vuelve al círculo con el aviso "¡No puedes huir de un combate contra un entrenador!".
- **Cofres en 2D** (y todo lo demás): regla ampliada en [reglas_calidad.md](reglas_calidad.md): todo en 3D salvo Pokémon, personajes y NPC.
- **Hecho (2026-10-10, noche):** árboles, rocas, arbustos, flores, cactus, hongos, hierba alta, recolectables (arbusto de bayas, árbol de bonguri, roca con minerales), lugares de interés (campamento con cofre 3D en 3 niveles, pozo, ruinas, árbol grande, cueva chica, mirador) y las flores/arbustos junto a los edificios del pueblo, todos en 3D (`PropModels3D`, ver [arte](sistemas/arte.md#todo-el-mundo-en-3d-2026-10-10-noche)). Pendiente: revisión visual con capturas por bioma y ajustar proporciones a ojo si algo se ve raro.

### Más pedidos tras probar (2026-10-10, noche) — por diseñar con Fernando o por hacer
- **Poké Ball (hecho):** atraviesa a los posados en árboles → ahora se les atina (caen al pie del árbol); rebota en lo que golpea; al atinar, rayo rojo que atrapa al Pokémon y luego las 3 sacudidas.
- **Dormir en la tienda de campaña:** animación de entrar, "Zzz" y lo que hace mientras duerme (hoy solo pasa de noche a día de golpe). También animaciones para Cocinar y Recoger. **Por preguntar ideas.**
- **Botones de todas las interfaces** (p. ej. Dormir/Cocinar/Recoger/Nada): mejor diseño, más visual. **Por preguntar.**
- **Rival:** apareció, retó y desapareció sin que se supiera si había que pelear. Bug por revisar (flujo claro: diálogo con opciones o combate obligatorio).
- **Pueblos:** más grandes, más detalle y decoración (sin bugs visuales), más cosas que hacer, identidad propia y diferencias reales entre ellos (algunos sin cosas que otros sí tienen). **Por preguntar.**
- **Vecino que solo da avisos:** corregido (hablan en la caja de diálogo); revisar que nadie más hable por avisos.
- **Mapa y mundo:** pocos puntos de interés; más eventos aleatorios, misiones extra y zonas exclusivas (como se acordó). **Por preguntar.**
- **Pantano tóxico:** envenena progresivamente al jugador, a tu Pokémon fuera y a los salvajes que pasen; no afecta a los Pokémon tipo Veneno ni a los que el veneno no afecta (Acero; habilidades como Inmunidad).
- **Mochila (hecho):** al acabarse un objeto, la descripción y las acciones de la derecha se quedaban; ahora desaparecen.
- **Rotom Móvil:** rediseño más visual e intuitivo, con forma de Rotom Teléfono (naranja con ojos), interactivo y sin amontonar; todo lo del Rotom con ese estilo; recursos de estilo BW2 si se pueden descargar. **Por preguntar.**
- **Todos los apartados del menú sin excepción** (Dinero, Equipo, Mochila, Pokédex, Cajas, Logros, Ficha, Mapa, Controles, Opciones, Guardar): responsivos, más interactivos, sin amontonar, más visuales y que se entienda cada cosa. **Por preguntar.**

### Decisiones de Fernando (2026-10-10, noche, ronda 3)
- **Veneno del pantano tóxico (hecho, `world/hazards/toxic_swamp.gd`):** estado que dura: pisar el agua morada envenena; pierdes vida poco a poco mientras sigues ahí y 20 s después de salir; igual tu Pokémon fuera y los salvajes que pasen; se cura con Antídoto, en el Centro Pokémon o al dormir; no afecta a tipo Veneno ni Acero. **Debe verse que está envenenado** (identificador visible en el jugador, en el Pokémon y en el HUD).
- **Dormir:** escena corta: Nate entra a la tienda, la cámara se aleja, "Zzz" saliendo de la tienda, tu compañero se acurruca junto a la fogata, el cielo pasa de noche a amanecer en ~4 s (estrellas, luna que baja, sol que sale), Nate sale estirándose; se salta con E.
- **Campamento animado:** cocinar (Nate revuelve la olla con vapor y burbujas, tu compañero mira con corazón, el platillo aparece en un plato sobre el tronco); recoger (la fogata se apaga con humo, la tienda se dobla y entra a la mochila); armar (la tienda se levanta pieza por pieza y la fogata se enciende con chispas).
- **Campamento, extras:** visitantes nocturnos (un salvaje curioso se acerca a la fogata mientras duermes, o deja un objeto); "Convivir" con todo tu equipo alrededor de la fogata (sube un poco el vínculo al día); sueños cortos con pistas (brote, legendario, cueva tapada); música tranquila, crepitar y luciérnagas de noche; mejorar el campamento con materiales (tienda más grande y de colores, fogata que cocina más rápido, mesa, baúl para guardar); mirar las estrellas (constelaciones con forma de Pokémon, algunas dan pistas). Fernando pidió aún más ideas: proponerlas al probar lo construido.
- **Botones de todas las interfaces:** ícono pixel + texto en píldora, color propio por acción, sombra, se agranda y brilla al pasar o elegir, con sonido.
- **Rival:** combate obligatorio como los entrenadores que te ven: te detiene, habla en la caja de diálogo y el combate empieza sí o sí. **Hecho:** desaparecía porque el combate no arrancaba con tu compañero guardado; ahora saca a tu compañero, espera y, si de verdad no puedes pelear, te lo dice antes de irse.

### Mundo más lleno y pueblos distintos (decisiones de Fernando, 2026-10-10 noche)
Fernando: los mapas aleatorios se ven vacíos y simples; los pueblos son pequeños, sin decoración y casi iguales.
- **Lugares en el campo:** rutas con vida (puentes, letreros, casetas de descanso, granjas, establos, molinos, pozos, cercas, campamentos de viajeros, aldeas de 2–3 casas); lugares únicos por bioma (templo en la montaña, barco hundido en la costa, árbol gigante, ruinas en el desierto, base científica en la tundra, faro, aguas termales en el volcán…); mazmorras y cuevas reales (varios pisos, tesoros, Pokémon propios y jefe al final); zonas exclusivas (Safari, isla de legendarios, bosque místico…); nidos y guaridas (árbol de Pidgey, colmena de Combee, madriguera de Diglett, con líder a veces); miradores (revelan el mapa), tirolesas y puentes colgantes; lugares de entrenamiento (dojos, cascadas, gimnasios abandonados con retos); santuarios de legendarios con acertijos.
- **Eventos:** misiones de NPC en el campo (niño perdido, Pokémon herido, mercader asaltado, alguien que busca un objeto); sucesos dinámicos (árbol caído que bloquea, Pokémon gigante dormido en el camino, torneo improvisado, caravana de comerciantes); tesoros y secretos (cofres escondidos, mapas del tesoro, puzles en ruinas, lugares que solo se ven de noche o con cierto clima); equipo villano activo (roba, bloquea caminos, bases que crecen); carreras y retos de tiempo en bici o montura con récords; clima extremo (tormentas eléctricas, ventiscas, sequías que cambian lo que sale); ferias y festivales en un pueblo al azar.
- **Densidad:** moderada, algo cada ~300 m.
- **Pueblos:** identidad por tema según bioma y oficio (pesquero, minero, granjero, tecnológico, artistas, termal…: edificios, colores, decoración, música y gente distintos); tamaños variados (aldeas, pueblos, ciudades con barrios, plazas y calles; no todos tienen todo); 1–2 edificios únicos por pueblo (museo, casino de juegos, salón de concursos, biblioteca, fábrica, acuario, mercado, torre); más cosas que hacer (minijuegos, tablones con encargos, fiestas en ciertos días, gente con misiones, tiendas especiales); casas que puedes comprar y decorar (descanso y guardado); pueblo que crece si ayudas a su gente (tiendas nuevas, más gente); transporte entre pueblos visitados (carruajes, botes, Pokémon taxi).
- Fernando pidió más recomendaciones de lugares; proponerlas al probar lo construido.

- **Veneno, detalles de implementación:** quita 0.5 de vida por segundo al jugador y 3 % por segundo a los Pokémon, nunca por debajo de 1 (no desmaya, como en los juegos actuales); se ve con tinte morado que late y burbujas moradas sobre el envenenado y los corazones del HUD en morado. Nuevo objeto **Antídoto** ($200, Curación, a la venta en la Tienda Pokémon). Prueba en `test_camping`.

### Rotom Móvil y menú (decisiones de Fernando, 2026-10-10 noche)
- **Rotom:** Teléfono Rotom en pantalla: entra flotando un Rotom Teléfono naranja con ojos; su pantalla tiene apps con íconos grandes; al tocar una se abre a pantalla completa con tarjetas, íconos y barras; el Rotom parpadea y reacciona (sonríe al cumplir algo).
- **Apps:** Actividades y caminos (tarjetas con ícono, barra y premio; caminos con progreso e insignias); Noticias con íconos por tipo, hora y "Ver en el mapa"; Clima y calendario (pronóstico por bioma, estación, días de eventos, horario de líderes); Charla con Rotom (consejos según lo que te falta, con animaciones); Cámara y álbum; Brújula de objetivos (flecha en el HUD); Contactos (líderes, héroes, profesor y rival: dónde están, revancha, consejos).
- **Menú completo (sin excepción):** tarjetas visuales: tarjetas grandes, íconos pixel, gráficas y colores por categoría; nada de listas de texto; se adapta al tamaño de la ventana; animaciones al entrar y al elegir; explicación de cada cosa al pasar el cursor (p. ej. Dinero: saldo grande con monedas, gráfica de ingresos y gastos, íconos en cada precio).
- **Recursos:** descargar recursos de interfaz de BW2/Rotom de spriters-resource pidiendo permiso por lote (archivo, origen, tamaño); Fernando pasa el Cloudflare si aparece.

### Recursos descargados (2026-10-10 noche, con permiso)
- 20 modelos de B2W2 en `art/models/b2w2_nature/` (4 mapas con vegetación y 16 objetos de mapa) para pasar árboles, arbustos, flores, hierba, rocas, letreros, cercas y faroles a 3D. Hallazgo: como piezas sueltas solo existen algunos objetos; los árboles normales, arbustos, flores y la hierba vienen dentro de los mapas y hay que extraerlos de ahí.
- Hoja "Overworld Entities" de BW en `sprites/overworld/bw_overworld_entities.png`: trae a Cilan. **Volkner no está** (es de Sinnoh): falta pedir permiso para la hoja de DP "NPCs (Overworld)" 6931.

### Últimas decisiones antes de la noche (Fernando, 2026-10-10)
- **Cofres:** 3D propio estilo BW2 (madera de pocas caras con textura pixel y herrajes; se abren con animación y brillo); variantes común (madera), raro (plata) y legendario (oro).
- **Cinemática:** 4 candidatos, uno por lugar visitado (pradera, bosque, costa, montaña), al azar entre los básicos de ese hábitat; la protagoniza el profesor de la región, que narra en cajas de texto cortas, con la música de introducción de BW2.
- **Túneles:** desfiladero a cielo abierto (paso estrecho entre paredes de roca, 40–80 m, algo de pasto, a veces un cofre, Pokémon de roca, sin pantalla de carga), tapado por una roca grande.
- **Jefes (fase 6):** guardianes por bioma (Pokémon enorme y fuerte con fases, ataques en área que se esquivan y premio único; uno fuerte del bioma elegido al azar por región, marcado por el Rotom) **y** el líder del equipo villano al final.
- **Dificultad:** se adapta sola a tu nivel (si ganas mucho, los rivales se vuelven más listos).
- **Pueblos:** todos el doble de grandes.
- **Entrega (fase 7):** aplicación de Mac (.app) en el Escritorio con ícono propio, guardado en la carpeta de usuario, y pasada final de rendimiento y bugs.
- **Trabajo de noche:** si surge una duda de diseño nueva, elijo la opción recomendada y la anoto en [decisiones_sin_preguntar.md](decisiones_sin_preguntar.md) con sus alternativas para que Fernando la revise. Máximo 3 agentes a la vez (en cuanto uno termina, entra el siguiente).

## Plan de la noche (orden de trabajo)
**Meta (Fernando):** el loop sigue hasta terminar el juego completo (fases 6 y 7 incluidas) y sin detalles como los reportados (ver [reglas_calidad.md](reglas_calidad.md)); al final, una revisión general con capturas de todo el juego buscando esos defectos.
1. Integrar lo de los agentes en curso (IA salvaje y Poké Ball en mano; interiores base) con la batería completa.
2. ~~Todo el mundo en 3D con los modelos de B2W2 (vegetación, rocas, objetos), cofres 3D propios~~ (**hecho** 2026-10-10, rama `mundo-3d`; pendiente revisión visual con capturas por bioma).
3. Cinemática del profesor e inicio (pared invisible, tutorial paso a paso). **Hecho.**
4. Faroles más fuertes de noche y el molino que cambiaba de color; Cilan y Volkner con sus sprites definitivos.
5. Túneles-desfiladero tapados por rocas grandes.
6. Campamento animado y extras; botones nuevos en todas las interfaces. **Hecho** (rama `campamento-ui`) → [jugador](sistemas/jugador.md), [interfaz](sistemas/interfaz.md).
7. Rotom Teléfono con apps y menú con tarjetas visuales.
6. Campamento animado y extras; botones nuevos en todas las interfaces.
7. ~~Rotom Teléfono con apps y menú con tarjetas visuales.~~ **Hecho** (2026-10-11, rama `rotom-menu`): Rotom Teléfono dibujado en vectores que parpadea y sonríe, con sus 7 apps (Actividades y caminos, Noticias, Clima y calendario, Charla con Rotom, Cámara y álbum, Brújula de objetivos, Contactos); Dinero y Logros del menú en tarjetas con ícono y gráfica; animación de entrada y tooltips en todas las pestañas. Detalle en [interfaz.md](sistemas/interfaz.md#rotom-teléfono-y-menú-con-tarjetas-en-todas-las-pestañas-2026-10-11). Pendiente si se quiere más: el mismo nivel de detalle (gráficas, tooltips exhaustivos) en Equipo, Mochila, Pokédex, Cajas, Ficha, Mapa, Controles, Opciones y Guardar.
8. Tienda y Centro Pokémon con todas sus funciones.
9. Mundo más lleno (algo cada ~300 m) y pueblos ×2 con identidad.
10. Fase 6 (guardianes, líder villano, dificultad adaptable) y fase 7 (app de Mac y pasada final).
