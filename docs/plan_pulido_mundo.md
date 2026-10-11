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
3. **Inicio y elección del inicial:**
   - Mucha gente se atraviesa en medio de la zona del inicial.
   - No debe dejarte salir de la zona hasta elegir inicial.
   - Instrucciones claras de qué hacer (lanzar la Poké Ball a tu inicial).
   - Cinemática en 3D del profesor viajando y conociendo a los Pokémon; luego el profesor queda a tu lado y te ayuda a elegir, y después sigue su vida. Detalles por preguntar a Fernando.
4. **Mensajes flotantes de la gente** según el contexto: lo que platican entre ellos, lo que hacen al pelear, comentarios de sucesos (p. ej. "está eligiendo su inicial").
5. **Física de los objetos:** al saltar sobre bancas, macetas, etc. se debe quedar encima, no atravesarlas.
6. **IA de los salvajes en combate:** no pegarse siempre al jugador; esquivar, tomar distancia y lanzar ataques con estrategia.
7. **Poké Ball al sacar o guardar al compañero:** aparece en la cabeza del personaje; debe salir de su mano.
8. **Tienda Pokémon sin puerta y con una pared negra** (la caja interior que tapa caras faltantes se ve): mejor diseño, que parezca real y tenga su puerta.
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
**Problemas reportados (bugs, se arreglan):**
- Interior vacío y oscuro; zonas negras (huecos sin pared, se ve el vacío); un área "sin diseño" y un florero flotando (no debe pasar en ningún interior).
- El Kecleon "vendedor" no está en el mostrador, no debería vender y usa un sprite de frente que no es del estilo del mundo.
- Una de las dos escaleras al segundo piso tiene una pared invisible (la otra sí deja subir); algo encimado bajo la escalera.

**Decisiones:**
- **Luz:** propia y cálida dentro de todos los edificios (lámparas de techo y luz ambiente clara), sin depender de la hora; por las ventanas se ve si es de día o de noche.
- **Pokémon en el mundo:** solo sprites de mundo (hojas de caminar estilo B2W2); nada de sprites de frente en el mundo. Un Pokémon de interior, solo como mascota de alguien (p. ej. el Kecleon acompaña al dependiente).
- **Gente:** dependientes humanos en el mostrador (uno de objetos generales y otro de lo de la ciudad: MT, Balls especiales, comida); clientes con rutina (entran, miran estantes, compran, se van, con burbujas); personal con funciones (consejos de objetos, oferta del día rotativa, un niño que intercambia o regala algo una vez al día); segundo piso útil (mostrador propio: medicinas y MT arriba, Balls y comida abajo; zona de descanso).
- **Extras elegidos:** estantes con objetos reales (íconos de lo que venden; al acercarte dice qué es y su precio y lo compras ahí); tarjeta de puntos (Premier Ball por cada 10 Balls, premios mayores después); tablón de anuncios (rumores, brotes, ofertas y peticiones de vecinos que se vuelven misiones cortas); horario 9:00–21:00, cerrada de noche con aviso, fila en la mañana; tu compañero reacciona a los estantes y a veces "pide" algo (comprarlo sube el vínculo); pedidos por encargo (llegan en 1–2 días, aviso del Rotom); existencias limitadas por día (los clientes también compran; se reabastece cada mañana); música de tienda de BW2, sonido de puerta, ruido de gente y jingle de compra; vender lo recolectado con precio del día (sube y baja, en el tablón); mostrador de regalos (regalar a vecinos, líderes o profesor según sus gustos, favores y amistad); eventos de temporada (decoración y rebajas avisadas por el Rotom); ladrón ocasional del equipo villano (si lo alcanzas y le ganas, recompensa); máquina de bebidas (llenan hambre, suben un poco el vínculo, a veces suelta dos) y cabina de fotos con tu compañero (queda en tu Ficha); ruleta diaria de premios con cualquier compra; "empleado del mes": tras muchas compras te saludan por tu nombre, rumores exclusivos y aviso antes de las rebajas.

### Noche (reportado 2026-10-10)
- Los faroles alumbran poco y muchas zonas se ven muy oscuras de noche: más luz de faroles (alcance y fuerza) y un mínimo de luz ambiente para que nunca se vea negro.
- El molino (y cualquier modelo que no se oscurece) se ve de otro color de noche: debe seguir la luz del día y la noche como lo demás.

### Casas y otros interiores (reportado 2026-10-10 noche)
- Por dentro: sin iluminación, paredes oscuras, cosas desfasadas o incompletas (se ve como agua en el piso de una casa). Revisar que no pase en ningún interior ni estructura (misma decisión de luz propia cálida).
- Por fuera: la puerta de la casa no se ve (caja oscura en la fachada) y la cámara hace mucho zoom al estar cerca (choca con cercas y arbustos). Asignado al arreglo de edificios (rama fisica-edificios).
- Casa por dentro: objetos fuera del cuarto flotando en el vacío (ventana, cubeta) y zonas negras por donde se puede caminar (piso fuera de las paredes). Va con el arreglo de interiores.
- Por fuera se atraviesa la puerta/fachada; el laboratorio por fuera es una caja azul con techo (no parece laboratorio). Asignado a la rama fisica-edificios.
- Al hablar con un líder solo sale un aviso ("El líder del gimnasio de … usa Pokémon de un solo tipo") en vez de una conversación con él.

### Centro Pokémon (pedido y decisiones de Fernando, 2026-10-10 noche)
**Problemas (bugs):** por fuera sin puerta y con caja oscura (como la tienda); por dentro un Chansey en el mostrador en vez de la enfermera, zonas negras y poca luz.
**Decisiones:**
- **Mostrador:** la enfermera (sprite de mundo de BW2) atiende; un Chansey o Blissey con su hoja de caminar de mundo la ayuda llevando las Poké Balls a la máquina (mascota, no atiende).
- **Curación clásica animada:** entregas tu equipo, las Balls se colocan en la máquina y se encienden una a una con el jingle de BW2 (~3 s), te las devuelve ("¡Tus Pokémon están en plena forma!"). Abierto 24 h; también cura al jugador y llena un poco el hambre con un té.
- **Servicios:** PC de las Cajas; recordador de movimientos (Escama Corazón o dinero); café y zona de descanso (bebidas que llenan hambre y suben un poco el vínculo; entrenadores descansando para platicar o pelear amistosamente); mostrador de intercambios del día (Pokémon de otra región por uno tuyo de cierta especie); revisión de vínculo y salud con la enfermera (ánimo, cansancio, hambre, consejos); guardería y huevos (tus Pokémon de la Caja ganan experiencia y a veces aparece un huevo); sala de entrenamiento con muñecos de práctica (sube el dominio de movimientos); taquilla de excursiones (tours guiados: ver una bandada, visitar una cueva tapada); fotógrafo y álbum en el Rotom.
- **Ambiente:** gente con rutina (entran a curar, esperan sentados, se van, con burbujas); segundo piso con club de combate (retos amistosos y tabla de récords de racha); tablón de la región (brotes, bandadas, dónde anda cada líder hoy, peticiones); música del Centro de BW2, luz cálida propia y sonido de puerta automática; visitas de líderes, héroes o tu rival curando a su equipo (platicar o retarlos amistosamente).

### Gimnasios (reportado 2026-10-10 noche)
- Mismo problema que la tienda y el centro: cosas incompletas, zonas negras y poca luz. Entra en el arreglo general de interiores (luz propia cálida, paredes y piso completos, nada flotando, nada fuera del cuarto).
